# Package 5e: the lints for guest languages (dev/design-5.md G33 to G37, G39, G40; rules 5.11.1 to 5.11.3).
# Static: no test here needs Python or Julia. Helpers: helper-3.R (lint_proj, lint_fixture, lint_one, f3_pos),
# helper-3c.R (c3_chunk, c3_para), helper-3d.R (f3d_doc, expect_none, expect_texts), helper-4a.R (g_scenario, g_gate),
# helper-4b.R (nothing). Invented content only.
#
# READINGS of the note (see the report): the finding of guest-inline has the code span alone as its text, whether or
# not an attribute block follows; "executed {r} chunk" excludes an `eval: false` chunk; the message of guest-call for
# a name other than claim has the shape of the first message with the name in place of fmt_num.

g5e_inline_py <- function(span) {
  sprintf(paste0("`%s` is inline Python, which the knitr engine does not run: it would print as code. ",
                 "Bind the value to a name in a Python chunk and write `r py$name` (rule 5.11.1)."), span)
}
g5e_inline_other <- function(span, lang) {
  sprintf("`%s` is inline %s code, which the knitr engine does not run: it would print as code (rule 5.11.1).",
          span, lang)
}
G5E_INLINE_HINT <- "A value from another language reaches prose through R; see vignette(\"languages\", package = \"weft\")."

g5e_call_msg <- function(name) {
  sprintf(paste0("`r.%s()` passes its arguments through reticulate, which can turn a Python int into a wrong number ",
                 "with no error. Write `from weft import %s` and call `%s()` (rule 5.11.2)."), name, name, name)
}
G5E_CLAIM_MSG <- paste0("`claim()` cannot be called through `r.`: reticulate converts its argument with no check. ",
                        "Write `from weft import claim` and `claim(n, \"> 10\")` (rule 5.11.2).")

g5e_read_msg <- function(read, path) {
  sprintf(paste0("`%s` in R code is converted by reticulate, which can turn a Python int into a wrong number with no ",
                 "error. For a value that reaches prose, read it with py_value(%s) (rule 5.11.3)."), read, path)
}
g5e_prose_msg <- function(call, pkg) {
  sprintf("`%s` is converted by %s, which weft does not check (rule 5.11.3).", call, pkg)
}

# the executed Python chunk lines
g5e_py <- function(..., opts = character()) c("```{python}", opts, c(...), "```")
g5e_knitr <- "engine: knitr"
g5e_lint <- function(lines, rule, ext = "qmd", tier = 1:2, env = parent.frame()) {
  lint_one(lines, rules = rule, ext = ext, tier = tier, env = env)
}

# ---- G33: lint_rules() ------------------------------------------------------------------------------------

test_that("5e G33: lint_rules() lists guest-inline, guest-call and guest-read with their tiers, numbers and scope", {
  lr <- lint_rules()
  want <- list(`guest-inline` = c("5.11.1", 1L), `guest-call` = c("5.11.2", 1L), `guest-read` = c("5.11.3", 2L))
  for (id in names(want)) {
    expect_identical(sum(lr$id == id), 1L, label = id)
    expect_identical(lr$spec[lr$id == id], want[[id]][[1]], label = paste("spec of", id))
    expect_identical(lr$tier[lr$id == id], as.integer(want[[id]][[2]]), label = paste("tier of", id))
    expect_identical(lr$scope[lr$id == id], "file", label = paste("scope of", id))
  }
})

# ---- G34: guest-inline ------------------------------------------------------------------------------------

test_that("5e G34: `{python} depth` in an .Rmd is a finding at the code span, with the exact message and hint", {
  lines <- c("Intro.", "", "The depth is `{python} depth` metres.", "", "More.")
  for (ext in c("Rmd", "rmd")) {
    x <- g5e_lint(lines, "guest-inline", ext = ext)
    expect_findings_shape(x)
    expect_identical(nrow(x), 1L, label = ext)
    expect_identical(x$rule, "guest-inline")
    expect_identical(x$tier, 1L)
    expect_identical(x$spec, "5.11.1")
    expect_identical(x$text, "`{python} depth`")
    expect_identical(x$message, g5e_inline_py("{python} depth"))
    expect_identical(x$hint, G5E_INLINE_HINT)
    expect_identical(c(x$line, x$col), unname(f3_pos(lines, "`{python}")))
  }
})

