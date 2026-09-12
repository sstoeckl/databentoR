# Hex logo for databentoR.
# Concept: the market-depth "butterfly" — cumulative bid depth stepping up to
# the left of the mid, cumulative ask depth stepping up to the right — with a
# trade tape (white step line) walking across the book. That is exactly what
# the package delivers: raw Databento market data, tidied into tibbles.
stopifnot(file.exists("DESCRIPTION"))
library(ggplot2)

font_ok <- tryCatch({
  sysfonts::font_add_google("Roboto Condensed", "roboto")
  showtext::showtext_auto()
  TRUE
}, error = function(e) FALSE)
logo_font <- if (font_ok) "roboto" else "sans"

col_bg    <- "#0d2136"  # deep navy hex fill
col_hex   <- "#35c2c7"  # cyan border
col_bid   <- "#3ecf8e"  # bid side
col_ask   <- "#f0685b"  # ask side
col_tape  <- "#ffffff"  # trade tape
col_mid   <- "#7f97ad"  # mid-price guide

set.seed(20260912)

# --- the book: 16 levels each side, decaying size, cumulative depth ---------
n   <- 16L
tick <- 1 / n
lvl <- seq_len(n)

size_bid <- 0.30 + 0.70 * (lvl / n)^1.4 + runif(n, 0, 0.12)
size_ask <- 0.30 + 0.70 * (lvl / n)^1.3 + runif(n, 0, 0.12)

bid <- data.frame(x = -0.88 * lvl * tick, y = cumsum(size_bid))
ask <- data.frame(x =  0.88 * lvl * tick, y = cumsum(size_ask))
sc  <- function(v) 0.80 * v / max(bid$y, ask$y)      # scale depth into the hex
bid$y <- sc(bid$y); ask$y <- sc(ask$y)

# close the areas down to the mid line
bid_area <- rbind(data.frame(x = 0, y = 0), bid, data.frame(x = min(bid$x), y = 0))
ask_area <- rbind(data.frame(x = 0, y = 0), ask, data.frame(x = max(ask$x), y = 0))

# --- the tape: a random-walk trade price crossing the book -----------------
m  <- 60L
tp <- cumsum(c(0, rnorm(m - 1L, 0, 0.055)))
tp <- tp - mean(tp)
tape <- data.frame(x = seq(-0.86, 0.86, length.out = m),
                   y = 0.40 + 0.22 * tp / max(abs(tp)))

sub <- ggplot() +
  geom_polygon(data = bid_area, aes(x, y), fill = col_bid, alpha = 0.85) +
  geom_polygon(data = ask_area, aes(x, y), fill = col_ask, alpha = 0.85) +
  geom_step(data = bid, aes(x, y), color = "#eafff5", linewidth = 0.35) +
  geom_step(data = ask, aes(x, y), color = "#fff0ee", linewidth = 0.35) +
  geom_segment(aes(x = 0, xend = 0, y = 0, yend = 0.92),
               color = col_mid, linewidth = 0.4, linetype = "22") +
  geom_step(data = tape, aes(x, y), color = col_tape, linewidth = 0.8) +
  coord_cartesian(xlim = c(-1.0, 1.0), ylim = c(-0.03, 0.95), expand = FALSE) +
  theme_void() +
  theme(plot.background = element_blank(), panel.background = element_blank())

hexSticker::sticker(
  sub,
  package = "databentoR",
  p_family = logo_font, p_size = 19, p_color = "#ffffff", p_y = 1.47,
  s_x = 1, s_y = 1.00, s_width = 1.28, s_height = 0.82,
  h_fill = col_bg, h_color = col_hex, h_size = 1.4,
  url = "sebastianstoeckl.com/databentoR", u_color = "#8fa6bb", u_size = 3.4, u_y = 0.07,
  filename = "man/figures/logo.png", dpi = 320
)
cat("written: man/figures/logo.png\n")
