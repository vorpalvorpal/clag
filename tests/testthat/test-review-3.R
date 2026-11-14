# Regression tests for the review of stage 3 (static lints): dev/review-3.md, its findings 1 to 13,
# design questions 1 to 5 and the stage-0 items S1 to S3, as ruled in "## Rulings". Helpers: helper-3.R,
# helper-3b.R, helper-3d.R, helper-2e2.R. ASCII only: non-ASCII is written as \u escapes.
# Claim words used in fixtures are only always, never, all, none, every (the default list is trimmed
# separately: decision 66, Q6, S4).

r3_rows <- function(x) as.data.frame(unclass(x), stringsAsFactors = FALSE)
# the 1-based character column of `frag` in `line`
r3_col <- function(line, frag) as.integer(regexpr(frag, line, fixed = TRUE))
r3_chunk <- function(...) c("```{r}", c(...), "```")
r3_table <- c("| a | b |", "|---|---|", "| 1 | 2 |")

# ---- #1: an inline footnote followed by another sentence --------------------------------------------

test_that("review-3 #1: a footnote then a second sentence does not crash claim-word", {
  lines <- "Note^[All sites are listed.] that x is never listed. Every site is here."
  x <- expect_no_error(lint_one(lines, rules = "claim-word", tier = 2, weft_yml = "claim_quantifiers: any"))
  w <- strsplit(tolower(x$text), ", ", fixed = TRUE)
  expect_true(any(vapply(w, function(v) "all" %in% v, NA)))
  expect_true(any(vapply(w, function(v) "never" %in% v, NA)))
  expect_true(any(vapply(w, function(v) "every" %in% v, NA)))
})

test_that("review-3 #1: the whole project lints at tier 1:2 and recall_check() runs", {
  root <- lint_proj(list("a.qmd" = "Note^[All sites are listed.] that x is never listed. Every site is here."))
  expect_no_error(lints(root, tier = 1:2))
  f <- data.frame(id = "f1", quote = "that x is never listed", file = NA_character_,
                  line = NA_integer_, rule = "claim-word", stringsAsFactors = FALSE)
  expect_no_error(recall_check(f, root, rules = "claim-word"))
})

test_that("review-3 #1: with one sentence the outer sentence keeps its claim word beside the note's", {
  x <- lint_one("Note^[All sites are listed.] that x is never listed.", rules = "claim-word", tier = 2, weft_yml = "claim_quantifiers: any")
  expect_identical(nrow(x), 2L)
  expect_setequal(tolower(x$text), c("all", "never"))
  expect_identical(x$col[tolower(x$text) == "never"],
                   r3_col("Note^[All sites are listed.] that x is never listed.", "never"))
})

test_that("review-3 #1: neighbours: no footnote, a footnote without a claim word, a footnote with one", {
  x <- lint_one("Rain was never heavy. Every site was wet.", rules = "claim-word", tier = 2, weft_yml = "claim_quantifiers: any")
  expect_identical(nrow(x), 2L)
  x <- lint_one("Note^[Sites are listed.] that x is never listed.", rules = "claim-word", tier = 2, weft_yml = "claim_quantifiers: any")
  expect_identical(tolower(x$text), "never")
  x <- lint_one(c("Every site is here.", "", "Note^[Sites are listed.] that x is never listed."),
                rules = "claim-word", tier = 2, weft_yml = "claim_quantifiers: any")
  expect_identical(nrow(x), 2L)
  expect_identical(x$line, c(1L, 3L))
  x <- lint_one("Note^[All sites are listed.] that x is listed. Sites are listed.",
                rules = "claim-word", tier = 2, weft_yml = "claim_quantifiers: any")
  expect_identical(tolower(x$text), "all")
})

# ---- #2: parse-data columns are characters ------------------------------------------------------------

test_that("review-3 #2: weft_str() numerals after a non-ASCII string on the same line are found where they are", {
  for (pre in c("s <- \"µg°\"; ", "s <- \"°C\"; ")) {
    code <- paste0(pre, "weft_str(\"rose over 25\")")
    x <- lint_one(r3_chunk(code), rules = "numeral")
    expect_identical(x$text, "25", info = pre)
    expect_identical(x$line, 2L, info = pre)
    expect_identical(x$col, r3_col(code, "25"), info = pre)
  }
  code <- "weft_str(\"rose over 25\")"
  x <- lint_one(r3_chunk(code), rules = "numeral")
  expect_identical(x$col, r3_col(code, "25"))
})

