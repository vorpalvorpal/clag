# Regression tests for the independent review of package A
# (dev/review-1a-A.md, with the rulings at the end of dev/design-1a.md).

st <- function(x, ...) weft:::scan_text(x, ...)
af <- function(v, cls, keys = list(), config = weft:::default_config(), ...) {
  weft:::apply_formatters(v, cls, keys, config, ...)
}
txt <- function(x) as.character(x)
MINUS_ <- "−"
PH <- ""

cfg_dir <- function(yml = NULL, env = parent.frame()) {
  root <- withr::local_tempdir(.local_envir = env)
  d <- file.path(root, "proj")
  dir.create(d)
  if (!is.null(yml)) writeLines(yml, file.path(d, "_weft.yml"))
  d
}
rc <- function(d, front = list()) weft:::read_config(d, front = front)
withr::local_envvar(WEFT_DRAFT = NA)

# ---- scanner -----------------------------------------------------------

test_that("review A #1: an attribute block that spans lines is a construct (2.10.1, 1.1.5)", {
  expect_equal(nrow(st('[a]{if="y" .em}')), 1L)          # control: one line
  for (x in c('[a]{if="y"\n.em}', '[a]{\nif="y"}', '[a | b]{if="x"\r\n}')) {
    r <- st(x)
    expect_equal(nrow(r), 1L, info = x)
    expect_equal(r$kind, "if", info = x)
    expect_true(is.na(r$error), info = x)
  }
  expect_equal(st('[a]{if="y"\n.em}')$expr, "y")
})

test_that("review A #2 / ruling: arm_templates keeps # placeholder and literal ## apart (1.5.12, 1.5.8)", {
  r <- st('[# item | ## items]{n="k"}')
  expect_equal(r$arms[[1]], c("# item", "# items"))        # control: arms unchanged
  expect_true("arm_templates" %in% names(r))
  expect_equal(r$arm_templates[[1]], c(paste0(PH, " item"), "# items"))
  # a plain placeholder-only case
  r2 <- st('[# a | b]{n="k"}')
  expect_equal(r2$arm_templates[[1]], c(paste0(PH, " a"), "b"))
})

test_that("review A #3 / ruling: a wording class on a number printed with decimals is a value error (1.4.12)", {
  expect_equal(txt(fmt_word(3)), "three")                  # controls
  expect_equal(txt(fmt_word(3.0000)), "three")
  expect_error(fmt_word(2.04), class = "weft_value_error")
  expect_error(fmt_word(1.96), class = "weft_value_error")
  expect_error(fmt_ord(1.96), class = "weft_value_error")
  expect_error(fmt_count(3.04), class = "weft_value_error")
})

test_that("review A #4 / ruling: wholeness is judged absolutely, to 1e-9 (1.4.13)", {
  expect_equal(txt(fmt_num(3)), "3")                       # control
  expect_equal(txt(fmt_num(1e10 + 0.3)), "10,000,000,000.3")
  expect_equal(txt(fmt_num(123456789012.3)), "123,456,789,012.3")
  expect_equal(txt(fmt_num(1e-10)), "0.0")
  expect_equal(txt(fmt_no(1e-10)), "0.0")
  expect_equal(txt(fmt_no(0)), "no")
})

test_that("review A #5: plural() refuses a weft_text with no number (1.5.11)", {
  expect_equal(plural(fmt_num(1), "x", "y"), "x")          # control
  e <- expect_error(plural(fmt_and(c("a", "b")), "x", "y"), class = "weft_value_error")
  expect_match(conditionMessage(e), "length")
  e <- expect_error(plural(fmt_strong("abc"), "x", "y"), class = "weft_value_error")
  expect_match(conditionMessage(e), "length")
})

