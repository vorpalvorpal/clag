# Package 4c: verify()'s static part (dev/design-4.md G23, G24 parts 1 and 2, G27, G28, G29; H17-H19; section 5
# "test-verify-static.R"). No render happens here: every call is `static = TRUE` or is made with a stand-in
# quarto that records whether it was called. Fixtures use the `construct` rule where they can; tests that
# need a stage 3 rule that is not built yet skip (v4_need()). Helpers: helper-4c.R, helper-4a.R, helper-3.R.
# ASCII only. Invented content only.

# the failure signal of G27: a weft_verify_error holding the result
expect_verify_failed <- function(r, n = NULL) {
  expect_false(is.null(r$err), label = "verify() raised")
  expect_s3_class(r$err, "weft_verify_error")
  expect_s3_class(r$err, "weft_error")
  expect_match(cli::ansi_strip(conditionMessage(r$err)),
               "^verify\\(\\) failed: [0-9]+ (reasons?|reason\\(s\\)); the report is above \\(rule 8\\.1\\.1\\)\\.$")
  expect_s3_class(r$err$result, "weft_verify")
  expect_false(r$err$result$ok)
  expect_identical(r$report[1], "weft verify: failed")
}

expect_verify_passed <- function(r) {
  expect_null(r$err, label = if (!is.null(r$err)) conditionMessage(r$err) else "no error")
  expect_s3_class(r$value, "weft_verify")
  expect_true(r$value$ok)
  expect_identical(r$report[1], "weft verify: passed")
}

# a baseline commit of `before`, then `after` committed; returns list(p, base) with base the baseline sha
st_two_commits <- function(before, after, env = parent.frame(), ...) {
  p <- v4_proj(before, git = TRUE, env = env, ...)
  base <- g_head(p$top)
  g_apply(p$top, after)
  g_add(p$top)
  g_commit(p$top, "second")
  list(p = p, base = base)
}

# ---- arguments (G23) ----------------------------------------------------------------------------------

test_that("4c G23: bad arguments are weft_verify_error", {
  v4_env()
  p <- v4_proj(list("a.qmd" = V4_PLAIN_DOC), git = TRUE)
  bad <- list(
    list(files = 1L), list(files = NA_character_), list(files = list("a.qmd")),
    list(since = 1L), list(since = c("HEAD", "HEAD")), list(since = NA_character_), list(since = ""),
    list(static = "yes"), list(static = NA), list(static = c(TRUE, FALSE))
  )
  expect_null(v4_verify(p$root, static = TRUE)$err)   # control: the defaults are fine
  for (a in bad) {
    args <- c(list(p$root), utils::modifyList(list(static = TRUE), a))
    names(args)[1] <- "path"
    e <- tryCatch(suppressMessages(do.call(verify, args)), error = function(e) e)
    f2_has_class(e, "weft_verify_error")
  }
})

test_that("4c G23: since names a commit; anything else is weft_verify_error, and no part has run", {
  v4_env()
  fq <- v4_fake_quarto()
  p <- v4_proj(list("a.qmd" = V4_PLAIN_DOC), git = TRUE)
  e <- tryCatch(suppressMessages(verify(since = "no-such-commit", path = p$root, static = TRUE)),
                error = function(e) e)
  f2_has_class(e, "weft_verify_error")
  expect_false(inherits(e$result, "weft_verify"))
  # a sha, a branch and a relative name are commits
  g_write(p$top, "a.qmd", c(V4_PLAIN_DOC, "", "More words."))
  g_add(p$top)
  g_commit(p$top, "second")
  for (s in c(g_head(p$top), "main", "HEAD~1", "HEAD")) {
    r <- v4_verify(p$root, since = s, static = TRUE)
    expect_verify_passed(r)
  }
  expect_length(v4_log(fq, "calls"), 0L)
})

