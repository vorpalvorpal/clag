# Finding 22 (dev/open-findings.md): on Linux, R's start-up script puts the system library folder
# on LD_LIBRARY_PATH, so Julia started inside R loaded the system libunwind, which segfaulted R the
# first time Julia recorded the backtrace of an exception. weft loads Julia's own first
# (jl_preload_unwind()).

test_that("finding 22: Julia in R uses its own libunwind, and an exception caught in Julia does not end R", {
  skip_on_os(c("windows", "mac", "solaris"))
  skip_if_no_julia()
  jl_set("t_f22_r = try; error(\"f22\"); catch e; sprint(showerror, e); end")
  expect_identical(JuliaCall::julia_eval("t_f22_r"), "f22")
  maps <- readLines("/proc/self/maps", warn = FALSE)
  libs <- unique(sub("^.* ", "", grep("libunwind", maps, value = TRUE, fixed = TRUE)))
  bindir <- JuliaCall::julia_eval("Sys.BINDIR")
  ours <- normalizePath(file.path(bindir, "..", "lib", "julia"))
  expect_true(length(libs) > 0L)
  expect_true(all(startsWith(libs, ours)), label = paste(libs, collapse = ", "))
})

test_that("finding 22: with a Julia folder that does not exist, nothing is found and nothing fails", {
  expect_no_error(weft:::jl_preload_unwind("/no/such/julia/bin"))
  expect_null(weft:::jl_unwind_path("/no/such/julia/bin"))
})

test_that("finding 22: a child that may start Julia gets LD_LIBRARY_PATH without the system's library folders, on Linux", {
  skip_on_os(c("windows", "mac", "solaris"))
  x <- "/opt/R/4.6.2/lib/R/lib:/usr/local/lib:/usr/lib/x86_64-linux-gnu:/usr/lib/jvm/jdk/lib/server"
  expect_identical(weft:::julia_child_env(x),
                   c(LD_LIBRARY_PATH = "/opt/R/4.6.2/lib/R/lib:/usr/local/lib:/usr/lib/jvm/jdk/lib/server"))
  expect_identical(weft:::julia_child_env("/lib:/usr/lib64:/lib/aarch64-linux-gnu/:/opt/x/lib"),
                   c(LD_LIBRARY_PATH = "/opt/x/lib"))
  expect_identical(weft:::julia_child_env("/opt/R/lib"), character())
  expect_identical(weft:::julia_child_env(""), character())
})
