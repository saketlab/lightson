test_that("get_india_admin('state') reads the bundled GeoJSON offline", {
  local_mocked_bindings(.bhuvan_get = function(...) stop("network used"))
  states <- get_india_admin("state")
  expect_s3_class(states, "sf")
  expect_gt(nrow(states), 30L)
  expect_true("state_name" %in% names(states))
})

fake_geojson <- function() {
  jsonlite::fromJSON(
    '{"type":"FeatureCollection","features":[{"type":"Feature","properties":{"name":"X"},
      "geometry":{"type":"Polygon","coordinates":[[[77,28],[78,28],[78,29],[77,29],[77,28]]]}}]}',
    simplifyVector = TRUE
  )
}

test_that("get_india_admin(source = 'bhuvan') builds sf from API geometry", {
  local_mocked_bindings(.bhuvan_get = function(endpoint, query = list()) {
    switch(endpoint,
      getStates.php = list("BIHAR", "TAMILNADU"),
      geometryState.php = fake_geojson()
    )
  })
  country <- get_india_admin("country", source = "bhuvan")
  expect_s3_class(country, "sf")
  expect_equal(nrow(country), 1L)

  states <- get_india_admin("state", source = "bhuvan")
  expect_equal(states$state_name, c("Bihar", "Tamil Nadu"))
})

test_that("get_india_admin(source = 'bhuvan') returns NULL when offline", {
  local_mocked_bindings(.bhuvan_get = function(...) NULL)
  expect_null(get_india_admin("country", source = "bhuvan"))
  expect_null(get_india_admin("district", source = "bhuvan"))
})
