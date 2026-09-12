# Full live coverage: every exported function against the real API.
#
# This is the expensive suite. It is deliberately NOT wired into any GitHub
# workflow; it runs only when you ask for it:
#
#   DATABENTOR_RUN_COVERAGE=true Rscript -e 'devtools::test(filter = "coverage")'
#
# Cost, measured 2026-09-12: about 0.40 USD per pass. Every slice sits inside
# one 15-minute billing chunk, which is the floor for its schema, so the price
# is driven by how many schemas are touched rather than by window length.
# `dev/equivalence/quote.R` prices it before you run it.

m0 <- "2024-01-02T14:30"  # one minute, inside a single 15-minute chunk
m1 <- "2024-01-02T14:31"
d0 <- "2024-01-02"
d1 <- "2024-01-03"

# dataset, schema, symbols, stype_in, start, end
slices <- list(
  list("GLBX.MDP3", "mbo",        "ES.c.0",  "continuous", m0, m1),
  list("GLBX.MDP3", "mbp-1",      "ES.c.0",  "continuous", m0, m1),
  list("GLBX.MDP3", "mbp-10",     "ES.c.0",  "continuous", m0, m1),
  list("GLBX.MDP3", "tbbo",       "ES.c.0",  "continuous", m0, m1),
  list("GLBX.MDP3", "trades",     "ES.c.0",  "continuous", m0, m1),
  list("GLBX.MDP3", "bbo-1s",     "ES.c.0",  "continuous", m0, m1),
  list("GLBX.MDP3", "bbo-1m",     "ES.c.0",  "continuous", m0, m1),
  list("GLBX.MDP3", "ohlcv-1s",   "ES.c.0",  "continuous", m0, m1),
  list("GLBX.MDP3", "ohlcv-1m",   "ES.c.0",  "continuous", m0, m1),
  list("GLBX.MDP3", "ohlcv-1h",   "ES.c.0",  "continuous", m0, m1),
  list("GLBX.MDP3", "ohlcv-1d",   "ES.c.0",  "continuous", d0, d1),
  list("GLBX.MDP3", "definition", "ES.FUT",  "parent",     d0, d1),
  list("GLBX.MDP3", "statistics", "ES.FUT",  "parent",     d0, d1),
  list("GLBX.MDP3", "status",     "ES.FUT",  "parent",     d0, d1),
  list("OPRA.PILLAR", "trades",     "SPX.OPT", "parent",   m0, m1),
  list("OPRA.PILLAR", "ohlcv-1d",   "SPX.OPT", "parent",   d0, d1),
  list("OPRA.PILLAR", "definition", "SPX.OPT", "parent",   d0, d1),
  list("OPRA.PILLAR", "statistics", "SPX.OPT", "parent",   d0, d1),
  list("XNAS.ITCH", "trades",     "AAPL", "raw_symbol",    m0, m1),
  list("XNAS.ITCH", "imbalance",  "AAPL", "raw_symbol",    d0, d1),
  list("XNAS.ITCH", "status",     "AAPL", "raw_symbol",    d0, d1),
  list("XNAS.ITCH", "definition", "AAPL", "raw_symbol",    d0, d1)
)

test_that("every schema downloads and types itself correctly", {
  skip_unless_coverage()

  for (s in slices) {
    label <- paste(s[[1]], s[[2]])
    tb <- tryCatch(
      db_get_range(dataset = s[[1]], start = s[[5]], end = s[[6]],
                   symbols = s[[3]], schema = s[[2]], stype_in = s[[4]]),
      error = function(e) e
    )
    if (inherits(tb, "error")) {
      # An unsupported dataset/schema pair is the server's answer, not a bug.
      expect_match(conditionMessage(tb), "not_supported|422", label = label)
      next
    }

    expect_s3_class(tb, "tbl_df")
    if (!nrow(tb)) next

    # The inference trap: a Databento CSV has no boolean column, so a logical
    # one means arrow guessed instead of databentoR assigning.
    expect_false(any(vapply(tb, is.logical, logical(1))), label = label)

    # The leading field is the record's timestamp, and map_symbols appends
    # symbol last.
    expect_true(names(tb)[1L] %in% c("ts_recv", "ts_event"), label = label)
    expect_equal(names(tb)[ncol(tb)], "symbol", label = label)

    # Every column carries the class its kind implies.
    kinds <- db_field_types(names(tb), schema = s[[2]])
    for (i in seq_along(tb)) {
      col <- tb[[i]]
      switch(kinds$kind[i],
        timestamp = expect_s3_class(col, "POSIXct"),
        price     = expect_type(col, "double"),
        character = expect_type(col, "character"),
        expect_true(is.numeric(col) || inherits(col, "integer64"),
                    label = paste(label, names(tb)[i]))
      )
    }
  }
})

test_that("the built-in field table agrees with the API for every schema", {
  skip_unless_coverage()
  # The API reports only "int" or "string", so it cannot tell a fixed-point
  # price from a plain integer. What it can settle is the text/number split,
  # and that is the one that corrupts data silently when it is wrong.
  for (schema in db_schemas()) {
    fields <- tryCatch(db_list_fields(schema, "csv", dataset = "GLBX.MDP3"),
                       error = function(e) NULL)
    if (is.null(fields) || !nrow(fields)) next
    kinds <- db_field_types(fields$name, schema = schema)$kind

    is_text <- fields$type == "string"
    expect_equal(kinds[is_text], rep("character", sum(is_text)),
                 label = paste(schema, "fields the API calls string"))
    expect_false(any(kinds[!is_text] == "character"),
                 label = paste(schema, "fields the API calls int"))
  }
})

