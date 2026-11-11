# Package B: exact positions (2.7), includes (2.7.4), child documents (2.1.5,
# section 21 "Child documents"), the content search stress document (section
# 21 "Positions"), and "One scanner, two uses" (section 21).
#
# Positions are looked at through failing claims: a failed check carries the
# line of its construct, in the report (non-draft) and in the marker (draft).

PRE_P <- c("k <- 3; flag <- TRUE")
FAIL <- "`r claim(k, . > 100)`"

# Lines of `lines` (1-based) that hold a failing claim in prose, i.e. outside
# a fenced block.
prose_fail_lines <- function(lines) {
  in_fence <- FALSE; out <- integer()
  for (i in seq_along(lines)) {
    if (grepl("^```", lines[i])) { in_fence <- !in_fence; next }
    if (!in_fence && grepl(FAIL, lines[i], fixed = TRUE)) out <- c(out, i)
  }
  out
}

marker_lines <- function(text) {
  m <- regmatches(text, gregexpr("<<weft: failed claim, line [0-9]+>>", text))
  as.integer(sub(".*line ([0-9]+)>>", "\\1", unlist(m)))
}

# The stress document of section 21 "Positions": repeated blocks, blank
# blocks, a block identical to a line of the chunk above it.
stress_body <- function() {
  c(
    "Opening line.",
    "",
    paste0("Same ", FAIL, " text."),
    "",
    "```{r c1}",
    "x <- 1",
    "```",
    "",
    paste0("Same ", FAIL, " text."),
    "",
    "```{r c2}",
    "NULL",
    "```",
    "```{r c3}",
    "NULL",
    "```",
    paste0("Right after two chunks ", FAIL, " here."),
    "",
    "```{r c4}",
    "txt <- \"",
    paste0("Dup ", FAIL, " line."),
    "\"",
    "```",
    "",
    paste0("Dup ", FAIL, " line."),
    "",
    paste0("Same ", FAIL, " text."),
    "",
    paste0("Closing ", FAIL, " line.")
  )
}

test_that("sanity of the stress document itself", {
  b <- stress_body()
  expect_equal(prose_fail_lines(b), c(3L, 9L, 17L, 25L, 27L, 29L))
})

test_that("2.7.1 + 2.7.2 + 21 Positions: the content search finds the right line in the stress document (LF)", {
  b <- stress_body()
  res <- render_rmd(b, code = PRE_P, env = c(WEFT_DRAFT = "1"), format = "knit")
  expect_false(res$failed, label = res$message)
  expect_equal(marker_lines(res$text), res$offset + prose_fail_lines(b))
})

test_that("21 Positions: CRLF line endings", {
  b <- stress_body()
  res <- render_rmd(b, code = PRE_P, env = c(WEFT_DRAFT = "1"), format = "knit", eol = "\r\n")
  expect_false(res$failed, label = res$message)
  expect_equal(marker_lines(res$text), res$offset + prose_fail_lines(b))
})

test_that("21 Positions: no final newline", {
  b <- stress_body()
  res <- render_rmd(b, code = PRE_P, env = c(WEFT_DRAFT = "1"), format = "knit", final_newline = FALSE)
  expect_false(res$failed, label = res$message)
  expect_equal(marker_lines(res$text), res$offset + prose_fail_lines(b))
})

test_that("21 Positions: a byte-order mark, and all three together", {
  b <- stress_body()
  res <- render_rmd(b, code = PRE_P, env = c(WEFT_DRAFT = "1"), format = "knit", bom = TRUE)
  expect_false(res$failed, label = res$message)
  expect_equal(marker_lines(res$text), res$offset + prose_fail_lines(b))
  res <- render_rmd(b, code = PRE_P, env = c(WEFT_DRAFT = "1"), format = "knit",
                    bom = TRUE, eol = "\r\n", final_newline = FALSE)
  expect_false(res$failed, label = res$message)
  expect_equal(marker_lines(res$text), res$offset + prose_fail_lines(b))
})

test_that("2.7.1: a non-draft render reports exactly those lines, each with the file name", {
  b <- stress_body()
  res <- render_rmd(b, code = PRE_P, in_process = TRUE)
  expect_true(res$failed)
  want <- res$offset + prose_fail_lines(b)
  expect_equal(sort(res$knit$failures$line), want)
  for (l in want) expect_match(res$message, sprintf("doc\\.Rmd:%d\\b", l))
})

