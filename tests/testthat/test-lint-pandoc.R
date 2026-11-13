# Package 3b: the Pandoc reader (L15, rules 2.10.3, 2.10.5; K1, K2; contract: dev/design-3.md).
# Every test that needs a Pandoc skips when none (version 3 or later) is found. The stub
# Pandoc of helper-3b.R logs calls and copies each input, so the masked read can be seen.
# ASCII only.

# ---- pandoc_path(): the order and the version ---------------------------------------------------

test_that("3b L15: pandoc_path() returns one string, empty when none is found", {
  if (!expect_built("pandoc_path")) return(invisible())
  p <- weft:::pandoc_path()
  expect_type(p, "character")
  expect_length(p, 1L)
  expect_false(is.na(p))
  if (nzchar(p)) expect_true(file.exists(p))
})

test_that("3b L15: the option weft.pandoc is looked at first, then WEFT_PANDOC", {
  n3_skip_no_pandoc()
  a <- n3_stub_pandoc()
  b <- n3_stub_pandoc()
  withr::local_options(weft.pandoc = a$path)
  withr::local_envvar(WEFT_PANDOC = b$path)
  expect_identical(normalizePath(weft:::pandoc_path()), normalizePath(a$path))
  withr::local_options(weft.pandoc = NULL)
  expect_identical(normalizePath(weft:::pandoc_path()), normalizePath(b$path))
})

test_that("3b L15: a Pandoc older than 3.0 is not accepted", {
  n3_skip_no_pandoc()
  old <- n3_stub_pandoc(version_line = "pandoc 2.19.2")
  withr::local_options(weft.pandoc = old$path)
  withr::local_envvar(WEFT_PANDOC = "")
  p <- weft:::pandoc_path()
  expect_false(identical(normalizePath(p, mustWork = FALSE), normalizePath(old$path)))
  ok <- n3_stub_pandoc(version_line = "pandoc 3.1.1")
  withr::local_options(weft.pandoc = ok$path)
  expect_identical(normalizePath(weft:::pandoc_path()), normalizePath(ok$path))
})

# ---- pinned: what Pandoc does -----------------------------------------------------------------

test_that("3b L15 pinned: +sourcepos puts data-pos on a Span round each word, in characters", {
  skip_if(!nzchar(n3_find_pandoc()), "no Pandoc 3 found")
  skip_if_not_installed("jsonlite")
  f <- withr::local_tempfile(fileext = ".md")
  writeBin(charToRaw("A caf\u00e9 of 4 sites.\n"), f)
  json <- system2(n3_find_pandoc(), c("-f", "commonmark_x+sourcepos", "-t", "json", shQuote(f)),
                  stdout = TRUE)
  txt <- paste(json, collapse = "")
  # the form: <file>@line:col-line:col, the end one past the last character
  expect_match(txt, "\"data-pos\",\"[^\"]*@1:3-1:7\"")
  expect_match(txt, "\"data-pos\",\"[^\"]*@1:11-1:12\"")
  expect_false(grepl("@1:3-1:8\"", txt, fixed = TRUE))
})

test_that("3b L15 pinned: columns count characters, not bytes, and start again on each line", {
  skip_if(!nzchar(n3_find_pandoc()), "no Pandoc 3 found")
  skip_if_not_installed("jsonlite")
  r <- n3_str_ranges("A caf\u00e9 of 4 sites.\nTwo 12 words\n")
  expect_true(any(r$start == 3L & r$end == 6L))
  expect_true(any(r$start == 11L & r$end == 11L))
  expect_true(any(r$start == 24L & r$end == 25L))
  r2 <- n3_str_ranges("x \u4e2d\u6587 y\n")
  expect_true(any(r2$start == 3L & r2$end == 4L))
  expect_true(any(r2$start == 6L & r2$end == 6L))
})

test_that("3b L15 pinned: masking a construct with a letter keeps a paragraph a paragraph, spaces do not", {
  skip_if(!nzchar(n3_find_pandoc()), "no Pandoc 3 found")
  skip_if_not_installed("jsonlite")
  src <- "[3 sites]{if=\"n > 2\"} remain wet.\n"
  by_letter <- "[3 sites]aaaaaaaaaaaa remain wet.\n"
  by_space <- "[3 sites]             remain wet.\n"
  expect_identical(n3_block_types(by_letter), "Para")
  expect_identical(n3_block_types(src), "Para")
  spaced <- "            [3 sites]{if=\"n > 2\"} remain wet.\n"
  expect_identical(n3_block_types(paste0("Intro.\n\n", spaced)), c("Para", "CodeBlock"))
  expect_identical(n3_block_types(by_space), "Para")
})

# ---- the masked read, through a stub Pandoc ----------------------------------------------------

