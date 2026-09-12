# List the schemas available for a dataset

Free of charge. Mirrors `metadata.list_schemas`. Which schemas exist is
a property of the dataset, so this is the authoritative list rather than
[`db_schemas()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_enums.md).

## Usage

``` r
db_list_schemas(dataset)
```

## Arguments

- dataset:

  Dataset code, e.g. `"GLBX.MDP3"`.

## Value

A character vector of schema names, e.g. `"ohlcv-1m"`.

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
[`db_list_unit_prices()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_list_unit_prices.md)

## Examples

``` r
if (FALSE) { # \dontrun{
db_list_schemas("GLBX.MDP3")
} # }
```
