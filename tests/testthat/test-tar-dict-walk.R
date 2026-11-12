# Package 2e-1: tar_dict(), tar_dict_deps() and the walker (dev/design-2e.md P1-P9, P11).
# No tar_make() here. Written before the code. Made-up values only.

K <- c("a", "b")
reads <- function(code, envir = new.env(), keys = K) weft:::code_reads(code, envir, keys)

# a fresh folder holding a two-key dict.yml, made the working folder
two_key_dir <- function(env = parent.frame()) {
  d <- withr::local_tempdir(.local_envir = env)
  e1_dict(d)
  withr::local_dir(d, .local_envir = env)
  d
}

# ---- P9: the walker -------------------------------------------------------------------------

test_that("2e-1 P9: dict$a, dict$\"a\", dict[[\"b\"]] and dict[['b']] each name one key", {
  skip_if_not_installed("targets")
  expect_identical(reads(quote(dict$a))$keys, "a")
  expect_identical(reads(quote(dict$"a"))$keys, "a")
  expect_identical(reads(quote(dict[["b"]]))$keys, "b")
  expect_identical(reads(quote(dict[['b']]))$keys, "b")
  r <- reads(quote(dict$a + dict[["b"]] + dict$a))
  expect_identical(r$keys, c("a", "b"))
  expect_false(r$all)
  expect_length(r$unknown, 0L)
})

test_that("2e-1 P9: keys are sorted and unique", {
  skip_if_not_installed("targets")
  expect_identical(reads(quote({ dict$b; dict$a; dict$b }))$keys, c("a", "b"))
})

test_that("2e-1 P9: a computed index, dict as an argument, names(dict) and with(dict, ) each set `all`", {
  skip_if_not_installed("targets")
  for (code in list(quote(dict[[k]]), quote(f(dict)), quote(names(dict)), quote(with(dict, a + 1)),
                    quote(dict[...]))) {
    r <- reads(code)
    expect_true(r$all, label = deparse(code))
    expect_identical(r$keys, c("a", "b"), label = deparse(code))
  }
})

test_that("2e-1 P9: a key that dict.yml does not hold is `unknown`, with `all` or not", {
  skip_if_not_installed("targets")
  r <- reads(quote(dict$zz))
  expect_identical(r$unknown, "zz")
  expect_false(r$all)
  r2 <- reads(quote({ dict$zz; names(dict) }))
  expect_true(r2$all)
  expect_identical(r2$unknown, "zz")
  expect_identical(r2$keys, c("a", "b"))
})

test_that("2e-1 P9: a function in envir is followed, called or passed as an argument", {
  skip_if_not_installed("targets")
  env <- new.env()
  env$g <- function() dict$b
  expect_identical(reads(quote(g()), env)$keys, "b")
  expect_identical(reads(quote(lapply(1, g)), env)$keys, "b")
  expect_identical(reads(quote(g), env)$keys, "b")
})

test_that("2e-1 P9: a function's formals are walked too", {
  skip_if_not_installed("targets")
  env <- new.env()
  env$g <- function(x = dict$a) x
  expect_identical(reads(quote(g()), env)$keys, "a")
})

test_that("2e-1 P9: a recursive function terminates", {
  skip_if_not_installed("targets")
  env <- new.env()
  env$f <- function(n) if (n > 0) { dict$a; g(n - 1) }
  env$g <- function(n) { f(n); dict$a }
  r <- reads(quote(f(3)), env)
  expect_identical(r$keys, "a")
})

test_that("2e-1 P9: pkg::f and functions outside envir are not followed; stats::median(dict$a) reads a", {
  skip_if_not_installed("targets")
  env <- new.env()
  env$fun <- function() dict$b
  expect_length(reads(quote(pkg::fun()), env)$keys, 0L)
  expect_length(reads(quote(pkg:::fun()), env)$keys, 0L)
  expect_length(reads(quote(median(1)), env)$keys, 0L)
  expect_identical(reads(quote(stats::median(dict$a)))$keys, "a")
})

