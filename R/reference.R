# The reference-data namespace: adjustment factors, corporate actions and the
# security master. Same gateway as the historical API, different endpoints.
#
# These endpoints answer with zstd-compressed JSON lines rather than a single
# JSON document, which is why they go through .db_jsonl() instead of
# .db_json().

#' Corporate-action adjustment factors
#'
#' Mirrors `adjustment_factors.get_range` of the Python client's reference
#' data API.
#'
#' @param start,end Request window. `start` is required; leaving `end` as
#'   `NULL` asks the server to forward-fill.
#' @param symbols Character vector of symbols, a comma-separated string, or
#'   `NULL` for all symbols.
#' @param stype_in Symbol type of `symbols`. The reference API accepts more
#'   types than the historical one, among them `"isin"`, `"figi"` and
#'   `"nasdaq_symbol"`, and passes the value through unvalidated.
#' @param countries Optional country filter, a character vector or a
#'   comma-separated string.
#' @param security_types Optional security-type filter.
#' @param allocate_isins Ask the server to allocate ISINs.
#' @param compression Transfer compression, `"zstd"` or `"none"`.
#' @return A tibble of adjustment factors, with `ts_created` parsed as a
#'   timestamp and `ex_date` as a date.
#' @family reference
#' @examples
#' \dontrun{
#' db_adjustment_factors(start = "2024-01-01", symbols = "AAPL")
#' }
#' @export
db_adjustment_factors <- function(start, end = NULL, symbols = NULL,
                                  stype_in = "raw_symbol", countries = NULL,
                                  security_types = NULL, allocate_isins = TRUE,
                                  compression = "zstd") {
  out <- .db_jsonl(.db_build("adjustment_factors.get_range", "POST", list(
    start          = .db_datetime(start, "start"),
    end            = .db_datetime(end, "end"),
    symbols        = .db_symbols(symbols, "raw_symbol"),
    stype_in       = stype_in,
    countries      = .db_join(countries),
    security_types = .db_join(security_types),
    allocate_isins = .db_bool(allocate_isins, "allocate_isins"),
    compression    = .db_enum(compression, db_compressions(), "compression")
  )), compression)
  .db_time_cols(out, datetime = "ts_created", date = "ex_date")
}

#' Corporate actions
#'
#' Mirrors `corporate_actions.get_range`.
#'
#' @inheritParams db_adjustment_factors
#' @param index Column the result is ordered by, `"event_date"` by default.
#' @param events Optional event-type filter, a character vector or a
#'   comma-separated string. See [db_corporate_action_events()].
#' @param exchanges Optional exchange filter. Sent only when supplied.
#' @param flatten Expand the nested `date_info`, `rate_info` and `event_info`
#'   objects into ordinary columns.
#' @param pit Keep every point-in-time record. `FALSE`, the default, keeps
#'   only the latest record of each event.
#' @return A tibble of corporate actions.
#' @family reference
#' @examples
#' \dontrun{
#' db_corporate_actions(start = "2024-01-01", symbols = "AAPL")
#' }
#' @export
db_corporate_actions <- function(start, end = NULL, index = "event_date",
                                 symbols = NULL, stype_in = "raw_symbol",
                                 events = NULL, countries = NULL,
                                 exchanges = NULL, security_types = NULL,
                                 flatten = TRUE, pit = FALSE,
                                 allocate_isins = TRUE, compression = "zstd") {
  out <- .db_jsonl(.db_build("corporate_actions.get_range", "POST", list(
    start          = .db_datetime(start, "start"),
    end            = .db_datetime(end, "end"),
    index          = index,
    symbols        = .db_symbols(symbols, "raw_symbol"),
    stype_in       = stype_in,
    events         = .db_join(events),
    countries      = .db_join(countries),
    security_types = .db_join(security_types),
    allocate_isins = .db_bool(allocate_isins, "allocate_isins"),
    compression    = .db_enum(compression, db_compressions(), "compression"),
    exchanges      = .db_join(exchanges)
  )), compression)
  if (!nrow(out)) return(out)

  out <- .db_time_cols(out,
    datetime = c("ts_record", "ts_created"),
    date = c("event_date", "event_created_date", "effective_date", "ex_date",
             "record_date", "listing_date", "delisting_date", "payment_date",
             "duebills_redemption_date", "from_date", "to_date",
             "registration_date", "start_date", "end_date", "open_date",
             "close_date", "start_subscription_date", "end_subscription_date",
             "option_election_date", "withdrawal_right_from_date",
             "withdrawal_rights_to_date", "notification_date",
             "financial_year_end_date", "exp_completion_date"))
  if (isTRUE(flatten)) {
    out <- .db_flatten(out, c("date_info", "rate_info", "event_info"))
  }
  if (!isTRUE(pit) && all(c("ts_record", "event_unique_id") %in% names(out))) {
    # Keep the latest record of each event, as the Python client does.
    out <- out[order(out$ts_record), , drop = FALSE]
    out <- out[!duplicated(out$event_unique_id, fromLast = TRUE), , drop = FALSE]
  }
  if (index %in% names(out)) out <- out[order(out[[index]]), , drop = FALSE]
  out
}

