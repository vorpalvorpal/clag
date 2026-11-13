# Package 2d: the ledger (dev/design-2d.md D1-D14, D20-D28). Written before the code.
# Non-ASCII is written as \uXXXX; "\\u00a0" is the six-character escape, "\u00a0" a no-break space.
# Made-up values only. Renders are shared between tests through d2_memo().
if (!exists("d2_render")) source(Filter(file.exists, c(testthat::test_path("helper-2d.R"), testthat::test_path("..", "helper-2d.R")))[[1]])
d2_need()

# ---- the example ------------------------------------------------------------------------

d2_example <- function() d2_memo("example", function() {
  d2_render(D2_EXAMPLE_BODY, code = D2_VARS, files = list("dict.yml" = D2_DICT))
})

test_that("2d D1: a set-up project gets exactly the two files, in _weft/ledger/<source>/", {
  res <- d2_example()
  expect_false(res$failed, label = res$message)
  folder <- file.path(res$dir, "_weft", "ledger", "doc.Rmd")
  expect_setequal(list.files(folder, all.files = TRUE, no.. = TRUE), c("doc.jsonl", "doc.conditions.jsonl"))
  expect_setequal(list.files(file.path(res$dir, "_weft"), no.. = TRUE), "ledger")
})

test_that("2d D4 + 2e P13: the header starts with the four fixed fields, then dict, files and targets", {
  res <- d2_example()
  line <- d2_lines(d2_path(res$dir))[1]
  fixed <- "{\"weft\":\"ledger\",\"version\":1,\"source\":\"doc.Rmd\",\"output\":\"doc\""
  expect_true(startsWith(line, paste0(fixed, ",\"dict\":{")))
  h <- d2_header(d2_path(res$dir))
  expect_identical(names(h), c("weft", "version", "source", "output", "dict", "files", "targets"))
  expect_identical(names(h$dict), "limit")
  expect_identical(names(h$files), "doc.Rmd")
  expect_true(grepl("^[0-9a-f]{16}$", h$files[["doc.Rmd"]]))
  expect_length(h$targets, 0L)
  expect_true(endsWith(line, "\"targets\":{}}"))
})

test_that("2d D3 + D8 + D13: the entry lines equal the example of the design note, byte for byte, in order", {
  res <- d2_example()
  got <- d2_lines(d2_path(res$dir))
  want <- d2_example_lines("doc.Rmd")
  expect_identical(got[-1], want[-1])
  expect_length(got, 6L)
})

test_that("2d D3: the escape is six ASCII characters, not a no-break space; no CR, no BOM, a final newline", {
  res <- d2_example()
  b <- d2_bytes(d2_path(res$dir))
  txt <- rawToChar(b)
  expect_true(grepl("1.5\\u00a0km", txt, fixed = TRUE))
  expect_false(grepl("\u00a0", txt, fixed = TRUE))
  expect_false(as.raw(0x0d) %in% b)
  expect_false(identical(b[1:3], as.raw(c(0xEF, 0xBB, 0xBF))))
  expect_identical(b[length(b)], as.raw(0x0a))
  # the condition log too
  cb <- d2_bytes(d2_path(res$dir, conditions = TRUE))
  expect_identical(cb[length(cb)], as.raw(0x0a))
  expect_false(as.raw(0x0d) %in% cb)
})

test_that("2d D28: last_knit() holds output, written and the entries as read_ledger() returns them", {
  res <- d2_example()
  k <- res$knit
  expect_identical(k$output, "doc")
  expect_identical(k$written, c(ledger = "_weft/ledger/doc.Rmd/doc.jsonl",
                                conditions = "_weft/ledger/doc.Rmd/doc.conditions.jsonl"))
  l <- weft:::read_ledger(d2_path(res$dir))
  attr(l, "header") <- NULL
  expect_equal(k$ledger, l)
  expect_s3_class(k$ledger, "weft_ledger")
  expect_identical(nrow(k$ledger), 5L)
})

test_that("2d D1 + D21 + D28: not set up, nothing is written but last_knit() holds the rows", {
  res <- d2_render(D2_EXAMPLE_BODY, set_up = FALSE, code = D2_VARS, files = list("dict.yml" = D2_DICT))
  expect_false(res$failed, label = res$message)
  expect_false(dir.exists(file.path(res$dir, "_weft")))
  expect_identical(nrow(res$knit$ledger), 5L)
  expect_identical(res$knit$written, c(ledger = NA_character_, conditions = NA_character_))
})

# ---- D8: the fields, one construct each ---------------------------------------------------

D2_BIB <- c("@book{survey2020,", "  author = {Smith, Anna},", "  title = {Rivers},", "  year = {2020},",
            "  publisher = {Example Press}", "}")

d2_kinds <- function() d2_memo("kinds", function() {
  lines <- c(
    "---", "title: |", "  Depth of `r 12.5`{.num} m", "bibliography: refs.bib",
    "knitr:", "  opts_knit:", "    weft: !expr weft::weft_setup()", "---", "",
    "```{r setup, include=FALSE}", "dd <- -2; vv <- c('a', 'b', 'c'); pv <- 0.0001; r0 <- 0.8; wsv <- 7", "```", "",
    "## Kinds", "",
    "Change was [rose | fell | flat]{sign=\"dd\"}.", "",
    "Flagged [None | # was | # were]{list=\"vv\"}.", "",
    "Cited [as reported]{cite=\"survey2020\"}.", "",
    "The p-value was `r pv`{.p}.", "",
    "```{r fig, fig.cap='Ratio of `r r0`{.num} overall.'}", "plot(1)", "```", "",
    "```{r strs, results='asis'}", "cat(weft_str('Weight `r wsv`{.num} kg here.'))", "```", "")
  d2_render(lines, setup = FALSE, files = list("refs.bib" = D2_BIB), format = "md")
})