test_that("2e-1 P9: a function found only in a parent of envir is not followed (inherits = FALSE)", {
  skip_if_not_installed("targets")
  parent <- new.env()
  parent$g <- function() dict$b
  child <- new.env(parent = parent)
  expect_length(reads(quote(g()), child)$keys, 0L)
})

test_that("2e-1 P9: formulas, function literals and the inside of quote() are walked", {
  skip_if_not_installed("targets")
  expect_identical(reads(quote(quote(dict$a)))$keys, "a")
  expect_identical(reads(quote(~ dict$b))$keys, "b")
  expect_identical(reads(quote(sapply(1:3, function(i) i * dict$a)))$keys, "a")
})

test_that("2e-1 P9: a local variable named dict counts; dict_local does not", {
  skip_if_not_installed("targets")
  expect_identical(reads(quote({ dict <- list(a = 1); dict$a }))$keys, "a")
  expect_length(reads(quote(dict_local$a))$keys, 0L)
})

test_that("2e-1 P9: code may be a call, an expression vector or a character vector; unparsable code reads nothing", {
  skip_if_not_installed("targets")
  expect_identical(reads(expression(dict$a, dict$b))$keys, c("a", "b"))
  expect_identical(reads("dict$a")$keys, "a")
  expect_identical(reads(c("x <- 1", "y <- dict[['b']]"))$keys, "b")
  r <- reads("dict$$ (")
  expect_length(r$keys, 0L)
  expect_false(r$all)
  expect_length(r$unknown, 0L)
})

test_that("2e-1 P9: code that reads no key gives an empty result with the documented shape", {
  skip_if_not_installed("targets")
  r <- reads(quote(1 + 1))
  expect_named(r, c("keys", "all", "unknown", "targets"), ignore.order = TRUE)
  expect_type(r$keys, "character")
  expect_length(r$keys, 0L)
  expect_false(r$all)
  expect_s3_class(r$targets, "data.frame")
  expect_named(r$targets, c("name", "store"))
  expect_identical(nrow(r$targets), 0L)
})

# ---- P9: the targets a chunk reads ------------------------------------------------------------

test_that("2e-1 P9: tar_read(fit), targets::tar_read(fit), tar_load(c(a, b)) record the names with store NA", {
  skip_if_not_installed("targets")
  t1 <- reads(quote(tar_read(fit)))$targets
  expect_identical(t1$name, "fit")
  expect_true(is.na(t1$store))
  expect_identical(reads(quote(targets::tar_read(fit)))$targets$name, "fit")
  t3 <- reads(quote(tar_load(c(a, b))))$targets
  expect_setequal(t3$name, c("a", "b"))
  expect_true(all(is.na(t3$store)))
  expect_setequal(reads(quote(targets::tar_load(c(a, b))))$targets$name, c("a", "b"))
  expect_identical(reads(quote(tar_load(a)))$targets$name, "a")
})

test_that("2e-1 P9: the raw readers with literal strings record the names", {
  skip_if_not_installed("targets")
  expect_identical(reads(quote(tar_read_raw("x")))$targets$name, "x")
  expect_identical(reads(quote(tar_load_raw("x")))$targets$name, "x")
  expect_setequal(reads(quote(tar_load_raw(c("x", "y"))))$targets$name, c("x", "y"))
})

test_that("2e-1 P9: a literal store argument is kept", {
  skip_if_not_installed("targets")
  t <- reads(quote(tar_read(y, store = "../_targets")))$targets
  expect_identical(t$name, "y")
  expect_identical(t$store, "../_targets")
})

test_that("2e-1 P9: names that are not literal are not recorded", {
  skip_if_not_installed("targets")
  expect_identical(nrow(reads(quote(tar_read_raw(nm)))$targets), 0L)
  expect_identical(nrow(reads(quote(tar_load(starts_with("x"))))$targets), 0L)
})

# ---- P2-P4: tar_dict() ----------------------------------------------------------------------

test_that("2e-1 P4: tar_dict() returns a plain list of dict_file and one target per key, in file order", {
  skip_if_not_installed("targets")
  e1_local_dict()
  two_key_dir()
  out <- tar_dict("dict.yml")
  expect_identical(class(out), "list")
  expect_length(out, 3L)
  expect_identical(vapply(out, function(t) t$settings$name, ""), c("dict_file", "dict_a", "dict_b"))
  expect_true(all(vapply(out, inherits, NA, "tar_target")))
})

