# Stage 1c: weft_str() (1.10.10, 3.6, 2.4.1, 2.6.8).
# Outside a knit it is a plain function: it resolves its markup and returns
# markdown text, or stops at once with the condition class of the failure.
# Inside a knit failures are collected and marked, naming the chunk.

# ---- outside a knit ------------------------------------------------------------

test_that("3.6.1: weft_str() is exported", {
  expect_true("weft_str" %in% getNamespaceExports("weft"))
  expect_true(is.function(weft::weft_str))
})

test_that("3.6.1 + 1.4: a value with a formatter, and plain text, resolve and come back as a character vector", {
  expect_identical(weft::weft_str("Depth `r 12.5`{.num} m"), "Depth 12.5 m")
  expect_identical(weft::weft_str("Up `r 0.123`{.pct} on last year"), "Up 12.3% on last year")
  expect_identical(weft::weft_str("`r 3`{.word} sites"), "three sites")
  # control: text with no construct, markdown and all, is returned as it came
  expect_identical(weft::weft_str("A **plain** string, 5 < 6."), "A **plain** string, 5 < 6.")
  # bare inline R is stock (1.1.8): evaluated as knitr evaluates it
  expect_identical(weft::weft_str("Sum `r 1 + 1` here"), "Sum 2 here")
})

test_that("3.6.1 + 1.5: n and if spans choose their arm, and nest", {
  k <- 3
  expect_identical(weft::weft_str("Found [a site | # sites]{n=\"k\"}."), "Found 3 sites.")
  k <- 1
  expect_identical(weft::weft_str("Found [a site | # sites]{n=\"k\"}."), "Found a site.")
  expect_identical(weft::weft_str("It was [met | not met]{if=\"k > 5\"}."), "It was not met.")
  expect_identical(weft::weft_str("It was [met | not met]{if=\"k < 5\"}."), "It was met.")
  k <- 3
  expect_identical(
    weft::weft_str("[a site | [few | many]{if=\"k < 5\"} sites]{n=\"k\"} sampled"),
    "few sites sampled"
  )
  k <- 9
  expect_identical(
    weft::weft_str("[a site | [few | many]{if=\"k < 5\"} sites]{n=\"k\"} sampled"),
    "many sites sampled"
  )
})

test_that("3.6.1: a character vector in gives a vector of the same length out, element by element", {
  k <- 2
  x <- c("`r 1.5`{.num} m", "plain", "[one | # sites]{n=\"k\"}", "[a | b]{if=\"k > 5\"}")
  out <- weft::weft_str(x)
  expect_type(out, "character")
  expect_length(out, 4L)
  expect_identical(unname(out), c("1.5 m", "plain", "2 sites", "b"))
  expect_identical(unname(weft::weft_str(character())), character())
})

test_that("3.6 interface: it is evaluated in the caller's environment", {
  f <- function() {
    only_here_k <- 4
    weft::weft_str("[a site | # sites]{n=\"only_here_k\"}")
  }
  expect_identical(f(), "4 sites")
  # control: the name is not visible from here, so the same string fails
  expect_error(weft::weft_str("[a site | # sites]{n=\"only_here_k\"}"))
  # the caller's own variables, and the enclosing ones, are seen
  g <- function() weft::weft_str("`r 2 * only_here_x`{.num}")
  only_here_x <- 6
  expect_identical(g(), "12")
})

test_that("3.6.3 + 2.4.1: outside a knit a failed check stops at once with class weft_claim_failed; a passing check returns its value", {
  k <- 3
  expect_identical(weft::weft_str("Mean `r claim(k, . > 0)`{.num} m"), "Mean 3 m")      # control
  expect_error(weft::weft_str("Mean `r claim(k, . > 100)`{.num} m"), class = "weft_claim_failed")
  expect_error(weft::weft_str("Mean `r claim(k, . > 100)`{.num} m"), ". > 100", fixed = TRUE)
  expect_error(weft::weft_str(c("fine", "Mean `r claim(k, . > 100)`")), class = "weft_claim_failed")
})

