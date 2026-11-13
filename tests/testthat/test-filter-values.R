# Package 6c: named values in the filter (dev/design-6.md N5 to N9, N13 (not here), N16, N17, N82 to N85).
# Each test writes one carrier block by hand and runs one document of many cases through plain Pandoc
# (helper-filter.R); an assertion per case names the case. Expected texts follow rules 1.4.13 and N85:
# digits 1 by default, "," for thousands from 1000, U+2212 for the minus. While inst/quarto/weft.lua does
# not exist every test fails on that.
#
# Left out because a later package changes them (6f): any class this filter does not implement yet other
# than .uname, .usym, .nounit and unit= (those stay E20 for good).

MINUS <- "\u2212"
CE <- "<<weft: construct error, line {L}>>"
VE <- "<<weft: value error, line {L}>>"
NV <- "<<weft: no value, line {L}>>"

values_block <- function() {
  carrier(
    f1 = fr_float("3.14159"), f2 = fr_float("2"), f3 = fr_float("2.5"), f4 = fr_float("0.15"),
    f5 = fr_float("-3.14159"), f6 = fr_float("1234567.891"), f7 = fr_float("0.256"),
    fv = fr_float("0.30000000000000004"), fe = fr_float("1e+23"), fneg = fr_float("-1.5"),
    i1 = fr_int("1234567"), i2 = fr_int("12345678901234567890123"), i3 = fr_int("-42"),
    i4 = fr_int("9007199254740993"), i5 = fr_int("1"), i6 = fr_int("12345678901234567890"),
    d1 = fr_dec("0.125"), d2 = fr_dec("2.50"), d3 = fr_dec("5.000"), d4 = fr_dec("1.5e3"),
    s1 = fr_str("north"), t1 = fr_date("2026-11-13"), b1 = fr_bool(TRUE), b0 = fr_bool(FALSE),
    l1 = fr_list_int(c("1", "2", "3")), l2 = fr_list_float(c("1.5", "2.5")), l3 = fr_list_str(c("a", "b")),
    m1 = fr_missing("no rows matched"), e1 = fr_error("{S} could not be computed")
  )
}

test_that("N85, 1.4.13: .num on float, int and decimal records, with digits and sigfig", {
  tbl <- list(
    f1 = c("`f1`{.num}", "3.1"), f2 = c("`f2`{.num}", "2"), f3 = c("`f3`{.num}", "2.5"),
    f4_half_away = c("`f4`{.num}", "0.2"), f5_minus = c("`f5`{.num}", paste0(MINUS, "3.1")),
    f6_thousands = c("`f6`{.num}", "1,234,567.9"),
    f1_digits3 = c("`f1`{.num digits=\"3\"}", "3.142"), f1_digits0 = c("`f1`{.num digits=\"0\"}", "3"),
    f1_sigfig1 = c("`f1`{.num sigfig=\"1\"}", "3"), f1_sigfig3 = c("`f1`{.num sigfig=\"3\"}", "3.14"),
    i1 = c("`i1`{.num}", "1,234,567"), i3_minus = c("`i3`{.num}", paste0(MINUS, "42")),
    i1_digits2 = c("`i1`{.num digits=\"2\"}", "1,234,567.00"),
    i2_big = c("`i2`{.num}", "12,345,678,901,234,567,890,123"),
    i2_sigfig3 = c("`i2`{.num sigfig=\"3\"}", "12,300,000,000,000,000,000,000"),
    i4_beyond_2_53 = c("`i4`{.num}", "9,007,199,254,740,993"),
    d1_default_digits = c("`d1`{.num}", "0.1"), d1_digits2 = c("`d1`{.num digits=\"2\"}", "0.13"),
    d1_digits3 = c("`d1`{.num digits=\"3\"}", "0.125"), d1_sigfig2 = c("`d1`{.num sigfig=\"2\"}", "0.13"),
    d2 = c("`d2`{.num}", "2.5"), d3_whole = c("`d3`{.num}", "5"), d4_exponent = c("`d4`{.num}", "1,500")
  )
  x <- tbl_cases(tbl)
  res <- filter_cases(x$cases, list(values_block()))
  expect_identical(res$status, 0L)
  expect_cases(res, x$expected)
})

