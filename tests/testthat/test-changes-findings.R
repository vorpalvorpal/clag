# Package 3d: tier-2 findings in changes() (7.3.5; L40, L41). Contract: dev/design-3.md L40, L41, K10, K15, K16.
# Helpers: helper-2e2.R (git projects, hand-written ledgers), helper-3d.R. The tier-2 rule used where any will do is
# xref-code (3d's own); claim-word (3b) is used where the design is about claim words.

skip_if_no_git <- function() skip_if(Sys.which("git") == "")

# a document: a heading, then paragraph lines
base_doc <- c("# A {#sec-a}", "", "Opening text here.", "")
# `@sec-a` written in a code span is one xref-code finding
code_line <- function(id = "sec-a") sprintf("Write `@%s` for it.", id)

findings_of <- function(dir, ...) changes(path = dir, ...)$findings

# ---- an added line is listed, an unchanged one is not -------------------------------------------------

test_that("3d L40: a finding on an added line is listed, one on an unchanged line is not", {
  skip_if_no_git()
  before <- list("a.qmd" = c(base_doc, code_line("sec-a")))                     # finding at line 5, in HEAD
  after  <- list("a.qmd" = c(base_doc, code_line("sec-a"), "", code_line("sec-b")))  # a second one at line 7
  dir <- f3d_scenario(before, after)
  ch <- changes(path = dir)
  expect_s3_class(ch, "weft_changes")
  f <- ch$findings
  expect_identical(nrow(f), 1L)
  expect_identical(f$file, "a.qmd")
  expect_identical(f$line, 7L)
  expect_identical(f$rule, "xref-code")
  expect_match(f$message, "@sec-b", fixed = TRUE)
})

test_that("3d L40: nothing added, nothing listed, and the unchanged result prints as no changes", {
  skip_if_no_git()
  dir <- f3d_scenario(list("a.qmd" = c(base_doc, code_line())))
  ch <- changes(path = dir)
  expect_identical(nrow(ch$findings), 0L)
  out <- f3d_print(ch)
  expect_match(out[nzchar(out)][1], "^weft: no changes since HEAD")
})

test_that("3d L40: a re-wrapped line that holds a finding is listed again at its new line", {
  skip_if_no_git()
  before <- list("a.qmd" = c(base_doc, "Write `@sec-a` for it and so on."))
  after  <- list("a.qmd" = c(base_doc, "Write", "`@sec-a` for it and so on."))
  f <- findings_of(f3d_scenario(before, after))
  expect_identical(nrow(f), 1L)
  expect_identical(f$line, 6L)
})

test_that("3d L40: an edit elsewhere in the file does not list an old finding", {
  skip_if_no_git()
  before <- list("a.qmd" = c(base_doc, code_line()))
  after  <- list("a.qmd" = c("# A {#sec-a}", "", "Opening text, now longer.", "", code_line()))
  expect_identical(nrow(findings_of(f3d_scenario(before, after))), 0L)
})

# ---- new files, untracked files, no commit ----------------------------------------------------------------

test_that("3d L40: a new untracked file has every line added, so its findings are all listed", {
  skip_if_no_git()
  before <- list("a.qmd" = base_doc)
  after  <- list("a.qmd" = base_doc, "new.qmd" = c("# N {#sec-n}", "", code_line("sec-n"), "", code_line("sec-m")))
  f <- findings_of(f3d_scenario(before, after))
  expect_identical(nrow(f), 2L)
  expect_identical(unique(f$file), "new.qmd")
  expect_identical(f$line, c(3L, 5L))
})

test_that("3d L40: a new file that is staged but not committed has every line added", {
  skip_if_no_git()
  dir <- f3d_scenario(list("a.qmd" = base_doc), list("a.qmd" = base_doc, "new.qmd" = c("# N {#sec-n}", "", code_line())))
  e2x_git(dir, "add", "new.qmd")
  f <- findings_of(dir)
  expect_identical(f$file, "new.qmd")
  expect_identical(f$line, 3L)
})

