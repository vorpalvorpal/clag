# Package P4 of design 9 (dev/design-9.md, "formatters that write TeX inside math"): the conformance set
# tex.tsv. Decision D80: a NEW set, `tex.tsv`, with the pseudo-key `target=tex` in the keys column; the four
# tab line format and the five columns of the existing sets stay as they are (test-conformance-6f.R pins them).
# Rule 1.4.22 of the design is read as 1.4.23. This file is the R side; the Lua side is test-lua-tex.R.
#
# WHAT THESE TESTS ASSUME OF THE IMPLEMENTATION (the design names these without a signature)
#   weft:::conformance_rows("tex")      the rows of the new set, five character columns as the others.
#   weft:::conformance_write(dir, sets = weft:::CONF_TEX_SETS)   writes dir/tex.tsv in the existing format.
#   weft:::CONF_TEX_SETS                a character vector holding "tex"; apart from CONF_NEW_SETS.
#   weft:::conf_parse_keys(keys)        returns, besides `opts`, `cfg` and `span`, a member `target`: "tex" for
#                                       the token `target=tex`; NULL or "markdown" when there is no such token.
#                                       The `target` token is never in `opts` or `cfg`.
#   weft:::conf_row_text(value, classes, keys)   with `target=tex` in the keys, prints what
#                                       apply_formatters(..., target = "tex") prints.
#   Every row of tex.tsv has the token `target=tex` in its keys (tokens in any order).
#
# THE TABLE CANNOT BE RIGHT MERELY BY AGREEING WITH ITSELF: CT_SAMPLES below are hand-written expectations
# from the forms of TX4 to TX7 and the tests of P1 (test-tex-target.R). They are checked against the live R
# generator, and, for the samples whose values the existing corpora already hold, against the committed table.
#
# READING: the design lists the rows of tex.tsv by category only (digits 0-3 and sigfig 1-3 for num and pct, the
# mark configurations, the sci corpus, the p corpus with p_label variants, ranges with plus, and plus). It names
# no values. So the table is checked by KEY coverage: the categories above must be present, and a corpus sample
# must match where the table has the row; at least half of the corpus samples must be present.
# Non-ASCII is written as \u escapes. ASCII only.

CT_COLS <- c("value", "classes", "keys", "text", "record")
ct_path <- function() test_path("_conformance", "tex.tsv")

ct_read <- function() {
  p <- ct_path()
  if (!file.exists(p)) return(NULL)
  utils::read.delim(p, header = TRUE, sep = "\t", quote = "", comment.char = "", colClasses = "character",
                    na.strings = character(), check.names = FALSE, stringsAsFactors = FALSE,
                    encoding = "UTF-8", fileEncoding = "UTF-8", blank.lines.skip = FALSE)
}

# the table, or a failed expectation that the file exists (so each test fails clearly while it is missing)
ct_table <- function() {
  d <- ct_read()
  expect_true(file.exists(ct_path()), label = "tests/testthat/_conformance/tex.tsv exists")
  d
}

ct_toks <- function(x) if (!nzchar(x)) character() else strsplit(x, " ", fixed = TRUE)[[1]]

# rows of d whose value, class tokens and key tokens are these (key tokens: exactly `target=tex` plus extra)
ct_find <- function(d, value, classes, extra = character()) {
  want_k <- sort(c("target=tex", extra))
  want_c <- sort(ct_toks(classes))
  hit <- vapply(seq_len(nrow(d)), function(i) {
    d$value[i] == value && identical(sort(ct_toks(d$classes[i])), want_c) &&
      identical(sort(ct_toks(d$keys[i])), want_k)
  }, logical(1))
  d[hit, , drop = FALSE]
}

# rows whose key tokens include all of `tokens`
ct_with <- function(d, tokens, classes = NULL) {
  hit <- vapply(seq_len(nrow(d)), function(i) {
    all(tokens %in% ct_toks(d$keys[i])) &&
      (is.null(classes) || identical(sort(ct_toks(d$classes[i])), sort(classes)))
  }, logical(1))
  d[hit, , drop = FALSE]
}