test_that("4c G23, H19: since given without git is weft_verify_error", {
  v4_env()
  p <- v4_proj(list("a.qmd" = V4_PLAIN_DOC))
  e <- tryCatch(suppressMessages(verify(since = "HEAD", path = p$root, static = TRUE)), error = function(e) e)
  f2_has_class(e, "weft_verify_error")
  # a repository with no commit has no commit to name either
  q <- v4_proj(list("a.qmd" = V4_PLAIN_DOC))
  g_ok_git(q$root, "init", "-q", "-b", "main")
  e <- tryCatch(suppressMessages(verify(since = "HEAD", path = q$root, static = TRUE)), error = function(e) e)
  f2_has_class(e, "weft_verify_error")
})

# ---- the result (G27) ---------------------------------------------------------------------------------

test_that("4c G27: a passing run returns a weft_verify invisibly, with the fields the design lists", {
  v4_env()
  p <- v4_proj(list("a.qmd" = V4_CONSTRUCT_DOC, "b.qmd" = V4_PLAIN_DOC), git = TRUE)
  expect_invisible(suppressMessages(verify(path = p$root, static = TRUE)))
  r <- v4_verify(p$root, static = TRUE)
  expect_verify_passed(r)
  x <- r$value
  expect_s3_class(x, "weft_verify")
  expect_true(all(V4_RESULT_FIELDS %in% names(x)), label = paste("missing:", paste(setdiff(V4_RESULT_FIELDS, names(x)), collapse = ", ")))
  expect_type(x$ok, "logical")
  expect_identical(x$ok, TRUE)
  expect_s3_class(x$parts, "data.frame")
  expect_identical(names(x$parts), c("part", "status", "detail"))
  expect_identical(x$parts$part, V4_PARTS)
  expect_true(all(x$parts$status %in% c("ran", "skipped", "failed")))
  expect_identical(v4_status(x, "lints"), "ran")
  expect_identical(v4_status(x, "render"), "skipped")
  for (f in c("errors", "added", "strict", "tier2")) expect_s3_class(x[[f]], "weft_findings")
  for (f in c("errors", "added", "strict", "tier2")) expect_identical(nrow(x[[f]]), 0L, label = f)
  expect_s3_class(x$tolerated, "data.frame")
  expect_identical(names(x$tolerated), c("rule", "n"))
  expect_type(x$notes, "character")
  expect_true(is.numeric(x$seconds) && length(x$seconds) == 1L)
})

test_that("4c G27: a failing run signals weft_verify_error with the object in $result (H17)", {
  v4_env()
  p <- v4_proj(list("a.qmd" = V4_PLAIN_DOC, "b.qmd" = g_bad_doc()), git = TRUE)
  r <- v4_verify(p$root, static = TRUE)
  expect_verify_failed(r)
  x <- r$res
  expect_s3_class(x, "weft_verify")
  expect_identical(x$ok, FALSE)
  expect_identical(v4_status(x, "lints"), "failed")
  expect_identical(x$errors$rule, "construct")
  expect_identical(x$errors$file, "b.qmd")
  expect_identical(x$errors$line, 3L)
  # the result is reachable from the condition by tryCatch, as a caller would
  e <- tryCatch(suppressMessages(verify(path = p$root, static = TRUE)), error = function(e) e)
  expect_s3_class(e$result, "weft_verify")
  expect_identical(e$result$errors$text, F3_BAD_TWO)
})

test_that("4c G27: print() of a result shows the report it printed, and returns it invisibly", {
  v4_env()
  p <- v4_proj(list("a.qmd" = V4_PLAIN_DOC), git = TRUE)
  r <- v4_verify(p$root, static = TRUE)
  expect_identical(v4_print_lines(r$value), r$report)
  expect_invisible(suppressMessages(print(r$value)))
})

# ---- the report (G28) ---------------------------------------------------------------------------------

