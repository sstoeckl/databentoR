# Reading the CSV encoding. These use synthetic slices with the exact column
# names the API emits, so they run offline and on CRAN.

trades_csv <- paste(
  "ts_recv,ts_event,rtype,publisher_id,instrument_id,action,side,depth,price,size,flags,ts_in_delta,sequence,symbol",
  "2020-12-28T13:00:00.006150193Z,2020-12-28T13:00:00.005871213Z,0,1,5482,T,B,0,3702.250000000,1,130,26128,145805,ESH1",
  "2020-12-28T13:00:01.006150193Z,2020-12-28T13:00:01.005871213Z,0,1,5482,T,A,0,3702.750000000,2,130,26128,145806,ESH1",
  sep = "\n"
)

ohlcv_csv <- paste(
  "ts_event,rtype,publisher_id,instrument_id,open,high,low,close,volume,symbol",
  "2020-12-28T00:00:00.000000000Z,35,1,5482,3702.750000000,3735.000000000,3697.250000000,3735.000000000,718174,ESH1",
  sep = "\n"
)

write_tmp <- function(text, ext = ".csv") {
  path <- withr::local_tempfile(fileext = ext, .local_envir = parent.frame())
  writeLines(text, path)
  path
}

test_that("an all-T action column stays character instead of becoming boolean", {
  # arrow's own inference reads "T" as TRUE, which would silently turn every
  # trade action into a logical. This is the single most important guard here.
  path <- write_tmp(trades_csv)
  tb <- databentoR:::.db_read_csv(path)
  expect_type(tb$action, "character")
  expect_equal(tb$action, c("T", "T"))
  expect_equal(tb$side, c("B", "A"))
})

test_that("the same file read by inference really would be wrong", {
  path <- write_tmp(trades_csv)
  naive <- arrow::read_csv_arrow(path)
  expect_type(naive$action, "logical")
})

test_that("timestamps, prices and counts get the right types", {
  path <- write_tmp(trades_csv)
  tb <- databentoR:::.db_read_csv(path)
  expect_s3_class(tb$ts_recv, "POSIXct")
  expect_equal(attr(tb$ts_recv, "tzone"), "UTC")
  expect_type(tb$price, "double")
  expect_equal(tb$price, c(3702.25, 3702.75), tolerance = 1e-12)
  expect_true(is.numeric(tb$size))
  expect_true(is.numeric(tb$flags))
  # symbol is appended last by map_symbols
  expect_equal(names(tb)[ncol(tb)], "symbol")
})

test_that("ohlcv slices round-trip with ts_event first and symbol last", {
  path <- write_tmp(ohlcv_csv)
  tb <- databentoR:::.db_read_csv(path)
  expect_equal(names(tb), c("ts_event", "rtype", "publisher_id",
                            "instrument_id", "open", "high", "low", "close",
                            "volume", "symbol"))
  expect_equal(tb$open, 3702.75, tolerance = 1e-12)
  expect_equal(tb$close, 3735, tolerance = 1e-12)
})

test_that("empty price and timestamp fields become NA, not zero", {
  csv <- paste(
    "ts_recv,ts_event,rtype,publisher_id,instrument_id,ts_ref,price,quantity,sequence,ts_in_delta,stat_type,channel_id,update_action,stat_flags,symbol",
    "2020-12-28T01:09:29.471598612Z,2020-12-28T01:09:29.000000000Z,24,1,5482,,3707.750000000,9223372036854775807,210043,22850,8,0,1,255,ESH1",
    sep = "\n"
  )
  tb <- databentoR:::.db_read_csv(write_tmp(csv))
  expect_true(is.na(tb$ts_ref))
  expect_equal(tb$price, 3707.75, tolerance = 1e-12)
})

test_that("an empty or missing response yields an empty tibble", {
  expect_equal(nrow(databentoR:::.db_read_csv(write_tmp(""))), 0L)
  expect_equal(nrow(databentoR:::.db_read_csv(tempfile())), 0L)
})

test_that("zstd responses are decompressed transparently", {
  skip_if_not(arrow::codec_is_available("zstd"), "arrow has no zstd codec")
  path <- withr::local_tempfile(fileext = ".csv.zst")
  stream <- arrow::CompressedOutputStream$create(path, arrow::Codec$create("zstd"))
  stream$write(charToRaw(paste0(ohlcv_csv, "\n")))
  stream$close()

  tb <- databentoR:::.db_read_csv(path, compression = "zstd")
  plain <- databentoR:::.db_read_csv(write_tmp(ohlcv_csv))
  expect_equal(tb, plain)
})

test_that("raw (non-pretty) slices keep timestamps as text and prices exact", {
  csv <- paste(
    "ts_event,rtype,publisher_id,instrument_id,open,high,low,close,volume,symbol",
    "1609113600000000000,35,1,5482,3702750000000,3735000000000,3697250000000,3735000000000,718174,ESH1",
    sep = "\n"
  )
  tb <- databentoR:::.db_read_csv(write_tmp(csv), pretty_px = FALSE,
                                  pretty_ts = FALSE)
  expect_type(tb$ts_event, "character")
  expect_equal(tb$ts_event, "1609113600000000000")
  expect_equal(as.numeric(tb$open) / 1e9, 3702.75, tolerance = 1e-12)
})

test_that("a user-supplied schema overrides the built-in types", {
  path <- write_tmp(ohlcv_csv)
  sch <- arrow::schema(
    ts_event = arrow::utf8(), rtype = arrow::int32(),
    publisher_id = arrow::int32(), instrument_id = arrow::int64(),
    open = arrow::float64(), high = arrow::float64(), low = arrow::float64(),
    close = arrow::float64(), volume = arrow::int64(), symbol = arrow::utf8()
  )
  tb <- databentoR:::.db_read_csv(path, col_types = sch)
  expect_type(tb$ts_event, "character")
})

test_that("db_field_types() classifies the documented field names", {
  ft <- db_field_types(c("ts_recv", "auction_time", "close", "leg_delta",
                         "ask_px_09", "ask_sz_09", "ask_ct_00", "raw_symbol",
                         "order_id", "rtype"))
  expect_equal(ft$kind, c("timestamp", "timestamp", "price", "price",
                          "price", "int64", "int64", "character",
                          "int64", "int32"))
})

test_that("the one schema-dependent field is typed per schema", {
  # `action` is a character code in the trade and book schemas but a numeric
  # enum in `status`. This is the only name in the API whose type depends on
  # the schema, so it is the only thing the override table carries.
  expect_equal(db_field_types("action")$kind, "character")
  expect_equal(db_field_types("action", schema = "trades")$kind, "character")
  expect_equal(db_field_types("action", schema = "status")$kind, "int32")

  csv <- paste(
    "ts_recv,ts_event,rtype,publisher_id,instrument_id,action,reason,trading_event,is_trading,is_quoting,is_short_sell_restricted,symbol",
    "2024-01-02T13:00:00.000000000Z,2024-01-02T13:00:00.000000000Z,23,1,5482,1,0,0,Y,Y,~,ESH4",
    sep = "\n"
  )
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(csv, path)

  status <- databentoR:::.db_read_csv(path, schema = "status")
  expect_true(is.numeric(status$action))
  expect_type(status$is_trading, "character")

  # without the schema the name alone wins, which is the trade reading
  plain <- databentoR:::.db_read_csv(path)
  expect_type(plain$action, "character")
})
