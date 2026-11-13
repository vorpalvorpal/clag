# Regression tests for the stage 4 review (dev/review-4.md, its findings 1 to 17 and the design questions
# 1, 3, 5 and 7, as ruled at the end of that file). Titles: `review-4 #<n>` for a finding, `review-4 Q<n>` for a
# design question. Findings 9 (cache identity) and the design questions 2, 4 and 6 have no test here: see
# the notes at the end.
#
# Built on helper-4a.R (temporary repositories, g_gate), helper-4b.R (installers, the hook, status) and
# helper-4c.R (v4_proj, v4_verify, v4_fake_quarto). The stand-in quarto answers `quarto inspect` (the render
# list, ruling 6) and logs one line per render call in `renders`. Nothing runs against a real repository.
#
# READINGS ASSUMED (the review and the rulings leave them open):
#   - #1, #2: the entries that are moved are the stem's files under _freeze/<stem>/ other than a child
#     document's own folder; while quarto runs `_freeze/chapters/execute-results` is not there and
#     `_freeze/chapters/c` is;
#   - #4, #5: the stand-in logs `render <file>` per call; with no `_quarto.yml` the call is `render a.qmd`;
#   - #6: the line is in the printed report and holds "not in the render list" and the file's name (on the
#     same line or within the next three);
#   - #10: the error says what was undone (one of "undone", "undid", "put back", "removed", "restored", "rolled
#     back") and does not say "Nothing was written.";
#   - #11: the hook that is not executable is `outdated` with "not executable" in the detail;
#   - #13: the project path reaches the workflow's run step through an `env:` entry of that step;
#   - #15: an R_PROFILE_USER that is set makes the .Rprofile route `off`, or says so in a message or warning;
#   - Q3: the manifest has a `run: <id>` line; the note holds "newer", "kept", "keeps" or "current";
#   - Q5: the report says the project's `_weft.yml` is a baseline (the word "baseline").

# ---- shared pieces ------------------------------------------------------------------------------------------

r4_nested <- function(env = parent.frame()) {
  v4_proj(list("chapters.qmd" = V4_PLAIN_DOC, "chapters/c.qmd" = V4_PLAIN_DOC, "d.qmd" = V4_PLAIN_DOC),
          git = TRUE, quarto_yml = V4_QUARTO_YML, env = env)
}
# entries for the stems chapters (with a file of its own beside execute-results), chapters/c and d
r4_plant_nested <- function(root) {
  v4_plant_freeze(root, c("chapters", "chapters/c", "d"))
  f3_write(file.path(root, "_freeze", "chapters", "figure-html", "p.png"), "PNG of the parent")
  f3_write(file.path(root, "_freeze", "chapters", "c", "figure-html", "q.png"), "PNG of the child")
  v4_freeze_snap(root)
}
r4_pair <- function(env = parent.frame()) {
  v4_proj(list("a.qmd" = V4_PLAIN_DOC, "b.qmd" = V4_PLAIN_DOC), git = TRUE, quarto_yml = V4_QUARTO_YML, env = env)
}
r4_failed <- function(r) {
  expect_s3_class(r$err, "weft_verify_error")
}
r4_text <- function(path) paste(readLines(path, warn = FALSE), collapse = "\n")
r4_entry <- function(root, stem) r4_text(file.path(root, "_freeze", stem, "execute-results", "html.json"))

# ---- #1, #2: the freeze of nested stems ---------------------------------------------------------------------

test_that("review-4 #1: verify(files = parent) leaves the child document's frozen results as they were after a pass", {
  v4_env()
  fq <- v4_fake_quarto(observe = c("chapters/c", "chapters/execute-results"),
                       body = v4_sh_freeze("chapters", "NEW"))
  p <- r4_nested()
  before <- r4_plant_nested(p$root)
  r <- v4_verify(p$root, files = "chapters.qmd")
  expect_null(r$err, label = if (!is.null(r$err)) conditionMessage(r$err) else "")
  expect_true(r$value$ok)
  # the render saw the child's entry where it was, and the parent's own entry gone
  expect_identical(v4_log(fq, "seen"), c("chapters/c present", "chapters/execute-results absent"))
  after <- v4_freeze_snap(p$root)
  expect_identical(v4_snap_of(after, "chapters/c"), v4_snap_of(before, "chapters/c"))
  expect_identical(after[startsWith(names(after), "d/")], before[startsWith(names(before), "d/")])
  expect_identical(r4_entry(p$root, "chapters"), "NEW")
  expect_false(dir.exists(v4_backup_dir(p$root)))
})

test_that("review-4 #1: verify(files = child) leaves the parent's entries as they were (neighbour guard)", {
  v4_env()
  fq <- v4_fake_quarto(body = v4_sh_freeze("chapters/c", "NEW"))
  p <- r4_nested()
  before <- r4_plant_nested(p$root)
  r <- v4_verify(p$root, files = "chapters/c.qmd")
  expect_null(r$err, label = if (!is.null(r$err)) conditionMessage(r$err) else "")
  after <- v4_freeze_snap(p$root)
  own <- function(s) s[startsWith(names(s), "chapters/") & !startsWith(names(s), "chapters/c/")]
  expect_identical(own(after), own(before))
  expect_identical(r4_entry(p$root, "chapters/c"), "NEW")
})

test_that("review-4 #1: after a failing render of the parent every entry, the child's too, is byte for byte as before", {
  v4_env()
  fq <- v4_fake_quarto(body = c(v4_sh_freeze("chapters", "HALF"), "echo junk > _freeze/chapters/partial.txt"),
                       status = 1L)
  p <- r4_nested()
  before <- r4_plant_nested(p$root)
  r <- v4_verify(p$root, files = "chapters.qmd")
  r4_failed(r)
  expect_identical(v4_freeze_snap(p$root), before)
  expect_false(dir.exists(v4_backup_dir(p$root)))
})

