# Live tests against the real API.
#
# The metadata endpoints are free of charge, so they run whenever a key is
# present. The one billed test needs DATABENTOR_RUN_LIVE=true as well, and is
# deliberately tiny: a week of daily bars for one product costs a fraction of
# a cent. Neither runs on CRAN.

test_that("the free metadata endpoints answer", {
  skip_if_no_key()

  datasets <- db_list_datasets()
  expect_true(is.character(datasets) && length(datasets) > 0)
  expect_true("GLBX.MDP3" %in% datasets)

  schemas <- db_list_schemas("GLBX.MDP3")
  expect_true(all(c("ohlcv-1d", "trades", "definition") %in% schemas))
  # every schema the server offers must be one databentoR accepts
  expect_true(all(schemas %in% db_schemas()),
              label = paste("unknown schema(s):",
                            paste(setdiff(schemas, db_schemas()), collapse = ", ")))

  publishers <- db_list_publishers()
  expect_s3_class(publishers, "tbl_df")
  expect_true(all(c("publisher_id", "dataset", "venue") %in% names(publishers)))
})

test_that("dataset range and condition describe the history", {
  skip_if_no_key()

  rng <- db_get_dataset_range("GLBX.MDP3")
  expect_s3_class(rng, "tbl_df")
  expect_true(all(c("schema", "start", "end") %in% names(rng)))
  expect_true(nrow(rng) >= 1)

  cond <- db_get_dataset_condition("GLBX.MDP3", "2024-01-02", "2024-01-05")
  expect_s3_class(cond, "tbl_df")
  expect_true("condition" %in% names(cond))
})

test_that("the built-in column types agree with metadata.list_fields", {
  skip_if_no_key()
  # This is the self-check that keeps R/fields.R honest: the API is the
  # authority on which fields a schema has, and a field databentoR has never
  # seen would silently fall back to int32.
  for (schema in c("ohlcv-1d", "trades", "tbbo", "mbp-1", "statistics",
                   "status", "definition")) {
    fields <- db_list_fields(schema, "csv", dataset = "GLBX.MDP3")
    expect_s3_class(fields, "tbl_df")
    expect_true("name" %in% names(fields))
    kinds <- db_field_types(fields$name)
    # Nothing may be classified by accident: every field the API reports as a
    # timestamp or a price must be classified as such.
    if ("type" %in% names(fields)) {
      ts_api <- fields$name[grepl("time|^ts_", fields$type, ignore.case = TRUE)]
      ts_api <- setdiff(ts_api, "ts_in_delta")
      expect_true(all(kinds$kind[kinds$name %in% ts_api] == "timestamp"),
                  label = paste(schema, "timestamp fields"))
    }
  }
})

test_that("a cost preview is free, small and consistent with the record count", {
  skip_if_no_key()
  args <- list(dataset = "GLBX.MDP3", start = "2024-01-02", end = "2024-01-09",
               symbols = "ES.FUT", schema = "ohlcv-1d", stype_in = "parent")

  cost <- do.call(db_get_cost, args)
  expect_true(is.numeric(cost) && length(cost) == 1L && !is.na(cost))
  expect_lt(cost, 0.05)

  count <- do.call(db_get_record_count, args)
  expect_true(is.numeric(count) && count > 0)

  size <- do.call(db_get_billable_size, args)
  expect_true(is.numeric(size) && size > 0)
})

test_that("symbology resolves a parent symbol to instrument ids", {
  skip_if_no_key()
  res <- db_resolve("GLBX.MDP3", "ES.FUT", stype_in = "parent",
                    start_date = "2024-01-02", end_date = "2024-01-09")
  expect_s3_class(res, "tbl_df")
  expect_equal(names(res), c("input_symbol", "start_date", "end_date", "symbol"))
  expect_gt(nrow(res), 0)
  expect_s3_class(res$start_date, "Date")
})

test_that("a tiny range download returns a typed tibble", {
  skip_unless_live()
  tb <- db_get_range("GLBX.MDP3", start = "2024-01-02", end = "2024-01-09",
                     symbols = "ES.FUT", schema = "ohlcv-1d",
                     stype_in = "parent")
  expect_s3_class(tb, "tbl_df")
  expect_gt(nrow(tb), 0)
  expect_equal(names(tb)[1L], "ts_event")
  expect_equal(names(tb)[ncol(tb)], "symbol")
  expect_s3_class(tb$ts_event, "POSIXct")
  expect_type(tb$open, "double")
  expect_type(tb$symbol, "character")
  expect_true(all(tb$high >= tb$low))
})

test_that("zstd transfer gives the same table as an uncompressed one", {
  skip_unless_live()
  args <- list(dataset = "GLBX.MDP3", start = "2024-01-02", end = "2024-01-09",
               symbols = "ES.FUT", schema = "ohlcv-1d", stype_in = "parent")
  plain <- do.call(db_get_range, c(args, list(compression = "none")))
  packed <- do.call(db_get_range, c(args, list(compression = "zstd")))
  expect_equal(packed, plain)
})

test_that("the parquet path writes the same table it returns", {
  skip_unless_live()
  path <- withr::local_tempfile(fileext = ".parquet")
  tb <- db_get_range("GLBX.MDP3", start = "2024-01-02", end = "2024-01-09",
                     symbols = "ES.FUT", schema = "ohlcv-1d",
                     stype_in = "parent", path = path)
  expect_true(file.exists(path))
  expect_equal(tibble::as_tibble(arrow::read_parquet(path)), tb)
})
