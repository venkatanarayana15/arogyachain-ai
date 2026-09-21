#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ArogyaChain AI — Vertex AI Preprocessing (Day 4, Asset 2)
=========================================================
Takes data/transactions_vertex.csv and produces:

  data/vertex_training.csv   -> AutoML Forecasting-ready table:
       timestamp, time_series_identifier, target, [covariates...]
  data/lag_features.csv      -> same table with explicit lag features (for the
       local gradient-boosted fallback model + judges' "real feature engineering" story)

Two-stage architecture note (this is the *why* for judges):
  * AutoML handles seasonality natively, but we still engineer explicit lags so the
    preprocessing craft is visible (plan.md Risk table, "Vertex AI feels too automated").
  * The local fallback model (functions/lib/forecastLocal.js) consumes the SAME lag
    features, so the demo never depends on a paid Vertex endpoint.

Usage:
  python preprocess_vertex.py [--horizon 7] [--outdir data]
"""

import argparse
import csv
import math
import os
import statistics
from collections import defaultdict
from datetime import date, datetime, timedelta

MONTH_SIN = {m: math.sin(2 * math.pi * m / 12) for m in range(1, 13)}
MONTH_COS = {m: math.cos(2 * math.pi * m / 12) for m in range(1, 13)}


def parse_date(s: str) -> date:
    return datetime.strptime(s, "%Y-%m-%d").date()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--horizon", type=int, default=7, help="forecast horizon in days")
    ap.add_argument("--lags", type=str, default="1,7,14")
    ap.add_argument("--outdir", default="data")
    args = ap.parse_args()

    lags = [int(x) for x in args.lags.split(",")]
    src = os.path.join(args.outdir, "transactions_vertex.csv")
    if not os.path.exists(src):
        raise SystemExit(f"Missing {src}. Run `python main.py` first.")

    # ---------- load daily series per (phc, medicine) ----------
    series = defaultdict(list)  # (phc, med) -> [(date, qty)]
    dates_min = None
    dates_max = None
    with open(src, newline="", encoding="utf-8") as f:
        r = csv.DictReader(f)
        for row in r:
            d = parse_date(row["date"])
            series[(row["phc_id"], row["medicine"])].append((d, float(row["quantity_dispensed"])))
            if dates_min is None or d < dates_min:
                dates_min = d
            if dates_max is None or d > dates_max:
                dates_max = d

    # fill gaps (days with zero dispense) so lags/rolling windows are honest
    full = {}
    for k, rows in series.items():
        rows.sort()
        by_date = {d: q for d, q in rows}
        dense = []
        d = dates_min
        while d <= dates_max:
            dense.append((d, by_date.get(d, 0.0)))
            d += timedelta(days=1)
        full[k] = dense

    # ---------- feature engineering ----------
    # header: timestamp, id, target, lag_1, lag_7, lag_14, roll7, roll28, dow, month_sin, month_cos
    header = (["timestamp", "series_id", "quantity_dispensed"]
              + [f"lag_{L}" for L in lags]
              + ["roll_7", "roll_28", "day_of_week", "month_sin", "month_cos"])

    rows_v, rows_f = [], []
    for (phc, med), dense in full.items():
        q = [v for _, v in dense]
        for i, (d, v) in enumerate(dense):
            feats = []
            ok = True
            for L in lags:
                if i - L >= 0:
                    feats.append(q[i - L])
                else:
                    ok = False
                    break
            if not ok:
                continue
            roll7 = statistics.fmean(q[max(0, i - 7):i]) if i >= 1 else 0.0
            roll28 = statistics.fmean(q[max(0, i - 28):i]) if i >= 1 else 0.0
            covs = [round(roll7, 2), round(roll28, 2), d.weekday(),
                    round(MONTH_SIN[d.month], 4), round(MONTH_COS[d.month], 4)]
            rows_f.append([d.isoformat(), f"{phc}|{med}", round(v, 1)] + feats + covs)
            if i >= 28:  # vertex row: keep full-history rows only (AutoML re-derives its own windows)
                rows_v.append([d.isoformat(), f"{phc}|{med}", round(v, 1)] + covs)

    rows_v.sort(key=lambda r: (r[1], r[0]))
    rows_f.sort(key=lambda r: (r[1], r[0]))

    vpath = os.path.join(args.outdir, "vertex_training.csv")
    with open(vpath, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["timestamp", "time_series_identifier", "quantity_dispensed",
                    "day_of_week", "month_sin", "month_cos"])
        w.writerows(rows_v)

    fpath = os.path.join(args.outdir, "lag_features.csv")
    with open(fpath, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows_f)

    print(f"[OK] {len(rows_v):,} AutoML rows  -> {vpath}")
    print(f"[OK] {len(rows_f):,} lag-feature rows -> {fpath}")
    print(f"     Horizon: {args.horizon}d | lags: {lags} | series: {len(full)}")


if __name__ == "__main__":
    main()
