# databentoR

R client for the [Databento](https://databento.com) historical market
data HTTP API — cost previews, metadata, and range downloads returned as
**tibbles** or written to **parquet**. Mirrors the interface of the
official Python client (`metadata.get_cost`, `timeseries.get_range`, …)
without Python and without the binary DBN format: it uses the CSV
encoding of the REST API (`https://hist.databento.com/v0`).

There is currently **no official R client** for Databento (only Python,
C++, Rust) — this package fills that gap.

## Install (development version)

```r
# not yet on CRAN/GitHub — local development package
devtools::load_all("path/to/databentoR")
```

## Authentication

Set your API key **once** as an environment variable — never in code:

```
setx DATABENTO_API_KEY "db-XXXX..."   # Windows, then open a new session
```

## Usage

```r
library(databentoR)

db_has_key()
db_list_datasets()
db_list_schemas("GLBX.MDP3")

# ALWAYS preview the cost first (previews are free, downloads are billed):
db_get_cost("GLBX.MDP3", "ohlcv-1d", "ES.FUT",
            start = "2024-01-01", end = "2024-02-01")

# Then download (tibble; optionally also written as parquet via `path=`):
es <- db_get_range("GLBX.MDP3", "ohlcv-1d", "ES.FUT",
                   start = "2024-01-01", end = "2024-02-01")
```

`stype_in = "parent"` (default) accepts product-level symbols such as
`"ES.FUT"`, `"ZQ.FUT"`, or `"SPX.OPT"`.

## Equivalence testing vs. the official Python client

`dev/equivalence/` contains the protocol: tiny fixed request slices are
frozen as reference parquet files with the official Python client
(QA-only) and the R output is compared 1:1 in
`tests/testthat/test-equivalence.R` (skipped when no key/fixtures are
present). See `dev/equivalence/README.md`.

**Do not commit downloaded market data** — the Databento license does not
permit redistribution; reference fixtures stay untracked.

## License

MIT © Sebastian Stöckl
