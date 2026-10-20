# Bhuvan is often blocked outside India, including GitHub runners
bhuvan_reachable <- local({
  ok <- NULL
  function() {
    if (is.null(ok)) ok <<- .probe_bhuvan()
    ok
  }
})

.probe_bhuvan <- function() {
  resp <- tryCatch(
    httr2::request(BHUVAN_NTL_BASE) |>
      httr2::req_method("HEAD") |>
      httr2::req_timeout(10) |>
      httr2::req_error(is_error = function(r) FALSE) |>
      httr2::req_perform(),
    error = function(e) NULL
  )
  !is.null(resp)
}

skip_if_no_bhuvan <- function() {
  skip_on_cran()
  skip_if_offline("bhuvan-app1.nrsc.gov.in")
  skip_if_not(bhuvan_reachable(), "Bhuvan unreachable from this host")
}

test_that("live: bhuvan_stats returns all states", {
  skip_if_no_bhuvan()
  df <- suppressMessages(bhuvan_stats(years = 2023))
  skip_if(is.null(df), "Bhuvan API returned nothing")
  expect_gt(length(unique(df$state)), 30L)
  expect_true(all(df$mean_radiance >= 0, na.rm = TRUE))
})

test_that("live: bhuvan_raster returns classed radiance for a small region", {
  skip_if_no_bhuvan()
  local_lightson_cache()
  delhi <- make_square(76.8, 77.4, 28.4, 28.9)
  r <- suppressMessages(bhuvan_raster(delhi, 2020, width = 128, height = 128))
  vals <- stats::na.omit(terra::values(r[["2020"]])[, 1])
  expect_gt(length(vals), 0L)
  expect_true(all(vals %in% .bhuvan_classes$radiance))
})

test_that("live: LAADS lists India tiles", {
  skip_on_cran()
  skip_if_offline("ladsweb.modaps.eosdis.nasa.gov")
  listing <- .laads_csv_listing("VNP46A4", as.Date("2020-01-01"))
  skip_if(is.null(listing), "LAADS listing unavailable")
  expect_true(any(grepl("h25v06", listing$name)))
})
