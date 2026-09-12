# List the corporate-action event types

Mirrors `corporate_actions.list_events`. This endpoint is public: the
Python client sends no credentials, and neither does databentoR.

## Usage

``` r
db_corporate_action_events()
```

## Value

A tibble of event codes and their descriptions.

## See also

Other reference:
[`db_adjustment_factors()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_adjustment_factors.md),
[`db_corporate_action_enums()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_corporate_action_enums.md),
[`db_corporate_actions()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_corporate_actions.md),
[`db_security_master()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_security_master.md),
[`db_security_master_last()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_security_master_last.md)

## Examples

``` r
if (FALSE) { # \dontrun{
db_corporate_action_events()
} # }
```
