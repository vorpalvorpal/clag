# Stage 7a, F1: an explicit plus sign (dev/design-7.md section 2.A, N1 to N11
# and N14, the messages E1 to E3). `.plus` signs the numbers that `.num` and
# `.pct` print, on `.range` ends and on collapse elements. Helpers: helper-7a.R.
# Tests marked "control" pass before `.plus` exists: they pin what `.plus`
# must leave alone.

E1 <- function(cls) {
  sprintf("`.plus` cannot go with `%s`: it signs a number that `.num` or `.pct` prints (rule 1.4.21).", cls)
}
E2 <- function(key) sprintf("`.plus` does not apply to a span with `%s=` (rule 1.4.21).", key)

# ---- N2: above zero ---------------------------------------------------------

test_that("N2: a positive number prints with + where the minus would stand", {
  expect_equal(p7_txt(fmt_num(1.25, plus = TRUE)), "+1.3")
  expect_equal(p7_txt(fmt_num(1234.5, plus = TRUE)), "+1,234.5")
  expect_equal(p7_txt(fmt_pct(0.12, plus = TRUE)), "+12%")
  expect_equal(p7_txt(fmt_num(0.999, digits = 2, plus = TRUE)), "+1.00")
  expect_equal(p7_txt(fmt_num(1.25, digits = 2, plus = TRUE)), "+1.25")
  expect_equal(p7_txt(fmt_num(1.25, sigfig = 2, plus = TRUE)), "+1.3")
  expect_equal(p7_txt(fmt_num(8, plus = TRUE)), "+8")
})

test_that("N2: a quantity prints +5 m (the sign goes before the number, the unit stays)", {
  plain <- p7_txt(fmt_num(u(5, "m")))                    # control: no plus
  expect_match(plain, "^5.m$")
  expect_equal(p7_txt(fmt_num(u(5, "m"), plus = TRUE)), sub("^5", "+5", plain))
})

test_that("N2: every element of a vector is signed", {
  expect_equal(p7_txt(fmt_num(c(1.25, -1.25, 12), plus = TRUE)),
               c("+1.3", paste0(P7_MINUS, "1.3"), "+12"))
})

# ---- N3: zero ---------------------------------------------------------------

test_that("N3: zero, minus zero and a value that is nothing have no sign", {
  expect_equal(p7_txt(fmt_num(0, plus = TRUE)), "0")
  expect_equal(p7_txt(fmt_num(-0, plus = TRUE)), "0")
  expect_equal(suppressWarnings(p7_txt(fmt_num(1e-10, plus = TRUE))), "0")
  expect_equal(p7_txt(fmt_pct(0, plus = TRUE)), "0%")
})

test_that("N3: 0.04 and -0.04 print 0.0 with no sign and warn exactly as without plus", {
  for (v in c(0.04, -0.04)) {
    r <- p7_zero_warnings(fmt_num(v, plus = TRUE))
    expect_equal(p7_txt(r$value), "0.0", label = paste("value", v))
    expect_length(r$zero, 1L)
    r0 <- p7_zero_warnings(fmt_num(v))                   # control: the same without plus
    expect_equal(p7_txt(r0$value), "0.0")
    expect_length(r0$zero, 1L)
    expect_equal(conditionMessage(r$zero[[1]]), conditionMessage(r0$zero[[1]]))
  }
})

test_that("N3: .pct judges zero on the percentage", {
  r <- p7_zero_warnings(fmt_pct(0.0004, plus = TRUE))
  expect_equal(p7_txt(r$value), "0.0%")
  expect_length(r$zero, 1L)
  expect_equal(p7_txt(fmt_pct(0.004, plus = TRUE)), "+0.4%")
})

# ---- N4: below zero ---------------------------------------------------------

test_that("N4: a negative number prints the minus setting, unchanged", {
  expect_equal(p7_txt(fmt_num(-1.25, plus = TRUE)), paste0(P7_MINUS, "1.3"))
  expect_equal(p7_txt(fmt_pct(-0.12, plus = TRUE)), paste0(P7_MINUS, "12%"))
  expect_equal(p7_txt(fmt_num(-1.25)), paste0(P7_MINUS, "1.3"))   # control
  p7_cfg("minus: \"-\"")
  expect_equal(p7_txt(fmt_num(-1.25, plus = TRUE)), "-1.3")
  expect_equal(p7_txt(fmt_num(1.25, plus = TRUE)), "+1.3")
})