# ---- hand-written expectations --------------------------------------------------------------------------------
# value (base R source), classes, extra keys (the `target=tex` token is added), the TeX text, and whether the
# value is one the existing corpora hold (so the committed table is expected to hold the row).
S <- function(value, classes, keys, tex, corpus = FALSE) {
  data.frame(value = value, classes = classes, keys = keys, tex = tex, corpus = corpus,
             stringsAsFactors = FALSE)
}
CT_SAMPLES <- rbind(
  # num: TX5 and the default marks
  S("-1234567.89", "num", "", r"(-1{,}234{,}567.9)"),
  S("999.95", "num", "", r"(1{,}000.0)"),
  S("3", "num", "", "3"),
  S("1234567.891", "num", "", r"(1{,}234{,}567.9)", TRUE),
  S("-1234567.891", "num", "", r"(-1{,}234{,}567.9)", TRUE),
  S("0.5", "num", "", "0.5", TRUE),
  S("-2.5", "num", "", "-2.5", TRUE),
  S("0", "num", "", "0", TRUE),
  S("1000", "num", "", r"(1{,}000)", TRUE),
  S("999", "num", "", "999", TRUE),
  S("0.995", "num", "", "1.0", TRUE),
  S("pi", "num", "digits=2", "3.14", TRUE),
  S("0.5", "num", "digits=2", "0.50", TRUE),
  S("1234.5678", "num", "sigfig=2", r"(1{,}200)", TRUE),
  # pct: `\%`
  S("0.123", "pct", "", r"(12.3\%)"),
  S("0.15", "pct", "", r"(15\%)", TRUE),
  S("-3.456", "pct", "", r"(-345.6\%)", TRUE),
  S("1234.5", "pct", "", r"(123{,}450\%)", TRUE),
  S("1/3", "pct", "", r"(33.3\%)", TRUE),
  S("1e-6", "pct", "", r"(0.0\%)", TRUE),
  # plus
  S("1.25", "num plus", "", "+1.3", TRUE),
  S("-1.25", "num plus", "", "-1.3", TRUE),
  S("0", "num plus", "", "0", TRUE),
  S("0.05", "pct plus", "", r"(+5\%)"),
  S("0.12", "pct plus", "", r"(+12\%)", TRUE),
  # sci
  S("1234567", "sci", "", r"(1.2 \times 10^{6})"),
  S("-0.000123", "sci", "", r"(-1.2 \times 10^{-4})"),
  S("12345", "sci", "", r"(1.2 \times 10^{4})", TRUE),
  S("0.000123456", "sci", "", r"(1.2 \times 10^{-4})", TRUE),
  S("1", "sci", "", r"(1 \times 10^{0})", TRUE),
  S("0", "sci", "", "0", TRUE),
  S("-2500", "sci", "", r"(-2.5 \times 10^{3})", TRUE),
  S("9.96", "sci", "", r"(1 \times 10^{1})", TRUE),
  S("12345", "sci", "digits=2", r"(1.23 \times 10^{4})", TRUE),
  S("-2500", "sci", "digits=2", r"(-2.50 \times 10^{3})", TRUE),
  # p
  S("0.0001", "p", "", "p < 0.001"),
  S("0.03", "p", "", "p = 0.030"),
  S("0.0004", "p", "", "p < 0.001", TRUE),
  S("0.046", "p", "", "p = 0.046", TRUE),
  S("0.5", "p", "", "p = 0.50", TRUE),
  S("0.995", "p", "", "p > 0.99", TRUE),
  S("0.046", "p", "label=q", "q = 0.046", TRUE),
  S("0.046", "p", "label=", "0.046", TRUE),
  S("0.995", "p", "label=", "> 0.99", TRUE),
  S("0.5", "p", "label=", "0.50"),
  S("0.046", "p", r"(label=\tilde{p})", r"(\tilde{p} = 0.046)"),
  # p_label setting under TeX (D72)
  S("0.046", "p", "cfg.p_label=*p*", "p = 0.046"),
  S("0.046", "p", "cfg.p_label=adj.%20p", r"(\text{adj. p} = 0.046)"),
  S("0.046", "p", "cfg.p_label=p_adj", r"(\text{p}\_\text{adj} = 0.046)"),
  S("0.046", "p", "cfg.p_label=", "0.046"),
  S("0.0004", "p", "cfg.p_label=q", "q < 0.001", TRUE),
  # ranges: always "to"
  S("c(1.23, 3.45)", "range", "", r"(1.2\ \text{to}\ 3.5)"),
  S("c(-1, 3)", "range", "", r"(-1\ \text{to}\ 3)"),
  S("c(2, 2)", "range", "", "2"),
  S("c(1, 3)", "range plus", "", r"(+1\ \text{to}\ +3)"),
  S("c(3, 5)", "range", "", r"(3\ \text{to}\ 5)", TRUE),
  S("c(5, 5)", "range", "", "5", TRUE),
  S("c(-1, 2)", "range", "", r"(-1\ \text{to}\ 2)", TRUE),
  S("c(1.25, 3.5)", "range", "", r"(1.3\ \text{to}\ 3.5)", TRUE),
  S("c(1.25, 3.5)", "range", "digits=2", r"(1.25\ \text{to}\ 3.50)", TRUE),
  S("c(1.2, 3.4)", "range plus", "", r"(+1.2\ \text{to}\ +3.4)", TRUE),
  S("c(-0.5, 1.2)", "range plus", "", r"(-0.5\ \text{to}\ +1.2)", TRUE),
  S("c(-3, -1)", "range plus", "", r"(-3\ \text{to}\ -1)", TRUE),
  # a vector under a number class prints element by element
  S("c(1.5, 2)", "num", "", "1.5, 2"),
  # the mark configurations (TX4, "with other configurations")
  S("1234567.89", "num", "cfg.decimal_mark=, cfg.big_mark=.", r"(1.234.567{,}9)"),
  S("1234567.89", "num", "cfg.big_mark=%20", r"(1\,234\,567.9)"),
  S("1234567.89", "num", "cfg.big_mark=\u00a0", r"(1\,234\,567.9)"),
  S("1234567.89", "num", "cfg.big_mark=\u2009", r"(1\,234\,567.9)"),
  S("1234567.89", "num", "cfg.big_mark='", r"(1\text{'}234\text{'}567.9)"),
  S("1234567.89", "num", "cfg.big_mark=\u2019", r"(1\text{'}234\text{'}567.9)"),
  S("1234567.89", "num", "cfg.big_mark=\u00b7", r"(1{\cdot}234{\cdot}567.9)"),
  S("1234567.89", "num", "cfg.big_mark=", "1234567.9"),
  S("1234567.89", "num", "cfg.decimal_mark=,", r"(1{,}234{,}567\text{,}9)"),
  S("0.5", "num", "cfg.decimal_mark=, cfg.big_mark=.", r"(0{,}5)"),
  S("-1234567.89", "num", "cfg.minus=-", r"(-1{,}234{,}567.9)"),
  S("-1234567.89", "num", "cfg.minus=\u2212", r"(-1{,}234{,}567.9)"),
  S("-1234567.89", "num", "cfg.minus=--", r"(-1{,}234{,}567.9)"),
  S("0.0001", "p", "cfg.decimal_mark=, cfg.big_mark=.", r"(p < 0{,}001)"),
  S("0.123", "pct", "cfg.decimal_mark=, cfg.big_mark=.", r"(12{,}3\%)")
)

