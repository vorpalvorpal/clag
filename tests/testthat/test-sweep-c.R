# Sweep package C (dev/refactor-sweep.md): gmatch() on a UTF-8 document (C1), the error paths of the project
# rules in lints() (C3), code_pieces() and the E4 text (C4), dead helpers (C5), and the rule cited by E73 and E75.

# ---- C1: gmatch() equals a plain gregexpr() ----------------------------------------------------------------

# This is today's gmatch(), copied here as the reference. The equivalence tests below PASS TODAY BY CONSTRUCTION
# (the package's body is this body); they are the guard for the rewrite of gmatch(), which must not move a single
# offset.
gmatch_ref <- function(pat, x) {
  m <- gregexpr(pat, x, perl = TRUE)[[1L]]
  if (m[1L] == -1L) return(list(s = integer(), e = integer(), cs = NULL))
  ml <- attr(m, "match.length")
  list(s = as.integer(m), e = as.integer(m) + ml - 1L,
       cs = attr(m, "capture.start"))
}

# The first argument of every gmatch() call in the body of mask_prose(): a named constant is looked up in the
# namespace, a literal is taken as it stands, and anything else is returned as a call so the test can fail on it.
sweep_mask_patterns <- function() {
  found <- list()
  walk <- function(e) {
    if (!is.call(e)) return(invisible())
    if (identical(e[[1L]], quote(gmatch))) found[[length(found) + 1L]] <<- e[[2L]]
    for (i in seq_along(e)) {
      el <- tryCatch(e[[i]], error = function(cnd) NULL)      # an empty argument is a missing symbol
      if (tryCatch(is.call(el), error = function(cnd) FALSE)) walk(el)
    }
    invisible()
  }
  walk(body(weft:::mask_prose))
  lapply(found, function(a) {
    if (is.character(a)) a
    else if (is.symbol(a)) get(as.character(a), envir = asNamespace("weft"))
    else a
  })
}

# The syntax fixture documents the suite already has: the `src` of every row of test-syntax-fixtures.R. Its
# top-level definitions (not its test_that() blocks) are evaluated here to get the rows.
sweep_fixture_docs <- function() {
  f <- test_path("test-syntax-fixtures.R")
  exprs <- parse(f, encoding = "UTF-8", keep.source = FALSE)
  env <- new.env(parent = globalenv())
  for (e in exprs) {
    if (is.call(e) && identical(e[[1L]], quote(test_that))) break
    eval(e, env)
  }
  rows <- c(get("OK_ROWS", env), get("BAD_ROWS", env))
  vapply(rows, function(r) paste(r$src, collapse = "\n"), "")
}

# A few thousand characters: 2-, 3- and 4-byte characters, combining marks, CRLF, and the constructs of the
# masking pass written next to non-ASCII letters.
sweep_utf8_doc <- function(n = 40L) {
  unit <- c(
    "Caf\u00e9 na\u00efve \u00fcber \u00e9`r x`\u00e9 and `r y`{.num} m.",
    "\u4e2d\u6587 \u20ac \u2013 dash [a | b]{if=\"k\"}\u00e9 [a site | # sites]{n=\"zk\"} here.",
    "Emoji \U0001F600 and \U0001D538 then e\u0301 e\u0301 plain words follow.",
    "Maths \u00e9$x_1 + \\alpha$\u00e9 and $$y = \\beta\u00b2$$ \u00e9 done.",
    "```{r}", "z <- \"\u00e9\"; w <- 'caf\u00e9'", "```",
    "A [link](http://x.org/\u00e9) and a footnote[^1] with <!-- a\u00e9\nb --> comment.",
    "[^1]: Note \u00e9 text.",
    "## Heading \u00e9 {#sec-a .cls}",
    "\\emph{caf\u00e9}[opt] and \\* and \\# escapes \u4e2d.",
    "    indented \u00e9 code", "")
  paste(rep(paste0(unit, collapse = "\r\n"), n), collapse = "\r\n")
}

sweep_utf8_texts <- function() {
  docs <- sweep_fixture_docs()
  c(list(generated = sweep_utf8_doc()), as.list(docs[!is.na(docs) & nzchar(docs)]))   # mask_prose() never matches on ""
}

test_that("C1 guard: the patterns of mask_prose() were found, each a character string", {
  pats <- sweep_mask_patterns()
  expect_gte(length(pats), 11L)
  expect_true(all(vapply(pats, function(p) is.character(p) && length(p) == 1L, NA)),
              label = "every first argument resolved to a string")
})