# ---- N5: placement ----------------------------------------------------------

test_that("N5: after a clamp() relation, the plus takes the minus's place", {
  expect_equal(p7_app(clamp(150, ceiling = 99), c(".num", ".plus")), "> +99")
  expect_equal(p7_app(clamp(0.5, floor = 1), c(".num", ".plus")), "< +1")
  expect_equal(p7_app(clamp(-150, floor = -99), c(".num", ".plus")), paste0("< ", P7_MINUS, "99"))
  expect_equal(p7_app(clamp(150, ceiling = 99), ".num"), "> 99")        # control
})

test_that("N5: after a unit written before its number and its space", {
  p7_cfg(c("units:", "  zzgbd:", "    is: base", "    before: true", "    symbol: \"$\"",
           "    space: false", "    name: dollar"))
  expect_equal(p7_txt(fmt_num(u(5, zzgbd), plus = TRUE)), "$+5")
  expect_equal(p7_txt(fmt_num(u(-5, zzgbd), plus = TRUE)), paste0("$", P7_MINUS, "5"))
  expect_equal(p7_txt(fmt_num(u(5, zzgbd))), "$5")                     # control
})

# ---- N6: .range -------------------------------------------------------------

test_that("N6: .range with plus signs the ends and joins with ' to ' when an end has a sign", {
  expect_equal(p7_txt(fmt_range(c(1.2, 3.4), plus = TRUE)), "+1.2 to +3.4")
  expect_equal(p7_txt(fmt_range(c(-0.5, 1.2), plus = TRUE)), paste0(P7_MINUS, "0.5 to +1.2"))
  expect_equal(p7_txt(fmt_range(c(0, 1.2), plus = TRUE)), "0.0 to +1.2")
  expect_equal(p7_txt(fmt_range(c(1.2, 1.2), plus = TRUE)), "+1.2")
  expect_equal(p7_txt(fmt_range(c(-3, -1), plus = TRUE)), paste0(P7_MINUS, "3 to ", P7_MINUS, "1"))
})

test_that("N6: without plus .range is unchanged (control)", {
  expect_equal(p7_txt(fmt_range(c(1.2, 3.4))), "1.2\u20133.4")
  expect_equal(p7_txt(fmt_range(c(0, 1.2))), "0.0\u20131.2")
  expect_equal(p7_txt(fmt_range(c(-3, -1))), paste0(P7_MINUS, "3 to ", P7_MINUS, "1"))
  expect_equal(p7_txt(fmt_range(c(1.2, 1.2))), "1.2")
})

test_that("N6: a range whose ends both print as zero has no sign and keeps the en dash", {
  expect_equal(p7_txt(fmt_range(c(0, 0), plus = TRUE)), "0")
})

test_that("N6: a quantity range with plus keeps the unit once", {
  plain <- p7_txt(fmt_range(u(c(1.2, 3.4), "mg/L")))       # control
  expect_match(plain, "mg/L$")
  expect_equal(p7_txt(fmt_range(u(c(1.2, 3.4), "mg/L"), plus = TRUE)),
               sub("^1.2\u20133.4", "+1.2 to +3.4", plain))
})

# ---- collapse classes -------------------------------------------------------

test_that("N1: each element is signed before the collapse", {
  expect_equal(p7_app(c(1.2, -3.4, 5.6), c(".and", ".plus")),
               paste0("+1.2, ", P7_MINUS, "3.4 and +5.6"))
  expect_equal(p7_app(c(1.2, 3.4), c(".or", ".plus")), "+1.2 or +3.4")
  expect_equal(p7_app(c(1.2, 3.4, 5.6), ".and"), "1.2, 3.4 and 5.6")      # control
})

# ---- N7: .a -----------------------------------------------------------------

test_that("N7: .a reads a leading + as it reads a minus", {
  expect_equal(p7_app(8, c(".num", ".plus", ".a")), "a +8")
  expect_equal(p7_app(-8, c(".num", ".a")), paste0("a ", P7_MINUS, "8"))   # control
  expect_equal(p7_app(8, c(".num", ".a")), "an 8")                         # control
})

# ---- N1: the class goes with the others -------------------------------------

