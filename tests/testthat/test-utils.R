test_that(".normalise_state maps known mismatches correctly", {
  expect_equal(lightson:::.normalise_state("TAMILNADU"), "Tamil Nadu")
  expect_equal(lightson:::.normalise_state("UTTARANCHAL"), "Uttarakhand")
  expect_equal(lightson:::.normalise_state("PONDICHERRY"), "Puducherry")
})

test_that(".normalise_state title-cases unknown states", {
  expect_equal(lightson:::.normalise_state("UTTAR PRADESH"), "Uttar Pradesh")
  expect_equal(lightson:::.normalise_state("MAHARASHTRA"), "Maharashtra")
})

test_that(".rgb_to_luminance collapses 3-band raster to 1 band", {
  r <- terra::rast(nrows = 5, ncols = 5, nlyr = 3)
  terra::values(r) <- rep(c(100, 100, 100), each = 25)
  lum <- lightson:::.rgb_to_luminance(r)
  expect_equal(terra::nlyr(lum), 1L)
  # 0.2126*100 + 0.7152*100 + 0.0722*100 = 100
  expect_equal(round(mean(terra::values(lum), na.rm = TRUE)), 100)
})

test_that(".rgb_to_luminance returns input unchanged for single-band raster", {
  r <- terra::rast(nrows = 5, ncols = 5)
  terra::values(r) <- 42
  expect_equal(terra::nlyr(lightson:::.rgb_to_luminance(r)), 1L)
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
