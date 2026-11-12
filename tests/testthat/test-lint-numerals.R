# Package 3b: the `numeral` lint (L19, rules 5.2.1-5.2.6; contract: dev/design-3.md).
# Every row of L19's table is a case under .qmd and .Rmd. Helpers: helper-3.R,
# helper-3b.R (expect_numerals()). ASCII only: \u escapes in ordinary strings.

# ---- the shape of a finding -----------------------------------------------------------

test_that("3b L19: a prose numeral is a tier-1 finding with the documented columns and message", {
  lines <- c("Intro words.", "", "We sampled 12 sites, 45% of them.")
  for (e in c("qmd", "Rmd")) {
    x <- lint_one(lines, rules = "numeral", ext = e)
    expect_findings_shape(x)
    expect_identical(x$text, c("12", "45%"))
    expect_identical(x$rule, c("numeral", "numeral"))
    expect_identical(x$tier, c(1L, 1L))
    expect_identical(x$spec, c("5.2.1", "5.2.1"))
    expect_identical(x$context, c("prose", "prose"))
    expect_identical(x$file, rep(paste0("doc.", e), 2L))
    expect_identical(x$line, c(3L, 3L))
    expect_identical(x$end_line, c(3L, 3L))
    expect_identical(x$col, c(as.integer(f3_pos(lines, "12")[["col"]]),
                              as.integer(f3_pos(lines, "45%")[["col"]])))
    expect_identical(x$message[[2]], "\"45%\" is a number typed in prose (rule 5.2.1).")
    expect_false(anyNA(x$hint))
    expect_match(x$hint[[2]], "weft-literal", fixed = TRUE)
    expect_true(all(is.na(x$sentence)))
  }
})

test_that("3b L19: a document with no typed numeral gives an empty weft_findings", {
  x <- lint_one(c("Plain words only.", "", "More words."), rules = "numeral")
  expect_findings_shape(x)
  expect_identical(nrow(x), 0L)
})

# ---- L19's table, row by row ------------------------------------------------------------

test_that("3b L19: the first row, a sentence with four numerals", {
  expect_numerals("We sampled 12 sites, 45% of them (n=12) in 3\u20135 m of water.",
                  c("12", "45%", "12", "3\u20135"), ctx = "prose")
})

test_that("3b L19: the second row, numerals with letters, signs and superscripts", {
  expect_numerals(
    "an 11-year record; the 3rd survey; the 1990s; \u22120.5; p<0.05; 10^6^",
    c("11-year", "3rd", "1990s", "\u22120.5", "0.05", "10^6"))
})

test_that("3b L19: a word that starts with a letter is a name, whatever digits it holds", {
  expect_numerals("The CO2, PM2.5, x2, COVID-19 and No.5 values are names.", character())
})

test_that("3b L19: numbers in headings are numerals; a year is one unless numeral_years", {
  expect_numerals("## 2. Methods {#sec-m}", "2")
  expect_numerals("## Results for 2020 {#sec-r}", "2020")
  expect_numerals("## Results for 2020 {#sec-r}", character(), weft_yml = "numeral_years: true")
  # a setext heading, and a heading with trailing hashes
  expect_numerals(c("Results 2020", "------------"), "2020")
  expect_numerals("## Results for 2020 ##", "2020")
})

test_that("3b L19: table body cells are read, the delimiter row is not", {
  tbl <- c("| Site | Depth |", "|---|---:|", "| Site A | 3.4 |")
  expect_numerals(tbl, "3.4")
  # no spaces round the cell
  expect_numerals(c("|Site|Depth|", "|:--|--:|", "|A|3.4|"), "3.4")
  # a cell is prose; the header is too
  expect_numerals(c("| Depth 5 | Site |", "|---|---|", "| a | b |"), "5")
})

test_that("3b L19: dates, times and version numbers", {
  expect_numerals("We met on 12 March 2020; at 10:30; using R 4.4.3.",
                  c("12", "2020", "10:30", "4.4.3"))
})

