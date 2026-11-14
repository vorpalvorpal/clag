# Stage 7g (dev/design-7.md, 2 G, notes N100 to N105, messages E50 to E52): `decision=` on literals, cite
# spans and claim(). Sources are scanned with scan_text(); knits run in process; verify() runs on a
# temporary project (helper-4c.R). Controls (behaviour that must not change) are marked. Made-up content.

dp_errs <- function(text) b_errs(text)
dp_has <- function(errs, msg) any(grepl(msg, errs, fixed = TRUE))

# ---- N100: the key on literals and cite spans ---------------------------------------------------------------

test_that("N100: decision is a key of a .weft-literal span, a .weft-literal div and a cite span, with no error", {
  txt <- c("A [0.45]{.weft-literal why=\"method\" decision=\"12\"} b.", "",
           "::: {.weft-literal why=\"rule\" decision=\"31\"}", "Text.", ":::", "",
           "C [10 m]{cite=\"@smith2020\" decision=\"7\"} d.")
  r <- weft:::scan_text(paste(txt, collapse = "\n"))
  expect_identical(r$kind, c("literal", "literal", "cite"))
  expect_identical(r$error, rep(NA_character_, 3L))
  expect_identical(unname(vapply(r$keys, function(k) k[["decision"]], "")), c("12", "31", "7"))
  # a decision does not stand for a why
  e <- dp_errs("A [0.45]{.weft-literal decision=\"12\"} b.")
  expect_length(e, 1L)
  expect_match(e, "no `why`", fixed = TRUE)
})

test_that("N100, E50: a blank decision is a construct error found from the source, on each of the three", {
  bad <- c(literal_empty = "A [0.45]{.weft-literal why=\"w\" decision=\"\"} b.",
           literal_spaces = "A [0.45]{.weft-literal why=\"w\" decision=\"  \"} b.",
           div_empty = "::: {.weft-literal why=\"w\" decision=\"\"}\nText.\n:::",
           cite_empty = "A [10 m]{cite=\"@smith2020\" decision=\"\"} b.",
           cite_spaces = "A [10 m]{cite=\"@smith2020\" decision=\" \"} b.")
  expect_length(bad, 5L)
  for (nm in names(bad)) {
    e <- dp_errs(bad[[nm]])
    expect_true(dp_has(e, dp_msg$E50), label = nm)
  }
  good <- c("A [0.45]{.weft-literal why=\"w\" decision=\"12\"} b.", "A [10 m]{cite=\"@smith2020\" decision=\"12\"} b.")
  for (g in good) expect_identical(dp_errs(g), character(), label = g)
})

# ---- N101: any other construct ------------------------------------------------------------------------------

test_that("N101, E51: decision on a value, a named value, an n, if, sign or list span, or a text span is a construct error", {
  tbl <- list(
    value = c("A `r k`{.num decision=\"3\"} b.", "a value"),
    named = c("A `k`{.num decision=\"3\"} b.", "a named value"),
    n = c("A [one | # many]{n=\"k\" decision=\"3\"} b.", "an `n` span"),
    text = c("A [word]{.cap decision=\"3\"} b.", "a text span")
  )
  for (nm in names(tbl)) {
    e <- dp_errs(tbl[[nm]][1])
    expect_true(dp_has(e, dp_msg$E51(tbl[[nm]][2])), label = nm)
  }
  # the articles of the other spans are the design's "...": read the head and the name of the span
  rest <- list(`if` = "A [yes | no]{if=\"f\" decision=\"3\"} b.",
               sign = "A [up | down]{sign=\"k\" decision=\"3\"} b.",
               list = "A [none | # was | # were]{list=\"k\" decision=\"3\"} b.")
  for (nm in names(rest)) {
    e <- dp_errs(rest[[nm]])
    expect_true(any(grepl(paste0(DP_E51_HEAD, "an? `", nm, "` span (rule 1.8.12)."), e, fixed = TRUE)) ||
                  any(grepl(sprintf("not on an? `%s` span \\(rule 1.8.12\\)", nm), e)), label = nm)
  }
})

test_that("N101 (control): a bracket with no weft key or class is an ordinary span and is left alone; the same constructs without decision are clean", {
  r <- weft:::scan_text("A [word]{.smallcaps decision=\"3\"} and [x]{.note why=\"y\"} b.")
  expect_equal(nrow(r), 0L)
  clean <- c("A `r k`{.num} b.", "A `k`{.num} b.", "A [one | # many]{n=\"k\"} b.", "A [word]{.cap} b.",
             "A [yes | no]{if=\"f\"} b.", "A [up | down]{sign=\"k\"} b.")
  for (g in clean) expect_identical(dp_errs(g), character(), label = g)
})

