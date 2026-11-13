# Package 2d: the condition log (dev/design-2d.md D15-D19, D27, D28). Written before the code.
# Non-ASCII is written as \uXXXX. Made-up values only.
if (!exists("d2_render")) source(Filter(file.exists, c(testthat::test_path("helper-2d.R"), testthat::test_path("..", "helper-2d.R")))[[1]])
d2_need()

D2_COND_HEADER <- "{\"weft\":\"conditions\",\"version\":1,\"source\":\"doc.Rmd\",\"output\":\"doc\"}"

d2_cond_line <- function(from, source, class, normalised, text = normalised) {
  sprintf("{\"from\":\"%s\",\"source\":\"%s\",\"class\":\"%s\",\"normalised\":\"%s\",\"text\":\"%s\"}",
          from, source, class, normalised, text)
}

d2_warn_doc <- function(n = 12) c("```{r load}", sprintf("warning('Removed %s rows')", n), "```", "", "Value `r 1`.")

test_that("2d D4: the condition log's header is exact, and a document with no conditions writes the header alone", {
  res <- d2_render(c("Value `r k`."), code = "k <- 1")
  expect_identical(d2_lines(d2_path(res$dir, conditions = TRUE)), D2_COND_HEADER)
})

d2_kinds_doc <- function() d2_memo("cond-kinds", function() {
  lines <- c(
    "Above any heading.", "",
    "```{r}", "warning('top warning')", "```", "",
    "```{r load}", "warning('Removed 12 rows')", "message('a note')", "```", "",
    "```{r oops, error=TRUE}", "stop('fatal thing')", "```", "",
    "## Results", "",
    "```{r}", "warning('below warning')", "```", "",
    "Prose `r noisy()` here.")
  d2_render(lines, code = "noisy <- function() { warning('prose warning'); 5 }")
})

test_that("2d D15: a warning in chunk `load` is one line with from, source, class, normalised and text", {
  res <- d2_kinds_doc()
  expect_false(res$failed, label = res$message)
  ln <- d2_lines(d2_path(res$dir, conditions = TRUE))
  expect_true("{\"from\":\"chunk\",\"source\":\"load\",\"class\":\"warning\",\"normalised\":\"Removed <n> rows\",\"text\":\"Removed 12 rows\"}" %in% ln)
})

test_that("2d D15: a message and an error under error=TRUE are logged with their classes", {
  c <- d2_conds(d2_kinds_doc())
  expect_length(d2_pick(c, from = "chunk", source = "load", class = "message", text = "a note"), 1L)
  expect_length(d2_pick(c, from = "chunk", source = "oops", class = "error", text = "fatal thing"), 1L)
})

test_that("2d D15: an unlabelled chunk is sourced by file and section; above any heading, by the file alone", {
  c <- d2_conds(d2_kinds_doc())
  expect_length(d2_pick(c, from = "chunk", source = "doc.Rmd#results", text = "below warning"), 1L)
  expect_length(d2_pick(c, from = "chunk", source = "doc.Rmd", text = "top warning"), 1L)
})

test_that("2d D15: a value in prose that warns is from prose, sourced by file and section", {
  c <- d2_conds(d2_kinds_doc())
  expect_length(d2_pick(c, from = "prose", source = "doc.Rmd#results", class = "warning", text = "prose warning"), 1L)
})

test_that("2d D15 + G19: no line number appears in any source", {
  src <- vapply(d2_conds(d2_kinds_doc()), `[[`, "", "source")
  expect_gt(length(src), 3L)
  expect_false(any(grepl(":[0-9]+", src)))
})

test_that("2d D15: lines are sorted on from, source, class, normalised, byte by byte", {
  c <- d2_conds(d2_kinds_doc())
  df <- data.frame(from = vapply(c, `[[`, "", "from"), source = vapply(c, `[[`, "", "source"),
                   class = vapply(c, `[[`, "", "class"), normalised = vapply(c, `[[`, "", "normalised"),
                   stringsAsFactors = FALSE)
  expect_identical(order(df$from, df$source, df$class, df$normalised, method = "radix"), seq_len(nrow(df)))
  expect_false(anyDuplicated(df) > 0)
})