test_that("3b L19: the digits of a typed cross-reference, with the cross-reference message", {
  lines <- "See Figure 3 and fig. 3 and [Table 2](#tbl-a)."
  expect_numerals(lines, c("3", "3", "2"))
  for (e in c("qmd", "Rmd")) {
    x <- lint_one(lines, rules = "numeral", ext = e)
    expect_identical(x$spec, rep("5.2.4", 3L))
    expect_identical(x$message[[1]],
      "\"3\" after \"Figure\" is a typed cross-reference number; use @fig-<label> (rule 5.2.4).")
    expect_match(x$message[[2]], "@fig-", fixed = TRUE)
    expect_match(x$message[[3]], "@tbl-", fixed = TRUE)
    expect_true(all(grepl("cross-reference", x$message, fixed = TRUE)))
    expect_true(all(grepl("rule 5.2.4", x$message, fixed = TRUE)))
  }
})

test_that("3b L19: every cross-reference word, any case and number, names its prefix", {
  words <- list(
    list("Figure 3", "3", "@fig-"), list("FIGURE 3", "3", "@fig-"), list("Figures 3", "3", "@fig-"),
    list("figs. 3", "3", "@fig-"), list("Table 2", "2", "@tbl-"), list("tables 2", "2", "@tbl-"),
    list("Section 4", "4", "@sec-"), list("sections 4", "4", "@sec-"),
    list("Equation 5", "5", "@eq-"), list("Eq. 5", "5", "@eq-"), list("eqs 5", "5", "@eq-"),
    list("Chapter 6", "6", NA), list("Appendix 7", "7", NA))
  for (w in words) {
    for (e in c("qmd", "Rmd")) {
      x <- lint_one(paste("As shown in", w[[1]], "here."), rules = "numeral", ext = e)
      expect_identical(x$text, w[[2]], info = w[[1]])
      expect_match(x$message, "cross-reference", fixed = TRUE, info = w[[1]])
      if (!is.na(w[[3]])) expect_match(x$message, w[[3]], fixed = TRUE, info = w[[1]])
    }
  }
})

test_that("3b L19: an ordinary numeral's message does not mention cross-references", {
  x <- lint_one("There were 12 sites.", rules = "numeral")
  expect_false(grepl("cross-reference", x$message, fixed = TRUE))
  # the previous word is not a cross-reference word when a word comes between
  x <- lint_one("The Figure shows 3 sites.", rules = "numeral")
  expect_false(grepl("cross-reference", x$message, fixed = TRUE))
})

test_that("3b L19: a label word exempts the next numeral only", {
  expect_numerals("Site 3 and 4", "4", weft_yml = "label_words: [Site]")
  # not without the setting
  expect_numerals("Site 3 and 4", c("3", "4"))
})

test_that("3b L19: label words are compared as typed, after stripping punctuation", {
  yml <- "label_words: [Site]"
  expect_numerals("We visited (Site 3) today.", character(), weft_yml = yml)
  expect_numerals("We visited Site: 3 today.", character(), weft_yml = yml)
  # case as typed
  expect_numerals("We visited site 3 today.", "3", weft_yml = yml)
  expect_numerals("We visited SITE 3 today.", "3", weft_yml = yml)
  # another word is not a label word
  expect_numerals("We visited Zone 3 today.", "3", weft_yml = yml)
  # several label words
  expect_numerals("We visited Zone 3 and Site 4 today.", character(),
                  weft_yml = "label_words: [Site, Zone]")
})

test_that("3b L19: the label word is the previous word in the same block", {
  yml <- "label_words: [Site]"
  # across a line break inside one paragraph
  expect_numerals(c("We visited Site", "3 today."), character(), weft_yml = yml)
  # across a paragraph break
  expect_numerals(c("We visited Site", "", "3 sites were dry."), "3", weft_yml = yml)
})

