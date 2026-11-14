# Package 6P: parity wins, the filter half (dev/lua-parity.md, sections A1 to A5 and "Found along the way"
# with the orchestrator's rulings S1 to S3). One document of many cases per test, through plain Pandoc
# (helper-filter.R). The conformance rows of A3 and A4 are in _conformance/lists.tsv and dates.tsv and are
# driven through Lua by test-lua-words.R; the static half is test-parity-static.R.
#
#   A1  `!name`: the negation of one bool name, in `if` (rule 1.12.4).
#   A2  a date compared with a 'YYYY-MM-DD' literal (rule 1.12.5).
#   A3  .num .pct .sci .p on a list with no collapse class print element by element (rule 1.12.11).
#   A5  a failing guard names the values it read (rule 2.13.4): `X was false (a = ..., b = ...)`.
#   S1  a `claim` or `level` key on a named value or on a span the filter resolves is a construct error.
#   S2  a span whose attribute value holds `\|` (a pipe-table cell) gets its source line.
#   S3  messages cite the rules 1.12.5 (kinds), 1.12.6 (governor values) and 1.12.7 (order).
#
# GAPS (the study fixes no text): the message of A2's value errors, of `!s` (E18), of S1's construct error
# and of an element-kind E17 is not pinned; those tests assert the marker, the status and, for S1, that the
# report's detail names the key.

CE <- "<<weft: construct error, line {L}>>"
VE <- "<<weft: value error, line {L}>>"
NV <- "<<weft: no value, line {L}>>"

pf_block <- function() {
  carrier(
    a = fr_bool(TRUE), f = fr_bool(FALSE), n_gap = fr_int("12"), n_sites = fr_int("3"),
    s = fr_str("north"), sdate = fr_str("2026-01-03"), sbar = fr_str("x|y"),
    dA = fr_date("2026-01-02"), dB = fr_date("2026-01-03"), dleap = fr_date("2024-02-29"),
    worst = fr_float("52.5"), xs = fr_list_float(c("1.25", "3.5")), ps = fr_list_float(c("0.046", "0.0004")),
    lz = fr_list_float(c("0.0004", "0.0003")), li = fr_list_int(c("1", "2", "3")),
    ls = fr_list_str(c("a", "b")), miss = fr_missing("not measured")
  )
}

pf_if <- function(cond) sprintf("Z [yes | no]{if=\"%s\"}.", cond)

# the detail lines of the report entry of case `nm`
pf_detail <- function(res, nm) {
  fm_entry(res$stderr, sprintf("^  doc\\.md:%d  ", res$line[[nm]]))$detail
}

# ---- A1: !name ----------------------------------------------------------------------------------------------

test_that("parity A1: `!name` negates one bool name, alone or beside other parts", {
  truth <- c(
    "!a" = FALSE, "!f" = TRUE, "a, !f" = TRUE, "!f, a" = TRUE, "!a, f" = FALSE, "!a, !f" = FALSE,
    "!f, !f" = TRUE, "n_gap > 10, !f" = TRUE, "!f, n_gap > 100" = FALSE, "!f,n_gap>10" = TRUE
  )
  cases <- vapply(names(truth), pf_if, "")
  res <- filter_cases(cases, list(pf_block()))
  expect_identical(res$status, 0L)
  expect_cases(res, stats::setNames(ifelse(truth, "Z yes.", "Z no."), names(truth)))
  expect_false(grepl("weft", res$stderr, fixed = TRUE))
})

test_that("parity A1: `!` applies to a name only; every other form is a construct error quoting the part", {
  parts <- c("!!a", "!a == f", "! (a)", "!(a)", "!n_gap > 3", "!", "!'x'", "!3", "a, !!f")
  res <- filter_cases(vapply(parts, pf_if, ""), list(pf_block()), draft = TRUE)
  expect_cases(res, stats::setNames(rep(paste0("Z ", CE, "."), length(parts)), parts))
  for (p in setdiff(parts, "a, !!f")) {
    expect_true(grepl(fm_msg$E3(p), res$stderr, fixed = TRUE), label = paste("E3 for", p))
  }
  expect_true(grepl(fm_msg$E3("!!f"), res$stderr, fixed = TRUE), label = "only the part is quoted")
})

