# Stage 1c: the ten items of "Trial bugs to fix in this stage"
# (dev/design-1c.md, from dev/field-notes.md). Item 1 is covered by the
# caption, weft_str() and front-matter files; the first test here is its
# invariant: a construct is never printed raw with a zero exit.

TB_PRE <- c("k <- 3; flag <- TRUE; noflag <- FALSE; vec <- c(1, 2)")

tb_setup <- c("```{r setup, include=FALSE}", "weft::weft_setup()", "k <- 3", "```", "")
tb_head <- c("---", "title: \"t\"", "---", "")

# ---- 1: silence is impossible --------------------------------------------------

test_that("trial 1 + 2.5 + 1.10.1: a construct in fig.cap in a single rmarkdown document with no filter is never printed raw with a zero exit", {
  doc <- function(hdr, setup = tb_setup) c(tb_head, setup, hdr, "plot(1)", "```", "")
  cases <- list(
    literal   = doc("```{r a, echo=FALSE, fig.cap='Cap [a | b]{if=\"TRUE\"}'}"),
    computed  = doc("```{r b, echo=FALSE, fig.cap=paste0('Cap [a | b]', '{if=\"TRUE\"}')}"),
    cached    = doc("```{r c, echo=FALSE, cache=TRUE, fig.cap='Cap [a | b]{if=\"TRUE\"}'}"),
    unevaluated = doc("```{r d, echo=FALSE, eval=FALSE, fig.cap='Cap [a | b]{if=\"TRUE\"}'}"),
    alt       = doc("```{r e, echo=FALSE, fig.cap='Plain', fig.alt='Alt [a | b]{if=\"TRUE\"}'}")
  )
  for (nm in names(cases)) {
    res <- render_rmd(cases[[nm]], setup = FALSE, format = "knit")
    expect_never_raw(res, label = nm)
  }
  # the legal one resolved, so the invariant is not met by failing everything
  res <- render_rmd(cases$literal, setup = FALSE, format = "knit")
  expect_false(res$failed, label = res$message)
  expect_match(res$md, "Cap a", fixed = TRUE)
  # control: a hand-made raw case does trip the helper
  expect_failure(expect_never_raw(list(failed = FALSE, md = "Cap [a | b]{if=\"TRUE\"}")))
})

# ---- 2: a span split by a blank line -------------------------------------------

test_that("trial 2 + 1.1.5: a span broken by a blank line is a construct error 'split by a blank line', not a raw leak", {
  src <- c("Intro [a", "", "b]{if=\"flag\"} end.")
  res <- render_rmd(src, code = TB_PRE)
  expect_true(res$failed)
  expect_true("weft_construct_error" %in% res$error$class)
  expect_match(res$message, "split by a blank line", fixed = TRUE)
  expect_match(res$message, paste0(at_line(res, 1), "|", at_line(res, 3)))
  # a weft key on a closing bracket with no opening one in its paragraph, in a paragraph of its own
  res <- render_rmd(c("Intro.", "", "b]{n=\"k\"} end."), code = TB_PRE)
  expect_true(res$failed)
  expect_match(res$message, "split by a blank line", fixed = TRUE)
  # controls: the unbroken span, and a stray `]{...}` that holds no weft key
  ok <- render_rmd(c("Intro [a b]{if=\"flag\"} end."), code = TB_PRE)
  expect_false(ok$failed, label = ok$message)
  ok <- render_rmd(c("Intro [a", "", "b]{.foo} end."), code = TB_PRE)
  expect_false(ok$failed, label = ok$message)
})

# ---- 3: a check that returns a vector --------------------------------------------

test_that("trial 3 + 3.1: claim(vec, . > 0) where the check returns a vector says it returned N values and suggests all()", {
  e <- tryCatch(claim(c(1, 2), . > 0), error = function(e) e)
  expect_s3_class(e, "weft_claim_failed")
  expect_match(conditionMessage(e), "returned 2 values", fixed = TRUE)
  expect_match(conditionMessage(e), "all(", fixed = TRUE)
  # control: all() passes, and a single value is not told to use all()
  expect_identical(claim(c(1, 2), all(. > 0)), c(1, 2))
  e1 <- tryCatch(claim(0, . > 1), error = function(e) e)
  expect_false(grepl("returned", conditionMessage(e1), fixed = TRUE))
  # inline, in a knit: the same words are in the record and the report
  res <- render_rmd(c("Both `r claim(vec, . > 0)` rise.", "", "Fine `r claim(vec, all(. > 0))`{.num}."),
                    code = TB_PRE, in_process = TRUE)
  expect_true(res$failed)
  expect_equal(nrow(res$knit$failures), 1L)
  expect_match(res$message, "returned 2 values", fixed = TRUE)
  expect_match(res$message, "all(", fixed = TRUE)
})

