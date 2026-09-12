# Report the condition of a dataset, day by day

Free of charge. Mirrors `metadata.get_dataset_condition`. Use it to spot
`degraded`, `pending` or `missing` days before paying for a range that
cannot be complete.

## Usage

``` r
db_get_dataset_condition(dataset, start_date = NULL, end_date = NULL)
```

## Arguments

- dataset:

  Dataset code, e.g. `"GLBX.MDP3"`.

- start_date, end_date:

  Optional `Date` or `"YYYY-MM-DD"` window.

## Value

A tibble with `date`, `condition` and `last_modified_date`.

## See also

Other metadata:
[`db_get_billable_size()`](https://www.sebastianstoeckl.com/databentoR/reference/db_get_billable_size.md),
[`db_get_cost()`](https://www.sebastianstoeckl.com/databentoR/reference/db_get_cost.md),
[`db_get_dataset_range()`](https://www.sebastianstoeckl.com/databentoR/reference/db_get_dataset_range.md),
[`db_get_record_count()`](https://www.sebastianstoeckl.com/databentoR/reference/db_get_record_count.md),
[`db_list_datasets()`](https://www.sebastianstoeckl.com/databentoR/reference/db_list_datasets.md),
[`db_list_fields()`](https://www.sebastianstoeckl.com/databentoR/reference/db_list_fields.md),
[`db_list_publishers()`](https://www.sebastianstoeckl.com/databentoR/reference/db_list_publishers.md),
[`db_list_schemas()`](https://www.sebastianstoeckl.com/databentoR/reference/db_list_schemas.md),
[`db_list_unit_prices()`](https://www.sebastianstoeckl.com/databentoR/reference/db_list_unit_prices.md)

## Examples

``` r
if (FALSE) { # \dontrun{
db_get_dataset_condition("GLBX.MDP3", "2024-01-01", "2024-02-01")
} # }
```