test_that("review A #6 / ruling: code spans knitr does not evaluate are not inline R (1.1.8, 1.3.1)", {
  expect_equal(st("a `r x` b")$kind, "bare")              # control
  expect_equal(nrow(st("a ` r x ` b")), 0L)
  expect_equal(nrow(st("a `r\tx` b")), 0L)
  for (x in c("a ` r x `{.num} b", "a `r\tx`{.num} b")) {
    expect_false(any(st(x)$kind %in% c("value", "bare")), info = x)
  }
})

test_that("review A #7 / ruling: several expressions in inline R are legal; only unparseable code errs (5.3.5)", {
  r <- st("E `r a; b` F")
  expect_equal(nrow(r), 1L)
  expect_equal(r$kind, "bare")
  expect_true(is.na(r$error))
  r <- st("`r a\nb`{.num}")
  expect_equal(nrow(r), 1L)
  expect_equal(r$kind, "value")
  expect_true(is.na(r$error))
  # control: code that does not parse is still the error
  r <- st("`r a b`{.num}")
  expect_true(any(!is.na(r$error)))
})

test_that("review A #8 / ruling: a number formatter given a weft_text formats its raw value (3.4.2, 1.4.11, 1.7.8)", {
  expect_equal(txt(fmt_pct(0.12)), "12%")                  # control
  expect_equal(txt(fmt_pct(fmt_num(0.12))), "12%")
  expect_equal(txt(fmt_pct(fmt_pct(0.12))), "12%")
  expect_equal(txt(fmt_num(fmt_num(3.14159), digits = 3)), "3.142")
  expect_equal(attr(fmt_num(0.12), "raw"), 0.12)
  expect_equal(txt(fmt_word(fmt_num(3))), "three")         # later stages use the record
})

test_that("review A #9: a missing value inside a list is a no-value error (1.3.4)", {
  expect_equal(txt(fmt_and(list("a", "b"))), "a and b")    # control
  expect_error(fmt_and(list(NA, "b")), class = "weft_no_value")
  expect_error(fmt_and(list(Inf, 1)), class = "weft_no_value")
  expect_error(fmt_strong(list(NULL)), class = "weft_no_value")
})

test_that("review A #10: a broken block holding any renderer key is a construct error (1.2.9, 1.2.3)", {
  expect_true(is.na(st('`r x`{.and sep="; "}')$error))     # control
  for (x in c('`r x`{.and sep="a"b"}', '`r x`{.num digits="2"x"}',
              '`r x`{.and last="a"b"}', '`r x`{.num sigfig="2"x"}')) {
    r <- st(x)
    expect_true(any(!is.na(r$error)), info = x)
  }
})

test_that("review A #11: an unclosed <!-- mid-line does not hide the rest (1.9.2)", {
  expect_equal(nrow(st("a <!-- `r x`{.num} -->")), 0L)     # control: a real comment
  r <- st("a <!-- unclosed `r x`{.num}")
  expect_equal(nrow(r), 1L)
  expect_equal(r$kind, "value")
})

test_that("review A #12: an autolink target inside an arm is protected (1.5.14)", {
  r <- st('[see <http://a.b/c#d> | # x]{n="k"}')
  expect_equal(r$arms[[1]], c("see <http://a.b/c#d>", "# x"))
  expect_equal(r$arm_templates[[1]], c("see <http://a.b/c#d>", paste0(PH, " x")))
  r <- st('[a <http://x.y/a|b> | c]{if="x"}')
  expect_true(is.na(r$error))
  expect_length(r$arms[[1]], 2L)
})

test_that("review A #13: a table pandoc does not see gives no pipe-table error (1.5.13)", {
  # control: a real pipe table with a bar inside a cell construct is the error
  r <- st('a | b\n---|---\n[x | y]{if="z"}')
  expect_true(any(!is.na(r$error)))
  for (x in c('Heading\n---|---\n[x | y]{if="z"}', 'para\n-|-\n[x | y]{if="z"}')) {
    r <- st(x)
    expect_equal(nrow(r), 1L, info = x)
    expect_true(is.na(r$error), info = x)
  }
})