test_that("review-3 #2: inert-check in a chunk names TRUE at its character column after non-ASCII", {
  for (pre in c("z <- \"été\"; ", "z <- \"\U0001F600\"; ")) {
    code <- paste0(pre, "claim(n, TRUE)")
    x <- lint_one(r3_chunk(code), rules = "inert-check")
    expect_identical(x$text, "TRUE", info = pre)
    expect_identical(x$col, r3_col(code, "TRUE"), info = pre)
  }
})

test_that("review-3 #2: an inline value after non-ASCII reports the constant, not a shifted piece", {
  line <- "Mean `r paste(\"été\", x * 100)` here."
  x <- lint_one(line, rules = "value-constant")
  expect_identical(x$text, "100")
  expect_identical(x$col, r3_col(line, "100"))
})

test_that("review-3 #2: dict-key in a chunk after non-ASCII is at its character column", {
  code <- "z <- \"été\"; x <- dict$limt"
  x <- lint_fixture(list("doc.qmd" = r3_chunk(code), "dict.yml" = C3_DICT), rules = "dict-key")
  expect_identical(x$text, "limt")
  expect_identical(x$col, r3_col(code, "limt"))
})

test_that("review-3 #2: ASCII neighbours still hold", {
  line <- "Mean `r paste(\"ete\", x * 100)` here."
  x <- lint_one(line, rules = "value-constant")
  expect_identical(x$col, r3_col(line, "100"))
  code <- "z <- \"ete\"; claim(n, TRUE)"
  expect_identical(lint_one(r3_chunk(code), rules = "inert-check")$col, r3_col(code, "TRUE"))
})

# ---- #3: capitalised cross-references -------------------------------------------------------------------

r3_xr_files <- function(body) {
  list("refs.bib" = F3D_BIBTEX,
       "a.qmd" = c("---", "title: T", "bibliography: refs.bib", "---", "",
                   "![A map](m.png){#fig-map fig-alt=\"x\"}", "",
                   "## Y {#sec-y}", "", "| a | b |", "|---|---|", "| 1 | 2 |", "", ": Sites {#tbl-x}", "",
                   body))
}

test_that("review-3 #3: @Fig-map, @Tbl-x and @Sec-y are cross-references, not citations", {
  x <- lint_fixture(r3_xr_files("@Fig-map shows it. See @Tbl-x and @Sec-y."),
                    rules = c("citation-key", "xref", "anchor-unused"))
  expect_identical(nrow(x), 0L)
})

test_that("review-3 #3: the lower-case forms stay quiet, and an unknown capitalised id is an xref finding", {
  x <- lint_fixture(r3_xr_files("@fig-map, @tbl-x and @sec-y."), rules = c("citation-key", "xref", "anchor-unused"))
  expect_identical(nrow(x), 0L)
  x <- lint_fixture(r3_xr_files("@Fig-map, @Tbl-x, @Sec-y and @Fig-nope."),
                    rules = c("citation-key", "xref", "anchor-unused"))
  expect_false("citation-key" %in% x$rule)
  expect_identical(sum(x$rule == "xref"), 1L)
  expect_match(x$text[x$rule == "xref"], "nope", ignore.case = TRUE)
})

test_that("review-3 #3: a real citation key is still checked", {
  x <- lint_fixture(r3_xr_files("@Fig-map and @nokey2020 and @smith2020."), rules = "citation-key")
  expect_identical(x$text, "nokey2020")
})

# ---- #4: changes() when the project is a subfolder of the repository ------------------------------------------

