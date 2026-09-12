# databentoR 0.1.0

First release. A complete R client for the Databento HTTP API, mirroring the
official Python client 0.86.0 on the wire.

## Historical API

* `db_get_range()` streams a range and returns a tibble, optionally writing
  parquet at the same time. It requests the CSV encoding rather than binary
  DBN, so no decoder is needed, and it is the only request the package never
  retries, because a retried stream can be billed twice.
* Metadata, all free of charge: `db_list_publishers()`, `db_list_datasets()`,
  `db_list_schemas()`, `db_list_fields()`, `db_list_unit_prices()`,
  `db_get_dataset_condition()`, `db_get_dataset_range()`,
  `db_get_record_count()`, `db_get_billable_size()` and `db_get_cost()`.
* `db_resolve()` resolves symbols and returns one row per validity interval,
  with unresolved symbols attached rather than dropped.
* Batch jobs: `db_batch_submit_job()`, `db_batch_get_job_details()`,
  `db_batch_list_jobs()`, `db_batch_list_files()` and `db_batch_download()`,
  with checksum verification and skip-if-complete restarts.

## Reference API

* `db_adjustment_factors()`, `db_corporate_actions()`,
  `db_corporate_action_events()`, `db_corporate_action_enums()`,
  `db_security_master()` and `db_security_master_last()`.

## Correctness

* Column types are assigned from the field name, never inferred. arrow's CSV
  inference reads a `trades` slice whose `action` column is all `"T"` as
  boolean, which would silently corrupt every trade action.
  `db_field_types()` reports what will be assigned.
* `ts_type = "integer64"` returns exact nanosecond timestamps. The default
  `POSIXct` stores seconds as a double and resolves to about a quarter of a
  microsecond on modern dates.
* Fields that are 64-bit on the wire come back as `bit64::integer64` instead
  of being downcast to double, so `order_id`, `raw_instrument_id` and an
  undefined statistics `quantity` keep their value. The last of those is the
  int64 maximum, which a double rounds.
* Symbols are normalised as the Python client normalises them: upper-cased,
  with the roll rule of a continuous symbol lower-cased, `NULL` becoming
  `ALL_SYMBOLS`, and the documented 2000-symbol cap enforced before the
  request is spent.
* Date parameters reject timestamps, as in the Python client, rather than
  silently truncating an instant to a day.
* HTTP 206 raises a warning: it is a success code that means only some
  symbols were resolved.
* The `X-Warning` response header is surfaced as an R warning, so server-side
  deprecation notices are not swallowed.

## Equivalence suite

* Wire equivalence against the pinned Python client for all 28 endpoints,
  offline and free, asserting method, endpoint, and parameter names, values
  and order. The R value domains are checked against the compiled DBN enums.
* Data equivalence over six tiny slices spanning `ohlcv-1d`, `trades`,
  `tbbo`, `mbp-1`, `statistics` and `definition`, with prices compared to a
  relative tolerance of `1e-12`. Both sides are sorted before comparison: the
  server does not promise a stable order among records sharing a timestamp,
  and neither client can.
* A weekly workflow diffs a new upstream release against the pin and files the
  changed calls as an issue.

Downloaded market data is never committed; the reference fixtures stay
untracked.
