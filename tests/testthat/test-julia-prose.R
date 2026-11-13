# Stage 5J-a: Julia reads in prose and in the places weft evaluates (J2, J9 to
# J16, J26 at knit time). Documents are knitted in this process (k5j(),
# helper-5j.R) with Julia chunks through knitr's julia engine, or with values
# set by jl_set(); none has library(JuliaCall). Draft mode (WEFT_DRAFT=1) is
# used where the markers are looked at, since a failing render writes no
# output (9.4.2). Julia is shared by the file; names are t_j5p_...
#
# Two fresh processes, made lazily: A starts no Julia (J13 and JM16, where
# Julia is not found), B starts Julia (J16, and a bare `missing` read, which
# is run there so that a crash fails the test and does not kill the run).

pset <- function() {
  jl_set(
    t_j5p_depth = "3.14159", t_j5p_n = "12", t_j5p_b53 = "2^53 + 1",
    t_j5p_b70 = "big(2)^70", t_j5p_a31 = "2^31", t_j5p_u8 = "UInt8(200)",
    t_j5p_none = "nothing", t_j5p_s = "\"h\u00e9llo\"",
    t_j5p_d = "Dates.Date(2026, 11, 13)", t_j5p_slope = "0.5",
    t_j5p_f32 = "Float32(0.1)", t_j5p_rat = "1//3",
    t_j5p_dt = "Dates.DateTime(2026, 11, 13, 10, 30)",
    t_j5p_dict = "Dict(\"b\" => 2, \"a\" => 1)",
    t_j5p_nt = "(b = 2, a = 1)",
    t_j5p_cfg = "Dict(\"depth\" => 2.5, \"inner\" => Dict(\"depth\" => 7))",
    t_j5p_sites = "[\"a\", \"b\", \"c\"]",
    t_j5p_mixed = "Any[1, \"a\"]")
}

PROSE_J <- c(
  V01 = "`r jl_value(\"t_j5p_depth\")`{.num} x",
  V02 = "`r weft::jl_value(\"t_j5p_depth\")`{.num} x",
  V03 = "`r jl_value(\"t_j5p_cfg\", \"depth\")`{.num} x",
  V04 = "`r jl_value(\"t_j5p_cfg\", \"inner\", \"depth\")`{.num} x",
  V05 = "`r jl_value(\"t_j5p_sites\")[2]` x",
  V06 = "`r length(jl_value(\"t_j5p_sites\"))`{.word} x",
  V07 = "`r jl_value(\"t_j5p_slope\") > 0` x",
  V08 = "`r claim(jl_value(\"t_j5p_n\"), . > 10)` x",
  V09 = "`r jl_value(\"t_j5p_sites\")`{.and} x",
  # J9: bare values
  B1 = "`r jl_value(\"t_j5p_n\")` x",
  B2 = "`r jl_value(\"t_j5p_u8\")` x",
  B3 = "`r jl_value(\"t_j5p_b53\")` x",
  B4 = "`r jl_value(\"t_j5p_none\")` x",
  B5 = "`r jl_value(\"t_j5p_depth\")` x",
  B6 = "`r jl_value(\"t_j5p_s\")` x",
  # J10: constructs
  C1 = "`r jl_value(\"t_j5p_b53\")`{.num} x",
  C2 = "`r jl_value(\"t_j5p_a31\")`{.num} x",
  C3 = "`r jl_value(\"t_j5p_f32\")`{.num} x",
  C4 = "`r jl_value(\"t_j5p_rat\")`{.num} x",
  C5 = "`r jl_value(\"t_j5p_dt\")`{.date} x",
  C6 = "`r jl_value(\"t_j5p_dict\")`{.pairs} x",
  C7 = "`r jl_value(\"t_j5p_nt\")`{.pairs} x",
  C8 = "`r jl_value(\"t_j5p_d\")`{.date} x",
  C9 = "`r as.Date(\"2026-11-13\")`{.date} x",
  C10 = "`r jl_value(\"t_j5p_nosuch_zz\")`{.num} x",
  C11 = "`r jl_value(\"t_j5p_cfg\", \"zzz\")`{.num} x",
  C12 = "`r jl_value(\"t_j5p_none\")`{.num} x",
  C13 = "`r jl_value(\"t_j5p_b70\")`{.num} x",
  C14 = "`r jl_value(\"t_j5p_mixed\")`{.and} x",
  C15 = "`r jl_value(\"t_j5p_b53\") > 0` x"
)