test_that("4c G28: a clean static run prints the verdict, one line per part, and the time, nothing else", {
  v4_env()
  p <- v4_proj(list("a.qmd" = V4_CONSTRUCT_DOC, "b.qmd" = V4_PLAIN_DOC), git = TRUE)
  r <- v4_verify(p$root, static = TRUE)
  expect_verify_passed(r)
  rep <- r$report
  expect_length(rep, 6L)
  expect_match(rep[2], "^  lints      ")
  expect_identical(rep[3], sprintf("  %-10s %s", "decisions", "skipped: no dict.yml"))
  expect_identical(rep[4], sprintf("  %-10s %s", "render", "skipped: static = TRUE"))
  expect_match(rep[5], "^  ledger     skipped: ")
  expect_identical(rep[6], "weft verify: T s")
  expect_false(any(vapply(V4_SECTIONS, function(s) v4_has_section(rep, s), NA)))
  expect_identical(v4_detail(r$value, "decisions"), "skipped: no dict.yml")
  expect_identical(v4_status(r$value, "decisions"), "skipped")
})

test_that("4c G28: the time line has one decimal and the verdict line is the first", {
  v4_env()
  p <- v4_proj(list("a.qmd" = V4_PLAIN_DOC))
  out <- character()
  withCallingHandlers(verify(path = p$root, static = TRUE),
                      message = function(m) { out <<- c(out, conditionMessage(m)); invokeRestart("muffleMessage") })
  rep <- g_lines(out)
  expect_match(rep[length(rep)], "^weft verify: [0-9]+\\.[0-9] s$")
  expect_identical(rep[1], "weft verify: passed")
})

# ---- construct errors (G24.1) -------------------------------------------------------------------------

test_that("4c G24: a construct error fails whether or not HEAD held it, in a file that did not change", {
  v4_env()
  p <- v4_proj(list("a.qmd" = g_bad_doc(), "b.qmd" = V4_PLAIN_DOC), git = TRUE)
  r <- v4_verify(p$root, static = TRUE)   # nothing has changed since HEAD
  expect_verify_failed(r)
  expect_identical(r$res$errors$rule, "construct")
  expect_identical(r$res$errors$file, "a.qmd")
  rep <- r$report
  expect_true(v4_has_section(rep, "Construct errors"))
  sec <- v4_section(rep, "Construct errors")
  expect_true("  a.qmd" %in% sec)
  expect_true(any(grepl("^ {4}[ 0-9]{5}  construct  ", sec)), label = paste(sec, collapse = "\n"))
  expect_match(sec[grepl("construct  ", sec)][1], "^ {4}    3  construct  ")
})

test_that("4c G24: block-start and read are construct errors too (the other two rules of the set)", {
  v4_env()
  # an unreadable file: bytes that are not UTF-8 in a document
  p <- v4_proj(list("a.qmd" = as.raw(c(0x41, 0x20, 0xff, 0xfe, 0x0a))), git = TRUE)
  r <- v4_verify(p$root, static = TRUE)
  if (is.null(r$err)) skip("this build reads that file; no `read` finding to judge")
  expect_verify_failed(r)
  expect_true(all(r$res$errors$rule %in% c("construct", "block-start", "read")))
})

# ---- findings added since a commit (G24.1, G10) -------------------------------------------------------

test_that("4c G24: since fails on a finding added, listed at its line, and a finding already in HEAD does not", {
  v4_need("numeral")
  v4_env()
  s <- st_two_commits(list("ch1.qmd" = G_PROSE), list("ch1.qmd" = g_num_doc("45%")))
  r <- v4_verify(s$p$root, since = s$base, static = TRUE)
  expect_verify_failed(r)
  x <- r$res
  expect_identical(x$added$rule, "numeral")
  expect_identical(x$added$file, "ch1.qmd")
  expect_identical(x$added$line, 3L)
  expect_identical(x$added$text, "45%")
  head <- grep("^Findings added since ", r$report, value = TRUE)
  expect_length(head, 1L)
  expect_match(head, paste0("^Findings added since ", v4_short(s$base)))
  sec <- v4_section(r$report, "Findings added since")
  expect_true("  ch1.qmd" %in% sec)
  expect_true(any(grepl("^ {4}    3  numeral  ", sec)))
  # since = HEAD (the default): the finding is in HEAD, so it is tolerated, not added
  r2 <- v4_verify(s$p$root, static = TRUE)
  expect_verify_passed(r2)
  expect_identical(nrow(r2$value$added), 0L)
  expect_false(v4_has_section(r2$report, "Findings added since"))
})

