# Stage 1c: constructs in chunk-option captions (1.10.1-1.10.4, 2.1.1 rows
# `opts_hooks` and `chunk`, 2.3.1-2.3.5).
#
# Quarto captions are looked at in HTML: Quarto's markdown writer replaces a
# float with a placeholder and drops its caption. What Quarto hands knitr, by
# experiment: `fig-cap`, `fig-alt` and `fig-subcap` reach knitr as `fig.cap`,
# `fig.alt` and `fig.subcap` (the last as a character vector, one element per
# list item); `tbl-cap` reaches it as `tbl-cap`. test "2.3.1 pinned" below
# pins those names.

# ---- documents ---------------------------------------------------------------

cap_head <- c("---", "title: \"t\"", "engine: knitr", "format: html",
              "execute:", "  echo: false", "---", "")

cap_setup <- function(active = TRUE) {
  c("```{r setup, include=FALSE}",
    if (active) "weft::weft_setup()" else "invisible(NULL)",
    "own_n <- 1", "```", "")
}

# every legal form, one case per chunk
cap_main <- c(
  cap_head, cap_setup(),
  "```{r}",
  "#| label: fig-depth",
  "#| fig-cap: |",
  "#|   Depth at [a site | # sites]{n=\"own_n\"}, mean `r own_depth`{.num} m.",
  "#| fig-alt: |",
  "#|   Alt for [several | one]{if=\"own_n > 1\"} points",
  "own_n <- 4; own_depth <- 12.5",
  "plot(1)", "```", "",
  "```{r}",
  "#| label: fig-plain",
  "#| fig-cap: \"A plain caption with no markup\"",
  "plot(2)", "```", "",
  "```{r}",
  "#| label: fig-panels",
  "#| fig-cap: Two panels",
  "#| fig-subcap:",
  "#|   - |",
  "#|     Panel of [a site | # sites]{n=\"own_n\"}",
  "#|   - Plain panel",
  "#| layout-ncol: 2",
  "plot(1); plot(2)", "```", "",
  "```{r}",
  "#| label: tbl-sum",
  "#| tbl-cap: |",
  "#|   Summary of [a site | # sites]{n=\"tbl_n\"}",
  "tbl_n <- 7",
  "knitr::kable(data.frame(x = 1))", "```", "",
  "```{r}",
  "#| label: tbl-plain",
  "#| tbl-cap: \"Plain table caption\"",
  "knitr::kable(data.frame(y = 2))", "```", "",
  "```{r}",
  "#| label: no-caps",
  "knitr::kable(data.frame(z = 3))", "```", "",
  "See @fig-depth and @tbl-sum.", ""
)

# only what has no construct
cap_plain <- function(active) {
  c(cap_head, cap_setup(active),
    "```{r}", "#| label: fig-plain", "#| fig-cap: \"A plain caption with no markup\"",
    "plot(2)", "```", "",
    "```{r}", "#| label: fig-block", "#| fig-cap: |", "#|   A block scalar caption, no markup",
    "plot(3)", "```", "",
    "```{r}", "#| label: tbl-plain", "#| tbl-cap: \"Plain table caption\"",
    "knitr::kable(data.frame(y = 2))", "```", "",
    "```{r}", "#| label: no-caps", "knitr::kable(data.frame(z = 3))", "```", "",
    "```{r}", "#| label: no-caps-fig", "plot(4)", "```", "",
    "See @fig-plain and @tbl-plain.", "")
}

cap_bad <- c(
  cap_head, cap_setup(),
  "```{r}",
  "#| label: fig-bad",
  "#| fig-cap: |",
  "#|   Mean `r claim(bad_a, . > 100)`{.num} here",
  "bad_a <- 3",
  "plot(1)", "```", "",
  "```{r}",
  "#| label: tbl-bad",
  "#| tbl-cap: |",
  "#|   Table of `r claim(bad_b, . > 100)`{.num} rows",
  "bad_b <- 4",
  "knitr::kable(data.frame(x = 1))", "```", "",
  "```{r}",
  "#| label: fig-alt-bad",
  "#| fig-cap: \"A plain caption beside a failing alt\"",
  "#| fig-alt: |",
  "#|   Alt `r claim(bad_c, . > 100)`{.num} here",
  "bad_c <- 5",
  "plot(1)", "```", "",
  "```{r}",
  "#| label: fig-good",
  "#| fig-cap: |",
  "#|   Fine: `r claim(good_a, . > 0)`{.num} here",
  "good_a <- 6",
  "plot(1)", "```", ""
)

