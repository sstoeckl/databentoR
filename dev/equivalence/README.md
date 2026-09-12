# Equivalence protocol: databentoR vs. the official Python client

The goal is narrow and testable: for the same arguments, databentoR must send
the same request as the official Databento Python client, and must give back
the same data. Two independent layers check that, plus a watcher that tells us
when the reference itself has moved.

The reference client is pinned as a git submodule at `dev/python-reference`.
It is never a floating dependency: every fixture in this repository describes
one exact version of it.

```
git submodule update --init --recursive
pip install ./dev/python-reference
```

## Layer 1 — wire equivalence (offline, free, runs on every push)

`wire_capture.py` imports the pinned client, replaces `requests.get` and
`requests.post` with a stub that records the call and aborts it, and walks
every endpoint of the historical and reference APIs. No network, no API key,
no money. The result is

```
tests/testthat/fixtures/python_wire.json
```

which is committed: it holds only endpoint names, parameter names and
parameter values from synthetic arguments, plus the DBN enum value sets. No
market data, no credentials.

`tests/testthat/test-wire.R` then builds the same request in R for each entry
and asserts, per endpoint:

* the HTTP method,
* the endpoint the URL resolves to,
* the parameter names, their values **and their order**.

It also asserts that `db_schemas()`, `db_encodings()` and `db_compressions()`
still equal the compiled DBN enums, so a schema added upstream fails the suite
instead of failing a user's request.

Regenerate after changing the pin:

```
pip install ./dev/python-reference
python dev/equivalence/wire_capture.py
```

The `equivalence` workflow regenerates the fixture in CI and fails if the
committed copy is stale.

### The one deliberate divergence

`timeseries.get_range` is where the two clients differ on purpose. The Python
client hard-codes `encoding=dbn` and `compression=zstd` and decodes the binary
format locally. databentoR asks for `encoding=csv` and sends the three
text-encoding flags (`pretty_px`, `pretty_ts`, `map_symbols`), which the HTTP
API documents for this endpoint and defaults to `false`. Every other parameter
still has to match, and `test-wire.R` asserts the divergence is exactly this
and nothing more.

## Layer 2 — data equivalence (live, needs a key, costs cents)

`make_reference.py` downloads six deliberately tiny slices through the pinned
Python client and writes each as parquet in the shape `to_df()` produces
(`price_type="float"`, `pretty_ts`, `map_symbols`, then `reset_index()` so the
timestamp index becomes the first column again, which is where the CSV
encoding puts it). It refuses to download anything if the quoted total exceeds
50 US cents.

| Fixture | Request |
|---|---|
| `glbx_es_ohlcv1d` | GLBX.MDP3, ohlcv-1d, ES.FUT (parent), 2024-01-02 → 2024-01-09 |
| `glbx_es_trades` | GLBX.MDP3, trades, ES.c.0 (continuous), one minute |
| `glbx_es_tbbo` | GLBX.MDP3, tbbo, ES.c.0 (continuous), one minute |
| `glbx_es_mbp1` | GLBX.MDP3, mbp-1, ES.c.0 (continuous), thirty seconds |
| `glbx_es_statistics` | GLBX.MDP3, statistics, ES.FUT (parent), one day |
| `glbx_es_definition` | GLBX.MDP3, definition, ES.FUT (parent), one day |

**The output is never committed.** Databento's licence does not permit
redistributing market data, so `reference/` is gitignored. Adding a slice
means editing `make_reference.py` and this table together.

`tests/testthat/test-equivalence.R` pulls the same slices through databentoR
and compares row count, column names, column order, and then each column
according to its kind. Both frames are ordered by every column first, because
**the server does not guarantee a stable order among records that share a
timestamp**: two downloads of the same slice, by either client, can return the
same rows in a different sequence. Measured on 2026-09-12, two consecutive R
pulls of the daily-bar slice disagreed on 47 of 49 row positions while holding
identical data. Sorting makes the comparison order-independent without hiding
a real difference, because two frames holding the same multiset of rows sort
identically.

* **prices**: relative tolerance `1e-12`. Both paths end at the IEEE-754
  double nearest to `fixed / 1e9`, one by parsing a nine-decimal string and
  one by dividing an int64. They agree bit for bit below `2^53`; the tolerance
  is loose enough never to fire on that, and far tighter than one unit of the
  1e-9 grid, so a real scaling bug still fails.
