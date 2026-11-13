# Package 4c: verify() on rmarkdown documents, with no _quarto.yml (dev/design-4.md G25 "rmarkdown", G26, G30, H36;
# PACKAGE-SCOPING 8.3.3; section 5 "test-verify-rmd.R"). Each .Rmd is rendered once, in a fresh Rscript in the
# project root; there is no freeze step; the stamp of each is found by the run id in WEFT_RUN. The renders are
# slow: two verify() runs are shared by the tests below (v4_rmd_pass(), v4_rmd_fail()). Skipped without
# rmarkdown or Pandoc. ASCII only. Invented content only.

rmd_need <- function() {
  skip_on_cran()
  skip_if_not_installed("rmarkdown")
  skip_if_no_pandoc()
}

rmd_doc <- function(name, ...) v4_qdoc(name, ext = "Rmd", ...)

# fixture: a passing document and a document with a warned check (which fails nothing), with a `_freeze`
# folder planted that rmarkdown has no use for
v4_rmd_pass <- function() {
  if (is.null(v4_cache$rmd_pass)) {
    rmd_need()
    v4_env(libs = TRUE)
    warned <- rmd_doc("c", extra = c("", "Warned `r claim(depth, . > 100, level = \"warn\")` here."))
    q <- v4_rproject(list("a.Rmd" = rmd_doc("a"), "c.Rmd" = warned))
    withr::defer(unlink(q$top, recursive = TRUE), teardown_env())
    v4_plant_freeze(q$root, c("a", "c"))
    fx <- list(q = q, freeze_before = v4_freeze_snap(q$root), outside_before = v4_outside_snap(q$top, q$root))
    fx$r <- v4_verify(q$root)
    fx$ran <- c(a = v4_ran(q$root, "a"), c = v4_ran(q$root, "c"))
    fx$stamp_files <- list.files(file.path(q$root, ".weft", "stamps"))
    fx$freeze_after <- v4_freeze_snap(q$root)
    fx$outside_after <- v4_outside_snap(q$top, q$root)
    v4_cache$rmd_pass <- fx
  }
  v4_cache$rmd_pass
}

# fixture: a failing claim in b, a missing value in d, and a clean e
v4_rmd_fail <- function() {
  if (is.null(v4_cache$rmd_fail)) {
    rmd_need()
    v4_env(libs = TRUE)
    b <- rmd_doc("b", claim = "claim(depth, . > 100)")
    d <- rmd_doc("d", extra = c("", "Missing `r NA_real_`{.num} here."))
    q <- v4_rproject(list("b.Rmd" = b, "d.Rmd" = d, "e.Rmd" = rmd_doc("e")))
    withr::defer(unlink(q$top, recursive = TRUE), teardown_env())
    fx <- list(q = q, b = b, d = d)
    fx$r <- v4_verify(q$root)
    fx$ran <- c(b = v4_ran(q$root, "b"), d = v4_ran(q$root, "d"), e = v4_ran(q$root, "e"))
    fx$stamp_files <- list.files(file.path(q$root, ".weft", "stamps"))
    v4_cache$rmd_fail <- fx
  }
  v4_cache$rmd_fail
}

expect_verify_failed <- function(r) {
  expect_false(is.null(r$err), label = "verify() raised")
  expect_s3_class(r$err, "weft_verify_error")
  expect_s3_class(r$err$result, "weft_verify")
  expect_false(r$err$result$ok)
  expect_identical(r$report[1], "weft verify: failed")
}

stamp_of <- function(fx, doc) {
  f <- list.files(file.path(fx$q$root, ".weft", "stamps"), pattern = sprintf("^%s\\.", doc), full.names = TRUE)
  if (length(f)) jsonlite::fromJSON(f[1], simplifyVector = FALSE) else NULL
}

# ---- a passing set of documents -----------------------------------------------------------------------

