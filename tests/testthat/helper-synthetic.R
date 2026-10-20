make_raster <- function(nrow = 10, ncol = 10, vals = NULL, crs = "EPSG:4326",
                        xmin = 68, xmax = 98, ymin = 8, ymax = 38) {
  r <- terra::rast(
    nrows = nrow, ncols = ncol,
    xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax,
    crs = crs
  )
  if (is.null(vals)) {
    vals <- seq_len(terra::ncell(r))
  }
  terra::values(r) <- vals
  r
}

make_polygons <- function() {
  sf::st_as_sf(data.frame(
    region_id = c("A", "B", "C"),
    geometry = sf::st_sfc(
      sf::st_polygon(list(cbind(c(68, 78, 78, 68, 68), c(8, 8, 18, 18, 8)))),
      sf::st_polygon(list(cbind(c(78, 88, 88, 78, 78), c(8, 8, 18, 18, 8)))),
      sf::st_polygon(list(cbind(c(68, 88, 88, 68, 68), c(18, 18, 28, 28, 18)))),
      crs = 4326
    )
  ))
}

make_square <- function(xmin = 77, xmax = 78, ymin = 28, ymax = 29) {
  sf::st_as_sf(sf::st_sfc(
    sf::st_polygon(list(cbind(c(xmin, xmax, xmax, xmin, xmin), c(ymin, ymin, ymax, ymax, ymin)))),
    crs = 4326
  ))
}

make_legend_raster <- function(xmin = 77, xmax = 78, ymin = 28, ymax = 29) {
  r <- terra::rast(nrows = 2, ncols = 2, nlyrs = 3, xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax)
  terra::values(r) <- as.matrix(.bhuvan_classes[c("red", "green", "blue")])
  r
}

local_lightson_cache <- function(env = parent.frame()) {
  cache <- withr::local_tempdir(.local_envir = env)
  local_mocked_bindings(.cache_dir = function() cache, .env = env)
  cache
}