test_that("review-3 #4: changes() in a subfolder lists only the added line", {
  skip_if(Sys.which("git") == "")
  top <- e2x_project(set_up = FALSE)
  sub <- file.path(top, "report")
  e2x_write(file.path(sub, "_weft.yml"), "draft: false")
  head <- c("# A {#sec-a}", "", "Opening text here.", "")
  code <- function(id) sprintf("Write `@%s` for it.", id)
  e2x_write(file.path(sub, "a.qmd"), c(head, code("sec-a"), "", code("sec-a"), "", code("sec-a")))
  e2x_put_ledger(sub, "a.qmd", list())
  e2x_commit(top)
  e2x_write(file.path(sub, "a.qmd"), c(head, code("sec-a"), "", code("sec-a"), "", code("sec-b")))
  f <- changes(path = sub)$findings
  expect_identical(nrow(f), 1L)
  expect_identical(f$line, 9L)
  expect_match(f$message, "@sec-b", fixed = TRUE)
})

test_that("review-3 #4: a new file in the subfolder still lists every line", {
  skip_if(Sys.which("git") == "")
  top <- e2x_project(set_up = FALSE)
  sub <- file.path(top, "report")
  e2x_write(file.path(sub, "_weft.yml"), "draft: false")
  e2x_write(file.path(sub, "a.qmd"), c("# A {#sec-a}", "", "Text."))
  e2x_put_ledger(sub, "a.qmd", list())
  e2x_commit(top)
  e2x_write(file.path(sub, "b.qmd"), c("# B {#sec-b}", "", "Write `@sec-b` for it.", "", "Write `@sec-b` again."))
  f <- changes(path = sub)$findings
  expect_identical(sort(f$line[f$file == "b.qmd"]), c(3L, 5L))
})

# ---- #5: reader = "pandoc" after a tab ------------------------------------------------------------------------

test_that("review-3 #5: the Pandoc reader finds numerals after a tab where the default reader does", {
  n3_skip_no_pandoc()
  lines <- c("Some text\twith a tab and 12 sites.", "", "- item\twith 7 here")
  a <- lint_one(lines, rules = "numeral")
  b <- lint_one(lines, rules = "numeral", reader = "pandoc")
  expect_identical(a$text, c("12", "7"))
  expect_identical(b$text, c("12", "7"))
  expect_identical(b$line, a$line)
  expect_identical(b$col, a$col)
})

test_that("review-3 #5: two tabs, and a tab inside a list item continuation", {
  n3_skip_no_pandoc()
  lines <- c("A\tB\tcount 31 here.", "", "1. First\twith 8 here")
  a <- lint_one(lines, rules = "numeral")
  b <- lint_one(lines, rules = "numeral", reader = "pandoc")
  expect_identical(b$text, a$text)
  expect_identical(b$col, a$col)
})

# ---- #6: pipes ------------------------------------------------------------------------------------------------

r3_inline <- function(code, rules) lint_one(paste0("Text `r ", code, "` here."), rules = rules)

test_that("review-3 #6: inert-check sees a piped claim(TRUE), native pipe and %>%", {
  for (code in c("n |> claim(TRUE)", "n %>% claim(TRUE)")) {
    x <- r3_inline(code, "inert-check")
    expect_identical(x$text, "TRUE", info = code)
  }
  expect_identical(r3_inline("claim(n, TRUE)", "inert-check")$text, "TRUE")
})

test_that("review-3 #6: a piped check that holds a variable is not inert", {
  expect_identical(nrow(r3_inline("claim(n, . > 10)", "inert-check")), 0L)
  expect_identical(nrow(r3_inline("n |> claim(. > 10)", "inert-check")), 0L)
  expect_identical(nrow(r3_inline("n %>% claim(. > 10)", "inert-check")), 0L)
})

test_that("review-3 #6: value-constant: the piped argument numbering is shifted by one", {
  for (code in c("claim(n, . > 10)", "n |> claim(. > 10)", "n %>% claim(. > 10)",
                 "round(x, 2)", "x |> round(2)", "x %>% round(2)")) {
    expect_identical(nrow(r3_inline(code, "value-constant")), 0L, info = code)
  }
})

test_that("review-3 #6: value-format flags round whether piped or not", {
  for (code in c("round(x, 2)", "x |> round(2)", "x %>% round(2)")) {
    x <- r3_inline(code, "value-format")
    expect_identical(x$text, "round", info = code)
  }
})

test_that("review-3 #6: a constant inside a piped value is still a constant", {
  x <- r3_inline("x |> round(2) * 100", c("value-constant", "value-format"))
  expect_true("100" %in% x$text[x$rule == "value-constant"])
  expect_false("2" %in% x$text[x$rule == "value-constant"])
})

