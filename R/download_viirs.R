LAADS_BASE <- "https://ladsweb.modaps.eosdis.nasa.gov"
LAADS_ARCHIVE <- "/archive/allData/5200"

#' Download NASA Black Marble nighttime lights
#'
#' Downloads calibrated VIIRS Black Marble annual (`VNP46A4`), monthly
#' (`VNP46A3`), or daily (`VNP46A2`) rasters from NASA LAADS DAAC.
#'
#' @param region An `sf` object, `SpatVector`, or ISO 3166-1 alpha-3 code.
#' @param years Integer years. Required for annual data; selects all twelve
#'   months for monthly data when `dates` is omitted.
#' @param token NASA Earthdata bearer token from [earthdata_token()].
#' @param force Re-download cached output.
#' @param product One of `"annual"`, `"monthly"`, or `"daily"`.
#' @param dates Date-like vector. Required for daily data. Monthly dates are
#'   normalised to the first day of their month.
#' @param quality For daily data, `"high"` masks pixels whose mandatory QA
#'   flag is nonzero; `"all"` retains every retrieval.
#' @return Named list of cropped `SpatRaster` objects. Names are years for
#'   annual data and ISO dates otherwise.
#' @export
#' @examples
#' \dontrun{
#' token <- earthdata_token()
#' annual <- ntl_download("IND", 2020:2025, token)
#' monthly <- ntl_download("IND", 2025, token, product = "monthly")
#' daily <- ntl_download("IND",
#'   token = token, product = "daily",
#'   dates = as.Date("2025-11-12")
#' )
#' }
ntl_download <- function(region, years = NULL, token, force = FALSE,
                         product = c("annual", "monthly", "daily"),
                         dates = NULL, quality = c("high", "all")) {
  product <- match.arg(product)
  quality <- match.arg(quality)
  acquisitions <- .viirs_acquisitions(product, years, dates)
  bbox <- .region_to_bbox(region)
  bbox_hash <- .short_hash(paste(bbox, collapse = "_"))
  tiles <- .bbox_to_viirs_tiles(bbox)
  tile_names <- vapply(tiles, function(x) sprintf("h%02dv%02d", x$h, x$v), character(1))
  product_id <- c(annual = "VNP46A4", monthly = "VNP46A3", daily = "VNP46A2")[[product]]

  result <- lapply(seq_along(acquisitions), function(i) {
    acquisition <- acquisitions[[i]]
    label <- names(acquisitions)[i]
    key <- paste("viirs", product, bbox_hash, label, quality, sep = "_")
    path <- file.path(.cache_dir(), paste0(key, ".tif"))
    if (.cache_hit(path, force)) {
      return(.set_ntl_metadata(terra::rast(path), product_id, product))
    }
    listing <- .laads_csv_listing(product_id, acquisition)
    if (is.null(listing)) {
      return(NULL)
    }
    matched <- listing[vapply(listing$name, function(n) {
      bits <- strsplit(n, ".", fixed = TRUE)[[1]]
      length(bits) >= 3 && bits[3] %in% tile_names
    }, logical(1)), , drop = FALSE]
    if (!nrow(matched)) {
      message("No ", product_id, " tiles found for ", label)
      return(NULL)
    }
    message("Downloading ", product_id, ": ", label, " (", nrow(matched), " tile(s)) ...")
    rs <- lapply(matched$name, .download_viirs_tile,
      product_id = product_id,
      acquisition = acquisition, token = token, quality = quality
    )
    rs <- Filter(Negate(is.null), rs)
    if (!length(rs)) {
      return(NULL)
    }
    r <- if (length(rs) == 1) rs[[1]] else do.call(terra::mosaic, c(rs, list(fun = "mean")))
    r <- terra::crop(r, terra::ext(bbox["xmin"], bbox["xmax"], bbox["ymin"], bbox["ymax"]))
    terra::writeRaster(r, path, overwrite = TRUE)
    .set_ntl_metadata(terra::rast(path), product_id, product)
  })
  names(result) <- names(acquisitions)
  result[!vapply(result, is.null, logical(1))]
}

.set_ntl_metadata <- function(r, product, cadence, units = "nW/cm^2/sr") {
  attr(r, "lightson_product") <- product
  attr(r, "lightson_cadence") <- cadence
  attr(r, "lightson_units") <- units
  r
}