test_that("N1: .plus alone implies .num", {
  expect_equal(p7_app(1.25, ".plus"), "+1.3")
  expect_equal(p7_app(-1.25, ".plus"), paste0(P7_MINUS, "1.3"))
  expect_equal(p7_app(1.25, ".plus", list(digits = "2")), "+1.25")
  expect_equal(p7_app(1.25, c(".plus", ".pct")), "+125%")
})

test_that("N1: .plus goes with text classes, unit classes and renderer keys", {
  expect_equal(p7_app(1.25, c(".num", ".plus", ".strong")), "**+1.3**")
  expect_equal(p7_app(1.25, c(".num", ".plus", ".em")), "*+1.3*")
  expect_equal(p7_app(1.25, c(".num", ".plus"), list(digits = "2")), "+1.25")
  expect_equal(p7_app(1.25, c(".num", ".plus"), list(sigfig = "2")), "+1.3")
  plain <- p7_app(u(5, "m"), c(".num", ".uname"))          # control
  expect_match(plain, "^5.met(re|er)s$")
  expect_equal(p7_app(u(5, "m"), c(".num", ".plus", ".uname")), sub("^5", "+5", plain))
})

# ---- N8: construct errors ---------------------------------------------------

test_that("E1: .plus with .sci, .p, .date, .no, .word, .count or .ord is a construct error", {
  for (cls in c(".sci", ".p", ".date", ".no", ".word", ".count", ".ord")) {
    val <- if (cls == ".date") as.Date("2024-06-03") else if (cls == ".p") 0.04 else 3
    e <- tryCatch(weft:::apply_formatters(val, c(cls, ".plus")), error = function(e) e)
    expect_s3_class(e, "weft_construct_error")
    expect_equal(conditionMessage(e), E1(cls), label = cls)
  }
})

test_that("E1: the scanner finds .plus with a conflicting class from the source", {
  for (cls in c(".sci", ".p", ".date", ".no", ".word", ".count", ".ord")) {
    errs <- p7_scan_errs(sprintf("A `r 3`{%s .plus} B.", cls))
    expect_true(any(errs == E1(cls)), label = paste(cls, "->", paste(errs, collapse = " / ")))
  }
  # controls: legal combinations scan clean
  expect_identical(p7_scan_errs("A `r 3`{.num .plus} B `r 0.1`{.pct .plus} C `r 3`{.plus} D."), character())
  expect_identical(p7_scan_errs("A `r c(1, 2)`{.range .plus} B `r c(1, 2)`{.and .plus} C `r 8`{.num .plus .a}."),
                   character())
})

test_that("E1: a project formatter of the number stage is a construct error", {
  p7_cfg(c("formatters:", "  .compact:", "    function: base::round", "    stage: number"))
  e <- tryCatch(weft:::apply_formatters(3, c(".compact", ".plus")), error = function(e) e)
  expect_s3_class(e, "weft_construct_error")
  expect_equal(conditionMessage(e), E1(".compact"))
  errs <- p7_scan_errs("A `r 3`{.compact .plus} B.")
  expect_true(any(errs == E1(".compact")), label = paste(errs, collapse = " / "))
})

test_that("E1: a project formatter of the text stage is allowed (control: it is not the number stage)", {
  p7_cfg(c("formatters:", "  .shout:", "    function: base::toupper", "    stage: text"))
  expect_equal(p7_app(1.25, c(".num", ".plus", ".shout")), "+1.3")
})

test_that("E2: .plus on a span with n, if, sign, list or cite is a construct error", {
  src <- c(n = "A [# site | # sites]{.plus n=\"k\"} B.",
           `if` = "A [yes | no]{.plus if=\"flag\"} B.",
           sign = "A [rose by # | fell by # | flat]{.pct .plus sign=\"up\"} B.",
           list = "A [none | # | both # | all #]{.plus list=\"v\"} B.",
           cite = "A [10 m]{.plus cite=\"@smith2020\"} B.")
  for (key in names(src)) {
    errs <- p7_scan_errs(src[[key]])
    expect_true(any(errs == E2(key)), label = paste(key, "->", paste(errs, collapse = " / ")))
  }
})

