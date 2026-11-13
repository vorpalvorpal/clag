# Code review B (dev/review-code-b.md), items 1 to 10: units, dictionary, targets, ledger, configuration.
# Failing tests written from the review's reproductions and its "Rulings". Items 11 to 17 are refactors
# guarded by the existing suite. ASCII only. Invented content only.
#
# Units are process-wide state: every test that installs a unit calls cl_units_clean() (helper-closing.R),
# which resets before and after, and uses made-up tokens.
#
# A test marked "(guard)" passes before the fix as well: it pins a neighbour a careless fix could break.

rcb_proj <- function(files = list(), env = parent.frame()) {
  d <- withr::local_tempdir(.local_envir = env)
  d <- normalizePath(d, winslash = "/")
  for (n in names(files)) {
    p <- file.path(d, n)
    dir.create(dirname(p), showWarnings = FALSE, recursive = TRUE)
    writeLines(files[[n]], p)
  }
  d
}

rcb_err <- function(expr) tryCatch({ expr; NULL }, error = function(e) e)

rcb_cfg <- function(dir) {
  withr::local_envvar(WEFT_DRAFT = NA)
  weft:::read_config(dir)
}

rcb_dict_line <- function(key, value = 3, type = "number") {
  sprintf("%s: {value: %s, type: %s, definition: \"A made-up entry.\"}", key, value, type)
}

# ---- 1: _weft.yml is read as YAML 1.2 for booleans ----------------------------------------------------------

test_that("review-code-b #1: a units row keyed N defines a unit named N, not FALSE", {
  cl_units_clean()
  d <- rcb_proj(list("_weft.yml" = c("units:", "  N:", "    name: newton-force")))
  x <- NULL
  expect_no_error(x <- rcb_cfg(d))
  expect_true("N" %in% names(x$units))
  expect_false("FALSE" %in% names(x$units))
})

test_that("review-code-b #1: claim_words drop: [no] drops the word no", {
  d <- rcb_proj(list("_weft.yml" = "claim_words: {drop: [no]}"))
  x <- NULL
  expect_no_error(x <- rcb_cfg(d))
  expect_true("no" %in% unlist(x$claim_words))
  expect_false("FALSE" %in% unlist(x$claim_words))
})

test_that("review-code-b #1: label_words [on, off] is a list of words", {
  d <- rcb_proj(list("_weft.yml" = "label_words: [on, off]"))
  x <- NULL
  expect_no_error(x <- rcb_cfg(d))
  expect_true(all(c("on", "off") %in% unlist(x$label_words)))
})

test_that("review-code-b #1 (guard): true, false and their letter cases are still booleans", {
  d <- rcb_proj(list("_weft.yml" = c("draft: False", "serial_comma: TRUE")))
  x <- rcb_cfg(d)
  expect_identical(x$draft, FALSE)
  expect_identical(x$serial_comma, TRUE)
  d2 <- rcb_proj(list("_weft.yml" = c("draft: false", "serial_comma: false")))
  y <- rcb_cfg(d2)
  expect_identical(y$draft, FALSE)
  expect_identical(y$serial_comma, FALSE)
})

# `!expr` is never evaluated, even with options(yaml.eval.expr = TRUE). The ruling is silent on what the read
# gives instead (a classed weft error or a plain string), so the tests accept either and pin only that the
# side effect did not happen and that an error, if there is one, is a weft error.
test_that("review-code-b #1: !expr in _weft.yml is never evaluated, whatever yaml.eval.expr says", {
  withr::local_options(yaml.eval.expr = TRUE)
  tmp <- withr::local_tempdir()
  for (setting in c("date_format: !expr", "severity: [!expr", "label_words: [!expr", "serial_comma: !expr")) {
    side <- file.path(tmp, "side-effect")
    unlink(side)
    line <- sprintf("%s writeLines('x', '%s')%s", setting, side, if (grepl("\\[", setting)) "]" else "")
    d <- rcb_proj(list("_weft.yml" = line))
    e <- rcb_err(rcb_cfg(d))
    expect_false(file.exists(side), label = paste("side effect of", setting))
    if (!is.null(e)) expect_s3_class(e, "weft_error")
  }
})

