# Findings 1, 2 and 7 of "Found while building the resolver filter (stage 6)" in dev/open-findings.md.
# Test-first: the owner's rulings are in the task that asked for these tests; the file is ASCII (the
# multiplication sign is \u00d7, the minus sign \u2212).
#
#  F1  round_half_away() cut a value of exactly 15 significant digits one digit early when log10 of it
#      rounds up to the next integer. Rule: a value with exactly 15 significant digits prints with all 15.
#      The Lua port (weftlib/num.lua) copies the bug and must follow.
#  F7  .sci: a mantissa that rounds up to the next power of ten is renormalised and must print as the same
#      power of ten prints when given directly (999000 as 1e6; the mantissa rule is print_one(): a whole
#      mantissa has no decimals unless `digits`/`sigfig` ask for them). .sci of 0 prints plain "0".
#  F2  An R chunk's claim() is counted by the gate exactly as a guest chunk's is (N59): not when the chunk is
#      statically not evaluated (static_option_value() + falsy(), chunk options only).
#
# The conformance rows these findings add are in _conformance/numbers.tsv (the last six rows, F1) and
# _conformance/sci.tsv (rows 5, 7, 8, 13 and 26, F7). They hold the CORRECT output; R's live corpus
# (R/conformance.R) does not yet make the six new numbers.tsv rows, so the implementer must add them at the
# END of conf_numbers_rows() in that order, then run
#   weft:::conformance_write("tests/testthat/_conformance", sets = c("numbers", "words", "lists", weft:::CONF_NEW_SETS))
# and check with git diff that nothing else changes.

s6_txt <- function(x) paste(suppressWarnings(as.character(unclass(x))), collapse = ", ")
TIMES <- "\u00d7"
MINUS <- "\u2212"
sci_text <- function(m, e, minus = FALSE) paste0(if (minus) MINUS, m, " ", TIMES, " 10^", e, "^")

# ---- F1: fmt_num / fmt_pct at exactly 15 significant digits ------------------------------------------------

test_that("F1: fmt_pct(999999999999999) prints all 15 digits of the product, 99,999,999,999,999,900%", {
  expect_identical(s6_txt(fmt_pct(999999999999999)), "99,999,999,999,999,900%")
  expect_identical(s6_txt(fmt_pct(-999999999999999)), paste0(MINUS, "99,999,999,999,999,900%"))
})

test_that("F1: a value of 15 significant digits just below a power of ten prints all 15 (fmt_num)", {
  expect_identical(s6_txt(fmt_num(99999999999999.9)), "99,999,999,999,999.9")
  expect_identical(s6_txt(fmt_num(-99999999999999.9)), paste0(MINUS, "99,999,999,999,999.9"))
  expect_identical(s6_txt(fmt_num(9999999999999.99, digits = 2)), "9,999,999,999,999.99")
  expect_identical(s6_txt(fmt_num(999999999999.999, digits = 3)), "999,999,999,999.999")
  expect_identical(s6_txt(fmt_num(99999999999.9999, digits = 4)), "99,999,999,999.9999")
})

test_that("F1 control: a value that genuinely rounds up to the power of ten still does", {
  expect_identical(s6_txt(fmt_num(99999999999999.9, digits = 0)), "100,000,000,000,000")
  expect_identical(s6_txt(fmt_num(0.99999, digits = 2)), "1.00")
  expect_identical(s6_txt(fmt_num(999.96, digits = 1)), "1,000.0")
})

test_that("F1 control: 16 or more significant digits still round to 15", {
  expect_identical(s6_txt(fmt_num(9999999999999999)), "10,000,000,000,000,000")
  expect_identical(s6_txt(fmt_num(1234567890123456789)), "1,234,567,890,123,460,000")
  expect_identical(s6_txt(fmt_pct(1e15)), "100,000,000,000,000,000%")
})

test_that("F1 control: ordinary values are unchanged", {
  expect_identical(s6_txt(fmt_num(123456.789)), "123,456.8")
  expect_identical(s6_txt(fmt_num(999999999999999)), "999,999,999,999,999")
  expect_identical(s6_txt(fmt_num(0.1 + 0.2)), "0.3")
  expect_identical(s6_txt(fmt_pct(0.5)), "50%")
  expect_identical(s6_txt(fmt_pct(0.1234)), "12.3%")
})

