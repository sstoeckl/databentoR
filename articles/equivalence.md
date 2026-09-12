# Equivalence with the official Python client

A second implementation of an API is only worth having if you can show
it agrees with the first. databentoR makes that a test rather than a
claim.

The official client is pinned as a git submodule at
`dev/python-reference`, so every fixture in the repository describes one
exact version of it. Two independent layers check agreement, and a third
watches for the reference moving underneath us.

## Layer 1: the same request

`dev/equivalence/wire_capture.py` imports the pinned Python client,
replaces its HTTP transport with a stub that records the call and aborts
it, and walks all 28 endpoints of the historical and reference APIs. No
network, no API key, no money.

The recording is committed as
`tests/testthat/fixtures/python_wire.json`. It contains endpoint names,
parameter names and parameter values from synthetic arguments, plus the
compiled DBN enum value sets. No market data and no credentials.

`test-wire.R` then builds the same request in R for every entry and
asserts the HTTP method, the endpoint, and the parameter names, values
**and order**. For example, the Python client’s own test suite pins this
body for `metadata.get_record_count`:

    dataset=GLBX.MDP3&symbols=ESH1&schema=mbo&start=2020-12-28T12:00
    &end=2020-12-29&stype_in=raw_symbol&limit=1000000

and databentoR produces it field for field, in that order, from

``` r

db_get_record_count("GLBX.MDP3", start = "2020-12-28T12:00", end = "2020-12-29",
                    symbols = "ESH1", schema = "mbo", limit = 1000000)
```

This layer runs on every push, on three operating systems, at no cost.
It catches the things that are easy to get wrong and hard to notice:

- Three `metadata.get_*` endpoints are POSTs with a form body, not GETs,
  despite what their docstrings say.
- `get_cost` and `get_billable_size` always pin
  `stype_out=instrument_id`; `get_record_count` sends no `stype_out` at
  all.
- Form-body booleans go on the wire as `True`/`False`, while the
  text-encoding flags are lower-case `true`/`false`.
- An omitted `end` must be dropped from the body, not sent empty,
  because the server forward-fills from `start` when it is absent.
- `symbols = NULL` becomes the literal string `ALL_SYMBOLS`.

