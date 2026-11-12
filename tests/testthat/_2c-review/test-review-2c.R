# Regression tests for the review of package 2c (dev/review-2c.md), decided by the
# "Rulings on the review of 2c" at the end of dev/design-2c.md (the rulings win over the
# contract above them and over the review). One or more tests per finding 1-16 and per
# ruling B, D, E, F, G, H, I, J, L, M. A, C and K are "Left" and have none. Made-up content
# only; no test touches the network (every resolver case passes a stub `fetch`).
# `~` in an expected string is U+00A0 (c2()). Non-ASCII is written as \uXXXX.

R2C_REPO <- "example/proj"

# the messages, the error (or NULL) and the value of an expression; warnings are muffled
r2c_run <- function(expr) {
  msgs <- character()
  err <- NULL
  value <- withCallingHandlers(
    tryCatch(expr, error = function(e) { err <<- e; NULL }),
    message = function(m) {
      msgs <<- c(msgs, sub("\n$", "", conditionMessage(m)))
      invokeRestart("muffleMessage")
    },
    warning = function(w) invokeRestart("muffleWarning")
  )
  list(err = err, msgs = msgs, value = value)
}

# a project holding the 2c fixture as dict.yml (and `extra` files), as the working folder
r2c_vale_proj <- function(extra = list(), env = parent.frame()) {
  files <- list(dict.yml = c2_fixture_lines())
  files[names(extra)] <- extra
  dir <- c2_proj(files, env)
  withr::local_dir(dir, .local_envir = env)
  dir
}

# a dictionary read from lines, with the project folder it lives in
r2c_dict <- function(lines, env = parent.frame()) {
  dir <- c2_proj(list(dict.yml = lines), env)
  list(dict = suppressWarnings(read_dict(file.path(dir, "dict.yml"))), root = dir)
}

r2c_chk <- function(x, ...) weft:::check_decisions(x$dict, root = x$root, ...)

# a fetch that answers the repository with `repo` and every issue with `issue`
# (each a function(url) giving a fetch result, or a fixed value); counts its calls
r2c_fetch <- function(repo = list(status = 200L, error = NULL), issue = list(status = 200L, error = NULL)) {
  calls <- character()
  f <- function(url, token) {
    calls <<- c(calls, url)
    a <- if (grepl("/issues/", url, fixed = TRUE)) issue else repo
    if (is.function(a)) a(url) else a
  }
  list(fetch = f, n = function() length(calls), urls = function() sub(C2_API, "", calls, fixed = TRUE))
}

r2c_skip_if_root <- function() {
  skip_if(identical(unname(Sys.info()[["effective_user"]]), "root"), "running as root: permissions are not enforced")
}

r2c_defer_chmod <- function(path, env = parent.frame()) {
  withr::defer(Sys.chmod(path, "755"), envir = env)
}

# the file a "Wrote:" message names, relative to `root`, or character()
r2c_wrote <- function(msgs, root) {
  w <- sub("^Wrote: ", "", grep("^Wrote: ", msgs, value = TRUE))
  if (!length(w)) return(character())
  w <- trimws(strsplit(w, ", ", fixed = TRUE)[[1]])
  ifelse(startsWith(w, "/"), w, file.path(root, w))
}

# ---- 1, M: no write through a symbolic link ---------------------------------------------------

test_that("review 2c #1: use_dictionary() refuses a schema path that is a link, and the file it points at is untouched (P10, ruling 1)", {
  skip_on_os("windows")
  dir <- c2_proj()
  dir.create(file.path(dir, "_weft"))
  other <- file.path(dir, "other.json")
  writeLines("{\"mine\":1}", other)
  expect_true(file.symlink(other, file.path(dir, "_weft", "dict.schema.json")))
  before <- c2_bytes(other)
  r <- r2c_run(use_dictionary(dir))
  c2_expect_cond(r$err, "weft_tool_error")
  c2_expect_msg(r$err, "dict.schema.json")
  expect_identical(c2_bytes(other), before)
  expect_false(file.exists(file.path(dir, "dict.yml")), label = "nothing was written before the refusal")
})

test_that("review 2c #1: use_dictionary() refuses a dangling dict.yml link and does not create its target (P10, ruling 1)", {
  skip_on_os("windows")
  dir <- c2_proj()
  expect_true(file.symlink(file.path(dir, "nowhere.yml"), file.path(dir, "dict.yml")))
  r <- r2c_run(use_dictionary(dir))
  c2_expect_cond(r$err, "weft_tool_error")
  c2_expect_msg(r$err, "dict.yml")
  expect_false(file.exists(file.path(dir, "nowhere.yml")))
  expect_false(file.exists(file.path(dir, "_weft", "dict.schema.json")), label = "nothing was written before the refusal")
})

test_that("review 2c #1: use_dictionary() refuses a _weft folder that is a link (P10, ruling 1)", {
  skip_on_os("windows")
  dir <- c2_proj()
  elsewhere <- file.path(dir, "elsewhere")
  dir.create(elsewhere)
  expect_true(file.symlink(elsewhere, file.path(dir, "_weft")))
  r <- r2c_run(use_dictionary(dir))
  c2_expect_cond(r$err, "weft_tool_error")
  c2_expect_msg(r$err, "_weft")
  expect_identical(list.files(elsewhere, all.files = TRUE, no.. = TRUE), character())
})

test_that("review 2c #1: control - a regular, outdated schema file is still replaced and announced (9.3.1)", {
  dir <- c2_proj(list(`_weft/dict.schema.json` = "{\"old\":1}"))
  r <- r2c_run(use_dictionary(dir))
  expect_null(r$err)
  expect_true(any(grepl("_weft/dict.schema.json  (exists: replaced by the schema of this version of weft)", r$msgs, fixed = TRUE)))
  expect_true(file.exists(file.path(dir, "dict.yml")))
  expect_false(identical(readLines(file.path(dir, "_weft", "dict.schema.json"), warn = FALSE), "{\"old\":1}"))
})

