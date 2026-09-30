#!/usr/bin/env node
/**
 * e2e.js — End-to-end test of the REAL functions/index.js + lib/* logic.
 * ==========================================================================
 * firebase-admin and firebase-functions are stubbed via Module._load; the
 * fake RTDB implements the exact surface index.js uses (ref/get/set/update/
 * push/snapshot forEach/child). Everything else — voice parser, forecaster,
 * redistribution engine, risk formula, alert dispatch — is the real code.
 *
 * Scenarios:
 *  1. RTDB trigger: dispense tx → stock update + history + risk score
 *  2. Alert path:  risk >= 80 → alertLog written + FCM send
 *  3. Scheduled:   computeAllRisks populates riskScores for all pairs
 *  4. HTTPS recommendTransfer → writes real recommendations
 *  5. HTTPS executeTransfer → moves stock both sides + tx logs
 *  6. HTTPS parseVoiceCommand (Tamil) → tx written with parsed payload
 *  7. HTTPS parseVoiceCommand (unknown drug) → graceful ok:false
 *  8. Risk bounds: every computed score in [0,100]
 *
 * Run: node test/e2e.js   (exit 1 on any failure)
 */

const assert = require("assert");
const Module = require("module");
const path = require("path");

// ---------------------------------------------------------------------------
// Fake RTDB
// ---------------------------------------------------------------------------
const tree = {};
const fcmSends = [];
let pushCounter = 0;

function splitPath(p) {
  return String(p).split("/").filter(Boolean);
}
function getValue(p) {
  let node = tree;
  for (const k of splitPath(p)) {
    if (node == null || typeof node !== "object") return null;
    node = node[k];
  }
  return node === undefined ? null : node;
}
function setValue(p, v) {
  const parts = splitPath(p);
  let node = tree;
  while (parts.length > 1) {
    const k = parts.shift();
    if (typeof node[k] !== "object" || node[k] === null) node[k] = {};
    node = node[k];
  }
  const last = parts.shift();
  if (v === null) delete node[last];
  else node[last] = v;
}
function snap(value, key) {
  return {
    key,
    exists: () => value !== null && value !== undefined,
    val: () => value,
    child: (k) => snap(value && typeof value === "object" ? (value[k] ?? null) : null, k),
    forEach: (cb) => {
      if (value && typeof value === "object") {
        return Object.keys(value).some((k) => cb(snap(value[k], k)) === true);
      }
      return false;
    },
  };
}
const dbApi = {
  ref: (p = "") => ({
    get: async () => snap(getValue(p), splitPath(p).pop()),
    set: async (v) => setValue(p, v),
    update: async (map) => {
      for (const [k, v] of Object.entries(map)) setValue(`${p}/${k}`, v);
    },
    push: () => {
      const key = `push-${++pushCounter}`;
      return {
        key,
        set: async (v) => setValue(`${p}/${key}`, v),
        update: async (m) => {
          for (const [k, v] of Object.entries(m)) setValue(`${p}/${key}/${k}`, v);
        },
      };
    },
  }),
  ServerValue: { TIMESTAMP: 1758451200000 },
};

// ---------------------------------------------------------------------------
// Stub firebase-admin / firebase-functions, then load the REAL index.js
// ---------------------------------------------------------------------------
const registry = { onCreate: null, onRun: null };

const adminStub = Object.assign(
  () => dbApi,
  {
    initializeApp: () => {},
    database: Object.assign(() => dbApi, { ServerValue: dbApi.ServerValue }),
    messaging: () => ({
      send: async (msg) => {
        fcmSends.push(msg);
        return "projects/x/messages/ok";
      },
    }),
  }
);

const functionsStub = {
  config: () => ({}), // no vertex config → local-ensemble fallback path
  database: {
    ref: (p) => ({
      onCreate: (h) => {
        registry.onCreate = { path: p, handler: h };
        return h;
      },
    }),
  },
  pubsub: {
    schedule: () => ({
      onRun: (h) => {
        registry.onRun = h;
        return h;
      },
    }),
  },
  https: { onRequest: (h) => h },
};

const origLoad = Module._load;
Module._load = function (request, parent, isMain) {
  if (request === "firebase-admin") return adminStub;
  if (request === "firebase-functions") return functionsStub;
  return origLoad.apply(this, arguments);
};

const fn = require(path.join(__dirname, "..", "index.js"));

// ---------------------------------------------------------------------------
// HTTP req/res doubles
// ---------------------------------------------------------------------------
function makeRes() {
  return {
    statusCode: 0,
    body: null,
    headers: {},
    set(k, v) { this.headers[k] = v; return this; },
    status(c) { this.statusCode = c; return this; },
    json(b) { this.body = b; return this; },
    end() { return this; },
  };
}

