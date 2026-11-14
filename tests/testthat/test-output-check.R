# Package 7d: the rendered-output check, driven through plain Pandoc (dev/design-7.md section 2.D, N50 to N59;
# section 5 "test-output-check.R"). The filter is inst/quarto/weft-output.lua, run last. Plain Pandoc is not
# Quarto, so N52 (unresolved references) does not apply here and is pinned in test-output-quarto.R.
#
# READINGS (the design is silent or loose):
#  - a finding's `text` for a missing value is the token after the leading and trailing punctuation is
#    removed ("NA", not "NA." or "(NA)"); for a unicode minus it is the token as printed ("\u2212Inf");
#  - `file` is the document as Pandoc was given it, so it ends in "doc.md";
#  - an excerpt is the whole stringified block when it is short; when it is cut, "..." marks each cut end and
#    the whole is at most 86 characters (80 and the two markers);
#  - the stderr report of N56 counts every finding, `fail` and `warn`, in its heading "weft: %d problem(s) in
#    the rendered output of <file> (<format>)", and lists one entry each, as the post-render script does, with
#    the excerpt on the next line, indented six spaces; the section part of the entry is left out when empty;
#  - a setting is written bare in _weft.yml: `output_missing: off`;
#  - `{#` and `{.` are tested in prose and table cells on a Str of Pandoc's tree (`word{.x}`);
#  - the tests that need a text weft-check.lua would itself fail on (`word{.x}`) run the output filter alone.
# Every test fails while inst/quarto/weft-output.lua is missing (filter_md() records the missing file).

MD_NA <- c("## Results {#results}", "", "The mean was NA here.")
KIND_MISSING <- "missing value in output"
KIND_MARKUP <- "leftover markup"
H_NA <- function(n = 1L, file = "doc\\.md", fmt = "html")
  sprintf("^weft: %d problem%s in the rendered output of \\S*%s \\(%s\\)$", n, if (n == 1L) "" else "s", file, fmt)

# ---- N53: each token ----------------------------------------------------------------------------------

test_that("N53: each of the eight tokens in prose is one finding of kind 'missing value in output'", {
  toks <- c("NA", "NaN", "nan", "Inf", "-Inf", "\u2212Inf", "inf", "-inf")
  md <- unlist(lapply(seq_along(toks), function(i) o7_sec(paste0("t", i), paste("Value", toks[i], "here."))))
  res <- o7_run(md)
  expect_identical(res$status, 0L)
  expect_identical(sort(o7_texts(res)), sort(toks))
  expect_true(all(o7_kinds(res) == KIND_MISSING))
  expect_true(all(o7_field(res, "level") == "warn"))
})

test_that("N53: punctuation attached to the token is removed; each variant is a finding with the token as text", {
  variants <- c("NA.", "NA,", "NA;", "NA:", "NA!", "NA?", "(NA)", "[NA]", "NA%", "\\\"NA\\\"", "\\'NA\\'",
                "\u201cNA\u201d", "\u2018NA\u2019", "(NA),", "[NA];")
  md <- unlist(lapply(seq_along(variants), function(i) o7_sec(paste0("v", i), paste("Value", variants[i], "here."))))
  res <- o7_run(md)
  expect_length(res$findings, length(variants))
  expect_true(all(o7_texts(res) == "NA"))
  expect_setequal(o7_field(res, "section"), paste0("v", seq_along(variants)))
})

test_that("N53: a token must be the whole word: other spellings and look-alikes are not findings", {
  md <- c("## Words {#words}", "",
          "Na N/A NULL None missing Nan Information banana NAs NA-like Infinity.")
  res <- o7_run(md, pre = character())
  expect_identical(res$status, 0L)
  expect_length(res$findings, 0L)
  # the control: the same document with one real token is a finding
  res2 <- o7_run(c(md, "", "Then NA."))
  expect_length(res2$findings, 1L)
})

