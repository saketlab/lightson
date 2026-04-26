# Get Indian administrative boundaries

Returns Indian administrative boundaries as an `sf` object. Useful as
the `polygons` argument to
[`extract_panel()`](https://saketkc.github.io/lightson/reference/extract_panel.md).

## Usage

``` r
get_india_admin(
  level = c("country", "state", "district"),
  source = c("gadm", "bhuvan")
)
```

## Arguments

- level:

  One of `"country"`, `"state"`, or `"district"`.

- source:

  One of `"gadm"` (default) or `"bhuvan"`. For `level = "state"`, the
  default uses a bundled LGD dataset with SoI-compliant boundaries
  regardless of `source`. `"bhuvan"` fetches geometries from the Bhuvan
  API so that names match
  [`bhuvan_stats()`](https://saketkc.github.io/lightson/reference/bhuvan_stats.md)
  output exactly.

## Value

An `sf` object.

## Details

State boundaries use a bundled LGD (Local Government Directory) dataset
derived from the Survey of India.

For custom boundaries, load your own file with
[`sf::read_sf()`](https://r-spatial.github.io/sf/reference/st_read.html)
and pass it directly to
[`extract_panel()`](https://saketkc.github.io/lightson/reference/extract_panel.md)
– no wrapper needed.

## Examples

``` r
if (FALSE) { # \dontrun{
states <- get_india_admin("state")
districts <- get_india_admin("district")

# custom boundary:
districts <- sf::read_sf("https://bharatviz.org/India-bhuvan-districts.geojson")
} # }
```
