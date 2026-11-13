# Package 6R, the Julia side: failing tests for open findings 15 and 17 of dev/open-findings.md (stage 6) and
# the rulings of dev/review-stage6.md ("Suspected" paragraph: on the julia engine a failed `@claim` prints its
# carrier and does not also `display()` it; "Python and Julia `put` under knitr are wired to R's waiting
# names"). Labels: "open-6 #N". Helpers: helper-julia-engine.R, helper-6b.R, helper-5j.R, helper-6k.R,
# helper-filter.R. Julia through JuliaCall (skip_if_no_julia), a plain `julia` process (jle_cases) or a
# Quarto render on the julia engine (skip_if_no_julia_engine). ASCII only.
#
# READINGS:
#  - the engine back end is chosen by kind() (Weft.jl): a notebook worker is recognised by the module
#    `QuartoNotebookWorker` in Main. The plain-process tests define that module to get the engine back end
#    without a render, and push a display of their own that records what `display()` is given, so "not
#    displayed" is seen without Quarto;
#  - the `lang` of a block the hooks write for records Julia handed over is not pinned.

jle_kill_at_file_end()

# ---- the engine back end in a plain julia process ---------------------------------------------------------------

JL_ENGINE_PRE <- paste(
  "using Weft",
  "Core.eval(Main, :(module QuartoNotebookWorker end))",
  "struct Cap <: AbstractDisplay end",
  "Base.display(::Cap, x) = (println(\"DISPLAYED \", typeof(x)); nothing)",
  "Base.display(::Cap, m::MIME, x) = (println(\"DISPLAYED \", typeof(x)); nothing)",
  "pushdisplay(Cap())",
  "n = 7",
  sep = "\n")

jl_engine_run <- function() {
  if (!is.null(.jle$engine6)) return(.jle$engine6)
  .jle$engine6 <- jle_cases(c(
    paste(JL_ENGINE_PRE, "@claim n > 10", sep = "\n"),
    paste(JL_ENGINE_PRE, "@claim n > 10 level=:warn", "println(\"after\")", sep = "\n"),
    paste(JL_ENGINE_PRE, "println(\"printed before\")", "@claim n > 10", sep = "\n"),
    paste(JL_ENGINE_PRE, "println(@claim n > 1)", sep = "\n")
  ))
}

CARRIER_RE <- "^~~~~\\{\\.weft-values\\}\n(\\{[^\n]*\\})\n~~~~\n"

test_that("open-6 (ruling on Suspected): on the julia engine a failed @claim prints its carrier with ~~~~ fences and throws, and does NOT also display() it", {
  x <- jl_engine_run()[[1]]
  expect_identical(x$etype, "ClaimFailed")
  expect_true(grepl(jle_msg$E55("n > 10", "7"), x$emsg, fixed = TRUE), label = x$emsg)
  # today the block is displayed first: "DISPLAYED Weft.Values", the four-backtick text, then the carrier
  expect_false(grepl("DISPLAYED", x$out, fixed = TRUE), label = x$out)
  expect_false(grepl("````", x$out, fixed = TRUE))
  # what is left is the carrier, once, whole
  expect_match(x$out, paste0(CARRIER_RE, "$"))
  expect_identical(lengths(regmatches(x$out, gregexpr("weft-values", x$out, fixed = TRUE))), 1L)
  j <- tryCatch(jsonlite::fromJSON(sub(paste0(CARRIER_RE, "$"), "\\1", x$out), simplifyVector = FALSE),
                error = function(e) list())
  expect_identical(as.integer(j$weft), 1L)
  expect_identical(j$lang, "julia")
  ch <- Filter(function(ch) isFALSE(ch$ok), j$checks)
  expect_length(ch, 1L)
  expect_identical(ch[[1]]$text, "n > 10")
  expect_identical(ch[[1]]$expr, "@claim n > 10")
  expect_identical(ch[[1]]$level, "fail")
  expect_identical(list(ch[[1]]$value$t, ch[[1]]$value$v), list("int", "7"))
})

test_that("open-6 (ruling on Suspected): text printed before a failed claim stays before the carrier, which is the end of the output", {
  x <- jl_engine_run()[[3]]
  expect_identical(x$etype, "ClaimFailed")
  expect_false(grepl("DISPLAYED", x$out, fixed = TRUE), label = x$out)
  expect_match(x$out, paste0("^printed before\n", sub("^\\^", "", CARRIER_RE), "$"))
})