test_that("E2: a governor span without .plus gives no E2 text (control)", {
  errs <- p7_scan_errs("A [# site | # sites]{n=\"k\"} B [rose by # | fell by # | flat]{.pct sign=\"up\"} C.")
  expect_false(any(grepl("`.plus`", errs, fixed = TRUE)))
})

test_that("N8: .plus on the result of ci(), pm(), of_n() or about() is a value error", {
  for (x in list(ci(2.1, 1.3, 2.9), pm(2, 0.3), of_n(3, 7, "site", "sites"), about(0.52))) {
    expect_error(weft:::apply_formatters(x, c(".num", ".plus")), class = "weft_value_error")
    expect_error(weft:::apply_formatters(x, ".plus"), class = "weft_value_error")
  }
})

# ---- N9: the function forms -------------------------------------------------

test_that("N9: fmt_num(), fmt_pct() and fmt_range() take plus as their last argument, default FALSE", {
  for (f in list(fmt_num, fmt_pct, fmt_range)) {
    fm <- formals(f)
    expect_identical(names(fm)[length(fm)], "plus")
    expect_identical(fm$plus, FALSE)
  }
})

test_that("E3: plus must be TRUE or FALSE (weft_construct_error)", {
  for (bad in list("yes", NA, 1, c(TRUE, FALSE), NULL)) {
    for (f in list(fmt_num, fmt_pct, fmt_range)) {
      x <- if (identical(f, fmt_range)) c(1, 2) else 1
      e <- tryCatch(f(x, plus = bad), error = function(e) e)
      expect_s3_class(e, "weft_construct_error")
      expect_equal(conditionMessage(e), "`plus` must be TRUE or FALSE.")
    }
  }
})

# ---- N10: no setting --------------------------------------------------------

test_that("N10: a project cannot make .plus the default (control)", {
  suppressWarnings(p7_cfg("plus: true"))
  expect_equal(p7_txt(fmt_num(1.25)), "1.3")
  expect_equal(p7_txt(fmt_pct(0.12)), "12%")
})

# ---- N11: the record --------------------------------------------------------

test_that("N11: the record's number keeps its sign and is the same with and without plus", {
  for (v in c(1.25, -1.25, 1234.5, 12)) {
    a <- p7_rec(v, c(".num", ".plus"))
    b <- p7_rec(v, ".num")                                 # control
    expect_identical(a$number, b$number, label = paste("number", v))
    expect_identical(a$decimals, b$decimals)
    expect_identical(a$relation, b$relation)
  }
  expect_equal(p7_rec(1.25, c(".num", ".plus"))$text, "+1.3")
  expect_equal(p7_rec(1.25, c(".num", ".plus"))$number, 1.3)
  expect_equal(p7_rec(-1.25, c(".num", ".plus"))$number, -1.3)
  rc <- p7_rec(clamp(150, ceiling = 99), c(".num", ".plus"))
  expect_equal(rc$relation, ">")
  expect_equal(rc$number, 99)
  expect_equal(p7_rec(0.12, c(".pct", ".plus"))$number, p7_rec(0.12, ".pct")$number)
})

# ---- N14: a sample of the conformance rows ----------------------------------

test_that("N14: the values the new conformance rows must carry print as the design says", {
  m <- P7_MINUS
  num <- list(`1.25` = "+1.3", `-1.25` = paste0(m, "1.3"), `0` = "0", `-0` = "0",
              `1234.5` = "+1,234.5")
  for (nm in names(num)) {
    expect_equal(p7_app(as.numeric(nm), c(".num", ".plus")), num[[nm]], label = paste("num plus", nm))
  }
  expect_equal(p7_app(1e-10, c(".num", ".plus")), "0")
  expect_equal(p7_app(0.04, c(".num", ".plus")), "0.0")
  expect_equal(p7_app(-0.04, c(".num", ".plus")), "0.0")
  expect_equal(p7_app(0.999, c(".num", ".plus"), list(digits = "2")), "+1.00")
  expect_equal(p7_app(0.12, c(".pct", ".plus")), "+12%")
  expect_equal(p7_app(-0.12, c(".pct", ".plus")), paste0(m, "12%"))
  expect_equal(p7_app(0, c(".pct", ".plus")), "0%")
  expect_equal(p7_app(c(1.2, 3.4), c(".range", ".plus")), "+1.2 to +3.4")
  expect_equal(p7_app(c(-0.5, 1.2), c(".range", ".plus")), paste0(m, "0.5 to +1.2"))
  expect_equal(p7_app(c(0, 1.2), c(".range", ".plus")), "0.0 to +1.2")
  expect_equal(p7_app(c(1.2, 1.2), c(".range", ".plus")), "+1.2")
  expect_equal(p7_app(c(-3, -1), c(".range", ".plus")), paste0(m, "3 to ", m, "1"))
  expect_equal(p7_app(8, c(".num", ".plus", ".a")), "a +8")
})