# ---- N100, N101 at knit ----------------------------------------------------------------------------------------

test_that("N100, N101, E50, E51: the knit reports the same errors, with the source's line", {
  cases <- list(
    list("A [0.45]{.weft-literal why=\"w\" decision=\"\"} b.", dp_msg$E50),
    list("A [10 m]{cite=\"@smith2020\" decision=\"\"} b.", dp_msg$E50),
    list("A `r k`{.num decision=\"3\"} b.", dp_msg$E51("a value"))
  )
  expect_length(cases, 3L)
  for (cs in cases) {
    res <- render_rmd(cs[[1]], code = "k <- 3", in_process = TRUE, front = "bibliography: refs.bib",
                      files = list("refs.bib" = DP_BIB))
    expect_true(res$failed, label = cs[[1]])
    expect_true(grepl(cs[[2]], res$message, fixed = TRUE), label = cs[[1]])
    expect_match(res$message, sprintf("doc.Rmd:%d", res$offset + 1L), fixed = TRUE)
  }
})

# ---- N102: decision is removed from the output ------------------------------------------------------------------

test_that("N102: decision is gone from the output of a literal span, a literal div and a cite span, the why too", {
  src <- c("A [0.45 mm]{.weft-literal why=\"method\" decision=\"12\"} b.", "",
           "::: {.weft-literal why=\"rule\" decision=\"31\"}", "Block text.", ":::", "",
           "See [10 m]{cite=\"@smith2020\" decision=\"7\"} here.")
  res <- render_rmd(src, in_process = TRUE, front = "bibliography: refs.bib", files = list("refs.bib" = DP_BIB))
  expect_false(res$failed, label = substr(res$message, 1, 300))
  expect_match(res$md, "A [0.45 mm]{.weft-literal} b.", fixed = TRUE)
  expect_match(res$md, "::: {.weft-literal}", fixed = TRUE)
  expect_match(res$md, "See 10 m [@smith2020] here.", fixed = TRUE)
  expect_false(grepl("decision", res$md, fixed = TRUE))
  expect_false(grepl("why", res$md, fixed = TRUE))
})

# ---- N103: claim(decision =) -----------------------------------------------------------------------------------------

test_that("N103: a failed claim outside a knit ends its message with the decision", {
  e <- tryCatch(claim(7, . >= 10, decision = 31), error = function(e) e)
  expect_s3_class(e, "weft_claim_failed")
  expect_match(conditionMessage(e), "(value: 7); decision 31", fixed = TRUE)
  e2 <- tryCatch(claim(7, . >= 10, decision = "D-12"), error = function(e) e)
  expect_s3_class(e2, "weft_claim_failed")
  expect_match(conditionMessage(e2), "(value: 7); decision D-12", fixed = TRUE)
  # a failure with no decision has no such ending (control)
  e3 <- tryCatch(claim(7, . >= 10), error = function(e) e)
  expect_false(grepl("decision", conditionMessage(e3), fixed = TRUE))
})

test_that("N103: a passing claim with a decision returns its value; whole numbers and non-blank strings are accepted", {
  ok <- list(31, 31L, 1, 2.0, "D-12", "31")
  expect_length(ok, 6L)
  for (d in ok) expect_identical(claim(5, . > 1, decision = d), 5, label = format(d))
  expect_identical(claim(5, . > 1, level = "warn", decision = 4), 5)
  expect_identical(claim(5, . > 1, decision = NULL), 5)
})

test_that("N103, E52: a decision that is not one non-blank string or one whole number from 1 is weft_claim_decision, before the checks run", {
  bad <- list(blank = "", spaces = "  ", zero = 0, negative = -1, fraction = 1.5, two = c(1, 2),
              logical = TRUE, na = NA_integer_, list = list(1), two_strings = c("a", "b"))
  expect_length(bad, 10L)
  for (nm in names(bad)) {
    ran <- FALSE
    e <- tryCatch(claim(5, { ran <- TRUE; TRUE }, decision = bad[[nm]]), error = function(e) e)
    expect_s3_class(e, "weft_claim_decision")
    expect_s3_class(e, "weft_error")
    if (!inherits(e, "condition")) next
    expect_identical(conditionMessage(e), dp_msg$E52, label = nm)
    expect_false(ran, label = paste("the check did not run:", nm))
  }
  # also when the check would fail, and under level = "warn": the decision is read first
  e <- tryCatch(claim(5, . > 10, decision = 0), error = function(e) e)
  expect_s3_class(e, "weft_claim_decision")
  e <- tryCatch(claim(5, . > 10, level = "warn", decision = ""), error = function(e) e, warning = function(w) w)
  expect_s3_class(e, "weft_claim_decision")
})