test_that("3b L15: the masked read has every construct masked, front matter blank and no position moved", {
  n3_skip_no_pandoc()
  skip_if_not_installed("jsonlite")
  stub <- n3_stub_pandoc()
  withr::local_options(weft.pandoc = stub$path)
  doc <- c("---", "title: T", "---", "", "[3 sites]{if=\"n > 2\"} remain wet.", "",
           "Plain `r x`{.num} text.")
  x <- lint_one(doc, rules = "numeral", reader = "pandoc")
  expect_identical(x$text, "3")
  expect_gte(n3_stub_calls(stub), 1L)
  expect_lte(n3_stub_calls(stub), 2L)
  inputs <- n3_stub_inputs(stub)
  masked <- inputs[!grepl("{if=", inputs, fixed = TRUE)]
  unmasked <- inputs[grepl("{if=\"n > 2\"}", inputs, fixed = TRUE)]
  expect_length(masked, 1L)
  expect_length(unmasked, 1L)
  ml <- strsplit(masked, "\n", fixed = TRUE)[[1]]
  expect_identical(length(ml), length(doc))
  expect_identical(nchar(ml), nchar(doc))
  expect_true(all(grepl("^ *$", ml[1:3])), info = "front matter blanked to spaces")
  expect_match(ml[[5]], "^\\[3 sites\\][A-Za-z]{12} remain wet\\.$")
  expect_match(ml[[7]], "^Plain [A-Za-z]{11} text\\.$")
  expect_false(grepl("n > 2", masked, fixed = TRUE))
  expect_false(grepl("{.num}", masked, fixed = TRUE))
  # the masked tree holds the same block types as the unmasked one
  expect_identical(n3_block_types(masked), n3_block_types(unmasked))
})

test_that("3b L15: Pandoc is called at most twice per file, and never by the default reader", {
  n3_skip_no_pandoc()
  stub <- n3_stub_pandoc()
  withr::local_options(weft.pandoc = stub$path)
  files <- list("a.qmd" = c("We sampled 12 sites.", "", "[a site | # sites]{n=\"k\"}"),
                "b.qmd" = c("Plain words.", "", "More 7 words."))
  root <- lint_proj(files)
  lints(root, tier = 1:2)
  lints(root, tier = 1:2, reader = "weft")
  expect_identical(n3_stub_calls(stub), 0L)
  expect_identical(n3_stub_versions(stub), 0L)
  lints(root, tier = 1:2, reader = "pandoc")
  expect_gte(n3_stub_calls(stub), 1L)
  expect_lte(n3_stub_calls(stub), 4L)
  root1 <- lint_proj(list("a.qmd" = files[["a.qmd"]]))
  before <- n3_stub_calls(stub)
  lints(root1, tier = 1:2, reader = "pandoc")
  expect_lte(n3_stub_calls(stub) - before, 2L)
})

# ---- reader = "pandoc" is the intersection --------------------------------------------------------

test_that("3b L15: on ordinary prose the two readers give the same findings", {
  n3_skip_no_pandoc()
  doc <- c("---", "title: \"Survey 2020\"", "---", "",
           "We sampled 12 sites, 45% of them (n=12) in 3\u20135 m of water.", "",
           "an 11-year record; the 3rd survey; p<0.05.", "",
           "## 2. Methods {#sec-m}", "",
           "| Site | Depth |", "|---|---:|", "| Site A | 3.4 |", "",
           "See [@smith2020, p. 4] and @fig-3d and https://x.org/2020/a and `x[3]` here.", "",
           "Some text^[In 2019 only.] and &#8212; and \\vspace{2em} done.", "",
           "[3 sites]{if=\"n > 2\"} remain wet.", "",
           "```{r}", "#| fig-cap: \"Depth at 3 sites\"", "x <- weft_str(\"over 5 years\")", "```")
  for (e in c("qmd", "Rmd")) {
    w <- lint_one(doc, rules = c("numeral", "claim-word"), ext = e, reader = "weft")
    p <- lint_one(doc, rules = c("numeral", "claim-word"), ext = e, reader = "pandoc")
    expect_gt(nrow(w), 8L)
    expect_identical(p$text, w$text)
    expect_identical(p$line, w$line)
    expect_identical(p$col, w$col)
    expect_identical(p$context, w$context)
  }
})

test_that("3b L15: the pieces beside the body are judged by the R reader alone", {
  n3_skip_no_pandoc()
  doc <- c("---", "title: \"Survey 2020\"", "abstract: |", "  Over 4 sites.", "---", "",
           "```{r}", "#| fig-cap: \"Depth at 3 sites\"", "x <- weft_str(\"over 5 years\")",
           "y <- brk(. > 2 ~ \"more than 2 sites\")", "```")
  x <- lint_one(doc, rules = "numeral", reader = "pandoc")
  expect_identical(x$text, c("2020", "4", "3", "5", "2"))
  expect_identical(x$context, c("front-matter", "front-matter", "caption", "weft_str", "phrase"))
})