test_that("N85, 1.4.13: .pct moves the decimal point two places, exactly for int and decimal", {
  tbl <- list(
    f7 = c("`f7`{.pct}", "25.6%"), f7_digits0 = c("`f7`{.pct digits=\"0\"}", "26%"),
    f1 = c("`f1`{.pct}", "314.2%"), i5 = c("`i5`{.pct}", "100%"), d1 = c("`d1`{.pct}", "12.5%"),
    i6_big = c("`i6`{.pct}", "1,234,567,890,123,456,789,000%")
  )
  x <- tbl_cases(tbl)
  res <- filter_cases(x$cases, list(values_block()))
  expect_identical(res$status, 0L)
  expect_cases(res, x$expected)
})

test_that("N8, 1.12.2: .val prints each record kind as itself, with no formatting", {
  tbl <- list(
    float = c("`f1`{.val}", "3.14159"), float_roundtrip = c("`fv`{.val}", "0.30000000000000004"),
    float_exponent = c("`fe`{.val}", "1e+23"), float_minus = c("`fneg`{.val}", "-1.5"),
    int_minus = c("`i3`{.val}", "-42"), int_big = c("`i2`{.val}", "12345678901234567890123"),
    decimal_as_written = c("`d2`{.val}", "2.50"), string = c("`s1`{.val}", "north"),
    date = c("`t1`{.val}", "2026-11-13"), bool_true = c("`b1`{.val}", "true"),
    bool_false = c("`b0`{.val}", "false"), list_int = c("`l1`{.val}", "1, 2, 3"),
    list_float = c("`l2`{.val}", "1.5, 2.5"), list_string = c("`l3`{.val}", "a, b")
  )
  x <- tbl_cases(tbl)
  res <- filter_cases(x$cases, list(values_block()))
  expect_identical(res$status, 0L)
  expect_cases(res, x$expected)
})

test_that("N5, 1.1.9: a code span with no weft class or key stays code, with a named value beside it", {
  md <- c(values_block(), "", paste0("Plain `f1`, class `f1`{.python}, id `f1`{#d}, named `f1`{.val}.",
          " Unregistered `f1`{.compact}."))
  res <- filter_md(md)
  expect_identical(res$status, 0L)
  expect_match(res$output, "<code>f1</code>", fixed = TRUE)
  expect_match(res$output, '<code class="python">f1</code>', fixed = TRUE)
  expect_match(res$output, '<code id="d">f1</code>', fixed = TRUE)
  expect_match(res$output, '<code class="compact">f1</code>', fixed = TRUE)
  expect_match(res$output, "named 3.14159.", fixed = TRUE)
  expect_false(grepl("weft", res$stderr, fixed = TRUE))
})

test_that("N5, N6: Pandoc's one-space trimming applies, so ` depth ` is the name depth", {
  res <- filter_cases(c(a = "A ` f1 `{.val} z."), list(values_block()), draft = TRUE)
  expect_cases(res, c(a = "A 3.14159 z."))
})

test_that("N6, N7, E1: a weft class on a code span whose text is not a name is a construct error", {
  long64 <- strrep("a", 64); long65 <- strrep("a", 65)
  texts <- c(arith = "x + 1", path = "cfg.depth[1]", brace = "{python} x", digit_first = "1x",
             trailing_dot = "x.", space_inside = "a b", non_ascii = "caf\u00e9", too_long = long65,
             r_TRUE = "TRUE", r_false = "false", r_None = "None", r_nothing = "nothing",
             r_missing = "missing", r_Inf = "Inf", r_NaN = "NaN", r_NA = "NA", r_NULL = "NULL")
  cases <- stats::setNames(sprintf("A `%s`{.num} z.", texts), names(texts))
  cases[["ok64"]] <- sprintf("A `%s`{.val} z.", long64)
  cases[["ok_underscore"]] <- "A `_x.y_1`{.val} z."
  blk <- carrier_raw(carrier_json(`_x.y_1` = fr_int("5")))
  blk64 <- carrier_raw(sprintf('{"weft":1,"values":{"%s":{"t":"int","v":"6"}}}', long64))
  res <- filter_cases(cases, list(blk, blk64), draft = TRUE)
  expect_identical(res$status, 0L)
  expected <- stats::setNames(rep(paste0("A ", CE, " z."), length(texts)), names(texts))
  expected[["ok64"]] <- "A 6 z."
  expected[["ok_underscore"]] <- "A 5 z."
  expect_cases(res, expected)
  for (nm in names(texts)) {
    expect_true(grepl(fm_msg$E1(texts[[nm]]), res$stderr, fixed = TRUE), label = paste("E1 for", nm))
  }
})