test_that("review-4 #2: files naming the child before the parent, with a failing render, leave both as before", {
  v4_env()
  fq <- v4_fake_quarto(body = c(v4_sh_freeze("chapters", "HALF"), v4_sh_freeze("chapters/c", "HALF")), status = 1L)
  p <- r4_nested()
  before <- r4_plant_nested(p$root)
  r <- v4_verify(p$root, files = c("chapters/c.qmd", "chapters.qmd"))
  r4_failed(r)
  after <- v4_freeze_snap(p$root)
  expect_identical(after, before)
  expect_true(file.exists(file.path(p$root, "_freeze", "chapters", "execute-results", "html.json")))
  expect_true(file.exists(file.path(p$root, "_freeze", "chapters", "c", "execute-results", "html.json")))
})

test_that("review-4 #2: files naming the parent before the child, with a failing render, leave both as before", {
  v4_env()
  fq <- v4_fake_quarto(body = c(v4_sh_freeze("chapters", "HALF"), v4_sh_freeze("chapters/c", "HALF")), status = 1L)
  p <- r4_nested()
  before <- r4_plant_nested(p$root)
  r <- v4_verify(p$root, files = c("chapters.qmd", "chapters/c.qmd"))
  r4_failed(r)
  expect_identical(v4_freeze_snap(p$root), before)
})

test_that("review-4 #2: a pass over parent and child, in either order, keeps both new entries and the other stems", {
  for (files in list(c("chapters/c.qmd", "chapters.qmd"), c("chapters.qmd", "chapters/c.qmd"))) {
    v4_env()
    fq <- v4_fake_quarto(body = c(v4_sh_freeze("chapters", "NEW"), v4_sh_freeze("chapters/c", "NEW")))
    p <- r4_nested()
    before <- r4_plant_nested(p$root)
    r <- v4_verify(p$root, files = files)
    expect_null(r$err, label = paste(files, collapse = ","))
    expect_identical(r4_entry(p$root, "chapters"), "NEW", label = paste(files, collapse = ","))
    expect_identical(r4_entry(p$root, "chapters/c"), "NEW", label = paste(files, collapse = ","))
    after <- v4_freeze_snap(p$root)
    expect_identical(after[startsWith(names(after), "d/")], before[startsWith(names(before), "d/")])
    expect_false(dir.exists(v4_backup_dir(p$root)))
  }
})

test_that("review-4 #2: a move that cannot be made is a weft_verify_error before the render, and _freeze is as it was", {
  skip_on_os("windows")
  skip_if(identical(Sys.info()[["user"]], "root"), "root can write into a read-only folder")
  v4_env()
  fq <- v4_fake_quarto()
  p <- r4_nested()
  before <- r4_plant_nested(p$root)
  stem_dir <- file.path(p$root, "_freeze", "chapters")
  Sys.chmod(stem_dir, "555")
  withr::defer(Sys.chmod(stem_dir, "755"))
  skip_if(file.access(stem_dir, 2L) == 0L, "the folder is still writable here")
  # the child's own entry can be moved, the parent's cannot: what was moved is put back
  r <- v4_verify(p$root, files = c("chapters/c.qmd", "chapters.qmd"))
  r4_failed(r)
  expect_length(v4_log(fq, "calls"), 0L)
  expect_identical(v4_freeze_snap(p$root), before)
  r2 <- v4_verify(p$root, files = "chapters.qmd")
  r4_failed(r2)
  expect_length(v4_log(fq, "calls"), 0L)
  expect_identical(v4_freeze_snap(p$root), before)
})

# ---- #3: nothing is written to the user's cache folder -------------------------------------------------------

test_that("review-4 #3: verify(static = TRUE), gate(), status() and use_hooks() write nothing under R_USER_CACHE_DIR; lints() is the guard", {
  skip_on_cran()
  skip_on_os("windows")
  d <- g_repo(list("a.qmd" = G_PROSE))
  calls <- c(lints = "weft::lints('%s')",
             verify = "weft::verify(static = TRUE, path = '%s')",
             gate = "weft::gate(NULL, path = '%s')",
             status = "weft::status('%s')",
             use_hooks = "weft::use_hooks('%s')")
  for (nm in names(calls)) {
    cache <- normalizePath(withr::local_tempdir(), winslash = "/")
    env <- u4_env(u4_home(), extra = c(R_USER_CACHE_DIR = cache))
    r <- u4_r(d, sprintf("try(suppressMessages(invisible(%s)), silent = TRUE)", sprintf(calls[[nm]], d)), env)
    expect_false(grepl("no package called", r$out), label = paste(nm, r$out))
    written <- list.files(cache, recursive = TRUE, all.files = TRUE)
    expect_identical(written, character(), label = paste(nm, "wrote", paste(written, collapse = ", ")))
    unlink(file.path(d, ".git", "hooks", "commit-msg"))
  }
})

# ---- #4, #5: how quarto is called ------------------------------------------------------------------------------

test_that("review-4 #4: several files are rendered by one `quarto render <file>` each", {
  v4_env()
  fq <- v4_fake_quarto(body = v4_sh_stamp("a.qmd"))
  p <- v4_proj(list("a.qmd" = V4_CONSTRUCT_DOC, "b.qmd" = V4_PLAIN_DOC, "c.qmd" = V4_PLAIN_DOC), git = TRUE,
               quarto_yml = V4_QUARTO_YML)
  r <- v4_verify(p$root, files = c("a.qmd", "b.qmd"))
  expect_null(r$err, label = if (!is.null(r$err)) conditionMessage(r$err) else "")
  expect_identical(v4_log(fq, "renders"), c("render a.qmd", "render b.qmd"))
})