* **timestamps**: compared as instants. `db_get_range(ts_type = "integer64")`
  gives the exact nanosecond count when that matters.
* **counts, flags, sequences**: exact.
* **text**: exact after normalising the empty field. The Python client renders
  an empty text field as `""`, databentoR as `NA`; that is the one cosmetic
  difference and it is normalised on both sides rather than papered over.

Run it with a key and an explicit opt-in, because layer 2 spends money:

```
DATABENTOR_RUN_LIVE=true Rscript -e 'devtools::test()'
```

### Known differences, by design

1. **Index vs. column.** `to_df()` returns a frame indexed by `ts_recv` (or
   `ts_event`). A tibble has no index, so databentoR keeps that field as the
   first column, which is also where the CSV encoding puts it. The fixture
   builder calls `reset_index()` so the two line up.
2. **Empty text fields.** `""` in pandas, `NA` in R.
3. **Timestamp resolution.** `POSIXct` stores seconds as a double, so on
   modern dates it resolves to about a quarter of a microsecond. Use
   `ts_type = "integer64"` for exact nanoseconds.
4. **Unsigned 64-bit fields.** R has no unsigned integer type, so fields that
   are 64-bit on the wire come back as `bit64::integer64`. That is what keeps
   `order_id`, `raw_instrument_id` and an undefined statistics `quantity`
   (the int64 maximum, which no double represents) intact. Values above
   `2^63` would still not fit; none has been observed.
5. **`pretty_ts` collapses two cases.** The CSV encoder writes an empty field
   both for an undefined timestamp and for a literal zero, while `to_df()`
   distinguishes them. Request `pretty_ts = FALSE` (which `ts_type =
   "integer64"` does) if that distinction matters.

## The attestation

`report.R` turns a live run into `LAST-RUN.md`: one row per slice with the
rows and columns compared, how many columns matched, the largest relative
deviation, and a verdict. The weekly workflow writes it to the run summary and
commits it, so the repository keeps a dated history.

It carries no field values. No sample rows, no extracts, no summary statistics
of the data. The generator holds a whitelist of permitted columns and errors
rather than render anything else; `tests/testthat/test-report.R` checks that,
including that a results frame contaminated with prices and symbols is
rejected.

## Layer 3 — upstream watch (weekly)

`.github/workflows/upstream-watch.yaml` compares the pin with the newest
upstream release. When there is a new one it re-captures the wire fixture with
that release, diffs it against the committed fixture, and opens an issue that
names the parameters, endpoints and enum values that changed, together with
the changelog delta. So the alert is never "a new version exists" but "these
are the calls you have to fix".

## What a run costs

Every `metadata.*` endpoint is free, including cost and record-count previews,
so layer 1 and most of `test-live.R` cost nothing. Only range downloads are
billed.

Measured on 2026-09-12, GLBX.MDP3:

| Slice | Quoted per download |
|---|---|
| `ohlcv-1d` | 0.000486 USD |
| `trades` | 0.029645 USD |
| `tbbo` | 0.049409 USD |
| `mbp-1` | 0.039556 USD |
| `statistics` | 0.000162 USD |
| `definition` | 0.000050 USD |
| **the six together** | **0.119307 USD** |

One full scheduled run makes 17 billed downloads, roughly 0.27 USD, because
the Python fixture builder and the R suite each fetch the set.

**Windows are billed in 15-minute chunks.** Measured on 2026-09-12 with
ES.c.0 trades starting at 14:30: windows ending at 14:31, 14:35 and 14:40 all
quote 0.029645 USD over 23,684 records; ending at 14:45 or 14:50 quotes
0.050340 over 40,217; ending at 14:55, 0.066971 over 53,504. So anything
shorter than a quarter of an hour costs the same as a quarter of an hour, and
beyond that the cost scales with the window. A whole day of the same
instrument and schema is 0.467668 USD, about sixteen times one chunk.

The practical rule: keep a slice inside one 15-minute chunk and you are at the
floor for that schema; the remaining levers are how many schemas you touch and
how often.

`Rscript dev/equivalence/quote.R` prices the whole run for you, using only the
free preview endpoints.
