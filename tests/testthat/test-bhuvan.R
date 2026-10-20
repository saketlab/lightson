# all network calls mocked; live checks are in test-live.R

fake_stats <- data.frame(
  state = c("BIHAR", "TAMILNADU"),
  avg_2023 = c("1.5", "3.0"),
  avg_2024 = c("2.0", "4.0"),
  stringsAsFactors = FALSE
)

test_that(".bhuvan_wide_to_long reshapes avg_YYYY columns", {
  df <- .bhuvan_wide_to_long(fake_stats)
  expect_named(df, c("state", "year", "mean_radiance"))
  expect_equal(nrow(df), 4L)
  expect_type(df$year, "integer")
  expect_equal(df$state[1:2], c("Bihar", "Tamil Nadu"))
  expect_equal(df$mean_radiance, c(1.5, 3, 2, 4))
  expect_null(.bhuvan_wide_to_long(list()))
})

test_that("bhuvan_stats warns across the collection break", {
  local_mocked_bindings(.bhuvan_get = function(endpoint, query = list()) fake_stats)
  expect_warning(df <- bhuvan_stats(), "collection break")
  expect_equal(sort(unique(df$year)), c(2023L, 2024L))
})

test_that("bhuvan_stats filters years and upper-cases the state query", {
  seen <- NULL
  local_mocked_bindings(.bhuvan_get = function(endpoint, query = list()) {
    seen <<- list(endpoint = endpoint, query = query)
    fake_stats[1, ]
  })
  expect_silent(df <- bhuvan_stats(years = 2023, state = "bihar"))
  expect_equal(seen$endpoint, "getStats.php")
  expect_equal(seen$query$state, "BIHAR")
  expect_equal(df$year, 2023L)
})

test_that("bhuvan_stats returns NULL when the API is unreachable", {
  local_mocked_bindings(.bhuvan_get = function(...) NULL)
  expect_null(bhuvan_stats())
})

test_that(".bhuvan_get returns NULL with a message on network failure", {
  local_mocked_bindings(
    req_perform = function(...) stop("Could not resolve host"),
    .package = "httr2"
  )
  expect_message(expect_null(.bhuvan_get("getIndiaStats.php")), "request failed")
})

# real tiles flag 0 as nodata
fake_wms_tile <- function() {
  path <- tempfile(fileext = ".tif")
  terra::writeRaster(make_legend_raster(), path, datatype = "INT1U", NAflag = 0)
  bytes <- readBin(path, "raw", file.size(path))
  unlink(path)
  bytes
}

test_that(".bhuvan_wms_fetch keeps pure black and red pixels", {
  bytes <- fake_wms_tile()
  local_mocked_bindings(
    req_perform = function(req, ...) httr2::response(status_code = 200, body = bytes),
    .package = "httr2"
  )
  bbox <- c(xmin = 77, xmax = 78, ymin = 28, ymax = 29)
  r <- .bhuvan_wms_fetch(bbox, 2020, 2, 2)
  expect_equal(terra::nlyr(r), 3L)
  expect_false(anyNA(terra::values(r)))
  expect_equal(terra::values(.rgb_to_radiance(r))[, 1], .bhuvan_classes$radiance)
})

test_that(".bhuvan_wms_fetch returns NULL for a non-GeoTIFF body", {
  local_mocked_bindings(
    req_perform = function(req, ...) httr2::response(status_code = 200, body = charToRaw("<html>")),
    .package = "httr2"
  )
  bbox <- c(xmin = 77, xmax = 78, ymin = 28, ymax = 29)
  expect_message(expect_null(.bhuvan_wms_fetch(bbox, 2020, 2, 2)), "Failed to parse")
})

test_that("bhuvan_raster converts, pads, caches and names by year", {
  cache <- local_lightson_cache()
  calls <- 0
  seen_bbox <- NULL
  local_mocked_bindings(
    .bhuvan_wms_fetch = function(bbox, year, width, height) {
      calls <<- calls + 1
      seen_bbox <<- bbox
      make_legend_raster(xmin = 68, xmax = 78, ymin = 8, ymax = 18)
    }
  )
  poly <- make_polygons()[1, ]

  out <- suppressMessages(bhuvan_raster(poly, 2020:2021, bbox_pad = c(0, 0, 0, 1)))
  expect_named(out, c("2020", "2021"))
  expect_equal(calls, 2)
  expect_equal(seen_bbox[["ymax"]], 19)
  expect_equal(sort(terra::values(out[["2020"]])[, 1]), .bhuvan_classes$radiance)
  expect_length(list.files(cache, "^bhuvan_v2_.*\\.tif$"), 2L)

  expect_message(bhuvan_raster(poly, 2020, bbox_pad = c(0, 0, 0, 1)), "Using cached")
  expect_equal(calls, 2)
})

test_that("bhuvan_raster errors when any year fails", {
  local_lightson_cache()
  local_mocked_bindings(.bhuvan_wms_fetch = function(...) NULL)
  expect_error(
    suppressMessages(bhuvan_raster(make_polygons()[1, ], 2020)),
    "failed for year\\(s\\): 2020"
  )
})