test_that("review 2c #M: dict_vale() never writes through a link: a link as the rule file or as the style folder is a weft_tool_error naming it (ruling 1)", {
  skip_on_os("windows")
  dir <- r2c_vale_proj()
  # the rule file is a link to a file of weft's own making
  dir.create(file.path(dir, "styles", "Weft"), recursive = TRUE)
  other <- file.path(dir, "other.yml")
  writeLines(c("# Generated by weft::dict_vale() from dict.yml. Do not edit.", "extends: substitution"), other)
  expect_true(file.symlink(other, file.path(dir, "styles", "Weft", "Terms.yml")))
  before <- c2_bytes(other)
  r <- r2c_run(dict_vale())
  c2_expect_cond(r$err, "weft_tool_error")
  c2_expect_msg(r$err, "Terms.yml")
  expect_identical(c2_bytes(other), before)
  # the style folder is a link to a folder elsewhere
  dir2 <- r2c_vale_proj()
  target <- file.path(dir2, "shared-style")
  dir.create(target)
  dir.create(file.path(dir2, "styles"))
  expect_true(file.symlink(target, file.path(dir2, "styles", "Weft")))
  r2 <- r2c_run(dict_vale())
  c2_expect_cond(r2$err, "weft_tool_error")
  c2_expect_msg(r2$err, "Weft")
  expect_identical(list.files(target, all.files = TRUE, no.. = TRUE), character())
})

test_that("review 2c #M: control - dict_vale() writes the rule into plain folders (4.7.2)", {
  dir <- r2c_vale_proj()
  r <- r2c_run(dict_vale())
  expect_null(r$err)
  expect_true(file.exists(file.path(dir, "styles", "Weft", "Terms.yml")))
})

# ---- 2: "Wrote:" only for a file that was written -----------------------------------------------

test_that("review 2c #2: a read-only folder is a weft_tool_error, with no 'Wrote:' for a file that is not there (9.3.1, ruling 2)", {
  skip_on_os("windows")
  r2c_skip_if_root()
  dir <- c2_proj()
  Sys.chmod(dir, "555")
  r2c_defer_chmod(dir)
  r <- r2c_run(use_dictionary(dir))
  c2_expect_cond(r$err, "weft_tool_error")
  c2_expect_msg(r$err, "dict.yml")
  for (p in r2c_wrote(r$msgs, dir)) expect_true(file.exists(p), label = paste("'Wrote:' names", p))
  expect_identical(list.files(dir, all.files = TRUE, no.. = TRUE), character())
})

test_that("review 2c #2: a read-only _weft folder is a weft_tool_error naming the schema, with no false 'Wrote:' (9.3.1, ruling 2)", {
  skip_on_os("windows")
  r2c_skip_if_root()
  dir <- c2_proj()
  dir.create(file.path(dir, "_weft"))
  Sys.chmod(file.path(dir, "_weft"), "555")
  r2c_defer_chmod(file.path(dir, "_weft"))
  r <- r2c_run(use_dictionary(dir))
  c2_expect_cond(r$err, "weft_tool_error")
  c2_expect_msg(r$err, "dict.schema.json")
  for (p in r2c_wrote(r$msgs, dir)) expect_true(file.exists(p), label = paste("'Wrote:' names", p))
})

test_that("review 2c #2: a _weft that is a regular file is a weft_tool_error naming the schema, and no schema is claimed (9.3.1, ruling 2)", {
  dir <- c2_proj(list(`_weft` = "not a folder"))
  r <- r2c_run(use_dictionary(dir))
  c2_expect_cond(r$err, "weft_tool_error")
  c2_expect_msg(r$err, "dict.schema.json")
  for (p in r2c_wrote(r$msgs, dir)) expect_true(file.exists(p), label = paste("'Wrote:' names", p))
  expect_true(file.exists(file.path(dir, "_weft")) && !dir.exists(file.path(dir, "_weft")))
})

test_that("review 2c #2: control - in a writable folder 'Wrote:' names two files that exist and the call returns them (9.3.1)", {
  dir <- c2_proj()
  r <- r2c_run(use_dictionary(dir))
  expect_null(r$err)
  expect_identical(r$value, c("dict.yml", "_weft/dict.schema.json"))
  for (p in r2c_wrote(r$msgs, dir)) expect_true(file.exists(p))
  expect_length(r2c_wrote(r$msgs, dir), 2L)
})

# ---- 3, B: avoid spellings Vale cannot match -----------------------------------------------------

R2C_DEAD <- c("approx.", "e.g.", "(v2) code", "say \"x\"", "- dash", "{brace}", "[sq]", "`tick`")

test_that("review 2c #3: an avoid spelling that starts or ends with a character that is not a letter or digit is a read_dict() problem (4.7.4, ruling 3, B)", {
  for (s in R2C_DEAD) {
    lines <- sprintf("a: {value: Canon, type: string, definition: x, avoid: ['%s']}", s)
    r <- c2_read_err(lines)
    c2_expect_cond(r$err, "weft_dict_error")
    c2_expect_msg(r$err, "`a`", "avoid", "(rule 4.7.4)")
    expect_true(grepl(s, c2_msg(r$err), fixed = TRUE), label = paste("the message names", s))
  }
})

test_that("review 2c #3: a spelling is checked at both ends, and each bad one in a list is reported (4.7.4, ruling 3)", {
  r <- c2_read_err("a: {value: Canon, type: string, definition: x, avoid: ['ok one', 'lead.', '.trail']}")
  c2_expect_cond(r$err, "weft_dict_error")
  c2_expect_msg(r$err, "lead.", ".trail")
  expect_false(grepl("`ok one`", c2_msg(r$err), fixed = TRUE))
})

test_that("review 2c #3: control - spellings with inner punctuation or a digit at the edge are read (4.7.4)", {
  d <- c2_dict(c("a: {value: Canon, type: string, definition: x, avoid: ['Nth. catchment', 'it is #1', 'min-size 2']}"))
  expect_s3_class(d, "weft_dict")
})

# ---- 4: a project path with glob characters ---------------------------------------------------------

