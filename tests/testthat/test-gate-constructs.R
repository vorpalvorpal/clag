# Package 4a: counting constructs (dev/design-4.md G11, G12; the no-trailer cases of section 5).
# count_constructs(src) is internal: weft:::count_constructs(), on a weft_source from read_src() (helper-3.R).
# ASSUMED reading (G11): the column `kind` holds "value" (scanner kinds value and bare), "span" (n, if, sign,
# list, cite, text) or "claim"; `text` is the construct as written, white space collapsed.

cc <- function(lines, ext = "qmd") weft:::count_constructs(read_src(lines, ext = ext))

test_that("4a G11: count_constructs() returns file, line, kind, text, one row per construct", {
  x <- cc(c("A `r n_sites`{.num} b.", "", "And `r depth` c."))
  expect_s3_class(x, "data.frame")
  expect_identical(names(x), c("file", "line", "kind", "text"))
  expect_identical(nrow(x), 2L)
  expect_identical(x$line, c(1L, 3L))
  expect_identical(x$kind, c("value", "value"))
  expect_match(x$text[[1]], "`r n_sites`", fixed = TRUE)
  expect_match(x$text[[2]], "`r depth`", fixed = TRUE)
})

test_that("4a G11: no constructs gives a zero-row data frame with the columns", {
  x <- cc(G_PROSE)
  expect_identical(nrow(x), 0L)
  expect_identical(names(x), c("file", "line", "kind", "text"))
})

test_that("4a G11: each scanner kind counts once: value, bare, n, if, sign, list, cite, text", {
  src <- c("v `r a`{.num}", "",
           "b `r b`", "",
           "n [a | b]{n=\"k\"}", "",
           "i [x]{if=\"cond\"}", "",
           "s [x]{sign=\"d\"}", "",
           "l [a]{list=\"zzlist\"}", "",
           "c [10 m]{cite=\"zzcite\"}", "",
           "t [t]{.strong}")
  x <- cc(src)
  expect_identical(nrow(x), 8L)
  expect_identical(x$line, c(1L, 3L, 5L, 7L, 9L, 11L, 13L, 15L))
  expect_identical(x$kind, c("value", "value", rep("span", 6L)))
})

test_that("4a G11: white space in the text is collapsed", {
  x <- cc(c("A [a  site |", "sites]{n=\"k\"} b."))
  expect_identical(nrow(x), 1L)
  expect_false(grepl("\n|  ", x$text))
  expect_match(x$text, "a site", fixed = TRUE)
})

test_that("4a G11: .weft-literal and plain links and code do not count", {
  x <- cc(c("A [45%]{.weft-literal why=\"SOP 12\"} b.", "", "See [the site](https://example.org) and `code`."))
  expect_identical(nrow(x), 0L)
})

test_that("4a G11: constructs count in every context: caption, front matter, weft_str()", {
  doc <- c("---", "title: \"t\"", "abstract: |", "  Front `r yr`{.num} text", "---", "",
           "```{r fig-one}", "#| fig-cap: |", "#|   Cap [a site | # sites]{n=\"n\"} end",
           "x <- weft_str(\"A `r five`{.num} string\")",
           "y <- other_fn(\"not weft `r nine`{.num}\")", "```")
  x <- cc(doc)
  expect_identical(sort(x$line), c(4L, 9L, 10L))
})

test_that("4a G11: claim() and weft::claim() calls in an R chunk count, also under eval: false", {
  doc <- c("```{r chk-a}", "#| eval: false", "claim(n_sites, . > 10)", "weft::claim(depth, . < 3)", "```")
  x <- cc(doc)
  expect_identical(nrow(x), 2L)
  expect_identical(x$kind, c("claim", "claim"))
  expect_identical(x$line, c(3L, 4L))
  expect_match(x$text[[1]], "claim(n_sites, . > 10)", fixed = TRUE)
  expect_match(x$text[[2]], "claim(depth, . < 3)", fixed = TRUE)
})

test_that("4a G11: a value whose expression holds claim() gives two rows", {
  x <- cc("The count is `r claim(n_sites, . > 10)`{.num} sites.")
  expect_identical(nrow(x), 2L)
  expect_setequal(x$kind, c("value", "claim"))
})

test_that("4a G11: a claim() in a governor expression counts too", {
  x <- cc("[a site | sites]{n=\"claim(k, . > 1)\"}")
  expect_setequal(x$kind, c("span", "claim"))
})

