# Package 5f: the Observable lint (dev/design-5.md G42; rule 5.11.4). Static: nothing runs.
# READINGS: an untagged template literal, a plain string and a template tagged with anything but md or html are not
# findings (the note names md and html only); each `${` in a tagged template is one finding, text `${...}` as written.

g5e_ojs_msg_inline <- function(span) {
  sprintf(paste0("`%s` is computed in the reader's browser after weft's checks have run, so weft cannot vouch for it ",
                 "(rule 5.11.4)."), span)
}
g5e_ojs_msg_tmpl <- function(tmpl) {
  sprintf(paste0("`%s` in an Observable template is computed in the reader's browser after weft's checks have run, ",
                 "so weft cannot vouch for it (rule 5.11.4)."), tmpl)
}
G5E_OJS_HINT <- paste0("Compute the value when the document renders, in R or Python, and print it as a weft value; ",
                       "or mark the text [...]{.weft-literal why=\"...\"}.")
g5e_ojs <- function(code) c("```{ojs}", code, "```")
g5e_ojs_lint <- function(lines, ext = "qmd", tier = 1:2, env = parent.frame()) {
  lint_one(lines, rules = "ojs-value", ext = ext, tier = tier, env = env)
}

test_that("5f G42: lint_rules() lists ojs-value at tier 2, rule 5.11.4, scope file", {
  lr <- lint_rules()
  expect_identical(sum(lr$id == "ojs-value"), 1L)
  expect_identical(lr$spec[lr$id == "ojs-value"], "5.11.4")
  expect_identical(lr$tier[lr$id == "ojs-value"], 2L)
  expect_identical(lr$scope[lr$id == "ojs-value"], "file")
})

test_that("5f G42: `{ojs} total` in prose of a .qmd is a tier-2 finding, exact message and hint", {
  lines <- c("Intro.", "", "The total is `{ojs} total` items.", "", "More.")
  x <- g5e_ojs_lint(lines)
  expect_findings_shape(x)
  expect_identical(nrow(x), 1L)
  expect_identical(x$rule, "ojs-value")
  expect_identical(x$tier, 2L)
  expect_identical(x$spec, "5.11.4")
  expect_identical(x$text, "`{ojs} total`")
  expect_identical(x$message, g5e_ojs_msg_inline("{ojs} total"))
  expect_identical(x$hint, G5E_OJS_HINT)
  expect_identical(c(x$line, x$col), unname(f3_pos(lines, "`{ojs}")))
})

test_that("5f G42: it is tier 2, so absent from lints() by default", {
  root <- lint_proj(list("a.qmd" = "The total is `{ojs} total` items."))
  # a rule named in `rules` runs whatever its tier (review 3 #9), so "by default" means no `rules`
  expect_identical(sum(lints(root)$rule == "ojs-value"), 0L)
  expect_identical(nrow(lints(root, rules = "ojs-value", tier = 2)), 1L)
})

test_that("5f G42: the span is a finding with an attribute block too, and with engine: knitr or none", {
  for (doc in list("A `{ojs} total`{.num} here.", f3d_doc("A `{ojs} total` here.", "engine: knitr"))) {
    x <- g5e_ojs_lint(doc)
    expect_identical(nrow(x), 1L)
    expect_identical(x$text, "`{ojs} total`")
  }
})

test_that("5f G42: each ${ in a template tagged md or html in an {ojs} chunk is a finding at it", {
  for (tag in c("md", "html")) {
    lines <- c("Intro.", "", g5e_ojs(sprintf("%s`Total is ${total} and ${other}.`", tag)))
    x <- g5e_ojs_lint(lines)
    expect_identical(nrow(x), 2L, label = tag)
    expect_identical(x$rule, rep("ojs-value", 2L))
    expect_identical(x$tier, c(2L, 2L))
    expect_identical(x$text, c("${total}", "${other}"), label = tag)
    expect_identical(x$message, c(g5e_ojs_msg_tmpl("${total}"), g5e_ojs_msg_tmpl("${other}")), label = tag)
    expect_identical(x$hint, rep(G5E_OJS_HINT, 2L))
    expect_identical(x$line, c(4L, 4L))
    expect_identical(x$col[[1]], unname(f3_pos(lines, "${total}")[["col"]]))
    expect_identical(x$col[[2]], unname(f3_pos(lines, "${other}")[["col"]]))
  }
})

test_that("5f G42: a multi-line tagged template is read across its lines", {
  lines <- g5e_ojs(c("md`Line one", "total ${total}", "end`"))
  x <- g5e_ojs_lint(lines)
  expect_identical(nrow(x), 1L)
  expect_identical(x$text, "${total}")
  expect_identical(x$line, 3L)
  expect_identical(x$col, 7L)
})

test_that("5f G42: not a finding: a tagged template with no ${, a plain string, an untagged or other-tagged template", {
  for (code in list("md`Total is fixed.`",
                    "html`<b>fixed</b>`",
                    "x = 'cost ${total}'",
                    "x = \"cost ${total}\"",
                    "x = `cost ${total}`",
                    "x = tex`a ${b}`",
                    "x = 1 + 2")) {
    expect_identical(nrow(g5e_ojs_lint(g5e_ojs(code))), 0L, label = code)
  }
})

test_that("5f G42: not a finding: ${ in an R or Python chunk, or in an md template outside an {ojs} chunk", {
  expect_identical(nrow(g5e_ojs_lint(c("```{r}", "x <- 'md`a ${b}`'", "```"))), 0L)
  expect_identical(nrow(g5e_ojs_lint(c("```{python}", "x = 'md`a ${b}`'", "```"))), 0L)
  expect_identical(nrow(g5e_ojs_lint("Prose with md`a ${b}` in it.")), 0L)
})

test_that("5f G42: not a finding inside a .weft-literal span or div", {
  span <- "A [`{ojs} total`]{.weft-literal why=\"shows the syntax\"} here."
  expect_identical(nrow(g5e_ojs_lint(span)), 0L)
  div <- c("::: {.weft-literal why=\"shows the syntax\"}", "Write `{ojs} total` in prose.", ":::")
  expect_identical(nrow(g5e_ojs_lint(div)), 0L)
  # control: outside them it is a finding
  expect_identical(nrow(g5e_ojs_lint("Write `{ojs} total` in prose.")), 1L)
})

test_that("5f G42: not a finding in an .Rmd", {
  expect_identical(nrow(g5e_ojs_lint("The total is `{ojs} total` items.", ext = "Rmd")), 0L)
  expect_identical(nrow(g5e_ojs_lint(g5e_ojs("md`a ${b}`"), ext = "Rmd")), 0L)
})

test_that("5f G42: {ojs} is not the business of guest-inline", {
  x <- lint_one(f3d_doc("The total is `{ojs} total` items.", "engine: knitr"), rules = "guest-inline", tier = 1:2)
  expect_identical(nrow(x), 0L)
})
