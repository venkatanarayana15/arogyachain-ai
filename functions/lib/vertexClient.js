/**
 * vertexClient.js — Vertex AI AutoML Forecasting endpoint caller
 * ===============================================================
 * Called when functions config has vertex.endpoint set:
 *   firebase functions:config:set vertex.endpoint="projects/P/locations/us-central1/endpoints/ID"
 *                                          vertex.project="arogyachain-ai"
 *
 * Uses google-auth-library ADC (works on Cloud Functions out of the box) or an
 * API key via functions config (vertex.apikey) for local emulator runs.
 */

const { GoogleAuth } = require("google-auth-library");

async function predictWithVertex({ phcId, medicine, recent = [], horizon = 7 }) {
  const cfg = require("firebase-functions").config();
  const endpoint = cfg.vertex && cfg.vertex.endpoint;
  if (!endpoint) throw new Error("vertex.endpoint not configured");

  const auth = new GoogleAuth({ scopes: "https://www.googleapis.com/auth/cloud-platform" });
  const client = await auth.getClient();
  const accessToken = await client.getAccessToken();

  // AutoML Forecasting returns predictions for a forecast window; for the live
  // risk score we request instance rows with the same covariate contract as
  // preprocess_vertex.py (day_of_week, month_sin, month_cos).
  const now = new Date();
  const instances = [];
  for (let d = 1; d <= horizon; d++) {
    const day = new Date(now.getTime() + d * 86400000);
    const m = day.getMonth() + 1;
    instances.push({
      time_series_identifier: `${phcId}|${medicine}`,
      quantity_dispensed: null,
      day_of_week: day.getDay(),
      month_sin: Math.sin((2 * Math.PI * m) / 12).toFixed(4),
      month_cos: Math.cos((2 * Math.PI * m) / 12).toFixed(4),
    });
  }

  const url = `https://${regionHost(endpoint)}/v1/${endpoint}:predict`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken.token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ instances }),
  });
  if (!res.ok) throw new Error(`vertex ${res.status}: ${await res.text()}`);
  const data = await res.json();
  const preds = (data.predictions || []).map((p) => Number(p.value != null ? p.value : p));
  if (!preds.length) throw new Error("vertex returned no predictions");
  return preds.slice(0, horizon);
}

function regionHost(endpoint) {
  // endpoint: projects/P/locations/us-central1/endpoints/ID
  const m = /locations\/([^/]+)/.exec(endpoint);
  return m ? `${m[1]}-aiplatform.googleapis.com` : "us-central1-aiplatform.googleapis.com";
}

module.exports = { predictWithVertex };
