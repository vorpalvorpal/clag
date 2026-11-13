# Package 6h: use_quarto() for a project with a julia-engine document (N74; message E62 of
# dev/design-6.md section 7). Written before the code. No Quarto, no Julia and no kernel are needed:
# use_quarto() only reads the project and writes files. Every project is a temporary folder.
#
# READINGS of the note (see the report, "Spec gaps"):
#  - the note does not say how a document is known to be on the julia engine; the tests take `engine: julia`
#    and a document whose only executed chunks are `{julia}` chunks with no `engine:` key (what Quarto
#    itself does), the same rule 6e used for Jupyter;
#  - a `{julia}` chunk in a document that says `engine: knitr` (JuliaCall) or that holds an `{r}` chunk is not
#    on the julia engine;
#  - `status()` gets no Julia row to test: the note says "Julia: `not checked`" under the Python row and the
#    package table gives 6h only `R/use.R`;
#  - E61 and E62 are each printed once per run, as E61 is.

JL_CHUNK <- c("```{julia}", "x = 1", "```")
R_CHUNK6H <- c("```{r}", "x <- 1", "```")
PY_CHUNK6H <- c("```{python}", "x = 1", "```")

ujl_doc <- function(front = "title: Home", chunk = JL_CHUNK) c("---", front, "---", "", "Some text.", "", chunk)

ujl_proj <- function(files) {
  dir <- tempfile("weft-uqjl-")
  dir.create(dir)
  dir <- normalizePath(dir, winslash = "/")
  writeLines(c("project:", "  type: default", "format: html"), file.path(dir, "_quarto.yml"))
  for (f in names(files)) {
    dir.create(dirname(file.path(dir, f)), showWarnings = FALSE, recursive = TRUE)
    writeLines(files[[f]], file.path(dir, f))
  }
  dir
}

# the messages use_quarto() sends (one string per message), and the printed output
ujl_says <- function(dir) {
  msgs <- character()
  out <- utils::capture.output(withCallingHandlers(
    weft::use_quarto(dir),
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    }))
  c(msgs, out)
}
ujl_n <- function(x, text) sum(grepl(text, x, fixed = TRUE))

E62_TEXT <- paste0("Install the Julia package: using Pkg; Pkg.add(url = \"https://github.com/vorpalvorpal/weft\", subdir = \"inst/julia/Weft\"). ",
                   "Quarto's Julia worker does not read JULIA_LOAD_PATH from the shell, so tell it where the package is in _quarto.yml: ",
                   "julia: {env: [\"JULIA_LOAD_PATH=<the folder that holds the Weft package>:\"]}, that is a julia: key with an env: list ",
                   "holding JULIA_LOAD_PATH=, a folder and a trailing colon.")
E61_TEXT <- "Install the Python package in the Python Quarto uses: pip install \"git+https://github.com/vorpalvorpal/weft#subdirectory=inst/python\""

test_that("N74: use_quarto() prints E62 for a project with a julia-engine document, whichever way the engine is chosen", {
  variants <- list(
    chunk = ujl_doc(),
    engine_key = ujl_doc("title: Home\nengine: julia", chunk = character()),
    engine_key_and_chunk = ujl_doc("title: Home\nengine: julia")
  )
  for (nm in names(variants)) {
    dir <- ujl_proj(list(`index.qmd` = variants[[nm]]))
    s <- ujl_says(dir)
    expect_identical(ujl_n(s, E62_TEXT), 1L, label = nm)
    expect_identical(ujl_n(s, E61_TEXT), 0L, label = paste(nm, "needs no Python package"))
  }
})

test_that("N74: use_quarto() prints E62 on every run, and for a document in a folder of the project", {
  dir <- ujl_proj(list(`index.qmd` = ujl_doc("title: Home", chunk = character()), `sub/page.qmd` = ujl_doc()))
  expect_identical(ujl_n(ujl_says(dir), E62_TEXT), 1L)
  expect_identical(ujl_n(ujl_says(dir), E62_TEXT), 1L)
})

test_that("N74: no E62 for a project with no julia-engine document", {
  projects <- list(
    knitr = list(`index.qmd` = ujl_doc(chunk = R_CHUNK6H)),
    plain = list(`index.qmd` = ujl_doc(chunk = character())),
    julia_on_knitr = list(`index.qmd` = ujl_doc("title: Home\nengine: knitr")),
    julia_with_r = list(`index.qmd` = ujl_doc(chunk = c(R_CHUNK6H, "", JL_CHUNK))),
    python = list(`index.qmd` = ujl_doc(chunk = PY_CHUNK6H)),
    none = list(`notes.md` = "Some text.")
  )
  for (nm in names(projects)) {
    expect_identical(ujl_n(ujl_says(ujl_proj(projects[[nm]])), E62_TEXT), 0L, label = nm)
  }
})

test_that("N74: a project with a Jupyter document and a julia document gets both messages, once each", {
  dir <- ujl_proj(list(`a.qmd` = ujl_doc(chunk = PY_CHUNK6H), `b.qmd` = ujl_doc()))
  s <- ujl_says(dir)
  expect_identical(ujl_n(s, E61_TEXT), 1L)
  expect_identical(ujl_n(s, E62_TEXT), 1L)
})

test_that("N74: use_quarto() installs the extension and scripts whatever the engine, and no Julia package", {
  jul <- ujl_proj(list(`index.qmd` = ujl_doc()))
  knit <- ujl_proj(list(`index.qmd` = ujl_doc(chunk = R_CHUNK6H)))
  before_j <- tree(jul)
  before_k <- tree(knit)
  suppressMessages(utils::capture.output(weft::use_quarto(jul)))
  suppressMessages(utils::capture.output(weft::use_quarto(knit)))
  added_j <- setdiff(tree(jul), before_j)
  added_k <- setdiff(tree(knit), before_k)
  expect_identical(added_j, added_k)
  expect_true(all(c("_extensions/weft-check/weft.lua", "_extensions/weft-check/weft-check.lua",
                    "_extensions/weft-check/_extension.yml", "_weft/pre-render.R", "_weft/post-render.R") %in% added_j))
  # nothing of Julia is written into the project
  expect_false(any(grepl("Project\\.toml|Manifest\\.toml|[.]jl$", added_j)))
})

test_that("control (N74): a project with a julia-engine document gets no E61 today", {
  s <- ujl_says(ujl_proj(list(`index.qmd` = ujl_doc())))
  expect_identical(ujl_n(s, E61_TEXT), 0L)
  expect_true(any(grepl("^Wrote: ", s)) || any(grepl("Nothing to change", s, fixed = TRUE)))
})
