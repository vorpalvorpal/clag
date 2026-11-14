# The TeX target of the formatters (package P1 of design 9, rules TX3 to TX8, messages E100 to E105).
# Specification: dev/design-9.md. Rule 1.4.22 of the design is read as 1.4.23 (1.4.22 is the options of
# project formatters). Helpers used: helper-2g.R (g2_cfg, g2_cfg_err, g2_u), helper-2f.R (f2_tx, f2_cond),
# test-formatter-options.R is the model for project formatters (the fo_* helpers are re-made here as tt_*,
# since test files do not share their own functions). ASCII only: non-ASCII is written as \u escapes.
#
# Out of P1 (not tested here): the scanner `tex` column, the resolver (`\ensuremath`, markers, ledger), the
# lints, the docs, the conformance table, Lua.

# ---- helpers ---------------------------------------------------------------------------------------

MINUS_U <- "\u2212"
NBSP <- "\u00a0"

tt_cfg <- function(yml = NULL, env = parent.frame()) g2_cfg(yml, env = env)

# the printed text of apply_formatters() under a target; warnings are muffled
tt_run <- function(value, classes, keys = list(), cfg, target = "tex") {
  suppressWarnings(f2_tx(weft:::apply_formatters(value, classes, keys, config = cfg, target = target)))
}
# today's call: no `target` at all
tt_md <- function(value, classes, keys = list(), cfg) {
  suppressWarnings(weft:::apply_formatters(value, classes, keys, config = cfg))
}

tt_err <- function(expr) f2_cond(expr)

# an error of the class, with exactly this message
expect_tt_error <- function(e, class, msg) {
  expect_false(is.null(e), label = "an error was raised")
  expect_true(inherits(e, class), label = paste("class", class))
  expect_true(inherits(e, "weft_error"), label = "class weft_error")
  expect_identical(conditionMessage(e), msg)
}

e100 <- function(got) sprintf("`target` must be \"markdown\" or \"tex\"; got %s.", got)
e101 <- function(cls, why) sprintf("`%s` has no TeX form (target = \"tex\"): %s (rule 3.4.11).", cls, why)
E103 <- "This text was formatted for TeX (target = \"tex\") and would print here as markdown. Format the number again, without `target` (rule 3.4.11)."
e102 <- function(tok, shown) {
  sprintf(paste0("The unit `%s` prints as \"%s\", which holds markdown with no TeX form (only ^...^, ~...~ and ",
                 "backslash escapes have one). Give it a plain `symbol:` or `name:` under `units:` in _weft.yml ",
                 "to use it in math (rule 4.4.25)."), tok, shown)
}
e104 <- function(f, got) sprintf("The formatter `%s` has `targets: %s`; `targets` lists markdown and, optionally, tex (rule 1.4.8).", f, got)
e105 <- function(f, fn) sprintf("The formatter `%s` lists tex in `targets:`, so its function `%s` must take an argument `target` (rule 1.4.8).", f, fn)

# every exported fmt_*() with arguments that are valid under both targets, as a function of `target`
tt_calls <- list(
  fmt_num = function(...) fmt_num(1234.5, ...),
  fmt_pct = function(...) fmt_pct(0.123, ...),
  fmt_sci = function(...) fmt_sci(1234567, ...),
  fmt_no = function(...) fmt_no(2, ...),
  fmt_word = function(...) fmt_word(3, ...),
  fmt_count = function(...) fmt_count(3, ...),
  fmt_ord = function(...) fmt_ord(3, ...),
  fmt_and = function(...) fmt_and(c("a", "b", "c"), ...),
  fmt_or = function(...) fmt_or(c("a", "b"), ...),
  fmt_p = function(...) fmt_p(0.03, ...),
  fmt_date = function(...) fmt_date(as.Date("2024-03-05"), ...),
  fmt_range = function(...) fmt_range(c(1, 3), ...),
  fmt_pairs = function(...) fmt_pairs(c(a = 1, b = 2), ...),
  fmt_ul = function(...) fmt_ul(c("a", "b"), ...),
  fmt_ol = function(...) fmt_ol(c("a", "b"), ...),
  fmt_dl = function(...) fmt_dl(c(a = "x", b = "y"), ...),
  fmt_cap = function(...) fmt_cap("abc", ...),
  fmt_a = function(...) fmt_a(8, ...),
  fmt_strong = function(...) fmt_strong("a", ...),
  fmt_em = function(...) fmt_em("a", ...),
  fmt_unit = function(...) fmt_unit(u(5, "mg/L"), ...)
)