test_that("4c G24: with no since, the comparison is with HEAD and counts the work tree", {
  v4_need("numeral")
  v4_env()
  p <- v4_proj(list("ch1.qmd" = G_PROSE), git = TRUE)
  g_write(p$top, "ch1.qmd", g_num_doc("45%"))   # not committed, not staged
  r <- v4_verify(p$root, static = TRUE)
  expect_verify_failed(r)
  expect_identical(r$res$added$text, "45%")
  # the same finding moved to another file passes (the keys cancel, G10)
  g_apply(p$top, list("ch1.qmd" = G_PROSE))
  g_apply(p$top, list("ch2.qmd" = g_num_doc("45%")))
  g_add(p$top); g_commit(p$top, "second")
  g_apply(p$top, list("ch1.qmd" = g_num_doc("45%"), "ch2.qmd" = G_PROSE))
  expect_verify_passed(v4_verify(p$root, static = TRUE))
})

test_that("4c G24: a finding in an unchanged chapter caused by removing an anchor is added, and listed there (rule 6.2.4)", {
  v4_need("xref")
  v4_env()
  p <- v4_proj(list("ch1.qmd" = c("## Limits {#sec-limits}", "", "Text."), "ch2.qmd" = "See @sec-limits for more."),
               git = TRUE)
  g_write(p$top, "ch1.qmd", c("## Limits {#sec-bounds}", "", "Text."))
  r <- v4_verify(p$root, static = TRUE)
  expect_verify_failed(r)
  expect_identical(r$res$added$rule, "xref")
  expect_identical(r$res$added$file, "ch2.qmd")
  # files names ch1 only: the rules that read across files still read the whole project (G29, 8.2.1)
  r2 <- v4_verify(p$root, files = "ch1.qmd", static = TRUE)
  expect_verify_failed(r2)
  expect_identical(r2$res$added$file, "ch2.qmd")
})

# ---- constructs removed (G24.1, 8.2.2) ----------------------------------------------------------------

test_that("4c G24: since reports constructs removed and does not fail on them, trailer or no trailer", {
  v4_env()
  vars <- g_vals(c("rain_mean", "n_sites", "depth_max"))
  s <- st_two_commits(list("ch1.qmd" = vars), list("ch1.qmd" = g_vals("rain_mean")))
  r <- v4_verify(s$p$root, since = s$base, static = TRUE)
  expect_verify_passed(r)
  x <- r$value
  expect_gt(nrow(x$removed), 0L)
  expect_true(all(c("file", "line", "kind", "text") %in% names(x$removed)))
  expect_identical(nrow(x$removed), 2L)
  expect_true(all(x$removed$file == "ch1.qmd"))
  expect_true(any(grepl("n_sites", x$removed$text, fixed = TRUE)))
  expect_true(any(grepl("depth_max", x$removed$text, fixed = TRUE)))
  expect_true(any(startsWith(r$report,
    sprintf("Constructs removed since %s (reported, not judged; rule 8.2.2)", v4_short(s$base)))))
  sec <- v4_section(r$report, "Constructs removed since")
  expect_true(any(grepl("n_sites", sec, fixed = TRUE)) && any(grepl("depth_max", sec, fixed = TRUE)))
  expect_false(any(grepl("rain_mean", sec, fixed = TRUE)))
})

# ---- tolerated and strict (G24.1, G26, 8.1.2, 8.1.3) --------------------------------------------------