ct_keys <- function(extra) paste(c("target=tex", if (nzchar(extra)) extra), collapse = " ")

# ---- the generator and the file ---------------------------------------------------------------------------------

test_that("D80, P4: conformance_rows('tex') makes the five columns, deterministically", {
  expect_true(exists("conformance_rows", envir = asNamespace("weft"), inherits = FALSE))
  d <- weft:::conformance_rows("tex")
  expect_identical(names(d), CT_COLS)
  expect_true(all(vapply(d, is.character, logical(1))))
  expect_false(anyNA(d))
  expect_gt(nrow(d), 0L)
  expect_identical(d, weft:::conformance_rows("tex"))
})

test_that("D80, P4: conformance_rows('tex') leaves the project configuration as it found it", {
  old <- weft:::weft_env$config
  invisible(weft:::conformance_rows("tex"))
  expect_identical(weft:::weft_env$config, old)
})

test_that("D80, P4: tex.tsv is committed in the fixed format of the other sets", {
  p <- ct_path()
  expect_true(file.exists(p), label = "tex.tsv exists")
  if (!file.exists(p)) return(invisible())
  raw <- readBin(p, "raw", file.size(p))
  expect_false(identical(raw[1:3], as.raw(c(0xef, 0xbb, 0xbf))), label = "no BOM")
  expect_false(as.raw(13) %in% raw, label = "LF line ends only")
  expect_identical(raw[length(raw)], as.raw(10), label = "final newline")
  txt <- rawToChar(raw)
  Encoding(txt) <- "UTF-8"
  expect_true(validUTF8(txt))
  lines <- strsplit(txt, "\n", fixed = TRUE)[[1]]
  expect_identical(lines[1], paste(CT_COLS, collapse = "\t"))
  expect_true(all(lengths(regmatches(lines, gregexpr("\t", lines, fixed = TRUE))) == 4L),
              label = "four tabs on every line")
})

