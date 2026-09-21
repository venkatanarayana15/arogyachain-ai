# Firebase Go-Live — Exact Steps (≈45 min)

Every command assumes repo root. Do these **in order**. Nothing here needs a credit card
(Blaze plan is only required for Vertex training; everything else runs on Spark).

## A. Create the project (console, 10 min)

1. https://console.firebase.google.com → **Add project**
2. Name: `arogyachain-ai` → (Analytics: disable) → Create
3. Build → **Realtime Database** → Create Database → location `us-central1` → **Start in test mode**
4. Rules tab → replace contents with `database.rules.json` from this repo → Publish
5. Project settings → Service accounts → **Generate new private key** → save as
   `serviceAccountKey.json` in repo root (already gitignored)

## B. Seed the database (2 min)

```bash
node scripts/seed_rtdb.js          # loads 8 PHCs × 30 medicines with history14
```
Verify in console: `/inventory/PHC-001/medicines/Paracetamol_500mg` exists with `stock`.

## C. Deploy Cloud Functions (5 min)

```bash
npm install -g firebase-tools      # one-time (not currently installed on this machine)
firebase login
npm --prefix functions install
firebase deploy --only functions,database --project arogyachain-ai
```
> First deploy asks to enable required APIs — answer yes.
> After deploy, `computeAllRisks` fills `/riskScores` within 30 min. To trigger sooner:
> write any transaction from the app, or temporarily raise schedule to `every 5 minutes`.

## D. Wire the app live (10 min)

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=arogyachain-ai \
  --platforms=web,android --out=lib/firebase_options.dart
```
Then in `app/lib/main.dart` change one line:
```dart
backend = StockBackend(demo: true);   →   backend = StockBackend(demo: false);
```
```bash
cd app && flutter run -d chrome
```
Voice-dispense "Paracetamol 50" → watch `/transactions/PHC-001` appear in console →
`/riskScores/PHC-001/Paracetamol_500mg` updates (trigger fires `scoreAndMaybeAlert`).

## E. Vertex AI AutoML Forecasting (Day 4–5, needs Blaze)

1. Console → Vertex AI → **Datasets** → Create → *Forecasting*
   - CSV: upload `data/vertex_training.csv` from this repo
   - Column spec: timestamp = `timestamp`, series ID = `time_series_identifier`,
     target = `quantity_dispensed`; covariates `day_of_week`, `month_sin`, `month_cos` (optional)
2. Train new model:
   - **Horizon = 7 days**, context window = 30+ days
   - Budget: 2–4 GPU-hours is plenty for this corpus (~80k rows)
3. When training finishes (1–4 h): **Deploy to endpoint** (`us-central1`, 1 node, machine type default)
4. Copy the endpoint resource name and:
```bash
firebase functions:config:set \
  vertex.endpoint="projects/arogyachain-ai/locations/us-central1/endpoints/<ENDPOINT_ID>" \
  vertex.project="arogyachain-ai"
firebase deploy --only functions
```
Risk cards in the app will now show `model: Vertex AI AutoML`.

## F. Ship the public demo (Day 8, 10 min)

```bash
cd app && flutter build web && cd ..
firebase deploy --only hosting
# → https://arogyachain-ai.web.app  (submit this link)
```

## G. Optional garnish

- **Gemini voice parsing:** Cloud Console → APIs & Services → Enable *Generative Language API*,
  create API key, then `npx firebase-tools functions:config:set gemini.key="..."` and read via
  `functions.config().gemini.key` (wire into `voiceParser.js` — regex fallback already works).
- **WhatsApp:** Meta Cloud API token + phone ID → `functions:config:set whatsapp.enabled="true" whatsapp.token="..." whatsapp.phoneId="..." whatsapp.to="91XXXXXXXXXX"`
- **FCM push:** topic subscription client-side (`alerts-PHC-001`); alerts.js already publishes.

## H. Emulator sanity test (no cloud account needed)

```bash
firebase emulators:start --only functions,database
# in another terminal:
curl -X POST http://localhost:5001/arogyachain-ai/us-central1/parseVoiceCommand \
  -H "Content-Type: application/json" -d '{"text":"Paracetamol 50","phcId":"PHC-001"}'
# expect: {"ok":true,"medicineKey":"Paracetamol_500mg","quantity":50,...}
```
