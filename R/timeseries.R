# The timeseries namespace: the one billed endpoint.

#' Download a historical range as a tibble
#'
#' Mirrors `timeseries.get_range`. Where the Python client always asks for the
#' binary DBN encoding and decodes it locally, databentoR asks the API for the
#' CSV encoding and reads it with arrow, so no DBN decoder is needed. The data
#' is identical; see `vignette("equivalence")` for the column-by-column
#' comparison and the handful of documented differences.
#'
#' **This endpoint costs money**, billed per gigabyte. Call [db_get_cost()]
#' with the same arguments first; previews are free. For the same reason this
#' is the only request databentoR never retries: a retried stream can be
#' billed twice.
#'
#' Column types are assigned explicitly from the field name, never inferred.
#' Inference is unsafe here: a `trades` slice whose `action` column is all
#' `"T"` would otherwise be read as boolean. See [db_field_types()].
#'
#' Fields that are 64-bit on the wire come back as `bit64::integer64` rather
#' than double, so `order_id`, `raw_instrument_id` and an undefined
#' statistics `quantity` survive intact.
#'
#' Row order is the server's, and the server does not guarantee a stable
#' order among records that share a timestamp: two downloads of the same
#' slice can return the same rows in a different sequence. Sort on
#' `ts_event`/`ts_recv` and `instrument_id` if you need a reproducible order.
#'
#' @inheritParams db_get_cost
#' @param stype_out Symbol type of the output, see [db_stypes()]. The API
#'   resolves to `"instrument_id"` from every input type, and to
#'   `"raw_symbol"` only from `"instrument_id"`.
#' @param path Optional file path. When given, the result is also written
#'   there as parquet, and the tibble is returned invisibly.
#' @param pretty_px Ask the server for decimal prices instead of fixed-point
#'   integers scaled by 1e-9.
#' @param pretty_ts Ask the server for ISO-8601 timestamps instead of
#'   nanosecond counts. With `FALSE` the timestamp columns come back as
#'   character, because a nanosecond count does not fit an R numeric type
#'   without loss.
#' @param map_symbols Ask the server to append a `symbol` column to every
#'   record.
#' @param ts_type How timestamps are represented in R. `"POSIXct"`, the
#'   default, is convenient but stores seconds as a double, so on modern dates
#'   it resolves to roughly a quarter of a microsecond rather than to the
#'   nanosecond. `"integer64"` keeps the exact nanosecond count (it requires
#'   the `bit64` package and forces `pretty_ts = FALSE`), which is what you
#'   want for book reconstruction or any latency work.
#' @param compression Transfer compression, `"none"` or `"zstd"`. `"zstd"`
#'   is worth it for large pulls and is decompressed transparently.
#' @param col_types Optional arrow schema overriding the column types
#'   databentoR would assign.
#' @return A tibble, invisibly when `path` is given.
#' @family timeseries
#' @examples
#' \dontrun{
#' # always preview the cost first
#' db_get_cost("GLBX.MDP3", start = "2024-01-01", end = "2024-02-01",
#'             symbols = "ES.FUT", schema = "ohlcv-1d", stype_in = "parent")
#'
#' es <- db_get_range("GLBX.MDP3", start = "2024-01-01", end = "2024-02-01",
#'                    symbols = "ES.FUT", schema = "ohlcv-1d",
#'                    stype_in = "parent")
#' }
#' @export
db_get_range <- function(dataset, start, end = NULL, symbols = NULL,
                         schema = "trades", stype_in = "raw_symbol",
                         stype_out = "instrument_id", limit = NULL,
                         path = NULL, pretty_px = TRUE, pretty_ts = TRUE,
                         map_symbols = TRUE, ts_type = c("POSIXct", "integer64"),
                         compression = c("none", "zstd"), col_types = NULL) {
  compression <- match.arg(compression)
  ts_type <- match.arg(ts_type)
  stype_in <- .db_enum(stype_in, db_stypes(), "stype_in")
  if (identical(ts_type, "integer64")) {
    if (!requireNamespace("bit64", quietly = TRUE)) {
      stop("`ts_type = \"integer64\"` needs the bit64 package. ",
           "Install it, or use the default \"POSIXct\".", call. = FALSE)
    }
    # Nanosecond counts only survive intact as raw integers.
    pretty_ts <- FALSE
  }

  req <- .db_build("timeseries.get_range", "POST", list(
    dataset     = .db_semantic_string(dataset, "dataset"),
    start       = .db_datetime(start, "start"),
    symbols     = .db_symbols(symbols, stype_in),
    schema      = .db_enum(schema, db_schemas(), "schema"),
    stype_in    = stype_in,
    stype_out   = .db_enum(stype_out, db_stypes(), "stype_out"),
    encoding    = "csv",
    compression = compression,
    pretty_px   = .db_flag(pretty_px, "pretty_px"),
    pretty_ts   = .db_flag(pretty_ts, "pretty_ts"),
    map_symbols = .db_flag(map_symbols, "map_symbols"),
    limit       = .db_int(limit, "limit"),
    end         = .db_datetime(end, "end")
  ), billed = TRUE)

  tmp <- tempfile(fileext = if (compression == "zstd") ".csv.zst" else ".csv")
  on.exit(unlink(tmp), add = TRUE)
  .db_perform(req, path = tmp)

  tb <- .db_read_csv(tmp, compression = compression, pretty_px = pretty_px,
                     pretty_ts = pretty_ts, col_types = col_types,
                     schema = schema)
  if (identical(ts_type, "integer64")) tb <- .db_ts_integer64(tb)

  if (!is.null(path)) {
    dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
    arrow::write_parquet(tb, path)
    return(invisible(tb))
  }
  tb
}