# the rows of a conformance set, as the generator makes them (R/conformance.R)
p7_conf <- function(set) {
  d <- as.data.frame(weft:::conformance_rows(set), stringsAsFactors = FALSE)
  rownames(d) <- NULL
  d
}
p7_conf_text <- function(d, value, classes, keys = "") {
  hit <- d$value == value & d$classes == classes & d$keys == keys
  if (sum(hit) != 1L) return(sprintf("<%d rows for %s | %s | %s>", sum(hit), value, classes, keys))
  d$text[hit]
}

test_that("N14: numbers.tsv gains `num plus` and `pct plus` rows with the design's values", {
  d <- p7_conf("numbers")
  m <- P7_MINUS
  want <- c(`1.25` = "+1.3", `-1.25` = paste0(m, "1.3"), `0` = "0", `-0` = "0",
            `0.04` = "0.0", `-0.04` = "0.0", `1e-10` = "0", `1234.5` = "+1,234.5")
  for (v in names(want)) {
    expect_equal(p7_conf_text(d, v, "num plus"), want[[v]], label = paste("num plus", v))
  }
  expect_equal(p7_conf_text(d, "0.999", "num plus", "digits=2"), "+1.00")
  pct <- c(`0.12` = "+12%", `-0.12` = paste0(m, "12%"), `0` = "0%")
  for (v in names(pct)) {
    expect_equal(p7_conf_text(d, v, "pct plus"), pct[[v]], label = paste("pct plus", v))
  }
  expect_true(any(d$classes == "pct plus" & d$value == "0.04"))
  expect_true(any(d$classes == "pct plus" & d$value == "1234.5"))
})

test_that("N14: collapse.tsv gains `range plus` rows and text.tsv a `num plus a` row", {
  d <- p7_conf("collapse")
  m <- P7_MINUS
  expect_equal(p7_conf_text(d, "c(1.2, 3.4)", "range plus"), "+1.2 to +3.4")
  expect_equal(p7_conf_text(d, "c(-0.5, 1.2)", "range plus"), paste0(m, "0.5 to +1.2"))
  expect_equal(p7_conf_text(d, "c(0, 1.2)", "range plus"), "0.0 to +1.2")
  expect_equal(p7_conf_text(d, "c(1.2, 1.2)", "range plus"), "+1.2")
  expect_equal(p7_conf_text(d, "c(-3, -1)", "range plus"), paste0(m, "3 to ", m, "1"))
  tx <- p7_conf("text")
  hit <- tx$classes == "num plus a"
  expect_true(any(hit))
  expect_true(all(grepl("^an? ", tx$text[hit])))
  expect_equal(p7_conf_text(tx, "8", "num plus a"), "a +8")
})

test_that("control: every conformance row without plus is as committed (.plus touches no unsigned construct)", {
  for (set in c("numbers", "collapse", "text")) {
    live <- p7_conf(set)
    file <- utils::read.delim(test_path("_conformance", paste0(set, ".tsv")), header = TRUE,
                              sep = "\t", quote = "", comment.char = "", colClasses = "character",
                              na.strings = character(), check.names = FALSE,
                              encoding = "UTF-8", fileEncoding = "UTF-8")
    has_plus <- function(x) vapply(strsplit(x$classes, " ", fixed = TRUE), function(t) "plus" %in% t, NA)
    live <- live[!has_plus(live), , drop = FALSE]
    file <- file[!has_plus(file), , drop = FALSE]
    rownames(live) <- NULL
    rownames(file) <- NULL
    expect_gt(nrow(live), 0L)
    expect_identical(live, file, label = paste(set, "rows without plus"))
  }
})

# ---- knitting ---------------------------------------------------------------

