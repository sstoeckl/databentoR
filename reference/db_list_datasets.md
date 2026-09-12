# List available datasets

Free of charge. Mirrors `metadata.list_datasets`.

## Usage

``` r
db_list_datasets(start_date = NULL, end_date = NULL)
```

## Arguments

- start_date, end_date:

  Optional `Date` or `"YYYY-MM-DD"` string restricting the answer to
  datasets with data in that window.

## Value

A character vector of dataset codes such as `"GLBX.MDP3"` or
`"OPRA.PILLAR"`.

## See also

Other metadata:
[`db_get_billable_size()`](https://www.sebastianstoeckl.com/databentoR/reference/db_get_billable_size.md),
[`db_get_cost()`](https://www.sebastianstoeckl.com/databentoR/reference/db_get_cost.md),
[`db_get_dataset_condition()`](https://www.sebastianstoeckl.com/databentoR/reference/db_get_dataset_condition.md),
[`db_get_dataset_range()`](https://www.sebastianstoeckl.com/databentoR/reference/db_get_dataset_range.md),
[`db_get_record_count()`](https://www.sebastianstoeckl.com/databentoR/reference/db_get_record_count.md),
[`db_list_fields()`](https://www.sebastianstoeckl.com/databentoR/reference/db_list_fields.md),
[`db_list_publishers()`](https://www.sebastianstoeckl.com/databentoR/reference/db_list_publishers.md),
[`db_list_schemas()`](https://www.sebastianstoeckl.com/databentoR/reference/db_list_schemas.md),
[`db_list_unit_prices()`](https://www.sebastianstoeckl.com/databentoR/reference/db_list_unit_prices.md)

## Examples

``` r
if (FALSE) { # \dontrun{
db_list_datasets()
} # }
```