# ---- N53: where it applies ----------------------------------------------------------------------------

test_that("N53: it applies in every prose container named by the design", {
  md <- c("# Top {#top}", "",
          "## HEAD has NA {#hx}", "",
          o7_sec("c1", "Container PARA has NA here."),
          o7_sec("c2", "- PLAIN has NA here.\n- other"),
          o7_sec("c3", "- LISTITEM has NA here.\n\n- other"),
          o7_sec("c4", "> QUOTE has NA here."),
          o7_sec("c5", "Term\n: DEFLIST has NA here."),
          o7_sec("c6", "| LINEBLOCK has NA here."),
          o7_sec("c7", "Some text.[^n1]\n\n[^n1]: FOOTNOTE has NA here."),
          o7_sec("c8", "![Caption FIGCAP has NA](x.png)"),
          o7_sec("c9", "| h |\n|---|\n| c |\n\n: Caption TABCAP has NA"))
  res <- o7_run(md)
  expect_identical(res$status, 0L)
  for (key in c("HEAD", "PARA", "PLAIN", "LISTITEM", "QUOTE", "DEFLIST", "LINEBLOCK", "FOOTNOTE", "FIGCAP", "TABCAP")) {
    f <- o7_by_excerpt(res, key)
    expect_false(is.null(f), label = paste("a finding for", key))
    if (!is.null(f)) {
      expect_identical(f$text, "NA", label = key)
      expect_identical(f$kind, KIND_MISSING, label = key)
    }
  }
  expect_length(res$findings, 10L)
})

test_that("N53: it does not apply in a table cell, code, math, raw content, a link target or a literal", {
  md <- c(
    o7_sec("e1", "| h |\n|---|\n| NA |"),
    o7_sec("e2", "Inline `NA` code."),
    o7_sec("e3", "```\nNA\n```"),
    o7_sec("e4", "Math $NA$ here."),
    o7_sec("e5", "Raw `NA`{=html} inline."),
    o7_sec("e6", "```{=html}\n<p>NA</p>\n```"),
    o7_sec("e7", "[see](https://example.org/NA)"),
    o7_sec("e8", "A [NA]{.weft-literal why=\"an abbreviation\"} span."),
    o7_sec("e9", "::: {.weft-literal why=\"an abbreviation\"}\nNA is here.\n\nNA again, in a second paragraph.\n\n- NA in a list\n:::"),
    o7_sec("e10", "A [**NA**]{.weft-literal why=\"nested\"} span."),
    o7_sec("e11", "CONTROL has NA here."))
  res <- o7_run(md)
  expect_identical(res$status, 0L)
  expect_length(res$findings, 1L)
  if (length(res$findings)) {
    expect_true(grepl("CONTROL", res$findings[[1]]$excerpt, fixed = TRUE))
    expect_identical(res$findings[[1]]$section, "e11")
  }
})

test_that("N53: a literal exempts only its own content: the same word beside it is still a finding", {
  md <- o7_sec("l1", "[NA]{.weft-literal why=\"an abbreviation\"} and NA again.")
  res <- o7_run(md)
  expect_length(res$findings, 1L)
  md2 <- o7_sec("l2", "::: {.weft-literal why=\"x\"}\nNA\n:::", "AFTER has NA.")
  res2 <- o7_run(md2)
  expect_length(res2$findings, 1L)
  if (length(res2$findings)) expect_true(grepl("AFTER", res2$findings[[1]]$excerpt, fixed = TRUE))
})

# ---- N54: leftover markup -----------------------------------------------------------------------------

