test_that("request is built with auth, base URL and query params (offline)", {
  withr::local_envvar(DATABENTO_API_KEY = "db-test-key")
  req <- databentoR:::.db_req("metadata.get_cost") |>
    databentoR:::.db_query("GLBX.MDP3", "ohlcv-1d", c("ES.FUT", "ZQ.FUT"),
                           "2024-01-01", "2024-02-01")
  expect_s3_class(req, "httr2_request")
  expect_match(req$url, "^https://hist\\.databento\\.com/v0/metadata\\.get_cost")
  expect_match(req$url, "dataset=GLBX\\.MDP3")
  expect_match(req$url, "symbols=ES\\.FUT%2CZQ\\.FUT|symbols=ES\\.FUT,ZQ\\.FUT")
  expect_match(req$url, "stype_in=parent")
  expect_false(is.null(req$headers[["Authorization"]]))
})

test_that("missing key gives a helpful error", {
  withr::local_envvar(DATABENTO_API_KEY = "")
  expect_error(databentoR:::.db_key(), "DATABENTO_API_KEY")
  expect_false(db_has_key())
})
