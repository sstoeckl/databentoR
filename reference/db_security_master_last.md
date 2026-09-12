# Latest security-master record per security

Mirrors `security_master.get_last`.

## Usage

``` r
db_security_master_last(
  symbols = NULL,
  stype_in = "raw_symbol",
  countries = NULL,
  security_types = NULL,
  allocate_isins = TRUE,
  compression = "zstd"
)
```

## Arguments

- symbols:

  Character vector of symbols, a comma-separated string, or `NULL` for
  all symbols.

- stype_in:

  Symbol type of `symbols`. The reference API accepts more types than
  the historical one, among them `"isin"`, `"figi"` and
  `"nasdaq_symbol"`, and passes the value through unvalidated.

- countries:

  Optional country filter, a character vector or a comma-separated
  string.

- security_types:

  Optional security-type filter.

- allocate_isins:

  Ask the server to allocate ISINs.

- compression:

  Transfer compression, `"zstd"` or `"none"`.

## Value

A tibble of security-master records, ordered by `ts_effective`.

## See also

Other reference:
[`db_adjustment_factors()`](https://www.sebastianstoeckl.com/databentoR/reference/db_adjustment_factors.md),
[`db_corporate_action_enums()`](https://www.sebastianstoeckl.com/databentoR/reference/db_corporate_action_enums.md),
[`db_corporate_action_events()`](https://www.sebastianstoeckl.com/databentoR/reference/db_corporate_action_events.md),
[`db_corporate_actions()`](https://www.sebastianstoeckl.com/databentoR/reference/db_corporate_actions.md),
[`db_security_master()`](https://www.sebastianstoeckl.com/databentoR/reference/db_security_master.md)

## Examples

``` r
if (FALSE) { # \dontrun{
db_security_master_last(symbols = "AAPL")
} # }
```