test_that("N54: a fence Pandoc did not read, `{#` and `{.` touching text, in prose and in a table cell", {
  md <- c(o7_sec("m1", "FENCE para\n::: here\nmore"),
          o7_sec("m2", "HASH has word{#id} here."),
          o7_sec("m3", "DOT has word{.cls} here."),
          o7_sec("m4", "| h |\n|---|\n| CELL x{.num} |"))
  res <- o7_run(md, pre = character())
  expect_identical(res$status, 1L)
  expect_length(res$findings, 4L)
  expect_true(all(o7_kinds(res) == KIND_MARKUP))
  expect_true(all(o7_field(res, "level") == "fail"))
  for (key in c("FENCE", "HASH", "DOT", "CELL")) {
    expect_false(is.null(o7_by_excerpt(res, key)), label = key)
  }
})

test_that("N54: `{#` is caught after weft.lua and weft-check.lua too (they do not catch it)", {
  res <- o7_run(o7_sec("m5", "HASH has word{#id} here."))
  expect_length(res$findings, 1L)
  expect_identical(res$findings[[1]]$kind, KIND_MARKUP)
  expect_identical(res$status, 1L)
})

test_that("N54: not for `]{.x}`, `{ .x`, braces after a space, a digit after the dot, or code", {
  md <- c(o7_sec("n1", "NEG1 \\[a\\]{.x} here."),
          o7_sec("n2", "NEG2 { .x} here."),
          o7_sec("n3", "NEG3 a {.y} z."),
          o7_sec("n4", "NEG4 `code{.x}` here."),
          o7_sec("n5", "```\nblock{.x} and block{#y}\n```"),
          o7_sec("n6", "NEG6 z{.5} and z{#9} here."),
          o7_sec("n7", "CONTROL word{.cls} here."))
  res <- o7_run(md, pre = character())
  expect_length(res$findings, 1L)
  if (length(res$findings)) {
    expect_true(grepl("CONTROL", res$findings[[1]]$excerpt, fixed = TRUE))
    expect_identical(res$findings[[1]]$kind, KIND_MARKUP)
  }
})

test_that("N52: plain Pandoc is not Quarto, so a bold '?meta:nosuch' or '?var:x' is not a finding", {
  md <- c("## Notes {#notes}", "", "A **?meta:nosuch** and a **?var:x** here.")
  res <- o7_run(md)
  expect_identical(res$status, 0L)
  expect_length(res$findings, 0L)
})

# ---- N55: the record ----------------------------------------------------------------------------------

test_that("N55: a finding is exactly {source, kind, level, file, format, section, text, excerpt}", {
  res <- o7_run(c("## Results {#results}", "", "The mean\nwas NA here."))
  expect_length(res$findings, 1L)
  f <- res$findings[[1]]
  expect_setequal(names(f), c("source", "kind", "level", "file", "format", "section", "text", "excerpt"))
  expect_identical(f$source, "output")
  expect_identical(f$kind, KIND_MISSING)
  expect_identical(f$level, "warn")
  expect_identical(f$format, "html")
  expect_identical(f$section, "results")
  expect_identical(f$text, "NA")
  expect_identical(f$excerpt, "The mean was NA here.")
  expect_match(f$file, "doc\\.md$")
})

test_that("N55: the section is the last heading above, and empty before any heading", {
  md <- c("Before NA any heading.", "", "# One {#one}", "", "In one: Inf.", "", "## Two {#two}", "", "In two: inf.")
  res <- o7_run(md)
  sec <- stats::setNames(o7_field(res, "section"), o7_texts(res))
  expect_identical(unname(sec[["NA"]]), "")
  expect_identical(unname(sec[["Inf"]]), "one")
  expect_identical(unname(sec[["inf"]]), "two")
})

test_that("N55: one finding per distinct (kind, text, section)", {
  md <- c(o7_sec("a1", "NA here and NA again.", "And NA once more.", "Then NaN."),
          o7_sec("a2", "NA in another section."))
  res <- o7_run(md)
  key <- paste(o7_kinds(res), o7_texts(res), o7_field(res, "section"))
  expect_length(res$findings, 3L)
  expect_setequal(key, c(paste(KIND_MISSING, "NA", "a1"), paste(KIND_MISSING, "NaN", "a1"),
                         paste(KIND_MISSING, "NA", "a2")))
})