# ---- TX3: the argument -----------------------------------------------------------------------------

test_that("TX3: apply_formatters() and every fmt_*() take `target`, last, default \"markdown\"", {
  expect_identical(formals(weft:::apply_formatters)$target, "markdown")
  fns <- sort(grep("^fmt_", getNamespaceExports("weft"), value = TRUE))
  expect_setequal(fns, names(tt_calls))     # the table above lists them all
  for (nm in fns) {
    f <- getExportedValue("weft", nm)
    fml <- formals(f)
    expect_identical(names(fml)[length(fml)], "target", label = nm)
    expect_identical(fml$target, "markdown", label = nm)
  }
})

test_that("TX3: target = \"markdown\" is byte-identical to leaving it out, attributes included, for every fmt_*()", {
  g2_restore()
  for (nm in names(tt_calls)) {
    f <- tt_calls[[nm]]
    expect_identical(f(target = "markdown"), f(), label = nm)
    expect_null(attr(f(target = "markdown"), "target"), label = nm)
  }
})

test_that("TX3: today's objects are unchanged: no `target` attribute, the same attributes in the same order", {
  g2_restore()
  expect_identical(names(attributes(fmt_num(3))), c("class", "number", "decimals", "relation", "raw"))
  for (nm in names(tt_calls)) expect_null(attr(tt_calls[[nm]](), "target"), label = nm)
})

test_that("TX3: a result made under \"tex\" carries the attribute target = \"tex\", and is still a weft_text", {
  g2_restore()
  for (nm in c("fmt_num", "fmt_pct", "fmt_sci", "fmt_p", "fmt_range", "fmt_unit")) {
    x <- tt_calls[[nm]](target = "tex")
    expect_s3_class(x, "weft_text")
    expect_identical(attr(x, "target"), "tex", label = nm)
  }
  x <- fmt_num(c(1.5, 2), target = "tex")
  expect_identical(attr(x, "target"), "tex")
  expect_identical(attr(fmt_num(u(5, "mg/L"), target = "tex"), "target"), "tex")
})

test_that("TX3, E100: any other value of `target` is a weft_construct_error with the value in double quotes", {
  g2_restore()
  for (bad in list("html", "TeX", "Markdown", "", "tex ", "latex")) {
    e <- tt_err(fmt_num(3, target = bad))
    expect_tt_error(e, "weft_construct_error", e100(sprintf("\"%s\"", bad)))
    e <- tt_err(weft:::apply_formatters(3, ".num", target = bad))
    expect_tt_error(e, "weft_construct_error", e100(sprintf("\"%s\"", bad)))
  }
})

test_that("TX3, E100: a `target` that is not one string says `something else`", {
  # READING: `something else` is written without backticks (the design's backticks are markdown for the reader).
  g2_restore()
  for (bad in list(NULL, NA_character_, NA, 1, TRUE, c("tex", "markdown"), character(0), list("tex"))) {
    e <- tt_err(fmt_num(3, target = bad))
    expect_tt_error(e, "weft_construct_error", e100("something else"))
  }
})

test_that("TX3, E100: it is raised by every fmt_*(), before anything else is looked at", {
  g2_restore()
  for (nm in names(tt_calls)) {
    e <- tt_err(tt_calls[[nm]](target = "html"))
    expect_tt_error(e, "weft_construct_error", e100("\"html\""))
  }
})

# ---- TX3: E101, classes with no TeX form -----------------------------------------------------------------

