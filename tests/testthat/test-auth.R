test_that("earthdata_token returns token passed directly", {
  expect_equal(earthdata_token("mytoken"), "mytoken")
})

test_that("earthdata_token reads EARTHDATA_TOKEN env var", {
  withr::with_envvar(c(EARTHDATA_TOKEN = "envtoken"), {
    expect_equal(earthdata_token(), "envtoken")
  })
})

test_that("earthdata_token stops when no token available", {
  withr::with_envvar(c(EARTHDATA_TOKEN = ""), {
    expect_error(earthdata_token(), "Earthdata token")
  })
})
