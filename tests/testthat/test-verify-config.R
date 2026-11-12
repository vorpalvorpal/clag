# Package 4c: the settings strict, verify_skip and weft_version (dev/design-4.md G31), the skipped parts
# the report names (G24, G28, 8.1.4), and the version warning (G32, H28, H37; 9.5.4). Section 5
# "test-verify-config.R". No render happens in this file except through a stand-in quarto. ASCII only.

# the weft_config_error from reading a project's configuration with `yml` lines
vc_err <- function(yml, front = list()) {
  withr::local_envvar(WEFT_DRAFT = NA)
  dir <- f2_proj(yml)
  f2_cond(weft:::read_config(dir, front = front))
}
vc_cfg <- function(yml, front = list(), env = parent.frame()) {
  withr::local_envvar(WEFT_DRAFT = NA, .local_envir = env)
  weft:::read_config(f2_proj(yml, env = env), front = front)
}

# ---- G31: the defaults and what is accepted ---------------------------------------------------------

test_that("4c G31: default_config() holds strict, verify_skip and weft_version, empty", {
  d <- weft:::default_config()
  expect_true(all(c("strict", "verify_skip", "weft_version") %in% names(d)))
  expect_length(d$strict, 0L)
  expect_length(d$verify_skip, 0L)
  expect_null(d$weft_version)
})

test_that("4c G31: a project with none of them reads the defaults", {
  x <- vc_cfg("draft: false")
  expect_true(all(c("strict", "verify_skip", "weft_version") %in% names(x)))
  expect_length(x$strict, 0L)
  expect_length(x$verify_skip, 0L)
  expect_null(x$weft_version)
})

test_that("4c G31: valid values are read as written", {
  expect_no_warning(x <- vc_cfg(c("strict: [numeral, xref]", "verify_skip: [render, ledger]", "weft_version: 0.1.0")))
  expect_identical(as.character(unlist(x$strict)), c("numeral", "xref"))
  expect_identical(as.character(unlist(x$verify_skip)), c("render", "ledger"))
  expect_identical(as.character(x$weft_version), "0.1.0")
  expect_no_warning(y <- vc_cfg(c("strict:", "  - numeral", "verify_skip:", "  - lints", "  - decisions", "weft_version: \"0.2.0\"")))
  expect_identical(as.character(unlist(y$strict)), "numeral")
  expect_identical(as.character(unlist(y$verify_skip)), c("lints", "decisions"))
  expect_identical(as.character(y$weft_version), "0.2.0")
  expect_no_warning(z <- vc_cfg(c("strict: []", "verify_skip: []", "weft_version: null")))
  expect_length(z$strict, 0L)
  expect_length(z$verify_skip, 0L)
  expect_null(z$weft_version)
  # every tier-1 rule can be strict, no tier-2 rule can
  t1 <- lint_rules()$id[lint_rules()$tier == 1]
  expect_no_error(vc_cfg(paste0("strict: [", paste(t1, collapse = ", "), "]")))
})

test_that("4c G31: strict names tier-1 rule ids; an unknown id is a weft_config_error with a suggestion", {
  e <- vc_err("strict: [numerl]")
  f2_has_class(e, "weft_config_error")
  f2_msg_has(e, "`numerl` is not a weft rule; did you mean `numeral`?")
  e2 <- vc_err("strict: [numeral, zzzzzz]")
  f2_has_class(e2, "weft_config_error")
  f2_msg_has(e2, "`zzzzzz` is not a weft rule")
})

test_that("4c G31: a tier-2 id cannot be strict", {
  e <- vc_err("strict: [claim-word]")
  f2_has_class(e, "weft_config_error")
  f2_msg_has(e, "`claim-word` is tier 2 and blocks nothing, so it cannot be strict (rule 8.1.3).")
  for (id in lint_rules()$id[lint_rules()$tier == 2]) {
    e <- vc_err(sprintf("strict: [%s]", id))
    f2_has_class(e, "weft_config_error")
    f2_msg_has(e, sprintf("`%s` is tier 2", id))
  }
})

