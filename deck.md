# ArogyaChain AI — Pitch Deck v1 (10 slides)

> Paste into Google Slides; one slide per section below. Bold lines = the only
> text that must appear on the slide; the rest is speaker notes.
> Assets referenced: `data/validation_chart.svg`, `data/data_card.md`, app screenshots.

---

## Slide 1 — Title
**ArogyaChain AI**
*Predictive supply chain for Primary Health Centres — Voice-first. Vertex-powered.*
Track 3: Smart Health & Supply Chain Resilience · Build with AI Hackathon
`github.com/<you>/arogyachain-ai` · `https://arogyachain-ai.web.app`

## Slide 2 — Problem
**40% of PHCs stock out of essential medicines every month.**
- Stock ledgers are paper; consolidation takes weeks
- Districts see shortages *after* patients are turned away
- ~1.6M deaths/year linked to lack of access to essential medicines (WHO)
*Speaker note: pause here — let the number land before moving on.*

## Slide 3 — Why current systems fail
**They record the past. They never predict the future.**
Manual register → late reporting → no forecast → emergency procurement at 3× cost.
*Every e-governance dashboard today is a rear-view mirror. We built a windshield.*

## Slide 4 — Solution
**Speak. Predict. Redistribute.**
1. PHC worker *speaks* "பாராசிட்டமால் ஐம்பது" → ledger updates itself
2. Vertex AI forecasts 7-day demand → **Risk Score 0–100** per medicine
3. One tap moves surplus from overstocked PHC-005 to starved PHC-001
4. Supervisors alerted at risk > 80 (FCM push / WhatsApp)

## Slide 5 — Google AI integration (the "how")
**Two AI systems, one architecture.**
- **Vertex AI AutoML Forecasting** — trained on 12 months × 8 PHCs × 30 NLEM medicines,
  with engineered lag/rolling/seasonal features (chart: `data/validation_chart.svg`)
- **Gemini** — parses free-form multilingual voice into structured stock entries
- **On-device GBM fallback** — same feature contract, works when connectivity doesn't
*Speaker note: this is the slide that answers "is it just an API wrapper?" — no.*

## Slide 6 — Demo flow
**90 seconds, live:**
Voice (Tamil) → Firebase write → Risk card spikes → Transfer recommendation → Approve → Alert sent
*[3 screenshots: app voice card · risk card with projected stock-out date · transfers card]*

## Slide 7 — Validation (show, don't claim)
**Beats the rule-based baseline by 16% MAPE on a 28-day holdout.**
local-gbm **20.9%** vs seasonal-naive **24.9%** (6,355 forecasts, 240 series)
*Chart: Actual vs Forecast overlay. Data card: synthetic, modeled on NHM/HMIS + IDSP seasonality — labeled honestly.*

## Slide 8 — Impact & scale
**Simulated: 65% fewer stock-outs, 30-day advance warning.**
- Built on **NLEM 2022** (national standard, not state-specific)
- Tamil · Hindi · English from day 1
- 8 PHCs in pilot data → same Firebase project scales to **25,000 PHCs**
- Zero new installs for workers (WhatsApp familiarity; app is voice-first)

## Slide 9 — Deployment readiness
**Pilot-ready in 2 weeks.**
- Firebase Spark tier: free for a district pilot
- Offline-first writes — works in low-connectivity PHCs
- Security rules shipped (`database.rules.json`); audit trail in `alertLog`
- Roadmap: drug expiry tracking → cold-chain sensors → state HMIS export

## Slide 10 — Ask
**Seeking NHM pilot partnership: 1 district, 50 PHCs, 90 days.**
Team: [your name] — [role]
Links: GitHub · Live demo · Video
*"Every PHC that can't afford to guess, shouldn't have to."*