test_that("N17, E7, E8: digits and sigfig are whole numbers from 0 to 100, in R's texts", {
  tbl <- list(
    digits_neg = c("`f1`{.num digits=\"-1\"}", CE), sigfig_neg = c("`f1`{.num sigfig=\"-2\"}", CE),
    digits_frac = c("`f1`{.num digits=\"1.5\"}", CE), digits_text = c("`f1`{.num digits=\"abc\"}", CE),
    digits_101 = c("`f1`{.num digits=\"101\"}", CE), sigfig_101 = c("`f1`{.num sigfig=\"101\"}", CE),
    digits_1000 = c("`f1`{.num digits=\"1000\"}", CE), key_only = c("`f1`{digits=\"-1\"}", CE)
  )
  x <- tbl_cases(tbl)
  res <- filter_cases(x$cases, list(values_block()), draft = TRUE)
  expect_cases(res, x$expected)
  msgs <- c(fm_msg$E7("digits", "-1"), fm_msg$E7("sigfig", "-2"), fm_msg$E7("digits", "1.5"),
            fm_msg$E7("digits", "abc"), fm_msg$E8("digits", "101"), fm_msg$E8("sigfig", "101"),
            fm_msg$E8("digits", "1000"))
  for (m in msgs) expect_true(grepl(m, res$stderr, fixed = TRUE), label = m)
})

test_that("N17, 1.4.2, 1.4.7: two number-stage classes, or digits with sigfig, are a construct error", {
  tbl <- list(num_pct = c("`f1`{.num .pct}", CE), val_num = c("`f1`{.val .num}", CE),
              val_pct = c("`f1`{.val .pct}", CE), digits_sigfig = c("`f1`{.num digits=\"1\" sigfig=\"2\"}", CE))
  x <- tbl_cases(tbl)
  res <- filter_cases(x$cases, list(values_block()), draft = TRUE)
  expect_cases(res, x$expected)
})

test_that("N8, E2: a wording class with .val is a construct error that names the class", {
  tbl <- list(word = c("`i1`{.val .word}", CE), no = c("`i1`{.val .no}", CE),
              count = c("`i1`{.val .count}", CE), ord = c("`i1`{.val .ord}", CE))
  x <- tbl_cases(tbl)
  res <- filter_cases(x$cases, list(values_block()), draft = TRUE)
  expect_cases(res, x$expected)
  for (cl in c("word", "no", "count", "ord")) {
    expect_true(grepl(fm_msg$E2(cl), res$stderr, fixed = TRUE), label = paste("E2 for", cl))
  }
})

test_that("N17, E9: a governor key on a named value is a construct error naming the key", {
  keys <- c("n", "if", "sign", "list", "cite")
  tbl <- stats::setNames(lapply(keys, function(k) c(sprintf("`f1`{.num %s=\"k\"}", k), CE)), keys)
  x <- tbl_cases(tbl)
  res <- filter_cases(x$cases, list(values_block()), draft = TRUE)
  expect_cases(res, x$expected)
  for (k in keys) expect_true(grepl(fm_msg$E9(k), res$stderr, fixed = TRUE), label = paste("E9 for", k))
})

test_that("1.3.4, E11: a missing record is no value, with its why", {
  tbl <- list(num = c("`m1`{.num}", NV), val = c("`m1`{.val}", NV), pct = c("`m1`{.pct}", NV))
  x <- tbl_cases(tbl)
  res <- filter_cases(x$cases, list(values_block()), draft = TRUE)
  expect_cases(res, x$expected)
  expect_true(grepl(fm_msg$E11("m1", "no rows matched"), res$stderr, fixed = TRUE))
  e <- fm_entry(res$stderr, "^  doc\\.md:[0-9]+  \\[no value\\] `m1`\\{\\.num\\}$")
  expect_true(e$found)
  expect_identical(e$detail[[1]], fm_msg$E11("m1", "no rows matched"))
})