TT_WORDS <- "it prints words"
TT_EMPH <- "it is markdown emphasis"
TT_JOIN <- "it joins items into a phrase or a list"

test_that("TX3, E101: a class that prints words, emphasis or a phrase has no TeX form (apply_formatters)", {
  # READING: the first %s is the class as written, with its leading dot (".word"), as E95 to E97 name it.
  cfg <- tt_cfg()
  cases <- list(
    list(".word", 3, TT_WORDS), list(".count", 3, TT_WORDS), list(".ord", 3, TT_WORDS), list(".no", 2, TT_WORDS),
    list(".date", as.Date("2024-03-05"), TT_WORDS), list(".a", 8, TT_WORDS), list(".cap", "abc", TT_WORDS),
    list(".em", "a", TT_EMPH), list(".strong", "a", TT_EMPH),
    list(".and", c("a", "b"), TT_JOIN), list(".or", c("a", "b"), TT_JOIN), list(".pairs", c(a = 1, b = 2), TT_JOIN),
    list(".ul", c("a", "b"), TT_JOIN), list(".ol", c("a", "b"), TT_JOIN), list(".dl", c(a = "x", b = "y"), TT_JOIN))
  for (cs in cases) {
    e <- tt_err(weft:::apply_formatters(cs[[2]], cs[[1]], config = cfg, target = "tex"))
    expect_tt_error(e, "weft_construct_error", e101(cs[[1]], cs[[3]]))
  }
})

test_that("TX3, E101: the same through the fmt_*() functions, and the markdown form of each still works", {
  g2_restore()
  words <- c(fmt_no = ".no", fmt_word = ".word", fmt_count = ".count", fmt_ord = ".ord", fmt_date = ".date",
             fmt_a = ".a", fmt_cap = ".cap")
  emph <- c(fmt_em = ".em", fmt_strong = ".strong")
  join <- c(fmt_and = ".and", fmt_or = ".or", fmt_pairs = ".pairs", fmt_ul = ".ul", fmt_ol = ".ol", fmt_dl = ".dl")
  for (set in list(list(words, TT_WORDS), list(emph, TT_EMPH), list(join, TT_JOIN))) {
    for (nm in names(set[[1]])) {
      e <- tt_err(tt_calls[[nm]](target = "tex"))
      expect_tt_error(e, "weft_construct_error", e101(set[[1]][[nm]], set[[2]]))
      expect_s3_class(tt_calls[[nm]](target = "markdown"), "weft_text")
    }
  }
})

test_that("TX3, E101: the classes that have a TeX form do not raise it", {
  g2_restore()
  for (nm in c("fmt_num", "fmt_pct", "fmt_sci", "fmt_p", "fmt_range", "fmt_unit")) {
    expect_no_error(tt_calls[[nm]](target = "tex"))
  }
})

# ---- TX3: E103, a TeX text reaching markdown ---------------------------------------------------------------

test_that("TX3, E103: a TeX text passed through a markdown text class is a weft_value_error", {
  g2_restore()
  tex <- fmt_num(1234.5, target = "tex")
  for (f in list(fmt_strong, fmt_em, fmt_cap)) {
    expect_tt_error(tt_err(f(tex)), "weft_value_error", E103)
    expect_tt_error(tt_err(f(tex, target = "markdown")), "weft_value_error", E103)
  }
})

test_that("TX3, E103: a TeX text joined by a markdown collapse is a weft_value_error", {
  g2_restore()
  tex <- fmt_num(c(1.5, 2), target = "tex")
  expect_tt_error(tt_err(fmt_and(tex)), "weft_value_error", E103)
  expect_tt_error(tt_err(fmt_ul(tex)), "weft_value_error", E103)
})

test_that("TX3, E103: formatting the number again, without `target`, is the way out", {
  g2_restore()
  expect_no_error(fmt_strong(fmt_num(1234.5)))
  expect_identical(f2_tx(fmt_strong(fmt_num(1234.5))), f2_tx(fmt_strong(fmt_num(1234.5, target = "markdown"))))
  expect_no_error(fmt_and(fmt_num(c(1.5, 2))))
})

