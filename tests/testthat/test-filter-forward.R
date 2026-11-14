# Stage 7f (dev/design-7.md, 2 F, notes N90 to N96, D23, messages E40 to E42): a named value used above
# its definition takes the value the document publishes below, when the name takes exactly one value.
# Blocks are written by hand and run through plain Pandoc (helper-filter.R). Cases where a failure is
# expected run in draft mode so that the output is written. Controls (behaviour that must not change)
# are marked. Made-up content only.

NVF <- "<<weft: no value, line %d>>"
FCL <- "<<weft: failed claim, line %d>>"

# ---- N90, N91: one value ---------------------------------------------------------------------------

test_that("N90: a name used above its only block takes that block's value, in each named-value class", {
  md <- c("Above `depth`{.num} and `depth`{.val} and `site`{.val} and `depth`{.word}.", "",
          carrier(depth = fr_int("7"), site = fr_str("north")), "")
  res <- filter_md(md, to = "plain")
  expect_identical(res$status, 0L)
  expect_identical(f7_paras(res), "Above 7 and 7 and north and seven.")
  expect_false(grepl("weft", res$stderr, fixed = TRUE))
})

test_that("N91: above two identical blocks, and above a block and a values file that agree", {
  md <- c("Above `depth`{.num}.", "", carrier(depth = fr_int("7")), "", "Middle.", "",
          carrier(depth = fr_int("7"), other = fr_int("1")))
  res <- filter_md(md, to = "plain")
  expect_identical(res$status, 0L)
  expect_identical(f7_paras(res), c("Above 7.", "Middle."))

  files <- setNames(list(carrier_json(depth = fr_int("7"))), "_weft/values/survey.json")
  md2 <- c("Above `depth`{.num}.", "", carrier(depth = fr_int("7")), "", f7_file_block("_weft/values/survey.json"))
  res2 <- filter_md(md2, files = files, to = "plain")
  expect_identical(res2$status, 0L)
  expect_identical(f7_paras(res2), "Above 7.")
  # a values file stands wherever it is read, including above the use's block and below the use
  md3 <- c("Above `depth`{.num}.", "", f7_file_block("_weft/values/survey.json"))
  res3 <- filter_md(md3, files = files, to = "plain")
  expect_identical(res3$status, 0L)
  expect_identical(f7_paras(res3), "Above 7.")
})

test_that("N91: a block inside a div, below the use, is read wherever it stands", {
  md <- c("Above `depth`{.num}.", "", "::: {.note}", carrier(depth = fr_int("9")), ":::")
  res <- filter_md(md, to = "plain")
  expect_identical(res$status, 0L)
  expect_identical(f7_paras(res), "Above 9.")
})

test_that("N91: a loop of identical publications is one value; the several publications of N91 compare without `checks`", {
  b <- function(chk) carrier(depth = if (chk) fr_with(fr_int("7"), fr_check("> 1", ok = TRUE)) else fr_int("7"))
  md <- c("Above `depth`{.num}.", "", b(FALSE), "", b(TRUE), "", b(FALSE), "", b(TRUE))
  res <- filter_md(md, to = "plain")
  expect_identical(res$status, 0L)
  expect_identical(f7_paras(res), "Above 7.")
})

# ---- N93: several values ----------------------------------------------------------------------------

test_that("N93, E40, E41, D23: above two blocks that differ is a failure of kind no value, an error not a warning", {
  md <- c("Above `depth`{.num} m.", "", carrier(depth = fr_int("1")), "", "Mid.", "", carrier(depth = fr_int("2")))
  res <- filter_md(md, to = "plain", env = F7_DRAFT)
  expect_identical(res$status, 0L)
  expect_identical(f7_paras(res)[1], sprintf("Above %s m.", sprintf(NVF, 1L)))
  expect_match(res$stderr, f7_msg$E40("depth", 2L), fixed = TRUE)
  expect_match(res$stderr, f7_msg$E41, fixed = TRUE)
  expect_match(fm_headings(res$stderr), rx_failures(1), all = FALSE)
  e <- fm_entry(res$stderr, "^  doc\\.md:1  ")
  expect_true(e$found)
  expect_identical(e$head, "  doc.md:1  [no value] `depth`{.num}")
  expect_identical(e$detail[[1]], f7_msg$E40("depth", 2L))
  # neither value is printed, and the render fails without draft mode
  expect_false(grepl("Above 1|Above 2", res$output))
  res2 <- filter_md(md, to = "plain")
  expect_identical(res2$status, 1L)
  expect_match(res2$stderr, f7_msg$E40("depth", 2L), fixed = TRUE)
})

