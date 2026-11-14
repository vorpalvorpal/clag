# Package 6k: the gate and the lints for guest claims (rule N59 of dev/design-6.md; message E58).
# Static: no test here needs Python or Julia. Helpers: helper-6k.R, helper-4a.R (g_scenario, g_gate,
# G_ENGINE), helper-3.R (read_src, lint_one), helper-3c.R (c3_chunk). Invented content only; every git
# repository is a temporary one with git isolated by g_repo().
#
# READINGS of the note (see the report):
#  - "an executed chunk" is read as G35 reads it: engine python or julia and `eval` not false. So a
#    guest chunk with `#| eval: false` counts nothing (an R chunk is read the same way), and
#    turning eval off on a chunk that holds a guest claim is a removal.
#  - the pattern is applied to every match on a line: `x = claim(a, ">1")  # claim(` is two.
#  - a count's `text` is not pinned; its `line` is the file line of the line the match is on.

E58 <- paste0("`claim()` cannot be called through `r.`: reticulate converts its argument with no check. ",
              "Write `from weft import claim` and `claim(n, \"> 10\")` (rule 5.11.2).")

# ---- the pattern, Python (count_constructs) ------------------------------------------------------

py_cases <- list(
  list("x = claim(n, \"> 10\")", 1L, "a bare call"),
  list("x = weft.claim(n, \"> 10\")", 1L, "weft.claim( is one call"),
  list("    ok = claim(a, \"> 1\")", 1L, "an indented call"),
  list("x = claim(a, \">1\"); y = claim(b, \">2\")", 2L, "two calls on a line"),
  list("x = [claim(a, \">1\"), claim(b, \">2\")]", 2L, "two calls in a list"),
  list("a = weft.claim(a, \">1\"); b = weft.claim(b, \">2\")", 2L, "two weft.claim( on a line"),
  list("# claim(n, \"> 10\")", 0L, "a comment line"),
  list("    # claim(n, \"> 10\")", 0L, "an indented comment line"),
  list("def claim(x, *checks):", 0L, "a definition"),
  list("obj.claim(n, \"> 10\")", 0L, "an attribute call"),
  list("r.claim(3, 4)", 0L, "r.claim( is the lint's, not a call"),
  list("my_claim(n)", 0L, "a longer name"),
  list("claim2(n)", 0L, "a name with a digit after claim"),
  list("x2claim(n)", 0L, "a digit before claim"),
  list("from weft import claim", 0L, "an import has no parenthesis"),
  list("claim = 3", 0L, "an assignment"),
  list("claim (n)", 0L, "a space before the parenthesis"),
  list("print(\"claim(\")", 1L, "a string literal counts (accepted: no parser)"),
  list("ok = 1  # claim(n)", 1L, "a trailing comment counts (the line starts with code)"),
  list("x = 1", 0L, "no claim")
)

test_that("N59: in a python chunk, claim( and weft.claim( count by the token pattern, one per match", {
  for (cs in py_cases) {
    x <- claims6k(cs[[1]], "python")
    expect_identical(nrow(x), cs[[2]], label = paste0(cs[[3]], ": ", cs[[1]]))
  }
})

test_that("N59: the rows are kind claim and are on the line of the match", {
  lines <- c("Intro.", "", c3_chunk(c("import weft", "x = 1", "y = claim(x, \"> 0\")", "z = 2"), engine = "python"))
  x <- cc6k(lines)
  x <- x[x$kind == "claim", , drop = FALSE]
  expect_identical(nrow(x), 1L)
  expect_identical(x$line, which(grepl("^y = claim", lines)))
})

test_that("N59: a multi-line call counts once, at the line of claim(", {
  lines <- c("Intro.", "", c3_chunk(c("claim(", "    n, \"> 10\")"), engine = "python"))
  x <- cc6k(lines)
  x <- x[x$kind == "claim", , drop = FALSE]
  expect_identical(nrow(x), 1L)
  expect_identical(x$line, which(lines == "claim("))
})

# ---- the pattern, Julia -----------------------------------------------------------------------------

jl_cases <- list(
  list("@claim n > 10", 1L, "a bare macro call"),
  list("Weft.@claim n > 10", 1L, "Weft.@claim is one call"),
  list("@claim(n > 10)", 1L, "a parenthesised macro call"),
  list("    @claim x (_ > 1) (_ < 9)", 1L, "an indented call with checks"),
  list("@claim a > 1; @claim b > 1", 2L, "two calls on a line"),
  list("# @claim n > 10", 0L, "a comment line"),
  list("    # @claim n > 10", 0L, "an indented comment line"),
  list("@claims n", 0L, "a longer macro name"),
  list("@claim_it n", 0L, "a longer macro name with an underscore"),
  list("x@claim n", 0L, "a letter before the @"),
  list("claim(n)", 0L, "a plain function call is not a macro call"),
  list("println(\"@claim\")", 1L, "a string literal counts (accepted: no parser)"),
  list("e = 1  # @claim x > 1", 1L, "a trailing comment counts (the line starts with code)"),
  list("x = 1", 0L, "no claim")
)

