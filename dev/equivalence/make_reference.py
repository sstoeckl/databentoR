"""QA-ONLY reference builder (the only tolerated Python in this repo).

Freezes tiny slices via the OFFICIAL Databento Python client as parquet
fixtures for tests/testthat/test-equivalence.R. Never commit the output
(Databento data must not be redistributed) — reference/ is gitignored.

Usage:
    pip install --user databento pyarrow pandas   # QA machine only
    python dev/equivalence/make_reference.py
"""
from pathlib import Path

import databento as db

REF = Path(__file__).resolve().parent / "reference"
REF.mkdir(exist_ok=True)

SLICES = [
    ("glbx_es_ohlcv1d_2024-01", "GLBX.MDP3", "ohlcv-1d", ["ES.FUT"], "2024-01-01", "2024-02-01"),
    ("glbx_zq_ohlcv1d_2024-01", "GLBX.MDP3", "ohlcv-1d", ["ZQ.FUT"], "2024-01-01", "2024-02-01"),
    ("opra_djt_ohlcv1d_2024-10-w1", "OPRA.PILLAR", "ohlcv-1d", ["DJT.OPT"], "2024-10-01", "2024-10-08"),
]

client = db.Historical()  # reads DATABENTO_API_KEY from the environment

for name, dataset, schema, symbols, start, end in SLICES:
    cost = client.metadata.get_cost(dataset=dataset, symbols=symbols, schema=schema,
                                    start=start, end=end, stype_in="parent")
    print(f"{name}: quoted cost {cost:.6f} USD")
    store = client.timeseries.get_range(dataset=dataset, schema=schema, symbols=symbols,
                                        stype_in="parent", start=start, end=end)
    df = store.to_df(pretty_px=True, pretty_ts=True, map_symbols=True)
    out = REF / f"{name}.parquet"
    df.to_parquet(out)
    print(f"  -> {out} ({len(df)} rows)")

print("Done. Fixtures are UNTRACKED by design — do not commit them.")