cap_env <- new.env()
cap_get <- function(what) {
  if (is.null(cap_env[[what]])) {
    cap_env[[what]] <- switch(what,
      main = qmd_html(cap_main),
      plain_on = qmd_html(cap_plain(TRUE)),
      plain_off = qmd_html(cap_plain(FALSE)),
      bad = qmd_html(cap_bad),
      bad_draft = qmd_html(cap_bad, env = c(WEFT_DRAFT = "1"))
    )
  }
  cap_env[[what]]
}

# ---- Quarto: resolution ------------------------------------------------------

test_that("1.10.1 + 1.10.2 + 2.3.1 (Quarto): fig-cap, fig-alt, fig-subcap and tbl-cap resolve, and see objects made in their own chunk", {
  skip_if_no_quarto()
  r <- cap_get("main")
  expect_false(r$failed, label = r$message)
  caps <- r$captions
  # fig-cap: a value and an n span; own_n is 1 before the chunk and 4 after it
  expect_true(any(grepl("Figure 1: Depth at 4 sites, mean 12.5 m\\.$", caps)),
              label = paste(caps, collapse = " | "))
  # fig-alt
  expect_true(any(grepl("^Alt for several points$", r$alts)), label = paste(r$alts, collapse = " | "))
  # fig-subcap, a block scalar in a list item, beside a plain item
  expect_true(any(grepl("^\\(a\\) Panel of 4 sites$", caps)), label = paste(caps, collapse = " | "))
  expect_true(any(grepl("^\\(b\\) Plain panel$", caps)))
  # tbl-cap, with an object made only in its own chunk
  expect_true(any(grepl("Table 1: Summary of 7 sites$", caps)), label = paste(caps, collapse = " | "))
  # nothing left raw
  expect_false(grepl("]{", r$text, fixed = TRUE))
  expect_false(grepl("{n=", r$html, fixed = TRUE))
})

test_that("1.10.1 control: the same document with weft off leaves the constructs as text (the test can fail)", {
  skip_if_no_quarto()
  off <- sub("weft::weft_setup()", "invisible(NULL)", cap_main, fixed = TRUE)
  r <- qmd_html(off)
  expect_false(r$failed, label = r$message)
  expect_true(any(grepl("# sites", r$captions, fixed = TRUE)))   # Pandoc keeps the arms as text
  expect_false(any(grepl("Depth at 4 sites", r$captions)))
})

test_that("2.3.4 (Quarto): figure and table numbering and cross-references are unaffected", {
  skip_if_no_quarto()
  r <- cap_get("main")
  expect_false(r$failed, label = r$message)
  expect_match(r$html, "<a href=\"#fig-depth\" class=\"quarto-xref\">Figure&nbsp;1</a>", fixed = TRUE)
  expect_match(r$html, "<a href=\"#tbl-sum\" class=\"quarto-xref\">Table&nbsp;1</a>", fixed = TRUE)
  caps <- r$captions
  # the captions that carry constructs are resolved and numbered too
  expect_true(any(grepl("^Figure 1: Depth at 4 sites", caps)))
  expect_true(any(grepl("^Table 1: Summary of 7 sites", caps)))
  # numbered in order of appearance; the plain caption is figure 2, the panels figure 3
  expect_true(any(grepl("^Figure 2: A plain caption with no markup$", caps)))
  expect_true(any(grepl("^Figure 3: Two panels$", caps)))
  expect_true(any(grepl("^Table 2: Plain table caption$", caps)))
})

test_that("1.10.1 + 2.3.1 + 1.10.3 (Quarto): a caption with no construct is byte-identical to stock, as is a chunk with no tbl-cap (2.1.1 `chunk` row)", {
  skip_if_no_quarto()
  on <- cap_get("plain_on")
  off <- cap_get("plain_off")
  expect_false(on$failed, label = on$message)
  expect_false(off$failed, label = off$message)
  expect_true(nzchar(off$html))
  expect_identical(on$html, off$html)
  # the chunk with no tbl-cap was not given a caption (a NULL tbl-cap would
  # have been forwarded to its cells): exactly the two captions that were written
  tab_caps <- grep("^Table ", on$captions, value = TRUE)
  expect_identical(tab_caps, "Table 1: Plain table caption")
  expect_identical(grep("^Figure ", on$captions, value = TRUE),
                   c("Figure 1: A plain caption with no markup", "Figure 2: A block scalar caption, no markup"))
})