test_that("2d D8: a sign span records the role of its arm and its governor's value", {
  res <- d2_kinds()
  expect_false(res$failed, label = res$message)
  e <- d2_one(d2_ledger(res), kind = "sign", expr = "dd")
  expect_identical(e$arm, "negative")
  expect_identical(e$rel, "=")
  expect_equal(as.numeric(e$raw), -2)
  expect_identical(e$text, "fell")
  expect_identical(e$section, "kinds")
  expect_identical(e$context, "prose")
})

test_that("2d D8: a list span over three names takes the arm `other`, with a null raw", {
  e <- d2_one(d2_ledger(d2_kinds()), kind = "list", expr = "vv")
  expect_identical(e$arm, "other")
  expect_null(e$raw)
})

test_that("2d D9: a cite span's expr is the key, ' | ', and the bracket text", {
  e <- d2_one(d2_ledger(d2_kinds()), kind = "cite")
  expect_identical(e$expr, "survey2020 | as reported")
  expect_null(e$arm)
})

test_that("2d D8 + D12: a caption construct has context caption, its chunk's section, the caption as sentence", {
  e <- d2_one(d2_ledger(d2_kinds()), kind = "value", expr = "r0")
  expect_identical(e$context, "caption")
  expect_identical(e$section, "kinds")
  expect_identical(e$text, "0.8")
  expect_identical(e$sentence, "Ratio of 0.8 overall.")
})

test_that("2d D8 + D12: a weft_str() string has context weft_str and the string as its sentence", {
  e <- d2_one(d2_ledger(d2_kinds()), kind = "value", expr = "wsv")
  expect_identical(e$context, "weft_str")
  expect_identical(e$sentence, "Weight 7 kg here.")
})

test_that("2d D8 + D10: a front-matter construct has context front-matter and section ''", {
  e <- d2_one(d2_ledger(d2_kinds()), context = "front-matter")
  expect_identical(e$section, "")
  expect_identical(e$expr, "12.5")
  expect_identical(e$text, "12.5")
  expect_identical(e$sentence, "Depth of 12.5 m")
})

test_that("2d D8: .p printing a small value records the relation `<`", {
  e <- d2_one(d2_ledger(d2_kinds()), kind = "value", expr = "pv")
  expect_identical(e$rel, "<")
  expect_match(e$text, "0.001", fixed = TRUE)
  expect_equal(e$raw, 1e-04)
})

test_that("2d D8: every entry has all fifteen fields, in the order of the table", {
  res <- d2_kinds()
  want <- c("file", "section", "kind", "expr", "occ", "id", "context", "text", "arm", "rel", "raw",
            "unit", "failed", "dict", "sentence")
  for (l in d2_lines(d2_path(res$dir))[-1]) {
    keys <- regmatches(l, gregexpr("\"[a-z]+\":", l))[[1]]
    # top-level keys appear in order; every wanted key is present once at least
    expect_identical(unique(sub("\":$", "", sub("^\"", "", keys)))[seq_along(want)], want)
  }
})

test_that("2d D7: text spans and links have no entry", {
  res <- d2_render(c("A [result]{.strong} and a [link](https://example.invalid) here.", "",
                     "Value `r 3` there."))
  e <- d2_ledger(res)
  expect_length(e, 1L)
  expect_identical(e[[1]]$kind, "bare")
})

# ---- D9: the expression --------------------------------------------------------------------

test_that("2d D9: expr_key() parses without source and deparses on one line", {
  expect_identical(weft:::expr_key(" mean(  x )"), "mean(x)")
  expect_identical(weft:::expr_key("mean(x)"), "mean(x)")
  expect_identical(weft:::expr_key("mean(x,\n   na.rm = TRUE)"), "mean(x, na.rm = TRUE)")
  expect_identical(weft:::expr_key("a<-1;  b"), "a <- 1; b")
  expect_identical(weft:::expr_key("x[[ 'k' ]]"), "x[[\"k\"]]")
})

d2_exprs <- function() d2_memo("exprs", function() {
  lines <- c("## A", "",
             "Two `r  mean( x )` and `r mean(x)` here.", "",
             "Spanning `r mean(x,", "  na.rm = TRUE)` lines.", "",
             "Limit `r dict[[\"limit\"]]` and `r dict$b + dict$a` here.")
  d2_render(lines, code = "x <- c(1, 2, 3)", files = list("dict.yml" = c(
    "a: {value: 1, type: number, definition: \"A.\"}",
    "b: {value: 2, type: number, definition: \"B.\"}",
    "limit: {value: 0.9, type: number, definition: \"The limit.\"}")))
})

test_that("2d D9 + D13: `r  mean( x )` and `r mean(x)` are one expression, occurrence 1 and 2", {
  res <- d2_exprs()
  expect_false(res$failed, label = res$message)
  e <- d2_pick(d2_ledger(res), expr = "mean(x)")
  expect_length(e, 2L)
  expect_identical(vapply(e, function(z) z$occ, 1L), 1:2)
})

test_that("2d D9: an expression over two lines is one line joined by a space", {
  e <- d2_pick(d2_ledger(d2_exprs()), expr = "mean(x, na.rm = TRUE)")
  expect_length(e, 1L)
})

test_that("2d D8: dict names the dictionary entries the expression names, unique and sorted", {
  e <- d2_ledger(d2_exprs())
  one <- d2_one(e, expr = "dict[[\"limit\"]]")
  expect_identical(unlist(one$dict), "dict$limit")
  two <- d2_one(e, expr = "dict$b + dict$a")
  expect_identical(unlist(two$dict), c("dict$a", "dict$b"))
  expect_identical(d2_one(e, section = "a", expr = "mean(x, na.rm = TRUE)")$dict, list())
})