test_that("review-code-b #2: !expr in dict.yml is never evaluated, by read_dict() or the entry hashes", {
  withr::local_options(yaml.eval.expr = TRUE)
  tmp <- withr::local_tempdir()
  side <- file.path(tmp, "side-effect")
  lines <- list(
    sprintf("a: {value: 1, type: number, definition: !expr writeLines('x', '%s')}", side),
    sprintf("a: !expr writeLines('x', '%s')", side))
  for (ln in lines) {
    d <- rcb_proj(list("dict.yml" = ln))
    p <- file.path(d, "dict.yml")
    unlink(side)
    e <- rcb_err(read_dict(p))
    expect_false(file.exists(side), label = "read_dict() ran the expression")
    if (!is.null(e)) expect_s3_class(e, "weft_error")
    unlink(side)
    e2 <- rcb_err(weft:::dict_entry_hashes(p))
    expect_false(file.exists(side), label = "dict_entry_hashes() ran the expression")
    if (!is.null(e2)) expect_s3_class(e2, "weft_error")
  }
})

# ---- 2: the dictionary's hashes use the same reading as read_dict() -----------------------------------------

test_that("review-code-b #2 (guard): read_dict() reads the keys y, n, yes, no, on, off under their own names", {
  for (k in c("y", "n", "yes", "no", "on", "off", "Y", "N")) {
    d <- rcb_proj(list("dict.yml" = c(rcb_dict_line(k), rcb_dict_line("word", 2))))
    expect_identical(names(read_dict(file.path(d, "dict.yml"))), c(k, "word"), label = paste("key", k))
  }
})

test_that("review-code-b #2: dict_entry_hashes() names an entry as read_dict() does, for y n yes no on off", {
  for (k in c("y", "n", "yes", "no", "on", "off", "Y", "N")) {
    d <- rcb_proj(list("dict.yml" = c(rcb_dict_line(k), rcb_dict_line("word", 2))))
    p <- file.path(d, "dict.yml")
    h <- NULL
    expect_no_error(h <- weft:::dict_entry_hashes(p))
    expect_identical(names(h), names(read_dict(p)), label = paste("hash names for key", k))
  }
})

test_that("review-code-b #2: a chapter that reads dict$n is not stale when nothing changed", {
  dir <- e2x_state_project()
  e2x_write(file.path(dir, "dict.yml"), c(rcb_dict_line("n"), rcb_dict_line("b", 2)))
  hs <- weft:::dict_entry_hashes(file.path(dir, "dict.yml"))
  rec <- c(n = unname(hs["n"]), b = unname(hs["b"]))        # what a render that read dict$n and dict$b records
  st <- weft:::ledger_state(dir, e2x_header(dict = rec))
  expect_false(st$stale)
  expect_identical(st$reasons, character())
})

test_that("review-code-b #2: a changed value of dict$n is reported as changed, not as gone", {
  dir <- e2x_state_project()
  e2x_write(file.path(dir, "dict.yml"), c(rcb_dict_line("n"), rcb_dict_line("b", 2)))
  hs <- weft:::dict_entry_hashes(file.path(dir, "dict.yml"))
  rec <- c(n = unname(hs["n"]), b = unname(hs["b"]))
  e2x_write(file.path(dir, "dict.yml"), c(rcb_dict_line("n", 4), rcb_dict_line("b", 2)))
  st <- weft:::ledger_state(dir, e2x_header(dict = rec))
  expect_true(st$stale)
  expect_identical(st$reasons, "dict$n changed")
})

test_that("review-code-b #2 (guard): an ordinary key still gives the same hash twice and a changed one differs", {
  d <- rcb_proj(list("dict.yml" = c(rcb_dict_line("a"), rcb_dict_line("b", 2))))
  p <- file.path(d, "dict.yml")
  h1 <- weft:::dict_entry_hashes(p)
  expect_identical(names(h1), c("a", "b"))
  expect_identical(weft:::dict_entry_hashes(p), h1)
  writeLines(c(rcb_dict_line("a", 9), rcb_dict_line("b", 2)), p)
  h2 <- weft:::dict_entry_hashes(p)
  expect_false(identical(h1[["a"]], h2[["a"]]))
  expect_identical(h1[["b"]], h2[["b"]])
})

