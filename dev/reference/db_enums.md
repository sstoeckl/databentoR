# Schemas, symbol types, encodings and compressions

The historical API validates these server-side; databentoR validates
them client-side first, exactly as the official Python client does, so
that a typo fails locally instead of costing a round trip.

## Usage

``` r
db_schemas()

db_stypes()

db_encodings()

db_compressions()
```

## Value

A character vector of accepted values.

## Details

If Databento adds a value that is not yet listed here, update the
package. The weekly `upstream-watch` workflow reports new values as soon
as they appear in the Python client.

## Examples

``` r
db_schemas()
#>  [1] "mbo"        "mbp-1"      "mbp-10"     "bbo-1s"     "bbo-1m"    
#>  [6] "tbbo"       "trades"     "ohlcv-1s"   "ohlcv-1m"   "ohlcv-1h"  
#> [11] "ohlcv-1d"   "ohlcv-eod"  "definition" "statistics" "status"    
#> [16] "imbalance"  "cmbp-1"     "cbbo-1s"    "cbbo-1m"    "tcbbo"     
db_stypes()
#> [1] "raw_symbol"    "instrument_id" "parent"        "continuous"   
```
