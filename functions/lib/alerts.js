/**
 * alerts.js — Alert dispatcher (FCM push default, WhatsApp optional)
 * ===================================================================
 * Default channel: Firebase Cloud Messaging — zero external accounts, works
 * in every demo. WhatsApp (Meta Cloud API) activates only when functions
 * config has whatsapp.enabled + whatsapp.token + whatsapp.phoneId; a demo-mode
 * webhook (alertLog in RTDB) always fires so the dashboard can show the trail.
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin"); // ServerValue + messaging (app initialized in index.js)

/**
 * @param {admin.database.Database} db
 * @param {{phcId, medicine, risk, daysOfCover, stock, channel}} a
 */
async function sendAlert(db, a) {
  const message =
    `[ArogyaChain] STOCK-OUT RISK ${a.risk}% — ${a.phcId} / ${a.medicine}\n` +
    `~${Math.round(a.daysOfCover)} days of cover left (stock ${a.stock}).\n` +
    `Action: open dashboard → approve recommended transfer.`;

  // 1) Always write the audit trail (drives the dashboard "Alerts" feed)
  const alertRef = db.ref("alertLog").push();
  await alertRef.set({
    phcId: a.phcId,
    medicine: a.medicine,
    risk: a.risk,
    channel: a.channel,
    message,
    status: "logged",
    sentAt: admin.database.ServerValue.TIMESTAMP,
  });

  // 2) FCM push (default)
  if (a.channel === "fcm") {
    try {
      await admin.messaging().send({
        topic: `alerts-${a.phcId}`,
        notification: {
          title: `⚠️ Stock-out risk ${a.risk}%: ${a.medicine}`,
          body: `${a.phcId}: ~${Math.round(a.daysOfCover)} days of cover left.`,
        },
      });
      await alertRef.update({ status: "fcm-sent" });
    } catch (e) {
      await alertRef.update({ status: `fcm-failed: ${String(e.message || e).slice(0, 120)}` });
    }
  }

  // 3) WhatsApp via Meta Cloud API (optional)
  if (a.channel === "whatsapp") {
    const cfg = functions.config().whatsapp || {};
    if (cfg.token && cfg.phoneId && cfg.to) {
      try {
        const res = await fetch(`https://graph.facebook.com/v20.0/${cfg.phoneId}/messages`, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${cfg.token}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            messaging_product: "whatsapp",
            to: cfg.to,
            type: "text",
            text: { body: message },
          }),
        });
        await alertRef.update({ status: res.ok ? "whatsapp-sent" : `whatsapp-${res.status}` });
      } catch (e) {
        await alertRef.update({ status: `whatsapp-failed: ${String(e.message || e).slice(0, 120)}` });
      }
    }
  }
  return message;
}

module.exports = { sendAlert };
