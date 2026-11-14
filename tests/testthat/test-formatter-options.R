# Options for project formatters (rule 1.4.22, PF1 to PF17, messages M1 to M11, W1, L1, L2).
# Specification: dev/design-formatter-options.md. Helpers used: helper-2g.R (g2_cfg, g2_cfg_err),
# helper-7a.R (p7_cfg, p7_scan_errs, p7_knit), helper-2d.R (d2_run, d2_ledger, d2_pick),
# helper-3.R (lint_one, lf_by_rule), helper-filter.R (filter_cases). ASCII only.
#
# A project formatter's function is looked up in the global environment (or as pkg::fun), so a function a
# test needs is installed there for the length of the test and removed again.

# ---- helpers ---------------------------------------------------------------------------------------

fo_install <- function(name, fn, env = parent.frame()) {
  assign(name, fn, envir = globalenv())
  withr::defer(rm(list = name, envir = globalenv()), envir = env)
  invisible(fn)
}

# installs a function that records the options it receives (list(...)) and returns ret(x)
fo_rec <- function(name, ret = function(x) paste0("<", paste(as.character(unclass(x)), collapse = "|"), ">"),
                   env = parent.frame()) {
  store <- new.env()
  store$calls <- list()
  fn <- function(x, ...) {
    store$calls <- c(store$calls, list(list(...)))
    ret(x)
  }
  fo_install(name, fn, env = env)
  store
}

# the docs example
fo_in_millions <- function(env = parent.frame()) {
  fo_install("in_millions", function(x, digits = NULL, word = "million") {
    paste(weft::fmt_num(x / 1e6, digits = digits), word)
  }, env = env)
}

# a configuration read from _weft.yml lines (read_config), for apply_formatters(config =)
fo_cfg <- function(yml, front = list(), env = parent.frame()) g2_cfg(yml, front = front, env = env)

fo_apply <- function(value, classes, keys = list(), cfg) {
  suppressWarnings(weft:::apply_formatters(value, classes, keys, config = cfg))
}

fo_err <- function(expr) tryCatch({ expr; NULL }, error = function(e) e)

fo_warns <- function(expr) {
  ws <- list()
  withCallingHandlers(expr, warning = function(w) {
    ws[[length(ws) + 1L]] <<- w
    invokeRestart("muffleWarning")
  })
  ws
}

# registration lines for one class
fo_reg <- function(cls, fn, stage = NULL, options = NULL) {
  c(paste0("  ", cls, ":"), paste0("    function: ", fn),
    if (!is.null(stage)) paste0("    stage: ", stage),
    if (!is.null(options)) c("    options:", paste0("      ", options)))
}
fo_yml <- function(...) c("formatters:", unlist(list(...)))

# the messages
m1 <- function(f) sprintf("The `options` of the formatter `%s` must be a list of option names or a mapping from option name to type (rule 1.4.22).", f)
m2 <- function(o, f) sprintf("The option name `%s` of the formatter `%s` must start with a lower-case letter and have only lower-case letters, digits and `_` (rule 1.4.22).", o, f)
m3 <- function(o, f) sprintf("The option `%s` is declared twice for the formatter `%s` (rule 1.4.22).", o, f)
m4 <- function(o, f, t) sprintf("The option `%s` of the formatter `%s` has the unknown type `%s`; the types are number, integer, string and logical (rule 1.4.22).", o, f, t)
m5 <- function(f, o) sprintf("The formatter `%s` cannot declare `%s` as an option: weft reads that key itself (rule 1.4.22).", f, o)
m6 <- function(f, o, wstage, fstage) {
  sprintf("The formatter `%s` cannot declare `%s` as an option: `%s` belongs to weft's %s stage, and `%s` is a %s-stage formatter (rule 1.4.22).",
          f, o, o, wstage, f, fstage)
}
m7 <- function(o, f, own, got) sprintf("The option `%s` of the formatter `%s` is weft's key, of type %s, and cannot be declared as %s (rule 1.4.22).", o, f, own, got)
w1 <- function(k, f) sprintf("Unknown key `%s` in the formatter `%s`; it is ignored (rule 1.4.8).", k, f)
m8 <- function(k, cls) sprintf("`%s` does not apply to `%s`: the formatter declares no option `%s` (rule 1.4.22).", k, cls, k)
m9 <- function(o, cls, what, got) sprintf("The option `%s` of `%s` must be %s; got `%s` (rule 1.4.22).", o, cls, what, got)
m10 <- function(fn, f, o) sprintf("The function `%s` of the formatter `%s` takes no argument `%s`, which the formatter declares as an option; add the argument or `...` (rule 1.4.22).", fn, f, o)
m11 <- function(o, f, fn) sprintf("The option `%s` of the formatter `%s` has the name of the first argument of `%s`, which receives the value; rename the option (rule 1.4.22).", o, f, fn)
l1 <- function(k, cls, near) sprintf("`%s` is not an option of `%s`; it is one edit from `%s` (rule 5.3.3).", k, cls, near)
l2 <- function(k, cls) sprintf("`%s` is an option of `%s`, which is not on this construct, so it passes through (rule 5.3.3).", k, cls)