test_that("C1 guard: gmatch() gives the offsets of a plain gregexpr(perl = TRUE) for every pattern of mask_prose()", {
  pats <- sweep_mask_patterns()
  texts <- sweep_utf8_texts()
  expect_gt(length(texts), 20L)
  expect_true(any(vapply(texts, function(t) nchar(t, "bytes") > nchar(t), NA)))
  total <- 0L
  for (p in pats) for (i in seq_along(texts)) {
    got <- weft:::gmatch(p, texts[[i]])
    want <- gmatch_ref(p, texts[[i]])
    lab <- paste0("pattern ", p, " on text ", i)
    expect_identical(got$s, want$s, label = lab)
    expect_identical(got$e, want$e, label = lab)
    expect_identical(is.null(got$cs), is.null(want$cs), label = lab)
    if (!is.null(want$cs)) {
      expect_identical(dim(got$cs), dim(want$cs), label = lab)
      expect_identical(as.integer(got$cs), as.integer(want$cs), label = lab)
    }
    total <- total + length(want$s)
  }
  expect_gt(total, 200L)   # the guard compares real matches
})

test_that("C1 guard: a pattern with captures and one that does not match behave as the reference does", {
  x <- paste0("caf\u00e9 [a | b]{if=\"k\"} \U0001F600 [c]{n=\"z\"} e\u0301 tail")
  p <- "\\[([^|\\]]*)(?:\\|([^\\]]*))?\\]\\{(if|n)=\"([^\"]*)\"\\}"
  got <- weft:::gmatch(p, x)
  want <- gmatch_ref(p, x)
  expect_gt(length(want$s), 1L)
  expect_identical(got$s, want$s)
  expect_identical(got$e, want$e)
  expect_identical(as.integer(got$cs), as.integer(want$cs))
  none <- weft:::gmatch("ZZZ[0-9]+", x)
  expect_identical(none$s, integer())
  expect_identical(none$e, integer())
  expect_null(none$cs)
})

# ---- C1: the gain ------------------------------------------------------------------------------------------

# On a non-ASCII UTF-8 string R turns each match's byte offset into a character offset from the start of the
# string, so the cost grows with matches x length. Measured once before the change (processor time, 20,000
# matches in about 370,000 characters): 12.8 s. The budget is 0.5 s, about a twenty-fifth of that, and a
# tenth would be under the floor.
test_that("C1 gain: 20,000 matches of [A-Za-z]+ in a non-ASCII text take under half a second", {
  skip_on_cran()
  unit <- paste0("ab \u00e9 caf\u00e9 ", strrep("\u4e2d\u6587", 20L), " x, ")   # three matches, no ASCII letter in the filler
  x <- paste(rep(unit, 6667L), collapse = "")
  expect_gt(nchar(x, "bytes"), nchar(x))
  got <- NULL
  elapsed <- cpu_time(got <- weft:::gmatch("[A-Za-z]+", x))
  expect_length(got$s, 20001L)
  expect_lt(elapsed, 0.5)
})

# ---- C3: project-scope rules and an R fault ---------------------------------------------------------------

c3_bad_front <- c("---", "title: B", "weft:", "  claim_cap: 0", "---", "", "Text with @sec-a and more.")
c3_good <- c("---", "title: A", "---", "", "## Heading {#sec-a}", "", "Words.")

test_that("C3: a project rule names the invalid setting of a document's weft: block, not 'could not be read'", {
  root <- lint_proj(list("a.qmd" = c3_good, "b.qmd" = c3_bad_front))
  x <- tryCatch(lints(root, files = "a.qmd", rules = "xref", tier = 1:2), error = function(e) e)
  expect_false(inherits(x, "error"), label = "a project rule over a good document does not stop on the other")
  notes <- attr(x, "notes")
  expect_false(any(grepl("could not be read", notes, fixed = TRUE)), label = paste(notes, collapse = " | "))
  expect_true(any(grepl("claim_cap", notes, fixed = TRUE)), label = paste(notes, collapse = " | "))
  expect_true(any(grepl("b.qmd", notes, fixed = TRUE)), label = paste(notes, collapse = " | "))
})