test_that("N93, N91: the count in E40 is the number of different values", {
  b <- function(v) carrier(depth = fr_int(v))
  md3 <- c("Above `depth`{.num}.", "", b("1"), "", b("2"), "", b("3"))
  res3 <- filter_md(md3, to = "plain", env = F7_DRAFT)
  expect_match(res3$stderr, f7_msg$E40("depth", 3L), fixed = TRUE)
  md2 <- c("Above `depth`{.num}.", "", b("1"), "", b("2"), "", b("2"), "", b("1"))
  res2 <- filter_md(md2, to = "plain", env = F7_DRAFT)
  expect_match(res2$stderr, f7_msg$E40("depth", 2L), fixed = TRUE)
})

test_that("N91: a float's v is compared as text, a kind that differs is a different value, and a missing record is a value", {
  pairs <- list(
    float_text = list(fr_float("2.0"), fr_float("2")),
    kind = list(fr_int("2"), fr_float("2")),
    string_case = list(fr_str("north"), fr_str("North")),
    missing_vs_value = list(fr_missing("not measured"), fr_int("2")),
    missing_reasons = list(fr_missing("not measured"), fr_missing("lost"))
  )
  expect_length(pairs, 5L)
  for (nm in names(pairs)) {
    p <- pairs[[nm]]
    md <- c("Above `depth`{.val}.", "", carrier(depth = p[[1]]), "", carrier(depth = p[[2]]))
    res <- filter_md(md, to = "plain", env = F7_DRAFT)
    expect_match(res$stderr, f7_msg$E40("depth", 2L), fixed = TRUE, label = nm)
    expect_identical(f7_paras(res)[1], sprintf("Above %s.", sprintf(NVF, 1L)), label = nm)
  }
})

test_that("N91: two identical missing records are one value, so the use gives the missing failure, not E40", {
  md <- c("Above `m`{.num}.", "", carrier(m = fr_missing("not measured")), "", carrier(m = fr_missing("not measured")))
  res <- filter_md(md, to = "plain", env = F7_DRAFT)
  expect_identical(f7_paras(res)[1], sprintf("Above %s.", sprintf(NVF, 1L)))
  expect_match(res$stderr, fm_msg$E11("m", "not measured"), fixed = TRUE)
  expect_false(grepl("different values", res$stderr, fixed = TRUE))
})

test_that("N94, E42: a name published nowhere is no value, with E42 as detail and the hint of E10", {
  md <- c("Above `depth`{.num} m.", "", carrier(other = fr_int("1")))
  res <- filter_md(md, to = "plain", env = F7_DRAFT)
  expect_identical(f7_paras(res)[1], sprintf("Above %s m.", sprintf(NVF, 1L)))
  e <- fm_entry(res$stderr, "^  doc\\.md:1  ")
  expect_true(e$found)
  expect_identical(e$head, "  doc.md:1  [no value] `depth`{.num}")
  expect_identical(e$detail[[1]], f7_msg$E42("depth"))
  expect_match(res$stderr, fm_msg$E10_hint("depth"), fixed = TRUE)
  expect_false(grepl(fm_msg$E10("depth"), res$stderr, fixed = TRUE))
  expect_identical(filter_md(md, to = "plain")$status, 1L)
})

# ---- N90: governors -----------------------------------------------------------------------------------

