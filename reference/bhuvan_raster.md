# Download Bhuvan NTL raster tiles for a region

Fetches annual nighttime lights GeoTIFF tiles from the Bhuvan WMS
service for a given spatial extent and converts the RGB visualization
output to a single-band luminance raster.

## Usage

``` r
bhuvan_raster(
  region,
  years,
  force = FALSE,
  width = 1024,
  height = 1024,
  bbox_pad = c(0, 0, 0, 0)
)
```

## Arguments

- region:

  An `sf` object, `SpatVector`, or ISO 3166-1 alpha-3 country code
  (e.g., `"IND"`). Used to derive the WMS bounding box.

- years:

  Integer vector of years to download (2012-2024).

- force:

  Logical. If `TRUE`, re-download even if cached. Default `FALSE`.

- width, height:

  Pixel dimensions of the WMS request. Default 1024x1024.

- bbox_pad:

  Numeric vector of length 1 or 4 (xmin, ymin, xmax, ymax sides) in
  degrees, added to the region bounding box before the WMS request.
  Useful when GADM boundaries clip disputed territories (e.g.
  `bbox_pad = c(0, 0, 0, 3.5)` extends the north edge by 3.5 degrees to
  include all of Jammu and Kashmir).

## Value

A named list of single-band `SpatRaster` objects, keyed by year

## Details

The Bhuvan WMS returns RGB visualization rasters, not physical radiance.
Luminance is computed as `lum = 0.2126*R + 0.7152*G + 0.0722*B` (ITU-R
BT.709). Values are comparable across years for trend analysis but
differ in units from VIIRS nW/cm²/sr. Do not mix Bhuvan luminance and
VIIRS radiance in the same regression without normalising first.

## Collection break

Bhuvan NTL data from 2024 onwards is derived from VNP46A4 **Collection
2.0**, while 2012-2023 uses the legacy **Collection 1.0**. The two
collections use different calibration and atmospheric correction
algorithms, so luminance values are not directly comparable across this
boundary. (e.g., `list("2020" = rast(...), "2021" = rast(...))`).

## Examples

``` r
if (FALSE) { # \dontrun{
districts <- sf::read_sf("https://bharatviz.org/India-bhuvan-districts.geojson")
rasters <- bhuvan_raster(districts, years = 2018:2023)
panel <- extract_panel(rasters, districts)
} # }
```
