# Helpers for the 2e-1 tests (the targets pipeline). Contract: dev/design-2e.md, 2e-1.
# Non-ASCII is written as \uXXXX. Made-up values only.
if (!exists("d2_render")) source(Filter(file.exists, c(testthat::test_path("helper-2d.R"), testthat::test_path("..", "helper-2d.R")))[[1]])

.e1 <- new.env()

# compute once per session; the value is whatever `f` returns (errors are not cached)
e1_memo <- function(key, f) {
  if (is.null(.e1[[key]])) .e1[[key]] <- f()
  .e1[[key]]
}

# detach the `weft:dict` environment tar_dict() attaches, when the calling test ends
e1_local_dict <- function(env = parent.frame()) {
  withr::defer({
    while ("weft:dict" %in% search()) detach("weft:dict", character.only = TRUE)
  }, envir = env)
  invisible(NULL)
}

# a dict.yml of number entries, in the order given. `vals` is a named list of values; `defs` holds
# the definition of a key (default "Key <name>."); `decision` adds a `decision` field to those keys.
e1_dict_lines <- function(vals = list(a = 1, b = 2), defs = list(a = "First."), decision = NULL) {
  unlist(lapply(names(vals), function(k) {
    d <- if (!is.null(defs[[k]])) defs[[k]] else paste0("Key ", k, ".")
    c(sprintf("%s:", k),
      sprintf("  value: %s", format(vals[[k]])),
      "  type: number",
      sprintf("  definition: \"%s\"", d),
      if (k %in% names(decision)) sprintf("  decision: %s", decision[[k]]))
  }))
}

# write dict.yml (and return its path) into `dir`
e1_dict <- function(dir, ...) {
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  p <- file.path(dir, "dict.yml")
  writeLines(e1_dict_lines(...), p)
  p
}

e1_put <- function(dir, files) {
  for (f in names(files)) {
    p <- file.path(dir, f)
    dir.create(dirname(p), showWarnings = FALSE, recursive = TRUE)
    writeLines(files[[f]], p, useBytes = TRUE)
  }
  invisible(dir)
}

# run tar_make() in `dir`. `plain = TRUE` (the script has no weft calls): in this process, with the
# targets options reset afterwards. Otherwise in the default callr process, which sees the
# development weft through a temporary library, so this session never has `weft:dict` attached.
# Returns the names of the targets that were built by this make (progress `completed`), with
# branches replaced by their pattern and without `dict_*`.
e1_libpath <- function() c(weft_test_lib(), .libPaths())

e1_make <- function(dir, plain = FALSE) {
  lib <- if (!plain) e1_libpath()   # before the working folder changes: it finds the package from there
  withr::local_dir(dir)
  if (plain) {
    # the script is evaluated in the global environment: take back what it defines
    had <- ls(globalenv(), all.names = TRUE)
    withr::defer({
      targets::tar_option_reset()
      rm(list = setdiff(ls(globalenv(), all.names = TRUE), had), envir = globalenv())
    })
    eval(quote(targets::tar_make(callr_function = NULL, reporter = "silent")), envir = globalenv())
  } else {
    targets::tar_make(callr_arguments = list(libpath = lib),
                      reporter = "silent")
  }
  e1_built()
}

# the names built by the last make in the working folder (see e1_make)
e1_built <- function() {
  prog <- targets::tar_progress()
  meta <- targets::tar_meta(fields = "parent")
  done <- prog$name[prog$progress == "completed"]
  parent <- meta$parent[match(done, meta$name)]
  done <- as.character(ifelse(!is.na(parent), parent, done))
  sort(unique(done[!grepl("^dict_", done)]))
}

# the error a call raises (or NULL), so its message can be searched
e1_err <- function(expr) tryCatch({ expr; NULL }, error = function(e) e)

# a message with every run of white space made one space (cli wraps long lines)
e1_flat <- function(x) gsub("[[:space:]]+", " ", if (is.character(x)) x else conditionMessage(x))