test_that("review 2c #4: the glob resolver finds the record when the project path holds [ ] * { } (4.5.2, ruling 4)", {
  for (nm in c("proj1", "proj[1]", "proj]", "proj*", "proj{a,b}")) {
    base <- c2_proj()
    proj <- file.path(base, nm)
    dir.create(file.path(proj, "decisions"), recursive = TRUE)
    writeLines("Core.", file.path(proj, "decisions", "12-core.md"))
    writeLines("a: {value: 1, type: number, definition: \"Fine.\", decision: 12}", file.path(proj, "dict.yml"))
    d <- read_dict(file.path(proj, "dict.yml"))
    r <- weft:::check_decisions(d, resolver = "decisions/{id}-*.md", root = proj)
    expect_identical(r$resolved, TRUE, label = nm)
    expect_identical(r$detail, "decisions/12-core.md", label = nm)
  }
})

# ---- 5, J: the glossary ends with a blank line, and keeps a definition's paragraphs ---------------

test_that("review 2c #5: the glossary string ends with a blank line so text after its chunk stays out of the last entry (4.7.1, ruling 5)", {
  d <- c2_dict(c("a: {value: 1, type: number, definition: One.}", "b: {value: 2, type: number, definition: Two.}"))
  s <- as.character(dict_glossary(d))
  expect_true(startsWith(s, "\n`a` (1)\n:   One.\n\n`b` (2)\n:   Two."))
  expect_true(endsWith(s, "\n\n"), label = "the string ends with a blank line")
  expect_false(endsWith(s, "\n\n\n"))
})

test_that("review 2c #5: the glossary of an empty dictionary is still empty (4.7.1)", {
  d <- c2_dict(character())
  expect_identical(as.character(dict_glossary(d)), "")
})

test_that("review 2c #J: a definition with a blank line keeps its paragraphs, the later ones indented four spaces (4.7.1, ruling 5, J)", {
  d <- c2_dict(c("a: {value: 1, type: number, definition: \"First paragraph.\\n\\nSecond paragraph.\"}",
                 "b: {value: 2, type: number, definition: \"One\\nline.\"}"))
  s <- as.character(dict_glossary(d))
  expect_true(grepl("`a` (1)\n:   First paragraph.\n\n    Second paragraph.\n\n`b` (2)", s, fixed = TRUE), label = s)
  expect_true(grepl("`b` (2)\n:   One line.", s, fixed = TRUE), label = "a single-paragraph definition is still one line")
})

# ---- 6, I: term ---------------------------------------------------------------------------------------

test_that("review 2c #6: a term written as a block scalar is trimmed, in the dictionary, the glossary and the Vale rule (4.7.3, ruling 6)", {
  dir <- r2c_vale_proj(list(dict.yml = c(
    "a:", "  value: 5", "  type: number", "  term: >", "    minimum", "    sample size",
    "  definition: d", "  avoid: [min size]")))
  d <- read_dict(file.path(dir, "dict.yml"))
  expect_identical(attr(d, "entries")$term, "minimum sample size")
  expect_true(startsWith(as.character(dict_glossary(d)), "\nminimum sample size (5)\n:   d"))
  suppressMessages(dict_vale())
  rule <- readLines(file.path(dir, "styles", "Weft", "Terms.yml"), warn = FALSE)
  expect_identical(rule[length(rule)], "  'min size': 'minimum sample size'")
})

test_that("review 2c #6: a term with surrounding spaces is trimmed, so an avoid equal to it is the own-spelling problem (4.7.3, 4.7.4, ruling 6)", {
  r <- c2_read_err(c("a: {value: 1, type: number, term: 'sample size ', avoid: [sample size], definition: x}"))
  c2_expect_cond(r$err, "weft_dict_error")
  c2_expect_msg(r$err, "`avoid` lists `sample size`, which is the entry's own spelling (rule 4.7.4)")
  d <- c2_dict("a: {value: 1, type: number, term: ' sample size ', definition: x}")
  expect_identical(attr(d, "entries")$term, "sample size")
})

test_that("review 2c #6: a term that holds a line break is a read_dict() problem (4.7.3, ruling 6)", {
  r <- c2_read_err("a: {value: 1, type: number, term: \"two\\nlines\", definition: x}")
  c2_expect_cond(r$err, "weft_dict_error")
  c2_expect_msg(r$err, "`a`", "term")
})

test_that("review 2c #6: a string canonical spelling with a line break never reaches the Vale rule as a newline (4.7.2, ruling 6)", {
  dir <- r2c_vale_proj(list(dict.yml = c(
    "a: {value: \"Northern\\ncatchment\\n\", type: string, definition: d, avoid: [nc]}")))
  r <- r2c_run(dict_vale())
  if (!is.null(r$err)) {
    c2_expect_cond(r$err, "weft_dict_error")
  } else {
    rule <- readLines(file.path(dir, "styles", "Weft", "Terms.yml"), warn = FALSE)
    expect_identical(rule[length(rule)], "  'nc': 'Northern catchment'")
  }
})

test_that("review 2c #I: a term that starts with a markdown block marker is a read_dict() problem (4.7.3, ruling 6, I)", {
  for (t in c("# Heading?", "> quote", "- item", "* item", ": definition", "1. item")) {
    r <- c2_read_err(sprintf("a: {value: 1, type: number, term: '%s', definition: x}", t))
    c2_expect_cond(r$err, "weft_dict_error")
    c2_expect_msg(r$err, "`a`", "term")
  }
})

test_that("review 2c #I: control - terms with a marker character inside, or a digit not followed by a full stop, are read (4.7.3)", {
  d <- c2_dict(c("a: {value: 1, type: number, term: 'sample-size #2', definition: x}",
                 "b: {value: 1, type: number, term: '2 samples', definition: x}"))
  expect_identical(attr(d, "entries")$term, c("sample-size #2", "2 samples"))
})

# ---- 7, F: decision pointers never changed silently ------------------------------------------------------

