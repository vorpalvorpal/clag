# Package 6d: use_setup() and status() for documents that hold named values (N74's use_setup() part and G41 narrowed;
# rule 9.3.1 as amended; N140 file list of package 6d in dev/design-6.md). Helpers: helper-4d.R (u4_dir, u4_use,
# u4_md5, u4_read, u4_yaml, u4_front, U4_QUARTO_YML), helper-4b.R (h4_repo, h4_status, h4_detail, h4_state), helper-6d.R.
# No Python, Julia, Quarto or Pandoc is needed: nothing is run or rendered. Every project is a temporary folder.
#
# READINGS of the note (see the report):
#  - under rmarkdown the files beside each .Rmd are weft-check.lua (as today), weft.lua and the folder weftlib/ with the
#    files of the package's own weftlib/ (the tests compare the copies with the package's files, so they hold whatever
#    the package ships); the .Rmd then names `--lua-filter weft.lua` before `--lua-filter weft-check.lua`;
#  - an .Rmd set up before this stage, which names only weft-check.lua, gets weft.lua named before it when use_setup()
#    is run again (the note says weft.lua is named before weft-check.lua; it does not say what an upgrade does);
#  - a `.qmd` that has an executed R chunk is not covered by the narrowing and is not tested here.
#  - these tests need inst/quarto/weft.lua to exist (package 6c): use_setup() copies it, as it copies weft-check.lua.

py_chunk <- c("```{python}", "x = 1", "```")
jl_chunk <- c("```{julia}", "x = 1", "```")
sh_chunk <- c("```{bash}", "echo 1", "```")

qdoc <- function(body, chunk, front = "title: t") c("---", front, "---", "", body, "", chunk)
qproj <- function(files) u4_dir(c(list(`_quarto.yml` = U4_QUARTO_YML), files))

NAMED_BODY <- "The depth is `depth`{.num} metres and the site `site`{.val}."
GRAMMAR_SPANS <- list(
  `if`  = r"{The level [rose | fell]{if="up"} again.}",
  `if2` = r"{The level [rose | fell]{if="n_gap > 10, n_sites >= 3"} again.}",
  n     = r"{We saw [a site | # sites]{n="k"} today.}",
  n_dot = r"{We saw [a site | # sites]{n="."} today.}",
  sign  = r"{The level [rose | fell]{sign="d"} again.}",
  list  = r"{[No sites were | # was | # were]{list="flagged"} flagged.}"
)
OUTSIDE_SPANS <- list(
  n_lit  = r"{We saw [a site | # sites]{n="3"} today.}",
  if_and = r"{The level [rose | fell]{if="a && b"} again.}",
  if_lit = r"{The level [rose | fell]{if="3 > 2"} again.}",
  sign_n = r"{The level [rose | fell]{sign="3"} again.}",
  list_n = r"{[No sites were | # was | # were]{list="3"} flagged.}"
)
RVALUE <- "The depth is `r x`{.num} metres."

# ---- use_setup(): a .qmd of another engine's chunks (G41 narrowed, N74) ----------------------------------------------

test_that("N74: a Python-only .qmd whose constructs are all named values or spans of the grammar is left byte for byte", {
  bodies <- c(list(named = NAMED_BODY), GRAMMAR_SPANS,
              list(mixed = c(NAMED_BODY, "", GRAMMAR_SPANS$`if`, "", GRAMMAR_SPANS$n)))
  files <- stats::setNames(lapply(bodies, qdoc, chunk = py_chunk), paste0(names(bodies), ".qmd"))
  q <- qproj(files)
  before <- u4_md5(q)
  u4_use(q)
  after <- u4_md5(q)
  for (f in names(files)) expect_identical(after[f], before[f], label = f)
})

test_that("N74: the same for a Julia-only and a bash-only .qmd", {
  files <- list(`jl.qmd` = qdoc(c(NAMED_BODY, "", GRAMMAR_SPANS$`if`), jl_chunk),
                `sh.qmd` = qdoc(c(NAMED_BODY, "", GRAMMAR_SPANS$sign), sh_chunk))
  q <- qproj(files)
  before <- u4_md5(q)
  u4_use(q)
  for (f in names(files)) expect_identical(u4_md5(q)[f], before[f], label = f)
})