test_that("4c G25: rmarkdown documents pass: each rendered once, the render part ran, no freeze step", {
  fx <- v4_rmd_pass()
  r <- fx$r
  expect_null(r$err, label = if (!is.null(r$err)) conditionMessage(r$err) else "")
  expect_true(r$value$ok)
  expect_identical(r$report[1], "weft verify: passed")
  expect_identical(v4_status(r$value, "render"), "ran")
  expect_identical(fx$ran, c(a = 1L, c = 1L))
  # the documents were written next to their sources
  expect_true(all(file.exists(file.path(fx$q$root, c("a.md", "c.md")))))
})

test_that("4c G25, 8.3.3: under rmarkdown there is no freeze step: a _freeze folder is left alone and no backup is made", {
  fx <- v4_rmd_pass()
  expect_s3_class(fx$r$value, "weft_verify")
  expect_identical(fx$freeze_after, fx$freeze_before)
  expect_false(dir.exists(v4_backup_dir(fx$q$root)))
})

test_that("4c G25, G30: each document's stamp carries the run id verify() made, the same for both", {
  fx <- v4_rmd_pass()
  expect_length(fx$stamp_files, 2L)
  sa <- stamp_of(fx, "a")
  sc <- stamp_of(fx, "c")
  expect_match(sa$run, V4_RUN_RE)
  expect_match(sa$run, sprintf("-%d$", Sys.getpid()))
  expect_identical(sa$run, sc$run)
  expect_length(sa$failures, 0L)
  expect_length(sc$failures, 0L)
})

test_that("4c G26: a warned check is not a failure: the run passes and the stamp has no failure", {
  fx <- v4_rmd_pass()
  expect_s3_class(fx$r$value, "weft_verify")
  expect_identical(NROW(fx$r$value$knit), 0L)
  expect_length(stamp_of(fx, "c")$failures, 0L)
})

test_that("4c G3: a real rmarkdown verify() writes nothing outside the project", {
  fx <- v4_rmd_pass()
  expect_s3_class(fx$r$value, "weft_verify")
  expect_identical(fx$outside_after, fx$outside_before)
})

# ---- a failing claim and a missing value --------------------------------------------------------------

test_that("4c G26: a failed claim in one .Rmd and a missing value in another fail verify(), each listed once", {
  fx <- v4_rmd_fail()
  r <- fx$r
  expect_verify_failed(r)
  expect_identical(v4_status(r$res, "render"), "failed")
  expect_identical(NROW(r$res$knit), 2L)
  expect_true(v4_has_section(r$report, "Knit-time failures"))
  sec <- v4_section(r$report, "Knit-time failures")
  expect_true(any(grepl("b.Rmd", sec, fixed = TRUE)))
  expect_true(any(grepl("d.Rmd", sec, fixed = TRUE)))
  expect_false(any(grepl("e.Rmd", sec, fixed = TRUE)))
  expect_true(any(grepl(". > 100 was FALSE (value 12.5)", sec, fixed = TRUE)))
  expect_true(any(grepl(as.character(v4_line_of(fx$b, "Depth is")), sec, fixed = TRUE)))
})

test_that("4c G25, H36: every .Rmd is rendered, once each, even after one of them failed", {
  fx <- v4_rmd_fail()
  expect_identical(fx$ran, c(b = 1L, d = 1L, e = 1L))
  expect_length(fx$stamp_files, 3L)
  runs <- vapply(c("b", "d", "e"), function(n) stamp_of(fx, n)$run, "")
  expect_length(unique(runs), 1L)
  expect_match(runs[[1]], V4_RUN_RE)
})

test_that("4c G26: the failing documents' stamps hold their failures, the clean one's none", {
  fx <- v4_rmd_fail()
  expect_length(stamp_of(fx, "b")$failures, 1L)
  expect_length(stamp_of(fx, "d")$failures, 1L)
  expect_length(stamp_of(fx, "e")$failures, 0L)
})

# ---- files, and the run id read by the knit -----------------------------------------------------------

test_that("4c G29: verify(files =) renders the named .Rmd only", {
  rmd_need()
  v4_env(libs = TRUE)
  q <- v4_rproject(list("a.Rmd" = rmd_doc("a"), "b.Rmd" = rmd_doc("b", claim = "claim(depth, . > 100)")))
  r <- v4_verify(q$root, files = "a.Rmd")
  expect_null(r$err, label = if (!is.null(r$err)) conditionMessage(r$err) else "")
  expect_identical(v4_ran(q$root, "a"), 1L)
  expect_identical(v4_ran(q$root, "b"), 0L)
  expect_true(r$value$ok)
})

