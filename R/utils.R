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
#' @param source One of `"viirs"`, `"bhuvan"`, or `NULL`.
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

#' Index nighttime-light values to a baseline period
#'
#' Converts each group's values to an index where its baseline observation is
#' 100. This is useful for comparing changes between sources with different
#' units, but does not make their absolute levels comparable.
#'
#' @param panel Data frame containing nighttime-light observations.
#' @param baseline Baseline value in `time_col`, such as `2020` or an ISO date.
#' @param group_cols Grouping columns. If omitted, uses `source` when present
#'   plus `region_id` or `state`.
#' @param time_col Time column name. Defaults to `"year"`.
#' @param value_col Value column name. Defaults to `"mean_radiance"`.
#' @param index_col Name for the new index column.
#' @return `panel` with an additional numeric index column.
#' @export
ntl_index <- function(panel, baseline, group_cols = NULL, time_col = "year",
                      value_col = "mean_radiance", index_col = "ntl_index") {
  needed <- c(time_col, value_col)
  if (!all(needed %in% names(panel))) {
    stop("`panel` is missing required columns: ",
      paste(setdiff(needed, names(panel)), collapse = ", "),
      call. = FALSE
    )
  }
  if (is.null(group_cols)) {
    id <- intersect(c("region_id", "state"), names(panel))[1]
    group_cols <- c(if ("source" %in% names(panel)) "source", id)
    group_cols <- group_cols[!is.na(group_cols)]
  }
  if (!length(group_cols) || !all(group_cols %in% names(panel))) {
    stop("`group_cols` must identify columns in `panel`.", call. = FALSE)
  }

  key <- interaction(panel[group_cols], drop = TRUE, lex.order = TRUE)
  groups <- split(seq_len(nrow(panel)), key)
  out <- rep(NA_real_, nrow(panel))
  for (idx in groups) {
    base <- panel[[value_col]][idx[panel[[time_col]][idx] == baseline]]
    if (length(base) != 1L || is.na(base) || base == 0) next
    out[idx] <- 100 * panel[[value_col]][idx] / base
  }
  panel[[index_col]] <- out
  panel
}

#' Measure agreement between two nighttime-light panels
#'
#' Aligns observations by region and time, then calculates within-region
#' correlation between two sources. Correlation compares co-movement, not
#' absolute levels or units.
#'
#' @param x,y Panel data frames, such as outputs from [extract_panel()].
#' @param id_col Region identifier column.
#' @param time_col Shared time column.
#' @param value_col Measurement column in both panels.
#' @param method Correlation method passed to [stats::cor()].
#' @return Data frame with region, correlation, and paired observation count.
#' @export
ntl_source_agreement <- function(x, y, id_col = "region_id", time_col = "year",
                                 value_col = "mean_radiance",
                                 method = c("pearson", "spearman", "kendall")) {
  method <- match.arg(method)
  needed <- c(id_col, time_col, value_col)
  if (!all(needed %in% names(x)) || !all(needed %in% names(y))) {
    stop("Both panels must contain: ", paste(needed, collapse = ", "), call. = FALSE)
  }
  joined <- merge(x[needed], y[needed],
    by = c(id_col, time_col),
    suffixes = c("_x", "_y")
  )
  value_x <- paste0(value_col, "_x")
  value_y <- paste0(value_col, "_y")
  regions <- split(joined, joined[[id_col]])
  rows <- lapply(regions, function(z) {
    complete <- stats::complete.cases(z[[value_x]], z[[value_y]])
    zx <- z[[value_x]][complete]
    zy <- z[[value_y]][complete]
    estimate <- if (length(zx) < 2L || stats::sd(zx) == 0 || stats::sd(zy) == 0) {
      NA_real_
    } else {
      stats::cor(zx, zy, method = method)
    }
    data.frame(
      region_id = as.character(z[[id_col]][1]), correlation = estimate,
      observations = length(zx), stringsAsFactors = FALSE
    )
  })
  result <- do.call(rbind, rows)
  rownames(result) <- NULL
  names(result)[1] <- id_col
  result[order(result$correlation, na.last = TRUE), ]
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
