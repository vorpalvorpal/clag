# Package 3b: the `claim-word` lint (L20, rule 5.5) and `long-guard` (L21, rule 3.1.9).
# Contract: dev/design-3.md. Both are tier 2, so every test asks for tier 1:2 (lint_one()'s default).
# ASCII only.

cw <- function(lines, ext = "qmd", weft_yml = NULL, env = parent.frame()) {
  lint_one(lines, rules = "claim-word", ext = ext, weft_yml = weft_yml, env = env)
}

# ---- the finding ------------------------------------------------------------------------------

test_that("3b L20: a sentence with a value and claim words, the whole finding", {
  lines <- c("Intro words.", "", "All `r n` sites rose.")
  for (e in c("qmd", "Rmd")) {
    x <- cw(lines, e)
    expect_findings_shape(x)
    expect_identical(nrow(x), 1L)
    expect_identical(x$rule, "claim-word")
    expect_identical(x$tier, 2L)
    expect_identical(x$spec, "5.5.1")
    expect_identical(x$context, "prose")
    expect_identical(x$text, "all, rose")
    expect_identical(x$line, 3L)
    expect_identical(x$col, 1L)
    expect_identical(x$end_line, 3L)
    expect_identical(x$sentence, "All `r n` sites rose.")
    expect_match(x$message, "in a sentence with a value; check that the value still bears it out",
                 fixed = TRUE)
    expect_match(x$message, "\"all\"", fixed = TRUE)
    expect_match(x$message, "\"rose\"", fixed = TRUE)
    expect_match(x$message, "(rule 5.5.1).", fixed = TRUE)
  }
})

test_that("3b L20: one claim word with a value gives the singular message of the design", {
  x <- cw("All `r n` sites were wet.")
  expect_identical(x$text, "all")
  expect_identical(x$message,
    paste0("Claim word \"all\" in a sentence with a value; check that the value still bears it out, ",
           "or guard the word with an `if` span (rule 5.5.1)."))
})

test_that("3b L20: claim words and no value give the other message", {
  x <- cw("The largest site rose.")
  expect_identical(nrow(x), 1L)
  expect_identical(x$text, "largest, rose")
  expect_match(x$message, "in a sentence with no value: if it states a result, compute it", fixed = TRUE)
  expect_match(x$message, "Claim words \"largest\", \"rose\"", fixed = TRUE)
  expect_match(x$message, "(rule 5.5.1).", fixed = TRUE)
  expect_identical(x$sentence, "The largest site rose.")
})

test_that("3b L20: tier 2 means the default tier of lints() does not list it", {
  root <- lint_proj(list("a.qmd" = "All sites rose."))
  expect_identical(nrow(lints(root, rules = "claim-word")), 0L)
  expect_identical(lints(root, rules = "claim-word", tier = 2)$text, "all, rose")
  expect_identical(lints(root, rules = "claim-word", tier = 1:2)$text, "all, rose")
})

test_that("3b L20: a sentence with no claim word gives nothing", {
  expect_identical(nrow(cw("The water was clear at `r n` sites.")), 0L)
  expect_identical(nrow(cw("Blue water, a clear ratio and some alleys.")), 0L)
})

# ---- the lexicon -------------------------------------------------------------------------------

claim_paras <- function(words) {
  unlist(lapply(words, function(w) c(paste("Blue", w, "items."), "")))[-(2 * length(words))]
}

test_that("3b L20/L8a: number words are claim words", {
  words <- c("zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
             "eleven", "twelve", "first", "second", "third")
  x <- cw(claim_paras(words))
  expect_identical(x$text, words)
  expect_identical(x$line, seq(1L, by = 2L, length.out = length(words)))
  expect_identical(x$col, rep(6L, length(words)))
})

test_that("3b L20/L8a: quantifier, extremum and direction words are claim words", {
  words <- c("all", "none", "only", "majority", "always", "never", "whole", "entire", "single",
             "sole", "solely", "largest", "fewest", "top", "rose", "exceed", "exceeding",
             "surpassed", "decline", "declines", "declining", "grow", "grows", "growing", "drop",
             "drops", "dropping", "reduced", "significant", "significantly")
  for (e in c("qmd", "Rmd")) {
    x <- cw(claim_paras(words), e)
    expect_identical(x$text, words)
  }
})

