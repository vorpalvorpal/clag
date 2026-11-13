# Package 2f: unit_form and units: in _weft.yml and front matter; lang en-US and de.
# Contract: dev/design-2f.md "Configuration and dictionary fields", "Another lang", "Errors";
# U8, U13-U17, U21. Rules 9.1.1, 9.1.2, 9.1.5, 9.1.6, 9.1.7, 1.6.8.
# `~` in an expected string is U+00A0.
if (!exists("f2_ws")) source(testthat::test_path("helper-2f.R"))
if (!exists("render_rmd")) source(testthat::test_path("..", "helper-render.R"))

cfg2 <- function(dir, front = list()) weft:::read_config(dir, front = front)

# ---- unit_form --------------------------------------------------------------------------------------------

test_that("2f config: with no _weft.yml unit_form is auto and units is empty (9.1.5)", {
  withr::local_envvar(WEFT_DRAFT = NA)
  x <- cfg2(f2_proj())
  expect_equal(x$unit_form, "auto")
  expect_length(x$units, 0L)
})

test_that("2f config: _weft.yml sets unit_form to name or symbol (9.1.2, 9.1.6)", {
  withr::local_envvar(WEFT_DRAFT = NA)
  expect_no_warning(x <- cfg2(f2_proj("unit_form: name")))       # a known setting, not "ignored"
  expect_equal(x$unit_form, "name")
  expect_equal(cfg2(f2_proj("unit_form: symbol"))$unit_form, "symbol")
  expect_equal(cfg2(f2_proj("unit_form: auto"))$unit_form, "auto")
})

test_that("2f config: front matter overrides the project's unit_form (9.1.1)", {
  withr::local_envvar(WEFT_DRAFT = NA)
  d <- f2_proj("unit_form: name")
  expect_no_warning(x <- cfg2(d, front = list(unit_form = "symbol")))
  expect_equal(x$unit_form, "symbol")
  expect_equal(cfg2(d)$unit_form, "name")
})

test_that("2f config: a unit_form that is not auto, symbol or name is a config error (9.1.6)", {
  withr::local_envvar(WEFT_DRAFT = NA)
  for (bad in c("none", "bogus", "Name")) {
    e <- f2_cond(cfg2(f2_proj(paste0("unit_form: ", bad))))
    f2_has_class(e, "weft_config_error")
    f2_msg_has(e, "unit_form")
    f2_msg_has(e, "auto")
    f2_msg_has(e, "symbol")
  }
  e2 <- f2_cond(cfg2(f2_proj(), front = list(unit_form = "bogus")))
  f2_has_class(e2, "weft_config_error")
  f2_msg_has(e2, "unit_form")
  f2_has_class(f2_cond(cfg2(f2_proj("unit_form: [name, symbol]"))), "weft_config_error")
  f2_has_class(f2_cond(cfg2(f2_proj("unit_form: 5"))), "weft_config_error")
})

test_that("2f config: the project's unit_form applies to every use, and the use wins (Forms)", {
  f2_rows(c("`r u(5, m)`{.num}", "`r u(5, m)`{.usym}", "`r u(5, m)`{.nounit}", "`r u(c(3, 5), m)`{.and}"),
          c("5~metres", "5~m", "5", "3 and 5~metres"), "unit_form: name")
  f2_rows(c("`r u(5, m)`{.num}", "`r u(5, m)`{.uname}"), c("5~m", "5~metres"), "unit_form: auto")
})

test_that("2f config: unit_form symbol leaves digits as symbols and a spelled number is a value error (U4)", {
  expect_equal(f2_ws("`r u(5, m)`{.num}", "unit_form: symbol"), f2("5~m"))
  expect_equal(f2_ws("`r u(5, year)`{.num}", "unit_form: symbol"), f2("5~years"))
  f2_has_class(f2_err("`r u(5, m)`{.word}", "unit_form: symbol"), "weft_value_error")
})

