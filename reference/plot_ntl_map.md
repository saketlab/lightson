# Plot a nighttime lights raster map

Renders a single `SpatRaster` as a map. Two palettes are available:

## Usage

``` r
plot_ntl_map(
  raster,
  polygons = NULL,
  title = "Nighttime lights",
  caption = NULL,
  palette = c("glow", "bhuvan"),
  dark = TRUE,
  limits = NULL
)
```

## Arguments

- raster:

  A single-layer `SpatRaster`. Pass one element from the list returned
  by
  [`ntl_download()`](https://saketkc.github.io/lightson/reference/ntl_download.md)
  or
  [`bhuvan_raster()`](https://saketkc.github.io/lightson/reference/bhuvan_raster.md).

- polygons:

  Optional `sf` object for boundary overlay.

- title:

  Plot title. Default `"Nighttime lights"`.

- caption:

  Optional caption string.

- palette:

  One of `"glow"` (default) or `"bhuvan"`.

- dark:

  Logical. If `TRUE`, the plot background is `#080c14` (deep navy) and
  text is light. Ignored when `palette = "bhuvan"` (always dark bg).
  Default `TRUE`.

- limits:

  Numeric vector of length 2 for the continuous scale. Only used when
  `palette = "glow"`. `NULL` uses the raster min/max. Set explicitly
  when comparing multiple panels on the same scale.

## Value

A `ggplot2` object.

## Details

- `"glow"` (default): continuous dark-olive-to-cream-white ramp modelled
  on the NASA Black Marble composite. Suited to dark backgrounds and
  multi-panel year comparisons.

- `"bhuvan"`: 4-class categorical legend matching the Bhuvan portal:
  black (\< 5 nW/cm2/sr), dark blue-grey (5-25), cream (26-200), red (\>
  200).

## Examples

``` r
if (FALSE) { # \dontrun{
rasters <- bhuvan_raster("IND", years = 2022, bbox_pad = c(0, 0, 0, 3.5))
plot_ntl_map(rasters[["2022"]], dark = TRUE)
plot_ntl_map(rasters[["2022"]], palette = "bhuvan")
} # }
```
