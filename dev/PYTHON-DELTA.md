# What the Python client does that the R scaffold did not

Written 2026-09-12 against `databento-python` 0.86.0, pinned as the submodule
`dev/python-reference`. This is the record of what the audit found and what
was done about it. Layer 3 of the equivalence protocol keeps it current: the
weekly `upstream-watch` workflow files an issue whenever a new release changes
any of this.

## 1. Wire-protocol corrections, all now fixed

These were real defects in the scaffold, not style differences. Each one would
have failed against the live API or silently misbehaved.

| # | What was wrong | Since | Now |
|---|---|---|---|
| 1 | `metadata.get_cost` was a GET with a query string | Python 0.48.0, Jan 2025 | POST with a form body. A query string cannot carry the documented 2000 symbols. |
| 2 | `timeseries.get_range` was a GET | same | POST with a form body. |
| 3 | `stype_out` was never sent | always | Sent explicitly. `get_cost` and `get_billable_size` pin `instrument_id`; `get_record_count` sends none, matching Python exactly. |
| 4 | `end` was always sent | Python 0.11.0 | Dropped from the body when `NULL`, which is what makes the server forward-fill from `start`. |
| 5 | Symbols were pasted together unchanged | always | Normalised as Python does: upper-cased, roll rule of a continuous symbol lower-cased (`ES.c.0`), `NULL` becoming `ALL_SYMBOLS`, 2000-symbol cap enforced locally. `es.c.0` would previously have been sent verbatim and not resolved. |
| 6 | Every request retried up to four times | always | Only the free endpoints retry, and only on 429 and 5xx. `timeseries.get_range` is billed per gigabyte; retrying a failed stream can be billed more than once. |
| 7 | The `X-Warning` response header was discarded | always | Surfaced as an R warning, as the Python client does. Server-side deprecation notices were invisible. |
| 8 | HTTP 206 was treated as plain success | always | Warns. It is a success code meaning only some symbols resolved. |
| 9 | `stype_in` defaulted to `"parent"` | — | Defaults to `"raw_symbol"`, matching the Python client. Pass `stype_in = "parent"` for product-level symbols such as `ES.FUT`. |
| 10 | Argument order was ad hoc | — | Mirrors the Python signatures, so scripts translate line by line. |

## 2. Endpoints the scaffold did not have

The scaffold implemented 4 of 16 historical endpoints and none of the
reference API. All are now present, 29 exported functions in total.

**Metadata** `db_list_publishers()`, `db_list_fields()`,
`db_list_unit_prices()`, `db_get_dataset_condition()`,
`db_get_dataset_range()`, `db_get_record_count()`, `db_get_billable_size()`.

**Symbology** `db_resolve()`.

**Batch** `db_batch_submit_job()`, `db_batch_get_job_details()`,
`db_batch_list_jobs()`, `db_batch_list_files()`, `db_batch_download()`. Ported
in the post-0.79.0 shape: `batch.download` fetches one zip from the API's own
endpoint, and `get_job_details` exists (0.79.0, June 2026); `list_jobs(short=)`
is 0.85.0, August 2026.

**Reference** `db_adjustment_factors()`, `db_corporate_actions()`,
`db_corporate_action_events()`, `db_corporate_action_enums()`,
`db_security_master()`, `db_security_master_last()`. These answer with
zstd-compressed JSON lines rather than a JSON document, and the two
`corporate_actions.list_*` endpoints are the only ones sent without
credentials.

## 3. Value domains that had drifted

`db_schemas()` now lists all twenty schemas, checked against the compiled DBN
enums by the offline test suite. The scaffold validated nothing, and the
docstrings in the Python client still show only the old twelve.

Added since the scaffold's reference point: `bbo-1s`, `bbo-1m`, `status`
(0.36.1), `ohlcv-eod`, `cmbp-1`, `cbbo-1s`, `cbbo-1m`, `tcbbo`.

`db_stypes()` is the four historical symbol types. The reference API accepts
twelve more (`isin`, `figi`, `nasdaq_symbol`, and since 0.84.0 `listing_id`,
`issuer_id`, `security_id`); `stype_in` is passed through unvalidated there,
as in Python.

`metadata.list_fields` regained an optional `dataset` parameter in 0.84.0
(August 2026). Always pass it: field sets differ between DBN record versions,
and DBN v3 became the default in 0.55.0 (May 2025), which changed the
`definition` schema from 64 to 73 fields.

`metadata.get_dataset_range` gained per-schema ranges in June 2025, and that
change never reached the changelog. `db_get_dataset_range()` parses them, and
it reads `start`/`end` rather than the `start_date`/`end_date` keys deprecated
in 0.34.0.

## 4. Things the Python source alone would have got wrong

The Python client always requests binary DBN, so its source says nothing about
the CSV path this package depends on. The HTTP reference, read on its HTTP tab
rather than its Python tab, settles it:

* `timeseries.get_range` does accept `encoding`, `compression`, `pretty_px`,
  `pretty_ts`, `map_symbols` and `limit`. They are not batch-only.
* Those three flags default to **false**, so they must be sent explicitly.
* They take lower-case `true`/`false`, whereas the form-body booleans the
  Python client sends render as `True`/`False`. Both spellings now go out in
  the right places, and the wire tests pin each.
* `encoding` defaults to `csv` server-side; the Python client overrides it.

## 5. A correctness trap that has nothing to do with Python

Reading a Databento CSV with arrow's type inference is unsafe. A `trades`
slice whose `action` column is all `"T"` infers as **boolean**, silently
turning every trade action into `TRUE`. An all-empty price column infers as
null. Both were reproduced on real fixtures.

`db_get_range()` therefore assigns every column type from the field name and
never infers. `db_field_types()` reports the assignment, and a live test checks
the built-in table against `db_list_fields()` for seven schemas.

Related: `POSIXct` stores seconds as a double, so on modern dates it resolves
to roughly a quarter of a microsecond, not a nanosecond. `ts_type =
"integer64"` returns the exact count.

## 6. Still open

**Live streaming is not implemented.** The live gateway speaks binary DBN over
TCP with a challenge-response handshake. Supporting it means writing a DBN
decoder in R, which is the one thing this package was designed to avoid. Every
HTTP endpoint is covered; live is a separate project if it is ever wanted.

**Data equivalence has not yet run against the live API.** No key is set on
this machine, so layer 2 has never executed. Layer 1, the wire comparison, is
complete and green for all 28 endpoints. Set `DATABENTO_API_KEY`, then:

```
pip install ./dev/python-reference pyarrow pandas
python dev/equivalence/make_reference.py
DATABENTOR_RUN_LIVE=true Rscript -e 'devtools::test()'
```

The fixture builder refuses to download if the quoted total exceeds fifty US
cents. Two assumptions close out on that first run: that the server's CSV
encoder matches the local one byte for byte, and that the CSV header appears
exactly once in a multi-chunk stream.