test_that("a batch job can be submitted, polled, downloaded and read back", {
  skip_unless_coverage()

  job <- db_batch_submit_job(
    dataset = "GLBX.MDP3", symbols = "ES.FUT", schema = "ohlcv-1d",
    start = "2024-01-02", end = "2024-01-09", stype_in = "parent",
    encoding = "csv", compression = "none", pretty_px = TRUE, pretty_ts = TRUE
  )
  expect_s3_class(job, "tbl_df")
  expect_true("id" %in% names(job))
  job_id <- job$id[[1L]]
  expect_true(nzchar(job_id))

  details <- db_batch_get_job_details(job_id)
  expect_equal(details$id[[1L]], job_id)

  listed <- db_batch_list_jobs(states = c("queued", "processing", "done"))
  expect_true(job_id %in% listed$id)

  short <- db_batch_list_jobs(states = "done", short = TRUE)
  expect_s3_class(short, "tbl_df")

  # Poll until the server finishes, but do not hang the suite.
  deadline <- Sys.time() + 600
  state <- NA_character_
  repeat {
    state <- db_batch_get_job_details(job_id)$state[[1L]]
    if (identical(state, "done") || Sys.time() > deadline) break
    Sys.sleep(20)
  }
  skip_if(!identical(state, "done"),
          paste("batch job still", state, "after ten minutes"))

  files <- db_batch_list_files(job_id)
  expect_s3_class(files, "tbl_df")
  expect_gt(nrow(files), 0)
  expect_true(all(c("filename", "hash", "size", "url") %in% names(files)))

  dir <- withr::local_tempdir()
  written <- db_batch_download(job_id, output_dir = dir)
  expect_true(length(written) > 0)
  expect_true(all(file.exists(written)))

  # The job's own output must agree with the streamed download.
  csv <- written[grepl("\\.csv$", written)]
  skip_if(!length(csv), "batch job produced no plain csv file")
  # split_duration defaults to "day", so the job writes one file per
  # trading day and they have to be stitched back together.
  batched <- do.call(rbind, lapply(csv, databentoR:::.db_read_csv))
  streamed <- db_get_range("GLBX.MDP3", start = "2024-01-02", end = "2024-01-09",
                           symbols = "ES.FUT", schema = "ohlcv-1d",
                           stype_in = "parent")
  ord <- function(tb) tb[do.call(order, unname(as.list(tb))), , drop = FALSE]
  expect_equal(nrow(batched), nrow(streamed))
  expect_equal(names(batched), names(streamed))
  expect_equal(ord(batched), ord(streamed))
})

test_that("the reference endpoints answer, or say why not", {
  skip_unless_coverage()

  # These two are public; the Python client sends no credentials either.
  events <- tryCatch(db_corporate_action_events(), error = function(e) e)
  if (inherits(events, "error")) {
    expect_match(conditionMessage(events), "40[0-9]|entitle|subscription")
  } else {
    expect_s3_class(events, "tbl_df")
    expect_gt(nrow(events), 0)
  }

  enums <- tryCatch(db_corporate_action_enums(), error = function(e) e)
  if (!inherits(enums, "error")) expect_type(enums, "list")

  # The billed reference endpoints share one zstd JSON-lines reader, so each
  # either returns a tibble or reports an entitlement problem.
  calls <- list(
    adjustment_factors = function() {
      db_adjustment_factors(start = "2024-01-02", end = "2024-01-09",
                            symbols = "AAPL")
    },
    corporate_actions = function() {
      db_corporate_actions(start = "2024-01-02", end = "2024-01-09",
                           symbols = "AAPL")
    },
    security_master = function() {
      db_security_master(start = "2024-01-02", end = "2024-01-09",
                         symbols = "AAPL")
    },
    security_master_last = function() db_security_master_last(symbols = "AAPL")
  )
  for (name in names(calls)) {
    out <- tryCatch(calls[[name]](), error = function(e) e)
    if (inherits(out, "error")) {
      testthat::skip(paste0(name, ": ", conditionMessage(out)))
    }
    expect_s3_class(out, "tbl_df", label = name)
  }
})

test_that("symbology resolves across every input symbol type", {
  skip_unless_coverage()

  for (spec in list(
    list("GLBX.MDP3", "ES.FUT", "parent"),
    list("GLBX.MDP3", "ES.c.0", "continuous"),
    list("GLBX.MDP3", "ESH4", "raw_symbol"),
    list("XNAS.ITCH", "AAPL", "raw_symbol")
  )) {
    res <- db_resolve(spec[[1]], spec[[2]], stype_in = spec[[3]],
                      start_date = "2024-01-02", end_date = "2024-01-09")
    expect_s3_class(res, "tbl_df")
    expect_equal(names(res),
                 c("input_symbol", "start_date", "end_date", "symbol"))
    expect_gt(nrow(res), 0)
  }
})

test_that("the remaining metadata endpoints answer for every dataset", {
  skip_unless_coverage()
  for (ds in c("GLBX.MDP3", "OPRA.PILLAR", "XNAS.ITCH")) {
    expect_type(db_list_schemas(ds), "character")
    expect_s3_class(db_get_dataset_range(ds), "tbl_df")
    expect_s3_class(db_get_dataset_condition(ds, d0, d1), "tbl_df")
    prices <- db_list_unit_prices(ds)
    expect_true(is.data.frame(prices) || is.list(prices))
  }
})