# ---- #7: table captions ------------------------------------------------------------------------------------------

test_that("review-3 #7: a table caption is accepted as ':', 'Table:' or 'table:' before or after the table", {
  for (cap in c(": Sites {#tbl-s}", "Table: Sites {#tbl-s}", "table: Sites {#tbl-s}")) {
    for (e in c("qmd", "Rmd")) {
      x <- lint_one(c(cap, "", r3_table), rules = "table-caption", ext = e)
      expect_identical(nrow(x), 0L, info = paste("before", cap, e))
      x <- lint_one(c(r3_table, "", cap), rules = "table-caption", ext = e)
      expect_identical(nrow(x), 0L, info = paste("after", cap, e))
    }
  }
})

test_that("review-3 #7: a table with no caption is still a finding", {
  x <- lint_one(c("Intro.", "", r3_table, "", "After."), rules = "table-caption")
  expect_identical(nrow(x), 1L)
  expect_identical(x$line, 3L)
})

# ---- #8: a span that holds a citation -------------------------------------------------------------------------------

test_that("review-3 #8: the text of a span holding a citation is prose", {
  for (attr in c("{.mark}", "{if=\"ok\"}")) {
    x <- lint_one(paste0("We saw [see @smith2020 for 3 sites]", attr, " here."), rules = "numeral")
    expect_identical(x$text, "3", info = attr)
  }
})

test_that("review-3 #8: the citation inside the span is still a citation, and a plain group is still masked", {
  x <- lint_one("We saw [see @smith2020 for 3 sites] here.", rules = "numeral")
  expect_identical(nrow(x), 0L)
  files <- list("refs.bib" = F3D_BIBTEX,
                "a.qmd" = c("---", "title: T", "bibliography: refs.bib", "---", "",
                            "We saw [see @nokey2020 for sites]{.mark} here."))
  x <- lint_fixture(files, rules = "citation-key")
  expect_identical(x$text, "nokey2020")
  files[["a.qmd"]][6] <- "We saw [see @smith2020 for sites]{.mark} here."
  expect_identical(nrow(lint_fixture(files, rules = "citation-key")), 0L)
})

# ---- #9: a named tier-2 rule without tier ----------------------------------------------------------------------------

test_that("review-3 #9: a rule named in rules runs whatever its tier when tier is not given", {
  root <- lint_proj(list("a.qmd" = "The largest sites are listed."))
  x <- lints(root, rules = "claim-word")
  expect_identical(x$rule, "claim-word")
  x <- lints(root, rules = c("numeral", "claim-word"))
  expect_true("claim-word" %in% x$rule)
})

test_that("review-3 #9: without rules the default tier still holds, and tier = 1:2 still gives it", {
  root <- lint_proj(list("a.qmd" = "The largest sites are listed."))
  expect_false("claim-word" %in% lints(root)$rule)
  expect_true("claim-word" %in% lints(root, tier = 1:2)$rule)
})

test_that("review-3 #9: with tier given and a named rule outside it, a note says so", {
  root <- lint_proj(list("a.qmd" = "The largest sites are listed."))
  x <- lints(root, rules = "claim-word", tier = 1)
  expect_identical(nrow(x), 0L)
  expect_true(any(grepl("claim-word", attr(x, "notes"), fixed = TRUE)))
})

# ---- #10: speed ----------------------------------------------------------------------------------------------------------

test_that("review-3 #10: 2,000 inline values under value-constant lint cost under eight times as much as 500", {
  skip_on_cran()
  proj <- function(n, env = parent.frame()) {
    lint_proj(list("ch.qmd" = sprintf("Line %d has `r x[%d] * 100` here.", seq_len(n), seq_len(n))), env = env)
  }
  small <- proj(500L)
  large <- proj(2000L)
  x <- lints(large, rules = "value-constant", tier = 2)       # the first call warms caches
  expect_gte(nrow(x), 2000L)
  cpu <- function(root) {
    invisible(lints(root, rules = "value-constant", tier = 2))
    cpu_time_min(function() lints(root, rules = "value-constant", tier = 2), 3L)
  }
  # processor time, not wall clock: four times the values is four times the work if linear and
  # sixteen if quadratic. Measured 3.9.
  ratio <- cpu(large) / max(cpu(small), 0.01)
  expect_lt(ratio, 8)
})