# ---- the Lua port, directly ------------------------------------------------------------------------------------

# Runs cases through weftlib/num.lua (one Pandoc process). Each case: kind ("num", "pct" or "sci"), the float
# text of the record, and keys as a named list of strings. Returns the printed texts.
s6_lua <- function(cases) {
  skip_if_no_lua_pandoc()
  dir <- withr::local_tempdir()
  script <- file.path(dir, "s6.lua")
  keys_lua <- function(k) {
    if (!length(k)) return("{}")
    paste0("{", paste0(names(k), " = '", unlist(k), "'", collapse = ", "), "}")
  }
  body <- vapply(cases, function(cs) {
    rec <- sprintf("{t = 'float', v = '%s'}", cs$v)
    call <- if (cs$kind == "sci") sprintf("num.format_sci(%s, %s, {})", rec, keys_lua(cs$keys))
            else sprintf("num.format(%s, '%s', %s, {})", rec, cs$kind, keys_lua(cs$keys))
    sprintf("do local t = %s; io.stdout:write(t, '\\n') end", call)
  }, "")
  writeLines(c("local num = dofile(arg[1])", body), script)
  r <- lua_run(script, lua_num_path())
  expect_identical(r$status, 0L, info = r$stderr)
  strsplit(r$stdout, "\n", fixed = TRUE)[[1]]
}

test_that("F1 (Lua): the port prints 15 significant digits whole, as R must", {
  cases <- list(
    list(kind = "pct", v = "999999999999999", keys = list()),
    list(kind = "pct", v = "-999999999999999", keys = list()),
    list(kind = "num", v = "99999999999999.9", keys = list()),
    list(kind = "num", v = "-99999999999999.9", keys = list()),
    list(kind = "num", v = "9999999999999.99", keys = list(digits = "2")),
    list(kind = "num", v = "999999999999.999", keys = list(digits = "3")),
    list(kind = "num", v = "99999999999.9999", keys = list(digits = "4")))
  want <- c("99,999,999,999,999,900%", paste0(MINUS, "99,999,999,999,999,900%"),
            "99,999,999,999,999.9", paste0(MINUS, "99,999,999,999,999.9"),
            "9,999,999,999,999.99", "999,999,999,999.999", "99,999,999,999.9999")
  got <- s6_lua(cases)
  expect_length(got, length(want))
  for (i in seq_along(want)) expect_identical(got[i], want[i], info = cases[[i]]$v)
})

test_that("F1 control (Lua): 16-digit values round to 15 and ordinary values are unchanged", {
  cases <- list(
    list(kind = "num", v = "9999999999999999", keys = list()),
    list(kind = "num", v = "99999999999999.9", keys = list(digits = "0")),
    list(kind = "num", v = "123456.789", keys = list()),
    list(kind = "pct", v = "0.5", keys = list()))
  expect_identical(s6_lua(cases), c("10,000,000,000,000,000", "100,000,000,000,000", "123,456.8", "50%"))
})

# ---- F7: .sci ----------------------------------------------------------------------------------------------------
# The mantissa rule found: print_one() of R/format.R. With neither `digits` nor `sigfig`, a mantissa that is
# a whole number prints with no decimals ("1", "5") and any other with cfg$digits (1) decimals ("1.2");
# `digits`/`sigfig` are honoured exactly (1e10 with digits = 1 prints "1.0"). Trailing zeros are not
# stripped as such: 1.0 prints "1" only because it is whole. A mantissa that rounds to ten is renormalised;
# the bug is that the renormalised mantissa is m / 10 (0.999), not 1, so it is not whole and prints "1.0".

test_that("F7: a mantissa that carries to ten prints as the power of ten prints directly (default digits)", {
  expect_identical(s6_txt(fmt_sci(1e6)), sci_text("1", 6))
  expect_identical(s6_txt(fmt_sci(999000)), s6_txt(fmt_sci(1e6)))
  expect_identical(s6_txt(fmt_sci(999000)), sci_text("1", 6))
  expect_identical(s6_txt(fmt_sci(99999)), s6_txt(fmt_sci(1e5)))
  expect_identical(s6_txt(fmt_sci(99999)), sci_text("1", 5))
  expect_identical(s6_txt(fmt_sci(9.96)), sci_text("1", 1))
  expect_identical(s6_txt(fmt_sci(-999000)), sci_text("1", 6, minus = TRUE))
  expect_identical(s6_txt(fmt_sci(9.96e-5)), s6_txt(fmt_sci(1e-4)))
  expect_identical(s6_txt(fmt_sci(9.96e-5)), paste0("1 ", TIMES, " 10^", MINUS, "4^"))
})

