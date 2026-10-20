test_that(".bbox_to_viirs_tiles maps a bbox to the 10-degree sinusoidal grid", {
  tiles <- .bbox_to_viirs_tiles(c(xmin = 68, xmax = 98, ymin = 8, ymax = 38))
  names <- vapply(tiles, function(x) sprintf("h%02dv%02d", x$h, x$v), character(1))
  expect_length(names, 16L)
  expect_true(all(c("h24v05", "h27v08") %in% names))
  one <- .bbox_to_viirs_tiles(c(xmin = 77.1, xmax = 77.3, ymin = 28.5, ymax = 28.7))
  expect_equal(one, list(list(h = 25L, v = 6L)), ignore_attr = TRUE)
})

test_that("ntl_download picks matching tiles, mosaics, crops and caches", {
  local_lightson_cache()
  fetched <- character()
  local_mocked_bindings(
    .laads_csv_listing = function(product_id, acquisition) {
      data.frame(name = c(
        "VNP46A4.A2020001.h25v06.002.h5",
        "VNP46A4.A2020001.h26v06.002.h5",
        "VNP46A4.A2020001.h10v04.002.h5"
      ))
    },
    .download_viirs_tile = function(fname, product_id, acquisition, token, quality) {
      fetched <<- c(fetched, fname)
      xmin <- if (grepl("h25", fname)) 70 else 80
      make_raster(xmin = xmin, xmax = xmin + 10, ymin = 20, ymax = 30, vals = 5)
    }
  )
  region <- make_raster(xmin = 75, xmax = 85, ymin = 22, ymax = 28)

  out <- suppressMessages(ntl_download(region, 2020, token = "x"))
  expect_named(out, "2020")
  expect_setequal(basename(fetched), c(
    "VNP46A4.A2020001.h25v06.002.h5", "VNP46A4.A2020001.h26v06.002.h5"
  ))
  expect_equal(as.vector(terra::ext(out[["2020"]])), c(xmin = 75, xmax = 85, ymin = 22, ymax = 28),
    tolerance = 1
  )
  expect_equal(attr(out[["2020"]], "lightson_product"), "VNP46A4")
  expect_equal(attr(out[["2020"]], "lightson_cadence"), "annual")

  fetched <- character()
  out2 <- ntl_download(region, 2020, token = "x")
  expect_length(fetched, 0L)
  expect_equal(attr(out2[["2020"]], "lightson_units"), "nW/cm^2/sr")
})

test_that("ntl_download drops periods with no listing or no tiles", {
  local_lightson_cache()
  local_mocked_bindings(
    .laads_csv_listing = function(product_id, acquisition) {
      if (format(acquisition, "%Y") == "2020") NULL else data.frame(name = "VNP46A4.A2021001.h00v00.002.h5")
    }
  )
  region <- make_raster(xmin = 75, xmax = 85, ymin = 22, ymax = 28)
  expect_message(out <- ntl_download(region, 2020:2021, token = "x"), "No VNP46A4 tiles")
  expect_length(out, 0L)
})

test_that(".download_viirs_tile rejects HTML login pages", {
  local_mocked_bindings(
    req_perform = function(req, ...) {
      httr2::response(status_code = 200, body = charToRaw("<!DOCTYPE html><html></html>"))
    },
    .package = "httr2"
  )
  expect_message(
    expect_null(.download_viirs_tile("f.h5", "VNP46A4", as.Date("2020-01-01"), "tok", "high")),
    "token invalid"
  )
})
