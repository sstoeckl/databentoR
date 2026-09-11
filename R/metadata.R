#' List available Databento datasets
#'
#' Metadata endpoints are free of charge.
#'
#' @return Character vector of dataset codes (e.g. `"GLBX.MDP3"`,
#'   `"OPRA.PILLAR"`).
#' @export
db_list_datasets <- function() {
  resp <- .db_req("metadata.list_datasets") |> httr2::req_perform()
  unlist(httr2::resp_body_json(resp), use.names = FALSE)
}

#' List schemas available for a dataset
#'
#' @param dataset Dataset code, e.g. `"GLBX.MDP3"`.
#' @return Character vector of schema names (e.g. `"ohlcv-1m"`).
#' @export
db_list_schemas <- function(dataset) {
  resp <- .db_req("metadata.list_schemas") |>
    httr2::req_url_query(dataset = dataset) |>
    httr2::req_perform()
  unlist(httr2::resp_body_json(resp), use.names = FALSE)
}

#' Cost preview in USD for one historical request (no download)
#'
#' Mirrors `metadata.get_cost` of the official Python client. Use this
#' before every [db_get_range()] call — previews are free, downloads are
#' billed per GB.
#'
#' @param dataset,schema,symbols,start,end,stype_in Request definition;
#'   `symbols` may be a character vector (joined with commas),
#'   `stype_in = "parent"` accepts symbols like `"ES.FUT"` or `"SPX.OPT"`.
#' @return A single number: the quoted cost in USD.
#' @export
db_get_cost <- function(dataset, schema, symbols, start, end,
                        stype_in = "parent") {
  resp <- .db_req("metadata.get_cost") |>
    .db_query(dataset, schema, symbols, start, end, stype_in) |>
    httr2::req_perform()
  as.numeric(httr2::resp_body_string(resp))
}
