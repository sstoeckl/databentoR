# The batch namespace: asynchronous jobs for requests too large to stream.

#' Submit a batch job
#'
#' Mirrors `batch.submit_job`. Batch jobs are the way to request slices too
#' large to stream with [db_get_range()] — Databento recommends them above
#' about five gigabytes. Submit the job, poll it with [db_batch_list_jobs()],
#' then fetch the output with [db_batch_download()].
#'
#' Defaults follow the Python client, so `encoding` is `"dbn"`. Note that
#' databentoR can read back only the `"csv"` and `"json"` encodings; a DBN job
#' downloads fine but needs a DBN decoder to open.
#'
#' @inheritParams db_get_cost
#' @param stype_out Symbol type of the output, see [db_stypes()].
#' @param encoding Output encoding, see [db_encodings()].
#' @param compression Output compression, see [db_compressions()].
#' @param pretty_px Write decimal prices instead of fixed-point integers.
#' @param pretty_ts Write ISO-8601 timestamps instead of nanosecond counts.
#' @param map_symbols Append a `symbol` field to every record. `NULL`, the
#'   default, means `TRUE` for the text encodings and `FALSE` for DBN.
#' @param split_symbols Split the output into one file per symbol.
#' @param split_duration Split the output by `"day"`, `"week"`, `"month"`,
#'   `"year"` or `"none"`.
#' @param split_size Optional maximum size per output file, in bytes.
#' @param delivery Delivery mechanism; `"download"` is the only one offered.
#' @return A one-row tibble of the job's properties, including its `id`.
#' @family batch
#' @examples
#' \dontrun{
#' job <- db_batch_submit_job("OPRA.PILLAR", symbols = "SPX.OPT",
#'                            schema = "ohlcv-1d", start = "2024-01-01",
#'                            end = "2024-02-01", encoding = "csv",
#'                            stype_in = "parent")
#' job$id
#' }
#' @export
db_batch_submit_job <- function(dataset, symbols, schema, start, end = NULL,
                                encoding = "dbn", compression = "zstd",
                                pretty_px = FALSE, pretty_ts = FALSE,
                                map_symbols = NULL, split_symbols = FALSE,
                                split_duration = "day", split_size = NULL,
                                delivery = "download", stype_in = "raw_symbol",
                                stype_out = "instrument_id", limit = NULL) {
  stype_in <- .db_enum(stype_in, db_stypes(), "stype_in")
  encoding <- .db_enum(encoding, db_encodings(), "encoding")
  if (is.null(symbols)) {
    stop("`symbols` is required for a batch job; all symbols is not accepted here.",
         call. = FALSE)
  }
  if (is.null(map_symbols)) map_symbols <- !identical(encoding, "dbn")

  .db_tbl(list(.db_json(.db_build("batch.submit_job", "POST", list(
    dataset        = .db_semantic_string(dataset, "dataset"),
    start          = .db_datetime(start, "start"),
    end            = .db_datetime(end, "end"),
    symbols        = .db_symbols(symbols, stype_in),
    schema         = .db_enum(schema, db_schemas(), "schema"),
    stype_in       = stype_in,
    stype_out      = .db_enum(stype_out, db_stypes(), "stype_out"),
    encoding       = encoding,
    compression    = .db_enum(compression, db_compressions(), "compression"),
    pretty_px      = .db_bool(pretty_px, "pretty_px"),
    pretty_ts      = .db_bool(pretty_ts, "pretty_ts"),
    map_symbols    = .db_bool(map_symbols, "map_symbols"),
    split_symbols  = .db_bool(split_symbols, "split_symbols"),
    split_duration = .db_enum(split_duration,
                              c("day", "week", "month", "year", "none"),
                              "split_duration"),
    delivery       = .db_enum(delivery, "download", "delivery"),
    limit          = .db_int(limit, "limit"),
    split_size     = .db_int(split_size, "split_size")
  )))))
}

#' Look up one batch job
#'
#' Mirrors `batch.get_job_details`.
#'
#' @param job_id Job identifier, as returned by [db_batch_submit_job()].
#' @return A one-row tibble of the job's properties.
#' @family batch
#' @examples
#' \dontrun{
#' db_batch_get_job_details("GLBX-20240101-ABCDEF")
#' }
#' @export
db_batch_get_job_details <- function(job_id) {
  .db_tbl(list(.db_json(.db_build("batch.get_job_details", "GET", list(
    job_id = .db_semantic_string(job_id, "job_id")
  )))))
}

#' List your batch jobs
#'
#' Mirrors `batch.list_jobs`.
#'
#' @param states Job states to include, as a character vector or a single
#'   comma-separated string: `"queued"`, `"processing"`, `"done"`,
#'   `"expired"`.
#' @param since Optional lower bound on the job's received timestamp.
#' @param short Ask the server for only `id`, `state` and `ts_received`, which
#'   is the cheap way to poll.
#' @return A tibble with one row per job.
#' @family batch
#' @examples
#' \dontrun{
#' db_batch_list_jobs(states = "done")
#' }
#' @export
db_batch_list_jobs <- function(states = c("queued", "processing", "done"),
                               since = NULL, short = NULL) {
  if (!is.null(states)) {
    states <- unlist(strsplit(as.character(states), ",", fixed = TRUE),
                     use.names = FALSE)
    states <- vapply(trimws(states), .db_enum, character(1),
                     allowed = c("queued", "processing", "done", "expired"),
                     arg = "states", USE.NAMES = FALSE)
    states <- paste(states, collapse = ",")
  }
  .db_tbl(.db_json(.db_build("batch.list_jobs", "GET", list(
    states = states,
    since  = .db_datetime(since, "since"),
    short  = .db_bool(short, "short")
  ))))
}