# a config error from a one-class registration with these option lines (a mapping or a list)
fo_cfg_error <- function(options, stage = NULL, cls = ".millions") {
  g2_cfg_err(fo_yml(fo_reg(cls, "in_millions", stage, options)))
}
expect_config_error <- function(e, msg) {
  expect_false(is.null(e), label = "a configuration error was raised")
  expect_true(inherits(e, "weft_config_error"), label = "class weft_config_error")
  expect_identical(conditionMessage(e), msg)
}

# ---- PF1 to PF7: the configuration ------------------------------------------------------------------

test_that("PF1: options as a mapping from name to type is stored as a named character vector", {
  x <- fo_cfg(fo_yml(fo_reg(".millions", "in_millions", "number", c("digits: integer", "word: string"))))
  expect_identical(x$formatters$.millions$options, c(digits = "integer", word = "string"))
})

test_that("PF1: options as a list of names: a weft key gets its own type, any other name gets string", {
  x <- fo_cfg(fo_yml(fo_reg(".millions", "in_millions", "number", NULL), "    options: [digits, word]"))
  expect_identical(x$formatters$.millions$options, c(digits = "integer", word = "string"))
  y <- fo_cfg(fo_yml(fo_reg(".join", "in_millions", "collapse", NULL), "    options: [sep, last, trunc, tag]"))
  expect_identical(y$formatters$.join$options, c(sep = "string", last = "string", trunc = "integer", tag = "string"))
})

test_that("PF1: the block form of a list gives the same vector, in declaration order", {
  x <- fo_cfg(fo_yml(fo_reg(".millions", "in_millions", "number", c("- word", "- digits"))))
  expect_identical(x$formatters$.millions$options, c(word = "string", digits = "integer"))
})

test_that("PF1, PF3: every type is accepted, and a weft key may be written with an empty value or its own type", {
  x <- fo_cfg(fo_yml(fo_reg(".millions", "in_millions", "number",
                            c("digits:", "sigfig: integer", "a: number", "b: integer", "c: string", "d: logical"))))
  expect_identical(x$formatters$.millions$options,
                   c(digits = "integer", sigfig = "integer", a = "number", b = "integer", c = "string", d = "logical"))
  y <- fo_cfg(fo_yml(fo_reg(".join", "in_millions", "collapse", c("sep:", "last: string", "trunc: integer"))))
  expect_identical(y$formatters$.join$options, c(sep = "string", last = "string", trunc = "integer"))
})

test_that("PF1: a single name counts as a list of one", {
  x <- fo_cfg(fo_yml(fo_reg(".millions", "in_millions", "number", NULL), "    options: word"))
  expect_identical(x$formatters$.millions$options, c(word = "string"))
})

test_that("PF1: an absent, empty or null options declares nothing", {
  for (opt in list(NULL, "options:", "options: []", "options: {}")) {
    lines <- fo_yml(fo_reg(".millions", "in_millions", "number", NULL), if (!is.null(opt)) paste0("    ", opt))
    x <- fo_cfg(lines)
    expect_length(x$formatters$.millions$options, 0L)
    expect_identical(x$formatters$.millions[["function"]], "in_millions")
  }
})

test_that("M1: a list holding a non-name, and a mapping whose value is a mapping", {
  e <- g2_cfg_err(fo_yml(fo_reg(".millions", "in_millions", "number", NULL), "    options: [1]"))
  expect_config_error(e, m1(".millions"))
  e2 <- g2_cfg_err(fo_yml(fo_reg(".millions", "in_millions", "number", NULL), "    options: {a: {b: c}}"))
  expect_config_error(e2, m1(".millions"))
})

test_that("M2: a name that is not lower-case snake case", {
  for (bad in c("Scale", "my-opt")) {
    e <- g2_cfg_err(fo_yml(fo_reg(".millions", "in_millions", "number", NULL), paste0("    options: [", bad, "]")))
    expect_config_error(e, m2(bad, ".millions"))
  }
})

