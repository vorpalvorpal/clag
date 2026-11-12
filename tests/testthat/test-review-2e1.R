# Regression tests for the review of 2e-1 (dev/review-2e1.md; rulings at the end of dev/design-2e.md).
# Written before the fixes. Made-up values only. Pipelines run in callr with the development weft
# in a temporary library, so this session never has `weft:dict` attached; a callr error keeps its
# message but may lose its class, so those tests assert on the message.
if (!exists("e1_pipe")) source(Filter(file.exists, c(testthat::test_path("helper-2e1.R"), testthat::test_path("..", "helper-2e1.R")))[[1]])

need_pipe <- function() {
  skip_if_not_installed("targets")
  skip_on_cran()
}

READ_FIT <- c("```{r fit}", "fit_val <- tar_read(fit)", "```", "", "Inline `r targets::tar_read(fit)`.")
edge_script <- c("library(targets)", "list(",
                 "  tar_target(base, {warning('base warned'); 1}),",
                 "  tar_target(up, {warning('upstream warned 3 times'); base + 1}),",
                 "  tar_target(fit, {warning('first 5'); warning('second'); up + 1}))")

DICT_HEAD <- c("library(targets)", "c(weft::tar_dict(\"dict.yml\"),")

# ---- #2, #3, A: the guard ----------------------------------------------------------------------------

test_that("review 2e1 #2: a target outside tar_dict_deps() that reads dict$a stops the first make, naming target and key", {
  need_pipe()
  d <- e1_pipe(c(DICT_HEAD,
    "  weft::tar_dict_deps(list(tar_target(inside, dict$a))),",
    "  list(tar_target(outside, dict$a * 2)))"))
  e <- e1_try_make(d)
  expect_false(is.null(e))
  msg <- e1_flat(e)
  expect_true(grepl("outside", msg, fixed = TRUE))
  expect_true(grepl("tar_dict_deps", msg, fixed = TRUE))
  expect_true(grepl("dict$a", msg, fixed = TRUE) || grepl("dict_a", msg, fixed = TRUE) || grepl("`a`", msg, fixed = TRUE))
})

test_that("review 2e1 #2 variant: a [[ read of another key in an unwrapped target is the error too", {
  need_pipe()
  d <- e1_pipe(c(DICT_HEAD, "  list(tar_target(loose, dict[[\"b\"]] + 1)))"))
  msg <- e1_flat(e1_try_make(d))
  expect_true(grepl("loose", msg, fixed = TRUE))
  expect_true(grepl("tar_dict_deps", msg, fixed = TRUE))
})

test_that("review 2e1 #2 control: the same target inside tar_dict_deps() builds without error", {
  need_pipe()
  d <- e1_pipe(c(DICT_HEAD, "  weft::tar_dict_deps(list(tar_target(inside, dict$a), tar_target(also, dict[[\"b\"]]))))"))
  expect_null(e1_try_make(d))
})

test_that("review 2e1 A: eval(parse(text = ))  of a read no walker can see, inside a wrapped target, is the error", {
  need_pipe()
  d <- e1_pipe(c(DICT_HEAD,
    "  weft::tar_dict_deps(list(tar_target(sneaky, eval(parse(text = \"dict$a\"))))))"))
  msg <- e1_flat(e1_try_make(d))
  expect_true(grepl("sneaky", msg, fixed = TRUE))
  expect_true(grepl("tar_dict_deps", msg, fixed = TRUE))
})

test_that("review 2e1 A: a read of the whole dictionary is the error in an unwrapped target and fine in a wrapped one", {
  need_pipe()
  d1 <- e1_pipe(c(DICT_HEAD, "  list(tar_target(whole, length(names(dict)))))"))
  msg <- e1_flat(e1_try_make(d1))
  expect_true(grepl("whole", msg, fixed = TRUE))
  expect_true(grepl("tar_dict_deps", msg, fixed = TRUE))
  d2 <- e1_pipe(c(DICT_HEAD, "  weft::tar_dict_deps(list(tar_target(whole, length(names(dict))))))"))
  expect_null(e1_try_make(d2))
})

