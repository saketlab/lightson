#' Get pre-aggregated Bhuvan NTL state statistics
#'
#' Wraps the ISRO Bhuvan NTL REST API to return mean radiance per Indian
#' state across years.
#'
#' For district-level or custom-geometry statistics, use [bhuvan_raster()]
#' together with [extract_panel()].
#'
#' @param years Integer vector of years to return. `NULL` (default) returns
#'   all available years (currently 2012-2024).
#' @param state Character. State name as returned by the API (e.g., `"BIHAR"`).
#'   `NULL` (default) returns all states.
#' @return A tidy data frame with columns `state` (character), `year`
#'   (integer), and `mean_radiance` (numeric). State names are normalised to
#'   title case (e.g., `"Tamil Nadu"` not `"TAMILNADU"`).
#' @section Collection break:
#'   Bhuvan NTL data from 2024 onwards is derived from VNP46A4 **Collection
#'   2.0**, while 2012-2023 uses the legacy **Collection 1.0**. The two
#'   collections use different calibration and atmospheric correction
#'   algorithms, so radiance estimates are not directly comparable across this
#'   boundary. Requests spanning both collections trigger a warning.
#' @export
#' @examples
#' \dontrun{
#' # All states, all years
#' df <- bhuvan_stats()
#'
#' # Bihar only
#' df <- bhuvan_stats(state = "BIHAR")
#'
#' # Multiple years
#' df <- bhuvan_stats(years = 2015:2023)
#' }
bhuvan_stats <- function(years = NULL, state = NULL) {
  if (is.null(state)) {
    raw <- .bhuvan_get("getIndiaStats.php")
  } else {
    raw <- .bhuvan_get("getStats.php", list(state = toupper(state)))
  }

  if (is.null(raw)) {
    return(NULL)
  }

  df <- .bhuvan_wide_to_long(raw)

  if (!is.null(years)) {
    df <- df[df$year %in% as.integer(years), ]
  }

  .warn_collection_break(df$year)
  df
}

#' Download Bhuvan NTL raster tiles for a region
#'
#' Fetches annual nighttime lights GeoTIFF tiles from the Bhuvan WMS service
#' for a given spatial extent and converts the RGB visualization output to a
#' single-band luminance raster.
#'
#' The Bhuvan WMS returns RGB visualization rasters. Luminance is computed
#' as `lum = 0.2126*R + 0.7152*G + 0.0722*B`
#' (ITU-R BT.709). Values are comparable across years for trend analysis but
#' differ in units from VIIRS nW/cm²/sr. Do not mix Bhuvan luminance and VIIRS
#' radiance in the same regression without normalising first.
#'
#' @param region An `sf` object, `SpatVector`, or ISO 3166-1 alpha-3 country
#'   code (e.g., `"IND"`). Used to derive the WMS bounding box.
#' @param years Integer vector of years to download (2012-2024).
#' @param force Logical. If `TRUE`, re-download even if cached. Default `FALSE`.
#' @param width,height Pixel dimensions of the WMS request. Default 1024x1024.
#' @param bbox_pad Numeric vector of length 1 or 4 (xmin, ymin, xmax, ymax
#'   sides) in degrees, added to the region bounding box before the WMS
#'   request. Useful when GADM boundaries clip disputed territories (e.g.
#'   `bbox_pad = c(0, 0, 0, 3.5)` extends the north edge by 3.5 degrees to
#'   include all of Jammu and Kashmir).
#' @return A named list of single-band `SpatRaster` objects, keyed by year
#' @section Collection break:
#'   Bhuvan NTL data from 2024 onwards is derived from VNP46A4 **Collection
#'   2.0**, while 2012-2023 uses the legacy **Collection 1.0**. The two
#'   collections use different calibration and atmospheric correction
#'   algorithms, so luminance values are not directly comparable across this
#'   boundary.
#'   (e.g., `list("2020" = rast(...), "2021" = rast(...))`).
#' @export
#' @examples
#' \dontrun{
#' districts <- sf::read_sf("https://bharatviz.org/India-bhuvan-districts.geojson")
#' rasters <- bhuvan_raster(districts, years = 2018:2023)
#' panel <- extract_panel(rasters, districts)
#' }
bhuvan_raster <- function(region, years, force = FALSE, width = 1024, height = 1024,
                          bbox_pad = c(0, 0, 0, 0)) {
  .warn_collection_break(as.integer(years))

  region <- .resolve_region(region)
  bbox <- .region_to_bbox(region)
  pad <- rep_len(bbox_pad, 4)
  bbox["xmin"] <- bbox["xmin"] - pad[1]
  bbox["ymin"] <- bbox["ymin"] - pad[2]
  bbox["xmax"] <- bbox["xmax"] + pad[3]
  bbox["ymax"] <- bbox["ymax"] + pad[4]
  bbox_hash <- .short_hash(paste(bbox, collapse = "_"))
  cache_d <- .cache_dir()

  mv <- .region_mask(region)

  result <- lapply(as.integer(years), function(yr) {
    key <- paste0("bhuvan_", bbox_hash, "_", yr)
    path <- file.path(cache_d, paste0(key, ".tif"))

    if (.cache_hit(path, force)) {
      message("Using cached: ", basename(path))
      return(terra::rast(path))
    }

    message("Downloading Bhuvan WMS: year ", yr, " ...")
    r <- .bhuvan_wms_fetch(bbox, yr, width, height)
    if (is.null(r)) {
      return(NULL)
    }

    lum <- .rgb_to_luminance(r)
    if (!is.null(mv)) lum <- terra::mask(lum, mv)
    terra::writeRaster(lum, path, overwrite = TRUE)
    lum
  })

  names(result) <- as.character(years)
  result[!vapply(result, is.null, logical(1))]
}

