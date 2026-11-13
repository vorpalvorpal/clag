# Package 6i, the file side of N46: a file written by weft_values_write() is read back by the filter through
# a `file=` block (N30), every record kind of N47 surviving (dev/design-6.md). The writing itself is pinned
# in test-weft-put.R (6b) and is not repeated here. Plain Pandoc through filter_md(); the file is written in
# a temporary folder, then passed to the project as text. ASCII only (non-ASCII as \u escapes).

vw_local_no_run <- function(.env = parent.frame()) {
  withr::local_envvar(c(WEFT_RUN = NA_character_), .local_envir = .env)
}

# writes a values file with weft_values_write() into a temporary folder and returns its lines (UTF-8)
vw_write <- function(..., .env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = .env)
  p <- file.path(dir, "v.json")
  weft::weft_values_write(p, ...)
  readLines(p, warn = FALSE, encoding = "UTF-8")
}

VW_PATH <- "_weft/values/survey.json"
vw_block <- function(path = VW_PATH) c(sprintf('````{.weft-values file="%s"}', path), "````")
vw_paras <- function(res) strsplit(trimws(res$output), "\n\n", fixed = TRUE)[[1]]

test_that("control: weft_values_write() makes a file that is one JSON object", {
  vw_local_no_run()
  lines <- vw_write(n = 3L)
  expect_true(jsonlite::validate(paste(lines, collapse = "\n")))
})

test_that("N46, N30: a file written by weft_values_write() is read through a `file=` block", {
  vw_local_no_run()
  s <- "caf\u00e9 \u2212 5 \u00b1 1"
  lines <- vw_write(n = 3L, depth = 3.14159, site = s)
  files <- setNames(list(lines), VW_PATH)
  md <- c(vw_block(), "", "N `n`{.val}, depth `depth`{.val}, site `site`{.val}.")
  res <- filter_md(md, files = files, to = "plain")
  expect_identical(res$status, 0L)
  expect_identical(trimws(res$output), paste0("N 3, depth 3.14159, site ", s, "."))
  expect_identical(res$stderr, "")
})

test_that("N46, N47, N30: every record kind survives the round trip, as it would in an in-document block", {
  vw_local_no_run()
  lines <- vw_write(flag = TRUE, off = FALSE, n = 3L, x = 3.14159, e = 1e23,
                    s = "north", when = as.Date("2026-11-13"), gap = NA, nothing = NULL, inf = Inf,
                    ids = c(4L, 5L, 6L), tags = c(a = "x", b = "y"), nums = c(1.5, 2.5), none = integer(0))
  names_used <- c("flag", "off", "n", "x", "e", "s", "when", "gap", "nothing", "inf")
  use <- paste(sprintf("%s `%s`{.val}.", names_used, names_used), collapse = "\n\n")
  tail_md <- c("", use)
  inline <- filter_md(c(carrier_raw(paste(lines, collapse = "\n")), tail_md), to = "plain",
                      env = c(WEFT_DRAFT = "1"))
  viafile <- filter_md(c(vw_block(), tail_md), files = setNames(list(lines), VW_PATH), to = "plain",
                       env = c(WEFT_DRAFT = "1"))
  expect_identical(inline$status, 0L)
  expect_identical(viafile$status, 0L)
  # the carrier's own source lines are shifted by the three lines of the inline block, so the markers
  # and the report entries compare after a line-number shift only; the printed text compares as it is
  expect_identical(gsub("line [0-9]+", "line N", viafile$output), gsub("line [0-9]+", "line N", inline$output))
  expect_identical(gsub(":[0-9]+  ", ":N  ", gsub("line [0-9]+", "line N", viafile$stderr)),
                   gsub(":[0-9]+  ", ":N  ", gsub("line [0-9]+", "line N", inline$stderr)))
  paras <- vw_paras(viafile)
  expect_length(paras, length(names_used))
  expect_identical(paras[[1]], "flag TRUE.")
  expect_identical(paras[[3]], "n 3.")
  expect_identical(paras[[5]], "x 3.14159.")
  expect_identical(paras[[7]], "s north.")
  expect_false(any(grepl("<<weft: (construct error|value error)", paras)))
})

