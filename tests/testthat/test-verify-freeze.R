# Package 4c: the freeze sequence of verify() under Quarto (dev/design-4.md G25 steps 1-4, G29, H22; PACKAGE-SCOPING
# 8.3.1; Q3; section 5 "test-verify-freeze.R"). The sequence is checked two ways: with a stand-in quarto that
# looks at `_freeze` and the backup while it runs (every path: pass, fail, error, killed, left by hand), and
# on real Quarto projects rendered once and shared (v4_real_fail(), v4_real_interrupted(), v4_real_files()).
# "Byte for byte" is a md5 of every file of `_freeze`, before and after. ASCII only. Invented content only.

fz_proj <- function(files = list("a.qmd" = V4_CONSTRUCT_DOC, "b.qmd" = V4_PLAIN_DOC), env = parent.frame(), ...) {
  v4_proj(files, quarto_yml = V4_QUARTO_YML, env = env, ...)
}

# the entries of `_freeze` for stems a and b, planted by hand, then returned as a snapshot
fz_planted <- function(root, stems = c("a", "b")) {
  v4_plant_freeze(root, stems)
  v4_freeze_snap(root)
}

expect_verify_passed_fz <- function(r) {
  expect_null(r$err, label = if (!is.null(r$err)) conditionMessage(r$err) else "no error")
  expect_true(r$value$ok)
}

# ---- the sequence, with a stand-in quarto -------------------------------------------------------------

test_that("4c G25: while quarto runs the entries of the verified documents are in the backup, with a manifest, and not in _freeze", {
  v4_env()
  fq <- v4_fake_quarto(observe = c("a", "b", "chapters/c"),
                       body = c(v4_sh_stamp("a.qmd"), v4_sh_freeze("a"), v4_sh_freeze("b")))
  p <- fz_proj(list("a.qmd" = V4_CONSTRUCT_DOC, "b.qmd" = V4_PLAIN_DOC, "chapters/c.qmd" = V4_PLAIN_DOC,
                    "d.qmd" = V4_PLAIN_DOC), git = TRUE)
  v4_plant_freeze(p$root, c("a", "b", "chapters/c"))
  r <- v4_verify(p$root)
  expect_null(r$err, label = if (!is.null(r$err)) conditionMessage(r$err) else "")
  # what the render saw
  expect_identical(v4_log(fq, "seen"), c("a absent", "b absent", "chapters/c absent"))
  manifest <- v4_log(fq, "manifest")
  expect_true(all(c("a", "b", "chapters/c") %in% manifest), label = paste(manifest, collapse = ","))
  # a stem is the document's path relative to the root, extension dropped (G25.2)
  expect_false(any(grepl("\\.qmd$", manifest)))
  expect_true("d" %in% manifest)       # a verified document with no entry is listed too: "each verified document"
  backup <- v4_log(fq, "backup")
  expect_true(any(grepl("a/execute-results/html.json", backup, fixed = TRUE)))
  expect_true(any(grepl("b/execute-results/html.json", backup, fixed = TRUE)))
  expect_true(any(grepl("chapters/c/execute-results/html.json", backup, fixed = TRUE)))
})

test_that("4c G25.4: when the render exits 0 the backup is deleted and the new entries stay; the old ones are not put back", {
  v4_env()
  fq <- v4_fake_quarto(body = c(v4_sh_stamp("a.qmd"), v4_sh_freeze("a", "NEW"), v4_sh_freeze("b", "NEW")))
  p <- fz_proj(git = TRUE)
  fz_planted(p$root)
  r <- v4_verify(p$root)
  expect_verify_passed_fz(r)
  expect_false(dir.exists(v4_backup_dir(p$root)))
  expect_identical(readLines(file.path(p$root, "_freeze/a/execute-results/html.json")), "NEW")
  expect_identical(readLines(file.path(p$root, "_freeze/b/execute-results/html.json")), "NEW")
})

test_that("4c G25.4: an entry the render did not rewrite is not resurrected from the backup after a pass", {
  v4_env()
  fq <- v4_fake_quarto(body = c(v4_sh_stamp("a.qmd"), v4_sh_freeze("a", "NEW")))   # writes a, not b
  p <- fz_proj(git = TRUE)
  fz_planted(p$root)
  r <- v4_verify(p$root)
  expect_verify_passed_fz(r)
  expect_false(dir.exists(v4_backup_dir(p$root)))
  expect_true(file.exists(file.path(p$root, "_freeze/a/execute-results/html.json")))
  expect_false(dir.exists(file.path(p$root, "_freeze", "b")))
})

test_that("4c G25.4: when the render exits non-zero, _freeze is restored byte for byte, half-written entries gone", {
  v4_env()
  fq <- v4_fake_quarto(body = c(v4_sh_freeze("a", "HALF"), "echo junk > _freeze/a/partial.txt", v4_sh_freeze("b", "HALF")),
                       status = 1L)
  p <- fz_proj(git = TRUE)
  before <- fz_planted(p$root)
  expect_gt(length(before), 0L)
  r <- v4_verify(p$root)
  expect_false(is.null(r$err))
  expect_s3_class(r$err, "weft_verify_error")
  expect_identical(v4_freeze_snap(p$root), before)
  expect_false(dir.exists(v4_backup_dir(p$root)))
})

