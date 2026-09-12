# Download a historical range as a tibble

Mirrors `timeseries.get_range`. Where the Python client always asks for
the binary DBN encoding and decodes it locally, databentoR asks the API
for the CSV encoding and reads it with arrow, so no DBN decoder is
needed. The data is identical; see
[`vignette("equivalence")`](https://www.sebastianstoeckl.com/databentoR/dev/articles/equivalence.md)
for the column-by-column comparison and the handful of documented
differences.

## Usage

``` r
db_get_range(
  dataset,
  start,
  end = NULL,
  symbols = NULL,
  schema = "trades",
  stype_in = "raw_symbol",
  stype_out = "instrument_id",
  limit = NULL,
  path = NULL,
  pretty_px = TRUE,
  pretty_ts = TRUE,
  map_symbols = TRUE,
  ts_type = c("POSIXct", "integer64"),
  compression = c("none", "zstd"),
  col_types = NULL
)
```

## Arguments

- dataset:

  Dataset code, e.g. `"GLBX.MDP3"`.

- start, end:

  Request window, start inclusive and end exclusive. A string passes
  through verbatim, a `Date` becomes a plain date, a `POSIXct` an
  ISO-8601 UTC instant, and a number is read as nanoseconds since the
  UNIX epoch. Leaving `end` as `NULL` asks the server to forward-fill
  from `start`.

- symbols:

  Character vector of symbols, a single comma-separated string, or
  `NULL` for all symbols. With `stype_in = "instrument_id"` a numeric
  vector is accepted. At most 2000 symbols per request.

- schema:

  Schema name, see
  [`db_schemas()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_enums.md).

- stype_in:

  Symbol type of `symbols`, see
  [`db_stypes()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_enums.md).
  Use `"parent"` for product-level symbols such as `"ES.FUT"` or
  `"SPX.OPT"`.

- stype_out:

  Symbol type of the output, see
  [`db_stypes()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_enums.md).
  The API resolves to `"instrument_id"` from every input type, and to
  `"raw_symbol"` only from `"instrument_id"`.

- limit:

  Optional cap on the number of records.

- path:

  Optional file path. When given, the result is also written there as
  parquet, and the tibble is returned invisibly.

- pretty_px:

  Ask the server for decimal prices instead of fixed-point integers
  scaled by 1e-9.

- pretty_ts:

  Ask the server for ISO-8601 timestamps instead of nanosecond counts.
  With `FALSE` the timestamp columns come back as character, because a
  nanosecond count does not fit an R numeric type without loss.

- map_symbols:

  Ask the server to append a `symbol` column to every record.

- ts_type:

  How timestamps are represented in R. `"POSIXct"`, the default, is
  convenient but stores seconds as a double, so on modern dates it
  resolves to roughly a quarter of a microsecond rather than to the
  nanosecond. `"integer64"` keeps the exact nanosecond count (it
  requires the `bit64` package and forces `pretty_ts = FALSE`), which is
  what you want for book reconstruction or any latency work.

- compression:

  Transfer compression, `"none"` or `"zstd"`. `"zstd"` is worth it for
  large pulls and is decompressed transparently.

- col_types:

  Optional arrow schema overriding the column types databentoR would
  assign.

## Value

A tibble, invisibly when `path` is given.

## Details

**This endpoint costs money**, billed per gigabyte. Call
[`db_get_cost()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_get_cost.md)
with the same arguments first; previews are free. For the same reason
this is the only request databentoR never retries: a retried stream can
be billed twice.

Column types are assigned explicitly from the field name, never
inferred. Inference is unsafe here: a `trades` slice whose `action`
column is all `"T"` would otherwise be read as boolean. See
[`db_field_types()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_field_types.md).

## Examples

``` r
if (FALSE) { # \dontrun{
# always preview the cost first
db_get_cost("GLBX.MDP3", start = "2024-01-01", end = "2024-02-01",
            symbols = "ES.FUT", schema = "ohlcv-1d", stype_in = "parent")

es <- db_get_range("GLBX.MDP3", start = "2024-01-01", end = "2024-02-01",
                   symbols = "ES.FUT", schema = "ohlcv-1d",
                   stype_in = "parent")
} # }
```