test_that("2d D15: a loop that raises 'Removed 1 rows', 'Removed 2 rows', 'Removed 3 rows' gives one line with the first text", {
  res <- d2_render(c("```{r loop}", "for (i in 1:3) warning(paste('Removed', i, 'rows'))", "```"))
  c <- d2_conds(res)
  expect_length(c, 1L)
  expect_identical(c[[1]]$text, "Removed 1 rows")
  expect_identical(c[[1]]$normalised, "Removed <n> rows")
})

# ---- D16: carry-forward -------------------------------------------------------------------------

test_that("2d D16: a render with 12 rows, then one with 5000, leaves the file byte-identical", {
  dir <- withr::local_tempdir()
  d2_render(d2_warn_doc(12), dir = dir)
  p <- d2_path(dir, conditions = TRUE)
  b <- d2_bytes(p)
  d2_render(d2_warn_doc(5000), dir = dir)
  expect_identical(d2_bytes(p), b)
})

test_that("2d D16: a hand edit of `text` on disk survives the next render", {
  dir <- withr::local_tempdir()
  d2_render(d2_warn_doc(12), dir = dir)
  p <- d2_path(dir, conditions = TRUE)
  ln <- d2_lines(p)
  ln <- sub("Removed 12 rows\"}$", "Removed 7 rows\"}", ln)
  expect_true(any(grepl("Removed 7 rows", ln, fixed = TRUE)))
  writeLines(ln, p, useBytes = TRUE)
  d2_render(d2_warn_doc(40), dir = dir)
  expect_identical(d2_conds(list(dir = dir))[[1]]$text, "Removed 7 rows")
})

test_that("2d D15 + D16: a reworded message adds a line and drops the old one", {
  dir <- withr::local_tempdir()
  d2_render(d2_warn_doc(12), dir = dir)
  d2_render(c("```{r load}", "warning('Dropped 12 rows')", "```"), dir = dir)
  c <- d2_conds(list(dir = dir))
  expect_length(c, 1L)
  expect_identical(c[[1]]$normalised, "Dropped <n> rows")
})

test_that("2d D18: a log with conflict markers and two versions of one line is rewritten clean, with one of the texts", {
  dir <- withr::local_tempdir()
  d2_render(d2_warn_doc(12), dir = dir)
  p <- d2_path(dir, conditions = TRUE)
  a <- d2_cond_line("chunk", "load", "warning", "Removed <n> rows", "Removed 7 rows")
  b <- d2_cond_line("chunk", "load", "warning", "Removed <n> rows", "Removed 9 rows")
  writeLines(c(D2_COND_HEADER, "<<<<<<< HEAD", a, "=======", b, ">>>>>>> branch"), p, useBytes = TRUE)
  res <- d2_render(d2_warn_doc(12), dir = dir)
  expect_false(res$failed, label = res$message)
  ln <- d2_lines(p)
  expect_false(any(grepl("^(<<<<<<<|=======|>>>>>>>)", ln)))
  expect_length(ln, 2L)
  expect_true(d2_json(ln[2])$text %in% c("Removed 7 rows", "Removed 9 rows"))
})

test_that("2d D18: a log of a later version counts as absent, is rewritten as version 1, with a weft_ledger_warning", {
  old <- c("{\"weft\":\"conditions\",\"version\":2,\"source\":\"doc.Rmd\",\"output\":\"doc\"}",
           d2_cond_line("chunk", "load", "warning", "Removed <n> rows", "Removed 7 rows"))
  res <- d2_run(d2_warn_doc(12), files = list("_weft/ledger/doc.Rmd/doc.conditions.jsonl" = old))
  expect_false(res$failed)
  expect_length(d2_of_class(res, "weft_ledger_warning"), 1L)
  p <- d2_path(res$dir, conditions = TRUE)
  expect_identical(d2_header(p)$version, 1L)
  expect_identical(d2_entries(p)[[1]]$text, "Removed 12 rows")
})