# ---- 4: checks in chunk code -----------------------------------------------------

test_that("trial 4 + 2.6.2 + 2.4.4: failed checks in one chunk are one entry each, with the chunk, the check as written and the value; a Date or a factor is shown as format() shows it", {
  src <- c("```{r checks, error=TRUE, echo=FALSE, results='hide'}",
           "claim(k, . >= 10)",
           "claim(as.Date('2026-01-05'), . > as.Date('2027-01-01'))",
           "claim(factor('a'), . == 'b')",
           "claim(k, . > 0)",
           "```", "")
  res <- render_rmd(src, code = TB_PRE, in_process = TRUE)
  expect_true(res$failed)
  f <- res$knit$failures
  expect_equal(nrow(f), 3L)                      # the passing check is no entry
  expect_setequal(f$chunk, "checks")
  expect_match(res$message, "chunk checks", fixed = TRUE)
  expect_match(res$message, ". >= 10 was FALSE (value 3)", fixed = TRUE)
  expect_match(res$message, "(value 2026-01-05)", fixed = TRUE)
  expect_match(res$message, "(value a)", fixed = TRUE)
  expect_false(grepl("structure(", res$message, fixed = TRUE))
  expect_match(res$message, "as\\.Date\\(.2027-01-01.\\)")
  expect_match(res$message, "weft: 3 claims failed", fixed = TRUE)
})

# ---- 5: an #id is not built yet -----------------------------------------------------

# ---- 6: a quote inside a value -------------------------------------------------------

test_that("trial 6 + 1.2.3: if=\"x == \\\"a\\\"\" reports the quoting rule and says to bind a name, not 'spaces around ='", {
  x <- weft:::scan_text("See [a | b]{if=\"x == \\\"a\\\"\"} here.")
  err <- x$error[!is.na(x$error)]
  expect_gte(length(err), 1L)
  expect_match(err[1], "bind", ignore.case = TRUE)
  expect_false(grepl("spaces around", err[1], ignore.case = TRUE))
  # control: the message for a genuinely spaced block is the other one
  y <- weft:::scan_text("See [a | b]{if = \"x\"} here.")
  expect_true(any(!is.na(y$error)))
  expect_false(grepl("bind", y$error[!is.na(y$error)][1], ignore.case = TRUE))
})

# ---- 7: a failed guard -----------------------------------------------------------------

test_that("trial 7 + 2.6.3 + 1.5.5: a failed guard's report gives the phrase as printed and each failing condition as written, and only the failing ones", {
  src <- c("Intro.", "", "[All sites rose]{if=\"flag, noflag, k > 100\"} in the study.")
  res <- render_rmd(src, code = TB_PRE, in_process = TRUE)
  expect_true(res$failed)
  lines <- strsplit(res$message, "\n", fixed = TRUE)[[1]]
  heads <- grep(at_line(res, 3), lines)
  expect_gte(length(heads), 1L)
  # every entry for the guard names the phrase; the failing conditions, each once, are under the entries
  expect_true(all(grepl("All sites rose", lines[heads], fixed = TRUE)))
  expect_equal(sum(grepl("noflag was FALSE", lines, fixed = TRUE)), 1L)
  expect_equal(sum(grepl("k > 100 was FALSE", lines, fixed = TRUE)), 1L)
  expect_false(any(grepl("(^| )flag was", lines)))     # the true condition is not listed
  expect_match(res$message, "[phrase | ]{if=", fixed = TRUE)
  expect_equal(nrow(res$knit$failures), 2L)
  # each condition sits under an entry that names the phrase
  cond <- grep("was FALSE", lines)
  for (i in cond) {
    prev <- max(heads[heads < i])
    expect_true(prev < i && all(!grepl("^  [^ ]+:[0-9]+", lines[seq_len(i - 1)[-seq_len(prev)]])))
  }
})

