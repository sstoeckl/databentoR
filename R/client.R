# The HTTP layer: authentication, request construction, error translation.
#
# Wire contract (verified against the official Python client 0.86.0 and the
# HTTP API reference):
#   * base URL  https://hist.databento.com/v0
#   * endpoint names are dotted and appended to the base URL, so the
#     metadata namespace becomes .../v0/metadata.list_datasets
#   * HTTP Basic auth, API key as the username, empty password
#   * endpoints that carry `symbols` are POST with an
#     application/x-www-form-urlencoded body; the rest are GET with a query
#     string. Unset parameters are omitted entirely, never sent empty.

.db_api_base <- "https://hist.databento.com/v0"

#' Is a Databento API key configured?
#'
#' Reads the environment variable `DATABENTO_API_KEY`. Never store the key in
#' code, scripts or test fixtures. Set it once per machine:
#'
#' ```
#' setx DATABENTO_API_KEY "db-XXXX..."   # Windows, then open a new session
#' export DATABENTO_API_KEY="db-XXXX..." # macOS / Linux, in ~/.profile
#' ```
#'
#' `usethis::edit_r_environ()` is the portable alternative.
#'
#' @return `TRUE` when a key is set, otherwise `FALSE`.
#' @examples
#' db_has_key()
#' @export
db_has_key <- function() {
  nzchar(Sys.getenv("DATABENTO_API_KEY"))
}

.db_key <- function() {
  key <- Sys.getenv("DATABENTO_API_KEY")
  if (!nzchar(trimws(key))) {
    stop("No Databento API key found. Set the environment variable ",
         "DATABENTO_API_KEY (see ?db_has_key), then start a new R session.",
         call. = FALSE)
  }
  if (identical(key, "YOUR_API_KEY")) {
    stop("DATABENTO_API_KEY is still the placeholder \"YOUR_API_KEY\". ",
         "Replace it with a key from https://databento.com/portal/keys.",
         call. = FALSE)
  }
  key
}

# Identify the client honestly: databentoR is not the official client.
.db_user_agent <- function() {
  ver <- tryCatch(as.character(utils::packageVersion("databentoR")),
                  error = function(e) "dev")
  si <- Sys.info()
  os <- if (is.null(si)) "unknown" else paste0(si[["sysname"]], "/", si[["release"]])
  gsub("[^a-zA-Z0-9./ -]", "-",
       sprintf("databentoR/%s R/%s %s", ver, getRversion(), os))
}

# Turn the API's JSON error body into a readable set of bullets. The server
# returns {"detail": "..."} or {"detail": {"case", "message", "docs"}}.
.db_error_body <- function(resp) {
  detail <- tryCatch(httr2::resp_body_json(resp)$detail, error = function(e) NULL)
  status <- httr2::resp_status(resp)
  head <- switch(as.character(status),
    "408" = "The request transmission timed out.",
    "504" = "The remote gateway timed out.",
    NULL)
  msg <- if (is.list(detail)) {
    c(detail$case, detail$message,
      if (!is.null(detail$docs)) paste("Documentation:", detail$docs))
  } else if (is.character(detail)) {
    detail
  } else {
    NULL
  }
  out <- c(head, msg)
  if (!length(out)) NULL else as.character(out)
}

# The API reports deprecations and soft failures in an X-Warning header that
# holds a JSON array of "Type: message" strings. The Python client re-raises
# them; so do we, or the user never sees them.
.db_check_warnings <- function(resp) {
  raw <- tryCatch(httr2::resp_header(resp, "X-Warning"), error = function(e) NULL)
  if (is.null(raw) || !nzchar(raw)) return(invisible(NULL))
  msgs <- tryCatch(unlist(jsonlite::fromJSON(raw), use.names = FALSE),
                   error = function(e) raw)
  for (m in msgs) warning("Databento: ", m, call. = FALSE)
  invisible(NULL)
}

#' Build a request against one historical endpoint
#'
#' Internal. `billed = TRUE` disables retries: `timeseries.get_range` is
#' charged per gigabyte, and silently repeating a failed stream can be billed
#' more than once. Metadata endpoints are free, so they retry.
#'
#' @param endpoint Dotted endpoint name, e.g. `"metadata.get_cost"`.
#' @param method `"GET"` or `"POST"`.
#' @param params Named list of parameters; `NULL` entries are dropped.
#' @param billed Whether the endpoint costs money.
#' @param auth Whether to send credentials. Two reference endpoints are
#'   public and the Python client sends no Authorization header for them.
#' @return An `httr2_request`.
#' @noRd
.db_build <- function(endpoint, method = c("GET", "POST"), params = list(),
                      billed = FALSE, auth = TRUE) {
  method <- match.arg(method)
  params <- .db_compact(params)

  req <- httr2::request(paste0(.db_api_base, "/", endpoint)) |>
    httr2::req_headers(accept = "application/json") |>
    httr2::req_user_agent(.db_user_agent()) |>
    httr2::req_timeout(100) |>
    httr2::req_error(body = .db_error_body)
  if (auth) req <- httr2::req_auth_basic(req, .db_key(), "")

  req <- if (identical(method, "POST")) {
    do.call(httr2::req_body_form, c(list(req), params))
  } else if (length(params)) {
    do.call(httr2::req_url_query, c(list(req), params))
  } else {
    req
  }

  if (billed) {
    req
  } else {
    httr2::req_retry(
      req,
      max_tries = 4L,
      is_transient = function(resp) httr2::resp_status(resp) %in% c(429L, 500L, 502L, 503L, 504L),
      backoff = function(i) 2^i
    )
  }
}

.db_perform <- function(req, path = NULL) {
  resp <- if (is.null(path)) httr2::req_perform(req) else httr2::req_perform(req, path = path)
  .db_check_warnings(resp)
  # 206 is a success code that means the server could only resolve some of
  # the symbols. Silence here would look like a complete answer.
  if (identical(httr2::resp_status(resp), 206L)) {
    warning("Databento resolved only some of the requested symbols ",
            "(HTTP 206 Partial Content). Check the result for gaps.",
            call. = FALSE)
  }
  resp
}

.db_json <- function(req) {
  # check_type = FALSE: the API does not document the success content type,
  # so trusting it would make the client brittle for no benefit.
  httr2::resp_body_json(.db_perform(req), check_type = FALSE,
                        simplifyVector = FALSE)
}

# Several endpoints answer with a bare JSON scalar (a number or a quoted
# string) rather than an object.
.db_scalar <- function(req) {
  txt <- httr2::resp_body_string(.db_perform(req))
  as.numeric(gsub('"', "", trimws(txt), fixed = TRUE))
}
