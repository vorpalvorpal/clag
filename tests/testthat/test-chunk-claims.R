# Stage 7e (dev/design-7.md, 2 E, notes N70 to N79): chunk claims collected, opt in with the
# setting `chunk_claims: collect`. Expected values and texts come from the design (2 E, 7: E30,
# E31). Controls (existing behaviour that must not change) are marked as such.

TWO_BAD <- c(
  "Intro.", "",
  cc7_chunk("claim-a", "n_up <- claim(shift_n, . >= 10)"),
  cc7_chunk("claim-ok", "ok <- claim(k, . > 0)"),
  cc7_chunk("claim-b", "share <- claim(low_n, . >= 5)"),
  cc7_chunk("after", "writeLines(c(format(n_up), format(share), format(ok)), 'seen.txt')"),
  "End."
)

# ---- N70 the setting ---------------------------------------------------------

test_that("N70 + E30: any value other than stop or collect is a weft_config_error", {
  res <- cc7_run(c("Text.", ""), setting = "sometimes")
  expect_true(res$failed)
  expect_true(inherits(res$error, "weft_config_error"))
  expect_match(cc7_msg(res), "The setting `chunk_claims` must be stop or collect.", fixed = TRUE)
})

test_that("N70: collect and stop are accepted (control for E30)", {
  for (s in c("collect", "stop")) {
    res <- cc7_run(c("Text.", ""), setting = s)
    expect_false(res$failed, label = paste(s, cc7_msg(res)))
  }
})

test_that("N70: a document's own weft: front matter sets it", {
  res <- d2_run(TWO_BAD, set_up = FALSE, code = CC7_PRE, may_fail = TRUE,
                files = list("_weft.yml" = "draft: false"),
                front = c("weft:", "  chunk_claims: collect"))
  expect_equal(nrow(cc7_fail(res)), 2L)
  expect_equal(cc7_seen(res, "seen.txt")[1], "7")
})

# ---- N71, N73, N79 collected ---------------------------------------------------

test_that("N71 + N73 + N79: two failing chunk claims and a passing one; the knit reaches the end", {
  res <- cc7_run(TWO_BAD)
  expect_true(res$failed)
  expect_true(inherits(res$error, "weft_failures"))
  # the knit went on: the last chunk ran, and claim() returned its value
  expect_equal(cc7_seen(res, "seen.txt"), c("7", "2", "3"))
  f <- cc7_fail(res)
  expect_equal(nrow(f), 2L)
  expect_equal(f$kind, c("failed claim", "failed claim"))
  expect_equal(f$chunk, c("claim-a", "claim-b"))
  expect_match(f$detail[1], ". >= 10 was FALSE (value 7)", fixed = TRUE)
  expect_match(f$detail[2], ". >= 5 was FALSE (value 2)", fixed = TRUE)
  # one report, both in the order collected
  msg <- cc7_msg(res)
  expect_match(msg, "weft: 2 claims failed", fixed = TRUE)
  a <- regexpr("claim-a", msg, fixed = TRUE)[1]
  b <- regexpr("claim-b", msg, fixed = TRUE)[1]
  expect_true(a > 0 && b > a)
  expect_false(grepl("claim-ok", msg, fixed = TRUE))
})

test_that("N71: claim() returns x visibly in the chunk's output", {
  res <- cc7_run(c(cc7_chunk("show", "claim(shift_n, . >= 10)")), draft = TRUE)
  expect_false(res$failed, label = cc7_msg(res))
  md <- readLines(file.path(res$dir, "doc.md"), warn = FALSE)
  expect_true(any(grepl("[1] 7", md, fixed = TRUE)))
  expect_equal(nrow(cc7_fail(res)), 1L)
})

test_that("N73: draft mode reports and does not fail", {
  res <- cc7_run(TWO_BAD, draft = TRUE)
  expect_false(res$failed, label = cc7_msg(res))
  expect_equal(nrow(cc7_fail(res)), 2L)
})

