# Package 6P: parity wins, the static half (dev/lua-parity.md, A1, A2, S1, S3). The scanner
# (weft:::scan_file(), filter_governor_errors()), the construct lint and the base-R pre-render script must
# agree with the filter on the grammar of `if`. No Pandoc, Quarto, Python or Julia is needed.
# Helpers: helper-6d.R (w6d_scan(), w6d_doc(), w6d_find(), W6D_E3()), helper-3.R (lint_proj()).
#
#   A1  `!name` is in the grammar (one line in each of the three copies): scanner, lint, pre-render script.
#   A2  control: a date compared with a 'YYYY-MM-DD' literal is already accepted statically.
#   S1  a `claim` or `level` key on a named value or a span in a document the filter resolves is a scanner
#       error (the text is not fixed: `!is.na(error)`).
#   S3  filter_governor_errors() cites 1.12.6 for governor values.

pp_run <- function(files, env = parent.frame()) {
  script <- system.file("quarto", "weft-pre-render.R", package = "weft")
  if (!expect_true(nzchar(script) && file.exists(script), label = "the package ships its pre-render script")) {
    return(invisible(NULL))
  }
  root <- lint_proj(files, env = env)
  withr::local_envvar(c(QUARTO_PROJECT_INPUT_FILES = NA, WEFT_RUN = NA), .local_envir = env)
  out <- suppressWarnings(withr::with_dir(root, system2(file.path(R.home("bin"), "Rscript"), shQuote(script),
                                                         stdout = TRUE, stderr = TRUE)))
  list(status = as.integer(attr(out, "status") %||% 0L), log = paste(out, collapse = "\n"))
}
`%||%` <- function(a, b) if (is.null(a)) b else a

PP_YML <- c("project:", "  type: default", "format: html")
pp_doc <- function(line) c("---", "title: t", "---", "", line)
pp_span <- function(cond) sprintf("The level [rose | fell]{if=\"%s\"} again.", cond)
pp_row <- function(src) w6d_scan(w6d_doc(src))

PP_GOOD <- c("!a", "!x", "!ok, n > 10", "n > 10, !ok", "!a, !b", "s == 'north', !ok", "!n.sites", "!_x")
PP_BAD <- c("!!a", "!a == b", "! (a)", "!(a)", "!n > 3", "!", "!'x'", "!3", "!a b", "!a,", "!a && b", "!a | b",
            "!!a, b")

# ---- A1 ----------------------------------------------------------------------------------------------------------

test_that("parity A1: the scanner takes `!name` in a condition, alone or beside other parts", {
  for (cond in PP_GOOD) {
    x <- pp_row(pp_span(cond))
    expect_identical(nrow(x), 1L, label = cond)
    expect_true(is.na(x$error), label = paste("no error for", cond))
  }
})

test_that("parity A1: the scanner refuses `!` before anything but a name, quoting the part", {
  for (cond in setdiff(PP_BAD, c("!a,", "!!a, b"))) {
    x <- pp_row(pp_span(cond))
    expect_false(is.na(x$error), label = paste("an error for", cond))
    expect_true(grepl(W6D_E3(cond), x$error, fixed = TRUE), label = paste("the part is quoted:", cond))
  }
  x <- pp_row(pp_span("!!a, b"))
  expect_true(grepl(W6D_E3("!!a"), x$error, fixed = TRUE), label = "only the failing part is quoted")
  expect_false(is.na(pp_row(pp_span("!a,"))$error), label = "an empty part")
})

test_that("parity A1: filter_governor_errors() agrees with the scanner", {
  for (cond in PP_GOOD) expect_identical(weft:::filter_governor_errors("if", cond), character(), label = cond)
  for (cond in PP_BAD) expect_gt(length(weft:::filter_governor_errors("if", cond)), 0L, label = cond)
  # the span of a one-arm guard too
  expect_identical(weft:::filter_governor_errors("if", "!ok"), character())
})

test_that("parity A1: the construct lint has no finding for `!name`, and one for the refused forms", {
  for (cond in c("!x", "!ok, n > 10")) {
    x <- w6d_find(w6d_doc(c("Intro.", "", pp_span(cond))), "construct")
    expect_identical(nrow(x), 0L, label = cond)
  }
  for (cond in c("!!a", "!a == b", "! (a)")) {
    x <- w6d_find(w6d_doc(c("Intro.", "", pp_span(cond))), "construct")
    expect_identical(nrow(x), 1L, label = cond)
    if (nrow(x) == 1L) expect_identical(x$spec, "1.12.4", label = cond)
  }
})