test_that("3b L20: claim words are matched as lower-cased letter runs, so case and hyphens do not matter", {
  expect_identical(cw("ALL sites were wet.")$text, "all")
  expect_identical(cw("All-weather sites were wet.")$text, "all")
  expect_identical(cw("The (largest) site, well-known.")$text, "largest")
  expect_identical(cw("Wet sites, wet sites, all wet, all sites.")$text, "all")
})

test_that("3b L20: a claim word is a whole letter run, not part of one", {
  expect_identical(nrow(cw("Someone saw a stone and an alley near the bone yard.")), 0L)
  expect_identical(nrow(cw("Tally and shallow and ballast.")), 0L)
})

test_that("3b L20: words in the order of the sentence, each once", {
  x <- cw("Only the largest site rose, and only the largest rose again.")
  expect_identical(x$text, "only, largest, rose")
})

# ---- guards -----------------------------------------------------------------------------------

test_that("3b L20: an if span guards the claim words inside it", {
  for (e in c("qmd", "Rmd")) {
    x <- cw("[All]{if=\"all(up)\"} sites rose.", e)
    expect_identical(x$text, "rose")
    expect_identical(nrow(cw("[All sites]{if=\"all(up)\"} were wet.", e)), 0L)
    expect_identical(nrow(cw("The [largest | smallest]{if=\"ok\"} site was wet.", e)), 0L)
  }
})

test_that("3b L20: a sign span guards the claim words inside it", {
  expect_identical(nrow(cw("The ratio [rose | fell]{sign=\"d\"} again.")), 0L)
  x <- cw("The ratio [rose | fell]{sign=\"d\"} and the largest drops.")
  expect_identical(x$text, "largest, drops")
})

test_that("3b L20: an n span does not guard", {
  for (e in c("qmd", "Rmd")) {
    x <- cw("[a site | # sites]{n=\"k\"}, all dry", e)
    expect_identical(x$text, "all")
    expect_match(x$message, "with a value", fixed = TRUE)
    x2 <- cw("[all site | all sites]{n=\"k\"} were wet.", e)
    expect_identical(x2$text, "all")
  }
})

test_that("3b L20: a guard is not a value, so a sentence with only an if span has no value", {
  x <- cw("[All]{if=\"all(up)\"} sites rose.")
  expect_match(x$message, "with no value", fixed = TRUE)
  x <- cw("[10 m]{cite=\"smith2020\"} showed the largest.")
  expect_match(x$message, "with no value", fixed = TRUE)
})

test_that("3b L20: a value, a bare value, an n, a sign or a list in the sentence is a value", {
  rows <- c("All `r n`{.num} sites rose.", "All `r n` sites rose.",
            "All [site | sites]{n=\"k\"} rose.", "All [x | y]{list=\"ks\"} rose.",
            "All sites [rose | fell]{sign=\"d\"} and the largest drops.")
  for (r in rows) {
    x <- cw(r)
    expect_identical(nrow(x), 1L, info = r)
    expect_match(x$message, "with a value", fixed = TRUE, info = r)
  }
})

test_that("3b L20: a value in another sentence does not count", {
  x <- cw("`r n` sites were visited. All were wet.")
  expect_identical(nrow(x), 1L)
  expect_identical(x$text, "all")
  expect_match(x$message, "with no value", fixed = TRUE)
  expect_identical(x$sentence, "All were wet.")
})

# ---- what is read ------------------------------------------------------------------------------

test_that("3b L20: a claim word in a code span, math, a link target, an attribute block or a URL is not read", {
  rows <- c("The `all` column was wet.", "The $all + only$ term was wet.",
            "See [the page](https://all.example.org/only) now.",
            "Wet [sites]{if=\"all(up) & never\"} here.", "See https://top.example.org now.",
            "Wet sites <!-- all rose --> here.")
  for (r in rows) expect_identical(nrow(cw(r)), 0L, info = r)
})