test_that("4c G28: a tolerated finding fails nothing and is totalled, rule by rule", {
  v4_need("numeral")
  v4_env()
  p <- v4_proj(list("ch1.qmd" = g_num_doc(c("45%", "37%"))), git = TRUE)
  r <- v4_verify(p$root, static = TRUE)
  expect_verify_passed(r)
  expect_identical(r$value$tolerated$rule, "numeral")
  expect_identical(as.integer(r$value$tolerated$n), 2L)
  rep <- r$report
  head <- "Tolerated findings (rule 8.1.2); make a rule strict in _weft.yml when its count is 0:"
  expect_true(head %in% rep)
  expect_identical(rep[which(rep == head) + 1L], sprintf("  %-15s %d remain", "numeral", 2L))
  expect_identical(rep[length(rep)], "weft verify: T s")
  expect_false("construct" %in% r$value$tolerated$rule)
})

test_that("4c G28: construct-error rules are not in the tolerated totals", {
  v4_need("numeral")
  v4_env()
  p <- v4_proj(list("a.qmd" = g_bad_doc(), "b.qmd" = g_num_doc("45%")), git = TRUE)
  r <- v4_verify(p$root, static = TRUE)
  expect_verify_failed(r)
  expect_false(any(c("construct", "block-start", "read") %in% r$res$tolerated$rule))
  expect_true("numeral" %in% r$res$tolerated$rule)
})

test_that("4c G24: a rule in strict fails on every instance, though HEAD held them all", {
  v4_need("numeral")
  v4_env()
  p <- v4_proj(list("ch1.qmd" = g_num_doc(c("45%", "37%"))), git = TRUE,
               weft_yml = c("draft: false", "strict: [numeral]"))
  r <- v4_verify(p$root, static = TRUE)
  expect_verify_failed(r)
  x <- r$res
  expect_identical(nrow(x$added), 0L)
  expect_identical(sort(x$strict$text), c("37%", "45%"))
  expect_true(all(x$strict$rule == "numeral"))
  sec <- v4_section(r$report, "Strict rules")
  expect_true(length(sec) >= 3L)
  expect_identical(sum(grepl("^ {4}[ 0-9]{5}  numeral  ", sec)), 2L)
  # without the setting the same project passes
  q <- v4_proj(list("ch1.qmd" = g_num_doc(c("45%", "37%"))), git = TRUE)
  expect_verify_passed(v4_verify(q$root, static = TRUE))
})

test_that("4c G24: strict also holds without git, where nothing is compared", {
  v4_need("numeral")
  v4_env()
  p <- v4_proj(list("ch1.qmd" = g_num_doc("45%")), weft_yml = c("draft: false", "strict: [numeral]"))
  r <- v4_verify(p$root, static = TRUE)
  expect_verify_failed(r)
  expect_identical(r$res$strict$text, "45%")
})

# ---- tar-name is judged absolutely (H5) ---------------------------------------------------------------

test_that("4c G24, H5: a tar-name finding fails verify() though HEAD held it", {
  skip_if_not_installed("targets")
  skip_on_cran()
  v4_env()
  doc <- c("---", "title: T", "---", "", "```{r}", "x <- tar_read(fitt)", "```")
  p <- v4_proj(list("a.qmd" = doc), git = TRUE)
  c3_store(p$root, c("fit", "dat"))
  # the store is a build product: not committed, but read from the work tree by verify()
  r <- v4_verify(p$root, static = TRUE)
  expect_verify_failed(r)
  expect_true(v4_has_section(r$report, "Target names"))
  sec <- v4_section(r$report, "Target names")
  expect_true(any(grepl("fitt", sec, fixed = TRUE)))
  # a target that exists is fine
  g_write(p$top, "a.qmd", sub("fitt", "fit", doc, fixed = TRUE))
  expect_verify_passed(v4_verify(p$root, static = TRUE))
})

# ---- tier 2 on added lines (H18, G16) -----------------------------------------------------------------