test_that("D80, P4: every row weft computes equals the committed row, and no row repeats", {
  file <- ct_table()
  if (is.null(file)) return(invisible())
  live <- as.data.frame(weft:::conformance_rows("tex"), stringsAsFactors = FALSE)
  rownames(live) <- NULL
  expect(identical(live, file),
         paste0("tex: ", nrow(live), " live rows, ", nrow(file),
                " committed; the file is stale: regenerate with conformance_write(dir, sets = CONF_TEX_SETS)"))
  key <- paste(file$value, file$classes, file$keys, sep = "\r")
  expect_false(anyDuplicated(key) > 0, label = "no duplicate row")
})

test_that("D80, P4: conformance_write(sets = CONF_TEX_SETS) writes tex.tsv, byte for byte what is committed", {
  expect_true(exists("CONF_TEX_SETS", envir = asNamespace("weft"), inherits = FALSE))
  expect_true("tex" %in% weft:::CONF_TEX_SETS)
  out <- file.path(withr::local_tempdir(), "tex")
  weft:::conformance_write(out, sets = weft:::CONF_TEX_SETS)
  expect_setequal(list.files(out), paste0(weft:::CONF_TEX_SETS, ".tsv"))
  p <- ct_path()
  expect_true(file.exists(p), label = "tex.tsv exists")
  if (!file.exists(p)) return(invisible())
  expect_identical(readBin(file.path(out, "tex.tsv"), "raw", 1e8), readBin(p, "raw", 1e8))
})

test_that("D80: every row has the pseudo-key target=tex, in the keys column", {
  d <- ct_table()
  if (is.null(d)) return(invisible())
  expect_gt(nrow(d), 0L)
  has <- vapply(d$keys, function(k) "target=tex" %in% ct_toks(k), logical(1))
  expect_true(all(has), label = "target=tex on every row")
})

test_that("D67, D68, D69: no row prints markdown (no U+2212, no times sign, no en dash, no bare caret)", {
  d <- ct_table()
  if (is.null(d)) return(invisible())
  for (col in "text") {
    x <- d[[col]]
    expect_false(any(grepl("\u2212", x, fixed = TRUE)), label = "no U+2212")
    expect_false(any(grepl("\u00d7", x, fixed = TRUE)), label = "no times sign")
    expect_false(any(grepl("\u2013", x, fixed = TRUE)), label = "no en dash")
    expect_false(any(grepl("\\^(?!\\{)", x, perl = TRUE)), label = "every exponent is braced")
    expect_false(any(grepl("<<weft", x, fixed = TRUE)), label = "no marker in the corpus")
  }
})

