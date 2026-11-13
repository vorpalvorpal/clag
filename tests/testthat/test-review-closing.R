# Regression tests for the closing review (dev/review-closing.md; rulings at its end).
# Written before the fixes. ASCII only. Made-up values only.
if (!exists("cl_render")) source(Filter(file.exists, c(testthat::test_path("helper-closing.R"), testthat::test_path("..", "helper-closing.R")))[[1]])

DH <- c("library(targets)", "c(weft::tar_dict(\"dict.yml\"),")

# ---- #1: a copy of dict held in a target's value is not guarded ----------------------------------------------

test_that("review closing #1: a target that reads a stored copy of dict (params$a) builds, inside tar_dict_deps()", {
  cl_need_pipe()
  d <- e1_pipe(c(DH, "  weft::tar_dict_deps(list(tar_target(params, dict), tar_target(y, params$a + 1))))"))
  expect_null(e1_try_make(d))
  if (file.exists(file.path(d, "_targets", "objects", "y"))) expect_equal(withr::with_dir(d, targets::tar_read(y)), 2)
})

test_that("review closing #1: a report that reads the stored copy through tar_read() builds", {
  cl_need_pipe()
  skip_if_not_installed("tarchetypes")
  skip_if_not(rmarkdown::pandoc_available(), "pandoc is not available")
  d <- e1_pipe(c(DH, "  weft::tar_dict_deps(list(tar_target(params, dict),",
                 "    tarchetypes::tar_render(report, \"report.Rmd\", output_format = rmarkdown::md_document()))))"),
               files = list("report.Rmd" = c("---", "title: r", "---", "", "A is `r targets::tar_read(params)$a`.")))
  expect_null(e1_try_make(d))
})

test_that("review closing #1: a real violation names the key actually read, and not another", {
  cl_need_pipe()
  d <- e1_pipe(c(DH, "  list(tar_target(outside, dict$a * 2)))"))
  e <- e1_try_make(d)
  expect_false(is.null(e))
  msg <- e1_flat(e)
  expect_true(grepl("outside", msg, fixed = TRUE))
  expect_true(grepl("dict$a", msg, fixed = TRUE) || grepl("dict_a", msg, fixed = TRUE))
  expect_false(grepl("dict_b", msg, fixed = TRUE))
  expect_false(grepl("dict$b", msg, fixed = TRUE))
  expect_false(grepl("dict$`", msg, fixed = TRUE))
})

test_that("review closing #1: a real violation by a whole-dictionary read does not name a key it never read", {
  cl_need_pipe()
  d <- e1_pipe(c(DH, "  list(tar_target(outside, length(names(dict)))))"))
  e <- e1_try_make(d)
  expect_false(is.null(e))
  msg <- e1_flat(e)
  expect_true(grepl("outside", msg, fixed = TRUE))
  expect_false(grepl("dict$a", msg, fixed = TRUE))
  expect_false(grepl("dict$b", msg, fixed = TRUE))
})

# ---- #2: reads of the report walker --------------------------------------------------------------------------

cl_qproj <- function() {
  d <- withr::local_tempdir(.local_envir = parent.frame())
  e1_put(d, list("_quarto.yml" = c("project:", "  type: default"),
                 "_part.qmd" = "Limit `r dict$limit`{.num}.",
                 "sub/my part.qmd" = "Limit `r dict$limit`{.num}.",
                 "sub/doc.qmd" = "x"))
  normalizePath(d)
}

cl_walk <- function(d, include) {
  writeLines(c("---", "title: t", "---", "", include), file.path(d, "sub", "doc.qmd"))
  withr::with_dir(d, weft:::report_reads("sub/doc.qmd", globalenv(), "limit")$keys)
}

test_that("review closing #2: an include rooted at / resolves against the project root", {
  d <- cl_qproj()
  expect_identical(cl_walk(d, "{{< include /_part.qmd >}}"), "limit")
})

test_that("review closing #2: a quoted include path may hold a space", {
  d <- cl_qproj()
  expect_identical(cl_walk(d, "{{< include \"my part.qmd\" >}}"), "limit")
})