test_that("3d L40: a file in a subfolder is named by its path from the root, with / separators", {
  skip_if_no_git()
  after <- list("a.qmd" = base_doc, "ch/new.qmd" = c("# N {#sec-n}", "", code_line()))
  f <- findings_of(f3d_scenario(list("a.qmd" = base_doc), after))
  expect_identical(f$file, "ch/new.qmd")
})

test_that("3d L40: with no commit yet, every line of every document is added", {
  skip_if_no_git()
  dir <- e2x_project()
  e2x_write(file.path(dir, "a.qmd"), c(base_doc, code_line()))
  e2x_put_ledger(dir, "a.qmd", list())
  ch <- changes(path = dir)
  expect_true(is.na(attr(ch, "commit")))
  expect_identical(nrow(ch$findings), 1L)
  expect_identical(ch$findings$line, 5L)
})

test_that("3d L40: a finding is kept when one of its lines is added, though it starts on an old line", {
  skip_if_no_git()
  # a sentence on lines 3 and 4; line 4 is new
  before <- list("a.qmd" = c("# A {#sec-a}", "", "All the sites", ""))
  after  <- list("a.qmd" = c("# A {#sec-a}", "", "All the sites", "rose again.", ""))
  f <- findings_of(f3d_scenario(before, after))
  expect_identical(nrow(f), 1L)
  expect_identical(f$rule, "claim-word")
  expect_identical(f$line, 3L)
})

# ---- files ------------------------------------------------------------------------------------------

test_that("3d L40: files limits the documents whose findings are listed", {
  skip_if_no_git()
  before <- list("a.qmd" = base_doc, "b.qmd" = base_doc)
  after  <- list("a.qmd" = c(base_doc, code_line()), "b.qmd" = c(base_doc, code_line()))
  dir <- f3d_scenario(before, after)
  expect_setequal(findings_of(dir)$file, c("a.qmd", "b.qmd"))
  f <- findings_of(dir, files = "a.qmd")
  expect_identical(f$file, "a.qmd")
})

test_that("3d L40: an anchor in a file outside files still counts toward a tier-2 finding inside it", {
  skip_if_no_git()
  fig <- c("```{r}", "#| label: fig-d", "#| fig-cap: \"D\"", "#| fig-alt: \"A\"", "plot(1)", "```")
  before <- list("a.qmd" = base_doc, "b.qmd" = base_doc)
  after  <- list("a.qmd" = c(base_doc, fig), "b.qmd" = c(base_doc, "See @fig-d."))
  dir <- f3d_scenario(before, after)
  # fig-d is referenced from b.qmd, so it is not an unused anchor, whichever files are asked for
  expect_identical(nrow(findings_of(dir, files = "a.qmd")), 0L)
  expect_identical(nrow(findings_of(dir)), 0L)
})

test_that("3d L40: an unused anchor added in a changed file is a tier-2 finding", {
  skip_if_no_git()
  fig <- c("```{r}", "#| label: fig-d", "#| fig-cap: \"D\"", "#| fig-alt: \"A\"", "plot(1)", "```")
  dir <- f3d_scenario(list("a.qmd" = base_doc), list("a.qmd" = c(base_doc, fig)))
  f <- findings_of(dir)
  expect_identical(f$rule, "anchor-unused")
  expect_identical(f$line, 6L)
})

# ---- the table --------------------------------------------------------------------------------------

test_that("3d L41: findings keeps exactly file, line, rule and message, sorted by file and line", {
  skip_if_no_git()
  before <- list("a.qmd" = base_doc, "b.qmd" = base_doc)
  after  <- list("b.qmd" = c(base_doc, code_line("sec-b1"), "", code_line("sec-b2")),
                 "a.qmd" = c(base_doc, code_line("sec-a1")))
  f <- findings_of(f3d_scenario(before, after))
  expect_identical(names(f), c("file", "line", "rule", "message"))
  expect_identical(f$file, c("a.qmd", "b.qmd", "b.qmd"))
  expect_identical(f$line, c(5L, 5L, 7L))
  expect_type(f$line, "integer")
  expect_type(f$message, "character")
})