test_that("review 2c #7: a decision past the integer range is a row that does not resolve, with its reason, and is not dropped (4.5.3, ruling 7)", {
  c2_no_token()
  x <- r2c_dict(c("a: {value: 1, type: number, decision: 99999999999, definition: x}"))
  r <- r2c_chk(x, resolver = "github:example/proj", fetch = c2_no_fetch())
  expect_identical(nrow(r), 1L)
  expect_identical(r$key, "a")
  expect_identical(r$decision, "99999999999")
  expect_identical(r$resolved, FALSE)
  expect_false(startsWith(r$detail, "could not check: "))
  expect_true(nzchar(r$detail))
})

test_that("review 2c #7: decisions written 012, 0x1F or 1e3 keep their text and do not resolve, with the reason, and no request (4.5.3, ruling 7)", {
  c2_no_token()
  x <- r2c_dict(c("a: {value: 1, type: number, decision: 012, definition: x}",
                  "b: {value: 1, type: number, decision: 0x1F, definition: x}",
                  "c: {value: 1, type: number, decision: 1e3, definition: x}"))
  r <- r2c_chk(x, resolver = "github:example/proj", fetch = c2_no_fetch())
  expect_identical(r$key, c("a", "b", "c"))
  expect_identical(r$decision, c("012", "0x1F", "1e3"))
  expect_identical(r$resolved, c(FALSE, FALSE, FALSE))
  for (i in 1:3) expect_true(grepl(sprintf("`%s`", r$decision[i]), r$detail[i], fixed = TRUE))
})

test_that("review 2c #F: decision \"#12\" is read as the issue number 12 under the GitHub route (4.5.3, ruling 7, F)", {
  c2_no_token()
  x <- r2c_dict("a: {value: 1, type: number, decision: '#12', definition: x}")
  expect_identical(attr(x$dict, "entries")$decision, "12")
  f <- c2_fetch(setNames(list(200, 200), c(R2C_REPO, paste0(R2C_REPO, "/issues/12"))))
  r <- r2c_chk(x, resolver = "github:example/proj", fetch = f$fetch)
  expect_identical(r$decision, "12")
  expect_identical(r$resolved, TRUE)
  expect_identical(f$urls(), c(R2C_REPO, paste0(R2C_REPO, "/issues/12")))
})

test_that("review 2c #7: control - a plain integer decision still resolves through the GitHub route (4.5.3)", {
  c2_no_token()
  x <- r2c_dict("a: {value: 1, type: number, decision: 12, definition: x}")
  f <- c2_fetch(setNames(list(200, 200), c(R2C_REPO, paste0(R2C_REPO, "/issues/12"))))
  r <- r2c_chk(x, resolver = "github:example/proj", fetch = f$fetch)
  expect_identical(r$resolved, TRUE)
})

# ---- 8: the schema accepts what read_dict() reads ---------------------------------------------------------

R2C_SCHEMA_CASES <- list(
  "an empty term" = "a: {value: 1, type: number, definition: x, term: }",
  "an empty avoid" = "a: {value: Alpha, type: string, definition: x, avoid: }",
  "an empty display on a quantity" = "a: {value: 1, type: quantity, unit: m, display: , definition: x}",
  "an empty decision" = "a: {value: 1, type: number, definition: x, decision: }",
  "a null unit on a number" = "a: {value: 1, type: number, unit: ~, definition: x}",
  "an empty display on a number" = "a: {value: 1, type: number, display: , definition: x}",
  "an empty why" = "a: {value: 1, type: number, definition: x, why: }",
  "a one-item list as definition" = "a: {value: 1, type: number, definition: [d]}",
  "a one-item list as term" = "a: {value: 1, type: number, definition: x, term: [the a]}",
  "a one-item list as decision" = "a: {value: 1, type: number, definition: x, decision: [12]}",
  "a one-item list as unit" = "a: {value: 1, type: quantity, unit: [m], definition: x}",
  "a one-item list as display" = "a: {value: 5, type: quantity, unit: m, display: [cm], definition: x}",
  "a one-item list as a number's value" = "a: {value: [5], type: number, definition: x}"
)

for (nm in names(R2C_SCHEMA_CASES)) {
  local({
    nm <- nm
    lines <- R2C_SCHEMA_CASES[[nm]]
    test_that(sprintf("review 2c #8: the schema accepts what read_dict() reads: %s (C19, ruling 8)", nm), {
      skip_if_not_installed("jsonlite")
      dir <- c2_proj(list(dict.yml = lines))
      expect_s3_class(suppressWarnings(read_dict(file.path(dir, "dict.yml"))), "weft_dict")
      expect_identical(schema_errors(lines), character())
    })
  })
}

test_that("review 2c #8: the schema's text pattern, read as Unicode (as an editor's validator does), accepts a definition of one no-break space that read_dict() reads (C19, ruling 8)", {
  skip_if_not_installed("jsonlite")
  lines <- "a: {value: 1, type: number, definition: \"\\u00a0\"}"
  dir <- c2_proj(list(dict.yml = lines))
  expect_s3_class(suppressWarnings(read_dict(file.path(dir, "dict.yml"))), "weft_dict")
  p <- schema_load()$definitions$text$pattern
  if (!is.null(p)) expect_true(grepl(paste0("(*UCP)", p), "\u00a0", perl = TRUE), label = paste("pattern", p))
})

test_that("review 2c #8: control - the schema still refuses an entry with no type (C19)", {
  skip_if_not_installed("jsonlite")
  expect_true(length(schema_errors("a: {value: 1, definition: x}")) > 0)
  expect_identical(schema_errors("a: {value: 1, type: number, definition: x}"), character())
})

# ---- 9: dict_vale() and another dictionary ---------------------------------------------------------------------

test_that("review 2c #9: dict_vale() given another dictionary with no spellings neither writes nor removes the project's rule (4.7.2, ruling 9)", {
  dir <- r2c_vale_proj(list(`other.yml` = "a: {value: 1, type: number, definition: x}"))
  suppressMessages(dict_vale())
  rule <- file.path(dir, "styles", "Weft", "Terms.yml")
  expect_true(file.exists(rule))
  before <- c2_bytes(rule)
  other <- read_dict(file.path(dir, "other.yml"))
  r <- r2c_run(dict_vale(other))
  expect_null(r$err)
  expect_true(file.exists(rule), label = "the project's rule is still there")
  if (file.exists(rule)) expect_identical(c2_bytes(rule), before)
  expect_false(any(grepl("remove|Removed", r$msgs)))
})

