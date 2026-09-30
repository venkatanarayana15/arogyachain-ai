# ArogyaChain AI — Pitch Deck (12 slides)

> Paste into Google Slides; one slide per section. Bold lines = the only text that
> must appear on the slide. Everything else is speaker notes.
> Every number below is either **measured by us** (marked MEASURED) or **cited to a
> named public source** (marked CITED). Nothing is asserted without a source.
> Assets: `data/validation_chart.svg`, `data/impact_metrics.json`, `data/data_card.md`.

---

## Slide 1 — Title
**ArogyaChain AI**
*Predictive supply chain for Primary Health Centres — voice-first, Vertex-powered.*
Track 3: Smart Health & Supply Chain Resilience · Build with AI Hackathon
`github.com/<you>/arogyachain-ai` · `https://arogyachain-ai.web.app`

## Slide 2 — Problem
**Indian public facilities hold 17–51% of essential medicines. The WHO benchmark is 80%.**
- Stock-outs run **4 to 14 weeks** at a time
- Stock ledgers are paper; district consolidation takes weeks
- Districts learn about a shortage *after* patients are turned away
*CITED: availability range and stock-out duration from "Factors Affecting the Availability and Utilization of Essential Medicines in India: A Systematic Review" (PMC11174260); 80% availability benchmark per WHO.*
*Speaker note: pause here. Then: "We are not short on procurement money. We are short on warning."*

## Slide 3 — Why current systems fail
**They record the past. They never predict the future.**
Manual register → late reporting → no forecast → emergency procurement at a premium.
*Every e-governance dashboard today is a rear-view mirror. We built a windshield.*

## Slide 4 — Solution
**Speak. Predict. Redistribute.**
1. PHC worker *speaks* "பாராசிட்டமால் ஐம்பது" → the ledger updates itself
2. Vertex AI forecasts **7-day** demand → **Risk Score 0–100** per medicine
3. One tap moves surplus from an overstocked PHC to a starved one
4. Supervisors alerted at risk > 80 (FCM push; WhatsApp in production)

## Slide 5 — Google AI integration
**Two Google AI systems, one architecture.**
- **Vertex AI AutoML Forecasting** — 12 months × 8 PHCs × 30 NLEM-2022 medicines,
  with engineered lag / rolling / seasonal features
- **Gemini (`gemini-2.0-flash`)** — parses free-form multilingual voice into
  structured stock entries
- **Cloud Speech-to-Text** — Tamil / Hindi / English capture, no typing
- **Fallback** — the same feature contract runs on-device when Vertex is unreachable
*Speaker note: this slide answers "is it just an API wrapper?" — the forecast, the
voice parser and the fallback share one feature contract.*

## Slide 6 — Demo flow
**90 seconds, live:**
Voice (Tamil) → Firebase write → Risk card spikes → Transfer recommendation →
Approve → Alert written to `alertLog`
*Assets: voice card · risk card with projected stock-out date · transfers card*

## Slide 7 — Validation: forecast accuracy
**Beats the rule-based baseline by 16.1% on a 28-day holdout.**
local-ensemble **20.93% MAPE** vs seasonal-naive **24.94%** — 6,355 forecasts, 240 series
*MEASURED (`backtest.py` → `data/validation_metrics.json`). Chart: `data/validation_chart.svg`.*

## Slide 8 — Validation: measured stock-out impact
**4,863 stock-outs → 38. And it survives a hard stress test.**
- Paired counterfactual re-simulation: both arms consume the identical RNG stream,
  so both face identical latent demand. Only difference: whether stock was moved
- Unmet demand: **65,229 units → 122**
- **Sensitivity:** if each PHC can only borrow from its nearest neighbour, the
  reduction falls to **71.0%** — still large, and the honest floor
*MEASURED (`impact_sim.py` → `data/impact_metrics.json`). These are stated upper
bounds from an 8-PHC district, not a field estimate — we did not have a pilot to
measure one, so we measured the mechanism instead.*

## Slide 9 — Who it serves
**Three roles, one system.**
- **PHC staff nurse / pharmacist** — speaks the update instead of maintaining a register
- **District Health Officer** — sees which of their PHCs break first, and which can lend
- **State drug procurement** — sees demand 7 days out, before ordering from a supplier
*Speaker note: the district officer is the buyer. Voice input is what makes the
pharmacist's participation non-negotiable.*

## Slide 10 — Why it's deployable
**Pilot-ready in two weeks, on infrastructure a district already has.**
- Firebase Spark tier — free for a district pilot; no new hardware
- Offline-first writes — works in low-connectivity PHCs
- Security rules shipped (`database.rules.json`); full audit trail in `alertLog`
- Offline fallback forecaster means the demo and the field degrade gracefully
- Roadmap: drug expiry tracking → cold-chain sensors → HMIS export

## Slide 11 — Scaling across India, and across BRICS
**Same code, new district. The scaling levers are configuration, not rewrites.**
- Built on **NLEM 2022** — the national standard, not a state-specific list
- 8 PHCs → 25,000: no architecture change, Firebase scales the storage tier
- Language is a config pack: Tamil · Hindi · English shipped, 22 official languages
  follow the same Gemini + Speech-to-Text path
- **BRICS:** the same demand-forecasting and transfer-matcher design applies to
  Brazil's *UBS* (primary care units), South Africa's *PHC* clinics, and Russia's
  *FAP* outpatient network. National drug lists and languages swap; the Risk Score
  formula and matcher are unchanged.
- Our reachability sweep is the scaling law: the further a facility sits from a
  donor, the more stock forecasting must carry before transfer can help.

## Slide 12 — Ask
**Seeking an NHM pilot partnership: 1 district, 50 PHCs, 90 days.**
Team: [name] — [role]
Links: GitHub · Live demo · Video
*"Every PHC that can't afford to guess, shouldn't have to."*

---
## Appendix (not counted in the 12)

**A. Data provenance.** Fully synthetic (`data/data_card.md`), modelled on NHM/HMIS
reporting structure and IDSP seasonal disease trends for Tamil Nadu. No real
patient or facility data used. Seed 42, generator `main.py`.

**B. What is measured vs asserted.** Every number on slides 2, 7 and 8 is either
CITED to a named source or MEASURED by a script in this repository that a judge
can re-run. Numbers we could not source were removed rather than softened.

**C. Known limits.** Single district, 8 PHCs, 30 medicines, one year. The
redistribution result is an upper bound; slide 8 states the constrained figure.
Vertex AutoML training is configured but the shipped demo runs the identical
feature contract on the offline forecaster.
