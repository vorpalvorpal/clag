# Helpers for stage 7g (dev/design-7.md, 2 G: `decision=` on literals, cite spans and claims):
# test-decision-pointers.R and test-filter-decision.R. Nothing here edits another helper. Made-up content.

# the messages of section 7
dp_msg <- list(
  E50 = "`decision` must not be blank (rule 1.8.12).",
  E51 = function(what) sprintf("`decision` goes on a `.weft-literal` span or div, a `cite` span or a `claim()`, not on %s (rule 1.8.12).", what),
  E52 = "`decision` of claim() must be one string that is not blank, or a whole number from 1."
)
# the start of E51, for the constructs whose article the design leaves open
DP_E51_HEAD <- "`decision` goes on a `.weft-literal` span or div, a `cite` span or a `claim()`, not on "

# a bibliography with one key, for the knits and verify runs
DP_BIB <- "@book{smith2020, author = {A, B}, title = {Rivers}, year = {2020}, publisher = {Example Press}}"

# a document holding five pointers: a literal span (12), a literal div (31), a cite span (31), a claim in a
# chunk (99) and a claim in inline code ("31"). Returns the lines; the line of each is found with dp_line().
dp_doc <- function(chunk_decision = "99") {
  c("---", "title: T", "bibliography: refs.bib", "---", "",
    "Filtered through [0.45 µm]{.weft-literal why=\"method\" decision=\"12\"} membranes.", "",
    "::: {.weft-literal why=\"quoted rule\" decision=\"31\"}", "Samples were filtered.", ":::", "",
    "It reached [10 m]{cite=\"@smith2020\" decision=\"31\"} in the upper catchment.", "",
    "```{r}", "n <- 5", sprintf("n <- claim(n, . > 0, decision = %s)", chunk_decision), "```", "",
    "Inline `r claim(n, . > 0, decision = \"31\")` here.")
}
dp_line <- function(lines, fragment) grep(fragment, lines, fixed = TRUE)[1]

DP_FILES <- list("refs.bib" = DP_BIB, "decisions/12-core.md" = "x", "decisions/31-other.md" = "x")
DP_YML <- c("draft: false", "decisions: \"decisions/{id}-*.md\"")

# the rows of a verify result's decision part that belong to one file (compared by base name: dict.yml's
# rows carry an absolute path), ordered by line
dp_rows <- function(res, file = "a.qmd") {
  d <- res$decisions
  testthat::expect_s3_class(d, "data.frame")
  d <- d[basename(d$file) == file, , drop = FALSE]
  d[order(d$line), , drop = FALSE]
}

# verify() outcomes (the same checks as the expect_verify_* of test-verify-static.R, which are local to it)
dp_expect_failed <- function(r) {
  testthat::expect_false(is.null(r$err), label = "verify() raised")
  testthat::expect_s3_class(r$err, "weft_verify_error")
  testthat::expect_identical(r$report[1], "weft verify: failed")
}
dp_expect_passed <- function(r) {
  testthat::expect_null(r$err, label = if (!is.null(r$err)) conditionMessage(r$err) else "no error")
  testthat::expect_true(isTRUE(r$value$ok))
  testthat::expect_identical(r$report[1], "weft verify: passed")
}