test_that("2e-1 P4: key targets follow the order of the file", {
  skip_if_not_installed("targets")
  e1_local_dict()
  d <- withr::local_tempdir()
  e1_dict(d, vals = list(b = 2, a = 1))
  withr::local_dir(d)
  expect_identical(vapply(tar_dict("dict.yml"), function(t) t$settings$name, ""),
                   c("dict_file", "dict_b", "dict_a"))
})

test_that("2e-1 P4: dict_file is a file target for the path as given", {
  skip_if_not_installed("targets")
  e1_local_dict()
  two_key_dir()
  out <- tar_dict("dict.yml")
  expect_identical(out[[1]]$settings$format, "file")
  expect_identical(out[[2]]$settings$format, targets::tar_option_get("format"))
  expect_true(grepl("dict.yml", paste(deparse(out[[1]]$command$expr), collapse = ""), fixed = TRUE))
})

test_that("2e-1 P4: each key target's command reads that key of the dictionary in dict_file", {
  skip_if_not_installed("targets")
  e1_local_dict()
  two_key_dir()
  out <- tar_dict("dict.yml")
  txt <- paste(deparse(out[[3]]$command$expr), collapse = "")
  expect_true(grepl("read_dict", txt, fixed = TRUE))
  expect_true(grepl("dict_file", txt, fixed = TRUE))
  expect_true(grepl("\"b\"", txt, fixed = TRUE))
})

test_that("2e-1 P3: the dictionary is attached as `dict` in `weft:dict` at position 2; a second call leaves one", {
  skip_if_not_installed("targets")
  e1_local_dict()
  two_key_dir()
  tar_dict("dict.yml")
  expect_true("weft:dict" %in% search())
  expect_identical(search()[2], "weft:dict")
  expect_equal(get("dict", "weft:dict")$a, 1)
  tar_dict("dict.yml")
  expect_identical(sum(search() == "weft:dict"), 1L)
  expect_identical(search()[2], "weft:dict")
})

test_that("2e-1 P3: a second call holds the new values", {
  skip_if_not_installed("targets")
  e1_local_dict()
  d <- two_key_dir()
  tar_dict("dict.yml")
  e1_dict(d, vals = list(a = 7, b = 2))
  tar_dict("dict.yml")
  expect_equal(get("dict", "weft:dict")$a, 7)
})

test_that("2e-1 P4: an empty dict.yml gives dict_file alone", {
  skip_if_not_installed("targets")
  e1_local_dict()
  d <- withr::local_tempdir()
  writeLines("", file.path(d, "dict.yml"))
  withr::local_dir(d)
  out <- tar_dict("dict.yml")
  expect_length(out, 1L)
  expect_identical(out[[1]]$settings$name, "dict_file")
})

test_that("2e-1 P2: a bad dict.yml raises weft_dict_error as it is", {
  skip_if_not_installed("targets")
  e1_local_dict()
  d <- withr::local_tempdir()
  writeLines("a: 5", file.path(d, "dict.yml"))
  withr::local_dir(d)
  e <- e1_err(tar_dict("dict.yml"))
  expect_s3_class(e, "weft_dict_error")
})

test_that("2e-1 P2: a path that is not a file is weft_pipeline_error", {
  skip_if_not_installed("targets")
  e1_local_dict()
  d <- withr::local_tempdir()
  withr::local_dir(d)
  e <- e1_err(tar_dict("missing.yml"))
  expect_s3_class(e, "weft_pipeline_error")
  expect_s3_class(e, "weft_error")
  expect_s3_class(e1_err(tar_dict(c("a.yml", "b.yml"))), "weft_pipeline_error")
  expect_s3_class(e1_err(tar_dict(d)), "weft_pipeline_error")
})

