# Package 7d: the installers' part of the rendered-output check (dev/design-7.md N50, section 4 "7d", section 5
# "test-use-quarto-output.R"). No render and no Pandoc here: only what use_quarto(), use_setup() and status()
# write and say.
#
# READINGS:
#  - "removal": there is no uninstaller; the removal that exists is status() noticing that the file or the entry
#    has gone, so that is what is tested (a project set up before this stage looks the same);
#  - a project with `filters: [weft-check]` is written in block style (`filters:` and `- weft-check`): a flow
#    sequence is refused by the editor today and stays refused;
#  - "after weft-check" is tested with weft-check last in the existing list, so that "after" and "last" agree;
#  - use_setup() under rmarkdown names `weft-output.lua` beside the document, as it does weft-check.lua, and
#    the pandoc_args end `"--lua-filter", "weft-output.lua"`.
# The existing tests that pin the exact file list of use_quarto() and the exact pandoc_args of use_setup()
# (test-use-quarto.R, test-use-setup-*.R, test-status.R's fixtures) are not edited here; they change with 7d.

OUT_REL <- "_extensions/weft-check/weft-output.lua"
OUT_ENTRY <- c("  - path: _extensions/weft-check/weft-output.lua", "    at: post-render")
OUT_ARGS <- c("--lua-filter", "weft.lua", "--lua-filter", "weft-check.lua", "--lua-filter", "weft-output.lua")

uo_project <- function(yml = c("project:", "  type: default", "format: html")) {
  u4_dir(list(`_quarto.yml` = yml, `index.qmd` = c("---", "title: Home", "---", "", "Some text.")))
}
uo_use <- function(dir) suppressMessages(utils::capture.output(res <- weft::use_quarto(dir)))
uo_yml <- function(dir) readLines(file.path(dir, "_quarto.yml"), warn = FALSE)
uo_shipped <- function() system.file("quarto", "weft-output.lua", package = "weft")
uo_entry_count <- function(lines) sum(grepl("weft-output.lua", lines, fixed = TRUE))

# ---- use_quarto(): the files -------------------------------------------------------------------------------

test_that("N50: use_quarto() copies weft-output.lua beside weft-check.lua, as the package ships it", {
  src <- uo_shipped()
  if (!expect_precondition(nzchar(src), "the package ships inst/quarto/weft-output.lua")) return(invisible())
  dir <- uo_project()
  uo_use(dir)
  expect_true(file.exists(file.path(dir, OUT_REL)))
  expect_identical(unname(tools::md5sum(file.path(dir, OUT_REL))), unname(tools::md5sum(src)))
  expect_true(file.exists(file.path(dir, "_extensions/weft-check/weft-check.lua")))
})

test_that("N50: a copy that differs is replaced by the package's file", {
  src <- uo_shipped()
  if (!expect_precondition(nzchar(src), "the package ships inst/quarto/weft-output.lua")) return(invisible())
  dir <- uo_project()
  uo_use(dir)
  writeLines("-- edited by hand", file.path(dir, OUT_REL))
  uo_use(dir)
  expect_identical(unname(tools::md5sum(file.path(dir, OUT_REL))), unname(tools::md5sum(src)))
})

test_that("N50 (control): the extension does not list weft-output.lua: an extension cannot place it (M2)", {
  dir <- uo_project()
  uo_use(dir)
  ext <- yaml::read_yaml(file.path(dir, "_extensions/weft-check/_extension.yml"))
  expect_false(any(grepl("weft-output", as_chr(ext$contributes$filters), fixed = TRUE)))
  expect_true("weft-check.lua" %in% as_chr(ext$contributes$filters))
})

test_that("N50: use_quarto() says it will write weft-output.lua (or the output filter)", {
  dir <- uo_project()
  says <- paste(c(utils::capture.output(withCallingHandlers(
    weft::use_quarto(dir), message = function(m) {
      cat(conditionMessage(m), "\n")
      invokeRestart("muffleMessage")
    }))), collapse = "\n")
  expect_match(says, "weft-output", fixed = TRUE)
})

# ---- use_quarto(): the _quarto.yml entry -------------------------------------------------------------------

