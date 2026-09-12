test_that("VIIRS acquisitions preserve backward-compatible annual names", {
  x <- .viirs_acquisitions("annual", c(2024, 2025), NULL)
  expect_named(x, c("2024", "2025"))
  expect_equal(x[[2]], as.Date("2025-01-01"))
})

test_that("monthly acquisitions expand years and normalise dates", {
  x <- .viirs_acquisitions("monthly", 2025, NULL)
  expect_length(x, 12)
  expect_named(x, sprintf("2025-%02d-01", 1:12))
  y <- .viirs_acquisitions("monthly", NULL, c("2025-03-20", "2025-03-01"))
  expect_named(y, "2025-03-01")
})

test_that("daily acquisitions require and validate dates", {
  expect_error(.viirs_acquisitions("daily", 2025, NULL), "dates")
  x <- .viirs_acquisitions("daily", NULL, c("2025-01-02", "2025-01-03"))
  expect_named(x, c("2025-01-02", "2025-01-03"))
})
