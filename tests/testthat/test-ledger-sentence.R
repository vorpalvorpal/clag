# Package 2d, D12 under the ruling that ICU (stringi) splits running prose into sentences:
# boundaries of stringi::stri_locate_all_boundaries(type = "sentence", locale = "<lang>@ss=standard"),
# plus one rule: a boundary is dropped when the next sentence starts with a lower-case letter or a digit.
# Written before the code. Non-ASCII is written as \uXXXX. Made-up values only.
if (!exists("d2_render")) source(Filter(file.exists, c(testthat::test_path("helper-2d.R"), testthat::test_path("..", "helper-2d.R")))[[1]])
d2_need()

d2s_en <- function() d2_memo("sent-en", function() {
  doc <- c(
    "Intro sentence. For example, e.g. `r a1` sites were dry.", "",
    "Intro sentence. The mean was `r b1`, below the limit.", "",
    "Intro sentence. Mr. Smith had `r c1`.", "",
    "Intro sentence. It rose (approx. `r d1` mm) in Jan. 2024.", "",
    "Intro sentence. Smith et al. found `r e1` sites.", "",
    "Intro sentence. See Fig. 3 for `r f1` details.", "",
    "Was it dry? Yes `r g1`! Then `r g2`.", "",
    "He said \"stop.\" Then `r h1` left.", "",
    "The reading at site No. 4 was `r i1`.", "",
    "Intro sentence. Mr. Smith saw `r j1` and `r j2` sites.", "",
    "It ended. so `r k1` more.", "",
    "Value `r l1` fell approx. 4 mm today.")
  vars <- c("a1","b1","c1","d1","e1","f1","g1","g2","h1","i1","j1","j2","k1","l1")
  d2_render(doc, code = paste0(vars, " <- ", seq_along(vars), collapse = "; "))
})

d2s_sentence <- function(res, expr) d2_one(d2_ledger(res), expr = expr)$sentence

test_that("2d D12 (stringi): an abbreviation ICU knows does not end a sentence (e.g., Mr., approx., et al., Fig.)", {
  res <- d2s_en()
  s <- function(x) d2s_sentence(res, x)
  expect_identical(s("a1"), "For example, e.g. 1 sites were dry.")
  expect_identical(s("c1"), "Mr. Smith had 3.")
  expect_identical(s("d1"), "It rose (approx. 4 mm) in Jan. 2024.")
  expect_identical(s("e1"), "Smith et al. found 5 sites.")
  expect_identical(s("f1"), "See Fig. 3 for 6 details.")
})

test_that("2d D12 (stringi): control - an ordinary sentence, and `?` and `!`, still bound a sentence", {
  res <- d2s_en()
  expect_identical(d2s_sentence(res, "b1"), "The mean was 2, below the limit.")
  expect_identical(d2s_sentence(res, "g1"), "Yes 7!")
  expect_identical(d2s_sentence(res, "g2"), "Then 8.")
})

test_that("2d D12 (stringi): a full stop inside a closing quotation mark ends the sentence", {
  expect_identical(d2s_sentence(d2s_en(), "h1"), "Then 9 left.")
})

test_that("2d D12 (stringi): a boundary before a lower-case letter or a digit is dropped", {
  res <- d2s_en()
  expect_identical(d2s_sentence(res, "i1"), "The reading at site No. 4 was 10.")
  expect_identical(d2s_sentence(res, "k1"), "It ended. so 13 more.")
  expect_identical(d2s_sentence(res, "l1"), "Value 14 fell approx. 4 mm today.")
})

test_that("2d D12 (stringi): two values in one sentence carry the identical sentence", {
  res <- d2s_en()
  expect_identical(d2s_sentence(res, "j1"), "Mr. Smith saw 11 and 12 sites.")
  expect_identical(d2s_sentence(res, "j2"), "Mr. Smith saw 11 and 12 sites.")
})

d2s_fr_doc <- c(
  "Intro. M. Dupont a vu `r n1` sites.", "",
  "Intro. Il a mesuré (env. `r n2` mm) hier.", "",
  "Intro. Voir p. ex. la fig. `r n3`.")
d2s_fr_vars <- "n1 <- 1; n2 <- 2; n3 <- 3"

