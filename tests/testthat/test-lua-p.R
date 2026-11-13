# Stage 7b, F2 in the filter: `.p` with `digits` and `label`, and the settings `p_digits` and `p_label`
# (dev/design-7.md section 2.B, N20 to N28; the messages E5, E6 and E7 of section 7). The expected texts are
# the design's examples and the committed rows of p.tsv, read through the whole filter (f6_rows()). ASCII only.

PP_CE <- "<<weft: construct error, line {L}>>"
PP_VE <- "<<weft: value error, line {L}>>"
PE5 <- function(got) {
  sprintf("`digits` on `.p` must be a whole number from 1 to 6 (got `%s`) (rule 1.4.17).", got)
}
PE6 <- "`sigfig` does not apply to `.p`; use `digits` (rule 1.4.17)."
PE7 <- "`label` applies to `.p` only (rule 1.4.17)."

pp_block <- function() {
  carrier(
    z = fr_float("0"), v0004 = fr_float("0.0004"), v001 = fr_float("0.001"), v046 = fr_float("0.046"),
    v12 = fr_float("0.12"), v9994 = fr_float("0.9994"), v9996 = fr_float("0.9996"), one = fr_float("1"),
    v004 = fr_float("0.004"), v995 = fr_float("0.995"), v00004 = fr_float("0.00004"), v05 = fr_float("0.05"),
    v125 = fr_float("0.125"), v25 = fr_float("0.25"), v96 = fr_float("0.96"), v1 = fr_float("0.1"),
    big = fr_float("1.5"), negv = fr_float("-0.1"), v9 = fr_float("0.9"), word = fr_str("north"),
    num3 = fr_float("3"), setv = fr_list_float(c("0.0004", "0.046", "0.12", "0.9996"))
  )
}
pp_run <- function(tbl, ...) {
  x <- tbl_cases(tbl)
  res <- filter_cases(x$cases, list(pp_block()), draft = TRUE, ...)
  expect_cases(res, x$expected)
  invisible(res)
}

# ---- N21: digits d ------------------------------------------------------------------------------------

test_that("N21: d = 3, every example of the design", {
  pp_run(list(a = c("`z`{.p digits=\"3\"}", "p < 0.001"), b = c("`v0004`{.p digits=\"3\"}", "p < 0.001"),
              c = c("`v001`{.p digits=\"3\"}", "p = 0.001"), d = c("`v046`{.p digits=\"3\"}", "p = 0.046"),
              e = c("`v12`{.p digits=\"3\"}", "p = 0.120"), f = c("`v9994`{.p digits=\"3\"}", "p = 0.999"),
              g = c("`v9996`{.p digits=\"3\"}", "p > 0.999"), h = c("`one`{.p digits=\"3\"}", "p > 0.999")))
})

test_that("N21: d = 2 and d = 4, every example of the design", {
  pp_run(list(a = c("`v004`{.p digits=\"2\"}", "p < 0.01"), b = c("`v046`{.p digits=\"2\"}", "p = 0.05"),
              c = c("`v995`{.p digits=\"2\"}", "p > 0.99"), d = c("`v00004`{.p digits=\"4\"}", "p < 0.0001"),
              e = c("`v05`{.p digits=\"4\"}", "p = 0.0500")))
})

test_that("N21: the limits, the thresholds themselves print with =, and a tie rounds half away from zero", {
  pp_run(list(a = c("`z`{.p digits=\"1\"}", "p < 0.1"), b = c("`v1`{.p digits=\"1\"}", "p = 0.1"),
              c = c("`v9`{.p digits=\"1\"}", "p = 0.9"), d = c("`v96`{.p digits=\"1\"}", "p > 0.9"),
              e = c("`one`{.p digits=\"1\"}", "p > 0.9"), f = c("`one`{.p digits=\"6\"}", "p > 0.999999"),
              g = c("`z`{.p digits=\"5\"}", "p < 0.00001"), h = c("`v125`{.p digits=\"2\"}", "p = 0.13"),
              i = c("`v25`{.p digits=\"1\"}", "p = 0.3")))
})

test_that("N22: without digits or p_digits, 1.4.17 is unchanged (control)", {
  pp_run(list(a = c("`z`{.p}", "p < 0.001"), b = c("`v0004`{.p}", "p < 0.001"), c = c("`v001`{.p}", "p = 0.001"),
              d = c("`v046`{.p}", "p = 0.046"), e = c("`v12`{.p}", "p = 0.12"), f = c("`v9`{.p}", "p = 0.90"),
              g = c("`v995`{.p}", "p > 0.99"), h = c("`one`{.p}", "p > 0.99")))
})