test_that("3b L19: a cross-reference word that is also a label word exempts its numeral", {
  expect_numerals("As in Figure 3 of the other report.", character(),
                  weft_yml = "label_words: [Figure]")
  # as typed: a lower-case figure is still a cross-reference word that is not a label word
  x <- lint_one("As in figure 3 of the other report.", rules = "numeral",
                weft_yml = "label_words: [Figure]")
  expect_identical(x$text, "3")
  expect_match(x$message, "cross-reference", fixed = TRUE)
})

test_that("3b L19: label_words in front matter wins over _weft.yml, setting by setting", {
  doc <- c("---", "title: T", "weft:", "  label_words: [Site]", "---", "",
           "We visited Site 3 and Zone 4.")
  for (e in c("qmd", "Rmd")) {
    x <- lint_one(doc, rules = "numeral", ext = e, weft_yml = "label_words: [Zone]")
    expect_identical(x$text, "4")
  }
})

test_that("3b L19: links, URLs, DOIs and addresses are not prose", {
  rows <- c("Visit https://x.org/2020/a today.", "See <https://x.org/1> now.",
            "Cited as doi 10.1000/xyz in full.", "Mail a@b2.org please.",
            "See www.example.org/2020 for more.", "Use [the site](https://x.org/2020) here.",
            "Read [the guide][g2] first.", "[g2]: https://x.org/2020/guide")
  for (r in rows) expect_numerals(r, character())
  # link text is prose
  expect_numerals("Use [12 sites](https://x.org/2020) here.", "12")
})

test_that("3b L19: inline R, code spans, comments, entities and raw TeX are not prose", {
  rows <- c("Some `r n` sites.", "Use `x[3]` here.", "<!-- 12 -->", "Dash &#8212; here.",
            "Space \\vspace{2em} here.", "A code span ``x[12]`` here.",
            "Shortcode {{< include chap2.qmd >}} here.")
  for (r in rows) expect_numerals(r, character())
})

test_that("3b L19: text between HTML tags, quoted numerals and an escaped dollar are prose", {
  expect_numerals("<span>12</span>", "12")
  expect_numerals("\u201c12\u201d", "12")
  expect_numerals("It cost \\$5 in total.", "5")
})

test_that("3b L19: citations and cross-references are not prose", {
  expect_numerals("[@smith2020, p. 4]", character())
  expect_numerals("@smith2020 [p. 4]", character())
  expect_numerals("See @fig-3d for details.", character())
  expect_numerals("As in [-@smith2020; @jones2019, ch. 2] and @{odd2020} too.", character())
})

test_that("3b L19: footnote markers are not prose but an inline note's text is", {
  expect_numerals(c("Text here.[^1]", "", "[^1]: Plain note."), character())
  expect_numerals("Some text^[In 2019 only.] here.", "2019")
  # the text of a footnote definition is prose
  expect_numerals(c("Text here.[^1]", "", "[^1]: Note about 8 sites."), "8")
})

test_that("3b L19: list markers are not numerals, but a year at a line start inside a paragraph is", {
  expect_numerals(c("Intro words.", "", "1. First"), character())
  expect_numerals(c("Intro words.", "", "(3) Third", "", "2) Second"), character())
  expect_numerals(c("Some text and in", "2020. The end."), "2020")
  # a list item's text is prose
  expect_numerals(c("Intro words.", "", "- Dry at 5 sites", "- Wet"), "5")
  expect_numerals(c("Intro words.", "", "1. First", "2. Dry at 5 sites"), "5")
  expect_numerals(c("> quoted 5 sites"), "5")
})

test_that("3b L19: image alt text is prose, its target is not", {
  expect_numerals("![Map of 4 sites](m2.png)", "4")
})

test_that("3b L19: span text is prose; the attribute block is not", {
  expect_numerals("[3 sites]{if=\"n > 2\"}", "3")
  expect_numerals("[a site | # sites]{n=\"k\"}", character())
  expect_numerals("[x]{.smallcaps}", character())
  expect_numerals("[x]{n=\"3\"}", character())
  expect_numerals("Wet `r x`{.num digits=2} sites.", character())
})