# ---- 3: a dictionary read outside a knit uses its own project's units: table ---------------------------------

rcb_units_projects <- function(env = parent.frame()) {
  a <- rcb_proj(list(
    "_weft.yml" = c("units:", "  zzrcbhaul:", "    is: 1000 t"),
    "dict.yml" = "haul: {value: 3, type: quantity, unit: zzrcbhaul, definition: \"A made-up haul.\"}"), env)
  b <- rcb_proj(list("_weft.yml" = "draft: false"), env)
  list(a = a, b = b)
}

test_that("review-code-b #3: read_dict() outside a knit uses the project's units: table (is: 1000 t)", {
  cl_units_clean()
  p <- rcb_units_projects()
  d <- withr::with_dir(p$a, read_dict("dict.yml"))
  v <- NULL
  expect_no_error(v <- units::set_units(d$haul, "t"))      # not installed as a new base unit
  expect_equal(as.numeric(v), 3000)
})

test_that("review-code-b #3: read_config() still works in the same session after such a dictionary read", {
  cl_units_clean()
  p <- rcb_units_projects()
  withr::with_dir(p$a, read_dict("dict.yml"))
  expect_no_error(x <- rcb_cfg(p$a))
  expect_true("zzrcbhaul" %in% names(x$units))
  d <- withr::with_dir(p$a, read_dict("dict.yml"))
  expect_no_error(units::set_units(d$haul, "t"))
})

test_that("review-code-b #3: the units belong to the dictionary's own project, not the working directory's", {
  cl_units_clean()
  p <- rcb_units_projects()
  d <- withr::with_dir(p$b, read_dict(file.path(p$a, "dict.yml")))
  expect_no_error(units::set_units(d$haul, "t"))
  expect_no_error(rcb_cfg(p$a))                            # reading A's configuration again
  expect_no_error(units::set_units(d$haul, "t"))           # ... does not take A's unit away
})

test_that("review-code-b #3 (guard): a dictionary unit with no row in units: still installs as before", {
  cl_units_clean()
  d <- rcb_proj(list("dict.yml" = "q: {value: 3, type: quantity, unit: zzrcbbase, definition: \"A made-up base.\"}"))
  x <- read_dict(file.path(d, "dict.yml"))
  expect_identical(attr(x, "registered"), "zzrcbbase")
  expect_no_error(units::as_units("zzrcbbase"))
})

# ---- 4: weft's advice for kt installs, and a failing row gives the true reason ------------------------------

test_that("review-code-b #4: the row weft advises for kt is accepted", {
  cl_units_clean()
  d <- rcb_proj(list("_weft.yml" = "draft: false"))
  e <- NULL
  expect_error(withr::with_dir(d, weft_str("`r u(3, kt)`{.num}")), "kilotonne")
  e <- rcb_err(withr::with_dir(d, weft_str("`r u(3, kt)`{.num}")))
  row <- regmatches(conditionMessage(e), regexec("for example `([^`]+)`", conditionMessage(e)))[[1]][2]
  expect_false(is.na(row), label = "the message quotes a row")
  d2 <- rcb_proj(list("_weft.yml" = c("units:", paste0("  ", row))))
  expect_no_error(rcb_cfg(d2))
})

test_that("review-code-b #4: a row that cannot be installed gives the true reason, not 'already installed'", {
  cl_units_clean()
  d <- rcb_proj(list("_weft.yml" = c("units:", "  ktonne:", "    is: 1000 t")))
  e <- rcb_err(rcb_cfg(d))
  if (!is.null(e)) {                                      # either it installs, or the reason is the real one
    expect_s3_class(e, "weft_config_error")
    expect_false(grepl("already installed", conditionMessage(e), fixed = TRUE))
    expect_match(conditionMessage(e), "prefix", fixed = TRUE)
  }
})