// ---------------------------------------------------------------------------
// Seed data (mirrors data/inventory_seed.json demo story)
// ---------------------------------------------------------------------------
function seedInventory() {
  for (const k of Object.keys(tree)) delete tree[k];
  fcmSends.length = 0;
  pushCounter = 0;
  const hist = (n) => Array.from({ length: 14 }, () => n);
  setValue("inventory/PHC-001/medicines/Paracetamol_500mg", {
    medicine: "Paracetamol", strength: "500mg", category: "Analgesic-Antipyretic",
    stock: 40, reorderLevel: 200, avgDailyUse: 24, history14: hist(24),
  });
  setValue("inventory/PHC-005/medicines/Paracetamol_500mg", {
    medicine: "Paracetamol", strength: "500mg", category: "Analgesic-Antipyretic",
    stock: 900, reorderLevel: 150, avgDailyUse: 10, history14: hist(10),
  });
  setValue("inventory/PHC-001/medicines/Amoxicillin_500mg", {
    medicine: "Amoxicillin", strength: "500mg", category: "Antibiotic",
    stock: 10, reorderLevel: 150, avgDailyUse: 18, history14: hist(18),
  });
  setValue("inventory/PHC-005/medicines/Amoxicillin_500mg", {
    medicine: "Amoxicillin", strength: "500mg", category: "Antibiotic",
    stock: 750, reorderLevel: 120, avgDailyUse: 9, history14: hist(9),
  });
}

let passed = 0;
let failed = 0;
async function scenario(name, testFn) {
  try {
    seedInventory();
    await testFn();
    passed++;
    console.log(`  PASS  ${name}`);
  } catch (e) {
    failed++;
    console.log(`  FAIL  ${name}\n        ${e.message}`);
  }
}