.bhuvan_get <- function(endpoint, query = list()) {
  url <- paste0(BHUVAN_NTL_BASE, endpoint)
  req <- httr2::request(url)
  if (length(query) > 0) req <- httr2::req_url_query(req, !!!query)
  req <- httr2::req_retry(req, max_tries = 3, backoff = ~ 2 * .x)

  resp <- tryCatch(httr2::req_perform(req), error = function(e) {
    message("Bhuvan API request failed: ", conditionMessage(e))
    NULL
  })
  if (is.null(resp)) {
    return(NULL)
  }
  httr2::resp_body_json(resp, simplifyVector = TRUE, check_type = FALSE)
}

.bhuvan_wide_to_long <- function(raw) {
  if (is.null(raw) || length(raw) == 0) {
    return(NULL)
  }

  df <- as.data.frame(raw)
  yr_cols <- grep("^avg_", names(df), value = TRUE)
  state_col <- names(df)[!grepl("^avg_", names(df))][1]
  states_normalised <- vapply(df[[state_col]], .normalise_state, character(1))

  rows <- lapply(yr_cols, function(col) {
    data.frame(
      state = states_normalised,
      year = as.integer(sub("avg_", "", col)),
      mean_radiance = as.numeric(df[[col]]),
      stringsAsFactors = FALSE
    )
  })

  result <- do.call(rbind, rows)
  rownames(result) <- NULL
  result
}

.bhuvan_wms_fetch <- function(bbox, year, width, height) {
  time_str <- paste0(year, "-01-01T00:00:00.000Z")
  bbox_str <- paste(bbox[c("xmin", "ymin", "xmax", "ymax")], collapse = ",")

  req <- httr2::request(BHUVAN_WMS_BASE) |>
    httr2::req_url_query(
      SERVICE     = "WMS",
      VERSION     = "1.1.1",
      REQUEST     = "GetMap",
      LAYERS      = BHUVAN_WMS_LAYER,
      STYLES      = "",
      SRS         = "EPSG:4326",
      BBOX        = bbox_str,
      WIDTH       = width,
      HEIGHT      = height,
      FORMAT      = "image/geotiff",
      TIME        = time_str,
      TRANSPARENT = "false"
    ) |>
    httr2::req_retry(max_tries = 3, backoff = ~ 2 * .x)

  resp <- tryCatch(httr2::req_perform(req), error = function(e) {
    message("Bhuvan WMS fetch failed: ", conditionMessage(e))
    NULL
  })
  if (is.null(resp)) {
    return(NULL)
  }

  raw_bytes <- httr2::resp_body_raw(resp)
  tmp <- tempfile(fileext = ".tif")
  writeBin(raw_bytes, tmp)
  r <- tryCatch(
    {
      disk_r <- terra::rast(tmp)
      vals <- terra::values(disk_r)
      mem_r <- terra::rast(disk_r)
      terra::values(mem_r) <- vals
      mem_r
    },
    error = function(e) {
      message("Failed to parse WMS response as GeoTIFF: ", conditionMessage(e))
      NULL
    }
  )
  unlink(tmp)
  r
}

.rgb_to_luminance <- function(r) {
  if (terra::nlyr(r) < 3) {
    return(r)
  }
  lum <- 0.2126 * r[[1]] + 0.7152 * r[[2]] + 0.0722 * r[[3]]
  mask <- (r[[1]] == 255) & (r[[2]] == 255) & (r[[3]] == 255)
  terra::mask(lum, mask, maskvalue = TRUE)
}
