"""Capture the exact HTTP requests the official Databento Python client makes.

No network, no API key, no cost: the transport is replaced with a stub that
records the URL, method and parameters and then aborts the call. The result is
a JSON fixture that `tests/testthat/test-wire.R` compares against the requests
databentoR builds for the same arguments.

The client is the pinned git submodule `dev/python-reference`, so the fixture
always describes one known version.

Usage:
    pip install ./dev/python-reference
    python dev/equivalence/wire_capture.py
    python dev/equivalence/wire_capture.py --out some/other/path.json
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys

import requests

import databento as db

# The client only checks that the key is neither blank nor the literal
# placeholder, so a dummy of the documented shape is enough.
DUMMY_KEY = "db-0000000000000000000000000000000"

OUT_DEFAULT = (
    pathlib.Path(__file__).resolve().parents[2]
    / "tests"
    / "testthat"
    / "fixtures"
    / "python_wire.json"
)


class _Captured(Exception):
    def __init__(self, record: dict) -> None:
        super().__init__("captured")
        self.record = record


def _stub(method: str):
    def call(*args, **kwargs):
        raise _Captured(
            {
                "method": method,
                "url": kwargs.get("url") or (args[0] if args else None),
                "params": kwargs.get("params"),
                "data": kwargs.get("data"),
            }
        )

    return call


def _render(value) -> str:
    """Render a value the way urlencode renders it in the request body."""
    if isinstance(value, bool):
        return "True" if value else "False"
    return str(value)


def _normalise(record: dict) -> dict:
    params = record.get("params") or []
    if isinstance(params, dict):
        params = list(params.items())
    data = record.get("data") or {}

    return {
        "method": record["method"],
        "url": record["url"],
        # Order matters: it is what the fixture pins down.
        "query": [[k, _render(v)] for k, v in params if v is not None],
        "body": [[k, _render(v)] for k, v in data.items() if v is not None],
    }


def capture(fn, /, *args, **kwargs) -> dict:
    try:
        fn(*args, **kwargs)
    except _Captured as captured:
        return _normalise(captured.record)
    raise RuntimeError(f"{fn!r} made no HTTP call")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=pathlib.Path, default=OUT_DEFAULT)
    args = parser.parse_args()

    requests.get = _stub("GET")
    requests.post = _stub("POST")

    hist = db.Historical(key=DUMMY_KEY)
    ref = db.Reference(key=DUMMY_KEY)
    m, t, s, b = hist.metadata, hist.timeseries, hist.symbology, hist.batch

    calls: dict[str, dict] = {
        "metadata.list_publishers": capture(m.list_publishers),
        "metadata.list_datasets": capture(m.list_datasets),
        "metadata.list_datasets.dated": capture(
            m.list_datasets, start_date="2024-01-01", end_date="2024-02-01"
        ),
        "metadata.list_schemas": capture(m.list_schemas, dataset="GLBX.MDP3"),
        "metadata.list_fields": capture(
            m.list_fields, schema="trades", encoding="csv", dataset="GLBX.MDP3"
        ),
        "metadata.list_unit_prices": capture(m.list_unit_prices, dataset="GLBX.MDP3"),
        "metadata.get_dataset_condition": capture(
            m.get_dataset_condition,
            dataset="GLBX.MDP3",
            start_date="2024-01-01",
            end_date="2024-02-01",
        ),
        "metadata.get_dataset_range": capture(m.get_dataset_range, dataset="GLBX.MDP3"),
        "metadata.get_record_count": capture(
            m.get_record_count,
            dataset="GLBX.MDP3",
            start="2020-12-28T12:00",
            end="2020-12-29",
            symbols="ESH1",
            schema="mbo",
            limit=1000000,
        ),
        "metadata.get_billable_size": capture(
            m.get_billable_size,
            dataset="GLBX.MDP3",
            start="2020-12-28T12:00",
            end="2020-12-29",
            symbols="ESH1",
            schema="mbo",
        ),
        "metadata.get_cost": capture(
            m.get_cost,
            dataset="GLBX.MDP3",
            start="2020-12-28T12:00",
            end="2020-12-29",
            symbols="ESH1",
            schema="mbo",
        ),
        "metadata.get_cost.parent": capture(
            m.get_cost,
            dataset="OPRA.PILLAR",
            start="2024-10-01",
            end="2024-10-08",
            symbols=["SPX.OPT", "VIX.OPT"],
            schema="ohlcv-1d",
            stype_in="parent",
        ),
        "metadata.get_cost.all_symbols": capture(
            m.get_cost,
            dataset="GLBX.MDP3",
            start="2024-01-01",
            schema="ohlcv-1d",
        ),
        "timeseries.get_range": capture(
            t.get_range,
            dataset="GLBX.MDP3",
            start="2020-12-28T12:00",
            end="2020-12-29",
            symbols="ES.c.0",
            schema="trades",
            stype_in="continuous",
        ),
        "timeseries.get_range.limit": capture(
            t.get_range,
            dataset="GLBX.MDP3",
            start="2020-12-28T12:00",
            symbols="ESH1",
            schema="ohlcv-1d",
            limit=100,
        ),
        "symbology.resolve": capture(
            s.resolve,
            dataset="GLBX.MDP3",
            symbols="ESH1",
            stype_in="raw_symbol",
            stype_out="instrument_id",
            start_date="2020-12-28",
            end_date="2020-12-29",
        ),
        "batch.submit_job": capture(
            b.submit_job,
            dataset="GLBX.MDP3",
            symbols="ESH1",
            schema="mbo",
            start="2020-12-28T12:00",
            end="2020-12-29",
        ),
        "batch.submit_job.csv": capture(
            b.submit_job,
            dataset="GLBX.MDP3",
            symbols="ESH1",
            schema="mbo",
            start="2020-12-28T12:00",
            encoding="csv",
            pretty_px=True,
            pretty_ts=True,
            split_duration="week",
            split_size=2000000000,
            limit=500,
        ),
        "batch.get_job_details": capture(b.get_job_details, job_id="JOB-0001"),
        "batch.list_jobs": capture(b.list_jobs),
        "batch.list_jobs.short": capture(b.list_jobs, states="done", short=True),
        "batch.list_files": capture(b.list_files, job_id="JOB-0001"),
        "adjustment_factors.get_range": capture(
            ref.adjustment_factors.get_range,
            start="2024-01-01",
            end="2024-02-01",
            symbols="AAPL",
            countries=["US", "CA"],
        ),
        "corporate_actions.get_range": capture(
            ref.corporate_actions.get_range,
            start="2024-01-01",
            end="2024-02-01",
            symbols="AAPL",
            events=["DIV", "SPLT"],
            exchanges=["XNAS"],
        ),
        "corporate_actions.list_events": capture(ref.corporate_actions.list_events),
        "corporate_actions.list_enums": capture(ref.corporate_actions.list_enums),
        "security_master.get_range": capture(
            ref.security_master.get_range,
            start="2024-01-01",
            end="2024-02-01",
            symbols="AAPL",
        ),
        "security_master.get_last": capture(
            ref.security_master.get_last,
            symbols="AAPL",
        ),
    }

    # The value domains come straight from the compiled DBN enums, so the R
    # tables in R/parse.R can be checked against them offline.
    import databento_dbn

    enums = {
        name: sorted(str(v) for v in getattr(databento_dbn, name).variants())
        for name in ("Schema", "SType", "Encoding", "Compression")
    }

    fixture = {
        "databento_python_version": db.__version__,
        "enums": enums,
        "gateway": "https://hist.databento.com",
        "note": (
            "Generated by dev/equivalence/wire_capture.py from the pinned "
            "dev/python-reference submodule. Contains no market data and no "
            "API key."
        ),
        "calls": calls,
    }

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(fixture, indent=2, sort_keys=False) + "\n",
                        encoding="utf-8")
    print(f"wrote {len(calls)} captured calls to {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
