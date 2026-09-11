# Live tests: run only with a configured key, never on CRAN.
# Each request is deliberately tiny (cost << 0.01 USD; metadata is free).

skip_if_no_key <- function() {
  testthat::skip_on_cran()
  testthat::skip_if(!db_has_key(), "DATABENTO_API_KEY not set")
}

test_that("metadata endpoints respond", {
  skip_if_no_key()
  ds <- db_list_datasets()
  expect_true(is.character(ds) && length(ds) > 0)
  expect_true("GLBX.MDP3" %in% ds)
  sc <- db_list_schemas("GLBX.MDP3")
  expect_true(all(c("ohlcv-1d", "ohlcv-1m", "definition") %in% sc))
})

test_that("cost preview returns a small number for a tiny slice", {
  skip_if_no_key()
  cost <- db_get_cost("GLBX.MDP3", "ohlcv-1d", "ES.FUT",
                      start = "2024-01-02", end = "2024-01-09")
  expect_true(is.numeric(cost) && length(cost) == 1 && !is.na(cost))
  expect_lt(cost, 0.05)
})

test_that("get_range returns a non-empty tibble for a tiny slice", {
  skip_if_no_key()
  tb <- db_get_range("GLBX.MDP3", "ohlcv-1d", "ES.FUT",
                     start = "2024-01-02", end = "2024-01-09")
  expect_s3_class(tb, "tbl_df")
  expect_gt(nrow(tb), 0)
  expect_true(all(c("open", "high", "low", "close", "volume") %in% names(tb)))
  expect_true("symbol" %in% names(tb))  # map_symbols=true
})