test_that("2f config: settings apply to anything, so unit_form name does not error on a number or a ratio (Forms)", {
  expect_equal(f2_ws("`r 5`{.num}", "unit_form: name"), "5")
  expect_equal(f2_ws("`r u(6, m) / u(3, m)`{.num}", "unit_form: name"), "2")
  expect_equal(f2_ws("`r 5`{.word}", "unit_form: symbol"), "five")
})

# ---- units: the table (9.1.7) ----------------------------------------------------------------------------------

test_that("2f units: name, plural, symbol and space are read per unit, and a read registers the keys (9.1.7, U16)", {
  withr::local_envvar(WEFT_DRAFT = NA)
  expect_error(u(3, zzqa), class = "weft_unit_error")                                   # not known before the read
  x <- cfg2(f2_proj(c("units:", "  zzqa:", "    name: quark", "    plural: quarks")))
  expect_gt(length(x$units), 0L)
  expect_no_error(u(3, zzqa))                                # known after, with no dictionary
})

test_that("2f units: a key written as u() takes one, a compound key registers its tokens (4.4.7, U16)", {
  withr::local_envvar(WEFT_DRAFT = NA)
  expect_error(u(3, zzqb / zzqc), class = "weft_unit_error")
  cfg2(f2_proj(c("units:", "  zzqb/zzqc:", "    name: quark per charm")))
  expect_no_error(u(3, zzqb / zzqc))
  expect_equal(f2_tx(fmt_unit(u(3, zzqb / zzqc), unit_form = "name")), "quarks per charm")
})

test_that("2f units: after the read u() works in weft_str with no dictionary (9.1.7)", {
  expect_equal(f2_ws("`r u(3, zzqd)`{.num}", c("units:", "  zzqd:", "    name: quark")), f2("3~quarks"))        # 2i I5: a name and no symbol prints by name
  expect_equal(f2_ws("`r u(3, zzqd)`{.uname}", c("units:", "  zzqd:", "    name: quark")), f2("3~quarks"))
})

test_that("2f units: symbol false prints the name in every form (9.1.7)", {
  yml <- c("units:", "  d:", "    symbol: false")
  f2_rows(c("`r u(5, d)`{.num}", "`r u(1, d)`{.num}", "`r u(5, d)`{.uname}"), c("5~days", "1~day", "5~days"), yml)
})

test_that("2f units: symbol text replaces the unit's text, printed as markdown as written (U14, U15)", {
  yml <- c("units:", "  zzqe:", "    name: quark", "    symbol: \"*q*^2^\"")
  expect_equal(f2_ws("`r u(3, zzqe)`{.num}", yml), f2("3~*q*^2^"))
  yml2 <- c("units:", "  CFU/100 mL:", "    name: colony-forming unit per 100 millilitres",
            "    plural: colony-forming units per 100 millilitres", "    symbol: CFU/100 mL")
  f2_register()
  expect_equal(f2_ws("`r u(150, \"CFU/100 mL\")`{.num}", yml2), f2("150~CFU/100 mL"))
  expect_equal(f2_ws("`r u(150, \"CFU/100 mL\")`{.uname}", yml2),
               f2("150~colony-forming units per 100 millilitres"))
  expect_equal(f2_ws("`r u(1, \"CFU/100 mL\")`{.uname}", yml2),
               f2("1~colony-forming unit per 100 millilitres"))
})

test_that("2f units: a symbol for a factor replaces that factor in a compound (U14)", {
  yml <- c("units:", "  L:", "    symbol: l")
  expect_equal(f2_ws("`r u(5, mg/L)`{.num}", yml), f2("5~mg/l"))
  expect_equal(f2_ws("`r u(5, L)`{.num}", yml), f2("5~l"))
})

test_that("2f units: derived symbol text is escaped as 4.4.8 says, while units: text is not (U15)", {
  yml <- c("units:", "  zzqf:", "    name: quark", "    symbol: \"a_b\"")
  expect_equal(f2_ws("`r u(3, zzqf)`{.num}", yml), f2("3~a_b"))
})

