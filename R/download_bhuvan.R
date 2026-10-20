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
#' @examplesIf interactive()
#' # All states, all years
#' df <- bhuvan_stats()
#'
#' # Bihar only
#' df <- bhuvan_stats(state = "BIHAR")
#'
#' # Multiple years
#' df <- bhuvan_stats(years = 2015:2023)
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
#' for a given spatial extent and converts the classed RGB map to a
#' single-band radiance raster.
#'
#' The Bhuvan WMS does not serve continuous radiance. It returns a map with
#' four colour classes, which are converted to representative radiance values
#' in nW/cm^2/sr:
#'
#' | Colour     | Class     | Value |
#' |------------|-----------|-------|
#' | black      | < 5       | 2.5   |
#' | blue-grey  | 5 - 25    | 15    |
#' | cream      | 26 - 200  | 112.5 |
#' | red        | > 200     | 200   |
#'
#' The first three values are class midpoints; the open-ended top class is set
#' to its floor, so the brightest areas are underestimated. Pixels that match
#' no class (the portal's watermark and its anti-aliased edges) are `NA`.
#' Treat the output as coarse, banded radiance: use VIIRS from
#' [ntl_download()] when you need continuous calibrated values.
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
#'   (e.g., `list("2020" = rast(...), "2021" = rast(...))`). Errors if the WMS
#'   fetch fails for any requested year.
#' @section Collection break:
#'   Bhuvan NTL data from 2024 onwards is derived from VNP46A4 **Collection
#'   2.0**, while 2012-2023 uses the legacy **Collection 1.0**. The two
#'   collections use different calibration and atmospheric correction
#'   algorithms, so values are not directly comparable across this
#'   boundary.
#' @export
#' @examplesIf interactive()
#' states <- get_india_admin("state")
#' rasters <- bhuvan_raster(states, years = 2021:2022)
#' panel <- extract_panel(rasters, states, id_col = "state_name")
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
    # v2: class radiance; older cached files hold BT.709 luminance
    key <- paste0("bhuvan_v2_", bbox_hash, "_", yr)
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

    rad <- .rgb_to_radiance(r)
    if (!is.null(mv)) rad <- terra::mask(rad, mv)
    terra::writeRaster(rad, path, overwrite = TRUE)
    rad
  })

  names(result) <- as.character(years)
  failed <- vapply(result, is.null, logical(1))
  if (any(failed)) {
    stop(
      "Bhuvan WMS fetch failed for year(s): ",
      paste(names(result)[failed], collapse = ", "),
      call. = FALSE
    )
  }
  result
}

.bhuvan_request <- function(url) {
  httr2::request(url) |>
    # connect timeout only; full-India tiles can take minutes to transfer
    httr2::req_options(connecttimeout = getOption("lightson.timeout", 30)) |>
    httr2::req_retry(max_tries = 3, backoff = ~ 2 * .x)
}

.bhuvan_get <- function(endpoint, query = list()) {
  req <- .bhuvan_request(paste0(BHUVAN_NTL_BASE, endpoint))
  if (length(query) > 0) req <- httr2::req_url_query(req, !!!query)

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

  req <- .bhuvan_request(BHUVAN_WMS_BASE) |>
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
    )

  resp <- tryCatch(httr2::req_perform(req), error = function(e) {
    message("Bhuvan WMS fetch failed: ", conditionMessage(e))
    NULL
  })
  if (is.null(resp)) {
    return(NULL)
  }

  raw_bytes <- httr2::resp_body_raw(resp)
  tmp <- tempfile(fileext = ".tif")
  tmp_raw <- tempfile(fileext = ".vrt")
  writeBin(raw_bytes, tmp)
  r <- tryCatch(
    {
      # nodata=0 per band would erase pure black and red pixels
      sf::gdal_utils("translate", tmp, tmp_raw, options = c("-of", "VRT", "-a_nodata", "none"))
      terra::toMemory(terra::rast(tmp_raw))
    },
    error = function(e) {
      message("Failed to parse WMS response as GeoTIFF: ", conditionMessage(e))
      NULL
    }
  )
  unlink(c(tmp, tmp_raw))
  r
}

# class midpoints; open-ended > 200 class uses its floor
.bhuvan_classes <- data.frame(
  red = c(0, 71, 245, 255),
  green = c(0, 71, 235, 0),
  blue = c(0, 95, 166, 0),
  radiance = c(2.5, 15, 112.5, 200)
)

# off-legend pixels (background, watermark, anti-aliasing) become NA
.rgb_to_radiance <- function(r, tol = 8) {
  if (terra::nlyr(r) < 3) {
    return(r)
  }
  v <- terra::values(r)
  out <- rep(NA_real_, nrow(v))
  for (i in seq_len(nrow(.bhuvan_classes))) {
    k <- .bhuvan_classes[i, ]
    hit <- abs(v[, 1] - k$red) <= tol & abs(v[, 2] - k$green) <= tol &
      abs(v[, 3] - k$blue) <= tol
    out[hit %in% TRUE] <- k$radiance
  }
  rad <- terra::rast(r, nlyrs = 1)
  terra::values(rad) <- out
  rad
}
