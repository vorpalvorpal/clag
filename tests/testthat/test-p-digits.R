# Stage 7a, F2: `.p` with `digits` and a label (dev/design-7.md section 2.B,
# N20 to N27, the messages E5 to E7, decision D9, D10). Helpers: helper-7a.R.
# Tests marked "control" pass before `digits` and `label` exist on `.p`.

E5 <- function(got) {
  sprintf("`digits` on `.p` must be a whole number from 1 to 6 (got `%s`) (rule 1.4.17).", got)
}
E6 <- "`sigfig` does not apply to `.p`; use `digits` (rule 1.4.17)."
E7 <- "`label` applies to `.p` only (rule 1.4.17)."

# ---- the signature ----------------------------------------------------------

test_that("N26: fmt_p(x, digits = NULL, label = NULL)", {
  fm <- formals(fmt_p)
  # `target` (TX3) is the last formal of every formatter
  expect_identical(names(fm), c("x", "digits", "label", "target"))
  expect_null(fm$digits)
  expect_null(fm$label)
})

# ---- N21: digits d ----------------------------------------------------------

test_that("N21: d = 3, every example of the design", {
  want <- c(`0` = "p < 0.001", `0.0004` = "p < 0.001", `0.001` = "p = 0.001",
            `0.046` = "p = 0.046", `0.12` = "p = 0.120", `0.9994` = "p = 0.999",
            `0.9996` = "p > 0.999", `1` = "p > 0.999")
  for (v in names(want)) {
    expect_equal(p7_txt(fmt_p(as.numeric(v), digits = 3)), want[[v]], label = paste("d=3:", v))
  }
})

test_that("N21: d = 2, every example of the design", {
  expect_equal(p7_txt(fmt_p(0.004, digits = 2)), "p < 0.01")
  expect_equal(p7_txt(fmt_p(0.046, digits = 2)), "p = 0.05")
  expect_equal(p7_txt(fmt_p(0.995, digits = 2)), "p > 0.99")
})

test_that("N21: d = 4, every example of the design", {
  expect_equal(p7_txt(fmt_p(0.00004, digits = 4)), "p < 0.0001")
  expect_equal(p7_txt(fmt_p(0.05, digits = 4)), "p = 0.0500")
})

test_that("N21: the thresholds at d = 1 to 4, exactly (10^-d and 1 - 10^-d print with =)", {
  expect_equal(p7_txt(fmt_p(0, digits = 1)), "p < 0.1")
  expect_equal(p7_txt(fmt_p(0.1, digits = 1)), "p = 0.1")
  expect_equal(p7_txt(fmt_p(0.5, digits = 1)), "p = 0.5")
  expect_equal(p7_txt(fmt_p(0.9, digits = 1)), "p = 0.9")
  expect_equal(p7_txt(fmt_p(0.96, digits = 1)), "p > 0.9")
  expect_equal(p7_txt(fmt_p(1, digits = 1)), "p > 0.9")
  expect_equal(p7_txt(fmt_p(0.01, digits = 2)), "p = 0.01")
  expect_equal(p7_txt(fmt_p(0.99, digits = 2)), "p = 0.99")
  expect_equal(p7_txt(fmt_p(1, digits = 2)), "p > 0.99")
  expect_equal(p7_txt(fmt_p(0.999, digits = 3)), "p = 0.999")
  expect_equal(p7_txt(fmt_p(0.0001, digits = 4)), "p = 0.0001")
  expect_equal(p7_txt(fmt_p(0.9999, digits = 4)), "p = 0.9999")
  expect_equal(p7_txt(fmt_p(0.99996, digits = 4)), "p > 0.9999")
  expect_equal(p7_txt(fmt_p(0, digits = 4)), "p < 0.0001")
  expect_equal(p7_txt(fmt_p(1, digits = 4)), "p > 0.9999")
})

test_that("N21: the limits d = 5 and d = 6", {
  expect_equal(p7_txt(fmt_p(0.0000004, digits = 6)), "p < 0.000001")
  expect_equal(p7_txt(fmt_p(0.5, digits = 6)), "p = 0.500000")
  expect_equal(p7_txt(fmt_p(0, digits = 5)), "p < 0.00001")
  expect_equal(p7_txt(fmt_p(1, digits = 6)), "p > 0.999999")
})

