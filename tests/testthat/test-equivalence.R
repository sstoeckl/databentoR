# Equivalence vs. the official Python client (protocol: dev/equivalence/).
# Reference fixtures are produced ONCE by dev/equivalence/make_reference.py
# (QA-only Python) and stored UNTRACKED under dev/equivalence/reference/.
# This test compares the live R download 1:1 against the frozen reference.

ref_dir <- function() {
  testthat::test_path("..", "..", "dev", "equivalence", "reference")
}

test_that("R output equals Python-client reference (ES ohlcv-1d Jan 2024)", {
  testthat::skip_on_cran()
  testthat::skip_if(!db_has_key(), "DATABENTO_API_KEY not set")
  ref_file <- file.path(ref_dir(), "glbx_es_ohlcv1d_2024-01.parquet")
  testthat::skip_if(!file.exists(ref_file),
                    "reference fixture missing (run dev/equivalence/make_reference.py)")

  ref <- tibble::as_tibble(arrow::read_parquet(ref_file))
  got <- db_get_range("GLBX.MDP3", "ohlcv-1d", "ES.FUT",
                      start = "2024-01-01", end = "2024-02-01")

  expect_equal(nrow(got), nrow(ref))
  for (col in intersect(c("open", "high", "low", "close", "volume"),
                        intersect(names(got), names(ref)))) {
    expect_equal(as.numeric(got[[col]]), as.numeric(ref[[col]]),
                 tolerance = 1e-12, label = paste("column", col))
  }
  if (all(c("symbol") %in% names(got)) && "symbol" %in% names(ref)) {
    expect_equal(sort(unique(got$symbol)), sort(unique(ref$symbol)))
  }
})