#' List the corporate-action event types
#'
#' Mirrors `corporate_actions.list_events`. This endpoint is public: the
#' Python client sends no credentials, and neither does databentoR.
#'
#' @return A tibble of event codes and their descriptions.
#' @family reference
#' @examples
#' \dontrun{
#' db_corporate_action_events()
#' }
#' @export
db_corporate_action_events <- function() {
  raw <- .db_json(.db_build("corporate_actions.list_events", "GET",
                            auth = FALSE))
  .db_named_tbl(raw, "event")
}

#' List the corporate-action enumerations
#'
#' Mirrors `corporate_actions.list_enums`. Public, like
#' [db_corporate_action_events()].
#'
#' @return The parsed enumerations, as a named list of tibbles.
#' @family reference
#' @examples
#' \dontrun{
#' db_corporate_action_enums()
#' }
#' @export
db_corporate_action_enums <- function() {
  raw <- .db_json(.db_build("corporate_actions.list_enums", "GET",
                            auth = FALSE))
  lapply(raw, .db_tbl)
}

#' Security master over a time range
#'
#' Mirrors `security_master.get_range`.
#'
#' @inheritParams db_adjustment_factors
#' @param index Column the result is ordered by, `"ts_effective"` by default.
#' @return A tibble of security-master records.
#' @family reference
#' @examples
#' \dontrun{
#' db_security_master(start = "2024-01-01", symbols = "AAPL")
#' }
#' @export
db_security_master <- function(start, end = NULL, index = "ts_effective",
                               symbols = NULL, stype_in = "raw_symbol",
                               countries = NULL, security_types = NULL,
                               allocate_isins = TRUE, compression = "zstd") {
  out <- .db_jsonl(.db_build("security_master.get_range", "POST", list(
    start          = .db_datetime(start, "start"),
    end            = .db_datetime(end, "end"),
    index          = index,
    symbols        = .db_symbols(symbols, "raw_symbol"),
    stype_in       = stype_in,
    countries      = .db_join(countries),
    security_types = .db_join(security_types),
    allocate_isins = .db_bool(allocate_isins, "allocate_isins"),
    compression    = .db_enum(compression, db_compressions(), "compression")
  )), compression)
  out <- .db_security_time_cols(out)
  if (index %in% names(out)) out <- out[order(out[[index]]), , drop = FALSE]
  out
}