test_that("D80: every value is base R on one line, and every record is the record maker's", {
  d <- ct_table()
  if (is.null(d)) return(invisible())
  expect_false(any(grepl("[\t\n\r]", unlist(d))))
  for (i in seq_len(nrow(d))) {
    x <- eval(parse(text = d$value[i]), envir = baseenv())
    expect_identical(weft:::values_record(x)$json, d$record[i], info = d$value[i])
  }
})

# ---- the keys column: `target=` -----------------------------------------------------------------------------

test_that("D80: conf_parse_keys() understands the token target=tex, in any position, apart from opts and cfg", {
  k <- weft:::conf_parse_keys("target=tex digits=2 cfg.big_mark=%20")
  expect_identical(k$target, "tex")
  expect_identical(k$opts, list(digits = 2L))
  expect_identical(k$cfg, list(big_mark = " "))
  expect_null(k$span)
  k2 <- weft:::conf_parse_keys("digits=2 cfg.big_mark=%20 target=tex")
  expect_identical(k2$target, "tex")
  expect_identical(k2$opts, k$opts)
  expect_identical(k2$cfg, k$cfg)
  k3 <- weft:::conf_parse_keys("target=tex")
  expect_identical(k3$target, "tex")
  expect_identical(length(k3$opts), 0L)
  expect_identical(length(k3$cfg), 0L)
})

test_that("D80: without the token, conf_parse_keys() reads a key as it does today", {
  k <- weft:::conf_parse_keys("cfg.p_label=q digits=3 label=x span=[a%20|%20b]")
  expect_identical(k$opts, list(digits = 3L, label = "x"))
  expect_identical(k$cfg, list(p_label = "q"))
  expect_identical(k$span, "[a | b]")
  expect_true(is.null(k$target) || identical(k$target, "markdown"))
  e <- weft:::conf_parse_keys("")
  expect_identical(length(e$opts), 0L)
  expect_identical(length(e$cfg), 0L)
  expect_true(is.null(e$target) || identical(e$target, "markdown"))
})

test_that("D66, D80: target=markdown prints as no target prints; target=tex prints TeX", {
  expect_identical(weft:::conf_row_text("1234.5", "num", "target=markdown"),
                   weft:::conf_row_text("1234.5", "num", ""))
  expect_identical(weft:::conf_row_text("1234.5", "num", ""), "1,234.5")
  expect_identical(weft:::conf_row_text("-1234.5", "num", "target=tex"), r"(-1{,}234.5)")
  expect_identical(weft:::conf_row_text("-1234.5", "num", "digits=2 target=tex"),
                   weft:::conf_row_text("-1234.5", "num", "target=tex digits=2"))
})

test_that("D66, E100: a target other than markdown and tex in a key is an error", {
  expect_error(weft:::conf_row_text("1", "num", "target=latex"))
})

# ---- independent expectations -------------------------------------------------------------------------------------

test_that("TX4 to TX7: the live generator prints the hand-written TeX for every sample", {
  expect_gte(nrow(CT_SAMPLES), 25L)
  for (i in seq_len(nrow(CT_SAMPLES))) {
    s <- CT_SAMPLES[i, ]
    got <- suppressWarnings(weft:::conf_row_text(s$value, s$classes, ct_keys(s$keys)))
    expect_identical(got, s$tex, info = paste(s$value, "|", s$classes, "|", s$keys))
  }
})

test_that("TX4 to TX7: the classes of the samples cover num, pct, sci, p, range, plus, negative, zero, thousands, marks", {
  cl <- unique(unlist(strsplit(CT_SAMPLES$classes, " ")))
  expect_true(all(c("num", "pct", "sci", "p", "range", "plus") %in% cl))
  expect_true(any(grepl("^-", CT_SAMPLES$value)))
  expect_true(any(CT_SAMPLES$value == "0"))
  expect_true(any(grepl("big_mark", CT_SAMPLES$keys)))
  expect_true(any(grepl("decimal_mark", CT_SAMPLES$keys)))
})