# ---- TX5: the outputs under "tex", and today's under "markdown" -----------------------------------------------

TT_YEAR <- function() weft:::new_weft_year(2024L)

# value, classes, keys, tex output
tt_rows <- function() list(
  list(-1234567.89, ".num", list(), "-1{,}234{,}567.9"),
  list(999.95, ".num", list(), "1{,}000.0"),
  list(3, ".num", list(), "3"),
  list(0.5, ".num", list(digits = 2), "0.50"),
  list(c(3, -3, 0), c(".num", ".plus"), list(), c("+3", "-3", "0")),
  list(0.123, ".pct", list(), r"(12.3\%)"),
  list(0.05, c(".pct", ".plus"), list(), r"(+5\%)"),
  list(1234567, ".sci", list(), r"(1.2 \times 10^{6})"),
  list(-0.000123, ".sci", list(), r"(-1.2 \times 10^{-4})"),
  list(0, ".sci", list(), "0"),
  list(1, ".sci", list(), r"(1 \times 10^{0})"),
  list(9.96, ".sci", list(), r"(1 \times 10^{1})"),
  list(12345, ".sci", list(digits = 2), r"(1.23 \times 10^{4})"),
  list(c(0.0001, 0.03, 0.5, 0.995), ".p", list(), c("p < 0.001", "p = 0.030", "p = 0.50", "p > 0.99")),
  list(c(0.5, 0.995), ".p", list(label = ""), c("0.50", "> 0.99")),
  list(0.046, ".p", list(label = r"(\tilde{p})"), r"(\tilde{p} = 0.046)"),
  list(c(1.23, 3.45), ".range", list(), r"(1.2\ \text{to}\ 3.5)"),
  list(c(-1, 3), ".range", list(), r"(-1\ \text{to}\ 3)"),
  list(c(2, 2), ".range", list(), "2"),
  list(c(1, 3), c(".range", ".plus"), list(), r"(+1\ \text{to}\ +3)"),
  list(clamp(0.004, floor = 0.01), ".num", list(), "< 0.01")
)

test_that("TX5: every row of the output table, under target = \"tex\"", {
  cfg <- tt_cfg()
  for (r in tt_rows()) {
    expect_identical(tt_run(r[[1]], r[[2]], r[[3]], cfg), r[[4]], label = paste(r[[2]], collapse = " "))
  }
})

test_that("TX5: .num on a weft_year prints the bare year (the year rule is unchanged)", {
  cfg <- tt_cfg()
  expect_identical(tt_run(TT_YEAR(), ".num", list(), cfg), "2024")
  expect_identical(f2_tx(tt_md(TT_YEAR(), ".num", list(), cfg)), "2024")
})

test_that("TX5: a vector under .num is formatted element by element", {
  # READING: the design's row `.num` c(1.5, 2) -> `1.5, 2` is read as the two elements "1.5" and "2",
  # as in markdown today; the ", " of the table is the join the resolver does, not part of the value.
  cfg <- tt_cfg()
  expect_identical(tt_run(c(1.5, 2), ".num", list(), cfg), c("1.5", "2"))
  expect_identical(f2_tx(tt_md(c(1.5, 2), ".num", list(), cfg)), c("1.5", "2"))
})

test_that("TX5: the zero-noise warnings name the TeX text printed", {
  cfg <- tt_cfg()
  expect_warning(weft:::apply_formatters(0.04, ".num", config = cfg, target = "tex"),
                 "0.04 printed as 0.0: add sigfig to show it, or digits to confirm it", fixed = TRUE)
  expect_warning(weft:::apply_formatters(0.0004, ".pct", config = cfg, target = "tex"),
                 r"(0.04% printed as 0.0\%: add sigfig to show it, or digits to confirm it)", fixed = TRUE)
  expect_identical(tt_run(0.04, ".num", list(), cfg), "0.0")
  expect_identical(tt_run(0.0004, ".pct", list(), cfg), r"(0.0\%)")
})

