# Build the pkgdown favicon set locally from man/figures/logo.png (offline;
# pkgdown::build_favicons() would post the logo to an external service).
stopifnot(file.exists("man/figures/logo.png"))
library(magick)
logo <- image_read("man/figures/logo.png")
out  <- "pkgdown/favicon"
dir.create(out, showWarnings = FALSE, recursive = TRUE)

sq <- function(px) {
  image_resize(logo, paste0(px, "x", px)) |>
    image_extent(paste0(px, "x", px), color = "none", gravity = "center")
}
image_write(sq(96),  file.path(out, "favicon-96x96.png"), format = "png")
image_write(sq(180), file.path(out, "apple-touch-icon.png"), format = "png")
image_write(sq(192), file.path(out, "web-app-manifest-192x192.png"), format = "png")
image_write(sq(512), file.path(out, "web-app-manifest-512x512.png"), format = "png")
image_write(image_join(sq(16), sq(32), sq(48)), file.path(out, "favicon.ico"),
            format = "ico")

writeLines(c(
  '{',
  '  "name": "databentoR",',
  '  "short_name": "databentoR",',
  '  "icons": [',
  '    { "src": "/web-app-manifest-192x192.png", "sizes": "192x192", "type": "image/png" },',
  '    { "src": "/web-app-manifest-512x512.png", "sizes": "512x512", "type": "image/png" }',
  '  ],',
  '  "theme_color": "#0d2136",',
  '  "background_color": "#0d2136",',
  '  "display": "standalone"',
  '}'
), file.path(out, "site.webmanifest"))

cat("favicons written to", out, "\n")
