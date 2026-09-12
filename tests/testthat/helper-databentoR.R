# Shared test helpers.

# Perform `expr` against a mocked transport and return the request that was
# built, so the wire format can be asserted without touching the network.
capture_request <- function(expr, status = 200L, body = "1",
                            headers = list(`content-type` = "application/json")) {
  captured <- NULL
  mock <- function(req) {
    captured <<- req
    httr2::response(status_code = status, headers = headers,
                    body = charToRaw(body))
  }
  withr::local_envvar(DATABENTO_API_KEY = "db-testkeytestkeytestkeytestkey12")
  suppressWarnings(try(httr2::with_mocked_responses(mock, force(expr)),
                       silent = TRUE))
  captured
}

# The form body of a captured request, as a named character vector. httr2
# stores the values percent-encoded, which is how they go on the wire; decode
# them so the assertions read like the Python client's own test fixtures.
request_body <- function(req) {
  if (is.null(req$body)) return(character())
  vapply(req$body$data, function(v) curl::curl_unescape(as.character(v)),
         character(1))
}

request_method <- function(req) if (is.null(req$body)) "GET" else "POST"

# The query string of a captured request, as a named character vector.
request_query <- function(req) {
  q <- httr2::url_parse(req$url)$query
  if (is.null(q)) character() else vapply(q, as.character, character(1))
}

skip_if_no_key <- function() {
  testthat::skip_on_cran()
  testthat::skip_if(!db_has_key(), "DATABENTO_API_KEY is not set")
}

# Live tests cost money, so they only run when explicitly enabled.
skip_unless_live <- function() {
  skip_if_no_key()
  testthat::skip_if_not(
    identical(tolower(Sys.getenv("DATABENTOR_RUN_LIVE")), "true"),
    "set DATABENTOR_RUN_LIVE=true to run billed live tests"
  )
}

# The full live coverage sweep costs about 0.40 USD a pass, so it never runs
# by accident and no GitHub workflow sets this.
skip_unless_coverage <- function() {
  skip_if_no_key()
  testthat::skip_if_not(
    identical(tolower(Sys.getenv("DATABENTOR_RUN_COVERAGE")), "true"),
    "set DATABENTOR_RUN_COVERAGE=true to run the full billed coverage sweep"
  )
}