test_that("review 2e1 A: reading dict outside any running target is never an error", {
  skip_if_not_installed("targets")
  e1_local_dict()
  d <- withr::local_tempdir()
  e1_dict(d)
  withr::local_dir(d)
  tar_dict("dict.yml")
  expect_no_error(get("dict", "weft:dict")$a)
  expect_no_error(get("dict", "weft:dict")[["b"]])
  expect_no_error(names(get("dict", "weft:dict")))
})

TRACKED <- c(
  "library(targets)",
  "make_g <- function() { inner <- function() dict$a; function() inner() }",
  "g_clo <- make_g()",
  "summary.myc <- function(object, ...) dict$a",
  "c(weft::tar_dict(\"dict.yml\"),",
  "  weft::tar_dict_deps(list(",
  "    tar_target(t_get, get(\"dict\")$a),",
  "    tar_target(t_mget, mget(\"dict\", inherits = TRUE)[[1]]$a),",
  "    tar_target(t_clo, g_clo()),",
  "    tar_target(t_s3, summary(structure(1, class = \"myc\"))),",
  "    tar_target(t_none, 1))))")

tracked_seq <- function() e1_memo("review-tracked", function() {
  need_pipe()
  d <- e1_pipe(TRACKED)
  out <- list(dir = d)
  out$err1 <- e1_try_make(d)
  out$first <- tryCatch(withr::with_dir(d, e1_built()), error = function(e) NULL)
  e1_dict(d, list(a = 5, b = 2))
  out$err2 <- e1_try_make(d)
  out$after <- tryCatch(withr::with_dir(d, e1_built()), error = function(e) NULL)
  out
})

test_that("review 2e1 #3: get(\"dict\"), mget(), a helper held in a closure and an S3 method are tracked: no error", {
  s <- tracked_seq()
  expect_null(s$err1)
  expect_null(s$err2)
  expect_setequal(s$first, c("t_get", "t_mget", "t_clo", "t_s3", "t_none"))
})

test_that("review 2e1 #3: each of them re-runs when the value of a changes, and a target reading nothing does not", {
  s <- tracked_seq()
  expect_setequal(s$after, c("t_get", "t_mget", "t_clo", "t_s3"))
  expect_false("t_none" %in% s$after)
})

# ---- #1 and the *_rep targets ---------------------------------------------------------------------

report_seq <- function(key, script, files, edit_vals = list(a = 1, b = 9), edit_name = "b") e1_memo(key, function() {
  need_pipe()
  d <- e1_pipe(script, files = files)
  out <- list(dir = d, err = e1_try_make(d))
  if (!is.null(out$err)) return(out)
  e1_dict(d, list(a = 1, b = 2), list(a = "A new definition."))
  out$err2 <- e1_try_make(d)
  out$after_def <- withr::with_dir(d, e1_built())
  e1_dict(d, edit_vals, list(a = "A new definition."))
  out$err3 <- e1_try_make(d)
  out$after_val <- withr::with_dir(d, e1_built())
  out
})

expect_report_seq <- function(s, target) {
  expect_null(s$err)
  expect_null(s$err2)
  expect_null(s$err3)
  expect_false(target %in% s$after_def)
  expect_true(target %in% s$after_val)
}

RMD_PARENT <- c("---", "title: r", "---", "", "A is `r dict$a`.", "", "```{r, child='kid.Rmd'}", "```")

test_that("review 2e1 #1: a tar_render() report with a knitr child= file re-renders on a value change, not on a definition change", {
  skip_if_not_installed("tarchetypes")
  skip_if_not(rmarkdown::pandoc_available(), "pandoc is not available")
  s <- report_seq("review-render-child",
    c("library(targets)", "c(weft::tar_dict(\"dict.yml\"),",
      "  weft::tar_dict_deps(list(tarchetypes::tar_render(report, \"report.Rmd\", output_format = rmarkdown::md_document()))))"),
    list("report.Rmd" = RMD_PARENT, "kid.Rmd" = "B is `r dict$b`."))
  expect_report_seq(s, "report")
})

