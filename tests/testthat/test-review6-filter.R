# Package 6L, part 1: the filter's review fixes (dev/review-stage6.md, findings 1 to 8, and its "Rulings"
# table). Written from the review and its rulings only; no implementation was read for the expected texts.
# Plain Pandoc through filter_md() (helper-filter.R). Every test is labelled with its finding number.
# Controls that hold today are marked "control". ASCII only: non-ASCII is written as \u escapes.
# Part 2 (findings 9 to 20 and the open findings) is test-review6-filter-2.R.

R6_VE <- "<<weft: value error, line {L}>>"
R6_NV <- "<<weft: no value, line {L}>>"
R6_CE <- "<<weft: construct error, line {L}>>"
R6_NBSP <- "\u00a0"

# ---- 1: unit= on a named value ----------------------------------------------------------------------------

test_that("review-6 #1: a named value whose only weft key is unit= is a failure with E20's text, never code", {
  md <- c(carrier(x = fr_float("2.5")), "", "A `x`{unit=\"m\"} B `x`{UNIT=\"m\"} C.")
  res <- filter_md(md)
  expect_identical(res$status, 1L)
  expect_true(grepl(fm_msg$E20_key("unit"), res$stderr, fixed = TRUE), label = "E20 for unit=")
  expect_false(grepl("<code>x</code>", res$output, fixed = TRUE), label = "the span is not left as code")
})

test_that("review-6 #1: in draft mode each such value is a value error in its place, as `.num unit=` already is", {
  cases <- c(lower = "A `x1`{unit=\"m\"} z.", upper = "A `x2`{UNIT=\"m\"} z.", with_class = "A `x3`{.num unit=\"m\"} z.",
             with_id = "A `x4`{#a unit=\"m\"} z.")
  res <- filter_cases(cases, list(carrier(x1 = fr_float("2.5"), x2 = fr_float("2.5"), x3 = fr_float("2.5"),
                                          x4 = fr_float("2.5"))), draft = TRUE)
  expect_identical(res$status, 0L)
  expect_cases(res, stats::setNames(rep(paste0("A ", R6_VE, " z."), length(cases)), names(cases)))
  expect_true(grepl(fm_msg$E20_key("unit"), res$stderr, fixed = TRUE))
})

test_that("review-6 #1: weft-check.lua alone also fails a named value that carries unit=", {
  res <- filter_md("A `x`{unit=\"m\"} B.", filters = "weft-check.lua")
  expect_identical(res$status, 1L)
  expect_true(nzchar(res$stderr))
})

test_that("review-6 #1 control: a code span with no weft key or class stays code, with unit= on code that is no name", {
  res <- filter_md(c(carrier(x = fr_float("2.5")), "", "Plain `x` and `x`{.python}."))
  expect_identical(res$status, 0L)
  expect_match(res$output, "<code>x</code>", fixed = TRUE)
})

# ---- 2: a governor value Pandoc does not read as a span ---------------------------------------------------

r6_gov_block <- function() {
  carrier(k = fr_int("2"), ok = fr_bool(TRUE), n_gap = fr_int("12"))
}

test_that("review-6 #2: a governor value with a leading space is not a span, and weft-check.lua fails the render", {
  cases <- list(
    n = c("A [one | many]{n=\" k\"} B.", "n"),
    if_double = c("A [yes | no]{if=\" ok\"} B.", "if"),
    if_single = c("A [yes | no]{if=' ok'} B.", "if"),
    sign = c("A [up | down]{sign=\" k\"} B.", "sign"),
    list = c("A [none | one | many]{list=\" k\"} B.", "list"))
  for (nm in names(cases)) {
    res <- filter_md(c(r6_gov_block(), "", cases[[nm]][1]), to = "plain")
    expect_identical(res$status, 1L, label = paste("status for", nm))
    expect_true(grepl(paste0(cases[[nm]][2], "="), res$stderr, fixed = TRUE), label = paste("the key named for", nm))
  }
})

test_that("review-6 #2: the case removed from test-filter-if.R, a condition padded with spaces, expects a failure", {
  md <- c(r6_gov_block(), "", "A [met | not met]{if=\"  n_gap > 10  \"} B.")
  res <- filter_md(md, to = "plain")
  expect_identical(res$status, 1L)
  expect_true(grepl("if=", res$stderr, fixed = TRUE))
  # in draft mode the render goes on, and the text is never printed as if it were resolved
  res2 <- filter_md(md, to = "plain", env = c(WEFT_DRAFT = "1"))
  expect_false(grepl("A met B", res2$output, fixed = TRUE))
  expect_false(grepl("A not met B", res2$output, fixed = TRUE))
})

