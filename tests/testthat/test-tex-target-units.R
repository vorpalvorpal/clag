# The TeX target of the formatters, part 2: units (TX7, E102) and project formatters (TX8, E104, E105).
# Part 1 is test-tex-target.R. Specification: dev/design-9.md (rule 1.4.22 of the design is read as 1.4.23).
# Helpers used: helper-2g.R (g2_cfg, g2_cfg_err, g2_u, g2_restore), helper-2f.R (f2_tx, f2_cond). ASCII only.

# ---- helpers (as in test-tex-target.R) ----

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

e102 <- function(tok, shown) {
  sprintf(paste0("The unit `%s` prints as \"%s\", which holds markdown with no TeX form (only ^...^, ~...~ and ",
                 "backslash escapes have one). Give it a plain `symbol:` or `name:` under `units:` in _weft.yml ",
                 "to use it in math (rule 4.4.25)."), tok, shown)
}
e104 <- function(f, got) sprintf("The formatter `%s` has `targets: %s`; `targets` lists markdown and, optionally, tex (rule 1.4.8).", f, got)
e105 <- function(f, fn) sprintf("The formatter `%s` lists tex in `targets:`, so its function `%s` must take an argument `target` (rule 1.4.8).", f, fn)


# ---- TX7: units ---------------------------------------------------------------------------------------------------

DEG <- "\u00b0"

test_that("TX7: the table of units, under target = \"tex\"", {
  cfg <- tt_cfg()
  cases <- list(
    list(u(5, "mg/L"), ".num", r"(5\,\text{mg/L})"),
    list(u(5, "m^2"), ".num", r"(5\,\text{m}^{2})"),
    list(u(5, "m-3"), ".num", r"(5\,\text{m}^{-3})"),
    list(u(5, "s^-1"), ".num", r"(5\,\text{s}^{-1})"),
    list(u(20, "degC"), ".num", paste0("20\\,\\text{", DEG, "C}")),
    list(g2_u(45, DEG), ".num", paste0("45\\text{", DEG, "}")),
    list(u(5, "kg*m/s^2"), ".num", r"(5\,\text{kg}{\cdot}\text{m/s}^{2})"),
    list(u(30, "%"), ".num", r"(30\%)"),
    list(u(5, "CFU/100mL"), ".num", r"(5\,\text{CFU/100}\,\text{mL})"),
    list(u(5, "mg/L"), ".uname", r"(5\ \text{milligrams per litre})"),
    list(u(1, "m"), ".uname", r"(1\ \text{metre})"),
    list(u(5, "mg/L"), ".nounit", "5"),
    list(u(c(1.2, 3.4), "m"), ".range", r"(1.2\ \text{to}\ 3.4\,\text{m})"),
    list(u(7, "pH"), ".num", r"(\text{pH}\,7)"))
  for (cs in cases) {
    expect_identical(tt_run(cs[[1]], cs[[2]], list(), cfg), cs[[3]], label = cs[[3]])
  }
})

test_that("TX7: unit characters that are not ASCII pass through inside \\text{}", {
  # the symbol is whatever the units database gives for the markdown form
  cfg <- tt_cfg()
  md <- f2_tx(tt_md(u(5, "ohm"), ".num", list(), cfg))
  sym <- sub(paste0("^5", NBSP), "", md)
  expect_false(identical(sym, md))
  expect_identical(tt_run(u(5, "ohm"), ".num", list(), cfg), paste0("5\\,\\text{", sym, "}"))
})

test_that("TX7: fmt_unit() under target = \"tex\" is the symbol alone", {
  g2_restore()
  expect_identical(f2_tx(fmt_unit(u(5, "mg/L"), target = "tex")), r"(\text{mg/L})")
  expect_identical(f2_tx(fmt_unit(u(5, "m^2"), target = "tex")), r"(\text{m}^{2})")
  expect_identical(f2_tx(fmt_unit(u(5, "mg/L"), target = "markdown")), "mg/L")
  expect_identical(f2_tx(fmt_unit(u(5, "mg/L"))), "mg/L")
})

