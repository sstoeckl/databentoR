# Wire equivalence with the official Python client.
#
# `dev/equivalence/wire_capture.py` replays the pinned Python client with its
# HTTP transport stubbed out and records the exact request it would send. This
# test builds the same request in R and compares them field by field. It needs
# no API key, no network and no money, so it runs everywhere, on every push.
#
# Regenerate the fixture after bumping the submodule:
#   pip install ./dev/python-reference
#   python dev/equivalence/wire_capture.py

fixture_path <- testthat::test_path("fixtures", "python_wire.json")

pairs_of <- function(x) {
  if (!length(x)) return(character())
  stats::setNames(vapply(x, function(p) as.character(p[[2L]]), character(1)),
                  vapply(x, function(p) as.character(p[[1L]]), character(1)))
}

# Python keeps the parameters out of the URL, so compare the endpoint alone.
endpoint_of <- function(url) {
  sub("[?].*$", "", sub("^.*/v0/", "", url))
}

# The R call for each captured Python call, with the same arguments.
r_calls <- list(
  "metadata.list_publishers" = function() db_list_publishers(),
  "metadata.list_datasets" = function() db_list_datasets(),
  "metadata.list_datasets.dated" = function() {
    db_list_datasets(start_date = "2024-01-01", end_date = "2024-02-01")
  },
  "metadata.list_schemas" = function() db_list_schemas("GLBX.MDP3"),
  "metadata.list_fields" = function() {
    db_list_fields(schema = "trades", encoding = "csv", dataset = "GLBX.MDP3")
  },
  "metadata.list_unit_prices" = function() db_list_unit_prices("GLBX.MDP3"),
  "metadata.get_dataset_condition" = function() {
    db_get_dataset_condition("GLBX.MDP3", start_date = "2024-01-01",
                             end_date = "2024-02-01")
  },
  "metadata.get_dataset_range" = function() db_get_dataset_range("GLBX.MDP3"),
  "metadata.get_record_count" = function() {
    db_get_record_count("GLBX.MDP3", start = "2020-12-28T12:00",
                        end = "2020-12-29", symbols = "ESH1", schema = "mbo",
                        limit = 1000000)
  },
  "metadata.get_billable_size" = function() {
    db_get_billable_size("GLBX.MDP3", start = "2020-12-28T12:00",
                         end = "2020-12-29", symbols = "ESH1", schema = "mbo")
  },
  "metadata.get_cost" = function() {
    db_get_cost("GLBX.MDP3", start = "2020-12-28T12:00", end = "2020-12-29",
                symbols = "ESH1", schema = "mbo")
  },
  "metadata.get_cost.parent" = function() {
    db_get_cost("OPRA.PILLAR", start = "2024-10-01", end = "2024-10-08",
                symbols = c("SPX.OPT", "VIX.OPT"), schema = "ohlcv-1d",
                stype_in = "parent")
  },
  "metadata.get_cost.all_symbols" = function() {
    db_get_cost("GLBX.MDP3", start = "2024-01-01", schema = "ohlcv-1d")
  },
  "timeseries.get_range" = function() {
    db_get_range("GLBX.MDP3", start = "2020-12-28T12:00", end = "2020-12-29",
                 symbols = "ES.c.0", schema = "trades", stype_in = "continuous")
  },
  "timeseries.get_range.limit" = function() {
    db_get_range("GLBX.MDP3", start = "2020-12-28T12:00", symbols = "ESH1",
                 schema = "ohlcv-1d", limit = 100)
  },
  "symbology.resolve" = function() {
    db_resolve("GLBX.MDP3", "ESH1", stype_in = "raw_symbol",
               stype_out = "instrument_id", start_date = "2020-12-28",
               end_date = "2020-12-29")
  },
  "batch.submit_job" = function() {
    db_batch_submit_job("GLBX.MDP3", "ESH1", "mbo", "2020-12-28T12:00",
                        end = "2020-12-29")
  },
  "batch.submit_job.csv" = function() {
    db_batch_submit_job("GLBX.MDP3", "ESH1", "mbo", "2020-12-28T12:00",
                        encoding = "csv", pretty_px = TRUE, pretty_ts = TRUE,
                        split_duration = "week", split_size = 2000000000,
                        limit = 500)
  },
  "batch.get_job_details" = function() db_batch_get_job_details("JOB-0001"),
  "batch.list_jobs" = function() db_batch_list_jobs(),
  "batch.list_jobs.short" = function() {
    db_batch_list_jobs(states = "done", short = TRUE)
  },
  "batch.list_files" = function() db_batch_list_files("JOB-0001"),
  "adjustment_factors.get_range" = function() {
    db_adjustment_factors(start = "2024-01-01", end = "2024-02-01",
                          symbols = "AAPL", countries = c("US", "CA"))
  },
  "corporate_actions.get_range" = function() {
    db_corporate_actions(start = "2024-01-01", end = "2024-02-01",
                         symbols = "AAPL", events = c("DIV", "SPLT"),
                         exchanges = "XNAS")
  },
  "corporate_actions.list_events" = function() db_corporate_action_events(),
  "corporate_actions.list_enums" = function() db_corporate_action_enums(),
  "security_master.get_range" = function() {
    db_security_master(start = "2024-01-01", end = "2024-02-01",
                       symbols = "AAPL")
  },
  "security_master.get_last" = function() db_security_master_last(symbols = "AAPL")
)