test_that("TX4 to TX7: the committed table agrees with the hand-written expectations where it has the row", {
  d <- ct_table()
  if (is.null(d)) return(invisible())
  cs <- CT_SAMPLES[CT_SAMPLES$corpus, ]
  present <- 0L
  for (i in seq_len(nrow(cs))) {
    r <- ct_find(d, cs$value[i], cs$classes[i], ct_toks(cs$keys[i]))
    if (nrow(r) == 0L) next
    present <- present + 1L
    expect_identical(r$text, cs$tex[i], info = paste(cs$value[i], "|", cs$classes[i], "|", cs$keys[i]))
  }
  # READING: a corpus sample may be absent, but not most of them
  expect_gte(present, ceiling(nrow(cs) / 2))
})

# ---- row coverage, by key -----------------------------------------------------------------------------------------

test_that("P4: num and pct have rows with digits 0 to 3 and with sigfig 1 to 3", {
  d <- ct_table()
  if (is.null(d)) return(invisible())
  for (cl in c("num", "pct")) {
    for (k in 0:3) {
      r <- ct_with(d, c("target=tex", paste0("digits=", k)), cl)
      expect_gt(nrow(r), 0L, label = paste(cl, "digits", k))
    }
    for (k in 1:3) {
      r <- ct_with(d, c("target=tex", paste0("sigfig=", k)), cl)
      expect_gt(nrow(r), 0L, label = paste(cl, "sigfig", k))
    }
  }
})

test_that("P4: the mark configurations (cfg.big_mark, cfg.decimal_mark, cfg.minus=-) have rows", {
  d <- ct_table()
  if (is.null(d)) return(invisible())
  for (tok in list(c("cfg.big_mark=%20"), c("cfg.big_mark='"), c("cfg.big_mark="),
                   c("cfg.big_mark=.", "cfg.decimal_mark=,"), c("cfg.decimal_mark=,"),
                   c("cfg.minus=-"))) {
    r <- ct_with(d, c("target=tex", tok))
    expect_gt(nrow(r), 0L, label = paste(tok, collapse = " "))
  }
  expect_gt(nrow(ct_with(d, c("target=tex", "cfg.decimal_mark=,"), "p")), 0L, label = "p under a decimal comma")
})

test_that("P4: the sci corpus (default, digits, sigfig, zero, one, a rounding carry) has rows", {
  d <- ct_table()
  if (is.null(d)) return(invisible())
  s <- d[d$classes == "sci", , drop = FALSE]
  expect_gte(nrow(s), 20L)
  for (v in c("0", "1", "9.96", "12345")) {
    expect_gt(nrow(ct_find(d, v, "sci")), 0L, label = paste("sci", v))
  }
  expect_gt(nrow(ct_with(d, c("target=tex", "digits=2"), "sci")), 0L)
  expect_gt(nrow(ct_with(d, c("target=tex", "sigfig=2"), "sci")), 0L)
  expect_true(any(grepl("^-", s$value)), label = "a negative sci value")
  expect_true(any(grepl("e-|\\.0000", s$value)), label = "a small sci value")
})

test_that("P4: the p corpus has rows, with the p_label settings *p* and adj.%20p and the label key", {
  d <- ct_table()
  if (is.null(d)) return(invisible())
  p <- d[d$classes == "p", , drop = FALSE]
  expect_gte(nrow(p), 20L)
  for (v in c("0", "0.0004", "0.046", "0.5", "0.995")) {
    expect_gt(nrow(ct_find(d, v, "p")), 0L, label = paste("p", v))
  }
  expect_gt(nrow(ct_with(d, c("target=tex", "cfg.p_label=*p*"), "p")), 0L)
  expect_gt(nrow(ct_with(d, c("target=tex", "cfg.p_label=adj.%20p"), "p")), 0L)
  expect_gt(nrow(ct_with(d, c("target=tex", "label="), "p")), 0L)
})