test_that("TX7: the unit through fmt_num(), fmt_range() and unit_form", {
  g2_restore()
  expect_identical(f2_tx(fmt_num(u(5, "mg/L"), target = "tex")), r"(5\,\text{mg/L})")
  expect_identical(f2_tx(fmt_num(u(5, "mg/L"), unit_form = "name", target = "tex")), r"(5\ \text{milligrams per litre})")
  expect_identical(f2_tx(fmt_num(u(5, "mg/L"), unit_form = "none", target = "tex")), "5")
  expect_identical(f2_tx(fmt_range(u(c(1.2, 3.4), "m"), target = "tex")), r"(1.2\ \text{to}\ 3.4\,\text{m})")
})

test_that("TX7: under markdown the same units print as today, with and without target", {
  g2_restore()
  expect_identical(f2_tx(fmt_num(u(5, "mg/L"))), paste0("5", NBSP, "mg/L"))
  expect_identical(f2_tx(fmt_num(u(5, "m-3"))), paste0("5", NBSP, "m^", MINUS_U, "3^"))
  expect_identical(f2_tx(fmt_num(u(5, "kg*m/s^2"))), paste0("5", NBSP, "kg\u00b7m/s^2^"))
  expect_identical(f2_tx(fmt_num(u(5, "mg/L"), target = "markdown")), paste0("5", NBSP, "mg/L"))
  expect_identical(f2_tx(fmt_num(u(5, "m-3"), target = "markdown")), paste0("5", NBSP, "m^", MINUS_U, "3^"))
  expect_identical(f2_tx(fmt_num(u(5, "kg*m/s^2"), target = "markdown")), paste0("5", NBSP, "kg\u00b7m/s^2^"))
})

# project units whose symbol holds a character TX7 maps; space: false so that only the symbol shows
tt_units_yml <- function(symbols) {
  toks <- paste0("zzth", letters[seq_along(symbols)])
  yml <- "units:"
  for (i in seq_along(symbols)) {
    sym <- symbols[[i]]
    quoted <- if (grepl("\"", sym, fixed = TRUE)) sprintf("'%s'", sym) else sprintf("\"%s\"", sym)
    yml <- c(yml, paste0("  ", toks[i], ":"), "    is: base", paste0("    symbol: ", quoted), "    name: quark",
             "    space: false")
  }
  list(yml = yml, toks = toks)
}

test_that("TX7: the characters TX6 maps single, in a project unit's symbol", {
  s <- tt_units_yml(c("a%b", "a$b", "a&b", "a#b", "a<b", "a>b", "a|b", "a{b}"))
  cfg <- tt_cfg(s$yml)
  want <- c(r"(5\text{a}\%\text{b})", r"(5\text{a}\$\text{b})", r"(5\text{a}\&\text{b})", r"(5\text{a}\#\text{b})",
            r"(5\text{a}<\text{b})", r"(5\text{a}>\text{b})", r"(5\text{a}|\text{b})", r"(5\text{a}\{\text{b}\})")
  for (i in seq_along(want)) expect_identical(tt_run(g2_u(5, s$toks[i]), ".num", list(), cfg), want[i], label = want[i])
})

test_that("TX7: ^...^ and ~...~ become a superscript and a subscript, U+2212 becomes `-`, primes and the dot", {
  s <- tt_units_yml(c("a^2^", "a~i~", "a^\u22123^", "\u2032", "'", "\u2033", "\"", "a\u00b7b", paste0("a", NBSP, "b")))
  cfg <- tt_cfg(s$yml)
  want <- c(r"(5\text{a}^{2})", r"(5\text{a}_{i})", r"(5\text{a}^{-3})", r"(5{}^{\prime})", r"(5{}^{\prime})",
            r"(5{}^{\prime\prime})", r"(5{}^{\prime\prime})", r"(5\text{a}{\cdot}\text{b})", r"(5\text{a}\,\text{b})")
  for (i in seq_along(want)) expect_identical(tt_run(g2_u(5, s$toks[i]), ".num", list(), cfg), want[i], label = want[i])
})

test_that("TX7: the unit's space is `\\,` when it is on", {
  cfg <- tt_cfg(c("units:", "  zzthz:", "    is: base", "    symbol: zq", "    name: quark", "    space: true"))
  expect_identical(tt_run(g2_u(5, "zzthz"), ".num", list(), cfg), r"(5\,\text{zq})")
  expect_identical(f2_tx(tt_md(g2_u(5, "zzthz"), ".num", list(), cfg)), paste0("5", NBSP, "zq"))
})

