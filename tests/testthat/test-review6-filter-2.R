# Package 6L, part 2: the filter's review fixes (dev/review-stage6.md, findings 9 to 20, and open findings
# 11, 14 and 15 of dev/open-findings.md). Written from the review and its rulings only. Plain Pandoc through
# filter_md() (helper-filter.R, helper-6f.R, helper-6g.R, helper-review6.R); one Quarto render for open
# finding 11. Every test is labelled with its finding. Controls that hold today are marked "control".
# ASCII only: non-ASCII is written as \u escapes. Part 1 is test-review6-filter.R.
#
# Where a ruling leaves the exact message open, these tests assert the behaviour (status, marker kind,
# the absence of the wrong text) and not the wording.

V2 <- "<<weft: value error, line {L}>>"

r6_list <- function(elems, keys = NULL, of = "float") {
  sprintf('{"t":"list","v":[%s],"of":"%s","keys":%s}', paste(elems, collapse = ","), of,
          if (is.null(keys)) "null" else paste0("[", paste(vapply(keys, jstr, ""), collapse = ","), "]"))
}

# ---- 9: doc.knit.md beside doc.Rmd ----------------------------------------------------------------------------

R6_RMD <- c("---", "title: t", "---", "", "```{r}", "x <- 1", "y <- 2", "z <- 3", "```", "",
            "A `nope`{.num} z.")

test_that("review-6 #9: doc.knit.md beside doc.Rmd reports the .Rmd with its line, and writes stamp and ledger for it", {
  md <- c("---", "title: t", "---", "", carrier(depth = fr_float("1.5")), "", "A `nope`{.num} z.")
  res <- filter_md(md, name = "doc.knit.md", files = list(doc.Rmd = R6_RMD), weft_yml = "draft: false",
                   env = c(WEFT_DRAFT = "1", WEFT_RUN = "RUN9"), to = "plain")
  expect_identical(res$status, 0L)
  expect_true(grepl("doc.Rmd:11  [no value]", res$stderr, fixed = TRUE), label = "the report names doc.Rmd, line 11")
  expect_false(grepl("doc.knit.md", res$stderr, fixed = TRUE), label = "the report never names doc.knit.md")
  expect_true(grepl("<<weft: no value, line 11>>", res$output, fixed = TRUE), label = "the marker holds the .Rmd's line")
  expect_true(".weft/stamps/doc.Rmd.json" %in% names(res$files), label = "a stamp under the .Rmd's name")
  expect_false(any(grepl("knit.md", names(res$files), fixed = TRUE)), label = "nothing is written under doc.knit.md")
  s <- g6_stamp(res, ".weft/stamps/doc.Rmd.json")
  expect_identical(s$source, "doc.Rmd")
  expect_true(any(grepl("^_weft/ledger/doc\\.Rmd/", names(res$files))), label = "a ledger under the .Rmd's name")
})

test_that("review-6 #9: doc.knit.md beside doc.Rmarkdown is mapped to the .Rmarkdown", {
  md <- c("---", "title: t", "---", "", carrier(depth = fr_float("1.5")), "", "A `nope`{.num} z.")
  res <- filter_md(md, name = "d2.knit.md", files = list(d2.Rmarkdown = R6_RMD), weft_yml = "draft: false",
                   env = c(WEFT_DRAFT = "1", WEFT_RUN = "RUN9"), to = "plain")
  expect_true(grepl("d2.Rmarkdown:11  [no value]", res$stderr, fixed = TRUE))
  expect_true(".weft/stamps/d2.Rmarkdown.json" %in% names(res$files))
  expect_false(any(grepl("knit.md", names(res$files), fixed = TRUE)))
})

test_that("review-6 #9 control: a .knit.md with no .Rmd beside it stays its own source", {
  md <- c("---", "title: t", "---", "", "A `nope`{.num} z.")
  res <- filter_md(md, name = "solo.knit.md", weft_yml = "draft: false",
                   env = c(WEFT_DRAFT = "1", WEFT_RUN = "RUN9"), to = "plain")
  expect_true(grepl("solo.knit.md:5  [no value]", res$stderr, fixed = TRUE))
})

# ---- 10: a frozen knitr document keeps its recorded failures ---------------------------------------------------

R6_OLD_FAILURE <- paste0("{\"source\":\"knit\",\"kind\":\"failed claim\",\"file\":\"doc.qmd\",\"line\":3,",
                         "\"chunk\":null,\"expr\":\"x\",\"detail\":\"d\",\"hint\":null,\"option\":null,\"chunk_line\":null}")
