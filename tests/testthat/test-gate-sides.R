# Package 4a: the gate's sides, projects and result (dev/design-4.md G5-G8, G19; G3 for "writes nothing").
# Rules judged here: `construct` (3a), `numeral` (3b), `file-link` (3d), `tar-name` (3c, left out by H5).
# Tests marked [3b], [3d] need a rule of that package to exist; the others need only 3a and `numeral`.

# ---- G19: the arguments and the result -----------------------------------------------------------------

test_that("4a G19: gate(message = NULL, path = \".\") has those arguments", {
  expect_identical(names(formals(gate)), c("message", "path"))
  expect_null(formals(gate)$message)
  expect_identical(formals(gate)$path, ".")
})

test_that("4a G19: a passing gate returns a weft_gate invisibly, with exactly the documented fields", {
  d <- g_scenario(list("ch1.qmd" = G_PROSE, "ch2.qmd" = G_PROSE),
                  list("ch1.qmd" = c(G_PROSE, "", "More."), "ch2.qmd" = c(G_PROSE, "", "Also more.")))
  vis <- withVisible(suppressMessages(gate(NULL, path = d)))
  expect_false(vis$visible)
  res <- vis$value
  expect_s3_class(res, "weft_gate")
  expect_setequal(names(res), c("ok", "errors", "added", "excess", "removed", "n_removed", "trailer",
                                "changed", "notes", "seconds"))
  expect_true(is.logical(res$ok) && length(res$ok) == 1L)
  expect_true(res$ok)
  expect_s3_class(res$errors, "weft_findings")
  expect_s3_class(res$added, "weft_findings")
  expect_identical(nrow(res$errors), 0L)
  expect_identical(nrow(res$added), 0L)
  expect_s3_class(res$excess, "data.frame")
  expect_identical(names(res$excess), c("project", "rule", "text", "base", "new"))
  expect_identical(nrow(res$excess), 0L)
  expect_s3_class(res$removed, "data.frame")
  expect_identical(names(res$removed), c("project", "file", "line", "kind", "text"))
  expect_identical(nrow(res$removed), 0L)
  expect_true(is.numeric(res$n_removed) && length(res$n_removed) == 1L)
  expect_true(res$n_removed == 0)
  expect_true(length(res$trailer) == 1L && is.na(res$trailer))
  expect_type(res$changed, "character")
  expect_setequal(res$changed, c("ch1.qmd", "ch2.qmd"))
  expect_type(res$notes, "character")
  expect_true(is.numeric(res$seconds) && length(res$seconds) == 1L && res$seconds >= 0)
})

test_that("4a G20: a passing run prints only the pass line, with the count of changed files and one decimal of seconds", {
  d <- g_scenario(list("ch1.qmd" = G_PROSE, "ch2.qmd" = G_PROSE),
                  list("ch1.qmd" = c(G_PROSE, "", "More."), "ch2.qmd" = c(G_PROSE, "", "Also more.")))
  res <- g_gate(d)
  expect_identical(g_report(res), "commit-msg: weft passed (2 changed files, T s)")
  raw <- attr(res, "report")
  expect_match(raw, "^commit-msg: weft passed \\(2 changed files, [0-9]+\\.[0-9] s\\)$")
})

test_that("4a G19: print() of a weft_gate prints the report", {
  d <- g_scenario(list("ch1.qmd" = G_PROSE), list("ch1.qmd" = g_num_doc("45%")))
  res <- g_gate(d)
  shown <- g_print_lines(res)
  expect_identical(shown, g_report(res))
  expect_true(length(shown) > 1L)
})

test_that("4a G19: a failing gate returns ok = FALSE and still returns (does not signal)", {
  d <- g_scenario(list("ch1.qmd" = G_PROSE), list("ch1.qmd" = g_bad_doc()))
  res <- g_gate(d)
  expect_s3_class(res, "weft_gate")
  expect_false(res$ok)
})