test_that("3b L20: link text, image alt text, headings, list items, quotes and table cells are read", {
  expect_identical(cw("See [all sites](u.html) now.")$text, "all")
  expect_identical(cw("![All sites](m.png)")$text, "all")
  expect_identical(cw("## Largest sites {#sec-l}")$text, "largest")
  expect_identical(cw(c("Intro words.", "", "- All wet"))$text, "all")
  expect_identical(cw(c("Intro words.", "", "> Only wet"))$text, "only")
  expect_identical(cw(c("| Site | Note |", "|---|---|", "| A | all wet |"))$text, "all")
})

test_that("3b L20: a .weft-literal span exempts numerals only, so its claim words are still read", {
  x <- cw("[All sites rose]{.weft-literal why=\"quoted\"} yesterday.")
  expect_identical(x$text, "all, rose")
})

test_that("3b L20: captions, alt text, front matter and weft_str() strings are read; phrases are not", {
  chunk <- function(...) c("```{r}", ..., "plot(1)", "```")
  x <- cw(chunk("#| fig-cap: \"All sites rose\""))
  expect_identical(x$text, "all, rose")
  expect_identical(x$context, "caption")
  expect_identical(x$line, 2L)
  x <- cw(chunk("#| fig-alt: The largest site"))
  expect_identical(x$context, "caption")
  expect_identical(x$text, "largest")
  x <- cw(c("---", "title: \"The largest site\"", "---", "", "Plain words."))
  expect_identical(x$text, "largest")
  expect_identical(x$context, "front-matter")
  expect_identical(x$line, 2L)
  x <- cw(c("---", "title: T", "abstract: |", "  Over the", "  years all rose.", "---", "", "Plain."))
  expect_identical(x$text, "all, rose")
  expect_identical(x$context, "front-matter")
  expect_identical(x$line, 5L)
  x <- cw(c("```{r}", "x <- weft_str(\"all sites rose: `r x`{.num}\")", "```"))
  expect_identical(x$text, "all, rose")
  expect_identical(x$context, "weft_str")
  # phrases: the call that chooses the phrase is the guard (5.1.6)
  expect_identical(nrow(cw(c("```{r}", "y <- brk(. > 2 ~ \"all dry\")", "```"))), 0L)
  expect_identical(nrow(cw(c("```{r}", "z <- lookup(c(a = \"largest and rose\"))", "```"))), 0L)
})

test_that("3b L20: strings and captions of an eval: false chunk follow reading 14 of the design", {
  doc <- c("```{r}", "#| eval: false", "#| fig-cap: \"All sites rose\"",
           "x <- weft_str(\"the largest dropped\")", "```")
  x <- cw(doc)
  expect_identical(x$text, "all, rose")
  expect_identical(x$context, "caption")
})

# ---- sentences and positions -------------------------------------------------------------------

test_that("3b L20: one finding per sentence, at its first claim word", {
  lines <- c("Sites were counted. All sites rose. The water was clear. Two sites rose.")
  for (e in c("qmd", "Rmd")) {
    x <- cw(lines, e)
    expect_identical(x$text, c("all, rose", "two, rose"))
    expect_identical(x$sentence, c("All sites rose.", "Two sites rose."))
    expect_identical(x$line, c(1L, 1L))
    expect_identical(x$col, c(as.integer(f3_pos(lines, "All")[["col"]]),
                              as.integer(f3_pos(lines, "Two")[["col"]])))
  }
})

test_that("3b L20: a sentence over two lines has line and end_line, and a collapsed sentence", {
  lines <- c("Intro words.", "", "The largest site", "rose by a lot.")
  x <- cw(lines)
  expect_identical(x$text, "largest, rose")
  expect_identical(x$line, 3L)
  expect_identical(x$end_line, 4L)
  expect_identical(x$col, 5L)
  expect_identical(x$sentence, "The largest site rose by a lot.")
})

test_that("3b L20: the finding starts at the first claim word, not the sentence start", {
  lines <- c("Intro words.", "", "The water was clear but the largest site rose.")
  x <- cw(lines)
  expect_identical(x$line, 3L)
  expect_identical(x$col, as.integer(f3_pos(lines, "largest")[["col"]]))
})

test_that("3b L20: the same sentence in two paragraphs is two findings", {
  x <- cw(c("All sites rose.", "", "All sites rose."))
  expect_identical(x$line, c(1L, 3L))
})