# ---- Quarto: failures --------------------------------------------------------

test_that("2.3.2 + 2.3.3 + 2.6.2 (Quarto): a failed check in a caption is collected and located by chunk and option", {
  skip_if_no_quarto()
  r <- cap_get("bad")
  expect_true(r$failed)
  expect_match(r$message, "weft: 3 claims failed", fixed = TRUE)
  expect_match(r$message, "chunk fig-bad, fig[.-]cap")
  expect_match(r$message, "chunk tbl-bad, tbl-cap")
  expect_match(r$message, "chunk fig-alt-bad, fig[.-]alt")
  # the check as written, and the value
  expect_match(r$message, ". > 100 was FALSE", fixed = TRUE)
  expect_match(r$message, "(value 3)", fixed = TRUE)
  expect_match(r$message, "(value 5)", fixed = TRUE)
})

test_that("2.3.3 + 2.6.8 (Quarto, draft): the marker names the chunk and sits in the caption; nothing fails", {
  skip_if_no_quarto()
  r <- cap_get("bad_draft")
  expect_false(r$failed, label = r$message)
  expect_true(any(grepl("Mean 3<<weft: failed claim, chunk fig-bad>> here", r$captions, fixed = TRUE)),
              label = paste(r$captions, collapse = " | "))
  expect_true(any(grepl("Table of 4<<weft: failed claim, chunk tbl-bad>> rows", r$captions, fixed = TRUE)))
  expect_match(r$html, "weft: failed claim, chunk fig-alt-bad")
  expect_false(grepl("weft: failed claim, chunk fig-good", r$html, fixed = TRUE))
  # the figure that holds prints its value
  expect_true(any(grepl("Fine: 6 here", r$captions, fixed = TRUE)))
})

# ---- Quarto: static errors ---------------------------------------------------

quarto_cap_doc <- function(chunk_lines, head = cap_head) {
  c(head, cap_setup(), "```{r}", chunk_lines, "plot(1)", "```", "")
}

test_that("1.10.3 (Quarto): a construct in a caption that is not a block scalar is a construct error naming the line", {
  skip_if_no_quarto()
  lines <- quarto_cap_doc(c("#| label: fig-q",
                            "#| fig-cap: 'Depth at [a site | # sites]{n=\"3\"}'"))
  r <- qmd_html(lines)
  expect_true(r$failed)
  expect_match(r$message, at_line(r, file_line(lines, "#| fig-cap:")))
  expect_match(r$message, "block scalar", ignore.case = TRUE)
  # control: a plain caption in the same non-block form is no error (it has no construct)
  ok <- qmd_html(quarto_cap_doc(c("#| label: fig-q", "#| fig-cap: 'Depth at three sites'")))
  expect_false(ok$failed, label = ok$message)
})

test_that("1.10.4 (Quarto): tab.cap, and !expr in fig-subcap, with a construct are errors", {
  skip_if_no_quarto()
  l1 <- quarto_cap_doc(c("#| label: tbl-q", "#| tab.cap: |", "#|   Table [a | b]{if=\"TRUE\"}"))
  r1 <- qmd_html(l1)
  expect_true(r1$failed)
  expect_match(r1$message, "tab.cap", fixed = TRUE)
  expect_match(r1$message, at_line(r1, file_line(l1, "#|   Table")))
  l2 <- quarto_cap_doc(c("#| label: fig-q", "#| fig-cap: Panels",
                         "#| fig-subcap: !expr c('One [a | b]{if=\"TRUE\"}', 'Two')",
                         "#| layout-ncol: 2"))
  r2 <- qmd_html(l2)
  expect_true(r2$failed)
  # Quarto's own YAML validation rejects this before knitr runs
  # control: the legal list form of fig-subcap is in the main document
  expect_false(cap_get("main")$failed)
})

test_that("2.3.5 (Quarto): a construct in the caption of a chunk under document-level cache: true is an error that points to a div", {
  skip_if_no_quarto()
  head <- c("---", "title: \"t\"", "engine: knitr", "format: html",
            "execute:", "  echo: false", "  cache: true", "---", "")
  lines <- quarto_cap_doc(c("#| label: fig-c", "#| fig-cap: |", "#|   Depth at [a site | # sites]{n=\"3\"}"), head)
  r <- qmd_html(lines)
  expect_true(r$failed)
  expect_match(r$message, "div")
  expect_match(r$message, at_line(r, file_line(lines, "#|   Depth at")))
  # control: the same chunk with no cache
  expect_false(cap_get("main")$failed)
})

