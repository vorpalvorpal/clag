# Package 6d: the `engine` rule for documents that hold named values (rule 5.8.9; N146 of dev/design-6.md; messages
# G38 as test-lint-engine-guest.R pins them, E73, E74). When the rule fires and what it says. Static: no Python, Julia,
# Quarto or Pandoc is needed. Helpers: helper-6d.R, helper-3.R (lint_fixture, expect_findings_shape), helper-3d.R (f3d_doc).
#
# READINGS of the note (see the report):
#  - "the resolver is installed" is read from `filters:` in the project's _quarto.yml or in the document's own front
#    matter, as a block list holding `weft-check` (the form use_quarto() writes);
#  - "one sentence added to each hint" is read as the hint of today, one space, then E73;
#  - a document that holds only spans of the grammar (no named value) and no resolver is not pinned (E74 says "named
#    values"); the tests that mix a named value in always do so;
#  - E74's hint is not pinned (the note gives only its message).

eng6d <- function(lines, name = "a.qmd", yml = NULL, env = parent.frame()) {
  files <- stats::setNames(list(lines), name)
  if (!is.null(yml)) files[["_quarto.yml"]] <- yml
  lint_fixture(files, rules = "engine", tier = 1:2, env = env)
}

py_chunk <- c("```{python}", "x = 1", "```")
jl_chunk <- c("```{julia}", "x = 1", "```")
r_chunk <- c("```{r}", "x <- 1", "```")
NAMED_ONLY <- "The depth is `depth`{.num} and the site `site`{.val}."
RVALUE <- "The depth is `r x`{.num} metres."
BAD_SPAN <- r"{We visited [a site | # sites]{n="3"} today.}"
GOOD_SPAN <- r"{The level [rose | fell]{if="up"} again.}"

HINT_PY <- paste0("Add `engine: knitr` to its front matter. Python chunks then run through reticulate, and a Python ",
                  "value reaches prose as `r py$x`.")
HINT_JL <- paste0("Add `engine: knitr` to its front matter. Julia chunks then run through JuliaCall, and a Julia ",
                  "value reaches prose as `r jl_value(\"x\")`.")
HINT_MARKED <- paste0("Change it to `engine: knitr`. Python chunks then run through reticulate, and a Python value ",
                      "reaches prose as `r py$x`.")
HINT4 <- "Add `engine: knitr` to its front matter."
MSG1 <- function(marked, file = "a.qmd") {
  sprintf(paste0("%s holds weft constructs and is marked `%s`; weft constructs are evaluated only under ",
                 "`engine: knitr` (rule 5.8.9)."), file, marked)
}
MSG2 <- paste0("a.qmd holds weft constructs and Python chunks but is not marked `engine: knitr`, so Quarto would run it ",
               "with Jupyter, which does not evaluate weft constructs (rule 5.8.9).")
MSG3 <- paste0("a.qmd holds weft constructs and Julia chunks but is not marked `engine: knitr`, so Quarto would run it ",
               "with its julia engine, which does not evaluate weft constructs (rule 5.8.9).")
MSG4 <- "a.qmd holds weft constructs but is not marked `engine: knitr` and no document includes it (rule 5.8.9)."

# one finding of the engine rule with today's message and the hint of today plus E73
expect_g38 <- function(x, message, old_hint, file = "a.qmd", label = NULL) {
  expect_findings_shape(x)
  expect_identical(nrow(x), 1L, label = label)
  if (nrow(x) != 1L) return(invisible())
  expect_identical(x$rule, "engine", label = label)
  expect_identical(x$spec, "5.8.9", label = label)
  expect_identical(x$tier, 1L, label = label)
  expect_identical(x$file, file, label = label)
  expect_identical(x$line, 1L, label = label)
  expect_identical(x$message, message, label = label)
  expect_true(startsWith(x$hint, old_hint), label = paste(label, "hint starts as today's"))
  expect_true(endsWith(x$hint, W6D_E73), label = paste(label, "hint ends with E73"))
  mid <- substr(x$hint, nchar(old_hint) + 1L, nchar(x$hint) - nchar(W6D_E73))
  expect_identical(trimws(mid), "", label = paste(label, "only space joins them"))
  expect_true(nchar(mid) >= 1L, label = paste(label, "a space joins them"))
}

