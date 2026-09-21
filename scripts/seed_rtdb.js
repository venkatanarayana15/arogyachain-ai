#!/usr/bin/env node
/**
 * seed_rtdb.js — Seed Firebase Realtime Database from data/inventory_seed.json
 * =============================================================================
 * Usage:
 *   npm --prefix functions install            # if not already
 *   node scripts/seed_rtdb.js [path/to/serviceAccountKey.json]
 *
 * Get the service account key: Firebase Console → Project settings →
 * Service accounts → Generate new private key → save as serviceAccountKey.json
 * (gitignored — never commit it).
 */

const fs = require("fs");
const path = require("path");
const admin = require(path.join(__dirname, "..", "functions", "node_modules", "firebase-admin"));

const keyPath = process.argv[2] || path.join(__dirname, "..", "serviceAccountKey.json");
if (!fs.existsSync(keyPath)) {
  console.error(`Service account key not found at ${keyPath}`);
  console.error("Download it from Firebase Console → Project settings → Service accounts.");
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(require(path.resolve(keyPath))),
  databaseURL: "https://arogyachain-ai-default-rtdb.firebaseio.com",
});

const seed = JSON.parse(
  fs.readFileSync(path.join(__dirname, "..", "data", "inventory_seed.json"), "utf8")
);

(async () => {
  // Normalize each medicine entry: keep core fields, initialize history14.
  const inventory = {};
  for (const [phcId, phc] of Object.entries(seed.inventory)) {
    inventory[phcId] = {
      name: phc.name,
      district: phc.district,
      medicines: {},
    };
    for (const [medKey, m] of Object.entries(phc.medicines)) {
      inventory[phcId].medicines[medKey] = {
        medicine: m.medicine,
        strength: m.strength,
        category: m.category,
        stock: m.stock,
        reorderLevel: m.reorderLevel,
        avgDailyUse: m.avgDailyUse,
        history14: Array.from({ length: 14 }, () =>
          Math.max(0, Math.round(m.avgDailyUse * (0.8 + Math.random() * 0.4)))
        ),
      };
    }
  }

  await admin.database().ref().update({ inventory });
  const phcCount = Object.keys(inventory).length;
  const medCount = Object.keys(inventory[Object.keys(inventory)[0]].medicines).length;
  console.log(`[OK] Seeded ${phcCount} PHCs × ${medCount} medicines into /inventory`);
  console.log("     Risk scores will appear within 30 min (computeAllRisks) or on first transaction.");
  process.exit(0);
})().catch((e) => {
  console.error("Seed failed:", e.message);
  process.exit(1);
});