test_that("open-6 control (N57): a warned claim on the engine is displayed, once, and prints no carrier and throws nothing", {
  x <- jl_engine_run()[[2]]
  expect_true(is.na(x$etype) || identical(x$etype, ""), label = paste(x$etype, x$emsg))
  expect_identical(lengths(regmatches(x$out, gregexpr("DISPLAYED Weft.Values", x$out, fixed = TRUE))), 1L)
  expect_false(grepl("~~~~", x$out, fixed = TRUE))
  expect_match(x$out, "after\n$")
})

test_that("open-6 control (N57): a claim that passes displays and prints nothing", {
  x <- jl_engine_run()[[4]]
  expect_true(is.na(x$etype) || identical(x$etype, ""), label = paste(x$etype, x$emsg))
  expect_identical(x$out, "7\n")
})

# ---- open-6 #15: a carrier at the END of a stdout block is read, whatever was printed before it ---------------

TRAIL_DOC <- c(
  "---", "title: Trail", "execute:", "  error: true", "---", "",
  "```{julia}", "#| include: false", "using Weft", "```", "",
  "```{julia}", "#| label: late", "#| echo: false",
  "n = 7",
  "println(\"a line printed first\")",
  "@claim n > 10",
  "```", "",
  "The end.")

trail_render <- function() {
  if (!is.null(.jle$trail6)) return(.jle$trail6)
  dir <- jle_project(list(`trail.qmd` = TRAIL_DOC))
  .jle$trail6 <- list(res = jle_render(dir, "trail.qmd"), dir = dir)
}

test_that("open-6 #15: a failed @claim whose cell printed text first is reported by the filter, at the line of the call, and the render fails", {
  x <- trail_render()$res
  l <- which(TRAIL_DOC == "@claim n > 10")
  e <- fm_entry(x$stderr, sprintf("^  trail\\.qmd:%d  ", l))
  # today: the carrier is not the whole stdout block, so the filter does not read it and reports nothing
  expect_true(e$found, label = x$stderr)
  expect_true(grepl("@claim n > 10", e$head, fixed = TRUE), label = e$head)
  expect_identical(e$detail, fm_msg$E14("n > 10", "7"))
  expect_identical(x$status, 1L)
})

# ---- open-6 #17 (and 12): Weft.put and @put under knitr hand their records to R's waiting names -----------------

jl_knit <- function(lines, ...) {
  res <- k5j(lines, jl = "using Weft", ...)
  res$blocks <- b6_blocks(res$text)
  res
}

test_that("open-6 #17: Weft.put() and @put in Julia chunks of a knitr document: the next prose block's carrier holds the names, and nothing is printed", {
  res <- jl_knit(c(
    jc6k("jp1", "Weft.put(n_sites = 12)", opts = "echo=FALSE"),
    jc6k("jp2", "a = 3", "@put a", opts = "echo=FALSE"),
    "Uses `n_sites`{.num} and `a`{.num}."
  ))
  expect_false(res$failed, label = res$message)
  # today the records wait in Weft.jl (drain_puts()) and no R code reads them
  expect_length(res$blocks, 1L)
  expect_identical(sum(grepl("weft-values", res$text, fixed = TRUE)), 1L)
  if (length(res$blocks) != 1L) return(invisible())
  b <- res$blocks[[1]]
  expect_setequal(names(b$block$values), c("n_sites", "a"))
  expect_identical(b6_core(b$block$values$n_sites), b6_e_int("12"))
  expect_identical(b6_core(b$block$values$a), b6_e_int("3"))
  expect_true(b$close < b6_line(res$text, "Uses `n_sites`"))
  expect_true(any(grepl("`n_sites`{.num}", res$text, fixed = TRUE)))
})

test_that("open-6 #17: a Julia put() with no prose after it is published at the end of the document", {
  res <- jl_knit(c(
    "Uses `tail_name`{.num}.", "",
    jc6k("jlast", "Weft.put(tail_name = 5)", opts = "include=FALSE")
  ))
  expect_false(res$failed, label = res$message)
  expect_length(res$blocks, 1L)
  if (length(res$blocks) != 1L) return(invisible())
  expect_identical(b6_core(res$blocks[[1]]$block$values$tail_name), b6_e_int("5"))
  expect_true(res$blocks[[1]]$open > b6_line(res$text, "Uses `tail_name`"))
})

test_that("open-6 #17 control: a Julia name that put() does not publish is not published by the hooks", {
  res <- jl_knit(c(
    jc6k("jp1", "n_sites = 12", opts = "include=FALSE"),
    "Uses `n_sites`{.num}."
  ))
  expect_false(res$failed, label = res$message)
  expect_length(res$blocks, 0L)
})