test_that("3b L19: .weft-literal spans and divs, and cite spans, exempt their numerals", {
  expect_numerals("[10 m]{cite=\"smith2020\"}", character())
  expect_numerals("[0.45 \u00b5m]{.weft-literal why=\"SOP 12\"}", character())
  expect_numerals(c("Intro words.", "", "::: {.weft-literal why=\"quoted rule\"}",
                    "The dose is 45 mg.", ":::"), character())
  # only what is inside is exempt
  expect_numerals("[0.45 \u00b5m]{.weft-literal why=\"SOP\"} and 7 more.", "7")
  expect_numerals("[10 m]{cite=\"smith2020\"} and 7 more.", "7")
})

test_that("3b L19: a numeral inside a weft construct's text span or a paragraph opened by a construct", {
  expect_numerals("[3 sites]{if=\"n > 2\"} remain wet.", "3")
  expect_numerals("[a site | sites]{n=\"k\"} had 5 visits.", "5")
  expect_numerals(c("Intro words.", "", "`r x`{.num} of 12 sites"), "12")
  # the same under an indented first line of a list item
  expect_numerals(c("- [a site | sites]{n=\"k\"} had 5 visits."), "5")
})

# ---- math (5.2.6) ---------------------------------------------------------------------------

test_that("3b L19: numerals in math, except exponents and subscripts", {
  expect_numerals("$p = 0.02$", "0.02", ctx = "prose")
  expect_numerals("$p = `r p`$", character())
  expect_numerals("$x^2 + \\beta_{12}$", character())
  expect_numerals("$10^{-3}$", "10")
  expect_numerals("$\\frac{1}{n}$", "1")
})

test_that("3b L19: math message and spec", {
  for (e in c("qmd", "Rmd")) {
    x <- lint_one("The level is $p = 0.02$ here.", rules = "numeral", ext = e)
    expect_identical(x$text, "0.02")
    expect_identical(x$spec, "5.2.6")
    expect_identical(x$message, "\"0.02\" is a number typed in math (rule 5.2.6).")
    expect_identical(x$tier, 1L)
  }
})

test_that("3b L19: display math and the other delimiters", {
  expect_numerals(c("Intro words.", "", "$$ x = 3 $$"), "3")
  expect_numerals(c("Intro words.", "", "$$", "x = 3 + y_2", "$$"), "3")
  expect_numerals("Here \\(a = 5\\) and more.", "5")
  expect_numerals(c("Intro words.", "", "\\[ b = 7 \\]"), "7")
  expect_numerals("$a_1 + b^{12} + c_{k2}$", character())
  expect_numerals("$y = 1.5x + 20$", c("1.5", "20"))
})

test_that("3b L19: a .weft-literal span around a formula exempts it; a cite span too", {
  expect_numerals("[$\\bar{x} = \\frac{1}{n}$]{.weft-literal why=\"definition of the mean\"}",
                  character())
  expect_numerals("[$z = 3$]{cite=\"smith2020\"}", character())
  expect_numerals("[$z = 3$]{.weft-literal why=\"given\"} and $w = 4$", "4")
})

# ---- front matter, captions, strings ---------------------------------------------------------

test_that("3b L19: front matter title is read, at its line and column", {
  doc <- c("---", "title: \"Survey 2020\"", "date: 2020-01-03", "params: {n: 5}", "---", "",
           "Words only.")
  for (e in c("qmd", "Rmd")) {
    x <- lint_one(doc, rules = "numeral", ext = e)
    expect_identical(x$text, "2020")
    expect_identical(x$line, 2L)
    expect_identical(x$col, as.integer(f3_pos(doc, "2020")[["col"]]))
    expect_identical(x$context, "front-matter")
  }
})

test_that("3b L19: only title, subtitle, abstract and description are read", {
  doc <- c("---", "title: Plain", "subtitle: \"Part 2\"", "author: Group 7",
           "description: Fieldwork in 5 sites", "keywords: [a1, 10]", "date: 2020-01-03",
           "params: {n: 5}", "---", "", "Words only.")
  for (e in c("qmd", "Rmd")) {
    x <- lint_one(doc, rules = "numeral", ext = e)
    expect_identical(x$text, c("2", "5"))
    expect_identical(x$line, c(3L, 5L))
    expect_identical(x$context, c("front-matter", "front-matter"))
  }
})

