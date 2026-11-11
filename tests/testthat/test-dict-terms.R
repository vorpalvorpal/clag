# Package 2c: the dictionary fields `term` and `avoid`. Contract: dev/design-2c.md "Two new
# dictionary fields", rules 4.7.3, 4.7.4, C1, C8-C10. Helpers: helper-2c.R, helper-render.R.

TERM_BAD <- "`term` must be a string that is not blank (rule 4.7.3)"
AVOID_SHAPE <- "`avoid` must be a string, or a list of strings, none blank (rule 4.7.4)"
AVOID_NEEDS_TERM <- "`avoid` needs a `term`: the spelling the avoided ones are replaced by (rule 4.7.4)"

FX_TOOLS_KEYS <- c("min_samples", "core_len", "salinity_res", "method_change", "survey_start",
                   "study_area", "zone_lab", "trend_word")

str1 <- function(key, value, extra = NULL) {
  sprintf("%s: {value: %s, type: string, definition: \"Fine.\"%s}", key, value,
          if (length(extra)) paste0(", ", paste(extra, collapse = ", ")) else "")
}

test_that("2c terms: the fixture reads, and the entries attribute gains term and avoid after display (4.2.1, 4.7.3, 4.7.4)", {
  d <- read_dict(c2_fixture())
  expect_identical(names(d), FX_TOOLS_KEYS)
  e <- attr(d, "entries")
  expect_identical(match(c("display", "term", "avoid"), names(e)),
                   match("display", names(e)) + 0:2)
  expect_true(all(c("term", "avoid") %in% names(e)))
})

test_that("2c terms: entries$term is the string, NA where absent (4.7.3)", {
  e <- attr(read_dict(c2_fixture()), "entries")
  expect_type(e$term, "character")
  expect_identical(e$term, c("minimum sample size", "core length", NA, "Method change", NA, NA,
                             "zone names", NA))
})

test_that("2c terms: entries$avoid is a list column of trimmed character vectors, character(0) where absent (4.7.4)", {
  e <- attr(read_dict(c2_fixture()), "entries")
  expect_type(e$avoid, "list")
  expect_length(e$avoid, 8L)
  expect_identical(e$avoid[[1]], c("min sample size", "minimum sample-size"))
  expect_identical(e$avoid[[6]], c("northern catchment", "Nth. catchment"))
  for (i in c(2:5, 7:8)) expect_identical(e$avoid[[i]], character(0))
})

test_that("2c terms: avoid is trimmed at its ends and keeps the order written; one string is a vector of one (4.7.4)", {
  d <- c2_dict(c(str1("a", "Alpha", "avoid: [\"  zz top \", \"mm  nn\"]"),
                 str1("b", "Beta", "avoid: \"  yy \"")))
  e <- attr(d, "entries")
  expect_identical(e$avoid[[1]], c("zz top", "mm  nn"))
  expect_identical(e$avoid[[2]], "yy")
})

test_that("2c terms: the entries attribute has term and avoid, all NA and empty, when no entry has one (4.7.3)", {
  e <- attr(c2_dict(c2_entry("a")), "entries")
  expect_true(is.na(e$term))
  expect_identical(e$avoid, list(character(0)))
})

test_that("2c terms: the unknown-field problem lists the nine fields (C1, DICT_FIELDS)", {
  r <- c2_read_err(c2_entry("a", extra = "colour: red"))
  c2_expect_cond(r$err, "weft_dict_error")
  c2_expect_msg(r$err, "colour")
  for (f in c("value", "type", "definition", "unit", "display", "decision", "why", "term", "avoid")) {
    expect_true(grepl(f, c2_msg(r$err), fixed = TRUE), label = f)
  }
  # in the contract's order: term and avoid come after why
  msg <- c2_msg(r$err)
  pos <- regexpr("value, type, definition, unit, display, decision, why, term, avoid", msg, fixed = TRUE)
  expect_gt(as.integer(pos), 0)
})

# ---- one dictionary per problem row ----------------------------------------------------------

test_that("2c terms: a term that is blank, not text or a list is the term problem (4.7.3)", {
  for (bad in c("\"\"", "\"   \"", "5", "[a, b]", "{a: b}")) {
    c2_expect_problem(c2_entry("a", extra = paste0("term: ", bad)), "a", TERM_BAD, label = bad)
  }
})