test_that("N71: a function defined in one chunk and called in a later one is collected", {
  src <- c(cc7_chunk("def", "chk <- function(x) claim(x, . >= 10)"),
           cc7_chunk("call", "y <- chk(shift_n)"),
           cc7_chunk("tail", "writeLines('reached', 'seen.txt')"))
  res <- cc7_run(src)
  expect_equal(cc7_seen(res, "seen.txt"), "reached")
  f <- cc7_fail(res)
  expect_equal(nrow(f), 1L)
  expect_equal(f$chunk, "call")
})

test_that("N71: a file the chunk source()s is collected", {
  src <- c(cc7_chunk("mk", "writeLines('claim(7, . >= 10)', 'bad.R')"),
           cc7_chunk("src", "source('bad.R')"),
           cc7_chunk("tail", "writeLines('reached', 'seen.txt')"))
  res <- cc7_run(src)
  expect_equal(cc7_seen(res, "seen.txt"), "reached")
  f <- cc7_fail(res)
  expect_equal(nrow(f), 1L)
  expect_equal(f$kind, "failed claim")
  expect_equal(f$chunk, "src")
})

test_that("N71: chunk options knitr evaluates are collected", {
  src <- c(cc7_chunk("opt", "x <- 1", opts = "echo = as.logical(claim(shift_n, . >= 10))"),
           cc7_chunk("tail", "writeLines('reached', 'seen.txt')"))
  res <- cc7_run(src)
  expect_equal(cc7_seen(res, "seen.txt"), "reached")
  f <- cc7_fail(res)
  expect_equal(nrow(f), 1L)
  expect_equal(f$kind, "failed claim")
})

# ---- control: stop is today's behaviour -----------------------------------------

test_that("control N70: under stop (default and written) the first failing claim stops the knit", {
  for (s in list(NULL, "stop")) {
    res <- cc7_run(TWO_BAD, setting = s)
    expect_true(res$failed)
    expect_match(cc7_msg(res), ". >= 10", fixed = TRUE)
    expect_null(cc7_seen(res, "seen.txt"))
    expect_false(inherits(res$error, "weft_claims_collected"))
  }
})

# ---- N72 still stops ------------------------------------------------------------

test_that("control N72: outside a knit a claim stops, whatever the setting", {
  we <- weft:::weft_env
  old <- we$config
  on.exit(we$config <- old)
  we$config <- utils::modifyList(weft:::current_config(), list(chunk_claims = "collect"))
  expect_error(claim(7, . >= 10), class = "weft_claim_failed")
})

test_that("N72: a claim in a running targets target stops under collect", {
  skip_if_not_installed("targets")
  testthat::local_mocked_bindings(tar_active = function() TRUE, .package = "targets")
  src <- c(cc7_chunk("tgt", "v <- claim(shift_n, . >= 10)"),
           cc7_chunk("tail", "writeLines('reached', 'seen.txt')"))
  res <- cc7_run(src)
  expect_true(res$failed)
  expect_match(cc7_msg(res), ". >= 10", fixed = TRUE)
  expect_null(cc7_seen(res, "seen.txt"))
})

test_that("control N72: with targets installed and no target running a claim is collected", {
  skip_if_not_installed("targets")
  src <- c(cc7_chunk("tgt", "v <- claim(shift_n, . >= 10)"),
           cc7_chunk("tail", "writeLines('reached', 'seen.txt')"))
  res <- cc7_run(src)
  expect_equal(cc7_seen(res, "seen.txt"), "reached")
  expect_equal(nrow(cc7_fail(res)), 1L)
})

