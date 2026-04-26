#' Download VIIRS Black Marble annual nighttime lights
#'
#' Downloads NASA VIIRS/Black Marble VNP46A4 annual composite rasters from
#' NASA LAADS DAAC for a given region and year range.
#'
#' Requires a NASA Earthdata bearer token, see [earthdata_token()].
#'
#' @param source Character. Currently only `"viirs"` is supported.
#' @param region An `sf` object, `SpatVector`, or ISO 3166-1 alpha-3 country
#'   code (e.g., `"IND"`).
#' @param years Integer vector of years to download.
#' @param token A bearer token string from [earthdata_token()].
#' @param force Logical. Re-download even if cached. Default `FALSE`.
#' @return A named list of `SpatRaster` objects, keyed by year.
#' @export
#' @examples
#' \dontrun{
#' token <- earthdata_token()
#' rasters <- ntl_download("viirs", region = "IND", years = 2020:2023, token = token)
#' panel <- extract_panel(rasters, get_india_admin("district"))
#' }
ntl_download <- function(source = "viirs", region, years, token, force = FALSE) {
  source <- match.arg(source, choices = "viirs")
  .ntl_download_viirs(region = region, years = as.integer(years), token = token, force = force)
}

LAADS_BASE <- "https://ladsweb.modaps.eosdis.nasa.gov"
LAADS_ARCHIVE <- "/archive/allData/5200/VNP46A4"

.ntl_download_viirs <- function(region, years, token, force) {
  bbox <- .region_to_bbox(region)
  bbox_hash <- .short_hash(paste(bbox, collapse = "_"))
  tiles <- .bbox_to_viirs_tiles(bbox)
  tile_names <- vapply(tiles, function(t) sprintf("h%02dv%02d", t$h, t$v), character(1))
  cache_d <- .cache_dir()

  years_to_download <- years[!vapply(years, function(yr) {
    .cache_hit(file.path(cache_d, paste0("viirs_", bbox_hash, "_", yr, ".tif")), force)
  }, logical(1))]
  listings <- stats::setNames(
    lapply(unique(years_to_download), .laads_csv_listing),
    as.character(unique(years_to_download))
  )

  result <- lapply(years, function(yr) {
    key <- paste0("viirs_", bbox_hash, "_", yr)
    path <- file.path(cache_d, paste0(key, ".tif"))

    if (.cache_hit(path, force)) {
      message("Using cached: ", basename(path))
      return(terra::rast(path))
    }

    listing <- listings[[as.character(yr)]]
    if (is.null(listing)) {
      return(NULL)
    }

    matched <- listing[
      vapply(listing$name, function(n) {
        strsplit(n, ".", fixed = TRUE)[[1]][3] %in% tile_names
      }, logical(1)),
    ]

    if (nrow(matched) == 0) {
      message("No tiles found for year ", yr, " in region")
      return(NULL)
    }

    message("Downloading VIIRS VNP46A4: year ", yr, " (", nrow(matched), " tile(s)) ...")
    tile_rasters <- lapply(matched$name, function(fname) {
      .download_viirs_tile(fname, yr, token)
    })
    tile_rasters <- Filter(Negate(is.null), tile_rasters)

    if (length(tile_rasters) == 0) {
      message("No tiles downloaded for year ", yr)
      return(NULL)
    }

    r <- if (length(tile_rasters) == 1) {
      tile_rasters[[1]]
    } else {
      do.call(terra::mosaic, c(tile_rasters, list(fun = "mean")))
    }

    r_crop <- terra::crop(r, terra::ext(bbox["xmin"], bbox["xmax"], bbox["ymin"], bbox["ymax"]))
    terra::writeRaster(r_crop, path, overwrite = TRUE)
    r_crop
  })

  names(result) <- as.character(years)
  result[!vapply(result, is.null, logical(1))]
}

.laads_csv_listing <- function(year) {
  url <- paste0(LAADS_BASE, LAADS_ARCHIVE, "/", year, "/001.csv")
  tryCatch(
    utils::read.csv(url, stringsAsFactors = FALSE),
    error = function(e) {
      message("LAADS listing failed for year ", year, ": ", conditionMessage(e))
      NULL
    }
  )
}

.download_viirs_tile <- function(fname, year, token) {
  doy <- substring(fname, 14, 16)
  url <- paste0(LAADS_BASE, LAADS_ARCHIVE, "/", year, "/", doy, "/", fname)
  tmp <- tempfile(fileext = ".h5")

  req <- httr2::request(url) |>
    httr2::req_headers(Authorization = paste("Bearer", token)) |>
    httr2::req_retry(max_tries = 3, backoff = ~ 2 * .x)

  tryCatch(
    {
      resp <- httr2::req_perform(req)
      body <- httr2::resp_body_raw(resp)
      if (length(body) < 10000) {
        stop("Response too small: token may be invalid or EULA not accepted")
      }
      writeBin(body, tmp)
      result <- terra::toMemory(.parse_vnp46a4(tmp))
      unlink(tmp)
      result
    },
    error = function(e) {
      message("Tile download failed (", fname, "): ", conditionMessage(e))
      unlink(tmp)
      NULL
    }
  )
}

.parse_vnp46a4 <- function(h5_path) {
  # Collection 2 (2022+): VIIRS_Grid_DNB_2d / AllAngle_Composite_Snow_Free
  # Collection 1 (pre-2022): VNP_Grid_DNB / Gap_Filled_DNB_BRDF-Corrected_NTL
  band_c2 <- paste0("HDF5:\"", h5_path, "\"://HDFEOS/GRIDS/VIIRS_Grid_DNB_2d/Data_Fields/AllAngle_Composite_Snow_Free")
  band_c1 <- paste0("HDF5:\"", h5_path, "\"://HDFEOS/GRIDS/VNP_Grid_DNB/Data Fields/Gap_Filled_DNB_BRDF-Corrected_NTL")

  r <- tryCatch(terra::rast(band_c2), error = function(e) NULL)
  if (is.null(r)) {
    r <- tryCatch(terra::rast(band_c1), error = function(e) {
      message("HDF5 parse failed: ", conditionMessage(e))
      NULL
    })
  }
  r
}

.bbox_to_viirs_tiles <- function(bbox) {
  xmin <- bbox["xmin"]
  xmax <- bbox["xmax"]
  ymin <- bbox["ymin"]
  ymax <- bbox["ymax"]

  h_min <- floor((xmin + 180) / 10)
  h_max <- floor((xmax + 180) / 10)
  v_min <- floor((90 - ymax) / 10)
  v_max <- floor((90 - ymin) / 10)

  grid <- expand.grid(h = h_min:h_max, v = v_min:v_max)
  lapply(seq_len(nrow(grid)), function(i) list(h = grid$h[i], v = grid$v[i]))
}