test_that("N55: an excerpt is cut to about 80 characters with '...' around the token", {
  pad <- function(n, w = "word") paste(rep(w, n), collapse = " ")
  mid <- o7_run(o7_sec("x1", paste(pad(20), "NA", pad(20))))
  head <- o7_run(o7_sec("x2", paste("NA", pad(40))))
  tail <- o7_run(o7_sec("x3", paste(pad(40), "NA")))
  e <- function(r) if (length(r$findings)) r$findings[[1]]$excerpt else NA_character_
  expect_true(grepl(" NA ", e(mid), fixed = TRUE))
  expect_true(startsWith(e(mid), "..."))
  expect_true(endsWith(e(mid), "..."))
  expect_lte(nchar(e(mid)), 86L)
  expect_gte(nchar(e(mid)), 40L)
  expect_false(startsWith(e(head), "..."))
  expect_true(endsWith(e(head), "..."))
  expect_true(startsWith(e(head), "NA word"))
  expect_lte(nchar(e(head)), 86L)
  expect_true(startsWith(e(tail), "..."))
  expect_false(endsWith(e(tail), "..."))
  expect_true(endsWith(e(tail), "word NA"))
  expect_lte(nchar(e(tail)), 86L)
})

test_that("N55: the format is the writer's: html, latex, typst and plain", {
  for (to in c("html", "latex", "typst", "plain")) {
    res <- o7_run(MD_NA, to = to)
    expect_length(res$findings, 1L)
    if (length(res$findings)) expect_identical(res$findings[[1]]$format, to, label = to)
  }
})

# ---- N56: reporting with no collection file ------------------------------------------------------------

test_that("N56: a warned finding alone: the report is on stderr under E25, and the exit status is 0", {
  res <- filter_md_post(MD_NA)
  expect_identical(res$status, 0L)
  expect_true(any(grepl(H_NA(1L), fm_lines(res$stderr))), label = res$stderr)
  e <- fm_entry(res$stderr, "\\[missing value in output\\] NA$")
  expect_true(e$found)
  expect_match(e$head, "^  \\S*doc\\.md( #results)? \\(html\\)  \\[missing value in output\\] NA$")
  expect_identical(e$detail, "The mean was NA here.")
})

test_that("N56: a fail finding exits 1; the heading counts every finding, fail and warn", {
  md <- c(MD_NA, "", "And word{#id} here.")
  res <- filter_md_post(md)
  expect_identical(res$status, 1L)
  expect_true(any(grepl(H_NA(2L), fm_lines(res$stderr))), label = res$stderr)
  e <- fm_entry(res$stderr, "\\[leftover markup\\] ")
  expect_true(e$found)
  expect_match(e$head, "^  \\S*doc\\.md( #results)? \\(html\\)  \\[leftover markup\\] ")
  expect_match(paste(e$detail, collapse = " "), "word{#id}", fixed = TRUE)
})

test_that("N56: in draft mode (WEFT_DRAFT, or draft: true) a fail finding is reported and the exit is 0", {
  md <- c("## S {#s}", "", "A word{#id} here.")
  for (r in list(filter_md_post(md, env = c(WEFT_DRAFT = "1")),
                 filter_md_post(md, weft_yml = "draft: true"))) {
    expect_identical(r$status, 0L)
    expect_true(any(grepl(H_NA(1L), fm_lines(r$stderr))), label = r$stderr)
  }
  # the control: the same document without draft mode fails
  expect_identical(filter_md_post(md)$status, 1L)
})

test_that("N56: nothing found: no report, exit 0, no output log", {
  res <- o7_run(c("## S {#s}", "", "A clean paragraph with 12 sites."))
  expect_identical(res$status, 0L)
  expect_false(any(grepl("rendered output", res$stderr, fixed = TRUE)))
  expect_length(res$findings, 0L)
  expect_length(res$log, 0L)
})