test_that("TX5: under \"markdown\" the zero-noise warnings are today's", {
  cfg <- tt_cfg()
  expect_warning(weft:::apply_formatters(0.0004, ".pct", config = cfg), "0.04% printed as 0.0%: add sigfig", fixed = TRUE)
  expect_warning(weft:::apply_formatters(0.0004, ".pct", config = cfg, target = "markdown"),
                 "0.04% printed as 0.0%: add sigfig", fixed = TRUE)
})

test_that("TX5, TX3: under target = \"markdown\" every row above is byte-identical to leaving `target` out", {
  cfg <- tt_cfg()
  for (r in c(tt_rows(), list(list(TT_YEAR(), ".num", list(), NULL)))) {
    a <- suppressWarnings(weft:::apply_formatters(r[[1]], r[[2]], r[[3]], config = cfg))
    b <- suppressWarnings(weft:::apply_formatters(r[[1]], r[[2]], r[[3]], config = cfg, target = "markdown"))
    expect_identical(b, a, label = paste(r[[2]], collapse = " "))
  }
})

test_that("TX5: today's markdown outputs are pinned (no `target` argument involved)", {
  cfg <- tt_cfg()
  md <- function(v, cl, k = list()) f2_tx(tt_md(v, cl, k, cfg))
  expect_identical(md(-1234567.89, ".num"), paste0(MINUS_U, "1,234,567.9"))
  expect_identical(md(999.95, ".num"), "1,000.0")
  expect_identical(md(0.123, ".pct"), "12.3%")
  expect_identical(md(0.05, c(".pct", ".plus")), "+5%")
  expect_identical(md(1234567, ".sci"), "1.2 \u00d7 10^6^")
  expect_identical(md(-0.000123, ".sci"), paste0(MINUS_U, "1.2 \u00d7 10^", MINUS_U, "4^"))
  expect_identical(md(c(0.0001, 0.03, 0.5, 0.995), ".p"), c("p < 0.001", "p = 0.030", "p = 0.50", "p > 0.99"))
  expect_identical(md(c(1.23, 3.45), ".range"), "1.2\u20133.5")
  expect_identical(md(c(-1, 3), ".range"), paste0(MINUS_U, "1 to 3"))
  expect_identical(md(0.046, ".p", list(label = "*p*")), "*p* = 0.046")
})

# ---- TX4: the marks -----------------------------------------------------------------------------------------

test_that("TX4: the thousands mark under the configurations of the design", {
  tt_mark <- function(yml) tt_run(1234567.89, ".num", list(), tt_cfg(yml))
  expect_identical(tt_mark(c("decimal_mark: \",\"", "big_mark: \".\"")), "1.234.567{,}9")
  expect_identical(tt_mark("big_mark: \" \""), "1\\,234\\,567.9")
  expect_identical(tt_mark("big_mark: \"'\""), "1\\text{'}234\\text{'}567.9")
  expect_identical(tt_mark("big_mark: \"\""), "1234567.9")
  expect_identical(tt_mark("big_mark: \",\""), "1{,}234{,}567.9")
})

test_that("TX4: every space mark, and the apostrophe mark of both kinds, share one TeX form", {
  tt_mark <- function(yml) tt_run(1234567.89, ".num", list(), tt_cfg(yml))
  for (sp in c(" ", NBSP, "\u2009", "\u202f")) {
    expect_identical(tt_mark(sprintf("big_mark: \"%s\"", sp)), "1\\,234\\,567.9", label = paste0("U+", format(as.hexmode(utf8ToInt(sp)))))
  }
  expect_identical(tt_mark("big_mark: \"\u2019\""), "1\\text{'}234\\text{'}567.9")
})