test_that("N21: a tie rounds half away from zero (values exact in binary)", {
  expect_equal(p7_txt(fmt_p(0.125, digits = 2)), "p = 0.13")
  expect_equal(p7_txt(fmt_p(0.375, digits = 2)), "p = 0.38")
  expect_equal(p7_txt(fmt_p(0.625, digits = 2)), "p = 0.63")
  expect_equal(p7_txt(fmt_p(0.25, digits = 1)), "p = 0.3")
  expect_equal(p7_txt(fmt_p(0.75, digits = 1)), "p = 0.8")
})

test_that("N21: p = 0.000 never prints, whatever d", {
  for (d in 1:6) {
    txt <- p7_txt(fmt_p(1e-9, digits = d))
    expect_false(grepl("= 0\\.0+$", txt), label = paste("d =", d, txt))
    expect_match(txt, "^p < 0\\.0*1$")
    expect_equal(nchar(sub("^p < 0\\.", "", txt)), d)
  }
})

test_that("N21: a vector prints one text per element", {
  expect_equal(p7_txt(fmt_p(c(0.0004, 0.046, 0.12, 0.9996), digits = 3)),
               c("p < 0.001", "p = 0.046", "p = 0.120", "p > 0.999"))
})

test_that("N21: the key d on a construct (digits as the scanner reads it, a string)", {
  expect_equal(p7_app(0.046, ".p", list(digits = "3")), "p = 0.046")
  expect_equal(p7_app(0.0004, ".p", list(digits = "3")), "p < 0.001")
  expect_equal(p7_app(0.12, ".p", list(digits = "2")), "p = 0.12")
  expect_equal(p7_app(0.9996, ".p", list(digits = "3")), "p > 0.999")
})

# ---- N22: without digits or p_digits ----------------------------------------

test_that("N22: without digits or p_digits, 1.4.17 is unchanged (control)", {
  expect_equal(p7_txt(fmt_p(0)), "p < 0.001")
  expect_equal(p7_txt(fmt_p(0.0004)), "p < 0.001")
  expect_equal(p7_txt(fmt_p(0.001)), "p = 0.001")
  expect_equal(p7_txt(fmt_p(0.046)), "p = 0.046")
  expect_equal(p7_txt(fmt_p(0.12)), "p = 0.12")
  expect_equal(p7_txt(fmt_p(0.9)), "p = 0.90")
  expect_equal(p7_txt(fmt_p(0.995)), "p > 0.99")
  expect_equal(p7_txt(fmt_p(1)), "p > 0.99")
})

test_that("N22: the .p value range is unchanged (control, and with digits)", {
  expect_error(fmt_p(1.5), class = "weft_value_error")
  expect_error(fmt_p(-0.1), class = "weft_value_error")
  expect_error(fmt_p(1.5, digits = 3), class = "weft_value_error")
  expect_error(fmt_p(-0.1, digits = 3), class = "weft_value_error")
  expect_error(fmt_p(NA_real_, digits = 3), class = "weft_no_value")
})

# ---- N23: label -------------------------------------------------------------

test_that("N23: a label replaces the p", {
  expect_equal(p7_txt(fmt_p(0.046, label = "q")), "q = 0.046")
  expect_equal(p7_txt(fmt_p(0.0004, label = "q")), "q < 0.001")
  expect_equal(p7_txt(fmt_p(0.995, label = "q")), "q > 0.99")
  expect_equal(p7_txt(fmt_p(0.12, label = "q")), "q = 0.12")
  expect_equal(p7_app(0.046, ".p", list(label = "q")), "q = 0.046")
})

test_that("N23: an empty label prints no label, no '=' and no space before the number", {
  expect_equal(p7_txt(fmt_p(0.046, label = "")), "0.046")
  expect_equal(p7_txt(fmt_p(0.0004, label = "")), "< 0.001")
  expect_equal(p7_txt(fmt_p(0.995, label = "")), "> 0.99")
  expect_equal(p7_txt(fmt_p(0.12, label = "")), "0.12")
  expect_equal(p7_app(0.046, ".p", list(label = "")), "0.046")
})

test_that("N23: the label is printed as written, markdown included", {
  expect_equal(p7_txt(fmt_p(0.046, label = "*p*")), "*p* = 0.046")
  expect_equal(p7_txt(fmt_p(0.0004, label = "*p*")), "*p* < 0.001")
  expect_equal(p7_txt(fmt_p(0.046, label = "p-adj")), "p-adj = 0.046")
})

