# Helpers for the package 3d tests (documents and project lints: citations, cross-references,
# hygiene, figures and tables, tier-2 findings in changes()). Contract: dev/design-3.md L29-L35, L40, L41.
# Built on helper-3.R (lint_proj, lint_fixture, lint_one, lf_*, f3_pos, f3_chunk, f3_fm) and, for the
# git scenarios, helper-2e2.R (e2x_*). ASCII only: write non-ASCII as \uXXXX. Invented content only.

# ---- bibliographies ---------------------------------------------------------------------------

F3D_BIBTEX <- c(
  "@book{smith2020,",
  "  author = {Smith, Anna},",
  "  title = {Rivers of the Blue Mountains},",
  "  year = {2020}",
  "}",
  "",
  "@article{doe:2018,",
  "  author = {Doe, Jane},",
  "  title = {Catchments},",
  "  journal = {Journal of Water},",
  "  year = {2018}",
  "}",
  "",
  "@comment{fakekey2001, not an entry}",
  "",
  "@article{real2001,",
  "  author = {Real, Rae},",
  "  title = {Notes},",
  "  note = {see fakekey2002},",
  "  year = {2001}",
  "}"
)
F3D_CSLJSON <- c(
  "[",
  "  {\"id\": \"jsonkey2019\", \"type\": \"book\", \"title\": \"A CSL JSON book\",",
  "   \"author\": [{\"family\": \"Jones\", \"given\": \"Alex\"}],",
  "   \"issued\": {\"date-parts\": [[2019]]}}",
  "]"
)
F3D_CSLYAML <- c(
  "references:",
  "- id: yamlkey2017",
  "  type: book",
  "  title: A CSL YAML book",
  "  author:",
  "  - family: Brown",
  "    given: Chris",
  "  issued:",
  "    date-parts:",
  "    - - 2017"
)
# a second BibTeX file with one more key
F3D_BIBTEX2 <- c("@book{other2015,", "  author = {Other, Olly},", "  title = {Another},", "  year = {2015}", "}")

# ---- documents --------------------------------------------------------------------------------

# a document: front matter lines (NULL: none) then the body lines
f3d_doc <- function(body, front = NULL) {
  if (is.null(front)) body else c("---", front, "---", "", body)
}

# lints() over `files` (a named list for lint_proj()) for one rule or several; both tiers by default
f3d_run <- function(files, rules, ..., weft_yml = NULL, tier = 1:2, env = parent.frame()) {
  lint_fixture(files, rules = rules, tier = tier, ..., weft_yml = weft_yml, env = env)
}

# the `text` of each finding of a rule, in order
f3d_texts <- function(x, rule) x$text[x$rule == rule]

# the findings of `rule` have exactly these texts (order ignored, repeats kept)
expect_texts <- function(x, rule, texts) {
  testthat::expect_identical(sort(f3d_texts(x, rule)), sort(as.character(texts)),
                             label = sprintf("texts of rule %s", rule))
}

# no finding of `rule` (every finding when rule is NULL)
expect_none <- function(x, rule = NULL) {
  n <- if (is.null(rule)) nrow(x) else sum(x$rule %in% rule)
  testthat::expect_identical(n, 0L, label = sprintf("number of %s findings", if (is.null(rule)) "any" else paste(rule, collapse = "/")))
}

# a finding of `rule` (and `text`, when given; and `file`) sits at `line`, and, when `col` is given, at one
# of the columns in `col` (a vector: where the design leaves open whether `col` is the sigil or the id)
expect_at <- function(x, rule, text = NULL, line, col = NULL, file = NULL) {
  r <- lf_by_rule(x, rule)
  if (!is.null(text)) r <- r[r$text %in% text, , drop = FALSE]
  if (!is.null(file)) r <- r[r$file == file, , drop = FALSE]
  testthat::expect_true(any(r$line == line),
    label = sprintf("%s %s at line %s (found at line %s)", rule, paste(text, collapse = "/"), line,
                    paste(r$line, collapse = ",")))
  if (!is.null(col)) {
    rr <- r[r$line == line, , drop = FALSE]
    testthat::expect_true(any(rr$col %in% col),
      label = sprintf("%s %s at line %s, column in {%s} (found %s)", rule, paste(text, collapse = "/"), line,
                      paste(col, collapse = ","), paste(rr$col, collapse = ",")))
  }
}

# the line of the first line of `lines` holding `frag`, and the columns at which the construct may start:
# the fragment itself and one after it (a sigil before an id)
f3d_line <- function(lines, frag) unname(f3_pos(lines, frag)[["line"]])
f3d_col  <- function(lines, frag) unname(f3_pos(lines, frag)[["col"]])

# ---- git scenarios for changes() (helper-2e2.R) ---------------------------------------------------------

# A git project: `before` (named list: path -> lines) is committed, each with an empty ledger so that
# changes(files =) accepts it, then `after` (same form) is written over the working tree. A path in `after`
# that is not in `before` is a new, untracked file. Returns the folder.
f3d_scenario <- function(before, after = before, env = parent.frame()) {
  dir <- e2x_project(env = env)
  for (nm in names(before)) {
    e2x_write(file.path(dir, nm), before[[nm]])
    e2x_put_ledger(dir, nm, list())
  }
  e2x_commit(dir)
  for (nm in names(after)) e2x_write(file.path(dir, nm), after[[nm]])
  dir
}

# the printed lines of a weft_changes
f3d_print <- function(x, ...) capture.output(print(x, ...))

# the sentences that give a claim-word finding with no value in them (lexicon words of L8a: highest, entire,
# grows, sole, declines, top, drops) -- one per paragraph so that each is its own sentence
F3D_CLAIMS <- c("Rain was highest again.", "The entire reach grows.", "Only the sole site declines.",
                "The top site drops.")
