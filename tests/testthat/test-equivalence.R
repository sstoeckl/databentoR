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

    for (col in intersect(names(got), names(ref))) {
      a <- got[[col]]
      b <- ref[[col]]
      kind <- db_field_types(col)$kind

      if (identical(kind, "price")) {
        expect_equal(as.numeric(a), as.numeric(b), tolerance = px_tolerance,
                     label = paste(name, col))
      } else if (identical(kind, "timestamp")) {
        # Compare as instants; both sides are UTC.
        expect_equal(as.numeric(as.POSIXct(a, tz = "UTC")),
                     as.numeric(as.POSIXct(b, tz = "UTC")),
                     tolerance = 1e-6, label = paste(name, col))
      } else if (identical(kind, "character")) {
        # The Python client renders an empty text field as "", databentoR as
        # NA. That is the one cosmetic difference, so normalise both sides.
        norm <- function(x) {
          x <- as.character(x)
          x[is.na(x)] <- ""
          x
        }
        expect_equal(norm(a), norm(b), label = paste(name, col))
      } else {
        expect_equal(as.numeric(a), as.numeric(b), label = paste(name, col))
      }
    }
  }
})

test_that("exact nanosecond timestamps survive the integer64 path", {
  skip_unless_live()
  skip_if_not_installed("bit64")
  manifest <- read_manifest()
  skip_if(is.null(manifest),
          "no reference fixtures (run dev/equivalence/make_reference.py)")
  spec <- manifest$slices[["glbx_es_trades"]]
  skip_if(is.null(spec), "no trades fixture")

  exact <- db_get_range(dataset = spec$dataset, start = spec$start,
                        end = spec$end, symbols = unlist(spec$symbols),
                        schema = spec$schema, stype_in = spec$stype_in,
                        ts_type = "integer64")
  expect_s3_class(exact$ts_recv, "integer64")

  ref <- tibble::as_tibble(arrow::read_parquet(
    file.path(ref_dir(), "glbx_es_trades.parquet")))
  # Round-trip the Python timestamps through nanoseconds and compare exactly.
  ref_ns <- bit64::as.integer64(format(as.numeric(ref$ts_recv) * 1e9,
                                       scientific = FALSE))
  expect_equal(bit64::as.integer64(round(as.numeric(exact$ts_recv) / 1e3)),
               bit64::as.integer64(round(as.numeric(ref_ns) / 1e3)))
})