test_that("M3: an option declared twice", {
  e <- g2_cfg_err(fo_yml(fo_reg(".millions", "in_millions", "number", NULL), "    options: [word, word]"))
  expect_config_error(e, m3("word", ".millions"))
})

test_that("M4: an unknown type", {
  e <- fo_cfg_error("scale: float", "number")
  expect_config_error(e, m4("scale", ".millions", "float"))
})

test_that("M5: a reserved name cannot be declared", {
  for (nm in c("unit", "n", "target")) {
    e <- g2_cfg_err(fo_yml(fo_reg(".millions", "in_millions", "number", NULL), paste0("    options: [", nm, "]")))
    expect_config_error(e, m5(".millions", nm))
  }
})

test_that("M5: the rest of the reserved names", {
  for (nm in c("if", "sign", "list", "cite", "none", "label", "why", "decision", "claim", "level")) {
    e <- g2_cfg_err(fo_yml(fo_reg(".millions", "in_millions", "number", NULL), paste0("    options: [", nm, "]")))
    expect_config_error(e, m5(".millions", nm))
  }
})

test_that("M6: a weft key of another stage cannot be declared", {
  e <- g2_cfg_err(fo_yml(fo_reg(".millions", "in_millions", "number", NULL), "    options: [sep]"))
  expect_config_error(e, m6(".millions", "sep", "collapse", "number"))
  e2 <- g2_cfg_err(fo_yml(fo_reg(".shout", "toupper", "text", NULL), "    options: [digits]"))
  expect_config_error(e2, m6(".shout", "digits", "number", "text"))
})

test_that("M7: a weft key declared with a type other than its own", {
  e <- fo_cfg_error("digits: string", "number")
  expect_config_error(e, m7("digits", ".millions", "integer", "string"))
})

test_that("W1: an unknown key in a registration is a weft_config_warning and is ignored", {
  lines <- fo_yml(fo_reg(".millions", "in_millions", "number", NULL), "    option: [digits]")
  ws <- fo_warns(x <- g2_cfg(lines))
  hit <- Filter(function(w) inherits(w, "weft_config_warning"), ws)
  expect_length(hit, 1L)
  expect_identical(conditionMessage(hit[[1]]), w1("option", ".millions"))
  expect_length(x$formatters$.millions$options, 0L)
})

test_that("W1: function, stage and options are not unknown keys (control)", {
  lines <- fo_yml(fo_reg(".millions", "in_millions", "number", "word: string"))
  ws <- fo_warns(g2_cfg(lines))
  expect_length(Filter(function(w) inherits(w, "weft_config_warning"), ws), 0L)
})

test_that("PF6: a registration in the front matter replaces the options as a whole; other keys merge", {
  lines <- fo_yml(fo_reg(".millions", "in_millions", "wording", c("digits: integer", "word: string")))
  front <- list(formatters = list(.millions = list(`function` = "other_fn", options = list(word = "string"))))
  x <- fo_cfg(lines, front = front)
  f <- x$formatters$.millions
  expect_identical(f$options, c(word = "string"))        # not c(digits, word)
  expect_identical(f[["function"]], "other_fn")           # the later source's key
  expect_identical(f$stage, "wording")                    # the earlier source's key survives
})

test_that("PF6: a later registration with no options leaves the earlier options alone", {
  lines <- fo_yml(fo_reg(".millions", "in_millions", "number", c("digits: integer", "word: string")))
  front <- list(formatters = list(.millions = list(`function` = "other_fn")))
  x <- fo_cfg(lines, front = front)
  expect_identical(x$formatters$.millions$options, c(digits = "integer", word = "string"))
})

# ---- PF11: the call at each stage -----------------------------------------------------------------------

FO_YML <- fo_yml(
  fo_reg(".fonum", "fo_num", "number", c("digits: integer", "word: string", "flag: logical")),
  fo_reg(".fotext", "fo_txt", "text", c("style: string", "times: integer")),
  fo_reg(".fowording", "fo_wrd", "wording", c("tone: string", "times: integer")),
  fo_reg(".focollapse", "fo_col", "collapse", c("tag: string", "depth: integer")))

test_that("PF11: the number stage receives exactly the options written, in declaration order", {
  st <- fo_rec("fo_num")
  cfg <- fo_cfg(FO_YML)
  out <- fo_apply(1234567, ".fonum", list(word = "M", digits = "2"), cfg)
  expect_length(st$calls, 1L)
  expect_identical(st$calls[[1]], list(digits = 2L, word = "M"))
  expect_identical(as.character(unclass(out)), "<1234567>")
})

