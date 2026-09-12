# Coercion and validation helpers.
#
# These mirror the official Python client's `common/parsing.py` and
# `common/validation.py` so that databentoR puts the same bytes on the wire.
# Deliberate divergences are flagged with a comment.

#' Schemas, symbol types, encodings and compressions
#'
#' The historical API validates these server-side; databentoR validates them
#' client-side first, exactly as the official Python client does, so that a
#' typo fails locally instead of costing a round trip.
#'
#' If Databento adds a value that is not yet listed here, update the package.
#' The weekly `upstream-watch` workflow reports new values as soon as they
#' appear in the Python client.
#'
#' @return A character vector of accepted values.
#' @examples
#' db_schemas()
#' db_stypes()
#' @name db_enums
NULL

#' @rdname db_enums
#' @export
db_schemas <- function() {
  c("mbo", "mbp-1", "mbp-10", "bbo-1s", "bbo-1m", "tbbo", "trades",
    "ohlcv-1s", "ohlcv-1m", "ohlcv-1h", "ohlcv-1d", "ohlcv-eod",
    "definition", "statistics", "status", "imbalance",
    "cmbp-1", "cbbo-1s", "cbbo-1m", "tcbbo")
}

#' @rdname db_enums
#' @export
db_stypes <- function() {
  c("raw_symbol", "instrument_id", "parent", "continuous")
}

#' @rdname db_enums
#' @export
db_encodings <- function() c("dbn", "csv", "json")

#' @rdname db_enums
#' @export
db_compressions <- function() c("none", "zstd")

.db_enum <- function(value, allowed, arg) {
  if (is.null(value)) return(NULL)
  if (!is.character(value) || length(value) != 1L || is.na(value)) {
    stop(sprintf("`%s` must be a single string, one of: %s.",
                 arg, paste(allowed, collapse = ", ")), call. = FALSE)
  }
  value <- tolower(trimws(value))
  if (!value %in% allowed) {
    stop(sprintf("`%s` must be one of: %s. Got %s.",
                 arg, paste(allowed, collapse = ", "), dQuote(value, FALSE)),
         call. = FALSE)
  }
  value
}

# validate_semantic_string(): non-empty, not whitespace only. No case folding,
# so `dataset` must already read "GLBX.MDP3".
.db_semantic_string <- function(value, arg) {
  if (!is.character(value) || length(value) != 1L || is.na(value)) {
    stop(sprintf("`%s` must be a single string.", arg), call. = FALSE)
  }
  if (!nzchar(trimws(value))) {
    stop(sprintf("`%s` must not be empty.", arg), call. = FALSE)
  }
  value
}

# validate_smart_symbol(): upper-case the whole symbol, then lower-case the
# middle token of a three-part continuous symbol, because the API expects the
# roll rule in lower case (ES.n.0).
.db_smart_symbol <- function(symbol) {
  s <- toupper(trimws(symbol))
  parts <- strsplit(s, ".", fixed = TRUE)[[1]]
  ok <- length(parts) >= 1L && length(parts) <= 3L && all(nzchar(parts))
  if (!ok) {
    stop(sprintf("%s is not a valid parent or continuous symbol. Use ",
                 dQuote(symbol, FALSE)),
         "[ROOT], [ROOT].[ASSET_CLASS] or [ROOT].[ROLL_RULE].[RANK].",
         call. = FALSE)
  }
  if (length(parts) == 3L) parts[2L] <- tolower(parts[2L])
  paste(parts, collapse = ".")
}

# Documented maximum number of symbols per request. The Python client does not
# enforce it; databentoR does, because discovering it server-side after a long
# upload is a worse experience.
.db_max_symbols <- 2000L