test_that("N90: a name in an if, n, sign or list value, above its block, takes the value below", {
  blk <- carrier(n_gap = fr_int("12"), k3 = fr_int("3"), d = fr_float("-0.12"),
                 l2 = fr_list_str(c("a", "b")), flag = fr_bool(FALSE))
  cases <- c(if_cmp = "Z [many | few]{if=\"n_gap > 3\"} z.",
             if_bool = "Z [yes | no]{if=\"flag\"} z.",
             n = "Z [a site | # sites]{n=\"k3\"} z.",
             sign = "Z [up # | down #]{sign=\"d\"} z.",
             list = "Z [none | # was | # were]{list=\"l2\"} z.")
  md <- c(unlist(lapply(cases, function(x) c(x, ""))), blk)
  res <- filter_md(md, to = "plain")
  expect_identical(res$status, 0L)
  expect_identical(f7_paras(res), c("Z many z.", "Z no z.", "Z 3 sites z.", "Z down 0.1 z.", "Z a and b were z."))
  expect_false(grepl("weft", res$stderr, fixed = TRUE))
})

test_that("N90, N93: a governor above two blocks that differ is E40 for the name it uses", {
  md <- c("Z [many | few]{if=\"n_gap > 3\"} z.", "", carrier(n_gap = fr_int("12")), "", carrier(n_gap = fr_int("1")))
  res <- filter_md(md, to = "plain", env = F7_DRAFT)
  expect_match(res$stderr, f7_msg$E40("n_gap", 2L), fixed = TRUE)
  expect_match(fm_headings(res$stderr), rx_failures(1), all = FALSE)
  expect_identical(filter_md(md, to = "plain")$status, 1L)
})

test_that("N90: a name inside an arm that is chosen, above its block, takes the value below", {
  md <- c("Z [`depth`{.num} m | none]{if=\"a\"} z.", "", carrier(a = fr_bool(TRUE), depth = fr_int("7")))
  res <- filter_md(md, to = "plain")
  expect_identical(res$status, 0L)
  expect_identical(f7_paras(res), "Z 7 m z.")
})

# ---- N92: checks ----------------------------------------------------------------------------------------

test_that("N92, N25a: a record with a failing check runs it at the forward use", {
  md <- c("Above `depth`{.num} m.", "", carrier(depth = fr_with(fr_int("7"), fr_check("> 10"))))
  res <- filter_md(md, to = "plain", env = F7_DRAFT)
  expect_identical(f7_paras(res)[1], sprintf("Above 7%s m.", sprintf(FCL, 1L)))
  expect_match(fm_headings(res$stderr), rx_claims(1), all = FALSE)
  e <- fm_entry(res$stderr, "^  doc\\.md:1  ")
  expect_identical(e$detail, fm_msg$E14("> 10", "7"))
  expect_identical(filter_md(md, to = "plain")$status, 1L)
})

test_that("N92: the record used is the last publication, with its checks, though the records compare without them", {
  bad <- fr_with(fr_int("7"), fr_check("> 10"))
  md_last_bad <- c("Above `depth`{.num}.", "", carrier(depth = fr_int("7")), "", carrier(depth = bad))
  res <- filter_md(md_last_bad, to = "plain", env = F7_DRAFT)
  expect_match(fm_headings(res$stderr), rx_claims(1), all = FALSE)
  expect_identical(f7_paras(res)[1], sprintf("Above 7%s.", sprintf(FCL, 1L)))
  md_first_bad <- c("Above `depth`{.num}.", "", carrier(depth = bad), "", carrier(depth = fr_int("7")))
  res2 <- filter_md(md_first_bad, to = "plain")
  expect_identical(res2$status, 0L)
  expect_identical(f7_paras(res2)[1], "Above 7.")
  expect_false(grepl("weft", res2$stderr, fixed = TRUE))
})

# ---- N95: unchanged (controls) ----------------------------------------------------------------------