test_that("5e G34: a .qmd that knitr knits (engine: knitr, or an executed {r} chunk and no engine key) is linted", {
  prose <- c("The depth is `{python} depth` metres.")
  docs <- list(
    engine_knitr = f3d_doc(prose, g5e_knitr),
    r_chunk      = c(prose, "", c3_chunk("x <- 1")),
    both         = f3d_doc(c(prose, "", c3_chunk("x <- 1")), g5e_knitr)
  )
  for (nm in names(docs)) {
    x <- g5e_lint(docs[[nm]], "guest-inline")
    expect_identical(nrow(x), 1L, label = nm)
    expect_identical(x$message, g5e_inline_py("{python} depth"), label = nm)
  }
})

test_that("5e G34: a .qmd Quarto would not knit with knitr is not linted", {
  prose <- c("The depth is `{python} depth` metres.")
  docs <- list(
    plain          = prose,
    python_chunk   = c(prose, "", g5e_py("depth = 3")),
    jupyter_engine = f3d_doc(c(prose, "", c3_chunk("x <- 1")), "engine: jupyter"),
    jupyter_key    = f3d_doc(c(prose, "", c3_chunk("x <- 1")), "jupyter: python3"),
    jupyter_only   = f3d_doc(prose, "engine: jupyter")
  )
  for (nm in names(docs)) expect_none(g5e_lint(docs[[nm]], "guest-inline"), "guest-inline")
})

test_that("5e G34: another language gets the second message; the language is as written", {
  # {julia} has its own text (J23, test-lint-julia.R)
  x <- g5e_lint(c("A `{bash} x` here.", "", "And `{perl} y` there."), "guest-inline", ext = "Rmd")
  expect_identical(nrow(x), 2L)
  expect_identical(x$text, c("`{bash} x`", "`{perl} y`"))
  expect_identical(x$message, c(g5e_inline_other("{bash} x", "bash"), g5e_inline_other("{perl} y", "perl")))
  expect_identical(x$hint, rep(G5E_INLINE_HINT, 2L))
})

test_that("5e G34: an attribute block after the code span does not change the finding", {
  bare <- g5e_lint("The depth is `{python} depth` metres.", "guest-inline", ext = "Rmd")
  attr <- g5e_lint("The depth is `{python} depth`{.num} metres.", "guest-inline", ext = "Rmd")
  expect_identical(nrow(attr), 1L)
  expect_identical(attr$message, bare$message)
  expect_identical(attr$hint, bare$hint)
  expect_identical(attr$text, "`{python} depth`")
  attr2 <- g5e_lint("The depth is `{bash} depth`{.num digits=\"2\"} metres.", "guest-inline", ext = "Rmd")
  expect_identical(nrow(attr2), 1L)
  expect_identical(attr2$message, g5e_inline_other("{bash} depth", "bash"))
})

test_that("5e G34: not a finding: r, R and ojs, no space, an invalid name", {
  for (span in c("`{r} x`", "`{R} x`", "`{ojs} x`", "`{python}`", "`{python}x`", "`python x`", "`{py-thon} x`",
                 "`{1x} y`", "`{ } y`", "`r x`", "`{python depth}`")) {
    expect_none(g5e_lint(paste("A", span, "here."), "guest-inline", ext = "Rmd"), "guest-inline")
  }
  # names with digits and underscores are languages
  x <- g5e_lint("A `{py_3} x` here.", "guest-inline", ext = "Rmd")
  expect_identical(nrow(x), 1L)
})

test_that("5e G34: not a finding: inside a fenced code block, or a .weft-literal span or div", {
  fence <- c("Intro.", "", "```", "Depth `{python} depth` here.", "```", "", "Done.")
  expect_none(g5e_lint(fence, "guest-inline", ext = "Rmd"), "guest-inline")
  fence_q <- f3d_doc(fence, g5e_knitr)
  expect_none(g5e_lint(fence_q, "guest-inline"), "guest-inline")
  span <- c("A [`{python} depth`]{.weft-literal why=\"shows the syntax\"} here.")
  expect_none(g5e_lint(span, "guest-inline", ext = "Rmd"), "guest-inline")
  expect_none(g5e_lint(f3d_doc(span, g5e_knitr), "guest-inline"), "guest-inline")
  div <- c("::: {.weft-literal why=\"shows the syntax\"}", "Write `{python} depth` in prose.", ":::")
  expect_none(g5e_lint(div, "guest-inline", ext = "Rmd"), "guest-inline")
  expect_none(g5e_lint(f3d_doc(div, g5e_knitr), "guest-inline"), "guest-inline")
  # control: the same prose outside them is a finding
  expect_identical(nrow(g5e_lint("Write `{python} depth` in prose.", "guest-inline", ext = "Rmd")), 1L)
})