test_that("review-code-b #4 (guard): a key that does not collide with udunits installs", {
  cl_units_clean()
  d <- rcb_proj(list("_weft.yml" = c("units:", "  ktn:", "    is: 1000 t")))
  expect_no_error(rcb_cfg(d))
})

# ---- 5: _quarto.yaml marks a project root -------------------------------------------------------------------

test_that("review-code-b #5: a folder with _quarto.yaml is the project root, as with _quarto.yml", {
  for (marker in c("_quarto.yaml", "_quarto.yml")) {
    root <- rcb_proj(setNames(list("project: {type: book}"), marker))
    sub <- file.path(root, "chapters")
    dir.create(sub)
    got <- weft:::find_project_root(sub)
    expect_identical(normalizePath(got, winslash = "/"), normalizePath(root, winslash = "/"),
                     label = paste("root from", marker))
  }
})

test_that("review-code-b #5 (guard): _weft.yml still marks a root, and with no marker the start folder is returned", {
  root <- rcb_proj(list("_weft.yml" = "draft: false"))
  sub <- file.path(root, "a", "b")
  dir.create(sub, recursive = TRUE)
  expect_identical(normalizePath(weft:::find_project_root(sub), winslash = "/"), normalizePath(root, winslash = "/"))
})

# ---- 6: a file that is not UTF-8 gives a classed error naming the file --------------------------------------

rcb_write_bytes <- function(dir, name, before, bad, after) {
  p <- file.path(dir, name)
  writeBin(c(charToRaw(before), as.raw(bad), charToRaw(after)), p)
  p
}

test_that("review-code-b #6: a Latin-1 dict.yml is a weft_dict_error naming the file and saying UTF-8", {
  d <- rcb_proj()
  p <- rcb_write_bytes(d, "dict.yml", "a: {value: 1, type: number, definition: \"caf", 0xe9, "\"}\n")
  e <- rcb_err(suppressWarnings(read_dict(p)))
  expect_s3_class(e, "weft_dict_error")
  expect_s3_class(e, "weft_error")
  expect_match(conditionMessage(e), "dict.yml", fixed = TRUE)
  expect_match(conditionMessage(e), "UTF-8", fixed = TRUE)
})

test_that("review-code-b #6: a Latin-1 _weft.yml is a weft_config_error naming the file and saying UTF-8", {
  d <- rcb_proj()
  rcb_write_bytes(d, "_weft.yml", "date_format: \"caf", 0xe9, "\"\nserial_comma: true\n")
  e <- rcb_err(suppressWarnings(rcb_cfg(d)))
  expect_s3_class(e, "weft_config_error")
  expect_s3_class(e, "weft_error")
  expect_match(conditionMessage(e), "_weft.yml", fixed = TRUE)
  expect_match(conditionMessage(e), "UTF-8", fixed = TRUE)
})

test_that("review-code-b #6 (guard): a NUL byte in dict.yml or _weft.yml is a classed error naming the file", {
  d <- rcb_proj()
  p <- rcb_write_bytes(d, "dict.yml", "a: {value: 1, type: number, definition: \"x", 0, "\"}\n")
  e <- rcb_err(suppressWarnings(read_dict(p)))
  expect_s3_class(e, "weft_dict_error")
  expect_match(conditionMessage(e), "dict.yml", fixed = TRUE)
  rcb_write_bytes(d, "_weft.yml", "draft: false\nlabel_words: [a", 0, "]\n")
  e2 <- rcb_err(suppressWarnings(rcb_cfg(d)))
  expect_s3_class(e2, "weft_config_error")
  expect_match(conditionMessage(e2), "_weft.yml", fixed = TRUE)
})

test_that("review-code-b #6 (guard): a UTF-8 dict.yml with accents and a BOM still reads", {
  d <- rcb_proj()
  p <- file.path(d, "dict.yml")
  writeBin(c(as.raw(c(0xef, 0xbb, 0xbf)),
             charToRaw("a: {value: 1, type: number, definition: \"caf\xc3\xa9\"}\n")), p)
  expect_s3_class(read_dict(p), "weft_dict")
})