test_that("TX4: the middle dot, and any other mark through tex_text()", {
  tt_mark <- function(yml) tt_run(1234567.89, ".num", list(), tt_cfg(yml))
  expect_identical(tt_mark("big_mark: \"\u00b7\""), "1{\\cdot}234{\\cdot}567.9")
  expect_identical(tt_mark("big_mark: \"_\""), "1\\_234\\_567.9")
  expect_identical(tt_mark("big_mark: \"*\""), "1\\text{*}234\\text{*}567.9")
})

test_that("TX4: a decimal mark has the same table", {
  tt_dec <- function(yml) tt_run(0.5, ".num", list(digits = 2), tt_cfg(yml))
  # big_mark is given because the two marks must differ (config rule)
  expect_identical(tt_dec("decimal_mark: \",\"\nbig_mark: \"\""), "0{,}50")
  expect_identical(tt_dec("decimal_mark: \"\u00b7\""), "0{\\cdot}50")
  expect_identical(tt_dec("decimal_mark: \".\""), "0.50")
})

test_that("TX4: when both marks map to the same TeX, the decimal mark is written \\text{<mark>}", {
  # READING: <mark> is the configured mark itself. The two marks must differ (else a config error), so the case
  # is two different marks with one TeX form: big "'" and decimal U+2019 are both \text{'}; so are two spaces.
  cfg <- tt_cfg(c("decimal_mark: \"\u2019\"", "big_mark: \"'\""))
  expect_identical(tt_run(1234567.89, ".num", list(), cfg), "1\\text{'}234\\text{'}567\\text{\u2019}9")
  cfg2 <- tt_cfg(c("decimal_mark: \"\u00a0\"", "big_mark: \" \""))
  expect_identical(tt_run(1234567.89, ".num", list(), cfg2), paste0("1\\,234\\,567\\text{", NBSP, "}9"))
})

test_that("TX4: the minus setting never reaches TeX: a negative number always prints `-`", {
  for (yml in list(NULL, "minus: \"-\"", "minus: \"\u2013\"", "minus: \"\u2212\"", "minus: \"--\"")) {
    cfg <- tt_cfg(yml)
    expect_identical(tt_run(-3, ".num", list(), cfg), "-3")
    expect_identical(tt_run(-0.000123, ".sci", list(), cfg), r"(-1.2 \times 10^{-4})")
    expect_identical(tt_run(c(-1, 3), ".range", list(), cfg), r"(-1\ \text{to}\ 3)")
  }
})

test_that("TX4: thousands_from and the year rule are unchanged", {
  cfg <- tt_cfg()
  expect_identical(tt_run(999, ".num", list(), cfg), "999")
  expect_identical(tt_run(1234, ".num", list(), cfg), "1{,}234")
  expect_identical(tt_run(TT_YEAR(), ".num", list(), tt_cfg("big_mark: \" \"")), "2024")
})

test_that("TX4: the marks are for TeX only: markdown output under the same configurations is today's", {
  tt_pair <- function(yml) {
    cfg <- tt_cfg(yml)
    list(tt_md(1234567.89, ".num", list(), cfg),
         suppressWarnings(weft:::apply_formatters(1234567.89, ".num", config = cfg, target = "markdown")))
  }
  expect_identical(f2_tx(tt_pair("big_mark: \" \"")[[1]]), "1 234 567.9")
  expect_identical(f2_tx(tt_pair(c("decimal_mark: \",\"", "big_mark: \".\""))[[1]]), "1.234.567,9")
  expect_identical(f2_tx(tt_pair("big_mark: \"\u00b7\"")[[1]]), "1\u00b7234\u00b7567.9")
  for (yml in list("big_mark: \" \"", c("decimal_mark: \",\"", "big_mark: \".\""), "big_mark: \"'\"")) {
    pr <- tt_pair(yml)
    expect_identical(pr[[2]], pr[[1]])
  }
})

# ---- TX5: p_label under TeX ------------------------------------------------------------------------------------

