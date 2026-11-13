# Package 5e: use_setup() and status() on a .qmd that holds only another engine's chunks (dev/design-5.md G41, V14,
# O5; reverses part of H29). Helpers: helper-4d.R (u4_dir, u4_use, u4_md5, u4_read, u4_yaml, U4_QUARTO_YML),
# helper-4b.R (h4_repo, h4_status, h4_detail, h4_state). No Python or Julia is needed: nothing is run or rendered.
# READING: a "construct" is a scanner row other than bare, link or literal, so `r x`{.num} and [a | b]{n="k"} count and
# `r x`, [text](url) and a .weft-literal span do not.

g5e_py_chunk <- c("```{python}", "x = 1", "```")
g5e_jl_chunk <- c("```{julia}", "x = 1", "```")
g5e_sh_chunk <- c("```{bash}", "echo 1", "```")
G5E_CONSTRUCT <- "The depth is `r x`{.num} metres."
G5E_CONSTRUCTS <- list(
  num   = "The depth is `r x`{.num} metres.",
  n     = r"{We visited [a site | # sites]{n="3"}.}",
  if_   = r"{The level [rose | fell]{if="up"} again.}",
  sign  = r"{The level [x]{sign="d"} again.}"
)
G5E_NO_CONSTRUCT <- list(
  bare    = "The depth is `r x` metres.",
  link    = "See [the page](a.html) for more.",
  literal = "A [10]{.weft-literal why=\"SOP\"} here.",
  plain   = "Plain words only."
)

g5e_qproj <- function(files) u4_dir(c(list(`_quarto.yml` = U4_QUARTO_YML), files))
g5e_doc <- function(body, chunk, front = "title: t") c("---", front, "---", "", body, "", chunk)

# ---- use_setup() ------------------------------------------------------------------------------------------

test_that("5e G41: a Python-only .qmd that holds a construct gains engine: knitr as a top-level key", {
  for (nm in names(G5E_CONSTRUCTS)) {
    q <- g5e_qproj(list(`py.qmd` = g5e_doc(G5E_CONSTRUCTS[[nm]], g5e_py_chunk, c("title: t", "author: A. Author"))))
    u4_use(q)
    y <- u4_yaml(file.path(q, "py.qmd"))
    expect_identical(y$engine, "knitr", label = nm)
    expect_identical(y$title, "t", label = nm)
    expect_identical(y$author, "A. Author", label = nm)
    expect_identical(sum(grepl("^engine:", u4_read(q, "py.qmd"))), 1L, label = nm)
    # its text and chunks are still there
    now <- u4_read(q, "py.qmd")
    expect_true(G5E_CONSTRUCTS[[nm]] %in% now, label = nm)
    expect_true(all(g5e_py_chunk %in% now), label = nm)
  }
})

test_that("5e G41: the same for a Julia-only or a bash-only .qmd", {
  q <- g5e_qproj(list(`jl.qmd` = g5e_doc(G5E_CONSTRUCT, g5e_jl_chunk), `sh.qmd` = g5e_doc(G5E_CONSTRUCT, g5e_sh_chunk)))
  u4_use(q)
  expect_identical(u4_yaml(file.path(q, "jl.qmd"))$engine, "knitr")
  expect_identical(u4_yaml(file.path(q, "sh.qmd"))$engine, "knitr")
})

test_that("5e G41: a Python-only .qmd with no front matter gains a front matter block with the line", {
  q <- g5e_qproj(list(`py.qmd` = c(G5E_CONSTRUCT, "", g5e_py_chunk)))
  orig <- u4_read(q, "py.qmd")
  u4_use(q)
  now <- u4_read(q, "py.qmd")
  expect_identical(now[1:3], c("---", "engine: knitr", "---"))
  expect_identical(utils::tail(now, length(orig)), orig)
})

test_that("5e G41: a Python-only .qmd with no construct is left byte for byte (H29)", {
  files <- stats::setNames(lapply(G5E_NO_CONSTRUCT, g5e_doc, chunk = g5e_py_chunk),
                           paste0(names(G5E_NO_CONSTRUCT), ".qmd"))
  q <- g5e_qproj(files)
  before <- u4_md5(q)
  u4_use(q)
  after <- u4_md5(q)
  for (f in names(files)) expect_identical(after[f], before[f], label = f)
})

