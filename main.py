#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ArogyaChain AI — Synthetic Data Generator (Day 1, Asset 1)
==========================================================
Simulates 12 months of medicine consumption across 8 Primary Health Centres (PHCs)
in Tamil Nadu, grounded in:
  * NLEM 2022 (National List of Essential Medicines) therapeutic categories
  * IDSP-style Tamil Nadu seasonality (monsoon -> vector-borne spike, winter -> ARI)
  * PHC scale (30-50 bed facilities serving ~30k people each)

Outputs (data/):
  transactions_full.csv   -> 12 months of daily stock movements (dispense/restock/expiry)
  transactions_vertex.csv -> Vertex AI AutoML Forecasting format (flat, pre-lag)
  inventory_seed.json     -> current snapshot to seed Firebase Realtime DB
  data_card.md            -> provenance note for judges ("synthetic, modeled on NHM/HMIS")

Usage:
  python main.py                     # default: 8 PHCs, 365 days, seed 42
  python main.py --phcs 12 --days 400 --seed 7
"""

import argparse
import csv
import json
import os
import random
from datetime import date, timedelta

# --------------------------------------------------------------------------
# NLEM 2022 subset (30 representative medicines across therapeutic areas).
# Real deployment: swap this list for the full 150-drug NLEM CSV.
# --------------------------------------------------------------------------
NLEM_MEDICINES = [
    # (name, form, strength, category, unit_size)
    ("Paracetamol",        "Tablet",    "500mg",  "Analgesic-Antipyretic",   100),
    ("Diclofenac",         "Tablet",    "50mg",   "Analgesic-Antipyretic",   100),
    ("Ibuprofen",          "Tablet",    "400mg",  "Analgesic-Antipyretic",   100),
    ("Amoxicillin",        "Capsule",   "500mg",  "Antibiotic",              100),
    ("Azithromycin",       "Tablet",    "500mg",  "Antibiotic",              100),
    ("Ciprofloxacin",      "Tablet",    "500mg",  "Antibiotic",              100),
    ("Doxycycline",        "Capsule",   "100mg",  "Antibiotic",              100),
    ("Cefixime",           "Tablet",    "200mg",  "Antibiotic",              100),
    ("Metronidazole",      "Tablet",    "400mg",  "Antibiotic",              100),
    ("ORS",                "Sachet",    "Low-Osmolarity", "Rehydration",     100),
    ("Zinc Sulphate",      "Tablet",    "20mg",   "Rehydration",             100),
    ("Ondansetron",        "Tablet",    "4mg",    "Antiemetic",              100),
    ("Ranitidine",         "Tablet",    "150mg",  "Gastrointestinal",        100),
    ("Omeprazole",         "Capsule",   "20mg",   "Gastrointestinal",        100),
    ("Metformin",          "Tablet",    "500mg",  "Endocrine",               100),
    ("Glibenclamide",      "Tablet",    "5mg",    "Endocrine",               100),
    ("Insulin (Soluble)",  "Injection", "100IU/ml", "Endocrine",             100),
    ("Amlodipine",         "Tablet",    "5mg",    "Cardiovascular",          100),
    ("Atenolol",           "Tablet",    "50mg",   "Cardiovascular",          100),
    ("Enalapril",          "Tablet",    "5mg",    "Cardiovascular",          100),
    ("Frusemide",          "Tablet",    "40mg",   "Cardiovascular",          240),
    ("Salbutamol",         "Inhaler",   "100mcg", "Respiratory",             200),
    ("Salbutamol",         "Tablet",    "4mg",    "Respiratory",             100),
    ("Prednisolone",       "Tablet",    "5mg",    "Respiratory",             100),
    ("Chlorpheniramine",   "Tablet",    "4mg",    "Antihistamine",           100),
    ("Cetirizine",         "Tablet",    "10mg",   "Antihistamine",           100),
    ("Ferrous Sulphate",   "Tablet",    "60mg",   "Haematinic",              100),
    ("Folic Acid",         "Tablet",    "0.4mg",  "Haematinic",              100),
    ("Vitamin A",          "Capsule",   "200kIU", "Vitamin",                 100),
    ("Artemether-Lumefantrine", "Tablet", "20/120mg", "Antimalarial",        240),
]

# Tamil Nadu IDSP-style seasonality multipliers per month (1.0 = baseline demand).
# Peaks: NE monsoon (Oct-Dec) -> malaria/dengue/fever -> antimalarials, ORS, antibiotics
#        winter (Dec-Jan)      -> ARI -> salbutamol, prednisolone, antibiotics
SEASONALITY = {
    "Analgesic-Antipyretic": {1: 0.95, 2: 0.95, 3: 1.00, 4: 1.10, 5: 1.20, 6: 1.10,
                              7: 1.00, 8: 1.05, 9: 1.10, 10: 1.35, 11: 1.45, 12: 1.30},
    "Antibiotic":            {1: 1.00, 2: 0.95, 3: 0.95, 4: 1.05, 5: 1.15, 6: 1.10,
                              7: 1.05, 8: 1.10, 9: 1.15, 10: 1.30, 11: 1.40, 12: 1.35},
    "Rehydration":           {1: 0.70, 2: 0.70, 3: 0.90, 4: 1.30, 5: 1.60, 6: 1.40,
                              7: 1.10, 8: 1.00, 9: 1.05, 10: 1.25, 11: 1.35, 12: 1.00},
    "Antiemetic":            {1: 0.80, 2: 0.80, 3: 0.90, 4: 1.20, 5: 1.40, 6: 1.20,
                              7: 1.00, 8: 1.00, 9: 1.00, 10: 1.15, 11: 1.20, 12: 0.95},
    "Gastrointestinal":      {1: 1.00, 2: 1.00, 3: 1.00, 4: 1.05, 5: 1.10, 6: 1.05,
                              7: 1.05, 8: 1.05, 9: 1.05, 10: 1.10, 11: 1.15, 12: 1.05},
    "Endocrine":             {1: 1.00, 2: 1.00, 3: 1.00, 4: 1.00, 5: 1.00, 6: 1.00,
                              7: 1.00, 8: 1.00, 9: 1.00, 10: 1.00, 11: 1.00, 12: 1.00},
    "Cardiovascular":        {1: 1.00, 2: 1.00, 3: 1.00, 4: 1.00, 5: 1.00, 6: 1.00,
                              7: 1.00, 8: 1.00, 9: 1.00, 10: 1.00, 11: 1.00, 12: 1.00},
    "Respiratory":           {1: 1.45, 2: 1.30, 3: 1.05, 4: 0.90, 5: 0.85, 6: 0.90,
                              7: 1.00, 8: 1.05, 9: 1.10, 10: 1.20, 11: 1.35, 12: 1.50},
    "Antihistamine":         {1: 1.20, 2: 1.10, 3: 1.00, 4: 1.00, 5: 1.05, 6: 1.05,
                              7: 1.05, 8: 1.10, 9: 1.15, 10: 1.25, 11: 1.30, 12: 1.25},
    "Haematinic":            {1: 1.00, 2: 1.00, 3: 1.00, 4: 1.00, 5: 1.00, 6: 1.00,
                              7: 1.00, 8: 1.00, 9: 1.00, 10: 1.00, 11: 1.00, 12: 1.00},
    "Vitamin":               {1: 0.90, 2: 0.90, 3: 0.95, 4: 1.00, 5: 1.00, 6: 1.00,
                              7: 1.00, 8: 1.00, 9: 1.00, 10: 1.05, 11: 1.10, 12: 1.00},
    "Antimalarial":          {1: 0.60, 2: 0.60, 3: 0.70, 4: 0.80, 5: 0.90, 6: 1.10,
                              7: 1.40, 8: 1.80, 9: 2.00, 10: 1.90, 11: 1.30, 12: 0.80},
}

# 8 PHCs: distinct sizes, restock cadences and hoarding/desync profiles so the
# dashboard has genuine redistribution stories to tell.
PHC_PROFILES = [
    {"id": "PHC-001", "name": "Thiruvallur Main",   "scale": 1.30, "restock_days": 7,  "efficiency": 0.90},
    {"id": "PHC-002", "name": "Ponneri",            "scale": 1.00, "restock_days": 10, "efficiency": 1.00},
    {"id": "PHC-003", "name": "Gummidipoondi",      "scale": 0.80, "restock_days": 14, "efficiency": 1.10},
    {"id": "PHC-004", "name": "Uthukottai",         "scale": 0.70, "restock_days": 21, "efficiency": 1.25},
    {"id": "PHC-005", "name": "Pallipattu",         "scale": 0.90, "restock_days": 7,  "efficiency": 0.85},  # overstocked
    {"id": "PHC-006", "restock_days": 10, "name": "Tiruttani", "scale": 1.10, "efficiency": 0.95},
    {"id": "PHC-007", "restock_days": 14, "name": "R.K. Pet",  "scale": 0.75, "efficiency": 1.30},  # starved
    {"id": "PHC-008", "restock_days": 21, "name": "Sholinghar","scale": 1.05, "efficiency": 1.20},
]

DISTRICT = "Thiruvallur"


def daterange(start: date, end: date):
    d = start
    while d <= end:
        yield d
        d += timedelta(days=1)


def sanitize_key(name: str, strength: str) -> str:
    """RTDB-safe medicine key: Realtime Database paths reject . $ # [ ] / and
    whitespace makes console ergonomics poor — normalize all to '-'."""
    import re
    raw = f"{name}_{strength}"
    return re.sub(r"[.$#\[\]/\s]", "-", raw)


def main():
    ap = argparse.ArgumentParser(description="ArogyaChain AI synthetic data generator")
    ap.add_argument("--phcs", type=int, default=8)
    ap.add_argument("--days", type=int, default=365)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--outdir", default="data")
    args = ap.parse_args()

    rng = random.Random(args.seed)
    os.makedirs(args.outdir, exist_ok=True)

    end_date = date(2026, 9, 20)  # yesterday relative to sprint start (Sep 21)
    start_date = end_date - timedelta(days=args.days - 1)
    dates = list(daterange(start_date, end_date))

    phcs = PHC_PROFILES[: args.phcs]

    # ---------------- inventory state per (phc, medicine) ----------------
    # opening stock sized to ~3 weeks of baseline demand so the year naturally
    # produces both stock-outs (inefficient PHCs) and gluts (efficient ones).
    state = {}
    for phc in phcs:
        for (name, form, strength, cat, unit) in NLEM_MEDICINES:
            key = (phc["id"], name, strength)
            base_daily = rng.uniform(3.0, 25.0) * phc["scale"]
            opening = base_daily * 21 * rng.uniform(0.8, 1.5)
            state[key] = {
                "phc": phc["id"], "medicine": name, "form": form, "strength": strength,
                "category": cat, "unit": unit,
                "stock": round(opening), "base_daily": base_daily,
                "restock_every": phc["restock_days"],
                "next_restock": start_date + timedelta(days=rng.randint(0, phc["restock_days"])),
                "eff": phc["efficiency"],
                "daily": [],
            }

    tx_rows = []
    tx_vertex = []

    for d in dates:
        month = d.month
        for phc in phcs:
            for (name, form, strength, cat, unit) in NLEM_MEDICINES:
                key = (phc["id"], name, strength)
                s = state[key]
                season = SEASONALITY.get(cat, {m: 1.0 for m in range(1, 13)})[month]
                # daily consumption with noise + day-of-week dip (Sundays quieter)
                dow = 0.7 if d.weekday() == 6 else 1.0
                demand = s["base_daily"] * season * dow * rng.uniform(0.75, 1.25) * s["eff"]
                dispensed = min(int(round(demand)), s["stock"])
                s["stock"] -= dispensed
                stockout_today = 1 if (s["stock"] <= 0 and demand > dispensed) else 0

                # scheduled restock delivery (procurement efficiency varies by PHC)
                if d >= s["next_restock"]:
                    order = s["base_daily"] * 21 * season * rng.uniform(0.9, 1.3) / s["eff"]
                    s["stock"] += int(round(order))
                    s["next_restock"] = d + timedelta(days=s["restock_every"])
                    tx_rows.append([d.isoformat(), phc["id"], name, strength, cat,
                                    "restock", int(round(order)), s["stock"]])
                if dispensed > 0:
                    tx_rows.append([d.isoformat(), phc["id"], name, strength, cat,
                                    "dispense", dispensed, s["stock"]])
                if stockout_today:
                    tx_rows.append([d.isoformat(), phc["id"], name, strength, cat,
                                    "stockout", 0, s["stock"]])

                s["daily"].append(dispensed)

                # Vertex format row (7-day horizon target computed in preprocess step)
                tx_vertex.append([d.isoformat(), phc["id"], f"{name} {strength}", dispensed])

    # ---------------- write transactions_full.csv ----------------
    full_path = os.path.join(args.outdir, "transactions_full.csv")
    with open(full_path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["date", "phc_id", "medicine", "strength", "category", "type", "quantity", "stock_after"])
        w.writerows(tx_rows)

    # ---------------- write transactions_vertex.csv ----------------
    vertex_path = os.path.join(args.outdir, "transactions_vertex.csv")
    with open(vertex_path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["date", "phc_id", "medicine", "quantity_dispensed"])
        w.writerows(tx_vertex)

    # ---------------- inventory_seed.json (current snapshot for Firebase) ----
    inventory = {}
    for phc in phcs:
        inv = {}
        for (name, form, strength, cat, unit) in NLEM_MEDICINES:
            key = (phc["id"], name, strength)
            s = state[key]
            avg14 = sum(s["daily"][-14:]) / max(len(s["daily"][-14:]), 1)
            # leave some PHCs in interesting states for the demo
            current = max(0, s["stock"])
            inv[sanitize_key(name, strength)] = {
                "medicine": name,
                "strength": strength,
                "category": cat,
                "stock": current,
                "reorderLevel": int(avg14 * 10) if avg14 > 0 else 20,
                "avgDailyUse": round(avg14, 1),
            }
        inventory[phc["id"]] = {
            "name": phc["name"],
            "district": DISTRICT,
            "medicines": inv,
        }

    seed_path = os.path.join(args.outdir, "inventory_seed.json")
    with open(seed_path, "w", encoding="utf-8") as f:
        json.dump({"inventory": inventory}, f, indent=2)

    # ---------------- data card ----------------
    n_disp = sum(1 for r in tx_rows if r[5] == "dispense")
    n_out = sum(1 for r in tx_rows if r[5] == "stockout")
    card = f"""# ArogyaChain AI — Data Card