# Stage 6 ruling 17 (D22) reversed the order this test first pinned: every reader takes `.weft/run`
# before WEFT_RUN, so the stamp, the published block and the filter agree. verify() writes its run to
# the file as well as the environment (next test), so a file left by an earlier render cannot mislead it.
test_that("4c G30: a knit reads .weft/run first, and WEFT_RUN when no file holds a run", {
  rmd_need()
  q <- v4_rproject(list("a.Rmd" = rmd_doc("a"), ".weft/run" = "run-from-file"))
  env <- u4_env(u4_home(), extra = c(WEFT_RUN = "run-from-env"))
  r <- u4_r(q$root, "rmarkdown::render('a.Rmd', quiet = TRUE)", env)
  expect_identical(r$status, 0L, info = r$out)
  f <- list.files(file.path(q$root, ".weft", "stamps"), pattern = "^a\\.", full.names = TRUE)
  expect_length(f, 1L)
  expect_identical(jsonlite::fromJSON(f)$run, "run-from-file")
  q2 <- v4_rproject(list("a.Rmd" = rmd_doc("a")))
  r2 <- u4_r(q2$root, "rmarkdown::render('a.Rmd', quiet = TRUE)", env)
  expect_identical(r2$status, 0L, info = r2$out)
  f2 <- list.files(file.path(q2$root, ".weft", "stamps"), pattern = "^a\\.", full.names = TRUE)
  expect_identical(jsonlite::fromJSON(f2)$run, "run-from-env")
})

test_that("4c G30: verify() on an R Markdown project is not misled by a .weft/run left behind", {
  rmd_need()
  v4_env(libs = TRUE)
  q <- v4_rproject(list("a.Rmd" = rmd_doc("a"), ".weft/run" = c("run-stale", "old.Rmd")))
  r <- v4_verify(q$root)
  expect_null(r$err, label = if (!is.null(r$err)) conditionMessage(r$err) else "")
  expect_true(r$value$ok)
  f <- list.files(file.path(q$root, ".weft", "stamps"), pattern = "^a\\.", full.names = TRUE)
  expect_false(identical(jsonlite::fromJSON(f)$run, "run-stale"))
  # the file is put to this run for the render and stays the project's own
  expect_true(file.exists(file.path(q$root, ".weft", "run")))
})

test_that("4c G30: with no WEFT_RUN the knit reads .weft/run, as before", {
  rmd_need()
  q <- v4_rproject(list("a.Rmd" = rmd_doc("a"), ".weft/run" = "run-from-file"))
  env <- u4_env(u4_home())
  r <- u4_r(q$root, "rmarkdown::render('a.Rmd', quiet = TRUE)", env)
  expect_identical(r$status, 0L, info = r$out)
  f <- list.files(file.path(q$root, ".weft", "stamps"), pattern = "^a\\.", full.names = TRUE)
  expect_identical(jsonlite::fromJSON(f)$run, "run-from-file")
})

# ---- a document that holds a construct but was not knit with weft active ----------------------------------

test_that("4c G26: an .Rmd that holds a construct and never activates weft has no stamp from this run and fails", {
  rmd_need()
  v4_env(libs = TRUE)
  doc <- c("---", "title: \"t\"", "output:", "  md_document:", "    variant: markdown", "---", "",
           "```{r}", "depth <- 12.5", "```", "", "Depth is `r depth`{.num} here.")
  q <- v4_rproject(list("a.Rmd" = doc))
  r <- v4_verify(q$root)
  expect_verify_failed(r)
  expect_true(v4_has_section(r$report, "Not executed in this render"))
  expect_true(any(grepl("a.Rmd", v4_section(r$report, "Not executed in this render"), fixed = TRUE)))
  expect_true(any(grepl("not executed in this render: served from freeze, or knit without weft active",
                        r$report, fixed = TRUE)))
})
