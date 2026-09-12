# Request construction, all offline. These assert the bytes databentoR would
# put on the wire; test-wire.R then compares them with the Python client's.

test_that("every request carries auth, the base URL and a user agent", {
  req <- capture_request(db_list_datasets())
  expect_match(req$url, "^https://hist\\.databento\\.com/v0/metadata\\.list_datasets")
  expect_false(is.null(req$headers[["Authorization"]]))
  ua <- c(req$options$useragent, req$headers[["User-Agent"]])
  expect_match(paste(ua, collapse = " "), "databentoR")
})

test_that("a missing key fails with an actionable message", {
  withr::local_envvar(DATABENTO_API_KEY = "")
  expect_error(databentoR:::.db_key(), "DATABENTO_API_KEY")
  expect_false(db_has_key())
  withr::local_envvar(DATABENTO_API_KEY = "YOUR_API_KEY")
  expect_error(databentoR:::.db_key(), "placeholder")
})

test_that("metadata.get_cost is a POST whose body matches the Python client", {
  req <- capture_request(db_get_cost("GLBX.MDP3", start = "2020-12-28T12:00",
                                     end = "2020-12-29", symbols = "ESH1",
                                     schema = "mbo"))
  expect_equal(request_method(req), "POST")
  expect_equal(request_body(req), c(
    dataset = "GLBX.MDP3", start = "2020-12-28T12:00", end = "2020-12-29",
    symbols = "ESH1", schema = "mbo", stype_in = "raw_symbol",
    stype_out = "instrument_id"
  ))
})

test_that("metadata.get_record_count sends no stype_out and orders as Python", {
  req <- capture_request(db_get_record_count(
    "GLBX.MDP3", start = "2020-12-28T12:00", end = "2020-12-29",
    symbols = "ESH1", schema = "mbo", limit = 1000000))
  expect_equal(request_body(req), c(
    dataset = "GLBX.MDP3", symbols = "ESH1", schema = "mbo",
    start = "2020-12-28T12:00", end = "2020-12-29", stype_in = "raw_symbol",
    limit = "1000000"
  ))
})

test_that("timeseries.get_range asks for CSV with the text-encoding flags", {
  req <- capture_request(db_get_range(
    "GLBX.MDP3", start = "2020-12-28T12:00", end = "2020-12-29",
    symbols = "ES.c.0", schema = "trades", stype_in = "continuous"))
  expect_equal(request_method(req), "POST")
  body <- request_body(req)
  expect_equal(body[["encoding"]], "csv")
  expect_equal(body[["compression"]], "none")
  expect_equal(body[["symbols"]], "ES.c.0")
  expect_equal(body[["stype_out"]], "instrument_id")
  expect_equal(unname(body[c("pretty_px", "pretty_ts", "map_symbols")]),
               c("true", "true", "true"))
  # `end` is appended last, exactly as the Python client appends it
  expect_equal(names(body)[length(body)], "end")
})

test_that("an omitted end is left out of the body entirely", {
  req <- capture_request(db_get_range("GLBX.MDP3", start = "2020-12-28",
                                      symbols = "ESH1"))
  expect_false("end" %in% names(request_body(req)))
})

test_that("the billed endpoint is not retried", {
  withr::local_envvar(DATABENTO_API_KEY = "db-testkeytestkeytestkeytestkey12")
  billed <- databentoR:::.db_build("timeseries.get_range", "POST",
                                   list(dataset = "X"), billed = TRUE)
  free <- databentoR:::.db_build("metadata.list_datasets", "GET")
  expect_null(billed$policies$retry_max_tries)
  expect_equal(free$policies$retry_max_tries, 4L)
})

test_that("symbology.resolve matches the Python body", {
  req <- capture_request(db_resolve("GLBX.MDP3", "ESH1",
                                    stype_in = "raw_symbol",
                                    stype_out = "instrument_id",
                                    start_date = "2020-12-28",
                                    end_date = "2020-12-29"))
  expect_equal(request_body(req), c(
    dataset = "GLBX.MDP3", symbols = "ESH1", stype_in = "raw_symbol",
    stype_out = "instrument_id", start_date = "2020-12-28",
    end_date = "2020-12-29"
  ))
})

test_that("batch.submit_job sends Python-style booleans in Python's order", {
  req <- capture_request(db_batch_submit_job(
    "GLBX.MDP3", "ESH1", "mbo", "2020-12-28T12:00", end = "2020-12-29"))
  body <- request_body(req)
  expect_equal(names(body), c(
    "dataset", "start", "end", "symbols", "schema", "stype_in", "stype_out",
    "encoding", "compression", "pretty_px", "pretty_ts", "map_symbols",
    "split_symbols", "split_duration", "delivery"
  ))
  expect_equal(unname(body[c("pretty_px", "pretty_ts", "map_symbols")]),
               c("False", "False", "False"))
  expect_equal(body[["encoding"]], "dbn")
})

test_that("batch.submit_job turns map_symbols on for the text encodings", {
  req <- capture_request(db_batch_submit_job(
    "GLBX.MDP3", "ESH1", "mbo", "2020-12-28T12:00", encoding = "csv"))
  expect_equal(request_body(req)[["map_symbols"]], "True")
})

test_that("batch.list_jobs sends the default states and a capitalised short", {
  req <- capture_request(db_batch_list_jobs(short = TRUE))
  q <- request_query(req)
  expect_equal(q[["states"]], "queued,processing,done")
  expect_equal(q[["short"]], "True")
})

test_that("the two public reference endpoints send no credentials", {
  req <- capture_request(db_corporate_action_events())
  expect_null(req$headers[["Authorization"]])
  req <- capture_request(db_security_master_last(symbols = "AAPL"))
  expect_false(is.null(req$headers[["Authorization"]]))
})

test_that("reference filters are joined with commas and dropped when empty", {
  req <- capture_request(db_adjustment_factors(
    start = "2024-01-01", symbols = "AAPL",
    countries = c("US", "CA"), security_types = NULL))
  body <- request_body(req)
  expect_equal(body[["countries"]], "US,CA")
  expect_false("security_types" %in% names(body))
  expect_equal(body[["allocate_isins"]], "True")
  expect_equal(body[["compression"]], "zstd")
})