test_that("PF11: an option that is not written is not passed; none written gives an empty list", {
  st <- fo_rec("fo_num")
  cfg <- fo_cfg(FO_YML)
  fo_apply(1234567, ".fonum", list(flag = "true"), cfg)
  fo_apply(1234567, ".fonum", list(), cfg)
  expect_identical(st$calls, list(list(flag = TRUE), list()))
})

test_that("PF11: a key matches a declared option in any letter case", {
  st <- fo_rec("fo_num")
  cfg <- fo_cfg(FO_YML)
  fo_apply(1234567, ".fonum", list(Word = "M"), cfg)
  expect_identical(st$calls[[1]], list(word = "M"))
})

test_that("PF11: the text stage receives exactly the options written, in declaration order", {
  st <- fo_rec("fo_txt", function(x) toupper(x))
  cfg <- fo_cfg(FO_YML)
  out <- fo_apply("abc", ".fotext", list(times = "3", style = "loud"), cfg)
  expect_identical(st$calls, list(list(style = "loud", times = 3L)))
  expect_identical(as.character(unclass(out)), "ABC")
})

test_that("PF11: the wording stage receives exactly the options written, in declaration order", {
  st <- fo_rec("fo_wrd")
  cfg <- fo_cfg(FO_YML)
  fo_apply(3, ".fowording", list(times = "2", tone = "dry"), cfg)
  expect_identical(st$calls, list(list(tone = "dry", times = 2L)))
})

test_that("PF11: the collapse stage receives exactly the options written, in declaration order", {
  st <- fo_rec("fo_col", function(x) paste(x, collapse = "+"))
  cfg <- fo_cfg(FO_YML)
  out <- fo_apply(c("a", "b", "c"), ".focollapse", list(depth = "4", tag = "t"), cfg)
  expect_identical(st$calls, list(list(tag = "t", depth = 4L)))
  expect_identical(as.character(unclass(out))[1], "a+b+c")
})

test_that("PF11: the text-class path of apply_text_classes (a string value with a text class) receives the options", {
  st <- fo_rec("fo_txt", function(x) toupper(x))
  fo_install("fo_num", function(x, ...) "n")
  res <- p7_knit(c("A `r \"abc\"`{.fotext style=\"y\"} B."), yml = FO_YML)
  expect_true(any(grepl("ABC", res$text, fixed = TRUE)))
  expect_true(length(st$calls) >= 1L)
  expect_true(all(vapply(st$calls, identical, NA, list(style = "y"))), label = "options of every call")
})

test_that("PF11: a governor span passes the options of a number-stage class", {
  st <- fo_rec("fo_num")
  res <- p7_knit(c("```{r}", "k <- 3", "```", "", "A [# site | # sites]{n=\"k\" .fonum digits=0} B."), yml = FO_YML)
  expect_true(any(grepl("<3>", res$text, fixed = TRUE)))
  expect_true(length(st$calls) >= 1L)
  expect_true(all(vapply(st$calls, identical, NA, list(digits = 0L))), label = "options of every call")
})

test_that("PF11: a text-stage class on a span arm receives the options (the finish() path)", {
  st <- fo_rec("fo_txt", function(x) toupper(x))
  res <- p7_knit(c("```{r}", "k <- 3", "```", "", "A [the # site | the # sites]{n=\"k\" .fotext style=\"x\"} B."),
                 yml = FO_YML)
  expect_true(any(grepl("THE", res$text, fixed = TRUE)))
  expect_true(length(st$calls) >= 1L)
  expect_true(all(vapply(st$calls, identical, NA, list(style = "x"))), label = "options of every call")
})

# ---- PF13: backward compatibility ------------------------------------------------------------------------

test_that("PF13: with no options registered fn(x) is called plainly: substitute(x) still sees x", {
  seen <- NULL
  fo_install("fo_plain", function(x) { seen <<- deparse(substitute(x)); "ok" })
  cfg <- fo_cfg(fo_yml(fo_reg(".foplain", "fo_plain", "number", NULL)))
  fo_apply(1234567, ".foplain", list(), cfg)
  expect_identical(seen, "x")
})

test_that("PF13, PF11: a class that declares options but is written with none is also called as fn(x)", {
  seen <- NULL
  fo_install("fo_plain", function(x, word = "w") { seen <<- deparse(substitute(x)); "ok" })
  cfg <- fo_cfg(fo_yml(fo_reg(".foplain", "fo_plain", "number", "word: string")))
  fo_apply(1234567, ".foplain", list(), cfg)
  expect_identical(seen, "x")
})