test_that("N74: a Python-only .qmd with no front matter and a grammar span is left alone", {
  q <- qproj(list(`py.qmd` = c(GRAMMAR_SPANS$`if`, "", py_chunk)))
  before <- u4_md5(q)
  u4_use(q)
  expect_identical(u4_md5(q)[["py.qmd"]], before[["py.qmd"]])
})

test_that("N74: an R value `r x`{...} still gets engine: knitr as a top-level key, alone or beside named values", {
  for (body in list(RVALUE, c(NAMED_BODY, "", RVALUE), c(RVALUE, "", GRAMMAR_SPANS$`if`))) {
    q <- qproj(list(`py.qmd` = qdoc(body, py_chunk, c("title: t", "author: A. Author"))))
    u4_use(q)
    y <- u4_yaml(file.path(q, "py.qmd"))
    expect_identical(y$engine, "knitr")
    expect_identical(y$title, "t")
    expect_identical(y$author, "A. Author")
    expect_identical(sum(grepl("^engine:", u4_read(q, "py.qmd"))), 1L)
  }
})

test_that("N74: a span outside the grammar still gets engine: knitr, with the document's text and chunk kept", {
  for (nm in names(OUTSIDE_SPANS)) {
    q <- qproj(list(`py.qmd` = qdoc(c(NAMED_BODY, "", OUTSIDE_SPANS[[nm]]), py_chunk)))
    u4_use(q)
    expect_identical(u4_yaml(file.path(q, "py.qmd"))$engine, "knitr", label = nm)
    now <- u4_read(q, "py.qmd")
    expect_true(OUTSIDE_SPANS[[nm]] %in% now, label = nm)
    expect_true(all(py_chunk %in% now), label = nm)
  }
})

test_that("N74: a Julia-only .qmd with an R value or a span outside the grammar gets the line", {
  q <- qproj(list(`jl.qmd` = qdoc(RVALUE, jl_chunk), `jl2.qmd` = qdoc(OUTSIDE_SPANS$n_lit, jl_chunk)))
  u4_use(q)
  expect_identical(u4_yaml(file.path(q, "jl.qmd"))$engine, "knitr")
  expect_identical(u4_yaml(file.path(q, "jl2.qmd"))$engine, "knitr")
})

test_that("N74: engine: jupyter, jupyter: python3 and engine: julia are kept as they are, whatever they hold", {
  q <- qproj(list(
    `jup.qmd`  = qdoc(c(NAMED_BODY, "", GRAMMAR_SPANS$`if`), py_chunk, "engine: jupyter"),
    `jup2.qmd` = qdoc(c(NAMED_BODY, "", RVALUE), py_chunk, "jupyter: python3"),
    `jul.qmd`  = qdoc(c(NAMED_BODY, "", OUTSIDE_SPANS$n_lit), jl_chunk, "engine: julia")
  ))
  before <- u4_md5(q)
  u4_use(q)
  after <- u4_md5(q)
  for (f in c("jup.qmd", "jup2.qmd", "jul.qmd")) expect_identical(after[f], before[f], label = f)
})

test_that("N74: a second use_setup() changes nothing more", {
  q <- qproj(list(`a.qmd` = qdoc(c(NAMED_BODY, "", GRAMMAR_SPANS$`if`), py_chunk),
                  `b.qmd` = qdoc(RVALUE, py_chunk)))
  u4_use(q)
  once <- u4_md5(q)
  u4_use(q)
  expect_identical(u4_md5(q), once)
})

# ---- status() agrees with use_setup() --------------------------------------------------------------------------------

st_dir <- function(doc, env = parent.frame()) {
  h4_repo(list(`_quarto.yml` = U4_QUARTO_YML, `.Rprofile` = U4_RPROFILE, `a.qmd` = doc), weft = character(),
          origin = NULL, env = env)
}
flagged <- function(st) grepl("engine", h4_detail(st, "activation"), fixed = TRUE)

