# Sweep package A (dev/refactor-sweep.md): processes, JSON and the knit's file metadata.
#
#   A1  no system2() call in R/ passes `env =`; withr is an import
#   A2  json_read_text()/json_read_file(); a non-BMP character survives collected_failures()
#   A4  run_id() and values_run() agree when WEFT_RUN and a different .weft/run are both present
#   A5  render_frame_value() is NULL outside a render
#   A6  verify_uses_julia() follows doc_is_julia()

sweep_a_dir <- function() testthat::test_path("..", "..", "R")

# ---- A1 ----------------------------------------------------------------------------------------------------------

test_that("sweep A1: no system2() call in R/ passes an `env` argument", {
  rdir <- sweep_a_dir()
  skip_if_not(dir.exists(rdir), "the R/ folder of the source is not available")
  files <- list.files(rdir, pattern = "\\.[Rr]$", full.names = TRUE)
  expect_gt(length(files), 0L)
  seen <- 0L
  bad <- character()
  # an empty argument, as in x[, 1], cannot be passed on
  is_empty_arg <- function(e, i) identical(e[[i]], quote(expr = ))
  walk <- function(e, f) {
    if (is.call(e)) {
      h <- e[[1L]]
      if (is.symbol(h) && identical(as.character(h), "system2")) {
        seen <<- seen + 1L
        if ("env" %in% names(e)) bad <<- c(bad, basename(f))
      }
      for (i in seq_along(e)) if (!is_empty_arg(e, i)) walk(e[[i]], f)
    } else if (is.pairlist(e)) {
      for (i in seq_along(e)) {
        if (!is_empty_arg(e, i) && !is.null(e[[i]])) walk(e[[i]], f)
      }
    }
  }
  for (f in files) {
    ex <- parse(f, keep.source = FALSE, encoding = "UTF-8")
    for (e in as.list(ex)) walk(e, f)
  }
  # the scan finds the calls at all (it would pass vacuously on a broken walker)
  expect_gt(seen, 0L)
  expect_identical(bad, character())
})

test_that("sweep A1: withr is in Imports, not only Suggests", {
  desc <- testthat::test_path("..", "..", "DESCRIPTION")
  skip_if_not(file.exists(desc), "DESCRIPTION of the source is not available")
  d <- read.dcf(desc, fields = c("Imports", "Suggests"))
  split <- function(x) trimws(sub("\\(.*$", "", strsplit(gsub("\n", " ", x), ",")[[1L]]))
  imports <- split(d[1L, "Imports"])
  expect_true("withr" %in% imports)
})

# ---- A2 ----------------------------------------------------------------------------------------------------------

test_that("sweep A2: a failure detail outside the BMP is returned by collected_failures()", {
  root <- withr::local_tempdir()
  coll <- file.path(root, "failures.jsonl")
  detail <- "grin \U0001F600 done"
  line <- weft:::failure_json(list(kind = "value error", line = 3L, chunk = NA_character_, expr = "x",
                                   detail = detail, hint = NA_character_, option = NA_character_,
                                   chunk_line = NA_integer_), "a.qmd")
  writeLines(c(line, weft:::failure_json(list(kind = "no value", line = 9L, chunk = NA_character_,
                                              expr = "y", detail = "plain", hint = NA_character_,
                                              option = NA_character_, chunk_line = NA_integer_), "b.qmd")),
             coll, useBytes = TRUE)
  withr::local_envvar(WEFT_COLLECT = coll)
  fr <- weft:::collected_failures(root)
  expect_identical(nrow(fr), 2L)
  expect_identical(enc2utf8(fr$detail[fr$file == "a.qmd"]), enc2utf8(detail))
  expect_identical(fr$detail[fr$file == "b.qmd"], "plain")
})

test_that("sweep A2: json_read_text() parses to plain lists and keeps a non-BMP character", {
  expect_true(is.function(weft:::json_read_text))
  x <- weft:::json_read_text('{"a":[1,2],"b":{"c":"x\\ud83d\\ude00y"}}')
  expect_identical(x$a, list(1L, 2L))
  expect_true(is.list(x$b))
  expect_identical(enc2utf8(x$b$c), enc2utf8("x\U0001F600y"))
})

test_that("sweep A2: json_read_file() reads a file and names it in a classed error on bad JSON", {
  expect_true(is.function(weft:::json_read_file))
  d <- withr::local_tempdir()
  good <- file.path(d, "good.json")
  writeLines('{"k":"v","n":[{"z":1}]}', good)
  x <- weft:::json_read_file(good)
  expect_identical(x$k, "v")
  expect_identical(x$n, list(list(z = 1L)))
  bad <- file.path(d, "broken-file.json")
  writeLines('{"k": ', bad)
  err <- tryCatch(weft:::json_read_file(bad), error = function(e) e)
  expect_s3_class(err, "weft_error")
  expect_match(conditionMessage(err), "broken-file.json", fixed = TRUE)
})

test_that("sweep A2: json_read_text() raises a classed weft error on bad JSON", {
  expect_true(is.function(weft:::json_read_text))
  err <- tryCatch(weft:::json_read_text("{not json"), error = function(e) e)
  expect_s3_class(err, "weft_error")
})

# ---- A4 ----------------------------------------------------------------------------------------------------------

test_that("sweep A4: run_id() and values_run() agree when WEFT_RUN and a different .weft/run exist", {
  root <- withr::local_tempdir()
  dir.create(file.path(root, ".weft"))
  writeLines("file-run", file.path(root, ".weft", "run"))
  withr::local_envvar(WEFT_RUN = "env-run")
  want <- weft:::values_run(root)
  expect_identical(want, "file-run")
  expect_identical(weft:::run_id(root), want)
})

test_that("sweep A4 control: run_id() is WEFT_RUN with no .weft/run, and empty with neither", {
  root <- withr::local_tempdir()
  withr::local_envvar(WEFT_RUN = "env-run")
  expect_identical(weft:::run_id(root), "env-run")
  withr::local_envvar(WEFT_RUN = NA)
  expect_identical(weft:::run_id(root), "")
})

# ---- A5 ----------------------------------------------------------------------------------------------------------

test_that("sweep A5: render_frame_value() is NULL outside a render", {
  expect_true(is.function(weft:::render_frame_value))
  expect_null(weft:::render_frame_value("original_input"))
  expect_null(weft:::render_frame_value("output_file"))
})

# ---- A6 ----------------------------------------------------------------------------------------------------------

sweep_a_doc <- function(lines) {
  root <- withr::local_tempdir(.local_envir = parent.frame())
  writeLines(lines, file.path(root, "d.qmd"))
  root
}

test_that("sweep A6: a knitr document with a julia chunk is not a julia-engine document", {
  jl <- c("```{julia}", "1 + 1", "```")
  r <- c("```{r}", "1 + 1", "```")
  r1 <- sweep_a_doc(c("---", "title: t", "engine: knitr", "---", "", jl))
  expect_false(weft:::verify_uses_julia(r1, "d.qmd"))
  r2 <- sweep_a_doc(c("---", "title: t", "---", "", r, "", jl))
  expect_false(weft:::verify_uses_julia(r2, "d.qmd"))
})

test_that("sweep A6: a julia-engine document is", {
  jl <- c("```{julia}", "1 + 1", "```")
  r1 <- sweep_a_doc(c("---", "title: t", "engine: julia", "---", "", "text"))
  expect_true(weft:::verify_uses_julia(r1, "d.qmd"))
  r2 <- sweep_a_doc(c("---", "title: t", "---", "", jl))
  expect_true(weft:::verify_uses_julia(r2, "d.qmd"))
})
