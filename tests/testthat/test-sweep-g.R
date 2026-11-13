# Package G of dev/refactor-sweep.md: dead code and one way to warn.
#   G1  every weft warning carries `weft_warning` beside its specific class; weft_warn(msg, class) is the helper
#   G2  dead code is gone
#   G3  the `units` internals are reached through one guarded wrapper: units_internal(name)
#   G4  ud_shipped() and tok_resolve_db() agree (review B item 16)

sw_catch <- function(expr) {
  ws <- list()
  val <- withCallingHandlers(
    expr,
    warning = function(w) { ws[[length(ws) + 1L]] <<- w; invokeRestart("muffleWarning") }
  )
  list(value = val, warnings = ws)
}

# the R/ sources, or NULL when the tests run against an installed copy
sw_r_dir <- function() {
  d <- testthat::test_path("..", "..", "R")
  if (dir.exists(d) && file.exists(file.path(d, "..", "DESCRIPTION"))) normalizePath(d) else NULL
}

# ---- G1 --------------------------------------------------------------------------------------------------------

test_that("sweep G1: weft_warn(msg, class) signals a warning of class c(class, 'weft_warning')", {
  w <- tryCatch(weft:::weft_warn("a message", "weft_some_warning"), warning = function(w) w)
  expect_s3_class(w, "warning")
  expect_identical(class(w)[1:2], c("weft_some_warning", "weft_warning"))
  expect_match(conditionMessage(w), "a message", fixed = TRUE)
})

test_that("sweep G1: a failed claim(level = 'warn') carries weft_claim_warning and weft_warning", {
  r <- sw_catch(claim(4217, . > 10000, level = "warn"))
  expect_gte(length(r$warnings), 1L)
  for (w in r$warnings) {
    expect_s3_class(w, "weft_claim_warning")
    expect_s3_class(w, "weft_warning")
  }
})

test_that("sweep G1: a number that prints as zero carries weft_zero_warning and weft_warning", {
  r <- sw_catch(fmt_num(0.04))
  expect_gte(length(r$warnings), 1L)
  for (w in r$warnings) {
    expect_s3_class(w, "weft_zero_warning")
    expect_s3_class(w, "weft_warning")
  }
})

test_that("sweep G1: a zero warning in a strict render (resolve.R) carries weft_warning", {
  r <- i2_run("`r fmt_num(0.04)`")
  zs <- Filter(function(w) inherits(w, "weft_zero_warning"), r$w)
  skip_if(!length(zs), "this set-up raises no zero warning outside a knit")
  for (w in zs) expect_s3_class(w, "weft_warning")
})

test_that("sweep G1: an unknown setting carries weft_config_warning and weft_warning", {
  r <- sw_catch(weft:::warn_unknown(list(no_such_setting = 1), "_weft.yml"))
  expect_length(r$warnings, 1L)
  expect_s3_class(r$warnings[[1]], "weft_config_warning")
  expect_s3_class(r$warnings[[1]], "weft_warning")
})

test_that("sweep G1: a bare quantity carries weft_unit_warning and weft_warning", {
  r <- i2_run("`r u(3, mm)`")
  ws <- i2_unit_warnings(r)
  expect_length(ws, 1L)
  expect_s3_class(ws[[1]], "weft_warning")
})

test_that("sweep G1: no call to base warning() remains in R/ outside weft_warn()", {
  d <- sw_r_dir()
  skip_if(is.null(d), "the R/ sources are not available")
  files <- list.files(d, pattern = "\\.[Rr]$", full.names = TRUE)
  expect_gt(length(files), 10L)
  hits <- character()
  found_helper <- FALSE
  walk <- function(e, f, in_helper) {
    if (is.call(e)) {
      h <- e[[1L]]
      if (identical(h, as.name("<-")) && length(e) == 3L && identical(e[[2L]], as.name("weft_warn"))) {
        found_helper <<- TRUE
        in_helper <- TRUE
      }
      if (!in_helper && identical(h, as.name("warning"))) hits <<- c(hits, basename(f))
      sub <- as.list(e)
      for (i in seq_along(sub)) if (!identical(sub[[i]], quote(expr = ))) walk(sub[[i]], f, in_helper)
    } else if (is.pairlist(e) || is.expression(e)) {
      sub <- as.list(e)
      for (i in seq_along(sub)) if (!identical(sub[[i]], quote(expr = ))) walk(sub[[i]], f, in_helper)
    }
  }
  for (f in files) for (e in parse(f, keep.source = FALSE)) walk(e, f, FALSE)
  expect_true(found_helper, label = "weft_warn() is defined in R/")
  expect_identical(unique(hits), character())
})