test_that("4c G25: with no _freeze folder there is no backup, and the render runs all the same", {
  v4_env()
  fq <- v4_fake_quarto(body = v4_sh_stamp("a.qmd"), observe = "a")
  p <- fz_proj(git = TRUE)
  expect_false(dir.exists(file.path(p$root, "_freeze")))
  r <- v4_verify(p$root)
  expect_verify_passed_fz(r)
  expect_length(v4_log(fq, "calls"), 1L)
  expect_length(v4_log(fq, "backup"), 0L)
  expect_false(dir.exists(v4_backup_dir(p$root)))
  expect_false(dir.exists(file.path(p$root, "_freeze")))
})

test_that("4c G25: a backup left by an interrupted run is restored first, before the new backup is made", {
  v4_env()
  fq <- v4_fake_quarto(observe = c("a", "b"), status = 1L)
  p <- fz_proj(git = TRUE)
  before <- fz_planted(p$root)
  # the interrupted run: both entries in the backup, a manifest, and a half-written entry in _freeze
  bk <- v4_backup_dir(p$root)
  dir.create(bk, recursive = TRUE)
  writeLines(c("a", "b"), file.path(bk, "manifest"))
  for (s in c("a", "b")) file.rename(file.path(p$root, "_freeze", s), file.path(bk, s))
  f3_write(file.path(p$root, "_freeze", "a", "partial.txt"), "half a render")
  expect_false(identical(v4_freeze_snap(p$root), before))
  r <- v4_verify(p$root)
  expect_false(is.null(r$err))                              # the render fails (exit 1) ...
  expect_identical(v4_freeze_snap(p$root), before)          # ... and the entries are the original ones again
  expect_false(dir.exists(bk))
  # this run's own backup held the restored entries, not an empty folder
  expect_identical(v4_log(fq, "seen"), c("a absent", "b absent"))
  expect_true(any(grepl("a/execute-results/html.json", v4_log(fq, "backup"), fixed = TRUE)))
})

test_that("4c G25: a backup left by an interrupted run is restored, and a pass then keeps the new results", {
  v4_env()
  fq <- v4_fake_quarto(body = c(v4_sh_stamp("a.qmd"), v4_sh_freeze("a", "NEW")), observe = "b")
  p <- fz_proj(git = TRUE)
  before <- fz_planted(p$root)
  bk <- v4_backup_dir(p$root)
  dir.create(bk, recursive = TRUE)
  writeLines(c("a", "b"), file.path(bk, "manifest"))
  for (s in c("a", "b")) file.rename(file.path(p$root, "_freeze", s), file.path(bk, s))
  r <- v4_verify(p$root)
  expect_verify_passed_fz(r)
  expect_false(dir.exists(bk))
  expect_identical(readLines(file.path(p$root, "_freeze/a/execute-results/html.json")), "NEW")
})

test_that("4c G25: a run killed while quarto runs leaves the backup, and the next run restores it first", {
  skip_on_cran()
  skip_on_os("windows")
  v4_env(libs = TRUE)
  fq <- v4_fake_quarto(body = c("echo $$ > \"$LOG/wrapper.pid\"", "exec sleep 120"))
  p <- fz_proj(git = TRUE)
  before <- fz_planted(p$root)
  # start a separate R running verify(); wait for the backup to exist; kill the process with SIGKILL
  pidfile <- file.path(fq$log, "r.pid")
  rlog <- file.path(fq$log, "r.log")
  expr <- sprintf("cat(Sys.getpid(), file = '%s'); weft::verify()", pidfile)   # R says its own pid
  cmd <- sprintf("(cd %s && exec %s -e %s) > %s 2>&1 &", shQuote(p$root),
                 shQuote(file.path(R.home("bin"), "Rscript")), shQuote(expr), shQuote(rlog))
  system2("sh", c("-c", shQuote(cmd)))
  alive <- function(pid) identical(suppressWarnings(system2("kill", c("-0", pid), stdout = FALSE, stderr = FALSE)), 0L)
  for (i in seq_len(300)) {
    if (file.exists(pidfile) && file.exists(file.path(fq$log, "wrapper.pid"))) break
    if (file.exists(pidfile) && !alive(trimws(readLines(pidfile, warn = FALSE)[1]))) break
    Sys.sleep(0.2)
  }
  rpid <- if (file.exists(pidfile)) trimws(readLines(pidfile, warn = FALSE)[1]) else NA_character_
  wpid <- if (file.exists(file.path(fq$log, "wrapper.pid"))) trimws(readLines(file.path(fq$log, "wrapper.pid"))[1]) else NA_character_
  withr::defer(for (id in c(rpid, wpid)) if (!is.na(id)) try(tools::pskill(as.integer(id), 9L), silent = TRUE))
  expect_false(is.na(wpid), label = paste("quarto was reached; the child said:", paste(readLines(rlog, warn = FALSE), collapse = " | ")))
  if (!is.na(wpid)) {
    tools::pskill(as.integer(rpid), 9L)           # killed: no on.exit runs
    tools::pskill(as.integer(wpid), 9L)
    Sys.sleep(0.5)
    expect_true(file.exists(file.path(v4_backup_dir(p$root), "manifest")))
    expect_false(dir.exists(file.path(p$root, "_freeze", "a")))
    # the next run restores first (this one fails its render, so what is left is what step 1 put back)
    fq2 <- v4_fake_quarto(status = 1L)
    r <- v4_verify(p$root)
    expect_false(is.null(r$err))
    expect_identical(v4_freeze_snap(p$root), before)
    expect_false(dir.exists(v4_backup_dir(p$root)))
  }
})