test_that("4c G24, H18: tier-2 findings are listed for the lines added since, and fail nothing", {
  v4_need("claim-word")
  v4_env()
  s <- st_two_commits(
    list("ch1.qmd" = c("Intro.", "", V4_CLAIM_WORD)),
    list("ch1.qmd" = c("Intro.", "", V4_CLAIM_WORD, "", "All `r m` rivers rose.")))
  r <- v4_verify(s$p$root, since = s$base, static = TRUE)
  expect_verify_passed(r)
  expect_identical(r$value$tier2$rule, "claim-word")
  expect_identical(r$value$tier2$line, 5L)     # the old sentence on line 3 is not on an added line
  expect_true(v4_has_section(r$report, "Tier-2 findings on added lines"))
  sec <- v4_section(r$report, "Tier-2 findings on added lines")
  expect_true(any(grepl("^ {4}    5  claim-word  ", sec)))
  expect_false(any(grepl("^ {4}    3  claim-word", sec)))
})

test_that("4c G24: with no since, every line counts as added for tier 2", {
  v4_need("claim-word")
  v4_env()
  p <- v4_proj(list("ch1.qmd" = c("Intro.", "", V4_CLAIM_WORD)))      # no git
  r <- v4_verify(p$root, static = TRUE)
  expect_verify_passed(r)
  expect_identical(r$value$tier2$line, 3L)
})

# ---- no git, no commit (H19, G24.1) -------------------------------------------------------------------

test_that("4c G24, H19: without git findings are counted, not compared, and the note says so", {
  v4_need("numeral")
  v4_env()
  p <- v4_proj(list("ch1.qmd" = g_num_doc("45%")))
  r <- v4_verify(p$root, static = TRUE)
  expect_verify_passed(r)        # a numeral is a finding, not an error, and there is nothing to compare with
  note <- "no commit to compare with: findings are counted, not compared (rule 8.2.2)"
  expect_true(note %in% r$value$notes)
  expect_true(any(grepl(note, r$report, fixed = TRUE)))
  expect_identical(r$value$tolerated$rule, "numeral")
  expect_identical(nrow(r$value$added), 0L)
})

test_that("4c G24, H19: a repository with no commit gives the same note; construct errors still fail", {
  v4_env()
  p <- v4_proj(list("a.qmd" = V4_PLAIN_DOC))
  g_ok_git(p$root, "init", "-q", "-b", "main")
  r <- v4_verify(p$root, static = TRUE)
  expect_verify_passed(r)
  expect_true("no commit to compare with: findings are counted, not compared (rule 8.2.2)" %in% r$value$notes)
  g_write(p$root, "b.qmd", g_bad_doc())
  expect_verify_failed(v4_verify(p$root, static = TRUE))
})

test_that("4c G24: no note when there is a commit to compare with", {
  v4_env()
  p <- v4_proj(list("a.qmd" = V4_PLAIN_DOC), git = TRUE)
  r <- v4_verify(p$root, static = TRUE)
  expect_verify_passed(r)
  expect_false(any(grepl("no commit to compare with", r$value$notes, fixed = TRUE)))
})

# ---- files (G23, G29) ---------------------------------------------------------------------------------

test_that("4c G29: files judges the named documents' construct errors only", {
  v4_env()
  p <- v4_proj(list("a.qmd" = V4_PLAIN_DOC, "b.qmd" = g_bad_doc()), git = TRUE)
  expect_verify_passed(v4_verify(p$root, files = "a.qmd", static = TRUE))
  r <- v4_verify(p$root, files = "b.qmd", static = TRUE)
  expect_verify_failed(r)
  expect_identical(r$res$errors$file, "b.qmd")
  # a vector of two
  expect_verify_failed(v4_verify(p$root, files = c("a.qmd", "b.qmd"), static = TRUE))
  # a path that is a document in a subfolder
  q <- v4_proj(list("a.qmd" = V4_PLAIN_DOC, "sub/b.qmd" = g_bad_doc()), git = TRUE)
  expect_verify_passed(v4_verify(q$root, files = "a.qmd", static = TRUE))
  expect_verify_failed(v4_verify(q$root, files = "sub/b.qmd", static = TRUE))
})