test_that("F7 control: a carry with an explicit digits or sigfig prints as the power of ten prints directly", {
  for (d in 0:3) {
    expect_identical(s6_txt(fmt_sci(999999, digits = d)), s6_txt(fmt_sci(1e6, digits = d)), info = paste("digits", d))
  }
  for (s in 1:4) {
    expect_identical(s6_txt(fmt_sci(999999, sigfig = s)), s6_txt(fmt_sci(1e6, sigfig = s)), info = paste("sigfig", s))
  }
  expect_identical(s6_txt(fmt_sci(999000, digits = 1)), sci_text("1.0", 6))
  expect_identical(s6_txt(fmt_sci(999000, digits = 0)), sci_text("1", 6))
  expect_identical(s6_txt(fmt_sci(999999, digits = 2)), sci_text("1.00", 6))
  expect_identical(s6_txt(fmt_sci(999000, sigfig = 2)), sci_text("1.0", 6))
})

test_that("F7 control: mantissas that do not carry are unchanged", {
  expect_identical(s6_txt(fmt_sci(990000)), sci_text("9.9", 5))
  expect_identical(s6_txt(fmt_sci(949000)), sci_text("9.5", 5))
  expect_identical(s6_txt(fmt_sci(999000, digits = 2)), sci_text("9.99", 5))
  expect_identical(s6_txt(fmt_sci(12345)), sci_text("1.2", 4))
  expect_identical(s6_txt(fmt_sci(1e10)), sci_text("1", 10))
  expect_identical(s6_txt(fmt_sci(1e10, digits = 2)), sci_text("1.00", 10))
  expect_identical(s6_txt(fmt_sci(0.5)), paste0("5 ", TIMES, " 10^", MINUS, "1^"))
  expect_identical(s6_txt(fmt_sci(-2500)), sci_text("2.5", 3, minus = TRUE))
})

test_that("F7: .sci of zero prints plain 0, with no power", {
  expect_identical(s6_txt(fmt_sci(0)), "0")
  expect_identical(s6_txt(fmt_sci(-0)), "0")
  expect_identical(s6_txt(fmt_sci(0L)), "0")
})

test_that("F7 (Lua): the port renormalises a carried mantissa the same way, and prints zero plain", {
  cases <- list(
    list(kind = "sci", v = "999000", keys = list()),
    list(kind = "sci", v = "99999", keys = list()),
    list(kind = "sci", v = "9.96", keys = list()),
    list(kind = "sci", v = "-999000", keys = list()),
    list(kind = "sci", v = "0", keys = list()),
    list(kind = "sci", v = "-0", keys = list()),
    list(kind = "sci", v = "999000", keys = list(digits = "1")),
    list(kind = "sci", v = "999999", keys = list(digits = "2")),
    list(kind = "sci", v = "999000", keys = list(sigfig = "2")),
    list(kind = "sci", v = "990000", keys = list()),
    list(kind = "sci", v = "1000000", keys = list()))
  want <- c(sci_text("1", 6), sci_text("1", 5), sci_text("1", 1), sci_text("1", 6, minus = TRUE),
            "0", "0",
            sci_text("1.0", 6), sci_text("1.00", 6), sci_text("1.0", 6),
            sci_text("9.9", 5), sci_text("1", 6))
  got <- s6_lua(cases)
  expect_length(got, length(want))
  for (i in seq_along(want)) {
    expect_identical(got[i], want[i], info = paste(cases[[i]]$v, paste(names(cases[[i]]$keys), cases[[i]]$keys, collapse = " ")))
  }
})

# ---- the conformance tables hold the new output ---------------------------------------------------------------------

