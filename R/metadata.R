# The metadata namespace. Every endpoint here is free of charge, which is why
# a cost preview belongs in front of every range download.
#
# Argument names, order and defaults mirror the official Python client, so
# code translates across the two clients without surprises.

#' List the publishers Databento serves
#'
#' Free of charge. Mirrors `metadata.list_publishers`.
#'
#' @return A tibble with one row per publisher: `publisher_id`, `dataset`,
#'   `venue` and `description`.
#' @family metadata
#' @examples
#' \dontrun{
#' db_list_publishers()
#' }
#' @export
db_list_publishers <- function() {
  .db_tbl(.db_json(.db_build("metadata.list_publishers", "GET")))
}

#' List available datasets
#'
#' Free of charge. Mirrors `metadata.list_datasets`.
#'
#' @param start_date,end_date Optional `Date` or `"YYYY-MM-DD"` string
#'   restricting the answer to datasets with data in that window.
#' @return A character vector of dataset codes such as `"GLBX.MDP3"` or
#'   `"OPRA.PILLAR"`.
#' @family metadata
#' @examples
#' \dontrun{
#' db_list_datasets()
#' }
#' @export
db_list_datasets <- function(start_date = NULL, end_date = NULL) {
  .db_chr(.db_json(.db_build("metadata.list_datasets", "GET", list(
    start_date = .db_date(start_date, "start_date"),
    end_date   = .db_date(end_date, "end_date")
  ))))
}

#' List the schemas available for a dataset
#'
#' Free of charge. Mirrors `metadata.list_schemas`. Which schemas exist is a
#' property of the dataset, so this is the authoritative list rather than
#' [db_schemas()].
#'
#' @param dataset Dataset code, e.g. `"GLBX.MDP3"`.
#' @return A character vector of schema names, e.g. `"ohlcv-1m"`.
#' @family metadata
#' @examples
#' \dontrun{
#' db_list_schemas("GLBX.MDP3")
#' }
#' @export
db_list_schemas <- function(dataset) {
  .db_chr(.db_json(.db_build("metadata.list_schemas", "GET", list(
    dataset = .db_semantic_string(dataset, "dataset")
  ))))
}

#' List the fields of one schema and encoding
#'
#' Free of charge. Mirrors `metadata.list_fields`. This is the authoritative
#' column list for a download: field sets differ between DBN record versions,
#' so pass `dataset` rather than relying on the newest layout.
#'
#' @param schema Schema name, see [db_schemas()].
#' @param encoding Encoding whose field list you want, see [db_encodings()].
#' @param dataset Optional dataset code. Omitting it returns the fields of the
#'   most recent DBN version, which may not match an older dataset.
#' @return A tibble with the field `name` and `type` per record.
#' @family metadata
#' @examples
#' \dontrun{
#' db_list_fields("ohlcv-1d", "csv", dataset = "GLBX.MDP3")
#' }
#' @export
db_list_fields <- function(schema, encoding, dataset = NULL) {
  .db_tbl(.db_json(.db_build("metadata.list_fields", "GET", list(
    schema   = .db_enum(schema, db_schemas(), "schema"),
    encoding = .db_enum(encoding, db_encodings(), "encoding"),
    dataset  = if (is.null(dataset)) NULL else .db_semantic_string(dataset, "dataset")
  ))))
}

#' List the unit prices of a dataset
#'
#' Free of charge. Mirrors `metadata.list_unit_prices`. Prices are US dollars
#' per **gibibyte** (2^30 bytes), per feed mode and schema, not per decimal
#' gigabyte. Measured on 2026-09-12, a quote equals
#' `db_get_billable_size() / 2^30 * unit_price` to six decimal places, so
#' dividing by 1e9 instead overstates the cost by about 7%.
#'
#' @inheritParams db_list_schemas
#' @return A tibble with `mode`, `schema` and `unit_price`. When the server
#'   answers with a shape this function does not recognise, the parsed JSON is
#'   returned unchanged and a warning is raised.
#' @family metadata
#' @examples
#' \dontrun{
#' db_list_unit_prices("GLBX.MDP3")
#' }
#' @export
db_list_unit_prices <- function(dataset) {
  raw <- .db_json(.db_build("metadata.list_unit_prices", "GET", list(
    dataset = .db_semantic_string(dataset, "dataset")
  )))
  rows <- list()
  ok <- length(raw) > 0L
  for (entry in raw) {
    if (!is.list(entry) || is.null(entry$mode) || !is.list(entry$unit_prices)) {
      ok <- FALSE
      break
    }
    for (schema in names(entry$unit_prices)) {
      rows[[length(rows) + 1L]] <- list(
        mode = as.character(entry$mode),
        schema = schema,
        unit_price = as.numeric(entry$unit_prices[[schema]])
      )
    }
  }
  if (!ok || !length(rows)) {
    warning("Unrecognised unit-price payload; returning the parsed JSON.",
            call. = FALSE)
    return(raw)
  }
  tibble::tibble(
    mode = vapply(rows, function(r) r$mode, character(1)),
    schema = vapply(rows, function(r) r$schema, character(1)),
    unit_price = vapply(rows, function(r) r$unit_price, numeric(1))
  )
}

