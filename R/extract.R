#' Compute zonal statistics for a panel of rasters
#'
#' Takes a named list of `SpatRaster` objects (one per time period, as returned by
#' [ntl_download()] or [bhuvan_raster()]) and an `sf` or `SpatVector` polygon
#' layer, and returns a tidy long-format data frame with one row per region and
#' time period. Annual names such as `"2025"` produce the original four-column
#' output. ISO-date names used by monthly and daily Black Marble additionally
#' produce a `date` column.
#'
#' The `polygons` argument accepts any `sf` object: GADM, bharatviz GeoJSONs,
#' LGD districts, or any shapefile loaded with `sf::read_sf()`.
#'
#' @param rasters A named list of `SpatRaster` objects. Names should be years
#'   or ISO dates (e.g., `"2020"` or `"2025-11-12"`).
#' @param polygons An `sf` object or `SpatVector` containing the regions to
#'   summarise over.
#' @param fun Aggregation function name passed to [terra::zonal()]. Default
#'   `"mean"`. Also accepts `"sum"`, `"median"`, etc.
#' @param id_col Name of the column in `polygons` to use as `region_id`. If
#'   `NULL` (default), the first character column is used.
#' @return A data frame with columns:
#'   \describe{
#'     \item{region_id}{Character. Region identifier from `polygons`.}
#'     \item{year}{Integer. Year, taken from the name of each raster.}
#'     \item{mean_radiance}{Numeric. Aggregated radiance value.}
#'     \item{n_pixels}{Integer. Number of non-NA cells contributing to the stat.}
#'   }
#' @export
#' @examples
#' \dontrun{
#' districts <- sf::read_sf("https://bharatviz.org/India-bhuvan-districts.geojson")
#' rasters <- bhuvan_raster(districts, years = 2018:2023)
#' panel <- extract_panel(rasters, districts)
#' head(panel)
#' }
extract_panel <- function(rasters, polygons, fun = "mean", id_col = NULL) {
  if (!is.list(rasters) || length(rasters) == 0) {
    stop("`rasters` must be a non-empty named list of SpatRaster objects.", call. = FALSE)
  }
  years <- names(rasters)
  if (is.null(years) || any(nchar(years) == 0)) {
    stop("`rasters` must be a named list with year strings as names.", call. = FALSE)
  }

  if (inherits(polygons, "sf")) {
    polygons <- terra::vect(sf::st_cast(polygons, "MULTIPOLYGON"))
  }

  id_col <- id_col %||% .first_char_col(polygons)

  is_annual <- grepl("^[0-9]{4}$", years)
  if (!all(is_annual) && any(is_annual)) {
    stop("Raster names must be either all years or all ISO dates.", call. = FALSE)
  }
  dates <- if (all(is_annual)) rep(as.Date(NA), length(years)) else as.Date(years)
  if (!all(is_annual) && anyNA(dates)) stop("Non-annual raster names must be ISO dates.", call. = FALSE)

  rows <- lapply(seq_along(years), function(i) {
    yr <- if (all(is_annual)) as.integer(years[i]) else as.integer(format(dates[i], "%Y"))
    row <- .extract_zonal(rasters[[years[i]]], polygons, fun = fun, id_col = id_col, year = yr)
    if (!all(is_annual)) row$date <- dates[i]
    row
  })

  result <- do.call(rbind, rows)
  if (!all(is_annual)) {
    result <- result[, c("region_id", "date", "year", "mean_radiance", "n_pixels")]
    return(result[order(result$region_id, result$date), ])
  }
  result[order(result$region_id, result$year), ]
}

.extract_zonal <- function(raster, polygons, fun, id_col, year) {
  id_raster <- terra::rasterize(polygons, raster, field = id_col)

  stat <- terra::zonal(raster, id_raster, fun = fun, na.rm = TRUE)
  counts <- terra::zonal(raster, id_raster, fun = "notNA")

  colnames(stat)[2] <- "mean_radiance"
  colnames(counts)[2] <- "n_pixels"

  merged <- merge(stat, counts, by = colnames(stat)[1])
  colnames(merged)[1] <- "region_id"
  merged$region_id <- as.character(merged$region_id)
  merged$year <- year

  merged[, c("region_id", "year", "mean_radiance", "n_pixels")]
}

.first_char_col <- function(v) {
  df <- as.data.frame(terra::values(v))
  char_cols <- names(df)[vapply(df, is.character, logical(1))]
  if (length(char_cols) == 0) {
    stop(
      "No character column found in `polygons`. Specify `id_col` explicitly.",
      call. = FALSE
    )
  }
  char_cols[[1]]
}

`%||%` <- function(x, y) if (is.null(x)) y else x