test_that("review 2e1 #1: a tar_quarto() report with a .md include re-renders on a value change, not on a definition change", {
  skip_if_not_installed("tarchetypes")
  skip_if_not_installed("quarto")
  skip_if_no_quarto()
  s <- report_seq("review-quarto-md",
    c("library(targets)", "c(weft::tar_dict(\"dict.yml\"),",
      "  weft::tar_dict_deps(list(tarchetypes::tar_quarto(report, \"report.qmd\", quiet = TRUE))))"),
    list("report.qmd" = c("---", "title: r", "engine: knitr", "format: html", "---", "",
                          "```{r}", "dict <- yaml::read_yaml(\"dict.yml\")", "```", "",
                          "{{< include _inc.md >}}"),
         "_inc.md" = "Included b is `r dict$b$value`."))
  expect_report_seq(s, "report")
})

test_that("review 2e1 #2: a tar_render_rep() report re-renders when a value it reads changes, not when a definition does", {
  skip_if_not_installed("tarchetypes")
  skip_if_not(rmarkdown::pandoc_available(), "pandoc is not available")
  s <- report_seq("review-render-rep",
    c("library(targets)", "c(weft::tar_dict(\"dict.yml\"),",
      "  weft::tar_dict_deps(list(tarchetypes::tar_render_rep(rrep, \"r.Rmd\",",
      "    params = data.frame(p = 1:2, output_file = c(\"a.md\", \"b.md\")),",
      "    output_format = rmarkdown::md_document()))))"),
    list("r.Rmd" = c("---", "title: r", "params:", "  p: 1", "---", "", "Value `r dict$b`.")))
  expect_report_seq(s, "rrep")
})

test_that("review 2e1 #2: tar_quarto_rep() is a report target too: a value it reads re-renders it", {
  skip_if_not_installed("tarchetypes")
  skip_if_not_installed("quarto")
  skip_if_no_quarto()
  s <- report_seq("review-quarto-rep",
    c("library(targets)", "c(weft::tar_dict(\"dict.yml\"),",
      "  weft::tar_dict_deps(list(tarchetypes::tar_quarto_rep(qrep, \"q.qmd\",",
      "    execute_params = data.frame(p = 1:2, output_file = c(\"a.html\", \"b.html\")), quiet = TRUE))))"),
    list("q.qmd" = c("---", "title: r", "engine: knitr", "format: html", "params:", "  p: 1", "---", "",
                     "```{r}", "dict <- yaml::read_yaml(\"dict.yml\")", "cat(dict$b$value)", "```")))
  expect_report_seq(s, "qrep")
})

# ---- #8: dict_values ----------------------------------------------------------------------------------

test_that("review 2e1 #8: a definition-only edit re-runs dict_values and the dict_<key> targets but no consumer", {
  need_pipe()
  d <- e1_pipe(c(DICT_HEAD,
    "  weft::tar_dict_deps(list(tar_target(t_a, dict$a + 1), tar_target(t_b, dict$b * 2))))"))
  lib <- e1_libpath()
  mk <- function() { withr::with_dir(d, targets::tar_make(callr_arguments = list(libpath = lib), reporter = "silent")); withr::with_dir(d, e1_built_all()) }
  first <- mk()
  expect_true(all(c("dict_file", "dict_values", "dict_a", "dict_b", "t_a", "t_b") %in% first))
  e1_dict(d, list(a = 1, b = 2), list(a = "A rewritten definition."))
  second <- mk()
  expect_true(all(c("dict_file", "dict_values", "dict_a", "dict_b") %in% second))
  expect_false(any(c("t_a", "t_b") %in% second))
})

# ---- #4 / B: the upstream cache -------------------------------------------------------------------

test_that("review 2e1 B: with a stale .weft/run left by an earlier render, a new upstream warning still reaches the log after a make", {
  dir <- e1_plain_dir()
  run <- function() e1_render(READ_FIT, dir, files = list(".weft/run" = "run-stale"))
  run()
  writeLines(edge_script, file.path(dir, "_targets.R"))
  e1_make(dir, plain = TRUE)
  sources <- vapply(d2_pick(d2_conds(run()), from = "target"), `[[`, "", "source")
  expect_true("base" %in% sources)
})