test_that("PF13: the same at the text, wording and collapse stages", {
  seen <- character()
  fo_install("fo_plain", function(x) { seen <<- c(seen, deparse(substitute(x))); "ok" })
  cfg <- fo_cfg(fo_yml(fo_reg(".fot", "fo_plain", "text", NULL), fo_reg(".fow", "fo_plain", "wording", NULL),
                       fo_reg(".foc", "fo_plain", "collapse", NULL)))
  fo_apply("abc", ".fot", list(), cfg)
  fo_apply(3, ".fow", list(), cfg)
  fo_apply(c("a", "b"), ".foc", list(), cfg)
  expect_identical(seen, c("x", "x", "x"))
})

test_that("PF13: a class with no options is called as before and a stray option is simply a pass-through key", {
  st <- fo_rec("fo_num")
  cfg <- fo_cfg(fo_yml(fo_reg(".foplain", "fo_num", "number", NULL)))
  fo_apply(5, ".foplain", list(foo = "x"), cfg)
  expect_identical(st$calls, list(list()))
})

# ---- PF10: typing ----------------------------------------------------------------------------------------

FO_TYPES <- fo_yml(fo_reg(".fot", "fo_num", "number",
                          c("scale: number", "times: integer", "flag: logical", "word: string")))

fo_arrives <- function(key, value) {
  st <- fo_rec("fo_num")
  fo_apply(1, ".fot", stats::setNames(list(value), key), fo_cfg(FO_TYPES))
  st$calls[[1]][[key]]
}

test_that("PF10: an integer arrives as an integer of length 1", {
  expect_identical(fo_arrives("times", "2"), 2L)
  expect_identical(fo_arrives("times", " 3 "), 3L)
  expect_identical(fo_arrives("times", "+4"), 4L)
  expect_identical(fo_arrives("times", "-5"), -5L)
})

test_that("PF10: a number arrives as a double of length 1", {
  expect_identical(fo_arrives("scale", "1e3"), 1000)
  expect_identical(fo_arrives("scale", "2"), 2)
  expect_identical(fo_arrives("scale", " 1.5 "), 1.5)
  expect_identical(fo_arrives("scale", ".5"), 0.5)
  expect_identical(fo_arrives("scale", "-2.5E-1"), -0.25)
  expect_identical(fo_arrives("scale", "3."), 3)
})

test_that("PF10: a logical is true or false in any case", {
  expect_identical(fo_arrives("flag", "TRUE"), TRUE)
  expect_identical(fo_arrives("flag", "true"), TRUE)
  expect_identical(fo_arrives("flag", "False"), FALSE)
  expect_identical(fo_arrives("flag", " false "), FALSE)
})

test_that("PF10: a string is kept as written, with its spaces and bar", {
  expect_identical(fo_arrives("word", "  a b  "), "  a b  ")
  expect_identical(fo_arrives("word", "x | y"), "x | y")
  expect_identical(fo_arrives("word", "123"), "123")
})

test_that("M9: a value outside its type, at render", {
  st <- fo_rec("fo_num")
  cfg <- fo_cfg(FO_TYPES)
  bad <- list(
    list("scale", "abc", "a number"), list("scale", "1,5", "a number"), list("scale", "Inf", "a number"),
    list("scale", "", "a number"), list("scale", "1e", "a number"),
    list("times", "2.5", "a whole number"), list("times", "x", "a whole number"),
    list("times", "99999999999", "a whole number"), list("times", "1e3", "a whole number"),
    list("flag", "yes", "true or false"), list("flag", "1", "true or false"), list("flag", "T", "true or false"))
  for (b in bad) {
    e <- fo_err(fo_apply(1, ".fot", stats::setNames(list(b[[2]]), b[[1]]), cfg))
    expect_s3_class(e, "weft_construct_error")
    expect_identical(conditionMessage(e), m9(b[[1]], ".fot", b[[3]], b[[2]]), label = paste(b[[1]], b[[2]]))
  }
  expect_length(st$calls, 0L)    # the function never ran
})

test_that("PF10: a declared weft key arrives as an integer and is checked by weft's own rules", {
  st <- fo_rec("fo_num")
  cfg <- fo_cfg(FO_YML)
  fo_apply(1234567, ".fonum", list(digits = "2"), cfg)
  expect_identical(st$calls[[1]], list(digits = 2L))
  e <- fo_err(fo_apply(1234567, ".fonum", list(digits = "x"), cfg))
  expect_s3_class(e, "weft_construct_error")
})

# ---- PF9: undeclared weft keys ---------------------------------------------------------------------------

FO_NONE <- fo_yml(
  fo_reg(".fomill", "fo_num", "number", "word: string"),
  fo_reg(".focoll", "fo_col", "collapse", "tag: string"))

