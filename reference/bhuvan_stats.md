# Get pre-aggregated Bhuvan NTL state statistics

Wraps the ISRO Bhuvan NTL REST API to return mean radiance per Indian
state across years.

## Usage

``` r
bhuvan_stats(years = NULL, state = NULL)
```

## Arguments

- years:

  Integer vector of years to return. `NULL` (default) returns all
  available years (currently 2012-2024).

- state:

  Character. State name as returned by the API (e.g., `"BIHAR"`). `NULL`
  (default) returns all states.

## Value

A tidy data frame with columns `state` (character), `year` (integer),
and `mean_radiance` (numeric). State names are normalised to title case
(e.g., `"Tamil Nadu"` not `"TAMILNADU"`).

## Details

For district-level or custom-geometry statistics, use
[`bhuvan_raster()`](https://saketkc.github.io/lightson/reference/bhuvan_raster.md)
together with
[`extract_panel()`](https://saketkc.github.io/lightson/reference/extract_panel.md).

## Collection break

Bhuvan NTL data from 2024 onwards is derived from VNP46A4 **Collection
2.0**, while 2012-2023 uses the legacy **Collection 1.0**. The two
collections use different calibration and atmospheric correction
algorithms, so radiance estimates are not directly comparable across
this boundary. Requests spanning both collections trigger a warning.

## Examples

``` r
if (FALSE) { # \dontrun{
# All states, all years
df <- bhuvan_stats()

# Bihar only
df <- bhuvan_stats(state = "BIHAR")

# Multiple years
df <- bhuvan_stats(years = 2015:2023)
} # }
```