test_that("review-4 #4: one file is `render <file>` and no files is a plain `render` in a Quarto project (neighbour guard)", {
  v4_env()
  fq <- v4_fake_quarto(body = v4_sh_stamp("a.qmd"))
  p <- v4_proj(list("a.qmd" = V4_CONSTRUCT_DOC, "b.qmd" = V4_PLAIN_DOC), git = TRUE, quarto_yml = V4_QUARTO_YML)
  expect_null(v4_verify(p$root, files = "a.qmd")$err)
  expect_identical(v4_log(fq, "renders"), "render a.qmd")
  fq2 <- v4_fake_quarto(body = v4_sh_stamp("a.qmd"))
  expect_null(v4_verify(p$root)$err)
  expect_identical(v4_log(fq2, "renders"), "render")
})

test_that("review-4 #5: with no _quarto.yml each document is rendered by name, and the report counts what was rendered", {
  v4_env()
  fq <- v4_fake_quarto(body = c(v4_sh_stamp("a.qmd"), v4_sh_stamp("b.qmd")))
  p <- v4_proj(list("a.qmd" = V4_CONSTRUCT_DOC, "b.qmd" = V4_CONSTRUCT_DOC), git = TRUE)
  expect_false(file.exists(file.path(p$root, "_quarto.yml")))
  r <- v4_verify(p$root)
  expect_null(r$err, label = if (!is.null(r$err)) conditionMessage(r$err) else "")
  expect_identical(v4_log(fq, "renders"), c("render a.qmd", "render b.qmd"))
  expect_match(v4_detail(r$value, "render"), "\\b2 documents rendered")
})

test_that("review-4 #5: a lone document with no _quarto.yml is rendered by its name", {
  v4_env()
  fq <- v4_fake_quarto(body = v4_sh_stamp("daily.qmd"))
  p <- v4_proj(list("daily.qmd" = V4_CONSTRUCT_DOC), git = FALSE)
  r <- v4_verify(p$root)
  expect_null(r$err, label = if (!is.null(r$err)) conditionMessage(r$err) else "")
  expect_identical(v4_log(fq, "renders"), "render daily.qmd")
})

# ---- #6: the render list ----------------------------------------------------------------------------------------

R4_BOOK <- c("project:", "  type: book", "book:", "  chapters:", "    - index.qmd", "format: html")

test_that("review-4 #6: a document outside the book's render list is not expected to have run, and is named in the report", {
  v4_env()
  fq <- v4_fake_quarto(body = v4_sh_stamp("index.qmd"), inspect = "index.qmd")
  p <- v4_proj(list("index.qmd" = V4_CONSTRUCT_DOC, "notes.qmd" = V4_CONSTRUCT_DOC), git = TRUE, quarto_yml = R4_BOOK)
  r <- v4_verify(p$root)
  expect_null(r$err, label = if (!is.null(r$err)) conditionMessage(r$err) else "")
  expect_true(r$value$ok)
  expect_identical(length(r$value$unexecuted), 0L)
  expect_false(v4_has_section(r$report, "Not executed in this render"))
  i <- grep("not in the render list", r$report, fixed = TRUE)
  expect_gt(length(i), 0L)
  near <- r$report[unique(pmin(length(r$report), unlist(lapply(i, function(k) k:(k + 3L)))))]
  expect_true(any(grepl("notes.qmd", near, fixed = TRUE)))
  expect_false(any(grepl("index.qmd", near[grepl("not in the render list", near, fixed = TRUE)], fixed = TRUE)))
  expect_match(v4_detail(r$value, "render"), "\\b1 documents? rendered")
  expect_gt(length(v4_log(fq, "inspects")), 0L)
})

test_that("review-4 #6: a document in the render list that holds a construct and has no stamp still fails", {
  v4_env()
  fq <- v4_fake_quarto(inspect = c("index.qmd", "notes.qmd"))     # no stamps written
  p <- v4_proj(list("index.qmd" = V4_CONSTRUCT_DOC, "notes.qmd" = V4_CONSTRUCT_DOC), git = TRUE, quarto_yml = R4_BOOK)
  r <- v4_verify(p$root)
  expect_s3_class(r$err, "weft_verify_error")
  expect_true(v4_has_section(r$report, "Not executed in this render"))
  expect_false(any(grepl("not in the render list", r$report, fixed = TRUE)))
})

test_that("review-4 #6: a document outside the render list is still linted: its construct error fails verify()", {
  v4_env()
  fq <- v4_fake_quarto(body = v4_sh_stamp("index.qmd"), inspect = "index.qmd")
  p <- v4_proj(list("index.qmd" = V4_CONSTRUCT_DOC, "notes.qmd" = g_bad_doc()), git = TRUE, quarto_yml = R4_BOOK)
  r <- v4_verify(p$root)
  expect_s3_class(r$err, "weft_verify_error")
  expect_true("notes.qmd" %in% v4_df(r$res$errors)$file)
})

# ---- #7: nested projects ----------------------------------------------------------------------------------------

r4_edit_before <- c("Intro paragraph.", "", "Flow rose by `r x`{.num} in March.", G_ENGINE)
r4_edit_after <- c("Intro paragraph.", "", "Flow rose by 45% in March.", G_ENGINE)

