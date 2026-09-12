# List the unit prices of a dataset

Free of charge. Mirrors `metadata.list_unit_prices`. Prices are US
dollars per **gibibyte** (2^30 bytes), per feed mode and schema, not per
decimal gigabyte. Measured on 2026-09-12, a quote equals
`db_get_billable_size() / 2^30 * unit_price` to six decimal places, so
dividing by 1e9 instead overstates the cost by about 7%.

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
[`db_get_billable_size()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_get_billable_size.md),
[`db_get_cost()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_get_cost.md),
[`db_get_dataset_condition()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_get_dataset_condition.md),
[`db_get_dataset_range()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_get_dataset_range.md),
[`db_get_record_count()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_get_record_count.md),
[`db_list_datasets()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_list_datasets.md),
[`db_list_fields()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_list_fields.md),
[`db_list_publishers()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_list_publishers.md),
[`db_list_schemas()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_list_schemas.md)

## Examples

``` r
if (FALSE) { # \dontrun{
db_list_unit_prices("GLBX.MDP3")
} # }
```
