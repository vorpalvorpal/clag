# Stage 7g (dev/design-7.md, 2 G, notes N100 to N102, N105, N106, messages E50, E51): the filter and
# `decision=`, in documents with named values (the weft-values blocks are written by hand and run through
# plain Pandoc, helper-filter.R). Cases where a failure is expected run in draft mode. Controls (behaviour
# that must not change) are marked. Made-up content only.

CED <- "<<weft: construct error, line {L}>>"

fd_block <- function() {
  carrier(depth = fr_float("3.14159"), k = fr_int("3"), flag = fr_bool(TRUE), l2 = fr_list_str(c("a", "b")),
          d = fr_float("-0.12"))
}

# ---- N106: accepted on a literal and a cite span, and removed ----------------------------------------------------

test_that("N106, N102: decision on a literal span, a literal div and a cite span is accepted and removed, the why too", {
  with <- c("A [0.45 mm]{.weft-literal why=\"method\" decision=\"12\"} b.",
            "::: {.weft-literal why=\"rule\" decision=\"31\"}\nBlock text.\n:::",
            "C [10 m]{cite=\"@smith2020\" decision=\"7\"} d.",
            "E [10 m]{cite=\"smith2020\" decision=\"7\"} f.",
            "G `depth`{.num} h.")
  without <- gsub(" decision=\"[0-9]+\"", "", with)
  expect_identical(without[5], with[5])
  expect_length(grep("decision", without, fixed = TRUE), 0L)
  expect_length(grep("decision", with, fixed = TRUE), 4L)
  run <- function(x) filter_md(c(fd_block(), "", unlist(lapply(x, function(l) c(l, "")))), to = "html")
  a <- run(with)
  b <- run(without)
  expect_identical(a$status, 0L)
  expect_identical(b$status, 0L)
  expect_identical(a$output, b$output)
  expect_false(grepl("decision", a$output, fixed = TRUE))
  expect_false(grepl("why", a$output, fixed = TRUE))
  expect_match(a$output, "<span class=\"weft-literal\">0.45 mm</span>", fixed = TRUE)
  expect_match(a$output, "<div class=\"weft-literal\">", fixed = TRUE)
  expect_match(a$output, "data-cites=\"smith2020\"", fixed = TRUE)
  expect_false(grepl("weft", a$stderr, fixed = TRUE))
})

test_that("N106 (control): a literal span holding a named value keeps both: the value prints, the decision is removed", {
  cases <- c(both = "Z [`depth`{.num} mm]{.weft-literal why=\"method\" decision=\"12\"} z.")
  res <- filter_cases(cases, list(fd_block()))
  expect_identical(res$status, 0L)
  expect_cases(res, c(both = "Z 3.1 mm z."))
})

# ---- E50 ---------------------------------------------------------------------------------------------------------------

test_that("N100, N106, E50: a blank decision on a literal span, a literal div or a cite span is a construct error", {
  cases <- c(span = "Z [0.45]{.weft-literal why=\"w\" decision=\"\"} z.",
             cite = "Z [10 m]{cite=\"@smith2020\" decision=\"\"} z.",
             cite_bare = "Z [10 m]{cite=\"smith2020\" decision=\"\"} z.")
  res <- filter_cases(cases, list(fd_block()), draft = TRUE)
  expect_cases(res, stats::setNames(rep(paste0("Z ", CED, " z."), length(cases)), names(cases)))
  expect_true(grepl(dp_msg$E50, res$stderr, fixed = TRUE))
  expect_match(fm_headings(res$stderr), rx_failures(3), all = FALSE)
  # the div
  res2 <- filter_md(c(fd_block(), "", "::: {.weft-literal why=\"w\" decision=\"\"}", "Text.", ":::"), to = "plain",
                    env = F7_DRAFT)
  expect_true(grepl(dp_msg$E50, res2$stderr, fixed = TRUE))
  expect_identical(filter_md(c(fd_block(), "", "::: {.weft-literal why=\"w\" decision=\"\"}", "Text.", ":::"),
                             to = "plain")$status, 1L)
})

# ---- E51 ---------------------------------------------------------------------------------------------------------------

test_that("N101, N106, E51: decision on a named value is a construct error, in each class, and the value does not print", {
  cases <- c(num = "Z `depth`{.num decision=\"3\"} z.", val = "Z `depth`{.val decision=\"3\"} z.",
             word = "Z `k`{.word decision=\"3\"} z.", key_only = "Z `depth`{decision=\"3\"} z.")
  res <- filter_cases(cases, list(fd_block()), draft = TRUE)
  expect_cases(res, stats::setNames(rep(paste0("Z ", CED, " z."), length(cases)), names(cases)))
  expect_true(grepl(dp_msg$E51("a named value"), res$stderr, fixed = TRUE))
  expect_match(fm_headings(res$stderr), rx_failures(4), all = FALSE)
  expect_identical(filter_cases(cases[1], list(fd_block()))$status, 1L)
})

