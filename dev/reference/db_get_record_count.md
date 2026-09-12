# Count the records a request would return

Free of charge. Mirrors `metadata.get_record_count`, and the cheapest
way to learn that a slice is empty before paying for it.

## Usage

``` r
db_get_record_count(
  dataset,
  start,
  end = NULL,
  symbols = NULL,
  schema = "trades",
  stype_in = "raw_symbol",
  limit = NULL
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

- limit:

  Optional cap on the number of records.

## Value

A single number: the record count.

## See also

Other metadata:
[`db_get_billable_size()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_get_billable_size.md),
[`db_get_cost()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_get_cost.md),
[`db_get_dataset_condition()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_get_dataset_condition.md),
[`db_get_dataset_range()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_get_dataset_range.md),
[`db_list_datasets()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_list_datasets.md),
[`db_list_fields()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_list_fields.md),
[`db_list_publishers()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_list_publishers.md),
[`db_list_schemas()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_list_schemas.md),
[`db_list_unit_prices()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_list_unit_prices.md)

## Examples

``` r
if (FALSE) { # \dontrun{
db_get_record_count("GLBX.MDP3", start = "2024-01-01", end = "2024-02-01",
                    symbols = "ES.FUT", schema = "ohlcv-1d",
                    stype_in = "parent")
} # }
```
