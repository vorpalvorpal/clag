# Helpers for the 2c tests (dictionary tooling). Contract: dev/design-2c.md.
# "~" in an expected string stands for U+00A0, the no-break space.

c2 <- function(s) gsub("~", " ", s, fixed = TRUE)

c2_fixture <- function() testthat::test_path("_dict-tools", "dict.yml")
c2_fixture_lines <- function() readLines(c2_fixture(), warn = FALSE, encoding = "UTF-8")

# a path under inst/dict of the weft being tested
c2_inst <- function(name) {
  p <- system.file("dict", name, package = "weft")
  if (!nzchar(p)) p <- file.path(weft_pkg_root(), "inst", "dict", name)
  p
}

# a fresh normalised temp directory, with files written (`files`: name -> lines)
c2_proj <- function(files = list(), env = parent.frame()) {
  dir <- normalizePath(withr::local_tempdir(.local_envir = env))
  for (f in names(files)) {
    p <- file.path(dir, f)
    dir.create(dirname(p), showWarnings = FALSE, recursive = TRUE)
    writeLines(files[[f]], p, useBytes = TRUE)
  }
  dir
}

# every file under a directory (dot-files too), relative, sorted
c2_tree <- function(dir) {
  sort(list.files(dir, recursive = TRUE, all.files = TRUE, no.. = TRUE, include.dirs = TRUE))
}

c2_bytes <- function(p) readBin(p, "raw", file.size(p))

# the error an expression raises, or NULL
c2_err <- function(expr) tryCatch({ expr; NULL }, error = function(e) e)

c2_msg <- function(e) if (is.null(e)) "" else conditionMessage(e)

# a condition of the given class that also carries weft_error
c2_expect_cond <- function(e, class) {
  testthat::expect_false(is.null(e), label = "an error was raised")
  testthat::expect_true(inherits(e, class), label = paste("class", class))
  testthat::expect_true(inherits(e, "weft_error"), label = "class weft_error")
}

# `fixed` pieces all occur in the message of `e`
c2_expect_msg <- function(e, ...) {
  m <- c2_msg(e)
  for (p in c(...)) testthat::expect_true(grepl(p, m, fixed = TRUE),
                                          label = sprintf("message holds `%s` (message: %s)", p, m))
}

# the messages (in order, trailing newline dropped), the value and its visibility.
# `on_first` runs when the first message arrives.
c2_says <- function(expr, on_first = NULL) {
  msgs <- character()
  v <- withCallingHandlers(
    withVisible(expr),
    message = function(m) {
      if (!length(msgs) && !is.null(on_first)) on_first()
      msgs <<- c(msgs, sub("\n$", "", conditionMessage(m)))
      invokeRestart("muffleMessage")
    }
  )
  list(msgs = msgs, all = paste(msgs, collapse = "\n"), value = v$value, visible = v$visible)
}

# a dictionary read from a temp file of lines (named dict.yml in its own folder)
c2_dict <- function(lines, env = parent.frame()) {
  dir <- c2_proj(list(dict.yml = lines), env)
  read_dict(file.path(dir, "dict.yml"))
}

c2_read_err <- function(lines, env = parent.frame()) {
  dir <- c2_proj(list(dict.yml = lines), env)
  p <- file.path(dir, "dict.yml")
  list(err = c2_err(read_dict(p)), path = p)
}

# one entry in flow style
c2_entry <- function(key, value = "1", type = "number", extra = NULL, definition = "Fine.") {
  sprintf("%s: {value: %s, type: %s, definition: \"%s\"%s}", key, value, type, definition,
          if (length(extra)) paste0(", ", paste(extra, collapse = ", ")) else "")
}

# a read_dict() problem line: `<file>:<line>: \`<key>\`: <what>`; the error is a
# weft_dict_error holding exactly `n` problems
c2_expect_problem <- function(lines, key, what, n = 1L, label = what) {
  r <- c2_read_err(lines)
  c2_expect_cond(r$err, "weft_dict_error")
  msg <- c2_msg(r$err)
  line <- grep(paste0("^", key, ":"), lines)[1]
  want <- sprintf("%s:%d: `%s`: %s", r$path, line, key, what)
  testthat::expect_true(want %in% strsplit(msg, "\n", fixed = TRUE)[[1]],
                        label = sprintf("problem line `%s` in\n%s", want, msg))
  testthat::expect_true(grepl(sprintf("%d problem(s) in the dictionary", n), msg, fixed = TRUE),
                        label = sprintf("%d problem(s) in: %s", n, msg))
  invisible(msg)
}

# ---- fetch doubles (no test touches the network) ---------------------------------------------

C2_API <- "https://api.github.com/repos/"

# `answers`: names are what follows C2_API (`example/proj`, `example/proj/issues/12`),
# values a status (integer or NA) or list(status =, error =). Any other URL fails the test.
c2_fetch <- function(answers) {
  calls <- character()
  tokens <- list()
  f <- function(url, token) {
    calls <<- c(calls, url)
    tokens <<- c(tokens, list(token))   # list(NULL) keeps a NULL token
    key <- sub(C2_API, "", url, fixed = TRUE)
    a <- if (startsWith(url, C2_API)) answers[[key]] else NULL
    if (is.null(a)) {
      testthat::fail(paste("an unexpected URL was requested:", url))
      return(list(status = NA_integer_, error = "unexpected URL"))
    }
    if (is.list(a)) return(list(status = as.integer(a$status), error = a$error))
    list(status = as.integer(a), error = NULL)
  }
  list(fetch = f, calls = function() calls, tokens = function() tokens,
       urls = function() sub(C2_API, "", calls, fixed = TRUE))
}

# a fetch that fails the test when called
c2_no_fetch <- function() {
  function(url, token) {
    testthat::fail(paste("fetch was called for", url))
    list(status = NA_integer_, error = "unexpected")
  }
}

# no GitHub token in the environment, unless set by the caller afterwards
c2_no_token <- function(env = parent.frame()) {
  withr::local_envvar(GITHUB_PAT = NA, GITHUB_TOKEN = NA, .local_envir = env)
}

# a dictionary whose entries a, b, c... carry the given decisions (an integer or a string
# each; NA for none), file in a fresh project; returns the dict and the project root
c2_decision_dict <- function(decisions, env = parent.frame()) {
  keys <- letters[seq_along(decisions)]
  lines <- vapply(seq_along(decisions), function(i) {
    d <- decisions[[i]]
    dec <- if (is.na(d)) "" else if (is.numeric(d)) sprintf(", decision: %d", as.integer(d))
           else sprintf(", decision: \"%s\"", gsub("\\", "\\\\", d, fixed = TRUE))
    sprintf("%s: {value: 1, type: number, definition: \"Fine.\"%s}", keys[i], dec)
  }, "")
  dir <- c2_proj(list(dict.yml = lines), env)
  list(dict = read_dict(file.path(dir, "dict.yml")), root = dir, keys = keys)
}

# resolved is NA exactly when the detail starts "could not check: "
c2_expect_na_iff_detail <- function(res) {
  testthat::expect_identical(is.na(res$resolved), startsWith(res$detail, "could not check: "))
}

# a temporary git repository, with an `origin` when `remote` is given
c2_git_repo <- function(remote = NULL, env = parent.frame()) {
  dir <- c2_proj(list(), env)
  system2("git", c("-C", shQuote(dir), "init", "-q"), stdout = FALSE, stderr = FALSE)
  if (!is.null(remote)) {
    system2("git", c("-C", shQuote(dir), "remote", "add", "origin", shQuote(remote)),
            stdout = FALSE, stderr = FALSE)
  }
  dir
}