expect_e74 <- function(x, file = "a.qmd", label = NULL) {
  expect_findings_shape(x)
  expect_identical(nrow(x), 1L, label = label)
  if (nrow(x) != 1L) return(invisible())
  expect_identical(x$rule, "engine", label = label)
  expect_identical(x$spec, "5.8.9", label = label)
  expect_identical(x$tier, 1L, label = label)
  expect_identical(x$file, file, label = label)
  expect_identical(x$line, 1L, label = label)
  expect_identical(x$message, W6D_E74(file), label = label)
}

# ---- the document of the design's test line --------------------------------------------------------------------

test_that("N146: a jupyter .qmd with only named values and the filter installed gives no engine finding", {
  x <- eng6d(f3d_doc(c(NAMED_ONLY, "", py_chunk), "engine: jupyter"), yml = W6D_FILTER_YML)
  expect_findings_shape(x)
  expect_identical(nrow(x), 0L)
})

test_that("N146, G38 case 1, E73: the same document with an inline R span `r x`{.num} is G38 case 1 with E73", {
  x <- eng6d(f3d_doc(c(RVALUE, "", py_chunk), "engine: jupyter"), yml = W6D_FILTER_YML)
  expect_g38(x, MSG1("engine: jupyter"), HINT_MARKED)
})

test_that("N146, E73: a named value beside the R span does not make the document valid", {
  x <- eng6d(f3d_doc(c(NAMED_ONLY, "", RVALUE, "", py_chunk), "engine: jupyter"), yml = W6D_FILTER_YML)
  expect_g38(x, MSG1("engine: jupyter"), HINT_MARKED)
})

# ---- G38's four cases, each with E73 on its hint (an R value or a span outside the grammar) -----------------------

test_that("N146, E73: case 1 for engine: jupyter, engine: markdown, jupyter: python3, whether or not the filter is installed", {
  for (yml in list(NULL, W6D_FILTER_YML)) {
    for (marked in c("engine: jupyter", "engine: markdown", "jupyter: python3")) {
      x <- eng6d(f3d_doc(c(RVALUE, "", py_chunk), marked), yml = yml)
      expect_g38(x, MSG1(marked), HINT_MARKED, label = paste(marked, is.null(yml)))
    }
  }
})

test_that("N146, E73: case 2, a Python chunk and no executed R chunk, with an R value", {
  expect_g38(eng6d(c(RVALUE, "", py_chunk)), MSG2, HINT_PY)
  expect_g38(eng6d(c(RVALUE, "", py_chunk), yml = W6D_FILTER_YML), MSG2, HINT_PY)
})

test_that("N146, E73: case 3, a Julia chunk and no R chunk, with an R value: the message and the hint with E73", {
  x <- eng6d(c(RVALUE, "", jl_chunk))
  expect_identical(nrow(x), 1L)
  expect_identical(x$message, MSG3)
  expect_g38(x, MSG3, HINT_JL)
})

test_that("N146, E73: case 4, no other engine's chunk, with an R value", {
  expect_g38(eng6d(c(RVALUE, "", r_chunk, "", py_chunk)), MSG4, HINT4)
  expect_g38(eng6d(RVALUE), MSG4, HINT4)
})

test_that("N146, E73: a span outside the grammar is G38's finding as well, with E73", {
  expect_g38(eng6d(c(BAD_SPAN, "", py_chunk)), MSG2, HINT_PY)
  expect_g38(eng6d(f3d_doc(c(BAD_SPAN, "", py_chunk), "engine: jupyter"), yml = W6D_FILTER_YML),
             MSG1("engine: jupyter"), HINT_MARKED)
  expect_g38(eng6d(c(r"{The level [rose | fell]{if="a && b"} again.}", "", py_chunk)), MSG2, HINT_PY)
  expect_g38(eng6d(c(r"{The level [rose | fell]{sign="3"} again.}", "", py_chunk)), MSG2, HINT_PY)
})

# ---- named constructs and the resolver installed ---------------------------------------------------------------------

test_that("N146: only named values and spans of the grammar, with the filter in _quarto.yml: valid on every non-knit shape", {
  doc_shapes <- list(
    jupyter_key   = f3d_doc(c(NAMED_ONLY, "", GOOD_SPAN, "", py_chunk), "engine: jupyter"),
    jupyter_key2  = f3d_doc(c(NAMED_ONLY, "", py_chunk), "jupyter: python3"),
    python_only   = c(NAMED_ONLY, "", GOOD_SPAN, "", py_chunk),
    julia_only    = c(NAMED_ONLY, "", jl_chunk),
    julia_engine  = f3d_doc(c(NAMED_ONLY, "", jl_chunk), "engine: julia"),
    no_chunks     = c(NAMED_ONLY, "", GOOD_SPAN),
    markdown      = f3d_doc(c(NAMED_ONLY), "engine: markdown")
  )
  for (nm in names(doc_shapes)) {
    x <- eng6d(doc_shapes[[nm]], yml = W6D_FILTER_YML)
    expect_identical(nrow(x), 0L, label = nm)
  }
})