r6_old_stamp <- function() {
  c("{", "  \"source\": \"doc.qmd\",", "  \"run\": \"R0\",", "  \"executed\": \"2026-11-01 10:00:00\",",
    "  \"checks\": 5,", "  \"failures\": [", paste0("    ", R6_OLD_FAILURE), "  ],",
    "  \"writers\": [\"knit\", \"filter\"],", "  \"named\": 1,", "  \"fresh\": null", "}")
}

test_that("review-6 #10: a knitr document with an old stamp of another run keeps its knit failures, checks and executed", {
  md <- c("```{r}", "x <- 1", "```", "", g6_block(x = fr_float("2.5"), run = "R0", at = 1794822900L), "",
          "Value `x`{.num}.")
  res <- filter_md(md, name = "doc.qmd", files = list(".weft/stamps/doc.qmd.json" = r6_old_stamp()),
                   weft_yml = "draft: false", env = c(WEFT_RUN = "R1", WEFT_DRAFT = "1"), to = "plain")
  expect_identical(res$status, 0L)
  s <- g6_stamp(res, ".weft/stamps/doc.qmd.json")
  expect_identical(s$run, "R1")
  src <- vapply(s$failures, function(f) fm_or(f$source, ""), "")
  det <- vapply(s$failures, function(f) fm_or(f$detail, ""), "")
  expect_true(any(src == "knit" & det == "d"), label = "the knit failure is kept")
  expect_gte(s$checks, 5)
  expect_identical(s$executed, "2026-11-01 10:00:00")
})

# ---- 12: .val with a text or collapse class treats published text as data ----------------------------------------

test_that("review-6 #12: .val with .cap, .strong, .em or .and prints asterisks and tags as text, not markdown or HTML", {
  blk <- carrier(c = fr_str("a*b*c"), d = fr_list_str(c("x*y", "z*w")), e = fr_str("<b>hi</b>"))
  cases <- c(bare_c = "A `c`{.val} z.", bare_e = "A `e`{.val} z.", cap = "A `c`{.val .cap} z.",
             strong = "A `c`{.val .strong} z.", and = "A `d`{.val .and} z.", em_tag = "A `e`{.val .em} z.",
             strong_tag = "A `e`{.val .strong} z.")
  res <- f6_cases_html(cases, list(blk))
  expect_identical(res$status, 0L)
  want <- c(bare_c = "<p>A a*b*c z.</p>", bare_e = "<p>A &lt;b&gt;hi&lt;/b&gt; z.</p>",
            cap = "<p>A A*b*c z.</p>", strong = "<p>A <strong>a*b*c</strong> z.</p>",
            and = "<p>A x*y and z*w z.</p>",
            em_tag = "<p>A <em>&lt;b&gt;hi&lt;/b&gt;</em> z.</p>",
            strong_tag = "<p>A <strong>&lt;b&gt;hi&lt;/b&gt;</strong> z.</p>")
  for (nm in names(want)) expect_identical(unname(res$got[nm]), unname(want[nm]), label = paste("case", nm))
})

# ---- 13: one form for a float under .val ---------------------------------------------------------------------------

test_that("review-6 #13: a float printed by .val has the shortest digits, no trailing .0, and R's exponent", {
  recs <- list(a = "100000.0", b = "1.0e23", c = "-0.0", d = "5e-324", e = "5.0e-324", f = "1e+23",
               g = "100000", h = "3.0", i = "-2.0", j = "0.30000000000000004", k = "2.5", m = "1.5e+22")
  blk <- do.call(carrier, lapply(recs, fr_float))
  cases <- stats::setNames(sprintf("`%s`{.val}", names(recs)), names(recs))
  res <- filter_cases(cases, list(blk))
  expect_identical(res$status, 0L)
  expect_cases(res, c(a = "100000", b = "1e+23", c = "-0", d = "5e-324", e = "5e-324", f = "1e+23", g = "100000",
                      h = "3", i = "-2", j = "0.30000000000000004", k = "2.5", m = "1.5e+22"))
})

test_that("review-6 #13: the same form for the floats of a list", {
  blk <- carrier(l = fr_list_float(c("1.0", "2.5", "1.0e23")))
  res <- filter_cases(c(a = "`l`{.val}"), list(blk))
  expect_cases(res, c(a = "1, 2.5, 1e+23"))
})

# ---- 14 (filter half): a list of one element prints as that element -----------------------------------------------

