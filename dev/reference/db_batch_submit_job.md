# Submit a batch job

Mirrors `batch.submit_job`. Batch jobs are the way to request slices too
large to stream with
[`db_get_range()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_get_range.md)
— Databento recommends them above about five gigabytes. Submit the job,
poll it with
[`db_batch_list_jobs()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_batch_list_jobs.md),
then fetch the output with
[`db_batch_download()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_batch_download.md).

## Usage

``` r
db_batch_submit_job(
  dataset,
  symbols,
  schema,
  start,
  end = NULL,
  encoding = "dbn",
  compression = "zstd",
  pretty_px = FALSE,
  pretty_ts = FALSE,
  map_symbols = NULL,
  split_symbols = FALSE,
  split_duration = "day",
  split_size = NULL,
  delivery = "download",
  stype_in = "raw_symbol",
  stype_out = "instrument_id",
  limit = NULL
)
```

## Arguments

- dataset:

  Dataset code, e.g. `"GLBX.MDP3"`.

- symbols:

  Character vector of symbols, a single comma-separated string, or
  `NULL` for all symbols. With `stype_in = "instrument_id"` a numeric
  vector is accepted. At most 2000 symbols per request.

- schema:

  Schema name, see
  [`db_schemas()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_enums.md).

- start, end:

  Request window, start inclusive and end exclusive. A string passes
  through verbatim, a `Date` becomes a plain date, a `POSIXct` an
  ISO-8601 UTC instant, and a number is read as nanoseconds since the
  UNIX epoch. Leaving `end` as `NULL` asks the server to forward-fill
  from `start`.

- encoding:

  Output encoding, see
  [`db_encodings()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_enums.md).

- compression:

  Output compression, see
  [`db_compressions()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_enums.md).

- pretty_px:

  Write decimal prices instead of fixed-point integers.

- pretty_ts:

  Write ISO-8601 timestamps instead of nanosecond counts.

- map_symbols:

  Append a `symbol` field to every record. `NULL`, the default, means
  `TRUE` for the text encodings and `FALSE` for DBN.

- split_symbols:

  Split the output into one file per symbol.

- split_duration:

  Split the output by `"day"`, `"week"`, `"month"`, `"year"` or
  `"none"`.

- split_size:

  Optional maximum size per output file, in bytes.

- delivery:

  Delivery mechanism; `"download"` is the only one offered.

- stype_in:

  Symbol type of `symbols`, see
  [`db_stypes()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_enums.md).
  Use `"parent"` for product-level symbols such as `"ES.FUT"` or
  `"SPX.OPT"`.

- stype_out:

  Symbol type of the output, see
  [`db_stypes()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_enums.md).

- limit:

  Optional cap on the number of records.

## Value

A one-row tibble of the job's properties, including its `id`.

## Details

Defaults follow the Python client, so `encoding` is `"dbn"`. Note that
databentoR can read back only the `"csv"` and `"json"` encodings; a DBN
job downloads fine but needs a DBN decoder to open.

## See also

Other batch:
[`db_batch_download()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_batch_download.md),
[`db_batch_get_job_details()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_batch_get_job_details.md),
[`db_batch_list_files()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_batch_list_files.md),
[`db_batch_list_jobs()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_batch_list_jobs.md)

## Examples

``` r
if (FALSE) { # \dontrun{
job <- db_batch_submit_job("OPRA.PILLAR", symbols = "SPX.OPT",
                           schema = "ohlcv-1d", start = "2024-01-01",
                           end = "2024-02-01", encoding = "csv",
                           stype_in = "parent")
job$id
} # }
```