It also asserts that
[`db_schemas()`](https://www.sebastianstoeckl.com/databentoR/reference/db_enums.md),
[`db_encodings()`](https://www.sebastianstoeckl.com/databentoR/reference/db_enums.md)
and
[`db_compressions()`](https://www.sebastianstoeckl.com/databentoR/reference/db_enums.md)
still equal the compiled DBN enums, so a schema added upstream fails the
test suite rather than a user’s request.

``` r

db_schemas()
#>  [1] "mbo"        "mbp-1"      "mbp-10"     "bbo-1s"     "bbo-1m"    
#>  [6] "tbbo"       "trades"     "ohlcv-1s"   "ohlcv-1m"   "ohlcv-1h"  
#> [11] "ohlcv-1d"   "ohlcv-eod"  "definition" "statistics" "status"    
#> [16] "imbalance"  "cmbp-1"     "cbbo-1s"    "cbbo-1m"    "tcbbo"
```

### The one deliberate divergence

`timeseries.get_range` is where the clients differ on purpose. The
Python client hard-codes `encoding=dbn` with `compression=zstd` and
decodes the binary format locally. databentoR asks for `encoding=csv`
and sends the three text-encoding flags the HTTP API documents for this
endpoint, because the server defaults all three to false:

| Parameter     | Python client | databentoR                           |
|---------------|---------------|--------------------------------------|
| `encoding`    | `dbn`         | `csv`                                |
| `compression` | `zstd`        | `none` by default, `zstd` on request |
| `pretty_px`   | not sent      | `true`                               |
| `pretty_ts`   | not sent      | `true`                               |
| `map_symbols` | not sent      | `true`                               |

Every other parameter still has to match, and the test asserts the
divergence is exactly this and nothing more.

## Layer 2: the same data

`dev/equivalence/make_reference.py` downloads six deliberately tiny
slices through the pinned Python client and freezes each as parquet in
the shape `to_df()` produces: `price_type="float"`, `pretty_ts`,
`map_symbols`, then `reset_index()`, because `to_df()` makes the leading
timestamp the frame’s index while the CSV encoding keeps it as the first
column. The script refuses to download anything if the quoted total
exceeds fifty US cents.

The slices span `ohlcv-1d`, `trades`, `tbbo`, `mbp-1`, `statistics` and
`definition`, which between them exercise every column kind: prices,
nanosecond timestamps, unsigned counts, single characters and
fixed-width text.

`test-equivalence.R` pulls the same slices through databentoR and
compares row count, column names, column order, then each column by
kind. Both frames are sorted first, because the server does not promise
a stable order among records that share a timestamp: two consecutive
downloads of the daily-bar slice were measured disagreeing on 47 of 49
row positions while holding identical data.

- **Prices** to a relative tolerance of `1e-12`. Both paths end at the
  IEEE-754 double nearest to `fixed / 1e9`, one by parsing a
  nine-decimal string and one by dividing an int64, and they agree bit
  for bit below `2^53`. The tolerance is loose enough never to fire on
  that, and roughly a thousand times tighter than one unit of the 1e-9
  grid, so a genuine scaling or rounding bug cannot hide inside it.
- **Timestamps** as instants, exactly when `ts_type = "integer64"`.
- **Counts, flags and sequence numbers** exactly.
- **Text** exactly, after normalising the empty field.

One full run makes 17 billed downloads, about 0.27 US dollars at the
rates measured in September 2026. Databento bills intraday requests in
15-minute chunks, so a one-minute and a ten-minute window of the same
instrument and schema are quoted identically, while a whole day costs
about sixteen times a single chunk. The slices here therefore sit inside
one chunk each, which is the floor for their schema.
`dev/equivalence/quote.R` prices a run using only the free preview
endpoints.

Layer 2 spends money, so it needs both a key and an explicit opt-in:

    DATABENTOR_RUN_LIVE=true Rscript -e 'devtools::test()'

Without fixtures or a key it skips cleanly, which is what keeps the
package CRAN-safe.

## The differences that remain

Five, all documented rather than papered over. Row order is not among
them: it is unstable on both sides, a property of the service rather
than of either client.

1.  **Index versus column.** `to_df()` returns a frame indexed by
    `ts_recv` (or `ts_event` for OHLCV). A tibble has no index, so
    databentoR keeps that field as the first column, which is where the
    CSV encoding puts it anyway.
2.  **Empty text fields** are `""` in pandas and `NA` in R.
3.  **Timestamp resolution.** `POSIXct` is a double count of seconds, so
    on modern dates it resolves to about a quarter of a microsecond. Use
    `ts_type = "integer64"` when nanoseconds matter.
4.  **Unsigned 64-bit fields.** R has no unsigned integer type, so
    fields that are 64-bit on the wire come back as
    [`bit64::integer64`](https://bit64.r-lib.org/reference/bit64-package.html).
    That is what keeps `order_id`, `raw_instrument_id` and an undefined
    statistics `quantity` intact; the last of those is the int64
    maximum, which no double can hold.
5.  **`pretty_ts` collapses two cases.** The CSV encoder writes an empty
    field both for an undefined timestamp and for a literal zero, while
    `to_df()` distinguishes them. `ts_type = "integer64"` requests raw
    timestamps and keeps the distinction.

## The published attestation

This vignette documents the method. The *result* is published
separately, because a vignette has to build offline from the package
tarball and a live comparison cannot. Each weekly run writes an
attestation to the workflow’s own summary and commits it to
[`dev/equivalence/LAST-RUN.md`](https://github.com/sstoeckl/databentoR/blob/master/dev/equivalence/LAST-RUN.md),
so the repository carries a dated history of the comparison.

That report states verdicts and shapes and nothing else: rows and
columns compared, columns matched, the largest relative deviation, pass
or fail. It contains no field values at all. No sample rows, no
extracts, and no summary statistics either, since a minimum or mean
price is derived market data rather than a fact about the software.
Column names and types are safe because Databento publishes them itself;
the values under them are not, and never reach the report.
`tests/testthat/test-report.R` asserts it, and the generator refuses
outright to render a column outside its whitelist.

## Layer 3: watching the reference

A weekly workflow compares the pinned submodule with the newest upstream
release. When there is a new one it re-captures the wire fixture against
that release, diffs it against the committed fixture, and opens an issue
naming the parameters, endpoints and enum values that changed, with the
changelog delta attached.

So the alert is never “a new version exists”. It is “these are the calls
you have to fix”.

## Reproducing it

    git submodule update --init --recursive
    pip install ./dev/python-reference
    python dev/equivalence/wire_capture.py
    Rscript -e 'devtools::test()'

The full protocol, including how to add a slice, is in
`dev/equivalence/README.md`.