test_that("4c G29: a file that is not there is an error, not a pass", {
  v4_env()
  p <- v4_proj(list("a.qmd" = V4_PLAIN_DOC), git = TRUE)
  e <- tryCatch(suppressMessages(verify(path = p$root, files = "nope.qmd", static = TRUE)), error = function(e) e)
  expect_true(inherits(e, "weft_error"))
})

# ---- decision pointers (G24.2) ------------------------------------------------------------------------

test_that("4c G24: pointers resolved by the glob route pass; one that matches no file fails (4.5.2)", {
  v4_env()
  files <- list("a.qmd" = V4_PLAIN_DOC, "decisions/12-core.md" = "x", "decisions/31-other.md" = "x",
                "dict.yml" = DICT_PTR("12", "31"))
  yml <- c("draft: false", "decisions: \"decisions/{id}-*.md\"")
  p <- v4_proj(files, git = TRUE, weft_yml = yml)
  r <- v4_verify(p$root, static = TRUE)
  expect_verify_passed(r)
  expect_identical(v4_status(r$value, "decisions"), "ran")
  expect_s3_class(r$value$decisions, "data.frame")
  expect_identical(r$value$decisions$resolved, c(TRUE, TRUE))
  # a pointer with no file
  files[["dict.yml"]] <- DICT_PTR("12", "99")
  q <- v4_proj(files, git = TRUE, weft_yml = yml)
  r2 <- v4_verify(q$root, static = TRUE)
  expect_verify_failed(r2)
  expect_identical(v4_status(r2$res, "decisions"), "failed")
  expect_identical(r2$res$decisions$resolved, c(TRUE, FALSE))
  expect_true(v4_has_section(r2$report, "Decision pointers"))
  sec <- v4_section(r2$report, "Decision pointers")
  expect_true(any(grepl("99", sec, fixed = TRUE)))
  expect_false(any(grepl("decisions/12-core.md", sec, fixed = TRUE)))
})

test_that("4c G24: a pointer that could not be checked is listed and fails nothing", {
  v4_env()
  # the default resolver is github; a repository with no origin cannot be checked, and nothing goes to the network
  files <- list("a.qmd" = V4_PLAIN_DOC, "dict.yml" = DICT_PTR("12"))
  p <- v4_proj(files, git = TRUE)
  r <- v4_verify(p$root, static = TRUE)
  expect_verify_passed(r)
  expect_true(is.na(r$value$decisions$resolved))
  expect_true(any(grepl("could not check", r$report, fixed = TRUE)))
  expect_false(v4_has_section(r$report, "Decision pointers") &&
                 any(grepl("does not resolve", v4_section(r$report, "Decision pointers"), fixed = TRUE)))
})

test_that("4c G24: a dict.yml that will not read fails, with its message", {
  v4_env()
  p <- v4_proj(list("a.qmd" = V4_PLAIN_DOC, "dict.yml" = c("a: {value: 1", "b: [")), git = TRUE)
  r <- v4_verify(p$root, static = TRUE)
  expect_verify_failed(r)
  expect_identical(v4_status(r$res, "decisions"), "failed")
  expect_true(any(grepl("dict.yml", r$report, fixed = TRUE)))
})

test_that("4c G24: with no _weft.yml the resolver is the single document's weft: decisions: front matter", {
  v4_env()
  doc <- c("---", "title: T", "weft:", "  decisions: \"decisions/{id}-*.md\"", "---", "", "Plain words.")
  p <- v4_proj(list("a.qmd" = doc, "decisions/12-core.md" = "x", "dict.yml" = DICT_PTR("12", "77")), weft_yml = NULL)
  r <- v4_verify(p$root, static = TRUE)
  expect_verify_failed(r)
  expect_identical(r$res$decisions$resolved, c(TRUE, FALSE))
})

# ---- nothing rendered ---------------------------------------------------------------------------------