test_that("2f units: the default space is none before %, degree and the arc marks, and a no-break space otherwise (U13)", {
  f2_rows(c("`r u(35, \"%\")`{.num}", "`r u(45, \"°\")`{.num}", "`r u(5, \"′\")`{.num}",
            "`r u(5, \"″\")`{.num}", "`r u(20, degC)`{.num}", "`r u(5, m)`{.num}", "`r u(5, ha)`{.num}"),
          c("35%", paste0("45", F2_DEG), "5′", "5″", paste0("20~", F2_DEG, "C"), "5~m", "5~ha"))
})

test_that("2f units: space true puts the no-break space before %, and space false removes it from a unit (R3, U13)", {
  expect_equal(f2_ws("`r u(35, \"%\")`{.num}", c("units:", "  \"%\":", "    space: true")), f2("35~%"))
  yml <- c("units:", "  zzqg:", "    name: quark", "    symbol: zq", "    space: false")
  expect_equal(f2_ws("`r u(3, zzqg)`{.num}", yml), "3zq")
  expect_equal(f2_ws("`r u(3, zzqg)`{.uname}", yml), f2("3~quarks"))        # a name always takes the space
})

test_that("2f units: a compound takes the no-break space unless its own key says otherwise (U13)", {
  yml <- c("units:", "  zzqh:", "    name: quark", "    symbol: zq", "    space: false")
  expect_equal(f2_ws("`r u(3, zzqh/s)`{.num}", yml), f2("3~zq/s"))
  yml2 <- c(yml, "  zzqh/s:", "    name: quark per second", "    space: false")
  expect_equal(f2_ws("`r u(3, zzqh/s)`{.num}", yml2), "3zq/s")
})

test_that("2f units: the shipped default for a symbol and for an exact unit is kept when the key sets only a name (9.1.7)", {
  yml <- c("units:", "  m:", "    name: emm")
  expect_equal(f2_ws("`r u(3, m)`{.num}", yml), f2("3~m"))
  expect_equal(f2_ws("`r u(3, m)`{.uname}", yml), f2("3~emms"))
})

# ---- every units: problem, one error (9.1.7, U17) ---------------------------------------------------------------

units_err <- function(lines, env = parent.frame()) {
  withr::local_envvar(WEFT_DRAFT = NA, .local_envir = env)
  e <- f2_cond(cfg2(f2_proj(c("units:", lines), env = env)))
  f2_has_class(e, "weft_config_error")
  e
}

test_that("2f units problems: units that is not a mapping (9.1.7)", {
  withr::local_envvar(WEFT_DRAFT = NA)
  e <- f2_cond(cfg2(f2_proj("units: [m, km]")))
  f2_has_class(e, "weft_config_error")
  f2_msg_has(e, "units:", "9.1.7")
  e2 <- f2_cond(cfg2(f2_proj("units: m")))
  f2_has_class(e2, "weft_config_error")
})

test_that("2f units problems: a key that does not parse (9.1.7)", {
  e <- units_err(c("  \"not a unit!!\":", "    name: nothing"))
  f2_msg_has(e, "`not a unit!!`", "(rule 9.1.7)", "problem(s) in `units:`")
})

test_that("2f units problems: a key with a power that is not whole (9.1.7)", {
  e <- units_err(c("  \"m^0.5\":", "    name: root metre"))
  f2_msg_has(e, "`m^0.5`", "(rule 9.1.7)")
})

test_that("2f units problems: two keys for one unit (9.1.7)", {
  e <- units_err(c("  m:", "    name: emm", "  metre:", "    name: meter"))
  f2_msg_has(e, "`m`", "`metre`", "(rule 9.1.7)")
})

