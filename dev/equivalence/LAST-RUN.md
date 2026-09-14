# Equivalence attestation

Generated 2026-09-14 10:39 UTC by `dev/equivalence/report.R`.

* databentoR 0.1.0
* databento-python 0.86.0 (pinned submodule)
* wire layer: 28 endpoints compared request by request

## Data layer

For each slice, databentoR downloads the CSV encoding and the official Python client downloads DBN. Both tables are ordered by every column, because the server does not promise a stable order among records sharing a timestamp, then compared column by column.

| dataset | schema | rows | columns | columns_compared | columns_identical | max_rel_deviation | verdict |
| --- | --- | --- | --- | --- | --- | --- | --- |
| GLBX.MDP3 | ohlcv-1d | 49 | 10 | 10 | 10 | 0e+00 | PASS |
| GLBX.MDP3 | trades | 4810 | 14 | 14 | 14 | 0e+00 | PASS |
| GLBX.MDP3 | tbbo | 4810 | 20 | 20 | 20 | 0e+00 | PASS |
| GLBX.MDP3 | mbp-1 | 30877 | 20 | 20 | 20 | 0e+00 | PASS |
| GLBX.MDP3 | statistics | 2171 | 15 | 15 | 15 | 0e+00 | PASS |
| GLBX.MDP3 | definition | 61 | 74 | 74 | 74 | 0e+00 | PASS |

6 of 6 slices identical.

## What this report deliberately omits

No field values. Databento's licence does not permit redistributing market data, so no sample rows, no extracts and no summary statistics of the data appear here. Row and column counts describe the request rather than its content; the largest relative deviation is the gap between two numbers that agree, so it discloses nothing about either.