test_that("N72: a claim in a callr worker is an ordinary error in the chunk, not a collected failure", {
  skip_if_not_installed("callr")
  skip_on_cran()
  lib <- weft_test_lib()
  src <- c(cc7_chunk("worker",
                     sprintf("r <- try(callr::r(function() weft::claim(7, . >= 10), libpath = c(%s, .libPaths())), silent = TRUE)",
                             deparse(lib)),
                     "writeLines(c(class(r)[1], as.character(r)), 'seen.txt')"))
  res <- cc7_run(src)
  seen <- cc7_seen(res, "seen.txt")
  expect_equal(seen[1], "try-error")
  expect_true(any(grepl(". >= 10", seen, fixed = TRUE)))
  expect_equal(nrow(cc7_fail(res)), 0L)
})

# ---- N75 unchanged ---------------------------------------------------------------

test_that("control N75: level = warn is never collected and never stops", {
  src <- c(cc7_chunk("w", "v <- claim(shift_n, . >= 10, level = 'warn')"),
           cc7_chunk("tail", "writeLines('reached', 'seen.txt')"))
  res <- cc7_run(src)
  expect_false(res$failed, label = cc7_msg(res))
  expect_equal(nrow(cc7_fail(res)), 0L)
  expect_equal(nrow(res$knit$warnings), 1L)
})

test_that("N75: a claim inside try() raises nothing and is recorded", {
  src <- c(cc7_chunk("tr", "r <- try(claim(shift_n, . >= 10), silent = TRUE)",
                     "writeLines(class(r)[1], 'seen.txt')"))
  res <- cc7_run(src)
  expect_equal(cc7_seen(res, "seen.txt"), "numeric")
  f <- cc7_fail(res)
  expect_equal(nrow(f), 1L)
  expect_equal(f$chunk, "tr")
  expect_true(res$failed)
})

test_that("N75: a chunk with error: true goes on, and the render fails at the end listing the claim", {
  src <- c(cc7_chunk("eb", "claim(shift_n, . >= 10)", opts = "error = TRUE"),
           cc7_chunk("tail", "writeLines('reached', 'seen.txt')"))
  res <- cc7_run(src)
  expect_equal(cc7_seen(res, "seen.txt"), "reached")
  expect_true(res$failed)
  expect_true(inherits(res$error, "weft_failures"))
  expect_match(cc7_msg(res), "eb", fixed = TRUE)
  expect_match(cc7_msg(res), ". >= 10 was FALSE", fixed = TRUE)
})

# ---- N74 a later error -------------------------------------------------------------

test_that("N74 + E31: a collected claim then a stop() gives weft_claims_collected, with the parent", {
  src <- c(cc7_chunk("claim-a", "n_up <- claim(shift_n, . >= 10)"),
           cc7_chunk("boom-chunk", "stop('boom')"),
           "End.")
  res <- cc7_run(src)
  expect_true(res$failed)
  e <- res$error
  expect_true(inherits(e, "weft_claims_collected"))
  expect_true(inherits(e, "weft_error"))
  expect_true(inherits(e$parent, "error"))
  expect_match(conditionMessage(e$parent), "boom", fixed = TRUE)
  msg <- conditionMessage(e)
  first <- strsplit(msg, "\n", fixed = TRUE)[[1]][1]
  expect_equal(first, paste0("weft: the knit stopped on an error after 1 failed claim in chunk code. ",
                             "The claims are listed first: the error may follow from a value that failed its claim."))
  expect_match(msg, "The error that stopped the knit:", fixed = TRUE)
  expect_match(msg, "\n  boom", fixed = TRUE)
  a <- regexpr("claim-a", msg, fixed = TRUE)[1]
  t <- regexpr("The error that stopped the knit:", msg, fixed = TRUE)[1]
  b <- regexpr("boom", substr(msg, t, nchar(msg)), fixed = TRUE)[1]
  expect_true(a > 0 && t > a && b > 0)
})

