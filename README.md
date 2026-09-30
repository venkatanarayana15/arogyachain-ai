# 🏆 ArogyaChain AI

**Track 3 — Smart Health & Supply Chain Resilience** · Built for the 9-day sprint (Sep 21–30, 2026)

Voice-first, AI-predictive medicine supply chain for Primary Health Centres (PHCs).
Workers **speak** stock updates in Tamil/Hindi/English → **Vertex AI forecasts** stock-out risk →
**one-click redistribution** moves surplus from overstocked PHCs to starved ones → alerts fire.

```
Voice ("பாராசிட்டமால் ஐம்பது") → Firebase RTDB → Cloud Function → Vertex AI / on-device ensemble
     → Risk Score (0-100) → Dashboard → Transfer Recommendation → FCM/WhatsApp alert
```

---

## Repository layout

| Path | What it is |
|---|---|
| `main.py` | Synthetic data generator — 8 PHCs × 30 NLEM-2022 medicines × 365 days, TN seasonality |
| `preprocess_vertex.py` | Lag/rolling/seasonal feature engineering → Vertex AutoML training CSV |
| `backtest.py` | 28-day holdout validation: MAPE vs a seasonal-naive baseline → forecast accuracy |
| `impact_sim.py` | Paired counterfactual re-simulation → **measured** stock-out reduction + reachability sweep |
| `data/` | `transactions_full.csv`, `vertex_training.csv`, `lag_features.csv`, `inventory_seed.json`, `data_card.md`, `validation_metrics.json`, `impact_metrics.json`, `validation_chart.svg` |
| `functions/` | Cloud Functions: risk scoring, redistribution, alerts, Gemini voice parser |
| `functions/lib/forecastLocal.js` | **On-device forecaster (weighted lag ensemble)** (Vertex fallback — demo never blocks on billing) |
| `app/` | Flutter app (web + Android): dashboard, voice input, demo mode |
| `scripts/seed_rtdb.js` | Seeds Firebase RTDB from `inventory_seed.json` |
| `firebase.json` | RTDB rules + functions + hosting config |
| `deck.md` | Pitch deck, 12 slides |
| `THIRD_PARTY_NOTICES.md` | Rule 03 open-source citations |
| `docs/` | `DEMO_VIDEO_SHOTLIST.md`, `RECORDLY_RUNBOOK.md`, `BRIEF_DESCRIPTION.md`, `FIREBASE_SETUP.md` |
| `plan.md` | Build plan and final status |

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
weighted-ensemble forecaster (`forecastSource: "local-ensemble"` in RTDB). To upgrade to Vertex:
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

> The shipped demo runs the **same feature contract** on the offline forecaster, so the
> demo never depends on billing being active. Turn on Vertex when you want the real thing.

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

## Tests — three end-to-end suites

```bash
python test_pipeline_e2e.py        # data pipeline: 7 scenarios (schema, keys, consistency, backtest claim)
cd functions && npm test           # Cloud Functions E2E: 8 scenarios (trigger, scheduled, all 3 HTTPS flows)
cd app && flutter test             # UI E2E: full demo story through the real widgets
```
All suites run offline with no cloud account. The Functions harness loads the real
`index.js` against a fake RTDB and **caught a real bug** during development: the
trigger path originally passed a partial inventory object to the forecaster,
silently zeroing every forecast (fixed; regression-tested by scenario 1).

## Impact numbers — all measured, all re-runnable

### Forecast accuracy (`python backtest.py`)
- 28-day holdout, 240 series, 6,355 forecasts
- local-ensemble **20.93% MAPE** vs seasonal-naive **24.94%** — a **16.1%** relative improvement
- → `data/validation_metrics.json`, `data/validation_chart.svg`

### Stock-out impact (`python impact_sim.py`)
Paired counterfactual re-simulation. Both arms consume the same RNG stream in the
same order (every draw in `main.py` is gated on a calendar condition, not on
stock), so both arms face identical latent demand — the only difference is whether
the redistribution matcher moved stock.

| Metric | Baseline | Intervention |
|---|---|---|
| Stock-out events (full year) | 4,863 | 38 |
| Stock-out events (28-day holdout) | 440 | 11 |
| Unmet demand (units) | 65,229 | 122 |

**Sensitivity to geographic reach** — an 8-PHC district is fully connected, so the
headline figure is an *upper bound*:

| Donor reach | Stock-out reduction | Unmet-demand reduction |
|---|---|---|
| Nearest neighbour only | **71.0%** | 71.2% |
| Within 2 PHCs | 99.1% | 99.8% |
| Any PHC in district | 99.2% | 99.8% |

We quote the 71% floor in the deck. These are simulation results on synthetic
data, not field measurements — we had no pilot to measure against, so we measured
the mechanism instead and reported where it breaks down.

## Honest labels (judges care)

- Data is **synthetic**, modeled on NHM/HMIS reporting structure + IDSP seasonality — see `data/data_card.md`
- `local-ensemble` is a weighted lag/rolling ensemble (fixed stage weights set from feature-lag design, not fitted);
  Vertex AutoML is the primary forecaster when configured
- Demo mode is clearly labeled in the app bar
- Every number in the deck is either CITED to a named source or MEASURED by a
  script in this repo. Claims we could not source were removed, not softened.

## Compliance

- **Rule 01 (Google AI):** `functions/lib/vertexClient.js` → `aiplatform.googleapis.com`;
  `functions/lib/voiceParser.js` → `generativelanguage.googleapis.com` (`gemini-2.0-flash`);
  `app/pubspec.yaml` → `speech_to_text`. Google AI is in the shipped code, not just the pitch.
- **Rule 02 (built in-period):** see `git log` — three commits, 2026-09-21.
- **Rule 03 (open-source citations):** see `THIRD_PARTY_NOTICES.md`.
- **Rule 04 (cross-border):** BRICS deployment path is addressed on deck slide 11 and
  quantified by the reachability sweep above.