test_that("review 2e1 #4: the same without any .weft/run (a single-file render)", {
  dir <- e1_plain_dir()
  run <- function() e1_render(READ_FIT, dir)
  run()
  writeLines(edge_script, file.path(dir, "_targets.R"))
  e1_make(dir, plain = TRUE)
  sources <- vapply(d2_pick(d2_conds(run()), from = "target"), `[[`, "", "source")
  expect_true("base" %in% sources)
})

test_that("review 2e1 B: two single-file renders over an unchanged store reuse the edges (network.rds is not rewritten)", {
  dir <- e1_plain_dir()
  e1_render(READ_FIT, dir)
  p <- file.path(dir, ".weft", "targets", "network.rds")
  expect_true(file.exists(p))
  m1 <- file.info(p)$mtime
  Sys.sleep(1.2)
  e1_render(READ_FIT, dir)
  expect_identical(file.info(p)$mtime, m1)
})

# ---- #5, #7: the store of a read ------------------------------------------------------------------------

store_proj <- function() {
  proj <- e1_tmp()
  sub <- file.path(proj, "reports")
  other <- file.path(proj, "store-root")
  dir.create(sub)
  dir.create(other)
  e1_plain_dir(dir = other)
  list(sub = sub, other = other)
}

test_that("review 2e1 #5: a store given by an expression is recorded under the evaluated store, with a real hash", {
  p <- store_proj()
  e1_render(c("```{r}", "v <- tar_read(fit, store = file.path(\"..\", \"store-root\", \"_targets\"))", "```"), dir = p$sub)
  tg <- e1_header(p$sub)$targets
  expect_identical(names(tg), "../store-root/_targets")
  expect_identical(tg[[1]][["fit"]], e1_data_hash(p$other, "fit"))
})

test_that("review 2e1 #5 variant: the expression may use a variable defined in the document", {
  p <- store_proj()
  e1_render(c("```{r}", "st <- file.path(\"..\", \"store-root\", \"_targets\")", "v <- tar_read(fit, store = st)", "```"), dir = p$sub)
  expect_identical(names(e1_header(p$sub)$targets), "../store-root/_targets")
})

test_that("review 2e1 #5: a store expression that cannot be evaluated gives one weft_ledger_warning naming the read", {
  dir <- e1_plain_dir()
  res <- d2_run(c("```{r}", "g <- function() tar_read(fit, store = zz_not_defined)", "```", "", "Text."),
                dir = dir, code = E1_LIB)
  expect_false(res$failed)
  w <- d2_of_class(res, "weft_ledger_warning")
  expect_length(w, 1L)
  expect_true(grepl("fit", d2_msgs(w), fixed = TRUE))
  # the read is recorded under the default store
  expect_identical(names(e1_header(dir)$targets), "_targets")
})

test_that("review 2e1 #7: upstream conditions are read for a literal non-default store", {
  p <- store_proj()
  res <- e1_render(c("```{r}", "v <- tar_read(fit, store = \"../store-root/_targets\")", "```"), dir = p$sub)
  sources <- vapply(d2_pick(d2_conds(res), from = "target"), `[[`, "", "source")
  expect_true(all(c("fit", "up") %in% sources))
  expect_false("other" %in% sources)
})

# ---- #13: one "Did you mean" rule ------------------------------------------------------------------------

suggest_both <- function(vals, typo) {
  d <- withr::local_tempdir(.local_envir = parent.frame())
  p <- e1_dict(d, vals = vals)
  e_read <- e1_err(weft::read_dict(p)[[typo]])
  withr::local_dir(d, .local_envir = parent.frame())
  call <- substitute(dict$x, list(x = as.name(typo)))
  tt <- targets::tar_target_raw("t1", call)
  e_pipe <- e1_err(tar_dict_deps(tt))
  list(read = if (is.null(e_read)) "" else e1_flat(e_read), pipe = if (is.null(e_pipe)) "" else e1_flat(e_pipe))
}

