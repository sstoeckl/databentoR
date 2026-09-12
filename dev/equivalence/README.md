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
according to its kind:

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
4. **Unsigned 64-bit fields.** R has no unsigned integer type. `order_id` and
   `raw_instrument_id` are exact below `2^53` and would lose precision above
   it; no venue observed so far comes close.
5. **`pretty_ts` collapses two cases.** The CSV encoder writes an empty field
   both for an undefined timestamp and for a literal zero, while `to_df()`
   distinguishes them. Request `pretty_ts = FALSE` (which `ts_type =
   "integer64"` does) if that distinction matters.

## Layer 3 — upstream watch (weekly)

`.github/workflows/upstream-watch.yaml` compares the pin with the newest
upstream release. When there is a new one it re-captures the wire fixture with
that release, diffs it against the committed fixture, and opens an issue that
names the parameters, endpoints and enum values that changed, together with
the changelog delta. So the alert is never "a new version exists" but "these
are the calls you have to fix".

## Free-of-charge notes

Every `metadata.*` endpoint is free, including cost and record-count previews,
so layer 1 and most of `test-live.R` cost nothing. Only the slices in layer 2
are billed, at fractions of a cent each.