prose_main_j <- function() {
  if (is.null(.w5j$prose)) {
    pset()
    .w5j$prose <- k5j_cases(PROSE_J, draft = TRUE)
  }
  .w5j$prose
}

test_that("the prose document knits to its end in draft mode, with no JuliaCall attached", {
  res <- prose_main_j()
  expect_false(res$failed, label = res$message)
  expect_false(res$searched)
})

test_that("J2: every jl_value() form in a value prints a read value", {
  res <- prose_main_j()
  expect_identical(res$line("V01"), "V01 3.1 x")
  expect_identical(res$line("V02"), "V02 3.1 x")
  expect_identical(res$line("V03"), "V03 2.5 x")
  expect_identical(res$line("V04"), "V04 7 x")
})

test_that("J2: R then does what it does with the R form", {
  res <- prose_main_j()
  expect_identical(res$line("V05"), "V05 b x")
  expect_identical(res$line("V06"), "V06 three x")
  expect_identical(res$line("V07"), "V07 TRUE x")
  expect_identical(res$line("V08"), "V08 12 x")
  expect_identical(res$line("V09"), "V09 a, b and c x")
})

# ---- J9: bare values -------------------------------------------------------------------------

test_that("J9: a bare Julia read prints its R form as stock knitr prints it", {
  res <- prose_main_j()
  expect_identical(res$line("B1"), "B1 12 x")
  expect_identical(res$line("B5"), "B5 3.14159 x")
  expect_identical(res$line("B6"), "B6 h\u00e9llo x")
})

test_that("J9: a bare UInt8(200) prints 200, where JuliaCall's route printed c8", {
  res <- prose_main_j()
  expect_identical(res$line("B2"), "B2 200 x")
})

test_that("J9: a bare nothing prints NA", {
  res <- prose_main_j()
  expect_identical(res$line("B4"), "B4 NA x")
})

test_that("J9: a bare 2^53 + 1 is a collected value error with the marker", {
  res <- prose_main_j()
  expect_identical(res$line("B3"), paste("B3", res$marker("B3", "value error"), "x"))
  f <- res$fail("B3")
  expect_identical(f$kind, "value error")
  expect_identical(msg5(f$detail), jm1("`jl_value(\"t_j5p_b53\")`", "Int64", "9007199254740993"))
})

test_that("J9: a bare read of a name that is not defined stops the knit with JM13", {
  jl_set(t_j5p_anchor = "1")
  res <- k5j_cases(c(B7 = "`r jl_value(\"t_j5p_nosuch_zz\")` x"))
  expect_true(res$failed)
  expect_true(grepl(jm13("jl_value(\"t_j5p_nosuch_zz\")", "t_j5p_nosuch_zz"), res$message, fixed = TRUE))
})

# ---- J10: constructs ----------------------------------------------------------------------------

test_that("J10: {.num} on 2^53 + 1 is a collected value error with the exact detail, never 9007199254740993 or a rounded number", {
  res <- prose_main_j()
  expect_identical(res$line("C1"), paste("C1", res$marker("C1", "value error"), "x"))
  f <- res$fail("C1")
  expect_equal(nrow(f), 1L)
  expect_identical(f$kind, "value error")
  expect_identical(
    msg5(f$detail),
    paste0("`jl_value(\"t_j5p_b53\")` is the Julia Int64 9007199254740993, beyond \u00b12^53, where R cannot hold a ",
           "whole number exactly. Scale it in Julia, or bind string() of it and print the text (rule 2.12.5)."))
  expect_identical(res$line("C13"), paste("C13", res$marker("C13", "value error"), "x"))
  expect_identical(msg5(res$fail("C13")$detail),
                   jm1("`jl_value(\"t_j5p_b70\")`", "BigInt", "1180591620717411303424"))
})

test_that("J10: 2^31 prints 2,147,483,648 (JuliaCall's route was \"no value\")", {
  res <- prose_main_j()
  expect_identical(res$line("C2"), "C2 2,147,483,648 x")
  expect_equal(nrow(res$fail("C2")), 0L)
})

test_that("J10: a Float32 under {.num} prints 0.1", {
  res <- prose_main_j()
  expect_identical(res$line("C3"), "C3 0.1 x")
})