.db_symbols <- function(symbols, stype_in = "raw_symbol") {
  if (is.null(symbols) || identical(symbols, NA)) return("ALL_SYMBOLS")
  if (is.numeric(symbols)) {
    if (!identical(stype_in, "instrument_id")) {
      stop("Numeric symbols are only valid with `stype_in = \"instrument_id\"`. ",
           "Pass raw symbols as strings.", call. = FALSE)
    }
    symbols <- format(as.integer(symbols), scientific = FALSE, trim = TRUE)
  }
  if (!is.character(symbols)) {
    stop("`symbols` must be a character vector, or numeric instrument ids.",
         call. = FALSE)
  }
  # accept both c("ES.FUT", "ZQ.FUT") and "ES.FUT,ZQ.FUT"
  symbols <- unlist(strsplit(symbols, ",", fixed = TRUE), use.names = FALSE)
  symbols <- trimws(symbols)
  symbols <- symbols[nzchar(symbols)]
  if (!length(symbols)) stop("`symbols` must not be empty.", call. = FALSE)
  if (length(symbols) > .db_max_symbols) {
    stop(sprintf("Databento accepts at most %d symbols per request, got %d. ",
                 .db_max_symbols, length(symbols)),
         "Split the request or submit a batch job.", call. = FALSE)
  }
  out <- if (!is.null(stype_in) && stype_in %in% c("parent", "continuous")) {
    vapply(symbols, .db_smart_symbol, character(1), USE.NAMES = FALSE)
  } else {
    toupper(symbols)
  }
  paste(out, collapse = ",")
}

# Timestamp parameters (`start`, `end`): a string passes through verbatim, a
# number is nanoseconds since the UNIX epoch, a Date becomes a plain ISO date
# and a POSIXct an ISO-8601 UTC instant. Mirrors datetime_to_string().
.db_datetime <- function(value, arg) {
  if (is.null(value)) return(NULL)
  if (length(value) != 1L) {
    stop(sprintf("`%s` must be a single value.", arg), call. = FALSE)
  }
  if (is.character(value)) return(value)
  if (inherits(value, "POSIXt")) {
    return(paste0(format(as.POSIXct(value), "%Y-%m-%dT%H:%M:%S", tz = "UTC"),
                  "+00:00"))
  }
  if (inherits(value, "Date")) return(format(value, "%Y-%m-%d"))
  if (is.numeric(value)) return(format(value, scientific = FALSE, trim = TRUE))
  stop(sprintf("`%s` must be a string, Date, POSIXct or nanosecond count.", arg),
       call. = FALSE)
}

# Date parameters (`start_date`, `end_date`) are stricter than timestamps: the
# Python client rejects datetimes here, and so do we, because silently
# truncating an instant to a date changes the answer.
.db_date <- function(value, arg) {
  if (is.null(value)) return(NULL)
  if (length(value) != 1L) {
    stop(sprintf("`%s` must be a single value.", arg), call. = FALSE)
  }
  if (is.character(value)) return(value)
  if (inherits(value, "POSIXt")) {
    stop(sprintf("`%s` takes a date, not a timestamp. Wrap it in as.Date().", arg),
         call. = FALSE)
  }
  if (inherits(value, "Date")) return(format(value, "%Y-%m-%d"))
  stop(sprintf("`%s` must be a Date or a \"YYYY-MM-DD\" string.", arg),
       call. = FALSE)
}

# The Python client puts raw Python booleans in the form body, which urlencode
# renders as "True"/"False". Matching that keeps the wire fixtures honest.
.db_bool <- function(value, arg) {
  if (is.null(value)) return(NULL)
  if (!is.logical(value) || length(value) != 1L || is.na(value)) {
    stop(sprintf("`%s` must be TRUE or FALSE.", arg), call. = FALSE)
  }
  if (value) "True" else "False"
}

# Lower-case flags, for the text-encoding query parameters that the HTTP API
# defines but the (always-DBN) Python client never sends.
.db_flag <- function(value, arg) {
  if (is.null(value)) return(NULL)
  if (!is.logical(value) || length(value) != 1L || is.na(value)) {
    stop(sprintf("`%s` must be TRUE or FALSE.", arg), call. = FALSE)
  }
  if (value) "true" else "false"
}

.db_int <- function(value, arg) {
  if (is.null(value)) return(NULL)
  if (!is.numeric(value) || length(value) != 1L || is.na(value)) {
    stop(sprintf("`%s` must be a single number.", arg), call. = FALSE)
  }
  format(as.numeric(value), scientific = FALSE, trim = TRUE)
}

# Drop NULL entries, keep insertion order: the HTTP layer drops unset
# parameters, and the order is what the wire fixtures pin down.
.db_compact <- function(x) x[!vapply(x, is.null, logical(1))]