test_that("4a G19: the path may be any folder inside the work tree and the whole repository is judged", {
  d <- g_scenario(list("book/ch1.qmd" = G_PROSE), list("book/ch1.qmd" = g_num_doc("45%")), weft = "book")
  from_top <- g_gate(d)
  from_sub <- g_gate(file.path(d, "book"))
  expect_false(from_top$ok)
  expect_identical(g_sig(from_sub), g_sig(from_top))
})

# ---- G2, G19: no git, not a work tree ------------------------------------------------------------------

test_that("4a G2: a folder that is not in a git work tree is a weft_gate_error", {
  git_env()
  d <- withr::local_tempdir()
  writeLines("draft: false", file.path(d, "_weft.yml"))
  skip_if_no_git()
  cnd <- tryCatch(suppressMessages(gate(NULL, path = d)), error = function(e) e)
  expect_s3_class(cnd, "weft_gate_error")
  expect_s3_class(cnd, "weft_error")
})

test_that("4a G2: no git on the PATH is a weft_gate_error", {
  d <- g_repo(list("ch1.qmd" = G_PROSE))
  empty <- withr::local_tempdir()
  withr::local_envvar(PATH = empty)
  cnd <- tryCatch(suppressMessages(gate(NULL, path = d)), error = function(e) e)
  expect_s3_class(cnd, "weft_gate_error")
  expect_s3_class(cnd, "weft_error")
})

# ---- G5: which side is judged ------------------------------------------------------------------------------

test_that("4a G5: the staged text is judged, not the work tree (edit, stage, edit again)", {
  d <- g_repo(list("ch1.qmd" = G_PROSE))
  g_write(d, "ch1.qmd", g_num_doc("45%"))
  g_add(d)
  g_write(d, "ch1.qmd", G_PROSE)             # the work tree is clean again, the index holds the finding
  res <- g_gate(d)
  expect_false(res$ok)
  expect_true("45%" %in% res$excess$text)
})

test_that("4a G5: a finding only in the work tree is not judged (stage clean, then edit)", {
  d <- g_repo(list("ch1.qmd" = G_PROSE))
  g_write(d, "ch1.qmd", c(G_PROSE, "", "Staged sentence."))
  g_add(d)
  g_write(d, "ch1.qmd", g_num_doc("45%"))
  res <- g_gate(d)
  expect_true(res$ok)
})

test_that("4a G5: an unstaged change is not part of the commit (nothing staged, work tree dirty): nothing changed", {
  d <- g_repo(list("ch1.qmd" = G_PROSE))
  g_write(d, "ch1.qmd", g_bad_doc())
  res <- g_gate(d)
  expect_true(res$ok)
  expect_length(res$changed, 0L)
})

test_that("4a G5: the index named by GIT_INDEX_FILE decides (git commit -a gives the hook a temporary index)", {
  d <- g_repo(list("ch1.qmd" = G_PROSE))
  tmp_index <- withr::local_tempfile(fileext = ".index")
  file.copy(file.path(d, ".git", "index"), tmp_index)
  g_write(d, "ch1.qmd", g_num_doc("45%"))
  withr::with_envvar(c(GIT_INDEX_FILE = tmp_index), g_add(d))   # only the temporary index holds the change
  expect_true(g_gate(d)$ok)                                      # the real index is clean
  withr::with_envvar(c(GIT_INDEX_FILE = tmp_index), {
    res <- g_gate(d)
    expect_false(res$ok)
  })
})

# ---- G6: materialising --------------------------------------------------------------------------------------

test_that("4a G6: an untracked document is never read", {
  d <- g_repo(list("ch1.qmd" = G_PROSE))
  g_write(d, "scratch.qmd", g_bad_doc())              # untracked
  g_write(d, "ch1.qmd", c(G_PROSE, "", "Edited."))
  g_add(d, "ch1.qmd")
  res <- g_gate(d)
  expect_true(res$ok)
  expect_false("scratch.qmd" %in% res$changed)
})