**Provenance:** Fully synthetic. Consumption patterns modeled on public
NHM/HMIS reporting structures and IDSP seasonal disease trends for Tamil Nadu
(NE monsoon vector-borne peak Oct-Dec; winter ARI peak Dec-Jan). No real
patient or facility data used.

**Generated:** {date.today().isoformat()} (seed={args.seed})
**Facilities:** {len(phcs)} PHCs in {DISTRICT} district, with heterogeneous
restock cadences (7/10/14/21 days) and procurement efficiency factors to
produce realistic imbalances.

**Scale:** {len(dates)} days x {len(phcs)} PHCs x {len(NLEM_MEDICINES)} NLEM-2022 medicines
= {len(dates) * len(phcs) * len(NLEM_MEDICINES)} series, {len(tx_rows):,} events
({n_disp:,} dispense, {n_out:,} stock-out events).

**Known uses:** Vertex AI AutoML Forecasting training (7-day horizon),
Firebase seeding, dashboard demo.
"""
    with open(os.path.join(args.outdir, "data_card.md"), "w", encoding="utf-8") as f:
        f.write(card)

    print(f"[OK] {len(tx_rows):,} transaction rows  -> {full_path}")
    print(f"[OK] {len(tx_vertex):,} vertex rows      -> {vertex_path}")
    print(f"[OK] inventory seed for {len(phcs)} PHCs -> {seed_path}")
    print(f"[OK] data card -> {os.path.join(args.outdir, 'data_card.md')}")
    print(f"     Stock-out events: {n_out:,} ({100 * n_out / max(len(dates) * len(phcs) * len(NLEM_MEDICINES), 1):.1f}% of facility-days)")


if __name__ == "__main__":
    main()