ST_CASES <- list(
  "python, named values"        = qdoc(NAMED_BODY, py_chunk),
  "python, an if span"          = qdoc(GRAMMAR_SPANS$`if`, py_chunk),
  "python, an n span"           = qdoc(GRAMMAR_SPANS$n, py_chunk),
  "python, a list span"         = qdoc(GRAMMAR_SPANS$list, py_chunk),
  "python, named and span"      = qdoc(c(NAMED_BODY, "", GRAMMAR_SPANS$sign), py_chunk),
  "python, an R value"          = qdoc(RVALUE, py_chunk),
  "python, a literal n"         = qdoc(OUTSIDE_SPANS$n_lit, py_chunk),
  "python, an && condition"     = qdoc(OUTSIDE_SPANS$if_and, py_chunk),
  "julia, named values"         = qdoc(NAMED_BODY, jl_chunk),
  "julia, an R value"           = qdoc(RVALUE, jl_chunk),
  "jupyter, named values"       = qdoc(NAMED_BODY, py_chunk, "engine: jupyter")
)

for (nm in names(ST_CASES)) local({
  nm <- nm
  doc <- ST_CASES[[nm]]
  test_that(paste0("N74: status() flags a.qmd exactly when use_setup() would change it (", nm, ")"), {
    dir <- st_dir(doc)
    before <- unname(tools::md5sum(file.path(dir, "a.qmd")))
    flagged_before <- flagged(h4_status(dir))
    suppressMessages(utils::capture.output(weft::use_setup(dir)))
    changed <- !identical(unname(tools::md5sum(file.path(dir, "a.qmd"))), before)
    expect_identical(flagged_before, changed)
    st <- h4_status(dir)
    expect_false(flagged(st))
    expect_identical(h4_state(st, "activation"), "ok")
  })
})

test_that("N74: status() does not flag a Python document of named values, and does flag one with an R value", {
  expect_false(flagged(h4_status(st_dir(qdoc(NAMED_BODY, py_chunk)))))
  expect_false(flagged(h4_status(st_dir(qdoc(GRAMMAR_SPANS$`if`, py_chunk)))))
  expect_true(flagged(h4_status(st_dir(qdoc(RVALUE, py_chunk)))))
  expect_true(flagged(h4_status(st_dir(qdoc(OUTSIDE_SPANS$n_lit, py_chunk)))))
})

# ---- use_setup() under rmarkdown: weft.lua and weftlib/ beside the document -------------------------------------------

rmd_with <- function(front) c("---", front, "---", "", "Some text.")
LUA_ARGS <- c("--lua-filter", "weft.lua", "--lua-filter", "weft-check.lua")
quarto_dir <- function(...) system.file("quarto", ..., package = "weft")
weftlib_files <- function() sort(list.files(quarto_dir("weftlib"), recursive = TRUE))

test_that("N74 rmarkdown: pandoc_args names weft.lua before weft-check.lua, under html_document by default", {
  d <- u4_dir(list(`a.Rmd` = rmd_with("title: \"t\"")))
  u4_use(d)
  y <- u4_yaml(file.path(d, "a.Rmd"))
  expect_identical(names(y$output), "html_document")
  expect_identical(y$output$html_document$pandoc_args, LUA_ARGS)
  expect_identical(y$knitr$opts_knit$weft, "!expr weft::weft_setup()")
})

test_that("N74 rmarkdown: a scalar output becomes a mapping with both filters; two formats each get both", {
  d <- u4_dir(list(`a.Rmd` = rmd_with(c("title: t", "output: pdf_document")),
                   `b.Rmd` = rmd_with(c("title: t", "output:", "  html_document:", "    toc: true",
                                        "  pdf_document:", "    toc: false"))))
  u4_use(d)
  ya <- u4_yaml(file.path(d, "a.Rmd"))
  expect_identical(ya$output$pdf_document$pandoc_args, LUA_ARGS)
  yb <- u4_yaml(file.path(d, "b.Rmd"))
  expect_true(yb$output$html_document$toc)
  expect_identical(yb$output$html_document$pandoc_args, LUA_ARGS)
  expect_identical(yb$output$pdf_document$pandoc_args, LUA_ARGS)
})

test_that("N74 rmarkdown: block-style pandoc_args get the four items appended, after the author's", {
  d <- u4_dir(list(`a.Rmd` = rmd_with(c("title: t", "output:", "  html_document:", "    pandoc_args:",
                                        "      - \"--toc\"", "      - \"--number-sections\""))))
  u4_use(d)
  y <- u4_yaml(file.path(d, "a.Rmd"))
  expect_identical(y$output$html_document$pandoc_args, c("--toc", "--number-sections", LUA_ARGS))
})

