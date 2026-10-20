test_that(".normalise_state maps known mismatches correctly", {
  expect_equal(lightson:::.normalise_state("TAMILNADU"), "Tamil Nadu")
  expect_equal(lightson:::.normalise_state("UTTARANCHAL"), "Uttarakhand")
  expect_equal(lightson:::.normalise_state("PONDICHERRY"), "Puducherry")
})

test_that(".normalise_state title-cases unknown states", {
  expect_equal(lightson:::.normalise_state("UTTAR PRADESH"), "Uttar Pradesh")
  expect_equal(lightson:::.normalise_state("MAHARASHTRA"), "Maharashtra")
})

test_that(".rgb_to_radiance maps legend colours and drops everything else", {
  rgb <- rbind(
    c(0, 0, 0), c(71, 71, 95), c(245, 235, 172), c(255, 0, 0), # classes
    c(255, 255, 255), c(157, 157, 157), c(255, 157, 157) # background, watermark
  )
  r <- terra::rast(nrows = 1, ncols = nrow(rgb), nlyr = 3)
  terra::values(r) <- rgb
  rad <- lightson:::.rgb_to_radiance(r)
  expect_equal(terra::nlyr(rad), 1L)
  expect_equal(terra::values(rad)[, 1], c(2.5, 15, 112.5, 200, NA, NA, NA))
})

test_that(".rgb_to_radiance returns input unchanged for single-band raster", {
  r <- terra::rast(nrows = 5, ncols = 5)
  terra::values(r) <- 42
  expect_equal(terra::nlyr(lightson:::.rgb_to_radiance(r)), 1L)
})

test_that("ntl_index indexes within source and region", {
  panel <- expand.grid(
    source = c("a", "b"), region_id = c("x", "y"),
    year = 2020:2021, stringsAsFactors = FALSE
  )
  panel$mean_radiance <- c(10, 20, 5, 10, 15, 30, 10, 20)
  result <- ntl_index(panel, 2020, c("source", "region_id"))
  expect_true(all(result$ntl_index[result$year == 2020] == 100))
  expect_true(all(is.finite(result$ntl_index)))
})

test_that("ntl_index leaves groups without a valid baseline as NA", {
  panel <- data.frame(region_id = "x", year = 2021, mean_radiance = 4)
  expect_true(is.na(ntl_index(panel, 2020)$ntl_index))
})

test_that("ntl_source_agreement aligns panels and calculates correlation", {
  x <- data.frame(
    region_id = rep(c("a", "b"), each = 3), year = rep(2020:2022, 2),
    mean_radiance = c(1, 2, 3, 2, 4, 6)
  )
  y <- data.frame(
    region_id = rep(c("a", "b"), each = 3), year = rep(2020:2022, 2),
    mean_radiance = c(2, 4, 6, 6, 4, 2)
  )
  result <- ntl_source_agreement(x, y)
  expect_equal(result$correlation, c(-1, 1))
  expect_equal(result$observations, c(3L, 3L))
})

test_that(".warn_collection_break warns, messages, or stays quiet", {
  expect_warning(.warn_collection_break(2023:2024), "collection break")
  expect_message(.warn_collection_break(2024), "Collection 2.0")
  expect_silent(.warn_collection_break(2015:2023))
})

test_that("cache_clear removes only the requested source", {
  cache <- local_lightson_cache()
  file.create(file.path(cache, c("bhuvan_v2_a_2020.tif", "viirs_annual_a_2020.tif", "keep.rds")))
  expect_equal(suppressMessages(cache_clear("bhuvan")), 1L)
  expect_equal(suppressMessages(cache_clear()), 1L)
  expect_equal(list.files(cache), "keep.rds")
})

test_that(".region_to_bbox handles sf in any CRS and SpatVector/SpatRaster", {
  poly <- make_square()
  bb <- .region_to_bbox(poly)
  expect_equal(bb, c(xmin = 77, xmax = 78, ymin = 28, ymax = 29))
  expect_equal(.region_to_bbox(sf::st_transform(poly, 3857)), bb, tolerance = 1e-6)
  expect_equal(.region_to_bbox(terra::vect(poly)), bb)
})

test_that(".region_mask returns a SpatVector for polygons and NULL otherwise", {
  expect_s4_class(.region_mask(make_square()), "SpatVector")
  expect_null(.region_mask(terra::rast()))
})

test_that(".resolve_region('IND') uses bundled states without network", {
  expect_s3_class(.resolve_region("IND"), "sf")
})

test_that("ntl_index validates columns", {
  panel <- data.frame(region_id = "x", year = 2020, mean_radiance = 1)
  expect_error(ntl_index(panel[1:2], 2020), "missing required columns")
  expect_error(ntl_index(panel, 2020, group_cols = "nope"), "group_cols")
  expect_true(is.na(ntl_index(transform(panel, mean_radiance = 0), 2020)$ntl_index))
})

test_that("ntl_source_agreement gives NA for constant or short series", {
  x <- data.frame(region_id = c("a", "a", "b"), year = c(2020, 2021, 2020), mean_radiance = c(1, 1, 2))
  result <- ntl_source_agreement(x, x)
  expect_true(all(is.na(result$correlation)))
  expect_error(ntl_source_agreement(x, x[1:2]), "Both panels")
})