#' Latest security-master record per security
#'
#' Mirrors `security_master.get_last`.
#'
#' @inheritParams db_adjustment_factors
#' @return A tibble of security-master records, ordered by `ts_effective`.
#' @family reference
#' @examples
#' \dontrun{
#' db_security_master_last(symbols = "AAPL")
#' }
#' @export
db_security_master_last <- function(symbols = NULL, stype_in = "raw_symbol",
                                    countries = NULL, security_types = NULL,
                                    allocate_isins = TRUE, compression = "zstd") {
  out <- .db_jsonl(.db_build("security_master.get_last", "POST", list(
    symbols        = .db_symbols(symbols, "raw_symbol"),
    stype_in       = stype_in,
    countries      = .db_join(countries),
    security_types = .db_join(security_types),
    allocate_isins = .db_bool(allocate_isins, "allocate_isins"),
    compression    = .db_enum(compression, db_compressions(), "compression")
  )), compression)
  out <- .db_security_time_cols(out)
  if ("ts_effective" %in% names(out)) {
    out <- out[order(out$ts_effective), , drop = FALSE]
  }
  out
}

.db_security_time_cols <- function(tb) {
  .db_time_cols(tb,
    datetime = c("ts_record", "ts_effective", "ts_created"),
    date = c("listing_created_date", "listing_date", "delisting_date",
             "shares_outstanding_date"))
}

# --- helpers ---------------------------------------------------------------

# Filters are sent as one comma-separated field, or omitted entirely.
.db_join <- function(x) {
  if (is.null(x) || !length(x)) return(NULL)
  x <- unlist(strsplit(as.character(x), ",", fixed = TRUE), use.names = FALSE)
  x <- trimws(x)
  x <- x[nzchar(x)]
  if (!length(x)) return(NULL)
  paste(x, collapse = ",")
}

# Stream a compressed JSON-lines response and read it into a tibble.
.db_jsonl <- function(req, compression = "zstd") {
  tmp <- tempfile(fileext = if (identical(compression, "zstd")) ".jsonl.zst" else ".jsonl")
  on.exit(unlink(tmp), add = TRUE)
  .db_perform(req, path = tmp)
  if (!file.exists(tmp) || file.size(tmp) == 0) return(tibble::tibble())
  input <- if (identical(compression, "zstd")) {
    arrow::CompressedInputStream$create(tmp, arrow::Codec$create("zstd"))
  } else {
    tmp
  }
  tb <- tryCatch(arrow::read_json_arrow(input, as_data_frame = TRUE),
                 error = function(e) {
                   stop("Could not parse the reference-data response: ",
                        conditionMessage(e), call. = FALSE)
                 })
  tibble::as_tibble(tb)
}

# Expand nested object columns into ordinary columns, keeping their position.
.db_flatten <- function(tb, cols) {
  cols <- intersect(cols, names(tb))
  for (nm in cols) {
    sub <- tb[[nm]]
    if (!is.data.frame(sub)) next
    tb[[nm]] <- NULL
    for (k in names(sub)) tb[[k]] <- sub[[k]]
  }
  tb
}

.db_time_cols <- function(tb, datetime = character(), date = character()) {
  if (!nrow(tb)) return(tb)
  for (nm in intersect(names(tb), datetime)) {
    if (is.character(tb[[nm]])) {
      tb[[nm]] <- as.POSIXct(tb[[nm]], tz = "UTC", format = "%Y-%m-%dT%H:%M:%OS")
    }
  }
  for (nm in intersect(names(tb), date)) {
    if (is.character(tb[[nm]])) tb[[nm]] <- as.Date(tb[[nm]])
  }
  tb
}

# A JSON object of name -> description becomes a two-column tibble.
.db_named_tbl <- function(x, name_col) {
  out <- if (!length(x)) {
    tibble::tibble(name = character(), description = character())
  } else {
    tibble::tibble(
      name = names(x),
      description = vapply(x, function(v) paste(as.character(unlist(v)),
                                                collapse = "; "),
                           character(1), USE.NAMES = FALSE)
    )
  }
  names(out)[1L] <- name_col
  out
}