test_that("3d L41: an empty findings table has the four columns", {
  skip_if_no_git()
  ch <- changes(path = f3d_scenario(list("a.qmd" = base_doc)))
  expect_identical(names(ch$findings), c("file", "line", "rule", "message"))
  expect_identical(nrow(ch$findings), 0L)
  expect_identical(names(ch), c("entries", "conditions", "stale", "ledgers", "findings"))
})

test_that("3d L41: a claim-word message ends with the sentence in quotes, white space collapsed", {
  skip_if_no_git()
  after <- list("a.qmd" = c(base_doc, "Rain was", "highest   again."))
  f <- findings_of(f3d_scenario(list("a.qmd" = base_doc), after))
  r <- f[f$rule == "claim-word", , drop = FALSE]
  expect_identical(nrow(r), 1L)
  expect_match(r$message, "\"Rain was highest again.\"$")
  # The finding sits on the claim word, which is on the second line.
  expect_identical(r$line, 6L)
})

# ---- the cap ----------------------------------------------------------------------------------------

claim_doc <- function(n) {
  out <- base_doc
  for (s in F3D_CLAIMS[seq_len(n)]) out <- c(out, s, "")
  out
}

test_that("3d L41: claim-word findings at the claim_cap are listed one by one", {
  skip_if_no_git()
  dir <- f3d_scenario(list("a.qmd" = base_doc), list("a.qmd" = claim_doc(2)))
  writeLines("claim_cap: 2", file.path(dir, "_weft.yml"))
  f <- findings_of(dir)
  expect_identical(sum(f$rule == "claim-word"), 2L)
  expect_false(any(grepl("so they are counted, not listed", f$message, fixed = TRUE)))
})

test_that("3d L41: claim-word findings below the claim_cap are listed one by one", {
  skip_if_no_git()
  dir <- f3d_scenario(list("a.qmd" = base_doc), list("a.qmd" = claim_doc(1)))
  writeLines("claim_cap: 2", file.path(dir, "_weft.yml"))
  f <- findings_of(dir)
  expect_identical(sum(f$rule == "claim-word"), 1L)
})

test_that("3d L41: more claim-word findings than the cap is one row, a count, at the first one's line", {
  skip_if_no_git()
  dir <- f3d_scenario(list("a.qmd" = base_doc), list("a.qmd" = claim_doc(3)))
  writeLines("claim_cap: 2", file.path(dir, "_weft.yml"))
  f <- findings_of(dir)
  r <- f[f$rule == "claim-word", , drop = FALSE]
  expect_identical(nrow(r), 1L)
  expect_identical(r$file, "a.qmd")
  expect_identical(r$line, 5L)
  expect_identical(r$message, paste0("3 added sentences hold claim words; more than the cap of 2, ",
                                     "so they are counted, not listed (rule 5.5.3)."))
})

test_that("3d L41: the cap is per file, and other rules are not capped", {
  skip_if_no_git()
  before <- list("a.qmd" = base_doc, "b.qmd" = base_doc)
  after  <- list("a.qmd" = c(claim_doc(3), code_line("sec-x"), "", code_line("sec-y")), "b.qmd" = claim_doc(1))
  dir <- f3d_scenario(before, after)
  writeLines("claim_cap: 2", file.path(dir, "_weft.yml"))
  f <- findings_of(dir)
  expect_identical(sum(f$rule == "claim-word" & f$file == "a.qmd"), 1L)
  expect_identical(sum(f$rule == "claim-word" & f$file == "b.qmd"), 1L)
  expect_identical(sum(f$rule == "xref-code"), 2L)
})

