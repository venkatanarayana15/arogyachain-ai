# ArogyaChain AI — Data Card

**Provenance:** Fully synthetic. Consumption patterns modeled on public
NHM/HMIS reporting structures and IDSP seasonal disease trends for Tamil Nadu
(NE monsoon vector-borne peak Oct-Dec; winter ARI peak Dec-Jan). No real
patient or facility data used.

**Generated:** 2026-09-21 (seed=42)
**Facilities:** 8 PHCs in Thiruvallur district, with heterogeneous
restock cadences (7/10/14/21 days) and procurement efficiency factors to
produce realistic imbalances.

**Scale:** 365 days x 8 PHCs x 30 NLEM-2022 medicines
= 87600 series, 96,407 events
(83,626 dispense, 4,863 stock-out events).

**Known uses:** Vertex AI AutoML Forecasting training (7-day horizon),
Firebase seeding, dashboard demo.
