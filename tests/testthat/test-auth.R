test_that("earthdata_token returns token passed directly", {
  expect_equal(earthdata_token("mytoken"), "mytoken")
})

test_that("earthdata_token reads EARTHDATA_TOKEN env var", {
  skip_if_not_installed("withr")
  withr::with_envvar(c(EARTHDATA_TOKEN = "envtoken"), {
    expect_equal(earthdata_token(), "envtoken")
  })
})

test_that("earthdata_token stops when no token available", {
  skip_if_not_installed("withr")
  withr::with_envvar(
    c(EARTHDATA_TOKEN = "", EARTHDATA_USERNAME = "", EARTHDATA_PASSWORD = ""),
    {
      expect_error(earthdata_token(), "No Earthdata credentials found")
    }
  )
})

test_that(".fetch_earthdata_token handles success and auth failure", {
  status <- 200
  local_mocked_bindings(
    req_perform = function(req, ...) {
      httr2::response(
        status_code = status,
        headers = list(`Content-Type` = "application/json"),
        body = charToRaw('{"access_token":"EDL-abc"}')
      )
    },
    .package = "httr2"
  )
  expect_equal(.fetch_earthdata_token("u", "p"), "EDL-abc")
  status <- 401
  expect_error(.fetch_earthdata_token("u", "p"), "authentication failed")
  status <- 500
  expect_error(.fetch_earthdata_token("u", "p"), "HTTP 500")
})

test_that("earthdata_token falls back to username and password", {
  local_mocked_bindings(.fetch_earthdata_token = function(u, p) paste(u, p))
  withr::with_envvar(
    c(EARTHDATA_TOKEN = "", EARTHDATA_USERNAME = "u", EARTHDATA_PASSWORD = "p"),
    expect_equal(earthdata_token(), "u p")
  )
})
