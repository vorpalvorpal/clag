# Package 6c: failures, markers, the one report, exit and collection (dev/design-6.md N25a, N25b, N86,
# N87, N88; rules 2.6.2, 2.6.8, 2.6.10, 9.4.1). Documents run through plain Pandoc (helper-filter.R).
# The report goes to stderr in the layout of inst/quarto/weft-post-render.R: failed claims first, then
# the other failures each tagged [KIND], then warned checks. The headings' plural forms ("claim(s)",
# "failure(s)") are read both ways (rx_claims(), rx_failures()). While inst/quarto/weft.lua does not
# exist every test fails on that.

report_block <- function() {
  carrier(depth = fr_with(fr_int("7"), fr_check("> 10")),
          w = fr_with(fr_int("7"), fr_check("> 10", level = "warn")),
          z = fr_float("0.04"), miss = fr_missing("gone"), ok = fr_int("5"), a = fr_bool(TRUE))
}

report_cases <- c(claim = "Depth `depth`{.num} m.", nov = "Gone `miss`{.num} m.", warn = "Warn `w`{.num} m.",
                  zero = "Zero `z`{.num} m.", fine = "Fine `ok`{.num} m.")

test_that("N86, 2.6.8: one of each kind: the markers in the text and the report's exact layout", {
  res <- filter_cases(report_cases, list(report_block()), draft = TRUE)
  expect_identical(res$status, 0L)
  expect_cases(res, c(claim = "Depth 7<<weft: failed claim, line {L}>> m.",
                      nov = "Gone <<weft: no value, line {L}>> m.", warn = "Warn 7 m.",
                      zero = "Zero 0.0 m.", fine = "Fine 5 m."))
  L <- res$line
  ls <- fm_lines(res$stderr)
  heads <- grep("^weft: ", ls)
  expect_length(heads, 3L)
  expect_match(ls[heads[1]], rx_claims(1))
  expect_match(ls[heads[2]], rx_failures(1))
  expect_match(ls[heads[3]], rx_warned(2))
  # failed claims
  e <- fm_entry(res$stderr, sprintf("^  doc\\.md:%d  ", L[["claim"]]))
  expect_identical(e$head, sprintf("  doc.md:%d  `depth`{.num}", L[["claim"]]))
  expect_identical(e$detail, fm_msg$E14("> 10", "7"))
  closers <- which(ls == "Read each sentence. If FALSE is right, rewrite the sentence.")
  expect_length(closers, 1L)
  expect_identical(ls[closers + 1L], "Do not loosen a claim to clear this.")
  expect_true(closers > heads[1] && closers + 1L < heads[2])
  # the other failures, tagged
  e <- fm_entry(res$stderr, sprintf("^  doc\\.md:%d  ", L[["nov"]]))
  expect_identical(e$head, sprintf("  doc.md:%d  [no value] `miss`{.num}", L[["nov"]]))
  expect_identical(e$detail, fm_msg$E11("miss", "gone"))
  # warned checks, after the failures: a warned claim and a number that printed as zero
  e <- fm_entry(res$stderr, sprintf("^  doc\\.md:%d  ", L[["warn"]]))
  expect_match(e$head, sprintf("^  doc\\.md:%d  (\\[failed claim\\] )?`w`\\{\\.num\\}$", L[["warn"]]))
  expect_identical(e$detail, fm_msg$E14("> 10", "7"))
  e <- fm_entry(res$stderr, sprintf("^  doc\\.md:%d  ", L[["zero"]]))
  expect_identical(e$head, sprintf("  doc.md:%d  [printed as zero] `z`{.num}", L[["zero"]]))
  expect_true(any(grepl("0.04 printed as 0.0: add sigfig to show it, or digits to confirm it", e$detail, fixed = TRUE)))
  expect_true(which(grepl(sprintf("^  doc\\.md:%d  ", L[["zero"]]), ls)) > heads[3])
  # no entry for the value that printed fine
  expect_false(any(grepl("`ok`", ls, fixed = TRUE)))
})

test_that("N86: without draft mode the same document fails the render", {
  res <- filter_cases(report_cases, list(report_block()))
  expect_identical(res$status, 1L)
  expect_match(fm_headings(res$stderr), rx_claims(1), all = FALSE)
})

