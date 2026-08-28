# NSE columns from ggplot2::aes() calls in R/plot.R
utils::globalVariables(c("x", "y", "year", "mean_radiance", ".data"))

BHUVAN_NTL_BASE <- "https://bhuvan-app1.nrsc.gov.in/bhuvanNTL/"
BHUVAN_WMS_BASE <- "https://bhuvan-app1.nrsc.gov.in/vec3wms/wms"
BHUVAN_WMS_LAYER <- "ntl:BhuvanNTL"

.bhuvan_state_lookup <- c(
  "TAMILNADU"            = "Tamil Nadu",
  "UTTARANCHAL"          = "Uttarakhand",
  "PONDICHERRY"          = "Puducherry",
  "ANDAMAN AND NICOBAR"  = "Andaman & Nicobar",
  "JAMMU & KASHMIR"      = "Union Territory of Jammu and Kashmir",
  "LADAKH"               = "Union Territory of Ladakh",
  "DADRA & NAGAR HAVELI" = "Dadar Nagar& Haveli",
  "DAMAN AND DIU"        = "Daman & Diu"
)

.normalise_state <- function(name) {
  if (name %in% names(.bhuvan_state_lookup)) {
    return(.bhuvan_state_lookup[[name]])
  }
  tools::toTitleCase(tolower(name))
}

.cache_dir <- function() {
  d <- tools::R_user_dir("lightson", "cache")
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  d
}

.short_hash <- function(x) {
  substr(digest::digest(x, algo = "md5"), 1, 12)
}

.has_value <- function(x) !is.na(x) && nchar(x) > 0

#' Clear the local lightson cache
#'
#' Removes cached raster files downloaded by `ntl_download()` or `bhuvan_raster()`.
#'
#' @param source One of `"viirs"`, `"bhuvan"`, or `NULL` (clears everything).
#' @return Invisibly returns the number of files removed.
#' @export
cache_clear <- function(source = NULL) {
  d <- .cache_dir()
  pattern <- if (is.null(source)) ".*\\.tif$" else paste0("^", source, "_.*\\.tif$")
  files <- list.files(d, pattern = pattern, full.names = TRUE)
  file.remove(files)
  message("Removed ", length(files), " cached file(s) from ", d)
  invisible(length(files))
}

.cache_hit <- function(path, force) {
  !force && file.exists(path)
}

.warn_collection_break <- function(years) {
  has_legacy <- any(years <= 2023, na.rm = TRUE)
  has_new <- any(years >= 2024, na.rm = TRUE)
  if (has_legacy && has_new) {
    warning(
      "Your request spans a collection break in the Bhuvan NTL data: ",
      "2012-2023 uses VNP46A4 Collection 1.0 and 2024 onwards uses ",
      "Collection 2.0. Radiance estimates are not directly comparable ",
      "across this boundary. Treat any 2023-to-2024 trend as an ",
      "artefact of the collection change.",
      call. = FALSE
    )
  } else if (has_new) {
    message(
      "Bhuvan NTL data from 2024 onwards uses VNP46A4 Collection 2.0. ",
      "Collection 1.0 was used for 2012-2023."
    )
  }
}

.resolve_region <- function(region) {
  if (is.character(region) && nchar(region) == 3) {
    if (!requireNamespace("geodata", quietly = TRUE)) {
      stop("Install the 'geodata' package to use ISO country codes as regions.", call. = FALSE)
    }
    return(geodata::gadm(country = region, level = 0, path = .cache_dir()))
  }
  region
}

.region_to_bbox <- function(region) {
  region <- .resolve_region(region)
  if (inherits(region, "sf")) {
    bb <- sf::st_bbox(sf::st_transform(region, 4326))
    return(c(xmin = bb[["xmin"]], xmax = bb[["xmax"]], ymin = bb[["ymin"]], ymax = bb[["ymax"]]))
  }
  as.vector(terra::ext(region))
}

.region_mask <- function(region) {
  if (!inherits(region, c("sf", "sfc", "SpatVector"))) {
    return(NULL)
  }
  if (inherits(region, "SpatVector")) {
    return(region)
  }
  tryCatch(
    terra::vect(sf::st_union(sf::st_make_valid(region))),
    error = function(e) NULL
  )
}