test_that("4c G29: verify(files =) backs up only the named documents' entries and leaves the others alone", {
  v4_env()
  fq <- v4_fake_quarto(observe = c("a", "b"), body = c(v4_sh_stamp("a.qmd"), v4_sh_freeze("a", "NEW")))
  p <- fz_proj(list("a.qmd" = V4_CONSTRUCT_DOC, "b.qmd" = V4_CONSTRUCT_DOC), git = TRUE)
  before <- fz_planted(p$root)
  r <- v4_verify(p$root, files = "a.qmd")
  expect_verify_passed_fz(r)
  expect_identical(v4_log(fq, "seen"), c("a absent", "b present"))
  expect_identical(v4_log(fq, "manifest"), "a")
  expect_false(any(grepl("^\\./b/", v4_log(fq, "backup"))))
  after <- v4_freeze_snap(p$root)
  expect_identical(v4_snap_of(after, "b"), v4_snap_of(before, "b"))       # byte for byte
  expect_identical(readLines(file.path(p$root, "_freeze/a/execute-results/html.json")), "NEW")
})

test_that("4c G29: a failed render with files restores the named entries and leaves the others as they were", {
  v4_env()
  fq <- v4_fake_quarto(body = v4_sh_freeze("a", "HALF"), status = 1L)
  p <- fz_proj(list("a.qmd" = V4_CONSTRUCT_DOC, "b.qmd" = V4_CONSTRUCT_DOC), git = TRUE)
  before <- fz_planted(p$root)
  r <- v4_verify(p$root, files = "a.qmd")
  expect_false(is.null(r$err))
  expect_s3_class(r$err, "weft_verify_error")
  expect_identical(v4_freeze_snap(p$root), before)
})

test_that("4c G25: two verify() runs in a row each end with no backup", {
  v4_env()
  fq <- v4_fake_quarto(body = c(v4_sh_stamp("a.qmd"), v4_sh_freeze("a", "NEW")))
  p <- fz_proj(git = TRUE)
  fz_planted(p$root)
  for (i in 1:2) {
    expect_verify_passed_fz(v4_verify(p$root))
    expect_false(dir.exists(v4_backup_dir(p$root)))
  }
  expect_length(v4_log(fq, "calls"), 2L)
})

# ---- the sequence on real Quarto (shared renders) -----------------------------------------------------

test_that("4c G25.4, Q3: a real render that fails leaves _freeze as it was, byte for byte, and no backup", {
  fx <- v4_real_fail()
  expect_gt(length(fx$freeze_before), 0L)
  expect_true(any(startsWith(names(fx$freeze_before), "a/")) && any(startsWith(names(fx$freeze_before), "b/")))
  expect_s3_class(fx$r$err, "weft_verify_error")
  expect_identical(fx$freeze_after, fx$freeze_before)
  expect_false(fx$backup_exists)
})

test_that("4c G25.1, Q3: a backup left by hand, with a half-written entry, is restored first: _freeze ends as the original", {
  fx <- v4_real_interrupted()
  expect_s3_class(fx$r$err, "weft_verify_error")      # b still fails its claim
  expect_identical(fx$freeze_after, fx$freeze_before)
  expect_false("a/partial.txt" %in% names(fx$freeze_after))
  expect_false(fx$backup_exists)
  # and both documents were executed again by that run
  expect_identical(unname(fx$ran - fx$ran_before), c(1L, 1L))
})

test_that("4c G29: verify(files = 'a.qmd') in a frozen project passes though b, not named, fails its claim", {
  fx <- v4_real_files()
  expect_null(fx$r$err, label = if (!is.null(fx$r$err)) conditionMessage(fx$r$err) else "")
  expect_true(fx$r$value$ok)
  expect_identical(NROW(fx$r$value$knit), 0L)
  expect_identical(length(fx$r$value$unexecuted), 0L)
})

test_that("4c G29: and only a was executed, b's frozen entries are untouched byte for byte, no backup is left", {
  fx <- v4_real_files()
  expect_identical(unname(fx$ran - fx$ran_before), c(1L, 0L))
  expect_identical(v4_snap_of(fx$freeze_after, "b"), v4_snap_of(fx$freeze_before, "b"))
  expect_false(fx$backup_exists)
  expect_true(any(startsWith(names(fx$freeze_after), "a/")))
})
