# Plot a multi-year nighttime lights panel

Arranges one map per year into a patchwork grid with a shared title,
subtitle, and caption. A shared luminance scale is computed from the
99.5th percentile across all rasters so panels are directly comparable.

## Usage

``` r
plot_ntl_panel(
  rasters,
  polygons = NULL,
  title = "India at night",
  subtitle = NULL,
  caption = NULL,
  palette = c("glow", "bhuvan"),
  ncol = 3L,
  bg_colour = "#080c14",
  title_colour = "#CDD9E5",
  subtitle_colour = "#8B949E",
  year_colour = "#E8A87C"
)
```

## Arguments

- rasters:

  Named list of `SpatRaster` objects as returned by
  [`ntl_download()`](https://saketkc.github.io/lightson/reference/ntl_download.md)
  or
  [`bhuvan_raster()`](https://saketkc.github.io/lightson/reference/bhuvan_raster.md),
  keyed by year.

- polygons:

  Optional `sf` object for boundary overlay.

- title:

  Overall plot title. Default `"India at night"`.

- subtitle:

  Optional subtitle string.

- caption:

  Optional caption string.

- palette:

  One of `"glow"` (default) or `"bhuvan"`. Passed to
  [`plot_ntl_map()`](https://saketkc.github.io/lightson/reference/plot_ntl_map.md).

- ncol:

  Number of columns in the grid. Default `3`.

- bg_colour:

  Background colour of the assembled panel. Default `"#080c14"` (deep
  navy).

- title_colour:

  Title text colour. Default `"#CDD9E5"`.

- subtitle_colour:

  Subtitle and caption text colour. Default `"#8B949E"`.

- year_colour:

  Year label colour on each individual map. Default `"#E8A87C"` (warm
  amber).

## Value

A `patchwork` object.

## Details

Requires the patchwork package.

## Examples

``` r
if (FALSE) { # \dontrun{
rasters <- bhuvan_raster("IND", years = c(2012, 2015, 2018, 2021, 2024))
states  <- get_india_admin("state")
plot_ntl_panel(rasters, polygons = states, title = "India at night, 2012-2024",
               caption = "Source: ISRO Bhuvan NTL portal")
} # }
```
