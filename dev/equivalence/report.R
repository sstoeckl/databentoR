# Generate the published equivalence attestation.
#
# The report states verdicts and shapes and nothing else. No field value ever
# reaches it: no sample rows, no head(), and no summary statistics either,
# because a minimum or mean price is derived market data rather than a fact
# about the software. What it does carry is how many rows and columns were
# compared, how many columns matched, and the largest relative deviation
# found, which is the difference between two numbers that agree and therefore
# says nothing about either.
#
# Column names and types are Databento's published schema documentation, so
# they are safe; the values under them are not, and are never emitted.
#
#   Rscript dev/equivalence/report.R                    # writes LAST-RUN.md
#   Rscript dev/equivalence/report.R --out somewhere.md

# The columns the report is permitted to contain. Anything else is a leak.
REPORT_COLUMNS <- c("dataset", "schema", "rows", "columns",
                    "columns_compared", "columns_identical",
                    "max_rel_deviation", "verdict")

PX_TOLERANCE <- 1e-12

stable_order <- function(tb) tb[do.call(order, unname(as.list(tb))), , drop = FALSE]

# Compare one pair of tables and return shapes and verdicts only.
compare_tables <- function(got, ref, schema) {
  if (nrow(got) != nrow(ref) || !identical(names(got), names(ref))) {
    return(list(columns_compared = 0L, columns_identical = 0L,
                max_rel_deviation = NA_real_, verdict = "SHAPE MISMATCH"))
  }
  got <- stable_order(got)
  ref <- stable_order(ref)

  identical_cols <- 0L
  worst <- 0
  for (col in names(got)) {
    kind <- databentoR::db_field_types(col, schema = schema)$kind
    a <- got[[col]]
    b <- ref[[col]]
    ok <- if (identical(kind, "price")) {
      dev <- abs(as.double(a) - as.double(b)) /
        pmax(abs(as.double(b)), .Machine$double.eps)
      dev <- dev[is.finite(dev)]
      if (length(dev)) worst <- max(worst, max(dev))
      isTRUE(all(dev <= PX_TOLERANCE))
    } else if (identical(kind, "timestamp")) {
      isTRUE(all(abs(as.double(as.POSIXct(a, tz = "UTC")) -
                     as.double(as.POSIXct(b, tz = "UTC"))) < 1e-6, na.rm = TRUE))
    } else if (identical(kind, "character")) {
      norm <- function(x) { x <- as.character(x); x[is.na(x)] <- ""; x }
      identical(norm(a), norm(b))
    } else {
      exact <- function(x) {
        if (inherits(x, "integer64")) return(as.character(x))
        out <- format(as.numeric(x), scientific = FALSE, trim = TRUE)
        out[is.na(x)] <- NA_character_
        out
      }
      identical(exact(a), exact(b))
    }
    if (isTRUE(ok)) identical_cols <- identical_cols + 1L
  }

  list(columns_compared = ncol(got), columns_identical = identical_cols,
       max_rel_deviation = worst,
       verdict = if (identical_cols == ncol(got)) "PASS" else "FAIL")
}

# Render the report. Pure: takes results, returns markdown, touches nothing.
equivalence_report <- function(results, meta) {
  extra <- setdiff(names(results), REPORT_COLUMNS)
  if (length(extra)) {
    stop("Report would leak columns that are not on the whitelist: ",
         paste(extra, collapse = ", "), call. = FALSE)
  }
  results <- results[, intersect(REPORT_COLUMNS, names(results)), drop = FALSE]

  header <- c(
    "# Equivalence attestation",
    "",
    sprintf("Generated %s by `dev/equivalence/report.R`.", meta$date),
    "",
    sprintf("* databentoR %s", meta$r_version),
    sprintf("* databento-python %s (pinned submodule)", meta$py_version),
    sprintf("* wire layer: %d endpoints compared request by request",
            meta$endpoints),
    "",
    "## Data layer",
    "",
    paste("For each slice, databentoR downloads the CSV encoding and the",
          "official Python client downloads DBN. Both tables are ordered by",
          "every column, because the server does not promise a stable order",
          "among records sharing a timestamp, then compared column by",
          "column."),
    ""
  )

  widths <- c(dataset = 11, schema = 10, rows = 7, columns = 7,
              columns_compared = 16, columns_identical = 17,
              max_rel_deviation = 17, verdict = 7)
  cols <- names(results)
  line <- function(cells) paste0("| ", paste(cells, collapse = " | "), " |")
  body <- c(
    line(cols),
    line(rep("---", length(cols))),
    vapply(seq_len(nrow(results)), function(i) {
      line(vapply(cols, function(k) {
        v <- results[[k]][i]
        if (is.numeric(v) && !is.na(v) && k == "max_rel_deviation") {
          format(v, digits = 3, scientific = TRUE)
        } else {
          as.character(v)
        }
      }, character(1)))
    }, character(1))
  )

  footer <- c(
    "",
    sprintf("%d of %d slices identical.",
            sum(results$verdict == "PASS"), nrow(results)),
    "",
    "## What this report deliberately omits",
    "",
    paste("No field values. Databento's licence does not permit",
          "redistributing market data, so no sample rows, no extracts and no",
          "summary statistics of the data appear here. Row and column counts",
          "describe the request rather than its content; the largest relative",
          "deviation is the gap between two numbers that agree, so it",
          "discloses nothing about either.")
  )

  c(header, body, footer)
}

# ---------------------------------------------------------------------------

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  out <- if ("--out" %in% args) args[match("--out", args) + 1L] else
    file.path("dev", "equivalence", "LAST-RUN.md")

  suppressMessages(pkgload::load_all(".", quiet = TRUE))
  ref_dir <- file.path("dev", "equivalence", "reference")
  manifest <- jsonlite::fromJSON(file.path(ref_dir, "manifest.json"),
                                 simplifyVector = FALSE)
  wire <- jsonlite::fromJSON(file.path("tests", "testthat", "fixtures",
                                       "python_wire.json"),
                             simplifyVector = FALSE)

  rows <- list()
  for (name in names(manifest$slices)) {
    spec <- manifest$slices[[name]]
    fixture <- file.path(ref_dir, paste0(name, ".parquet"))
    if (!file.exists(fixture)) next
    ref <- tibble::as_tibble(arrow::read_parquet(fixture))
    got <- databentoR::db_get_range(
      dataset = spec$dataset, start = spec$start, end = spec$end,
      symbols = unlist(spec$symbols), schema = spec$schema,
      stype_in = spec$stype_in)
    cmp <- compare_tables(got, ref, spec$schema)
    rows[[length(rows) + 1L]] <- data.frame(
      dataset = spec$dataset, schema = spec$schema,
      rows = nrow(got), columns = ncol(got),
      columns_compared = cmp$columns_compared,
      columns_identical = cmp$columns_identical,
      max_rel_deviation = cmp$max_rel_deviation,
      verdict = cmp$verdict, stringsAsFactors = FALSE)
  }
  results <- do.call(rbind, rows)

  meta <- list(
    date = format(Sys.time(), "%Y-%m-%d %H:%M UTC", tz = "UTC"),
    r_version = as.character(utils::packageVersion("databentoR")),
    py_version = wire$databento_python_version,
    endpoints = length(wire$calls)
  )

  dir.create(dirname(out), showWarnings = FALSE, recursive = TRUE)
  writeLines(equivalence_report(results, meta), out)
  cat("wrote", out, "\n")
  if (any(results$verdict != "PASS")) quit(status = 1L)
}