test_that("4a G11: an R chunk's other calls do not count", {
  x <- cc(c("```{r chk-a}", "x <- mean(depth)", "print(x)", "```"))
  expect_identical(nrow(x), 0L)
})

test_that("4a G11: the file column is the document's path", {
  x <- cc("A `r a`{.num}.")
  expect_match(x$file, "doc\\.qmd$")
})

# ---- G12 through the gate: edits that need no trailer (section 5) ---------------------------------------------

removed_n <- function(res) max(0, res$n_removed)

test_that("4a G12: a value turned into a span removes nothing", {
  d <- g_scenario(list("ch1.qmd" = "We monitored `r n_sites`{.num} sites."),
                  list("ch1.qmd" = "We monitored [a site | # sites]{n=\"n_sites\"} here."))
  res <- g_gate(d)
  expect_identical(removed_n(res), 0)
  expect_true(res$ok)
})

test_that("4a G12: a variable renamed in forty expressions removes nothing", {
  old <- paste0("v", 1:40)
  new <- paste0("w", 1:40)
  d <- g_scenario(list("ch1.qmd" = g_vals(old)), list("ch1.qmd" = g_vals(new)))
  res <- g_gate(d)
  expect_identical(removed_n(res), 0)
  expect_true(res$ok)
})

test_that("4a G12: a changed bound removes nothing", {
  d <- g_scenario(list("ch1.qmd" = "There are `r claim(n_sites, . > 10)`{.num} sites."),
                  list("ch1.qmd" = "There are `r claim(n_sites, . > 5)`{.num} sites."))
  res <- g_gate(d)
  expect_identical(removed_n(res), 0)
  expect_true(res$ok)
})

test_that("4a G12: a paragraph moved between files removes nothing", {
  d <- g_scenario(list("ch1.qmd" = c(G_PROSE, "", g_vals("a_one")), "ch2.qmd" = G_PROSE),
                  list("ch1.qmd" = G_PROSE, "ch2.qmd" = c(G_PROSE, "", g_vals("a_one"), G_ENGINE)))
  res <- g_gate(d)
  expect_identical(removed_n(res), 0)
  expect_true(res$ok)
  expect_identical(nrow(res$removed), 0L)
})

test_that("4a G12: a renamed file removes nothing", {
  d <- g_scenario(list("ch1.qmd" = g_vals(c("a_one", "a_two"))),
                  list("ch1.qmd" = NULL, "intro.qmd" = c(g_vals(c("a_one", "a_two")), G_ENGINE)))
  res <- g_gate(d)
  expect_identical(removed_n(res), 0)
  expect_true(res$ok)
})

test_that("4a G12: reflowing so that a line break lands after `r removes a construct", {
  d <- g_scenario(list("ch1.qmd" = "Wide text before `r n_sites`{.num} and after it."),
                  list("ch1.qmd" = c("Wide text before `r", "n_sites`{.num} and after it.")))
  res <- g_gate(d)
  expect_false(res$ok)
  expect_identical(res$n_removed, 1L)
})

test_that("4a G12: a reflow that keeps every construct whole removes nothing", {
  d <- g_scenario(list("ch1.qmd" = "Wide text before `r n_sites`{.num} and after it."),
                  list("ch1.qmd" = c("Wide text before", "`r n_sites`{.num} and", "after it.")))
  res <- g_gate(d)
  expect_identical(removed_n(res), 0)
  expect_true(res$ok)
})

test_that("4a G12: a value turned into a plain number in prose is a removal (and a numeral finding)", {
  d <- g_scenario(list("ch1.qmd" = "The reading is `r mean_rain`{.num} mm."),
                  list("ch1.qmd" = "The reading is 812 mm."))
  res <- g_gate(d)
  expect_false(res$ok)
  expect_identical(res$n_removed, 1L)
})

test_that("4a G12: a deleted claim() call in a chunk is a removal; setting eval: false is not", {
  base <- c("```{r chk-a}", "claim(n_sites, . > 10)", "```")
  d <- g_scenario(list("ch1.qmd" = base),
                  list("ch1.qmd" = c("```{r chk-a}", "#| eval: false", "claim(n_sites, . > 10)", "```")))
  expect_identical(removed_n(g_gate(d)), 0)
  d2 <- g_scenario(list("ch1.qmd" = base), list("ch1.qmd" = c("```{r chk-a}", "x <- 1", "```")))
  res <- g_gate(d2)
  expect_identical(res$n_removed, 1L)
})
