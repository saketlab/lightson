# Plot nighttime lights radiance trends

Line chart of mean radiance over time for one or more regions. Accepts
output from
[`extract_panel()`](https://saketkc.github.io/lightson/reference/extract_panel.md)
or
[`bhuvan_stats()`](https://saketkc.github.io/lightson/reference/bhuvan_stats.md).

## Usage

``` r
plot_ntl_trend(
  panel,
  region = NULL,
  title = "Nighttime lights radiance",
  subtitle = NULL,
  caption = NULL
)
```

## Arguments

- panel:

  A data frame as returned by
  [`extract_panel()`](https://saketkc.github.io/lightson/reference/extract_panel.md)
  (with `region_id` column) or
  [`bhuvan_stats()`](https://saketkc.github.io/lightson/reference/bhuvan_stats.md)
  (with `state` column), plus `year` and `mean_radiance`.

- region:

  Character vector of region identifiers to plot. `NULL` (default) plots
  all regions.

- title:

  Plot title. Default `"Nighttime lights radiance"`.

- subtitle:

  Optional subtitle string.

- caption:

  Optional caption string.

## Value

A `ggplot2` object.

## Examples

``` r
if (FALSE) { # \dontrun{
panel <- extract_panel(rasters, districts)
plot_ntl_trend(panel, region = "Lucknow")
plot_ntl_trend(panel, region = c("Mumbai", "Delhi", "Chennai"))
} # }
```