test_that("N101, N106, E51: decision on an n, if, sign or list span or a text span is a construct error", {
  cases <- c(n = "Z [a site | # sites]{n=\"k\" decision=\"3\"} z.",
             `if` = "Z [yes | no]{if=\"flag\" decision=\"3\"} z.",
             sign = "Z [up # | down #]{sign=\"d\" decision=\"3\"} z.",
             list = "Z [none | # was | # were]{list=\"l2\" decision=\"3\"} z.",
             text = "Z [word]{.cap decision=\"3\"} z.")
  res <- filter_cases(cases, list(fd_block()), draft = TRUE)
  expect_cases(res, stats::setNames(rep(paste0("Z ", CED, " z."), length(cases)), names(cases)))
  expect_true(grepl(dp_msg$E51("an `n` span"), res$stderr, fixed = TRUE))
  expect_true(grepl(dp_msg$E51("a text span"), res$stderr, fixed = TRUE))
  for (nm in c("if", "sign", "list")) {
    expect_true(grepl(sprintf("not on an? `%s` span \\(rule 1\\.8\\.12\\)\\.", nm), res$stderr), label = nm)
  }
  expect_true(grepl(DP_E51_HEAD, res$stderr, fixed = TRUE))
})

test_that("N101 (control): the same constructs without decision resolve as before", {
  cases <- c(n = "Z [a site | # sites]{n=\"k\"} z.", `if` = "Z [yes | no]{if=\"flag\"} z.",
             sign = "Z [up # | down #]{sign=\"d\"} z.", list = "Z [none | # was | # were]{list=\"l2\"} z.",
             text = "Z [word]{.cap} z.", named = "Z `depth`{.num} z.")
  res <- filter_cases(cases, list(fd_block()))
  expect_identical(res$status, 0L)
  expect_cases(res, c(n = "Z 3 sites z.", `if` = "Z yes z.", sign = "Z down 0.1 z.", list = "Z a and b were z.",
                      text = "Z Word z.", named = "Z 3.1 z."))
})

test_that("N101, N106 (control): an ordinary Pandoc span with a decision key and no weft key or class is left alone", {
  res <- filter_md(c(fd_block(), "", "Z [word]{.smallcaps decision=\"3\"} z."), to = "html")
  expect_identical(res$status, 0L)
  expect_match(res$output, "word", fixed = TRUE)
  expect_false(grepl("weft", res$stderr, fixed = TRUE))
})

# ---- comments ----------------------------------------------------------------------------------------------------

test_that("N106 (control): a comment is never read: a decision on a construct inside one is no error", {
  md <- c(fd_block(), "", "<!-- `depth`{.num decision=\"3\"} and [x]{.cap decision=\"1\"} -->", "",
          "Z `depth`{.num} z.")
  res <- filter_md(md, to = "plain")
  expect_identical(res$status, 0L)
  expect_identical(f7_paras(res), "Z 3.1 z.")
  expect_false(grepl("weft", res$stderr, fixed = TRUE))
})

# ---- N105: the ledger --------------------------------------------------------------------------------------------------

test_that("N105 (control): a pointer is not recorded: the ledger of a document with and without pointers has the same entries", {
  blk <- g6_block(depth = fr_float("12.5"), n_sites = fr_int("3"), run = "R1", at = 1794822900L)
  doc <- function(with) {
    dl <- if (with) " decision=\"12\"" else ""
    dc <- if (with) " decision=\"31\"" else ""
    c(blk, "", "## Data", "",
      sprintf("Depth `depth`{.num}, filtered through [0.45 mm]{.weft-literal why=\"method\"%s} membranes.", dl), "",
      sprintf("Found [one site | # sites]{n=\"n_sites\"} [here]{cite=\"@smith2020\"%s}.", dc))
  }
  run <- function(with) filter_md(doc(with), weft_yml = G6_YML, env = c(WEFT_RUN = "R1"), to = "plain")
  a <- run(FALSE)
  b <- run(TRUE)
  expect_identical(b$status, 0L)
  la <- g6_ledger_lines(a)
  lb <- g6_ledger_lines(b)
  expect_gte(length(la), 3L)
  expect_identical(lb[-1], la[-1])
  expect_false(grepl("decision", paste(lb, collapse = "\n"), fixed = TRUE))
  expect_identical(b$output, a$output)
})