test_that("4c G31: strict that is not a list of ids is a weft_config_error", {
  for (v in c("strict: 5", "strict: true", "strict: {a: b}", "strict: [1, 2]", "strict: [[numeral]]")) {
    f2_has_class(vc_err(v), "weft_config_error")
  }
})

test_that("4c G31: verify_skip is a subset of lints, decisions, render, ledger; any other name is refused", {
  e <- vc_err("verify_skip: [render, ledgr]")
  f2_has_class(e, "weft_config_error")
  f2_msg_has(e, "ledgr")
  e <- vc_err("verify_skip: [static]")
  f2_has_class(e, "weft_config_error")
  f2_msg_has(e, "static")
  for (v in c("verify_skip: 3", "verify_skip: true", "verify_skip: {render: true}")) {
    f2_has_class(vc_err(v), "weft_config_error")
  }
  for (p in V4_PARTS) expect_no_error(vc_cfg(sprintf("verify_skip: [%s]", p)))
  expect_no_error(vc_cfg(sprintf("verify_skip: [%s]", paste(V4_PARTS, collapse = ", "))))
})

test_that("4c G31: weft_version is one string; a list is a weft_config_error", {
  for (v in c("weft_version: [0.1.0, 0.2.0]", "weft_version: {a: b}", "weft_version: [0.1.0]")) {
    f2_has_class(vc_err(v), "weft_config_error")
  }
})

test_that("4c G31: a bad setting stops verify() before any part runs, as a weft_config_error", {
  v4_env()
  fq <- v4_fake_quarto()
  for (yml in c("strict: [numerl]", "verify_skip: [ledgr]")) {
    p <- v4_proj(list("a.qmd" = V4_PLAIN_DOC), weft_yml = c("draft: false", yml))
    e <- tryCatch(suppressMessages(verify(path = p$root, static = TRUE)), error = function(e) e)
    f2_has_class(e, "weft_config_error")
  }
  expect_length(v4_log(fq, "calls"), 0L)
})

test_that("4c G31: verify_skip is a project setting (9.1.4): in front matter beside a _weft.yml it is a weft_config_error", {
  expect_true("verify_skip" %in% weft:::project_only_settings())
  for (v in list("render", c("lints", "ledger"), character())) {
    e <- vc_err("draft: false", front = list(verify_skip = v))
    f2_has_class(e, "weft_config_error")
    f2_msg_has(e, "verify_skip")
  }
})

test_that("4c G31: a single document with no _weft.yml may set verify_skip in its front matter", {
  expect_no_warning(x <- vc_cfg(NULL, front = list(verify_skip = "render")))
  expect_identical(as.character(unlist(x$verify_skip)), "render")
})

test_that("4c G31: a lone document that skips the lints in its own front matter passes verify() with them skipped", {
  v4_env()
  doc <- c("---", "title: T", "weft:", "  verify_skip: [lints]", "---", "", "A", F3_BAD_TWO, "here.")
  p <- v4_proj(list("a.qmd" = doc), weft_yml = NULL)
  r <- v4_verify(p$root, static = TRUE)
  expect_null(r$err, label = if (!is.null(r$err)) conditionMessage(r$err) else "")
  expect_identical(v4_status(r$value, "lints"), "skipped")
})

# ---- skipped parts are reported (G24, G28, 8.1.4) -----------------------------------------------------

test_that("4c G28: verify_skip lints: the part does not run and the report says why; nothing fails on its account", {
  v4_env()
  p <- v4_proj(list("a.qmd" = g_bad_doc()), weft_yml = c("draft: false", "verify_skip: [lints]"))
  r <- v4_verify(p$root, static = TRUE)
  expect_null(r$err)
  expect_identical(v4_status(r$value, "lints"), "skipped")
  expect_true(sprintf("  %-10s %s", "lints", "skipped: verify_skip in _weft.yml") %in% r$report)
  expect_identical(nrow(r$value$errors), 0L)
  expect_false(v4_has_section(r$report, "Construct errors"))
})