test_that("2d D9: changing the formatter class between two renders keeps every key field and changes the text", {
  dir <- withr::local_tempdir()
  one <- d2_render(c("## A", "", "Share `r 0.5`{.num} here."), dir = dir)
  e1 <- d2_ledger(one)
  two <- d2_render(c("## A", "", "Share `r 0.5`{.pct} here."), dir = dir)
  e2 <- d2_ledger(two)
  expect_length(e1, 1L); expect_length(e2, 1L)
  for (f in c("file", "section", "kind", "expr", "occ", "id")) expect_identical(e1[[1]][[f]], e2[[1]][[f]], label = f)
  expect_false(identical(e1[[1]]$text, e2[[1]]$text))
  expect_identical(e1[[1]]$expr, "0.5")
})

# ---- D13: occurrence and order ---------------------------------------------------------------

test_that("2d D13: two `r x` in one section are occurrences 1 and 2; in two sections each is 1", {
  res <- d2_render(c("## A", "", "One `r x` and two `r x`.", "", "## B", "", "Three `r x`."), code = "x <- 4")
  e <- d2_ledger(res)
  expect_identical(vapply(d2_pick(e, section = "a"), function(z) z$occ, 1L), 1:2)
  expect_identical(vapply(d2_pick(e, section = "b"), function(z) z$occ, 1L), 1L)
})

test_that("2d D13: lines after the header are sorted on file, section, kind, expr, occ in the C locale; occ numerically", {
  body <- c("## b-sec", "", "`r Zeta` `r alpha` `r Zeta`", "", "[x | y]{if=\"alpha > 0\"}", "",
            "## a-sec", "", paste(rep("`r alpha`", 11), collapse = " "), "",
            "Intro words `r alpha`.")
  res <- d2_render(c("Top `r alpha`.", "", body), code = "Zeta <- 1; alpha <- 2")
  e <- d2_ledger(res)
  expect_length(e, 17L)
  df <- data.frame(file = vapply(e, `[[`, "", "file"), section = vapply(e, `[[`, "", "section"),
                   kind = vapply(e, `[[`, "", "kind"), expr = vapply(e, `[[`, "", "expr"),
                   occ = vapply(e, `[[`, 1L, "occ"), stringsAsFactors = FALSE)
  expect_identical(order(df$file, df$section, df$kind, df$expr, df$occ, method = "radix"), seq_len(nrow(df)))
  expect_true(11L %in% df$occ[df$section == "a-sec" & df$expr == "alpha"])
  expect_lt(which(df$expr == "Zeta")[1], which(df$expr == "alpha" & df$section == "b-sec")[1])
})

test_that("2d D13: inserting a paragraph with a value into section B leaves every line of section A unchanged", {
  dir <- withr::local_tempdir()
  base <- c("## A", "", "Alpha `r x`.", "", "## B", "", "Beta `r y`.")
  one <- d2_render(base, dir = dir, code = "x <- 1; y <- 2; z <- 3")
  l1 <- d2_lines(d2_path(one$dir))
  two <- d2_render(c(base, "", "More beta `r z`."), dir = dir, code = "x <- 1; y <- 2; z <- 3")
  l2 <- d2_lines(d2_path(two$dir))
  isA <- function(l) grepl("\"section\":\"a\"", l, fixed = TRUE)
  expect_identical(l2[isA(l2)], l1[isA(l1)])
  expect_length(l2, length(l1) + 1L)
})

# ---- D10: sections ------------------------------------------------------------------------

D2_SECTION_DOC <- c(
  "---", "title: t", "# not a heading", "---", "",
  "Intro.", "",
  "## Mean ratio, 2024", "",
  "## Water {#quality}", "",
  "## Methods", "",
  "## Methods", "",
  "## Methods", "",
  "Setext heading", "--------------", "",
  "```{r}", "# comment", "x <- 1", "```", "",
  "```", "## fenced", "```", "",
  "## Sites in `r yr`", "",
  "## 2024 results", "",
  "## 2024", "",
  "## Water (quality) & more {.unnumbered}", "")
D2_SECTION_ANCHORS <- c("mean-ratio-2024", "quality", "methods", "methods-1", "methods-2", "setext-heading",
                        "sites-in", "results", "section", "water-quality-more")
D2_SECTION_LINES <- c(8L, 10L, 12L, 14L, 16L, 18L, 30L, 32L, 34L, 36L)

test_that("2d D10: heading_anchors() applies Pandoc's rule to the source text, outside code, fences and front matter", {
  a <- weft:::heading_anchors(D2_SECTION_DOC)
  expect_s3_class(a, "data.frame")
  expect_identical(names(a), c("line", "anchor"))
  expect_identical(a$anchor, D2_SECTION_ANCHORS)
  expect_identical(as.integer(a$line), D2_SECTION_LINES)
})

d2_sections <- function() d2_memo("sections", function() {
  lines <- c(
    "Intro `r v1`.", "",
    "## Mean ratio, 2024", "", "A `r v2`.", "",
    "## Water {#quality}", "", "B `r v3`.", "",
    "## Methods", "", "C `r v4`.", "",
    "## Methods", "", "D `r v5`.", "",
    "Setext heading", "--------------", "", "E `r v6`.", "",
    "```{r}", "# comment", "x <- 1", "```", "", "F `r v7`.", "",
    "## Sites in `r yr`", "", "G `r v8`.", "")
  d2_render(lines, code = paste0("v", 1:8, " <- ", 1:8, "; yr <- 2024", collapse = "; "))
})

