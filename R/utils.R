# Small helpers for turning the API's JSON into tibbles.

# A JSON array of scalars becomes a character vector.
.db_chr <- function(x) {
  if (is.null(x)) return(character())
  as.character(unlist(x, use.names = FALSE))
}

# A JSON array of flat objects becomes a tibble: the union of all keys, with
# missing keys filled in as NA and empty results returning a zero-row tibble.
.db_tbl <- function(x, cols = NULL) {
  if (is.null(x) || !length(x)) {
    if (is.null(cols)) return(tibble::tibble())
    out <- rep(list(character()), length(cols))
    names(out) <- cols
    return(tibble::as_tibble(out))
  }
  if (!is.list(x[[1L]])) {
    return(tibble::tibble(value = .db_chr(x)))
  }
  keys <- unique(unlist(lapply(x, names), use.names = FALSE))
  cells <- lapply(keys, function(k) {
    vapply(x, function(row) {
      v <- row[[k]]
      if (is.null(v) || !length(v)) NA_character_ else as.character(v[[1L]])
    }, character(1))
  })
  names(cells) <- keys
  out <- tibble::as_tibble(cells)
  .db_retype(out)
}

# The API sends everything as JSON scalars; give the obvious columns their
# natural R type so downstream joins and arithmetic work.
.db_retype <- function(tb) {
  num_cols <- c("publisher_id", "instrument_id", "size", "unit_price",
                "cost_usd", "record_count", "billable_size")
  date_cols <- c("date", "start_date", "end_date", "last_modified_date")
  for (nm in intersect(names(tb), num_cols)) {
    v <- suppressWarnings(as.numeric(tb[[nm]]))
    if (!any(is.na(v) & !is.na(tb[[nm]]))) tb[[nm]] <- v
  }
  for (nm in intersect(names(tb), date_cols)) {
    v <- suppressWarnings(as.Date(tb[[nm]]))
    if (!any(is.na(v) & !is.na(tb[[nm]]))) tb[[nm]] <- v
  }
  tb
}