test_that("parity A1: `!` before a name that is not a bool is a value error; before a missing name, no value", {
  cases <- c("!s" = pf_if("!s"), "!n_gap" = pf_if("!n_gap"), "!dA" = pf_if("!dA"))
  res <- filter_cases(cases, list(pf_block()), draft = TRUE)
  expect_cases(res, stats::setNames(rep(paste0("Z ", VE, "."), 3), names(cases)))
  expect_true(grepl("a condition must be true or false", res$stderr, fixed = TRUE))
  cases2 <- c(nothere = pf_if("!nothere"), miss = pf_if("!miss"))
  res2 <- filter_cases(cases2, list(pf_block()), draft = TRUE)
  expect_cases(res2, stats::setNames(rep(paste0("Z ", NV, "."), 2), names(cases2)))
  # N94, E42: a name published nowhere has the detail of E42
  expect_true(grepl(f7_msg$E42("nothere"), res2$stderr, fixed = TRUE))
  expect_true(grepl(fm_msg$E11("miss", "not measured"), res2$stderr, fixed = TRUE))
})

test_that("parity A1: a one-arm guard of `!name` prints its phrase and fails only when the name is true", {
  g <- function(cond) sprintf("Sampling ran on schedule[, in full]{if=\"%s\"}.", cond)
  cases <- c(holds = g("!f"), fails = g("!a"), second_part_fails = g("a, !a"))
  res <- filter_cases(cases, list(pf_block()), draft = TRUE)
  expect_cases(res, c(holds = "Sampling ran on schedule, in full.",
                      fails = "Sampling ran on schedule, in full<<weft: failed claim, line {L}>>.",
                      second_part_fails = "Sampling ran on schedule, in full<<weft: failed claim, line {L}>>."))
  expect_match(fm_headings(res$stderr), rx_claims(2), all = FALSE)
  expect_true(grepl("!a", res$stderr, fixed = TRUE))
  # outside draft mode the failed guard fails the render
  res2 <- filter_md(fm_doc(cases[c("holds", "fails")], list(pf_block()), character())$md, to = "plain")
  expect_identical(res2$status, 1L)
})

test_that("parity A1 control: && and || stay construct errors, and a bare bool name still chooses", {
  parts <- c("a && f", "a || f", "not a")
  res <- filter_cases(vapply(parts, pf_if, ""), list(pf_block()), draft = TRUE)
  expect_cases(res, stats::setNames(rep(paste0("Z ", CE, "."), 3), parts))
  res2 <- filter_cases(c(t = pf_if("a"), f = pf_if("f")), list(pf_block()))
  expect_cases(res2, c(t = "Z yes.", f = "Z no."))
})

# ---- A2: a date against a date literal ------------------------------------------------------------------------

test_that("parity A2: a date compares with a 'YYYY-MM-DD' literal in calendar order, either side", {
  truth <- c(
    "dA < '2026-01-03'" = TRUE, "'2026-01-03' > dA" = TRUE, "dA < '2026-01-02'" = FALSE,
    "dA <= '2026-01-02'" = TRUE, "dA == '2026-01-02'" = TRUE, "'2026-01-02' == dA" = TRUE,
    "dA != '2026-01-02'" = FALSE, "dA != '2026-01-03'" = TRUE, "dA >= '2026-01-02'" = TRUE,
    "dA > '2026-01-02'" = FALSE, "dB > '2026-01-02'" = TRUE, "dA < '2027-01-01'" = TRUE,
    "dA > '2025-12-31'" = TRUE, "dleap == '2024-02-29'" = TRUE, "dleap < '2024-03-01'" = TRUE,
    "dleap > '2024-02-28'" = TRUE, "dleap > '2024-02-29'" = FALSE, "dA < '2026-01-03', dB > '2026-01-02'" = TRUE
  )
  res <- filter_cases(vapply(names(truth), pf_if, ""), list(pf_block()))
  expect_identical(res$status, 0L)
  expect_cases(res, stats::setNames(ifelse(truth, "Z yes.", "Z no."), names(truth)))
  expect_false(grepl("weft", res$stderr, fixed = TRUE))
})