test_that("N56: with the collection file open, each finding is a JSON line in it and the filter does not exit", {
  md <- c(MD_NA, "", "And word{#id} here.")
  res <- filter_md_post(md, collect = TRUE)
  expect_identical(res$status, 0L)
  recs <- o7_parse(res$collected)
  expect_length(recs, 2L)
  expect_setequal(vapply(recs, function(f) f$kind, ""), c(KIND_MISSING, KIND_MARKUP))
  expect_setequal(vapply(recs, function(f) f$level, ""), c("warn", "fail"))
  # the report is the post-render script's to print, not the filter's
  expect_false(any(grepl("rendered output", res$stderr, fixed = TRUE)))
})

test_that("N56: the collection file keeps what was in it and gains the findings after it", {
  seed <- "{\"weft\":\"run\",\"run\":\"r1\"}"
  res <- filter_md_post(MD_NA, collect = seed)
  expect_identical(res$collected[1], seed)
  expect_length(o7_parse(res$collected), 1L)
})

# ---- N57: WEFT_OUTPUT_LOG -------------------------------------------------------------------------------

test_that("N57: WEFT_OUTPUT_LOG receives one JSON line per finding", {
  md <- c(MD_NA, "", o7_sec("two", "Inf here and word{#id} there."))
  res <- o7_run(md, env = c(WEFT_DRAFT = "1"))
  expect_length(res$log, 3L)
  expect_length(res$findings, 3L)
  expect_setequal(o7_texts(res)[o7_kinds(res) == KIND_MISSING], c("NA", "Inf"))
})

test_that("N57: the log is written alongside the collection file, with the same records", {
  res <- o7_run(MD_NA, collect = TRUE)
  expect_identical(res$status, 0L)
  expect_length(res$findings, 1L)
  expect_identical(res$findings, o7_parse(res$collected))
})

test_that("N57: the log is appended to, not replaced", {
  log <- withr::local_tempfile(fileext = ".jsonl")
  writeLines("{\"source\":\"output\",\"kind\":\"earlier\"}", log)
  filter_md_post(MD_NA, env = c(WEFT_OUTPUT_LOG = log))
  lines <- readLines(log, warn = FALSE)
  expect_length(lines, 2L)
  expect_match(lines[1], "earlier", fixed = TRUE)
})

test_that("N57: with no WEFT_OUTPUT_LOG nothing is written and the findings are still reported", {
  res <- filter_md_post(MD_NA)
  expect_identical(res$status, 0L)
  expect_true(any(grepl(H_NA(1L), fm_lines(res$stderr))))
})

# ---- N51: the three settings --------------------------------------------------------------------------

test_that("N51: output_missing: off, warn and fail; the default is warn", {
  d <- o7_run(MD_NA)
  expect_identical(d$findings[[1]]$level, "warn")
  expect_identical(d$status, 0L)
  off <- o7_run(MD_NA, weft_yml = "output_missing: off")
  expect_length(off$findings, 0L)
  expect_identical(off$status, 0L)
  expect_false(any(grepl("rendered output", off$stderr, fixed = TRUE)))
  warn <- o7_run(MD_NA, weft_yml = "output_missing: warn")
  expect_identical(warn$findings[[1]]$level, "warn")
  expect_identical(warn$status, 0L)
  fail <- o7_run(MD_NA, weft_yml = "output_missing: fail")
  expect_identical(fail$findings[[1]]$level, "fail")
  expect_identical(fail$status, 1L)
})

test_that("N51: output_markup: off, warn and fail; the default is fail", {
  md <- c("## S {#s}", "", "A word{#id} here.")
  d <- o7_run(md)
  expect_identical(d$findings[[1]]$level, "fail")
  expect_identical(d$status, 1L)
  off <- o7_run(md, weft_yml = "output_markup: off")
  expect_length(off$findings, 0L)
  expect_identical(off$status, 0L)
  warn <- o7_run(md, weft_yml = "output_markup: warn")
  expect_identical(warn$findings[[1]]$level, "warn")
  expect_identical(warn$status, 0L)
  fail <- o7_run(md, weft_yml = "output_markup: fail")
  expect_identical(fail$findings[[1]]$level, "fail")
  expect_identical(fail$status, 1L)
})