test_that("TX5, TX6: every p row under a p_label setting prints that label in TeX", {
  d <- ct_table()
  if (is.null(d)) return(invisible())
  star <- ct_with(d, c("target=tex", "cfg.p_label=*p*"), "p")
  for (i in seq_len(nrow(star))) {
    # a label key on the same row would win; none is expected, but test only what has none
    if (any(startsWith(ct_toks(star$keys[i]), "label="))) next
    expect_match(star$text[i], "^p [<=>] [0-9]", info = star$text[i])
  }
  adj <- ct_with(d, c("target=tex", "cfg.p_label=adj.%20p"), "p")
  for (i in seq_len(nrow(adj))) {
    if (any(startsWith(ct_toks(adj$keys[i]), "label="))) next
    expect_match(adj$text[i], r"(^\\text\{adj\. p\} [<=>] [0-9])", info = adj$text[i])
  }
})

test_that("P4: ranges, ranges with plus, num with plus and pct with plus have rows", {
  d <- ct_table()
  if (is.null(d)) return(invisible())
  expect_gte(nrow(d[d$classes == "range", ]), 5L)
  expect_gte(nrow(d[d$classes == "range plus" | d$classes == "plus range", ]), 5L)
  expect_gt(nrow(d[d$classes %in% c("num plus", "plus num"), ]), 0L)
  expect_gt(nrow(d[d$classes %in% c("pct plus", "plus pct"), ]), 0L)
  rg <- d[d$classes == "range", ]
  expect_true(all(grepl(r"(\\ \\text\{to\}\\ )", rg$text) |
                    (!grepl("[[:space:]]", rg$text) & !grepl("\\text", rg$text, fixed = TRUE))),
              label = "a range says to, or is one number")
})

test_that("TX5: every text under .pct or .pct .plus ends in \\%", {
  d <- ct_table()
  if (is.null(d)) return(invisible())
  pc <- d[d$classes %in% c("pct", "pct plus", "plus pct"), ]
  expect_gt(nrow(pc), 0L)
  expect_true(all(grepl(r"(\\%$)", pc$text)))
})

# ---- the existing sets are untouched -----------------------------------------------------------------------------

test_that("D80: the TeX set is kept apart from the existing sets", {
  expect_identical(weft:::CONF_NEW_SETS, c("dates", "sci", "p", "collapse", "text", "governors"))
  expect_true(exists("CONF_TEX_SETS", envir = asNamespace("weft"), inherits = FALSE))
  expect_false(any(weft:::CONF_TEX_SETS %in% weft:::CONF_NEW_SETS))
  expect_false(any(weft:::CONF_TEX_SETS %in% c("numbers", "words", "lists")))
})

test_that("D80: the default set is still the three sets of 5h, stacked, and none of its rows names a target", {
  a <- weft:::conformance_rows()
  stacked <- rbind(weft:::conformance_rows("numbers"), weft:::conformance_rows("words"),
                   weft:::conformance_rows("lists"))
  rownames(stacked) <- NULL
  expect_identical(a, stacked)
  expect_false(any(grepl("target=", a$keys, fixed = TRUE)))
})

test_that("D80: the default conformance_write() still writes the three first sets", {
  dflt <- file.path(withr::local_tempdir(), "dflt")
  weft:::conformance_write(dflt)
  expect_setequal(list.files(dflt), c("numbers.tsv", "words.tsv", "lists.tsv"))
})

test_that("D80: the nine existing tables are byte-identical to a fresh generation, and name no target", {
  sets <- c("numbers", "words", "lists", weft:::CONF_NEW_SETS)
  out <- file.path(withr::local_tempdir(), "regen")
  weft:::conformance_write(out, sets = sets)
  expect_setequal(list.files(out), paste0(sets, ".tsv"))
  for (s in sets) {
    a <- readBin(file.path(out, paste0(s, ".tsv")), "raw", 1e8)
    b <- readBin(test_path("_conformance", paste0(s, ".tsv")), "raw", 1e8)
    expect_identical(a, b, info = s)
    expect_false(grepl("target=", rawToChar(b), fixed = TRUE), info = s)
  }
})