test_that("parity A2: any other string literal against a date, or an impossible date, is a value error", {
  bad <- c("dA < '2026-1-3'", "dA < '2026-02-30'", "dA < '03/01/2026'", "dleap == '2025-02-29'",
           "dA < 'x'", "dA == ''", "dA < '2026-13-01'", "dA < '2026-00-10'", "dA < '2026-01-32'",
           "dA < '26-01-03'", "dA < '2026-01-03 '", "'2026-01-03x' > dA", "dA < '2100-02-29'")
  res <- filter_cases(vapply(bad, pf_if, ""), list(pf_block()), draft = TRUE)
  expect_cases(res, stats::setNames(rep(paste0("Z ", VE, "."), length(bad)), bad))
  for (b in bad) expect_true(grepl(sprintf("`%s`", b), res$stderr, fixed = TRUE), label = paste("the part", b))
})

test_that("parity A2: a date against a string NAME stays a value error citing rule 1.12.5", {
  res <- filter_cases(c(a = pf_if("dA == sdate"), b = pf_if("dA < s"), c = pf_if("sdate > dA")),
                      list(pf_block()), draft = TRUE)
  expect_cases(res, c(a = paste0("Z ", VE, "."), b = paste0("Z ", VE, "."), c = paste0("Z ", VE, ".")))
  expect_true(grepl("`dA == sdate` compares a date with a string (rule 1.12.5).", res$stderr, fixed = TRUE))
})

test_that("parity A2 control: strings compare as strings, whatever they look like, and a literal pair stays E4", {
  cases <- c(same = pf_if("sdate == '2026-01-03'"), other = pf_if("sdate == '2026-01-04'"),
             north = pf_if("s == 'north'"), dates_only = pf_if("dA < dB"))
  res <- filter_cases(cases, list(pf_block()))
  expect_cases(res, c(same = "Z yes.", other = "Z no.", north = "Z yes.", dates_only = "Z yes."))
  res2 <- filter_cases(c(lits = pf_if("'2026-01-03' > '2026-01-01'")), list(pf_block()), draft = TRUE)
  expect_cases(res2, c(lits = paste0("Z ", CE, ".")))
})

# ---- A3: number classes on a list with no collapse class -----------------------------------------------------

test_that("parity A3: .num, .pct and .p on a list print element by element, joined by a comma and a space", {
  cases <- c(num = "A `xs`{.num} z.", pct = "A `xs`{.pct} z.", p = "A `ps`{.p} z.", ints = "A `li`{.num} z.",
             keyed = "A `xs`{.num digits=\"2\"} z.")
  res <- filter_cases(cases, list(pf_block()), draft = TRUE)
  expect_identical(res$status, 0L)
  expect_cases(res, c(num = "A 1.3, 3.5 z.", pct = "A 125%, 350% z.", p = "A p = 0.046, p < 0.001 z.",
                      ints = "A 1, 2, 3 z.", keyed = "A 1.25, 3.50 z."))
  expect_false(grepl("weft", res$stderr, fixed = TRUE))
})

test_that("parity A3: .sci on a list prints element by element", {
  res <- f6_cases_html(c(sci = "A `xs`{.sci} z."), list(pf_block()))
  want <- f6_want_html(c(sci = "A 1.3 × 10^0^, 3.5 × 10^0^ z."))
  expect_identical(res$status, 0L)
  expect_identical(unname(res$got["sci"]), unname(want["sci"]))
})

test_that("parity A3: the printed-as-zero warning is one per construct, however many elements print as zero", {
  res <- filter_cases(c(z = "A `lz`{.num} z."), list(pf_block()))   # no digits: an explicit digits confirms the zero
  expect_identical(res$status, 0L)
  expect_cases(res, c(z = "A 0.0, 0.0 z."))
  expect_match(fm_headings(res$stderr), rx_warned(1), all = FALSE)
})