test_that("review-4 #7: a document of a nested project is judged by the nested project only: one finding, one removal", {
  d <- g_scenario(list("sub/x.qmd" = r4_edit_before), list("sub/x.qmd" = r4_edit_after), weft = c(".", "sub"))
  res <- g_gate(d)
  expect_false(res$ok)
  expect_identical(nrow(res$added), 1L)
  expect_identical(res$n_removed, 1L)
  expect_identical(nrow(res$removed), 1L)
  expect_true("commit-msg: 1 finding added that HEAD did not hold" %in% g_report(res))
  expect_true(any(trimws(g_report(res)) == "Weft-Removed: 1"))
  expect_false(g_gate(d, c("Edit", "", "Weft-Removed: 2"))$ok)
})

test_that("review-4 #7: a document of the outer project and one of the nested project count once each", {
  d <- g_scenario(list("y.qmd" = r4_edit_before, "sub/x.qmd" = r4_edit_before),
                  list("y.qmd" = r4_edit_after, "sub/x.qmd" = r4_edit_after), weft = c(".", "sub"))
  res <- g_gate(d)
  expect_identical(nrow(res$added), 2L)
  expect_identical(res$n_removed, 2L)
  expect_identical(nrow(res$removed), 2L)
})

test_that("review-4 #7: two sibling projects count their own documents once (neighbour guard)", {
  d <- g_scenario(list("a/x.qmd" = r4_edit_before, "b/x.qmd" = r4_edit_before),
                  list("a/x.qmd" = r4_edit_after, "b/x.qmd" = r4_edit_after), weft = c("a", "b"))
  res <- g_gate(d)
  expect_identical(nrow(res$added), 2L)
  expect_identical(res$n_removed, 2L)
})

# ---- #8: a rename ---------------------------------------------------------------------------------------------------

R4_SITE_DOC <- c("---", "title: A", "---", "", "Intro paragraph one.", "", "Second paragraph here.", "",
                 "Third paragraph of text.", "", "[a site | # sites]{n=\"k\"}", "", "Last paragraph.")

test_that("review-4 #8: renaming a .qmd that lacks `engine: knitr` passes the gate", {
  d <- g_scenario(list("a.qmd" = R4_SITE_DOC), list("a.qmd" = NULL, "b.qmd" = R4_SITE_DOC))
  res <- g_gate(d)
  expect_identical(nrow(res$added), 0L)
  expect_true(res$ok)
})

test_that("review-4 #8: a rename with a small edit passes too", {
  edited <- sub("Last paragraph.", "Final paragraph.", R4_SITE_DOC, fixed = TRUE)
  d <- g_scenario(list("a.qmd" = R4_SITE_DOC), list("a.qmd" = NULL, "b.qmd" = edited))
  res <- g_gate(d)
  expect_identical(nrow(res$added), 0L)
  expect_true(res$ok)
})

test_that("review-4 #8: a rename plus a newly typed number is still refused, for the number only", {
  d <- g_scenario(list("a.qmd" = R4_SITE_DOC),
                  list("a.qmd" = NULL, "b.qmd" = c(R4_SITE_DOC, "", "Flow rose by 45% in March.")))
  res <- g_gate(d)
  expect_false(res$ok)
  expect_identical(nrow(res$added), 1L)
  expect_identical(g_df(res$added)$rule, "numeral")
})

test_that("review-4 #8: a copy (the old file stays) is a new file lacking the marker: refused (neighbour guard)", {
  d <- g_scenario(list("a.qmd" = R4_SITE_DOC), list("b.qmd" = R4_SITE_DOC))
  expect_false(g_gate(d)$ok)
})

test_that("review-4 #8: through the installed hook a `git mv` of such a document is committed", {
  skip_on_os("windows")
  dir <- h4_repo(list("a.qmd" = R4_SITE_DOC))
  h4_hooks(dir)
  g_ok_git(dir, "mv", "a.qmd", "b.qmd")
  r <- h4_commit(dir, "Rename a to b")
  expect_identical(r$status, 0L)
  expect_true(r$moved)
})

# ---- #9: cache identity: no test ---------------------------------------------------------------------------------------
# What identifies the installed code (the md5 of R/weft.rdb, or the newest source time under load_all()) is
# internal, and the two builds in two libraries that would show it are too slow for a test. See the report.

# ---- #10: use_weft() undoes a failed run ----------------------------------------------------------------------------------

test_that("review-4 #10: a use_weft() whose hook step fails undoes what the earlier steps wrote, and says so", {
  skip_on_os("windows")
  skip_if(identical(Sys.info()[["user"]], "root"), "root can write into a read-only folder")
  files <- list(`_quarto.yml` = U4_QUARTO_YML, `index.qmd` = u4_qmd(), `.Rprofile` = "options(digits = 4)",
                `_weft.yml` = c("draft: false", "# the author's note"))
  dir <- h4_repo(files, weft = character(), origin = "https://github.com/example-org/example-repo.git")
  hooks <- file.path(dir, ".git", "hooks")
  dir.create(hooks, showWarnings = FALSE)
  Sys.chmod(hooks, "555")
  withr::defer(Sys.chmod(hooks, "755"))
  skip_if(file.access(hooks, 2L) == 0L, "the folder is still writable here")
  withr::local_libpaths(h4_lib(), action = "prefix")
  snap <- function() {
    s <- h4_snap_repo(dir)
    s[s != "<dir>"]
  }
  before <- snap()
  err <- tryCatch(suppressMessages(utils::capture.output(weft::use_weft(dir))), error = function(e) e)
  expect_s3_class(err, "error")
  msg <- if (inherits(err, "error")) cli::ansi_strip(conditionMessage(err)) else ""
  expect_match(msg, "commit-msg", fixed = TRUE)
  expect_false(grepl("Nothing was written.", msg, fixed = TRUE))
  expect_match(msg, "undone|undid|put back|removed|restored|rolled back", ignore.case = TRUE)
  after <- snap()
  expect_identical(names(after), names(before))
  expect_identical(after, before)
})