test_that("3b L19: a block-scalar abstract is read line by line", {
  doc <- c("---", "title: T", "abstract: |", "  Over 3 sites we", "  found 9 dry ones.", "---", "",
           "Words only.")
  expect_numerals(doc, c("3", "9"), ctx = "front-matter")
})

test_that("3b L19: a late metadata block's abstract numeral is reported at its YAML line", {
  doc <- c("---", "title: T", "---", "", n3_filler(80), "", "---", "abstract: |",
           "  Over the 4 sites.", "---", "", "After text.")
  expect_identical(f3_pos(doc, "4 sites")[["line"]], 88L)
  for (e in c("qmd", "Rmd")) {
    x <- lint_one(doc, rules = "numeral", ext = e)
    expect_identical(x$text, "4")
    expect_identical(x$line, 88L)
    expect_identical(x$col, as.integer(f3_pos(doc, "4 sites")[["col"]]))
    expect_identical(x$context, "front-matter")
  }
})

test_that("3b L19: chunk-option captions and alt text are read, with context caption", {
  chunk <- function(...) c("```{r}", ..., "plot(1)", "```")
  expect_numerals(chunk("#| fig-cap: \"Depth at 3 sites\""), "3", ctx = "caption")
  expect_numerals(chunk("#| fig-alt: Scatter of 75 points"), "75", ctx = "caption")
  expect_numerals(chunk("#| tbl-cap: \"Counts at 6 sites\""), "6", ctx = "caption")
  expect_numerals(chunk("#| fig-scap: \"Short for 4\""), "4", ctx = "caption")
  expect_numerals(c("```{r, fig.cap=\"In 2019\"}", "plot(1)", "```"), "2019", ctx = "caption")
  expect_numerals(c("```{r, fig.alt=\"Dots for 12 sites\"}", "plot(1)", "```"), "12", ctx = "caption")
})

test_that("3b L19: block-scalar and list captions are read at their own lines", {
  expect_numerals(c("```{r}", "#| fig-cap: |", "#|   Depth at 7 sites", "plot(1)", "```"),
                  "7", ctx = "caption")
  expect_numerals(c("```{r}", "#| fig-subcap:", "#|   - \"Panel of 6 sites\"",
                    "#|   - \"Panel of 8 sites\"", "plot(1)", "```"),
                  c("6", "8"), ctx = "caption")
  expect_numerals(c("```{r, fig.subcap=c(\"Panel of 5\", \"Panel of 9\")}", "plot(1)", "```"),
                  c("5", "9"), ctx = "caption")
})

test_that("3b L19: a caption that is an expression, and chunk labels and code, are not read", {
  expect_numerals(c("```{r}", "#| fig-cap: !expr paste(\"n\", 9)", "plot(1)", "```"), character())
  expect_numerals(c("```{r, fig.cap=paste(\"n\", 8)}", "plot(1)", "```"), character())
  expect_numerals(c("```{r}", "#| label: fig-depth-3", "#| echo: false", "x <- 12", "```"),
                  character())
})

test_that("3b L19: a .weft-literal inside a block-scalar caption exempts only itself", {
  chunk <- c("```{r}", "#| fig-cap: |", "#|   Depth at [3]{.weft-literal why=\"SOP\"} sites and 5 more",
             "plot(1)", "```")
  expect_numerals(chunk, "5", ctx = "caption")
})