test_that("N27: the .p value range is unchanged, with and without digits (a value error)", {
  res <- filter_cases(c(hi = "A `big`{.p} z.", lo = "A `negv`{.p} z.", hid = "A `big`{.p digits=\"3\"} z.",
                        lod = "A `negv`{.p digits=\"3\"} z."), list(pp_block()), draft = TRUE)
  expect_cases(res, c(hi = paste0("A ", PP_VE, " z."), lo = paste0("A ", PP_VE, " z."),
                      hid = paste0("A ", PP_VE, " z."), lod = paste0("A ", PP_VE, " z.")))
})

# ---- N23: label ---------------------------------------------------------------------------------------

test_that("N23: a label replaces the p; an empty label prints no label, no = and no space", {
  pp_run(list(a = c("`v046`{.p label=\"q\"}", "q = 0.046"), b = c("`v0004`{.p label=\"q\"}", "q < 0.001"),
              c = c("`v995`{.p label=\"q\"}", "q > 0.99"), d = c("`v12`{.p label=\"q\"}", "q = 0.12"),
              e = c("`v046`{.p label=\"\"}", "0.046"), f = c("`v0004`{.p label=\"\"}", "< 0.001"),
              g = c("`v995`{.p label=\"\"}", "> 0.99"), h = c("`v12`{.p label=\"\"}", "0.12"),
              i = c("`v046`{.p label=\"p-adj\"}", "p-adj = 0.046")))
})

test_that("N23: digits and label together", {
  pp_run(list(a = c("`v046`{.p digits=\"3\" label=\"q\"}", "q = 0.046"), b = c("`v0004`{.p digits=\"3\" label=\"q\"}", "q < 0.001"),
              c = c("`v12`{.p digits=\"3\" label=\"\"}", "0.120"), d = c("`v9996`{.p label=\"\" digits=\"3\"}", "> 0.999")))
})

test_that("N23: the label is printed as written, markdown included", {
  res <- f6_cases_html(c(a = "A `v046`{.p label=\"*p*\"} z.", b = "A `v0004`{.p label=\"*p*\"} z."), list(pp_block()))
  want <- f6_want_html(c(a = "A *p* = 0.046 z.", b = "A *p* < 0.001 z."))
  expect_identical(res$status, 0L)
  for (nm in names(want)) expect_identical(unname(res$got[nm]), unname(want[nm]), label = nm)
  expect_match(res$got[["a"]], "<em>p</em> = 0.046", fixed = TRUE)
})

test_that("N23: digits and label read from a name's keys do not change the other classes (control)", {
  pp_run(list(a = c("`num3`{.num}", "3"), b = c("`v12`{.pct}", "12%")))
})

# ---- N25: the settings --------------------------------------------------------------------------------

test_that("N25: p_digits and p_label from _weft.yml, and a key on the construct wins", {
  tbl <- list(a = c("`v12`{.p}", "p = 0.120"), b = c("`v0004`{.p}", "p < 0.001"), c = c("`v9996`{.p}", "p > 0.999"),
              d = c("`v12`{.p digits=\"2\"}", "p = 0.12"), e = c("`v046`{.p digits=\"4\"}", "p = 0.0460"))
  pp_run(tbl, weft_yml = "p_digits: 3")
  pp_run(list(a = c("`v046`{.p}", "q = 0.046"), b = c("`v0004`{.p}", "q < 0.001"), c = c("`v046`{.p label=\"r\"}", "r = 0.046"),
              d = c("`v046`{.p label=\"\"}", "0.046")), weft_yml = "p_label: q")
  pp_run(list(a = c("`v995`{.p}", "> 0.99"), b = c("`v046`{.p}", "0.046"), c = c("`v046`{.p label=\"p\"}", "p = 0.046")),
         weft_yml = "p_label: \"\"")
  pp_run(list(a = c("`v12`{.p}", "q = 0.120"), b = c("`v12`{.p digits=\"2\" label=\"p\"}", "p = 0.12")),
         weft_yml = c("p_digits: 3", "p_label: q"))
})

test_that("N25: p_digits null and the default p_label are the rule of 1.4.17 (control)", {
  pp_run(list(a = c("`v12`{.p}", "p = 0.12"), b = c("`v0004`{.p}", "p < 0.001")), weft_yml = "p_digits: null")
  pp_run(list(a = c("`v046`{.p}", "p = 0.046")), weft_yml = "p_label: p")
})

test_that("N25: the settings reach a .p inside a collapse class, one text per element", {
  pp_run(list(and = c("`setv`{.and .p}", "p < 0.001, p = 0.046, p = 0.120 and p > 0.999")), weft_yml = "p_digits: 3")
})

# ---- N20, E5, E6: construct errors ---------------------------------------------------------------------

