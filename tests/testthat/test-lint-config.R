# Package 3a: the L8 configuration keys, validate_lint_config(), lint_config(), claim_lexicon().
# Contract: dev/design-3.md L4, L8, L8a, L14. Helpers: helper-3.R, helper-2f.R.

L8_KEYS <- c("label_words", "numeral_years", "claim_words", "claim_cap",
             "guard_words", "expected_names")

# an empty project's merged config through read_config(), as the knit sees it
rc <- function(yml = NULL, front = list(), env = parent.frame()) {
  withr::local_envvar(WEFT_DRAFT = NA, .local_envir = env)
  weft:::read_config(f2_proj(yml, env = env), front = front)
}

# the condition from read_config() with _weft.yml lines
rc_err <- function(yml, front = list()) {
  withr::local_envvar(WEFT_DRAFT = NA)
  f2_cond(weft:::read_config(f2_proj(yml), front = front))
}

# the condition from lints() over a project whose _weft.yml has `yml`
ln_err_yml <- function(yml) {
  root <- lint_proj(list("a.qmd" = "Plain."), weft_yml = yml)
  f2_cond(lints(root))
}

# the condition from lints() over a document whose front matter weft: has `lines`
ln_err_front <- function(lines) {
  doc <- c("---", "title: T", "weft:", paste0("  ", lines), "---", "", "Plain.")
  f2_cond(lint_one(doc))
}

len0 <- function(x) length(x) == 0L

# ---- defaults ---------------------------------------------------------------------

test_that("3a L8: default_config() holds each new key with its default", {
  d <- weft:::default_config()
  expect_true(all(L8_KEYS %in% names(d)))
  expect_true(len0(d$label_words))
  expect_identical(d$numeral_years, FALSE)
  expect_true(is.list(d$claim_words))
  expect_true(all(c("add", "drop") %in% names(d$claim_words)))
  expect_true(len0(d$claim_words$add))
  expect_true(len0(d$claim_words$drop))
  expect_equal(d$claim_cap, 20)
  expect_equal(d$guard_words, 25)
  expect_true(len0(d$expected_names))
})

test_that("3a L8: read_config() with no _weft.yml returns the defaults for the new keys", {
  x <- rc()
  expect_true(len0(x$label_words))
  expect_false(x$numeral_years)
  expect_true(len0(x$claim_words$add))
  expect_true(len0(x$claim_words$drop))
  expect_equal(x$claim_cap, 20)
  expect_equal(x$guard_words, 25)
  expect_true(len0(x$expected_names))
})

test_that("3a L8: the new keys in _weft.yml do not make a knit warn about unknown settings", {
  yml <- c("label_words: [Site, Station]", "numeral_years: true",
           "claim_words: {add: [dramatic], drop: [rose]}", "claim_cap: 5",
           "guard_words: 10", "expected_names: ['.foo', foo]")
  expect_no_warning(x <- rc(yml))
  expect_setequal(unlist(x$label_words), c("Site", "Station"))
  expect_true(x$numeral_years)
  expect_identical(unlist(x$claim_words$add), "dramatic")
  expect_identical(unlist(x$claim_words$drop), "rose")
  expect_equal(x$claim_cap, 5)
  expect_equal(x$guard_words, 10)
  expect_setequal(unlist(x$expected_names), c(".foo", "foo"))
})

test_that("3a L8: a document's weft: block overrides _weft.yml setting by setting", {
  yml <- c("label_words: [Site]", "claim_cap: 5", "guard_words: 10")
  x <- rc(yml, front = list(claim_cap = 7, numeral_years = TRUE))
  expect_equal(x$claim_cap, 7)
  expect_true(x$numeral_years)
  expect_equal(x$guard_words, 10)
  expect_identical(unlist(x$label_words), "Site")
})

# ---- the refusals: each key, each message, both routes -------------------------------