test_that("review 2c #9: control - dict_vale() of the project's own dictionary with no spellings removes the rule it generated (4.7.2)", {
  dir <- r2c_vale_proj()
  suppressMessages(dict_vale())
  rule <- file.path(dir, "styles", "Weft", "Terms.yml")
  expect_true(file.exists(rule))
  writeLines("a: {value: 1, type: number, definition: x}", file.path(dir, "dict.yml"))
  r <- r2c_run(dict_vale())
  expect_null(r$err)
  expect_false(file.exists(rule))
  expect_true(any(grepl("^Removed: ", r$msgs)))
})

# ---- 10: a fetch that throws or returns rubbish ------------------------------------------------------------------

test_that("review 2c #10: a fetch that throws on an issue call gives 'could not check' rows and no further call (4.5.4, ruling 10)", {
  c2_no_token()
  x <- c2_decision_dict(list(12, 13))
  f <- r2c_fetch(issue = function(url) stop("boom while fetching"))
  r <- NULL
  expect_no_error(r <- weft:::check_decisions(x$dict, root = x$root, resolver = "github:example/proj", fetch = f$fetch))
  expect_identical(r$resolved, c(NA, NA))
  expect_true(all(startsWith(r$detail, "could not check: ")))
  expect_identical(f$n(), 2L)
})

test_that("review 2c #10: a fetch that throws on the repository call gives 'could not check' rows after one call (4.5.4, ruling 10)", {
  c2_no_token()
  x <- c2_decision_dict(list(12, 13))
  f <- r2c_fetch(repo = function(url) stop("boom"))
  r <- NULL
  expect_no_error(r <- weft:::check_decisions(x$dict, root = x$root, resolver = "github:example/proj", fetch = f$fetch))
  expect_identical(r$resolved, c(NA, NA))
  expect_true(all(startsWith(r$detail, "could not check: ")))
  expect_identical(f$n(), 1L)
})

test_that("review 2c #10: a fetch that returns a malformed value gives 'could not check' rows (4.5.4, ruling 10)", {
  c2_no_token()
  x <- c2_decision_dict(list(12, 13))
  for (bad in list(list(error = NULL), list(status = c(200L, 404L), error = NULL), 200L)) {
    f <- r2c_fetch(issue = bad)
    r <- NULL
    expect_no_error(r <- weft:::check_decisions(x$dict, root = x$root, resolver = "github:example/proj", fetch = f$fetch))
    expect_identical(r$resolved, c(NA, NA))
    expect_true(all(startsWith(r$detail, "could not check: ")))
    expect_identical(f$n(), 2L)
  }
})

test_that("review 2c #10: control - a fetch that answers normally gives TRUE rows (4.5.3)", {
  c2_no_token()
  x <- c2_decision_dict(list(12, 13))
  f <- r2c_fetch()
  r <- weft:::check_decisions(x$dict, root = x$root, resolver = "github:example/proj", fetch = f$fetch)
  expect_identical(r$resolved, c(TRUE, TRUE))
  expect_identical(f$n(), 3L)
})

# ---- 11: a folder where a file is wanted --------------------------------------------------------------------------

test_that("review 2c #11: use_dictionary() with a folder named dict.yml is a weft_tool_error naming it, not a base R error (9.3.1, ruling 2)", {
  dir <- c2_proj()
  dir.create(file.path(dir, "dict.yml"))
  r <- r2c_run(use_dictionary(dir))
  c2_expect_cond(r$err, "weft_tool_error")
  c2_expect_msg(r$err, "dict.yml")
})

test_that("review 2c #11: dict_vale() with a folder as the rule path is a weft_tool_error naming it (4.7.2, ruling 2)", {
  dir <- r2c_vale_proj()
  dir.create(file.path(dir, "styles", "Dir", "Terms.yml"), recursive = TRUE)
  r <- r2c_run(dict_vale(path = "styles/Dir/Terms.yml"))
  c2_expect_cond(r$err, "weft_tool_error")
  c2_expect_msg(r$err, "Terms.yml")
})

test_that("review 2c #11: control - dict_vale() to a new rule path still writes it (4.7.2)", {
  dir <- r2c_vale_proj()
  r <- r2c_run(dict_vale(path = "styles/Dir/Terms.yml"))
  expect_null(r$err)
  expect_true(file.exists(file.path(dir, "styles", "Dir", "Terms.yml")))
})

# ---- 12: parse_github_remote() --------------------------------------------------------------------------------------

test_that("review 2c #12: a repository name with a query or a fragment is not a GitHub remote (4.5.3, ruling 12)", {
  for (u in c("https://user@github.com/o/r?x=1", "https://github.com/o/r#frag", "https://github.com/o/r?x=1.git",
              "git@github.com:o/r#x")) {
    expect_null(weft:::parse_github_remote(u), label = u)
  }
})

test_that("review 2c #12: ssh.github.com with a port, and any letter case of github.com, are read as GitHub (4.5.3, ruling 12)", {
  want <- c(owner = "o", repo = "r")
  expect_identical(weft:::parse_github_remote("ssh://git@ssh.github.com:443/o/r.git"), want)
  expect_identical(weft:::parse_github_remote("https://GitHub.com/o/r"), want)
  expect_identical(weft:::parse_github_remote("https://GITHUB.COM/o/r.git/"), want)
})

test_that("review 2c #12: control - the documented forms and other hosts keep their reading (4.5.3)", {
  want <- c(owner = "o", repo = "r.x_y-z")
  expect_identical(weft:::parse_github_remote("https://github.com/o/r.x_y-z.git"), want)
  expect_identical(weft:::parse_github_remote("git@github.com:o/r.x_y-z"), want)
  expect_identical(weft:::parse_github_remote("ssh://git@github.com:22/o/r.x_y-z.git"), want)
  expect_null(weft:::parse_github_remote("https://example.org/o/r"))
  expect_null(weft:::parse_github_remote("https://github.com/o"))
})

