panel <- data.frame(
  region_id = rep(c("A", "B"), each = 3),
  year = rep(2020:2022, 2),
  mean_radiance = c(1, 2, 3, 3, 2, 1)
)

test_that("plot_ntl_trend builds a ggplot and validates input", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("scales")
  expect_s3_class(plot_ntl_trend(panel), "ggplot")
  expect_s3_class(plot_ntl_trend(panel, region = "A"), "ggplot")
  expect_error(plot_ntl_trend(NULL), "upstream download")
  expect_error(plot_ntl_trend(panel, region = "Z"), "No rows")
  expect_error(plot_ntl_trend(panel[-1]), "region_id")
})

test_that("plot_ntl_map renders both palettes with polygons", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("scales")
  r <- make_raster()
  expect_s3_class(plot_ntl_map(r, polygons = make_polygons()), "ggplot")
  expect_s3_class(plot_ntl_map(r, palette = "bhuvan", dark = FALSE), "ggplot")
})

test_that("plot_ntl_panel combines years", {
  skip_if_not_installed("patchwork")
  skip_if_not_installed("scales")
  p <- plot_ntl_panel(list("2020" = make_raster(), "2021" = make_raster()))
  expect_s3_class(p, "patchwork")
})
