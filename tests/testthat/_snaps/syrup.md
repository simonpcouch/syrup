# syrup does basic type checks

    Code
      syrup(1, interval = "boop")
    Condition
      Error in `syrup()`:
      ! `interval` must be a single, finite numeric.

---

    Code
      syrup(1, peak = "no")
    Condition
      Error in `syrup()`:
      ! `peak` must be `TRUE` or `FALSE`.

---

    Code
      syrup(1, env = "schmenv")
    Condition
      Error in `syrup()`:
      ! `env` must be an environment.

# syrup warns with only one ID

    ! `expr` evaluated fully before syrup could take a snapshot of memory usage.
    * Results likely represent memory usage before `expr` was evaluated.

