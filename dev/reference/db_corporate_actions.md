# Corporate actions

Mirrors `corporate_actions.get_range`.

## Usage

``` r
db_corporate_actions(
  start,
  end = NULL,
  index = "event_date",
  symbols = NULL,
  stype_in = "raw_symbol",
  events = NULL,
  countries = NULL,
  exchanges = NULL,
  security_types = NULL,
  flatten = TRUE,
  pit = FALSE,
  allocate_isins = TRUE,
  compression = "zstd"
)
```

## Arguments

- start, end:

  Request window. `start` is required; leaving `end` as `NULL` asks the
  server to forward-fill.

- index:

  Column the result is ordered by, `"event_date"` by default.

- symbols:

  Character vector of symbols, a comma-separated string, or `NULL` for
  all symbols.

- stype_in:

  Symbol type of `symbols`. The reference API accepts more types than
  the historical one, among them `"isin"`, `"figi"` and
  `"nasdaq_symbol"`, and passes the value through unvalidated.

- events:

  Optional event-type filter, a character vector or a comma-separated
  string. See
  [`db_corporate_action_events()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_corporate_action_events.md).

- countries:

  Optional country filter, a character vector or a comma-separated
  string.

- exchanges:

  Optional exchange filter. Sent only when supplied.

- security_types:

  Optional security-type filter.

- flatten:

  Expand the nested `date_info`, `rate_info` and `event_info` objects
  into ordinary columns.

- pit:

  Keep every point-in-time record. `FALSE`, the default, keeps only the
  latest record of each event.

- allocate_isins:

  Ask the server to allocate ISINs.

- compression:

  Transfer compression, `"zstd"` or `"none"`.

## Value

A tibble of corporate actions.

## See also

Other reference:
[`db_adjustment_factors()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_adjustment_factors.md),
[`db_corporate_action_enums()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_corporate_action_enums.md),
[`db_corporate_action_events()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_corporate_action_events.md),
[`db_security_master()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_security_master.md),
[`db_security_master_last()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_security_master_last.md)

## Examples

``` r
if (FALSE) { # \dontrun{
db_corporate_actions(start = "2024-01-01", symbols = "AAPL")
} # }
```