test_that("3d L41: the default claim_cap is 20", {
  skip_if_no_git()
  many <- base_doc
  for (i in 1:21) many <- c(many, "Rain was highest again.", "")
  dir <- f3d_scenario(list("a.qmd" = base_doc), list("a.qmd" = many))
  f <- findings_of(dir)
  r <- f[f$rule == "claim-word", , drop = FALSE]
  expect_identical(nrow(r), 1L)
  expect_match(r$message, "^21 added sentences hold claim words; more than the cap of 20")
})

# ---- print ------------------------------------------------------------------------------------------

test_that("3d L41: print shows a Tier-2 findings section, one '? file:line  rule  message' line per finding", {
  skip_if_no_git()
  dir <- f3d_scenario(list("a.qmd" = base_doc), list("a.qmd" = c(base_doc, code_line())))
  ch <- changes(path = dir)
  out <- f3d_print(ch)
  expect_true("Tier-2 findings" %in% out)
  f <- ch$findings
  expect_true(sprintf("  ? %s:%d  %s  %s", f$file, f$line, f$rule, f$message) %in% out)
  # the header line is the ordinary one, and a result with findings is not "no changes"
  expect_false(any(grepl("^weft: no changes", out)))
  expect_match(out[nzchar(out)][1], "^weft changes since HEAD \\([0-9a-f]{7}\\)")
})

test_that("3d L41: the Tier-2 findings section comes after New conditions", {
  skip_if_no_git()
  dir <- f3d_scenario(list("a.qmd" = base_doc), list("a.qmd" = c(base_doc, code_line())))
  e2x_put_ledger(dir, "a.qmd", list(), conds = list(e2x_cond()))
  out <- f3d_print(changes(path = dir))
  expect_true(all(c("New conditions", "Tier-2 findings") %in% out))
  expect_lt(match("New conditions", out), match("Tier-2 findings", out))
})

test_that("3d L41: brief does not print the findings", {
  skip_if_no_git()
  dir <- f3d_scenario(list("a.qmd" = base_doc), list("a.qmd" = c(base_doc, code_line())))
  ch <- changes(path = dir)
  out <- f3d_print(ch, brief = TRUE)
  expect_false("Tier-2 findings" %in% out)
  expect_false(any(grepl("^  \\? ", out)))
  expect_identical(f3d_print(ch, brief = FALSE), f3d_print(ch))
})

test_that("3d L41: no findings, no Tier-2 findings section", {
  skip_if_no_git()
  dir <- f3d_scenario(list("a.qmd" = base_doc), list("a.qmd" = c(base_doc, "Plain words.")))
  e2x_put_ledger(dir, "a.qmd", list(), conds = list(e2x_cond()))
  expect_false("Tier-2 findings" %in% f3d_print(changes(path = dir)))
})

test_that("3d L41: findings alone are a change; no entry, condition or stale row is needed", {
  skip_if_no_git()
  dir <- f3d_scenario(list("a.qmd" = base_doc), list("a.qmd" = c(base_doc, code_line())))
  ch <- changes(path = dir)
  expect_identical(nrow(ch$entries), 0L)
  expect_identical(nrow(ch$conditions), 0L)
  expect_identical(nrow(ch$stale), 0L)
  expect_identical(nrow(ch$findings), 1L)
})

test_that("3d L40: changes() does not change the project: files, git state and the mtimes are as before", {
  skip_if_no_git()
  dir <- f3d_scenario(list("a.qmd" = base_doc), list("a.qmd" = c(base_doc, code_line()), "new.qmd" = base_doc))
  before <- e2x_snapshot(dir)
  status <- e2x_git(dir, "status", "--porcelain")
  invisible(changes(path = dir))
  expect_identical(e2x_snapshot(dir), before)
  expect_identical(e2x_git(dir, "status", "--porcelain"), status)
})
