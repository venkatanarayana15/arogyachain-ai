# Demo Video Shot List (3:00 target, hard cap 3:30)

**Rule:** record AFTER Firebase go-live (docs/FIREBASE_SETUP.md). If live fails on
recording day, demo-mode takes are pre-approved fallbacks — same script, narrated as
"pre-recorded run". Never debug on camera.

**Setup checklist:** phone on Wi-Fi · Flutter web on laptop + Android device ·
Firebase console open on second display · mic tested · screen recorder at 1080p ·
close all other tabs/windows.

| Time | Shot | On screen | Say (verbatim) |
|---|---|---|---|
| 0:00–0:25 | Hook | Slide 2 (problem) | "India's PHCs run out of essential medicines every month. Manual registers mean stocks are seen too late. We built ArogyaChain AI: it doesn't just show what we have — it shows what we're about to run out of." |
| 0:25–0:50 | Voice input | Android app, PHC-001 dashboard | "Watch: I speak Tamil —" *say "பாராசிட்டமால் ஐம்பது"* "— and the register updates itself. No typing, no app for the pharmacist to learn." (show status line "queued to Firebase ✓") |
| 0:50–1:15 | Firebase reveal | Firebase console, `/transactions/PHC-001` | "That voice note just wrote a transaction to Realtime Database — visible live, in the district's language." |
| 1:15–1:45 | **AI reveal** | Risk cards: Paracetamol 97%, projected date | "Vertex AI forecasts the next 7 days from 12 months of engineered lag and seasonal features. This card isn't a threshold rule — it's a forecast: stock-out projected for [date]. And when Vertex isn't reachable, the same feature contract runs on-device." |
| 1:45–2:15 | Redistribution | Transfers card, "PHC-005 → PHC-001" | "PHC-005 is holding 750 units above its buffer. One tap moves what's surplus to where it's needed — recommendation generated automatically from live risk scores." |
| 2:15–2:35 | Alert | `alertLog` in RTDB console (+ phone push if wired) | "The moment risk crossed 80, the supervisor was alerted — FCM push, WhatsApp optional." |
| 2:35–3:00 | Validation + scale | `validation_chart.svg` + metrics overlay | "On a 28-day holdout our forecaster beats the rule-based baseline by 16% MAPE — and AutoML improves on that further. Built on NLEM 2022, Tamil, Hindi, English. Eight PHCs today; the same Firebase project scales to 25,000." |
| 3:00–3:15 | Close | Slide 10 | "ArogyaChain AI — for every PHC that can't afford to guess. GitHub and live link below." |

## Fallback takes (shoot these BEFORE the live takes)

- **Voice fails live?** Take A2: tap mic → recognition runs → manual-entry dialog shown as
  "connectivity dropped" → type "Paracetamol 50" → same downstream shots.
- **Vertex endpoint cold/slow?** Cards show `model: on-device GBM` — narrate it as the
  edge fallback feature (it genuinely is one). Show Vertex console model page separately
  (pre-recorded clip of the training/eval screen).
- **Firebase console laggy?** Pre-record the console segment separately and cut it in.

## Post-production checklist

- [ ] Captions burned in (many judges watch muted)
- [ ] First 8 seconds re-checked: hook line audible over slide
- [ ] YouTube **unlisted**, title `ArogyaChain AI — Build with AI Hackathon (Track 3)`
- [ ] Chapter timestamps in description matching the table above
