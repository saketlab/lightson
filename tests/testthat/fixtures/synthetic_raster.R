# Helpers for building synthetic terra objects in tests — no API keys needed.

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
      sf::st_polygon(list(cbind(c(68, 88, 88, 68, 68), c(18, 18, 28, 28, 18))))
    ),
    crs = 4326
  ))
}