test_that("4c G28: verify_skip decisions: pointers are not read; a dict.yml with an unresolved pointer does not fail", {
  v4_env()
  files <- list("a.qmd" = V4_PLAIN_DOC, "decisions/12-core.md" = "x", "dict.yml" = DICT_PTR("12", "99"))
  yml <- c("draft: false", "decisions: \"decisions/{id}-*.md\"", "verify_skip: [decisions]")
  p <- v4_proj(files, git = TRUE, weft_yml = yml)
  r <- v4_verify(p$root, static = TRUE)
  expect_null(r$err)
  expect_identical(v4_status(r$value, "decisions"), "skipped")
  expect_true(sprintf("  %-10s %s", "decisions", "skipped: verify_skip in _weft.yml") %in% r$report)
  # the control: without the setting the same project fails
  q <- v4_proj(files, git = TRUE, weft_yml = yml[1:2])
  expect_false(is.null(v4_verify(q$root, static = TRUE)$err))
})

test_that("4c G28: verify_skip render: quarto is never called, and the report says why", {
  v4_env()
  fq <- v4_fake_quarto(observe = "a")
  p <- v4_proj(list("a.qmd" = V4_CONSTRUCT_DOC), git = TRUE, quarto_yml = V4_QUARTO_YML,
               weft_yml = c("draft: false", "verify_skip: [render]"))
  v4_plant_freeze(p$root, "a")
  before <- v4_freeze_snap(p$root)
  r <- v4_verify(p$root)
  expect_null(r$err, label = if (!is.null(r$err)) conditionMessage(r$err) else "")
  expect_identical(v4_status(r$value, "render"), "skipped")
  expect_true(sprintf("  %-10s %s", "render", "skipped: verify_skip in _weft.yml") %in% r$report)
  expect_length(v4_log(fq, "calls"), 0L)
  expect_identical(v4_freeze_snap(p$root), before)
  # with render skipped the document that holds a construct is not failed for being unexecuted
  expect_identical(length(r$value$unexecuted), 0L)
})

test_that("4c G28: verify_skip ledger: a stale ledger does not fail, and the report says why", {
  v4_env()
  fq <- v4_fake_quarto()
  p <- v4_proj(list("a.qmd" = V4_PLAIN_DOC), git = TRUE, quarto_yml = V4_QUARTO_YML,
               weft_yml = c("draft: false", "verify_skip: [ledger]"))
  v4_plant_stale_ledger(p$root, "a.qmd")
  r <- v4_verify(p$root)
  expect_null(r$err, label = if (!is.null(r$err)) conditionMessage(r$err) else "")
  expect_identical(v4_status(r$value, "ledger"), "skipped")
  expect_true(sprintf("  %-10s %s", "ledger", "skipped: verify_skip in _weft.yml") %in% r$report)
  expect_identical(v4_status(r$value, "render"), "ran")
})

test_that("4c G28: ledger: false in _weft.yml skips the ledger with its own reason and a note (G24.4)", {
  v4_env()
  fq <- v4_fake_quarto()
  p <- v4_proj(list("a.qmd" = V4_PLAIN_DOC), git = TRUE, quarto_yml = V4_QUARTO_YML,
               weft_yml = c("draft: false", "ledger: false"))
  v4_plant_stale_ledger(p$root, "a.qmd")
  r <- v4_verify(p$root)
  expect_null(r$err, label = if (!is.null(r$err)) conditionMessage(r$err) else "")
  expect_identical(v4_status(r$value, "ledger"), "skipped")
  expect_true(sprintf("  %-10s %s", "ledger", "skipped: ledger: false in _weft.yml") %in% r$report)
  expect_true(length(r$value$notes) >= 1L)
})