test_that("review-6 #14: under a scalar class a list of exactly one element prints as the element", {
  one <- r6_list(fr_float("1.25"))
  blk <- carrier(l1 = one, s1 = fr_float("1.25"), p1 = r6_list(fr_float("0.256")), p0 = fr_float("0.256"),
                 c1 = r6_list(fr_float("12345")), c0 = fr_float("12345"),
                 q1 = r6_list(fr_float("0.0004")), q0 = fr_float("0.0004"),
                 o1 = r6_list(fr_float("3")), o0 = fr_float("3"), w1 = r6_list(fr_float("3")),
                 t1 = r6_list(fr_str("north"), of = "string"), t0 = fr_str("north"),
                 k1 = r6_list(fr_float("1.25"), keys = "A"))
  cases <- c(num = "`l1`{.num}", pct = "`p1`{.pct}", pct0 = "`p0`{.pct}", sci = "`c1`{.sci}", sci0 = "`c0`{.sci}",
             p = "`q1`{.p}", p0 = "`q0`{.p}", ord = "`o1`{.ord}", ord0 = "`o0`{.ord}", word = "`w1`{.word}",
             val = "`l1`{.val}", val_str = "`t1`{.val}", val_str0 = "`t0`{.val}", keyed_num = "`k1`{.num}")
  res <- filter_cases(cases, list(blk), draft = TRUE)
  expect_identical(res$status, 0L)
  expect_cases(res, c(num = "1.3", pct = "25.6%", pct0 = "25.6%", sci = res$got[["sci0"]], sci0 = res$got[["sci0"]],
                      p = res$got[["p0"]], p0 = res$got[["p0"]], ord = "3rd", ord0 = "3rd", word = "three",
                      val = "1.25", val_str = "north", val_str0 = "north", keyed_num = "1.3"))
  expect_false(grepl("<<weft", res$got[["sci0"]], fixed = TRUE), label = "the scalar .sci control prints")
  expect_false(grepl("<<weft", res$got[["p0"]], fixed = TRUE), label = "the scalar .p control prints")
})

test_that("review-6 #14: .pairs on a keyed list of one prints the name and the value", {
  blk <- carrier(k1 = r6_list(fr_float("1.3"), keys = "A"), k2 = r6_list(c(fr_float("1.2"), fr_float("3.4")),
                                                                         keys = c("A", "B")))
  res <- filter_cases(c(one = "`k1`{.pairs}", two = "`k2`{.pairs}"), list(blk))
  expect_cases(res, c(one = "A (1.3)", two = "A (1.2) and B (3.4)"))
})

test_that("review-6 #14 control: a list of two under .num is still E17", {
  blk <- carrier(l2 = fr_list_float(c("1.5", "2.5")))
  res <- filter_cases(c(a = "A `l2`{.num} z."), list(blk), draft = TRUE)
  expect_cases(res, c(a = paste0("A ", V2, " z.")))
  expect_true(grepl(fm_msg$E17("num", "number", "l2", "list"), res$stderr, fixed = TRUE))
})

# ---- 17: where the run is looked for, and which source wins ---------------------------------------------------------

test_that("review-6 #17: .weft/run is found 8 parents up from the document's folder", {
  deep <- "a/b/c/d/e/f/g/h"
  md <- c(g6_block(depth = fr_float("12.5"), run = "OLD-RUN", at = 1794822900L), "", "Depth `depth`{.num}.")
  res <- filter_md(md, name = paste0(deep, "/doc.md"), run_in = deep, files = list(".weft/run" = "RUN8"),
                   to = "plain")
  expect_identical(res$status, 0L)
  expect_true(grepl("not this run (RUN8)", res$stderr, fixed = TRUE), label = "the stale notice names the run found")
})

test_that("review-6 #17: .weft/run wins over WEFT_RUN", {
  md <- c(g6_block(depth = fr_float("12.5"), run = "FILE-RUN", at = 1794822900L), "", "Depth `depth`{.num}.")
  res <- filter_md(md, files = list(".weft/run" = "FILE-RUN"), weft_yml = G6_YML, env = c(WEFT_RUN = "ENV-RUN"),
                   to = "plain")
  expect_identical(res$status, 0L)
  expect_false(grepl("not this run", res$stderr, fixed = TRUE), label = "no notice: the file's run is the run")
  s <- g6_stamp(res)
  expect_identical(s$run, "FILE-RUN")
  expect_true(isTRUE(s$fresh))
})