test_that("2d D10: the section of each construct is the anchor of the nearest heading above it", {
  res <- d2_sections()
  expect_false(res$failed, label = res$message)
  e <- d2_ledger(res)
  sec <- function(expr) d2_one(e, expr = expr)$section
  expect_identical(sec("v1"), "")
  expect_identical(sec("v2"), "mean-ratio-2024")
  expect_identical(sec("v3"), "quality")
  expect_identical(sec("v4"), "methods")
  expect_identical(sec("v5"), "methods-1")
  expect_identical(sec("v6"), "setext-heading")
  expect_identical(sec("v7"), "setext-heading")    # a `# comment` line in a chunk is not a heading
  expect_identical(sec("v8"), "sites-in")
})

# ---- D11: raw --------------------------------------------------------------------------------

d2_raws <- function() d2_memo("raws", function() {
  lines <- c("A `r 0.8234567` b `r 1234567` c `r 0` d `r c(1, 2)` e `r 'a'` f `r NA_real_` g `r NA_real_`{.num} h.", "",
             "H [x | y]{if=\"TRUE\"}.")
  d2_render(lines, env = c(WEFT_DRAFT = "1"))
})

test_that("2d D11: a number is written to six significant figures as formatC(digits = 6, 'g') prints it", {
  res <- d2_raws()
  e <- d2_ledger(res)
  expect_equal(d2_one(e, expr = "0.8234567")$raw, 0.823457)
  expect_equal(d2_one(e, expr = "1234567")$raw, 1234570)
  expect_equal(d2_one(e, expr = "0")$raw, 0)
  ln <- d2_lines(d2_path(res$dir))
  expect_true(any(grepl("\"expr\":\"0.8234567\".*\"raw\":0.823457,", ln)))
  expect_true(any(grepl("\"raw\":1.23457e+06,", ln, fixed = TRUE)))
  expect_true(any(grepl("\"expr\":\"0\".*\"raw\":0,", ln)))
})

test_that("2d D11: a vector, text, NA and an `if` have a null raw", {
  e <- d2_ledger(d2_raws())
  expect_null(d2_one(e, expr = "c(1, 2)")$raw)
  expect_null(d2_one(e, expr = "\"a\"")$raw)
  expect_null(d2_one(e, kind = "if")$raw)
  expect_null(d2_one(e, kind = "bare", expr = "NA_real_")$raw)
  expect_null(d2_one(e, kind = "value", expr = "NA_real_")$raw)
})

test_that("2d D8: a bare NA records the text knitr printed, with raw null and failed null", {
  na <- d2_one(d2_ledger(d2_raws()), kind = "bare", expr = "NA_real_")
  expect_identical(na$text, "NA")
  expect_null(na$raw)
  expect_null(na$failed)
})

test_that("2d D8: in draft mode a missing value in a value construct has text null, failed 'no value', raw null", {
  na <- d2_one(d2_ledger(d2_raws()), kind = "value", expr = "NA_real_")
  expect_null(na$text)
  expect_identical(na$failed, "no value")
  expect_null(na$raw)
})

# ---- D3: characters -------------------------------------------------------------------------

d2_chars <- function() d2_memo("chars", function() {
  lines <- c("A `r -3`{.num} b `r 'say \"hi\" \\\\ there'` c `r 'm\\u00b2'` d `r 'p\\u00a0q'` e `r 'u\\u2028v'` f `r 'w\\tx'` g `r 'a\\nb'` h `r 's\\u00adt'` i `r 'f\\ufeffg'`.")
  d2_render(lines)
})

test_that("2d D3: other characters are written as themselves (U+2212, U+00B2); invisible ones and controls escaped in lower case", {
  res <- d2_chars()
  expect_false(res$failed, label = res$message)
  txt <- paste(d2_lines(d2_path(res$dir))[-1], collapse = "\n")
  expect_true(grepl("\"text\":\"\u22123\"", txt, fixed = TRUE))
  expect_true(grepl("m\u00b2", txt, fixed = TRUE))
  expect_false(grepl("\\u2212", txt, fixed = TRUE))
  expect_false(grepl("\\u00b2", txt, fixed = TRUE))
  expect_true(grepl("p\\u00a0q", txt, fixed = TRUE))
  expect_true(grepl("u\\u2028v", txt, fixed = TRUE))
  expect_true(grepl("s\\u00adt", txt, fixed = TRUE))
  expect_true(grepl("f\\ufeffg", txt, fixed = TRUE))
  expect_true(grepl("w\\tx", txt, fixed = TRUE))
  expect_true(grepl("a\\nb", txt, fixed = TRUE))
  expect_false(grepl("[\u00a0\u2028\u00ad\ufeff\t]", txt))
})

test_that("2d D3: a quote and a backslash are escaped, and the line parses back to the text", {
  res <- d2_chars()
  txt <- paste(d2_lines(d2_path(res$dir))[-1], collapse = "\n")
  expect_true(grepl("say \\\"hi\\\" \\\\ there", txt, fixed = TRUE))
  e <- d2_one(d2_ledger(res), expr = "\"say \\\"hi\\\" \\\\ there\"")
  expect_identical(e$text, "say \"hi\" \\ there")
})

# ---- D8: arms ------------------------------------------------------------------------------

d2_arms <- function() d2_memo("arms", function() {
  lines <- c(
    "## Arms", "",
    "One [# was | # were]{n=\"k1\"} here.", "",
    "Three [# was | # were]{n=\"k3\"} here.", "",
    "Guard[, ok]{if=\"tt\"} true.", "",
    "Two arms [yes | ]{if=\"tt2\"} true.", "",
    "Nested [chosen `r inner_a`{.num} | other `r inner_b`{.num}]{if=\"tt3\"} done.")
  d2_render(lines, code = c("k1 <- 1; k3 <- 3; tt <- TRUE; tt2 <- TRUE; tt3 <- TRUE",
                            "inner_a <- 5; inner_b <- 6"))
})

test_that("2d D8: an n span records the role of its arm: one for 1, other for 3", {
  e <- d2_ledger(d2_arms())
  expect_identical(d2_one(e, kind = "n", expr = "k1")$arm, "one")
  expect_identical(d2_one(e, kind = "n", expr = "k3")$arm, "other")
})