test_that("F1, F7: the committed tables hold the corrected rows, and R's live corpus makes the new numbers rows", {
  d <- f6_read("sci")
  at <- function(v, k = "") d$text[d$value == v & d$keys == k & d$classes == "sci"]
  expect_identical(at("999000"), sci_text("1", 6))
  expect_identical(at("9.99e5"), sci_text("1", 6))
  expect_identical(at("99999"), sci_text("1", 5))
  expect_identical(at("9.96"), sci_text("1", 1))
  expect_identical(at("0"), "0")
  expect_identical(at("999000", "digits=1"), sci_text("1.0", 6))
  n <- f6_read("numbers")
  expect_true(all(c("99,999,999,999,999,900%", paste0(MINUS, "99,999,999,999,999,900%")) %in% n$text))
  live <- as.data.frame(weft:::conformance_rows("numbers"), stringsAsFactors = FALSE)
  expect_true("99,999,999,999,999,900%" %in% live$text)
})

# ---- F2: an R chunk's claim() counts only when the chunk is statically evaluated ----------------------------------------
# The guest rule (R/constructs.R construct_rows(); the chunk's `eval` column from chunk_table() in
# R/lint-source.R): a chunk whose `eval` option is statically false (header or `#|` line; static_option_value()
# then falsy(): FALSE, F, false, no, 0, `!expr FALSE`, `!expr F`) counts nothing; a non-literal (`!expr flag`,
# `eval=flag`) counts; a `#|` line beats the header. Document-level `execute: eval: false` and
# knitr::opts_chunk$set(eval = FALSE) are not read, so for guests (and now for R) the claim still counts.

f2_chunk <- function(engine, hdr = character(), pipe = character(), claim = TRUE) {
  open <- paste0("```{", engine, if (length(hdr)) paste0(" ", hdr), "}")
  code <- if (!claim) "n = 1" else if (engine == "r") "claim(n, . > 10)" else "claim(n, \"> 10\")"
  c(open, pipe, code, "```")
}
f2_count <- function(engine, ...) {
  x <- cc6k(c("Intro.", "", f2_chunk(engine, ...)))
  sum(x$kind == "claim")
}

F2_SPELLINGS <- list(
  list(pipe = "#| eval: false", n = 0L),
  list(pipe = "#| eval: FALSE", n = 0L),
  list(pipe = "#| eval: no", n = 0L),
  list(pipe = "#| eval: 0", n = 0L),
  list(pipe = "#| eval: !expr FALSE", n = 0L),
  list(pipe = "#| eval: !expr F", n = 0L),
  list(pipe = "#| eval: false # why", n = 0L),
  list(hdr = ", eval=FALSE", n = 0L),
  list(hdr = ", eval = F", n = 0L),
  list(hdr = "eval=FALSE", n = 0L),
  list(hdr = ", eval=FALSE", pipe = "#| eval: true", n = 1L),
  list(pipe = "#| eval: true", n = 1L),
  list(pipe = "#| eval: !expr flag", n = 1L),
  list(hdr = ", eval=flag", n = 1L),
  list(hdr = ", eval=TRUE", n = 1L))
f2_hdr <- function(sp) if (is.null(sp$hdr)) character() else sub("^, ", ",", sp$hdr)

test_that("F2: the guest rule counts nothing in a chunk that is statically not evaluated (the table R must match)", {
  for (sp in F2_SPELLINGS) {
    got <- f2_count("python", hdr = f2_hdr(sp), pipe = sp$pipe %||% character())
    expect_identical(got, sp$n, info = paste("python:", sp$hdr, sp$pipe))
  }
})

test_that("F2: an R chunk's claim() is counted by the same test of 'not evaluated' as a guest chunk's", {
  for (sp in F2_SPELLINGS) {
    got <- f2_count("r", hdr = f2_hdr(sp), pipe = sp$pipe %||% character())
    expect_identical(got, sp$n, info = paste("r:", sp$hdr, sp$pipe))
  }
})

test_that("F2 control: an R chunk with no eval option counts, and a label does not change that", {
  expect_identical(f2_count("r"), 1L)
  expect_identical(f2_count("r", hdr = "label1"), 1L)
})

test_that("F2 control: document-level eval: false and opts_chunk$set(eval = FALSE) are not read for guests, so not for R", {
  front <- c("---", "execute:", "  eval: false", "---", "")
  setup <- c("```{r setup}", "knitr::opts_chunk$set(eval = FALSE)", "```", "")
  for (eng in c("python", "r")) {
    a <- cc6k(c(front, f2_chunk(eng)))
    b <- cc6k(c("Intro.", "", setup, f2_chunk(eng)))
    expect_identical(sum(a$kind == "claim"), 1L, info = paste(eng, "execute: eval: false"))
    expect_identical(sum(b$kind == "claim"), 1L, info = paste(eng, "opts_chunk"))
  }
})