test_that("5e G41: engine: jupyter and jupyter: python3 are kept, with a construct", {
  q <- g5e_qproj(list(
    `jup.qmd`  = g5e_doc(G5E_CONSTRUCT, g5e_py_chunk, "engine: jupyter"),
    `jup2.qmd` = g5e_doc(G5E_CONSTRUCT, g5e_py_chunk, "jupyter: python3"),
    `jul.qmd`  = g5e_doc(G5E_CONSTRUCT, g5e_jl_chunk, "engine: julia")
  ))
  before <- u4_md5(q)
  u4_use(q)
  after <- u4_md5(q)
  for (f in c("jup.qmd", "jup2.qmd", "jul.qmd")) expect_identical(after[f], before[f], label = f)
})

test_that("5e G41: a document with R chunks keeps getting the line, as before", {
  q <- g5e_qproj(list(`both.qmd` = g5e_doc(G5E_CONSTRUCT, c(g5e_py_chunk, "", "```{r}", "x <- 1", "```"))))
  u4_use(q)
  expect_identical(u4_yaml(file.path(q, "both.qmd"))$engine, "knitr")
})

test_that("5e G41: a second use_setup() changes nothing more", {
  q <- g5e_qproj(list(`py.qmd` = g5e_doc(G5E_CONSTRUCT, g5e_py_chunk)))
  u4_use(q)
  once <- u4_md5(q)
  u4_use(q)
  expect_identical(u4_md5(q), once)
})

# ---- status() agrees --------------------------------------------------------------------------------------

g5e_status_dir <- function(doc, env = parent.frame()) {
  h4_repo(list(`_quarto.yml` = U4_QUARTO_YML, `.Rprofile` = U4_RPROFILE, `a.qmd` = doc), weft = character(),
          origin = NULL, env = env)
}
g5e_flagged <- function(st) grepl("engine", h4_detail(st, "activation"), fixed = TRUE)

g5e_cases <- list(
  "python with a construct"  = g5e_doc(G5E_CONSTRUCT, g5e_py_chunk),
  "python with an n span"    = g5e_doc(G5E_CONSTRUCTS$n, g5e_py_chunk),
  "python, bare value only"  = g5e_doc(G5E_NO_CONSTRUCT$bare, g5e_py_chunk),
  "python, link only"        = g5e_doc(G5E_NO_CONSTRUCT$link, g5e_py_chunk),
  "python, literal only"     = g5e_doc(G5E_NO_CONSTRUCT$literal, g5e_py_chunk),
  "python, plain"            = g5e_doc(G5E_NO_CONSTRUCT$plain, g5e_py_chunk),
  "julia with a construct"   = g5e_doc(G5E_CONSTRUCT, g5e_jl_chunk),
  "jupyter with a construct" = g5e_doc(G5E_CONSTRUCT, g5e_py_chunk, "engine: jupyter"),
  "jupyter key"              = g5e_doc(G5E_CONSTRUCT, g5e_py_chunk, "jupyter: python3"),
  "knitr already"            = g5e_doc(G5E_CONSTRUCT, g5e_py_chunk, "engine: knitr")
)

for (nm in names(g5e_cases)) local({
  nm <- nm
  doc <- g5e_cases[[nm]]
  test_that(paste0("5e G41: status() flags a.qmd exactly when use_setup() would change it (", nm, ")"), {
    dir <- g5e_status_dir(doc)
    before <- unname(tools::md5sum(file.path(dir, "a.qmd")))
    flagged_before <- g5e_flagged(h4_status(dir))
    suppressMessages(utils::capture.output(weft::use_setup(dir)))
    changed <- !identical(unname(tools::md5sum(file.path(dir, "a.qmd"))), before)
    expect_identical(flagged_before, changed)
    st <- h4_status(dir)
    expect_false(g5e_flagged(st))
    expect_identical(h4_state(st, "activation"), "ok")
  })
})

test_that("5e G41: status() flags the Python-only document with a construct, and not the one without", {
  flagged <- function(doc) g5e_flagged(h4_status(g5e_status_dir(doc)))
  expect_true(flagged(g5e_doc(G5E_CONSTRUCT, g5e_py_chunk)))
  expect_false(flagged(g5e_doc(G5E_NO_CONSTRUCT$plain, g5e_py_chunk)))
})
