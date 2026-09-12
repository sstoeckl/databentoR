# List the publishers Databento serves

Free of charge. Mirrors `metadata.list_publishers`.

## Usage

``` r
db_list_publishers()
```

## Value

A tibble with one row per publisher: `publisher_id`, `dataset`, `venue`
and `description`.

## See also

Other metadata:
[`db_get_billable_size()`](https://www.sebastianstoeckl.com/databentoR/reference/db_get_billable_size.md),
[`db_get_cost()`](https://www.sebastianstoeckl.com/databentoR/reference/db_get_cost.md),
[`db_get_dataset_condition()`](https://www.sebastianstoeckl.com/databentoR/reference/db_get_dataset_condition.md),
[`db_get_dataset_range()`](https://www.sebastianstoeckl.com/databentoR/reference/db_get_dataset_range.md),
[`db_get_record_count()`](https://www.sebastianstoeckl.com/databentoR/reference/db_get_record_count.md),
[`db_list_datasets()`](https://www.sebastianstoeckl.com/databentoR/reference/db_list_datasets.md),
[`db_list_fields()`](https://www.sebastianstoeckl.com/databentoR/reference/db_list_fields.md),
[`db_list_schemas()`](https://www.sebastianstoeckl.com/databentoR/reference/db_list_schemas.md),
[`db_list_unit_prices()`](https://www.sebastianstoeckl.com/databentoR/reference/db_list_unit_prices.md)

## Examples

``` r
if (FALSE) { # \dontrun{
db_list_publishers()
} # }
```