# ---- G2 --------------------------------------------------------------------------------------------------------

test_that("sweep G2: the dead functions are gone from the namespace", {
  ns <- asNamespace("weft")
  for (nm in c("unit_text", "unit_key_parse", "unit_proj", "empty_ledger_x", "as_obj", "order_docs")) {
    expect_false(exists(nm, envir = ns, inherits = FALSE), label = nm)
  }
})

test_that("sweep G2: recall_normalise() has no with_map argument, and still exists", {
  expect_true(is.function(weft:::recall_normalise))
  expect_false("with_map" %in% names(formals(weft:::recall_normalise)))
})

# ---- G3 --------------------------------------------------------------------------------------------------------

test_that("sweep G3: the units internals weft relies on exist in the installed units", {
  ns <- asNamespace("units")
  expect_true(exists("R_ut_get_symbol", envir = ns, inherits = FALSE),
              info = "units removed R_ut_get_symbol: see units #447/#448 and weft's units_internal() wrappers")
  expect_true(exists("R_ut_parse", envir = ns, inherits = FALSE),
              info = "units removed R_ut_parse: see units #447/#448 and weft's units_internal() wrappers")
  expect_true(is.function(get0("default_units_xml", envir = ns, inherits = FALSE)),
              info = "units removed default_units_xml")
})

test_that("sweep G3: units_internal(name) returns the function from the units namespace", {
  f <- weft:::units_internal("R_ut_parse")
  expect_identical(f, get("R_ut_parse", envir = asNamespace("units")))
  expect_true(is.function(weft:::units_internal("R_ut_get_symbol")))
  expect_true(is.function(weft:::units_internal("default_units_xml")))
})

test_that("sweep G3: units_internal() of a missing internal aborts with a weft_error that names it", {
  e <- tryCatch(weft:::units_internal("no_such_internal_for_weft_tests"), error = function(e) e)
  expect_s3_class(e, "weft_error")
  expect_match(conditionMessage(e), "no_such_internal_for_weft_tests", fixed = TRUE)
})

test_that("sweep G3: ud_internal_symbol(def) reports a missing internal instead of returning ''", {
  expect_true(is.character(weft:::ud_internal_symbol("m")))
  testthat::local_mocked_bindings(
    units_internal = function(name) weft:::weft_abort(sprintf("the units internal `%s` is missing", name),
                                                      "weft_units_internal_error"),
    .package = "weft")
  e <- tryCatch(weft:::ud_internal_symbol("m"), error = function(e) e)
  expect_s3_class(e, "weft_error")
  expect_match(conditionMessage(e), "R_ut", fixed = TRUE)
})

test_that("sweep G3: ud_units_xml_path() returns the units default database file, and reports a missing internal", {
  p <- weft:::ud_units_xml_path()
  expect_true(is.character(p) && length(p) == 1L && file.exists(p))
  testthat::local_mocked_bindings(
    units_internal = function(name) weft:::weft_abort(sprintf("the units internal `%s` is missing", name),
                                                      "weft_units_internal_error"),
    .package = "weft")
  e <- tryCatch(weft:::ud_units_xml_path(), error = function(e) e)
  expect_s3_class(e, "weft_error")
  expect_match(conditionMessage(e), "default_units_xml", fixed = TRUE)
})

# ---- G4 --------------------------------------------------------------------------------------------------------

test_that("sweep G4: ud_shipped() and tok_resolve_db() agree on every symbol the shipped database holds", {
  v <- weft:::ud_tables()$v
  syms <- unique(trimws(unlist(strsplit(v$symbol[nzchar(v$symbol)], "[, ]+"))))
  syms <- syms[nzchar(syms)]
  expect_gt(length(syms), 50L)
  a <- vapply(syms, weft:::ud_shipped, NA)
  b <- vapply(syms, function(s) isTRUE(weft:::tok_resolve_db(s)$known), NA)
  expect_true(all(a), label = "ud_shipped() knows every shipped symbol")
  expect_true(all(b), label = "tok_resolve_db() knows every shipped symbol")
  expect_identical(a, b)
})

test_that("sweep G4: the two answer alike on names, aliases, prefixed units and unknown tokens", {
  toks <- c("m", "km", "mm", "metre", "meters", "kilometre", "second", "hour", "degree_Celsius",
            "astronomical_unit_BIPM_2006", "notaunit", "zzq", "kmetre_unknown", "mbar")
  for (t in toks) {
    expect_identical(weft:::ud_shipped(t), isTRUE(weft:::tok_resolve_db(t)$known), label = t)
  }
})
