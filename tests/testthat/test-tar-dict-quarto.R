# Package 2e-1: report targets (dev/design-2e.md P10, P11, rule 4.6.5). Written before the code.
# Made-up values only.

REPORT <- c(
  "---", "title: \"Report\"", "engine: knitr", "format: html", "---", "",
  "The first value is `r dict$a`.", "",
  "```{r}", "#| eval: false", "x <- dict[[\"b\"]]", "```", "",
  "{{< include _part.qmd >}}")
REPORT_NO_PART <- c(
  "---", "title: \"Report\"", "engine: knitr", "format: html", "---", "",
  "The first value is `r dict$a`.", "",
  "```{r}", "#| eval: false", "x <- dict[[\"b\"]]", "```")
PART <- c("```{r}", "y <- dict$b", "```")

report_dir <- function(report = REPORT, part = PART, env = parent.frame()) {
  d <- withr::local_tempdir(.local_envir = env)
  e1_dict(d)
  e1_put(d, list("report.qmd" = report))
  if (!is.null(part)) e1_put(d, list("_part.qmd" = part))
  withr::local_dir(d, .local_envir = env)
  d
}

test_that("2e-1 P11: pinned internals of tarchetypes: a tar_quarto() target's command has `sources`", {
  skip_if_not_installed("targets")
  skip_if_not_installed("tarchetypes")
  skip_if_no_quarto()
  report_dir()
  t <- tarchetypes::tar_quarto(report, "report.qmd")
  cmd <- t$command$expr[[1]]
  expect_identical(deparse(cmd[[1]]), "tarchetypes::tar_quarto_run")
  expect_true("sources" %in% names(cmd))
  expect_true(all(c("report.qmd", "_part.qmd") %in% eval(cmd$sources)))
})

test_that("2e-1 P11: pinned internals of tarchetypes: a tar_render() target's command has `path`", {
  skip_if_not_installed("targets")
  skip_if_not_installed("tarchetypes")
  d <- withr::local_tempdir()
  writeLines("Text.", file.path(d, "r.Rmd"))
  withr::local_dir(d)
  t <- tarchetypes::tar_render(rep, "r.Rmd")
  cmd <- t$command$expr[[1]]
  expect_identical(deparse(cmd[[1]]), "tarchetypes::tar_render_run")
  expect_identical(cmd$path, "r.Rmd")
})

test_that("2e-1 P10: a tar_quarto() target gets the keys of its inline R and of an included file", {
  skip_if_not_installed("targets")
  skip_if_not_installed("tarchetypes")
  skip_if_no_quarto()
  report_dir()
  res <- tar_dict_deps(list(tarchetypes::tar_quarto(report, "report.qmd")))
  t <- e1_get(res, "report")
  expect_true(all(c("dict_a", "dict_b") %in% t$deps))
})

test_that("2e-1 P10: a chunk with eval: false does not count; without the include only dict_a is added", {
  skip_if_not_installed("targets")
  skip_if_not_installed("tarchetypes")
  skip_if_no_quarto()
  report_dir(REPORT_NO_PART, NULL)
  res <- tar_dict_deps(list(tarchetypes::tar_quarto(report, "report.qmd")))
  t <- e1_get(res, "report")
  expect_true("dict_a" %in% t$deps)
  expect_false("dict_b" %in% t$deps)
})

test_that("2e-1 P10: eval=FALSE written in the chunk header is skipped too; inline R in front matter counts", {
  skip_if_not_installed("targets")
  skip_if_not_installed("tarchetypes")
  d <- withr::local_tempdir()
  e1_dict(d, vals = list(a = 1, b = 2, c = 3))
  e1_put(d, list("r.Rmd" = c(
    "---", "title: \"Level `r dict$c`\"", "---", "",
    "```{r, eval=FALSE}", "dict$b", "```", "",
    "```{r}", "dict$a", "```")))
  withr::local_dir(d)
  res <- tar_dict_deps(list(tarchetypes::tar_render(rep, "r.Rmd")))
  t <- e1_get(res, "rep")
  expect_true(all(c("dict_a", "dict_c") %in% t$deps))
  expect_false("dict_b" %in% t$deps)
})