test_that("5e G34: tier 1, so lints() with the default tier lists it", {
  root <- lint_proj(list("a.Rmd" = "The depth is `{python} depth` metres."))
  x <- lints(root, rules = "guest-inline")
  expect_identical(nrow(x), 1L)
})

# ---- G35: guest-call --------------------------------------------------------------------------------------

test_that("5e G35: r.fmt_num( in a Python chunk is a finding at `r.`, with the exact message", {
  lines <- c("Intro.", "", g5e_py("depth = 3.14159", "s = r.fmt_num(depth)"))
  for (ext in c("Rmd", "qmd")) {
    x <- g5e_lint(if (ext == "qmd") f3d_doc(lines, g5e_knitr) else lines, "guest-call", ext = ext)
    expect_findings_shape(x)
    expect_identical(nrow(x), 1L, label = ext)
    expect_identical(x$rule, "guest-call")
    expect_identical(x$tier, 1L)
    expect_identical(x$spec, "5.11.2")
    expect_identical(x$text, "r.fmt_num(")
    expect_identical(x$message, g5e_call_msg("fmt_num"))
    d <- if (ext == "qmd") 4L else 0L
    expect_identical(c(x$line, x$col), c(unname(f3_pos(lines, "r.fmt_num(")[["line"]]) + d, 5L))
  }
})

test_that("5e G35: r.claim( has its own message", {
  x <- g5e_lint(g5e_py("ok = r.claim(3, 4)"), "guest-call", ext = "Rmd")
  expect_identical(nrow(x), 1L)
  expect_identical(x$text, "r.claim(")
  expect_identical(x$message, G5E_CLAIM_MSG)
})

test_that("5e G35: each name of the module is a finding, with its own name in the message", {
  for (nm in c("fmt_pct", "fmt_and", "plural", "ci", "weft_str")) {
    x <- g5e_lint(g5e_py(sprintf("v = r.%s(1)", nm)), "guest-call", ext = "Rmd")
    expect_identical(nrow(x), 1L, label = nm)
    expect_identical(x$text, sprintf("r.%s(", nm), label = nm)
    expect_identical(x$message, g5e_call_msg(nm), label = nm)
  }
})

test_that("5e G35: a call inside another call or a string literal is a finding too", {
  lines <- g5e_py("print(r.fmt_num(3))", "s = \"r.fmt_num(3)\"")
  x <- g5e_lint(lines, "guest-call", ext = "Rmd")
  expect_identical(nrow(x), 2L)
  expect_identical(x$line, c(2L, 3L))
  expect_identical(x$col, c(7L, 6L))
})

test_that("5e G35: not a finding: other prefixes, comment lines, imports, plain calls, reads of R values", {
  code <- c("from weft import fmt_num",
            "a = fmt_num(3)",
            "b = r.depth",
            "c = r.depth + 1",
            "# r.fmt_num(3)",
            "    # r.fmt_num(3)",
            "d = bar.fmt_num(3)",
            "e = myr.fmt_num(3)",
            "f = x1r.fmt_num(3)",
            "g = _r.fmt_num(3)",
            "h = a.r.fmt_num(3)",
            "i = r.fmt_numx(3)",
            "j = r.not_a_weft_name(3)")
  expect_none(g5e_lint(g5e_py(code), "guest-call", ext = "Rmd"), "guest-call")
  expect_none(g5e_lint(f3d_doc(g5e_py(code), g5e_knitr), "guest-call"), "guest-call")
})