test_that("2f units problems: an entry that is not a mapping, or is empty (9.1.7)", {
  e <- units_err(c("  zzra: just text"))
  f2_msg_has(e, "`zzra`", "(rule 9.1.7)")
  e2 <- units_err(c("  zzrb: {}"))
  f2_msg_has(e2, "`zzrb`", "(rule 9.1.7)")
  e3 <- units_err(c("  zzrc:"))
  f2_msg_has(e3, "`zzrc`", "(rule 9.1.7)")
})

test_that("2f units problems: an unknown field is named, with the four listed (9.1.7)", {
  e <- units_err(c("  zzrd:", "    plurl: quarks"))
  f2_msg_has(e, "`zzrd`", "plurl", "name", "plural", "symbol", "space", "(rule 9.1.7)")
})

test_that("2f units problems: a field of the wrong type (9.1.7)", {
  for (bad in list(c("    name: 5"), c("    name: \"\""), c("    plural: [a, b]"), c("    symbol: true"),
                   c("    symbol: \"\""), c("    space: \"yes\""), c("    space: 1"))) {
    # ruling: no second `name` line, which YAML refuses as a duplicate key
    e <- units_err(c("  zzre:", if (!grepl("name:", bad)) "    name: ok", bad))
    f2_msg_has(e, "`zzre`", "(rule 9.1.7)")
  }
})

test_that("2f units problems: symbol false on a unit with no name (9.1.7)", {
  e <- units_err(c("  zzrf:", "    symbol: false"))
  f2_msg_has(e, "`zzrf`", "(rule 9.1.7)")
  # control: a name given, or a unit the database names, is fine
  withr::local_envvar(WEFT_DRAFT = NA)
  expect_no_error(cfg2(f2_proj(c("units:", "  zzrg:", "    name: quark", "    symbol: false"))))
  expect_no_error(cfg2(f2_proj(c("units:", "  d:", "    symbol: false"))))
})

test_that("2f units problems: all of them are raised together as one error with a count line and one line each (U17)", {
  e <- units_err(c("  zzsa:", "    nmae: x",
                   "  zzsb:", "    name: 5",
                   "  zzsc: {}",
                   "  zzsd: foo"))
  m <- f2_msg(e)
  f2_msg_has(e, "4 problem(s) in `units:`", "`zzsa`", "`zzsb`", "`zzsc`", "`zzsd`")
  lines <- strsplit(m, "\n", fixed = TRUE)[[1]]
  expect_match(lines[1], "^weft: .*_weft\\.yml: 4 problem\\(s\\) in `units:`")
  expect_equal(sum(grepl("units: `zzs[a-d]`: .*\\(rule 9\\.1\\.7\\)", lines)), 4L)
  f2_msg_has(e, "_weft.yml")
})

test_that("2f units problems: a read with problems registers nothing, not even the keys that are fine (U16)", {
  withr::local_envvar(WEFT_DRAFT = NA)
  e <- f2_cond(cfg2(f2_proj(c("units:", "  zzsx:", "    name: quark", "  zzsy:", "    nmae: x"))))
  f2_has_class(e, "weft_config_error")
  expect_error(u(3, zzsx), class = "weft_unit_error")
  expect_error(u(3, zzsy), class = "weft_unit_error")
})

test_that("2f units problems: the error stops a draft-mode read too (U17, 9.1.7)", {
  withr::local_envvar(WEFT_DRAFT = "1")
  e <- f2_cond(cfg2(f2_proj(c("units:", "  zzsz:", "    nmae: x"))))
  f2_has_class(e, "weft_config_error")
})

test_that("2f units problems: the check also runs on a front-matter units: table (9.1.7, U21)", {
  withr::local_envvar(WEFT_DRAFT = NA)
  e <- f2_cond(cfg2(f2_proj(), front = list(units = list(zzta = list(nmae = "x")))))
  f2_has_class(e, "weft_config_error")
  f2_msg_has(e, "`zzta`", "(rule 9.1.7)")
})