test_that("J10: a Rational, a DateTime and a Dict are collected value errors (JM2, JM5, JM7)", {
  res <- prose_main_j()
  expect_collected_j(res, "C4", "value error", jm2("`jl_value(\"t_j5p_rat\")`", "Rational{Int64}"))
  expect_collected_j(res, "C5", "value error", jm5("`jl_value(\"t_j5p_dt\")`", "DateTime"))
  expect_collected_j(res, "C6", "value error", jm7("`jl_value(\"t_j5p_dict\")`", "Dict{String, Int64}"))
})

test_that("J10: a NamedTuple under {.pairs} prints in the order written", {
  res <- prose_main_j()
  expect_identical(res$line("C7"), "C7 b (2) and a (1) x")
})

test_that("J10: a Date read prints as the same R Date does", {
  res <- prose_main_j()
  c8 <- sub("^C8 ", "", res$line("C8"))
  c9 <- sub("^C9 ", "", res$line("C9"))
  expect_identical(c8, c9)
  expect_false(grepl("<<weft", c8, fixed = TRUE))
})

test_that("J10 + JM13/JM14: a read that cannot be done is a collected \"no value\" with `error evaluating`", {
  res <- prose_main_j()
  expect_identical(res$line("C10"), paste("C10", res$marker("C10", "no value"), "x"))
  f <- res$fail("C10")
  expect_identical(f$kind, "no value")
  expect_match(msg5(f$detail), "^error evaluating ")
  expect_true(grepl(jm13("jl_value(\"t_j5p_nosuch_zz\")", "t_j5p_nosuch_zz"), msg5(f$detail), fixed = TRUE))
  expect_identical(res$line("C11"), paste("C11", res$marker("C11", "no value"), "x"))
  f <- res$fail("C11")
  expect_match(msg5(f$detail), "^error evaluating ")
  expect_true(grepl(jm14("jl_value(\"t_j5p_cfg\", \"zzz\")", "jl_value(\"t_j5p_cfg\")", "zzz"),
                    msg5(f$detail), fixed = TRUE))
})

test_that("J10 + 1.3.4: a missing value reaching a formatter is \"no value\"", {
  res <- prose_main_j()
  expect_no_value_j(res, "C12")
})

test_that("J10: a mixed list under {.and} is a collected value error (JM3)", {
  res <- prose_main_j()
  expect_collected_j(res, "C14", "value error",
                     jm3("`jl_value(\"t_j5p_mixed\")`", "Vector{Any}", "integer, string"))
})

test_that("J2 + J10: a refusal inside a larger expression is the whole read refused", {
  res <- prose_main_j()
  expect_identical(res$line("C15"), paste("C15", res$marker("C15", "value error"), "x"))
  expect_identical(msg5(res$fail("C15")$detail),
                   jm1("`jl_value(\"t_j5p_b53\")`", "Int64", "9007199254740993"))
})

test_that("J10 + 2.6.2: a value error fails the render once, with one report that names the line and the message", {
  pset()
  res <- k5j_cases(c(F1 = "`r jl_value(\"t_j5p_b53\")`{.num} x", F2 = "Fine `r jl_value(\"t_j5p_n\")`{.num} x"))
  expect_true(res$failed)
  expect_true("weft_failures" %in% res$class)
  expect_equal(nrow(res$failures), 1L)
  expect_identical(res$failures$kind, "value error")
  expect_equal(res$failures$line, unname(res$at["F1"]))
  expect_match(res$message, sprintf("doc\\.Rmd:%d\\b", res$at[["F1"]]))
  expect_true(grepl("is the Julia Int64 9007199254740993", res$message, fixed = TRUE))
  expect_false(grepl("weft: 2 ", res$message, fixed = TRUE))
})

# ---- J14: Julia's state is left alone --------------------------------------------------------

test_that("J14: after a refused read of big(2)^70 in prose the next Julia chunk runs and the knit reaches its end", {
  pset()
  lines <- c(
    "First `r jl_value(\"t_j5p_b70\")`{.num} x", "",
    "```{julia, include=FALSE}",
    "t_j5p_after = 1 + 1;",
    "```", "",
    "AFTER `r jl_value(\"t_j5p_after\")` x", "",
    "END of the document", "")
  res <- k5j(lines, draft = TRUE)
  expect_false(res$failed, label = res$message)
  expect_true("AFTER 2 x" %in% res$text)
  expect_true("END of the document" %in% res$text)
  expect_equal(nrow(res$failures), 1L)
  expect_identical(res$failures$kind, "value error")
  expect_identical(JuliaCall::julia_eval("1 + 1"), 2L)
  res2 <- k5j(lines)
  expect_true(res2$failed)
  expect_true("weft_failures" %in% res2$class)
  expect_equal(nrow(res2$failures), 1L)
  expect_false(grepl("InexactError", res2$message, fixed = TRUE))
})