# ---- 13: dict_seed() --------------------------------------------------------------------------------------------------

r2c_chunk_file <- function(header, body = "xi <- 1") c("# Doc", "", paste0("```", header), body, "```", "")

r2c_seed <- function(files, env = parent.frame()) {
  dir <- c2_proj(files, env)
  withr::local_dir(dir, .local_envir = env)
  suppressMessages(dict_seed())
}

test_that("review 2c #13: a chunk whose caption mentions eval=FALSE is read (9.5.2, finding 13)", {
  h <- "{r, fig.cap='eval=FALSE is off'}"
  r <- r2c_seed(list(a.qmd = r2c_chunk_file(h), b.qmd = r2c_chunk_file(h)))
  expect_identical(r$name, "xi")
})

test_that("review 2c #13: a chunk with `#| eval: false` and a trailing YAML comment is left out (9.5.2, finding 13)", {
  b <- c("#| eval: false  # not now", "xi <- 1")
  r <- r2c_seed(list(a.qmd = r2c_chunk_file("{r}", b), b.qmd = r2c_chunk_file("{r}", b)))
  expect_identical(nrow(r), 0L)
})

test_that("review 2c #13: a chunk of another engine is not read as R (9.5.2, finding 13)", {
  h <- "{r engine='python'}"
  r <- r2c_seed(list(a.qmd = r2c_chunk_file(h), b.qmd = r2c_chunk_file(h)))
  expect_identical(nrow(r), 0L)
})

test_that("review 2c #13: control - plain chunks, and a literal `#| eval: false`, behave as the contract says (9.5.2)", {
  r <- r2c_seed(list(a.qmd = r2c_chunk_file("{r}"), b.qmd = r2c_chunk_file("{r}")))
  expect_identical(r$name, "xi")
  skipped <- c("#| eval: false", "xi <- 1")
  r2 <- r2c_seed(list(a.qmd = r2c_chunk_file("{r}", skipped), b.qmd = r2c_chunk_file("{r}", skipped)))
  expect_identical(nrow(r2), 0L)
})

test_that("review 2c #13: a file that is not UTF-8 gives no R warnings (9.5.2, finding 13)", {
  dir <- c2_proj(list(b.qmd = r2c_chunk_file("{r}")))
  withr::local_dir(dir)
  writeBin(c(charToRaw("# Doc\n\n```{r}\nxi <- 1\nlabel <- \"caf"), as.raw(0xe9), charToRaw("\"\n```\n")),
           file.path(dir, "a.qmd"))
  expect_no_warning(suppressMessages(dict_seed()))
})

test_that("review 2c #13: a folder in `paths` is reported as what it is, not as a missing file (9.5.2, finding 13)", {
  dir <- c2_proj(list(a.qmd = r2c_chunk_file("{r}")))
  withr::local_dir(dir)
  e <- c2_err(suppressMessages(dict_seed(paths = c("a.qmd", "."))))
  c2_expect_cond(e, "weft_tool_error")
  expect_false(grepl("no such file", c2_msg(e), fixed = TRUE))
})

# ---- 14: the resolvers' scope ---------------------------------------------------------------------------------------------

test_that("review 2c #14: a glob pointer of `..` does not reach a file outside the project root (4.5.3, ruling 4)", {
  x <- c2_decision_dict(list(".."))
  outside <- file.path(dirname(x$root), "x.md")
  writeLines("outside", outside)
  withr::defer(unlink(outside))
  r <- weft:::check_decisions(x$dict, resolver = "{id}/x.md", root = x$root)
  expect_false(isTRUE(r$resolved))
})

test_that("review 2c #14: a glob pointer of `~` does not look in the home folder (4.5.3, ruling 4)", {
  home <- c2_proj(list(`x.md` = "home"))
  withr::local_envvar(HOME = home)
  x <- c2_decision_dict(list("~"))
  r <- weft:::check_decisions(x$dict, resolver = "{id}/x.md", root = x$root)
  expect_false(isTRUE(r$resolved))
})

test_that("review 2c #14: a dangling link is not a record that resolves (4.5.2, ruling 4)", {
  skip_on_os("windows")
  x <- c2_decision_dict(list(5))
  dir.create(file.path(x$root, "decisions"))
  file.symlink(file.path(x$root, "gone.md"), file.path(x$root, "decisions", "5-x.md"))
  r <- weft:::check_decisions(x$dict, resolver = "decisions/{id}-*.md", root = x$root)
  expect_false(isTRUE(r$resolved))
})

test_that("review 2c #14: control - a pointer naming a folder inside the project resolves (4.5.3)", {
  x <- c2_decision_dict(list("sub"))
  dir.create(file.path(x$root, "sub"))
  writeLines("in", file.path(x$root, "sub", "x.md"))
  r <- weft:::check_decisions(x$dict, resolver = "{id}/x.md", root = x$root)
  expect_identical(r$resolved, TRUE)
  expect_identical(r$detail, "sub/x.md")
})

test_that("review 2c #14: a bare function name is looked up in the global environment, not on the search path (4.5.3, ruling 4)", {
  x <- c2_decision_dict(list(5))
  for (fun in c("isTRUE", "file.exists", "c")) {
    e <- c2_err(weft:::check_decisions(x$dict, resolver = fun, root = x$root))
    c2_expect_cond(e, "weft_config_error")
    c2_expect_msg(e, "Cannot find the decisions function", fun, "(rule 9.1.8).")
  }
})

test_that("review 2c #14: control - a function defined in the global environment is called with the pointer (4.5.3)", {
  assign("r2c_decider", function(id) identical(id, "5"), envir = globalenv())
  withr::defer(rm("r2c_decider", envir = globalenv()))
  x <- c2_decision_dict(list(5, 6))
  r <- weft:::check_decisions(x$dict, resolver = "r2c_decider", root = x$root)
  expect_identical(r$resolved, c(TRUE, FALSE))
})