test_that("N86, 2.6.10: warned checks alone never fail the render, and leave no marker", {
  cases <- c(warn = "Warn `w`{.num} m.", zero = "Zero `z`{.num} m.")
  res <- filter_cases(cases, list(report_block()))
  expect_identical(res$status, 0L)
  expect_cases(res, c(warn = "Warn 7 m.", zero = "Zero 0.0 m."))
  expect_length(grep("^weft: ", fm_lines(res$stderr)), 1L)
  expect_match(fm_headings(res$stderr), rx_warned(2), all = FALSE)
  expect_false(grepl("<<weft:", res$stderr, fixed = TRUE))
})

test_that("N25a: a check carried on a record counts once per use, in a value or a condition, never when unused", {
  blk <- carrier(depth = fr_with(fr_int("7"), fr_check("> 10")),
                 unused = fr_with(fr_int("7"), fr_check("> 99")), a = fr_bool(TRUE))
  cases <- c(u1 = "A `depth`{.num}.", u2 = "B `depth`{.num}.",
             u3 = "C [yes | no]{if=\"depth > 3\"}.", u4 = "D [x | `depth`{.num}]{if=\"a\"}.")
  res <- filter_cases(cases, list(blk), draft = TRUE)
  expect_cases(res, c(u1 = "A 7<<weft: failed claim, line {L}>>.", u2 = "B 7<<weft: failed claim, line {L}>>.",
                      u3 = "C yes<<weft: failed claim, line {L}>>.", u4 = "D x."))
  expect_match(fm_headings(res$stderr), rx_claims(3), all = FALSE)
  expect_length(grep("^weft: ", fm_lines(res$stderr)), 1L)
  e <- fm_entry(res$stderr, sprintf("^  doc\\.md:%d  ", res$line[["u3"]]))
  expect_identical(e$head, sprintf("  doc.md:%d  [yes | no]{if=\"depth > 3\"}", res$line[["u3"]]))
  expect_identical(e$detail, fm_msg$E14("> 10", "7"))
  expect_false(grepl("unused", res$stderr, fixed = TRUE))
  expect_false(grepl("> 99", res$stderr, fixed = TRUE))
})

test_that("N25a: a check with why, with ok null, and with several checks of which one fails", {
  blk <- carrier(
    w1 = fr_with(fr_int("7"), fr_check("> 10", why = "7 is not above 10")),
    w2 = fr_with(fr_int("7"), fr_check("> 10", ok = NA, why = "could not be evaluated")),
    w3 = fr_with(fr_int("7"), fr_check("> 1", ok = TRUE), fr_check("< 5", ok = FALSE), fr_check("!= 0", ok = TRUE)))
  cases <- c(c1 = "A `w1`{.num}.", c2 = "B `w2`{.num}.", c3 = "C `w3`{.num}.")
  res <- filter_cases(cases, list(blk), draft = TRUE)
  expect_match(fm_headings(res$stderr), rx_claims(3), all = FALSE)
  d <- function(nm) fm_entry(res$stderr, sprintf("^  doc\\.md:%d  ", res$line[[nm]]))$detail
  expect_identical(d("c1"), fm_msg$E14("> 10", "7", "7 is not above 10"))
  expect_identical(d("c2"), fm_msg$E14("> 10", "7", "could not be evaluated"))
  expect_identical(d("c3"), fm_msg$E14("< 5", "7"))
})

test_that("N25b: the block's own failed check is reported once, located by its cell, whether or not a name is used", {
  chk <- fr_check("> 10", extra = ',"expr":"claim(n, \\"> 10\\")","value":{"t":"int","v":"7"},"line":null')
  blk <- c("::: {#cell-chk .cell}", carrier(n = fr_int("7"), members = sprintf('"checks":[%s]', chk)), ":::")
  res <- filter_md(c(blk, "", "Uses `n`{.val} and `n`{.val}."), to = "plain")
  expect_identical(res$status, 1L)
  expect_match(fm_headings(res$stderr), rx_claims(1), all = FALSE)
  expect_length(grep("^weft: ", fm_lines(res$stderr)), 1L)
  e <- fm_entry(res$stderr, "^  doc\\.md chunk chk  ")
  expect_true(e$found)
  expect_true(grepl("claim(n, \"> 10\")", e$head, fixed = TRUE))
  expect_identical(e$detail, fm_msg$E14("> 10", "7"))
  # no name is used at all: still reported
  res2 <- filter_md(c(blk, "", "Nothing named here."), to = "plain")
  expect_identical(res2$status, 1L)
  expect_match(fm_headings(res2$stderr), rx_claims(1), all = FALSE)
  # in draft mode the text carries no marker (nothing in the text is the claim)
  res3 <- filter_md(c(blk, "", "Uses `n`{.val}."), to = "plain", env = c(WEFT_DRAFT = "1"))
  expect_identical(res3$status, 0L)
  expect_identical(trimws(res3$output), "Uses 7.")
})

