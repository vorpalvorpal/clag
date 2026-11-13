# Package 5e: the static Julia lints (dev/design-5.md J23, J24, J25, J26's static case; rules 5.11.1, 5.11.3, 5.8.9).
# They replace what G34, G37 and G38 said of Julia. No Julia or JuliaCall is needed: nothing runs.
# READING: J25 says "Case 1 when the front matter says `engine: julia`": the message is G38's case 1 message naming
# `engine: julia`; the other cases of case 1 keep G38's (Python) hint.

G5E_JL_HINT <- "A value from another language reaches prose through R; see vignette(\"languages\", package = \"weft\")."
g5e_jl_lint <- function(lines, rule, ext = "Rmd", tier = 1:2, env = parent.frame()) {
  lint_one(lines, rules = rule, ext = ext, tier = tier, env = env)
}

# ---- J23: guest-inline for Julia ---------------------------------------------------------------------------

G5E_JL_INLINE <- paste0("`{julia} depth` is inline Julia, which the knitr engine does not run: it would print as ",
                        "code. Bind the value to a name in a Julia chunk and write `r jl_value(\"name\")` ",
                        "(rule 5.11.1).")

test_that("5e J23: `{julia} depth` in an .Rmd and in an engine: knitr .qmd, exact message and G34's hint", {
  lines <- c("Intro.", "", "The depth is `{julia} depth` metres.")
  docs <- list(Rmd = list(lines, "Rmd"), rmd = list(lines, "rmd"),
               qmd = list(f3d_doc(lines, "engine: knitr"), "qmd"))
  for (nm in names(docs)) {
    x <- g5e_jl_lint(docs[[nm]][[1]], "guest-inline", ext = docs[[nm]][[2]])
    expect_findings_shape(x)
    expect_identical(nrow(x), 1L, label = nm)
    expect_identical(x$tier, 1L)
    expect_identical(x$text, "`{julia} depth`", label = nm)
    expect_identical(x$message, G5E_JL_INLINE, label = nm)
    expect_identical(x$hint, G5E_JL_HINT, label = nm)
  }
})

test_that("5e J23: an attribute block after it does not change the finding; not in a Jupyter .qmd or a literal", {
  x <- g5e_jl_lint("The depth is `{julia} depth`{.num} metres.", "guest-inline")
  expect_identical(nrow(x), 1L)
  expect_identical(x$message, G5E_JL_INLINE)
  expect_identical(nrow(g5e_jl_lint("A `{julia} depth` here.", "guest-inline", ext = "qmd")), 0L)
  expect_identical(nrow(g5e_jl_lint(f3d_doc("A `{julia} depth` here.", "engine: jupyter"), "guest-inline",
                                    ext = "qmd")), 0L)
  expect_identical(nrow(g5e_jl_lint("A [`{julia} depth`]{.weft-literal why=\"syntax\"} here.", "guest-inline")), 0L)
})

test_that("5e J23: `{bash} x` keeps G34's text for another language", {
  x <- g5e_jl_lint("A `{bash} x` here.", "guest-inline")
  expect_identical(x$message,
    paste0("`{bash} x` is inline bash code, which the knitr engine does not run: it would print as code ",
           "(rule 5.11.1)."))
  expect_identical(x$hint, G5E_JL_HINT)
})

# ---- J24: guest-read for JuliaCall -------------------------------------------------------------------------

g5e_jl_read_msg <- function(call) {
  sprintf(paste0("`%s` is converted by JuliaCall, which stops on a whole number beyond ±2^31 and crashes R on ",
                 "a Julia missing. Read a Julia value with jl_value() (rule 5.11.3)."), call)
}

test_that("5e J24: julia_eval and julia_call in a value, with and without JuliaCall::, quote the call as written", {
  for (fn in c("julia_eval", "julia_call")) {
    for (pre in c("", "JuliaCall::")) {
      call <- sprintf("%s%s(\"x\")", pre, fn)
      x <- g5e_jl_lint(sprintf("A value `r %s` here.", call), "guest-read")
      expect_identical(nrow(x), 1L, label = call)
      expect_identical(x$rule, "guest-read")
      expect_identical(x$tier, 2L)
      expect_identical(x$text, call, label = call)
      expect_identical(x$message, g5e_jl_read_msg(call), label = call)
    }
  }
})

test_that("5e J24: the same in a typed value, a bare value and a governor", {
  x <- g5e_jl_lint("A value `r JuliaCall::julia_eval(\"x\")`{.num} here.", "guest-read")
  expect_identical(x$message, g5e_jl_read_msg("JuliaCall::julia_eval(\"x\")"))
  x <- g5e_jl_lint("A bare `r julia_call(\"f\", 2)` here.", "guest-read")
  expect_identical(x$text, "julia_call(\"f\", 2)")
  expect_identical(x$message, g5e_jl_read_msg("julia_call(\"f\", 2)"))
  x <- g5e_jl_lint("The level [rose]{if=\"julia_eval('t')\"} again.", "guest-read")
  expect_identical(nrow(x), 1L)
  expect_identical(x$text, "julia_eval('t')")
  expect_identical(x$message, g5e_jl_read_msg("julia_eval('t')"))
})

