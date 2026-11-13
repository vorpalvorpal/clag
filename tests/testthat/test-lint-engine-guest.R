# Package 5e: the `engine` lint's message by case (dev/design-5.md G38; rule 5.8.9). When the rule fires is
# unchanged (test-lint-hygiene-doc.R); here only what it says. Static: no Python or Julia needed.
# READING: case 4's text is the text of the package today (measured by running lints() before the change; the note
# says only "unchanged"): the message below and the hint "Add `engine: knitr` to its front matter."

# 6d: a span of the filter's grammar (if="ok") needs no knitr (N146), so the body is one outside it
G5E_BODY <- r"{Words [a site]{if="a && ok"} more.}"
# 6d (E73): each G38 hint gains this sentence
G5E_E73 <- "Or write each value as a name, `x`{.num}, and publish it in code: then no knitr is needed (rule 1.12.7)."
g5e_en_py <- c("```{python}", "x = 1", "```")
g5e_en_jl <- c("```{julia}", "x = 1", "```")
g5e_en_r <- c("```{r}", "x <- 1", "```")

g5e_engine <- function(lines, name = "a.qmd") {
  lint_fixture(stats::setNames(list(lines), name), rules = "engine", tier = 1:2)
}
g5e_hint_py <- paste0("Change it to `engine: knitr`. Python chunks then run through reticulate, and a Python value ",
                      "reaches prose as `r py$x`.")
g5e_add_py <- paste0("Add `engine: knitr` to its front matter. Python chunks then run through reticulate, and a ",
                     "Python value reaches prose as `r py$x`.")
g5e_msg1 <- function(marked, file = "a.qmd") {
  sprintf(paste0("%s holds weft constructs and is marked `%s`; weft constructs are evaluated only under ",
                 "`engine: knitr` (rule 5.8.9)."), file, marked)
}
G5E_MSG2 <- paste0("a.qmd holds weft constructs and Python chunks but is not marked `engine: knitr`, so Quarto would ",
                   "run it with Jupyter, which does not evaluate weft constructs (rule 5.8.9).")
G5E_MSG3 <- paste0("a.qmd holds weft constructs and Julia chunks but is not marked `engine: knitr`, so Quarto would ",
                   "run it with its julia engine, which does not evaluate weft constructs (rule 5.8.9).")
G5E_MSG4 <- "a.qmd holds weft constructs but is not marked `engine: knitr` and no document includes it (rule 5.8.9)."
G5E_HINT4 <- "Add `engine: knitr` to its front matter."

expect_engine <- function(x, message, hint, file = "a.qmd") {
  expect_findings_shape(x)
  expect_identical(nrow(x), 1L)
  expect_identical(x$rule, "engine")
  expect_identical(x$spec, "5.8.9")
  expect_identical(x$tier, 1L)
  expect_identical(x$file, file)
  expect_identical(x$line, 1L)
  expect_identical(x$message, message)
  expect_identical(x$hint, paste(hint, G5E_E73))
}

# ---- case 1: another engine named in the front matter -----------------------------------------------------

test_that("5e G38 case 1: engine: jupyter or markdown names the engine; the hint says to change it", {
  # (engine: julia has the Julia hint of J25: test-lint-julia.R)
  for (eng in c("jupyter", "markdown")) {
    x <- g5e_engine(f3d_doc(c(G5E_BODY, "", g5e_en_py), paste("engine:", eng)))
    expect_engine(x, g5e_msg1(paste("engine:", eng)), g5e_hint_py)
  }
})

test_that("5e G38 case 1: a jupyter: key gives the value as written", {
  x <- g5e_engine(f3d_doc(c(G5E_BODY, "", g5e_en_py), "jupyter: python3"))
  expect_engine(x, g5e_msg1("jupyter: python3"), g5e_hint_py)
  x <- g5e_engine(f3d_doc(c(G5E_BODY, "", g5e_en_py), "jupyter: ir"))
  expect_engine(x, g5e_msg1("jupyter: ir"), g5e_hint_py)
})