test_that("N51: a setting turns off only its own check", {
  md <- c(MD_NA, "", "And word{#id} here.")
  a <- o7_run(md, weft_yml = "output_missing: off")
  expect_identical(o7_kinds(a), KIND_MARKUP)
  b <- o7_run(md, weft_yml = "output_markup: off")
  expect_identical(o7_kinds(b), KIND_MISSING)
})

test_that("N51: the document's weft: mapping wins over _weft.yml", {
  md <- c("---", "title: t", "weft:", "  output_missing: off", "---", "", MD_NA)
  res <- o7_run(md, weft_yml = "output_missing: fail")
  expect_length(res$findings, 0L)
  expect_identical(res$status, 0L)
  md2 <- c("---", "title: t", "weft:", "  output_missing: fail", "---", "", MD_NA)
  res2 <- o7_run(md2, weft_yml = "output_missing: off")
  expect_identical(res2$findings[[1]]$level, "fail")
})

test_that("N51: a wrong value is reported once (E33) and the default is used", {
  res <- o7_run(MD_NA, weft_yml = "output_missing: sometimes", pre = character())
  expect_identical(sum(grepl("output_missing: sometimes", fm_lines(res$stderr), fixed = TRUE)), 1L)
  expect_length(res$findings, 1L)
  expect_identical(res$findings[[1]]$level, "warn")
})

# ---- the document is left as it is ---------------------------------------------------------------------

test_that("N50: the filter reports and changes nothing in the document", {
  md <- c(MD_NA, "", "And word{#id} here.", "", "| h |", "|---|", "| NA |", "", "`NA`")
  with <- filter_md_post(md, env = c(WEFT_DRAFT = "1"))
  without <- filter_md(md, env = c(WEFT_DRAFT = "1"))
  expect_identical(with$status, 0L)
  expect_gt(nchar(with$output), 0L)
  expect_identical(with$output, without$output)
})

test_that("N50: a document with no findings passes through all three filters unchanged", {
  md <- c("## S {#s}", "", "Plain text, 12 sites.")
  expect_identical(filter_md_post(md)$output, filter_md(md)$output)
})

# ---- the messages E23 and E24, and the Quarto-only pattern -----------------------------------------------------

# READING: the design says "Detail E23" / "Detail E24" without saying where the detail is printed; the stderr
# report of N56 is the only text of the filter that a test can read in plain Pandoc, so the detail is looked for
# there, anywhere in the report, with %s filled by the finding's `text`.
test_that("E23: the stderr report carries the missing-value message with the token filled in", {
  res <- filter_md_post(MD_NA)
  want <- "\"NA\" in the rendered prose: a value printed as missing. Mark a deliberate one [NA]{.weft-literal why=\"...\"} (rule 2.5.5)."
  expect_true(any(grepl(want, fm_lines(res$stderr), fixed = TRUE)), label = res$stderr)
})

test_that("E24: the stderr report carries the leftover-markup message with the text filled in", {
  res <- filter_md_post(c("## S {#s}", "", "A word{#id} here."), pre = character())
  want <- "\"word{#id}\" in the rendered text: markup that Pandoc did not read (rule 2.5.5)."
  expect_true(any(grepl(want, fm_lines(res$stderr), fixed = TRUE)), label = res$stderr)
})

test_that("N54: `\\@ref(` is bookdown syntax Quarto never resolves, so it is a finding only under Quarto: not in plain Pandoc", {
  res <- o7_run(o7_sec("r1", "See \\\\@ref(fig:x) for the figure."))
  expect_identical(res$status, 0L)
  expect_length(res$findings, 0L)
})