test_that("review closing #2 control: a relative include (../_part.qmd) is followed", {
  d <- cl_qproj()
  expect_identical(cl_walk(d, "{{< include ../_part.qmd >}}"), "limit")
})

RMD_COMPUTED <- c("---", "title: r", "---", "", "```{r setup, include=FALSE}", "weft::weft_setup()", "part <- 'part.Rmd'", "```", "",
                  "```{r, child = part}", "```")

test_that("review closing #2: a report whose child= is computed re-runs when a key it reads changes", {
  cl_need_pipe()
  skip_if_not_installed("tarchetypes")
  skip_if_not(rmarkdown::pandoc_available(), "pandoc is not available")
  s <- cl_report_seq("closing-child-read",
    c(DH, "  weft::tar_dict_deps(list(tarchetypes::tar_render(report, \"report.Rmd\", output_format = rmarkdown::md_document()))))"),
    list("report.Rmd" = RMD_COMPUTED, "part.Rmd" = "The a is `r dict$a`.", "_weft.yml" = "draft: false"),
    edit_vals = list(a = 7, b = 2))
  expect_null(s$err)
  expect_null(s$err3)
  expect_true("report" %in% s$after_val)
})

test_that("review closing #2: a report whose child= is computed depends on every key (a key it does not read changes)", {
  cl_need_pipe()
  skip_if_not_installed("tarchetypes")
  skip_if_not(rmarkdown::pandoc_available(), "pandoc is not available")
  s <- cl_report_seq("closing-child-any",
    c(DH, "  weft::tar_dict_deps(list(tarchetypes::tar_render(report, \"report.Rmd\", output_format = rmarkdown::md_document()))))"),
    list("report.Rmd" = RMD_COMPUTED, "part.Rmd" = "The a is `r dict$a`.", "_weft.yml" = "draft: false"),
    edit_vals = list(a = 1, b = 9))
  expect_null(s$err)
  expect_null(s$err3)
  expect_true("report" %in% s$after_val)
})

test_that("review closing #2: scanning a report with a child= that cannot be evaluated prints nothing to the console", {
  cl_need_pipe()
  skip_if_not_installed("tarchetypes")
  d <- e1_tmp()
  e1_dict(d)
  e1_put(d, list("report.Rmd" = RMD_COMPUTED, "part.Rmd" = "The a is `r dict$a`."))
  withr::local_dir(d)
  # tar_render() itself prints the failed evaluation of the option; only weft's scan is captured
  utils::capture.output(tg <- suppressMessages(tarchetypes::tar_render(report, "report.Rmd")), type = "message")
  out <- capture.output(msg <- capture.output(res <- weft::tar_dict_deps(list(tg)), type = "message"))
  expect_identical(out, character())
  expect_identical(msg, character())
  expect_true("report" %in% e1_names(res))
})

# ---- #3: an empty dictionary ---------------------------------------------------------------------------------

test_that("review closing #3: with no keys, names(dict) and as.list(dict) in a target build (they are empty)", {
  cl_need_pipe()
  d <- e1_pipe(c(DH, "  weft::tar_dict_deps(list(tar_target(n, length(names(dict))), tar_target(l, length(as.list(dict))))))"),
               files = list("dict.yml" = "# no entries yet"))
  expect_null(e1_try_make(d))
  if (file.exists(file.path(d, "_targets", "objects", "n"))) {
    expect_identical(withr::with_dir(d, targets::tar_read(n)), 0L)
    expect_identical(withr::with_dir(d, targets::tar_read(l)), 0L)
  }
})

# ---- #4: a list item's or quote's sentence ends before the next block marker ---------------------------------

CL_LIST <- c("- Rain was `r 3`{.num} mm on the day",
             "- Flow was `r 4`{.num} ML",
             "1. Third `r 5`{.num} here",
             "2. Fourth item",
             "",
             "> Quoted `r 7`{.num} here.",
             "> Next quoted line.",
             "",
             "- Last `r 9`{.num} item")

cl_sentence <- function(res, expr) d2_one(d2_ledger(res), expr = expr)$sentence