test_that("F2: an inline R claim in prose is unaffected by a chunk's eval option", {
  inline <- "The count is `r claim(n_sites, . > 10)`{.num} sites."
  for (pipe in list(character(), "#| eval: false")) {
    x <- cc6k(c(inline, "", f2_chunk("r", pipe = pipe, claim = FALSE)))
    expect_identical(sum(x$kind == "claim"), 1L, info = paste(pipe, collapse = " "))
    expect_identical(sum(x$kind == "value"), 1L, info = paste(pipe, collapse = " "))
  }
})

f2_doc <- function(engine, pipe = character(), claim = TRUE, extra = character()) {
  c("Intro paragraph.", "", f2_chunk(engine, pipe = c("#| label: c1", pipe), claim = claim), extra, G_ENGINE)
}

test_that("F2: turning eval off on an R chunk that holds a claim is a removal, as for a Python chunk", {
  for (eng in c("python", "r")) {
    d <- g_scenario(list("ch1.qmd" = f2_doc(eng)), list("ch1.qmd" = f2_doc(eng, pipe = "#| eval: false")))
    res <- g_gate(d)
    expect_false(res$ok, info = eng)
    expect_identical(res$n_removed, 1L, info = eng)
    expect_identical(res$removed$kind, "claim", info = eng)
    expect_true(grepl("ch1\\.qmd$", res$removed$file), info = eng)
  }
  # the reports differ in their check-strength lines by design (an R claim is read as a check, a guest claim
  # is not, N121), so only the count and the kind above are compared
})

test_that("F2: with Weft-Removed: 1 the R eval-off removal passes", {
  d <- g_scenario(list("ch1.qmd" = f2_doc("r")), list("ch1.qmd" = f2_doc("r", pipe = "#| eval: false")))
  res <- g_gate(d, c("Switch the check off", "", "Weft-Removed: 1"))
  expect_true(res$ok)
  expect_identical(res$n_removed, 1L)
  expect_identical(res$trailer, 1L)
})

test_that("F2: a chunk eval: false in both versions counts nothing on either side", {
  for (eng in c("python", "r")) {
    both <- f2_doc(eng, pipe = "#| eval: false")
    changed <- f2_doc(eng, pipe = "#| eval: false", extra = c("", "More prose."))
    d <- g_scenario(list("ch1.qmd" = both), list("ch1.qmd" = changed))
    res <- g_gate(d)
    expect_true(res$ok, info = eng)
    expect_identical(max(0, res$n_removed), 0, info = eng)
    expect_identical(sum(cc6k(both)$kind == "claim"), 0L, info = eng)
  }
  # deleting the claim from such a chunk costs nothing
  d <- g_scenario(list("ch1.qmd" = f2_doc("r", pipe = "#| eval: false")),
                  list("ch1.qmd" = f2_doc("r", pipe = "#| eval: false", claim = FALSE)))
  expect_identical(max(0, g_gate(d)$n_removed), 0)
})

test_that("F2: turning eval back on is an addition, not a removal", {
  for (eng in c("python", "r")) {
    d <- g_scenario(list("ch1.qmd" = f2_doc(eng, pipe = "#| eval: false")), list("ch1.qmd" = f2_doc(eng)))
    res <- g_gate(d)
    expect_true(res$ok, info = eng)
    expect_identical(max(0, res$n_removed), 0, info = eng)
  }
})

test_that("F2 control: deleting an R claim from an evaluated chunk is still a removal", {
  d <- g_scenario(list("ch1.qmd" = f2_doc("r")), list("ch1.qmd" = f2_doc("r", claim = FALSE)))
  expect_identical(g_gate(d)$n_removed, 1L)
})

test_that("F2 control: checks_read() already reads no claim from an R chunk that is not evaluated", {
  doc <- function(pipe) c("```{r}", pipe, "n <- 12", "claim(n, . > 10)", "```")
  expect_identical(nrow(j7_read(doc(character()))), 1L)
  expect_identical(nrow(j7_read(doc("#| eval: false"))), 0L)
})
