# Findings made while writing the documentation: texts that said something the package does not do.
# Each test is titled `doc-finding #<n>: ...`. Helpers: helper-3.R (lint_one), helper-4b.R, helper-4d.R. ASCII only.

# ---- #1: draft mode and the commit gate (spec 9.4.3) --------------------------------------------------------

test_that("doc-finding #1: status() does not say a draft project is unchecked at a commit", {
  dir <- u4_dir(list(`_weft.yml` = "draft: true", `index.qmd` = u4_qmd()))
  git_env(); h4_env()
  st <- h4_status(dir)
  expect_identical(h4_state(st, "draft"), "off")
  d <- h4_detail(st, "draft")
  expect_false(grepl("nothing is checked", d, fixed = TRUE))
  expect_match(d, "render", fixed = TRUE)
  expect_match(d, "commit", fixed = TRUE)
  expect_match(d, "still", fixed = TRUE)
})

test_that("doc-finding #1: the shipped skill does not say the commit gate passes a draft", {
  p <- system.file("agent", "SKILL.md", package = "weft")
  expect_true(nzchar(p))
  txt <- paste(readLines(p), collapse = " ")
  expect_false(grepl("passes nothing", txt, fixed = TRUE))
  expect_match(txt, "commit gate ignores", fixed = TRUE)
})

# ---- #2: what lints() lists and what a failed-claim report gives --------------------------------------------

test_that("doc-finding #2: the skill says lints() lists every finding and gate() judges as the hook does", {
  txt <- paste(readLines(system.file("agent", "SKILL.md", package = "weft")), collapse = " ")
  expect_false(grepl("lists what the hook would refuse", txt, fixed = TRUE))
  expect_match(txt, "lints()", fixed = TRUE)
  expect_match(txt, "gate()", fixed = TRUE)
  expect_match(txt, "every finding", fixed = TRUE)
})

test_that("doc-finding #2: the skill says a failed-claim report gives the line, the expression, the check and the value", {
  txt <- paste(readLines(system.file("agent", "SKILL.md", package = "weft")), collapse = " ")
  expect_false(grepl("gives the sentence", txt, fixed = TRUE))
  expect_match(txt, "gives the line, the expression, the check and the value", fixed = TRUE)
})

# ---- #3: the literal-value hint shows the value written -----------------------------------------------------

test_that("doc-finding #3: the literal-value hint shows the value the author wrote, not always 10", {
  x <- lint_one("`r 7`", rules = "literal-value")
  expect_identical(nrow(x), 1L)
  expect_false(grepl("[10]", x$hint, fixed = TRUE))
  expect_match(x$hint, "[7]{.weft-literal", fixed = TRUE)
  y <- lint_one("`r 2 * 5`", rules = "literal-value")
  expect_false(grepl("[10]", y$hint, fixed = TRUE))
  expect_match(y$hint, "{.weft-literal", fixed = TRUE)
  z <- lint_one("`r 10`", rules = "literal-value")
  expect_match(z$hint, "[10]{.weft-literal", fixed = TRUE)   # the value written was 10
})

# ---- #4: the if-zero hint agrees with spec 5.3.3 --------------------------------------------------------------

test_that("doc-finding #4: the if-zero hint points to `sign`, as spec 5.3.3 says, not to the dictionary", {
  x <- lint_one("[up | down]{if=\"d > 0\"}", rules = "if-zero")
  expect_identical(nrow(x), 1L)
  expect_match(x$hint, "sign", fixed = TRUE)
  expect_false(grepl("dictionary", x$hint, fixed = TRUE))
})

# ---- #5: an empty two-arm list says "add a first arm" once --------------------------------------------------

test_that("doc-finding #5: the report of an empty two-arm list says to add a first arm once", {
  s <- weft:::string_state()
  weft:::resolve_string(s, "[# was | # were]{list=\"v\"}",
                        list(chunk = "c1", option = NA_character_, envir = list2env(list(v = character(0))),
                             strict = FALSE, context = "weft_str", file = "a.qmd", line = 3L))
  fr <- weft:::failures_frame(s)
  expect_identical(nrow(fr), 1L)
  txt <- paste(weft:::report_entry(fr, 1L), collapse = "\n")
  expect_match(txt, "empty case", fixed = TRUE)
  expect_identical(lengths(regmatches(txt, gregexpr("add a first arm", txt, fixed = TRUE))), 1L)
})

# ---- #6: use_agent_docs() on an edited skill --------------------------------------------------------------

test_that("doc-finding #6: use_agent_docs() when nothing is to change says 'are already set up'", {
  d <- u4_dir(list(`_weft.yml` = "draft: false"))
  h4_agent(d)
  skill <- file.path(d, ".claude", "skills", "weft", "SKILL.md")
  orig <- readLines(skill)
  writeLines(append(orig, "My own rule.", after = length(orig) - 1L), skill)
  # the skill is edited and AGENTS.md is current: nothing is written
  s <- h4_say(weft::use_agent_docs(d))
  expect_false(grepl("documents is", s$text, fixed = TRUE))
  expect_match(s$text, "the agent documents are already set up", fixed = TRUE)
})