test_that("2c terms: a term on every type is read (4.7.3)", {
  d <- c2_dict(c(
    c2_entry("a", "1", "number", "term: aa"),
    c2_entry("b", "2014", "year", "term: bb"),
    c2_entry("c", "2024-06-01", "date", "term: cc"),
    c2_entry("d", "{x: X}", "labels", "term: dd"),
    c2_entry("e", "3", "quantity", c("unit: m", "term: ee"))
  ))
  expect_identical(attr(d, "entries")$term, c("aa", "bb", "cc", "dd", "ee"))
})

test_that("2c terms: avoid empty, not text, or holding a blank or non-string item is the shape problem (4.7.4)", {
  bad <- c("[]", "5", "[a, \"\"]", "[a, 5]", "[\"  \"]", "\"\"", "\"   \"", "{a: b}", "[[a]]", "[true]")
  for (b in bad) {
    c2_expect_problem(str1("a", "Alpha", paste0("avoid: ", b)), "a", AVOID_SHAPE, label = b)
  }
})

test_that("2c terms: avoid on an entry that is not a string and has no term needs a term (4.7.4)", {
  for (ent in list(c2_entry("a", "1", "number", "avoid: [uno]"),
                   c2_entry("a", "2014", "year", "avoid: [uno]"),
                   c2_entry("a", "{x: X}", "labels", "avoid: [uno]"),
                   c2_entry("a", "3", "quantity", c("unit: m", "avoid: [uno]")))) {
    c2_expect_problem(ent, "a", AVOID_NEEDS_TERM)
  }
})

test_that("2c terms: avoid on a string entry with no term reads, the value being canonical; so does a term on a non-string (C1)", {
  d <- c2_dict(c(str1("a", "Alpha", "avoid: [alpha]"),
                 c2_entry("b", "1", "number", c("term: bee", "avoid: [b e e]"))))
  expect_identical(names(d), c("a", "b"))
  expect_identical(attr(d, "entries")$avoid[[1]], "alpha")
  expect_identical(attr(d, "entries")$avoid[[2]], "b e e")
})

test_that("2c terms: a spelling equal to the entry's own canonical spelling is a problem, and only that one (4.7.4)", {
  msg <- c2_expect_problem(str1("a", "Alpha", "avoid: [Alpha]"), "a",
                           "`avoid` lists `Alpha`, which is the entry's own spelling (rule 4.7.4)")
  expect_false(grepl("is part of the spelling", msg, fixed = TRUE))
  msg2 <- c2_expect_problem(c2_entry("a", "1", "number", c("term: one thing", "avoid: [one thing]")), "a",
                            "`avoid` lists `one thing`, which is the entry's own spelling (rule 4.7.4)")
  expect_false(grepl("is part of the spelling", msg2, fixed = TRUE))
})

test_that("2c terms: a spelling listed twice in one entry is a problem (4.7.4)", {
  c2_expect_problem(str1("a", "Alpha", "avoid: [bb, cc, bb]"), "a",
                    "`avoid` lists `bb` twice (rule 4.7.4)")
})

test_that("2c terms: a spelling another entry also lists is a problem on the later entry (4.7.4)", {
  lines <- c(str1("a", "Alpha", "avoid: [\"cc dd\"]"), str1("b", "Beta", "avoid: [\"cc dd\"]"))
  msg <- c2_expect_problem(lines, "b", "`avoid` lists `cc dd`, which `a` also lists (rule 4.7.4)")
  expect_false(grepl(":1: `a`", msg, fixed = TRUE))
})

test_that("2c terms: a spelling inside another entry's canonical spelling, as whole words, is a problem (4.7.4)", {
  lines <- c(str1("a", "Alpha", "avoid: [Beta]"), str1("b", "Beta gamma"))
  c2_expect_problem(lines, "a", paste0(
    "`avoid` lists `Beta`, which is part of the spelling `Beta gamma` of `b`; ",
    "Vale would flag that spelling (rule 4.7.4)"))
})

test_that("2c terms: a spelling inside the entry's own canonical spelling is a problem naming that entry (4.7.4)", {
  c2_expect_problem(str1("a", "\"Fast car\"", "avoid: [car]"), "a", paste0(
    "`avoid` lists `car`, which is part of the spelling `Fast car` of `a`; ",
    "Vale would flag that spelling (rule 4.7.4)"))
  c2_expect_problem(c(c2_entry("t", "1", "number", c("term: fast car", "avoid: [car]"))), "t", paste0(
    "`avoid` lists `car`, which is part of the spelling `fast car` of `t`; ",
    "Vale would flag that spelling (rule 4.7.4)"))
})