test_that("N59: in a julia chunk, @claim and Weft.@claim count by the token pattern, one per match", {
  for (cs in jl_cases) {
    x <- claims6k(cs[[1]], "julia")
    expect_identical(nrow(x), cs[[2]], label = paste0(cs[[3]], ": ", cs[[1]]))
  }
})

# ---- the pattern is per language ---------------------------------------------------------------------

test_that("N59: a python claim( in a julia chunk, and a julia @claim in a python chunk, count nothing", {
  expect_identical(nrow(claims6k("x = claim(n, \"> 10\")", "julia")), 0L)
  expect_identical(nrow(claims6k("@claim n > 10", "python")), 0L)
})

test_that("N59: R chunks and prose keep their own rule: claim() in an R chunk counts, `claim(` in prose does not", {
  x <- claims6k("claim(n_sites, . > 10)", "r")
  expect_identical(nrow(x), 1L)
  y <- cc6k(c("The claim(n) function is described here.", "", "Another sentence."))
  expect_identical(sum(y$kind == "claim"), 0L)
})

test_that("N59: a guest chunk that is not executed (eval: false) counts nothing", {
  for (eng in c("python", "julia")) {
    code <- if (eng == "python") "x = claim(n, \"> 10\")" else "@claim n > 10"
    x <- cc6k(c("Intro.", "", c3_chunk(code, "#| eval: false", engine = eng)))
    expect_identical(sum(x$kind == "claim"), 0L, label = eng)
  }
})

test_that("N59: .Rmd documents count the same way as .qmd", {
  lines <- c("Intro.", "", c3_chunk("x = claim(n, \"> 10\")", engine = "python"), "",
             c3_chunk("@claim n > 10", engine = "julia"))
  x <- cc6k(lines, ext = "Rmd")
  expect_identical(sum(x$kind == "claim"), 2L)
})

# ---- the gate: removing a guest claim needs the trailer, adding one does not ----------------------------

gate_doc <- function(code, engine, more = character()) {
  c("Intro paragraph.", "", c3_chunk(code, engine = engine), more, G_ENGINE)
}

gate_py <- function(code) gate_doc(code, "python")
gate_jl <- function(code) gate_doc(code, "julia")

removed_6k <- function(res) max(0, res$n_removed)

test_that("N59: deleting a claim( from a python chunk is a removal: the gate fails without the trailer and lists it as a claim", {
  d <- g_scenario(list("ch1.qmd" = gate_py(c("n = 12", "claim(n, \"> 10\")"))),
                  list("ch1.qmd" = gate_py(c("n = 12"))))
  res <- g_gate(d)
  expect_false(res$ok)
  expect_identical(res$n_removed, 1L)
  expect_identical(res$removed$kind, "claim")
  expect_true(grepl("ch1\\.qmd$", res$removed$file))
})

test_that("N59: with Weft-Removed: 1 the python removal passes", {
  d <- g_scenario(list("ch1.qmd" = gate_py(c("n = 12", "claim(n, \"> 10\")"))),
                  list("ch1.qmd" = gate_py(c("n = 12"))))
  res <- g_gate(d, c("Drop a check", "", "Weft-Removed: 1"))
  expect_true(res$ok)
  expect_identical(res$trailer, 1L)
  expect_identical(res$n_removed, 1L)
})

test_that("N59: deleting an @claim from a julia chunk is a removal that needs the trailer", {
  d <- g_scenario(list("ch1.qmd" = gate_jl(c("n = 12", "@claim n > 10"))),
                  list("ch1.qmd" = gate_jl(c("n = 12"))))
  res <- g_gate(d)
  expect_false(res$ok)
  expect_identical(res$n_removed, 1L)
  expect_identical(res$removed$kind, "claim")
  expect_true(g_gate(d, c("Drop a check", "", "Weft-Removed: 1"))$ok)
})

test_that("N59: deleting a weft.claim( or a Weft.@claim is a removal too", {
  d1 <- g_scenario(list("ch1.qmd" = gate_py(c("import weft", "weft.claim(n, \"> 10\")"))),
                   list("ch1.qmd" = gate_py(c("import weft"))))
  expect_identical(g_gate(d1)$n_removed, 1L)
  d2 <- g_scenario(list("ch1.qmd" = gate_jl(c("import Weft", "Weft.@claim n > 10"))),
                   list("ch1.qmd" = gate_jl(c("import Weft"))))
  expect_identical(g_gate(d2)$n_removed, 1L)
})

test_that("N59: adding a guest claim is not a removal, in either language", {
  d1 <- g_scenario(list("ch1.qmd" = gate_py(c("n = 12"))),
                   list("ch1.qmd" = gate_py(c("n = 12", "claim(n, \"> 10\")"))))
  res1 <- g_gate(d1)
  expect_identical(removed_6k(res1), 0)
  expect_true(res1$ok)
  d2 <- g_scenario(list("ch1.qmd" = gate_jl(c("n = 12"))),
                   list("ch1.qmd" = gate_jl(c("n = 12", "@claim n > 10"))))
  res2 <- g_gate(d2)
  expect_identical(removed_6k(res2), 0)
  expect_true(res2$ok)
})