# ---- the document and the project: nearest wins, merged per unit (U21) -------------------------------------------------

DOC_CASES <- c(
  "`r u(5, m)`{.num}",           # 1 the document's unit_form beats the project's
  "`r u(5, m)`{.usym}",          # 2 the use beats the document
  "`r u(2, zzua)`{.num}",        # 3 a unit the project names and the document leaves alone
  "`r u(2, zzub)`{.uname}",      # 4 a unit both name: the document's entry replaces the project's whole
  "`r u(2, zzuc)`{.uname}",      # 5 a unit only the document names
  "`r u(1, zzub)`{.uname}"       # 6 singular of the replaced entry: no plural carried over
)
DOC_WANT <- c("5~metres", "5~m", "2~aaas", "2~cccs", "2~dddds", "1~ccc")

doc_render <- local({
  cache <- NULL
  function() {
    if (is.null(cache)) {
      cache <<- render_rmd(
        batch_cases(DOC_CASES),
        front = c("weft:", "  unit_form: name", "  units:", "    zzub:", "      name: ccc",
                  "    zzuc:", "      name: dddd"),
        files = list("_weft.yml" = c("unit_form: symbol", "units:", "  zzua:", "    name: aaa",
                                     "  zzub:", "    name: bbb", "    plural: bbbbs")),
        in_process = TRUE, env = c(WEFT_DRAFT = "1"))
    }
    cache
  }
})

test_that("2f precedence: default < _weft.yml < document < the use, and units merge per unit (9.1.1, U21)", {
  res <- doc_render()
  expect_false(res$failed, label = res$message)
  skip_if(res$failed, "the document did not render")
  got <- f2_unesc(split_cases(res, length(DOC_CASES)))
  for (i in seq_along(DOC_WANT)) expect_equal(got[i], f2(DOC_WANT[i]), label = DOC_CASES[i])
})

# ---- lang: en-US, and de (1.6.8, U8) ----------------------------------------------------------------------------------------

test_that("2f lang: en_US and any case of en-US take the en-US spellings (U8)", {
  for (lang in c("en_US", "EN-us")) {
    res <- render_rmd(c("`r u(5, m)`{.num} and `r u(2, L)`{.uname}"), front = paste0("lang: ", lang),
                      files = list("_weft.yml" = "unit_form: name"), format = "knit", in_process = TRUE)
    expect_false(res$failed, label = paste(lang, res$message))
    expect_match(f2_unesc(res$md), f2("5~meters and 2~liters"), fixed = TRUE, label = lang)
  }
})

test_that("2f lang: any other English lang, or none, takes the other spelling (U8)", {
  for (lang in c("en-AU", "en-GB")) {
    res <- render_rmd(c("`r u(5, m)`{.uname}"), front = paste0("lang: ", lang), format = "knit", in_process = TRUE)
    expect_false(res$failed, label = paste(lang, res$message))
    expect_match(f2_unesc(res$md), f2("5~metres"), fixed = TRUE, label = lang)
  }
})

DE_CASES <- c(
  "`r u(5, m)`{.num}",                                     # 1 a symbol is not words: prints
  "`r u(10, year)`{.num}",                                 # 2 a unit with no symbol: value error
  "`r u(5, m)`{.uname}",                                   # 3 construct error from the source
  "`r fmt_num(u(5, m), unit_form = \"name\")`{.strong}",   # 4 construct error when called
  "`r u(2, zzva)`{.num}",                                  # 5 symbol: false under de: value error
  "`r u(35, \"%\")`{.num}"                                 # 6 control: prints
)

de_render <- local({
  cache <- NULL
  function() {
    if (is.null(cache)) {
      cache <<- render_rmd(batch_cases(DE_CASES), front = "lang: de",
                           files = list("_weft.yml" = c("units:", "  zzva:", "    name: quark", "    symbol: false")),
                           format = "knit", in_process = TRUE, env = c(WEFT_DRAFT = "1"))
    }
    cache
  }
})

