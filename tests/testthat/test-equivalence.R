# Data equivalence with the official Python client.
#
# Layer two of the protocol. `dev/equivalence/make_reference.py` downloads a
# handful of tiny slices through the pinned Python client and freezes each as
# parquet; this test downloads the same slices through databentoR and compares
# the tables column by column.
#
# The fixtures are market data, so they are never committed. Without them the
# test skips. See dev/equivalence/README.md.

ref_dir <- function() {
  testthat::test_path("..", "..", "dev", "equivalence", "reference")
}

read_manifest <- function() {
  path <- file.path(ref_dir(), "manifest.json")
  if (!file.exists(path)) return(NULL)
  jsonlite::fromJSON(path, simplifyVector = FALSE)
}

# Prices agree to the last bit that both paths can represent. A relative
# tolerance of 1e-12 is many orders looser than the worst float divergence
# between "parse a nine-decimal string" and "divide an int64 by 1e9", and
# still far tighter than one unit of the 1e-9 fixed-point grid, so a genuine
# scaling or rounding bug cannot hide inside it.
px_tolerance <- 1e-12

# The server does not guarantee a stable order among records that share a
# timestamp: two downloads of the same slice, by either client, can return
# the same rows in a different sequence. Ordering both frames by every column
# makes the comparison independent of that without hiding a real difference,
# because two frames holding the same multiset of rows sort identically.
stable_order <- function(tb) {
  tb[do.call(order, unname(as.list(tb))), , drop = FALSE]
}

# Compare one column without ever routing a 64-bit integer through a double.
expect_column_equal <- function(a, b, kind, label) {
  if (identical(kind, "price")) {
    testthat::expect_equal(as.double(a), as.double(b),
                           tolerance = px_tolerance, label = label)
  } else if (identical(kind, "timestamp")) {
    testthat::expect_equal(as.double(as.POSIXct(a, tz = "UTC")),
                           as.double(as.POSIXct(b, tz = "UTC")),
                           tolerance = 1e-6, label = label)
  } else if (identical(kind, "character")) {
    # The Python client renders an empty text field as "", databentoR as NA.
    # That is the one cosmetic difference, so normalise both sides.
    norm <- function(x) {
      x <- as.character(x)
      x[is.na(x)] <- ""
      x
    }
    testthat::expect_equal(norm(a), norm(b), label = label)
  } else {
    # Integers, exactly. as.character() on integer64 keeps every digit,
    # including the int64 sentinel a double would round.
    exact <- function(x) {
      if (inherits(x, "integer64")) return(as.character(x))
      out <- format(as.numeric(x), scientific = FALSE, trim = TRUE)
      out[is.na(x)] <- NA_character_
      out
    }
    testthat::expect_equal(exact(a), exact(b), label = label)
  }
}

test_that("the reference manifest matches the pinned Python client", {
  manifest <- read_manifest()
  skip_if(is.null(manifest),
          "no reference fixtures (run dev/equivalence/make_reference.py)")
  wire <- jsonlite::fromJSON(testthat::test_path("fixtures", "python_wire.json"),
                             simplifyVector = FALSE)
  expect_equal(manifest$databento_python_version,
               wire$databento_python_version)
})

test_that("databentoR returns the same table as the Python client", {
  skip_unless_live()
  manifest <- read_manifest()
  skip_if(is.null(manifest),
          "no reference fixtures (run dev/equivalence/make_reference.py)")

  for (name in names(manifest$slices)) {
    spec <- manifest$slices[[name]]
    fixture <- file.path(ref_dir(), paste0(name, ".parquet"))
    if (!file.exists(fixture)) next

    ref <- tibble::as_tibble(arrow::read_parquet(fixture))
    got <- db_get_range(
      dataset = spec$dataset,
      start = spec$start,
      end = spec$end,
      symbols = unlist(spec$symbols),
      schema = spec$schema,
      stype_in = spec$stype_in
    )

    expect_equal(nrow(got), nrow(ref), label = paste(name, "row count"))
    expect_equal(names(got), names(ref), label = paste(name, "column names"))
    if (nrow(got) != nrow(ref) || !identical(names(got), names(ref))) next

    got <- stable_order(got)
    ref <- stable_order(ref)
    for (col in names(got)) {
      expect_column_equal(got[[col]], ref[[col]],
                          db_field_types(col, schema = spec$schema)$kind,
                          label = paste(name, col))
    }
  }
})

test_that("64-bit fields keep their range instead of rounding to a double", {
  skip_unless_live()
  manifest <- read_manifest()
  skip_if(is.null(manifest),
          "no reference fixtures (run dev/equivalence/make_reference.py)")
  fixture <- file.path(ref_dir(), "glbx_es_statistics.parquet")
  skip_if(!file.exists(fixture), "no statistics fixture")

  ref <- tibble::as_tibble(arrow::read_parquet(fixture))
  skip_if(!"quantity" %in% names(ref), "no quantity column")
  # An undefined statistics quantity is the int64 maximum. A double cannot
  # hold it, so this is the column that proves the downcast is off.
  expect_s3_class(ref$quantity, "integer64")
  spec <- manifest$slices[["glbx_es_statistics"]]
  got <- db_get_range(dataset = spec$dataset, start = spec$start,
                      end = spec$end, symbols = unlist(spec$symbols),
                      schema = spec$schema, stype_in = spec$stype_in)
  expect_s3_class(got$quantity, "integer64")
  expect_equal(sort(as.character(got$quantity)), sort(as.character(ref$quantity)))
})

test_that("exact nanosecond timestamps survive the integer64 path", {
  skip_unless_live()
  skip_if_not_installed("bit64")
  manifest <- read_manifest()
  skip_if(is.null(manifest),
          "no reference fixtures (run dev/equivalence/make_reference.py)")
  spec <- manifest$slices[["glbx_es_trades"]]
  skip_if(is.null(spec), "no trades fixture")

  args <- list(dataset = spec$dataset, start = spec$start, end = spec$end,
               symbols = unlist(spec$symbols), schema = spec$schema,
               stype_in = spec$stype_in)
  exact <- do.call(db_get_range, c(args, list(ts_type = "integer64")))
  expect_s3_class(exact$ts_recv, "integer64")

  # The count really is to the nanosecond: a POSIXct column could not carry
  # these digits, so at least one timestamp must be a non-round microsecond.
  ns <- as.character(exact$ts_recv)
  expect_true(any(substr(ns, nchar(ns) - 2L, nchar(ns)) != "000"))

  # And it agrees with the default representation to within its resolution.
  # Narrowing the nanosecond count to a double is exactly what this test is
  # measuring the cost of, so bit64's warning about it is expected here.
  friendly <- do.call(db_get_range, args)
  seconds <- suppressWarnings(as.numeric(exact$ts_recv) / 1e9)
  expect_equal(sort(seconds), sort(as.numeric(friendly$ts_recv)),
               tolerance = 1e-6)
})