test_that("2.7.1 + 2.7.2: the same stress document under Quarto (LF and CRLF)", {
  skip_if_no_quarto()
  b <- stress_body()
  for (eol in c("\n", "\r\n")) {
    res <- render_qmd(b, code = PRE_P, env = c(WEFT_DRAFT = "1"), eol = eol)
    expect_false(res$failed, label = res$message)
    expect_equal(marker_lines(unesc(res$text)), res$offset + prose_fail_lines(b), label = paste("quarto", deparse(eol)))
  }
})

test_that("2.7.1: the line of a construct is the block's first line plus the newlines before it", {
  b <- c("First paragraph line.", paste0("second line ", FAIL, "."), "third line.", "",
         paste0("Next ", FAIL, " paragraph"), paste0("and ", FAIL, " again."))
  res <- render_rmd(b, code = PRE_P, env = c(WEFT_DRAFT = "1"), format = "knit")
  expect_equal(marker_lines(res$text), res$offset + c(2L, 5L, 6L))
})

test_that("2.7.3: knit(text = ) has no file; positions are relative to the block", {
  withr::defer(weft_restore_knitr())
  weft::weft_setup()
  txt <- c("Intro.", "", paste0("Value ", FAIL, " here."))
  k <- 3
  err <- tryCatch(knitr::knit(text = txt, quiet = TRUE, envir = environment()), error = function(e) e)
  expect_s3_class(err, "error")
  f <- weft:::last_knit()$failures
  expect_equal(f$line, 3L)
})

# ---- includes (Quarto, 2.7.4) -------------------------------------------------

inc_files <- function() list(
  "inc.qmd" = c("Included line one.", "", paste0("Included ", FAIL, " failing."), "", "Included [a | b]{if=\"flag\"} resolved."),
  "sub/inc2.qmd" = c("Second include.", paste0("Deep ", FAIL, " failing."))
)
inc_main <- c(
  paste0("Main A ", FAIL, "."),
  "",
  "{{< include inc.qmd >}}",
  "",
  paste0("Main B ", FAIL, " after the include."),
  "",
  "{{< include sub/inc2.qmd >}}",
  "",
  paste0("Main C ", FAIL, " last.")
)

test_that("2.7.4: an error in an included file names that file and its own line; lines below an include are the main file's", {
  skip_if_no_quarto()
  res <- render_qmd(inc_main, code = PRE_P, files = inc_files())
  expect_true(res$failed)
  expect_match(res$message, at_line(res, 1))                         # main A
  expect_match(res$message, "inc\\.qmd:3\\b")                       # inside the include
  expect_match(res$message, at_line(res, 5))                         # main B, after the include
  expect_match(res$message, "inc2\\.qmd:2\\b")                      # an include in a subdirectory
  expect_match(res$message, at_line(res, 9))                         # main C
  expect_false(grepl("inc\\.qmd:5\\b", res$message), label = "the resolved span in the include is not a failure")
})

test_that("2.7.4 + 21: constructs in an included file resolve", {
  skip_if_no_quarto()
  res <- render_qmd(inc_main, code = PRE_P, files = inc_files(), env = c(WEFT_DRAFT = "1"))
  expect_false(res$failed, label = res$message)
  expect_match(res$md, "Included a resolved.", fixed = TRUE)
  expect_false(grepl("if=", res$md, fixed = TRUE))
})

# ---- child documents (2.1.5) ---------------------------------------------------

child_lines <- c("Child line.", "", paste0("In child ", FAIL, " failing."), "", "Child [a | b]{if=\"flag\"} resolved.")

test_that("2.1.5 + 21 Child documents: failures above, inside and below a child are all reported with file and line (child= option, rmarkdown)", {
  src <- c(paste0("Above ", FAIL, " (parent)."), "",
           "```{r kid, child='child.Rmd'}", "```", "",
           paste0("Below ", FAIL, " (parent)."))
  res <- render_rmd(src, code = PRE_P, files = list("child.Rmd" = child_lines), in_process = TRUE)
  expect_true(res$failed)
  f <- res$knit$failures
  expect_equal(nrow(f), 3L)
  expect_setequal(f$line[grepl("doc\\.Rmd$", f$file)], res$offset + c(1L, 6L))
  expect_equal(f$line[grepl("child\\.Rmd$", f$file)], 3L)
  expect_match(res$message, at_line(res, 1))
  expect_match(res$message, at_line(res, 6))
  expect_match(res$message, "child\\.Rmd:3\\b")
})