# ---- rmarkdown ---------------------------------------------------------------

rmd_head <- c("---", "title: \"t\"", "---", "")
rmd_setup <- c("```{r setup, include=FALSE}", "weft::weft_setup()", "own_n <- 1", "```", "")

rmd_main <- c(
  rmd_head, rmd_setup,
  "```{r fig-depth, echo=FALSE, fig.cap='Depth at [a site | # sites]{n=\"own_n\"}, mean `r own_depth`{.num} m.', fig.alt='Alt for [several | one]{if=\"own_n > 1\"} points'}",
  "own_n <- 4; own_depth <- 12.5",
  "plot(1)", "```", "",
  "```{r fig-plain, echo=FALSE, fig.cap=\"A plain caption\", fig.alt=\"A plain alt\"}",
  "plot(2)", "```", ""
)

test_that("1.10.1 + 1.10.2 + 2.3.1 (rmarkdown): fig.cap and fig.alt resolve after the chunk; a plain caption is untouched", {
  res <- render_rmd(rmd_main, setup = FALSE, format = "knit", in_process = TRUE)
  expect_false(res$failed, label = res$message)
  expect_match(res$md, "Depth at 4 sites, mean 12.5 m.", fixed = TRUE)
  expect_match(res$md, "Alt for several points", fixed = TRUE)
  expect_match(res$md, "A plain caption", fixed = TRUE)
  expect_match(res$md, "A plain alt", fixed = TRUE)
  expect_false(grepl("]{", res$md, fixed = TRUE))
  # control: weft off leaves them as text
  off <- render_rmd(sub("weft::weft_setup()", "invisible(NULL)", rmd_main, fixed = TRUE),
                    setup = FALSE, format = "knit")
  expect_true(grepl("{n=", off$md, fixed = TRUE))
})

test_that("1.10.1 (rmarkdown): a caption with no construct is byte-identical to stock", {
  plain <- c(rmd_head, rmd_setup,
             "```{r fig-plain, echo=FALSE, fig.cap=\"A plain caption\", fig.alt=\"A plain alt\"}", "plot(2)", "```", "",
             "```{r tab, echo=FALSE}", "knitr::kable(data.frame(x = 1), caption = 'Plain table')", "```", "")
  on <- render_rmd(plain, setup = FALSE, format = "knit")
  off <- render_rmd(sub("weft::weft_setup()", "invisible(NULL)", plain, fixed = TRUE), setup = FALSE, format = "knit")
  expect_false(on$failed, label = on$message)
  expect_identical(on$text, off$text)
})

test_that("2.3.2 + 2.3.3 + 2.6.2 + 2.6.8 (rmarkdown): a failed check in fig.cap is located by chunk and option, with a chunk marker in draft mode", {
  lines <- c(rmd_head, rmd_setup,
             "```{r fig-bad, echo=FALSE, fig.cap='Mean `r claim(bad_a, . > 100)`{.num} here'}",
             "bad_a <- 3", "plot(1)", "```", "")
  res <- render_rmd(lines, setup = FALSE, in_process = TRUE)
  expect_true(res$failed)
  expect_true("weft_failures" %in% res$error$class)
  expect_match(res$message, "chunk fig-bad, fig.cap", fixed = TRUE)
  expect_match(res$message, ". > 100 was FALSE", fixed = TRUE)
  f <- res$knit$failures
  expect_equal(nrow(f), 1L)
  expect_equal(f$kind, "failed claim")
  expect_equal(f$chunk, "fig-bad")
  expect_match(f$detail, "fig.cap", fixed = TRUE)
  # draft: the marker names the chunk and sits in the caption
  d <- render_rmd(lines, setup = FALSE, format = "knit", in_process = TRUE, env = c(WEFT_DRAFT = "1"))
  expect_false(d$failed, label = d$message)
  expect_match(unesc(d$md), "Mean 3<<weft: failed claim, chunk fig-bad>> here", fixed = TRUE)
})

