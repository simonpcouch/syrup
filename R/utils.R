# a wrapper around ps::ps() that returns info only on live R-ish processes
ps_r_processes <- function(id) {
  ps <- ps::ps()

  ps <-
    vctrs::vec_slice(
      ps,
      (ps$name %in% c("R", "ark", "R.exe") | grepl("rsession", ps$name)) &
      ps$status != "zombie" &
      ps$pid != ps::ps_pid()
    )

  ps$rss <- bench::bench_bytes(ps$rss)
  ps$vms <- bench::bench_bytes(ps$vms)

  vctrs::vec_cbind(
    tibble::new_tibble(
      list(id = rep(id, nrow(ps)), time  = rep(Sys.time(), nrow(ps)))
    ),
    ps[!colnames(ps) %in% c("username", "status", "created", "ps_handle")]
  )
}

# x is a data frame of row-binded ps_r_processes() outputs
mutate_pct_cpu <- function(x) {
  x <- dplyr::mutate(
    x,
    pct_cpu = calculate_pct_cpu(time, user, system),
    .after = name,
    .by = pid
  )
  x <- dplyr::select(x, -c(user, system))
}

# time, user, and system are vectors of repeated measures from a given pid
calculate_pct_cpu <- function(time, user, system) {
  intervals <- as.numeric(diff(time))
  user_diffs <- diff(user)
  system_diffs <- diff(system)

  c(NA_real_, (user_diffs + system_diffs) * 100 / intervals)
}

# grab the result from sesh and close it.
# may be a slightly longer delay before sesh is able to return, so iteratively
# query until we get a result back.
retrieve_results <- function(sesh, call = caller_env()) {
  sesh_res <- sesh$read()
  cnt <- 1
  while (is.null(sesh_res) & cnt < 10) {
    Sys.sleep(.2)
    sesh_res <- sesh$read()
    cnt <- cnt + 1
  }

  sesh$close()

  if (cnt == 10) {
    rlang::abort(
      "Unable to retrieve resource usage results from the temporary session.",
      .internal = TRUE,
      call = call
    )
  }

  sesh_res$result
}

is_unix <- function() {
  identical(.Platform$OS.type, "unix")
}

# from rstudio/reticulate
is_fedora <- function() {
  if (is_unix() && file.exists("/etc/os-release")) {
    os_info <- readLines("/etc/os-release")
    any(grepl("Fedora", os_info))
  } else {
    FALSE
  }
}
