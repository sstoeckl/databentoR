# Report the available date range of a dataset

Free of charge. Mirrors `metadata.get_dataset_range`. Newer servers
report a range per schema, which is how you learn that a venue's quotes
start years after its trades.

## Usage

``` r
db_get_dataset_range(dataset)
```

## Arguments

- dataset:

  Dataset code, e.g. `"GLBX.MDP3"`.

## Value

A tibble with `schema`, `start` and `end`. When the server reports only
one overall range, `schema` is `NA`. The parsed JSON is attached as the
`"raw"` attribute.

## See also

Other metadata:
[`db_get_billable_size()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_get_billable_size.md),
[`db_get_cost()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_get_cost.md),
[`db_get_dataset_condition()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_get_dataset_condition.md),
[`db_get_record_count()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_get_record_count.md),
[`db_list_datasets()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_list_datasets.md),
[`db_list_fields()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_list_fields.md),
[`db_list_publishers()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_list_publishers.md),
[`db_list_schemas()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_list_schemas.md),
[`db_list_unit_prices()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_list_unit_prices.md)

## Examples

``` r
if (FALSE) { # \dontrun{
db_get_dataset_range("OPRA.PILLAR")
} # }
```