test_that("N25b: a check's own line locates it; why, null ok, warn level and a passing check", {
  mk <- function(chk, cell = "chk") {
    c(sprintf("::: {#cell-%s .cell}", cell),
      carrier(n = fr_int("7"), members = sprintf('"checks":[%s]', paste(chk, collapse = ","))), ":::")
  }
  ex <- ',"expr":"claim(n, \\"> 10\\")","value":{"t":"int","v":"7"},"line":%s'
  # a line
  res <- filter_md(mk(fr_check("> 10", extra = sprintf(ex, "12") )), to = "plain")
  e <- fm_entry(res$stderr, "^  doc\\.md:12  ")
  expect_true(e$found)
  expect_identical(e$detail, fm_msg$E14("> 10", "7"))
  # why, and ok null
  res <- filter_md(mk(c(fr_check("> 10", why = "n was 7", extra = sprintf(ex, "null")),
                        fr_check("n % 2 == 0", ok = NA, why = "could not be evaluated", extra = sprintf(ex, "null")))),
                   to = "plain")
  expect_match(fm_headings(res$stderr), rx_claims(2), all = FALSE)
  e <- fm_entry(res$stderr, "^  doc\\.md chunk chk  ")
  expect_identical(e$detail, fm_msg$E14("> 10", "7", "n was 7"))
  # a label with a dash
  res <- filter_md(mk(fr_check("> 10", extra = sprintf(ex, "null")), cell = "fig-depth"), to = "plain")
  expect_true(fm_entry(res$stderr, "^  doc\\.md chunk fig-depth  ")$found)
  # warn level: warned, fails nothing
  res <- filter_md(mk(fr_check("> 10", level = "warn", extra = sprintf(ex, "null"))), to = "plain")
  expect_identical(res$status, 0L)
  expect_match(fm_headings(res$stderr), rx_warned(1), all = FALSE)
  expect_length(grep("^weft: ", fm_lines(res$stderr)), 1L)
  # ok true: nothing
  res <- filter_md(mk(fr_check("> 1", ok = TRUE, extra = sprintf(ex, "null"))), to = "plain")
  expect_identical(res$status, 0L)
  expect_false(grepl("weft", res$stderr, fixed = TRUE))
})

test_that("2.6.8, N86: a marker names the line, else the chunk, else nothing", {
  md <- c(report_block(), "",
          "::: {#cell-lab .cell}", "Printed ``miss``{.num} here.", ":::", "",
          "Outside ``miss``{.num} here.", "",
          "Located `miss`{.num} here.")
  res <- filter_md(md, to = "plain", env = c(WEFT_DRAFT = "1"))
  expect_identical(res$status, 0L)
  paras <- strsplit(trimws(res$output), "\n\n", fixed = TRUE)[[1]]
  line_of <- grep("^Located", md)
  expect_identical(paras, c("Printed <<weft: no value, chunk lab>> here.", "Outside <<weft: no value>> here.",
                            sprintf("Located <<weft: no value, line %d>> here.", line_of)))
  e <- fm_entry(res$stderr, "^  doc\\.md chunk lab  ")
  expect_identical(e$head, "  doc.md chunk lab  [no value] `miss`{.num}")
  e <- fm_entry(res$stderr, "^  doc\\.md  \\[no value\\]")
  expect_identical(e$head, "  doc.md  [no value] `miss`{.num}")
})

test_that("N87: a construct as shown: a named value with its id, classes and keys; a span with its text cut at 60", {
  long <- strrep("a", 70)
  blk <- carrier(f = fr_bool(FALSE))
  cases <- c(named = "A `nothere`{#d .num .smallcaps digits=\"2\"} z.",
             span = sprintf("B [%s | yes]{if=\"nothere > 1\" .smallcaps}.", long),
             short = "C [x | y]{if=\"nothere > 1\" .smallcaps}.")
  res <- filter_cases(cases, list(blk), draft = TRUE)
  L <- res$line
  e <- fm_entry(res$stderr, sprintf("^  doc\\.md:%d  ", L[["named"]]))
  expect_true(e$found)
  expect_match(e$head, sprintf("^  doc\\.md:%d  (\\[[a-z ]+\\] )?`nothere`\\{#d \\.num \\.smallcaps digits=\"2\"\\}$", L[["named"]]))
  e <- fm_entry(res$stderr, sprintf("^  doc\\.md:%d  ", L[["span"]]))
  expect_match(e$head, sprintf("^  doc\\.md:%d  (\\[[a-z ]+\\] )?\\[%s\\.\\.\\.\\]\\{if=\"nothere > 1\"\\}$", L[["span"]], strrep("a", 60)),
               fixed = FALSE)
  e <- fm_entry(res$stderr, sprintf("^  doc\\.md:%d  ", L[["short"]]))
  expect_match(e$head, sprintf("^  doc\\.md:%d  (\\[[a-z ]+\\] )?\\[x \\| y\\]\\{if=\"nothere > 1\"\\}$", L[["short"]]))
})