test_that("E16: an error record's why is the detail, with {S} replaced by the name", {
  res <- filter_cases(c(a = "A `e1`{.num} z."), list(values_block()), draft = TRUE)
  expect_match(res$got[["a"]], sprintf("^A <<weft: [a-z ]+, line %d>> z\\.$", res$line[["a"]]))
  expect_true(grepl("`e1` could not be computed", res$stderr, fixed = TRUE))
  expect_false(grepl("{S}", res$stderr, fixed = TRUE))
})

test_that("E31: a record that breaks the table is read as an error record", {
  blk <- carrier(bad1 = '{"t":"int","v":"abc"}', bad2 = '{"t":"float"}', bad3 = '{"t":"nonsense","v":"1"}')
  cases <- c(a = "A `bad1`{.val} z.", b = "A `bad2`{.val} z.", c = "A `bad3`{.val} z.")
  res <- filter_cases(cases, list(blk), draft = TRUE)
  for (nm in names(cases)) {
    expect_match(res$got[[nm]], sprintf("^A <<weft: [a-z ]+, line %d>> z\\.$", res$line[[nm]]), label = nm)
  }
  for (nm in c("bad1", "bad2", "bad3")) {
    expect_match(res$stderr, sprintf("the record of `%s` does not read: .+ \\(rule 2\\.13\\.1\\)\\.", nm), label = nm)
  }
})

test_that("N17, E17: a class that needs a number, on a record of another kind, is a value error", {
  tbl <- list(
    num_string = c("`s1`{.num}", VE), num_bool = c("`b1`{.num}", VE), num_list = c("`l1`{.num}", VE),
    pct_date = c("`t1`{.pct}", VE), pct_string = c("`s1`{.pct}", VE)
  )
  x <- tbl_cases(tbl)
  res <- filter_cases(x$cases, list(values_block()), draft = TRUE)
  expect_cases(res, x$expected)
  msgs <- c(fm_msg$E17("num", "number", "s1", "string"), fm_msg$E17("num", "number", "b1", "bool"),
            fm_msg$E17("num", "number", "l1", "list"), fm_msg$E17("pct", "number", "t1", "date"),
            fm_msg$E17("pct", "number", "s1", "string"))
  for (m in msgs) expect_true(grepl(m, res$stderr, fixed = TRUE), label = m)
})

test_that("N83, E20: unit classes and unit= are a value error in place of the construct, never a pass-through", {
  tbl <- list(
    uname = c("`f1`{.num .uname}", VE), usym = c("`f1`{.num .usym}", VE), nounit = c("`f1`{.num .nounit}", VE),
    unit_key = c("`f1`{.num unit=\"m\"}", VE)
  )
  x <- tbl_cases(tbl)
  res <- filter_cases(x$cases, list(values_block()), draft = TRUE)
  expect_cases(res, x$expected)
  expect_true(grepl(fm_msg$E20_class("uname"), res$stderr, fixed = TRUE))
  expect_true(grepl(fm_msg$E20_class("usym"), res$stderr, fixed = TRUE))
  expect_true(grepl(fm_msg$E20_class("nounit"), res$stderr, fixed = TRUE))
  expect_true(grepl(fm_msg$E20_key("unit"), res$stderr, fixed = TRUE))
})

test_that("N84, N83, E21: a project formatter named in _weft.yml is a value error on a named value", {
  yml <- c("formatters:", "  .compact:", "    function: myproject::fmt_compact", "    stage: number")
  res <- filter_cases(c(a = "A `f1`{.compact} z."), list(values_block()), draft = TRUE, weft_yml = yml)
  expect_cases(res, c(a = paste0("A ", VE, " z.")))
  expect_true(grepl(fm_msg$E21("compact"), res$stderr, fixed = TRUE))
})