# ---- 15: messages -----------------------------------------------------------------------------------------------------------

test_that("review 2c #15: a 401 with no token does not blame a token in GITHUB_PAT (4.5.3, finding 15)", {
  c2_no_token()
  x <- c2_decision_dict(list(12))
  f <- c2_fetch(setNames(list(401), R2C_REPO))
  r <- weft:::check_decisions(x$dict, root = x$root, resolver = "github:example/proj", fetch = f$fetch)
  expect_identical(r$resolved, NA)
  expect_true(startsWith(r$detail, "could not check: "))
  expect_false(grepl("the token in", r$detail, fixed = TRUE))
})

test_that("review 2c #15: control - a 401 with a token names the variable that held it (4.5.3)", {
  c2_no_token()
  withr::local_envvar(GITHUB_PAT = "ghp_made_up_value")
  x <- c2_decision_dict(list(12))
  f <- c2_fetch(setNames(list(401), R2C_REPO))
  r <- weft:::check_decisions(x$dict, root = x$root, resolver = "github:example/proj", fetch = f$fetch)
  expect_identical(r$detail, "could not check: GitHub refused the token in GITHUB_PAT (401)")
})

test_that("review 2c #15: a function that returns NA_integer_, NULL or stops with an empty message gives a grammatical, non-empty detail (4.5.3, finding 15)", {
  assign("r2c_na_int", function(id) NA_integer_, envir = globalenv())
  assign("r2c_null", function(id) NULL, envir = globalenv())
  assign("r2c_stop", function(id) stop(""), envir = globalenv())
  withr::defer(rm(list = c("r2c_na_int", "r2c_null", "r2c_stop"), envir = globalenv()))
  x <- c2_decision_dict(list(5))
  d <- function(fun) weft:::check_decisions(x$dict, resolver = fun, root = x$root)$detail
  expect_false(grepl("a integer", d("r2c_na_int"), fixed = TRUE))
  expect_false(grepl("a NULL", d("r2c_null"), fixed = TRUE))
  expect_false(grepl("failed: $", d("r2c_stop")))
})

test_that("review 2c #15: a GitHub failure detail is one line (4.5.3, finding 15)", {
  c2_no_token()
  x <- c2_decision_dict(list(12))
  f <- c2_fetch(setNames(list(list(status = NA, error = "Could not connect to server\nFailed to connect")), R2C_REPO))
  r <- weft:::check_decisions(x$dict, root = x$root, resolver = "github:example/proj", fetch = f$fetch)
  expect_identical(r$resolved, NA)
  expect_false(grepl("\n", r$detail, fixed = TRUE))
})

# ---- 16: small things -----------------------------------------------------------------------------------------------------------

test_that("review 2c #16: the .vale.ini hint is printed when BasedOnStyles lists only Weft-old, not Weft (4.7.2, finding 16)", {
  dir <- r2c_vale_proj(list(`.vale.ini` = c("StylesPath = styles", "BasedOnStyles = Vale, Weft-old")))
  r <- r2c_run(dict_vale())
  expect_true(any(grepl("Vale uses this rule when .vale.ini", r$msgs, fixed = TRUE)))
})

test_that("review 2c #16: the .vale.ini hint is printed when Weft is listed but StylesPath is somewhere else (4.7.2, finding 16)", {
  dir <- r2c_vale_proj(list(`.vale.ini` = c("StylesPath = elsewhere", "BasedOnStyles = Vale, Weft")))
  r <- r2c_run(dict_vale())
  expect_true(any(grepl("Vale uses this rule when .vale.ini", r$msgs, fixed = TRUE)))
})

test_that("review 2c #16: control - no hint when .vale.ini lists Weft under the StylesPath used (4.7.2)", {
  dir <- r2c_vale_proj(list(`.vale.ini` = c("StylesPath = styles", "BasedOnStyles = Vale, Weft")))
  r <- r2c_run(dict_vale())
  expect_false(any(grepl("Vale uses this rule when .vale.ini", r$msgs, fixed = TRUE)))
})

test_that("review 2c #16: a rule path that climbs out of the project is refused or shown without '..' (4.7.2, finding 16)", {
  base <- c2_proj()
  root <- file.path(base, "a", "b", "proj")
  dir.create(root, recursive = TRUE)
  writeLines(c2_fixture_lines(), file.path(root, "dict.yml"))
  withr::local_dir(root)
  r <- r2c_run(dict_vale(path = "../../escaped/Weft/Terms.yml"))
  if (is.null(r$err)) {
    expect_false(any(grepl("/../", r$msgs, fixed = TRUE)), label = paste(r$msgs, collapse = " | "))
  } else {
    c2_expect_cond(r$err, "weft_tool_error")
  }
})

test_that("review 2c #16: a schema line inside a value is not the schema line (4.7.1, finding 16)", {
  dir <- c2_proj(list(dict.yml = "a: {value: 1, type: number, definition: 'see yaml-language-server: $schema=x'}"))
  r <- r2c_run(use_dictionary(dir))
  expect_null(r$err)
  expect_true(any(grepl("dict.yml has no schema line", r$msgs, fixed = TRUE)), label = paste(r$msgs, collapse = " | "))
})

# ---- L: a schema line that points elsewhere ------------------------------------------------------------------------------------------

test_that("review 2c #L: an existing dict.yml whose schema line points elsewhere gets the line to use, and is not edited (9.3.1, ruling L)", {
  lines <- c("# yaml-language-server: $schema=https://example.org/old.json",
             "a: {value: 1, type: number, definition: x}")
  dir <- c2_proj(list(dict.yml = lines))
  before <- c2_bytes(file.path(dir, "dict.yml"))
  r <- r2c_run(use_dictionary(dir))
  expect_null(r$err)
  expect_true(any(grepl("# yaml-language-server: $schema=_weft/dict.schema.json", r$msgs, fixed = TRUE)),
              label = paste(r$msgs, collapse = " | "))
  expect_identical(c2_bytes(file.path(dir, "dict.yml")), before)
})

