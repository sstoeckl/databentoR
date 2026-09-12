# Is a Databento API key configured?

Reads the environment variable `DATABENTO_API_KEY`. Never store the key
in code, scripts or test fixtures. Set it once per machine:

## Usage

``` r
db_has_key()
```

## Value

`TRUE` when a key is set, otherwise `FALSE`.

## Details

    setx DATABENTO_API_KEY "db-XXXX..."   # Windows, then open a new session
    export DATABENTO_API_KEY="db-XXXX..." # macOS / Linux, in ~/.profile

`usethis::edit_r_environ()` is the portable alternative.

## Examples

``` r
db_has_key()
#> [1] FALSE
```
