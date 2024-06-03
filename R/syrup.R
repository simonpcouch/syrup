#' Memory Usage Information for Parallel R Code
#'
#' @description
#' This function is a wrapper around the system command `ps` that can
#' be used to benchmark (peak) memory usage of parallel R code.
#' By taking snapshots the memory usage of R processes at a regular `interval`,
#' the function dynamically builds up a  profile of their usage of system
#' resources.
#'
#' @param expr An expression.
#' @param interval The interval at which to take snapshots of memory usage.
#' In practice, there's an overhead on top of each of these intervals.
#' @param env The environment to evaluate `expr` in.
#'
#' @returns A tibble with column `id` and a number of columns from
#' `ps::ps()` output describing memory usage. Notably, the process ID `pid`,
#' parent process ID `ppid`, and resident set size `rss` (a measure of memory
#' usage).
#' @export
syrup <- function(expr, interval = .5, env = caller_env()) {
  expr <- substitute(expr)

  # create a new temporary R session `sesh`
  sesh <- callr::r_session$new()
  withr::defer(sesh$close())

  # communicate with `sesh` through a tempfile:
  keep_going_file <- tempfile()
  writeLines("TRUE", keep_going_file)

  # regularly take snapshots of memory usage of R sessions
  sesh$call(
    function(interval, keep_going_file, ps_r_processes, exclude) {
      keep_going <- readLines(keep_going_file)
      id <- 1
      res <- ps_r_processes(exclude = exclude, id = id)

      while (as.logical(keep_going)) {
        id <- id + 1
        Sys.sleep(interval)
        res <- vctrs::vec_rbind(res, ps_r_processes(exclude = exclude, id = id))
        keep_going <- readLines(keep_going_file)
      }

      res
    },
    args = list(
      interval = interval,
      keep_going_file = keep_going_file,
      ps_r_processes = ps_r_processes,
      exclude = sesh$get_pid()
    )
  )

  # run the expression
  eval(expr, envir = env)

  # tell `sesh` to stop taking snapshots
  writeLines("FALSE", keep_going_file)
  Sys.sleep(interval + .1)

  # grab the result from sesh and close it
  sesh_res <- sesh$read()
  sesh$close()

  withr::deferred_clear()

  # return the memory usage information
  sesh_res$result
}