#' Report the condition of a dataset, day by day
#'
#' Free of charge. Mirrors `metadata.get_dataset_condition`. Use it to spot
#' `degraded`, `pending` or `missing` days before paying for a range that
#' cannot be complete.
#'
#' @inheritParams db_list_schemas
#' @param start_date,end_date Optional `Date` or `"YYYY-MM-DD"` window.
#' @return A tibble with `date`, `condition` and `last_modified_date`.
#' @family metadata
#' @examples
#' \dontrun{
#' db_get_dataset_condition("GLBX.MDP3", "2024-01-01", "2024-02-01")
#' }
#' @export
db_get_dataset_condition <- function(dataset, start_date = NULL, end_date = NULL) {
  .db_tbl(.db_json(.db_build("metadata.get_dataset_condition", "GET", list(
    dataset    = .db_semantic_string(dataset, "dataset"),
    start_date = .db_date(start_date, "start_date"),
    end_date   = .db_date(end_date, "end_date")
  ))))
}

#' Report the available date range of a dataset
#'
#' Free of charge. Mirrors `metadata.get_dataset_range`. Newer servers report
#' a range per schema, which is how you learn that a venue's quotes start
#' years after its trades.
#'
#' @inheritParams db_list_schemas
#' @return A tibble with `schema`, `start` and `end`. When the server reports
#'   only one overall range, `schema` is `NA`. The parsed JSON is attached as
#'   the `"raw"` attribute.
#' @family metadata
#' @examples
#' \dontrun{
#' db_get_dataset_range("OPRA.PILLAR")
#' }
#' @export
db_get_dataset_range <- function(dataset) {
  raw <- .db_json(.db_build("metadata.get_dataset_range", "GET", list(
    dataset = .db_semantic_string(dataset, "dataset")
  )))
  # `start`/`end` supersede the deprecated `start_date`/`end_date` keys.
  overall_start <- raw$start %||% raw$start_date
  overall_end <- raw$end %||% raw$end_date
  per_schema <- raw$schema
  out <- if (is.list(per_schema) && length(per_schema)) {
    tibble::tibble(
      schema = names(per_schema),
      start = vapply(per_schema, function(s) as.character(s$start %||% NA),
                     character(1), USE.NAMES = FALSE),
      end = vapply(per_schema, function(s) as.character(s$end %||% NA),
                   character(1), USE.NAMES = FALSE)
    )
  } else {
    tibble::tibble(schema = NA_character_,
                   start = as.character(overall_start %||% NA),
                   end = as.character(overall_end %||% NA))
  }
  attr(out, "raw") <- raw
  out
}

`%||%` <- function(x, y) if (is.null(x)) y else x

# The three request-shaped metadata endpoints below are POSTs with a form
# body, as in the Python client. They carry `symbols`, and a query string
# cannot hold two thousand of them.