# ---- #11: a hook without its execute bit ----------------------------------------------------------------------------------

test_that("review-4 #11: a weft hook that is not executable is `outdated` in status(), with the detail", {
  skip_on_os("windows")
  dir <- h4_repo()
  h4_hooks(dir)
  expect_identical(h4_state(h4_status(dir), "hooks"), "ok")
  Sys.chmod(h4_hook_path(dir), "644")
  st <- h4_status(dir)
  expect_identical(h4_state(st, "hooks"), "outdated")
  expect_match(h4_detail(st, "hooks"), "not executable", fixed = TRUE)
})

test_that("review-4 #11: use_hooks() repairs the mode, keeps the text, and the next commit is judged", {
  skip_on_os("windows")
  dir <- h4_repo(list("ch1.qmd" = G_PROSE))
  h4_hooks(dir)
  text <- readLines(h4_hook_path(dir))
  Sys.chmod(h4_hook_path(dir), "644")
  h4_hooks(dir)
  expect_identical(as.character(file.info(h4_hook_path(dir))$mode), "755")
  expect_identical(readLines(h4_hook_path(dir)), text)
  expect_identical(h4_state(h4_status(dir), "hooks"), "ok")
  g_apply(dir, list("ch1.qmd" = g_bad_doc()))
  g_add(dir)
  r <- h4_commit(dir)
  expect_identical(r$status, 1L)
  expect_false(r$moved)
})

test_that("review-4 #11: a foreign hook that is not executable is left as it is (neighbour guard)", {
  skip_on_os("windows")
  dir <- h4_repo()
  writeLines(H4_FOREIGN_HOOK, h4_hook_path(dir))
  Sys.chmod(h4_hook_path(dir), "644")
  h4_hooks(dir)
  expect_identical(as.character(file.info(h4_hook_path(dir))$mode), "644")
  expect_identical(readLines(h4_hook_path(dir)), H4_FOREIGN_HOOK)
})

# ---- #12: the count of findings added -------------------------------------------------------------------------------------

test_that("review-4 #12: verify() counts the excess of a key, not the instances it lists", {
  v4_env()
  p <- v4_proj(list("a.qmd" = c("We saw `r x` and 45% today.", G_ENGINE)), git = TRUE)
  g_write(p$top, "a.qmd", c("We saw 45% and 45% today.", G_ENGINE))
  r <- v4_verify(p$root, static = TRUE)
  expect_s3_class(r$err, "weft_verify_error")
  expect_match(v4_detail(r$res, "lints"), "\\b1 added")
  expect_false(grepl("\\b2 added", v4_detail(r$res, "lints")))
  expect_gt(nrow(r$res$added), 0L)
  expect_match(cli::ansi_strip(conditionMessage(r$err)), "failed: 1 (reason|reason\\(s\\));")
})

# ---- #13: the CI template and an awkward project path -------------------------------------------------------------------

test_that("review-4 #13: the project path reaches the workflow through an env entry, not inside the shell and R strings", {
  skip_on_os("windows")
  for (nm in c("it's", "a$(touch pwned)", "x`id`y")) {
    dir <- h4_repo(stats::setNames(list(G_PROSE), file.path(nm, "ch1.qmd")), weft = nm)
    h4_ci(file.path(dir, nm))
    y <- yaml::yaml.load(r4_text(file.path(dir, ".github", "workflows", "weft.yml")))
    steps <- y$jobs$verify$steps
    step <- Filter(function(s) identical(s$name, "weft static checks"), steps)[[1]]
    expect_false(grepl(nm, step$run, fixed = TRUE), label = nm)
    expect_true(nm %in% unlist(step$env), label = nm)
  }
})

# ---- #14: a project .Renviron ----------------------------------------------------------------------------------------------

test_that("review-4 #14: a project .Renviron that sets R_LIBS does not hide weft from the hook", {
  skip_on_os("windows")
  dir <- h4_repo(list("ch1.qmd" = G_PROSE, ".Renviron" = "R_LIBS=/nonexistent/weft-lib"))
  h4_hooks(dir)
  g_apply(dir, list("ch1.qmd" = g_num_doc("45%")))
  g_add(dir)
  r <- h4_commit(dir)
  expect_false(grepl("weft is not installed", r$out, fixed = TRUE))
  expect_identical(r$status, 1L)
  expect_match(r$out, "1 finding added that HEAD did not hold", fixed = TRUE)
})

test_that("review-4 #14: and a clean commit passes with such an .Renviron", {
  skip_on_os("windows")
  dir <- h4_repo(list("ch1.qmd" = G_PROSE, ".Renviron" = "R_LIBS=/nonexistent/weft-lib"))
  h4_hooks(dir)
  g_apply(dir, list("ch1.qmd" = c(G_PROSE, "", "One more sentence.")))
  g_add(dir)
  r <- h4_commit(dir)
  expect_identical(r$status, 0L)
  expect_true(r$moved)
})

# ---- #15: status() and R_PROFILE_USER -----------------------------------------------------------------------------------------

