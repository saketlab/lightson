#' Get Indian administrative boundaries
#'
#' Returns Indian administrative boundaries as an `sf` object. Useful as the
#' `polygons` argument to [extract_panel()].
#'
#' State boundaries use a bundled LGD (Local Government Directory) dataset
#' derived from the Survey of India.
#'
#' For custom boundaries, load your own file with `sf::read_sf()` and pass it
#' directly to [extract_panel()] -- no wrapper needed.
#'
#' @param level One of `"country"`, `"state"`, or `"district"`.
#' @param source One of `"gadm"` (default) or `"bhuvan"`. For `level = "state"`,
#'   the default uses a bundled LGD dataset with SoI-compliant boundaries
#'   regardless of `source`. `"bhuvan"` fetches geometries from the Bhuvan API
#'   so that names match [bhuvan_stats()] output exactly.
#' @return An `sf` object.
#' @export
#' @examples
#' \dontrun{
#' states <- get_india_admin("state")
#' districts <- get_india_admin("district")
#'
#' # custom boundary:
#' districts <- sf::read_sf("https://bharatviz.org/India-bhuvan-districts.geojson")
#' }
get_india_admin <- function(level = c("country", "state", "district"),
                            source = c("gadm", "bhuvan")) {
  level <- match.arg(level)
  source <- match.arg(source)

  if (level == "state" && source == "gadm") {
    path <- system.file("extdata", "india_states.geojson", package = "lightson")
    if (!.has_value(path)) {
      stop("Bundled state boundaries not found. Re-install the lightson package.", call. = FALSE)
    }
    return(sf::read_sf(path))
  }

  gadm_level <- switch(level,
    country = 0,
    state = 1,
    district = 2
  )

  if (source == "gadm") {
    if (!requireNamespace("geodata", quietly = TRUE)) {
      stop("Install the 'geodata' package to use source='gadm'.", call. = FALSE)
    }
    cache_d <- .cache_dir()
    path <- file.path(cache_d, paste0("gadm_IND_", gadm_level, ".rds"))
    if (file.exists(path)) {
      return(readRDS(path))
    }
    v <- geodata::gadm(country = "IND", level = gadm_level, path = tempdir())
    result <- sf::st_as_sf(v)
    saveRDS(result, path)
    return(result)
  }

  if (level == "country") {
    raw <- .bhuvan_get("geometryState.php", list(state = "INDIA"))
    if (is.null(raw)) {
      return(NULL)
    }
    return(.bhuvan_json_to_sf(raw))
  }

  states_raw <- .bhuvan_get("getStates.php")
  if (is.null(states_raw)) {
    return(NULL)
  }
  states <- unlist(states_raw)

  if (level == "state") {
    sf_list <- lapply(states, function(s) {
      raw <- .bhuvan_get("geometryState.php", list(state = s))
      if (is.null(raw)) {
        return(NULL)
      }
      result <- .bhuvan_json_to_sf(raw)
      result$state_name <- .normalise_state(s)
      result
    })
    sf_list <- Filter(Negate(is.null), sf_list)
    return(do.call(rbind, sf_list))
  }

  sf_list <- lapply(states, function(s) {
    districts_raw <- .bhuvan_get("getDistricts.php", list(statename = s))
    if (is.null(districts_raw)) {
      return(NULL)
    }
    districts <- unlist(districts_raw)
    d_list <- lapply(districts, function(d) {
      raw <- .bhuvan_get("geometryDistrict.php", list(state = s, district = d))
      if (is.null(raw)) {
        return(NULL)
      }
      result <- .bhuvan_json_to_sf(raw)
      result$state_name <- .normalise_state(s)
      result$district_name <- d
      result
    })
    do.call(rbind, Filter(Negate(is.null), d_list))
  })
  do.call(rbind, Filter(Negate(is.null), sf_list))
}

.bhuvan_json_to_sf <- function(raw) {
  tmp <- tempfile(fileext = ".geojson")
  writeLines(jsonlite::toJSON(raw, auto_unbox = TRUE), tmp)
  sf::read_sf(tmp)
}