test_that("N50: a new project gets the entry after weft-check, as a mapping with at: post-render, byte for byte", {
  dir <- uo_project()
  uo_use(dir)
  lines <- uo_yml(dir)
  i <- which(lines == "filters:")
  expect_length(i, 1L)
  if (length(i) == 1L) {
    expect_identical(lines[i + 0:3], c("filters:", "  - weft-check", OUT_ENTRY))
  }
  y <- yaml::read_yaml(file.path(dir, "_quarto.yml"))
  expect_identical(y$filters[[1]], "weft-check")
  expect_identical(y$filters[[2]]$path, "_extensions/weft-check/weft-output.lua")
  expect_identical(y$filters[[2]]$`at`, "post-render")
  expect_length(y$filters, 2L)
})

test_that("N50: a project set up before this stage (filters: weft-check) gets the entry added after it", {
  yml <- c("project:", "  type: default", "  pre-render: _weft/pre-render.R",
           "  post-render: _weft/post-render.R", "filters:", "  - weft-check", "format: html")
  dir <- uo_project(yml)
  uo_use(dir)
  lines <- uo_yml(dir)
  i <- which(lines == "filters:")
  expect_identical(lines[i + 0:3], c("filters:", "  - weft-check", OUT_ENTRY))
  expect_identical(lines[lines != OUT_ENTRY[1] & lines != OUT_ENTRY[2]], yml)   # nothing else changed
})

test_that("N50: other filters stay, in order, and the entry comes after weft-check", {
  yml <- c("project:", "  type: default", "filters:", "  - other.lua", "  - weft-check", "format: html")
  dir <- uo_project(yml)
  uo_use(dir)
  y <- yaml::read_yaml(file.path(dir, "_quarto.yml"))
  f <- y$filters
  expect_identical(f[[1]], "other.lua")
  expect_identical(f[[2]], "weft-check")
  expect_identical(f[[3]]$path, "_extensions/weft-check/weft-output.lua")
  expect_identical(f[[3]]$`at`, "post-render")
  expect_length(f, 3L)
})

test_that("N50: other keys, comments and anchors of _quarto.yml are kept as they were", {
  yml <- c("# my project", "project:", "  type: default", "  output-dir: out  # where", "format:", "  html:",
           "    toc: true", "execute:", "  freeze: auto")
  dir <- uo_project(yml)
  uo_use(dir)
  lines <- uo_yml(dir)
  for (l in yml) expect_true(l %in% lines, label = l)
  expect_identical(uo_entry_count(lines), 1L)
})

test_that("N50: run twice, nothing changes and there is one entry", {
  dir <- uo_project()
  uo_use(dir)
  files1 <- tree(dir)
  sums1 <- u4_md5(dir)
  yml1 <- uo_yml(dir)
  uo_use(dir)
  uo_use(dir)
  expect_identical(tree(dir), files1)
  expect_identical(u4_md5(dir), sums1)
  expect_identical(uo_yml(dir), yml1)
  expect_identical(uo_entry_count(uo_yml(dir)), 1L)
  expect_identical(sum(uo_yml(dir) == "  - weft-check"), 1L)
})

test_that("N50: a project that already holds the entry (written by hand) is not given a second", {
  yml <- c("project:", "  type: default", "filters:", "  - weft-check",
           "  - path: _extensions/weft-check/weft-output.lua", "    at: post-render", "format: html")
  dir <- uo_project(yml)
  uo_use(dir)
  expect_identical(uo_entry_count(uo_yml(dir)), 1L)
  expect_identical(sum(uo_yml(dir) == "  - weft-check"), 1L)
  expect_identical(sum(uo_yml(dir) == "    at: post-render"), 1L)
})

# ---- status() -----------------------------------------------------------------------------------------------

test_that("N50: status() quarto row is ok after use_quarto()", {
  dir <- uo_project()
  uo_use(dir)
  expect_identical(h4_state(h4_status(dir), "quarto"), "ok")
})

test_that("N50: status() reports the missing entry (a project set up before this stage), naming it", {
  dir <- uo_project()
  uo_use(dir)
  lines <- uo_yml(dir)
  writeLines(lines[!(lines %in% OUT_ENTRY)], file.path(dir, "_quarto.yml"))
  st <- h4_status(dir)
  expect_identical(h4_state(st, "quarto"), "missing")
  expect_match(h4_detail(st, "quarto"), "weft-output", fixed = TRUE)
  expect_match(attr(st, "next", exact = TRUE), "^Next: run weft::use_quarto\\(\\) to ")
})