test_that("4a G6: an ignored document is never read", {
  d <- g_repo(list("ch1.qmd" = G_PROSE, ".gitignore" = "drafts/"))
  g_write(d, "drafts/old.qmd", g_bad_doc())
  g_write(d, "ch1.qmd", c(G_PROSE, "", "Edited."))
  g_add(d)
  expect_true(g_gate(d)$ok)
})

test_that("4a G6: a non-ASCII path is read and reported as written", {
  nm <- "caf\u00e9.qmd"
  d <- g_scenario(list("ch1.qmd" = G_PROSE), setNames(list(g_num_doc("45%")), nm))
  res <- g_gate(d)
  expect_false(res$ok)
  expect_true(any(grepl(nm, enc2utf8(g_report(res)), fixed = TRUE)))
  expect_true(nm %in% enc2utf8(res$changed))
})

test_that("4a G5, G6: a symbolic link is a path with no content, and a 6 MB .json is a placeholder with a note", {
  skip_on_os("windows")
  d <- g_repo(list("ch1.qmd" = G_PROSE))
  file.symlink("ch1.qmd", file.path(d, "alias.qmd"))
  g_write(d, "data/big.json", rep(as.raw(0x20), 6 * 1024^2))
  g_write(d, "ch1.qmd", c(G_PROSE, "", "Edited."))
  g_add(d)
  expect_identical(substr(as.character(g_ok_git(d, "ls-files", "-s", "alias.qmd")), 1, 6), "120000")
  res <- g_gate(d)
  expect_true(res$ok)
  expect_true(any(grepl("big.json", res$notes, fixed = TRUE)))
  expect_true(any(grepl("big.json", g_report(res), fixed = TRUE)))
})

test_that("4a G6 [3d]: a link to a tracked file passes; to an untracked one is a finding", {
  d <- g_repo(list("ch1.qmd" = G_PROSE, "data/x.csv" = "a,b", "chA.qmd" = G_PROSE))
  g_write(d, "ch1.qmd", c(G_PROSE, "", "See [the data](data/x.csv)."))
  g_add(d)
  expect_true(g_gate(d)$ok)
  g_write(d, "data/y.csv", "c,d")                      # present in the work tree, never added
  g_write(d, "ch1.qmd", c(G_PROSE, "", "See [the data](data/x.csv) and [more](data/y.csv)."))
  g_add(d, "ch1.qmd")
  res <- g_gate(d)
  expect_false(res$ok)
  expect_true("data/y.csv" %in% res$excess$text[res$excess$rule == "file-link"])
})

test_that("4a G6, H5: a tracked _targets/ store is not materialised, and tar-name is not judged", {
  d <- g_repo(list("ch1.qmd" = G_PROSE, "_targets/meta/meta" = "not a real store"))
  g_write(d, "ch1.qmd", c(G_PROSE, "", "```{r chk-a}", "tar_read(zzz)", "```"))
  g_add(d)
  res <- g_gate(d)
  expect_false(any(res$excess$rule == "tar-name"))
  expect_false(any(res$errors$rule == "tar-name"))
  expect_false(any(res$added$rule == "tar-name"))
})

test_that("4a H5 [3c]: tar-name belongs to verify(): a typo against a real store the commit does not hold passes the gate", {
  skip_on_cran()
  skip_if_not_installed("targets")
  d <- g_repo(list("ch1.qmd" = G_PROSE))
  ok <- tryCatch({
    withr::with_dir(d, {
      targets::tar_script(list(targets::tar_target(fit, 1 + 1)), ask = FALSE)
      targets::tar_make(callr_function = NULL, reporter = "silent")
    })
    TRUE
  }, error = function(e) FALSE)
  if (!expect_precondition(ok, "the fixture built a targets store")) return(invisible())
  g_write(d, "ch1.qmd", c(G_PROSE, "", "```{r chk-a}", "tar_read(fitt)", "```"))
  g_add(d, "ch1.qmd")
  work <- lints(d, rules = "tar-name", tier = 1)             # the premise: the work tree's store flags it
  if (!expect_precondition("fitt" %in% work$text, "tar-name flags the typo against the store in the work tree")) return(invisible())
  res <- g_gate(d)
  expect_true(res$ok)
  expect_false(any(res$excess$rule == "tar-name"))
})

