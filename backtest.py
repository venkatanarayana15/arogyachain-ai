#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ArogyaChain AI — Backtest & Validation (Day 5 evidence, Asset 4)
================================================================
Answers the judge question: "does the forecaster actually work?"

Compares on the LAST 28 DAYS of the synthetic corpus (held out):
  A) local-ensemble  — the exact Cloud Function fallback (functions/lib/forecastLocal.js),
                  re-implemented here feature-identically
  B) seasonal-naive baseline (t-7 persistence) — "the dumb rule-based system"
                  that the pitch says AI should beat

Outputs:
  data/validation_metrics.json   — MAPE / sMAPE per model
  data/validation_chart.svg      — Actual vs Forecast for 3 sample series
  data/validation_chart.png      — PNG version (matplotlib, if available)

Usage: python backtest.py [--holdout 28]
"""

import argparse
import csv
import json
import math
import os
import statistics
from collections import defaultdict
from datetime import datetime


def fmean(xs):
    return sum(xs) / len(xs) if xs else 0.0


def forecast_local_ensemble(history, horizon=7):
    """Python port of functions/lib/forecastLocal.js (must stay in sync)."""
    h = [float(x) for x in history]
    out = []
    for _ in range(horizon):
        if len(h) >= 14:
            lag7 = h[-7]
            lag14 = h[-14]
            roll7 = fmean(h[-7:])
            roll3 = fmean(h[-3:])
            pred = 0.35 * lag7 + 0.15 * lag14 + 0.30 * roll7 + 0.20 * roll3
        elif len(h) >= 7:
            pred = 0.5 * h[-7] + 0.5 * fmean(h[-7:])
        elif len(h) >= 1:
            pred = fmean(h)
        else:
            pred = 0.0
        out.append(max(0.0, pred))
        h.append(pred)  # recursive multi-step, same as the JS fallback appends per day
    return out


def forecast_seasonal_naive(history, horizon=7):
    """Baseline: 'same as last week' — the rule-based system we claim to beat."""
    h = [float(x) for x in history]
    if len(h) < 7:
        return [fmean(h)] * horizon
    return [h[-7 + (i % 7)] for i in range(horizon)]


def mape(actual, pred):
    pairs = [(a, p) for a, p in zip(actual, pred) if a > 0]
    if not pairs:
        return None
    return 100.0 * sum(abs(a - p) / a for a, p in pairs) / len(pairs)


def smape(actual, pred):
    pairs = [(a, p) for a, p in zip(actual, pred)]
    if not pairs:
        return None
    return 100.0 * sum(abs(a - p) / max((a + p) / 2, 1e-9) for a, p in pairs) / len(pairs)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--holdout", type=int, default=28)
    ap.add_argument("--outdir", default="data")
    args = ap.parse_args()

    src = os.path.join(args.outdir, "transactions_vertex.csv")
    series = defaultdict(dict)  # (phc, med) -> {date: qty}
    with open(src, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            series[(row["phc_id"], row["medicine"])][row["date"]] = float(row["quantity_dispensed"])

    all_dates = sorted({d for s in series.values() for d in s})
    dates = [datetime.strptime(d, "%Y-%m-%d").date() for d in all_dates]
    holdout_dates = dates[-args.holdout:]

    # walk-forward evaluation: each holdout day gets a 7-day forecast made from history before it
    errs = {"local-ensemble": {"ape": [], "sape": []}, "seasonal-naive": {"ape": [], "sape": []}}
    sample_results = []  # for the chart
    sample_keys = None

    for key, by_date in series.items():
        hist = [by_date.get(d.isoformat(), 0.0) for d in dates[:-args.holdout]]
        if len(hist) < 21:
            continue
        for i, hd in enumerate(holdout_dates):
            actual = [by_date.get((hd).isoformat(), 0.0)]
            history = [by_date.get((dates[j]).isoformat(), 0.0) for j in range(len(dates) - args.holdout + i)]
            if len(history) < 14:
                continue
            pred_ens = forecast_local_ensemble(history, 1)
            pred_naive = forecast_seasonal_naive(history, 1)
            a = actual[0]
            if a > 0:
                errs["local-ensemble"]["ape"].append(abs(a - pred_ens[0]) / a)
                errs["local-ensemble"]["sape"].append(abs(a - pred_ens[0]) / max((a + pred_ens[0]) / 2, 1e-9))
                errs["seasonal-naive"]["ape"].append(abs(a - pred_naive[0]) / a)
                errs["seasonal-naive"]["sape"].append(abs(a - pred_naive[0]) / max((a + pred_naive[0]) / 2, 1e-9))
        # keep 3 chart samples: highest-variance series we encounter first
        if sample_keys is None or len(sample_results) < 3:
            if key not in [s["key"] for s in sample_results]:
                cutoff = len(dates) - args.holdout
                history_full = [by_date.get(d.isoformat(), 0.0) for d in dates[:cutoff]]
                if len(history_full) < 30:
                    continue
                fc = forecast_local_ensemble(history_full, args.holdout)
                actuals = [by_date.get(d.isoformat(), 0.0) for d in holdout_dates]
                sample_results.append({
                    "key": "|".join(key),
                    "dates": [d.isoformat() for d in holdout_dates],
                    "actual": actuals,
                    "forecast": fc,
                })

    metrics = {}
    for model, e in errs.items():
        metrics[model] = {
            "mape": round(100 * fmean(e["ape"]), 2) if e["ape"] else None,
            "smape": round(100 * fmean(e["sape"]), 2) if e["sape"] else None,
            "n": len(e["ape"]),
        }

    improvement = None
    if metrics["seasonal-naive"]["mape"] and metrics["local-ensemble"]["mape"]:
        improvement = round(
            100 * (1 - metrics["local-ensemble"]["mape"] / metrics["seasonal-naive"]["mape"]), 1
        )

    out = {
        "holdout_days": args.holdout,
        "series_count": len(series),
        "models": metrics,
        "ensemble_improvement_over_naive_pct": improvement,
        "note": "local-ensemble is the on-device fallback (feature-identical port of functions/lib/forecastLocal.js) "
                "and is the forecaster the shipped demo actually runs. Vertex AutoML consumes the identical "
                "feature contract (data/vertex_training.csv) and is the primary model once an endpoint is "
                "configured, but it is NOT included in these numbers - do not quote this file as Vertex "
                "validation. Stock-out impact is measured separately by impact_sim.py.",
    }
    mpath = os.path.join(args.outdir, "validation_metrics.json")
    with open(mpath, "w", encoding="utf-8") as f:
        json.dump(out, f, indent=2)

    # ---- chart: SVG always (no deps), PNG if matplotlib exists ----
    svg = render_svg(sample_results[:3], metrics)
    with open(os.path.join(args.outdir, "validation_chart.svg"), "w", encoding="utf-8") as f:
        f.write(svg)

    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        fig, axes = plt.subplots(3, 1, figsize=(10, 8), sharex=False)
        for ax, s in zip(axes, sample_results[:3]):
            ax.plot(s["dates"], s["actual"], label="Actual", color="#111")
            ax.plot(s["dates"], s["forecast"], label="Forecast (local-ensemble)", color="#0B6E4F", linestyle="--")
            ax.set_title(s["key"], fontsize=9)
            ax.legend(fontsize=8)
            ax.tick_params(axis="x", labelsize=7, rotation=45)
        fig.suptitle("ArogyaChain AI — Holdout Validation (last 28 days)")
        fig.tight_layout()
        fig.savefig(os.path.join(args.outdir, "validation_chart.png"), dpi=120)
        png_done = True
    except Exception:
        png_done = False

    print(json.dumps(out, indent=2))
    print(f"[OK] {mpath}")
    print(f"[OK] validation_chart.svg written" + (" (+ .png)" if png_done else " (install matplotlib for PNG)"))


def render_svg(samples, metrics):
    W, H = 900, 260 * max(len(samples), 1)
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" font-family="monospace">']
    parts.append(f'<text x="20" y="24" font-size="16" font-weight="bold">ArogyaChain AI — Actual vs Forecast (28-day holdout)</text>')
    parts.append(f'<text x="20" y="44" font-size="12">MAPE local-ensemble: {metrics["local-ensemble"]["mape"]}% | seasonal-naive: {metrics["seasonal-naive"]["mape"]}%</text>')
    for i, s in enumerate(samples):
        oy = 70 + i * 240
        all_v = s["actual"] + s["forecast"]
        vmax = max(all_v) or 1
        n = len(s["dates"])
        pw = W - 80
        def pts(vals):
            return " ".join(
                f"{40 + (j * pw / max(n - 1, 1)):.1f},{oy + 160 - (v / vmax) * 150:.1f}"
                for j, v in enumerate(vals)
            )
        parts.append(f'<text x="40" y="{oy - 6}" font-size="11">{s["key"]}</text>')
        parts.append(f'<polyline fill="none" stroke="#111" stroke-width="1.5" points="{pts(s["actual"])}"/>')
        parts.append(f'<polyline fill="none" stroke="#0B6E4F" stroke-width="1.5" stroke-dasharray="5,3" points="{pts(s["forecast"])}"/>')
        parts.append(f'<line x1="40" y1="{oy + 10}" x2="40" y2="{oy + 170}" stroke="#999"/>')
        parts.append(f'<line x1="40" y1="{oy + 170}" x2="{W - 40}" y2="{oy + 170}" stroke="#999"/>')
        if i == 0:
            parts.append(f'<line x1="600" y1="36" x2="640" y2="36" stroke="#111"/><text x="646" y="40" font-size="11">Actual</text>')
            parts.append(f'<line x1="720" y1="36" x2="760" y2="36" stroke="#0B6E4F" stroke-dasharray="5,3"/><text x="766" y="40" font-size="11">Forecast</text>')
    parts.append("</svg>")
    return "\n".join(parts)


if __name__ == "__main__":
    main()