test_that("N50: status() reports a missing weft-output.lua file, naming it", {
  dir <- uo_project()
  uo_use(dir)
  unlink(file.path(dir, OUT_REL))
  st <- h4_status(dir)
  expect_identical(h4_state(st, "quarto"), "missing")
  expect_match(h4_detail(st, "quarto"), "weft-output.lua", fixed = TRUE)
})

test_that("N50: status() says a copy of weft-output.lua that differs from the shipped one is not ok", {
  dir <- uo_project()
  uo_use(dir)
  writeLines("-- edited", file.path(dir, OUT_REL))
  expect_true(h4_state(h4_status(dir), "quarto") %in% c("edited", "outdated"))
})

test_that("N50: use_quarto() run again on that project brings it to ok, adding the file and the entry once", {
  dir <- uo_project()
  uo_use(dir)
  before <- u4_md5(dir)
  lines <- uo_yml(dir)
  writeLines(lines[!(lines %in% OUT_ENTRY)], file.path(dir, "_quarto.yml"))
  unlink(file.path(dir, OUT_REL))
  expect_identical(h4_state(h4_status(dir), "quarto"), "missing")
  uo_use(dir)
  expect_identical(h4_state(h4_status(dir), "quarto"), "ok")
  expect_identical(u4_md5(dir), before)
  expect_identical(uo_entry_count(uo_yml(dir)), 1L)
})

# ---- use_setup() under rmarkdown ------------------------------------------------------------------------------

rmd_front <- function(front) c("---", front, "---", "", "Some text.")

test_that("N50 rmarkdown: pandoc_args end with --lua-filter weft-output.lua, after weft-check.lua", {
  d <- u4_dir(list(`a.Rmd` = rmd_front("title: \"t\"")))
  u4_use(d)
  y <- u4_yaml(file.path(d, "a.Rmd"))
  expect_identical(y$output$html_document$pandoc_args, OUT_ARGS)
})

test_that("N50 rmarkdown: weft-output.lua is copied beside the document, as the package ships it", {
  src <- uo_shipped()
  if (!expect_precondition(nzchar(src), "the package ships inst/quarto/weft-output.lua")) return(invisible())
  d <- u4_dir(list(`a.Rmd` = rmd_front("title: a"), `sub/b.Rmd` = rmd_front("title: b")))
  u4_use(d)
  for (where in c(".", "sub")) {
    p <- file.path(d, where, "weft-output.lua")
    expect_true(file.exists(p), label = where)
    expect_identical(unname(tools::md5sum(p)), unname(tools::md5sum(src)), label = where)
  }
})

test_that("N50 rmarkdown: two formats each get weft-output.lua last; the author's arguments stay first", {
  d <- u4_dir(list(`a.Rmd` = rmd_front(c("title: t", "output:", "  html_document:", "    pandoc_args:",
                                         "      - \"--toc\"", "  pdf_document:", "    toc: false"))))
  u4_use(d)
  y <- u4_yaml(file.path(d, "a.Rmd"))
  expect_identical(y$output$html_document$pandoc_args, c("--toc", OUT_ARGS))
  expect_identical(y$output$pdf_document$pandoc_args, OUT_ARGS)
})

test_that("N50 rmarkdown: a document set up before this stage (weft.lua and weft-check.lua) gets weft-output.lua last", {
  old <- c("title: t", "knitr:", "  opts_knit:", "    weft: !expr weft::weft_setup()", "output:", "  html_document:",
           "    pandoc_args: [\"--lua-filter\", \"weft.lua\", \"--lua-filter\", \"weft-check.lua\"]")
  d <- u4_dir(list(`a.Rmd` = rmd_front(old)))
  u4_use(d)
  y <- u4_yaml(file.path(d, "a.Rmd"))
  expect_identical(y$output$html_document$pandoc_args, OUT_ARGS)
  expect_true(file.exists(file.path(d, "weft-output.lua")))
})

test_that("N50 rmarkdown: a second run changes nothing", {
  d <- u4_dir(list(`a.Rmd` = rmd_front(c("title: t", "output: pdf_document")), `b.Rmd` = rmd_front("title: b")))
  u4_use(d)
  before <- u4_md5(d)
  u4_use(d)
  expect_identical(u4_md5(d), before)
  y <- u4_yaml(file.path(d, "a.Rmd"))
  expect_identical(sum(y$output$pdf_document$pandoc_args == "weft-output.lua"), 1L)
})