#' Count the records a request would return
#'
#' Free of charge. Mirrors `metadata.get_record_count`, and the cheapest way
#' to learn that a slice is empty before paying for it.
#'
#' @inheritParams db_get_cost
#' @return A single number: the record count.
#' @family metadata
#' @examples
#' \dontrun{
#' db_get_record_count("GLBX.MDP3", start = "2024-01-01", end = "2024-02-01",
#'                     symbols = "ES.FUT", schema = "ohlcv-1d",
#'                     stype_in = "parent")
#' }
#' @export
db_get_record_count <- function(dataset, start, end = NULL, symbols = NULL,
                                schema = "trades", stype_in = "raw_symbol",
                                limit = NULL) {
  stype_in <- .db_enum(stype_in, db_stypes(), "stype_in")
  .db_scalar(.db_build("metadata.get_record_count", "POST", list(
    dataset  = .db_semantic_string(dataset, "dataset"),
    symbols  = .db_symbols(symbols, stype_in),
    schema   = .db_enum(schema, db_schemas(), "schema"),
    start    = .db_datetime(start, "start"),
    end      = .db_datetime(end, "end"),
    stype_in = stype_in,
    limit    = .db_int(limit, "limit")
  )))
}

#' Report the billable size of a request in bytes
#'
#' Free of charge. Mirrors `metadata.get_billable_size`.
#'
#' @inheritParams db_get_cost
#' @return A single number: the billable size in bytes.
#' @family metadata
#' @examples
#' \dontrun{
#' db_get_billable_size("GLBX.MDP3", start = "2024-01-01", end = "2024-02-01",
#'                      symbols = "ES.FUT", schema = "ohlcv-1d",
#'                      stype_in = "parent")
#' }
#' @export
db_get_billable_size <- function(dataset, start, end = NULL, symbols = NULL,
                                 schema = "trades", stype_in = "raw_symbol",
                                 limit = NULL) {
  .db_scalar(.db_build("metadata.get_billable_size", "POST",
                       .db_cost_params(dataset, start, end, symbols, schema,
                                       stype_in, limit)))
}

#' Preview the cost of a request in US dollars
#'
#' Free of charge, and the one call that belongs in front of every
#' [db_get_range()]: downloads are billed per gigabyte, previews are not.
#' Mirrors `metadata.get_cost`. The quote already reflects any plan discount,
#' so it is not simply billable size times unit price.
#'
#' @param dataset Dataset code, e.g. `"GLBX.MDP3"`.
#' @param start,end Request window, start inclusive and end exclusive. A
#'   string passes through verbatim, a `Date` becomes a plain date, a
#'   `POSIXct` an ISO-8601 UTC instant, and a number is read as nanoseconds
#'   since the UNIX epoch. Leaving `end` as `NULL` asks the server to
#'   forward-fill from `start`.
#' @param symbols Character vector of symbols, a single comma-separated
#'   string, or `NULL` for all symbols. With `stype_in = "instrument_id"` a
#'   numeric vector is accepted. At most 2000 symbols per request.
#' @param schema Schema name, see [db_schemas()].
#' @param stype_in Symbol type of `symbols`, see [db_stypes()]. Use
#'   `"parent"` for product-level symbols such as `"ES.FUT"` or `"SPX.OPT"`.
#' @param limit Optional cap on the number of records.
#' @return A single number: the quoted cost in USD.
#' @family metadata
#' @examples
#' \dontrun{
#' db_get_cost("GLBX.MDP3", start = "2024-01-01", end = "2024-02-01",
#'             symbols = "ES.FUT", schema = "ohlcv-1d", stype_in = "parent")
#' }
#' @export
db_get_cost <- function(dataset, start, end = NULL, symbols = NULL,
                        schema = "trades", stype_in = "raw_symbol",
                        limit = NULL) {
  .db_scalar(.db_build("metadata.get_cost", "POST",
                       .db_cost_params(dataset, start, end, symbols, schema,
                                       stype_in, limit)))
}

# get_cost and get_billable_size share one body, in this order, and always pin
# stype_out to instrument_id: the Python client offers no way to change it,
# and the API only resolves to instrument_id from these symbol types.
.db_cost_params <- function(dataset, start, end, symbols, schema, stype_in, limit) {
  stype_in <- .db_enum(stype_in, db_stypes(), "stype_in")
  list(
    dataset   = .db_semantic_string(dataset, "dataset"),
    start     = .db_datetime(start, "start"),
    end       = .db_datetime(end, "end"),
    symbols   = .db_symbols(symbols, stype_in),
    schema    = .db_enum(schema, db_schemas(), "schema"),
    stype_in  = stype_in,
    stype_out = "instrument_id",
    limit     = .db_int(limit, "limit")
  )
}