test_that("M8: digits and sigfig on a number-stage class that does not declare them", {
  fo_rec("fo_num")
  cfg <- fo_cfg(FO_NONE)
  for (k in c("digits", "sigfig")) {
    e <- fo_err(fo_apply(1234567, ".fomill", stats::setNames(list("2"), k), cfg))
    expect_s3_class(e, "weft_construct_error")
    expect_identical(conditionMessage(e), m8(k, ".fomill"), label = k)
  }
})

test_that("M8: sep and trunc on a collapse-stage class that does not declare them", {
  fo_rec("fo_col", function(x) paste(x, collapse = "+"))
  cfg <- fo_cfg(FO_NONE)
  for (kv in list(c("sep", "; "), c("trunc", "2"))) {
    e <- fo_err(fo_apply(c("a", "b", "c"), ".focoll", stats::setNames(list(kv[2]), kv[1]), cfg))
    expect_s3_class(e, "weft_construct_error")
    expect_identical(conditionMessage(e), m8(kv[1], ".focoll"), label = kv[1])
  }
})

test_that("M8: the declared option of the class is not an error (control)", {
  st <- fo_rec("fo_num")
  cfg <- fo_cfg(FO_NONE)
  expect_no_error(fo_apply(1234567, ".fomill", list(word = "M"), cfg))
  expect_identical(st$calls, list(list(word = "M")))
})

test_that("M8: a weft key the class declares is passed, not an error (control)", {
  st <- fo_rec("fo_num")
  cfg <- fo_cfg(fo_yml(fo_reg(".fomill", "fo_num", "number", "digits: integer")))
  expect_no_error(fo_apply(1234567, ".fomill", list(digits = "1"), cfg))
  expect_identical(st$calls, list(list(digits = 1L)))
})

# ---- PF12: checking the function -------------------------------------------------------------------------

test_that("M10: a declared option the function has no argument for, whether or not it is written", {
  fo_install("fo_one", function(x) "ok")
  cfg <- fo_cfg(fo_yml(fo_reg(".fostrict", "fo_one", "number", "word: string")))
  for (keys in list(list(), list(word = "M"))) {
    e <- fo_err(fo_apply(1234567, ".fostrict", keys, cfg))
    expect_s3_class(e, "weft_construct_error")
    expect_identical(conditionMessage(e), m10("fo_one", ".fostrict", "word"))
  }
})

test_that("M10: a function with ... takes any declared option", {
  fo_install("fo_dots", function(x, ...) "ok")
  cfg <- fo_cfg(fo_yml(fo_reg(".fostrict", "fo_dots", "number", "word: string")))
  expect_no_error(fo_apply(1234567, ".fostrict", list(word = "M"), cfg))
  expect_no_error(fo_apply(1234567, ".fostrict", list(), cfg))
})

test_that("M10: a function whose arguments cover the options is fine (control)", {
  fo_install("fo_args", function(x, word = "w") "ok")
  cfg <- fo_cfg(fo_yml(fo_reg(".fostrict", "fo_args", "number", "word: string")))
  expect_no_error(fo_apply(1234567, ".fostrict", list(word = "M"), cfg))
})

test_that("M11: an option named like the first argument", {
  fo_install("fo_first", function(x, y = 1) "ok")
  cfg <- fo_cfg(fo_yml(fo_reg(".fofirst", "fo_first", "number", "x: string")))
  e <- fo_err(fo_apply(1234567, ".fofirst", list(), cfg))
  expect_s3_class(e, "weft_construct_error")
  expect_identical(conditionMessage(e), m11("x", ".fofirst", "fo_first"))
  fo_install("fo_value", function(value, ...) "ok")
  cfg2 <- fo_cfg(fo_yml(fo_reg(".fofirst", "fo_value", "number", "value: string")))
  e2 <- fo_err(fo_apply(1234567, ".fofirst", list(value = "a"), cfg2))
  expect_s3_class(e2, "weft_construct_error")
  expect_identical(conditionMessage(e2), m11("value", ".fofirst", "fo_value"))
})

test_that("M10: a function with no formals other than the value, as a text-stage class", {
  fo_install("fo_one", function(x) toupper(x))
  cfg <- fo_cfg(fo_yml(fo_reg(".foup", "fo_one", "text", "style: string")))
  e <- fo_err(fo_apply("abc", ".foup", list(style = "s"), cfg))
  expect_s3_class(e, "weft_construct_error")
  expect_identical(conditionMessage(e), m10("fo_one", ".foup", "style"))
})

# ---- PF8: two classes declaring the same name --------------------------------------------------------------

