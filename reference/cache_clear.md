# Clear the local lightson cache

Removes cached raster files downloaded by
[`ntl_download()`](https://saketkc.github.io/lightson/reference/ntl_download.md)
or
[`bhuvan_raster()`](https://saketkc.github.io/lightson/reference/bhuvan_raster.md).

## Usage

``` r
cache_clear(source = NULL)
```

## Arguments

- source:

  One of `"viirs"`, `"bhuvan"`, or `NULL` (clears everything).

## Value

Invisibly returns the number of files removed.