# ---- 7: use_quarto() does not report a file it failed to write ----------------------------------------------

rcb_quarto_project <- function(env = parent.frame()) {
  rcb_proj(list("_quarto.yml" = c("project:", "  type: default", "format: html"), "index.qmd" = "Some text."), env)
}

# the message lines and the error of use_quarto(dir); warnings are muffled
rcb_use_quarto <- function(dir) {
  msgs <- character()
  err <- NULL
  withCallingHandlers(
    tryCatch(weft::use_quarto(dir), error = function(e) err <<- e),
    message = function(m) { msgs <<- c(msgs, conditionMessage(m)); invokeRestart("muffleMessage") },
    warning = function(w) invokeRestart("muffleWarning"))
  list(msgs = msgs, err = err)
}

test_that("review-code-b #7: a read-only target folder gives a weft_tool_error and no false 'Wrote:' line", {
  skip_on_os("windows")
  skip_if(identical(Sys.info()[["user"]], "root"), "root writes anywhere")
  d <- rcb_quarto_project()
  ext <- file.path(d, "_extensions", "weft-check")
  dir.create(ext, recursive = TRUE)
  Sys.chmod(ext, "555")
  withr::defer(Sys.chmod(ext, "755"))
  skip_if(file.access(ext, 2L) == 0L, "the folder is still writable")
  r <- rcb_use_quarto(d)
  expect_false(file.exists(file.path(ext, "weft-check.lua")))
  wrote <- grep("^Wrote:", r$msgs, value = TRUE)
  expect_false(any(grepl("weft-check.lua", wrote, fixed = TRUE)))
  expect_s3_class(r$err, "weft_tool_error")
  expect_match(if (is.null(r$err)) "" else conditionMessage(r$err), "weft-check", fixed = TRUE)
})

test_that("review-code-b #7: a symlink standing where a file goes is not written through", {
  skip_on_os("windows")
  d <- rcb_quarto_project()
  dir.create(file.path(d, "_weft"))
  victim <- file.path(withr::local_tempdir(), "victim.txt")
  writeLines("VICTIM", victim)
  skip_if(!isTRUE(file.symlink(victim, file.path(d, "_weft", "pre-render.R"))), "no symlinks here")
  r <- rcb_use_quarto(d)
  expect_identical(readLines(victim), "VICTIM")
  expect_s3_class(r$err, "weft_tool_error")
})

test_that("review-code-b #7: a dangling symlink standing where a file goes does not create its target", {
  skip_on_os("windows")
  d <- rcb_quarto_project()
  dir.create(file.path(d, "_weft"))
  target <- file.path(withr::local_tempdir(), "not-yet.txt")
  skip_if(!isTRUE(file.symlink(target, file.path(d, "_weft", "post-render.R"))), "no symlinks here")
  r <- rcb_use_quarto(d)
  expect_false(file.exists(target))
  expect_s3_class(r$err, "weft_tool_error")
})

test_that("review-code-b #7: use_quarto() on a folder with no Quarto project is a weft_tool_error", {
  d <- rcb_proj()
  r <- rcb_use_quarto(d)
  expect_s3_class(r$err, "weft_tool_error")
})

test_that("review-code-b #7 (guard): a plain run lists exactly what it wrote, and every listed file exists", {
  d <- rcb_quarto_project()
  r <- rcb_use_quarto(d)
  expect_null(r$err)
  wrote <- grep("^Wrote:", r$msgs, value = TRUE)
  expect_length(wrote, 1L)
  files <- trimws(strsplit(sub("^Wrote:", "", wrote), ",")[[1]])
  expect_true(length(files) >= 5L)
  expect_true(all(file.exists(file.path(d, files))))
})

# ---- 8: an unusual top-level key is read under its real name or refused, never weft_k1 ----------------------

