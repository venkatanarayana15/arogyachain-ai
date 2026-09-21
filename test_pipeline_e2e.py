#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
test_pipeline_e2e.py — End-to-end test of the Python data pipeline.
====================================================================
Runs main.py → preprocess_vertex.py → backtest.py against a temp directory
and asserts the cross-artifact invariants a judge (or a teammate) would check:

  1. Generator outputs exist with correct schemas and sane row counts
  2. Every RTDB key in inventory_seed.json is Firebase-safe
  3. Vertex CSV has exactly the columns AutoML Forecasting requires
  4. Series counts match across artifacts (240 = 8 PHCs × 30 medicines)
  5. Backtest core claim: local-gbm beats seasonal-naive on MAPE
  6. Stock/out events actually exist (the problem is real in the data)

Run: python test_pipeline_e2e.py   (exit 1 on any failure)
"""

import csv
import json
import os
import shutil
import subprocess
import sys
import tempfile

PASS = "  PASS  "
FAIL = "  FAIL  "
results = {"passed": 0, "failed": 0}

# Windows consoles default to cp1252; keep our labels printable everywhere
try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass


def check(name, fn):
    try:
        fn()
        results["passed"] += 1
        print(PASS + name)
    except AssertionError as e:
        results["failed"] += 1
        print(FAIL + name + f"\n        {e}")


def read_csv(path):
    with open(path, newline="", encoding="utf-8") as f:
        r = csv.reader(f)
        header = next(r)
        rows = list(r)
    return header, rows


def main():
    tmp = tempfile.mkdtemp(prefix="arogyachain_e2e_")
    try:
        print("ArogyaChain AI — Python pipeline E2E\n")

        # ---------------- run the three stages ----------------
        for script, args in [
            ("main.py", ["--phcs", "8", "--days", "365", "--seed", "42", "--outdir", os.path.join(tmp, "data")]),
            ("preprocess_vertex.py", ["--horizon", "7", "--outdir", os.path.join(tmp, "data")]),
        ]:
            # preprocess reads/writes ./data — run it in a cwd that symlinks tmp
            pass
        # main.py supports --outdir; the other two hardcode data/ → run in tmp cwd with copies
        os.makedirs(os.path.join(tmp, "data"), exist_ok=True)
        r1 = subprocess.run(
            [sys.executable, os.path.abspath("main.py"), "--phcs", "8", "--days", "365",
             "--seed", "42", "--outdir", "data"],
            cwd=tmp, capture_output=True, text=True)
        assert r1.returncode == 0, f"main.py failed: {r1.stderr[-500:]}"

        r2 = subprocess.run(
            [sys.executable, os.path.abspath("preprocess_vertex.py"), "--horizon", "7", "--outdir", "data"],
            cwd=tmp, capture_output=True, text=True)
        assert r2.returncode == 0, f"preprocess_vertex.py failed: {r2.stderr[-500:]}"

        r3 = subprocess.run(
            [sys.executable, os.path.abspath("backtest.py"), "--holdout", "28", "--outdir", "data"],
            cwd=tmp, capture_output=True, text=True)
        assert r3.returncode == 0, f"backtest.py failed: {r3.stderr[-500:]}"

        data = os.path.join(tmp, "data")

        # ---------------- 1. schemas & row counts ----------------
        def t_full_schema():
            h, rows = read_csv(os.path.join(data, "transactions_full.csv"))
            assert h == ["date", "phc_id", "medicine", "strength", "category", "type", "quantity", "stock_after"], h
            assert len(rows) > 90_000, f"expected >90k rows, got {len(rows)}"
            types = {r[5] for r in rows}
            assert {"dispense", "restock", "stockout"} <= types, types
        check("generator: transactions_full.csv schema + >90k rows", t_full_schema)

        def t_seed_keys():
            seed = json.load(open(os.path.join(data, "inventory_seed.json"), encoding="utf-8"))
            phcs = seed["inventory"]
            assert len(phcs) == 8, f"expected 8 PHCs, got {len(phcs)}"
            bad = []
            for phc_id, phc in phcs.items():
                assert phc["district"] == "Thiruvallur"
                for med_key, m in phc["medicines"].items():
                    if any(c in med_key for c in ".$#[]/ "):
                        bad.append(med_key)
                    assert m["stock"] >= 0, f"negative stock {phc_id}/{med_key}"
                    assert m["reorderLevel"] > 0
                    assert m["avgDailyUse"] >= 0
            assert not bad, f"RTDB-unsafe keys: {bad[:5]}"
            n_meds = {len(p["medicines"]) for p in phcs.values()}
            assert n_meds == {30}, f"expected 30 meds per PHC, got {n_meds}"
        check("seed: 8 PHCs × 30 meds, all RTDB-safe keys, non-negative stock", t_seed_keys)

        # ---------------- 3. Vertex schema ----------------
        def t_vertex_schema():
            h, rows = read_csv(os.path.join(data, "vertex_training.csv"))
            assert h == ["timestamp", "time_series_identifier", "quantity_dispensed",
                         "day_of_week", "month_sin", "month_cos"], h
            assert len(rows) > 70_000, f"expected >70k rows, got {len(rows)}"
            series = {r[1] for r in rows}
            assert len(series) == 240, f"expected 240 series, got {len(series)}"
        check("vertex_training.csv: AutoML schema + 240 series + >70k rows", t_vertex_schema)

        def t_lag_features():
            h, rows = read_csv(os.path.join(data, "lag_features.csv"))
            for col in ["lag_1", "lag_7", "lag_14", "roll_7", "roll_28", "day_of_week", "month_sin", "month_cos"]:
                assert col in h, f"missing feature {col}"
            assert len(rows) > 70_000
        check("lag_features.csv: all engineered features present", t_lag_features)

        # ---------------- 4. cross-artifact consistency ----------------
        def t_consistency():
            seed = json.load(open(os.path.join(data, "inventory_seed.json"), encoding="utf-8"))
            seed_series = {f"{phc}|{k}" for phc, p in seed["inventory"].items() for k in p["medicines"]}
            _, rows = read_csv(os.path.join(data, "vertex_training.csv"))
            vertex_series = {r[1] for r in rows}
            missing = seed_series - vertex_series
            extra = vertex_series - seed_series
            assert not missing, f"seed series missing from vertex data: {list(missing)[:3]}"
            assert not extra, f"vertex series not in seed: {list(extra)[:3]}"
        check("consistency: seed <-> vertex series identical (240)", t_consistency)

        # ---------------- 5. backtest claim ----------------
        def t_backtest_claim():
            m = json.load(open(os.path.join(data, "validation_metrics.json"), encoding="utf-8"))
            gbm = m["models"]["local-gbm"]["mape"]
            naive = m["models"]["seasonal-naive"]["mape"]
            assert gbm is not None and naive is not None, "metrics missing"
            assert m["models"]["local-gbm"]["n"] > 5000, "too few evaluated points"
            assert gbm < naive, f"core claim failed: gbm {gbm} >= naive {naive}"
            assert 0 < gbm < 50, f"gbm MAPE out of sane range: {gbm}"
        check("backtest: local-gbm MAPE beats seasonal-naive baseline", t_backtest_claim)

        # ---------------- 6. the problem is real in the data ----------------
        def t_stockouts():
            _, rows = read_csv(os.path.join(data, "transactions_full.csv"))
            stockouts = sum(1 for r in rows if r[5] == "stockout")
            assert stockouts > 3000, f"expected >3k stock-out events, got {stockouts}"
        check("data realism: >3,000 stock-out events present", t_stockouts)

        print(f"\n{results['passed']} passed, {results['failed']} failed")
        sys.exit(1 if results["failed"] else 0)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    main()
