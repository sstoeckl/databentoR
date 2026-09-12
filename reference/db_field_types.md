# Column types databentoR gives a CSV download

[`db_get_range()`](https://www.sebastianstoeckl.com/databentoR/reference/db_get_range.md)
never lets arrow guess a column type. This function reports the type it
will assign to each field, which is useful when you want to pass your
own `col_types` or to check the package against
[`db_list_fields()`](https://www.sebastianstoeckl.com/databentoR/reference/db_list_fields.md).

## Usage

``` r
db_field_types(fields)
```

## Arguments

- fields:

  Character vector of field names, for instance the `name` column of
  [`db_list_fields()`](https://www.sebastianstoeckl.com/databentoR/reference/db_list_fields.md).

## Value

A tibble with `name` and `kind`, where `kind` is one of `"timestamp"`,
`"price"`, `"character"`, `"int64"` or `"int32"`.

## Examples

``` r
db_field_types(c("ts_event", "open", "action", "order_id", "flags"))
#> # A tibble: 5 × 2
#>   name     kind     
#>   <chr>    <chr>    
#> 1 ts_event timestamp
#> 2 open     price    
#> 3 action   character
#> 4 order_id int64    
#> 5 flags    int32    
```