test_that("review closing #4: the sentence of a list item or a quoted line does not end with the next marker", {
  res <- d2_render(CL_LIST)
  expect_identical(cl_sentence(res, "3"), "Rain was 3 mm on the day")
  expect_identical(cl_sentence(res, "4"), "Flow was 4 ML")
  expect_identical(cl_sentence(res, "5"), "Third 5 here")
  expect_identical(cl_sentence(res, "7"), "Quoted 7 here.")
})

test_that("review closing #4 control: the last item of a list has no marker after it", {
  res <- d2_render(CL_LIST)
  expect_identical(cl_sentence(res, "9"), "Last 9 item")
})

# ---- #5: .^[note] ----------------------------------------------------------------------------------------------

test_that("review closing #5: a boundary after .^[note] stands; the sentence is not joined to the next", {
  s <- weft:::ledger_sentence("It was 3 mm.^[A note. With two sentences.] Then it stopped.", 8, 11)
  expect_false(grepl("Then it stopped", s, fixed = TRUE))
  expect_true(startsWith(s, "It was 3 mm."))
})

test_that("review closing #5 control: a plain full stop, and a [^1] reference after it, still end the sentence", {
  s1 <- weft:::ledger_sentence("It was 3 mm. Then it stopped.", 8, 11)
  expect_identical(s1, "It was 3 mm.")
  s2 <- weft:::ledger_sentence("It was 3 mm.[^1] Then it stopped.", 8, 11)
  expect_false(grepl("Then it stopped", s2, fixed = TRUE))
})

# ---- #6: a reader's default arguments -------------------------------------------------------------------------

test_that("review closing #6: a reader's default store is the store of a call that omits it", {
  p <- cl_two_stores()
  res <- cl_render(c("```{r}", "rd <- function(name, store = \"../store-root/_targets\") targets::tar_read_raw(name, store = store)",
                     "v <- rd(\"fit\")", "```", "", "Text."), p$sub)
  expect_false(res$failed)
  tg <- e1_header(p$sub)$targets
  expect_identical(names(tg), "../store-root/_targets")
  expect_identical(tg[[1]][["fit"]], e1_data_hash(p$other, "fit"))
})

test_that("review closing #6: a reader's default name is the target of a call that omits it", {
  dir <- e1_plain_dir()
  cl_render(c("```{r}", "rdn <- function(name = \"fit\") targets::tar_read_raw(name)", "v <- rdn()", "```", "", "Text."), dir)
  expect_identical(e1_header(dir)$targets[["_targets"]][["fit"]], e1_data_hash(dir, "fit"))
})

test_that("review closing #6 control: a store passed in the call is still used", {
  p <- cl_two_stores()
  cl_render(c("```{r}", "rd <- function(name, store = \"_targets\") targets::tar_read_raw(name, store = store)",
              "v <- rd(\"fit\", store = \"../store-root/_targets\")", "```", "", "Text."), p$sub)
  expect_identical(names(e1_header(p$sub)$targets), "../store-root/_targets")
})

test_that("review closing #6 control: a store held in a local of the reader is unresolved (one warning, default store)", {
  p <- cl_two_stores()
  assign("s", "../store-root/_targets", envir = globalenv())
  withr::defer(rm("s", envir = globalenv()))
  res <- cl_render(c("```{r}",
                     "rd2 <- function(name) { s <- \"../store-root/_targets\"; targets::tar_read_raw(name, store = s) }",
                     "v <- rd2(\"fit\")", "```", "", "Text."), p$sub)
  expect_false(res$failed)
  w <- d2_of_class(res, "weft_ledger_warning")
  expect_length(w, 1L)
  expect_true(grepl("7.2.2", e1_flat(d2_msgs(w)), fixed = TRUE))
  expect_identical(names(e1_header(p$sub)$targets), "_targets")
})

# ---- #7: the tidyselect reader tar_load({{ x }}) ---------------------------------------------------------------

test_that("review closing #7: a reader that embraces its argument records the bare symbol it is called with", {
  dir <- e1_plain_dir()
  cl_render(c("```{r}", "ld <- function(x) targets::tar_load({{ x }})", "ld(fit)", "```", "", "Text."), dir)
  expect_identical(e1_header(dir)$targets[["_targets"]][["fit"]], e1_data_hash(dir, "fit"))
})

