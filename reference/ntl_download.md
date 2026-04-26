# Download VIIRS Black Marble annual nighttime lights

Downloads NASA VIIRS/Black Marble VNP46A4 annual composite rasters from
NASA LAADS DAAC for a given region and year range.

## Usage

``` r
ntl_download(source = "viirs", region, years, token, force = FALSE)
```

## Arguments

- source:

  Character. Currently only `"viirs"` is supported.

- region:

  An `sf` object, `SpatVector`, or ISO 3166-1 alpha-3 country code
  (e.g., `"IND"`).

- years:

  Integer vector of years to download.

- token:

  A bearer token string from
  [`earthdata_token()`](https://saketkc.github.io/lightson/reference/earthdata_token.md).

- force:

  Logical. Re-download even if cached. Default `FALSE`.

## Value

A named list of `SpatRaster` objects, keyed by year.

## Details

Requires a NASA Earthdata bearer token, see
[`earthdata_token()`](https://saketkc.github.io/lightson/reference/earthdata_token.md).

## Examples

``` r
if (FALSE) { # \dontrun{
token <- earthdata_token()
rasters <- ntl_download("viirs", region = "IND", years = 2020:2023, token = token)
panel <- extract_panel(rasters, get_india_admin("district"))
} # }
```