# value written as YAML, the message pieces that must appear
BAD_L8 <- list(
  list(key = "label_words",    yml = "label_words: [Site 3]",
       msg = "must be a list of words without spaces (rule 5.2.4)"),
  list(key = "label_words",    yml = "label_words: 5",
       msg = "must be a list of words without spaces (rule 5.2.4)"),
  list(key = "label_words",    yml = "label_words: {a: 1}",
       msg = "must be a list of words without spaces (rule 5.2.4)"),
  list(key = "numeral_years",  yml = "numeral_years: maybe",
       msg = "must be TRUE or FALSE"),
  list(key = "numeral_years",  yml = "numeral_years: 1",
       msg = "must be TRUE or FALSE"),
  list(key = "numeral_years",  yml = "numeral_years: [true]",
       msg = "must be TRUE or FALSE"),
  list(key = "claim_words",    yml = "claim_words: [a, b]",
       msg = "must be a mapping with `add` and `drop`, each a list of words"),
  list(key = "claim_words",    yml = "claim_words: {add: 5, drop: []}",
       msg = "must be a mapping with `add` and `drop`, each a list of words"),
  list(key = "claim_words",    yml = "claim_words: {add: [a b], drop: []}",
       msg = "must be a mapping with `add` and `drop`, each a list of words"),
  list(key = "claim_words",    yml = "claim_words: yes please",
       msg = "must be a mapping with `add` and `drop`, each a list of words"),
  list(key = "claim_cap",      yml = "claim_cap: 0",
       msg = "must be a whole number from 1"),
  list(key = "claim_cap",      yml = "claim_cap: -3",
       msg = "must be a whole number from 1"),
  list(key = "claim_cap",      yml = "claim_cap: 2.5",
       msg = "must be a whole number from 1"),
  list(key = "claim_cap",      yml = "claim_cap: many",
       msg = "must be a whole number from 1"),
  list(key = "claim_cap",      yml = "claim_cap: true",
       msg = "must be a whole number from 1"),
  list(key = "guard_words",    yml = "guard_words: 0",
       msg = "must be a whole number from 1"),
  list(key = "guard_words",    yml = "guard_words: 1.5",
       msg = "must be a whole number from 1"),
  list(key = "guard_words",    yml = "guard_words: lots",
       msg = "must be a whole number from 1"),
  list(key = "expected_names", yml = "expected_names: ['.a b']",
       msg = "must be a list of names, each `.class` or `key`"),
  list(key = "expected_names", yml = "expected_names: [5]",
       msg = "must be a list of names, each `.class` or `key`"),
  list(key = "expected_names", yml = "expected_names: ['']",
       msg = "must be a list of names, each `.class` or `key`"),
  list(key = "expected_names", yml = "expected_names: {a: b}",
       msg = "must be a list of names, each `.class` or `key`")
)

test_that("3a L8: a wrong value is a weft_config_error from read_config() with the documented message", {
  for (b in BAD_L8) {
    e <- rc_err(b$yml)
    lbl <- b$yml
    expect_false(is.null(e), label = paste("raises:", lbl))
    expect_true(inherits(e, "weft_config_error"), label = paste("weft_config_error:", lbl))
    expect_true(inherits(e, "weft_error"), label = paste("weft_error:", lbl))
    m <- f2_msg(e)
    expect_true(grepl(paste0("The setting `", b$key, "` "), m, fixed = TRUE), label = paste("names the key:", lbl, "|", m))
    expect_true(grepl(b$msg, m, fixed = TRUE), label = paste("message:", lbl, "|", m))
  }
})

test_that("3a L8: the message ends with the rule: label_words (rule 5.2.4)", {
  e <- rc_err("label_words: [Site 3]")
  expect_match(f2_msg(e), "The setting `label_words` must be a list of words without spaces (rule 5.2.4).",
               fixed = TRUE)
})

test_that("3a L8: the same refusals come from lints() on _weft.yml", {
  for (b in BAD_L8) {
    e <- ln_err_yml(b$yml)
    expect_true(inherits(e, "weft_config_error"), label = paste("lints():", b$yml))
    expect_true(grepl(b$msg, f2_msg(e), fixed = TRUE), label = paste("lints() message:", b$yml))
  }
})