test_that("3.6.3 + 1.3.4 + 5.3.2 + 5.3.1: outside a knit a missing value, a value error and a construct error each stop at once with their class", {
  expect_error(weft::weft_str("Mean `r NA_real_`{.num} m"), class = "weft_no_value")
  expect_error(weft::weft_str("Mean `r numeric(0)`{.num} m"), class = "weft_no_value")
  expect_error(weft::weft_str("`r 1.5`{.word} sites"), class = "weft_value_error")
  expect_error(weft::weft_str("[a | b | c | d | e]{if=\"TRUE\"}"), class = "weft_construct_error")   # 1.5.2
  expect_error(weft::weft_str("`r 3`{if=\"TRUE\"}"), class = "weft_construct_error")                 # 1.3.3
  # controls: the legal neighbours of each
  expect_identical(weft::weft_str("`r 1.5`{.num}"), "1.5")
  expect_identical(weft::weft_str("[a | b]{if=\"TRUE\"}"), "a")
  expect_identical(weft::weft_str("`r 3`{.word}"), "three")
})

# ---- inside a knit -------------------------------------------------------------

str_setup <- c("```{r setup, include=FALSE}", "weft::weft_setup()", "k <- 3", "```", "")
str_head <- c("---", "title: \"t\"", "---", "")

test_that("1.10.10 + 3.6.1 (rmarkdown): weft_str() in results = 'asis' with cat() and in kable(caption =) resolve during a knit", {
  lines <- c(str_head, str_setup,
    "```{r asis1, results='asis', echo=FALSE}",
    "cat('Found', weft::weft_str('[a site | # sites]{n=\"k\"}'), 'here.\\n')",
    "```", "",
    "```{r tbl1, echo=FALSE}",
    "knitr::kable(data.frame(x = 1), caption = weft::weft_str('Sites: [a site | # sites]{n=\"k\"}'))",
    "```", "")
  res <- render_rmd(lines, setup = FALSE, format = "knit", in_process = TRUE)
  expect_false(res$failed, label = res$message)
  expect_match(res$md, "Found 3 sites here.", fixed = TRUE)
  expect_match(res$md, "Table: Sites: 3 sites", fixed = TRUE)
  expect_false(grepl("]{", res$md, fixed = TRUE))
  expect_equal(nrow(res$knit$failures), 0L)
})

test_that("3.6.1 (rmarkdown): weft_str() in ggplot2::labs() resolves, and a failure there is collected", {
  skip_if_not_installed("ggplot2")
  plot_chunk <- function(label, title) {
    c(sprintf("```{r %s, echo=FALSE}", label),
      "print(ggplot2::ggplot(data.frame(x = 1, y = 1), ggplot2::aes(x, y)) + ggplot2::geom_point() +",
      sprintf("  ggplot2::labs(title = weft::weft_str('%s')))", title),
      "```", "")
  }
  ok <- c(str_head, str_setup, plot_chunk("fig-ok", "Mean `r claim(k, . > 0)`{.num} m"))
  res <- render_rmd(ok, setup = FALSE, format = "knit", in_process = TRUE)
  expect_false(res$failed, label = res$message)
  expect_equal(nrow(res$knit$failures), 0L)
  bad <- c(str_head, str_setup, plot_chunk("fig-depth", "Mean `r claim(k, . > 100)`{.num} m"))
  res <- render_rmd(bad, setup = FALSE, format = "knit", in_process = TRUE)
  expect_true(res$failed)
  expect_true("weft_failures" %in% res$error$class)
  expect_match(res$message, "fig-depth", fixed = TRUE)
  expect_equal(res$knit$failures$chunk, "fig-depth")
})

str_bad <- c(str_head, str_setup,
  "```{r fig-depth, results='asis', echo=FALSE}",
  "cat('Mean', weft::weft_str('`r claim(k, . > 100)`{.num} m'), '\\n')",
  "```", "",
  "```{r second, results='asis', echo=FALSE}",
  "cat(weft::weft_str('[a]{if=\"k > 100\"}'), '\\n')",
  "```", "")