test_that("2d D8: a one-arm if records `always` when true", {
  t <- d2_one(d2_ledger(d2_arms()), kind = "if", expr = "tt")
  expect_identical(t$arm, "always")
  expect_identical(t$text, ", ok")
})

test_that("2d D8: a one-arm if that is false (a failure, so draft mode) has a null arm and is marked failed", {
  res <- d2_render(c("Guard[, no]{if=\"ff\"} false."), code = "ff <- FALSE", env = c(WEFT_DRAFT = "1"))
  f <- d2_one(d2_ledger(res), kind = "if", expr = "ff")
  expect_null(f$arm)
  expect_identical(f$failed, "failed claim")
  # D8 says `text` is "" when no arm was chosen and null when the construct failed; either is accepted here
  expect_true(is.null(f$text) || identical(f$text, ""))
})

test_that("2d D8: the same if with an empty second arm records `true` when true (G8)", {
  e <- d2_ledger(d2_arms())
  expect_identical(d2_one(e, kind = "if", expr = "tt2")$arm, "true")
})

test_that("2d D7: a value nested in the chosen arm has an entry; one in the arm not chosen has none", {
  e <- d2_ledger(d2_arms())
  expect_length(d2_pick(e, expr = "inner_a"), 1L)
  expect_length(d2_pick(e, expr = "inner_b"), 0L)
})

# ---- D12: the sentence ----------------------------------------------------------------------

test_that("2d D12: two values in one sentence carry the same sentence, which starts after the previous one", {
  res <- d2_render(c("First sentence ends here. Then `r a` and `r b` end now.  Last one."), code = "a <- 1; b <- 2")
  e <- d2_ledger(res)
  expect_length(e, 2L)
  expect_identical(e[[1]]$sentence, "Then 1 and 2 end now.")
  expect_identical(e[[2]]$sentence, "Then 1 and 2 end now.")
})

test_that("2d D12: a sentence of 600 characters is cut near the value, marked with an ellipsis", {
  words <- paste(rep("alpha", 60), collapse = " ")
  res <- d2_render(sprintf("%s `r a`{.num} %s.", words, words), code = "a <- 42")
  e <- d2_one(d2_ledger(res), expr = "a")
  s <- e$sentence
  expect_true(grepl("42", s, fixed = TRUE))
  expect_true(startsWith(s, "\u2026") || endsWith(s, "\u2026"))
  expect_lte(nchar(s), 402L + nchar(e$text))
  expect_lt(nchar(s), 600L)
})

test_that("2d D12: the sentence of a value in a table cell is the cell", {
  res <- d2_render(c("| Name | Depth |", "|------|-------|", "| one | Depth `r tcv`{.num} m |"), code = "tcv <- 3.5")
  e <- d2_one(d2_ledger(res), expr = "tcv")
  expect_identical(e$sentence, "Depth 3.5 m")
})

# ---- D20: when it is written ------------------------------------------------------------------

test_that("2d D8 + D20: a failed claim in draft mode is written with text null, failed set and raw set", {
  res <- d2_render(c("Check `r claim(k, . > 100)` here."), code = "k <- 3", env = c(WEFT_DRAFT = "1"))
  expect_false(res$failed, label = res$message)
  e <- d2_ledger(res)
  f <- Filter(function(z) identical(z$failed, "failed claim"), e)
  expect_length(f, 1L)
  expect_null(f[[1]]$text)
  expect_equal(as.numeric(f[[1]]$raw), 3)
})

test_that("2d D20: a render that stops on its failures, or on a chunk error, leaves both files byte-identical", {
  dir <- withr::local_tempdir()
  good <- c("Value `r k` here.")
  ok <- d2_render(good, code = "k <- 3", dir = dir)
  expect_false(ok$failed, label = ok$message)
  pl <- d2_path(dir); pc <- d2_path(dir, conditions = TRUE)
  before <- list(d2_bytes(pl), d2_bytes(pc))
  bad <- d2_render(c("Value `r k` here.", "", "Check `r claim(k, . > 100)` now."), code = "k <- 4", dir = dir,
                   env = c(WEFT_DRAFT = NA), may_fail = TRUE)
  expect_true(bad$failed)
  expect_identical(d2_bytes(pl), before[[1]])
  expect_identical(d2_bytes(pc), before[[2]])
  boom <- d2_render(c("```{r, error=FALSE}", "stop('boom')", "```", "", "Value `r k` here."), code = "k <- 5", dir = dir,
                    env = c(WEFT_DRAFT = NA), may_fail = TRUE)
  expect_true(boom$failed)
  expect_identical(d2_bytes(pl), before[[1]])
  expect_identical(d2_bytes(pc), before[[2]])
})

test_that("2d D20: knit_exit() ends the document: entries above it are written, entries below are not", {
  res <- d2_render(c("Above `r a`.", "", "```{r}", "knitr::knit_exit()", "```", "", "Below `r b`."),
                   code = "a <- 1; b <- 2")
  e <- d2_ledger(res)
  expect_length(d2_pick(e, expr = "a"), 1L)
  expect_length(d2_pick(e, expr = "b"), 0L)
})

test_that("2d D6: an identical second render does not rewrite the file, and leaves no temporary file", {
  dir <- withr::local_tempdir()
  d2_render(c("Value `r k`."), code = "k <- 3", dir = dir)
  p <- d2_path(dir)
  expect_true(file.exists(p))
  t1 <- file.mtime(p)
  Sys.sleep(1.1)
  again <- d2_render(c("Value `r k`."), code = "k <- 3", dir = dir)
  expect_false(again$failed, label = again$message)
  expect_identical(file.mtime(p), t1)
  expect_false(is.na(file.mtime(p)))
  left <- list.files(file.path(dir, "_weft"), all.files = TRUE, recursive = TRUE)
  expect_true(length(left) >= 2L)
  expect_false(any(grepl("tmp", left)))
})