test_that("3b L19: weft_str() strings, brk() and lookup() phrases are read, with their contexts", {
  chunk <- function(code) c("```{r}", code, "```")
  expect_numerals(chunk("x <- weft_str(\"over 5 years: `r x`{.num}\")"), "5", ctx = "weft_str")
  for (e in c("qmd", "Rmd")) {
    lines <- chunk("y <- brk(. > 2 ~ \"more than 2 sites\")")
    x <- lint_one(lines, rules = "numeral", ext = e)
    expect_identical(x$text, "2")
    expect_identical(x$context, "phrase")
    expect_identical(x$line, 2L)
    expect_identical(x$col, as.integer(f3_pos(lines, "2 sites")[["col"]]))
    x <- lint_one(chunk("z <- lookup(c(a = \"top 10\"))"), rules = "numeral", ext = e)
    expect_identical(x$text, "10")
    expect_identical(x$context, "phrase")
  }
  # a string that is a name is not a phrase
  expect_numerals(chunk("z <- lookup(c(hi = \"high\"))"), character())
  expect_numerals(chunk("z <- lookup(c(\"top 9\" = \"high\"))"), character())
})

test_that("3b L19: strings in code that is not read, other engines, and unrelated strings are not read", {
  expect_numerals(c("```{r}", "#| eval: false", "x <- weft_str(\"over 5 years\")", "```"), character())
  expect_numerals(c("```{r, eval=FALSE}", "x <- weft_str(\"over 5 years\")", "```"), character())
  expect_numerals(c("```{python}", "x = \"over 5 years\"", "```"), character())
  expect_numerals(c("```{r}", "x <- paste(\"over 5 years\")", "```"), character())
  expect_numerals(c("```{r}", "x <- brk(. > 2 ~ \"more than 2\")", "```"), "2", pos = FALSE)
})

test_that("3b L19: a caption in an eval: false chunk is read, its weft_str() strings are not", {
  doc <- c("```{r}", "#| eval: false", "#| fig-cap: \"Depth at 3 sites\"",
           "x <- weft_str(\"over 5 years\")", "```")
  expect_numerals(doc, "3", ctx = "caption")
  doc2 <- c("```{r, eval=FALSE, fig.cap=\"At 8 sites\"}", "x <- weft_str(\"over 5 years\")", "```")
  expect_numerals(doc2, "8", ctx = "caption")
})

test_that("3b L19: fenced blocks and indented code are not prose", {
  expect_numerals(c("Intro words.", "", "```text", "over 5 years", "```", "", "after"), character())
  expect_numerals(c("Intro words.", "", "~~~", "over 5 years", "~~~"), character())
  expect_numerals(c("Intro words.", "", "    x = 12", "    y = 13", "", "after"), character())
  expect_numerals(c("Intro words.", "", "```{=html}", "<p>12</p>", "```"), character())
  # indented text inside a list item is a continuation, so prose
  expect_numerals(c("- item one", "", "    more about 12 sites"), "12")
})

# ---- word and numeral forms -------------------------------------------------------------------

test_that("3b L19: where a numeral's text starts and ends", {
  rows <- list(
    c("-3", "-3"), c("+3", "+3"), c("\u00b10.5", "\u00b10.5"), c("\u22123", "\u22123"),
    c("10x", "10x"), c("45\u2030", "45\u2030"), c("20\u00b0C", "20\u00b0C"),
    c("1,000", "1,000"), c("(12)", "12"), c("12th", "12th"), c("3-5", "3-5"),
    c("3\u20135", "3\u20135"), c("45%,", "45%"), c("0.5.", "0.5"), c("\"12\"", "12"))
  for (r in rows) {
    expect_numerals(paste("The value", r[[1]], "was kept"), r[[2]])
  }
})

test_that("3b L19: words are split at = < > and the comparison signs (K4)", {
  expect_numerals("Here n=12 and p<0.05 and a>3 were set.", c("12", "0.05", "3"))
  expect_numerals("Here n\u22645 and m\u22656 and k\u22487 and j\u22608 held.", c("5", "6", "7", "8"))
})

test_that("3b L19: sentence starts, block quotes and bullet lists", {
  expect_numerals("12 sites were dry.", "12")
  expect_numerals(c("Intro words.", "", "> 5 sites"), "5")
  expect_numerals(c("Intro words.", "", "* 5 sites", "+ 6 sites"), c("5", "6"))
  expect_numerals(c("Intro words.", "", "- [ ] 5 sites"), "5")
})