test_that("2f lang de: a symbol prints, a name and a unit with no symbol are errors where they would print (1.6.8)", {
  res <- de_render()
  expect_false(res$failed, label = res$message)
  skip_if(res$failed, "the batch did not render")
  got <- f2_cases(res, length(DE_CASES))
  expect_equal(got[1], f2("5~m"))
  expect_equal(got[6], "35%")
  expect_match(got[2], "<<weft: value error", fixed = TRUE)
  expect_match(got[3], "<<weft: construct error", fixed = TRUE)
  expect_match(got[4], "<<weft: construct error", fixed = TRUE)
  expect_match(got[5], "<<weft: value error", fixed = TRUE)
})

test_that("2f lang de: the value error for a unit with no symbol names the unit, the lang and symbol: (1.6.8)", {
  res <- de_render()
  skip_if(res$failed, "the batch did not render")
  ft <- f2_failures(res)
  hit <- ft[grepl("year", ft, fixed = TRUE)]
  expect_gte(length(hit), 1L)
  expect_true(any(grepl("de", hit, fixed = TRUE)))
  expect_true(any(grepl("symbol:", hit, fixed = TRUE)))
  expect_true(any(grepl("units:", hit, fixed = TRUE)))
})

test_that("2f lang de: unit_form name in _weft.yml is a config error at knit initialisation (1.6.8, 9.1.6)", {
  res <- render_rmd(c("`r u(5, m)`{.num}"), front = "lang: de", files = list("_weft.yml" = "unit_form: name"),
                    format = "knit", in_process = TRUE, env = c(WEFT_DRAFT = NA))
  expect_true(res$failed)
  expect_true("weft_config_error" %in% res$error$class)
  expect_match(res$message, "unit_form", fixed = TRUE)
})

test_that("2f lang de: unit_form name in the front matter is a config error too (1.6.8)", {
  res <- render_rmd(c("`r u(5, m)`{.num}"), front = c("lang: de", "weft:", "  unit_form: name"),
                    format = "knit", in_process = TRUE, env = c(WEFT_DRAFT = NA))
  expect_true(res$failed)
  expect_true("weft_config_error" %in% res$error$class)
})

test_that("2f lang de: control, unit_form symbol and auto are fine under de (1.6.8)", {
  res <- render_rmd(c("`r u(5, m)`{.num}"), front = "lang: de", files = list("_weft.yml" = "unit_form: symbol"),
                    format = "knit", in_process = TRUE, env = c(WEFT_DRAFT = NA))
  expect_false(res$failed, label = res$message)
  expect_match(f2_unesc(res$md), f2("5~m"), fixed = TRUE)
})

test_that("2f units problems: a bad units: table in the front matter stops the knit and names the document (9.1.7, U21)", {
  res <- render_rmd(c("`r u(5, m)`{.num}"), front = c("weft:", "  units:", "    zzwa:", "      nmae: x"),
                    format = "knit", in_process = TRUE, env = c(WEFT_DRAFT = "1"))
  expect_true(res$failed)
  expect_true("weft_config_error" %in% res$error$class)
  expect_match(res$message, "doc.Rmd", fixed = TRUE)
  expect_match(res$message, "`zzwa`", fixed = TRUE)
  expect_match(res$message, "(rule 9.1.7)", fixed = TRUE)
})

test_that("2f units problems: a bad _weft.yml units: table stops a knit in draft mode (U17)", {
  res <- render_rmd(c("`r u(5, m)`{.num}"), files = list("_weft.yml" = c("units:", "  zzwb:", "    nmae: x")),
                    format = "knit", in_process = TRUE, env = c(WEFT_DRAFT = "1"))
  expect_true(res$failed)
  expect_true("weft_config_error" %in% res$error$class)
  expect_match(res$message, "_weft.yml", fixed = TRUE)
})
