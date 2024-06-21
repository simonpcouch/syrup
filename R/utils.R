# a wrapper around ps::ps() that returns info only on live R-ish processes
ps_r_processes <- function(id) {
  ps <- ps::ps()

  ps <-
    vctrs::vec_slice(
      ps,
      (ps$name == "R" | grepl("rsession", ps$name)) &
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

  c(NA_real_, (user_diffs + system_diffs) / intervals)
}