test_that("4c G28: all four parts switched off: nothing runs, every line says skipped, and the run passes", {
  v4_env()
  fq <- v4_fake_quarto()
  p <- v4_proj(list("a.qmd" = g_bad_doc()), quarto_yml = V4_QUARTO_YML,
               weft_yml = c("draft: false", "verify_skip: [lints, decisions, render, ledger]"))
  r <- v4_verify(p$root)
  expect_null(r$err)
  expect_identical(r$value$parts$status, rep("skipped", 4L))
  expect_identical(r$report[1], "weft verify: passed")
  for (part in V4_PARTS) {
    expect_true(sprintf("  %-10s %s", part, "skipped: verify_skip in _weft.yml") %in% r$report, label = part)
  }
  expect_length(v4_log(fq, "calls"), 0L)
})

test_that("4c G28: a skipped part reads skipped: <why>, a part that ran does not", {
  v4_env()
  p <- v4_proj(list("a.qmd" = V4_PLAIN_DOC), git = TRUE)
  r <- v4_verify(p$root, static = TRUE)
  expect_false(grepl("skipped", v4_part_line(r$report, "lints")))
  expect_match(v4_part_line(r$report, "render"), "^  render     skipped: static = TRUE$")
})

# ---- G32: the version record and its warning ----------------------------------------------------------

version_warnings <- function(r) Filter(function(w) inherits(w, "weft_version_warning"), r$warnings)

test_that("4c G32: a recorded version that is not the installed one gives one warning, with the design's text", {
  v4_env()
  rec <- v4_other_version()
  p <- v4_proj(list("a.qmd" = V4_PLAIN_DOC), git = TRUE, weft_yml = c("draft: false", paste0("weft_version: ", rec)))
  r <- v4_verify(p$root, static = TRUE)
  w <- version_warnings(r)
  expect_length(w, 1L)
  expect_length(r$warnings, 1L)
  expect_s3_class(w[[1]], "weft_warning")
  expect_identical(cli::ansi_strip(conditionMessage(w[[1]])), v4_version_msg(rec))
  # a warning does not stop the run: verify() still passes and returns its result
  expect_null(r$err)
  expect_s3_class(r$value, "weft_verify")
  expect_true(r$value$ok)
})

test_that("4c G32: the text names the recorded and the installed version, quoted or not in the file", {
  v4_env()
  rec <- v4_other_version()
  p <- v4_proj(list("a.qmd" = V4_PLAIN_DOC), weft_yml = c("draft: false", sprintf("weft_version: \"%s\"", rec)))
  w <- version_warnings(v4_verify(p$root, static = TRUE))
  expect_length(w, 1L)
  expect_match(conditionMessage(w[[1]]), sprintf("This project records weft %s in _weft.yml,", rec), fixed = TRUE)
  expect_match(conditionMessage(w[[1]]), sprintf("and weft %s is installed.", v4_version()), fixed = TRUE)
  expect_match(conditionMessage(w[[1]]), "Run weft::use_weft() to update the files weft installed and the record (rule 9.5.4).",
               fixed = TRUE)
})

test_that("4c G32, H28: a newer record than the installed version warns too: any difference", {
  v4_env()
  p <- v4_proj(list("a.qmd" = V4_PLAIN_DOC), weft_yml = c("draft: false", "weft_version: 99.0.0"))
  w <- version_warnings(v4_verify(p$root, static = TRUE))
  expect_length(w, 1L)
  expect_identical(cli::ansi_strip(conditionMessage(w[[1]])), v4_version_msg("99.0.0"))
})

test_that("4c G32: a record equal to the installed version, and no record, give no warning", {
  v4_env()
  for (yml in list(c("draft: false", paste0("weft_version: ", v4_version())), "draft: false",
                   c("draft: false", "weft_version: null"))) {
    p <- v4_proj(list("a.qmd" = V4_PLAIN_DOC), weft_yml = yml)
    r <- v4_verify(p$root, static = TRUE)
    expect_null(r$err, label = if (!is.null(r$err)) conditionMessage(r$err) else "")
    expect_length(r$warnings, 0L)
  }
  # no _weft.yml at all
  n <- v4_proj(list("a.qmd" = V4_PLAIN_DOC), weft_yml = NULL)
  r <- v4_verify(n$root, static = TRUE)
  expect_null(r$err)
  expect_length(r$warnings, 0L)
})