test_that("3a L8: the same refusals come from lints() on a document's weft: front matter", {
  for (b in BAD_L8[c(1, 4, 7, 11, 16, 18)]) {
    # YAML flow lines are valid indented under `weft:`
    e <- ln_err_front(b$yml)
    expect_true(inherits(e, "weft_config_error"), label = paste("front matter:", b$yml))
    expect_true(grepl(b$msg, f2_msg(e), fixed = TRUE), label = paste("front message:", b$yml))
  }
})

test_that("3a L8: read_config() refuses a wrong value given in the front matter list too", {
  withr::local_envvar(WEFT_DRAFT = NA)
  e <- f2_cond(weft:::read_config(f2_proj(), front = list(claim_cap = 0)))
  f2_has_class(e, "weft_config_error")
  f2_msg_has(e, "claim_cap", "a whole number from 1")
  e <- f2_cond(weft:::read_config(f2_proj(), front = list(numeral_years = "yes")))
  f2_has_class(e, "weft_config_error")
})

test_that("3a L8: valid forms are accepted by lints()", {
  ok <- list(
    "label_words: []", "label_words: [Site, 'Stn.']", "numeral_years: true",
    "numeral_years: false", "claim_words: {add: [], drop: []}",
    "claim_words: {add: [dramatic], drop: [rose, fell]}",
    "claim_cap: 1", "claim_cap: 500", "guard_words: 1", "guard_words: 25",
    "expected_names: []", "expected_names: ['.foo', bar]"
  )
  for (y in ok) {
    root <- lint_proj(list("a.qmd" = "Plain."), weft_yml = y)
    expect_no_error(lints(root))
  }
})

# ---- L4: lint_config() parses YAML only -----------------------------------------------

test_that("3a L4: a bad `units:` table does not stop a lint (lint_config() never calls read_config())", {
  root <- lint_proj(list("a.qmd" = F3_BAD_LIT), weft_yml = "units: [m, km]")
  expect_error(weft:::read_config(root), class = "weft_config_error")
  expect_no_error(lints(root))
  x <- lints(root)
  expect_true("construct" %in% x$rule)
})

test_that("3a L4: lint_config() returns the merged settings, with the new keys' defaults", {
  root <- lint_proj(list(), weft_yml = c("claim_cap: 6", "label_words: [Site]"))
  cfg <- weft:::lint_config(root, list())
  expect_equal(cfg$claim_cap, 6)
  expect_identical(unlist(cfg$label_words), "Site")
  expect_equal(cfg$guard_words, 25)
  expect_false(cfg$numeral_years)
})

test_that("3a L4: the nearest wins, setting by setting: front matter over _weft.yml", {
  root <- lint_proj(list(), weft_yml = c("claim_cap: 6", "guard_words: 9"))
  # Design silent on whether `front` is the front matter or its weft: key; both shapes tried.
  shapes <- list(list(weft = list(claim_cap = 3)), list(claim_cap = 3))
  got <- vapply(shapes, function(f) {
    r <- tryCatch(weft:::lint_config(root, f), error = function(e) NULL)
    !is.null(r) && isTRUE(all.equal(r$claim_cap, 3)) && isTRUE(all.equal(r$guard_words, 9))
  }, logical(1))
  expect_true(any(got))
})

test_that("3a L4: a document's weft: block is applied per document by lints() (error is per front matter)", {
  root <- lint_proj(list(
    "good.qmd" = c("---", "weft:", "  claim_cap: 3", "---", "", F3_BAD_LIT),
    "bad.qmd" = c("---", "weft:", "  claim_cap: 0", "---", "", "Plain.")
  ))
  e <- f2_cond(lints(root))
  f2_has_class(e, "weft_config_error")
  f2_msg_has(e, "claim_cap")
})

