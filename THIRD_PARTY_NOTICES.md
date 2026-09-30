# THIRD-PARTY NOTICES

ArogyaChain AI · Build with AI Hackathon · Track 3

Per Rule 03 — *"All code must be original or built on properly licensed
open-source components — cite anything you reuse."*

## Original work

All application logic in this repository is original and was written during the
hackathon period (Aug 11 – Sep 30, 2026):

| Component | File | Status |
|---|---|---|
| Synthetic data generator | `main.py` | Original |
| Vertex feature engineering | `preprocess_vertex.py` | Original |
| Forecast validation harness | `backtest.py` | Original |
| Counterfactual impact simulation | `impact_sim.py` | Original |
| Cloud Functions entry + risk scorer | `functions/index.js` | Original |
| Vertex AI REST client | `functions/lib/vertexClient.js` | Original |
| Gemini voice parser | `functions/lib/voiceParser.js` | Original |
| Transfer matcher | `functions/lib/redistribution.js` | Original |
| On-device forecaster | `functions/lib/forecastLocal.js` | Original |
| Alert dispatch | `functions/lib/alerts.js` | Original |
| E2E suites | `test_pipeline_e2e.py`, `functions/test/e2e.js`, `app/test/*.dart` | Original |
| Flutter application | `app/lib/*.dart` | Original |
| RTDB seed tooling | `scripts/seed_rtdb.js` | Original |

**Porting note:** `functions/lib/forecastLocal.js` and `forecast_local()` in
`backtest.py` are deliberate cross-language ports of the *same* algorithm, so the
shipped runtime and the published validation numbers cannot drift apart. They are
two implementations of our own algorithm, not third-party code.

## Third-party dependencies

Runtime dependencies, each under a permissive licence. No source was copied.

| Dependency | Licence | Used for |
|---|---|---|
| Flutter SDK | BSD-3-Clause | Application framework |
| `firebase_core`, `firebase_database` | BSD-3-Clause | RTDB client |
| `speech_to_text` | BSD-3-Clause | Google Cloud Speech-to-Text wrapper |
| `firebase-admin` (Node) | Apache-2.0 | RTDB admin access in Cloud Functions |
| `firebase-functions` (Node) | Apache-2.0 | Cloud Functions framework |
| `google-auth-library` (Node) | Apache-2.0 | Vertex AI authentication |
| `googleapis` (Node) | Apache-2.0 | Vertex AI REST transport |
| Python stdlib (`random`, `csv`, `json`, `datetime`) | PSF | Data generation + validation |
| `matplotlib` (optional) | PSF-based | PNG chart export only |

Attribution files shipped by dependencies remain in their own packages and in
`app/build/web/NOTICES`, as their licences require.

## External services (no code imported)

- **Google Vertex AI** — `aiplatform.googleapis.com`, forecast endpoint
- **Google Gemini API** — `generativelanguage.googleapis.com`, model `gemini-2.0-flash`
- **Google Cloud Speech-to-Text** — via the `speech_to_text` plugin
- **Firebase Realtime Database** — prototype data store

## Data sources

No third-party dataset files are vendored into this repository. `main.py`
*synthesises* its corpus rather than copying one. The structure is informed by
public reporting formats and the problem framing is cited from:

- "Factors Affecting the Availability and Utilization of Essential Medicines in
  India: A Systematic Review" — PMC11174260 (availability range 17–51%, stock-out
  duration 4–14 weeks)
- WHO availability benchmark for essential medicines (80%)

NLEM 2022 medicine names are used as identifiers; the lists themselves are
published by the Government of India and are not redistributed here.

## Assets

- Icons and fonts are Flutter defaults (Material Icons, Roboto), Apache-2.0 /
  Apache-2.0 with OFL respectively, redistributed by the Flutter SDK.
- No stock photography, no third-party video or music is used in the demo.
- Screen recording is captured with Recordly (AGPL-3.0) as a local tool; the
  resulting video is our own work and no Recordly code is included in this
  repository.
