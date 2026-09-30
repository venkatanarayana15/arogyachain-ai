# Demo Video Shot List (3:15 target, hard cap 3:30)

**Rule:** record AFTER Firebase go-live (docs/FIREBASE_SETUP.md). If live fails on
recording day, demo-mode takes are pre-approved fallbacks — same script, narrated as
"pre-recorded run". Never debug on camera.

**Numbers rule:** every figure spoken below is read from `data/*.json`. If the
numbers on screen differ from what you say, the video loses credibility. Read the
live values off the screen rather than reciting from memory.

**Setup checklist:** phone on Wi-Fi · Flutter web on laptop + Android device ·
Firebase console open on second display · mic tested · screen recorder at 1080p ·
close all other tabs/windows · notifications off.

| Time | Shot | On screen | Say (verbatim) |
|---|---|---|---|
| 0:00–0:25 | Hook | Deck slide 2 (problem) | "Indian public facilities hold 17 to 51 percent of essential medicines. The WHO benchmark is 80. And stock-outs run four to fourteen weeks at a time. Manual registers mean districts see the shortage after a patient has been turned away. We built ArogyaChain AI: it doesn't just show what we have — it shows what we're about to run out of." |
| 0:25–0:50 | Voice input | Android app, PHC-001 dashboard | "Watch: I speak Tamil —" *say "பாராசிட்டமால் ஐம்பது"* "— and the register updates itself. No typing, no new app for the pharmacist to learn." (show status line "queued to Firebase ✓") |
| 0:50–1:15 | Firebase reveal | Firebase console, `/inventory/PHC-001` | "That voice note just wrote a transaction to Realtime Database — visible live, in the district's language." |
| 1:15–1:45 | **AI reveal** | Risk card: Paracetamol, projected stock-out date | "Vertex AI forecasts the next 7 days from 12 months of engineered lag and seasonal features. This card isn't a threshold rule — it's a forecast: stock-out projected for [read the date off screen]. And when Vertex isn't reachable, the same feature contract runs on-device." |
| 1:45–2:15 | Redistribution | Transfers card, "PHC-005 → PHC-001" | "PHC-005 is holding surplus above its reorder buffer. One tap moves what's surplus to where it's needed — the recommendation is generated automatically from live risk scores." *Read the quantity off screen; do not quote a number.* |
| 2:15–2:35 | Alert | `alertLog` in RTDB console (+ phone push if wired) | "The moment risk crossed 80, the supervisor was alerted — FCM push, WhatsApp optional." |
| 2:35–3:00 | Validation | `data/validation_chart.svg` + `validation_metrics.json` open beside it | "On a 28-day holdout — 6,355 forecasts across 240 series — our ensemble forecaster scores 20.93 percent MAPE against 24.94 for a seasonal-naive baseline. That's a 16.1 percent relative improvement, and it's reproducible with one command." |
| 3:00–3:15 | Measured impact + close | `data/impact_metrics.json` open | "And the impact is measured, not asserted. A paired counterfactual simulation cut stock-outs from 4,863 to 38 in the simulated district. Even when each facility can only borrow from its nearest neighbour, it still holds at 71 percent. That's the number we'd defend. Eight PHCs today; the same project scales to 25,000." |

## Fallback takes (shoot these BEFORE the live takes)

- **Voice fails live?** Take A2: tap mic → recognition runs → manual-entry dialog shown as
  "connectivity dropped" → type "Paracetamol 50" → same downstream shots.
- **Vertex endpoint cold/slow?** Cards show `model: on-device ensemble` — narrate it as
  the edge fallback feature (it genuinely is one). Do **not** claim the Vertex model
  scores better than the measured number; it is not evaluated in this build.
- **Firebase console laggy?** Pre-record the console segment separately and cut it in.
- **App won't load at all?** Show `docs/assets/app_dashboard.png` and narrate the
  recorded pre-production run. Still better than a broken live demo.

## Do not say

- ❌ "AutoML improves on that further" — the Vertex model is **not** evaluated in this
  build. The 20.93% figure belongs to the on-device ensemble only.
- ❌ "30-day advance warning" — the horizon is **7 days**, everywhere.
- ❌ "65% fewer stock-outs" — never measured. Use 71% (the conservative floor).
- ❌ Any transfer quantity recited from memory — read it off screen.

## Post-production checklist

- [ ] Captions burned in (many judges watch muted)
- [ ] First 8 seconds re-checked: hook line audible over slide
- [ ] Zoom region held on the risk card for the full AI-reveal beat (slowest zoom of the video)
- [ ] Every spoken number cross-checked against what is on screen at that timestamp
- [ ] YouTube **unlisted**, title `ArogyaChain AI — Build with AI Hackathon (Track 3)`
- [ ] Chapter timestamps in description matching the table above