# Undefined timestamps are 2^64-1, which no signed type holds, so they arrive
# as text and become NA here.
.db_undef_ts <- "18446744073709551615"

.db_ts_integer64 <- function(tb) {
  for (nm in intersect(names(tb), .db_ts_fields)) {
    if (!is.character(tb[[nm]])) next
    v <- tb[[nm]]
    v[!nzchar(v) | v == .db_undef_ts] <- NA_character_
    tb[[nm]] <- bit64::as.integer64(v)
  }
  tb
}

# Read a Databento CSV slice with explicit column types.
.db_read_csv <- function(file, compression = "none", pretty_px = TRUE,
                         pretty_ts = TRUE, col_types = NULL, schema = NULL) {
  # arrow downcasts 64-bit integers to double by default, which silently
  # mangles the fields that genuinely need the range: order_id and
  # raw_instrument_id are unsigned 64-bit, and an undefined statistics
  # quantity is the int64 maximum, which no double represents.
  old <- options(arrow.int64_downcast = FALSE)
  on.exit(options(old), add = TRUE)
  input <- if (identical(compression, "zstd")) {
    arrow::CompressedInputStream$create(file, arrow::Codec$create("zstd"))
  } else {
    file
  }
  header <- .db_csv_header(file, compression)
  if (!length(header)) return(tibble::tibble())

  sch <- col_types %||% .db_arrow_schema(header, pretty_px, pretty_ts, schema)
  tb <- arrow::read_csv_arrow(input, schema = sch, skip = 1L,
                              as_data_frame = TRUE)
  tibble::as_tibble(tb)
}

# Read just the header line, so the schema can be built before parsing.
.db_csv_header <- function(file, compression = "none") {
  if (!file.exists(file) || file.size(file) == 0) return(character())
  con <- if (identical(compression, "zstd")) {
    stream <- arrow::CompressedInputStream$create(file, arrow::Codec$create("zstd"))
    on.exit(stream$close(), add = TRUE)
    raw <- stream$Read(65536L)
    textConnection(rawToChar(as.raw(raw)))
  } else {
    file(file, open = "r")
  }
  on.exit(close(con), add = TRUE)
  line <- readLines(con, n = 1L, warn = FALSE)
  if (!length(line) || !nzchar(line)) return(character())
  strsplit(line, ",", fixed = TRUE)[[1L]]
}