test_that("5e G35: an R chunk is not read for it, and neither is an eval: false Python chunk", {
  expect_none(g5e_lint(c3_chunk("x <- r.fmt_num(3)"), "guest-call", ext = "Rmd"), "guest-call")
  expect_none(g5e_lint(g5e_py("x = r.fmt_num(3)", opts = "#| eval: false"), "guest-call"), "guest-call")
  expect_none(g5e_lint(c("```{python, eval=FALSE}", "x = r.fmt_num(3)", "```"), "guest-call", ext = "Rmd"),
              "guest-call")
  # control: the same chunk executed
  expect_identical(nrow(g5e_lint(c("```{python}", "x = r.fmt_num(3)", "```"), "guest-call", ext = "Rmd")), 1L)
})

# ---- G36: the code rules ignore guest code ----------------------------------------------------------------

test_that("5e G36: a Python chunk `dict = {'a': 1}` gives no dict-assign", {
  for (ext in c("qmd", "Rmd")) {
    py <- c(c3_para("Intro."), c3_chunk("dict = {'a': 1}", engine = "python"))
    expect_none(g5e_lint(py, "dict-assign", ext = ext), "dict-assign")
    # control: the same in an R chunk
    r <- c(c3_para("Intro."), c3_chunk("dict <- list(a = 1)"))
    expect_identical(nrow(g5e_lint(r, "dict-assign", ext = ext)), 1L, label = ext)
  }
})

test_that("5e G36: a Python chunk with cache: true and tar_read(x) gives no tar-cache", {
  for (ext in c("qmd", "Rmd")) {
    py <- c(c3_para("Intro."), c3_chunk("x = tar_read(fit)", "#| cache: true", engine = "python"))
    expect_none(g5e_lint(py, "tar-cache", ext = ext), "tar-cache")
    r <- c(c3_para("Intro."), c3_chunk("x <- tar_read(fit)", "#| cache: true"))
    expect_identical(nrow(g5e_lint(r, "tar-cache", ext = ext)), 1L, label = ext)
  }
})

test_that("5e G36: a Python chunk `claim = 3` adds nothing to the gate's count", {
  src <- read_src(c(c3_para("Intro."), c3_chunk("claim = 3", engine = "python")))
  x <- weft:::count_constructs(src)
  expect_identical(nrow(x), 0L)
  # control: a value in prose is counted
  src2 <- read_src(c(c3_para("Intro."), c3_chunk("claim = 3", engine = "python"), "", "A `r x`{.num} here."))
  expect_identical(nrow(weft:::count_constructs(src2)), 1L)
})

# ---- G37: guest-read --------------------------------------------------------------------------------------

test_that("5e G37: guest-read is tier 2: absent from lints() by default, present with tier 2", {
  root <- lint_proj(list("a.qmd" = c3_chunk("x <- py$n")))
  # a rule named in `rules` runs whatever its tier (review 3 #9), so "by default" means no `rules`
  expect_none(lints(root), "guest-read")
  expect_none(lints(root, rules = "guest-read", tier = 1), "guest-read")
  x <- lints(root, rules = "guest-read", tier = 2)
  expect_identical(nrow(x), 1L)
  expect_identical(x$tier, 2L)
  expect_identical(x$spec, "5.11.3")
})

test_that("5e G37: a read of py in an executed R chunk is a finding with the exact message", {
  lines <- c("Intro.", "", c3_chunk("x <- py$n"))
  for (ext in c("qmd", "Rmd")) {
    x <- g5e_lint(lines, "guest-read", ext = ext)
    expect_findings_shape(x)
    expect_identical(nrow(x), 1L, label = ext)
    expect_identical(x$rule, "guest-read")
    expect_identical(x$text, "py$n")
    expect_identical(x$message, g5e_read_msg("py$n", "\"n\""))
    expect_identical(c(x$line, x$col), c(unname(f3_pos(lines, "py$n")[["line"]]), 6L))
  }
})

test_that("5e G37: py[[\"n\"]], reticulate::py$n and a chain are each one finding, text as written", {
  x <- g5e_lint(c3_chunk("a <- py[[\"n\"]]"), "guest-read", ext = "Rmd")
  expect_identical(x$text, "py[[\"n\"]]")
  expect_identical(x$message, g5e_read_msg("py[[\"n\"]]", "\"n\""))
  x <- g5e_lint(c3_chunk("a <- reticulate::py$n"), "guest-read", ext = "Rmd")
  expect_identical(x$text, "reticulate::py$n")
  expect_identical(nrow(x), 1L)
  x <- g5e_lint(c3_chunk("a <- py$cfg$depth"), "guest-read", ext = "Rmd")
  expect_identical(nrow(x), 1L)
  expect_identical(x$text, "py$cfg$depth")
  expect_identical(x$message, g5e_read_msg("py$cfg$depth", "\"cfg\", \"depth\""))
})