test_that("3b L20: CRLF and a BOM do not move a finding", {
  lines <- c("---", "title: T", "---", "", "Wet words.", "", "The largest site rose.")
  plain <- lint_fixture(list("doc.qmd" = lines), rules = "claim-word")
  crlf <- lint_fixture(list("doc.qmd" = list(lines = lines, eol = "\r\n", bom = TRUE)), rules = "claim-word")
  expect_identical(plain$line, 7L)
  expect_identical(crlf$line, plain$line)
  expect_identical(crlf$col, plain$col)
  expect_identical(crlf$sentence, plain$sentence)
})

# ---- lang ----------------------------------------------------------------------------------------

test_that("3b L20: the shipped lexicon is English: lang de gives no finding", {
  for (e in c("qmd", "Rmd")) {
    expect_identical(nrow(cw(c("---", "title: T", "lang: de", "---", "", "The ratio rose."), e)), 0L)
    expect_identical(nrow(cw(c("---", "title: T", "lang: fr", "---", "", "All sites rose."), e)), 0L)
    expect_identical(cw(c("---", "title: T", "lang: en-AU", "---", "", "All sites rose."), e)$text, "all, rose")
    expect_identical(cw(c("---", "title: T", "lang: EN", "---", "", "All sites rose."), e)$text, "all, rose")
    expect_identical(cw(c("---", "title: T", "lang: en", "---", "", "All sites rose."), e)$text, "all, rose")
    expect_identical(cw(c("---", "title: T", "---", "", "All sites rose."), e)$text, "all, rose")
  }
  expect_identical(cw("The ratio rose.")$text, "rose")
})

test_that("3b L20: lang comes from _quarto.yml when the document has none", {
  x <- lint_fixture(list("_quarto.yml" = c("project:", "  type: default", "lang: de"),
                         "a.qmd" = "All sites rose."), rules = "claim-word")
  expect_identical(nrow(x), 0L)
  y <- lint_fixture(list("_quarto.yml" = c("project:", "  type: default", "lang: de"),
                         "a.qmd" = c("---", "title: T", "lang: en", "---", "", "All sites rose.")),
                    rules = "claim-word")
  expect_identical(y$text, "all, rose")
})

# ---- claim_words: add and drop -----------------------------------------------------------------

test_that("3b L20: claim_words add makes a word a claim word", {
  yml <- c("claim_words:", "  add: [ratio]")
  for (e in c("qmd", "Rmd")) {
    x <- cw("The ratio was clear.", e, weft_yml = yml)
    expect_identical(x$text, "ratio")
    expect_identical(nrow(cw("The ratio was clear.", e)), 0L)
  }
})

test_that("3b L20: claim_words drop removes a word from the lexicon", {
  yml <- c("claim_words:", "  drop: [rose]")
  x <- cw("All sites rose.", weft_yml = yml)
  expect_identical(x$text, "all")
  expect_identical(nrow(cw("The sites rose.", weft_yml = yml)), 0L)
})

test_that("3b L20: a word both added and dropped is dropped; add reaches a language with no shipped words", {
  expect_identical(nrow(cw("The ratio was clear.", weft_yml = c("claim_words:", "  add: [ratio]", "  drop: [ratio]"))), 0L)
  doc <- c("---", "title: T", "lang: de", "---", "", "The ratio rose.")
  x <- cw(doc, weft_yml = c("claim_words:", "  add: [ratio]"))
  expect_identical(x$text, "ratio")
})

test_that("3b L20: claim_words in front matter is honoured", {
  doc <- c("---", "title: T", "weft:", "  claim_words:", "    add: [ratio]", "    drop: [rose]",
           "---", "", "The ratio rose.")
  for (e in c("qmd", "Rmd")) expect_identical(cw(doc, e)$text, "ratio")
})

test_that("3b L20: claim_cap limits changes(), not lints(): every sentence is listed", {
  doc <- c("All sites rose.", "", "All sites fell.", "", "All sites dropped.")
  x <- cw(doc, weft_yml = "claim_cap: 1")
  expect_identical(nrow(x), 3L)
})