test_that("parity A1: the pre-render script passes `!name` and stops on the refused forms", {
  for (cond in PP_GOOD) {
    r <- pp_run(list("_quarto.yml" = PP_YML, "a.qmd" = pp_doc(pp_span(cond))))
    expect_identical(r$status, 0L, label = paste("passes", cond))
    expect_false(grepl("holds a weft construct", r$log, fixed = TRUE), label = paste("no complaint:", cond))
  }
  for (cond in c("!!a", "!a == b", "! (a)", "!(a)", "!n > 3", "!a && b")) {
    r <- pp_run(list("_quarto.yml" = PP_YML, "a.qmd" = pp_doc(pp_span(cond))))
    expect_identical(r$status, 1L, label = paste("stops", cond))
    expect_true(grepl("has no `engine: knitr` in its own front matter", r$log, fixed = TRUE), label = cond)
  }
})

test_that("parity A1 control: && and || and the other refused forms are still refused statically", {
  for (cond in c("a && b", "a || b", "not a", "(a)", "a + 1 > b")) {
    expect_false(is.na(pp_row(pp_span(cond))$error), label = cond)
    expect_gt(length(weft:::filter_governor_errors("if", cond)), 0L, label = cond)
  }
})

# ---- A2: a control -----------------------------------------------------------------------------------------------

test_that("parity A2 control: a date against a date literal is already accepted by the scanner, the lint and the pre-render script", {
  conds <- c("d < '2026-07-01'", "'2026-07-01' >= d", "sampled == '2024-02-29'", "d != '2026-01-01', ok")
  for (cond in conds) {
    expect_true(is.na(pp_row(pp_span(cond))$error), label = paste("scanner", cond))
    expect_identical(weft:::filter_governor_errors("if", cond), character(), label = cond)
    expect_identical(nrow(w6d_find(w6d_doc(c("Intro.", "", pp_span(cond))), "construct")), 0L, label = cond)
  }
  r <- pp_run(list("_quarto.yml" = PP_YML, "a.qmd" = pp_doc(pp_span(conds[1]))))
  expect_identical(r$status, 0L)
})

# ---- S1: claim and level ------------------------------------------------------------------------------------------

test_that("parity S1: a `claim` or `level` key on a named value or a span of a filter document is a scanner error", {
  src <- c(
    named_claim = "A `d`{.num claim=\"d < 5\"} z.",
    named_level = "A `d`{.num level=\"warn\"} z.",
    named_val_claim = "A `d`{.val claim=\"d < 5\"} z.",
    if_claim = "A [y | z]{if=\"a\" claim=\"x\"} z.",
    guard_claim = "A [y]{if=\"a\" claim=\"x\"} z.",
    n_claim = "A [c | cs]{n=\"k\" claim=\"x\"} z.",
    n_level = "A [c | cs]{n=\"k\" level=\"warn\"} z.",
    sign_claim = "A [c | cs]{sign=\"k\" claim=\"x\"} z.",
    list_claim = "A [none | # was | # were]{list=\"k\" claim=\"x\"} z.",
    list_level = "A [none | # was | # were]{list=\"k\" level=\"warn\"} z."
  )
  for (nm in names(src)) {
    x <- pp_row(src[[nm]])
    expect_identical(nrow(x), 1L, label = nm)
    expect_false(is.na(x$error), label = paste("an error for", nm))
  }
})

test_that("parity S1: the construct lint reports the key on a filter document, one finding per construct", {
  x <- w6d_find(w6d_doc(c("Intro.", "", "A `d`{.num claim=\"d < 5\"} z.")), "construct")
  expect_identical(nrow(x), 1L)
  expect_true(grepl("claim", x$message, fixed = TRUE))
  y <- w6d_find(w6d_doc(c("Intro.", "", "A [y | z]{if=\"a\" level=\"warn\"} z.")), "construct")
  expect_gte(nrow(y), 1L)
  expect_true(any(grepl("level", y$message, fixed = TRUE)))
})

test_that("parity S1 control: ordinary keys on a named value or a span leave no error", {
  for (s in c("A `d`{.num digits=\"2\"} z.", "A `d`{.num .and sep=\"; \"} z.", "A [y | z]{if=\"a\"} z.",
              "A [c | cs]{n=\"k\"} z.")) {
    expect_true(is.na(pp_row(s)$error), label = s)
  }
})

# ---- S3 -----------------------------------------------------------------------------------------------------------

test_that("parity S3: governor-value errors cite rule 1.12.6, condition errors still cite 1.12.4", {
  expect_match(weft:::filter_governor_errors("n", "3"), "(rule 1.12.6).", fixed = TRUE)
  expect_match(weft:::filter_governor_errors("sign", "3"), "(rule 1.12.6).", fixed = TRUE)
  expect_match(weft:::filter_governor_errors("list", "3"), "(rule 1.12.6).", fixed = TRUE)
  expect_match(weft:::filter_governor_errors("if", "a && b"), "(rule 1.12.4).", fixed = TRUE)
  expect_match(weft:::filter_governor_errors("if", "3 > 2"), "(rule 1.12.4).", fixed = TRUE)
})