# ---- D2 + D24: outputs -------------------------------------------------------------------------

D2_PARAM_DOC <- c("---", "title: t", "params:", "  site: x", "---", "",
                  "```{r setup, include=FALSE}", "weft::weft_setup()", "```", "",
                  "Site `r params$site` done.", "")

d2_params_dir <- function() {
  dir <- withr::local_tempdir(.local_envir = parent.frame())
  writeLines("draft: false", file.path(dir, "_weft.yml"))
  writeLines(D2_PARAM_DOC, file.path(dir, "doc.Rmd"))
  normalizePath(dir)
}

test_that("2d D2 + D24: one document rendered to two outputs gets a ledger each, and a re-render rewrites only its own", {
  dir <- d2_params_dir()
  a <- d2_render_to(dir, "doc.Rmd", "site-a.md", list(site = "a"))
  expect_null(a$error)
  b <- d2_render_to(dir, "doc.Rmd", "site-b.md", list(site = "b"))
  expect_null(b$error)
  pa <- d2_path(dir, output = "site-a"); pb <- d2_path(dir, output = "site-b")
  expect_identical(d2_one(d2_entries(pa), expr = "params$site")$text, "a")
  expect_identical(d2_one(d2_entries(pb), expr = "params$site")$text, "b")
  expect_identical(d2_header(pa)$output, "site-a")
  expect_identical(a$knit$output, "site-a")
  keep <- d2_bytes(pb)
  c1 <- d2_render_to(dir, "doc.Rmd", "site-a.md", list(site = "c"))
  expect_null(c1$error)
  expect_identical(d2_one(d2_entries(pa), expr = "params$site")$text, "c")
  expect_identical(d2_bytes(pb), keep)
  expect_setequal(list.files(dirname(pa)), c("site-a.jsonl", "site-a.conditions.jsonl", "site-b.jsonl",
                                             "site-b.conditions.jsonl"))
})

test_that("2d D2: a plain knitr::knit() names the output after the source", {
  res <- d2_render(c("Value `r k`."), code = "k <- 1", format = "knit")
  expect_identical(res$knit$output, "doc")
  expect_true(file.exists(d2_path(res$dir)))
})

test_that("2d D2: WEFT_OUTPUT names the output first", {
  res <- d2_render(c("Value `r k`."), code = "k <- 1", env = c(WEFT_OUTPUT = "other"))
  expect_true(file.exists(d2_path(res$dir, output = "other")))
  expect_false(file.exists(d2_path(res$dir)))
  expect_identical(res$knit$output, "other")
  expect_identical(d2_header(d2_path(res$dir, output = "other"))$output, "other")
})

test_that("2d G18 pinned: rmarkdown::render() holds output_file in its frame while the document is knitted", {
  skip_if_not(rmarkdown::pandoc_available(), "pandoc is not available")
  dir <- withr::local_tempdir()
  doc <- c("```{r}",
           "for (i in seq_len(sys.nframe())) if (identical(sys.function(i), rmarkdown::render)) {",
           "  writeLines(basename(get('output_file', envir = sys.frame(i))), 'seen.txt')",
           "}",
           "```", "", "Done.")
  writeLines(doc, file.path(dir, "pin.Rmd"))
  r <- d2_render_to(dir, "pin.Rmd", "pinned-out.md")
  expect_null(r$error)
  expect_identical(readLines(file.path(dir, "seen.txt")), "pinned-out.md")
})

# ---- D1, D21: placement and children ---------------------------------------------------------

test_that("2d D1: a source in a sub-folder gets its path under _weft/ledger, with file set to the relative path", {
  dir <- withr::local_tempdir()
  dir.create(file.path(dir, "reports"))
  res <- d2_render(c("Value `r k`."), code = "k <- 1", dir = dir, name = "reports/water")
  expect_false(res$failed, label = res$message)
  p <- file.path(res$dir, "_weft", "ledger", "reports", "water.Rmd", "water.jsonl")
  expect_true(file.exists(p))
  expect_identical(d2_header(p)$source, "reports/water.Rmd")
  expect_identical(d2_entries(p)[[1]]$file, "reports/water.Rmd")
})

test_that("2d D21 + G4: a child's entries go to the parent's ledger with the child's file; the child has no files", {
  res <- d2_render(c("```{r, child='part.Rmd'}", "```", "", "Parent `r k`."), code = "k <- 1; ck <- 2",
                   files = list("part.Rmd" = c("## Child section", "", "Child `r ck`.")))
  expect_false(res$failed, label = res$message)
  e <- d2_ledger(res)
  c1 <- d2_one(e, expr = "ck")
  expect_identical(c1$file, "part.Rmd")
  expect_identical(c1$section, "child-section")
  expect_identical(d2_one(e, expr = "k")$file, "doc.Rmd")
  expect_false(dir.exists(file.path(res$dir, "_weft", "ledger", "part.Rmd")))
})

test_that("2d D10 + D13: knit_child(text =) in a loop gives occurrences 1 to 3 in the parent's file and the calling chunk's section", {
  res <- d2_render(c("## Loop", "", "```{r, results='asis'}",
                     "for (i in 1:3) cat(knitr::knit_child(text = 'Item `r i`.', quiet = TRUE), '\\n')", "```"))
  expect_false(res$failed, label = res$message)
  e <- d2_pick(d2_ledger(res), expr = "i")
  expect_length(e, 3L)
  expect_identical(vapply(e, function(z) z$occ, 1L), 1:3)
  expect_identical(unique(vapply(e, function(z) z$file, "")), "doc.Rmd")
  expect_identical(unique(vapply(e, function(z) z$section, "")), "loop")
})