# ---- #11: a multi-line paragraph over --- -----------------------------------------------------------------------------------

test_that("review-3 #11: a paragraph of two lines over --- is not a heading", {
  x <- lint_one(c("Para line one", "line two", "---", "", "After."), rules = "section-anchor")
  expect_identical(nrow(x), 0L)
  x <- lint_one(c("Para line one", "line two", "===", "", "After."), rules = "section-anchor")
  expect_identical(nrow(x), 0L)
})

test_that("review-3 #11: the --- under such a paragraph is not blanked from the prose, a one-line setext is a heading", {
  s <- read_src(c("Para line one", "line two", "---", "", "After."))
  expect_true(src_is_kept(s, "---"))
  x <- lint_one(c("Title", "---", "", "After."), rules = "section-anchor")
  expect_identical(x$text, "Title")
  x <- lint_one(c("Title", "=====", "", "After."), rules = "section-anchor")
  expect_identical(x$text, "Title")
})

# ---- #12: classes on code spans --------------------------------------------------------------------------------------------

test_that("review-3 #12: a highlighting class on a code span is never a name finding", {
  # cpp/cap, gap/cap, elm/em, nim/num, go/no and xul/ul are highlighting languages one edit from a weft class
  for (line in c("A `int x`{.cpp} here.", "A `x`{.gap} here.", "A `x`{.elm} here.", "A `x`{.nim} here.",
                 "A `x`{.go} here.", "A `x`{.xul} here.", "A `x`{.python} here.")) {
    expect_identical(nrow(lint_one(line, rules = "name")), 0L, info = line)
  }
})

test_that("review-3 #12: any other class one edit from a weft class is flagged on a code span, with or without a governor", {
  x <- lint_one("A `r x`{.nmu} here.", rules = "name")
  expect_identical(x$text, ".nmu")
  x <- lint_one("A `x`{.nmu} here.", rules = "name")
  expect_identical(x$text, ".nmu")
  x <- lint_one("A `r x`{.nmu n=\"k\"} here.", rules = "name")
  expect_identical(x$text, ".nmu")
})

# ---- #13: punctuation of two messages ------------------------------------------------------------------------------------------

test_that("review-3 #13: the unknown-rule message joins with a semicolon", {
  root <- lint_proj(list("a.qmd" = "Text."))
  e <- expect_error(lints(root, rules = "numerals"), class = "weft_lint_error")
  expect_match(conditionMessage(e), "Unknown rule: `numerals`; Did you mean `numeral`?", fixed = TRUE)
})

test_that("review-3 #13: dict-key with no near key has no stray full stop", {
  x <- lint_fixture(list("doc.qmd" = c3_para("`r dict$zzz`"), "dict.yml" = C3_DICT), rules = "dict-key")
  expect_identical(nrow(x), 1L)
  expect_match(x$message, "`dict$zzz` is not a key of dict.yml (rule 5.8.6).", fixed = TRUE)
  expect_no_match(x$message, ". (rule", fixed = TRUE)
})

# ---- Q1: block-start fires only where Pandoc's markdown reader cuts the paragraph ------------------------------------------------
# Checked with `quarto pandoc -f markdown -t json` on  "We saw [a site |" / <marker line> / "b]{n=\"k\"} today."
# and, for the fences, a closing fence line after the marker:
#   cuts the paragraph (span lost):  a closed backtick fence (```, ```r); a lone "-" (setext underline, makes
#                                    a Header); a lone "=" (setext underline); a ":   q" definition line
#   does NOT cut (one Para, span kept): "# sites", "#", "###### s", "> q", "- x", "+ x", "* x", "1. x", "12) x",
#                                    "1.", "1)", "(1) x", "i. x", "::: div", "::: {.x}", "~~~", "~~~ code" (also
#                                    closed), an unclosed ``` line, "$$" (also closed), "| a | b |" (also a whole
#                                    table), "    code", "* * *", "***", "___", "<div>"
# Pinned here (coordinator's ruling): a closed backtick fence, a lone "-" or "=", and a ":" definition line
# give a finding; every marker of the second group gives none. The fence finding's text is the fence (```).