test_that("5e G37: several reads in one chunk are one finding each", {
  x <- g5e_lint(c3_chunk("a <- py$n", "b <- py$m + py$k"), "guest-read", ext = "Rmd")
  # c3_chunk() puts its later arguments first, and findings come in file order
  expect_identical(sort(x$text), sort(c("py$n", "py$m", "py$k")))
})

test_that("5e G37: the target of an assignment is not a finding", {
  for (code in c("py$x <- 1", "py$x = 1")) {
    expect_none(g5e_lint(c3_chunk(code), "guest-read", ext = "Rmd"), "guest-read")
  }
  # but a read on the right-hand side is
  x <- g5e_lint(c3_chunk("py$x <- py$y"), "guest-read", ext = "Rmd")
  expect_identical(x$text, "py$y")
})

test_that("5e G37: an eval: false R chunk, a Python chunk and a non-symbol py are not read", {
  expect_none(g5e_lint(c3_chunk("x <- py$n", "#| eval: false"), "guest-read", ext = "qmd"), "guest-read")
  expect_none(g5e_lint(c("```{r, eval=FALSE}", "x <- py$n", "```"), "guest-read", ext = "Rmd"), "guest-read")
  expect_none(g5e_lint(c3_chunk("x = py$n", engine = "python"), "guest-read", ext = "Rmd"), "guest-read")
  expect_none(g5e_lint(c3_chunk("x <- py_value(\"n\")"), "guest-read", ext = "Rmd"), "guest-read")
  expect_none(g5e_lint(c3_chunk("x <- py(1)$n"), "guest-read", ext = "Rmd"), "guest-read")
})

test_that("5e G37: a bare py$x in prose is guarded by weft, so it is not a finding", {
  expect_none(g5e_lint("The depth is `r py$depth` m.", "guest-read", ext = "Rmd"), "guest-read")
  expect_none(g5e_lint("The depth is `r py_value(\"depth\")`{.num} m.", "guest-read", ext = "Rmd"), "guest-read")
})

test_that("5e G37: prose calls of each listed reticulate function are findings, text the call as written", {
  for (fn in c("py_eval", "py_to_r", "py_get_attr", "py_call", "import_main")) {
    for (pre in c("", "reticulate::")) {
      call <- sprintf("%s%s(\"x\")", pre, fn)
      x <- g5e_lint(sprintf("A value `r %s` here.", call), "guest-read", ext = "Rmd")
      expect_identical(nrow(x), 1L, label = call)
      expect_identical(x$text, call, label = call)
      expect_identical(x$message, g5e_prose_msg(call, "reticulate"), label = call)
    }
  }
})

# (JuliaCall calls in prose: J24, test-lint-julia.R)

test_that("5e G37: a call of a read, py$f(2), in prose is a finding; so is a call in a governor", {
  x <- g5e_lint("A value `r py$f(2)` here.", "guest-read", ext = "Rmd")
  expect_identical(nrow(x), 1L)
  expect_identical(x$text, "py$f(2)")
  x <- g5e_lint("The level [rose]{if=\"py_get_attr(a, 'b')\"} again.", "guest-read", ext = "Rmd")
  expect_identical(nrow(x), 1L)
  expect_identical(x$text, "py_get_attr(a, 'b')")
})

test_that("5e G37: listed over added lines by changes(), and over a file when asked for", {
  skip_if(Sys.which("git") == "", "git is not on the PATH")
  before <- list("a.qmd" = c("Intro.", "", c3_chunk("x <- py$a")))
  after  <- list("a.qmd" = c("Intro.", "", c3_chunk("x <- py$a", "y <- py$b")))
  dir <- f3d_scenario(before, after)
  f <- changes(path = dir)$findings
  f <- f[f$rule == "guest-read", ]
  expect_identical(nrow(f), 1L)
  # changes()$findings has the columns file, line, rule, message
  expect_match(f$message, "py$b", fixed = TRUE)
  root <- lint_proj(after)
  x <- lints(root, files = "a.qmd", rules = "guest-read", tier = 2)
  expect_identical(sort(x$text), c("py$a", "py$b"))
})