# ---- D22: the chunk cache -----------------------------------------------------------------------

test_that("2d D22: a render served from the chunk cache writes byte-identical files, and stores the rows with the cache", {
  skip_if_not(rmarkdown::pandoc_available(), "pandoc is not available")
  dir <- withr::local_tempdir()
  doc <- c("## Cached", "",
           "```{r make, cache=TRUE, results='asis'}",
           "cat('ran\\n', file = 'ran.txt', append = TRUE)",
           "warning('cached warning text')",
           "cat(weft_str('Weight `r wcv`{.num} kg here.'))",
           "```", "", "Prose `r wcv`.")
  r1 <- d2_render(doc, code = "wcv <- 7", dir = dir, format = "md")
  expect_false(r1$failed, label = r1$message)
  expect_true(any(vapply(d2_ledger(r1), function(z) identical(z$context, "weft_str"), NA)))
  b1 <- list(d2_bytes(d2_path(dir)), d2_bytes(d2_path(dir, conditions = TRUE)))
  r2 <- d2_render(doc, code = "wcv <- 7", dir = dir, format = "md")
  expect_false(r2$failed, label = r2$message)
  expect_length(readLines(file.path(dir, "ran.txt")), 1L)
  expect_identical(d2_bytes(d2_path(dir)), b1[[1]])
  expect_identical(d2_bytes(d2_path(dir, conditions = TRUE)), b1[[2]])
  expect_true(length(list.files(dir, pattern = "\\.weft-ledger\\.rds$", recursive = TRUE)) >= 1L)
})

# ---- D21: rehearsal ------------------------------------------------------------------------------

test_that("2d D21: WEFT_REHEARSE=1 writes no ledger", {
  res <- d2_render(c("Value `r k`."), code = "k <- 1", env = c(WEFT_REHEARSE = "1"))
  expect_false(dir.exists(file.path(res$dir, "_weft", "ledger")))
  expect_identical(res$knit$written, c(ledger = NA_character_, conditions = NA_character_))
})

test_that("2d D21: rehearse() in a set-up project leaves the folder's file list unchanged", {
  skip_if_not(rmarkdown::pandoc_available(), "pandoc is not available")
  doc <- c("---", "title: t", "params:", "  count: 2", "---", "", "```{r setup, include=FALSE}",
           "weft::weft_setup()", "```", "", "Found [one site | # sites]{n=\"params$count\"}.", "")
  path <- e1_write(doc, "doc.Rmd", files = list("_weft.yml" = "draft: false"))
  before <- e1_snapshot(dirname(path))
  r <- e1_with_libs(rehearse(path, list(a = list(count = 1), b = list(count = 3))))
  expect_identical(e1_snapshot(dirname(path)), before)
  expect_false(dir.exists(file.path(dirname(path), "_weft", "ledger")))
  expect_true(r$cases$a$ok)
})

# ---- D5, D18, D26, D27: versions, errors, the readers ------------------------------------------

test_that("2d D27: read_ledger() reads the example into a classed data frame with D8's columns", {
  l <- weft:::read_ledger(lines = d2_example_lines("reports/survey.qmd"))
  expect_s3_class(l, c("weft_ledger", "data.frame"))
  expect_identical(names(l), c("file", "section", "kind", "expr", "occ", "id", "context", "text", "arm", "rel",
                               "raw", "unit", "failed", "dict", "sentence"))
  expect_identical(nrow(l), 5L)
  expect_type(l$occ, "integer")
  expect_type(l$raw, "double")
  expect_type(l$dict, "list")
  expect_identical(l$dict[[3]], "dict$limit")
  expect_identical(l$dict[[1]], character())
  expect_true(is.na(l$arm[1]))
  expect_identical(l$arm[2], "other")
  expect_true(is.na(l$raw[3]))
  expect_identical(attr(l, "header")$source, "reports/survey.qmd")
  expect_identical(l$text[4], "1.5\u00a0km")
  expect_type(l$unit, "character")
  expect_identical(l$unit, c(NA, NA, NA, "m", NA))
})

test_that("2d D27: read_ledger(file) reads a file the same way as lines", {
  p <- withr::local_tempfile(fileext = ".jsonl")
  writeLines(d2_example_lines("reports/survey.qmd"), p, useBytes = TRUE)
  expect_equal(weft:::read_ledger(p), weft:::read_ledger(lines = d2_example_lines("reports/survey.qmd")))
})

test_that("2d D27: strict mode raises weft_ledger_error for a wrong header, a later version, and a bad line (naming it)", {
  good <- d2_example_lines("reports/survey.qmd")
  e1 <- tryCatch(weft:::read_ledger(lines = c("{\"weft\":\"conditions\",\"version\":1,\"source\":\"s\",\"output\":\"o\"}", good[-1])),
                 error = function(e) e)
  expect_s3_class(e1, "weft_ledger_error")
  expect_s3_class(e1, "weft_error")
  e2 <- tryCatch(weft:::read_ledger(lines = c("{\"weft\":\"ledger\",\"version\":2,\"source\":\"s\",\"output\":\"o\"}", good[-1])),
                 error = function(e) e)
  expect_s3_class(e2, "weft_ledger_error")
  bad <- c(good[1:2], "<<<<<<< HEAD", good[3:4])
  e3 <- tryCatch(weft:::read_ledger(lines = bad), error = function(e) e)
  expect_s3_class(e3, "weft_ledger_error")
  expect_match(conditionMessage(e3), "line 3 of", fixed = TRUE)
  expect_s3_class(weft:::read_ledger(lines = bad, lenient = TRUE), "weft_ledger")
  expect_identical(nrow(weft:::read_ledger(lines = bad, lenient = TRUE)), 3L)
})