bs3 <- function(mid, ...) lint_one(c("[a site |", mid, "b]{n=\"k\"}"), rules = "block-start", ...)

test_that("review-3 Q1: markers Pandoc's markdown reader does not cut at give no finding", {
  none <- c("# sites", "## sites", "###### sites", "#", "> quoted", "- item", "+ item", "* item", "1. item",
            "12) item", "123456789. item", "::: div", "::: {.x}", "~~~", "~~~ code", "``` code", "$$", "$$ x",
            "| a | b |", "    code")
  for (m in none) {
    for (e in c("qmd", "Rmd")) {
      expect_identical(nrow(bs3(m, ext = e)), 0L, info = paste(m, e))
    }
  }
})

test_that("review-3 Q1: a closed backtick fence inside a span is a finding at the opening line", {
  for (e in c("qmd", "Rmd")) {
    x <- lint_one(c("[a site |", "```", "code", "```", "b]{n=\"k\"}"), rules = "block-start", ext = e)
    expect_identical(nrow(x), 1L, info = e)
    expect_identical(x$line, 2L, info = e)
    expect_identical(x$text, "```", info = e)
  }
})

test_that("review-3 Q1: a lone '-' or '=' under a span line (setext underline) is a finding on its line", {
  for (m in c("-", "=")) {
    for (e in c("qmd", "Rmd")) {
      x <- bs3(m, ext = e)
      expect_identical(nrow(x), 1L, info = paste(m, e))
      expect_identical(x$line, 2L, info = paste(m, e))
      expect_identical(x$text, m, info = paste(m, e))
    }
  }
})

test_that("review-3 Q1: a definition line (':' then spaces then text) inside a span is a finding on its line", {
  for (m in c(":   q", ": q")) {
    x <- bs3(m)
    expect_identical(nrow(x), 1L, info = m)
    expect_identical(x$line, 2L, info = m)
    expect_identical(x$text, ":", info = m)
  }
})

test_that("review-3 Q1: the one-line and plain-word neighbours stay quiet", {
  expect_identical(nrow(lint_one("[a site | # sites]{n=\"k\"}", rules = "block-start")), 0L)
  expect_identical(nrow(bs3("plain words")), 0L)
  expect_identical(nrow(bs3("a - b")), 0L)
})

# ---- Q2: anchors in _ folders ---------------------------------------------------------------------------------------------------

test_that("review-3 Q2: an anchor in _includes/part.qmd resolves an xref in a top-level document", {
  x <- lint_fixture(list("_includes/part.qmd" = c("## Methods {#sec-methods}", "", "Text."),
                         "a.qmd" = c("# A {#sec-a}", "", "See @sec-methods.")),
                    rules = c("xref", "anchor-unused"))
  expect_none(x, "xref")
})

test_that("review-3 #Q2: no finding is reported with a file under a _ folder", {
  files <- list("_includes/part.qmd" = c("## Methods {#sec-methods}", "", "All sites are listed.",
                                         "[1]{.weft-literal}", "", "See @sec-zzz and `@sec-methods`.",
                                         "", "## No anchor"),
                "_partials/p.qmd" = c("All sites are listed.", "", "See @sec-yyy."),
                "a.qmd" = c("# A {#sec-a}", "", "See @sec-methods."))
  x <- lint_fixture(files)
  expect_false(any(grepl("^_", x$file)))
})

test_that("review-3 Q2: _site, _book, _freeze and _extensions stay unread for anchors", {
  for (d in c("_site", "_book", "_freeze", "_extensions")) {
    x <- lint_fixture(setNames(list(c("## Hidden {#sec-hidden}", "", "Text."), c("# A {#sec-a}", "", "See @sec-hidden.")),
                               c(paste0(d, "/p.qmd"), "a.qmd")),
                      rules = "xref")
    expect_identical(sum(x$rule == "xref"), 1L, info = d)
    expect_false(any(grepl("^_", x$file)), info = d)
  }
})

# ---- Q3: file-link to a rendered output whose source is beside it ---------------------------------------------------------------------

test_that("review-3 Q3: a link to other.html passes when other.qmd, .Rmd or .md exists beside it", {
  for (src in c("other.qmd", "other.Rmd", "other.md")) {
    x <- lint_fixture(setNames(list("Text.", c("See [the other page](other.html).")), c(src, "a.qmd")),
                      rules = "file-link")
    expect_identical(nrow(x), 0L, info = src)
  }
})