test_that("F1 knit: .plus in a document prints N2 to N7", {
  res <- p7_knit(c(
    "A `r 1.25`{.num .plus} mg/L and `r 0.12`{.pct .plus}.",
    "",
    "B `r c(-0.5, 1.2)`{.range .plus} and `r c(1.2, 3.4)`{.range .plus}.",
    "",
    "C `r 8`{.num .plus .a} and `r 1.25`{.plus} and `r 0`{.plus} and `r -1.25`{.num .plus}.",
    "",
    "D `r c(1.2, -3.4, 5.6)`{.and .plus}."))
  m <- P7_MINUS
  expect_equal(res$text, c(
    "A +1.3 mg/L and +12%.",
    paste0("B ", m, "0.5 to +1.2 and +1.2 to +3.4."),
    paste0("C a +8 and +1.3 and 0 and ", m, "1.3."),
    paste0("D +1.2, ", m, "3.4 and +5.6.")))
})

test_that("F1 knit: the printed-as-zero check of N3 is recorded once", {
  res <- p7_knit(c("A `r 0.04`{.num .plus} B."))
  expect_equal(res$text, "A 0.0 B.")
  # the knit reports its warned checks in one message, not as a condition each
  expect_equal(sum(grepl("^weft: 1 warned check", d2_msgs(res$conds))), 1L)
})

test_that("E1 knit: .plus with .sci stops the render with E1's text", {
  res <- p7_knit(c("A `r 3`{.sci .plus} B."), may_fail = TRUE)
  expect_true(res$failed)
  expect_match(res$error$message, E1(".sci"), fixed = TRUE)
})

test_that("E2 knit: .plus on an n span stops the render with E2's text", {
  res <- p7_knit(c("```{r, include=FALSE}", "k <- 3", "```", "", "A [# site | # sites]{.plus n=\"k\"} B."), may_fail = TRUE)
  expect_true(res$failed)
  expect_match(res$error$message, E2("n"), fixed = TRUE)
})

test_that("N8 knit: .plus on a ci() result is a value error in the render", {
  res <- p7_knit(c("A `r ci(2.1, 1.3, 2.9)`{.num .plus} B."), may_fail = TRUE)
  expect_true(res$failed)
})

# ---- what would stop the package: .plus must not touch an unsigned construct ----

test_that("control: a document with no .plus knits byte-identical to before", {
  res <- p7_knit(c(
    "A `r 1.25`{.num}, `r -1.25`{.num}, `r 1234.5`{.num} and `r 0.12`{.pct}.",
    "",
    "B `r c(1.2, 3.4)`{.range}, `r c(-3, -1)`{.range} and `r c(1.2, 3.4, 5.6)`{.and}.",
    "",
    "C `r 8`{.num .a}, `r -8`{.num .a}, `r 0.046`{.p}, `r 3`{.word} and `r 2`{.ord}.",
    "",
    "D `r ci(2.1, 1.3, 2.9)` and `r pm(2, 0.3)` and `r clamp(150, ceiling = 99)`{.num}."))
  m <- P7_MINUS
  expect_equal(res$text, c(
    paste0("A 1.3, ", m, "1.3, 1,234.5 and 12%."),
    paste0("B 1.2\u20133.4, ", m, "3 to ", m, "1 and 1.2, 3.4 and 5.6."),
    paste0("C an 8, a ", m, "8, p = 0.046, three and 2nd."),
    "D 2.1 (95% CI 1.3 to 2.9) and 2 \u00b1 0.3 and > 99."))
})

test_that("control: unsigned constructs print the same through apply_formatters", {
  m <- P7_MINUS
  expect_equal(p7_app(1.25, ".num"), "1.3")
  expect_equal(p7_app(-1.25, ".num"), paste0(m, "1.3"))
  expect_equal(p7_app(0.12, ".pct"), "12%")
  expect_equal(p7_app(c(1.2, 3.4), ".range"), "1.2\u20133.4")
  expect_equal(p7_app(1234.5, ".num"), "1,234.5")
  expect_equal(p7_app(3, ".word"), "three")
  expect_equal(p7_app(2, ".ord"), "2nd")
  expect_equal(p7_app(3, ".sci"), p7_app(3, ".sci"))
  expect_equal(p7_app(0.046, ".p"), "p = 0.046")
  expect_equal(p7_app(8, c(".num", ".a")), "an 8")
  expect_equal(p7_app(0, ".num"), "0")
})