# ---- long-guard (L21) ---------------------------------------------------------------------------

dry <- function(n) paste(rep("dry", n), collapse = " ")
lg <- function(lines, ext = "qmd", weft_yml = NULL, env = parent.frame()) {
  lint_one(lines, rules = "long-guard", ext = ext, weft_yml = weft_yml, env = env)
}

test_that("3b L21: an arm of more than 25 words is listed, at 25 it is not", {
  for (e in c("qmd", "Rmd")) {
    expect_identical(nrow(lg(sprintf("[%s]{if=\"ok\"}", dry(24)), e)), 0L)
    expect_identical(nrow(lg(sprintf("[%s]{if=\"ok\"}", dry(25)), e)), 0L)
    x <- lg(sprintf("[%s]{if=\"ok\"}", dry(26)), e)
    expect_findings_shape(x)
    expect_identical(nrow(x), 1L)
    expect_identical(x$rule, "long-guard")
    expect_identical(x$tier, 2L)
    expect_identical(x$spec, "3.1.9")
    expect_identical(x$text, "ok")
    expect_identical(x$line, 1L)
    expect_identical(x$context, "prose")
    expect_identical(x$message,
      paste0("A guarded bracket of 26 words: one condition guards all of it; guard only the words ",
             "it decides, and nest what is computed (rule 3.1.9)."))
  }
})

test_that("3b L21: the longest arm counts, not the sum (K19)", {
  doc <- sprintf("[%s | %s]{if=\"ok\"}", dry(10), dry(30))
  x <- lg(doc)
  expect_identical(nrow(x), 1L)
  expect_match(x$message, "A guarded bracket of 30 words", fixed = TRUE)
  expect_identical(nrow(lg(doc, weft_yml = "guard_words: 35")), 0L)
  expect_identical(nrow(lg(sprintf("[%s | %s]{if=\"ok\"}", dry(20), dry(20)))), 0L)
})

test_that("3b L21: each nested value or bare value counts as one word", {
  one <- sprintf("[%s `r x`]{if=\"ok\"}", dry(24))
  expect_identical(nrow(lg(one)), 0L)
  two <- sprintf("[%s `r x` `r y`{.num}]{if=\"ok\"}", dry(24))
  x <- lg(two)
  expect_identical(nrow(x), 1L)
  expect_match(x$message, "A guarded bracket of 26 words", fixed = TRUE)
})

test_that("3b L21: guard_words sets the limit, from _weft.yml and from front matter", {
  expect_identical(nrow(lg(sprintf("[%s]{if=\"ok\"}", dry(5)), weft_yml = "guard_words: 5")), 0L)
  expect_identical(nrow(lg(sprintf("[%s]{if=\"ok\"}", dry(6)), weft_yml = "guard_words: 5")), 1L)
  doc <- c("---", "title: T", "weft:", "  guard_words: 3", "---", "", sprintf("[%s]{if=\"ok\"}", dry(4)))
  for (e in c("qmd", "Rmd")) {
    expect_identical(nrow(lg(doc, e, weft_yml = "guard_words: 25")), 1L)
  }
})

test_that("3b L21: only an if span is a guard", {
  expect_identical(nrow(lg(sprintf("[%s]{n=\"k\"}", dry(40)))), 0L)
  expect_identical(nrow(lg(sprintf("[%s]{.strong}", dry(40)))), 0L)
  expect_identical(nrow(lg(sprintf("[%s | %s]{sign=\"d\"}", dry(40), dry(40)))), 0L)
})

test_that("3b L21: words are those of the prose, so a code span or an attribute block adds none", {
  expect_identical(nrow(lg(sprintf("[%s `x[1] + y`]{if=\"ok\"}", dry(25)))), 0L)
  expect_identical(nrow(lg(sprintf("[%s [see](http://a.example.org/b/c/d)]{if=\"ok\"}", dry(23)))), 0L)
})

test_that("3b L21: the finding is at the line of the guarded bracket", {
  lines <- c("Intro words.", "", sprintf("Then [%s]{if=\"ok\"} follows.", dry(30)))
  x <- lg(lines)
  expect_identical(x$line, 3L)
  expect_identical(x$text, "ok")
})