test_that("C3: the anchor-twice rule gives the same note", {
  root <- lint_proj(list("a.qmd" = c3_good, "b.qmd" = c3_bad_front))
  for (rule in c("anchor-twice")) {
    x <- tryCatch(lints(root, files = "a.qmd", rules = rule, tier = 1:2), error = function(e) e)
    expect_false(inherits(x, "error"), label = rule)
    notes <- attr(x, "notes")
    expect_false(any(grepl("could not be read", notes, fixed = TRUE)), label = rule)
    expect_true(any(grepl("claim_cap", notes, fixed = TRUE)), label = paste(rule, paste(notes, collapse = " | ")))
  }
})

test_that("C3: a fault in the reader that is not a configuration or YAML error is raised, not turned into a note", {
  root <- lint_proj(list("a.qmd" = c3_good, "b.qmd" = c("Plain text.")))
  real <- weft:::lint_open
  local_mocked_bindings(lint_open = function(root, rel) {
    if (identical(rel, "b.qmd")) stop("a bug in the reader", call. = FALSE)
    real(root, rel)
  }, .package = "weft")
  expect_error(lints(root, files = "a.qmd", rules = "xref", tier = 1:2), "a bug in the reader")
})

# ---- C4: code_pieces() decides from the value, not from the text of E4 -------------------------------------

test_that("C4: with E4 reworded, a condition of two literals is still reported once and not by a second lint", {
  real <- weft:::cond_part_error
  local_mocked_bindings(cond_part_error = function(part) {
    sub("compares two literals", "is a comparison of constants", real(part), fixed = TRUE)
  }, .package = "weft")
  doc <- c("---", "title: T", "---", "", "Intro.", "", "The [a | b]{if=\"3 > 2\"} here.")
  all <- lint_fixture(list("a.qmd" = doc), rules = NULL, tier = 1:2)
  con <- all[all$rule == "construct", , drop = FALSE]
  expect_identical(sum(grepl("3 > 2", con$message, fixed = TRUE)), 1L)
  expect_true(any(grepl("is a comparison of constants", con$message, fixed = TRUE)), label = "the mock took effect")
  for (rule in c("literal-value", "inert-check", "value-constant", "value-format")) {
    expect_identical(sum(all$rule == rule), 0L, label = rule)
  }
})

# ---- C5: dead helpers are gone ------------------------------------------------------------------------------

test_that("C5: dl_empty, isFALSE_vec, lc_find and parse_col_chars are not objects in the weft namespace", {
  for (nm in c("dl_empty", "isFALSE_vec", "lc_find", "parse_col_chars")) {
    expect_false(exists(nm, envir = asNamespace("weft"), inherits = FALSE), label = nm)
  }
})

# ---- the rule E73 and E75 cite is 1.12.8 --------------------------------------------------------------------

test_that("E73 cites rule 1.12.8", {
  doc <- c("---", "title: T", "---", "", "Words [a site]{if=\"a && ok\"} more.", "", "```{python}", "x = 1", "```")
  x <- lint_fixture(list("a.qmd" = doc), rules = "engine", tier = 1:2)
  expect_identical(nrow(x), 1L)
  expect_true(grepl("Or write each value as a name", x$hint, fixed = TRUE), label = x$hint)
  expect_true(grepl("1.12.8", x$hint, fixed = TRUE), label = x$hint)
  expect_false(grepl("1.12.7", x$hint, fixed = TRUE), label = x$hint)
})

test_that("E75 cites rule 1.12.8", {
  script <- system.file("quarto", "weft-pre-render.R", package = "weft")
  if (!expect_precondition(nzchar(script) && file.exists(script), "the package ships its pre-render script")) return()
  root <- lint_proj(list("a.qmd" = c("---", "title: t", "---", "", "The `depth`{.num} metres."),
                         "_quarto.yml" = c("project:", "  type: default", "format: html")))
  withr::local_envvar(c(QUARTO_PROJECT_INPUT_FILES = NA, WEFT_RUN = NA))
  out <- suppressWarnings(withr::with_dir(root, system2(file.path(R.home("bin"), "Rscript"), shQuote(script),
                                                         stdout = TRUE, stderr = TRUE)))
  log <- paste(out, collapse = "\n")
  expect_true(grepl("A document on another engine can use named values instead", log, fixed = TRUE), label = log)
  expect_true(grepl("(rule 1.12.8)", log, fixed = TRUE), label = log)
  expect_false(grepl("1.12.7", log, fixed = TRUE), label = log)
})