test_that("4c G24: static = TRUE renders nothing, writes no stamp and does not touch _freeze", {
  v4_env()
  fq <- v4_fake_quarto(observe = c("a", "b"))
  p <- v4_proj(list("a.qmd" = V4_CONSTRUCT_DOC, "b.qmd" = V4_PLAIN_DOC), git = TRUE,
               quarto_yml = V4_QUARTO_YML)
  v4_plant_freeze(p$root)
  before <- v4_freeze_snap(p$root)
  expect_verify_passed(v4_verify(p$root, static = TRUE))
  expect_length(v4_log(fq, "calls"), 0L)
  expect_identical(v4_freeze_snap(p$root), before)
  expect_false(dir.exists(v4_backup_dir(p$root)))
  expect_false(dir.exists(file.path(p$root, ".weft", "stamps")))
})

test_that("4c G24: static = TRUE needs no quarto at all", {
  v4_env(extra = c(QUARTO_PATH = file.path(tempdir(), "no-such-quarto")))
  p <- v4_proj(list("a.qmd" = V4_PLAIN_DOC), git = TRUE, quarto_yml = V4_QUARTO_YML)
  expect_verify_passed(v4_verify(p$root, static = TRUE))
})

test_that("4c G24: the static run of a project with no _weft.yml passes (only render needs one)", {
  v4_env()
  p <- v4_proj(list("a.qmd" = V4_PLAIN_DOC), weft_yml = NULL)
  expect_verify_passed(v4_verify(p$root, static = TRUE))
})

# ---- a project in a subfolder of a repository ---------------------------------------------------------

test_that("4c G23: a project in a subfolder of a repository is compared by its own files", {
  v4_need("numeral")
  v4_env()
  p <- v4_proj(list("ch1.qmd" = G_PROSE), git = TRUE, sub = TRUE)
  g_write(p$root, "ch1.qmd", g_num_doc("45%"))
  r <- v4_verify(p$root, static = TRUE)
  expect_verify_failed(r)
  expect_identical(r$res$added$file, "ch1.qmd")
})

# ---- nothing is written outside the project -----------------------------------------------------------

test_that("4c G3: a static run writes nothing outside the project and moves nothing in git", {
  v4_need("numeral")
  v4_env()
  p <- v4_proj(list("ch1.qmd" = g_num_doc("45%"), "ch2.qmd" = G_PROSE), git = TRUE, sub = TRUE)
  g_write(p$root, "ch2.qmd", g_num_doc("37%"))
  outside <- v4_outside_snap(p$top, p$root)
  git <- g_git_snapshot(p$top)
  tmp <- list.files(tempdir(), recursive = TRUE, all.files = TRUE, include.dirs = TRUE)
  r <- v4_verify(p$root, static = TRUE)
  expect_verify_failed(r)
  expect_identical(v4_outside_snap(p$top, p$root), outside)
  # git is only read: no ref moved, nothing staged (the cache folder .git/weft is left out of the snapshot)
  expect_identical(g_git_snapshot(p$top), git)
  # temporary folders are removed before it returns
  expect_identical(list.files(tempdir(), recursive = TRUE, all.files = TRUE, include.dirs = TRUE), tmp)
})

# ---- Rscript (G27, H17) -------------------------------------------------------------------------------

test_that("4c G27, H17: Rscript -e 'weft::verify(static = TRUE)' exits 1 on a failure and 0 on a pass", {
  skip_on_cran()
  skip_on_os("windows")
  bad <- v4_proj(list("a.qmd" = g_bad_doc()))
  good <- v4_proj(list("a.qmd" = V4_PLAIN_DOC))
  env <- u4_env(u4_home())
  r1 <- u4_r(bad$root, "weft::verify(static = TRUE)", env)
  expect_identical(r1$status, 1L, info = r1$out)
  expect_match(r1$out, "weft verify: failed", fixed = TRUE)
  expect_match(r1$out, "verify() failed:", fixed = TRUE)
  r0 <- u4_r(good$root, "weft::verify(static = TRUE)", env)
  expect_identical(r0$status, 0L, info = r0$out)
  expect_match(r0$out, "weft verify: passed", fixed = TRUE)
})
