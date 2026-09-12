# List the unit prices of a dataset

Free of charge. Mirrors `metadata.list_unit_prices`. Prices are US
dollars per gigabyte, per feed mode and schema.
[`db_get_cost()`](https://www.sebastianstoeckl.com/databentoR/reference/db_get_cost.md)
already accounts for plan discounts, so a quote is not simply size times
unit price.

## Usage

``` r
db_list_unit_prices(dataset)
```

## Arguments

- dataset:

  Dataset code, e.g. `"GLBX.MDP3"`.

## Value

A tibble with `mode`, `schema` and `unit_price`. When the server answers
with a shape this function does not recognise, the parsed JSON is
returned unchanged and a warning is raised.

## See also

Other metadata:
[`db_get_billable_size()`](https://www.sebastianstoeckl.com/databentoR/reference/db_get_billable_size.md),
[`db_get_cost()`](https://www.sebastianstoeckl.com/databentoR/reference/db_get_cost.md),
[`db_get_dataset_condition()`](https://www.sebastianstoeckl.com/databentoR/reference/db_get_dataset_condition.md),
[`db_get_dataset_range()`](https://www.sebastianstoeckl.com/databentoR/reference/db_get_dataset_range.md),
[`db_get_record_count()`](https://www.sebastianstoeckl.com/databentoR/reference/db_get_record_count.md),
[`db_list_datasets()`](https://www.sebastianstoeckl.com/databentoR/reference/db_list_datasets.md),
[`db_list_fields()`](https://www.sebastianstoeckl.com/databentoR/reference/db_list_fields.md),
[`db_list_publishers()`](https://www.sebastianstoeckl.com/databentoR/reference/db_list_publishers.md),
[`db_list_schemas()`](https://www.sebastianstoeckl.com/databentoR/reference/db_list_schemas.md)

## Examples

``` r
if (FALSE) { # \dontrun{
db_list_unit_prices("GLBX.MDP3")
} # }
```