test_that("N103: in a knit a failing inline claim and a failing chunk claim carry the decision in their detail", {
  res <- render_rmd(c("The shift was `r claim(shift_n, . >= 10, decision = 31)` sites."), code = "shift_n <- 7",
                    in_process = TRUE)
  expect_true(res$failed)
  f <- res$knit$failures
  expect_identical(nrow(f), 1L)
  expect_identical(f$kind, "failed claim")
  expect_match(f$detail, ". >= 10 was FALSE (value 7); decision 31", fixed = TRUE)
  expect_match(res$message, "decision 31", fixed = TRUE)

  res2 <- cc7_run(c("Intro.", "", cc7_chunk("c1", "x <- claim(shift_n, . >= 10, decision = \"D-12\")"), "End."))
  f2 <- cc7_fail(res2)
  expect_identical(nrow(f2), 1L)
  expect_match(f2$detail, ". >= 10 was FALSE (value 7); decision D-12", fixed = TRUE)
})

test_that("N103, E52: a bad decision in a knit raises E52 whatever the check would say", {
  res <- render_rmd(c("The shift was `r claim(shift_n, . >= 1, decision = 0)` sites."), code = "shift_n <- 7",
                    in_process = TRUE)
  expect_true(res$failed)
  expect_true(grepl(dp_msg$E52, res$message, fixed = TRUE))
})

# ---- N104: verify() ---------------------------------------------------------------------------------------------------

test_that("N104: verify() has a row for each document pointer, and fails on the one that does not resolve", {
  v4_env()
  doc <- dp_doc()
  p <- v4_proj(c(list("a.qmd" = doc), DP_FILES), git = TRUE, weft_yml = DP_YML)
  r <- v4_verify(p$root, static = TRUE)
  dp_expect_failed(r)
  expect_identical(v4_status(r$res, "decisions"), "failed")
  rows <- dp_rows(r$res)
  expect_identical(nrow(rows), 5L)
  expect_identical(rows$line, c(dp_line(doc, "[0.45"), dp_line(doc, "::: {.weft-literal"), dp_line(doc, "[10 m]"),
                                dp_line(doc, "decision = 99"), dp_line(doc, "`r claim")))
  expect_identical(rows$key, c(".weft-literal", ".weft-literal", "cite=\"@smith2020\"", "claim()", "claim()"))
  expect_identical(rows$decision, c("12", "31", "31", "99", "31"))
  expect_identical(rows$resolved, c(TRUE, TRUE, TRUE, FALSE, TRUE))
  expect_true(v4_has_section(r$report, "Decision pointers"))
  sec <- v4_section(r$report, "Decision pointers")
  expect_true(any(grepl("99", sec, fixed = TRUE)))
  expect_true(any(grepl("a.qmd", sec, fixed = TRUE)))
  expect_false(any(grepl("decisions/12-core.md", sec, fixed = TRUE)))
  # with every pointer resolving, verify passes (control for the failure above)
  p2 <- v4_proj(c(list("a.qmd" = dp_doc("12")), DP_FILES), git = TRUE, weft_yml = DP_YML)
  r2 <- v4_verify(p2$root, static = TRUE)
  dp_expect_passed(r2)
  expect_identical(v4_status(r2$value, "decisions"), "ran")
  expect_identical(dp_rows(r2$value)$resolved, rep(TRUE, 5L))
})

test_that("N104: the pointers of dict.yml and of the documents are checked together", {
  v4_env()
  p <- v4_proj(c(list("a.qmd" = dp_doc("12"), "dict.yml" = DICT_PTR("12", "31")), DP_FILES), git = TRUE, weft_yml = DP_YML)
  r <- v4_verify(p$root, static = TRUE)
  dp_expect_passed(r)
  d <- r$value$decisions
  expect_identical(sum(basename(d$file) == "dict.yml"), 2L)
  expect_identical(sum(basename(d$file) == "a.qmd"), 5L)
  expect_identical(nrow(d), 7L)
  # a dict pointer that does not resolve still fails, beside document pointers that do (control)
  q <- v4_proj(c(list("a.qmd" = dp_doc("12"), "dict.yml" = DICT_PTR("77")), DP_FILES), git = TRUE, weft_yml = DP_YML)
  dp_expect_failed(v4_verify(q$root, static = TRUE))
})

