# ArogyaChain AI — Build Plan & Final Status

**Track:** 3 — Smart Health & Supply Chain Resilience · Build with AI Hackathon
**Build window:** Sep 21 – Sep 30, 2026 (9-day sprint)
**Status:** Prototype complete. Remaining work is packaging and recording.

---

## 1. Where this landed

We chose Track 3 because it maximises the two heaviest criteria at once —
**AI/Technical Execution (25%)** and **Deployability (20%)** — without needing hardware,
government API access, or rare-event simulation. The thesis:

> Districts do not fail because they lack money. They fail because they learn about a
> shortage after a patient has been turned away. We show the shortage **before** it happens.

## 2. What was built

| Layer | Component | Google technology |
|---|---|---|
| Capture | Voice stock updates, Tamil/Hindi/English | Cloud Speech-to-Text |
| Parse | Free-form speech → structured entry | Gemini API (`gemini-2.0-flash`) |
| Predict | 7-day demand per medicine per PHC | Vertex AI AutoML forecasting |
| Fallback | Same feature contract, on-device | — (offline resilience) |
| Score | 0–100 stock-out Risk Score | Cloud Functions |
| Act | Cross-PHC transfer matcher | Cloud Functions |
| Alert | Supervisor notification | FCM (demo) / WhatsApp (production) |
| Store | Real-time inventory + audit trail | Firebase Realtime Database |

**Google AI is in the shipped code, not just the pitch** — `functions/lib/vertexClient.js`
calls `aiplatform.googleapis.com`, `functions/lib/voiceParser.js` calls
`generativelanguage.googleapis.com`. Rule 01 is satisfied in the repository.

## 3. Evidence

| Claim | Status | Reproduce with |
|---|---|---|
| Forecast beats a seasonal-naive baseline by 16.1% (20.93% vs 24.94% MAPE) | **MEASURED** — 28-day holdout, 240 series, 6,355 forecasts | `python backtest.py` |
| Stock-outs fall 4,863 → 38 | **MEASURED** — paired counterfactual re-simulation | `python impact_sim.py` |
| Unmet demand falls 65,229 → 122 units | **MEASURED** | `python impact_sim.py` |
| Reduction holds at 71% when each PHC can only borrow from its nearest neighbour | **MEASURED** — reachability sweep | `python impact_sim.py` |
| Essential medicine availability 17–51% vs 80% WHO benchmark; stock-outs 4–14 weeks | **CITED** — PMC11174260 systematic review | deck slide 2 |
| Data is synthetic, modelled on NHM/HMIS + IDSP | **LABELLED** | `data/data_card.md` |

**Three E2E suites, all offline, no cloud account needed:**
`python test_pipeline_e2e.py` · `cd functions && npm test` · `cd app && flutter test`

The Functions harness earned its keep: it caught a real bug where the RTDB trigger path
passed a partial inventory object to the forecaster, silently zeroing every forecast.
Fixed and regression-tested as scenario 1.

## 4. Integrity rules we held

- Every deck number is CITED or MEASURED. Two claims that could not be sourced were
  **removed, not softened**: a mortality statistic attributed to WHO that we could not
  find in any WHO publication, and a "30-day advance warning" claim that contradicted
  the 7-day horizon the model actually runs.
- The stock-out reduction was originally asserted as 65%. It is now measured, and the
  headline figure is the **conservative 71% floor**, not the 99% upper bound.
- Vertex AutoML training is configured but the shipped demo runs the identical feature
  contract on the offline forecaster. We say so rather than implying a trained endpoint
  is serving the demo.

## 5. Remaining work

| # | Task | Blocked on | Status |
|---|---|---|---|
| 1 | Verify deployed link in incognito | Firebase deploy | ☐ |
| 2 | Record demo video (3–5 min) | Task 1 | ☐ |
| 3 | Build pitch deck from `deck.md` | — | ☐ |
| 4 | Submit brief description | — | ☐ (`docs/BRIEF_DESCRIPTION.md` ready) |
| 5 | Push to public GitHub | — | ☐ |

Recording order is fixed: **fix copy → deploy → record → re-export.**
See `docs/RECORDLY_RUNBOOK.md` for the capture plan and `docs/DEMO_VIDEO_SHOTLIST.md`
for the beat-by-beat script.

## 6. Known limits (state these if asked)

- One district, 8 PHCs, 30 NLEM medicines, one year of synthetic data
- The redistribution result is an **upper bound**; the 71% figure is the honest floor
- No real PHC user has tested it — problem validation is a stated next step, not a claim
- BRICS applicability is a design argument plus the reachability sweep, not a deployment