test_that("N88, 9.4.1: draft mode comes from WEFT_DRAFT, _weft.yml or the document's own weft: key; it changes only the exit", {
  md <- c(carrier(miss = fr_missing("gone")), "", "Gone `miss`{.num} here.")
  fm <- c("---", "weft:", "  draft: true", "---", "")
  drafts <- list(
    env_1 = filter_md(md, to = "plain", env = c(WEFT_DRAFT = "1")),
    env_true = filter_md(md, to = "plain", env = c(WEFT_DRAFT = "true")),
    yml_true = filter_md(md, to = "plain", weft_yml = "draft: true"),
    yml_comment = filter_md(md, to = "plain", weft_yml = c("digits: 1", "draft: true   # while writing")),
    front_matter = filter_md(c(fm, md), to = "plain")
  )
  for (nm in names(drafts)) {
    expect_identical(drafts[[nm]]$status, 0L, label = paste("status with", nm))
    expect_match(fm_headings(drafts[[nm]]$stderr), rx_failures(1), all = FALSE, label = paste("report with", nm))
  }
  expect_match(drafts$env_1$output, "Gone <<weft: no value, line 5>> here.", fixed = TRUE)
  fails <- list(
    none = filter_md(md, to = "plain"),
    env_false = filter_md(md, to = "plain", env = c(WEFT_DRAFT = "false")),
    yml_false = filter_md(md, to = "plain", weft_yml = "draft: false")
  )
  for (nm in names(fails)) {
    expect_identical(fails[[nm]]$status, 1L, label = paste("status with", nm))
    expect_match(fm_headings(fails[[nm]]$stderr), rx_failures(1), all = FALSE, label = paste("report with", nm))
  }
})

test_that("N86, N111: with a collection file open one line per failure and warned check is appended, and the run goes on", {
  seed <- '{"run":"20261113T101500-123-000042"}'
  res <- filter_cases(report_cases, list(report_block()), collect = seed)
  expect_identical(res$status, 0L)
  expect_match(fm_headings(res$stderr), rx_claims(1), all = FALSE)
  expect_identical(utils::head(res$collected, 1L), seed)
  recs <- lapply(res$collected[-1], jsonlite::fromJSON)
  expect_length(recs, 4L)
  expect_true(all(vapply(recs, function(r) identical(r$source, "resolve"), NA)))
  by_line <- stats::setNames(recs, vapply(recs, function(r) as.character(fm_or(r$line, NA)), ""))
  L <- res$line
  expect_setequal(names(by_line), as.character(L[c("claim", "nov", "warn", "zero")]))
  at <- function(nm) fm_or(by_line[[as.character(L[[nm]])]], list())
  r <- at("claim")
  expect_identical(r$kind, "failed claim")
  expect_true(grepl(fm_msg$E14("> 10", "7"), r$detail, fixed = TRUE))
  expect_false(identical(r$level, "warn"))
  expect_identical(basename(fm_or(r$file, "")), "doc.md")
  r <- at("nov")
  expect_identical(r$kind, "no value")
  expect_true(grepl(fm_msg$E11("miss", "gone"), r$detail, fixed = TRUE))
  r <- at("warn")
  expect_identical(r$level, "warn")
  r <- at("zero")
  expect_identical(r$level, "warn")
  expect_identical(r$kind, "printed as zero")
})

test_that("N86: a clean document writes nothing to stderr and appends nothing to a collection file", {
  res <- filter_cases(c(fine = "Fine `ok`{.num} m."), list(report_block()), collect = TRUE)
  expect_identical(res$status, 0L)
  expect_false(grepl("weft", res$stderr, fixed = TRUE))
  expect_length(res$collected, 0L)
})
