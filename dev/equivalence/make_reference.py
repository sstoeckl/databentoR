"""Freeze reference slices with the official Databento Python client.

This is the QA half of the data-equivalence protocol: it downloads a handful
of deliberately tiny slices through the pinned client (`dev/python-reference`)
and writes each as parquet, in the shape `tests/testthat/test-equivalence.R`
expects. The R client then downloads the same slices and the two tables are
compared column by column.

The output is NEVER committed. Databento's licence does not permit
redistributing market data, so `dev/equivalence/reference/` is gitignored.

Usage:
    pip install ./dev/python-reference pyarrow pandas
    python dev/equivalence/make_reference.py
"""

from __future__ import annotations

import json
import pathlib

import databento as db

REF = pathlib.Path(__file__).resolve().parent / "reference"
REF.mkdir(exist_ok=True)

# name, dataset, schema, symbols, stype_in, start, end
#
# Window sizes are chosen for coverage, not for cost: Databento bills an
# intraday request at whole-day granularity, so a one-second window and a
# one-minute window of the same instrument and schema are quoted identically.
# Measured 2026-09-12: ES.c.0 trades quotes 0.029645 USD for any window
# inside 2024-01-02.
SLICES = [
    ("glbx_es_ohlcv1d", "GLBX.MDP3", "ohlcv-1d", ["ES.FUT"], "parent",
     "2024-01-02", "2024-01-09"),
    ("glbx_es_trades", "GLBX.MDP3", "trades", ["ES.c.0"], "continuous",
     "2024-01-02T14:30", "2024-01-02T14:31"),
    ("glbx_es_tbbo", "GLBX.MDP3", "tbbo", ["ES.c.0"], "continuous",
     "2024-01-02T14:30", "2024-01-02T14:31"),
    ("glbx_es_mbp1", "GLBX.MDP3", "mbp-1", ["ES.c.0"], "continuous",
     "2024-01-02T14:30", "2024-01-02T14:30:30"),
    ("glbx_es_statistics", "GLBX.MDP3", "statistics", ["ES.FUT"], "parent",
     "2024-01-02", "2024-01-03"),
    ("glbx_es_definition", "GLBX.MDP3", "definition", ["ES.FUT"], "parent",
     "2024-01-02", "2024-01-03"),
]

BUDGET_USD = 0.50


def main() -> int:
    client = db.Historical()  # reads DATABENTO_API_KEY from the environment

    quotes = {}
    total = 0.0
    for name, dataset, schema, symbols, stype_in, start, end in SLICES:
        cost = client.metadata.get_cost(
            dataset=dataset, symbols=symbols, schema=schema,
            stype_in=stype_in, start=start, end=end,
        )
        quotes[name] = cost
        total += cost
        print(f"{name}: quoted {cost:.6f} USD")

    print(f"total quoted: {total:.6f} USD")
    if total > BUDGET_USD:
        raise SystemExit(
            f"Refusing to download: {total:.4f} USD exceeds the "
            f"{BUDGET_USD:.2f} USD budget for reference fixtures."
        )

    manifest = {
        "databento_python_version": db.__version__,
        "budget_usd": BUDGET_USD,
        "total_quoted_usd": round(total, 6),
        "slices": {},
    }

    for name, dataset, schema, symbols, stype_in, start, end in SLICES:
        store = client.timeseries.get_range(
            dataset=dataset, schema=schema, symbols=symbols,
            stype_in=stype_in, start=start, end=end,
        )
        # price_type="float" is the modern spelling of pretty_px=True;
        # reset_index turns the ts_recv/ts_event index back into the first
        # column, which is where the CSV encoding puts it.
        frame = store.to_df(price_type="float", pretty_ts=True,
                            map_symbols=True).reset_index()
        out = REF / f"{name}.parquet"
        frame.to_parquet(out)
        manifest["slices"][name] = {
            "dataset": dataset,
            "schema": schema,
            "symbols": symbols,
            "stype_in": stype_in,
            "start": start,
            "end": end,
            "rows": int(len(frame)),
            "columns": list(frame.columns),
            "quoted_usd": round(quotes[name], 6),
        }
        print(f"  -> {out.name} ({len(frame)} rows, {len(frame.columns)} cols)")

    (REF / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    print("Done. Fixtures are untracked by design - do not commit them.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
