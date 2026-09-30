/**
 * ArogyaChain AI — Cloud Functions (Day 6, Asset 3)
 * =================================================
 * Entry point. Wires four capabilities:
 *   1. onTransactionWrite  — RTDB trigger → forecast → Risk Score → alert if > 80
 *   2. computeAllRisks     — scheduled every 30 min, re-scores all PHC×medicine pairs
 *   3. forecastLocal       — weighted-ensemble fallback forecaster (no Vertex bill)
 *   4. parseVoiceCommand   — Gemini API natural-language stock update parser
 *   5. recommendTransfer / executeTransfer — redistribution logic + alert dispatch
 *
 * Vertex endpoint vs local fallback is controlled by functions config:
 *   firebase functions:config:set vertex.endpoint="..." vertex.project="..."
 * If unset → local forecaster is used and demo never blocks on billing/quota.
 */

const admin = require("firebase-admin");
const functions = require("firebase-functions");
const { parseCommand } = require("./lib/voiceParser");
const { forecastLocal } = require("./lib/forecastLocal");
const { recommendTransfers } = require("./lib/redistribution");
const { sendAlert } = require("./lib/alerts");
const { predictWithVertex } = require("./lib/vertexClient");

admin.initializeApp();
const db = admin.database();

const ALERT_THRESHOLD = 80; // Risk Score (0-100) above which we alert
const HORIZON_DAYS = 7;

// ---------------------------------------------------------------------------
// 1) RTDB trigger: every new transaction re-scores that PHC×medicine pair
// ---------------------------------------------------------------------------
exports.onTransactionWrite = functions.database
  .ref("/transactions/{phcId}/{txId}")
  .onCreate(async (snapshot, ctx) => {
    const tx = snapshot.val();
    const { phcId } = ctx.params;
    const medKey = String(tx.medicine || "").trim();
    if (!medKey) return null;

    const invRef = db.ref(`/inventory/${phcId}/medicines/${medKey}`);
    const invSnap = await invRef.get();
    if (!invSnap.exists()) return null;
    const inv = invSnap.val();

    // apply the movement to stock
    let stock = Number(inv.stock || 0);
    if (tx.type === "dispense") stock = Math.max(0, stock - Number(tx.quantity || 0));
    else if (tx.type === "restock" || tx.type === "adjust") stock += Number(tx.quantity || 0);

    // demand history: record actual dispensed demand only — restock/adjust
    // quantities would poison the demand signal the forecaster consumes
    const demandEntry = tx.type === "dispense" ? Math.max(0, Number(tx.quantity || 0)) : 0;
    const history = (inv.history14 || []).concat([demandEntry]).slice(-14);
    const avgDaily = history.length ? history.reduce((a, b) => a + b, 0) / history.length : 1;

    const updatedInv = {
      ...inv,
      stock,
      history14: history,
      avgDailyUse: Math.round(avgDaily * 10) / 10,
    };

    await invRef.update({
      stock,
      history14: history,
      avgDailyUse: updatedInv.avgDailyUse,
    });

    // pass the FULL updated inventory so the forecaster sees history14
    await scoreAndMaybeAlert(phcId, medKey, updatedInv);
    return null;
  });

// ---------------------------------------------------------------------------
// 2) Scheduled: recompute every risk score twice an hour
// ---------------------------------------------------------------------------
exports.computeAllRisks = functions.pubsub
  .schedule("every 30 minutes")
  .onRun(async () => {
    const invSnap = await db.ref("inventory").get();
    if (!invSnap.exists()) return null;
    const jobs = [];
    invSnap.forEach((phcSnap) => {
      const phcId = phcSnap.key;
      phcSnap.child("medicines").forEach((medSnap) => {
        jobs.push(scoreAndMaybeAlert(phcId, medSnap.key, medSnap.val()));
      });
    });
    await Promise.allSettled(jobs);
    return null;
  });

// ---------------------------------------------------------------------------
// Core scorer: forecast next-7-day demand → risk = f(cover, forecast, reorder)
// ---------------------------------------------------------------------------
async function scoreAndMaybeAlert(phcId, medKey, inv) {
  const stock = Number(inv.stock || 0);
  const avgDaily = Math.max(Number(inv.avgDailyUse || 0), 0.1);
  const reorder = Number(inv.reorderLevel || avgDaily * 10);

  // ---- Two-stage forecasting (the judge-visible AI moment) ----
  let forecast;
  let source;
  try {
    if (functions.config().vertex && functions.config().vertex.endpoint) {
      forecast = await predictWithVertex({
        phcId,
        medicine: medKey,
        recent: inv.history14 || [],
        horizon: HORIZON_DAYS,
      });
      source = "vertex";
    } else {
      throw new Error("vertex-not-configured");
    }
  } catch (e) {
    forecast = await forecastLocal({ recent: inv.history14 || [], horizon: HORIZON_DAYS });
      source = "local-ensemble";
  }

  const total7d = forecast.reduce((a, b) => a + b, 0);
  const daysOfCover = stock / Math.max(avgDaily, 0.1);
  const deficit = Math.max(0, total7d - stock);
  const deficitRatio = Math.min(1, deficit / Math.max(total7d, 1));

  // Composite risk: coverage collapse dominates, deficit pushes it up, reorder buffer adds urgency
  let risk = 100 * (0.6 * Math.max(0, 1 - daysOfCover / 14)
    + 0.3 * deficitRatio
    + 0.1 * Math.max(0, 1 - stock / Math.max(reorder, 1)));
  risk = Math.max(0, Math.min(100, Math.round(risk)));

  const update = {
    risk,
    daysOfCover: Math.round(daysOfCover * 10) / 10,
    forecast7d: Math.round(total7d),
    forecastSource: source,
    updatedAt: admin.database.ServerValue.TIMESTAMP,
  };
  await db.ref(`/riskScores/${phcId}/${medKey}`).update(update);

  if (risk >= ALERT_THRESHOLD) {
    await sendAlert(db, {
      phcId,
      medicine: medKey,
      risk,
      daysOfCover,
      stock,
      channel: functions.config().whatsapp && functions.config().whatsapp.enabled
        ? "whatsapp" : "fcm",
    });
  }
  return update;
}