test_that("5e G38 case 1: it applies with no guest chunk at all, and with an R chunk", {
  x <- g5e_engine(f3d_doc(G5E_BODY, "engine: jupyter"))
  expect_engine(x, g5e_msg1("engine: jupyter"), g5e_hint_py)
  x <- g5e_engine(f3d_doc(c(G5E_BODY, "", g5e_en_r), "engine: jupyter"))
  expect_engine(x, g5e_msg1("engine: jupyter"), g5e_hint_py)
})

test_that("5e G38 case 1: the file's own name is in the message", {
  x <- g5e_engine(f3d_doc(c(G5E_BODY, "", g5e_en_py), "engine: jupyter"), name = "ch/results.qmd")
  expect_identical(x$message, g5e_msg1("engine: jupyter", file = "ch/results.qmd"))
})

# ---- case 2: no executed R chunk, a Python chunk ----------------------------------------------------------

test_that("5e G38 case 2: a Python chunk and no R chunk, no engine key", {
  expect_engine(g5e_engine(c(G5E_BODY, "", g5e_en_py)), G5E_MSG2, g5e_add_py)
  expect_engine(g5e_engine(f3d_doc(c(G5E_BODY, "", g5e_en_py), "title: T")), G5E_MSG2, g5e_add_py)
})

test_that("5e G38 case 2: an R chunk that is not executed does not count as one", {
  x <- g5e_engine(c(G5E_BODY, "", g5e_en_py, "", c("```{r}", "#| eval: false", "x <- 1", "```")))
  expect_engine(x, G5E_MSG2, g5e_add_py)
})

test_that("5e G38 case 2: Python and Julia chunks together give the Python message", {
  expect_engine(g5e_engine(c(G5E_BODY, "", g5e_en_jl, "", g5e_en_py)), G5E_MSG2, g5e_add_py)
})

# ---- case 3: no R chunk, a Julia chunk: message here, hint is J25's (test-lint-julia.R) -------------------

test_that("5e G38 case 3: a Julia chunk, no R chunk, no Python chunk: the message", {
  x <- g5e_engine(c(G5E_BODY, "", g5e_en_jl))
  expect_identical(nrow(x), 1L)
  expect_identical(x$message, G5E_MSG3)
})

# ---- case 4: today's message ------------------------------------------------------------------------------

test_that("5e G38 case 4: an R chunk, or no chunk, or another engine's chunk keeps today's message and hint", {
  for (lines in list(c(G5E_BODY, "", g5e_en_r),
                     G5E_BODY,
                     c(G5E_BODY, "", g5e_en_py, "", g5e_en_r),
                     c(G5E_BODY, "", g5e_en_jl, "", g5e_en_r),
                     c(G5E_BODY, "", c("```{bash}", "echo 1", "```")))) {
    expect_engine(g5e_engine(lines), G5E_MSG4, G5E_HINT4)
  }
})

test_that("5e G38 case 4: a Python chunk and an R chunk with no engine key is not the Jupyter message", {
  x <- g5e_engine(c(G5E_BODY, "", g5e_en_py, "", g5e_en_r))
  expect_false(grepl("Jupyter", x$message, fixed = TRUE))
  expect_false(grepl("reticulate", x$hint, fixed = TRUE))
})

# ---- when it fires is unchanged ---------------------------------------------------------------------------

test_that("5e G38: with engine: knitr, in an .Rmd, or with a construct-free file, no finding", {
  expect_identical(nrow(g5e_engine(f3d_doc(c(G5E_BODY, "", g5e_en_py), "engine: knitr"))), 0L)
  expect_identical(nrow(g5e_engine(c(G5E_BODY, "", g5e_en_py), name = "a.Rmd")), 0L)
  expect_identical(nrow(g5e_engine(c("Plain words.", "", g5e_en_py))), 0L)
})