test_that("N74 rmarkdown: weft.lua and the files of weftlib/ are copied beside the document, as the package ships them", {
  libs <- weftlib_files()
  if (!expect_precondition(length(libs) > 0L, "the package ships weftlib/ files")) return(invisible())
  d <- u4_dir(list(`a.Rmd` = rmd_with("title: t")))
  u4_use(d)
  expect_true(file.exists(file.path(d, "weft.lua")))
  expect_true(file.exists(file.path(d, "weft-check.lua")))
  expect_identical(sort(list.files(file.path(d, "weftlib"), recursive = TRUE)), libs)
  for (f in libs) {
    expect_identical(unname(tools::md5sum(file.path(d, "weftlib", f))),
                     unname(tools::md5sum(quarto_dir("weftlib", f))), label = f)
  }
  src <- quarto_dir("weft.lua")
  if (expect_precondition(nzchar(src), "the package ships weft.lua")) {
    expect_identical(unname(tools::md5sum(file.path(d, "weft.lua"))), unname(tools::md5sum(src)))
  }
})

test_that("N74 rmarkdown: the files go beside each document, in its own folder", {
  d <- u4_dir(list(`a.Rmd` = rmd_with("title: a"), `sub/b.Rmd` = rmd_with("title: b")))
  u4_use(d)
  for (where in c(".", "sub")) {
    expect_true(file.exists(file.path(d, where, "weft.lua")), label = where)
    expect_true(file.exists(file.path(d, where, "weft-check.lua")), label = where)
    expect_true(dir.exists(file.path(d, where, "weftlib")), label = where)
  }
})

test_that("N74 rmarkdown: a copy of weft.lua that differs is replaced by the package's file", {
  d <- u4_dir(list(`a.Rmd` = rmd_with("title: t")))
  u4_use(d)
  writeLines("-- edited by hand", file.path(d, "weft.lua"))
  u4_use(d)
  src <- quarto_dir("weft.lua")
  if (expect_precondition(nzchar(src), "the package ships weft.lua")) {
    expect_identical(unname(tools::md5sum(file.path(d, "weft.lua"))), unname(tools::md5sum(src)))
  }
})

test_that("N74 rmarkdown: a second run changes nothing", {
  d <- u4_dir(list(`a.Rmd` = rmd_with(c("title: t", "output: pdf_document")), `b.Rmd` = rmd_with("title: b")))
  u4_use(d)
  before <- u4_md5(d)
  u4_use(d)
  expect_identical(u4_md5(d), before)
})

test_that("N74 rmarkdown: an .Rmd set up before this stage, naming only weft-check.lua, gets weft.lua named before it", {
  old <- c("title: t", "knitr:", "  opts_knit:", "    weft: !expr weft::weft_setup()", "output:", "  html_document:",
           "    pandoc_args:", "      - \"--lua-filter\"", "      - \"weft-check.lua\"")
  d <- u4_dir(list(`a.Rmd` = rmd_with(old), `weft-check.lua` = "-- old copy"))
  u4_use(d)
  y <- u4_yaml(file.path(d, "a.Rmd"))
  expect_identical(y$output$html_document$pandoc_args, LUA_ARGS)
  expect_true(file.exists(file.path(d, "weft.lua")))
  before <- u4_md5(d)
  u4_use(d)
  expect_identical(u4_md5(d), before)
})

test_that("N74 control: the .Rmd's body is untouched, and a Quarto project of .qmd files gets no weft.lua beside its documents", {
  body <- c("", "Some text.", "", "```{r}", "x <- 1", "```")
  d <- u4_dir(list(`a.Rmd` = c("---", "title: t", "---", body)))
  u4_use(d)
  expect_identical(utils::tail(u4_read(d, "a.Rmd"), length(body)), body)
  q <- qproj(list(`a.qmd` = qdoc(NAMED_BODY, py_chunk)))
  u4_use(q)
  expect_false(file.exists(file.path(q, "weft.lua")))
  expect_false(dir.exists(file.path(q, "weftlib")))
})