# ---- D17, D16: left out, ANSI, caps ----------------------------------------------------------

test_that("2d D17: a message that matches the severity list in draft mode is a failure, not a log line", {
  res <- d2_render(c("```{r fit}", "message(\"boundary (singular) fit: see help('isSingular')\")", "```", "",
                     "```{r other}", "warning('ordinary')", "```"),
                   env = c(WEFT_DRAFT = "1"))
  expect_false(res$failed, label = res$message)
  expect_true(any(grepl("singular", unlist(res$knit$failures), fixed = TRUE)))
  c <- d2_conds(res)
  expect_false(any(grepl("singular", vapply(c, `[[`, "", "text"), fixed = TRUE)))
  expect_length(d2_pick(c, text = "ordinary"), 1L)
})

test_that("2d D16: ANSI styling and trailing new lines are removed from text", {
  res <- d2_render(c("```{r ansi}", "warning('\\033[31mStyled 5 rows\\033[39m')", "message('plain note\\n')", "```"))
  c <- d2_conds(res)
  w <- d2_one(c, class = "warning")
  expect_identical(w$text, "Styled 5 rows")
  expect_identical(w$normalised, "Styled <n> rows")
  expect_identical(d2_one(c, class = "message")$text, "plain note")
  expect_false(any(grepl("\033", d2_lines(d2_path(res$dir, conditions = TRUE)), fixed = TRUE)))
})

test_that("2d D16: a 3,000-character message is cut to 999 characters and an ellipsis in text and normalised", {
  res <- d2_render(c("```{r long}", "message(strrep('abc ', 750))", "```"))
  c <- d2_conds(res)
  expect_length(c, 1L)
  expect_identical(nchar(c[[1]]$text), 1000L)
  expect_identical(nchar(c[[1]]$normalised), 1000L)
  expect_true(endsWith(c[[1]]$text, "\u2026"))
  expect_true(endsWith(c[[1]]$normalised, "\u2026"))
})

# ---- the chunk cache ---------------------------------------------------------------------------

test_that("2d D15 + D22: a warning replayed from the chunk cache keeps its line on the cached render", {
  skip_if_not(rmarkdown::pandoc_available(), "pandoc is not available")
  dir <- withr::local_tempdir()
  doc <- c("```{r warn-cached, cache=TRUE}", "cat('ran\\n', file = 'ran.txt', append = TRUE)",
           "warning('Cached 5 rows')", "```", "", "Text `r 1`.")
  r1 <- d2_render(doc, dir = dir, format = "md")
  expect_false(r1$failed, label = r1$message)
  p <- d2_path(dir, conditions = TRUE)
  b <- d2_bytes(p)
  expect_length(d2_pick(d2_entries(p), source = "warn-cached", class = "warning"), 1L)
  r2 <- d2_render(doc, dir = dir, format = "md")
  expect_false(r2$failed, label = r2$message)
  expect_length(readLines(file.path(dir, "ran.txt")), 1L)
  expect_identical(d2_bytes(p), b)
})

# ---- D19: new conditions --------------------------------------------------------------------------

test_that("2d D19: in a repository with the log committed, a render adding warnings reports them since HEAD; a render with only committed ones is silent", {
  skip_if(Sys.which("git") == "")
  dir <- withr::local_tempdir()
  d2_git_init(dir)
  one <- d2_run(d2_warn_doc(12), dir = dir)
  expect_false(one$failed)
  d2_git_commit(dir)
  quiet <- d2_run(d2_warn_doc(12), dir = dir)
  expect_length(d2_of_class(quiet, "weft_new_condition"), 0L)
  more <- c("```{r load}", "warning('Removed 12 rows')", "```", "",
            "```{r extra}", "warning('Fresh problem'); message('Fresh note')", "```", "", "Value `r 1`.")
  res <- d2_run(more, dir = dir)
  m <- d2_of_class(res, "weft_new_condition")
  expect_length(m, 1L)
  txt <- conditionMessage(m[[1]])
  expect_match(txt, "weft: 2 new conditions since HEAD (rule 7.4.4)", fixed = TRUE)
  expect_match(txt, "extra  warning: Fresh problem", fixed = TRUE)
  expect_match(txt, "extra  message: Fresh note", fixed = TRUE)
  expect_false(grepl("Removed 12", txt, fixed = TRUE))
})