test_that("2d D5: a reader ignores fields it does not know", {
  good <- d2_example_lines("doc.Rmd")
  extra <- sub("\"sentence\"", "\"later\":[1,2],\"sentence\"", good[2], fixed = TRUE)
  hdr <- sub("\"output\"", "\"extra\":true,\"output\"", good[1], fixed = TRUE)
  l <- weft:::read_ledger(lines = c(hdr, extra))
  expect_identical(nrow(l), 1L)
  expect_false("later" %in% names(l))
})

test_that("2d D27: ledger_paths() names both files relative to the root", {
  p <- weft:::ledger_paths(withr::local_tempdir(), "reports/survey.qmd", "survey")
  expect_identical(p, c(ledger = "_weft/ledger/reports/survey.qmd/survey.jsonl",
                        conditions = "_weft/ledger/reports/survey.qmd/survey.conditions.jsonl"))
})

test_that("2d D18: an existing ledger with header version 2 is rewritten as version 1, with a weft_ledger_warning", {
  old <- c("{\"weft\":\"ledger\",\"version\":2,\"source\":\"doc.Rmd\",\"output\":\"doc\"}", "{\"new\":\"shape\"}")
  res <- d2_run(c("Value `r k`."), code = "k <- 1", files = list("_weft/ledger/doc.Rmd/doc.jsonl" = old))
  expect_false(res$failed, label = if (is.null(res$error)) "" else conditionMessage(res$error))
  w <- d2_of_class(res, "weft_ledger_warning")
  expect_length(w, 1L)
  expect_identical(d2_header(d2_path(res$dir))$version, 1L)
  expect_identical(d2_entries(d2_path(res$dir))[[1]]$expr, "k")
})

test_that("2d D26: a file where the _weft/ledger folder should be raises one weft_ledger_warning and the render carries on", {
  skip_on_os("windows")
  res <- d2_run(c("Value `r k`."), code = "k <- 1", files = list("_weft/ledger" = "not a folder"))
  expect_false(res$failed)
  w <- d2_of_class(res, "weft_ledger_warning")
  expect_length(w, 1L)
  expect_match(conditionMessage(w[[1]]), "ledger", fixed = TRUE)
  expect_true(file.exists(file.path(res$dir, "doc.md")))
})

test_that("2d D27: git_show() returns a committed file's lines, NULL for a path not in the revision, NULL outside a work tree", {
  skip_if(Sys.which("git") == "")
  dir <- withr::local_tempdir()
  d2_git_init(dir)
  writeLines(c("one", "two"), file.path(dir, "a.txt"))
  d2_git_commit(dir)
  expect_identical(weft:::git_show(dir, "a.txt"), c("one", "two"))
  expect_null(weft:::git_show(dir, "missing.txt"))
  expect_identical(weft:::git_show(dir, "a.txt", rev = "HEAD"), c("one", "two"))
  plain <- withr::local_tempdir()
  writeLines("x", file.path(plain, "a.txt"))
  expect_null(weft:::git_show(plain, "a.txt"))
  empty <- withr::local_tempdir()
  d2_git_init(empty)
  expect_null(weft:::git_show(empty, "a.txt"))
})

test_that("2d D5: a freshly written ledger reads back strictly", {
  res <- d2_example()
  l <- weft:::read_ledger(d2_path(res$dir))
  expect_identical(attr(l, "header")$version, 1L)
  expect_identical(nrow(l), 5L)
})

# ---- D8 (unit): the unit raw is in ---------------------------------------------------------------

d2_units <- function() d2_memo("units", function() {
  lines <- c("## Units", "",
             "Reach `r len`{unit=\"m|km\"} long.", "",
             "Dose `r dose` here.", "",
             "Plain `r 5` and text `r 'abc'` here.", "",
             "Few [# was | # were]{n=\"u(3, m)\"} seen.")
  d2_render(lines, code = c("len <- u(1500, m)", "dose <- u(2, \"mg/L\")"))
})

test_that("2d D8 (unit): a quantity printed in another unit records raw and the held unit, not the printed one", {
  res <- d2_units()
  e <- d2_one(d2_ledger(res), expr = "len")
  expect_equal(as.numeric(e$raw), 1500)
  expect_identical(e$unit, "m")
  expect_true(any(grepl("\"raw\":1500,\"unit\":\"m\",", d2_lines(d2_path(res$dir)), fixed = TRUE)))
})

test_that("2d D8 (unit): a compound unit is written as units::deparse_unit() spells it", {
  want <- units::deparse_unit(units::set_units(2, "mg/L", mode = "standard"))
  e <- d2_one(d2_ledger(d2_units()), expr = "dose")
  expect_identical(e$unit, want)
  expect_equal(as.numeric(e$raw), 2)
})

test_that("2d D8 (unit): a plain number and a text value write unit null", {
  e <- d2_ledger(d2_units())
  expect_null(d2_one(e, expr = "5")$unit)
  expect_null(d2_one(e, expr = "\"abc\"")$unit)
  ln <- d2_lines(d2_path(d2_units()$dir))
  expect_true(any(grepl("\"expr\":\"5\".*\"raw\":5,\"unit\":null,", ln)))
})

test_that("2d D8 (unit): a governed span over a quantity carries the governor's unit", {
  e <- d2_one(d2_ledger(d2_units()), kind = "n")
  expect_equal(as.numeric(e$raw), 3)
  expect_identical(e$unit, "m")
})

test_that("2d D8 (unit): read_ledger() on a line without the field gives NA in the unit column", {
  line <- sub("\"unit\":null,", "", d2_example_lines("doc.Rmd")[2], fixed = TRUE)
  expect_false(grepl("unit", line, fixed = TRUE))
  l <- weft:::read_ledger(lines = c(d2_example_lines("doc.Rmd")[1], line))
  expect_true("unit" %in% names(l))
  expect_true(is.na(l$unit))
})