test_that("3b L15: a numeral in math is still reported with reader = 'pandoc'", {
  n3_skip_no_pandoc()
  x <- lint_one("The level is $p = 0.02$ here.", rules = "numeral", reader = "pandoc")
  expect_identical(x$text, "0.02")
  expect_identical(x$spec, "5.2.6")
})

test_that("3b L15: a paragraph that begins with a construct is read under reader = 'pandoc'", {
  n3_skip_no_pandoc()
  doc <- c("Intro words.", "", "[3 sites]{if=\"n > 2\"} remain wet.", "",
           "[a site | sites]{n=\"k\"} had 5 visits.", "", "`r x`{.num} of 12 sites")
  x <- lint_one(doc, rules = "numeral", reader = "pandoc")
  expect_identical(x$text, c("3", "5", "12"))
  expect_identical(x$line, c(3L, 5L, 7L))
})

test_that("3b L15: reader = 'pandoc' removes a false positive of the R reader (a raw HTML block)", {
  n3_skip_no_pandoc()
  doc <- c("Intro words.", "", "<div>", "12 sites", "</div>", "", "After 7 words.")
  w <- lint_one(doc, rules = "numeral", reader = "weft")
  p <- lint_one(doc, rules = "numeral", reader = "pandoc")
  expect_identical(w$text, c("12", "7"))
  expect_identical(p$text, "7")
  expect_identical(p$line, 7L)
})

test_that("3b L15: with reader = 'pandoc' a finding is never one the R reader would not make", {
  n3_skip_no_pandoc()
  doc <- c("Intro 3 words.", "", "<div>", "12 sites", "</div>", "", "- a 5 list", "",
           "> quote of 6", "", "Cite [@smith2020, p. 4] and 8 more.")
  w <- lint_one(doc, rules = "numeral", reader = "weft")
  p <- lint_one(doc, rules = "numeral", reader = "pandoc")
  key <- function(z) paste(z$line, z$col, z$text)
  expect_true(all(key(p) %in% key(w)))
  expect_lt(nrow(p), nrow(w))
})

# ---- parity: R prose against Pandoc's Str ---------------------------------------------------------

test_that("3b L15 parity: R prose lies inside Pandoc's Str, and Str outside the masked kinds is R prose", {
  n3_skip_no_pandoc()
  skip_if_not_installed("jsonlite")
  doc <- c("Alpha beta gamma.", "",
           "A caf\u00e9 of 4 sites &amp; 5 with [@smith2020] and https://x.org/a?b=1 and $x$ and `code`.", "",
           "Some text \\vspace{2em} more text. <span>12</span> and more.", "",
           "- item one", "> quote 9", "", "Last line of text, with punctuation; and (brackets).")
  src <- read_src(doc)
  txt <- src$text
  ranges <- n3_str_ranges(txt)
  in_str <- rep(FALSE, nchar(txt))
  for (i in seq_len(nrow(ranges))) in_str[ranges$start[[i]]:ranges$end[[i]]] <- TRUE
  chars <- strsplit(txt, "")[[1]]
  rchars <- strsplit(src$prose, "")[[1]]
  is_ws <- chars %in% c(" ", "\n", "\t")
  r_prose <- !(rchars %in% c(" ", "\n")) & !is_ws
  # (a) every character the R reader calls prose, Pandoc calls a Str
  expect_true(all(in_str[r_prose]), info = paste(chars[r_prose & !in_str], collapse = ""))
  # the kinds Pandoc's Str covers but this package masks: citations, entities, raw TeX, bare URLs
  masked_kinds <- rep(FALSE, nchar(txt))
  for (pat in c("\\[@[^]]*\\]", "&[a-z#0-9]+;", "\\\\[a-z]+(\\{[^}]*\\})?", "https?://[^ ]+")) {
    m <- gregexpr(pat, txt, perl = TRUE)[[1]]
    if (m[[1]] > 0L) for (j in seq_along(m)) {
      masked_kinds[m[[j]]:(m[[j]] + attr(m, "match.length")[[j]] - 1L)] <- TRUE
    }
  }
  # (b) every Str character outside those kinds is R prose
  expect_true(all(r_prose[in_str & !is_ws & !masked_kinds]),
              info = paste(chars[in_str & !is_ws & !masked_kinds & !r_prose], collapse = ""))
  # and the masked kinds are not R prose
  expect_false(any(r_prose & masked_kinds))
})