test_that("2.4.1 + 2.6.2 + 2.6.8 + 3.6.3 (rmarkdown): a failed check in a weft_str() string is collected; the record has no line and names the chunk; the marker names the chunk", {
  res <- render_rmd(str_bad, setup = FALSE, in_process = TRUE)
  expect_true(res$failed)
  expect_true("weft_failures" %in% res$error$class)
  expect_match(res$message, "chunk fig-depth", fixed = TRUE)
  expect_match(res$message, ". > 100 was FALSE", fixed = TRUE)
  f <- res$knit$failures
  expect_equal(nrow(f), 2L)
  expect_true(all(is.na(f$line)))
  expect_equal(f$chunk, c("fig-depth", "second"))
  expect_setequal(f$kind, "failed claim")
  # draft mode: same markers, same records, nothing fails
  d <- render_rmd(str_bad, setup = FALSE, format = "knit", in_process = TRUE, env = c(WEFT_DRAFT = "1"))
  expect_false(d$failed, label = d$message)
  expect_match(unesc(d$md), "Mean 3<<weft: failed claim, chunk fig-depth>> m", fixed = TRUE)
  expect_match(unesc(d$md), "<<weft: failed claim, chunk second>>", fixed = TRUE)
  expect_equal(d$knit$failures$chunk, c("fig-depth", "second"))
  expect_true(all(is.na(d$knit$failures$line)))
})

test_that("2.6.5 + 2.6.8 + 3.6.3 (rmarkdown): a construct error in a weft_str() string stops the render, naming the chunk; in draft mode it is a marker", {
  lines <- c(str_head, str_setup,
    "```{r cs, results='asis', echo=FALSE}",
    "cat(weft::weft_str('[a | b | c | d | e]{if=\"TRUE\"}'), '\\n')",
    "```", "")
  res <- render_rmd(lines, setup = FALSE, in_process = TRUE)
  expect_true(res$failed)
  expect_true("weft_construct_error" %in% res$error$class)
  expect_match(res$message, "cs", fixed = TRUE)
  d <- render_rmd(lines, setup = FALSE, format = "knit", in_process = TRUE, env = c(WEFT_DRAFT = "1"))
  expect_false(d$failed, label = d$message)
  expect_match(unesc(d$md), "<<weft: construct error", fixed = TRUE)
})

test_that("3.6.3 + 2.4.1 (Quarto): a failed check in weft_str() is collected under Quarto too, with the chunk-named marker in draft mode", {
  skip_if_no_quarto()
  lines <- c("---", "title: \"t\"", "engine: knitr", "format: html", "---", "",
             "```{r setup, include=FALSE}", "weft::weft_setup()", "k <- 3", "```", "",
             "```{r fig-depth, results='asis', echo=FALSE}",
             "cat('Mean', weft::weft_str('`r claim(k, . > 100)`{.num} m'), '\\n\\n')",
             "```", "")
  r <- qmd_html(lines)
  expect_true(r$failed)
  expect_match(r$message, "chunk fig-depth", fixed = TRUE)
  d <- qmd_html(lines, env = c(WEFT_DRAFT = "1"))
  expect_false(d$failed, label = d$message)
  expect_match(d$text, "Mean 3<<weft: failed claim, chunk fig-depth>> m", fixed = TRUE)
})

test_that("3.6 interface: with no weft_setup() weft_str() works, and behaves as outside a knit (a failed check stops the chunk)", {
  ok <- c(str_head,
    "```{r a, results='asis', echo=FALSE}",
    "k <- 3",
    "cat('Found', weft::weft_str('[a site | # sites]{n=\"k\"}'), 'here.\\n')",
    "```", "")
  res <- render_rmd(ok, setup = FALSE, format = "knit")
  expect_false(res$failed, label = res$message)
  expect_match(res$md, "Found 3 sites here.", fixed = TRUE)
  bad <- c(str_head,
    "```{r a, results='asis', echo=FALSE}",
    "k <- 3",
    "cat(weft::weft_str('`r claim(k, . > 100)`'))",
    "```", "")
  res <- render_rmd(bad, setup = FALSE)   # knit() alone prints a chunk error and carries on
  expect_true(res$failed)
  expect_match(res$message, ". > 100", fixed = TRUE)
})
