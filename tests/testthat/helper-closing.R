# Helpers for the closing review tests (dev/review-closing.md). ASCII only.
if (!exists("e1_pipe")) source(Filter(file.exists, c(testthat::test_path("helper-2e1.R"), testthat::test_path("..", "helper-2e1.R")))[[1]])
if (!exists("i2_run")) source(Filter(file.exists, c(testthat::test_path("helper-2i.R"), testthat::test_path("..", "helper-2i.R")))[[1]])

cl_need_pipe <- function() {
  testthat::skip_if_not_installed("targets")
  testthat::skip_on_cran()
}

# a project folder `reports/` (the document's) beside `store-root/` (a plain pipeline, built)
cl_two_stores <- function() {
  proj <- e1_tmp()
  sub <- file.path(proj, "reports")
  other <- file.path(proj, "store-root")
  dir.create(sub)
  dir.create(other)
  e1_plain_dir(dir = other)
  list(sub = sub, other = other)
}

# a render of `lines` in `dir` where the setup chunk holds `E1_LIB` and any `code`
cl_render <- function(lines, dir, code = NULL, ...) {
  d2_run(lines, dir = dir, code = c(E1_LIB, code), ...)
}

# the unit "database" is session-global: clear what a test registered, now and when it ends
cl_units_clean <- function(env = parent.frame()) {
  clean <- function() {
    ns <- asNamespace("weft")
    if (exists("units_reset", ns, inherits = FALSE)) try(get("units_reset", ns)(), silent = TRUE)
  }
  clean()
  withr::defer(clean(), envir = env)
}

# a make, a definition-only edit, and a value edit of a report pipeline (as report_seq in test-review-2e1.R)
cl_report_seq <- function(key, script, files, edit_vals = list(a = 1, b = 9)) e1_memo(key, function() {
  cl_need_pipe()
  d <- e1_pipe(script, files = files)
  out <- list(dir = d, err = e1_try_make(d))
  if (!is.null(out$err)) return(out)
  e1_dict(d, edit_vals, list(a = "A new definition."))
  out$err3 <- e1_try_make(d)
  out$after_val <- withr::with_dir(d, e1_built())
  out
})