test_that("2.1.5: the same with knitr::knit_child() called from a chunk", {
  src <- c(paste0("Above ", FAIL, " (parent)."), "",
           "```{r kid, results='asis'}", "cat(knitr::knit_child('child.Rmd', quiet = TRUE))", "```", "",
           paste0("Below ", FAIL, " (parent)."))
  res <- render_rmd(src, code = PRE_P, files = list("child.Rmd" = child_lines), in_process = TRUE)
  expect_true(res$failed)
  f <- res$knit$failures
  expect_equal(nrow(f), 3L)
  expect_match(res$message, at_line(res, 1))
  expect_match(res$message, at_line(res, 7))
  expect_match(res$message, "child\\.Rmd:3\\b")
})

test_that("2.1.5: the child's constructs resolve, from its own file (draft, no failure)", {
  src <- c("Parent `r k`{.word}.", "", "```{r kid, child='child.Rmd'}", "```")
  res <- render_rmd(src, code = PRE_P, files = list("child.Rmd" = child_lines),
                    env = c(WEFT_DRAFT = "1"), format = "knit")
  expect_false(res$failed, label = res$message)
  expect_match(res$md, "Child a resolved.", fixed = TRUE)
  expect_match(res$md, "Parent three.", fixed = TRUE)
})

test_that("21 Child documents: under Quarto too", {
  skip_if_no_quarto()
  src <- c(paste0("Above ", FAIL, " (parent)."), "",
           "```{r kid}", "#| child: child.qmd", "```", "",
           paste0("Below ", FAIL, " (parent)."))
  res <- render_qmd(src, code = PRE_P, files = list("child.qmd" = child_lines))
  expect_true(res$failed)
  expect_match(res$message, at_line(res, 1))
  expect_match(res$message, at_line(res, 7))
  expect_match(res$message, "child\\.qmd:3\\b")
})

# ---- one scanner, two uses (section 21) ------------------------------------------

scan_doc <- c(
  "Intro with a bare `r k` value.",
  "",
  "A value `r k`{.word} and a span [# site | # sites]{n=\"k\"}.",
  "",
  "## Heading [no | `r k`{.word} items]{n=\"k\"}",
  "",
  "- list [a | b]{if=\"flag\"}",
  "- list `r k`{.num}",
  "",
  "> quote [x]{.strong} and [met | not met]{if=\"flag\"}",
  "",
  "| a | b |",
  "|---|---|",
  "| [x \\| y]{if=\"flag\"} | `r k`{.word} |",
  "",
  "```text",
  "not executed `r k`{.num} [a | b]{if=\"flag\"}",
  "```",
  "",
  "<!-- comment `r k`{.num} -->",
  "",
  "```{r chunk}",
  "z <- 1",
  "```",
  "",
  "[All [a | b]{if=\"flag\"} the `r k`{.word}]{if=\"flag\"} done.",
  "",
  "[# sample[ | s]{n=\".\"} [was | were]{n=\".\"}]{n=\"k\"}",
  "",
  "Last line `r k`{.num}"
)

agree <- function(res) {
  sf <- weft:::scan_file(res$input)
  kc <- res$knit$constructs
  expect_gt(nrow(sf), 10)
  key <- function(d) {
    d <- d[order(d$line, d$start), ]
    data.frame(kind = d$kind, line = d$line, expr = as.character(d$expr), stringsAsFactors = FALSE)
  }
  expect_equal(key(kc), key(sf))
}

test_that("21 One scanner, two uses: scan_file() and the knit-time constructs agree on kind and line", {
  res <- render_rmd(scan_doc, code = PRE_P, in_process = TRUE)
  expect_false(res$failed, label = res$message)
  agree(res)
})

test_that("21 One scanner, two uses: also for CRLF, no final newline and a byte-order mark", {
  res <- render_rmd(scan_doc, code = PRE_P, in_process = TRUE, eol = "\r\n", bom = TRUE, final_newline = FALSE)
  expect_false(res$failed, label = res$message)
  agree(res)
})

test_that("21 One scanner, two uses: the stress document and a document with nested spans", {
  res <- render_rmd(stress_body(), code = PRE_P, in_process = TRUE)
  expect_true(res$failed)                        # the claims fail; the records are still there
  sf <- weft:::scan_file(res$input)
  kc <- res$knit$constructs
  key <- function(d) { d <- d[order(d$line, d$start), ]; paste(d$kind, d$line) }
  expect_equal(key(kc), key(sf))
  expect_equal(sum(sf$kind == "bare"), 6L)       # the six prose claims; chunk lines are skipped
})