r4_full <- function(files, env = parent.frame()) {
  dir <- h4_repo(files, weft = character(), origin = "https://github.com/example-org/example-repo.git", env = env)
  h4_weft(dir, env = env)
  dir
}
r4_status_say <- function(dir) {
  said <- character()
  st <- withCallingHandlers(
    {
      utils::capture.output(res <- weft::status(dir))
      res
    },
    message = function(m) {
      said <<- c(said, conditionMessage(m))
      invokeRestart("muffleMessage")
    },
    warning = function(w) {
      said <<- c(said, conditionMessage(w))
      invokeRestart("muffleWarning")
    })
  list(st = st, said = cli::ansi_strip(said))
}

test_that("review-4 #15: with R_PROFILE_USER set the .Rprofile route is not reported as working", {
  dir <- r4_full(list(`_quarto.yml` = U4_QUARTO_YML, `index.qmd` = u4_qmd()))
  expect_identical(h4_state(h4_status(dir), "activation"), "ok")
  prof <- withr::local_tempfile(lines = "x <- 1")
  withr::local_envvar(R_PROFILE_USER = prof)
  x <- r4_status_say(dir)
  expect_true(identical(h4_state(x$st, "activation"), "off") ||
                any(grepl("R_PROFILE_USER", c(x$said, x$st$detail), fixed = TRUE)))
})

test_that("review-4 #15: the front-matter route is still ok with R_PROFILE_USER set (neighbour guard)", {
  dir <- r4_full(list(`index.qmd` = u4_qmd()))
  prof <- withr::local_tempfile(lines = "x <- 1")
  withr::local_envvar(R_PROFILE_USER = prof)
  expect_identical(h4_state(h4_status(dir), "activation"), "ok")
})

# ---- #16: line endings ---------------------------------------------------------------------------------------------------------

r4_crlf_write <- function(path, lines) writeBin(charToRaw(paste0(paste(lines, collapse = "\r\n"), "\r\n")), path)
r4_raw <- function(path) readBin(path, "raw", file.size(path))
r4_bare_lf <- function(r) {
  i <- which(r == as.raw(10L))
  length(i) > 0L && any(i == 1L | r[pmax(i - 1L, 1L)] != as.raw(13L))
}
r4_starts_with <- function(new, old) length(new) >= length(old) && identical(new[seq_along(old)], old)

test_that("review-4 #16: use_agent_docs() keeps the CRLF of an AGENTS.md and the author's bytes", {
  dir <- h4_repo()
  p <- file.path(dir, "AGENTS.md")
  r4_crlf_write(p, c("# Our agents", "", "Be kind."))
  old <- r4_raw(p)
  h4_agent(dir)
  new <- r4_raw(p)
  expect_gt(length(new), length(old))
  expect_true(r4_starts_with(new, old))
  expect_false(r4_bare_lf(new))
})

test_that("review-4 #16: use_setup() keeps the CRLF of .Rprofile and _weft.yml in a Quarto project", {
  dir <- h4_repo(list(`_quarto.yml` = U4_QUARTO_YML, `index.qmd` = u4_qmd()))
  r4_crlf_write(file.path(dir, ".Rprofile"), c("options(digits = 4)", "# mine"))
  r4_crlf_write(file.path(dir, "_weft.yml"), c("draft: false", "# the author's note"))
  old <- lapply(c(".Rprofile", "_weft.yml"), function(f) r4_raw(file.path(dir, f)))
  suppressMessages(utils::capture.output(weft::use_setup(dir)))
  for (i in 1:2) {
    f <- c(".Rprofile", "_weft.yml")[[i]]
    new <- r4_raw(file.path(dir, f))
    expect_true(r4_starts_with(new, old[[i]]), label = f)
    expect_false(r4_bare_lf(new), label = f)
  }
  expect_gt(length(r4_raw(file.path(dir, ".Rprofile"))), length(old[[1]]))   # the route was added
})

test_that("review-4 #16: use_setup() keeps the CRLF of a document whose front matter it edits", {
  dir <- h4_repo(list(`index.qmd` = u4_qmd()))
  r4_crlf_write(file.path(dir, "index.qmd"), u4_qmd())
  suppressMessages(utils::capture.output(weft::use_setup(dir)))
  new <- r4_raw(file.path(dir, "index.qmd"))
  expect_true(any(grepl("weft_setup", readLines(file.path(dir, "index.qmd"), warn = FALSE), fixed = TRUE)))
  expect_false(r4_bare_lf(new))
})

test_that("review-4 #16: an LF file stays LF (neighbour guard)", {
  dir <- h4_repo(list(`_quarto.yml` = U4_QUARTO_YML, `index.qmd` = u4_qmd(), `.Rprofile` = "options(digits = 4)"))
  suppressMessages(utils::capture.output(weft::use_setup(dir)))
  h4_agent(dir)
  for (f in c(".Rprofile", "_weft.yml", "AGENTS.md")) {
    expect_false(any(r4_raw(file.path(dir, f)) == as.raw(13L)), label = f)
  }
})

# ---- #17: the pre-commit entry ------------------------------------------------------------------------------------------------------

test_that("review-4 #17: the pre-commit entry asks git for the common directory, as the plain hook line does", {
  dir <- h4_repo(list(`.pre-commit-config.yaml` = "repos: []"))
  writeLines(H4_PRECOMMIT_HOOK, h4_hook_path(dir))
  s <- h4_say(weft::use_hooks(dir, lib = h4_lib()))
  entry <- grep("entry:", s$lines, value = TRUE)
  expect_length(entry, 1L)
  expect_match(entry, "git rev-parse --git-common-dir", fixed = TRUE)
  expect_match(entry, "weft/commit-msg", fixed = TRUE)
  expect_false(grepl("entry: sh .git/", entry, fixed = TRUE))
})

# ---- Q1: the removal count is per kind ---------------------------------------------------------------------------------------------