test_that("N16: the why of a .weft-literal span and div is removed and the class stays", {
  md <- c("A [text]{.weft-literal why=\"quoted on purpose\"} here.", "",
          "::: {.weft-literal why=\"a block\"}", "Block text.", ":::")
  res <- filter_md(md)
  expect_identical(res$status, 0L)
  expect_match(res$output, '<span class="weft-literal">text</span>', fixed = TRUE)
  expect_match(res$output, '<div class="weft-literal">', fixed = TRUE)
  expect_false(grepl("why", res$output, fixed = TRUE))
  expect_false(grepl("quoted on purpose|a block", res$output))
})

test_that("1.2.6: other classes go on a span around the output; with none the output is plain text", {
  md <- c(values_block(), "",
          "A `f1`{.num .smallcaps} z.", "", "B `f1`{.num .foo .bar} z.", "", "C `f1`{.num} z.")
  res <- filter_md(md)
  expect_identical(res$status, 0L)
  expect_match(res$output, '<p>A <span class="smallcaps">3.1</span> z.</p>', fixed = TRUE)
  expect_match(res$output, '<p>B <span class="foo bar">3.1</span> z.</p>', fixed = TRUE)
  expect_match(res$output, "<p>C 3.1 z.</p>", fixed = TRUE)
})

test_that("2.6.11, 1.4.13: a nonzero number that prints as zero is a warned check, which fails nothing", {
  blk <- carrier(z = fr_float("0.04"), zneg = fr_float("-0.04"), tiny = fr_float("1e-10"), tiny2 = fr_float("1e-12"),
                 zero = fr_float("0"), pz = fr_float("0.04"))
  # warned: default digits, no digits or sigfig given
  res <- filter_md(c(blk, "", "A `z`{.num} z."), to = "plain")
  expect_identical(res$status, 0L)
  expect_identical(trimws(res$output), "A 0.0 z.")
  expect_match(fm_headings(res$stderr), rx_warned(1), all = FALSE)
  expect_true(grepl("0.04 printed as 0.0: add sigfig to show it, or digits to confirm it", res$stderr, fixed = TRUE))
  e <- fm_entry(res$stderr, "^  doc\\.md:[0-9]+  \\[printed as zero\\] `z`\\{\\.num\\}$")
  expect_true(e$found)
  # a project default digits does not count as given
  res2 <- filter_md(c(blk, "", "A `z`{.num} z."), to = "plain", weft_yml = "digits: 1")
  expect_identical(res2$status, 0L)
  expect_match(fm_headings(res2$stderr), rx_warned(1), all = FALSE)
  # silenced by digits or sigfig on the construct; .val, an exact zero and a number below 1e-9 never warn
  tbl <- list(digits = c("`z`{.num digits=\"1\"}", "0.0"), sigfig = c("`z`{.num sigfig=\"1\"}", "0.04"),
              val = c("`z`{.val}", "0.04"), neg_no_minus = c("`zneg`{.num digits=\"1\"}", "0.0"),
              tiny = c("`tiny`{.num}", "0"), tiny_pct = c("`tiny2`{.pct}", "0%"), zero = c("`zero`{.num}", "0"))
  x <- tbl_cases(tbl)
  res3 <- filter_cases(x$cases, list(blk))
  expect_identical(res3$status, 0L)
  expect_cases(res3, x$expected)
  expect_false(grepl("weft", res3$stderr, fixed = TRUE))
})

test_that("N4: the cases give the same text on every Pandoc found (3.1 or later)", {
  skip_if_no_lua_pandoc()
  tbl <- list(f1 = c("`f1`{.num}", "3.1"), i4 = c("`i4`{.num}", "9,007,199,254,740,993"),
              d1 = c("`d1`{.num digits=\"2\"}", "0.13"), val = c("`fv`{.val}", "0.30000000000000004"),
              minus = c("`f5`{.num}", paste0(MINUS, "3.1")))
  x <- tbl_cases(tbl)
  for (p in lua_pandocs()) {
    expect_true(lua_version_ok(p), label = paste("Pandoc", p$version, "is 3.1 or later"))
    res <- filter_cases(x$cases, list(values_block()), pandoc = p)
    expect_identical(res$status, 0L, label = paste("status on Pandoc", p$version))
    expect_cases(res, x$expected)
  }
})