# The one deliberate divergence: databentoR reads the CSV encoding, so it asks
# for csv rather than dbn and adds the three documented text-encoding flags.
# Every other parameter must still match exactly.
csv_divergence <- c("encoding", "compression", "pretty_px", "pretty_ts",
                    "map_symbols")

test_that("the wire fixture is present and describes the pinned client", {
  expect_true(file.exists(fixture_path))
  wire <- jsonlite::fromJSON(fixture_path, simplifyVector = FALSE)
  expect_match(wire$databento_python_version, "^[0-9]+\\.[0-9]+\\.[0-9]+$")
  expect_setequal(names(wire$calls), names(r_calls))
})

test_that("databentoR builds the same request as the Python client", {
  wire <- jsonlite::fromJSON(fixture_path, simplifyVector = FALSE)

  for (name in names(r_calls)) {
    py <- wire$calls[[name]]
    req <- capture_request(r_calls[[name]]())
    expect_false(is.null(req), label = paste("R built a request for", name))

    expect_equal(request_method(req), py$method, label = paste(name, "method"))
    expect_equal(endpoint_of(req$url), endpoint_of(py$url),
                 label = paste(name, "endpoint"))

    py_pairs <- pairs_of(if (identical(py$method, "GET")) py$query else py$body)
    r_pairs <- if (identical(py$method, "GET")) request_query(req) else request_body(req)

    if (startsWith(name, "timeseries.get_range")) {
      expect_equal(r_pairs[setdiff(names(r_pairs), csv_divergence)],
                   py_pairs[setdiff(names(py_pairs), csv_divergence)],
                   label = paste(name, "shared parameters"))
    } else {
      expect_equal(r_pairs, py_pairs, label = paste(name, "parameters"))
    }
  }
})

test_that("the CSV divergence on get_range is exactly the documented one", {
  wire <- jsonlite::fromJSON(fixture_path, simplifyVector = FALSE)
  py <- pairs_of(wire$calls[["timeseries.get_range"]]$body)
  req <- capture_request(r_calls[["timeseries.get_range"]]())
  r <- request_body(req)

  # Python always asks for the binary encoding and never sends the text flags.
  expect_equal(unname(py[["encoding"]]), "dbn")
  expect_equal(unname(py[["compression"]]), "zstd")
  expect_false(any(c("pretty_px", "pretty_ts", "map_symbols") %in% names(py)))

  # databentoR asks for CSV and must send all three flags explicitly, because
  # the API defaults them to false.
  expect_equal(unname(r[["encoding"]]), "csv")
  expect_equal(unname(r[c("pretty_px", "pretty_ts", "map_symbols")]),
               c("true", "true", "true"))
})

test_that("the R value domains still match the Python client's enums", {
  # These come from the compiled DBN enums, so a schema or symbol type added
  # upstream is caught here, offline, before anyone hits a 400 in production.
  wire <- jsonlite::fromJSON(fixture_path, simplifyVector = FALSE)
  enums <- wire$enums
  skip_if(is.null(enums), "fixture predates the enum capture")

  expect_setequal(db_schemas(), unlist(enums$Schema))
  expect_setequal(db_encodings(), unlist(enums$Encoding))
  expect_setequal(db_compressions(), unlist(enums$Compression))
  # db_stypes() is the historical subset; the rest are reference-data types.
  expect_true(all(db_stypes() %in% unlist(enums$SType)))
})
