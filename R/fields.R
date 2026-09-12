# Column types for the CSV encoding of every DBN schema.
#
# Why this table exists at all: arrow's CSV type inference is actively unsafe
# on Databento records. A `trades` slice whose `action` column is all "T"
# infers as boolean, silently turning a trade action into TRUE; an all-empty
# price column infers as null. databentoR therefore reads every column as
# text and casts it here, so a pull's types never depend on which rows
# happened to come back.
#
# The field names are stable across schemas, so one table covers all of them.
# `db_list_fields()` is the authoritative source; the live test suite checks
# this table against it for every schema.

# Nanosecond timestamps. With pretty_ts they arrive as ISO-8601 with nine
# fractional digits and a Z suffix.
.db_ts_fields <- c("ts_recv", "ts_event", "ts_ref", "auction_time",
                   "expiration", "activation")

# Fixed-point fields scaled by 1e-9. With pretty_px they arrive as decimals.
# display_factor, unit_of_measure_qty and leg_delta are not prices but carry
# the same scaling.
.db_px_fields <- c(
  "price", "open", "high", "low", "close",
  "ref_price", "cont_book_clr_price", "auct_interest_clr_price",
  "ssr_filling_price", "ind_match_price", "upper_collar", "lower_collar",
  "min_price_increment", "display_factor", "high_limit_price",
  "low_limit_price", "max_price_variation", "unit_of_measure_qty",
  "min_price_increment_amount", "price_ratio", "strike_price",
  "leg_price", "leg_delta"
)

# Character fields. The Python client decodes these to strings and leaves a
# genuinely empty field as "", not as a missing value.
.db_chr_fields <- c(
  "action", "side", "symbol", "raw_symbol", "security_update_action",
  "instrument_class", "currency", "settl_currency", "secsubtype", "group",
  "exchange", "asset", "cfi", "security_type", "unit_of_measure",
  "underlying", "strike_price_currency", "match_algorithm",
  "user_defined_instrument", "leg_raw_symbol", "leg_instrument_class",
  "leg_side", "auction_type", "unpaired_side", "significant_imbalance",
  "is_trading", "is_quoting", "is_short_sell_restricted"
)

# Counts and identifiers that are unsigned 32- or 64-bit on the wire and so
# will not fit an R integer.
.db_i64_fields <- c(
  "instrument_id", "sequence", "order_id", "size", "volume", "quantity",
  "raw_instrument_id", "paired_qty", "total_imbalance_qty",
  "market_imbalance_qty", "unpaired_qty", "underlying_id",
  "leg_underlying_id", "leg_instrument_id", "max_trade_vol", "min_trade_vol",
  "decay_quantity", "original_contract_size", "market_segment_id",
  "min_lot_size", "min_lot_size_block", "min_lot_size_round_lot",
  "inst_attrib_value", "contract_multiplier",
  "leg_ratio_price_numerator", "leg_ratio_price_denominator",
  "leg_ratio_qty_numerator", "leg_ratio_qty_denominator"
)

# A field name implies one type everywhere but in a single case: `action` is
# a character code in the book and trade schemas and a numeric enum in
# `status`. Reading it as text there would silently disagree with the Python
# client, so the lookup takes the schema into account.
.db_schema_overrides <- list(
  status = c(action = "int32")
)

# Level-suffixed book fields: bid_px_00 .. ask_ct_09, and the publisher-id
# variants of the consolidated schemas.
.db_field_kind <- function(name, schema = NULL) {
  if (!is.null(schema)) {
    override <- .db_schema_overrides[[schema]]
    if (!is.null(override) && name %in% names(override)) {
      return(unname(override[[name]]))
    }
  }
  if (name %in% .db_ts_fields) return("timestamp")
  if (name %in% .db_px_fields) return("price")
  if (name %in% .db_chr_fields) return("character")
  if (name %in% .db_i64_fields) return("int64")
  if (grepl("^(bid|ask)_px_[0-9]+$", name)) return("price")
  if (grepl("^(bid|ask)_(sz|ct|pb)_[0-9]+$", name)) return("int64")
  "int32"
}

#' Column types databentoR gives a CSV download
#'
#' `db_get_range()` never lets arrow guess a column type. This function
#' reports the type it will assign to each field, which is useful when you
#' want to pass your own `col_types` or to check the package against
#' [db_list_fields()].
#'
#' @param fields Character vector of field names, for instance the `name`
#'   column of [db_list_fields()].
#' @param schema Optional schema name. One field is schema-dependent:
#'   `action` is a character code in the book and trade schemas and a numeric
#'   enum in `status`.
#' @return A tibble with `name` and `kind`, where `kind` is one of
#'   `"timestamp"`, `"price"`, `"character"`, `"int64"` or `"int32"`.
#' @examples
#' db_field_types(c("ts_event", "open", "action", "order_id", "flags"))
#' db_field_types("action", schema = "status")
#' @export
db_field_types <- function(fields, schema = NULL) {
  tibble::tibble(
    name = as.character(fields),
    kind = vapply(as.character(fields), .db_field_kind, character(1),
                  schema = schema, USE.NAMES = FALSE)
  )
}

# Build the arrow schema for a set of CSV column names.
.db_arrow_schema <- function(names, pretty_px = TRUE, pretty_ts = TRUE,
                            schema = NULL) {
  types <- lapply(names, function(nm) {
    switch(.db_field_kind(nm, schema),
      # Raw timestamps are unsigned 64-bit and the undefined sentinel is
      # 2^64-1, which no signed R type holds, so they stay text.
      timestamp = if (pretty_ts) arrow::timestamp("ns", "UTC") else arrow::utf8(),
      price     = if (pretty_px) arrow::float64() else arrow::int64(),
      character = arrow::utf8(),
      int64     = arrow::int64(),
      arrow::int32()
    )
  })
  names(types) <- names
  do.call(arrow::schema, types)
}