R4_CLAIM_CHUNK <- c("```{r chk-a}", "claim(n_sites, . > 10)", "```")
R4_NO_CLAIM <- c("```{r chk-a}", "x <- 1", "```")

test_that("review-4 Q1: removing a claim() and adding a value needs Weft-Removed: 1", {
  before <- c(R4_CLAIM_CHUNK, "", "The reading is `r a1`{.num} metres.", G_ENGINE)
  after <- c(R4_NO_CLAIM, "", "The reading is `r a1`{.num} metres.", "", "Also `r a2`{.num} here.", G_ENGINE)
  d <- g_scenario(list("ch1.qmd" = before), list("ch1.qmd" = after))
  res <- g_gate(d)
  expect_false(res$ok)
  expect_identical(res$n_removed, 1L)
  expect_identical(res$removed$kind, "claim")
  expect_true(g_gate(d, c("Drop the claim", "", "Weft-Removed: 1"))$ok)
})

test_that("review-4 Q1: removing two claims and adding three values needs Weft-Removed: 2", {
  chunks <- function(n) unlist(lapply(seq_len(n), function(i) c(sprintf("```{r chk-%d}", i),
                                                                sprintf("claim(v%d, . > %d)", i, i), "```", "")))
  before <- c(chunks(3), G_ENGINE)
  after <- c(chunks(1), g_vals(c("w1", "w2", "w3")), G_ENGINE)
  d <- g_scenario(list("ch1.qmd" = before), list("ch1.qmd" = after))
  res <- g_gate(d)
  expect_false(res$ok)
  expect_identical(res$n_removed, 2L)
  expect_true(g_gate(d, c("Drop claims", "", "Weft-Removed: 2"))$ok)
})

test_that("review-4 Q1: removing a value and adding a value of the same kind needs no trailer (neighbour guard)", {
  d <- g_scenario(list("ch1.qmd" = c(g_vals(c("a1", "a2", "a3")), G_ENGINE)),
                  list("ch1.qmd" = c(g_vals(c("a1", "a2", "b9")), G_ENGINE)))
  res <- g_gate(d)
  expect_identical(max(0, res$n_removed), 0)
  expect_true(res$ok)
})

test_that("review-4 Q1: the count sums over projects: one removes a value, another adds one, N is 1", {
  d <- g_scenario(list("a/x.qmd" = c(g_vals(c("a1", "a2")), G_ENGINE), "b/y.qmd" = c(g_vals("b1"), G_ENGINE)),
                  list("a/x.qmd" = c(g_vals("a1"), G_ENGINE), "b/y.qmd" = c(g_vals(c("b1", "b2")), G_ENGINE)),
                  weft = c("a", "b"))
  res <- g_gate(d)
  expect_identical(res$n_removed, 1L)
  expect_false(res$ok)
})

# values and spans count together, claims on their own
R4_SPAN <- "We monitored [a site | # sites]{n=\"n_sites\"} here."
R4_VALUE <- "We monitored `r n_sites`{.num} sites."

test_that("review-4 Q1: removing a claim() and adding a span needs Weft-Removed: 1", {
  d <- g_scenario(list("ch1.qmd" = c(R4_CLAIM_CHUNK, G_ENGINE)),
                  list("ch1.qmd" = c(R4_NO_CLAIM, "", R4_SPAN, G_ENGINE)))
  res <- g_gate(d)
  expect_false(res$ok)
  expect_identical(res$n_removed, 1L)
  expect_true(g_gate(d, c("Drop the claim", "", "Weft-Removed: 1"))$ok)
})

test_that("review-4 Q1: removing a value and adding a span needs no trailer (values and spans count together)", {
  d <- g_scenario(list("ch1.qmd" = c(R4_VALUE, G_ENGINE)), list("ch1.qmd" = c(R4_SPAN, G_ENGINE)))
  res <- g_gate(d)
  expect_identical(max(0, res$n_removed), 0)
  expect_true(res$ok)
})

test_that("review-4 Q1: removing a span and adding a claim needs Weft-Removed: 1", {
  d <- g_scenario(list("ch1.qmd" = c(R4_SPAN, G_ENGINE)),
                  list("ch1.qmd" = c(R4_CLAIM_CHUNK, G_ENGINE)))
  res <- g_gate(d)
  expect_false(res$ok)
  expect_identical(res$n_removed, 1L)
  expect_true(g_gate(d, c("Swap", "", "Weft-Removed: 1"))$ok)
})

# ---- Q3: a stale backup of a killed run --------------------------------------------------------------------------------------------------
# The manifest of a backup records the run id of the verify run that took it, on a line `run: <id>` (the
# stems are the other lines, as before). A stem's current entry is kept, and its backup discarded with a
# note, only when the document's stamp exists and carries a run id other than the manifest's.

R4_KILLED_RUN <- "verify-20260101000000-111"
R4_LATER_RUN <- "verify-20260102000000-222"