test_that("review A #14: inline R in a link target is a row (1.1.8, 2.10.2)", {
  expect_equal(nrow(st("see `r p` here")), 1L)             # control
  for (x in c("[a](`r url`)", "[a](http://x.y/`r p`)")) {
    r <- st(x)
    expect_equal(nrow(r), 1L, info = x)
    expect_equal(r$kind, "bare", info = x)
  }
})

test_that("review A #15: front matter not at character 1 is not scanned as prose", {
  d <- withr::local_tempdir()
  f1 <- file.path(d, "a.qmd")
  writeLines("---\ntitle: \"`r x`{.num}\"\n---\nbody", f1)
  expect_equal(nrow(weft:::scan_file(f1)), 0L)             # control
  f2 <- file.path(d, "b.qmd")
  writeBin(charToRaw("\n---\ntitle: \"`r x`{.num}\"\n---\nbody"), f2)
  expect_equal(nrow(weft:::scan_file(f2)), 0L)
  f3 <- file.path(d, "c.qmd")
  writeBin(charToRaw("para\n\n---\nb: \"[a]{if='x'}\"\n---\n\nmore"), f3)
  r <- weft:::scan_file(f3)
  expect_false(any(!is.na(r$error)))
})

test_that("review A #16: a tilde fence inside a block quote is skipped (1.9.2)", {
  r <- st("> ~~~\n> `r x`{.num}\n> ~~~\n\n`r y`{.num}")
  expect_equal(nrow(r), 1L)
  expect_equal(r$expr, "y")
  r <- st("~~~\n`r x`{.num}\n~~~\n\n`r y`{.num}")          # control: unquoted
  expect_equal(r$expr, "y")
})

test_that("review A #17: digits or sigfig on a value that is not a number is a value error (1.4.7)", {
  expect_equal(txt(af(3.14159, character(), list(digits = "3"))), "3.142")  # control
  expect_error(af("abc", character(), list(digits = "2")), class = "weft_value_error")
  expect_error(af("abc", character(), list(sigfig = "2")), class = "weft_value_error")
  # a weft_text input: the number stage formats the raw value afresh (ruling 8)
  expect_equal(txt(af(fmt_num(3.14159), character(), list(digits = "3"))), "3.142")
})

# ---- configuration -----------------------------------------------------

test_that("review A #18 / ruling K: bad configuration values are errors from read_config()", {
  expect_equal(rc(cfg_dir("digits: 2"))$digits, 2)         # controls
  expect_equal(rc(cfg_dir("governor_class: .word"))$governor_class, ".word")
  expect_equal(rc(cfg_dir("digits: 0"))$digits, 0)
  for (y in c("digits: 1.5", "digits: .inf", "digits: -1", "digits: abc",
              "count_threshold: -1", "count_threshold: 2.5", "word_limit: .inf",
              "word_limit: 1.5",
              "governor_class: .and", "governor_class: .bogus", "governor_class: num",
              "governor_class: .strong")) {
    expect_error(rc(cfg_dir(y)), info = y)
  }
})

test_that("review A ruling K: decimal_mark equal to big_mark is an error", {
  expect_error(rc(cfg_dir(c('decimal_mark: ","', 'big_mark: ","'))))
  expect_equal(rc(cfg_dir(c('decimal_mark: ","', 'big_mark: "."')))$decimal_mark, ",")  # control
})

test_that("review A #19 / ruling K: a badly shaped formatters: or front matter is an error (1.4.8, 9.1.1)", {
  ok <- c("formatters:", "  .compact:", "    function: base::toupper", "    stage: text")
  expect_named(rc(cfg_dir(ok))$formatters, ".compact")     # control
  expect_error(rc(cfg_dir("formatters: 3")))
  expect_error(rc(cfg_dir("formatters: [.a1]")))
  expect_error(rc(cfg_dir(), front = list(1, 2)))
  expect_error(rc(cfg_dir(c("formatters:", "  .compact: 3"))))
})

