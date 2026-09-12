# What does one scheduled equivalence run cost?
#
# Prices every slice the weekly `equivalence` workflow downloads, using only
# metadata.get_cost, which is free. Nothing is downloaded and nothing is
# billed by running this.
#
# Databento bills intraday requests in 15-minute chunks, so shrinking a window
# below a quarter of an hour does not reduce the quote. Beyond that the cost
# scales with the window.
#
#   Rscript dev/equivalence/quote.R
#
# Needs DATABENTO_API_KEY in the environment. The portable way to set it is
# usethis::edit_r_environ(), adding the line
#
#   DATABENTO_API_KEY=db-XXXX...
#
# and restarting R. Never put the key in a script.

if (requireNamespace("pkgload", quietly = TRUE) && file.exists("DESCRIPTION")) {
  suppressMessages(pkgload::load_all(".", quiet = TRUE))
} else {
  library(databentoR)
}

if (!db_has_key()) {
  stop("DATABENTO_API_KEY is not set in this session.\n",
       "  Set it with usethis::edit_r_environ() and restart R, or for one\n",
       "  shell only:  export DATABENTO_API_KEY=\"db-...\"", call. = FALSE)
}

# The six reference slices, and how many times each is fetched in one run:
# once by the Python fixture builder, once by test-equivalence.R, plus the
# repeats the R tests make (the daily-bar slice is also the one test-live.R
# uses, and it pulls it four times).
slices <- list(
  list(name = "ohlcv-1d",   times = 6L, schema = "ohlcv-1d",   symbols = "ES.FUT",
       stype_in = "parent",     start = "2024-01-02",       end = "2024-01-09"),
  list(name = "trades",     times = 3L, schema = "trades",     symbols = "ES.c.0",
       stype_in = "continuous", start = "2024-01-02T14:30",  end = "2024-01-02T14:31"),
  list(name = "tbbo",       times = 2L, schema = "tbbo",       symbols = "ES.c.0",
       stype_in = "continuous", start = "2024-01-02T14:30",  end = "2024-01-02T14:31"),
  list(name = "mbp-1",      times = 2L, schema = "mbp-1",      symbols = "ES.c.0",
       stype_in = "continuous", start = "2024-01-02T14:30",  end = "2024-01-02T14:30:30"),
  list(name = "statistics", times = 2L, schema = "statistics", symbols = "ES.FUT",
       stype_in = "parent",     start = "2024-01-02",       end = "2024-01-03"),
  list(name = "definition", times = 2L, schema = "definition", symbols = "ES.FUT",
       stype_in = "parent",     start = "2024-01-02",       end = "2024-01-03")
)

rows <- lapply(slices, function(s) {
  args <- list(dataset = "GLBX.MDP3", start = s$start, end = s$end,
               symbols = s$symbols, schema = s$schema, stype_in = s$stype_in)
  cost <- do.call(db_get_cost, args)
  size <- do.call(db_get_billable_size, args)
  rows <- do.call(db_get_record_count, args)
  data.frame(slice = s$name, records = rows, bytes = size,
             usd_each = cost, fetches = s$times, usd_per_run = cost * s$times)
})

out <- do.call(rbind, rows)
total <- sum(out$usd_per_run)

cat("\nCost of one scheduled equivalence run (GLBX.MDP3)\n\n")
print(format(out, digits = 6), row.names = FALSE)
cat(sprintf("\n  downloads per run : %d\n", sum(out$fetches)))
cat(sprintf("  cost per run      : %.6f USD\n", total))
cat(sprintf("  cost per year     : %.4f USD  (weekly schedule)\n", total * 52))
cat("\n  Metadata calls - listings, previews, symbology - are free and are\n")
cat("  not counted here. Pricing this script itself cost nothing.\n\n")