test_that("N23: digits and label together", {
  expect_equal(p7_txt(fmt_p(0.046, digits = 3, label = "q")), "q = 0.046")
  expect_equal(p7_txt(fmt_p(0.0004, digits = 3, label = "q")), "q < 0.001")
  expect_equal(p7_txt(fmt_p(0.12, digits = 3, label = "")), "0.120")
  expect_equal(p7_txt(fmt_p(0.0004, digits = 3, label = "")), "< 0.001")
  expect_equal(p7_txt(fmt_p(0.9996, digits = 3, label = "")), "> 0.999")
  expect_equal(p7_txt(fmt_p(0.995, digits = 2, label = "")), "> 0.99")
})

test_that("N21/N23: the decimal mark applies to the digits and keeps the label", {
  p7_cfg(c("decimal_mark: \",\"", "big_mark: \".\""))
  expect_equal(p7_txt(fmt_p(0.046, digits = 3)), "p = 0,046")
  expect_equal(p7_txt(fmt_p(0.0004, digits = 3)), "p < 0,001")
  expect_equal(p7_txt(fmt_p(0.12, digits = 3, label = "")), "0,120")
  expect_equal(p7_txt(fmt_p(0.046)), "p = 0,046")                           # control
})

# ---- N27: the record --------------------------------------------------------

test_that("N27: number and relation as N21; the label does not enter the record", {
  r <- p7_rec(0.0004, ".p", list(digits = "3"))
  expect_equal(r$relation, "<")
  expect_equal(r$number, 0.001)
  r <- p7_rec(0.9996, ".p", list(digits = "3"))
  expect_equal(r$relation, ">")
  expect_equal(r$number, 0.999)
  r <- p7_rec(0.9996, ".p", list(digits = "2"))
  expect_equal(r$relation, ">")
  expect_equal(r$number, 0.99)
  r <- p7_rec(0.12, ".p", list(digits = "3"))
  expect_equal(r$relation, "=")
  expect_equal(r$number, 0.12)
  expect_true(r$decimals)
  r <- p7_rec(0.9994, ".p", list(digits = "3"))
  expect_equal(r$relation, "=")
  expect_equal(r$number, 0.999)
  r <- p7_rec(0, ".p", list(digits = "4"))
  expect_equal(r$number, 1e-04)
  for (v in c(0.0004, 0.046, 0.9996)) {
    with_label <- p7_rec(v, ".p", list(digits = "3", label = "q"))
    without <- p7_rec(v, ".p", list(digits = "3"))
    expect_equal(with_label$number, without$number)
    expect_equal(with_label$relation, without$relation)
    expect_equal(with_label$decimals, without$decimals)
    empty <- p7_rec(v, ".p", list(digits = "3", label = ""))
    expect_equal(empty$number, without$number)
    expect_equal(empty$relation, without$relation)
  }
})

test_that("N27: without digits the record is as it was (control)", {
  expect_equal(p7_rec(0.0004, ".p")$relation, "<")
  expect_equal(p7_rec(0.0004, ".p")$number, 0.001)
  expect_equal(p7_rec(0.995, ".p")$relation, ">")
  expect_equal(p7_rec(0.995, ".p")$number, 0.99)
  expect_equal(p7_rec(0.046, ".p")$number, 0.046)
})

# ---- N20: E5, E6 ------------------------------------------------------------

test_that("E5: digits on .p must be a whole number from 1 to 6", {
  for (got in c("0", "7", "1.5", "-1", "abc")) {
    e <- tryCatch(weft:::apply_formatters(0.05, ".p", list(digits = got)), error = function(e) e)
    expect_s3_class(e, "weft_construct_error")
    expect_equal(conditionMessage(e), E5(got), label = got)
  }
  for (ok in as.character(1:6)) {                                            # the limits are fine
    expect_no_error(weft:::apply_formatters(0.05, ".p", list(digits = ok)))
  }
})

test_that("E5: fmt_p(digits =) is judged the same way, got as written", {
  for (got in list(0, 7, 1.5)) {
    e <- tryCatch(fmt_p(0.05, digits = got), error = function(e) e)
    expect_s3_class(e, "weft_construct_error")
    expect_equal(conditionMessage(e), E5(format(got)))
  }
})

test_that("E5: the scanner finds it from the source", {
  for (got in c("0", "7", "1.5")) {
    errs <- p7_scan_errs(sprintf("A `r 0.05`{.p digits=\"%s\"} B.", got))
    expect_true(any(errs == E5(got)), label = paste(got, "->", paste(errs, collapse = " / ")))
  }
  expect_identical(p7_scan_errs("A `r 0.05`{.p digits=\"3\"} B `r 0.05`{.p label=\"q\"} C `r 0.05`{.p label=\"\"} D."),
                   character())
})