# ---- jl_value() in R chunk code and other weft-evaluated places (J2, J15) ---------------

test_that("J2: jl_value() is on the search path in a knit and reads in R chunk code", {
  pset()
  res <- k5j_cases(
    c(R1 = "`r r_n`{.num} x", R2 = "`r r_cfg`{.num} x"),
    before = c("```{r}", "r_n <- jl_value(\"t_j5p_n\")", "r_cfg <- weft::jl_value(\"t_j5p_cfg\", \"depth\")", "```", ""),
    draft = TRUE)
  expect_false(res$failed, label = res$message)
  expect_identical(res$line("R1"), "R1 12 x")
  expect_identical(res$line("R2"), "R2 2.5 x")
})

test_that("J2: jl_value() of 2^53 + 1 in R chunk code stops the chunk with the message", {
  pset()
  res <- k5j(c("```{r}", "x <- jl_value(\"t_j5p_b53\")", "```", "", "After."))
  expect_true(res$failed)
  expect_true(grepl(jm1("`jl_value(\"t_j5p_b53\")`", "Int64", "9007199254740993"), res$message, fixed = TRUE))
})

test_that("J15: a caption construct on an R chunk reads Julia values by J8", {
  pset()
  lines <- c(
    "```{r, echo=FALSE, fig.cap=\"Depth `r jl_value('t_j5p_depth')`{.num} m.\"}",
    "plot(1)",
    "```", "",
    "```{r, echo=FALSE, fig.cap=\"Big `r jl_value('t_j5p_b53')`{.num} m.\"}",
    "plot(2)",
    "```", "")
  res <- k5j(lines, draft = TRUE)
  expect_false(res$failed, label = res$message)
  expect_true(any(grepl("Depth 3.1 m.", res$text, fixed = TRUE)))
  expect_false(any(grepl("Big 9007199254740993 m.", res$text, fixed = TRUE)))
  f <- res$failures
  expect_true(any(f$kind == "value error"))
  expect_true(any(vapply(f$detail, function(d) identical(msg5(d), jm1("`jl_value(\"t_j5p_b53\")`", "Int64", "9007199254740993")), NA)))
})

test_that("J15: weft_str() in an R chunk reads Julia values by J8 and collects its failures", {
  pset()
  lines <- c(
    "```{r, echo=FALSE, results='asis'}",
    "cat(\"WSR:\", weft::weft_str(\"[rose | fell]{if=\\\"jl_value('t_j5p_slope') > 0\\\"}\"), \"\\n\")",
    "cat(\"WSD:\", weft::weft_str(\"`r jl_value('t_j5p_depth')`{.num} m\"), \"\\n\")",
    "cat(\"WSB:\", weft::weft_str(\"`r jl_value('t_j5p_b53')`{.num} m\"), \"\\n\")",
    "```", "")
  res <- k5j(lines, draft = TRUE)
  expect_false(res$failed, label = res$message)
  expect_true("WSR: rose" %in% res$text)
  expect_true("WSD: 3.1 m" %in% res$text)
  expect_false(any(grepl("^WSB: 9007199254740993", res$text)))
  expect_true(any(vapply(res$failures$detail,
                         function(d) identical(msg5(d), jm1("`jl_value(\"t_j5p_b53\")`", "Int64", "9007199254740993")), NA)))
})

test_that("J15: outside a knit weft_str() stops at once with the value error", {
  skip_if_no_julia()
  jl_set(t_j5p_ws1 = "2^53 + 1", t_j5p_ws2 = "3.14159")
  expect_refused5(weft_str("`r jl_value('t_j5p_ws1')`{.num}"),
                  jm1("`jl_value(\"t_j5p_ws1\")`", "Int64", "9007199254740993"))
  expect_identical(as.character(weft_str("`r jl_value('t_j5p_ws2')`{.num} m")), "3.1 m")
})

test_that("J15: x <- JuliaCall::julia_eval(\"b53\") in an R chunk is JuliaCall's conversion, pinned as the documented limit", {
  pset()
  lines <- c(
    "```{r, echo=FALSE, results='asis'}",
    "x <- JuliaCall::julia_eval(\"t_j5p_b53\")",
    "cat(\"LIMIT:\", x, \"\\n\")",
    "```", "")
  res <- k5j(lines, draft = TRUE)
  expect_true(res$failed)
  expect_true(grepl("InexactError", res$message, fixed = TRUE))
})

