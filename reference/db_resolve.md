# Resolve symbols from one symbol type to another

Free of charge. Mirrors `symbology.resolve`. Resolution is
time-dependent, which is why the answer is a set of intervals per input
symbol rather than one mapping: an instrument id is only valid for the
days it was assigned.

## Usage

``` r
db_resolve(
  dataset,
  symbols,
  stype_in = "raw_symbol",
  stype_out = "instrument_id",
  start_date,
  end_date = NULL
)
```

## Arguments

- dataset:

  Dataset code, e.g. `"GLBX.MDP3"`.

- symbols:

  Character vector of symbols, a single comma-separated string, or
  `NULL` for all symbols. With `stype_in = "instrument_id"` a numeric
  vector is accepted. At most 2000 symbols per request.

- stype_in:

  Symbol type of `symbols`, see
  [`db_stypes()`](https://www.sebastianstoeckl.com/databentoR/reference/db_enums.md).
  Use `"parent"` for product-level symbols such as `"ES.FUT"` or
  `"SPX.OPT"`.

- stype_out:

  Symbol type to resolve to, see
  [`db_stypes()`](https://www.sebastianstoeckl.com/databentoR/reference/db_enums.md).

- start_date, end_date:

  Resolution window, `start_date` required. Both take a `Date` or a
  `"YYYY-MM-DD"` string; timestamps are rejected, as in the Python
  client.

## Value

A tibble with one row per resolved interval: `input_symbol`,
`start_date` (inclusive), `end_date` (exclusive) and `symbol`. Symbols
the server resolved only partially or not at all are attached as the
`"partial"` and `"not_found"` attributes, alongside `"status"` and
`"message"`.

## Examples

``` r
if (FALSE) { # \dontrun{
db_resolve("GLBX.MDP3", "ES.FUT", stype_in = "parent",
           start_date = "2024-01-01", end_date = "2024-02-01")
} # }
```