test_that("parity A3 control: a list of strings under a number class is still a value error naming the class", {
  cases <- c(num = "A `ls`{.num} z.", p = "A `ls`{.p} z.", pct = "A `ls`{.pct} z.")
  res <- filter_cases(cases, list(pf_block()), draft = TRUE)
  expect_cases(res, stats::setNames(rep(paste0("A ", VE, " z."), 3), names(cases)))
  expect_true(grepl("`.num` needs a number", res$stderr, fixed = TRUE))
})

test_that("parity A3 control: .date and .val on a list already join, and a collapse class still collapses", {
  cases <- c(val = "A `li`{.val} z.", and = "A `xs`{.num .and} z.", or = "A `li`{.num .or} z.")
  res <- filter_cases(cases, list(pf_block()))
  expect_cases(res, c(val = "A 1, 2, 3 z.", and = "A 1.3 and 3.5 z.", or = "A 1, 2 or 3 z."))
})

# ---- A4: date_format beyond the default (the conformance rows carry the tokens) ---------------------------------

test_that("parity A4: a date_format of the listed tokens prints in the filter", {
  blk <- carrier(dleap = fr_date("2024-02-29"), d1900 = fr_date("1900-03-01"))
  cases <- c(a = "A `dleap`{.date} z.", b = "A `d1900`{.date} z.")
  res <- filter_cases(cases, list(blk), draft = TRUE, weft_yml = "date_format: \"%d/%m/%Y\"")
  expect_cases(res, c(a = "A 29/02/2024 z.", b = "A 01/03/1900 z."))
  res2 <- filter_cases(cases, list(blk), draft = TRUE, weft_yml = "date_format: \"%A %-d %B %Y\"")
  expect_cases(res2, c(a = "A Thursday 29 February 2024 z.", b = "A Thursday 1 March 1900 z."))
  expect_false(grepl("not available in this version of weft.lua", res2$stderr, fixed = TRUE))
})

test_that("parity A4: a token outside the list is still a value error (E20)", {
  blk <- carrier(dleap = fr_date("2024-02-29"))
  for (tok in c("%U", "%H", "%p", "%Z", "%W")) {
    res <- filter_cases(c(a = "A `dleap`{.date} z."), list(blk), draft = TRUE,
                        weft_yml = sprintf("date_format: \"%%d %s\"", tok))
    expect_cases(res, c(a = paste0("A ", VE, " z.")))
    expect_true(grepl("not available in this version of weft.lua", res$stderr, fixed = TRUE), label = tok)
  }
})

# ---- A5: a failing guard names the values it read ---------------------------------------------------------------

test_that("parity A5: a failing guard reports `X was false (name = value, ...)` with each name it read", {
  g <- function(cond) sprintf("Reading [`worst`{.num}]{if=\"%s\"} NTU.", cond)
  cases <- c(one = g("worst < 50"), two = g("n_gap < n_sites"), bool = g("f"), str = g("s == 'south'"),
             dates = g("dA > dB"), literal_first = g("100 < worst"), lit_date = g("dA > '2026-06-01'"))
  res <- filter_cases(cases, list(pf_block()), draft = TRUE)
  expect_match(fm_headings(res$stderr), rx_claims(7), all = FALSE)
  want <- c(one = "worst < 50 was false (worst = 52.5)",
            two = "n_gap < n_sites was false (n_gap = 12, n_sites = 3)",
            bool = "f was false (f = false)",
            str = "s == 'south' was false (s = north)",
            dates = "dA > dB was false (dA = 2026-01-02, dB = 2026-01-03)",
            literal_first = "100 < worst was false (worst = 52.5)",
            lit_date = "dA > '2026-06-01' was false (dA = 2026-01-02)")
  for (nm in names(want)) expect_identical(pf_detail(res, nm)[1], unname(want[nm]), label = nm)
})

