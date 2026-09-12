# Coercion and validation, all offline.

test_that("symbols are normalised the way the Python client normalises them", {
  expect_equal(databentoR:::.db_symbols(NULL, "raw_symbol"), "ALL_SYMBOLS")
  expect_equal(databentoR:::.db_symbols(" nvda ", "raw_symbol"), "NVDA")
  expect_equal(databentoR:::.db_symbols(c("es", "zq"), "raw_symbol"), "ES,ZQ")
  expect_equal(databentoR:::.db_symbols("ES,ZQ", "raw_symbol"), "ES,ZQ")
  # smart symbols: upper case, but the roll rule stays lower case
  expect_equal(databentoR:::.db_symbols("es.c.0", "continuous"), "ES.c.0")
  expect_equal(databentoR:::.db_symbols("ES.N.0", "continuous"), "ES.n.0")
  expect_equal(databentoR:::.db_symbols("es.fut", "parent"), "ES.FUT")
  # numeric ids only with instrument_id
  expect_equal(databentoR:::.db_symbols(c(5482, 12), "instrument_id"), "5482,12")
  expect_error(databentoR:::.db_symbols(5482, "raw_symbol"), "instrument_id")
})

test_that("invalid symbols are refused before a request is spent", {
  expect_error(databentoR:::.db_symbols("ES..0", "parent"), "not a valid")
  expect_error(databentoR:::.db_symbols("A.B.C.D", "parent"), "not a valid")
  expect_error(databentoR:::.db_symbols(character(), "raw_symbol"), "must not be empty")
  expect_error(databentoR:::.db_symbols(as.character(1:2001), "raw_symbol"),
               "at most 2000")
})

test_that("timestamp parameters are coerced like datetime_to_string()", {
  expect_equal(databentoR:::.db_datetime("2020-12-28T12:00", "start"),
               "2020-12-28T12:00")
  expect_equal(databentoR:::.db_datetime(as.Date("2020-12-28"), "start"),
               "2020-12-28")
  expect_equal(
    databentoR:::.db_datetime(as.POSIXct("2020-12-28 00:00:00", tz = "UTC"), "start"),
    "2020-12-28T00:00:00+00:00"
  )
  expect_equal(databentoR:::.db_datetime(1609113600000000000, "start"),
               "1609113600000000000")
  expect_null(databentoR:::.db_datetime(NULL, "end"))
})

test_that("date parameters refuse timestamps, as the Python client does", {
  expect_equal(databentoR:::.db_date("2020-12-28", "start_date"), "2020-12-28")
  expect_equal(databentoR:::.db_date(as.Date("2020-12-28"), "start_date"),
               "2020-12-28")
  expect_error(
    databentoR:::.db_date(as.POSIXct("2020-12-28", tz = "UTC"), "start_date"),
    "not a timestamp"
  )
})

test_that("booleans serialise per endpoint family", {
  # form bodies mirror Python's True/False
  expect_equal(databentoR:::.db_bool(TRUE, "x"), "True")
  expect_equal(databentoR:::.db_bool(FALSE, "x"), "False")
  # the documented text-encoding flags are lower case
  expect_equal(databentoR:::.db_flag(TRUE, "x"), "true")
  expect_equal(databentoR:::.db_flag(FALSE, "x"), "false")
  expect_error(databentoR:::.db_bool(NA, "x"), "TRUE or FALSE")
})

test_that("enums are validated with a message that lists the alternatives", {
  expect_equal(databentoR:::.db_enum("OHLCV-1D", db_schemas(), "schema"), "ohlcv-1d")
  expect_error(databentoR:::.db_enum("ohlcv-1y", db_schemas(), "schema"),
               "must be one of")
  expect_error(databentoR:::.db_enum("nasdaq_symbol", db_stypes(), "stype_in"),
               "raw_symbol")
})

test_that("the enum accessors report the documented value sets", {
  expect_true(all(c("mbo", "ohlcv-1d", "definition", "tcbbo") %in% db_schemas()))
  expect_equal(db_stypes(),
               c("raw_symbol", "instrument_id", "parent", "continuous"))
  expect_equal(db_encodings(), c("dbn", "csv", "json"))
  expect_equal(db_compressions(), c("none", "zstd"))
})

test_that("NULL parameters are dropped but order is kept", {
  out <- databentoR:::.db_compact(list(a = "1", b = NULL, c = "3"))
  expect_equal(names(out), c("a", "c"))
})