test_that("review-6 #2 control: the same governors with no padding resolve", {
  res <- filter_md(c(r6_gov_block(), "", "A [one | many]{n=\"k\"} B. C [yes | no]{if=\"ok\"} D."), to = "plain")
  expect_identical(res$status, 0L)
  expect_identical(trimws(res$output), "A many B. C yes D.")
})

test_that("review-6 #2 control: the syntax shown as code, in a document the filter resolves, is not reported", {
  res <- filter_md(c(r6_gov_block(), "", "Write `[a | b]{n=\" k\"}` like this, or a fence:", "",
                     "```", "[a | b]{n=\" k\"}", "```"), to = "plain")
  expect_identical(res$status, 0L)
  expect_false(grepl("weft", res$stderr, fixed = TRUE))
})

# ---- 3: a no-break-space big_mark, and text holding a-grave ------------------------------------------------

r6_nbsp_block <- function() carrier(f = fr_float("1234.5"), i = fr_int("1234567"), k = fr_int("1234"))
r6_nbsp_cases <- c(f = "`f`{.num}", i = "`i`{.num}", k = "`k`{.num}")

test_that("review-6 #3: big_mark of U+00A0, unquoted in _weft.yml, prints the right bytes", {
  res <- filter_cases(r6_nbsp_cases, list(r6_nbsp_block()), weft_yml = paste0("big_mark: ", R6_NBSP))
  expect_identical(res$status, 0L)
  expect_cases(res, c(f = paste0("1", R6_NBSP, "234.5"), i = paste0("1", R6_NBSP, "234", R6_NBSP, "567"),
                      k = paste0("1", R6_NBSP, "234")))
  expect_true(all(vapply(res$got, r6_valid_utf8, logical(1))))
})

test_that("review-6 #3: big_mark of U+00A0 in a document's weft: mapping prints the right bytes", {
  res <- filter_cases(r6_nbsp_cases, list(r6_nbsp_block()),
                      head = c("---", "weft:", paste0("  big_mark: ", R6_NBSP), "---", ""))
  expect_cases(res, c(f = paste0("1", R6_NBSP, "234.5"), i = paste0("1", R6_NBSP, "234", R6_NBSP, "567"),
                      k = paste0("1", R6_NBSP, "234")))
})

test_that("review-6 #3 control: a quoted U+00A0 and a plain space big_mark already print as written", {
  res <- filter_cases(r6_nbsp_cases, list(r6_nbsp_block()), weft_yml = paste0("big_mark: \"", R6_NBSP, "\""))
  expect_cases(res, c(f = paste0("1", R6_NBSP, "234.5"), i = paste0("1", R6_NBSP, "234", R6_NBSP, "567"),
                      k = paste0("1", R6_NBSP, "234")))
  res2 <- filter_cases(r6_nbsp_cases, list(r6_nbsp_block()), weft_yml = "big_mark: \" \"")
  expect_cases(res2, c(f = "1 234.5", i = "1 234 567", k = "1 234"))
})

test_that("review-6 #3: the report, the stamp and the collection line keep a-grave (U+00E0) whole", {
  md <- c(carrier(k = fr_int("2")), "", "A [voil\u00e0 | l\u00e0]{if=\"nope\"} B.")
  res <- filter_md(md, weft_yml = "serial_comma: true", collect = TRUE, to = "plain")
  expect_true(r6_valid_utf8(res$stderr), label = "stderr is valid UTF-8 with no replacement character")
  expect_true(suppressWarnings(grepl("voil\u00e0", res$stderr, fixed = TRUE)), label = "the report shows the word as written")
  expect_false(grepl("(unreadable text)", paste(res$collected, collapse = "\n"), fixed = TRUE),
               label = "the collection line is readable")
  expect_true(grepl("voil\\u00e0", paste(res$collected, collapse = "\n"), fixed = TRUE),
              label = "the collection line holds the escaped a-grave")
  stamp_text <- res$files[[G6_STAMP]]
  expect_false(is.null(stamp_text), label = "the filter wrote a stamp")
  expect_false(grepl("(unreadable text)", stamp_text, fixed = TRUE), label = "the stamp is readable")
  expect_true(grepl("voil\\u00e0", stamp_text, fixed = TRUE), label = "the stamp holds the escaped a-grave")
})

test_that("review-6 #3: a value whose text holds a-grave prints whole, through .val, .cap and .and", {
  blk <- carrier(s = fr_str("voil\u00e0 la"), l = fr_list_str(c("l\u00e0", "ou\u00e0")))
  res <- filter_cases(c(val = "`s`{.val}", cap = "`s`{.val .cap}", and = "`l`{.val .and}"), list(blk))
  expect_cases(res, c(val = "voil\u00e0 la", cap = "Voil\u00e0 la", and = "l\u00e0 and ou\u00e0"))
})