test_that("PF8: two classes on one construct that declare the same name each receive the one value", {
  a <- fo_rec("fo_a", function(x) paste0("A", x))
  b <- fo_rec("fo_b", function(x) toupper(x))
  cfg <- fo_cfg(fo_yml(fo_reg(".fomany", "fo_a", "number", "times: integer"),
                       fo_reg(".fotxt", "fo_b", "text", "times: string")))
  fo_apply(7, c(".fomany", ".fotxt"), list(times = "2"), cfg)
  expect_identical(a$calls, list(list(times = 2L)))       # parsed by its own type
  expect_identical(b$calls, list(list(times = "2")))
})

# ---- the scanner -------------------------------------------------------------------------------------------

FO_SCAN <- fo_yml(
  fo_reg(".fomill", "fo_num", "number", c("word: string", "times: integer", "scale: number")),
  fo_reg(".fonum", "fo_num", "number", c("digits: integer", "word: string")))

test_that("M8: the scanner finds an undeclared weft key from the source", {
  p7_cfg(FO_SCAN)
  errs <- p7_scan_errs("A `r 3`{.fomill digits=\"2\"} B.")
  expect_true(any(errs == m8("digits", ".fomill")), label = paste(errs, collapse = " / "))
  errs2 <- p7_scan_errs("A `r 3`{.fomill sigfig=\"2\"} B.")
  expect_true(any(errs2 == m8("sigfig", ".fomill")), label = paste(errs2, collapse = " / "))
})

test_that("M9: the scanner finds a value outside its type from the source", {
  p7_cfg(FO_SCAN)
  errs <- p7_scan_errs("A `r 3`{.fomill times=\"x\"} B.")
  expect_true(any(errs == m9("times", ".fomill", "a whole number", "x")), label = paste(errs, collapse = " / "))
  errs2 <- p7_scan_errs("A `r 3`{.fomill scale=\"big\"} B.")
  expect_true(any(errs2 == m9("scale", ".fomill", "a number", "big")), label = paste(errs2, collapse = " / "))
})

test_that("PF8: a legal construct scans clean, in any letter case of the option (control)", {
  p7_cfg(FO_SCAN)
  expect_identical(p7_scan_errs("A `r 3`{.fomill times=\"2\" Word=\"M\" scale=\"1e3\"} B."), character())
  expect_identical(p7_scan_errs("A `r 3`{.fonum digits=\"2\"} B."), character())
})

test_that("PF8: Scale=2 scale=3 is the 1.2.10 duplicate", {
  p7_cfg(FO_SCAN)
  errs <- p7_scan_errs("A `r 3`{.fomill Scale=\"2\" scale=\"3\"} B.")
  expect_true(any(errs == "The key `scale` is written twice in one block (rule 1.2.10)."),
              label = paste(errs, collapse = " / "))
})

test_that("PF16: a named value gets no PF9 or PF10 error from the scanner", {
  p7_cfg(FO_SCAN)
  errs <- p7_scan_errs("A `depth`{.fomill digits=\"2\" times=\"x\"} B.")
  expect_false(any(grepl("rule 1.4.22", errs, fixed = TRUE)), label = paste(errs, collapse = " / "))
})

# ---- PF15: lint name -----------------------------------------------------------------------------------------

FO_LINT <- c("formatters:", "  .millions:", "    function: in_millions", "    stage: number",
             "    options:", "      scale: number", "      lest: string")

fo_name_findings <- function(src, ext) lf_by_rule(lint_one(src, rules = "name", ext = ext, weft_yml = FO_LINT), "name")

test_that("PF15: an option the construct's project class declares is not listed, in any letter case", {
  for (ext in c("qmd", "Rmd")) {
    expect_identical(fo_name_findings(c3_para("`r 1`{.millions scale=2}"), ext)$text, character(), label = ext)
    expect_identical(fo_name_findings(c3_para("`r 1`{.millions Scale=2}"), ext)$text, character(), label = ext)
  }
})

test_that("L1: a key one edit from a declared option", {
  for (ext in c("qmd", "Rmd")) {
    x <- fo_name_findings(c3_para("`r 1`{.millions scael=2}"), ext)
    expect_identical(x$text, "scael", label = ext)
    expect_identical(x$message, l1("scael", ".millions", "scale"), label = ext)
    expect_identical(x$tier, 2L)
  }
})

test_that("L1 is checked before the weft-name near miss", {
  # `lst` is one edit from the option `lest` and from the weft key `list`
  x <- fo_name_findings(c3_para("`r 1`{.millions lst=2}"), "qmd")
  expect_identical(x$message, l1("lst", ".millions", "lest"))
})