test_that("E102, TX7: markdown with no TeX form in a project symbol is a weft_value_error", {
  # READING: the first %s is the unit as written in u() (the token), the second the markdown the symbol prints as.
  for (sym in c("*x*", "a_b", "a[b]", "a`b")) {
    cfg <- tt_cfg(c("units:", "  zzthe:", "    is: base", sprintf("    symbol: '%s'", sym), "    name: quark"))
    e <- tt_err(weft:::apply_formatters(g2_u(5, "zzthe"), ".num", config = cfg, target = "tex"))
    expect_tt_error(e, "weft_value_error", e102("zzthe", sym))
    # the markdown form of the same unit is not an error, and is today's
    expect_identical(f2_tx(tt_md(g2_u(5, "zzthe"), ".num", list(), cfg)), paste0("5", NBSP, sym))
    expect_identical(tt_run(g2_u(5, "zzthe"), ".num", list(), cfg, target = "markdown"), paste0("5", NBSP, sym))
  }
})

test_that("E102, TX7: the same for a project name, when the name is what prints", {
  cfg <- tt_cfg(c("units:", "  zzthn:", "    is: base", "    name: '*quark*'"))
  e <- tt_err(weft:::apply_formatters(g2_u(5, "zzthn"), ".uname", config = cfg, target = "tex"))
  expect_s3_class(e, "weft_value_error")
  expect_match(conditionMessage(e), "^The unit `zzthn` prints as \"", perl = TRUE)
  expect_match(conditionMessage(e), "(rule 4.4.25).", fixed = TRUE)
})

test_that("E102, TX7: a backslash-escaped marker is not an error (only unescaped ones are)", {
  cfg <- tt_cfg(c("units:", "  zzthb:", "    is: base", "    symbol: 'a\\*b'", "    name: quark", "    space: false"))
  expect_no_error(tt_run(g2_u(5, "zzthb"), ".num", list(), cfg))
})

# ---- TX8: project formatters ----------------------------------------------------------------------------------------

tt_install <- function(name, fn, env = parent.frame()) {
  assign(name, fn, envir = globalenv())
  withr::defer(rm(list = name, envir = globalenv()), envir = env)
  invisible(fn)
}
# records every call's extra arguments; returns "<x>/<target>" when it has a target, "<x>" otherwise
tt_rec <- function(name, with_target = TRUE, env = parent.frame()) {
  store <- new.env()
  store$calls <- list()
  fn <- if (with_target) function(x, ...) {
    store$calls <- c(store$calls, list(list(...)))
    paste0(as.character(unclass(x)), "/", list(...)$target)
  } else function(x) {
    store$calls <- c(store$calls, list(list()))
    paste0(as.character(unclass(x)))
  }
  tt_install(name, fn, env = env)
  store
}
tt_reg <- function(cls, fn, extra = NULL) {
  c("formatters:", paste0("  ", cls, ":"), paste0("    function: ", fn), "    stage: number", extra)
}
tt_proj <- function(cfg, value, cls, keys = list(), target = NULL) {
  args <- list(value, cls, keys, config = cfg)
  if (!is.null(target)) args$target <- target
  suppressWarnings(f2_tx(do.call(weft:::apply_formatters, args)))
}

test_that("TX8: targets: [markdown, tex] calls the function with `target`, for every target", {
  st <- tt_rec("tt_both")
  cfg <- tt_cfg(tt_reg(".ttboth", "tt_both", "    targets: [markdown, tex]"))
  expect_identical(tt_proj(cfg, 5, ".ttboth", target = "tex"), "5/tex")
  expect_identical(tt_proj(cfg, 5, ".ttboth", target = "markdown"), "5/markdown")
  expect_identical(tt_proj(cfg, 5, ".ttboth"), "5/markdown")
  expect_identical(st$calls, list(list(target = "tex"), list(target = "markdown"), list(target = "markdown")))
})

test_that("TX8: `target` arrives after any options", {
  st <- tt_rec("tt_opt")
  cfg <- tt_cfg(tt_reg(".ttopt", "tt_opt", c("    options: [word]", "    targets: [markdown, tex]")))
  tt_proj(cfg, 5, ".ttopt", list(word = "M"), target = "tex")
  tt_proj(cfg, 5, ".ttopt", list(word = "M"))
  expect_identical(st$calls[[1]], list(word = "M", target = "tex"))
  expect_identical(st$calls[[2]], list(word = "M", target = "markdown"))
})