# ---- 4: exact integers past 2^53 through .ord --------------------------------------------------------------

test_that("review-6 #4: .ord builds its digits and suffix from the exact integer, not from a double", {
  blk <- carrier(k = fr_int("9007199254740993"), m = fr_int("123456789012345678901"),
                 e = fr_int("9007199254740994"), t = fr_int("9007199254740995"),
                 h = fr_int("9007199254741012"), neg_ok = fr_int("-9007199254740993"),
                 big = fr_int("100000000000000011"))
  cases <- c(k_ord = "`k`{.ord}", k_num = "`k`{.num}", m_ord = "`m`{.ord}", e_ord = "`e`{.ord}",
             t_ord = "`t`{.ord}", h_ord = "`h`{.ord}", big_ord = "`big`{.ord}")
  res <- filter_cases(cases, list(blk), draft = TRUE)
  expect_cases(res, c(k_ord = "9,007,199,254,740,993rd", k_num = "9,007,199,254,740,993",
                      m_ord = "123,456,789,012,345,678,901st", e_ord = "9,007,199,254,740,994th",
                      t_ord = "9,007,199,254,740,995th", h_ord = "9,007,199,254,741,012th",
                      big_ord = "100,000,000,000,000,011th"))
})

test_that("review-6 #4: .word and .count keep the exact digits of an integer past 2^53", {
  blk <- carrier(k = fr_int("9007199254740993"), m = fr_int("123456789012345678901"))
  res <- filter_cases(c(w = "`k`{.word}", c = "`m`{.count}", wm = "`m`{.word}"), list(blk), draft = TRUE)
  expect_cases(res, c(w = "9,007,199,254,740,993", c = "123,456,789,012,345,678,901",
                      wm = "123,456,789,012,345,678,901"))
})

# ---- 5: flow-style mappings --------------------------------------------------------------------------------

r6_cfg_block <- function() carrier(g = fr_float("3.14159"), f = fr_float("1234.5"), i = fr_int("1234567"))
r6_cfg_cases <- c(g = "`g`{.num}", f = "`f`{.num}", i = "`i`{.num}")

test_that("review-6 #5: a flow-style weft: mapping in the front matter is read as the block form is", {
  block <- filter_cases(r6_cfg_cases, list(r6_cfg_block()), head = c("---", "weft:", "  digits: 3", "---", ""))
  flow <- filter_cases(r6_cfg_cases, list(r6_cfg_block()), head = c("---", "weft: {digits: 3}", "---", ""))
  expect_identical(block$status, 0L)
  expect_cases(block, c(g = "3.142", f = "1,234.500", i = "1,234,567"))
  expect_identical(flow$status, 0L)
  expect_cases(flow, c(g = "3.142", f = "1,234.500", i = "1,234,567"))
})

test_that("review-6 #5: a flow-style weft: mapping with several keys, a trailing comment, and the document wins", {
  flow <- filter_cases(r6_cfg_cases, list(r6_cfg_block()),
                       head = c("---", "weft: {digits: 2, big_mark: \" \"}   # two keys", "---", ""))
  expect_cases(flow, c(g = "3.14", f = "1 234.50", i = "1 234 567"))
  wins <- filter_cases(r6_cfg_cases, list(r6_cfg_block()), weft_yml = "digits: 5",
                       head = c("---", "weft: {digits: 3}", "---", ""))
  expect_cases(wins, c(g = "3.142", f = "1,234.500", i = "1,234,567"))
})

test_that("review-6 #5: a flow-style formatters: mapping names a project formatter, so a named value on it is E21", {
  cases <- c(a = "A `g`{.compact} z.")
  blk <- list(r6_cfg_block())
  block <- filter_cases(cases, blk, draft = TRUE, weft_yml = c("formatters:", "  .compact:", "    digits: 2"))
  expect_cases(block, c(a = paste0("A ", R6_VE, " z.")))
  expect_true(grepl(fm_msg$E21("compact"), block$stderr, fixed = TRUE), label = "block form: E21")
  flow <- filter_cases(cases, blk, draft = TRUE, weft_yml = "formatters: {.compact: {digits: 2}}")
  expect_cases(flow, c(a = paste0("A ", R6_VE, " z.")))
  expect_true(grepl(fm_msg$E21("compact"), flow$stderr, fixed = TRUE), label = "flow form: E21")
})

# ---- 7: a values file whose run is not the current run ------------------------------------------------------

R6_VFILE <- "_weft/values/survey.json"
r6_file_block <- function(path) c(sprintf("````{.weft-values file=\"%s\"}", path), "````")
r6_vfile <- function(run = "PIPE-1") {
  stats::setNames(list(carrier_json(n_sites = fr_int("12"), members = sprintf("\"run\":\"%s\",\"at\":1794822900", run))),
                  R6_VFILE)
}