rcb_key_case <- function(lines, key) {
  d <- rcb_proj(list("dict.yml" = lines))
  r <- tryCatch(read_dict(file.path(d, "dict.yml")), error = function(e) e)
  if (inherits(r, "error")) {
    expect_s3_class(r, "weft_dict_error")
    expect_match(conditionMessage(r), key, fixed = TRUE)
  } else {
    expect_false(any(grepl("^weft_k[0-9]+$", names(r))))
    expect_true(key %in% names(r))
    expect_true("b" %in% names(r))
  }
  invisible(r)
}

test_that("review-code-b #8: a key written with a tag (!!str yes:) is read as yes or refused naming it", {
  rcb_key_case(c("!!str yes: {value: 1, type: number, definition: x}", rcb_dict_line("b", 2)), "yes")
})

test_that("review-code-b #8: a key written in the explicit form (? a) is read as a or refused naming it", {
  rcb_key_case(c("? a", ": {value: 1, type: number, definition: x}", rcb_dict_line("b", 2)), "a")
})

test_that("review-code-b #8 (guard): ordinary and quoted keys are read under their names", {
  d <- rcb_proj(list("dict.yml" = c(rcb_dict_line("a"), rcb_dict_line("\"c\"", 2), rcb_dict_line("b", 2))))
  expect_identical(names(read_dict(file.path(d, "dict.yml"))), c("a", "c", "b"))
})

# ---- 9: the second tar_dict() check ------------------------------------------------------------------------
# What is reachable without relying on targets internals: the manifest of a script with one dictionary, and
# the two shapes of a second tar_dict() (both in one c(), and the first assigned and dropped), each run in the
# current process with tar_manifest(callr_function = NULL). The soft failure itself (the lookup of
# targets::tar_callr_inner_try returning NULL when a release renames it) cannot be pinned without removing a
# binding from the targets namespace, which is locked; it is left to the existing suite and the code review.

rcb_manifest <- function(script, env = parent.frame()) {
  d <- rcb_proj(list("dict.yml" = rcb_dict_line("a"), "_targets.R" = c("library(targets)", script)), env)
  withr::with_dir(d, targets::tar_manifest(callr_function = NULL))
}

test_that("review-code-b #9: one tar_dict() builds the dictionary targets", {
  skip_if_not_installed("targets")
  skip_on_cran()
  m <- rcb_manifest("weft::tar_dict('dict.yml')")
  expect_true(all(c("dict_file", "dict_values", "dict_a") %in% m$name))
})

test_that("review-code-b #9: two tar_dict() results in one c() are refused with weft's own message", {
  skip_if_not_installed("targets")
  skip_on_cran()
  e <- rcb_err(rcb_manifest("c(weft::tar_dict('dict.yml'), weft::tar_dict('dict.yml'))"))
  expect_s3_class(e, "weft_error")
  expect_match(conditionMessage(e), "twice", fixed = TRUE)
  expect_false(grepl("tar_callr_inner_try", conditionMessage(e), fixed = TRUE))
})

test_that("review-code-b #9: a first tar_dict() assigned and dropped, then a second, is refused too", {
  skip_if_not_installed("targets")
  skip_on_cran()
  e <- rcb_err(rcb_manifest(c("a <- weft::tar_dict('dict.yml')", "weft::tar_dict('dict.yml')")))
  expect_s3_class(e, "weft_error")
  expect_match(conditionMessage(e), "twice", fixed = TRUE)
})

test_that("review-code-b #9: a second evaluation of the script in one session is not mistaken for a repeat", {
  skip_if_not_installed("targets")
  skip_on_cran()
  d <- rcb_proj(list("dict.yml" = rcb_dict_line("a"),
                     "_targets.R" = c("library(targets)", "weft::tar_dict('dict.yml')")))
  for (i in 1:2) {
    m <- withr::with_dir(d, targets::tar_manifest(callr_function = NULL))
    expect_true("dict_values" %in% m$name)
  }
})

# ---- 10: a units cache file of the wrong shape is ignored ---------------------------------------------------