test_that("2d D12 (stringi): with `lang: fr` the French abbreviations do not end a sentence", {
  res <- d2_render(d2s_fr_doc, front = "lang: fr", code = d2s_fr_vars)
  expect_identical(d2s_sentence(res, "n1"), "M. Dupont a vu 1 sites.")
  expect_identical(d2s_sentence(res, "n2"), "Il a mesuré (env. 2 mm) hier.")
  expect_identical(d2s_sentence(res, "n3"), "Voir p. ex. la fig. 3.")
})

test_that("2d D12 (stringi): the same French text under `lang: en` splits after `M.`, so the locale is passed", {
  for (front in list("lang: en", NULL)) {
    res <- d2_render(d2s_fr_doc, front = front, code = d2s_fr_vars)
    expect_identical(d2s_sentence(res, "n1"), "Dupont a vu 1 sites.")
  }
})

test_that("2d D12 (stringi): a regional `lang` (en-AU) works and keeps English abbreviations", {
  res <- d2_render(c("Intro sentence. Mr. Smith had `r a`.", "", "Intro sentence. Then `r b` ends."),
                   front = "lang: en-AU", code = "a <- 1; b <- 2")
  expect_identical(d2s_sentence(res, "a"), "Mr. Smith had 1.")
  expect_identical(d2s_sentence(res, "b"), "Then 2 ends.")
})

test_that("2d D12 (stringi): an unknown `lang` does not fail the render and still splits at plain full stops", {
  res <- d2_render(c("Intro sentence. Then `r a` ends. Last one."), front = "lang: xx", code = "a <- 1")
  expect_identical(d2s_sentence(res, "a"), "Then 1 ends.")
})

test_that("2d D12 (stringi): a table cell, a caption and a front-matter field are still one sentence each", {
  res <- d2_render(c("| Name | Depth |", "|------|-------|", "| one | Mr. Depth `r tc`. Next. |"), code = "tc <- 3")
  expect_identical(d2s_sentence(res, "tc"), "Mr. Depth 3. Next.")
})

test_that("2d D30 (stringi): stringi is in Imports", {
  d <- read.dcf(system.file("DESCRIPTION", package = "weft"), fields = "Imports")
  expect_true(grepl("\\bstringi\\b", d[1, "Imports"]))
})

# ---- the supplementary abbreviations (ICU alone splits before a capitalised word) -----------------

d2s_supp <- function() d2_memo("sent-supp", function() {
  doc <- c(
    "Intro sentence. See Fig. A for `r s1`.", "",
    "Intro sentence. Sites were wet, e.g. Wombat Creek had `r s2`.", "",
    "Intro sentence. It covered approx. Half of the `r s3` sites.", "",
    "Intro sentence. Dr. Wombat saw `r s4`.", "",
    "Intro sentence. St. Kilda had `r s5`.", "",
    "Intro sentence. The count was low, cf. Table 2, with `r s6` sites.", "",
    "We counted frogs, fish, etc. Then `r s7` more.")
  d2_render(doc, code = paste0("s", 1:7, " <- ", 1:7, collapse = "; "))
})

test_that("2d D12 (stringi): a supplementary abbreviation before a capitalised word does not end a sentence (and `Fig.` does)", {
  res <- d2s_supp()
  s <- function(x) d2s_sentence(res, x)
  expect_identical(s("s1"), "A for 1.")   # `Fig.` is not in weft's list (decision 57): ICU's split stands
  expect_identical(s("s2"), "Sites were wet, e.g. Wombat Creek had 2.")
  expect_identical(s("s3"), "It covered approx. Half of the 3 sites.")
  expect_identical(s("s4"), "Dr. Wombat saw 4.")
  expect_identical(s("s5"), "St. Kilda had 5.")
  expect_identical(s("s6"), "The count was low, cf. Table 2, with 6 sites.")
})

test_that("2d D12 (stringi): `etc.` is not an abbreviation of the list, so it ends a sentence before a capital", {
  expect_identical(d2s_sentence(d2s_supp(), "s7"), "Then 7 more.")
})

test_that("2d D12 (stringi): under `lang: fr` the English-only abbreviations (Dr., No.) are not applied, the any-language ones are", {
  doc <- c("Intro. Voir No. Wombat pour `r f1`.", "", "Intro. Le Dr. Wombat a vu `r f2`.", "",
           "Intro. Voir cf. Tableau 2 avec `r f3`.")
  res <- d2_render(doc, front = "lang: fr", code = "f1 <- 1; f2 <- 2; f3 <- 3")
  expect_identical(d2s_sentence(res, "f1"), "Wombat pour 1.")
  expect_identical(d2s_sentence(res, "f2"), "Wombat a vu 2.")
  expect_identical(d2s_sentence(res, "f3"), "Voir cf. Tableau 2 avec 3.")
})

