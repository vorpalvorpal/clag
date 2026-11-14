# Package 7d: verify() reads the rendered-output findings (dev/design-7.md N57; section 5 "test-verify-output.R").
# The stand-in `quarto` of helper-4c.R (v4_fake_quarto()) renders nothing: its body writes a stamp for a.qmd, as
# a render would, and appends JSON lines to the file named by WEFT_OUTPUT_LOG, as the filter does.
#
# READINGS:
#  - the `output` data frame has one row per JSON line (so one per format), the columns in the order file,
#    format, kind, level, section, text, excerpt;
#  - it is a data frame with those columns and no rows when nothing was found, and when the render part is
#    skipped;
#  - each `fail` row is one reason; a stand-in that exits 0 still fails the render part when a `fail` row
#    is in the log;
#  - the report names a warned finding by its kind and text somewhere in its lines.

OUT_COLS <- c("file", "format", "kind", "level", "section", "text", "excerpt")

vo_line <- function(kind = "unresolved reference", level = "fail", format = "html", text = "?@sec-missing",
                    section = "methods", excerpt = "See ?@sec-missing for details.", file = "a.qmd") {
  sprintf("echo '{\"source\":\"output\",\"kind\":\"%s\",\"level\":\"%s\",\"file\":\"%s\",\"format\":\"%s\",\"section\":\"%s\",\"text\":\"%s\",\"excerpt\":\"%s\"}' >> \"$WEFT_OUTPUT_LOG\"",
          kind, level, file, format, section, text, excerpt)
}

vo_run <- function(lines = character(), status = 0L, weft_yml = "draft: false", env = parent.frame()) {
  v4_env(env = env)
  fq <- v4_fake_quarto(body = c(v4_sh_stamp("a.qmd"), "echo \"$WEFT_OUTPUT_LOG\" > outlog-seen.txt", lines),
                       status = status, env = env)
  p <- v4_proj(list("a.qmd" = V4_CONSTRUCT_DOC), quarto_yml = V4_QUARTO_YML, weft_yml = weft_yml, env = env)
  r <- v4_verify(p$root)
  list(r = r, p = p, fq = fq)
}

test_that("N57: one unresolved reference (a fail row): the render part fails, and the row is in `output`", {
  x <- vo_run(c(vo_line()))
  expect_s3_class(x$r$err, "weft_verify_error")
  res <- x$r$res
  expect_s3_class(res, "weft_verify")
  expect_false(res$ok)
  expect_identical(v4_status(res, "render"), "failed")
  out <- v4_df(res$output)
  expect_identical(names(out), OUT_COLS)
  expect_identical(nrow(out), 1L)
  expect_identical(out$kind, "unresolved reference")
  expect_identical(out$level, "fail")
  expect_identical(out$file, "a.qmd")
  expect_identical(out$format, "html")
  expect_identical(out$section, "methods")
  expect_identical(out$text, "?@sec-missing")
  expect_identical(out$excerpt, "See ?@sec-missing for details.")
  expect_match(cli::ansi_strip(conditionMessage(x$r$err)), "^verify\\(\\) failed: 1 reason")
  expect_true(any(grepl("?@sec-missing", x$r$report, fixed = TRUE)))
})

test_that("N57: only a warned NA: ok is TRUE, the row is listed, and nothing fails", {
  x <- vo_run(c(vo_line(kind = "missing value in output", level = "warn", text = "NA",
                        excerpt = "The mean was NA here.")))
  expect_null(x$r$err, label = if (!is.null(x$r$err)) conditionMessage(x$r$err) else "no error")
  res <- x$r$value
  expect_true(res$ok)
  expect_identical(v4_status(res, "render"), "ran")
  out <- v4_df(res$output)
  expect_identical(names(out), OUT_COLS)
  expect_identical(nrow(out), 1L)
  expect_identical(out$level, "warn")
  expect_identical(out$kind, "missing value in output")
  expect_identical(out$text, "NA")
  expect_identical(x$r$report[1], "weft verify: passed")
  expect_true(any(grepl("missing value in output", x$r$report, fixed = TRUE)))
})

test_that("N57: a fail row and a warn row: both are rows, only the fail row is a reason", {
  x <- vo_run(c(vo_line(),
                vo_line(kind = "missing value in output", level = "warn", text = "NA", section = "results",
                        excerpt = "The mean was NA here.")))
  res <- x$r$res
  expect_false(res$ok)
  out <- v4_df(res$output)
  expect_identical(nrow(out), 2L)
  expect_setequal(out$level, c("fail", "warn"))
  expect_match(cli::ansi_strip(conditionMessage(x$r$err)), "^verify\\(\\) failed: 1 reason")
})

test_that("N57: the same finding in two formats is two rows, one per format", {
  x <- vo_run(c(vo_line(format = "html"), vo_line(format = "latex")))
  out <- v4_df(x$r$res$output)
  expect_identical(nrow(out), 2L)
  expect_setequal(out$format, c("html", "latex"))
  expect_true(all(out$kind == "unresolved reference"))
})

test_that("N57: a render with no findings has an `output` data frame with the columns and no rows", {
  x <- vo_run()
  expect_null(x$r$err)
  out <- v4_df(x$r$value$output)
  expect_identical(names(out), OUT_COLS)
  expect_identical(nrow(out), 0L)
  expect_true(x$r$value$ok)
})

test_that("N57: verify() sets WEFT_OUTPUT_LOG to a temporary file outside the project, for the render", {
  x <- vo_run(c(vo_line()))
  seen <- readLines(file.path(x$p$root, "outlog-seen.txt"), warn = FALSE)
  expect_length(seen, 1L)
  expect_true(nzchar(seen))
  expect_false(startsWith(normalizePath(seen, mustWork = FALSE), x$p$root))
})

test_that("N57: the variable is not left set in the session", {
  vo_run(c(vo_line()))
  expect_identical(Sys.getenv("WEFT_OUTPUT_LOG", ""), "")
})

test_that("N57: verify_skip: [render] skips the render and the output: no rows, and the stand-in never ran", {
  x <- vo_run(c(vo_line()), weft_yml = c("draft: false", "verify_skip: [render]"))
  expect_identical(v4_status(x$r$res, "render"), "skipped")
  out <- v4_df(x$r$res$output)
  expect_identical(names(out), OUT_COLS)
  expect_identical(nrow(out), 0L)
  expect_length(v4_log(x$fq, "calls"), 0L)
})

test_that("N57: a render that exits non-zero with no findings still fails, as before", {
  x <- vo_run(status = 1L)
  expect_s3_class(x$r$err, "weft_verify_error")
  expect_identical(v4_status(x$r$res, "render"), "failed")
  expect_identical(nrow(v4_df(x$r$res$output)), 0L)
})