test_that("TX5: the setting p_label is converted for TeX", {
  tt_p <- function(label) tt_run(0.03, ".p", list(), tt_cfg(sprintf("p_label: \"%s\"", label)))
  expect_identical(tt_p("p"), "p = 0.030")
  expect_identical(tt_p("*p*"), "p = 0.030")
  expect_identical(tt_p("_p_"), "p = 0.030")
  expect_identical(tt_p("q"), "q = 0.030")
  expect_identical(tt_p(""), "0.030")
  expect_identical(tt_p("adj. p"), r"(\text{adj. p} = 0.030)")
  expect_identical(tt_p("p_adj"), r"(\text{p}\_\text{adj} = 0.030)")
})

test_that("TX5: an explicit label (key or argument) is TeX and goes in verbatim", {
  cfg <- tt_cfg("p_label: \"adj. p\"")
  expect_identical(tt_run(0.046, ".p", list(label = "*p*"), cfg), "*p* = 0.046")
  expect_identical(tt_run(0.046, ".p", list(label = r"(\tilde{p})"), cfg), r"(\tilde{p} = 0.046)")
  expect_identical(f2_tx(fmt_p(0.046, label = r"(\hat{p})", target = "tex")), r"(\hat{p} = 0.046)")
})

test_that("TX5: p_label under markdown is today's (not converted), with and without target", {
  cfg <- tt_cfg("p_label: \"*p*\"")
  expect_identical(f2_tx(tt_md(0.03, ".p", list(), cfg)), "*p* = 0.030")
  expect_identical(tt_run(0.03, ".p", list(), cfg, target = "markdown"), "*p* = 0.030")
})

test_that("TX5: .p under the comma decimal mark", {
  cfg <- tt_cfg(c("decimal_mark: \",\"", "big_mark: \".\""))
  expect_identical(tt_run(0.0001, ".p", list(), cfg), "p < 0{,}001")
  expect_identical(tt_run(0.03, ".p", list(), cfg), "p = 0{,}030")
  expect_identical(tt_run(0.0001, ".p", list(), cfg, target = "markdown"), "p < 0,001")
})

# ---- TX6: tex_text() ---------------------------------------------------------------------------------------------

test_that("TX6: maximal runs of ordinary characters go in \\text{}, spaces and non-ASCII included", {
  tt <- weft:::tex_text
  expect_identical(tt("adj. p"), r"(\text{adj. p})")
  expect_identical(tt("abc"), r"(\text{abc})")
  expect_identical(tt("a b"), r"(\text{a b})")
  expect_identical(tt("\u00b0C"), "\\text{\u00b0C}")
  expect_identical(tt("\u00b5m"), "\\text{\u00b5m}")
})

test_that("TX6: each special character maps singly, and splits the runs around it", {
  tt <- weft:::tex_text
  expect_identical(tt("\\"), "\\backslash")
  expect_identical(tt("{"), "\\{")
  expect_identical(tt("}"), "\\}")
  expect_identical(tt("$"), "\\$")
  expect_identical(tt("%"), "\\%")
  expect_identical(tt("&"), "\\&")
  expect_identical(tt("#"), "\\#")
  expect_identical(tt("_"), "\\_")
  expect_identical(tt("^"), "\\hat{}")
  expect_identical(tt("~"), "\\sim")
  expect_identical(tt("<"), "<")
  expect_identical(tt(">"), ">")
  expect_identical(tt("|"), "|")
  expect_identical(tt(NBSP), "\\,")
  expect_identical(tt("p_adj"), r"(\text{p}\_\text{adj})")
  expect_identical(tt("a%b"), r"(\text{a}\%\text{b})")
  expect_identical(tt("a\\b"), r"(\text{a}\backslash\text{b})")
  expect_identical(tt("a^b~c"), r"(\text{a}\hat{}\text{b}\sim\text{c})")
  expect_identical(tt(paste0("a", NBSP, "b")), r"(\text{a}\,\text{b})")
  expect_identical(tt("5%"), r"(\text{5}\%)")
  expect_identical(tt("{a}"), r"(\{\text{a}\})")
})