test_that("N146: the filter listed in the document's own front matter installs it", {
  front <- c("engine: jupyter", "filters:", "  - weft-check")
  expect_identical(nrow(eng6d(f3d_doc(c(NAMED_ONLY, "", py_chunk), front), yml = W6D_PLAIN_YML)), 0L)
  expect_identical(nrow(eng6d(f3d_doc(c(NAMED_ONLY, "", py_chunk), front))), 0L)
})

test_that("N146: weft-check among other filters in _quarto.yml still installs it", {
  yml <- c("project:", "  type: default", "filters:", "  - other", "  - weft-check", "  - another")
  expect_identical(nrow(eng6d(f3d_doc(c(NAMED_ONLY, "", py_chunk), "engine: jupyter"), yml = yml)), 0L)
})

# ---- E74: named values and no resolver ------------------------------------------------------------------------------

test_that("N146, E74: only named constructs and no resolver installed is a finding with E74, at line 1", {
  expect_e74(eng6d(f3d_doc(c(NAMED_ONLY, "", py_chunk), "engine: jupyter"), yml = W6D_PLAIN_YML), label = "jupyter")
  expect_e74(eng6d(f3d_doc(c(NAMED_ONLY, "", py_chunk), "engine: jupyter")), label = "no _quarto.yml filters")
  expect_e74(eng6d(c(NAMED_ONLY, "", py_chunk)), label = "python only")
  expect_e74(eng6d(c(NAMED_ONLY, "", jl_chunk)), label = "julia only")
  expect_e74(eng6d(f3d_doc(c(NAMED_ONLY, "", jl_chunk), "engine: julia"), yml = W6D_PLAIN_YML), label = "julia engine")
  expect_e74(eng6d(NAMED_ONLY), label = "no chunks")
})

test_that("N146, E74: the message names the file as the lint reports it", {
  x <- eng6d(f3d_doc(c(NAMED_ONLY, "", py_chunk), "engine: jupyter"), name = "ch/results.qmd", yml = W6D_PLAIN_YML)
  expect_e74(x, file = "ch/results.qmd")
})

test_that("N146, E74: a named value with a span of the grammar and no resolver is E74 too", {
  expect_e74(eng6d(f3d_doc(c(NAMED_ONLY, "", GOOD_SPAN, "", py_chunk), "engine: jupyter"), yml = W6D_PLAIN_YML))
})

test_that("N146, E74: a filters: list without weft-check is no resolver", {
  yml <- c("project:", "  type: default", "filters:", "  - other")
  expect_e74(eng6d(f3d_doc(c(NAMED_ONLY, "", py_chunk), "engine: jupyter"), yml = yml))
})

# ---- when it does not fire, as before -----------------------------------------------------------------------------------

test_that("N146 control: a knit document is valid with named values whatever the resolver", {
  for (yml in list(NULL, W6D_PLAIN_YML, W6D_FILTER_YML)) {
    expect_identical(nrow(eng6d(f3d_doc(c(NAMED_ONLY, "", RVALUE, "", py_chunk), "engine: knitr"), yml = yml)), 0L)
    expect_identical(nrow(eng6d(c(NAMED_ONLY, "", RVALUE), name = "a.Rmd", yml = yml)), 0L)
  }
})

test_that("N146 control: a document with no construct, or only bare values, links and literals, is no finding", {
  for (b in list("Plain words.", "Words `r x` more.", "A [link](a.html) here.",
                 "A [10]{.weft-literal why=\"SOP\"} here.")) {
    expect_identical(nrow(eng6d(c(b, "", py_chunk))), 0L, label = b)
  }
})

test_that("N146 control: a named value is not made a G38 finding by an R chunk that is not executed", {
  x <- eng6d(c(NAMED_ONLY, "", py_chunk, "", c("```{r}", "#| eval: false", "x <- 1", "```")), yml = W6D_FILTER_YML)
  expect_identical(nrow(x), 0L)
})