test_that("review 2c #L: control - a dict.yml with the right schema line gets no schema message (9.3.1)", {
  lines <- c("# yaml-language-server: $schema=_weft/dict.schema.json",
             "a: {value: 1, type: number, definition: x}")
  dir <- c2_proj(list(dict.yml = lines))
  r <- r2c_run(use_dictionary(dir))
  expect_null(r$err)
  expect_false(any(grepl("$schema=", r$msgs, fixed = TRUE)))
  expect_false(any(grepl("no schema line", r$msgs, fixed = TRUE)))
})

# ---- D: 410 ----------------------------------------------------------------------------------------------------------------------------------

test_that("review 2c #D: an issue answered 410 (issues are off, as in a fork) is 'could not check', never 'does not resolve' (4.5.3, ruling D)", {
  c2_no_token()
  x <- c2_decision_dict(list(12))
  f <- c2_fetch(setNames(list(200, 410), c(R2C_REPO, paste0(R2C_REPO, "/issues/12"))))
  r <- weft:::check_decisions(x$dict, root = x$root, resolver = "github:example/proj", fetch = f$fetch)
  expect_identical(r$resolved, NA)
  expect_true(startsWith(r$detail, "could not check: "))
})

test_that("review 2c #D: control - an issue answered 404 is still FALSE (4.5.3)", {
  c2_no_token()
  x <- c2_decision_dict(list(12))
  f <- c2_fetch(setNames(list(200, 404), c(R2C_REPO, paste0(R2C_REPO, "/issues/12"))))
  r <- weft:::check_decisions(x$dict, root = x$root, resolver = "github:example/proj", fetch = f$fetch)
  expect_identical(r$resolved, FALSE)
  expect_identical(r$detail, "example/proj has no issue or pull request #12")
})

# ---- E: a remote that belongs to another project ----------------------------------------------------------------------------------------------

r2c_repo_project <- function(sub = NULL, env = parent.frame()) {
  skip_if(!nzchar(Sys.which("git")), "git is not installed")
  repo <- c2_git_repo("https://github.com/example/proj.git", env)
  root <- if (is.null(sub)) repo else file.path(repo, sub)
  dir.create(root, showWarnings = FALSE, recursive = TRUE)
  writeLines("a: {value: 1, type: number, definition: \"Fine.\", decision: 12}", file.path(root, "dict.yml"))
  list(dict = read_dict(file.path(root, "dict.yml")), root = normalizePath(root))
}

test_that("review 2c #E: a project inside another repository does not use that repository's origin (4.5.3, ruling E)", {
  c2_no_token()
  x <- r2c_repo_project("sub")
  r <- weft:::check_decisions(x$dict, root = x$root, resolver = "github", fetch = c2_no_fetch())
  expect_identical(r$resolved, NA)
  expect_true(startsWith(r$detail, "could not check: "))
  expect_true(grepl("github:<owner>/<repo>", r$detail, fixed = TRUE))
})

test_that("review 2c #E: control - a project at the top level of its repository uses the origin (4.5.3)", {
  c2_no_token()
  x <- r2c_repo_project()
  f <- c2_fetch(setNames(list(200, 200), c(R2C_REPO, paste0(R2C_REPO, "/issues/12"))))
  r <- weft:::check_decisions(x$dict, root = x$root, resolver = "github", fetch = f$fetch)
  expect_identical(r$resolved, TRUE)
})

# ---- G: the glossary outside a knit reads _weft.yml ------------------------------------------------------------------------------------------------

test_that("review 2c #G: outside a knit the glossary uses the decimal mark of the project's _weft.yml (4.7.1, ruling G)", {
  dir <- c2_proj(list(
    dict.yml = c("a: {value: 12345.5, type: number, definition: x}",
                 "b: {value: 0.5, type: quantity, unit: m, definition: y}"),
    `_weft.yml` = "decimal_mark: ','"))
  withr::local_dir(dir)
  expect_identical(as.character(dict_glossary()), c2("\n`a` (12.345,5)\n:   x\n\n`b` (0,5~m)\n:   y\n\n"))
})

test_that("review 2c #G: control - with no _weft.yml the glossary prints with the defaults (4.7.1)", {
  dir <- c2_proj(list(dict.yml = c("a: {value: 12345.5, type: number, definition: x}",
                                   "b: {value: 0.5, type: quantity, unit: m, definition: y}")))
  withr::local_dir(dir)
  expect_true(startsWith(as.character(dict_glossary()), c2("\n`a` (12,345.5)\n:   x\n\n`b` (0.5~m)\n:   y")))
})

# ---- H: decimals --------------------------------------------------------------------------------------------------------------------------------------------

test_that("review 2c #H: a value prints with the decimals it was written with (4.7.1, ruling H)", {
  d <- c2_dict(c("a: {value: 0.50, type: quantity, unit: m, definition: x}",
                 "b: {value: 0.50, type: number, definition: y}"))
  s <- as.character(dict_glossary(d))
  expect_true(grepl(c2("`a` (0.50~m)\n"), s, fixed = TRUE), label = s)
  expect_true(grepl("`b` (0.50)\n", s, fixed = TRUE), label = s)
})

test_that("review 2c #H: a value converted by display prints as fmt_num() prints it, not with fifteen digits (4.7.1, ruling H)", {
  d <- c2_dict("a: {value: 1, type: quantity, unit: m, display: ft, definition: x}")
  s <- as.character(dict_glossary(d))
  expect_true(grepl(c2("`a` (3.3~ft)\n"), s, fixed = TRUE), label = s)
})

test_that("review 2c #H: control - a value written with the decimals it has prints as written (4.7.1)", {
  d <- c2_dict(c("a: {value: 2.5, type: quantity, unit: m, definition: x}", "b: {value: 5, type: number, definition: y}"))
  s <- as.character(dict_glossary(d))
  expect_true(grepl(c2("`a` (2.5~m)\n"), s, fixed = TRUE))
  expect_true(grepl("`b` (5)\n", s, fixed = TRUE))
})