test_that("review-3 Q3: a link to an html page with no source, and to a missing csv, are still findings", {
  x <- lint_fixture(list("a.qmd" = "See [x](nowhere.html) and [y](data/x.csv)."), rules = "file-link")
  expect_setequal(x$text, c("nowhere.html", "data/x.csv"))
})

# ---- Q4: section-anchor in callouts and tabsets --------------------------------------------------------------------------------------------

test_that("review-3 Q4: a heading inside a callout or a panel-tabset div is not a section", {
  lines <- c("# Top {#sec-top}", "",
             "::: {.callout-tip}", "## Tip with a title", "", "Body.", ":::", "",
             "::: {.panel-tabset}", "## Tab A", "", "One.", "", "## Tab B", "", "Two.", ":::", "")
  expect_identical(nrow(lint_one(lines, rules = "section-anchor")), 0L)
})

test_that("review-3 Q4: a heading after the div closes, and a plain one, are findings", {
  lines <- c("::: {.callout-tip}", "## Tip with a title", "", "Body.", ":::", "", "## Real section", "", "Text.")
  x <- lint_one(lines, rules = "section-anchor")
  expect_identical(nrow(x), 1L)
  expect_identical(x$line, 7L)
  x <- lint_one(c("## Plain", "", "Text."), rules = "section-anchor")
  expect_identical(nrow(x), 1L)
})

# ---- Q5: inert-check on conditions that vary ---------------------------------------------------------------------------------------------------

test_that("review-3 Q5: a condition with a call other than operators is not inert", {
  for (cond in c("knitr::is_html_output()", "interactive()", "!interactive()", "is_html()")) {
    x <- lint_one(sprintf("A [text]{if=\"%s\"} here.", cond), rules = "inert-check")
    expect_identical(nrow(x), 0L, info = cond)
  }
})

test_that("review-3 Q5: a condition of constants and operators is still inert", {
  for (cond in c("TRUE", "!TRUE", "(TRUE)", "1 > 0", "TRUE && FALSE")) {
    # .Rmd: a .qmd with no knitr is the filter's, where a literal against a literal is E4 (N143)
    x <- lint_one(sprintf("A [text]{if=\"%s\"} here.", cond), rules = "inert-check", ext = "Rmd")
    expect_identical(nrow(x), 1L, info = cond)
  }
})

# ---- S1: recall_check() credits a flag in a chunk option by its lines ---------------------------------------------------------------------------------

test_that("review-3 S1: a quote that is a figure caption in a chunk option is reproduced when figure flags the chunk", {
  src <- lint_proj(list("a.qmd" = c("Intro words.", "", "```{r}", "#| label: fig-d",
                                    "#| fig-cap: \"Depth of the lake in the summer months\"", "plot(1)", "```")))
  f <- data.frame(id = "f1", quote = "Depth of the lake in the summer months", file = NA_character_,
                  line = NA_integer_, rule = "figure", stringsAsFactors = FALSE)
  r <- recall_check(f, src, rules = "figure")
  row <- r[r$rule == "figure", ]
  expect_equal(row$located, 1)
  expect_equal(row$reproduced, 1)
})

test_that("review-3 S1: a complete figure chunk is not flagged, so its caption is not reproduced", {
  src <- lint_proj(list("a.qmd" = c("Intro words.", "", "```{r}", "#| label: fig-d",
                                    "#| fig-cap: \"Depth of the lake in the summer months\"",
                                    "#| fig-alt: \"A plot\"", "plot(1)", "```")))
  f <- data.frame(id = "f1", quote = "Depth of the lake in the summer months", file = NA_character_,
                  line = NA_integer_, rule = "figure", stringsAsFactors = FALSE)
  r <- recall_check(f, src, rules = "figure")
  expect_equal(r[r$rule == "figure", ]$reproduced, 0)
})

