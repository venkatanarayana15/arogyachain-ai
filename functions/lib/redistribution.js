/**
 * redistribution.js — Cross-PHC transfer recommendation engine
 * =============================================================
 * Greedy surplus→deficit matcher driven by live Risk Scores:
 *   1. Find receivers: risk >= 70 (high stock-out risk within 7 days)
 *   2. Find donors:    risk <= 30 AND surplus > buffer after giving
 *   3. Match same-medicine, rank by severity × deficit, cap at donor surplus
 * Produces "Transfer 50 units of Paracetamol_500mg from PHC-005 to PHC-001".
 */

const RECEIVER_RISK = 70;
const DONOR_MAX_RISK = 30;
const SEVERITY_FLOOR = 50;

/**
 * @param {object|null} inventory  /inventory node
 * @param {object|null} riskScores /riskScores node
 * @returns {Array<{medicine,fromPhc,toPhc,quantity,severity,reason}>}
 */
function recommendTransfers(inventory, riskScores) {
  const recs = [];
  if (!inventory || !riskScores) return recs;

  for (const [phcId, phcInv] of Object.entries(inventory)) {
    const meds = phcInv && phcInv.medicines;
    if (!meds) continue;
    for (const medKey of Object.keys(meds)) {
      const recvRisk = getRisk(riskScores, phcId, medKey);
      if (recvRisk == null || recvRisk.risk < RECEIVER_RISK) continue;

      const need = Math.max(1, Math.round((recvRisk.forecast7d || 0) - (meds[medKey].stock || 0)));
      if (need <= 0) continue;

      // find best donor for this medicine
      let best = null;
      for (const [dId, dInv] of Object.entries(inventory)) {
        if (dId === phcId) continue;
        const dMed = dInv && dInv.medicines && dInv.medicines[medKey];
        if (!dMed) continue;
        const dRisk = getRisk(riskScores, dId, medKey);
        if (!dRisk || dRisk.risk > DONOR_MAX_RISK) continue;
        const surplus = Number(dMed.stock || 0) - Number(dMed.reorderLevel || 0);
        if (surplus <= 0) continue;
        const qty = Math.min(need, surplus);
        if (qty <= 0) continue;
        const score = recvRisk.risk + qty / 100;
        if (!best || score > best.score) {
          best = { dId, qty, score, surplus };
        }
      }

      if (best) {
        recs.push({
          medicine: medKey,
          fromPhc: best.dId,
          toPhc: phcId,
          quantity: Math.round(best.qty),
          severity: Math.min(100, recvRisk.risk),
          reason: `${phcId} has ${recvRisk.daysOfCover ?? "?"} days of cover; ` +
                  `${best.dId} holds ${best.surplus} above its reorder buffer.`,
        });
      }
      if (recs.length >= 10) return recs; // dashboard top-10 is plenty
    }
  }
  return recs.sort((a, b) => b.severity - a.severity);
}

function getRisk(riskScores, phcId, medKey) {
  const node = riskScores && riskScores[phcId] && riskScores[phcId][medKey];
  if (!node || typeof node.risk !== "number") return null;
  return node;
}

module.exports = { recommendTransfers, RECEIVER_RISK, DONOR_MAX_RISK, SEVERITY_FLOOR };