test_that("parity A5: each failing part of a guard is reported with the names that part read", {
  cases <- c(two = "Needs [more sites]{if=\"n_gap > 100, n_sites > 100\"}.")
  res <- filter_cases(cases, list(pf_block()), draft = TRUE)
  expect_match(fm_headings(res$stderr), rx_claims(2), all = FALSE)
  expect_true(grepl("n_gap > 100 was false (n_gap = 12)", res$stderr, fixed = TRUE))
  expect_true(grepl("n_sites > 100 was false (n_sites = 3)", res$stderr, fixed = TRUE))
  expect_false(grepl("n_gap > 100 was false (n_gap = 12, n_sites", res$stderr, fixed = TRUE))
})

test_that("parity A5 control: a guard that holds reports nothing, and a missing name is no value, not a false guard", {
  cases <- c(holds = "Needs [more]{if=\"n_gap > 10\"}.", missing = "Needs [more]{if=\"miss > 10\"}.")
  res <- filter_cases(cases, list(pf_block()), draft = TRUE)
  expect_cases(res, c(holds = "Needs more.", missing = paste0("Needs ", NV, ".")))
  expect_false(grepl("was false", res$stderr, fixed = TRUE))
})

# ---- S1: claim and level on a construct the filter resolves ---------------------------------------------------

test_that("parity S1: a `claim` or `level` key on a named value or a span is a construct error naming the key", {
  tbl <- list(
    named_claim = c("A `worst`{.num claim=\"worst < 50\"} z.", "claim"),
    named_level = c("A `worst`{.num level=\"warn\"} z.", "level"),
    named_both = c("A `worst`{.num claim=\"worst < 50\" level=\"warn\"} z.", "claim"),
    if_claim = c("A [y | z]{if=\"a\" claim=\"a\"} z.", "claim"),
    if_level = c("A [y | z]{if=\"a\" level=\"warn\"} z.", "level"),
    guard_claim = c("A [y]{if=\"a\" claim=\"a\"} z.", "claim"),
    guard_level = c("A [y]{if=\"a\" level=\"warn\"} z.", "level"),
    n_claim = c("A [core | cores]{n=\"n_sites\" claim=\"x\"} z.", "claim"),
    n_level = c("A [core | cores]{n=\"n_sites\" level=\"warn\"} z.", "level"),
    sign_claim = c("A [up | down]{sign=\"n_gap\" claim=\"x\"} z.", "claim"),
    sign_level = c("A [up | down]{sign=\"n_gap\" level=\"warn\"} z.", "level"),
    list_claim = c("A [No site was | # was | # were]{list=\"ls\" claim=\"x\"} z.", "claim"),
    list_level = c("A [No site was | # was | # were]{list=\"ls\" level=\"warn\"} z.", "level")
  )
  cases <- vapply(tbl, `[`, "", 1L)
  res <- filter_cases(cases, list(pf_block()), draft = TRUE)
  expect_cases(res, stats::setNames(rep(paste0("A ", CE, " z."), length(cases)), names(cases)))
  for (nm in names(tbl)) {
    detail <- paste(pf_detail(res, nm), collapse = " ")
    key <- tbl[[nm]][2]
    expect_true(grepl(sprintf("`%s`", key), detail, fixed = TRUE), label = paste(nm, "names the key in the report"))
  }
})

test_that("parity S1: the construct error fails the render outside draft mode", {
  for (src in c("A `worst`{.num claim=\"worst < 50\"} z.", "A `worst`{.num level=\"warn\"} z.",
                "A [y | z]{if=\"a\" claim=\"a\"} z.", "A [y | z]{if=\"a\" level=\"warn\"} z.")) {
    res <- filter_md(fm_doc(c(x = src), list(pf_block()), character())$md, to = "plain")
    expect_identical(res$status, 1L, label = src)
    expect_true(grepl("construct error", res$stderr, fixed = TRUE), label = src)
  }
})

test_that("parity S1 control: a named value and a span with ordinary keys are no construct error", {
  cases <- c(num = "A `worst`{.num digits=\"0\"} z.", span = "A [y | z]{if=\"a\"} z.")
  res <- filter_cases(cases, list(pf_block()), draft = TRUE)
  expect_cases(res, c(num = "A 53 z.", span = "A y z."))
})