test_that("5e J24: julia_get (no such function), jl_value() and weft::jl_value() are not findings", {
  for (call in c("julia_get(\"x\")", "JuliaCall::julia_get(\"x\")", "jl_value(\"x\")", "weft::jl_value(\"x\")",
                 "jl_value(\"cfg\", \"depth\")")) {
    expect_identical(nrow(g5e_jl_lint(sprintf("A value `r %s` here.", call), "guest-read")), 0L, label = call)
  }
})

test_that("5e J24: a julia_eval() in R chunk code is not a finding (V21)", {
  code <- c3_chunk(c("x <- julia_eval(\"1 + 1\")", "y <- JuliaCall::julia_call(\"f\", 2)"))
  expect_identical(nrow(g5e_jl_lint(code, "guest-read")), 0L)
  expect_identical(nrow(g5e_jl_lint(code, "guest-read", ext = "qmd")), 0L)
})

test_that("5e J24: tier 2, so absent from lints() by default", {
  root <- lint_proj(list("a.Rmd" = "A value `r julia_eval(\"x\")` here."))
  # a rule named in `rules` runs whatever its tier (review 3 #9), so "by default" means no `rules`
  expect_identical(sum(lints(root)$rule == "guest-read"), 0L)
  expect_identical(nrow(lints(root, rules = "guest-read", tier = 2)), 1L)
})

# ---- J25: the engine message for Julia ---------------------------------------------------------------------

G5E_JL_BODY <- r"{Words [a site]{if="ok"} more.}"
G5E_JL_CHUNK <- c("```{julia}", "x = 1", "```")
g5e_jl_engine <- function(lines) lint_fixture(list("a.qmd" = lines), rules = "engine", tier = 1:2)

test_that("5e J25: case 3's hint names jl_value", {
  x <- g5e_jl_engine(c(G5E_JL_BODY, "", G5E_JL_CHUNK))
  expect_identical(nrow(x), 1L)
  expect_identical(x$message, paste0("a.qmd holds weft constructs and Julia chunks but is not marked `engine: knitr`, ",
    "so Quarto would run it with its julia engine, which does not evaluate weft constructs (rule 5.8.9)."))
  expect_identical(x$hint, paste0("Add `engine: knitr` to its front matter. Julia chunks then run through JuliaCall, ",
    "and a Julia value reaches prose as `r jl_value(\"x\")`."))
})

test_that("5e J25: case 1 with engine: julia has the Julia hint", {
  x <- g5e_jl_engine(f3d_doc(c(G5E_JL_BODY, "", G5E_JL_CHUNK), "engine: julia"))
  expect_identical(nrow(x), 1L)
  expect_identical(x$message, paste0("a.qmd holds weft constructs and is marked `engine: julia`; weft constructs ",
    "are evaluated only under `engine: knitr` (rule 5.8.9)."))
  expect_identical(x$hint, paste0("Change it to `engine: knitr`. Julia chunks then run through JuliaCall, and a ",
    "Julia value reaches prose as `r jl_value(\"x\")`."))
})

test_that("5e J25: case 1 with engine: jupyter, or a jupyter: key, keeps G38's hint", {
  py_hint <- paste0("Change it to `engine: knitr`. Python chunks then run through reticulate, and a Python value ",
                    "reaches prose as `r py$x`.")
  for (front in c("engine: jupyter", "jupyter: julia-1.13")) {
    x <- g5e_jl_engine(f3d_doc(c(G5E_JL_BODY, "", G5E_JL_CHUNK), front))
    expect_identical(nrow(x), 1L, label = front)
    expect_identical(x$hint, py_hint, label = front)
  }
})

# ---- J26: captions on Julia chunks, static case ------------------------------------------------------------

test_that("5e J26: an n construct in the fig-cap of a Julia chunk is a construct finding, exact message", {
  doc <- f3d_doc(c("```{julia}", "#| label: j1", "#| fig-cap: |", "#|   [# site | # sites]{n=\"k\"}", "x = 1", "```"),
                 "engine: knitr")
  x <- lint_one(doc, rules = "construct", tier = 1:2)
  expect_identical(nrow(x), 1L)
  expect_identical(x$context, "caption")
  expect_identical(x$message, paste0("A `n` construct in a caption of chunk `j1`, which uses the `julia` engine, ",
    "not R: write the caption in a figure or table div instead, `::: {#fig-name}` ... caption paragraph ... `:::` ",
    "(rules 1.10.5, 2.3.5)."))
})