test_that("2c terms: the whole-word test uses letters, digits and _ as word characters (4.7.4 'as whole words')", {
  # controls: none of these is a whole-word occurrence, so all read
  expect_s3_class(c2_dict(c(str1("a", "Alpha", "avoid: [car]"), str1("b", "\"Cart horse\""))), "weft_dict")
  expect_s3_class(c2_dict(c(str1("a", "Alpha", "avoid: [ca]"), str1("b", "ca_t"))), "weft_dict")
  expect_s3_class(c2_dict(c(str1("a", "Alpha", "avoid: [\"a.b\"]"), str1("b", "aXb"))), "weft_dict")
  # and these are
  c2_expect_problem(c(str1("a", "Alpha", "avoid: [car]"), str1("b", "\"a car-park\"")), "a", paste0(
    "`avoid` lists `car`, which is part of the spelling `a car-park` of `b`; ",
    "Vale would flag that spelling (rule 4.7.4)"))
})

test_that("2c terms: the comparisons are case-sensitive, and canonical spellings need not be unique (4.7.4)", {
  expect_s3_class(c2_dict(str1("a", "Alpha", "avoid: [alpha]")), "weft_dict")
  expect_s3_class(c2_dict(c(str1("a", "Alpha", "avoid: [bb]"), str1("b", "Alpha"))), "weft_dict")
  expect_s3_class(c2_dict(c(c2_entry("a", "1", "number", "term: same"),
                            c2_entry("b", "2", "number", "term: same"))), "weft_dict")
})

test_that("2c terms: the cross-entry checks skip an entry whose own term or avoid had a problem (4.7.4)", {
  lines <- c(str1("a", "Alpha", "term: \"\""), str1("b", "Beta", "avoid: [Alpha]"))
  msg <- c2_expect_problem(lines, "a", TERM_BAD)
  expect_false(grepl("is part of the spelling", msg, fixed = TRUE))
  lines2 <- c(str1("a", "Alpha", "avoid: [x, x]"), str1("b", "Beta", "avoid: [x]"))
  msg2 <- c2_expect_problem(lines2, "a", "`avoid` lists `x` twice (rule 4.7.4)")
  expect_false(grepl("also lists", msg2, fixed = TRUE))
})

test_that("2c terms: two problems in one file are listed together, each at its own line (D5, 4.7.3, 4.7.4)", {
  lines <- c(c2_entry("a", extra = "term: \"\""), c2_entry("ok"), str1("b", "Beta", "avoid: [x, x]"))
  r <- c2_read_err(lines)
  c2_expect_cond(r$err, "weft_dict_error")
  msg <- c2_msg(r$err)
  expect_true(grepl("2 problem(s) in the dictionary", msg, fixed = TRUE))
  expect_true(grepl(sprintf("%s:1: `a`: %s", r$path, TERM_BAD), msg, fixed = TRUE))
  expect_true(grepl(sprintf("%s:3: `b`: `avoid` lists `x` twice (rule 4.7.4)", r$path), msg, fixed = TRUE))
})

# ---- dict_local ------------------------------------------------------------------------------

local_front <- function(entry_lines) c("weft:", "  dict_local:", paste0("    ", entry_lines))

test_that("2c terms: term is allowed in dict_local, read from front matter in a render (4.7.3)", {
  res <- render_rmd(
    c("Body."),
    front = local_front(c("loc:", "  value: 3", "  type: number", "  term: local thing",
                          "  definition: \"A local number.\"", "  why: \"Chapter-specific.\"")),
    files = list(dict.yml = c2_fixture_lines()), format = "knit", in_process = TRUE)
  expect_false(res$failed, label = res$message)
  e <- attr(res$knit$dict_local, "entries")
  expect_identical(e$term, "local thing")
  expect_identical(e$avoid, list(character(0)))
})

test_that("2c terms: avoid in dict_local is a weft_dict_error with the rule's text (4.7.4, C8)", {
  res <- render_rmd(
    c("Body."),
    front = local_front(c("loc:", "  value: Alpha", "  type: string", "  avoid: [alpha]",
                          "  definition: \"A local string.\"", "  why: \"Chapter-specific.\"")),
    files = list(dict.yml = c2_fixture_lines()), format = "knit", in_process = TRUE)
  expect_true(res$failed)
  expect_true("weft_dict_error" %in% res$error$class)
  expect_match(res$message,
               "`loc`: `avoid` is for dict.yml; a chapter's own entries write no Vale rules (rule 4.7.4)",
               fixed = TRUE)
})
