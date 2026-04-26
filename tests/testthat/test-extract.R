source(test_path("fixtures", "synthetic_raster.R"))

test_that("extract_panel returns correct structure", {
  r1 <- make_raster(vals = rep(10, 100))
  r2 <- make_raster(vals = rep(20, 100))
  rasters <- list("2020" = r1, "2021" = r2)
  polygons <- make_polygons()

  result <- extract_panel(rasters, polygons, id_col = "region_id")

  expect_s3_class(result, "data.frame")
  expect_named(result, c("region_id", "year", "mean_radiance", "n_pixels"))
  expect_equal(nrow(result), 6L) # 3 regions × 2 years
  expect_type(result$region_id, "character")
  expect_type(result$year, "integer")
  expect_type(result$mean_radiance, "double")
})

test_that("extract_panel errors on unnamed rasters list", {
  r <- make_raster()
  polygons <- make_polygons()
  expect_error(extract_panel(list(r), polygons), "named list")
})

test_that("extract_panel errors on empty rasters list", {
  polygons <- make_polygons()
  expect_error(extract_panel(list(), polygons), "non-empty")
})

test_that("extract_panel years in output match raster names", {
  rasters <- list("2019" = make_raster(), "2022" = make_raster())
  result <- extract_panel(rasters, make_polygons(), id_col = "region_id")
  expect_equal(sort(unique(result$year)), c(2019L, 2022L))
})