# ---- G39: captions on guest chunks ------------------------------------------------------------------------

G5E_CAP_MSG <- paste0("A `n` construct in a caption of chunk `p1`, which uses the `python` engine, not R: write the ",
                      "caption in a figure or table div instead, `::: {#fig-name}` ... caption paragraph ... `:::` ",
                      "(rules 1.10.5, 2.3.5).")

rmd_head_5e <- c("---", "title: \"t\"", "---", "", "```{r setup, include=FALSE}", "weft::weft_setup()", "```", "")

test_that("5e G39: an n construct in the fig-cap of a Python chunk is a construct finding, with the exact message", {
  doc <- f3d_doc(c("```{python}", "#| label: p1", "#| fig-cap: |", "#|   [# site | # sites]{n=\"k\"}", "x = 1", "```"),
                 g5e_knitr)
  x <- g5e_lint(doc, "construct")
  expect_identical(nrow(x), 1L)
  expect_identical(x$tier, 1L)
  expect_identical(x$context, "caption")
  expect_identical(x$message, G5E_CAP_MSG)
})

test_that("5e G39: at knit time the same construct stops the render with the same message", {
  lines <- c("```{python p1, echo=FALSE, fig.cap='[# site | # sites]{n=\"k\"}'}", "x = 1", "```", "")
  res <- render_rmd(c(rmd_head_5e, lines), setup = FALSE, format = "knit")
  expect_true(res$failed)
  expect_true("weft_construct_error" %in% res$error$class)
  squash <- function(x) gsub("[[:space:]]+", " ", x)
  expect_true(grepl(squash(G5E_CAP_MSG), squash(res$message), fixed = TRUE))
})

# ---- G40: the gate on guest documents ---------------------------------------------------------------------

test_that("5e G40: an added `{python} x` fails the gate as a tier-1 finding", {
  skip_if_no_git()
  front <- c("---", g5e_knitr, "---", "")
  before <- c(front, G_PROSE)
  after <- c(before, "", "The depth is `{python} x` metres.")
  d <- g_scenario(list("ch1.qmd" = before), list("ch1.qmd" = after))
  res <- g_gate(d)
  expect_false(res$ok)
  expect_true("guest-inline" %in% res$added$rule)
  # control: without engine: knitr nothing is added, the document is not knitted by knitr
  d2 <- g_scenario(list("ch1.qmd" = G_PROSE), list("ch1.qmd" = c(G_PROSE, "", "The depth is `{python} x` metres.")))
  expect_true(g_gate(d2)$ok)
})

test_that("5e G40: an added r.fmt_num( in a Python chunk fails the gate too", {
  skip_if_no_git()
  front <- c("---", g5e_knitr, "---", "")
  before <- c(front, G_PROSE, "", g5e_py("x = 1", opts = "#| label: py1"))
  after <- c(front, G_PROSE, "", g5e_py("x = r.fmt_num(1)", opts = "#| label: py1"))
  d <- g_scenario(list("ch1.qmd" = before), list("ch1.qmd" = after))
  res <- g_gate(d)
  expect_false(res$ok)
  expect_true("guest-call" %in% res$added$rule)
})

test_that("5e G40: a weft_str('...') removed from a Python chunk needs no trailer", {
  skip_if_no_git()
  front <- c("---", g5e_knitr, "---", "")
  with_str <- c(front, G_PROSE, "",
                g5e_py("print(weft_str('Depth [rose | fell]{if=\"TRUE\"}.'))", opts = "#| label: py1"))
  without <- c(front, G_PROSE, "", g5e_py("print('Depth rose.')", opts = "#| label: py1"))
  d <- g_scenario(list("ch1.qmd" = with_str), list("ch1.qmd" = without))
  res <- g_gate(d)
  expect_true(res$ok)
  expect_identical(res$n_removed, 0L)
})

test_that("5e G40: a weft_str('...') in Python code holding a construct error is not linted", {
  doc <- f3d_doc(g5e_py("print(weft_str('Depth [rose | fell]{if=\"TRUE\" n=\"3\"}.'))"), g5e_knitr)
  expect_none(g5e_lint(doc, c("construct", "numeral")))
})