# ---- L8a the claim lexicon ----------------------------------------------------------------

LEX_LISTED <- c("zero", "one", "two", "three", "four", "five", "six", "seven", "eight",
                "nine", "ten", "eleven", "twelve", "first", "second", "third",
                "always", "never", "whole", "entire", "single", "sole", "solely", "fewest",
                "top", "exceed", "exceeding", "surpassed", "decline", "declines",
                "declining", "grow", "grows", "growing", "drop", "drops", "dropping",
                "reduced", "significant", "significantly")

lex <- function(cfg = weft:::default_config(), lang) {
  if (missing(lang)) weft:::claim_lexicon(cfg) else weft:::claim_lexicon(cfg, lang)
}

test_that("3a L8a: inst/weft-claim-words.yml is a mapping of the four lists, lower case", {
  p <- system.file("weft-claim-words.yml", package = "weft")
  expect_true(nzchar(p))
  y <- yaml::read_yaml(p)
  expect_setequal(names(y), c("number", "quantifier", "extremum", "direction"))
  w <- unlist(y, use.names = FALSE)
  expect_identical(w, tolower(w))
  expect_false(anyDuplicated(w) > 0)
  expect_true(all(c("zero", "one", "twelve", "first", "third") %in% y$number))
})

test_that("3a L8a: the shipped lexicon holds the words the design lists", {
  w <- lex(lang = "en")
  expect_type(w, "character")
  expect_true(all(LEX_LISTED %in% w), label = paste("missing:", paste(setdiff(LEX_LISTED, w), collapse = ", ")))
  # the shipped words are the union of the four lists
  y <- yaml::read_yaml(system.file("weft-claim-words.yml", package = "weft"))
  expect_setequal(w, unlist(y, use.names = FALSE))
})

test_that("3a L8a: the words of the interim claim_words() are all in the lexicon (K10)", {
  interim <- weft:::claim_words()
  w <- lex(lang = "en")
  expect_true(all(interim %in% w), label = paste("missing:", paste(setdiff(interim, w), collapse = ", ")))
})

test_that("3a L8a: lang missing, NA or starting en (any case) gets the shipped words", {
  shipped <- lex(lang = "en")
  expect_identical(sort(lex()), sort(shipped))
  expect_identical(sort(lex(lang = NA_character_)), sort(shipped))
  for (l in c("en", "en-AU", "en_GB", "EN", "En-us", "eng")) {
    expect_identical(sort(lex(lang = l)), sort(shipped), label = l)
  }
})

test_that("3a L8a: a lang not starting en gets no shipped words", {
  for (l in c("de", "fr-CA", "ende", "xen")) {
    expect_equal(length(lex(lang = l)), 0L, label = l)
  }
})

test_that("3a L8a: add is united in, then drop removed, for any lang", {
  cfg <- weft:::default_config()
  cfg$claim_words <- list(add = c("dramatic", "huge"), drop = c("rose", "one"))
  w <- lex(cfg, "en-AU")
  expect_true(all(c("dramatic", "huge") %in% w))
  expect_false(any(c("rose", "one") %in% w))
  expect_true("always" %in% w)
  # add under a language with no shipped words: only the added words
  expect_setequal(lex(cfg, "de"), c("dramatic", "huge"))
  # drop after add: a word both added and dropped is gone
  cfg$claim_words <- list(add = "dramatic", drop = "dramatic")
  expect_false("dramatic" %in% lex(cfg, "en"))
  # no duplicates
  cfg$claim_words <- list(add = c("always", "always"), drop = character(0))
  expect_false(anyDuplicated(lex(cfg, "en")) > 0)
})

test_that("3a L8a: the configuration read from _weft.yml feeds claim_lexicon()", {
  cfg <- rc(c("claim_words: {add: [dramatic], drop: [never]}"))
  w <- lex(cfg, "en")
  expect_true("dramatic" %in% w)
  expect_false("never" %in% w)
  expect_true("always" %in% w)
})
