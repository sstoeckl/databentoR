# List the fields of one schema and encoding

Free of charge. Mirrors `metadata.list_fields`. This is the
authoritative column list for a download: field sets differ between DBN
record versions, so pass `dataset` rather than relying on the newest
layout.

## Usage

``` r
db_list_fields(schema, encoding, dataset = NULL)
```

## Arguments

- schema:

  Schema name, see
  [`db_schemas()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_enums.md).

- encoding:

  Encoding whose field list you want, see
  [`db_encodings()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_enums.md).

- dataset:

  Optional dataset code. Omitting it returns the fields of the most
  recent DBN version, which may not match an older dataset.

## Value

A tibble with the field `name` and `type` per record.

## See also

Other metadata:
[`db_get_billable_size()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_get_billable_size.md),
[`db_get_cost()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_get_cost.md),
[`db_get_dataset_condition()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_get_dataset_condition.md),
[`db_get_dataset_range()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_get_dataset_range.md),
[`db_get_record_count()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_get_record_count.md),
[`db_list_datasets()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_list_datasets.md),
[`db_list_publishers()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_list_publishers.md),
[`db_list_schemas()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_list_schemas.md),
[`db_list_unit_prices()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_list_unit_prices.md)

## Examples

``` r
if (FALSE) { # \dontrun{
db_list_fields("ohlcv-1d", "csv", dataset = "GLBX.MDP3")
} # }
```