test_that("J15: under Quarto with engine: knitr a Julia read is guarded the same way, in prose and in a caption", {
  skip_if_no_quarto()
  skip_if_no_julia()
  lines <- c(
    "```{julia}",
    "#| include: false",
    "t_j5p_depth = 3.14159;",
    "t_j5p_b53 = 2^53 + 1;",
    "```", "",
    "Depth `{r} jl_value(\"t_j5p_depth\")`{.num} m.", "",
    "Big `{r} jl_value(\"t_j5p_b53\")`{.num} m.", "",
    "```{r}",
    "#| label: fig-depth",
    "#| fig-cap: |",
    "#|   Cap depth `r jl_value(\"t_j5p_depth\")`{.num} m.",
    "plot(1)",
    "```", "",
    "```{r}",
    "#| label: fig-big",
    "#| fig-cap: |",
    "#|   Cap big `r jl_value(\"t_j5p_b53\")`{.num} m.",
    "plot(2)",
    "```", "")
  res <- render_qmd(lines, env = c(WEFT_DRAFT = "1"))
  expect_false(res$failed, label = substr(res$message, 1, 400))
  expect_true(any(grepl("Depth 3.1 m.", res$text, fixed = TRUE)))
  expect_true(any(grepl("Cap depth 3.1 m.", res$text, fixed = TRUE)))
  expect_false(any(grepl("Big 9007199254740993 m.", res$text, fixed = TRUE)))
  # Quarto's markdown escapes the angle brackets of a marker, so look for the words
  expect_gte(sum(grepl("weft: value error", res$text, fixed = TRUE)), 2L)
})

# ---- J12: Julia is not there -------------------------------------------------------------

test_that("J12 seam: without JuliaCall a value is a collected \"no value\" with JM15", {
  withr::local_options(weft.juliacall = FALSE)
  res <- k5j_cases(c(N1 = "`r jl_value(\"t_j5p_x\")`{.num} x"), draft = TRUE)
  expect_identical(res$line("N1"), paste("N1", res$marker("N1", "no value"), "x"))
  f <- res$fail("N1")
  expect_identical(f$kind, "no value")
  expect_match(msg5(f$detail), "^error evaluating ")
  expect_true(grepl(jm15("jl_value(\"t_j5p_x\")"), msg5(f$detail), fixed = TRUE))
})

test_that("J12 seam: without JuliaCall a bare read stops the knit with JM15", {
  withr::local_options(weft.juliacall = FALSE)
  res <- k5j_cases(c(N2 = "`r jl_value(\"t_j5p_x\")` x"))
  expect_true(res$failed)
  expect_true(grepl(jm15("jl_value(\"t_j5p_x\")"), res$message, fixed = TRUE))
})

# ---- J12, J13: fresh process A, which starts no Julia -------------------------------------

fresh_a <- function() {
  if (is.null(.w5j$fresh_a)) {
    .w5j$fresh_a <- k5j_fresh(r"---(
weft::weft_setup()
res <- list()
res$setup_loaded <- "JuliaCall" %in% loadedNamespaces()
res$ronly <- knit1(c(
  "R-only `r 3.14159`{.num} m and `r 2 + 3` bare.", "",
  "```{r, echo=FALSE, results='asis'}",
  "cat(\"JLLOADED:\", \"JuliaCall\" %in% loadedNamespaces(), \"\\n\")",
  "```"))
res$after_ronly <- "JuliaCall" %in% loadedNamespaces()
saveRDS(res, .out)
Sys.setenv(JULIA_HOME = "/nonexistent/weft-no-julia")
res$jm16_value <- knit1("N3 `r jl_value(\"t_j5p_x\")`{.num} x", draft = TRUE)
res$jm16_bare <- knit1("N4 `r jl_value(\"t_j5p_x\")` x")
saveRDS(res, .out)
)---")
  }
  .w5j$fresh_a
}

test_that("J13: weft_setup() alone loads no JuliaCall (fresh process)", {
  skip_if_not_installed("JuliaCall")
  res <- fresh_a()
  skip_if(is.null(res$setup_loaded), "the child saved nothing")
  expect_false(res$setup_loaded)
})