test_that("review 2e1 C13: the nearest key within distance 2 is suggested by both the dictionary reader and the pipeline", {
  skip_if_not_installed("targets")
  r <- suggest_both(list(abcd = 1, abxy = 2), "abcx")
  expect_true(grepl("Did you mean `abcd`?", r$read, fixed = TRUE))
  expect_true(grepl("Did you mean `abcd`?", r$pipe, fixed = TRUE))
})

test_that("review 2e1 C13: a tie gives no suggestion in either", {
  skip_if_not_installed("targets")
  r <- suggest_both(list(abc1 = 1, abc2 = 2), "abc3")
  expect_false(grepl("Did you mean", r$read, fixed = TRUE))
  expect_false(grepl("Did you mean", r$pipe, fixed = TRUE))
  expect_true(nzchar(r$read) && nzchar(r$pipe))
})

# ---- C, D, E ---------------------------------------------------------------------------------------------

test_that("review 2e1 C: a literal source() in a chunk puts that file in the header's files, with its hash", {
  dir <- e1_tmp()
  res <- e1_render(c("```{r}", "source(\"helpers.R\", local = TRUE)", "x <- hf()", "```", "", "Text."), dir,
                   files = list("helpers.R" = "hf <- function() 1"))
  f <- e1_header(dir)$files
  expect_true("helpers.R" %in% names(f))
  expect_identical(f[["helpers.R"]], weft:::file_hash(file.path(dir, "helpers.R")))
})

test_that("review 2e1 C variant: sys.source() with a literal path counts too", {
  dir <- e1_tmp()
  e1_render(c("```{r}", "sys.source(\"helpers2.R\", envir = environment())", "```", "", "Text."), dir,
            files = list("helpers2.R" = "hf2 <- function() 1"))
  expect_true("helpers2.R" %in% names(e1_header(dir)$files))
})

test_that("review 2e1 D: a render that creates .weft/ also writes .weft/.gitignore holding *", {
  res <- d2_render(c("Value `r 1`."))
  g <- file.path(res$dir, ".weft", ".gitignore")
  expect_true(dir.exists(file.path(res$dir, ".weft")))
  expect_true(file.exists(g))
  expect_identical(trimws(readLines(g, warn = FALSE)), "*")
})

test_that("review 2e1 E: an author's target named dict_values, dict_file or dict_<key> is a weft_pipeline_error", {
  skip_if_not_installed("targets")
  d <- withr::local_tempdir()
  e1_dict(d, list(a = 1, zz = 2))
  withr::local_dir(d)
  for (nm in c("dict_values", "dict_file", "dict_zz")) {
    t <- targets::tar_target_raw(nm, quote(42))
    e <- e1_err(tar_dict_deps(list(t)))
    expect_s3_class(e, "weft_pipeline_error")
    expect_true(grepl(nm, e1_flat(e), fixed = TRUE), label = nm)
  }
})

test_that("review 2e1 E: two dictionaries in one pipeline definition are a weft_pipeline_error from weft", {
  skip_if_not_installed("targets")
  e1_local_dict()
  d <- withr::local_tempdir()
  e1_dict(d)
  e1_dict(file.path(d, "sub"))
  withr::local_dir(d)
  e <- e1_err(tar_dict_deps(list(tar_dict("dict.yml"), tar_dict("sub/dict.yml"))))
  expect_s3_class(e, "weft_pipeline_error")
})

test_that("review 2e1 E: the same in a _targets.R is weft's message, not targets' duplicated-names one", {
  need_pipe()
  d <- e1_pipe(c("library(targets)", "c(weft::tar_dict(\"dict.yml\"), weft::tar_dict(\"other.yml\"))"),
               files = list("other.yml" = e1_dict_lines(list(a = 1))))
  msg <- e1_flat(e1_try_make(d))
  expect_true(nzchar(msg))
  expect_true(grepl("tar_dict", msg, fixed = TRUE))
  expect_false(grepl("duplicated target names", msg, fixed = TRUE))
})

# ---- wording: #9, #10 ------------------------------------------------------------------------------------