test_that("review A ruling G: an unknown configuration key is a warning naming the key", {
  expect_no_warning(rc(cfg_dir("digits: 2")))              # control
  expect_warning(rc(cfg_dir("digts: 2")), "digts")
  expect_warning(rc(cfg_dir(), front = list(digts = 2)), "digts")
})

# ---- attribute blocks and messages ---------------------------------------

test_that("review A #20: two ids in one block are not a construct error (5.3.1)", {
  r <- st('[a]{if="y" #x #z}')
  expect_equal(nrow(r), 1L)
  expect_true(is.na(r$error))
  expect_equal(r$id, "z")
})

test_that("review A #21: the does-not-parse message names the real cause (1.2.3)", {
  expect_true(any(!is.na(st('[a]{if="a"b"}')$error)))      # control: quote problem
  for (x in c('[a]{n = "k"}', "[a]{if=}", '[a]{# if="y"}')) {
    r <- st(x)
    expect_true(any(!is.na(r$error)), info = x)
    expect_false(grepl("ends it early", r$error[!is.na(r$error)][1]), info = x)
  }
})

# ---- claim() -----------------------------------------------------------

test_that("review A #22: an empty check argument is no check (3.1.10)", {
  expect_error(claim(5), class = "weft_claim_no_check")    # control
  expect_error(claim(5, ), class = "weft_claim_no_check")
  r <- st("`r claim(k, )`")
  expect_true(any(!is.na(r$error)))
})

test_that("review A #27: a failed claim quotes the check as written (3.1.4)", {
  e <- expect_error(claim(5, . > 10), class = "weft_claim_failed")
  expect_match(conditionMessage(e), ". > 10", fixed = TRUE)  # control
  e <- expect_error(claim(5, . > 1e6), class = "weft_claim_failed")
  expect_match(conditionMessage(e), ". > 1e6", fixed = TRUE)
  expect_false(grepl("1e+06", conditionMessage(e), fixed = TRUE))
  e <- expect_error(claim(5, . >= 10.50), class = "weft_claim_failed")
  expect_match(conditionMessage(e), ". >= 10.50", fixed = TRUE)
})

test_that("review A ruling F: a check that errors is a failed check reporting the error (2.6.1)", {
  expect_identical(claim(5, . > 1, . < 10), 5)             # control
  e <- expect_error(claim(5, stop("boom")), class = "weft_claim_failed")
  expect_match(conditionMessage(e), "boom")
  expect_match(conditionMessage(e), "stop(", fixed = TRUE)
  e <- expect_error(claim(5, . > 1, stop("second")), class = "weft_claim_failed")
  expect_match(conditionMessage(e), "second")
})

# ---- crashes -----------------------------------------------------------

test_that("review A #23: a file that is not UTF-8 gives a classed error naming the file", {
  d <- withr::local_tempdir()
  ok <- file.path(d, "ok.qmd")
  writeLines("café `r y`{.num}", ok, useBytes = FALSE)
  expect_equal(nrow(weft:::scan_file(ok)), 1L)             # control
  bad <- file.path(d, "latin1.qmd")
  writeBin(c(charToRaw("caf"), as.raw(0xe9), charToRaw(" `r y`{.num}")), bad)
  e <- expect_error(weft:::scan_file(bad))
  expect_match(conditionMessage(e), "latin1.qmd", fixed = TRUE)
  expect_true(any(grepl("^weft_", class(e))))
})

test_that("review A #24: fmt_sci() of a denormal number does not crash", {
  expect_match(txt(fmt_sci(1234)), "×")               # control
  x <- fmt_sci(5e-324)
  expect_s3_class(x, "weft_text")
  expect_length(x, 1L)
  expect_false(is.na(txt(x)))
  expect_match(txt(x), "×")
})

# ---- cosmetic ----------------------------------------------------------