test_that("N59: changing a bound, or renaming the value, removes nothing", {
  d1 <- g_scenario(list("ch1.qmd" = gate_py("claim(n, \"> 10\")")),
                   list("ch1.qmd" = gate_py("claim(n, \"> 5\")")))
  expect_identical(removed_6k(g_gate(d1)), 0)
  d2 <- g_scenario(list("ch1.qmd" = gate_jl("@claim n > 10")),
                   list("ch1.qmd" = gate_jl("@claim depth > 10")))
  expect_identical(removed_6k(g_gate(d2)), 0)
})

test_that("N59: removing one of two claims on a line removes one", {
  d <- g_scenario(list("ch1.qmd" = gate_py("x = claim(a, \">1\"); y = claim(b, \">2\")")),
                  list("ch1.qmd" = gate_py("x = claim(a, \">1\"); y = b")))
  expect_identical(g_gate(d)$n_removed, 1L)
})

test_that("N59: a claim( inside a python comment line costs nothing either way; one inside a string counts, so removing it needs the trailer", {
  d1 <- g_scenario(list("ch1.qmd" = gate_py(c("x = 1", "# claim(n, \"> 10\")"))),
                   list("ch1.qmd" = gate_py(c("x = 1"))))
  expect_identical(removed_6k(g_gate(d1)), 0)
  d2 <- g_scenario(list("ch1.qmd" = gate_py(c("print(\"claim(\")"))),
                   list("ch1.qmd" = gate_py(c("pass"))))
  expect_identical(g_gate(d2)$n_removed, 1L)
})

test_that("N59: an @claim in a julia comment line costs nothing when removed", {
  d <- g_scenario(list("ch1.qmd" = gate_jl(c("x = 1", "# @claim n > 10"))),
                  list("ch1.qmd" = gate_jl(c("x = 1"))))
  expect_identical(removed_6k(g_gate(d)), 0)
})

test_that("N59: a guest claim moved to another chunk of the same file removes nothing", {
  before <- c("Intro paragraph.", "", c3_chunk(c("n = 12", "claim(n, \"> 10\")"), engine = "python"), "",
              c3_chunk("m = 1", engine = "python"), G_ENGINE)
  after <- c("Intro paragraph.", "", c3_chunk(c("n = 12"), engine = "python"), "",
             c3_chunk(c("m = 1", "claim(m, \"> 0\")"), engine = "python"), G_ENGINE)
  d <- g_scenario(list("ch1.qmd" = before), list("ch1.qmd" = after))
  expect_identical(removed_6k(g_gate(d)), 0)
})

test_that("N59: setting eval: false on a guest chunk that holds a claim is a removal (the claim no longer runs)", {
  d <- g_scenario(list("ch1.qmd" = gate_py("claim(n, \"> 10\")")),
                  list("ch1.qmd" = c("Intro paragraph.", "",
                                     c3_chunk("claim(n, \"> 10\")", "#| eval: false", engine = "python"),
                                     G_ENGINE)))
  expect_identical(g_gate(d)$n_removed, 1L)
})

# ---- guest-call: r.claim( has the text E58 ------------------------------------------------------------------

test_that("N59 E58: r.claim( in a python chunk is a guest-call finding with the new text", {
  for (ext in c("Rmd", "qmd")) {
    lines <- if (ext == "Rmd") c("```{python}", "ok = r.claim(3, 4)", "```") else
      f3d_doc(c("```{python}", "ok = r.claim(3, 4)", "```"), "engine: knitr")
    x <- g6k_lint(lines, ext = ext)
    expect_identical(nrow(x), 1L, label = ext)
    expect_identical(x$rule, "guest-call")
    expect_identical(x$spec, "5.11.2")
    expect_identical(x$tier, 1L)
    expect_identical(x$text, "r.claim(")
    expect_identical(x$message, E58, label = ext)
  }
})

test_that("N59 E58: the old message, which told the author to write the check in R, is gone", {
  x <- g6k_lint(c("```{python}", "ok = r.claim(3, 4)", "```"))
  expect_false(grepl("r claim(py$n", x$message, fixed = TRUE))
  expect_false(grepl("cannot be called from Python", x$message, fixed = TRUE))
})

test_that("N59: from weft import claim, claim(n, \"> 10\") and weft.claim(...) are not guest-call findings", {
  for (code in c("from weft import claim", "ok = claim(n, \"> 10\")", "import weft", "ok = weft.claim(n, \"> 10\")",
                 "claim(n, '_ % 2 == 0', level='warn')")) {
    x <- g6k_lint(c("```{python}", code, "```"))
    expect_identical(nrow(x), 0L, label = code)
  }
})

test_that("N59: the other r.NAME( messages are unchanged by the new claim text", {
  x <- g6k_lint(c("```{python}", "v = r.fmt_num(1)", "```"))
  expect_identical(nrow(x), 1L)
  expect_identical(x$message,
                   paste0("`r.fmt_num()` passes its arguments through reticulate, which can turn a Python int into ",
                          "a wrong number with no error. Write `from weft import fmt_num` and call `fmt_num()` ",
                          "(rule 5.11.2)."))
})