.viirs_acquisitions <- function(product, years, dates) {
  if (product == "annual") {
    if (is.null(years) || !length(years)) stop("`years` is required for annual data.", call. = FALSE)
    x <- as.Date(sprintf("%04d-01-01", as.integer(years)))
    return(stats::setNames(as.list(x), as.character(as.integer(years))))
  }
  if (is.null(dates)) {
    if (product == "daily") stop("`dates` is required for daily data.", call. = FALSE)
    if (is.null(years) || !length(years)) stop("Supply `years` or `dates` for monthly data.", call. = FALSE)
    x <- lapply(as.integer(years), function(y) seq(as.Date(sprintf("%d-01-01", y)), as.Date(sprintf("%d-12-01", y)), by = "month"))
    dates <- do.call(c, x)
  }
  x <- as.Date(dates)
  if (anyNA(x)) stop("`dates` contains invalid dates.", call. = FALSE)
  if (product == "monthly") x <- as.Date(format(x, "%Y-%m-01"))
  x <- unique(x)
  stats::setNames(as.list(x), as.character(x))
}

.laads_csv_listing <- function(product_id, acquisition) {
  url <- paste0(
    LAADS_BASE, LAADS_ARCHIVE, "/", product_id, "/",
    format(acquisition, "%Y/%j"), ".csv"
  )
  tryCatch(utils::read.csv(url, stringsAsFactors = FALSE), error = function(e) {
    message("LAADS listing failed for ", product_id, " ", acquisition, ": ", conditionMessage(e))
    NULL
  })
}

.download_viirs_tile <- function(fname, product_id, acquisition, token, quality) {
  url <- paste0(
    LAADS_BASE, LAADS_ARCHIVE, "/", product_id, "/",
    format(acquisition, "%Y/%j"), "/", fname
  )
  tmp <- tempfile(fileext = ".h5")
  tryCatch(
    {
      resp <- httr2::request(url) |>
        httr2::req_headers(Authorization = paste("Bearer", token)) |>
        httr2::req_retry(max_tries = 3, backoff = ~ 2 * .x) |>
        httr2::req_perform()
      body <- httr2::resp_body_raw(resp)
      is_html <- length(body) >= 5 && rawToChar(body[1:5]) %in% c("<!DOC", "<html", "<HTML")
      if (is_html || length(body) < 10000) {
        stop("Received an HTML page instead of an HDF5 file: token invalid or EULA not accepted for this dataset.")
      }
      writeBin(body, tmp)
      out <- terra::toMemory(.parse_black_marble(tmp, product_id, quality))
      unlink(tmp)
      out
    },
    error = function(e) {
      message("Tile download failed (", fname, "): ", conditionMessage(e))
      unlink(tmp)
      NULL
    }
  )
}

.parse_black_marble <- function(path, product_id, quality = "high") {
  s <- terra::sds(path)
  nms <- names(s)
  wanted <- if (product_id == "VNP46A2") "Gap.*Filled.*DNB.*BRDF.*Corrected.*NTL" else "AllAngle.*Composite.*Snow.*Free"
  idx <- grep(wanted, nms, ignore.case = TRUE)
  if (!length(idx)) stop("Could not find the Black Marble science band in HDF5 file.")
  r <- s[idx[1]]
  if (inherits(r, "SpatRasterDataset")) r <- r[[1]]
  if (product_id == "VNP46A2" && quality == "high") {
    qidx <- grep("Mandatory.*Quality.*Flag", nms, ignore.case = TRUE)
    if (length(qidx)) {
      qa <- s[qidx[1]]
      if (inherits(qa, "SpatRasterDataset")) qa <- qa[[1]]
      r <- terra::ifel(qa == 0, r, NA)
    } else {
      warning("Daily QA band not found; returning unmasked radiance.", call. = FALSE)
    }
  }
  r
}

.bbox_to_viirs_tiles <- function(bbox) {
  grid <- expand.grid(
    h = floor((bbox["xmin"] + 180) / 10):floor((bbox["xmax"] + 180) / 10),
    v = floor((90 - bbox["ymax"]) / 10):floor((90 - bbox["ymin"]) / 10)
  )
  lapply(seq_len(nrow(grid)), function(i) list(h = grid$h[i], v = grid$v[i]))
}