(async () => {
  console.log("ArogyaChain AI — Functions E2E (real index.js, fake RTDB)\n");

  // 1) RTDB trigger ---------------------------------------------------------
  await scenario("trigger: dispense tx updates stock/history/risk", async () => {
    setValue("transactions/PHC-001/tx1", { medicine: "Paracetamol_500mg", type: "dispense", quantity: 50, timestamp: 1 });
    const txSnap = snap(getValue("transactions/PHC-001/tx1"), "tx1");
    await registry.onCreate.handler(txSnap, { params: { phcId: "PHC-001", txId: "tx1" } });

    const inv = getValue("inventory/PHC-001/medicines/Paracetamol_500mg");
    assert.strictEqual(inv.stock, 0, `stock should clamp at 0, got ${inv.stock}`);
    assert.strictEqual(inv.history14.length, 14);
    assert.strictEqual(inv.history14[13], 50, "latest dispense appended to history14");
    assert.ok(inv.avgDailyUse > 24, `avgDailyUse should rise toward 25.9, got ${inv.avgDailyUse}`);

    const risk = getValue("riskScores/PHC-001/Paracetamol_500mg");
    assert.strictEqual(risk.forecastSource, "local-ensemble");
    // the 50-unit demand spike must raise the rolling-mean forecast above the
    // steady-state 7×24=168 — proves history14 actually feeds the forecaster
    assert.ok(risk.forecast7d > 168, `7d forecast ${risk.forecast7d} should exceed steady-state 168`);
    assert.strictEqual(risk.daysOfCover, 0);
    assert.strictEqual(risk.risk, 100, `cover=0 → risk 100, got ${risk.risk}`);
  });

  // 2) Alert path -----------------------------------------------------------
  await scenario("trigger: risk >= 80 fires FCM + alertLog", async () => {
    // dispense 35 of 40 → stock 5, cover ~0.2d → composite risk ≈ 98
    setValue("transactions/PHC-001/tx2", { medicine: "Paracetamol_500mg", type: "dispense", quantity: 35, timestamp: 2 });
    await registry.onCreate.handler(snap(getValue("transactions/PHC-001/tx2"), "tx2"),
      { params: { phcId: "PHC-001", txId: "tx2" } });

    const risk = getValue("riskScores/PHC-001/Paracetamol_500mg");
    assert.ok(risk.risk >= 90 && risk.risk <= 100, `near-zero cover → risk ≥90, got ${risk.risk}`);
    const alerts = getValue("alertLog") || {};
    const first = Object.values(alerts)[0];
    assert.ok(first, "alertLog entry written");
    assert.ok(first.message.includes(`STOCK-OUT RISK ${risk.risk}%`), `alert message should cite ${risk.risk}%`);
    assert.strictEqual(first.channel, "fcm");
    assert.strictEqual(fcmSends.length, 1, `FCM send count ${fcmSends.length}`);
    assert.match(fcmSends[0].topic, /alerts-PHC-001/);
    assert.strictEqual(first.status, "fcm-sent");
  });

  // 3) Scheduled scoring ----------------------------------------------------
  await scenario("scheduled: computeAllRisks scores every PHC×medicine", async () => {
    await registry.onRun();
    const scores = getValue("riskScores");
    const pairs = [];
    for (const [phc, meds] of Object.entries(scores)) {
      for (const [med, v] of Object.entries(meds)) {
        assert.ok(v.risk >= 0 && v.risk <= 100, `risk bounds violated: ${phc}/${med}=${v.risk}`);
        pairs.push(`${phc}/${med}=${v.risk}`);
      }
    }
    assert.strictEqual(pairs.length, 4, `expected 4 scored pairs, got ${pairs.length}`);
    assert.ok(getValue("riskScores/PHC-001/Amoxicillin_500mg").risk >= 80,
      "starved Amoxicillin (stock 10, use 18/day) must be high risk");
    assert.ok(getValue("riskScores/PHC-005/Paracetamol_500mg").risk <= 40,
      "stocked-up PHC-005 must be low risk");
  });

  // 4) Recommend transfers --------------------------------------------------
  let recId = null;
  await scenario("https: recommendTransfer writes PHC-005→PHC-001 recs", async () => {
    await registry.onRun(); // populate risk scores first
    const req = { method: "POST", body: {} };
    const res = makeRes();
    await fn.recommendTransfer(req, res);
    assert.strictEqual(res.statusCode, 200, `status ${res.statusCode}: ${JSON.stringify(res.body)}`);
    assert.ok(res.body.count >= 1, "at least one recommendation");
    const recs = getValue("recommendations");
    const rec = Object.entries(recs).find(([, r]) => r.medicine === "Paracetamol_500mg");
    assert.ok(rec, "Paracetamol recommendation present");
    assert.strictEqual(rec[1].fromPhc, "PHC-005");
    assert.strictEqual(rec[1].toPhc, "PHC-001");
    assert.strictEqual(rec[1].status, "proposed");
    recId = rec[0];
  });

  // 5) Execute transfer -----------------------------------------------------
  await scenario("https: executeTransfer moves stock + writes tx logs", async () => {
    await registry.onRun();
    const req0 = { method: "POST", body: {} };
    const res0 = makeRes();
    await fn.recommendTransfer(req0, res0);
    const recs = getValue("recommendations");
    const [id, rec] = Object.entries(recs).find(([, r]) => r.status === "proposed");

    const fromBefore = getValue(`inventory/${rec.fromPhc}/medicines/${rec.medicine}`).stock;
    const toBefore = getValue(`inventory/${rec.toPhc}/medicines/${rec.medicine}`).stock;

    const res = makeRes();
    await fn.executeTransfer({ method: "POST", body: { recommendationId: id } }, res);
    assert.strictEqual(res.statusCode, 200, `status ${res.statusCode}: ${JSON.stringify(res.body)}`);
    assert.strictEqual(res.body.ok, true);

    const fromAfter = getValue(`inventory/${rec.fromPhc}/medicines/${rec.medicine}`).stock;
    const toAfter = getValue(`inventory/${rec.toPhc}/medicines/${rec.medicine}`).stock;
    assert.strictEqual(fromAfter, fromBefore - res.body.transferred, "donor decremented");
    assert.strictEqual(toAfter, toBefore + res.body.transferred, "receiver incremented");
    assert.strictEqual(getValue(`recommendations/${id}/status`), "executed");

    const outTx = getValue(`transactions/${rec.fromPhc}`) || {};
    assert.ok(Object.values(outTx).some((t) => t.note && t.note.includes("transfer-out")), "transfer-out logged");
    const inTx = getValue(`transactions/${rec.toPhc}`) || {};
    assert.ok(Object.values(inTx).some((t) => t.note && t.note.includes("transfer-in")), "transfer-in logged");
  });

  // 6) Voice command (Tamil) ------------------------------------------------
  await scenario("https: parseVoiceCommand Tamil → dispense tx written", async () => {
    const res = makeRes();
    await fn.parseVoiceCommand(
      { method: "POST", body: { text: "பாராசிட்டமால் ஐம்பது", phcId: "PHC-001" } }, res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.body.ok, true, JSON.stringify(res.body));
    assert.strictEqual(res.body.medicineKey, "Paracetamol_500mg");
    assert.strictEqual(res.body.quantity, 50);
    assert.strictEqual(res.body.type, "dispense");
    const txs = getValue("transactions/PHC-001") || {};
    const tx = Object.values(txs).find((t) => t.spoken !== undefined);
    assert.ok(tx, "parsed tx persisted with spoken form");
    assert.strictEqual(tx.medicine, "Paracetamol_500mg");
  });

  // 7) Voice command fallback ----------------------------------------------
  await scenario("https: parseVoiceCommand unknown drug → ok:false", async () => {
    const res = makeRes();
    await fn.parseVoiceCommand(
      { method: "POST", body: { text: "Aspirin 30", phcId: "PHC-001" } }, res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.body.ok, false);
    assert.match(res.body.reason, /medicine-not-recognized/);
  });

  // 8) Validation failures are graceful ------------------------------------
  await scenario("https: executeTransfer unknown id → 404", async () => {
    const res = makeRes();
    await fn.executeTransfer({ method: "POST", body: { recommendationId: "nope" } }, res);
    assert.strictEqual(res.statusCode, 404);
  });

  console.log(`\n${passed} passed, ${failed} failed`);
  process.exit(failed ? 1 : 0);
})().catch((e) => {
  console.error("Harness crashed:", e);
  process.exit(1);
});