test_that("E5: digits on .p must be a whole number from 1 to 6, with R's text and the value as written", {
  bad <- c("0", "7", "1.5", "-1", "abc")
  cases <- stats::setNames(sprintf("A `v046`{.p digits=\"%s\"} z.", bad), paste0("d", seq_along(bad)))
  res <- filter_cases(cases, list(pp_block()), draft = TRUE)
  expect_cases(res, stats::setNames(rep(paste0("A ", PP_CE, " z."), length(bad)), names(cases)))
  for (got in bad) expect_true(grepl(PE5(got), res$stderr, fixed = TRUE), label = PE5(got))
})

test_that("E5: 1 to 6 are fine (control)", {
  ok <- as.character(1:6)
  cases <- stats::setNames(sprintf("A `v12`{.p digits=\"%s\"} z.", ok), paste0("d", ok))
  res <- filter_cases(cases, list(pp_block()), draft = TRUE)
  expect_cases(res, stats::setNames(c("A p = 0.1 z.", "A p = 0.12 z.", "A p = 0.120 z.", "A p = 0.1200 z.",
                                      "A p = 0.12000 z.", "A p = 0.120000 z."), names(cases)))
  expect_false(grepl("must be a whole number", res$stderr, fixed = TRUE))
})

test_that("E6: sigfig on .p is a construct error, whatever the other keys", {
  res <- filter_cases(c(a = "A `v046`{.p sigfig=\"2\"} z.", b = "A `v046`{.p sigfig=\"2\" label=\"q\"} z."),
                      list(pp_block()), draft = TRUE)
  expect_cases(res, c(a = paste0("A ", PP_CE, " z."), b = paste0("A ", PP_CE, " z.")))
  expect_true(grepl(PE6, res$stderr, fixed = TRUE))
})

test_that("E6: on .date digits and sigfig stay the error of today (control)", {
  res <- filter_cases(c(a = "A `dt`{.date digits=\"2\"} z."), list(carrier(dt = fr_date("2024-06-03"))), draft = TRUE)
  expect_true(grepl("weft: construct error", res$got[["a"]], fixed = TRUE))
  expect_true(grepl("`digits` and `sigfig` do not apply to `.date`.", res$stderr, fixed = TRUE))
  expect_false(grepl("must be a whole number from 1 to 6", res$stderr, fixed = TRUE))
})

# ---- N24, E7: label ------------------------------------------------------------------------------------

test_that("E7: label on a construct without .p is a construct error", {
  res <- filter_cases(c(num = "A `num3`{.num label=\"q\"} z.", pct = "A `v12`{.pct label=\"q\"} z.",
                        word = "A `num3`{.word label=\"q\"} z.", and = "A `setv`{.and label=\"q\"} z.",
                        strong = "A `num3`{.num .strong label=\"q\"} z."), list(pp_block()), draft = TRUE)
  expect_cases(res, stats::setNames(rep(paste0("A ", PP_CE, " z."), 5L), c("num", "pct", "word", "and", "strong")))
  expect_true(grepl(PE7, res$stderr, fixed = TRUE))
})

test_that("N24: a code span whose only attribute is label is not a named value and stays code", {
  res <- filter_md(c(pp_block(), "", "A `v046`{label=\"q\"} z."), to = "html")
  expect_identical(res$status, 0L)
  expect_match(res$output, "<code", fixed = TRUE)
  expect_false(grepl("weft", res$stderr, fixed = TRUE))
  expect_false(grepl("q = 0.046", res$output, fixed = TRUE))
})

test_that("N24: label is not left over for weft-check.lua beside .p (the whole run reports nothing)", {
  res <- filter_md(c(pp_block(), "", "A `v046`{.p label=\"q\"} and `v046`{.p label=\"\"} z."), to = "plain")
  expect_identical(res$status, 0L)
  expect_identical(trimws(res$output), "A q = 0.046 and 0.046 z.")
  expect_false(grepl("weft", res$stderr, fixed = TRUE))
})

# ---- N28: the committed rows, through the filter -------------------------------------------------------

test_that("N28: every p.tsv row with digits, label or a setting prints what R printed", {
  d <- f6_read("p")
  new <- d[grepl("digits|label|cfg", d$keys), , drop = FALSE]
  expect_identical(nrow(new), 147L)
  expect_true(any(grepl("^cfg\\.p_digits=", new$keys)))
  expect_true(any(grepl("^cfg\\.p_label=$", new$keys)))
  expect_true(any(grepl("label= cfg\\.p_label=q", new$keys)))
  r <- f6_rows(new)
  f6_expect_rows(new, r, "p.tsv new rows")
})

test_that("N28: the p.tsv rows without digits, label or a setting are as before (control)", {
  d <- f6_read("p")
  old <- d[!grepl("digits|label|cfg", d$keys), , drop = FALSE]
  expect_gt(nrow(old), 30L)
  r <- f6_rows(old)
  f6_expect_rows(old, r, "p.tsv old rows")
})