#' List the files a finished batch job produced
#'
#' Mirrors `batch.list_files`.
#'
#' @inheritParams db_batch_get_job_details
#' @return A tibble with `filename`, `hash`, `size` and the download `url`.
#' @family batch
#' @examples
#' \dontrun{
#' db_batch_list_files("GLBX-20240101-ABCDEF")
#' }
#' @export
db_batch_list_files <- function(job_id) {
  raw <- .db_json(.db_build("batch.list_files", "GET", list(
    job_id = .db_semantic_string(job_id, "job_id")
  )))
  if (!length(raw)) {
    return(tibble::tibble(filename = character(), hash = character(),
                          size = numeric(), url = character()))
  }
  tibble::tibble(
    filename = vapply(raw, function(f) as.character(f$filename %||% NA), character(1)),
    hash     = vapply(raw, function(f) as.character(f$hash %||% NA), character(1)),
    size     = vapply(raw, function(f) as.numeric(f$size %||% NA), numeric(1)),
    url      = vapply(raw, function(f) as.character(f$urls$https %||% NA), character(1))
  )
}

#' Download the output of a batch job
#'
#' Mirrors `batch.download`. With `filename_to_download = NULL` the whole job
#' is fetched as one zip archive and unpacked; naming a single file fetches
#' just that file from the job manifest.
#'
#' A file that already exists locally at the size the manifest reports is left
#' alone, so an interrupted download resumes by calling the function again.
#' When the `digest` package is installed, each file's SHA-256 is checked
#' against the manifest and a mismatch raises a warning.
#'
#' @inheritParams db_batch_get_job_details
#' @param output_dir Directory to write into; a subdirectory named after the
#'   job is created inside it. Defaults to the working directory.
#' @param filename_to_download Optional single file from the job manifest.
#' @param keep_zip Keep the archive after unpacking it. Only meaningful when
#'   downloading a whole job.
#' @return A character vector of the paths written, invisibly.
#' @family batch
#' @examples
#' \dontrun{
#' db_batch_download("GLBX-20240101-ABCDEF", output_dir = tempdir())
#' }
#' @export
db_batch_download <- function(job_id, output_dir = ".",
                              filename_to_download = NULL, keep_zip = FALSE) {
  job_id <- .db_semantic_string(job_id, "job_id")
  if (!is.null(filename_to_download) && keep_zip) {
    stop("`keep_zip` only applies when downloading a whole job.", call. = FALSE)
  }
  dest_dir <- file.path(output_dir, job_id)
  dir.create(dest_dir, showWarnings = FALSE, recursive = TRUE)

  if (is.null(filename_to_download)) {
    zip_path <- file.path(dest_dir, paste0(job_id, ".zip"))
    .db_perform(.db_build("batch.download", "GET", list(job_id = job_id),
                          billed = TRUE), path = zip_path)
    files <- utils::unzip(zip_path, exdir = dest_dir)
    if (!keep_zip) unlink(zip_path)
    return(invisible(files))
  }

  manifest <- db_batch_list_files(job_id)
  row <- manifest[manifest$filename == filename_to_download, , drop = FALSE]
  if (!nrow(row)) {
    stop(sprintf("Batch job %s has no file named %s.", job_id,
                 dQuote(filename_to_download, FALSE)), call. = FALSE)
  }
  if (is.na(row$url[[1L]])) {
    stop("This job was not delivered for download, so its files have no URL.",
         call. = FALSE)
  }
  dest <- file.path(dest_dir, filename_to_download)
  if (file.exists(dest) && !is.na(row$size[[1L]]) &&
      file.size(dest) == row$size[[1L]]) {
    return(invisible(dest))
  }
  req <- httr2::request(row$url[[1L]]) |>
    httr2::req_auth_basic(.db_key(), "") |>
    httr2::req_user_agent(.db_user_agent()) |>
    httr2::req_error(body = .db_error_body)
  .db_perform(req, path = dest)
  .db_verify_hash(dest, row$hash[[1L]])
  invisible(dest)
}

.db_verify_hash <- function(path, hash) {
  if (is.na(hash) || !startsWith(hash, "sha256:")) return(invisible(NULL))
  if (!requireNamespace("digest", quietly = TRUE)) return(invisible(NULL))
  got <- digest::digest(file = path, algo = "sha256")
  if (!identical(got, sub("^sha256:", "", hash))) {
    warning(sprintf("Checksum mismatch for %s; the download may be incomplete.",
                    basename(path)), call. = FALSE)
  }
  invisible(NULL)
}
