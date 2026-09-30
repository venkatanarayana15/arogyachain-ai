# SUBMISSION — Brief Description (2–3 lines)

> Copy exactly this into the submission portal's "brief description" field.

---

ArogyaChain AI is a voice-first, AI-predictive medicine supply chain for India's Primary Health Centres: a pharmacist speaks a stock update in Tamil, Hindi or English, Vertex AI forecasts 7-day demand and returns a 0–100 stock-out Risk Score, and a matcher recommends which nearby PHC can lend the shortfall before patients are turned away. It runs on Firebase and Google AI with an offline fallback, is built on the NLEM 2022 national standard, and was validated on a 28-day holdout (20.9% MAPE vs 24.9% for a seasonal-naive baseline) plus a paired counterfactual simulation that cut stock-outs from 4,863 to 38 in the simulated district.

---

## Shorter variant (if the field is tight)

Voice-first predictive supply chain for India's Primary Health Centres. A pharmacist speaks a stock update in Tamil, Hindi or English; Vertex AI forecasts 7-day demand and flags stock-out risk; a matcher moves surplus between PHCs before patients are turned away. Built on Firebase + Google AI, on the NLEM 2022 national standard, and deployable to a district in two weeks.

---

## Longer variant (for social posts / README header)

ArogyaChain AI turns India's PHC medicine supply chain from a paper register into a live prediction. A pharmacist speaks the update — "பாராசிட்டமால் ஐம்பது" — and the ledger writes itself. Vertex AI forecasts the next 7 days of demand per medicine per facility and returns a stock-out Risk Score; when risk crosses 70, the engine matches the deficit to a nearby PHC holding surplus above its reorder buffer and recommends the transfer. District officers see which of their facilities break first and which can lend. Built for Tamil, Hindi and English, on the NLEM 2022 national drug standard, so the same deployment scales from our 8-facility pilot district to all ~25,000 PHCs in India — and the same forecasting and matching design transfers to Brazil's UBS, South Africa's PHC clinics and Russia's outpatient network.
