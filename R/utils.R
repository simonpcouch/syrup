# a reinterpretation of ps() that returns all available memory
# information and doesn't convert to tibble when returning
ps_r_processes <- function(id) {
  # can have no unstated dependencies in the separate process, so inline where needed
  fallback <- function(expr, alternative) {
    tryCatch(
      expr,
      error = function(e) alternative
    )
  }
  if_null <- function(x, y) {if (rlang::is_null(x)) y else x}

  pids <- ps::ps_pids()
  pids <- pids[pids != ps::ps_pid()]

  processes <- purrr::map(pids, function(p) {
    tryCatch(ps::ps_handle(p), error = function(e) NULL)
  })
  processes <- processes[!purrr::map_lgl(processes, is.null)]
  nm <- purrr::map_chr(processes, function(p) fallback(ps::ps_name(p), NA_character_))

  # retain only R-ish processes
  r_ish <- nm == "R" | grepl("rsession", nm)

  processes <- processes[r_ish]
  nm <- nm[r_ish]

  pd <- purrr::map_int(processes, function(p) fallback(ps::ps_pid(p), NA_integer_))
  pp <- purrr::map_int(processes, function(p) fallback(ps::ps_ppid(p), NA_integer_))
  mem <- purrr::map(processes, function(p) fallback(ps::ps_memory_info(p), NULL))
  rss <- purrr::map_dbl(mem, function(x) if_null(fallback(x[["rss"]], NULL), NA_real_))
  vms <- purrr::map_dbl(mem, function(x) if_null(fallback(x[["vms"]], NULL),NA_real_))

  rss <- bench::bench_bytes(rss)
  vms <- bench::bench_bytes(vms)

  # todo: include status / filter out zombies?
  tibble::new_tibble(
    list(
      id = rep(id, length(pd)),
      time = rep(Sys.time(), length(pd)),
      pid = pd, ppid = pp, name = nm, rss = rss, vms = vms
    )
  )
}
