test_that("syrup warns with only one ID", {
  expect_snapshot_warning(syrup(1))
})