# every target object in a nested list
e1_targets <- function(x) {
  if (inherits(x, "tar_target")) return(list(x))
  if (is.list(x)) return(unlist(lapply(x, e1_targets), recursive = FALSE))
  list()
}
e1_names <- function(x) vapply(e1_targets(x), function(t) t$settings$name, "")
e1_get <- function(x, name) e1_targets(x)[[match(name, e1_names(x))]]

# `tar_meta()`'s data hash of a target in the store under `dir`
e1_data_hash <- function(dir, name, store = "_targets") {
  m <- targets::tar_meta(store = file.path(dir, store), fields = "data")
  m$data[m$name == name]
}

# ---- the plain pipeline of the ledger tests (no weft calls in _targets.R) ------------------------

E1_PLAIN <- c(
  "library(targets)",
  "list(",
  "  tar_target(up, {warning('upstream warned 3 times'); 1}),",
  "  tar_target(fit, {warning('first 5'); warning('second'); up + 1}),",
  "  tar_target(other, {warning('other warned'); 3})",
  ")")

# a temporary project folder holding `script` as _targets.R, built once with stock targets
e1_tmp <- function() {
  d <- tempfile("weft-e1-")
  dir.create(d)
  normalizePath(d)
}

e1_plain_dir <- function(script = E1_PLAIN, dir = e1_tmp()) {
  skip_if_not_installed("targets")
  skip_on_cran()
  dir <- normalizePath(dir)
  writeLines(script, file.path(dir, "_targets.R"))
  e1_make(dir, plain = TRUE)
  dir
}

# the setup chunk code of a document that reads targets
E1_LIB <- "library(targets)"

# a render of `lines` in `dir` (a set-up project) that keeps `dict.yml` and any other files
e1_render <- function(lines, dir, dict = NULL, files = NULL, ...) {
  if (!is.null(dict)) files <- c(list("dict.yml" = dict), files)
  d2_render(lines, dir = dir, files = files, code = E1_LIB, ...)
}

# the header line of a render's ledger, as a list and as text
e1_header <- function(dir, ...) d2_header(d2_path(dir, ...))
e1_header_line <- function(dir, ...) d2_lines(d2_path(dir, ...))[1]

# the weft internal that says whether targets is installed: the design names none (P17), so the
# first of these that exists is mocked to report "absent".
e1_no_targets <- function(env = parent.frame()) {
  cand <- c("has_targets", "targets_installed", "targets_available", "have_targets")
  ns <- asNamespace("weft")
  nm <- cand[vapply(cand, exists, NA, envir = ns, inherits = FALSE)]
  if (!length(nm)) {
    testthat::fail("none of has_targets/targets_installed/targets_available/have_targets exists in weft")
    return(invisible(FALSE))
  }
  args <- setNames(list(function(...) FALSE), nm[[1]])
  do.call(testthat::local_mocked_bindings, c(args, list(.package = "weft", .env = env)))
  invisible(TRUE)
}

# ---- additions for the review of 2e-1 ---------------------------------------------------------

# the names built by the last make, dict_* included (branches replaced by their pattern)
e1_built_all <- function() {
  prog <- targets::tar_progress()
  meta <- targets::tar_meta(fields = "parent")
  done <- prog$name[prog$progress == "completed"]
  parent <- meta$parent[match(done, meta$name)]
  sort(unique(as.character(ifelse(!is.na(parent), parent, done))))
}

# a pipeline folder: dict.yml, _targets.R (`script` lines) and any other `files`
e1_pipe <- function(script, vals = list(a = 1, b = 2), defs = list(a = "First."), files = NULL) {
  d <- e1_tmp()
  e1_dict(d, vals, defs)
  writeLines(script, file.path(d, "_targets.R"))
  if (length(files)) e1_put(d, files)
  d
}

# tar_make() in callr; returns the error (or NULL) instead of stopping
e1_try_make <- function(dir) {
  lib <- e1_libpath()
  withr::with_dir(dir, e1_err(targets::tar_make(callr_arguments = list(libpath = lib), reporter = "silent")))
}