test_that("N74 + E31: two claims are counted in the plural", {
  src <- c(TWO_BAD[1:14], cc7_chunk("boom-chunk", "stop('boom')"))
  res <- cc7_run(src)
  expect_true(inherits(res$error, "weft_claims_collected"))
  expect_match(strsplit(cc7_msg(res), "\n", fixed = TRUE)[[1]][1],
               "after 2 failed claims in chunk code.", fixed = TRUE)
})

test_that("control N74: the same stop() with no collected claim keeps its class and message", {
  src <- c(cc7_chunk("ok", "ok <- claim(k, . > 0)"), cc7_chunk("boom-chunk", "stop('boom')"))
  res <- cc7_run(src)
  expect_true(res$failed)
  expect_false(inherits(res$error, "weft_claims_collected"))
  expect_false(inherits(res$error, "weft_failures"))
  expect_match(cc7_msg(res), "boom", fixed = TRUE)
  expect_false(grepl("The error that stopped the knit", cc7_msg(res), fixed = TRUE))
})

test_that("N74: a bare inline value's error after a collected claim is wrapped too", {
  src <- c(cc7_chunk("claim-a", "n_up <- claim(shift_n, . >= 10)"),
           "Inline `r stop('inline boom')` here.")
  res <- cc7_run(src)
  expect_true(res$failed)
  expect_true(inherits(res$error, "weft_claims_collected"))
  expect_match(cc7_msg(res), "inline boom", fixed = TRUE)
  expect_match(cc7_msg(res), "claim-a", fixed = TRUE)
})

test_that("control N74: under stop a claim that stops the knit is not wrapped", {
  src <- c(cc7_chunk("claim-a", "claim(shift_n, . >= 10)"))
  res <- cc7_run(src, setting = "stop")
  expect_true(res$failed)
  expect_false(inherits(res$error, "weft_claims_collected"))
  expect_match(cc7_msg(res), ". >= 10", fixed = TRUE)
})

# ---- N76 rehearse -------------------------------------------------------------------

CC7_REH <- c(
  "---", "title: \"t\"", "params:", "  count: 2", "---", "",
  "```{r setup, include=FALSE}", "weft::weft_setup()", "knitr::opts_chunk$set(error = FALSE)", "```", "",
  "```{r gate}", "n <- params$count", "claim(n, . >= 5)", "```", "",
  "```{r gate2}", "claim(n, . >= 6)", "```", "",
  "```{r later}", "if (params$count == 3) stop('boom')", "```", ""
)

test_that("N76: rehearse() knits each case with the project's setting and lists claims per case", {
  path <- e1_write(CC7_REH, "doc.Rmd", files = list("_weft.yml" = c("draft: false", "chunk_claims: collect")))
  r <- e1_with_libs(rehearse(path, list(a = list(count = 1), b = list(count = 2),
                                        c = list(count = 3), d = list(count = 9))))
  expect_equal(nrow(r$cases$a$failures), 2L)
  expect_equal(nrow(r$cases$b$failures), 2L)
  expect_match(r$cases$a$failures$detail, "(value 1)", fixed = TRUE)
  expect_match(r$cases$b$failures$detail, "(value 2)", fixed = TRUE)
  expect_false(r$cases$a$ok)
  expect_false(r$cases$b$ok)
  expect_equal(r$cases$a$failures$chunk, c("gate", "gate2"))
  # control: the case whose claim passes lists nothing
  expect_equal(nrow(r$cases$d$failures), 0L)
  expect_true(r$cases$d$ok)
})

test_that("N76: a case that stops under N74 is reported with E31's text", {
  path <- e1_write(CC7_REH, "doc.Rmd", files = list("_weft.yml" = c("draft: false", "chunk_claims: collect")))
  r <- e1_with_libs(rehearse(path, list(c = list(count = 3))))
  expect_false(r$cases$c$ok)
  expect_match(r$cases$c$error, "the knit stopped on an error after 2 failed claims in chunk code.", fixed = TRUE)
  expect_match(r$cases$c$error, "boom", fixed = TRUE)
})