# ---- 8: the post-render report -------------------------------------------------------

test_that("trial 8 + trial 7 + 2.6.6 + 2.6.2 (Quarto): the post-render report prints text unescaped, keeps two findings with no line as two entries, and gives a failed guard's phrase and each failing condition", {
  skip_if_no_quarto()
  doc <- c("---", "title: \"t\"", "engine: knitr", "---", "",
           "```{r setup, include=FALSE}", "weft::weft_setup()", "k <- 3; noflag <- FALSE", "```", "",
           "```{r checks, error=TRUE, echo=FALSE, results='hide'}",
           "claim(\"b\", . == \"a\")",
           "claim(\"d\", . == \"c\")",
           "```", "",
           "Prose [All sites rose]{if=\"noflag, k > 100\"} in the study.", "")
  dir <- mk_project(list(`_quarto.yml` = c("project:", "  type: default", "format: html"), `index.qmd` = doc))
  r <- qrender(dir)
  expect_false(identical(r$status, 0L))
  expect_match(r$log, "weft: [0-9]+ claims failed")
  expect_match(r$log, "All sites rose", fixed = TRUE)
  expect_match(r$log, "noflag was FALSE", fixed = TRUE)
  expect_match(r$log, "k > 100 was FALSE", fixed = TRUE)
  expect_match(r$log, ". == \"a\"", fixed = TRUE)
  expect_match(r$log, ". == \"c\"", fixed = TRUE)
  expect_false(grepl("\\\"", r$log, fixed = TRUE), label = "no backslash-escaped quote in the report")
  expect_equal(n_matches("chunk checks", r$log), 2L)
})

# ---- 9: the pre-render message ----------------------------------------------------------

test_that("trial 9 + 2.5.4: the pre-render message does not name use_setup(); it says to add engine: knitr to the file's front matter", {
  skip_if_no_quarto()
  body <- c("```{r setup, include=FALSE}", "weft::weft_setup()", "k <- 3", "```", "", "Found [a site | # sites]{n=\"k\"}.")
  bad <- c("---", "title: \"t\"", "---", "", body)
  dir <- mk_project(list(`_quarto.yml` = c("project:", "  type: default", "format: html"), `index.qmd` = bad))
  r <- qrender(dir)
  expect_false(identical(r$status, 0L))
  expect_match(r$log, "index.qmd", fixed = TRUE)
  expect_match(r$log, "engine: knitr", fixed = TRUE)
  expect_false(grepl("use_setup", r$log, fixed = TRUE))
  # control: with the engine named, the same project renders
  ok <- c("---", "title: \"t\"", "engine: knitr", "---", "", body)
  dir <- mk_project(list(`_quarto.yml` = c("project:", "  type: default", "format: html"), `index.qmd` = ok))
  r <- qrender(dir)
  expect_identical(r$status, 0L, label = r$log)
})

# ---- 10: a chunk with no label ---------------------------------------------------------

test_that("trial 10 + 2.6.2: a chunk with no label is located by 'the chunk at line N' as well as knitr's generated label", {
  src <- c("Intro.", "", "```{r}", "claim(k, . > 100)", "```", "", "Outro.")
  res <- render_rmd(src, code = TB_PRE, in_process = TRUE)
  expect_true(res$failed)
  m <- regmatches(res$message, regexpr("chunk at line [0-9]+", res$message))
  expect_length(m, 1L)
  n <- as.integer(sub("chunk at line ", "", m))
  header <- res$offset + 3L
  expect_true(n %in% c(header, header + 1L), label = paste("N =", n, "for a chunk whose fence is line", header))
  expect_match(res$message, "unnamed-chunk-[0-9]+")
  expect_match(res$knit$failures$chunk, "unnamed-chunk-[0-9]+")
  # control: a labelled chunk is named by its label alone
  res <- render_rmd(c("Intro.", "", "```{r named}", "claim(k, . > 100)", "```"), code = TB_PRE, in_process = TRUE)
  expect_match(res$message, "chunk named", fixed = TRUE)
  expect_false(grepl("chunk at line", res$message, fixed = TRUE))
})
