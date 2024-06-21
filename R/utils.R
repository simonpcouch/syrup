# a wrapper around ps::ps() that returns info only on live R-ish processes
ps_r_processes <- function(id) {
  ps <- ps::ps()

  ps <-
    vctrs::vec_slice(
      ps,
      (ps$name == "R" | grepl("rsession", ps$name)) & ps$status != "zombie"
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