test_that("4c G32: the warning is one even when the run fails, and it comes from the version alone", {
  v4_env()
  p <- v4_proj(list("a.qmd" = g_bad_doc()), weft_yml = c("draft: false", paste0("weft_version: ", v4_other_version())))
  r <- v4_verify(p$root, static = TRUE)
  expect_s3_class(r$err, "weft_verify_error")
  expect_length(version_warnings(r), 1L)
})

test_that("4c G32: draft mode is refused before the version is checked: the refusal, and no warning", {
  v4_env(extra = c(WEFT_DRAFT = "1"))
  p <- v4_proj(list("a.qmd" = V4_PLAIN_DOC), weft_yml = c("draft: false", paste0("weft_version: ", v4_other_version())))
  r <- v4_verify(p$root, static = TRUE)
  expect_s3_class(r$err, "weft_verify_error")
  expect_match(conditionMessage(r$err), "does not run in draft mode", fixed = TRUE)
  expect_length(r$warnings, 0L)
})

test_that("4c G32: the record is read from _weft.yml as text, so a version that is also a number keeps its spelling", {
  v4_env()
  # 1.10 is a number to YAML (1.1) and a different version from 1.1
  p <- v4_proj(list("a.qmd" = V4_PLAIN_DOC), weft_yml = c("draft: false", "weft_version: 1.10"))
  w <- version_warnings(v4_verify(p$root, static = TRUE))
  expect_length(w, 1L)
  expect_match(conditionMessage(w[[1]]), "records weft 1.10 in _weft.yml", fixed = TRUE)
})

test_that("4c G32: use_setup() writes the version when it creates _weft.yml, and verify() has nothing to warn about", {
  v4_env()
  dir <- u4_dir(list("a.qmd" = V4_PLAIN_DOC))
  u4_use(dir)
  expect_identical(weft:::recorded_version(dir), v4_version())
  r <- v4_verify(dir, static = TRUE)
  expect_null(r$err, label = if (!is.null(r$err)) conditionMessage(r$err) else "")
  expect_length(r$warnings, 0L)
})

test_that("4c G32, H37: use_quarto() writes a _weft.yml with no version, so a project it set up never warns", {
  v4_env()
  dir <- u4_dir(list(`_quarto.yml` = U4_QUARTO_YML, "a.qmd" = V4_PLAIN_DOC))
  suppressMessages(utils::capture.output(weft::use_quarto(dir)))
  expect_true(is.na(weft:::recorded_version(dir)))
  r <- v4_verify(dir, static = TRUE)
  expect_null(r$err, label = if (!is.null(r$err)) conditionMessage(r$err) else "")
  expect_length(r$warnings, 0L)
})

test_that("4c G32: use_weft() updates an existing version line in place, and the warning stops", {
  skip_if_not("use_weft" %in% getNamespaceExports("weft"), "use_weft() is not built yet (package 4b)")
  v4_env()
  p <- v4_proj(list(`_quarto.yml` = U4_QUARTO_YML, "a.qmd" = V4_PLAIN_DOC),
               weft_yml = c("digits: 2", paste0("weft_version: ", v4_other_version()), "serial_comma: true"))
  expect_length(version_warnings(v4_verify(p$root, static = TRUE)), 1L)
  withr::local_options(rlang_interactive = FALSE)
  suppressMessages(utils::capture.output(weft::use_weft(p$root)))
  expect_identical(weft:::recorded_version(p$root), v4_version())
  yml <- readLines(file.path(p$root, "_weft.yml"))
  expect_identical(yml[c(1, 3)], c("digits: 2", "serial_comma: true"))
  expect_length(version_warnings(v4_verify(p$root, static = TRUE)), 0L)
})
