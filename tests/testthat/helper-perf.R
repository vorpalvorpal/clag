# Timing in tests. Wall-clock bounds fail on a loaded machine, so a performance test compares the
# processor time of the same work at two sizes (or against a trivial reference) in one session, and
# asserts a ratio. Processor time (user + system of this process, and of its children when asked)
# does not grow when another process is busy.

# Processor time, in seconds, taken by `expr`.
cpu_time <- function(expr, children = FALSE) {
  tm <- system.time(expr)
  out <- tm[["user.self"]] + tm[["sys.self"]]
  if (children) out <- out + tm[["user.child"]] + tm[["sys.child"]]
  out
}

# The least processor time of `n` runs of `f()`: a single run is noisy, the least of a few is not.
cpu_time_min <- function(f, n = 3L, children = FALSE) {
  min(vapply(seq_len(n), function(i) cpu_time(f(), children = children), 0))
}

# The ratio of the least processor time of `work(large)` to that of `work(small)`, each the least of
# `n` runs, after one untimed run of the small size to warm caches. Linear work gives
# large / small; quadratic work gives its square. `work` takes the size and does the work.
cpu_ratio <- function(work, small, large, n = 3L, children = FALSE) {
  work(small)
  t_small <- cpu_time_min(function() work(small), n, children)
  t_large <- cpu_time_min(function() work(large), n, children)
  t_large / max(t_small, 0.01)
}