test_that("3b L19: years under numeral_years: four digits from 1000 to 2999 only", {
  yml <- "numeral_years: true"
  expect_numerals("It ended in 2020.", character(), weft_yml = yml)
  expect_numerals("From 1000 to 2999 it held.", character(), weft_yml = yml)
  expect_numerals("It ended in 3000.", "3000", weft_yml = yml)
  expect_numerals("It ended in 999.", "999", weft_yml = yml)
  expect_numerals("It ended in 12345.", "12345", weft_yml = yml)
  expect_numerals("It ended in 2020 with 5 sites.", "5", weft_yml = yml)
  expect_numerals("It ended in 2020.", "2020", weft_yml = "numeral_years: false")
  expect_numerals("It ended in 2020.", "2020")
})

test_that("3b L19: numeral_years in front matter wins over _weft.yml", {
  doc <- c("---", "title: T", "weft:", "  numeral_years: true", "---", "", "It ended in 2020.")
  for (e in c("qmd", "Rmd")) {
    expect_identical(nrow(lint_one(doc, rules = "numeral", ext = e, weft_yml = "numeral_years: false")), 0L)
  }
})

test_that("3b L19: a year in a heading under numeral_years is exempt, in a caption too", {
  yml <- "numeral_years: true"
  expect_numerals("## Results for 2020 {#sec-r}", character(), weft_yml = yml)
  expect_numerals(c("```{r, fig.cap=\"In 2019\"}", "plot(1)", "```"), character(), weft_yml = yml)
})

# ---- file layout does not move findings -----------------------------------------------------

test_that("3b L19: CRLF, a BOM and a missing final newline do not move a finding", {
  lines <- c("---", "title: T", "---", "", "We sampled 12 sites, 45% of them.", "", "- 7 more")
  plain <- lint_fixture(list("doc.qmd" = lines), rules = "numeral")
  crlf <- lint_fixture(list("doc.qmd" = list(lines = lines, eol = "\r\n")), rules = "numeral")
  bom <- lint_fixture(list("doc.qmd" = list(lines = lines, bom = TRUE)), rules = "numeral")
  nofinal <- lint_fixture(list("doc.qmd" = list(lines = lines, final_newline = FALSE)), rules = "numeral")
  expect_identical(plain$text, c("12", "45%", "7"))
  for (v in list(crlf, bom, nofinal)) {
    expect_identical(v$text, plain$text)
    expect_identical(v$line, plain$line)
    expect_identical(v$col, plain$col)
  }
})

test_that("3b L19: a repeated line and a line equal to code in a chunk above keep their own positions", {
  lines <- c("```{r}", "x <- 12", "```", "", "x <- 12", "", "We saw 12 sites.", "We saw 12 sites.")
  x <- lint_one(lines, rules = "numeral")
  expect_identical(x$text, c("12", "12", "12"))
  expect_identical(x$line, c(5L, 7L, 8L))
  expect_identical(x$col, c(6L, 8L, 8L))
})

test_that("3b L19: numerals in a longer document are found at their lines", {
  doc <- c(n3_filler(3), "", "We sampled 12 sites.", "", n3_filler(2), "", "In 45% of cases.")
  x <- lint_one(doc, rules = "numeral")
  expect_identical(x$text, c("12", "45%"))
  expect_identical(x$line, c(5L, 10L))
  expect_identical(x$col, c(12L, 4L))
})

# ---- the file set -----------------------------------------------------------------------------

test_that("3b L19: a numeral is reported for each file, with paths relative to the root", {
  x <- lint_fixture(list("a.qmd" = "There were 12 sites.", "sub/b.Rmd" = "There were 7 sites."),
                    rules = "numeral")
  expect_identical(x$file, c("a.qmd", "sub/b.Rmd"))
  expect_identical(x$text, c("12", "7"))
})

test_that("3b L19: findings are tier 1, so the default tier lists them", {
  root <- lint_proj(list("a.qmd" = "There were 12 sites."))
  x <- lints(root, rules = "numeral")
  expect_identical(x$text, "12")
  expect_true(all(x$tier == 1L))
})