test_that("2.3.5 (rmarkdown): cache = TRUE, eval = FALSE and a non-R engine with a construct in the caption are construct errors that point to a div; plain captions are legal there", {
  cap <- "fig.cap='Depth at [a site | # sites]{n=\"3\"}'"
  cases <- list(
    cache = sprintf("```{r cap-c, echo=FALSE, cache=TRUE, %s}", cap),
    eval  = sprintf("```{r cap-e, echo=FALSE, eval=FALSE, %s}", cap),
    engine = sprintf("```{bash cap-b, echo=FALSE, %s}", cap)
  )
  for (nm in names(cases)) {
    lines <- c(rmd_head, rmd_setup, cases[[nm]], "echo hi", "```", "")
    res <- render_rmd(lines, setup = FALSE, format = "knit")
    expect_true(res$failed, label = nm)
    expect_true("weft_construct_error" %in% res$error$class, label = nm)
    expect_match(res$message, "div", label = nm)
    expect_match(res$message, at_line(res, file_line(lines, "fig.cap=")), label = nm)
  }
  # controls: no construct, in the same three kinds of chunk
  plain <- "fig.cap='Depth at three sites'"
  for (hdr in c(sprintf("```{r cap-c, echo=FALSE, cache=TRUE, %s}", plain),
                sprintf("```{r cap-e, echo=FALSE, eval=FALSE, %s}", plain),
                sprintf("```{bash cap-b, echo=FALSE, %s}", plain))) {
    res <- render_rmd(c(rmd_head, rmd_setup, hdr, "echo hi", "```", ""), setup = FALSE, format = "knit")
    expect_false(res$failed, label = paste(hdr, res$message))
  }
})

test_that("1.10.4 (rmarkdown): a construct in tab.cap is a construct error; the same text in fig.cap is legal", {
  bad <- c(rmd_head, rmd_setup, "```{r tc, echo=FALSE, tab.cap='Table [a | b]{if=\"TRUE\"}'}",
           "knitr::kable(data.frame(x = 1))", "```", "")
  res <- render_rmd(bad, setup = FALSE, format = "knit")
  expect_true(res$failed)
  expect_true("weft_construct_error" %in% res$error$class)
  expect_match(res$message, "tab.cap", fixed = TRUE)
  expect_match(res$message, at_line(res, file_line(bad, "tab.cap=")))
  ok <- c(rmd_head, rmd_setup, "```{r tc, echo=FALSE, fig.cap='Plot [a | b]{if=\"TRUE\"}'}", "plot(1)", "```", "")
  res <- render_rmd(ok, setup = FALSE, format = "knit")
  expect_false(res$failed, label = res$message)
  expect_match(res$md, "Plot a", fixed = TRUE)
})

test_that("2.3.1 pinned: the option names are fig.cap and fig.alt (rmarkdown) and, under Quarto, the hooks see fig.cap, fig.alt, fig.subcap and tbl-cap", {
  skip_if_no_quarto()
  # a spy opts_hook records which options knitr is handed; weft is not active
  head <- c("---", "title: \"t\"", "engine: knitr", "format: html", "---", "")
  spy <- c("```{r}", "#| include: false",
           "for (o in c('fig.cap', 'fig.alt', 'fig.subcap', 'tbl-cap', 'fig-cap', 'fig-alt', 'fig-subcap', 'tbl.cap')) {",
           "  local({ o <- o; knitr::opts_hooks$set(setNames(list(function(options) { message('SPY ', o); options }), o)) })",
           "}", "```", "")
  body <- c("```{r}", "#| label: fig-s", "#| fig-cap: Cap", "#| fig-alt: Alt", "#| fig-subcap:", "#|   - One", "#|   - Two",
            "#| layout-ncol: 2", "plot(1); plot(2)", "```", "",
            "```{r}", "#| label: tbl-s", "#| tbl-cap: Tcap", "knitr::kable(data.frame(x = 1))", "```", "")
  r <- qmd_html(c(head, spy, body))
  expect_false(r$failed, label = r$message)
  seen <- unique(sub(".*SPY ", "", regmatches(r$log, gregexpr("SPY [A-Za-z.-]+", r$log))[[1]]))
  expect_true(all(c("fig.cap", "fig.alt", "fig.subcap", "tbl-cap") %in% seen), label = paste(seen, collapse = ", "))
  expect_false(any(c("fig-cap", "fig-alt", "fig-subcap", "tbl.cap") %in% seen))
})
