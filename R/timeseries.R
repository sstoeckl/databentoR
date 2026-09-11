#' Download a historical data range as a tibble (CSV encoding, no DBN)
#'
#' Mirrors `timeseries.get_range` of the official Python client, using the
#' HTTP API's CSV encoding with pretty prices/timestamps and mapped symbols,
#' so no binary DBN decoding is required. The response is streamed to a
#' temporary file and read with 'arrow'.
#'
#' **Costs money** (billed per GB): call [db_get_cost()] with the same
#' arguments first.
#'
#' @inheritParams db_get_cost
#' @param path Optional file path; when given, the result is also written
#'   as parquet to `path` (directories are created).
#' @return A tibble; invisibly when `path` is given.
#' @export
db_get_range <- function(dataset, schema, symbols, start, end,
                         stype_in = "parent", path = NULL) {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)
  .db_req("timeseries.get_range") |>
    .db_query(dataset, schema, symbols, start, end, stype_in) |>
    httr2::req_url_query(encoding = "csv", compression = "none",
                         pretty_px = "true", pretty_ts = "true",
                         map_symbols = "true") |>
    httr2::req_perform(path = tmp)
  tb <- tibble::as_tibble(arrow::read_csv_arrow(tmp))
  if (!is.null(path)) {
    dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
    arrow::write_parquet(tb, path)
    return(invisible(tb))
  }
  tb
}
