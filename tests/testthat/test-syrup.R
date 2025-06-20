skip_if_not(ps::ps_os_type()[["POSIX"]])
skip_on_cran()

test_that("syrup works", {
  set.seed(1)
  expect_no_error(
    res <- syrup(
      res_with_syrup <- Sys.sleep(1)
    )
  )

  set.seed(1)
  res_no_syrup <- Sys.sleep(1)

  expect_equal(res_with_syrup, res_no_syrup)

  expect_s3_class(res, "tbl_df")

  expect_named(res, c("id", "time", "pid", "ppid", "name", "pct_cpu", "rss", "vms"))
  expect_gte(nrow(res), 1)
  expect_equal(unique(res$id), 1:max(res$id, na.rm = TRUE))
  expect_type(res$pid, "integer")
  expect_true(ps::ps_pid() %in% res$pid)
  expect_type(res$ppid, "integer")
  expect_type(res$name, "character")
  expect_s3_class(res$rss, "bench_bytes")
  expect_s3_class(res$vms, "bench_bytes")
})

test_that("syrup(peak = TRUE) works", {
  expect_no_error(
    res <- syrup(
      Sys.sleep(1),
      peak = TRUE
    )
  )

  expect_s3_class(res, "tbl_df")
  expect_equal(length(unique(res$id)), 1)
})

test_that("syrup(interval) works", {
  # can't expect that nrow will grow strictly proportionally, as
  # the number of other processes running may change and there's some
  # overhead associated with the inter-process communication
  expect_no_error(
    res_01 <- syrup(
      Sys.sleep(1),
      interval = .01
    )
  )

  expect_no_error(
    res_1 <- syrup(
      Sys.sleep(1),
      interval = .1
    )
  )

  expect_s3_class(res_01, "tbl_df")
  expect_s3_class(res_1, "tbl_df")

  skip_on_cran()

  expect_true(length(unique(res_01$id)) > length(unique(res_1$id)))
})

test_that("syrup does basic type checks", {
  # the rlang type check standalone is probably overkill for this project,
  # but some simple type checks should still be helpful.
  expect_snapshot(error = TRUE, syrup(1, interval = "boop"))
  expect_snapshot(error = TRUE, syrup(1, peak = "no"))
  expect_snapshot(error = TRUE, syrup(1, env = "schmenv"))
})

test_that("syrup warns with only one ID", {
  skip_on_cran()

  expect_snapshot_warning(syrup(1))
})
