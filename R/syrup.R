#' Memory and CPU Usage Information for Parallel R Code
#'
#' @description
#' This function is a wrapper around the system command `ps` that can
#' be used to benchmark (peak) memory and CPU usage of parallel R code.
#' By taking snapshots the memory usage of R processes at a regular `interval`,
#' the function dynamically builds up a profile of their usage of system
#' resources.
#'
#' @param expr An expression.
#' @param interval The interval at which to take snapshots of respirce usage.
#' In practice, there's an overhead on top of each of these intervals.
#' @param peak Whether to return rows for only the "peak" memory usage.
#' Interpreted as the `id` with the maximum `rss` sum. Defaults to `FALSE`,
#' but may be helpful to set `peak = TRUE` for potentially very long-running
#' processes so that the tibble doesn't grow too large.
#' @param env The environment to evaluate `expr` in.
#'
#' @returns A tibble with columns `id` and `time` and a number of columns from
#' [ps::ps()] output describing memory and CPU usage. Notably, the process ID
#' `pid`, parent process ID `ppid`, percent CPU usage, and resident set size
#' `rss` (a measure of memory usage).
#'
#' @details
#' While much of the verbiage in the package assumes that the supplied
#' expression will be distributed across CPU cores, there's nothing specific
#' about this package that necessitates the expression provided to `syrup()` is
#' run in parallel. Said another way, `syrup()` will work just fine
#' with "normal," sequentially-run R code (as in the examples). That said,
#' there are many better, more fine-grained tools for the job in the case of
#' sequential R code, such as [Rprofmem()], the
#' [profmem](https://CRAN.R-project.org/package=profmem)
#' package, the [bench][bench::mark()] package, and packages in
#' the [R-prof](https://github.com/r-prof) GitHub organization.
#'
#' Loosely, the function works by:
#'
#' * Setting up another R process (call it `sesh`) that queries system
#'   information using [ps::ps()] at a regular interval,
#' * Evaluating the supplied expression,
#' * Reading the queried system information back into the main process from `sesh`,
#' * Closing `sesh`, and then
#' * Returning the queried system information.
#'
#' Note that information on the R process `sesh` is filtered out from the results
#' automatically.
#'
#' @examplesIf !on_cran()
#' # pass any expression to syrup. first, sequentially:
#' res_syrup <- syrup({res_output <- Sys.sleep(1)})
#'
#' res_syrup
#'
#' # to snapshot memory and CPU information more (or less) often, set `interval`
#' syrup(Sys.sleep(1), interval = .01)
#'
#' # use `peak = TRUE` to return only the snapshot with
#' # the highest memory usage (as `sum(rss)`)
#' syrup(Sys.sleep(1), interval = .01, peak = TRUE)
#'
#' # results from syrup are more---or maybe only---useful when
#' # computations are evaluated in parallel. see package README
#' # for an example.
#' @export
syrup <- function(expr, interval = .5, peak = FALSE, env = caller_env()) {
  expr <- substitute(expr)
  if (!is_double(interval, n = 1, finite = TRUE)) {
    abort("`interval` must be a single, finite numeric.")
  }
  if (!is_bool(peak)) {
    abort("`peak` must be `TRUE` or `FALSE`.")
  }
  if (!is_environment(env)) {
    abort("`env` must be an environment.")
  }

  # create a new temporary R session `sesh`
  sesh <- callr::r_session$new()
  withr::defer(sesh$close())

  # communicate with `sesh` through existence of a tempfile:
  keep_going_file <- tempfile()
  file.create(keep_going_file)
  withr::defer(if (file.exists(keep_going_file)) file.remove(keep_going_file))

  # regularly take snapshots of memory usage of R sessions
  sesh$call(
    function(interval, keep_going_file, ps_r_processes, exclude, peak) {
      id <- 1
      res <- ps_r_processes(id = id)
      current_peak <- sum(res$rss, na.rm = TRUE)

      while (file.exists(keep_going_file)) {
        id <- id + 1
        Sys.sleep(interval)
        new_res <- ps_r_processes(id = id)
        if (peak) {
          new_peak <- sum(new_res$rss, na.rm = TRUE)
          if (new_peak > current_peak) {
            current_peak <- new_peak
            res <- new_res
          }
        } else {
          res <- vctrs::vec_rbind(res, new_res)
        }
      }

      res
    },
    args = list(
      interval = interval,
      keep_going_file = keep_going_file,
      ps_r_processes = ps_r_processes,
      peak = peak
    )
  )

  # run the expression
  eval(expr, envir = env)

  # tell `sesh` to stop taking snapshots
  file.remove(keep_going_file)
  Sys.sleep(interval + .2)

  res <- retrieve_results(sesh)

  withr::deferred_clear()

  if (identical(res$id[length(res$id)], 1) && !isTRUE(peak)) {
    rlang::warn(c(
      "!" = "`expr` evaluated fully before syrup could take a snapshot of memory usage.",
      "*" = "Results likely represent memory usage before `expr` was evaluated."
    ))
  }

  res <- mutate_pct_cpu(res)

  res
}
