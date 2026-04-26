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