test_that("parity S1 control: on an R value `level` passes through as before", {
  x <- weft_str("A `r 1.5`{.num level=\"warn\"} z.")
  expect_identical(as.character(unclass(x)), "A [1.5]{level=\"warn\"} z.")
})

# ---- S2: a span whose attribute value holds \| gets its line ------------------------------------------------

test_that("parity S2: spans in a pipe-table cell with an escaped bar in an attribute value are reported with their line", {
  md <- c(pf_block(), "",
          "| k | v |", "|---|---|",
          "| r1 | [yes \\| no]{if=\"a \\|\\| f\"} |",
          "| r2 | [more]{if=\"sbar == 'q\\|r'\"} |",
          "| r3 | [yes \\| no]{if=\"sbar == 'x\\|y'\"} |")
  l1 <- grep("^\\| r1 ", md)
  l2 <- grep("^\\| r2 ", md)
  res <- filter_md(md, to = "plain", env = c(WEFT_DRAFT = "1"))
  expect_identical(res$status, 0L)
  expect_true(grepl(sprintf("<<weft: construct error, line %d>>", l1), res$output, fixed = TRUE),
              label = "the construct error has the line of its row")
  expect_true(grepl(sprintf("<<weft: failed claim, line %d>>", l2), res$output, fixed = TRUE),
              label = "the failed guard has the line of its row")
  expect_false(grepl("<<weft: construct error>>", res$output, fixed = TRUE))
  expect_false(grepl("<<weft: failed claim>>", res$output, fixed = TRUE))
  expect_true(grepl(sprintf("  doc.md:%d  ", l1), res$stderr, fixed = TRUE), label = "report line 1")
  expect_true(grepl(sprintf("  doc.md:%d  ", l2), res$stderr, fixed = TRUE), label = "report line 2")
})

test_that("parity S2 control: the same spans outside a table are reported with their line", {
  cases <- c(bad = "Z [yes | no]{if=\"a || f\"}.", ok = "Z [yes | no]{if=\"sbar == 'x|y'\"}.")
  res <- filter_cases(cases, list(pf_block()), draft = TRUE)
  expect_cases(res, c(bad = paste0("Z ", CE, "."), ok = "Z yes."))
})

# ---- S3: rule numbers in messages --------------------------------------------------------------------------

test_that("parity S3: E19 cites 1.12.5, the no-value text cites 1.12.7, the governor values cite 1.12.6", {
  cases <- c(kinds = pf_if("s == a"), order = pf_if("s < 'z'"), novalue = "Z `nothere`{.num}.",
             n = "Z [core | cores]{n=\"3\"}.", sign = "Z [up | down]{sign=\"3\"}.",
             list = "Z [No site was | # was | # were]{list=\"3\"}.")
  res <- filter_cases(cases, list(pf_block()), draft = TRUE)
  err <- res$stderr
  expect_true(grepl("`s == a` compares a string with a bool (rule 1.12.5).", err, fixed = TRUE))
  expect_true(grepl("`s < 'z'` orders two strings; strings compare only with == and != (rule 1.12.5).", err,
                    fixed = TRUE))
  expect_true(grepl(# N94, E42
                    "no value is published under the name `nothere` in this document (rule 1.12.7).", err,
                    fixed = TRUE))
  expect_true(grepl("`3` is not a name for `n`; it takes a name, `.` or `#id` (rule 1.12.6).", err, fixed = TRUE))
  expect_true(grepl("`3` is not a name for `sign`; it takes a name or `#id` (rule 1.12.6).", err, fixed = TRUE))
  expect_true(grepl("`3` is not a name for `list`; it takes a name (rule 1.12.6).", err, fixed = TRUE))
  expect_false(grepl("compares a string with a bool (rule 1.12.4)", err, fixed = TRUE))
  expect_false(grepl("orders two strings; strings compare only with == and != (rule 1.12.4)", err, fixed = TRUE))
})
