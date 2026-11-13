# Package 4c: verify()'s render part, the knit-time results, the ledger part and the draft refusal
# (dev/design-4.md G24 parts 3 and 4, G25, G26, G27, G28, G30; H20, H21; section 5 "test-verify-render.R").
# Two kinds of test. Most use a stand-in `quarto` (helper-4c.R: v4_fake_quarto()) that writes stamps as
# a render would: fast, and every case of G26 is reachable. A few use real Quarto on two tiny documents,
# rendered once and shared (v4_real_pass(), v4_real_fail()); they skip when quarto is not found.
# ASCII only. Invented content only.

expect_verify_failed <- function(r) {
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

# a project of the stand-in render: a.qmd holds a construct, b.qmd none; `extra` files; git optional
fk_proj <- function(files = list("a.qmd" = V4_CONSTRUCT_DOC, "b.qmd" = V4_PLAIN_DOC), env = parent.frame(), ...) {
  v4_proj(files, quarto_yml = V4_QUARTO_YML, env = env, ...)
}

FAILURE_A <- list(list(kind = "failed claim", file = "a.qmd", line = 3L, expr = "`r claim(depth, . > 100)`",
                       detail = ". > 100 was FALSE (value 12.5)"))
NOT_EXECUTED <- "not executed in this render: served from freeze, or knit without weft active"

# ---- draft mode is refused before anything runs (G24, 8.1.5, 9.4.3) ------------------------------------

test_that("4c G24: draft: true in _weft.yml is refused with the design's message, and nothing runs", {
  v4_env()
  fq <- v4_fake_quarto(observe = "a")
  # a project that would otherwise fail in three ways, so that only the refusal can explain the error
  p <- fk_proj(list("a.qmd" = g_bad_doc(), "dict.yml" = DICT_PTR("12")), git = TRUE,
               weft_yml = c("draft: true", "strict: [numeral]"))
  v4_plant_freeze(p$root, "a")
  v4_plant_stale_ledger(p$root, "a.qmd")
  before <- g_snapshot(p$root)
  r <- v4_verify(p$root)
  expect_s3_class(r$err, "weft_verify_error")
  expect_s3_class(r$err, "weft_error")
  expect_identical(cli::ansi_strip(conditionMessage(r$err)), paste0(
    "verify() does not run in draft mode (rule 8.1.5): draft is on in _weft.yml. ",
    "A draft render fails nothing, so it can verify nothing."))
  expect_length(r$report, 0L)                     # no report: not a single part ran
  expect_length(v4_log(fq, "calls"), 0L)
  expect_identical(g_snapshot(p$root), before)    # nothing written, _freeze untouched, no backup
  expect_false(dir.exists(v4_backup_dir(p$root)))
})

test_that("4c G24: WEFT_DRAFT=1 and WEFT_DRAFT=true are refused, the clause naming the variable", {
  for (v in c("1", "true")) {
    v4_env(extra = c(WEFT_DRAFT = v))
    fq <- v4_fake_quarto()
    p <- fk_proj(git = TRUE)
    r <- v4_verify(p$root)
    expect_s3_class(r$err, "weft_verify_error")
    expect_identical(cli::ansi_strip(conditionMessage(r$err)), paste0(
      "verify() does not run in draft mode (rule 8.1.5): WEFT_DRAFT is set. ",
      "A draft render fails nothing, so it can verify nothing."), label = v)
    expect_length(v4_log(fq, "calls"), 0L)
  }
})

test_that("4c G24: draft is refused for static = TRUE and for a given since as well", {
  v4_env()
  p <- v4_proj(list("a.qmd" = V4_PLAIN_DOC), git = TRUE, weft_yml = "draft: true")
  for (a in list(list(static = TRUE), list(static = TRUE, since = "HEAD"), list(files = "a.qmd", static = TRUE))) {
    e <- tryCatch(suppressMessages(do.call(verify, c(list(path = p$root), a))), error = function(e) e)
    f2_has_class(e, "weft_verify_error")
    expect_match(conditionMessage(e), "does not run in draft mode (rule 8.1.5)", fixed = TRUE)
  }
})

test_that("4c G24: draft: false and no WEFT_DRAFT are not draft mode", {
  v4_env()
  fq <- v4_fake_quarto()
  p <- fk_proj(list("a.qmd" = V4_PLAIN_DOC), weft_yml = "draft: false")
  r <- v4_verify(p$root)
  expect_verify_passed(r)
})

# ---- the render needs a set-up project (G24.3) --------------------------------------------------------

test_that("4c G24: a render of a project with no _weft.yml is refused with the design's text", {
  v4_env()
  fq <- v4_fake_quarto()
  p <- v4_proj(list("a.qmd" = V4_PLAIN_DOC), weft_yml = NULL, quarto_yml = V4_QUARTO_YML)
  r <- v4_verify(p$root)
  txt <- paste(c(if (!is.null(r$err)) conditionMessage(r$err), r$report), collapse = "\n")
  expect_false(is.null(r$err))
  expect_s3_class(r$err, "weft_verify_error")
  expect_match(txt, "verify() renders and reads the stamps of a set-up project;", fixed = TRUE)
  expect_match(txt, "has no _weft.yml (rule 9.3.2)", fixed = TRUE)
  expect_length(v4_log(fq, "calls"), 0L)
})

# ---- how quarto is called (G25) -----------------------------------------------------------------------

test_that("4c G25: one `quarto render` in the root, with no files, output to a log, and the run id in WEFT_RUN", {
  v4_env()
  fq <- v4_fake_quarto(body = c(v4_sh_stamp("a.qmd")))
  p <- fk_proj(git = TRUE)
  r <- v4_verify(p$root)
  expect_verify_passed(r)
  expect_length(v4_log(fq, "calls"), 1L)
  expect_identical(v4_log(fq, "args"), c("render", "--execute-daemon-restart"))
  expect_identical(normalizePath(v4_log(fq, "cwd")), normalizePath(p$root))
  run <- v4_log(fq, "run")
  expect_match(run, V4_RUN_RE)
  expect_match(run, sprintf("-%d$", Sys.getpid()))
  expect_identical(v4_status(r$value, "render"), "ran")
  # the run id is read back: the stamp the stand-in wrote carries it
  expect_identical(v4_stamp(p$root, "a.qmd")$run, run)
})

test_that("4c G25: the stand-in's output is not echoed into the report when the render passes", {
  v4_env()
  fq <- v4_fake_quarto(body = v4_sh_stamp("a.qmd"), out = "Output created: nothing")
  p <- fk_proj(git = TRUE)
  r <- v4_verify(p$root)
  expect_verify_passed(r)
  expect_false(any(grepl("Output created", r$report, fixed = TRUE)))
})

test_that("4c G25, G29: verify(files =) renders the named documents only: `quarto render <files>`", {
  v4_env()
  fq <- v4_fake_quarto(body = v4_sh_stamp("a.qmd"))
  p <- fk_proj(list("a.qmd" = V4_CONSTRUCT_DOC, "b.qmd" = V4_CONSTRUCT_DOC, "sub/c.qmd" = V4_PLAIN_DOC), git = TRUE)
  r <- v4_verify(p$root, files = "a.qmd")
  expect_verify_passed(r)
  expect_identical(v4_log(fq, "args"), c("render", "a.qmd", "--execute-daemon-restart"))
  fq2 <- v4_fake_quarto(body = v4_sh_stamp("a.qmd"))   # sub/c.qmd holds no construct: no stamp needed
  r2 <- v4_verify(p$root, files = c("a.qmd", "sub/c.qmd"))
  expect_verify_passed(r2)
  # review-4 #4: several files are rendered one `quarto render <file>` at a time (Quarto renders the first
  # of `render a b` and hands the second to Pandoc)
  expect_identical(v4_log(fq2, "renders"), c("render a.qmd --execute-daemon-restart", "render sub/c.qmd --execute-daemon-restart"))
})

test_that("4c G25: QUARTO_PATH names the quarto that is run (it comes first)", {
  v4_env()
  fq <- v4_fake_quarto(body = v4_sh_stamp("a.qmd"))
  expect_identical(Sys.getenv("QUARTO_PATH"), fq$path)
  p <- fk_proj(git = TRUE)
  expect_verify_passed(v4_verify(p$root))
  expect_length(v4_log(fq, "calls"), 1L)
})

test_that("4c G25: a document with no weft construct needs no stamp, and one that holds a construct needs a stamp of this run", {
  v4_env()
  # b.qmd holds none: no stamp for it is not a failure
  fq <- v4_fake_quarto(body = v4_sh_stamp("a.qmd"))
  p <- fk_proj(git = TRUE)
  r <- v4_verify(p$root)
  expect_verify_passed(r)
  expect_identical(length(r$value$unexecuted), 0L)
  expect_false(v4_has_section(r$report, "Not executed in this render"))
})

# ---- G26: the knit-time results from the stamps -------------------------------------------------------

test_that("4c G26: failures in a stamp of this run fail verify(), listed with their file and line", {
  v4_env()
  fq <- v4_fake_quarto(body = v4_sh_stamp("a.qmd", failures = FAILURE_A))
  p <- fk_proj(git = TRUE)
  r <- v4_verify(p$root)
  expect_verify_failed(r)
  x <- r$res
  expect_identical(NROW(x$knit), 1L)
  expect_identical(v4_status(x, "render"), "failed")
  expect_true(v4_has_section(r$report, "Knit-time failures"))
  sec <- v4_section(r$report, "Knit-time failures")
  expect_true(any(grepl("a.qmd", sec, fixed = TRUE)))
  expect_true(any(grepl("3", sec, fixed = TRUE)))
  expect_true(any(grepl(". > 100 was FALSE (value 12.5)", sec, fixed = TRUE)))
  expect_false(v4_has_section(r$report, "Not executed in this render"))
})

test_that("4c G26: several failures in several documents are all listed", {
  v4_env()
  fb <- list(list(kind = "no value", file = "b.qmd", line = 3L, expr = "`r NA_real_`",
                  detail = "A formatter was given a missing value."))
  fq <- v4_fake_quarto(body = c(v4_sh_stamp("a.qmd", failures = c(FAILURE_A, FAILURE_A)),
                                v4_sh_stamp("b.qmd", failures = fb)))
  p <- fk_proj(list("a.qmd" = V4_CONSTRUCT_DOC, "b.qmd" = V4_CONSTRUCT_DOC), git = TRUE)
  r <- v4_verify(p$root)
  expect_verify_failed(r)
  expect_identical(NROW(r$res$knit), 3L)
  sec <- v4_section(r$report, "Knit-time failures")
  expect_true(any(grepl("a.qmd", sec, fixed = TRUE)) && any(grepl("b.qmd", sec, fixed = TRUE)))
})

test_that("4c G26: a failure in a stamp of another run is not this run's, and the document is then unexecuted", {
  v4_env()
  fq <- v4_fake_quarto(body = v4_sh_stamp("a.qmd", run = "older-run", failures = FAILURE_A))
  p <- fk_proj(git = TRUE)
  r <- v4_verify(p$root)
  expect_verify_failed(r)
  expect_identical(NROW(r$res$knit), 0L)
  expect_true(v4_has_section(r$report, "Not executed in this render"))
})

test_that("4c G26, H21: a document that holds a construct and has no stamp from this run fails: not executed in this render", {
  v4_env()
  fq <- v4_fake_quarto()                       # a render that wrote no stamp, as one served from freeze would
  p <- fk_proj(git = TRUE)
  v4_plant_freeze(p$root, c("a", "b"))
  r <- v4_verify(p$root)
  expect_verify_failed(r)
  x <- r$res
  expect_true(any(grepl("a.qmd", as.character(unlist(x$unexecuted)), fixed = TRUE)))
  expect_false(any(grepl("b.qmd", as.character(unlist(x$unexecuted)), fixed = TRUE)))   # no construct, not judged
  sec <- v4_section(r$report, "Not executed in this render")
  expect_true(any(grepl("a.qmd", sec, fixed = TRUE)))
  expect_true(any(grepl(NOT_EXECUTED, sec, fixed = TRUE)))
  expect_identical(NROW(x$knit), 0L)
})

test_that("4c G26: a document with a construct and a stamp of this run with no failures passes", {
  v4_env()
  fq <- v4_fake_quarto(body = v4_sh_stamp("a.qmd"))
  p <- fk_proj(git = TRUE)
  r <- v4_verify(p$root)
  expect_verify_passed(r)
  expect_identical(NROW(r$value$knit), 0L)
  expect_identical(length(r$value$unexecuted), 0L)
})

test_that("4c G26: the documents verified are the ones judged: failures and missing stamps of the others are not", {
  v4_env()
  fb <- list(list(kind = "failed claim", file = "b.qmd", line = 3L, expr = "`r claim(x)`", detail = "x was FALSE"))
  fq <- v4_fake_quarto(body = c(v4_sh_stamp("a.qmd"), v4_sh_stamp("b.qmd", failures = fb)))
  p <- fk_proj(list("a.qmd" = V4_CONSTRUCT_DOC, "b.qmd" = V4_CONSTRUCT_DOC, "c.qmd" = V4_CONSTRUCT_DOC), git = TRUE)
  r <- v4_verify(p$root, files = "a.qmd")
  expect_verify_passed(r)                      # b failed and c was never executed, neither is named
  expect_identical(NROW(r$value$knit), 0L)
  expect_identical(length(r$value$unexecuted), 0L)
})

test_that("4c G26: a non-zero exit with no failure in a stamp fails with the log from the first weft: line", {
  v4_env()
  fq <- v4_fake_quarto(body = c("echo 'some noise before'", "echo 'weft: 1 failure'", "echo '  a.qmd:3  something broke'",
                                "echo 'a last line'"),
                       status = 1L, out = character())
  p <- fk_proj(list("a.qmd" = V4_PLAIN_DOC), git = TRUE)
  r <- v4_verify(p$root)
  expect_verify_failed(r)
  expect_identical(v4_status(r$res, "render"), "failed")
  expect_true(any(grepl("weft: 1 failure", r$report, fixed = TRUE)))
  expect_true(any(grepl("a.qmd:3  something broke", r$report, fixed = TRUE)))
  expect_true(any(grepl("a last line", r$report, fixed = TRUE)))
  expect_false(any(grepl("some noise before", r$report, fixed = TRUE)))
})

test_that("4c G26: a non-zero exit with no weft: line fails with the last 40 lines of the log", {
  v4_env()
  fq <- v4_fake_quarto(body = "i=1; while [ $i -le 60 ]; do echo \"log line $i\"; i=$((i + 1)); done",
                       status = 1L)
  p <- fk_proj(list("a.qmd" = V4_PLAIN_DOC), git = TRUE)
  r <- v4_verify(p$root)
  expect_verify_failed(r)
  expect_true(any(grepl("log line 60", r$report, fixed = TRUE)))
  expect_true(any(grepl("log line 21", r$report, fixed = TRUE)))
  expect_false(any(grepl("log line 20", r$report, fixed = TRUE)))
  expect_false(any(grepl("log line 1$", r$report)))
})

test_that("4c G26: a non-zero exit when the stamps hold failures reports the failures, as the knit's own", {
  v4_env()
  fq <- v4_fake_quarto(body = v4_sh_stamp("a.qmd", failures = FAILURE_A), status = 1L)
  p <- fk_proj(git = TRUE)
  r <- v4_verify(p$root)
  expect_verify_failed(r)
  expect_identical(NROW(r$res$knit), 1L)
  expect_true(v4_has_section(r$report, "Knit-time failures"))
})

# ---- the ledger part (G24.4, 7.2.3) -------------------------------------------------------------------

test_that("4c G24: a verified document whose ledger the render did not rewrite and that is stale fails, with its reasons", {
  v4_env()
  fq <- v4_fake_quarto(body = v4_sh_stamp("a.qmd"))
  p <- fk_proj(git = TRUE)
  v4_plant_stale_ledger(p$root, "a.qmd")        # a header holding dict$lim as it was; dict.yml now says otherwise
  r <- v4_verify(p$root)
  expect_verify_failed(r)
  expect_identical(v4_status(r$res, "ledger"), "failed")
  expect_gte(NROW(r$res$stale), 1L)
  expect_true(v4_has_section(r$report, "Ledger: entries not re-rendered"))
  sec <- v4_section(r$report, "Ledger: entries not re-rendered")
  expect_true(any(grepl("dict$lim changed", sec, fixed = TRUE)))
  expect_true(any(grepl("a.qmd", sec, fixed = TRUE)))
})

test_that("4c G24: a stale ledger of a document that is not verified is not judged", {
  v4_env()
  fq <- v4_fake_quarto(body = v4_sh_stamp("b.qmd"))
  p <- fk_proj(git = TRUE)
  v4_plant_stale_ledger(p$root, "a.qmd")
  r <- v4_verify(p$root, files = "b.qmd")
  expect_verify_passed(r)
  expect_identical(NROW(r$value$stale), 0L)
})

test_that("4c G24: a project with no stale ledger passes the ledger part (it ran)", {
  v4_env()
  fq <- v4_fake_quarto(body = v4_sh_stamp("a.qmd"))
  p <- fk_proj(git = TRUE)
  r <- v4_verify(p$root)
  expect_verify_passed(r)
  expect_identical(v4_status(r$value, "ledger"), "ran")
  expect_identical(NROW(r$value$stale), 0L)
})

# ---- the report (G28) ---------------------------------------------------------------------------------

test_that("4c G28: a failed render's report has the verdict, the four parts, the sections, and the time last", {
  v4_env()
  fq <- v4_fake_quarto(body = v4_sh_stamp("a.qmd", failures = FAILURE_A))
  p <- fk_proj(git = TRUE)
  r <- v4_verify(p$root)
  rep <- r$report
  expect_identical(rep[1], "weft verify: failed")
  expect_match(rep[2], "^  lints      ")
  expect_match(rep[3], "^  decisions ")
  expect_match(rep[4], "^  render     ")
  expect_match(rep[5], "^  ledger     ")
  expect_identical(rep[length(rep)], "weft verify: T s")
  expect_lt(which(startsWith(rep, "  ledger")), which(startsWith(rep, "Knit-time failures")))
  expect_lt(which(startsWith(rep, "Knit-time failures")), length(rep))
})

# ---- nothing is written outside the project (G3) ------------------------------------------------------

test_that("4c G3: a full verify() with a render writes nothing outside the project", {
  v4_env()
  fq <- v4_fake_quarto(body = c(v4_sh_stamp("a.qmd"), v4_sh_freeze("a")), observe = c("a", "b"))
  p <- fk_proj(git = TRUE, sub = TRUE)
  v4_plant_freeze(p$root)
  outside <- v4_outside_snap(p$top, p$root)
  git <- g_git_snapshot(p$top)
  r <- v4_verify(p$root)
  expect_verify_passed(r)
  expect_identical(v4_outside_snap(p$top, p$root), outside)
  expect_identical(g_git_snapshot(p$top), git)
})

# ---- G30: the run id ---------------------------------------------------------------------------------

# Stage 6 ruling 17: every reader takes `.weft/run` first and WEFT_RUN only
# when no file holds a run, so the stamp and the published block agree.
test_that("4c G30: run_id() returns what .weft/run holds, else WEFT_RUN", {
  root <- lint_proj(list(".weft/run" = "run-from-file"), weft_yml = "draft: false")
  withr::local_envvar(WEFT_RUN = NA)
  expect_identical(trimws(weft:::run_id(root)), "run-from-file")
  withr::local_envvar(WEFT_RUN = "verify-20260101000000-1")
  expect_identical(trimws(weft:::run_id(root)), "run-from-file")
  bare <- lint_proj(list(), weft_yml = "draft: false")
  expect_identical(trimws(weft:::run_id(bare)), "verify-20260101000000-1")
})

# ---- real Quarto: a passing project (shared render) ---------------------------------------------------

test_that("4c G25: a real render of two passing documents passes, and the totals line is there", {
  fx <- v4_real_pass()
  r <- fx$r
  expect_identical(fx$first$status, 0L, info = fx$first$log)
  expect_verify_passed(r)
  expect_identical(v4_status(r$value, "lints"), "ran")
  expect_identical(v4_status(r$value, "render"), "ran")
  expect_identical(NROW(r$value$knit), 0L)
  expect_identical(length(r$value$unexecuted), 0L)
  expect_identical(NROW(r$value$stale), 0L)
  expect_identical(r$report[length(r$report)], "weft verify: T s")
  expect_false(any(vapply(c("Knit-time failures", "Not executed in this render", "Ledger: entries not re-rendered",
                            "Construct errors"), function(s) v4_has_section(r$report, s), NA)))
})

test_that("4c G25: every document is executed again although its results are frozen", {
  fx <- v4_real_pass()
  expect_identical(fx$ran_before, c(a = 1L, b = 1L))
  expect_identical(fx$ran, c(a = 2L, b = 2L))
})

test_that("4c G25, 8.3.2: after a pass the backup is gone and _freeze holds the verified results", {
  fx <- v4_real_pass()
  root <- fx$q$root
  expect_verify_passed(fx$r)
  expect_false(dir.exists(v4_backup_dir(root)))
  expect_true(all(file.exists(file.path(root, "_freeze", c("a", "b"), "execute-results", "html.json"))))
  # G25 step 4: a pass deletes the backup and keeps the fresh _freeze; only the execute-results entries are promised
  er <- function(s) sort(grep("/execute-results/", names(s), fixed = TRUE, value = TRUE))
  expect_identical(er(fx$freeze_after), er(fx$freeze_before))
})

test_that("4c G25, G30: the stamps carry the run id verify() made, the same for both documents, and not the earlier render's", {
  fx <- v4_real_pass()
  expect_identical(fx$stamps_before$a$run, "run-first")        # the pre-render script used WEFT_RUN (G30)
  expect_identical(fx$stamps_before$b$run, "run-first")
  expect_match(fx$stamps$a$run, V4_RUN_RE)
  expect_match(fx$stamps$a$run, sprintf("-%d$", fx$pid))
  expect_identical(fx$stamps$a$run, fx$stamps$b$run)
  expect_length(fx$stamps$a$failures, 0L)
})

test_that("4c G3: a real verify() writes nothing outside the project", {
  fx <- v4_real_pass()
  expect_verify_passed(fx$r)
  expect_identical(fx$outside_after, fx$outside_before)
})

# ---- real Quarto: a failing project (shared render) ---------------------------------------------------

test_that("4c G26: a failed claim, a missing value and a warned check: the first two fail, the warned check does not", {
  fx <- v4_real_fail()
  r <- fx$r
  expect_verify_failed(r)
  x <- r$res
  expect_identical(v4_status(x, "render"), "failed")
  expect_identical(NROW(x$knit), 2L)
  expect_true(v4_has_section(r$report, "Knit-time failures"))
  sec <- v4_section(r$report, "Knit-time failures")
  expect_true(any(grepl("b.qmd", sec, fixed = TRUE)))
  expect_false(any(grepl("a.qmd", sec, fixed = TRUE)))
  expect_true(any(grepl(". > 100 was FALSE (value 12.5)", sec, fixed = TRUE)))
  expect_true(any(grepl(as.character(v4_line_of(fx$bad, "Depth is")), sec, fixed = TRUE)))   # the claim's line
  expect_true(any(grepl(as.character(v4_line_of(fx$bad, "Missing")), sec, fixed = TRUE)))    # the missing value's line
  # the warned check is neither a failure nor listed as one
  expect_false(any(grepl("level = \"warn\"", sec, fixed = TRUE)))
  expect_false(v4_has_section(r$report, "Not executed in this render"))
})

test_that("4c G26, G25: the failing document's stamp is of this run; the clean one has none to fail", {
  fx <- v4_real_fail()
  expect_match(fx$stamps$b$run, V4_RUN_RE)
  expect_identical(fx$stamps$a$run, fx$stamps$b$run)
  expect_length(fx$stamps$b$failures, 2L)
  expect_length(fx$stamps$a$failures, 0L)
})

test_that("4c G25: both documents were executed again in the failing run, once each", {
  fx <- v4_real_fail()
  expect_identical(fx$ran_before, c(a = 1L, b = 1L))
  expect_identical(fx$ran, c(a = 2L, b = 2L))
})

test_that("4c G3: a failing real verify() writes nothing outside the project", {
  fx <- v4_real_fail()
  expect_s3_class(fx$r$err, "weft_verify_error")
  expect_identical(fx$outside_after, fx$outside_before)
})