# a killed run's leftovers for stems a, b and c (as test-verify-freeze.R forges them); `run`: the manifest's
# run id (NULL: a manifest as older versions wrote). Stamps: a from a later run, b from the killed run, c none.
r4_forge_killed <- function(root, run = R4_KILLED_RUN) {
  v4_plant_freeze(root, c("a", "b", "c"))
  bk <- v4_backup_dir(root)
  dir.create(bk, recursive = TRUE)
  writeLines(c(if (!is.null(run)) paste0("run: ", run), "a", "b", "c"), file.path(bk, "manifest"))
  for (s in c("a", "b", "c")) file.rename(file.path(root, "_freeze", s), file.path(bk, s))
  # a later complete render of a wrote a newer entry and its stamp; b's stamp is the killed run's own
  f3_write(file.path(root, "_freeze", "a", "execute-results", "html.json"), "NEWER a")
  f3_write(file.path(root, ".weft", "stamps", "a.qmd.json"), v4_stamp_json("a.qmd", run = R4_LATER_RUN))
  f3_write(file.path(root, ".weft", "stamps", "b.qmd.json"), v4_stamp_json("b.qmd", run = R4_KILLED_RUN))
  invisible(root)
}
r4_trio <- function(env = parent.frame()) {
  v4_proj(list("a.qmd" = V4_PLAIN_DOC, "b.qmd" = V4_PLAIN_DOC, "c.qmd" = V4_PLAIN_DOC), git = TRUE,
          quarto_yml = V4_QUARTO_YML, env = env)
}

test_that("review-4 Q3: a stem with a stamp of a later run keeps its entry, with a note; the others are restored", {
  v4_env()
  fq <- v4_fake_quarto(status = 1L)
  p <- r4_trio()
  r4_forge_killed(p$root)
  r <- v4_verify(p$root)
  r4_failed(r)
  expect_identical(r4_entry(p$root, "a"), "NEWER a")     # stamp of another run: kept
  expect_identical(r4_entry(p$root, "b"), "OLD b")       # stamp of the killed run: restored
  expect_identical(r4_entry(p$root, "c"), "OLD c")       # no stamp: restored
  expect_false(dir.exists(v4_backup_dir(p$root)))
  said <- c(r$report, r$res$notes, vapply(r$warnings, conditionMessage, ""))
  expect_true(any(grepl("the document's stamp is of a newer run", said, fixed = TRUE)))
})

test_that("review-4 Q3: verify(files = b) keeps the entry of a, which stays after a pass", {
  v4_env()
  fq <- v4_fake_quarto()
  p <- r4_trio()
  r4_forge_killed(p$root)
  r <- v4_verify(p$root, files = "b.qmd")
  expect_null(r$err, label = if (!is.null(r$err)) conditionMessage(r$err) else "")
  expect_identical(r4_entry(p$root, "a"), "NEWER a")
  expect_false(dir.exists(v4_backup_dir(p$root)))
})

test_that("review-4 Q3: a manifest with no run id (older versions) restores every stem, whatever the stamps", {
  v4_env()
  fq <- v4_fake_quarto(status = 1L)
  p <- r4_trio()
  r4_forge_killed(p$root, run = NULL)
  r <- v4_verify(p$root)
  r4_failed(r)
  for (s in c("a", "b", "c")) expect_identical(r4_entry(p$root, s), paste("OLD", s), label = s)
  expect_false(dir.exists(v4_backup_dir(p$root)))
})

# ---- Q5: a project that did not exist at `since` ------------------------------------------------------------------------------------------

test_that("review-4 Q5: a project whose _weft.yml is not in HEAD has nothing added, and the report says it is a baseline", {
  v4_env()
  p <- v4_proj(list("a.qmd" = g_num_doc("45%")), git = TRUE, weft_yml = NULL)
  f3_write(file.path(p$root, "_weft.yml"), "draft: false")
  r <- v4_verify(p$root, static = TRUE)
  expect_null(r$err, label = if (!is.null(r$err)) conditionMessage(r$err) else "")
  expect_true(r$value$ok)
  expect_identical(nrow(r$value$added), 0L)
  expect_true(any(grepl("baseline", c(r$report, r$value$notes), ignore.case = TRUE)))
})

test_that("review-4 Q5: a new folder of a repository that has commits: nothing is added, and the report says baseline", {
  v4_env()
  top <- g_repo(list("README.md" = "Outside the project."), weft = character())
  f3_write(file.path(top, "proj", "_weft.yml"), "draft: false")
  f3_write(file.path(top, "proj", "a.qmd"), g_num_doc(c("45%", "37%")))
  r <- v4_verify(file.path(top, "proj"), static = TRUE)
  expect_null(r$err, label = if (!is.null(r$err)) conditionMessage(r$err) else "")
  expect_identical(nrow(r$value$added), 0L)
  expect_true(any(grepl("baseline", c(r$report, r$value$notes), ignore.case = TRUE)))
})

test_that("review-4 Q5: construct errors in such a project still fail (neighbour guard)", {
  v4_env()
  p <- v4_proj(list("a.qmd" = g_bad_doc()), git = TRUE, weft_yml = NULL)
  f3_write(file.path(p$root, "_weft.yml"), "draft: false")
  r <- v4_verify(p$root, static = TRUE)
  expect_s3_class(r$err, "weft_verify_error")
})

# ---- Q7: _weft.yml unreadable at HEAD ------------------------------------------------------------------------------------------------------

test_that("review-4 Q7: with _weft.yml unreadable at HEAD, a commit that removes a construct still needs the trailer", {
  d <- g_scenario(list("ch1.qmd" = c(g_vals(c("a1", "a2")), G_ENGINE),
                       "_weft.yml" = c("draft: false", "label_words: [Station")),
                  list("ch1.qmd" = c(g_vals("a1"), G_ENGINE), "_weft.yml" = "draft: false"))
  res <- g_gate(d)
  expect_false(res$ok)
  expect_identical(res$n_removed, 1L)
  expect_true(any(grepl("_weft.yml", res$notes, fixed = TRUE)))        # the findings comparison is still skipped
  expect_true(g_gate(d, c("Drop one", "", "Weft-Removed: 1"))$ok)
})

# ---- no tests ------------------------------------------------------------------------------------------------------------------------------------
# #9: see above. Q2, Q4 and Q6 stand as built.
