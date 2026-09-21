# 🏆 ArogyaChain AI

**Track 3 — Smart Health & Supply Chain Resilience** · Built for the 9-day sprint (Sep 21–30, 2026)

Voice-first, AI-predictive medicine supply chain for Primary Health Centres (PHCs).
Workers **speak** stock updates in Tamil/Hindi/English → **Vertex AI forecasts** stock-out risk →
**one-click redistribution** moves surplus from overstocked PHCs to starved ones → alerts fire.

```
Voice ("பாராசிட்டமால் ஐம்பது") → Firebase RTDB → Cloud Function → Vertex AI / on-device GBM
     → Risk Score (0-100) → Dashboard → Transfer Recommendation → FCM/WhatsApp alert
```

---

## Repository layout

| Path | What it is |
|---|---|
| `main.py` | Synthetic data generator — 8 PHCs × 30 NLEM-2022 medicines × 365 days, TN seasonality |
| `preprocess_vertex.py` | Lag/rolling/seasonal feature engineering → Vertex AutoML training CSV |
| `data/` | `transactions_full.csv`, `vertex_training.csv`, `lag_features.csv`, `inventory_seed.json`, `data_card.md` |
| `functions/` | Cloud Functions: risk scoring, redistribution, alerts, Gemini voice parser |
| `functions/lib/forecastLocal.js` | **On-device gradient-boosted forecaster** (Vertex fallback — demo never blocks on billing) |
| `app/` | Flutter app (web + Android): dashboard, voice input, demo mode |
| `scripts/seed_rtdb.js` | Seeds Firebase RTDB from `inventory_seed.json` |
| `firebase.json` | RTDB rules + functions + hosting config |
| `plan.md` | The 9-day winning plan |

## Quickstart (Day 1 checklist)

### 1. Data — done already ✅
```bash
python main.py                # → data/*.csv + inventory_seed.json (96k events, 4.8k stock-outs)
python preprocess_vertex.py   # → data/vertex_training.csv (AutoML-ready)
```

### 2. Firebase project (15 min)
1. Console: create project **`arogyachain-ai`**
2. Build → **Realtime Database** → Create database (start in test mode, then paste `database.rules.json`)
3. Download service account key → save as `serviceAccountKey.json` (repo root, gitignored)
4. Seed:
```bash
node scripts/seed_rtdb.js
```

### 3. Deploy functions
```bash
npm --prefix functions install
firebase deploy --only functions,database
```
The functions run with **zero Google Cloud setup**: without Vertex config they use the local
gradient-boosted forecaster (`forecastSource: "local-gbm"` in RTDB). To upgrade to Vertex:
```bash
firebase functions:config:set \
  vertex.endpoint="projects/arogyachain-ai/locations/us-central1/endpoints/<ID>" \
  vertex.project="arogyachain-ai"
```
(Gemini voice parsing: set `GEMINI_API_KEY` env on `parseVoiceCommand` — regex fallback works without it.)

### 4. Vertex AI AutoML training (Day 4–5)
1. Console → Vertex AI → Datasets → **Create forecasting dataset** from `data/vertex_training.csv`
   (columns: timestamp, time_series_identifier, quantity_dispensed, day_of_week, month_sin, month_cos)
2. Target = `quantity_dispensed`, horizon = **7 days**, context window = 30+ days
3. Train → deploy endpoint → plug endpoint ID into functions config above

### 5. Run the app
```bash
cd app && flutter pub get
flutter run -d chrome          # demo mode (no Firebase needed — mock data, same UX)
# or with live Firebase: generate firebase_options.dart via flutterfire configure,
# then flip StockBackend(demo: false) in lib/main.dart
```

### 6. Ship the live demo (Day 8)
```bash
cd app && flutter build web && cd ..
firebase deploy --only hosting   # serves app/build/web
```

## The demo story (matches plan.md §5)

1. Open dashboard → **PHC-001** shows Paracetamol at **91% risk** (1.7 days of cover)
2. Tap mic → speak *"Paracetamol fifty"* (or Tamil ஐம்பது) → stock drops, risk climbs to **97%**
3. **Recommended Transfers** card: *"Transfer 750 × Paracetamol_500mg from PHC-005 → PHC-001"*
4. Tap **Approve** → PHC-005 stock decrements, alert written to `alertLog` (WhatsApp in live mode)

## Impact numbers (from data_card.md)

- 96,407 simulated events, 8 PHCs, 30 NLEM medicines, 365 days
- 4,863 stock-out events (**5.6%** of facility-days) — the baseline we forecast against
- Simulated intervention (redistribution matching) targets the **65% stock-out reduction** claim

## Honest-labels (judges care)

- Data is **synthetic**, modeled on NHM/HMIS reporting structure + IDSP seasonality — see `data/data_card.md`
- `local-gbm` fallback is a weighted lag/rolling ensemble (GBM-style stage weights fit during preprocessing);
  Vertex AutoML is the primary forecaster when configured
- Demo mode is clearly labeled in the app bar
