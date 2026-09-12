# Changelog

## databentoR 0.1.0

First release. A complete R client for the Databento HTTP API, mirroring
the official Python client 0.86.0 on the wire.

### Historical API

- [`db_get_range()`](https://www.sebastianstoeckl.com/databentoR/reference/db_get_range.md)
  streams a range and returns a tibble, optionally writing parquet at
  the same time. It requests the CSV encoding rather than binary DBN, so
  no decoder is needed, and it is the only request the package never
  retries, because a retried stream can be billed twice.
- Metadata, all free of charge:
  [`db_list_publishers()`](https://www.sebastianstoeckl.com/databentoR/reference/db_list_publishers.md),
  [`db_list_datasets()`](https://www.sebastianstoeckl.com/databentoR/reference/db_list_datasets.md),
  [`db_list_schemas()`](https://www.sebastianstoeckl.com/databentoR/reference/db_list_schemas.md),
  [`db_list_fields()`](https://www.sebastianstoeckl.com/databentoR/reference/db_list_fields.md),
  [`db_list_unit_prices()`](https://www.sebastianstoeckl.com/databentoR/reference/db_list_unit_prices.md),
  [`db_get_dataset_condition()`](https://www.sebastianstoeckl.com/databentoR/reference/db_get_dataset_condition.md),
  [`db_get_dataset_range()`](https://www.sebastianstoeckl.com/databentoR/reference/db_get_dataset_range.md),
  [`db_get_record_count()`](https://www.sebastianstoeckl.com/databentoR/reference/db_get_record_count.md),
  [`db_get_billable_size()`](https://www.sebastianstoeckl.com/databentoR/reference/db_get_billable_size.md)
  and
  [`db_get_cost()`](https://www.sebastianstoeckl.com/databentoR/reference/db_get_cost.md).
- [`db_resolve()`](https://www.sebastianstoeckl.com/databentoR/reference/db_resolve.md)
  resolves symbols and returns one row per validity interval, with
  unresolved symbols attached rather than dropped.
- Batch jobs:
  [`db_batch_submit_job()`](https://www.sebastianstoeckl.com/databentoR/reference/db_batch_submit_job.md),
  [`db_batch_get_job_details()`](https://www.sebastianstoeckl.com/databentoR/reference/db_batch_get_job_details.md),
  [`db_batch_list_jobs()`](https://www.sebastianstoeckl.com/databentoR/reference/db_batch_list_jobs.md),
  [`db_batch_list_files()`](https://www.sebastianstoeckl.com/databentoR/reference/db_batch_list_files.md)
  and
  [`db_batch_download()`](https://www.sebastianstoeckl.com/databentoR/reference/db_batch_download.md),
  with checksum verification and skip-if-complete restarts.

### Reference API

- [`db_adjustment_factors()`](https://www.sebastianstoeckl.com/databentoR/reference/db_adjustment_factors.md),
  [`db_corporate_actions()`](https://www.sebastianstoeckl.com/databentoR/reference/db_corporate_actions.md),
  [`db_corporate_action_events()`](https://www.sebastianstoeckl.com/databentoR/reference/db_corporate_action_events.md),
  [`db_corporate_action_enums()`](https://www.sebastianstoeckl.com/databentoR/reference/db_corporate_action_enums.md),
  [`db_security_master()`](https://www.sebastianstoeckl.com/databentoR/reference/db_security_master.md)
  and
  [`db_security_master_last()`](https://www.sebastianstoeckl.com/databentoR/reference/db_security_master_last.md).

### Correctness

- Column types are assigned from the field name, never inferred. arrow’s
  CSV inference reads a `trades` slice whose `action` column is all
  `"T"` as boolean, which would silently corrupt every trade action.
  [`db_field_types()`](https://www.sebastianstoeckl.com/databentoR/reference/db_field_types.md)
  reports what will be assigned, and takes a `schema` argument because
  exactly one field name is schema-dependent: `action` is a character
  code in the trade and book schemas and a numeric enum in `status`.
- `ts_type = "integer64"` returns exact nanosecond timestamps. The
  default `POSIXct` stores seconds as a double and resolves to about a
  quarter of a microsecond on modern dates.
- Fields that are 64-bit on the wire come back as
  [`bit64::integer64`](https://bit64.r-lib.org/reference/bit64-package.html)
  instead of being downcast to double, so `order_id`,
  `raw_instrument_id` and an undefined statistics `quantity` keep their
  value. The last of those is the int64 maximum, which a double rounds.
- Symbols are normalised as the Python client normalises them:
  upper-cased, with the roll rule of a continuous symbol lower-cased,
  `NULL` becoming `ALL_SYMBOLS`, and the documented 2000-symbol cap
  enforced before the request is spent.
- Date parameters reject timestamps, as in the Python client, rather
  than silently truncating an instant to a day.
- HTTP 206 raises a warning: it is a success code that means only some
  symbols were resolved.
- The `X-Warning` response header is surfaced as an R warning, so
  server-side deprecation notices are not swallowed.

### Equivalence suite

- Wire equivalence against the pinned Python client for all 28
  endpoints, offline and free, asserting method, endpoint, and parameter
  names, values and order. The R value domains are checked against the
  compiled DBN enums.
- Data equivalence over six tiny slices spanning `ohlcv-1d`, `trades`,
  `tbbo`, `mbp-1`, `statistics` and `definition`, with prices compared
  to a relative tolerance of `1e-12`. Both sides are sorted before
  comparison: the server does not promise a stable order among records
  sharing a timestamp, and neither client can.
- A full live coverage sweep over every exported function: all twenty
  schemas across three datasets, a batch job submitted, polled,
  downloaded and compared against the streamed equivalent, symbology for
  every input symbol type, and the reference endpoints. It runs weekly
  and on demand, and never on a push.
- A weekly workflow diffs a new upstream release against the pin and
  files the changed calls as an issue.

Downloaded market data is never committed; the reference fixtures stay
untracked.