test_that("2e-1 P5: tar_dict() refuses a global `dict` and names the cure", {
  skip_if_not_installed("targets")
  e1_local_dict()
  two_key_dir()
  assign("dict", list(a = 1), envir = globalenv())
  withr::defer(rm("dict", envir = globalenv()))
  e <- e1_err(tar_dict("dict.yml"))
  expect_s3_class(e, "weft_pipeline_error")
  msg <- e1_flat(e)
  expect_true(grepl("is an object in the pipeline's environment", msg, fixed = TRUE))
  expect_true(grepl("rule 4.6.3", msg, fixed = TRUE))
  expect_false("weft:dict" %in% search())
})

# ---- P6-P8: tar_dict_deps() ------------------------------------------------------------------

test_that("2e-1 P7: a target reading dict$a gains dict_a and keeps its other dependencies", {
  skip_if_not_installed("targets")
  two_key_dir()
  t1 <- targets::tar_target(t1, dict$a + y + 1)
  before <- t1$deps
  res <- tar_dict_deps(t1)
  expect_true("dict_a" %in% t1$deps)
  expect_true(all(before %in% t1$deps))
  expect_false("dict_b" %in% t1$deps)
  expect_true(is.character(t1$deps))
  expect_true("y" %in% t1$deps)
  expect_true(identical(res, t1) || identical(e1_targets(res)[[1]], t1))
})

test_that("2e-1 P7: a target that reads no key is left alone", {
  skip_if_not_installed("targets")
  two_key_dir()
  t0 <- targets::tar_target(t0, 1 + z)
  before <- t0$deps
  tar_dict_deps(list(t0))
  expect_identical(t0$deps, before)
})

test_that("2e-1 P7: a function in the pipeline's environment is followed; names(dict) adds every key", {
  skip_if_not_installed("targets")
  two_key_dir()
  env <- new.env()
  env$f <- function() dict$b + 1
  old <- targets::tar_option_get("envir")
  targets::tar_option_set(envir = env)
  withr::defer(targets::tar_option_reset())
  t1 <- targets::tar_target(t1, f())
  t2 <- targets::tar_target(t2, length(names(dict)))
  tar_dict_deps(list(t1, t2))
  expect_true("dict_b" %in% t1$deps)
  expect_false("dict_a" %in% t1$deps)
  expect_true(all(c("dict_a", "dict_b") %in% t2$deps))
})

test_that("2e-1 P7: the structure of a nested list is kept, and every target in it is changed", {
  skip_if_not_installed("targets")
  two_key_dir()
  t1 <- targets::tar_target(t1, dict$a)
  t2 <- targets::tar_target(t2, dict$b)
  t3 <- targets::tar_target(t3, dict$a + dict$b)
  x <- list(t1, list(t2, list(t3)))
  res <- tar_dict_deps(x)
  expect_length(res, 2L)
  expect_length(res[[2]], 2L)
  expect_length(res[[2]][[2]], 1L)
  expect_true("dict_a" %in% t1$deps)
  expect_true("dict_b" %in% t2$deps)
  expect_true(all(c("dict_a", "dict_b") %in% t3$deps))
})

test_that("2e-1 P7: the targets of tar_dict() are left alone", {
  skip_if_not_installed("targets")
  e1_local_dict()
  two_key_dir()
  dt <- tar_dict("dict.yml")
  before <- lapply(dt, function(t) t$deps)
  tar_dict_deps(dt)
  expect_identical(lapply(dt, function(t) t$deps), before)
})

test_that("2e-1 P6: anything that is not a target or a list of targets is weft_pipeline_error", {
  skip_if_not_installed("targets")
  two_key_dir()
  expect_s3_class(e1_err(tar_dict_deps(1)), "weft_pipeline_error")
  expect_s3_class(e1_err(tar_dict_deps("t1")), "weft_pipeline_error")
  expect_s3_class(e1_err(tar_dict_deps(list(targets::tar_target(t1, 1), 2))), "weft_pipeline_error")
})

test_that("2e-1 P6: a path that is not a file is weft_pipeline_error; a bad dictionary is weft_dict_error", {
  skip_if_not_installed("targets")
  d <- withr::local_tempdir()
  withr::local_dir(d)
  t1 <- targets::tar_target(t1, 1)
  expect_s3_class(e1_err(tar_dict_deps(t1, "nope.yml")), "weft_pipeline_error")
  writeLines("a: 5", file.path(d, "bad.yml"))
  expect_s3_class(e1_err(tar_dict_deps(t1, "bad.yml")), "weft_dict_error")
})