# a fresh cache folder; the session's copies of the tables and the database are emptied now and put back when
# the test ends. Never touches the user's real cache.
rcb_cache <- function(env = parent.frame()) {
  cache <- withr::local_tempdir(.local_envir = env)
  withr::local_envvar(R_USER_CACHE_DIR = cache, "_R_CHECK_PACKAGE_NAME_" = NA, .local_envir = env)
  withr::local_options(weft.units_cache = TRUE, .local_envir = env)
  uc <- weft:::un_cache
  saved <- as.list(uc, all.names = TRUE)
  clear <- function() rm(list = ls(uc, all.names = TRUE), envir = uc)
  clear()
  withr::defer({ clear(); for (n in names(saved)) assign(n, saved[[n]], envir = uc) }, envir = env)
  list(clear = clear)
}

rcb_cache_cases <- list(
  "v with other columns" = function(o, f) { o$v <- data.frame(x = 1); saveRDS(o, f) },
  "pf with other columns" = function(o, f) { o$pf <- data.frame(y = 2); saveRDS(o, f) },
  "v without the def column" = function(o, f) { o$v$def <- NULL; saveRDS(o, f) },
  "v columns not character" = function(o, f) { o$v$def <- seq_len(nrow(o$v)); saveRDS(o, f) },
  "pf without the value column" = function(o, f) { o$pf$value <- NULL; saveRDS(o, f) },
  "a list of the wrong structure" = function(o, f) saveRDS(list(key = o$key, v = list(1, 2), pf = "x"), f),
  "a file from another version" = function(o, f) { o$key[[1]] <- "another-version"; saveRDS(o, f) },
  "a truncated file" = function(o, f) {
    saveRDS(o, f)
    b <- readBin(f, "raw", file.size(f))
    writeBin(b[seq_len(length(b) %/% 2L)], f)
  },
  "an empty file" = function(o, f) file.create(f)
)

# Only the first three shapes break units today; the others are already ignored (neighbour guards).
rcb_cache_breaks_today <- c("v with other columns", "pf with other columns", "v without the def column")

for (case in names(rcb_cache_cases)) {
  local({
    case <- case
    guard <- if (case %in% rcb_cache_breaks_today) "" else " (guard)"
    test_that(paste0("review-code-b #10", guard, ": a units cache file of the wrong shape (", case, ") is ignored and units work"), {
      cc <- rcb_cache()
      good <- weft:::ud_tables()
      key <- weft:::ud_tables_key()
      if (!expect_precondition(!is.null(key), "ud_tables_key() gives a key")) return(invisible())
      f <- weft:::ud_tables_file(key)
      if (!expect_precondition(file.exists(f), "the cache file was written")) return(invisible())
      rcb_cache_cases[[case]](readRDS(f), f)
      cc$clear()
      t2 <- NULL
      expect_no_error(t2 <- weft:::ud_tables())
      expect_true(all(c("symbol", "def") %in% names(t2$v)))
      expect_equal(nrow(t2$v), nrow(good$v))
      expect_no_error(weft:::ud_db())
      expect_no_error(u(3, m))
    })
  })
}

test_that("review-code-b #10: a cache file of the wrong shape is replaced by a good one", {
  cc <- rcb_cache()
  weft:::ud_tables()
  f <- weft:::ud_tables_file(weft:::ud_tables_key())
  if (!expect_precondition(file.exists(f), "the cache file was written")) return(invisible())
  o <- readRDS(f)
  o$v <- data.frame(x = 1)
  saveRDS(o, f)
  cc$clear()
  weft:::ud_tables()
  expect_true("def" %in% names(readRDS(f)$v))
})

test_that("review-code-b #10 (guard): a good cache file is read back, not rebuilt", {
  cc <- rcb_cache()
  a <- weft:::ud_tables()
  f <- weft:::ud_tables_file(weft:::ud_tables_key())
  if (!expect_precondition(file.exists(f), "the cache file was written")) return(invisible())
  m1 <- file.mtime(f)
  cc$clear()
  b <- weft:::ud_tables()
  expect_identical(b$v, a$v)
  expect_identical(file.mtime(f), m1)
})
