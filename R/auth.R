#' Get NASA Earthdata bearer token
#'
#' Returns the bearer token used for VIIRS/Black Marble downloads from NASA
#' LAADS DAAC.
#'
#' **Getting a token (web):**
#' 1. Create an account at <https://urs.earthdata.nasa.gov>
#' 2. Accept the MERIS and Sentinel EULAs under Profile > EULAs
#' 3. Go to Profile > **Generate Token**, click "Generate Token", then "Show Token"
#' 4. Copy the token (starts with `EDL-`) and store it
#'
#' **Supplying the token:**
#' - Set `EARTHDATA_TOKEN` environment variable (recommended: add to `~/.Renviron`)
#' - Or pass it directly as the `token` argument
#' - Or set `EARTHDATA_USERNAME` + `EARTHDATA_PASSWORD` to fetch it automatically
#'
#' Bhuvan NTL functions ([bhuvan_stats()], [bhuvan_raster()]) do not require
#' any authentication.
#'
#' @param token Character string. If `NULL`, checks `EARTHDATA_TOKEN` env var,
#'   then tries `EARTHDATA_USERNAME` + `EARTHDATA_PASSWORD`.
#' @return The access token string, invisibly.
#' @export
#' @examples
#' \dontrun{
#' # Option 1: token from Profile > Generate Token on urs.earthdata.nasa.gov
#' Sys.setenv(EARTHDATA_TOKEN = "EDL-xxxxxxxxxxxxxxxxxxxx")
#' token <- earthdata_token()
#'
#' # Option 2: username + password (fetches token automatically)
#' Sys.setenv(EARTHDATA_USERNAME = "myuser", EARTHDATA_PASSWORD = "mypass")
#' token <- earthdata_token()
#'
#' # Option 3: pass directly
#' token <- earthdata_token("EDL-xxxxxxxxxxxxxxxxxxxx")
#' }
earthdata_token <- function(token = NULL) {
  if (!is.null(token)) {
    return(invisible(token))
  }

  env <- Sys.getenv("EARTHDATA_TOKEN", unset = NA)
  if (.has_value(env)) {
    return(invisible(env))
  }

  user <- Sys.getenv("EARTHDATA_USERNAME", unset = NA)
  pass <- Sys.getenv("EARTHDATA_PASSWORD", unset = NA)
  if (.has_value(user) && .has_value(pass)) {
    return(invisible(.fetch_earthdata_token(user, pass)))
  }

  stop(
    "No Earthdata credentials found.\n",
    "  Option 1: get a token from https://urs.earthdata.nasa.gov/profile/tokens\n",
    "            then: Sys.setenv(EARTHDATA_TOKEN = 'EDL-xxx')\n",
    "  Option 2: Sys.setenv(EARTHDATA_USERNAME = 'u', EARTHDATA_PASSWORD = 'p')\n",
    "  Add to ~/.Renviron so it persists across sessions.",
    call. = FALSE
  )
}

.fetch_earthdata_token <- function(username, password) {
  req <- httr2::request("https://urs.earthdata.nasa.gov/api/users/find_or_create_token") |>
    httr2::req_auth_basic(username, password) |>
    httr2::req_method("POST") |>
    httr2::req_error(is_error = \(r) FALSE)

  resp <- tryCatch(
    httr2::req_perform(req),
    error = function(e) stop("Earthdata token fetch failed: ", conditionMessage(e), call. = FALSE)
  )

  if (httr2::resp_status(resp) == 401) {
    stop("Earthdata authentication failed: check EARTHDATA_USERNAME and EARTHDATA_PASSWORD.", call. = FALSE)
  }
  if (httr2::resp_status(resp) != 200) {
    stop("Earthdata token fetch failed: HTTP ", httr2::resp_status(resp), call. = FALSE)
  }

  httr2::resp_body_json(resp)$access_token
}