test_that("N104: with no dict.yml, a document pointer makes the part run", {
  v4_env()
  doc <- c("Plain words with [0.45]{.weft-literal why=\"method\" decision=\"12\"} here.")
  p <- v4_proj(c(list("a.qmd" = doc), DP_FILES), git = TRUE, weft_yml = DP_YML)
  r <- v4_verify(p$root, static = TRUE)
  dp_expect_passed(r)
  expect_identical(v4_status(r$value, "decisions"), "ran")
  rows <- dp_rows(r$value)
  expect_identical(nrow(rows), 1L)
  expect_identical(rows$key, ".weft-literal")
  expect_identical(rows$line, 1L)
  expect_identical(basename(rows$file), "a.qmd")
})

test_that("N104: a computed decision argument is not checked, and a claim with no decision has no row", {
  v4_env()
  doc <- c("---", "title: T", "---", "", "```{r}", "n <- 5; d <- 99",
           "a <- claim(n, . > 0, decision = d)",
           "b <- claim(n, . > 0, decision = paste0(\"9\", \"9\"))",
           "c <- claim(n, . > 0)",
           "e <- claim(n, . > 0, decision = NULL)",
           "f <- claim(n, . > 0, decision = 12)",
           "```", "", "Inline `r claim(n, . > 0, decision = d)` and `r claim(n, . > 0)`.")
  p <- v4_proj(c(list("a.qmd" = doc), DP_FILES), git = TRUE, weft_yml = DP_YML)
  r <- v4_verify(p$root, static = TRUE)
  dp_expect_passed(r)
  rows <- dp_rows(r$value)
  expect_identical(nrow(rows), 1L)
  expect_identical(rows$key, "claim()")
  expect_identical(rows$decision, "12")
  expect_identical(rows$line, dp_line(doc, "decision = 12"))
})

test_that("N104: with no pointer anywhere the part is skipped with its own reason", {
  v4_env()
  p <- v4_proj(list("a.qmd" = V4_PLAIN_DOC), git = TRUE, weft_yml = DP_YML)
  r <- v4_verify(p$root, static = TRUE)
  dp_expect_passed(r)
  expect_identical(v4_status(r$value, "decisions"), "skipped")
  expect_identical(v4_detail(r$value, "decisions"), "skipped: no decision pointers")
  expect_true(sprintf("  %-10s %s", "decisions", "skipped: no decision pointers") %in% r$report)
  # only computed arguments: still no pointer
  doc <- c("```{r}", "n <- 5; d <- 1", "claim(n, . > 0, decision = d)", "```")
  q <- v4_proj(list("a.qmd" = doc), git = TRUE, weft_yml = DP_YML)
  expect_identical(v4_detail(v4_verify(q$root, static = TRUE)$value, "decisions"), "skipped: no decision pointers")
})

test_that("N104 (control): verify_skip: [decisions] still skips the part, and an unresolved document pointer fails nothing then", {
  v4_env()
  yml <- c(DP_YML, "verify_skip: [decisions]")
  p <- v4_proj(c(list("a.qmd" = dp_doc("99")), DP_FILES), git = TRUE, weft_yml = yml)
  r <- v4_verify(p$root, static = TRUE)
  dp_expect_passed(r)
  expect_identical(v4_status(r$value, "decisions"), "skipped")
  expect_identical(v4_detail(r$value, "decisions"), "skipped: verify_skip in _weft.yml")
})

# ---- N105: the ledger -------------------------------------------------------------------------------------------------

test_that("N105: adding pointers changes no ledger entry; the cite entry's expression is unchanged", {
  # one pointer per line, so that a pointer is the only difference
  mk <- function(with) {
    dl <- if (with) " decision=\"12\"" else ""
    ci <- if (with) " decision=\"31\"" else ""
    c("Depth was `r depth`{.num} m.", "",
      sprintf("Filtered through [0.45 mm]{.weft-literal why=\"method\"%s} membranes.", dl), "",
      sprintf("It reached [10 m]{cite=\"@smith2020\"%s} upstream.", ci))
  }
  run <- function(with) d2_render(mk(with), code = "depth <- 3.5", front = "bibliography: refs.bib",
                                  files = list("refs.bib" = DP_BIB))
  a <- run(FALSE)
  b <- run(TRUE)
  la <- d2_lines(d2_path(a$dir))
  lb <- d2_lines(d2_path(b$dir))
  expect_gte(length(la), 3L)
  expect_identical(lb[-1], la[-1])
  cite <- d2_one(d2_entries(d2_path(b$dir)), kind = "cite")
  expect_match(cite$expr, "smith2020", fixed = TRUE)
  expect_false(grepl("decision", paste(lb, collapse = "\n"), fixed = TRUE))
  # the output carries no decision either
  expect_false(grepl("decision", b$md, fixed = TRUE))
})