test_that("review closing #7: the same reader called with a string records the target", {
  dir <- e1_plain_dir()
  cl_render(c("```{r}", "ld <- function(x) targets::tar_load({{ x }})", "ld(\"fit\")", "```", "", "Text."), dir)
  expect_identical(e1_header(dir)$targets[["_targets"]][["fit"]], e1_data_hash(dir, "fit"))
})

test_that("review closing #7: a reader that passes !!enquo(x) records the bare symbol", {
  skip_if_not_installed("rlang")
  dir <- e1_plain_dir()
  cl_render(c("```{r}", "ld <- function(x) targets::tar_load(!!rlang::enquo(x))", "ld(fit)", "```", "", "Text."), dir)
  expect_identical(e1_header(dir)$targets[["_targets"]][["fit"]], e1_data_hash(dir, "fit"))
})

test_that("review closing #7 control: a reader that passes its argument plainly to tar_read_raw() records a string and not a bare symbol", {
  dir <- e1_plain_dir()
  res <- cl_render(c("```{r}", "rd <- function(name) targets::tar_read_raw(name)",
                     "if (FALSE) rd(fit)", "```", "", "Text."), dir)
  expect_false(res$failed)
  expect_length(e1_header(dir)$targets, 0L)
  dir2 <- e1_plain_dir()
  cl_render(c("```{r}", "rd <- function(name) targets::tar_read_raw(name)", "v <- rd(\"fit\")", "```", "", "Text."), dir2)
  expect_identical(e1_header(dir2)$targets[["_targets"]][["fit"]], e1_data_hash(dir2, "fit"))
})

# ---- #8: ledger: false collects no reads --------------------------------------------------------------------------

CL_UNRES <- c("```{r}", "if (FALSE) targets::tar_read(fit, store = mystore)", "```", "", "Text.")

READ_FIT_CL <- c("```{r fit}", "fit_val <- tar_read(fit)", "```", "", "Text.")

cl_network <- function(dir) list.files(file.path(dir, ".weft"), pattern = "^network\\.rds$", recursive = TRUE)

test_that("review closing #8: with ledger: false a read that cannot be resolved raises no weft_ledger_warning", {
  res <- d2_run(CL_UNRES, set_up = FALSE, files = list("_weft.yml" = c("draft: false", "ledger: false")),
                code = E1_LIB, env = c(WEFT_DRAFT = NA))
  expect_false(res$failed)
  expect_length(d2_of_class(res, "weft_ledger_warning"), 0L)
})

test_that("review closing #8: with ledger: false no network cache is written", {
  dir <- e1_plain_dir()
  res <- d2_run(READ_FIT_CL, dir = dir, set_up = FALSE, files = list("_weft.yml" = c("draft: false", "ledger: false")),
                code = E1_LIB, env = c(WEFT_DRAFT = NA))
  expect_false(res$failed)
  expect_identical(cl_network(dir), character())
  expect_false(file.exists(file.path(dir, ".weft", "targets", "network.rds")))
})

test_that("review closing #8 control: with the ledger on the same unresolved read warns once", {
  res <- d2_run(CL_UNRES, code = E1_LIB)
  expect_false(res$failed)
  expect_length(d2_of_class(res, "weft_ledger_warning"), 1L)
})

# ---- #9: unit typed again ----------------------------------------------------------------------------------------------

test_that("review closing #9: a symbol that is an ordinary word, or differs in case, does not warn", {
  for (src in c("`r u(3, \"in\")`{.num} in the first week.",
                "`r u(3, at)`{.num} at the site.",
                "`r u(3, m)`{.num} M is the label.",
                "`r u(3, year)`{.num} Year 3.")) {
    r <- i2_run(src)
    expect_null(r$e, label = src)
    expect_length(i2_unit_warnings(r), 0L)
    expect_length(r$w, 0L)
  }
})

test_that("review closing #9 control: a unit typed again as symbol, or as name, still warns", {
  for (src in c("`r u(3, mm)`{.num} mm of rain.", "`r u(3, m)`{.num} metres of rain.", "`r u(5, m)`{.num} m",
                "`r u(3, day)`{.num} days")) {
    r <- i2_run(src)
    expect_length(i2_unit_warnings(r), 1L)
  }
})