test_that("review 2e1 #9: the 'upstream not read' warning names the cause", {
  dir <- e1_plain_dir()
  writeLines(c(E1_PLAIN, "stop('broken script')"), file.path(dir, "_targets.R"))
  res <- d2_run(READ_FIT, dir = dir, code = E1_LIB)
  w <- d2_of_class(res, "weft_ledger_warning")
  expect_length(w, 1L)
  expect_true(grepl("broken script", d2_msgs(w), fixed = TRUE))
})

test_that("review 2e1 #10: the global-dict error says the object may come from the session and how to remove it", {
  skip_if_not_installed("targets")
  d <- withr::local_tempdir()
  e1_dict(d)
  withr::local_dir(d)
  assign("dict", list(a = 1), envir = globalenv())
  withr::defer(rm("dict", envir = globalenv()))
  e <- e1_err(tar_dict_deps(targets::tar_target(t1, dict$a)))
  msg <- e1_flat(e)
  expect_true(grepl("rm(dict)", msg, fixed = TRUE))
  expect_true(grepl("callr_function", msg, fixed = TRUE))
})

# ---- I15, I16: from the field trial -----------------------------------------------------------------------

I15_READS <- c("a <- dict$alpha", "x <- targets::tar_read(fit)")

test_that("review 2e1 I15: reads in the chunk that calls weft_setup() are recorded", {
  dir <- e1_plain_dir()
  d2_render(c("Text."), dir = dir, code = c(E1_LIB, I15_READS),
            files = list("dict.yml" = e1_dict_lines(list(alpha = 1, beta = 2))))
  h <- e1_header(dir)
  expect_identical(names(h$dict), "alpha")
  expect_identical(h$targets[["_targets"]][["fit"]], e1_data_hash(dir, "fit"))
})

test_that("review 2e1 I15 control: the same reads in a second chunk are recorded", {
  dir <- e1_plain_dir()
  e1_render(c("```{r}", I15_READS, "```", "", "Text."), dir, dict = e1_dict_lines(list(alpha = 1, beta = 2)))
  h <- e1_header(dir)
  expect_identical(names(h$dict), "alpha")
  expect_identical(h$targets[["_targets"]][["fit"]], e1_data_hash(dir, "fit"))
})

TR <- "tr <- function(name) targets::tar_read_raw(name, store = file.path(getwd(), \"_targets\"))"

test_that("review 2e1 I16: a reader of the author's with a literal name is a read of that target, from the store its body gives", {
  dir <- e1_plain_dir()
  res <- e1_render(c("```{r}", TR, "v <- tr(\"fit\")", "```", "", "Text."), dir)
  expect_false(res$failed, label = res$message)
  tg <- e1_header(dir)$targets
  expect_identical(names(tg), "_targets")
  expect_identical(tg[[1]][["fit"]], e1_data_hash(dir, "fit"))
})

test_that("review 2e1 I16 variant: a wrapper that passes the name on with the default store records it under the default store", {
  dir <- e1_plain_dir()
  e1_render(c("```{r}", "tr2 <- function(name) targets::tar_read_raw(name)", "v <- tr2(\"fit\")", "```", "", "Text."), dir)
  tg <- e1_header(dir)$targets
  expect_identical(tg[["_targets"]][["fit"]], e1_data_hash(dir, "fit"))
})

test_that("review 2e1 I16: a call with a non-literal name records nothing and raises nothing", {
  dir <- e1_plain_dir()
  res <- d2_run(c("```{r}", TR, "nm <- \"fit\"", "v <- tr(nm)", "```", "", "Text."), dir = dir, code = E1_LIB)
  expect_false(res$failed)
  expect_length(d2_of_class(res, "weft_ledger_warning"), 0L)
  expect_length(e1_header(dir)$targets, 0L)
})

test_that("review 2e1 I16 control: a function that contains a tar_read() of a fixed target is still followed", {
  dir <- e1_plain_dir()
  e1_render(c("```{r}", "g <- function() targets::tar_read(fit)", "v <- g()", "```", "", "Text."), dir)
  expect_identical(e1_header(dir)$targets[["_targets"]][["fit"]], e1_data_hash(dir, "fit"))
})
