# Compute zonal statistics for a panel of rasters

Takes a named list of `SpatRaster` objects (one per year, as returned by
[`ntl_download()`](https://saketkc.github.io/lightson/reference/ntl_download.md)
or
[`bhuvan_raster()`](https://saketkc.github.io/lightson/reference/bhuvan_raster.md))
and an `sf` or `SpatVector` polygon layer, and returns a tidy
long-format data frame with one row per region per year.

## Usage

``` r
extract_panel(rasters, polygons, fun = "mean", id_col = NULL)
```

## Arguments

- rasters:

  A named list of `SpatRaster` objects. Names should be years (e.g.,
  `"2020"`, `"2021"`). Returned by
  [`ntl_download()`](https://saketkc.github.io/lightson/reference/ntl_download.md)
  or
  [`bhuvan_raster()`](https://saketkc.github.io/lightson/reference/bhuvan_raster.md).

- polygons:

  An `sf` object or `SpatVector` containing the regions to summarise
  over.

- fun:

  Aggregation function name passed to
  [`terra::zonal()`](https://rspatial.github.io/terra/reference/zonal.html).
  Default `"mean"`. Also accepts `"sum"`, `"median"`, etc.

- id_col:

  Name of the column in `polygons` to use as `region_id`. If `NULL`
  (default), the first character column is used.

## Value

A data frame with columns:

- region_id:

  Character. Region identifier from `polygons`.

- year:

  Integer. Year, taken from the name of each raster.

- mean_radiance:

  Numeric. Aggregated radiance value.

- n_pixels:

  Integer. Number of non-NA cells contributing to the stat.

## Details

The `polygons` argument accepts any `sf` object – GADM, bharatviz
GeoJSONs, LGD districts, or any shapefile loaded with
[`sf::read_sf()`](https://r-spatial.github.io/sf/reference/st_read.html).

## Examples

``` r
if (FALSE) { # \dontrun{
districts <- sf::read_sf("https://bharatviz.org/India-bhuvan-districts.geojson")
rasters <- bhuvan_raster(districts, years = 2018:2023)
panel <- extract_panel(rasters, districts)
head(panel)
} # }
```