test_that("N95, N26 (control): a use below a publication takes the latest publication above it, not the last", {
  md <- c("Above `depth`{.num}.", "", carrier(depth = fr_int("1")), "", "One `depth`{.num}.", "",
          carrier(depth = fr_int("2")), "", "Two `depth`{.num}.")
  res <- filter_md(md, to = "plain", env = F7_DRAFT)
  expect_identical(f7_paras(res), c(sprintf("Above %s.", sprintf(NVF, 1L)), "One 1.", "Two 2."))
  # only the forward use fails
  expect_match(fm_headings(res$stderr), rx_failures(1), all = FALSE)
  # with no use above every publication, several values are no failure at all
  md2 <- md[-(1:2)]
  res2 <- filter_md(md2, to = "plain")
  expect_identical(res2$status, 0L)
  expect_identical(f7_paras(res2), c("One 1.", "Two 2."))
  expect_false(grepl("weft", res2$stderr, fixed = TRUE))
})

test_that("N95, N81 (control): a title and a caption take the last value, with no several-values failure", {
  md <- c("---", 'title: "T `depth`{.val}"', "---", "",
          carrier(depth = fr_int("1")), "", "Body `depth`{.val}.", "",
          carrier(depth = fr_int("2")), "",
          "| a |", "|---|", "| 1 |", "", ": Cap `depth`{.val}")
  res <- filter_md(md, to = "plain", args = "-s")
  expect_identical(res$status, 0L)
  expect_match(res$output, "T 2", fixed = TRUE)
  expect_match(res$output, "Cap 2", fixed = TRUE)
  expect_match(res$output, "Body 1.", fixed = TRUE)
  expect_false(grepl("different values", res$stderr, fixed = TRUE))
})

# ---- N11 of the missing record -------------------------------------------------------------------------

test_that("N91: a missing record used above its block gives today's missing failure, not E42", {
  md <- c("Above `m`{.num} m.", "", carrier(m = fr_missing("not measured")))
  res <- filter_md(md, to = "plain", env = F7_DRAFT)
  expect_identical(f7_paras(res)[1], sprintf("Above %s m.", sprintf(NVF, 1L)))
  e <- fm_entry(res$stderr, "^  doc\\.md:1  ")
  expect_true(e$found)
  expect_identical(e$detail[[1]], fm_msg$E11("m", "not measured"))
  expect_false(grepl("is used above its first publication", res$stderr, fixed = TRUE))
  expect_false(grepl("no value is published", res$stderr, fixed = TRUE))
})

# ---- N96: ledger and stamp ------------------------------------------------------------------------------

test_that("N96: the ledger entry is a named value's entry, its text the fallback's, with no field added", {
  blk <- g6_block(depth = fr_float("12.5"), run = "R1", at = 1794822900L)
  md <- c("Above `depth`{.num}.", "", blk, "", "Below `depth`{.num}.")
  res <- filter_md(md, weft_yml = G6_YML, env = c(WEFT_RUN = "R1"), to = "plain")
  expect_identical(res$status, 0L)
  es <- g6_entries(res)
  expect_setequal(g6_keys(es), c("value|depth|1", "value|depth|2"))
  fwd <- g6_pick(es, "value", "depth", 1)
  below <- g6_pick(es, "value", "depth", 2)
  expect_identical(fwd$text, "12.5")
  expect_identical(fwd$kind, "value")
  expect_identical(fwd$writer, "filter")
  expect_identical(names(fwd), names(below))
  expect_equal(fwd$raw, 12.5)
})

test_that("N96: the stamp counts the checks of a forward use as it counts those of a use below", {
  rec <- fr_with(fr_int("7"), fr_check("> 1", ok = TRUE), fr_check("< 99", ok = TRUE))
  fwd <- c("Use `depth`{.num}.", "", carrier(depth = rec))
  below <- c(carrier(depth = rec), "", "Use `depth`{.num}.")
  rf <- filter_md(fwd, weft_yml = G6_YML, env = c(WEFT_RUN = "R1"), to = "plain")
  rb <- filter_md(below, weft_yml = G6_YML, env = c(WEFT_RUN = "R1"), to = "plain")
  expect_identical(rf$status, 0L)
  sf <- g6_stamp(rf)
  sb <- g6_stamp(rb)
  expect_true(sb$checks >= 1)
  expect_identical(sf$checks, sb$checks)
  expect_identical(sf$named, sb$named)
})
