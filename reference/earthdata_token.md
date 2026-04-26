# Get NASA Earthdata bearer token

Returns the bearer token used for VIIRS/Black Marble downloads from NASA
LAADS DAAC.

## Usage

``` r
earthdata_token(token = NULL)
```

## Arguments

- token:

  Character string. If `NULL`, checks `EARTHDATA_TOKEN` env var, then
  tries `EARTHDATA_USERNAME` + `EARTHDATA_PASSWORD`.

## Value

The access token string, invisibly.

## Details

**Getting a token (web):**

1.  Create an account at <https://urs.earthdata.nasa.gov>

2.  Accept the MERIS and Sentinel EULAs under Profile \> EULAs

3.  Go to Profile \> **Generate Token**, click "Generate Token", then
    "Show Token"

4.  Copy the token (starts with `EDL-`) and store it

**Supplying the token:**

- Set `EARTHDATA_TOKEN` environment variable (recommended: add to
  `~/.Renviron`)

- Or pass it directly as the `token` argument

- Or set `EARTHDATA_USERNAME` + `EARTHDATA_PASSWORD` to fetch it
  automatically

Bhuvan NTL functions
([`bhuvan_stats()`](https://saketkc.github.io/lightson/reference/bhuvan_stats.md),
[`bhuvan_raster()`](https://saketkc.github.io/lightson/reference/bhuvan_raster.md))
do not require any authentication.

## Examples

``` r
if (FALSE) { # \dontrun{
# Option 1: token from Profile > Generate Token on urs.earthdata.nasa.gov
Sys.setenv(EARTHDATA_TOKEN = "EDL-xxxxxxxxxxxxxxxxxxxx")
token <- earthdata_token()

# Option 2: username + password (fetches token automatically)
Sys.setenv(EARTHDATA_USERNAME = "myuser", EARTHDATA_PASSWORD = "mypass")
token <- earthdata_token()

# Option 3: pass directly
token <- earthdata_token("EDL-xxxxxxxxxxxxxxxxxxxx")
} # }
```