test_that("E6: sigfig on .p is a construct error", {
  e <- tryCatch(weft:::apply_formatters(0.05, ".p", list(sigfig = "2")), error = function(e) e)
  expect_s3_class(e, "weft_construct_error")
  expect_equal(conditionMessage(e), E6)
  errs <- p7_scan_errs("A `r 0.05`{.p sigfig=\"2\"} B.")
  expect_true(any(errs == E6), label = paste(errs, collapse = " / "))
})

test_that("E6: on .date digits and sigfig stay the error of today (control)", {
  d <- as.Date("2024-06-03")
  for (k in c("digits", "sigfig")) {
    e <- tryCatch(weft:::apply_formatters(d, ".date", stats::setNames(list("2"), k)), error = function(e) e)
    expect_s3_class(e, "weft_construct_error")
    expect_equal(conditionMessage(e), "`digits` and `sigfig` do not apply to `.date`.")
  }
})

# ---- N24: E7 ----------------------------------------------------------------

test_that("E7: label on a construct without .p is a construct error", {
  for (cls in list(".num", ".pct", c(".num", ".strong"), ".word")) {
    e <- tryCatch(weft:::apply_formatters(3, cls, list(label = "q")), error = function(e) e)
    expect_s3_class(e, "weft_construct_error")
    expect_equal(conditionMessage(e), E7, label = paste(cls, collapse = " "))
  }
})

test_that("E7: the scanner finds it from the source", {
  for (src in c("A `r 3`{.num label=\"q\"} B.", "A `r 0.2`{.pct label=\"q\"} B.",
                "A `r c(1, 2)`{.and label=\"q\"} B.")) {
    errs <- p7_scan_errs(src)
    expect_true(any(errs == E7), label = paste(src, "->", paste(errs, collapse = " / ")))
  }
})

test_that("N24: a code span whose only attribute is label is not a named value and stays code", {
  expect_identical(p7_scan_errs("A `x`{label=\"q\"} B."), character())
})

# ---- N25: settings ----------------------------------------------------------

test_that("N25: p_digits from the settings", {
  p7_cfg("p_digits: 3")
  expect_equal(p7_txt(fmt_p(0.12)), "p = 0.120")
  expect_equal(p7_txt(fmt_p(0.0004)), "p < 0.001")
  expect_equal(p7_txt(fmt_p(0.9996)), "p > 0.999")
  expect_equal(p7_app(0.046, ".p"), "p = 0.046")
  expect_equal(p7_rec(0.0004, ".p")$number, 0.001)
})

test_that("N25: a digits key (or argument) beats p_digits", {
  p7_cfg("p_digits: 3")
  expect_equal(p7_txt(fmt_p(0.12, digits = 2)), "p = 0.12")
  expect_equal(p7_app(0.12, ".p", list(digits = "2")), "p = 0.12")
  expect_equal(p7_app(0.046, ".p", list(digits = "4")), "p = 0.0460")
})

test_that("N25: p_digits null is the rule of 1.4.17", {
  p7_cfg("p_digits: null")
  expect_equal(p7_txt(fmt_p(0.12)), "p = 0.12")
  expect_equal(p7_txt(fmt_p(0.0004)), "p < 0.001")
})

test_that("N25: p_label from the settings, and an empty one", {
  p7_cfg("p_label: q")
  expect_equal(p7_txt(fmt_p(0.046)), "q = 0.046")
  expect_equal(p7_app(0.0004, ".p"), "q < 0.001")
  p7_cfg("p_label: \"\"")
  expect_equal(p7_txt(fmt_p(0.046)), "0.046")
  expect_equal(p7_app(0.995, ".p"), "> 0.99")
})

test_that("N25: a label key (or argument) beats p_label, an empty key too", {
  p7_cfg("p_label: q")
  expect_equal(p7_txt(fmt_p(0.046, label = "p")), "p = 0.046")
  expect_equal(p7_app(0.046, ".p", list(label = "r")), "r = 0.046")
  expect_equal(p7_txt(fmt_p(0.046, label = "")), "0.046")
  expect_equal(p7_app(0.046, ".p", list(label = "")), "0.046")
  p7_cfg("p_label: \"\"")
  expect_equal(p7_txt(fmt_p(0.046, label = "p")), "p = 0.046")
})

test_that("N25: both settings together, and keys beating each", {
  p7_cfg(c("p_digits: 3", "p_label: q"))
  expect_equal(p7_txt(fmt_p(0.12)), "q = 0.120")
  expect_equal(p7_txt(fmt_p(0.12, digits = 2, label = "p")), "p = 0.12")
})

