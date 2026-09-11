.db_api_base <- "https://hist.databento.com/v0"

#' Is a Databento API key configured?
#'
#' Reads the environment variable `DATABENTO_API_KEY` (never store the key
#' in code or files). Set it once on Windows via
#' `setx DATABENTO_API_KEY "db-..."` and open a fresh session.
#'
#' @return `TRUE` if a key is set.
#' @export
db_has_key <- function() {
  nzchar(Sys.getenv("DATABENTO_API_KEY"))
}

.db_key <- function() {
  k <- Sys.getenv("DATABENTO_API_KEY")
  if (!nzchar(k)) {
    stop("Env var DATABENTO_API_KEY is not set. ",
         "Set it once via  setx DATABENTO_API_KEY \"db-...\"  ",
         "and start a new session.", call. = FALSE)
  }
  k
}

# Build an authenticated request for one endpoint (HTTP Basic: key as
# username, blank password). Retries transient failures with backoff.
.db_req <- function(endpoint) {
  httr2::request(paste0(.db_api_base, "/", endpoint)) |>
    httr2::req_auth_basic(.db_key(), "") |>
    httr2::req_user_agent("databentoR (R; https://github.com/sstoeckl/databentoR)") |>
    httr2::req_retry(max_tries = 4, backoff = function(i) 2^i)
}

# Common query-parameter block shared by cost and range endpoints.
.db_query <- function(req, dataset, schema, symbols, start, end,
                      stype_in = "parent") {
  stopifnot(is.character(dataset), length(dataset) == 1L,
            is.character(schema), length(schema) == 1L,
            is.character(symbols), length(symbols) >= 1L)
  httr2::req_url_query(req,
    dataset = dataset, schema = schema,
    symbols = paste(symbols, collapse = ","),
    start = start, end = end, stype_in = stype_in)
}