test_that("review-6 #17 control: WEFT_RUN is used when there is no .weft/run", {
  md <- c(g6_block(depth = fr_float("12.5"), run = "OLD-RUN", at = 1794822900L), "", "Depth `depth`{.num}.")
  res <- filter_md(md, env = c(WEFT_RUN = "ENV-RUN"), to = "plain")
  expect_true(grepl("not this run (ENV-RUN)", res$stderr, fixed = TRUE))
})

# ---- 18: malformed checks make an error record ------------------------------------------------------------------------

test_that("review-6 #18: a record whose checks is not an array of well-formed check objects is an error record", {
  base <- fr_int("5")
  bad <- list(
    object = '{"text":"x > 1","ok":false}',
    string = '"x > 1"',
    number_elem = "[1]",
    string_elem = '["x > 1"]',
    no_text = '[{"ok":false}]',
    text_number = '[{"text":5,"ok":false}]',
    ok_string = '[{"text":"x > 1","ok":"no"}]',
    level_wrong = '[{"text":"x > 1","ok":false,"level":"loud"}]',
    one_bad_of_two = '[{"text":"a","ok":true},{"ok":false}]')
  good <- list(empty = "[]", passed = '[{"text":"x > 1","ok":true}]',
               warned_ok = '[{"text":"x > 1","ok":true,"level":"warn","why":null}]')
  recs <- c(lapply(bad, function(j) r6_rec_checks(base, j)), lapply(good, function(j) r6_rec_checks(base, j)))
  names(recs) <- c(paste0("b_", names(bad)), paste0("g_", names(good)))
  blk <- do.call(carrier, recs)
  cases <- stats::setNames(sprintf("A `%s`{.num} z.", names(recs)), names(recs))
  res <- filter_cases(cases, list(blk), draft = TRUE)
  expect_identical(res$status, 0L)
  want <- stats::setNames(c(rep(paste0("A ", V2, " z."), length(bad)), rep("A 5 z.", length(good))), names(recs))
  expect_cases(res, want)
  for (nm in names(bad)) {
    expect_true(grepl(sprintf("the record of `b_%s` does not read", nm), res$stderr, fixed = TRUE),
                label = paste("E31 for", nm))
  }
  expect_false(grepl("the record of `g_", res$stderr, fixed = TRUE), label = "no E31 for a well-formed checks")
})

test_that("review-6 #18: a record whose checks is an object does not print, and the render fails", {
  md <- c(carrier(x = r6_rec_checks(fr_int("5"), '{"text":"x > 1","ok":false}')), "", "A `x`{.num} z.")
  res <- filter_md(md, to = "plain")
  expect_identical(res$status, 1L)
})

# ---- 20: odd messages and reads at the edges -----------------------------------------------------------------------------

test_that("review-6 #20a: a named value in a front-matter field the filter does not resolve fails, and the message is not E35", {
  md <- c("---", "title: t", "author: \"`d`{.num}\"", "---", "", carrier(d = fr_int("5")), "", "Body.")
  res <- filter_md(md, args = "-s", to = "html")
  expect_identical(res$status, 1L)
  expect_false(grepl(fm_msg$E35, res$stderr, fixed = TRUE), label = "E35 is not said: weft.lua is installed")
  expect_false(grepl("is not installed", res$stderr, fixed = TRUE))
  expect_true(grepl("author", res$stderr, fixed = TRUE), label = "the message names the field")
})

test_that("review-6 #20c: a values file over 5,000,000 bytes is refused", {
  path <- "_weft/values/big.json"
  files <- stats::setNames(list(r6_padded_json(5000001)), path)
  md <- c(sprintf("````{.weft-values file=\"%s\"}", path), "````", "", "Body.")
  res <- filter_md(md, files = files, to = "plain")
  expect_identical(res$status, 1L)
  expect_true(grepl("limit is 5000000", res$stderr, fixed = TRUE))
  expect_true(grepl(path, res$stderr, fixed = TRUE))
})

test_that("review-6 #20c control: a values file just under the limit is read", {
  path <- "_weft/values/ok.json"
  files <- stats::setNames(list(r6_padded_json(4999990)), path)
  md <- c(sprintf("````{.weft-values file=\"%s\"}", path), "````", "", "Body.")
  res <- filter_md(md, files = files, to = "plain")
  expect_identical(res$status, 0L)
})

# ---- open 14: a list governor over bools --------------------------------------------------------------------------------

