# The published attestation must never carry a field value.
#
# `dev/equivalence/report.R` lives outside the package, so these skip on CRAN
# and anywhere the source tree is not to hand.

report_source <- testthat::test_path("..", "..", "dev", "equivalence", "report.R")

skip_without_report <- function() {
  testthat::skip_if(!file.exists(report_source), "dev/equivalence/report.R absent")
}

fake_results <- function() {
  data.frame(
    dataset = c("GLBX.MDP3", "GLBX.MDP3"),
    schema = c("ohlcv-1d", "trades"),
    rows = c(49L, 4810L),
    columns = c(10L, 14L),
    columns_compared = c(10L, 14L),
    columns_identical = c(10L, 14L),
    max_rel_deviation = c(0, 1.1e-16),
    verdict = c("PASS", "PASS"),
    stringsAsFactors = FALSE
  )
}

fake_meta <- function() {
  list(date = "2026-09-12 08:00 UTC", r_version = "0.1.0",
       py_version = "0.86.0", endpoints = 28L)
}

test_that("the report renders verdicts and shapes", {
  skip_without_report()
  env <- new.env()
  sys.source(report_source, env)

  md <- env$equivalence_report(fake_results(), fake_meta())
  text <- paste(md, collapse = "\n")

  expect_match(text, "Equivalence attestation")
  expect_match(text, "databento-python 0\\.86\\.0")
  expect_match(text, "28 endpoints")
  expect_match(text, "2 of 2 slices identical")
  expect_match(text, "ohlcv-1d")
  expect_match(text, "PASS")
})

test_that("the report refuses to render a column outside the whitelist", {
  skip_without_report()
  env <- new.env()
  sys.source(report_source, env)

  # A results frame that has picked up actual market data must be rejected
  # rather than quietly printed.
  leaky <- fake_results()
  leaky$open <- c(4818.25, 3702.75)
  leaky$symbol <- c("ESH4", "ESH4")

  expect_error(env$equivalence_report(leaky, fake_meta()), "leak")
  expect_error(env$equivalence_report(leaky, fake_meta()), "open")
})

test_that("no price, symbol or timestamp value reaches the rendered report", {
  skip_without_report()
  env <- new.env()
  sys.source(report_source, env)

  md <- env$equivalence_report(fake_results(), fake_meta())
  text <- paste(md, collapse = "\n")

  # Nothing that looks like a traded price, an instrument symbol or a
  # nanosecond timestamp may appear.
  expect_no_match(text, "4818|3702|ESH4|ESU4")
  expect_no_match(text, "[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:")
  expect_no_match(text, "[0-9]{13,}")

  # The rendered table header is exactly the whitelist, in order.
  header <- grep("^[|] dataset", md, value = TRUE)
  expect_length(header, 1L)
  cells <- trimws(strsplit(gsub("^[|]|[|]$", "", header), "|", fixed = TRUE)[[1]])
  expect_equal(cells, env$REPORT_COLUMNS)
})