test_that("2e-1 P10: the R code of a construct (an `if` key) is walked", {
  skip_if_not_installed("targets")
  skip_if_not_installed("tarchetypes")
  d <- withr::local_tempdir()
  e1_dict(d)
  e1_put(d, list("r.Rmd" = c(
    "Count `r 3`[, below the limit]{if=\"3 < dict$b\"}.")))
  withr::local_dir(d)
  res <- tar_dict_deps(list(tarchetypes::tar_render(rep, "r.Rmd")))
  expect_true("dict_b" %in% e1_get(res, "rep")$deps)
})

test_that("2e-1 P10: functions called by a report are followed in the pipeline's environment", {
  skip_if_not_installed("targets")
  skip_if_not_installed("tarchetypes")
  d <- withr::local_tempdir()
  e1_dict(d)
  e1_put(d, list("r.Rmd" = c("```{r}", "helper()", "```")))
  withr::local_dir(d)
  env <- new.env()
  env$helper <- function() dict$b
  targets::tar_option_set(envir = env)
  withr::defer(targets::tar_option_reset())
  res <- tar_dict_deps(list(tarchetypes::tar_render(rep, "r.Rmd")))
  expect_true("dict_b" %in% e1_get(res, "rep")$deps)
  expect_false("dict_a" %in% e1_get(res, "rep")$deps)
})

test_that("2e-1 P8: an unknown key in a report names the file as well as the target", {
  skip_if_not_installed("targets")
  skip_if_not_installed("tarchetypes")
  d <- withr::local_tempdir()
  e1_dict(d)
  e1_put(d, list("r.Rmd" = "Value `r dict$zz`."))
  withr::local_dir(d)
  e <- e1_err(tar_dict_deps(list(tarchetypes::tar_render(rep, "r.Rmd"))))
  expect_s3_class(e, "weft_pipeline_error")
  expect_true(grepl("`rep` (r.Rmd) reads `dict$zz`", e1_flat(e), fixed = TRUE))
})

test_that("2e-1 P10: a report source that does not exist is weft_pipeline_error", {
  skip_if_not_installed("targets")
  d <- withr::local_tempdir()
  e1_dict(d)
  withr::local_dir(d)
  t <- targets::tar_target_raw("rep", quote(tarchetypes::tar_quarto_run(
    args = list(), deps = list(), sources = c("nope.qmd"), output = "nope.html", input = "nope.qmd")))
  e <- e1_err(tar_dict_deps(list(t)))
  expect_s3_class(e, "weft_pipeline_error")
})

test_that("2e-1 P10: tar_quarto_rep() is not recognised; its command is walked as a command", {
  skip_if_not_installed("targets")
  d <- withr::local_tempdir()
  e1_dict(d)
  withr::local_dir(d)
  t <- targets::tar_target_raw("rep", quote(tarchetypes::tar_quarto_rep_run(
    path = "nope.qmd", execute_params = list(k = dict$a))))
  res <- tar_dict_deps(list(t))
  expect_true("dict_a" %in% t$deps)
})

test_that("2e-1 P10: end to end, a changed value re-renders the report and a changed definition does not", {
  skip_if_not_installed("targets")
  skip_if_not_installed("tarchetypes")
  skip_if_not_installed("quarto")
  skip_if_no_quarto()
  skip_on_cran()
  d <- e1_tmp()
  put <- function(vals, defs = list(a = "First.")) {
    e1_dict(d, vals, defs)
    e1_put(d, list(
      "report.qmd" = c("---", "title: \"Report\"", "engine: knitr", "format: html", "---", "",
                       "```{r}", "dict <- yaml::read_yaml(\"dict.yml\")",
                       "cat('The first value is', dict$a$value)", "```"),
      "_targets.R" = c(
        "library(targets)",
        "c(weft::tar_dict(\"dict.yml\"),",
        "  weft::tar_dict_deps(list(tarchetypes::tar_quarto(report, \"report.qmd\", quiet = TRUE))))")))
  }
  lib <- e1_libpath()
  mk <- function() {
    withr::local_dir(d)
    targets::tar_make(callr_arguments = list(libpath = lib), reporter = "silent")
    prog <- targets::tar_progress()
    prog$name[prog$progress == "completed"]
  }
  put(list(a = 1, b = 2))
  expect_true("report" %in% mk())
  put(list(a = 5, b = 2))
  expect_true("report" %in% mk())
  put(list(a = 5, b = 2), list(a = "A new definition."))
  expect_false("report" %in% mk())
})