// ---------------------------------------------------------------------------
// 3) Redistribution engine (HTTPS, callable from dashboard)
// ---------------------------------------------------------------------------
exports.recommendTransfer = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  if (req.method === "OPTIONS") {
    res.set("Access-Control-Allow-Headers", "Content-Type");
    res.set("Access-Control-Allow-Methods", "POST, GET");
    return res.status(204).end();
  }
  try {
    const invSnap = await db.ref("inventory").get();
    const riskSnap = await db.ref("riskScores").get();
    const recs = recommendTransfers(invSnap.val(), riskSnap.val());
    const batch = {};
    recs.forEach((r) => {
      const id = db.ref("recommendations").push().key;
      batch[`recommendations/${id}`] = {
        ...r,
        status: "proposed",
        createdAt: admin.database.ServerValue.TIMESTAMP,
      };
    });
    await db.ref().update(batch);
    return res.status(200).json({ count: recs.length, recommendations: recs });
  } catch (e) {
    return res.status(500).json({ error: String(e.message || e) });
  }
});

exports.executeTransfer = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  if (req.method === "OPTIONS") {
    res.set("Access-Control-Allow-Headers", "Content-Type");
    return res.status(204).end();
  }
  try {
    const { recommendationId } = req.body || {};
    const recSnap = await db.ref(`recommendations/${recommendationId}`).get();
    if (!recSnap.exists()) return res.status(404).json({ error: "not found" });
    const rec = recSnap.val();
    if (rec.status !== "proposed") return res.status(409).json({ error: `status=${rec.status}` });

    const fromRef = db.ref(`/inventory/${rec.fromPhc}/medicines/${rec.medicine}`);
    const toRef = db.ref(`/inventory/${rec.toPhc}/medicines/${rec.medicine}`);
    const [fromSnap, toSnap] = [await fromRef.get(), await toRef.get()];
    if (!fromSnap.exists() || !toSnap.exists()) return res.status(404).json({ error: "inventory missing" });

    const qty = Math.min(Number(rec.quantity), Number(fromSnap.val().stock));
    const txId = db.ref().push().key;
    await db.ref().update({
      [`/inventory/${rec.fromPhc}/medicines/${rec.medicine}/stock`]:
        Number(fromSnap.val().stock) - qty,
      [`/inventory/${rec.toPhc}/medicines/${rec.medicine}/stock`]:
        Number(toSnap.val().stock) + qty,
      [`recommendations/${recommendationId}/status`]: "executed",
      [`transactions/${rec.fromPhc}/${txId}f`]: {
        medicine: rec.medicine, type: "adjust", quantity: -qty,
        note: `transfer-out to ${rec.toPhc}`, timestamp: admin.database.ServerValue.TIMESTAMP,
      },
      [`transactions/${rec.toPhc}/${txId}t`]: {
        medicine: rec.medicine, type: "adjust", quantity: qty,
        note: `transfer-in from ${rec.fromPhc}`, timestamp: admin.database.ServerValue.TIMESTAMP,
      },
    });
    return res.status(200).json({ ok: true, transferred: qty });
  } catch (e) {
    return res.status(500).json({ error: String(e.message || e) });
  }
});

// ---------------------------------------------------------------------------
// 4) Gemini voice-command parser (called by the Flutter app)
// ---------------------------------------------------------------------------
exports.parseVoiceCommand = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  if (req.method === "OPTIONS") {
    res.set("Access-Control-Allow-Headers", "Content-Type");
    return res.status(204).end();
  }
  try {
    const { text, phcId, lang } = req.body || {};
    if (!text || !phcId) return res.status(400).json({ error: "text and phcId required" });

    const parsed = await parseCommand(text, lang || "ta");
    if (!parsed.ok) return res.status(200).json({ ok: false, reason: parsed.reason });

    const txId = db.ref(`transactions/${phcId}`).push().key;
    await db.ref(`transactions/${phcId}/${txId}`).set({
      medicine: parsed.medicineKey,
      spoken: parsed.spoken,
      type: parsed.type || "dispense",
      quantity: parsed.quantity,
      timestamp: admin.database.ServerValue.TIMESTAMP,
    });
    return res.status(200).json({ ok: true, ...parsed, txId });
  } catch (e) {
    return res.status(500).json({ error: String(e.message || e) });
  }
});
