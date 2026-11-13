# Package D of dev/refactor-sweep.md: one reading of a document's front block and engine.
#   front_block(lines)   the lines of the first metadata block, or character()
#   quarto_engine(lines) "knitr", "jupyter", "julia" or "markdown", by Quarto's rule
# doc_is_jupyter(), doc_is_julia() and filter_resolves() answer from the same reading.
#
# One case rule for chunk languages: only the lower-case `{python}`, `{julia}` and `{r}` are executable
# chunks (Quarto's own rule); `{Python}` and `{Julia}` are not, so a document holding only those is markdown.

# ---- front_block() ---------------------------------------------------------------------------------------------

test_that("sweep D front_block: the lines between the first `---` and its closing `---`", {
  expect_identical(weft:::front_block(c("---", "title: t", "author: a", "---", "body")), c("title: t", "author: a"))
})

test_that("sweep D front_block: a block closed by `...` is read as metadata_blocks() reads it", {
  expect_identical(weft:::front_block(c("---", "title: t", "...", "body")), "title: t")
})

test_that("sweep D front_block: trailing spaces, tabs and CR on the fence lines are tolerated", {
  expect_identical(weft:::front_block(c("--- ", "title: t", "---\t", "body")), "title: t")
  expect_identical(weft:::front_block(c("---\r", "title: t", "---\r", "body")), "title: t")
  expect_identical(weft:::front_block(c("---  \t\r", "title: t", "...\t ", "body")), "title: t")
})

test_that("sweep D front_block: only the first block is returned", {
  x <- c("---", "title: t", "---", "", "text", "", "---", "other: 1", "---")
  expect_identical(weft:::front_block(x), "title: t")
})

test_that("sweep D front_block: no front block gives character()", {
  expect_identical(weft:::front_block(character()), character())
  expect_identical(weft:::front_block(c("# Heading", "text")), character())
  # the first non-blank line is not a fence
  expect_identical(weft:::front_block(c("# Heading", "---", "title: t", "---")), character())
  # a block that never closes
  expect_identical(weft:::front_block(c("---", "title: t", "text")), character())
})

# ---- quarto_engine() -------------------------------------------------------------------------------------------

fence <- function(lang, ticks = "```") paste0(ticks, "{", lang, "}")
chunk <- function(lang) c(fence(lang), "1 + 1", "```")
fm <- function(...) c("---", "title: t", ..., "---", "")

# name = list(lines, engine)
ENGINE_DOCS <- list(
  no_chunks          = list(c(fm(), "Just prose."), "markdown"),
  empty              = list(character(), "markdown"),
  r_only             = list(c(fm(), chunk("r")), "knitr"),
  python_only        = list(c(fm(), chunk("python")), "jupyter"),
  julia_only         = list(c(fm(), chunk("julia")), "julia"),
  r_and_julia        = list(c(fm(), chunk("julia"), chunk("r")), "knitr"),
  r_and_python       = list(c(fm(), chunk("python"), chunk("r")), "knitr"),
  python_and_julia   = list(c(fm(), chunk("julia"), chunk("python")), "jupyter"),
  engine_julia_vs_r  = list(c(fm("engine: julia"), chunk("r")), "julia"),
  engine_knitr_vs_py = list(c(fm("engine: knitr"), chunk("python")), "knitr"),
  engine_jupyter     = list(c(fm("engine: jupyter"), "prose"), "jupyter"),
  engine_markdown    = list(c(fm("engine: markdown"), chunk("r")), "markdown"),
  engine_quoted      = list(c(fm("engine: \"julia\"  # comment"), chunk("r")), "julia"),
  engine_mapping     = list(c(fm("engine:", "  julia:", "    env: [\"A=1\"]"), chunk("r")), "julia"),
  jupyter_key        = list(c(fm("jupyter: python3"), "prose"), "jupyter"),
  jupyter_key_vs_r   = list(c(fm("jupyter: python3"), chunk("r")), "jupyter"),
  fence_in_4_ticks   = list(c(fm(), "````", fence("python"), "1", "```", "````", "prose"), "markdown"),
  four_ticks_real    = list(c(fm(), "````", fence("python"), "````", chunk("julia")), "julia"),
  upper_python       = list(c(fm(), chunk("Python")), "markdown"),
  upper_julia        = list(c(fm(), chunk("Julia")), "markdown"),
  no_front_block     = list(chunk("python"), "jupyter"),
  indented_chunk     = list(c(fm(), paste0("  ", fence("python")), "  1", "  ```"), "jupyter")
)

test_that("sweep D quarto_engine: Quarto's rule on a table of documents", {
  for (nm in names(ENGINE_DOCS)) {
    expect_identical(weft:::quarto_engine(ENGINE_DOCS[[nm]][[1]]), ENGINE_DOCS[[nm]][[2]], label = nm)
  }
})

test_that("sweep D quarto_engine: one case rule for {Python} and {Julia}, lower case only", {
  expect_identical(weft:::quarto_engine(c(fm(), chunk("Python"))), "markdown")
  expect_identical(weft:::quarto_engine(c(fm(), chunk("Julia"))), "markdown")
  # an upper-case chunk does not hide a lower-case one beside it
  expect_identical(weft:::quarto_engine(c(fm(), chunk("Python"), chunk("julia"))), "julia")
})

test_that("sweep D quarto_engine: the result is always one of the four engines", {
  got <- vapply(ENGINE_DOCS, function(d) weft:::quarto_engine(d[[1]]), "")
  expect_true(all(got %in% c("knitr", "jupyter", "julia", "markdown")))
  expect_gt(length(unique(got)), 3L)
})

test_that("sweep D: doc_is_jupyter() and doc_is_julia() agree with quarto_engine() on every document", {
  for (nm in names(ENGINE_DOCS)) {
    x <- ENGINE_DOCS[[nm]][[1]]
    e <- weft:::quarto_engine(x)
    expect_identical(weft:::doc_is_jupyter(x), e == "jupyter", label = paste("jupyter:", nm))
    expect_identical(weft:::doc_is_julia(x), e == "julia", label = paste("julia:", nm))
  }
})

# ---- filter_resolves(): pinned behaviour -----------------------------------------------------------------------

test_that("sweep D filter_resolves: the Lua filter resolves what the knitr hooks do not knit (as before)", {
  expect_false(weft:::filter_resolves(c(fm(), chunk("r"))))
  expect_true(weft:::filter_resolves(c(fm(), "Just prose.")))
  expect_true(weft:::filter_resolves(c(fm("engine: jupyter"), chunk("python"))))
  expect_false(weft:::filter_resolves(c(fm("engine: knitr"), chunk("python"))))
  expect_true(weft:::filter_resolves(c(fm("jupyter: python3"), chunk("r"))))
  expect_true(weft:::filter_resolves(c(fm(), "```{r, eval=FALSE}", "1", "```")))
  expect_false(weft:::filter_resolves(c(fm(), "prose"), file = "doc.Rmd"))
})