test_that("2d D12 (stringi): the English-only abbreviations apply under `lang: en-AU` too", {
  res <- d2_render(c("Intro sentence. Dr. Wombat saw `r a`."), front = "lang: en-AU", code = "a <- 1")
  expect_identical(d2s_sentence(res, "a"), "Dr. Wombat saw 1.")
})

# ---- masking of markdown and Quarto syntax (decision 57), initials, block markers -------------------

d2s_mask <- function() d2_memo("sent-mask", function() {
  doc <- c(
    "Intro sentence. The call `x.y(). Z` gave `r m1`.", "",
    "Intro sentence. And $p < 0.05. Q$ held for `r m2`.", "",
    "Intro sentence. A [link. Text](http://a.b/c. D) had `r m3`.", "",
    "Intro sentence. A note^[First part. Second part.] had `r m4`.", "",
    "Intro sentence. A note^[First part. Second `r m5` part.] here.", "",
    "Intro sentence. Next [span. Text]{.x key=\"A. B\"} was `r m6`.", "",
    "Intro sentence. A <span title=\"a. B\">tag</span> had `r m7`.", "",
    "Intro sentence. Rain fell [@smith2020, p. 4; @jones.lee2021]. Then `r m8` more.", "",
    "Intro sentence. As in @tbl-a.b the count was `r m9`.", "",
    "**Note.** The value was `r m10`.", "",
    "*All sites were dry.* Then `r m11` more.", "",
    "Intro sentence. The pH was 7.2.[^1] Then `r m12`.", "",
    "Intro sentence. Counts by J. R. Smith were `r m13`.", "",
    "Intro sentence. E. Coli was `r m14`.", "",
    "1. Wombats were `r m15`.", "",
    "> Koalas were `r m16`.", "",
    "[^1]: A footnote text.")
  vars <- paste0("m", 1:16)
  d2_render(doc, code = paste0(vars, " <- ", 1:16, collapse = "; "))
})

d2s_cases <- list(
  m1  = "The call `x.y(). Z` gave 1.",
  m2  = "And $p < 0.05. Q$ held for 2.",
  m3  = "A [link. Text](http://a.b/c. D) had 3.",
  m4  = "A note^[First part. Second part.] had 4.",
  m5  = "Second 5 part.",
  m6  = "Next [span. Text]{.x key=\"A. B\"} was 6.",
  m7  = "A <span title=\"a. B\">tag</span> had 7.",
  m8  = "Then 8 more.",
  m9  = "As in @tbl-a.b the count was 9.",
  m10 = "The value was 10.",
  m11 = "Then 11 more.",
  m12 = "Then 12.",
  m13 = "Counts by J. R. Smith were 13.",
  m14 = "E. Coli was 14.",
  m15 = "Wombats were 15.",
  m16 = "Koalas were 16.")

for (nm in names(d2s_cases)) local({
  nm <- nm
  want <- d2s_cases[[nm]]
  why <- c(m1 = "inline code", m2 = "inline math", m3 = "a link's text and target", m4 = "an inline footnote before the value",
           m5 = "a value inside an inline footnote (the footnote's own sentence)", m6 = "a span with an attribute block",
           m7 = "a raw HTML tag", m8 = "a citation with a locator and a key holding a full stop",
           m9 = "a cross-reference", m10 = "strong emphasis ends before the sentence", m11 = "an emphasised sentence before the value",
           m12 = "a footnote reference after the full stop", m13 = "initials (J. R. Smith)", m14 = "an initial (E. Coli)",
           m15 = "an ordered-list marker is not part of the sentence", m16 = "a block-quote marker is not part of the sentence")[[nm]]
  test_that(paste0("2d D12 (stringi): masking - ", why), {
    expect_identical(d2s_sentence(d2s_mask(), nm), want)
  })
})

test_that("2d D12 (stringi): a lower-case letter after initials needs no rule of its own (E. coli)", {
  res <- d2_render("Intro sentence. E. coli was `r a`.", code = "a <- 1")
  expect_identical(d2s_sentence(res, "a"), "E. coli was 1.")
})