test_that("review A #25: bold or italic of an empty string emits nothing (1.2.6)", {
  expect_equal(txt(fmt_strong("a")), "**a**")              # control
  expect_equal(txt(fmt_strong("")), "")
  expect_equal(txt(fmt_em("")), "")
})

test_that("review A #26: a very large ordinal prints no base warnings", {
  expect_equal(txt(fmt_ord(21)), "21st")                   # control
  expect_no_warning(fmt_ord(1e20))
})

test_that("review A #28: scan time grows about linearly with the text", {
  skip_on_cran()
  unit <- "Para `r x`{.num} and `r y`{.num} text `r z` and [a | b]{if=\"q\"}.\n\n"
  small <- strrep(unit, 1000L)
  big <- strrep(unit, 4000L)
  t_small <- system.time(st(small))[["elapsed"]]
  t_big <- system.time(st(big))[["elapsed"]]
  expect_lt(t_big, max(6 * t_small, 0.5))
  expect_lt(t_big, 4)
})

# ---- rulings that change behaviour ---------------------------------------

test_that("review A ruling A: rounding is half away from zero on the decimal as written", {
  expect_equal(txt(fmt_num(1.23)), "1.2")                  # control
  expect_equal(txt(fmt_num(0.05)), "0.1")
  expect_equal(txt(fmt_num(0.15)), "0.2")
  expect_equal(txt(fmt_num(0.25)), "0.3")
  expect_equal(txt(fmt_num(2.45)), "2.5")
  expect_equal(txt(fmt_num(2.5, digits = 0)), "3")
  expect_equal(txt(fmt_num(3.5, digits = 0)), "4")
  expect_equal(txt(fmt_num(-0.05)), paste0(MINUS_, "0.1"))
  expect_equal(txt(fmt_num(-0.04)), "0.0")                 # rounds to zero: no minus
})

test_that("review A ruling B: a wording class with .pct or .sci is a construct error", {
  expect_equal(txt(af(3, ".word")), "three")               # control
  expect_error(af(0.03, c(".pct", ".word")), class = "weft_construct_error")
  expect_error(af(0.03, c(".pct", ".ord")), class = "weft_construct_error")
  expect_error(af(30, c(".sci", ".word")), class = "weft_construct_error")
})

test_that("review A ruling D: a weft key on a link is a construct error (1.9.1)", {
  expect_equal(nrow(st("[a](u)")), 0L)                     # control
  expect_true(is.na(st('[a]{if="x"}')$error))              # control
  r <- st('[a](u){if="x"}')
  expect_true(any(!is.na(r$error)))
})

test_that("review A ruling E: an attribute block on inline R in a link target is a construct error", {
  r <- st("[a](`r u`{.num})")
  expect_true(any(!is.na(r$error)))
})

test_that("review A ruling J: on a text span a formatter class or renderer key passes through (1.1.9)", {
  for (x in c("[x]{.num .strong}", '[x]{.em digits="2"}')) {
    r <- st(x)
    expect_equal(nrow(r), 1L, info = x)
    expect_equal(r$kind, "text", info = x)
    expect_true(is.na(r$error), info = x)
  }
  expect_true(".num" %in% st("[x]{.num .strong}")$classes[[1]])
})

test_that("review A ruling: apply_formatters(governor = TRUE) runs stages i and ii only (1.5.7, 1.5.18)", {
  expect_equal(txt(af(3, c(".word", ".strong"))), "**three**")         # control
  expect_equal(txt(af(3, c(".word", ".strong"), governor = TRUE)), "three")
  expect_equal(txt(af(3, ".em", governor = TRUE)), "3")                # default .num
  conf <- weft:::default_config()
  conf$governor_class <- ".word"
  expect_equal(txt(af(3, character(), config = conf, governor = TRUE)), "three")
  expect_equal(txt(af(3, ".em", config = conf, governor = TRUE)), "three")
})
