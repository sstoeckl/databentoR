# The symbology namespace.

#' Resolve symbols from one symbol type to another
#'
#' Free of charge. Mirrors `symbology.resolve`. Resolution is time-dependent,
#' which is why the answer is a set of intervals per input symbol rather than
#' one mapping: an instrument id is only valid for the days it was assigned.
#'
#' @inheritParams db_get_cost
#' @param stype_out Symbol type to resolve to, see [db_stypes()].
#' @param start_date,end_date Resolution window, `start_date` required. Both
#'   take a `Date` or a `"YYYY-MM-DD"` string; timestamps are rejected, as in
#'   the Python client.
#' @return A tibble with one row per resolved interval: `input_symbol`,
#'   `start_date` (inclusive), `end_date` (exclusive) and `symbol`. Symbols
#'   the server resolved only partially or not at all are attached as the
#'   `"partial"` and `"not_found"` attributes, alongside `"status"` and
#'   `"message"`.
#' @family symbology
#' @examples
#' \dontrun{
#' db_resolve("GLBX.MDP3", "ES.FUT", stype_in = "parent",
#'            start_date = "2024-01-01", end_date = "2024-02-01")
#' }
#' @export
db_resolve <- function(dataset, symbols, stype_in = "raw_symbol",
                       stype_out = "instrument_id", start_date, end_date = NULL) {
  stype_in <- .db_enum(stype_in, db_stypes(), "stype_in")
  raw <- .db_json(.db_build("symbology.resolve", "POST", list(
    dataset    = .db_semantic_string(dataset, "dataset"),
    symbols    = .db_symbols(symbols, stype_in),
    stype_in   = stype_in,
    stype_out  = .db_enum(stype_out, db_stypes(), "stype_out"),
    start_date = .db_date(start_date, "start_date"),
    end_date   = .db_date(end_date, "end_date")
  )))

  rows <- list()
  for (input_symbol in names(raw$result)) {
    for (iv in raw$result[[input_symbol]]) {
      # The Python client skips intervals with an empty output symbol.
      if (is.null(iv$s) || !nzchar(as.character(iv$s))) next
      rows[[length(rows) + 1L]] <- c(input_symbol, as.character(iv$d0),
                                     as.character(iv$d1), as.character(iv$s))
    }
  }
  out <- if (length(rows)) {
    m <- do.call(rbind, rows)
    tibble::tibble(
      input_symbol = m[, 1L],
      start_date = as.Date(m[, 2L]),
      end_date = as.Date(m[, 3L]),
      symbol = m[, 4L]
    )
  } else {
    tibble::tibble(input_symbol = character(), start_date = as.Date(character()),
                   end_date = as.Date(character()), symbol = character())
  }
  attr(out, "partial") <- .db_chr(raw$partial)
  attr(out, "not_found") <- .db_chr(raw$not_found)
  attr(out, "status") <- as.character(raw$status %||% NA)
  attr(out, "message") <- as.character(raw$message %||% NA)
  out
}