test_that("2e-1 P8: unknown keys over every target are one error naming each target and key, with a suggestion", {
  skip_if_not_installed("targets")
  two_key_dir()
  t1 <- targets::tar_target(t1, dict$zz)
  t2 <- targets::tar_target(t2, dict$aa)
  e <- e1_err(tar_dict_deps(list(t1, t2)))
  expect_s3_class(e, "weft_pipeline_error")
  msg <- e1_flat(e)
  expect_true(grepl("2 unknown key(s) read by the pipeline", msg, fixed = TRUE))
  expect_true(grepl("dict.yml", msg, fixed = TRUE))
  expect_true(grepl("`t1` reads `dict$zz`, which dict.yml does not hold (rule 4.6.4)", msg, fixed = TRUE))
  expect_true(grepl("`t2` reads `dict$aa`, which dict.yml does not hold (rule 4.6.4)", msg, fixed = TRUE))
  expect_true(grepl("Did you mean `a`?", msg, fixed = TRUE))
  # `zz` is two edits from both keys: no suggestion for it
  expect_identical(lengths(regmatches(msg, gregexpr("Did you mean", msg, fixed = TRUE))), 1L)
})

test_that("2e-1 P8: an unknown key makes the error even when `all` is set", {
  skip_if_not_installed("targets")
  two_key_dir()
  t1 <- targets::tar_target(t1, {dict$zz; names(dict)})
  e <- e1_err(tar_dict_deps(t1))
  expect_s3_class(e, "weft_pipeline_error")
  expect_true(grepl("1 unknown key(s)", e1_flat(e), fixed = TRUE))
})

test_that("2e-1 P5: tar_dict_deps() refuses a global `dict` too, with the same advice", {
  skip_if_not_installed("targets")
  two_key_dir()
  assign("dict", list(a = 1), envir = globalenv())
  withr::defer(rm("dict", envir = globalenv()))
  e <- e1_err(tar_dict_deps(targets::tar_target(t1, dict$a)))
  expect_s3_class(e, "weft_pipeline_error")
  msg <- e1_flat(e)
  expect_true(grepl("is an object in the pipeline's environment", msg, fixed = TRUE))
  expect_true(grepl("Remove `dict <- ...` from _targets.R", msg, fixed = TRUE))
})

# ---- P11, P1 ---------------------------------------------------------------------------------

test_that("2e-1 P11: pinned internals of targets: deps, command$expr and settings$name on a target object", {
  skip_if_not_installed("targets")
  t <- targets::tar_target(x, dict$a + 1)
  expect_true(is.character(t$deps))
  expect_true(is.expression(t$command$expr))
  expect_identical(t$settings$name, "x")
  # appending to deps is what tar_dict_deps() relies on: the network sees it
  t$deps <- union(t$deps, "dict_a")
  expect_true("dict_a" %in% t$deps)
})

test_that("2e-1 P1: with targets reported missing, both exports raise need_targets()'s error", {
  skip_if_not_installed("targets")
  testthat::local_mocked_bindings(
    need_targets = function() rlang::abort("targets is needed to define a pipeline"),
    .package = "weft")
  expect_error(tar_dict("no-such-file.yml"), "targets is needed to define a pipeline")
  expect_error(tar_dict_deps(list(), "no-such-file.yml"), "targets is needed to define a pipeline")
  expect_false("weft:dict" %in% search())
})

test_that("2e-1 P1: need_targets() asks rlang to check for targets and passes when it is installed", {
  skip_if_not_installed("targets")
  expect_no_error(weft:::need_targets())
  testthat::local_mocked_bindings(
    check_installed = function(pkg, reason = NULL, ...) rlang::abort(paste("need", pkg, reason)),
    .package = "rlang")
  e <- e1_err(weft:::need_targets())
  expect_true(!is.null(e) && grepl("need targets to define a pipeline", conditionMessage(e), fixed = TRUE))
})