test_that("J13: a document with no Julia chunk and no jl_value() leaves JuliaCall unloaded and its output as today (fresh process)", {
  skip_if_not_installed("JuliaCall")
  res <- fresh_a()
  skip_if(is.null(res$ronly), "the child saved nothing")
  expect_false(res$ronly$failed, label = res$ronly$message)
  expect_true("R-only 3.1 m and 5 bare." %in% trimws(res$ronly$text))
  expect_true("JLLOADED: FALSE" %in% trimws(res$ronly$text))
  expect_false(res$after_ronly)
})

test_that("J12: when JuliaCall cannot start Julia a value is a collected \"no value\" with JM16 (fresh process, JULIA_HOME missing)", {
  skip_if_not_installed("JuliaCall")
  res <- fresh_a()
  skip_if(is.null(res$jm16_value), "the child saved nothing")
  r <- res$jm16_value
  expect_false(r$failed, label = r$message)
  expect_true(any(grepl("N3 <<weft: no value, line [0-9]+>> x", r$text)))
  f <- r$failures
  expect_equal(nrow(f), 1L)
  expect_identical(f$kind, "no value")
  expect_match(msg5(f$detail), "^error evaluating ")
  expect_true(grepl(jm16("jl_value(\"t_j5p_x\")", "Julia is not found."), msg5(f$detail), fixed = TRUE))
})

test_that("J12: when JuliaCall cannot start Julia a bare read stops the knit with JM16 (fresh process)", {
  skip_if_not_installed("JuliaCall")
  res <- fresh_a()
  skip_if(is.null(res$jm16_bare), "the child saved nothing")
  expect_true(res$jm16_bare$failed)
  expect_true(grepl(jm16("jl_value(\"t_j5p_x\")", "Julia is not found."), msg5(res$jm16_bare$message), fixed = TRUE))
})

# ---- J16, J9: fresh process B, which starts Julia ----------------------------------------

fresh_b <- function() {
  if (is.null(.w5j$fresh_b)) {
    .w5j$fresh_b <- k5j_fresh(r"---(
res <- list()
res$j16 <- knit1(c("```{julia, include=FALSE}", "t_j5p_x16 = 1;", "```", "", "No reads here."))
res$j16_defined <- JuliaCall::julia_eval("isdefined(Main, :WeftGuest)")
saveRDS(res, .out)
res$m <- knit1(c("```{julia, include=FALSE}", "t_j5p_m = missing;", "```", "",
                 "M1 `r jl_value(\"t_j5p_m\")` x"), draft = TRUE)
saveRDS(res, .out)
res$after <- JuliaCall::julia_eval("1 + 1")
saveRDS(res, .out)
)---")
  }
  .w5j$fresh_b
}

test_that("J16: after the first Julia chunk of a weft knit whose prose has no jl_value(), WeftGuest is defined (fresh process)", {
  skip_if_no_julia()
  res <- fresh_b()
  expect_identical(attr(res, "status"), 0L)
  skip_if(is.null(res$j16), "the child saved nothing")
  expect_false(res$j16$failed, label = res$j16$message)
  expect_true(any(grepl("No reads here.", res$j16$text, fixed = TRUE)))
  expect_true(res$j16_defined)
})

test_that("J9: a bare read of a Julia missing prints NA and R is still running (fresh process)", {
  skip_if_no_julia()
  res <- fresh_b()
  expect_identical(attr(res, "status"), 0L)
  skip_if(is.null(res$m), "the child saved nothing")
  expect_false(res$m$failed, label = res$m$message)
  expect_true("M1 NA x" %in% trimws(res$m$text))
  expect_identical(res$after, 2L)
})

# ---- J26: captions on Julia chunks, at knit time --------------------------------------------

test_that("J26: a fig.cap holding an `n` construct on Julia chunk j1 is a construct error at knit time, with the exact message", {
  lines <- c(
    "```{julia j1, fig.cap=\"[# site | # sites]{n=\\\"3\\\"}\"}",
    "t_j5p_cap = 1;",
    "```", "")
  res <- k5j(lines)
  expect_true(res$failed)
  expect_true(grepl(paste0(
    "A `n` construct in a caption of chunk `j1`, which uses the `julia` engine, not R: write the caption in a ",
    "figure or table div instead, `::: {#fig-name}` ... caption paragraph ... `:::` (rules 1.10.5, 2.3.5)."),
    res$message, fixed = TRUE))
})