test_that("N22/N25: the default setting for p_label is p (control)", {
  p7_cfg(NULL)
  expect_equal(p7_txt(fmt_p(0.046)), "p = 0.046")
})

# ---- knitting ---------------------------------------------------------------

test_that("F2 knit: the three sentences of the design", {
  res <- p7_knit(c(
    "The trend was weak (`r 0.046`{.p digits=\"3\"}).",
    "",
    "After correction it held (`r 0.012`{.p label=\"q\"}).",
    "",
    "Effects were small (`r 0.046`{.p label=\"\"}).",
    "",
    "Others: `r 0.0004`{.p digits=\"3\" label=\"\"} and `r 0.12`{.p digits=\"3\"} and `r 0.12`{.p}."))
  expect_equal(res$text, c(
    "The trend was weak (p = 0.046).",
    "After correction it held (q = 0.012).",
    "Effects were small (0.046).",
    "Others: < 0.001 and p = 0.120 and p = 0.12."))
})

test_that("F2 knit: p_digits and p_label in _weft.yml, and a key beating them", {
  res <- p7_knit(c(
    "A `r 0.12`{.p} and `r 0.0004`{.p} and `r 0.12`{.p digits=\"2\" label=\"p\"}."),
    yml = c("p_digits: 3", "p_label: q"))
  expect_equal(res$text, "A q = 0.120 and q < 0.001 and p = 0.12.")
})

test_that("F2 knit: p_label: \"\" in _weft.yml prints no label", {
  res <- p7_knit(c("A `r 0.046`{.p} and `r 0.995`{.p}."), yml = "p_label: \"\"")
  expect_equal(res$text, "A 0.046 and > 0.99.")
})

test_that("E5 knit: digits=\"7\" stops the render with E5's text", {
  res <- p7_knit(c("A `r 0.046`{.p digits=\"7\"} B."), may_fail = TRUE)
  expect_true(res$failed)
  expect_match(res$error$message, E5("7"), fixed = TRUE)
})

test_that("E7 knit: label on .num stops the render with E7's text", {
  res <- p7_knit(c("A `r 3`{.num label=\"q\"} B."), may_fail = TRUE)
  expect_true(res$failed)
  expect_match(res$error$message, E7, fixed = TRUE)
})

test_that("control: a .p with no digits or label knits as before", {
  res <- p7_knit(c("A `r 0.046`{.p} and `r 0.0004`{.p} and `r 0.12`{.p} and `r 0.995`{.p}."))
  expect_equal(res$text, "A p = 0.046 and p < 0.001 and p = 0.12 and p > 0.99.")
})

# ---- the conformance rows ---------------------------------------------------

test_that("N28: p.tsv gains rows with digits, a label and an empty label", {
  d <- as.data.frame(weft:::conformance_rows("p"), stringsAsFactors = FALSE)
  txt <- function(value, keys) {
    hit <- d$value == value & d$classes == "p" & d$keys == keys
    if (sum(hit) != 1L) return(sprintf("<%d rows for %s | %s>", sum(hit), value, keys))
    d$text[hit]
  }
  expect_equal(txt("0.0004", "digits=3"), "p < 0.001")
  expect_equal(txt("0.12", "digits=3"), "p = 0.120")
  expect_equal(txt("0.9996", "digits=3"), "p > 0.999")
  expect_equal(txt("0.004", "digits=2"), "p < 0.01")
  expect_equal(txt("0.00004", "digits=4"), "p < 0.0001")
  expect_equal(txt("0.046", "label=q"), "q = 0.046")
  expect_equal(txt("0.046", "label="), "0.046")
  expect_equal(txt("0.046", ""), "p = 0.046")                                 # control
})

test_that("control: every p conformance row without digits or label is as committed", {
  live <- as.data.frame(weft:::conformance_rows("p"), stringsAsFactors = FALSE)
  file <- utils::read.delim(test_path("_conformance", "p.tsv"), header = TRUE, sep = "\t", quote = "",
                            comment.char = "", colClasses = "character", na.strings = character(),
                            check.names = FALSE, encoding = "UTF-8", fileEncoding = "UTF-8")
  old <- function(x) x[!grepl("digits|label|cfg", x$keys), , drop = FALSE]
  live <- old(live); file <- old(file)
  rownames(live) <- NULL; rownames(file) <- NULL
  expect_gt(nrow(live), 0L)
  expect_identical(live, file)
})
