# Preview & Test Guide

Four independent layers. Each one runs offline — no cloud account, no billing,
no Java. Run them in order; each catches a class of failure the next one cannot.

---

## Layer 1 — Data pipeline (no dependencies)

```bash
python main.py               # → 8 PHCs x 30 NLEM meds x 365 days, 96k events
python preprocess_vertex.py  # → AutoML-ready training table + lag features
python backtest.py           # → MAPE vs baseline, chart SVG
python impact_sim.py         # → counterfactual stock-out reduction  (~6 min)
```

Each writes to `data/` and prints a summary. `impact_sim.py` takes the longest
because it runs five full-year re-simulations — that is expected, not a hang.

**Look for:** `4863 → 38` and the reach sweep `71.0 / 99.1 / 99.1 / 99.2`.

---

## Layer 2 — Cloud Functions logic (no cloud account)

This is the important one: it runs the **real `index.js`** against a fake RTDB,
so it verifies your risk formula, matcher, and Gemini voice parser without
deploying anything.

```bash
npm --prefix functions install     # once
npm --prefix functions test
```

Expected: `8 passed, 0 failed`, including
- trigger updates stock/history/risk
- risk >= 80 fires FCM + writes alertLog
- `recommendTransfer` produces PHC-005 → PHC-001
- Tamil voice parse → dispense transaction

---

## Layer 3 — The app (visual)

Fastest iteration, with hot reload:

```bash
cd app
flutter run -d chrome
```

Or test the exact release artefact you'll deploy:

```bash
flutter build web --release
cd ..
python -m http.server 8765 --directory app/build/web
# open http://localhost:8765
```

**Demo mode toggle** — no code edit needed:

```bash
flutter run -d chrome --dart-define=DEMO=false   # attempt live Firebase
flutter run -d chrome --dart-define=DEMO=true    # force demo (default)
```

### The four things to check by eye

| Check | Expected |
|---|---|
| Header badge | `DEMO MODE` visible — honesty, not a bug |
| Risk cards | Paracetamol ~91%, Amoxicillin ~96%, ORS ~8% |
| Manual entry | Type `Paracetamol 50`, press `+` → risk climbs, transfer recommendation appears |
| Approve button | Stock moves, donor PHC decrements |

If any card shows `on-device GBM`, you have a stale build — run `flutter clean`.

---

## Layer 4 — Submission artefacts

```bash
python build_deck.py       # → docs/ArogyaChainAI_Deck.pdf
```

Then open `docs/ArogyaChainAI_Deck.pdf` (12 pages) and
`docs/assets/app_dashboard.png`.

The builder **fails loudly** if a metric is missing or renamed — it reads every
figure from `data/*.json` at build time, so the deck cannot show a stale number.
If it raises `KeyError`, regenerate the JSON above first.

---

## Everything at once

```bash
python test_pipeline_e2e.py    # 8 checks, regenerates data in a temp dir
npm --prefix functions test    # 8 checks
cd app && flutter test && cd .. # 3 checks
```
**19 checks total.**

---

## What you cannot test locally

| Blocked by | Workaround |
|---|---|
| Firebase RTDB / FCM | Functions E2E uses a fake RTDB — logic covered, transport not |
| Vertex AI endpoint | Requires a real trained model + billing. The app's offline ensemble is what the demo shows. |
| Gemini API | Set `GEMINI_API_KEY`; without it `parseVoiceCommand` falls back to regex. |
| Speech-to-Text | Needs a real microphone — Chrome prompts on first click. |
| Firebase emulators | **No Java on this machine.** That is why Layer 2 uses a fake RTDB instead. |

---

## Before you record the video

1. `flutter build web --release` and confirm the release build loads
2. Read the actual numbers off screen — the shot list forbids reciting from memory
3. Record the fallback takes **first** (manual entry, demo mode)
4. Check `docs/DEMO_VIDEO_SHOTLIST.md` § "Do not say" — four claims must not be spoken