test_that("TX8: without `targets:` (or with targets: [markdown]) the call is fn(x), as today", {
  st <- tt_rec("tt_one", with_target = FALSE)
  for (extra in list(NULL, "    targets: [markdown]")) {
    st$calls <- list()
    cfg <- tt_cfg(tt_reg(".ttone", "tt_one", extra))
    expect_identical(tt_proj(cfg, 5, ".ttone"), "5")
    expect_identical(tt_proj(cfg, 5, ".ttone", target = "markdown"), "5")
    expect_identical(st$calls, list(list(), list()))
  }
})

test_that("TX8, E105: a formatter that lists tex must take `target` (or `...`), at resolution", {
  # READING: E105 is a weft_construct_error (as the argument checks of apply_project are), raised whichever
  # target the call has; the first %s is the class as written, the second the function's name.
  tt_install("tt_notarget", function(x) "ok")
  cfg <- tt_cfg(tt_reg(".ttnt", "tt_notarget", "    targets: [markdown, tex]"))
  for (tg in list(NULL, "markdown", "tex")) {
    e <- tt_err(tt_proj(cfg, 5, ".ttnt", target = tg))
    expect_tt_error(e, "weft_construct_error", e105(".ttnt", "tt_notarget"))
  }
  tt_install("tt_dots", function(x, ...) "ok")
  expect_identical(tt_proj(tt_cfg(tt_reg(".ttd", "tt_dots", "    targets: [markdown, tex]")), 5, ".ttd", target = "tex"), "ok")
  tt_install("tt_formal", function(x, target) paste0("ok-", target))
  expect_identical(tt_proj(tt_cfg(tt_reg(".ttf", "tt_formal", "    targets: [markdown, tex]")), 5, ".ttf", target = "tex"), "ok-tex")
})

test_that("TX8, E104: `targets:` lists markdown and, optionally, tex: anything else is a weft_config_error", {
  # READING: the %s after `targets:` is the written list joined by ", " ("tex", "markdown, pdf", "").
  tt_install("tt_notarget", function(x, ...) "ok")
  bad <- list(
    list("[tex]", "tex"), list("[pdf]", "pdf"), list("[markdown, pdf]", "markdown, pdf"),
    list("[markdown, tex, html]", "markdown, tex, html"), list("[]", ""))
  for (b in bad) {
    e <- g2_cfg_err(tt_reg(".ttbad", "tt_notarget", paste0("    targets: ", b[[1]])))
    expect_tt_error(e, "weft_config_error", e104(".ttbad", b[[2]]))
  }
})

test_that("TX8: the accepted forms of `targets:` read without error", {
  tt_install("tt_notarget", function(x, ...) "ok")
  for (t in c("[markdown]", "[markdown, tex]", "[tex, markdown]")) {
    expect_null(g2_cfg_err(tt_reg(".ttok", "tt_notarget", paste0("    targets: ", t))), label = t)
  }
})

# ---- omitting `target` changes nothing ----------------------------------------------------------------------------------

test_that("TX3: a formatter result for a markdown call is identical whether the argument is omitted or \"markdown\"", {
  cfg <- tt_cfg(c("big_mark: \" \"", "decimal_mark: \",\"", "p_label: \"*p*\""))
  vals <- list(list(1234567.89, ".num"), list(0.123, ".pct"), list(1234567, ".sci"), list(0.03, ".p"),
               list(c(1.2, 3.4), ".range"), list(u(5, "kg*m/s^2"), ".num"), list(u(5, "mg/L"), ".uname"),
               list(3, ".word"), list(c("a", "b", "c"), ".and"), list("a", ".strong"), list(3, c(".num", ".plus")))
  for (v in vals) {
    a <- suppressWarnings(weft:::apply_formatters(v[[1]], v[[2]], config = cfg))
    b <- suppressWarnings(weft:::apply_formatters(v[[1]], v[[2]], config = cfg, target = "markdown"))
    expect_identical(b, a, label = paste(v[[2]], collapse = " "))
    expect_null(attr(a, "target"))
  }
})