test_that("open-14: a list governor over bools prints true and false, as .val does", {
  bools <- '{"t":"list","v":[{"t":"bool","v":true},{"t":"bool","v":false}],"of":"bool","keys":null}'
  bools3 <- '{"t":"list","v":[{"t":"bool","v":true},{"t":"bool","v":false},{"t":"bool","v":true}],"of":"bool","keys":null}'
  blk <- carrier(b = bools, b3 = bools3)
  cases <- c(two = "A [None were | # was | # were]{list=\"b\"} z.", three = "A [None were | # was | # were]{list=\"b3\"} z.",
             val = "A `b`{.val} z.")
  res <- filter_cases(cases, list(blk))
  expect_identical(res$status, 0L)
  expect_cases(res, c(two = "A true and false were z.", three = "A true, false and true were z.", val = "A true, false z."))
})

# ---- open 15: a carrier at the end of a cell-output-stdout code block --------------------------------------------------

r6_stdout_block <- function(lines) c("::: {.cell-output .cell-output-stdout}", "```", lines, "```", ":::")
r6_fence <- function(name, v) {
  c("~~~~{.weft-values}", sprintf('{"weft":1,"values":{"%s":{"t":"int","v":"%s"}}}', name, v), "~~~~")
}

test_that("open-15: a carrier fence at the end of a stdout block is read and removed, the printed lines stay", {
  md <- c(r6_stdout_block(c("before one", "before two", r6_fence("q", "7"))), "", "Q `q`{.val}.")
  res <- filter_md(md)
  expect_identical(res$status, 0L)
  expect_true(grepl("<pre><code>before one\nbefore two</code></pre>", res$output, fixed = TRUE),
              label = "the earlier printed lines stay as output")
  expect_false(grepl("weft-values", res$output, fixed = TRUE))
  expect_false(grepl("~~~~", res$output, fixed = TRUE))
  expect_true(grepl("Q 7.", res$output, fixed = TRUE), label = "the carrier was read")
})

test_that("open-15: a carrier fence at the end, after a blank printed line, is read too", {
  md <- c(r6_stdout_block(c("line", "", r6_fence("q", "8"))), "", "Q `q`{.val}.")
  res <- filter_md(md)
  expect_identical(res$status, 0L)
  expect_true(grepl("Q 8.", res$output, fixed = TRUE))
  expect_false(grepl("weft-values", res$output, fixed = TRUE))
})

test_that("open-15: text that holds a fence in the middle is left alone, and its names are not published", {
  md <- c(r6_stdout_block(c("before", r6_fence("w", "9"), "after")), "", "W `w`{.val}.")
  res <- filter_md(md, env = c(WEFT_DRAFT = "1"))
  expect_identical(res$status, 0L)
  expect_true(grepl("~~~~{.weft-values}", res$output, fixed = TRUE), label = "the block keeps its fence")
  expect_true(grepl("after", res$output, fixed = TRUE))
  expect_true(grepl("weft: no value", res$output, fixed = TRUE), label = "w stays unpublished")
  res2 <- filter_md(md)
  expect_identical(res2$status, 1L)
})

test_that("open-15 control: a stdout block that is only a carrier is read, and one with another class is code", {
  md <- c(r6_stdout_block(r6_fence("p", "3")), "", "P `p`{.val}.")
  res <- filter_md(md)
  expect_identical(res$status, 0L)
  expect_true(grepl("P 3.", res$output, fixed = TRUE))
  md2 <- c("```", "before", r6_fence("r", "4"), "```", "", "R `r`{.val}.")
  res2 <- filter_md(md2, env = c(WEFT_DRAFT = "1"))
  expect_true(grepl("weft: no value", res2$output, fixed = TRUE))
})

# ---- open 11: one report under Quarto ----------------------------------------------------------------------------------------

test_that("open-11: under quarto render the failure report prints once, from the post-render script, and the render fails", {
  skip_if_no_quarto()
  dir <- mk_project(list("_quarto.yml" = c("project:", "  title: t"), "_weft.yml" = "draft: false",
                         "doc.qmd" = c("---", "title: t", "---", "", "A `nope`{.num} z.")))
  r <- qrender(dir, c("doc.qmd", "--to", "markdown"))
  expect_true(r$status != 0L, label = "the render fails")
  expect_true(grepl("no value is published under the name `nope`", r$log, fixed = TRUE), label = "the failure is reported")
  expect_identical(n_matches("weft: 1 failure", r$log), 1L)
})