test_that("N46, N47, N30: lists, keys and a missing value reach the filter as the records R wrote", {
  vw_local_no_run()
  lines <- vw_write(ids = c(4L, 5L, 6L), tags = c(a = "x", b = "y"), gap = NA)
  files <- setNames(list(lines), VW_PATH)
  md <- c(vw_block(), "", "Gap `gap`{.val}.")
  res <- filter_md(md, files = files, to = "plain", env = c(WEFT_DRAFT = "1"))
  expect_identical(res$status, 0L)
  # a missing record, not a construct error: the report says the name is missing, with R's why "NA"
  expect_match(res$stderr, fm_msg$E11("gap", "NA"), fixed = TRUE)
  expect_false(grepl("[construct error]", res$stderr, fixed = TRUE))
  # the file as read by the filter equals the file as written: a second chapter sees the same
  res2 <- filter_md(c(vw_block(), "", "Ids `ids`{.val}."), files = files, to = "plain", env = c(WEFT_DRAFT = "1"))
  expect_false(grepl("[construct error]", res2$stderr, fixed = TRUE))
  expect_false(grepl("no value is published", res2$stderr, fixed = TRUE))
})

test_that("N46, N25a, N30: a claim() that failed when the file was written counts where the name is used", {
  vw_local_no_run()
  lines <- vw_write(depth = claim(7L, . > 10), other = 1L)
  files <- setNames(list(lines), VW_PATH)
  used <- filter_md(c(vw_block(), "", "Depth `depth`{.val} m."), files = files, to = "plain",
                    env = c(WEFT_DRAFT = "1"))
  expect_match(used$output, "Depth 7<<weft: failed claim, line 4>> m.", fixed = TRUE)
  expect_match(fm_headings(used$stderr), rx_claims(1), all = FALSE)
  expect_identical(fm_entry(used$stderr, "^  doc\\.md:4  ")$detail, fm_msg$E14(". > 10", "7"))
  unused <- filter_md(c(vw_block(), "", "Other `other`{.val}."), files = files, to = "plain")
  expect_identical(unused$status, 0L)
  expect_identical(unused$stderr, "")
})

test_that("N46, N30: a second write replaces the file, and a later render reads the new one", {
  vw_local_no_run()
  dir <- withr::local_tempdir()
  p <- file.path(dir, "v.json")
  md <- c(vw_block(), "", "Use `d`{.val}.")
  weft::weft_values_write(p, d = 1L)
  r1 <- filter_md(md, files = setNames(list(readLines(p, warn = FALSE)), VW_PATH), to = "plain")
  weft::weft_values_write(p, d = 2L)
  r2 <- filter_md(md, files = setNames(list(readLines(p, warn = FALSE)), VW_PATH), to = "plain")
  expect_identical(trimws(r1$output), "Use 1.")
  expect_identical(trimws(r2$output), "Use 2.")
})

test_that("N46, N27: two chapters of one project read one written file and agree", {
  vw_local_no_run()
  lines <- vw_write(n = 4L, site = "north")
  files <- setNames(list(lines), VW_PATH)
  a <- filter_md(c(vw_block("/_weft/values/survey.json"), "", "One: `n`{.val} `site`{.val}."), files = files,
                 name = "ch1/a.md", weft_yml = "draft: false", to = "plain")
  b <- filter_md(c(vw_block("/_weft/values/survey.json"), "", "Two: `n`{.val} `site`{.val}."), files = files,
                 name = "ch2/b.md", weft_yml = "draft: false", to = "plain")
  expect_identical(trimws(a$output), "One: 4 north.")
  expect_identical(trimws(b$output), "Two: 4 north.")
})

# needs 6g
test_that("N112, N46: the ledger header holds the md5 of the file weft_values_write() wrote", {
  vw_local_no_run()
  dir <- withr::local_tempdir()
  p <- file.path(dir, "v.json")
  weft::weft_values_write(p, d = 7L)
  lines <- readLines(p, warn = FALSE)
  res <- filter_md(c(vw_block(), "", "Use `d`{.num}."), files = setNames(list(lines), VW_PATH),
                   weft_yml = c("draft: false", "ledger: true"), env = c(WEFT_RUN = "R1"))
  expect_identical(res$status, 0L)
  h <- g6_header(res)
  expect_identical(h$files[[VW_PATH]], unname(tools::md5sum(p)))
})