test_that("review-6 #7: a values file of another run is not stale: no E34 notice, and fresh is not false", {
  md <- c(r6_file_block(R6_VFILE), "", "Sites `n_sites`{.num}.")
  res <- filter_md(md, files = r6_vfile("PIPE-1"), weft_yml = G6_YML, env = c(WEFT_RUN = "RENDER-2"), to = "plain")
  expect_identical(res$status, 0L)
  expect_true(grepl("Sites 12.", res$output, fixed = TRUE))
  expect_false(grepl("served from freeze", res$stderr, fixed = TRUE), label = "no E34 notice")
  expect_false(grepl("not this run", res$stderr, fixed = TRUE), label = "no run notice")
  s <- g6_stamp(res)
  expect_false(identical(s$fresh, FALSE), label = "the file leaves fresh alone")
})

test_that("review-6 #7: with an inline block of this run and a values file of another run the stamp is fresh", {
  md <- c(r6_file_block(R6_VFILE), "", g6_block(depth = fr_float("12.5"), run = "RENDER-2", at = 1794822900L), "",
          "Sites `n_sites`{.num} depth `depth`{.num}.")
  res <- filter_md(md, files = r6_vfile("PIPE-1"), weft_yml = G6_YML, env = c(WEFT_RUN = "RENDER-2"), to = "plain")
  expect_identical(res$status, 0L)
  expect_false(grepl("served from freeze", res$stderr, fixed = TRUE))
  expect_true(isTRUE(g6_stamp(res)$fresh))
})

test_that("review-6 #7 control: an inline block of another run is still stale, with the notice and fresh false", {
  md <- c(g6_block(depth = fr_float("12.5"), run = "PIPE-1", at = 1794822900L), "", "Depth `depth`{.num}.")
  res <- filter_md(md, weft_yml = G6_YML, env = c(WEFT_RUN = "RENDER-2"), to = "plain")
  expect_identical(res$status, 0L)
  expect_true(grepl("served from freeze", res$stderr, fixed = TRUE))
  expect_identical(g6_stamp(res)$fresh, FALSE)
})

# ---- 8: settings R accepts -----------------------------------------------------------------------------------

test_that("review-6 #8: draft: TRUE is draft mode, as in R: a missing name is a marker and the render passes", {
  res <- filter_md(c(carrier(g = fr_float("3.14159")), "", "A `nope`{.num} z."), weft_yml = "draft: TRUE", to = "plain")
  expect_identical(res$status, 0L)
  expect_true(grepl("<<weft: no value, line 5>>", res$output, fixed = TRUE))
  expect_false(grepl("is not a true or false", res$stderr, fixed = TRUE), label = "no E33 for the boolean")
})

test_that("review-6 #8: booleans in any letter case and whole-valued decimals are read, with no E33", {
  yml <- c("serial_comma: True", "digits: 2.0", "thousands_from: 10000.0", "ledger: FALSE")
  blk <- carrier(g = fr_float("3.14159"), k = fr_int("1234"), l = fr_list_str(c("a", "b", "c")))
  res <- filter_cases(c(g = "`g`{.num}", k = "`k`{.num}", l = "`l`{.val .and}"), list(blk), weft_yml = yml)
  expect_identical(res$status, 0L)
  expect_cases(res, c(g = "3.14", k = "1234", l = "a, b, and c"))
  expect_false(grepl("the default is used", res$stderr, fixed = TRUE), label = "no E33")
})

test_that("review-6 #8: the same in a document's weft: mapping", {
  blk <- carrier(g = fr_float("3.14159"), l = fr_list_str(c("a", "b", "c")))
  res <- filter_cases(c(g = "`g`{.num}", l = "`l`{.val .and}"), list(blk),
                      head = c("---", "weft:", "  serial_comma: TRUE", "  digits: 3.0", "---", ""))
  expect_identical(res$status, 0L)
  expect_cases(res, c(g = "3.142", l = "a, b, and c"))
})

test_that("review-6 #8 control: a decimal that is not whole, and a word, are still E33", {
  res <- filter_md(c(carrier(g = fr_float("3.14159")), "", "A `g`{.num} z."), weft_yml = c("digits: 2.5", "draft: maybe"),
                   to = "plain")
  expect_identical(res$status, 1L)
  expect_true(grepl("`digits: 2.5` is not a whole number; the default is used (rule 9.1.6).", res$stderr, fixed = TRUE))
  expect_true(grepl("`draft: maybe` is not a true or false; the default is used (rule 9.1.6).", res$stderr, fixed = TRUE))
})