# ---- G7: projects ---------------------------------------------------------------------------------------------

test_that("4a G7: a repository with no _weft.yml passes with the note", {
  d <- g_scenario(list("ch1.qmd" = G_PROSE), list("ch1.qmd" = g_bad_doc()), weft = character())
  res <- g_gate(d)
  expect_true(res$ok)
  expect_true("no weft project (no _weft.yml)" %in% res$notes)
  expect_true("commit-msg: note: no weft project (no _weft.yml)" %in% g_report(res))
})

test_that("4a G7: a project in a subfolder is judged; paths are relative to the repository top", {
  d <- g_scenario(list("book/ch1.qmd" = G_PROSE), list("book/ch1.qmd" = g_num_doc("45%")), weft = "book")
  res <- g_gate(d)
  expect_false(res$ok)
  expect_identical(res$changed, "book/ch1.qmd")
  rep <- g_report(res)
  expect_true("  book/ch1.qmd" %in% rep)
  expect_true(all(grepl("book", res$excess$project)))
})

test_that("4a G7: files outside every project are not read", {
  d <- g_scenario(list("book/ch1.qmd" = G_PROSE, "notes/n.qmd" = G_PROSE),
                  list("book/ch1.qmd" = c(G_PROSE, "", "Edited."), "notes/n.qmd" = g_bad_doc()),
                  weft = "book")
  res <- g_gate(d)
  expect_true(res$ok)
  expect_identical(nrow(res$errors), 0L)
})

test_that("4a G7: two projects are judged each on its own", {
  d <- g_scenario(list("a/x.qmd" = G_PROSE, "b/y.qmd" = G_PROSE),
                  list("a/x.qmd" = g_num_doc("45%"), "b/y.qmd" = c(G_PROSE, "", "Edited.")),
                  weft = c("a", "b"))
  res <- g_gate(d)
  expect_false(res$ok)
  expect_identical(nrow(res$excess), 1L)
  expect_match(res$excess$project, "^a/?$")
  # the same finding in both projects is two keys, one per project
  g_write(d, "b/y.qmd", g_num_doc("45%"))
  g_add(d)
  res2 <- g_gate(d)
  expect_identical(nrow(res2$excess), 2L)
  expect_identical(length(unique(res2$excess$project)), 2L)
})

test_that("4a G7: a text in project a does not cancel the same text added in project b", {
  d <- g_scenario(list("a/x.qmd" = g_num_doc("45%"), "b/y.qmd" = G_PROSE),
                  list("a/x.qmd" = G_PROSE, "b/y.qmd" = g_num_doc("45%")), weft = c("a", "b"))
  res <- g_gate(d)
  expect_false(res$ok)
})

# ---- G3: nothing is written outside the cache and tempdir() ----------------------------------------------

test_that("4a G3: the gate writes nothing in the work tree or the git directory (but its cache) and leaves tempdir() as it was", {
  d <- g_scenario(list("ch1.qmd" = G_PROSE, "data/x.csv" = "a,b"),
                  list("ch1.qmd" = g_num_doc("45%"), "ch2.qmd" = g_bad_doc()))
  work <- g_snapshot(d)
  gitd <- g_git_snapshot(d)
  status <- g_ok_git(d, "status", "--porcelain")
  tmp_before <- sort(list.files(tempdir(), all.files = TRUE, no.. = TRUE))
  res <- g_gate(d)
  expect_s3_class(res, "weft_gate")
  expect_identical(g_snapshot(d), work)
  expect_identical(g_git_snapshot(d), gitd)
  expect_identical(g_ok_git(d, "status", "--porcelain"), status)
  expect_identical(sort(list.files(tempdir(), all.files = TRUE, no.. = TRUE)), tmp_before)
})