test_that("review-3 S1: the same when the caption sits in the chunk header, on the flagged line", {
  src <- lint_proj(list("a.qmd" = c("Intro words.", "", "```{r fig-d, fig.cap=\"Depth of the lake in the summer months\"}",
                                    "plot(1)", "```")))
  f <- data.frame(id = "f1", quote = "Depth of the lake in the summer months", file = NA_character_,
                  line = NA_integer_, rule = "figure", stringsAsFactors = FALSE)
  r <- recall_check(f, src, rules = "figure")
  expect_equal(r[r$rule == "figure", ]$reproduced, 1)
})

# ---- S2: numeral_years --------------------------------------------------------------------------------------------------------------------------------

test_that("review-3 S2: under numeral_years a year range, a decade and a possessive are years", {
  for (w in c("2016-17", "2016-2017", "2010s", "2019's")) {
    line <- sprintf("It was warm in %s again.", w)
    x <- lint_one(line, rules = "numeral", weft_yml = "numeral_years: true")
    expect_identical(nrow(x), 0L, info = w)
  }
})

test_that("review-3 S2: without the setting they are findings", {
  for (w in c("2016-17", "2016-2017", "2010s", "2019's")) {
    line <- sprintf("It was warm in %s again.", w)
    x <- lint_one(line, rules = "numeral")
    expect_gte(nrow(x), 1L, label = w)
  }
})

test_that("review-3 S2: a real number after a year range is still flagged", {
  line <- "From 2016-17 there were 14 sites."
  x <- lint_one(line, rules = "numeral", weft_yml = "numeral_years: true")
  expect_identical(x$text, "14")
  expect_identical(x$col, r3_col(line, "14"))
  x <- lint_one("In the 2010s there were 14 sites, said 2019's report.", rules = "numeral",
                weft_yml = "numeral_years: true")
  expect_identical(x$text, "14")
})

# ---- S3: xref-code in a multi-line HTML comment with a blank line and an indented line -------------------------------------------------------------------

test_that("review-3 S3: xref-code does not fire inside a multi-line comment holding a blank and an indented line", {
  lines <- c("# A {#sec-a}", "", "<!-- Superseded: `@sec-b` is gone", "     and so on.", "",
             "       1  first item", "", "       2  second item -->", "", "After.")
  d <- lint_proj(list("a.qmd" = lines))
  x <- lints(d, rules = "xref-code", tier = 2)
  expect_identical(nrow(x), 0L)
})

test_that("review-3 S3: the same code span outside a comment is still a finding", {
  x <- lint_one(c("# A {#sec-a}", "", "Write `@sec-b` for it.", "", "<!-- `@sec-c` -->"),
                rules = "xref-code", tier = 2)
  expect_identical(nrow(x), 1L)
  expect_identical(x$line, 3L)
})

# ---- extra: a paragraph over 10 KB ----------------------------------------------------------------

r3_long_sentences <- function() {
  s <- paste0("Site ", seq_len(600), " was sampled.")
  s[100] <- "The largest value was always 4321 here."
  s
}

test_that("review-3 extra: a single paragraph over 10 KB lints without error and finds the numeral and claim word", {
  for (lines in list(paste(r3_long_sentences(), collapse = " "),
                     strsplit(paste(r3_long_sentences(), collapse = " "), "(?<=\\.) (?=Site 1[0-9]0 )", perl = TRUE)[[1]])) {
    expect_gt(sum(nchar(lines, "bytes")), 10000L)
    root <- lint_proj(list("a.qmd" = lines))
    x <- expect_no_error(lints(root, tier = 1:2))
    expect_true("claim-word" %in% x$rule)
    expect_true("numeral" %in% x$rule)
    expect_true(any(grepl("always", x$text[x$rule == "claim-word"], fixed = TRUE)))
    expect_true(any(grepl("4321", x$text[x$rule == "numeral"], fixed = TRUE)))
  }
})

test_that("review-3 extra: a 12 KB line inside a pipe table row and inside a list item lints without error", {
  long <- paste(rep("word", 2400), collapse = " ")
  expect_gt(nchar(long), 10000L)
  tbl <- c("| a | b |", "|---|---|", paste0("| ", long, " | 2 |"))
  expect_no_error(lints(lint_proj(list("a.qmd" = tbl)), tier = 1:2))
  lst <- c("- first", paste0("- ", long), "- third")
  expect_no_error(lints(lint_proj(list("a.qmd" = lst)), tier = 1:2))
})
