# Getting started with databentoR

databentoR is a complete R client for the
[Databento](https://databento.com) market data HTTP API. It covers the
same ground as the official Python client: dataset discovery, free cost
previews, streaming range downloads, symbology, asynchronous batch jobs,
and the reference data endpoints for corporate actions, adjustment
factors and the security master.

Argument names, defaults and the bytes on the wire mirror the Python
client, so a script translates line by line. What comes back is a
tibble.

## Authentication

The key lives in an environment variable and nowhere else. Never put it
in a script, a fixture, or a repository.

    setx DATABENTO_API_KEY "db-XXXX..."     # Windows, then open a new session
    export DATABENTO_API_KEY="db-XXXX..."   # macOS and Linux, in ~/.profile

`usethis::edit_r_environ()` is the portable alternative. Check it with:

``` r

db_has_key()
#> [1] FALSE
```

## Find out what exists, for free

Every `metadata` endpoint is free of charge. Use them liberally.

``` r

db_list_datasets()
#> [1] "ARCX.PILLAR" "DBEQ.BASIC" "EQUS.SUMMARY" "GLBX.MDP3" "IFEU.IMPACT" ...

db_list_schemas("GLBX.MDP3")
#> [1] "mbo" "mbp-1" "mbp-10" "tbbo" "trades" "ohlcv-1s" "ohlcv-1m" ...
```

[`db_get_dataset_range()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_get_dataset_range.md)
answers the question that decides most research designs: how far back
does each schema actually go?

``` r

db_get_dataset_range("OPRA.PILLAR")
#> # A tibble: 6 x 3
#>   schema     start                end
#>   <chr>      <chr>                <chr>
#> 1 trades     2013-04-01T00:00:00Z 2026-09-11T00:00:00Z
#> 2 mbp-1      2023-03-28T00:00:00Z 2026-09-11T00:00:00Z
#> ...
```

[`db_get_dataset_condition()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_get_dataset_condition.md)
reports day-by-day whether a dataset is `available`, `degraded`,
`pending` or `missing`, which is worth checking before paying for a
window that cannot be complete.

## Always preview the cost

`timeseries.get_range` is the one endpoint that costs money, billed per
gigabyte. The preview is free and takes the identical arguments, so
there is no excuse for a surprise.

``` r

args <- list(
  dataset  = "GLBX.MDP3",
  start    = "2024-01-02",
  end      = "2024-01-09",
  symbols  = "ES.FUT",
  schema   = "ohlcv-1d",
  stype_in = "parent"
)

do.call(db_get_cost, args)          # US dollars
#> [1] 0.0021
do.call(db_get_record_count, args)  # how many rows you would get
#> [1] 43
do.call(db_get_billable_size, args) # bytes
#> [1] 4308
```

The quote already reflects any plan discount, so it is not simply
billable size times the unit price from
[`db_list_unit_prices()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_list_unit_prices.md).

Because a retried stream can be billed twice,
[`db_get_range()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_get_range.md)
is the only request databentoR never retries. The free endpoints retry
on 429 and 5xx.

## Download

``` r

es <- do.call(db_get_range, args)
es
#> # A tibble: 43 x 10
#>   ts_event            rtype publisher_id instrument_id  open  high   low close
#>   <dttm>              <int>        <int>         <dbl> <dbl> <dbl> <dbl> <dbl>
#> 1 2024-01-02 00:00:00    34            1          5002 4818. 4834. 4780. 4790.
#> ...
#> # i 2 more variables: volume <dbl>, symbol <chr>
```

Pass `path =` to write parquet at the same time:

``` r

do.call(db_get_range, c(args, list(path = "data/es_ohlcv1d.parquet")))
```

Symbols follow the Python client’s rules. `stype_in = "parent"` takes
product-level symbols such as `"ES.FUT"` or `"SPX.OPT"`; `"continuous"`
takes `"ES.c.0"`; `"raw_symbol"`, the default, takes `"ESH4"`. Symbols
are upper-cased for you, the roll rule of a continuous symbol is
lower-cased, and `symbols = NULL` means every symbol in the dataset.

## Column types are never guessed

Column types come from the field name, never from arrow’s CSV inference.
That is not fussiness. A `trades` slice whose `action` column is all
`"T"` infers as boolean, which would silently turn every trade action
into `TRUE`.

``` r

db_field_types(c("ts_recv", "price", "action", "order_id", "flags", "bid_px_00"))
#> # A tibble: 6 × 2
#>   name      kind     
#>   <chr>     <chr>    
#> 1 ts_recv   timestamp
#> 2 price     price    
#> 3 action    character
#> 4 order_id  int64    
#> 5 flags     int32    
#> 6 bid_px_00 price
```

[`db_list_fields()`](https://www.sebastianstoeckl.com/databentoR/dev/reference/db_list_fields.md)
is the authoritative list for a given schema and dataset, and the live
test suite checks the built-in table against it.

### Nanosecond timestamps

`POSIXct` stores seconds as a double, so on modern dates it resolves to
about a quarter of a microsecond. For book reconstruction or latency
work, ask for the exact count:

``` r

mbo <- db_get_range("GLBX.MDP3", start = "2024-01-02T14:30",
                    end = "2024-01-02T14:31", symbols = "ES.c.0",
                    schema = "mbo", stype_in = "continuous",
                    ts_type = "integer64")
class(mbo$ts_recv)
#> [1] "integer64"
```

## Symbology

Resolution is time-dependent, so the answer is a set of intervals per
input symbol rather than one mapping.

``` r

db_resolve("GLBX.MDP3", "ES.FUT", stype_in = "parent",
           start_date = "2024-01-02", end_date = "2024-01-09")
#> # A tibble: 38 x 4
#>   input_symbol start_date end_date   symbol
#>   <chr>        <date>     <date>     <chr>
#> 1 ES.FUT       2024-01-02 2024-01-03 5002
#> ...
```

Symbols the server could not resolve are attached as the `partial` and
`not_found` attributes rather than dropped in silence.

## Batch jobs

Databento recommends batch delivery above about five gigabytes. Submit,
poll, download.

``` r

job <- db_batch_submit_job(
  "OPRA.PILLAR", symbols = "SPX.OPT", schema = "ohlcv-1d",
  start = "2024-01-01", end = "2024-02-01",
  stype_in = "parent", encoding = "csv"
)

db_batch_list_jobs(states = "done", short = TRUE)
db_batch_list_files(job$id)
db_batch_download(job$id, output_dir = "data/batch")
```

`encoding` defaults to `"dbn"`, as in the Python client. databentoR can
read back only the text encodings, so ask for `"csv"` unless you have a
DBN decoder.

## Reference data

The reference endpoints share the gateway and cover corporate actions,
adjustment factors and the security master.

``` r

db_corporate_actions(start = "2024-01-01", end = "2024-02-01", symbols = "AAPL")
db_adjustment_factors(start = "2024-01-01", symbols = "AAPL")
db_security_master_last(symbols = "AAPL")
db_corporate_action_events()
```

## What is not here

Live streaming. The live gateway speaks binary DBN over TCP with a
challenge-response handshake, which needs a DBN decoder; databentoR is
built on the text encodings precisely to avoid one. Everything the HTTP
API offers is covered.

## Equivalence with the Python client

The package ships a two-layer equivalence suite that checks databentoR
against the official client request by request and column by column. See
[`vignette("equivalence")`](https://www.sebastianstoeckl.com/databentoR/dev/articles/equivalence.md).