# ---- #10: ASCII in R/ ------------------------------------------------------------------------------------------------

test_that("review closing #10: every file in R/ is ASCII", {
  rdir <- testthat::test_path("..", "..", "R")
  skip_if_not(dir.exists(rdir), "the R/ folder of the source is not available")
  files <- list.files(rdir, pattern = "\\.[Rr]$", full.names = TRUE)
  expect_gt(length(files), 0L)
  bad <- Filter(function(f) {
    x <- readLines(f, warn = FALSE, encoding = "bytes")
    any(is.na(iconv(x, "latin1", "ASCII")) | grepl("[^\\x01-\\x7F]", x, perl = TRUE, useBytes = TRUE))
  }, files)
  expect_identical(basename(bad), character())
})

# ---- #11: heading anchors ------------------------------------------------------------------------------------------------

test_that("review closing #11: < and > in a heading are text, and inline code keeps its text", {
  expect_identical(weft:::pandoc_id("Sites with pH < 6 and EC > 500"), "sites-with-ph-6-and-ec-500")
  expect_identical(weft:::pandoc_id("The `lm` fit"), "the-lm-fit")
})

test_that("review closing #11 control: a real tag is still stripped, and a plain heading is unchanged", {
  expect_identical(weft:::pandoc_id("A <b>bold</b> heading"), "a-bold-heading")
  expect_identical(weft:::pandoc_id("Plain heading"), "plain-heading")
})

# ---- #12: a project unit does not outlive its project ------------------------------------------------------------

CL_A <- c("units:", "  zzsite:", "    name: site")
CL_B <- c("units:", "  zzsite:", "    name: site", "    is: 2 m")
CL_SRC <- "`r u(3, zzsite)`{.num}"

test_that("review closing #12 control: B alone, and B before A, are clean", {
  cl_units_clean()
  expect_equal(i2_text(CL_SRC, CL_B), f2("3~sites"))
  expect_equal(i2_text(CL_SRC, CL_A), f2("3~sites"))
})

test_that("review closing #12: a project with `is:` for a key an earlier project registered without it is read", {
  cl_units_clean()
  expect_equal(i2_text(CL_SRC, CL_A), f2("3~sites"))
  expect_equal(i2_text(CL_SRC, CL_B), f2("3~sites"))
})

test_that("review closing #12: a project with no such row does not still have the earlier project's unit", {
  cl_units_clean()
  i2_text(CL_SRC, CL_A)
  r <- i2_run(CL_SRC)
  shown <- if (!is.null(r$e)) "error" else r$v
  expect_false(grepl("^3.zzsite", shown))
  expect_false(identical(shown, f2("3~sites")))
})

test_that("review closing #12: units_reset() removes a project's registered unit", {
  cl_units_clean()
  i2_text(CL_SRC, CL_A)
  ns <- asNamespace("weft")
  if (!expect_built("units_reset")) return(invisible())
  get("units_reset", ns)()
  r <- i2_run(CL_SRC)
  shown <- if (!is.null(r$e)) "error" else r$v
  expect_false(identical(shown, f2("3~sites")))
})

# ---- 2e1 D: the pre-render script writes .weft/.gitignore -------------------------------------------------------------

test_that("review 2e1 D: the pre-render script writes .weft/.gitignore holding *", {
  skip_on_cran()
  script <- system.file("quarto", "weft-pre-render.R", package = "weft")
  if (!expect_precondition(nzchar(script) && file.exists(script), "the package ships its pre-render script")) return(invisible())
  d <- withr::local_tempdir()
  e1_put(d, list("_quarto.yml" = c("project:", "  type: default"), "plain.qmd" = c("---", "title: p", "---", "", "Text.")))
  withr::with_dir(d, system2(file.path(R.home("bin"), "Rscript"), shQuote(script), stdout = FALSE, stderr = FALSE))
  g <- file.path(d, ".weft", ".gitignore")
  expect_true(file.exists(g))
  expect_identical(trimws(readLines(g, warn = FALSE)), "*")
})