test_that("2d D19: outside a repository the comparison is with the log of the previous render", {
  dir <- withr::local_tempdir()
  d2_run(d2_warn_doc(12), dir = dir)
  same <- d2_run(d2_warn_doc(12), dir = dir)
  expect_length(d2_of_class(same, "weft_new_condition"), 0L)
  res <- d2_run(c(d2_warn_doc(12), "", "```{r extra}", "warning('Fresh problem')", "```"), dir = dir)
  m <- d2_of_class(res, "weft_new_condition")
  expect_length(m, 1L)
  expect_match(conditionMessage(m[[1]]), "since the last render", fixed = TRUE)
  expect_match(conditionMessage(m[[1]]), "Fresh problem", fixed = TRUE)
})

test_that("2d D19: a new condition fails nothing, in any mode", {
  dir <- withr::local_tempdir()
  d2_run(d2_warn_doc(12), dir = dir)
  res <- d2_run(c(d2_warn_doc(12), "", "```{r extra}", "warning('Fresh problem')", "```"), dir = dir,
                env = c(WEFT_DRAFT = NA))
  expect_false(res$failed)
  expect_length(d2_of_class(res, "weft_new_condition"), 1L)    # reported, and the render still succeeds
})

test_that("2d D21 + D19: not set up, there is no message and no file", {
  res <- d2_run(d2_warn_doc(12), set_up = FALSE)
  expect_length(d2_of_class(res, "weft_new_condition"), 0L)
  expect_false(dir.exists(file.path(res$dir, "_weft")))
})

# ---- D28 --------------------------------------------------------------------------------------------

test_that("2d D28: last_knit()$condition_log equals read_condition_log() of the file; conditions keeps its stage-1 columns and rows", {
  res <- d2_kinds_doc()
  l <- weft:::read_condition_log(d2_path(res$dir, conditions = TRUE))
  attr(l, "header") <- NULL
  expect_s3_class(res$knit$condition_log, "weft_condition_log")
  expect_equal(res$knit$condition_log, l)
  expect_identical(names(l), c("from", "source", "class", "normalised", "text"))
  cond <- res$knit$conditions
  expect_true(all(c("source", "class", "text", "normalised") %in% names(cond)))
  expect_true(any(cond$source == "load" & cond$class == "warning" & cond$text == "Removed 12 rows"))
  expect_true(any(grepl("doc\\.Rmd:[0-9]+$", cond$source) & grepl("prose warning", cond$text, fixed = TRUE)))
})

test_that("2d D27: read_condition_log() is strict about its header and lenient on request", {
  ok <- c(D2_COND_HEADER, d2_cond_line("chunk", "load", "warning", "Removed <n> rows", "Removed 12 rows"))
  l <- weft:::read_condition_log(lines = ok)
  expect_s3_class(l, c("weft_condition_log", "data.frame"))
  expect_identical(nrow(l), 1L)
  expect_identical(l$text, "Removed 12 rows")
  e <- tryCatch(weft:::read_condition_log(lines = c(sub("conditions", "ledger", ok[1]), ok[2])), error = function(e) e)
  expect_s3_class(e, "weft_ledger_error")
  bad <- c(ok[1], ok[2], "<<<<<<< HEAD")
  e2 <- tryCatch(weft:::read_condition_log(lines = bad), error = function(e) e)
  expect_s3_class(e2, "weft_ledger_error")
  expect_match(conditionMessage(e2), "line 3 of", fixed = TRUE)
  expect_identical(nrow(weft:::read_condition_log(lines = bad, lenient = TRUE)), 1L)
  # a missing header is accepted when lenient; the first of two lines of one key wins is D18's rule
  expect_identical(nrow(weft:::read_condition_log(lines = ok[2], lenient = TRUE)), 1L)
})