test_that("L2: an option of a project class that is not on the construct passes through", {
  for (ext in c("qmd", "Rmd")) {
    x <- fo_name_findings(c3_para("`r 1`{.num scale=2}"), ext)
    expect_identical(x$text, "scale", label = ext)
    expect_identical(x$message, l2("scale", ".millions"), label = ext)
    expect_identical(x$tier, 2L)
  }
})

test_that("PF15: an unknown key foo on a project-class construct is listed as today", {
  for (ext in c("qmd", "Rmd")) {
    x <- fo_name_findings(c3_para("`r 1`{.millions foo=2}"), ext)
    expect_identical(x$text, "foo", label = ext)
    expect_identical(x$message, "`foo` is not a name weft knows on a construct (rule 5.3.3).", label = ext)
  }
})

# ---- PF16: the Lua config reader -----------------------------------------------------------------------------

FO_VE <- "<<weft: value error, line {L}>>"
fo_values_block <- function() carrier(f1 = fr_float("1234.5"))

test_that("PF16: block and flow options: raise no configuration problem, and E21 is still raised", {
  cases <- c(a = "A `f1`{.compact} z.")
  yml_block_map <- c("formatters:", "  .compact:", "    function: myproject::fmt_compact", "    stage: number",
                     "    options:", "      digits: integer", "      word: string")
  yml_block_seq <- c("formatters:", "  .compact:", "    function: myproject::fmt_compact", "    stage: number",
                     "    options:", "      - digits", "      - word")
  yml_flow <- c("formatters: {.compact: {function: myproject::fmt_compact, stage: number, options: {digits: integer, word: string}}}")
  yml_flow_seq <- c("formatters: {.compact: {function: myproject::fmt_compact, options: [digits, word]}}")
  for (yml in list(yml_block_map, yml_block_seq, yml_flow, yml_flow_seq)) {
    res <- filter_cases(cases, list(fo_values_block()), draft = TRUE, weft_yml = yml)
    expect_identical(res$status, 0L)
    expect_cases(res, c(a = paste0("A ", FO_VE, " z.")))
    expect_true(grepl(fm_msg$E21("compact"), res$stderr, fixed = TRUE), label = paste(yml, collapse = " / "))
    expect_false(grepl("_weft.yml:", res$stderr, fixed = TRUE), label = "no configuration problem")
  }
})

test_that("PF16: a setting after a formatter with options: is still read", {
  yml <- c("formatters:", "  .compact:", "    function: myproject::fmt_compact", "    options:", "      digits: integer",
           "digits: 2")
  res <- filter_cases(c(g = "`g`{.num}"), list(carrier(g = fr_float("3.14159"))), weft_yml = yml)
  expect_cases(res, c(g = "3.14"))
})

# ---- one render and one ledger test ----------------------------------------------------------------------------

FO_RENDER_YML <- c("formatters:", "  .millions:", "    function: in_millions", "    stage: number",
                   "    options:", "      digits: integer", "      word: string")

test_that("PF11: a render passes the options to the function and keeps the other keys as attributes", {
  fo_in_millions()
  res <- p7_knit(c("```{r}", "v <- 1234567", "```", "",
                   "A `r v`{.millions digits=2 foo=\"x\"} B.", "",
                   "C `r v`{.millions word=\"M\"} D.", "",
                   "E `r v`{.millions} F."), yml = FO_RENDER_YML)
  txt <- paste(res$text, collapse = "\n")
  expect_true(grepl("A [1.23 million]{foo=\"x\"} B.", txt, fixed = TRUE), label = txt)
  expect_true(grepl("C 1.2 M D.", txt, fixed = TRUE), label = txt)
  expect_true(grepl("E 1.2 million F.", txt, fixed = TRUE), label = txt)
})

test_that("PF17: changing an option value on a project class changes the ledger entry's text and not its key", {
  fo_in_millions()
  run <- function(d) {
    res <- d2_run(c("```{r}", "v <- 1234567", "```", "", sprintf("A `r v`{.millions digits=%d} B.", d)),
                  files = list("_weft.yml" = c("draft: false", FO_RENDER_YML)))
    d2_pick(d2_ledger(res), expr = "v")
  }
  a <- run(1L)
  b <- run(2L)
  expect_length(a, 1L)
  expect_length(b, 1L)
  for (f in c("file", "section", "kind", "expr", "occ", "id")) {
    expect_identical(a[[1]][[f]], b[[1]][[f]], label = f)
  }
  expect_false(identical(a[[1]]$text, b[[1]]$text))
  expect_match(a[[1]]$text, "1.2 million", fixed = TRUE)
  expect_match(b[[1]]$text, "1.23 million", fixed = TRUE)
})
