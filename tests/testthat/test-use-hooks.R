# 4b: use_hooks() (G22, G21, G40, G41, H11, H12, H24, H31, H33). What it writes, where, what it says
# and returns. No commit runs here (test-hook-commit.R runs real commits). Every write is in a temporary
# repository; the HOME folder, the cache folder and the repository's parent are checked at the end.
#
# READINGS ASSUMED (the design is silent or ambiguous):
#   - the hook's marker is line 2; the hash is md5 of the other lines joined by "\n" (G40);
#   - when use_hooks() leaves a foreign hook it returns the path of the script copy it wrote;
#   - a foreign hook is left alone even with overwrite = TRUE (G40: no marker, never replaced);
#   - a hook manager is a foreign hook in .git/hooks or any core.hooksPath (G22);
#   - weft's printed state words are G41's `new`, `keep`, `replace`, `edited`.

hooks_path <- function(dir) h4_hook_path(dir)
copy_path <- function(dir) file.path(h4_common_dir(dir), "weft", "commit-msg")
ADVICE_1 <- "Add this line to the commit-msg hook your setup runs:"
ADVICE_2 <- "  sh \"$(git rev-parse --git-common-dir)/weft/commit-msg\" \"$1\""
EDITED_MSG <- "edited since weft wrote it; left as it is (use overwrite = TRUE to replace it)"

test_that("4b G21: a fresh install writes the filled template to .git/hooks/commit-msg", {
  dir <- h4_repo()
  res <- h4_hooks(dir)
  expect_true(file.exists(hooks_path(dir)))
  expect_identical(readLines(hooks_path(dir)), h4_hook_expected())
  expect_identical(u4_rel(res, dir), ".git/hooks/commit-msg")
})

test_that("4b G22: use_hooks() returns the paths it wrote, invisibly", {
  dir <- h4_repo()
  suppressMessages(expect_invisible(weft::use_hooks(dir, lib = h4_lib())))
})

test_that("4b G21: the marker is line 2 and its hash is the md5 of the other lines joined by newlines (G40)", {
  dir <- h4_repo()
  h4_hooks(dir)
  x <- readLines(hooks_path(dir))
  expect_identical(x[1], "#!/bin/sh")
  m <- h4_marker(x)
  expect_identical(m$idx, 2L)
  expect_identical(m$fn, "use_hooks")
  expect_identical(m$version, u4_version())
  expect_identical(m$hash, cli::hash_md5(paste(x[-2], collapse = "\n")))
})

test_that("4b G21: the script is ASCII, has no placeholder left, and ends in a newline", {
  dir <- h4_repo()
  h4_hooks(dir)
  raw <- readBin(hooks_path(dir), "raw", file.size(hooks_path(dir)))
  expect_true(all(raw < as.raw(128)))
  expect_false(any(grepl("@[A-Z]+@", readLines(hooks_path(dir)))))
  expect_identical(raw[length(raw)], as.raw(10))
})

test_that("4b G22: the hook is executable (mode 755)", {
  skip_on_os("windows")
  dir <- h4_repo()
  h4_hooks(dir)
  expect_identical(as.character(file.info(hooks_path(dir))$mode), "755")
})

test_that("4b G21: rscript defaults to R.home('bin')/Rscript and lib to the libraries given, joined by the path separator", {
  dir <- h4_repo()
  h4_hooks(dir)
  x <- readLines(hooks_path(dir))
  expect_true(paste0("weft_rscript='", file.path(R.home("bin"), "Rscript"), "'") %in% x)
  expect_true(paste0("weft_libs='", paste(h4_lib(), collapse = .Platform$path.sep), "'") %in% x)
})

test_that("4b G21: an explicit rscript is the one recorded", {
  dir <- h4_repo()
  rs <- file.path(withr::local_tempdir(), "Rscript")
  h4_hooks(dir, rscript = rs)
  expect_identical(readLines(hooks_path(dir)), h4_hook_expected(rscript = rs))
})

test_that("4b G21: a single quote in a recorded value is written as '\\''", {
  dir <- h4_repo()
  qdir <- file.path(withr::local_tempdir(), "it's a lib")
  dir.create(qdir)
  lib <- c(qdir, h4_lib())
  h4_hooks(dir, lib = lib)
  x <- readLines(hooks_path(dir))
  expect_identical(x, h4_hook_expected(lib = lib))
  expect_true(any(grepl("it'\\''s a lib", x, fixed = TRUE)))
})

test_that("4b G41: it says what it will write before it writes, then what it wrote", {
  dir <- h4_repo()
  early <- NULL
  s <- h4_say(weft::use_hooks(dir, lib = h4_lib()), first = function() early <<- file.exists(hooks_path(dir)))
  expect_false(early)
  expect_match(s$text, "weft will write", fixed = TRUE)
  expect_match(s$text, "commit-msg  \\(new: ")
  expect_match(s$text, "Wrote: ")
  expect_match(s$text, "commit-msg", fixed = TRUE)
})

test_that("4b G41: silent under suppressMessages()", {
  dir <- h4_repo()
  out <- utils::capture.output(suppressMessages(weft::use_hooks(dir, lib = h4_lib())))
  expect_identical(out, character())
})

test_that("4b G22: a second run changes nothing and says so", {
  dir <- h4_repo()
  h4_hooks(dir)
  before <- h4_snap_repo(dir)
  s <- h4_say(weft::use_hooks(dir, lib = h4_lib()))
  expect_match(s$text, "Nothing to change", fixed = TRUE)
  expect_match(s$text, "commit-msg  \\(keep: ")
  expect_identical(s$value, character())
  expect_identical(h4_snap_repo(dir), before)
})

test_that("4b G22: a changed rscript rewrites our unedited hook", {
  dir <- h4_repo()
  h4_hooks(dir)
  rs <- file.path(withr::local_tempdir(), "Rscript")
  s <- h4_say(weft::use_hooks(dir, rscript = rs, lib = h4_lib()))
  expect_identical(readLines(hooks_path(dir)), h4_hook_expected(rscript = rs))
  expect_match(s$text, "commit-msg  \\(replace: ")
  expect_identical(u4_rel(s$value, dir), ".git/hooks/commit-msg")
})

test_that("4b G22: a changed lib rewrites our unedited hook", {
  dir <- h4_repo()
  h4_hooks(dir)
  extra <- withr::local_tempdir()
  lib <- c(h4_lib(), extra)
  h4_hooks(dir, lib = lib)
  expect_identical(readLines(hooks_path(dir)), h4_hook_expected(lib = lib))
})

test_that("4b G22/G40: a hook from an older template (marker and hash valid) is replaced without overwrite", {
  dir <- h4_repo()
  old <- h4_forge(h4_hook_expected(), function(b) sub("rules 6.1 to 6.3", "rules 6.1 to 6.2", b, fixed = TRUE))
  expect_true(h4_marker_valid(old))
  writeLines(old, hooks_path(dir))
  Sys.chmod(hooks_path(dir), "755")
  h4_hooks(dir)
  expect_identical(readLines(hooks_path(dir)), h4_hook_expected())
})

test_that("4b G40: an edited hook is left as it is, with the message, and nothing is returned", {
  dir <- h4_repo()
  h4_hooks(dir)
  edited <- c(readLines(hooks_path(dir)), "# my own note")
  writeLines(edited, hooks_path(dir))
  before <- unname(tools::md5sum(hooks_path(dir)))
  s <- h4_say(weft::use_hooks(dir, lib = h4_lib()))
  expect_identical(unname(tools::md5sum(hooks_path(dir))), before)
  expect_match(s$text, EDITED_MSG, fixed = TRUE)
  expect_identical(s$value, character())
})

test_that("4b G40: an edited hook is replaced with overwrite = TRUE", {
  dir <- h4_repo()
  h4_hooks(dir)
  writeLines(c(readLines(hooks_path(dir)), "# my own note"), hooks_path(dir))
  res <- h4_hooks(dir, overwrite = TRUE)
  expect_identical(readLines(hooks_path(dir)), h4_hook_expected())
  expect_identical(u4_rel(res, dir), ".git/hooks/commit-msg")
})

test_that("4b G40: a hook whose marker was altered (hash mismatch) counts as edited", {
  dir <- h4_repo()
  h4_hooks(dir)
  x <- readLines(hooks_path(dir))
  x[2] <- sub("[0-9a-f]{32}", strrep("0", 32), x[2])
  writeLines(x, hooks_path(dir))
  s <- h4_say(weft::use_hooks(dir, lib = h4_lib()))
  expect_identical(readLines(hooks_path(dir)), x)
  expect_match(s$text, EDITED_MSG, fixed = TRUE)
})

# ---- another tool's hook, hook managers (G22, H12) ----------------------------------------------

test_that("4b G22: a hook written by someone else is never overwritten, even with overwrite = TRUE", {
  dir <- h4_repo()
  writeLines(H4_FOREIGN_HOOK, hooks_path(dir))
  before <- unname(tools::md5sum(hooks_path(dir)))
  h4_hooks(dir)
  h4_hooks(dir, overwrite = TRUE)
  expect_identical(unname(tools::md5sum(hooks_path(dir))), before)
  expect_identical(readLines(hooks_path(dir)), H4_FOREIGN_HOOK)
})

test_that("4b G22: beside a foreign hook the script goes to <git common dir>/weft/commit-msg, the line to add is printed, and the copy's path is returned", {
  dir <- h4_repo()
  writeLines(H4_FOREIGN_HOOK, hooks_path(dir))
  s <- h4_say(weft::use_hooks(dir, lib = h4_lib()))
  expect_true(file.exists(copy_path(dir)))
  expect_identical(readLines(copy_path(dir)), h4_hook_expected())
  expect_true(ADVICE_1 %in% s$lines)
  expect_true(ADVICE_2 %in% s$lines)
  expect_identical(u4_rel(s$value, dir), ".git/weft/commit-msg")
})

test_that("4b G22: a foreign hook with no .pre-commit-config.yaml gets no pre-commit entry", {
  dir <- h4_repo()
  writeLines(H4_FOREIGN_HOOK, hooks_path(dir))
  s <- h4_say(weft::use_hooks(dir, lib = h4_lib()))
  expect_false(grepl("repo: local", s$text, fixed = TRUE))
})

test_that("4b G22: with .pre-commit-config.yaml the pre-commit repo: local entry is printed too", {
  dir <- h4_repo(list(`.pre-commit-config.yaml` = "repos: []"))
  writeLines(H4_PRECOMMIT_HOOK, hooks_path(dir))
  s <- h4_say(weft::use_hooks(dir, lib = h4_lib()))
  expect_true(ADVICE_1 %in% s$lines)
  expect_true(ADVICE_2 %in% s$lines)
  expect_match(s$text, "repo: local", fixed = TRUE)
  # review-4 #17: `.git` is a file in a linked worktree, so the entry asks git for the common directory
  expect_match(s$text, "entry: sh -c 'sh \"$(git rev-parse --git-common-dir)/weft/commit-msg\" \"$1\"' weft", fixed = TRUE)
  expect_false(grepl("entry: sh .git/weft/commit-msg", s$text, fixed = TRUE))
  expect_match(s$text, "language: system", fixed = TRUE)
  expect_match(s$text, "stages: [commit-msg]", fixed = TRUE)
  expect_identical(readLines(hooks_path(dir)), H4_PRECOMMIT_HOOK)
  expect_identical(readLines(copy_path(dir)), h4_hook_expected())
})

test_that("4b G22: a lefthook-style hook in .git/hooks is another tool's and is left", {
  dir <- h4_repo()
  lh <- c("#!/bin/sh", "# LEFTHOOK_VERSION=1.5.0", "call_lefthook commit-msg \"$@\"")
  writeLines(lh, hooks_path(dir))
  s <- h4_say(weft::use_hooks(dir, lib = h4_lib()))
  expect_identical(readLines(hooks_path(dir)), lh)
  expect_true(ADVICE_2 %in% s$lines)
})

test_that("4b G22: core.hooksPath set (husky): the hooks folder it names is not touched, the script goes beside the cache, the line is printed", {
  dir <- h4_repo()
  husky <- file.path(dir, ".husky", "_")
  dir.create(husky, recursive = TRUE)
  writeLines(c("#!/bin/sh", ". \"$(dirname \"$0\")/h\""), file.path(husky, "commit-msg"))
  g_ok_git(dir, "config", "core.hooksPath", ".husky/_")
  before <- h4_snap(file.path(dir, ".husky"))
  s <- h4_say(weft::use_hooks(dir, lib = h4_lib()))
  expect_identical(h4_snap(file.path(dir, ".husky")), before)
  expect_false(file.exists(hooks_path(dir)))
  expect_identical(readLines(copy_path(dir)), h4_hook_expected())
  expect_true(ADVICE_1 %in% s$lines)
  expect_true(ADVICE_2 %in% s$lines)
})

test_that("4b G22: core.hooksPath set to a folder with no commit-msg is still a hook manager: nothing is written there", {
  dir <- h4_repo()
  hp <- file.path(dir, "my-hooks")
  dir.create(hp)
  g_ok_git(dir, "config", "core.hooksPath", "my-hooks")
  s <- h4_say(weft::use_hooks(dir, lib = h4_lib()))
  expect_identical(list.files(hp, all.files = TRUE, no.. = TRUE), character())
  expect_false(file.exists(hooks_path(dir)))
  expect_true(file.exists(copy_path(dir)))
  expect_true(ADVICE_2 %in% s$lines)
})

test_that("4b G22: no error is raised for a foreign hook (it is left, not refused)", {
  dir <- h4_repo()
  writeLines(H4_FOREIGN_HOOK, hooks_path(dir))
  expect_no_error(suppressMessages(weft::use_hooks(dir, lib = h4_lib())))
})

# ---- remove --------------------------------------------------------------------------------------

test_that("4b G22: remove = TRUE deletes our hook and <git common dir>/weft/ (script copy and cache)", {
  dir <- h4_repo()
  h4_hooks(dir)
  cdir <- file.path(h4_common_dir(dir), "weft", "cache")
  dir.create(cdir, recursive = TRUE)
  writeLines("x", file.path(cdir, "entry"))
  h4_hooks(dir, remove = TRUE)
  expect_false(file.exists(hooks_path(dir)))
  expect_false(dir.exists(file.path(h4_common_dir(dir), "weft")))
})

test_that("4b G22: remove = TRUE deletes our hook even when it was edited", {
  dir <- h4_repo()
  h4_hooks(dir)
  writeLines(c(readLines(hooks_path(dir)), "# mine"), hooks_path(dir))
  h4_hooks(dir, remove = TRUE)
  expect_false(file.exists(hooks_path(dir)))
})

test_that("4b G22: remove = TRUE leaves a foreign hook and says to remove the weft line from it", {
  dir <- h4_repo()
  writeLines(H4_FOREIGN_HOOK, hooks_path(dir))
  h4_hooks(dir)
  s <- h4_say(weft::use_hooks(dir, remove = TRUE, lib = h4_lib()))
  expect_identical(readLines(hooks_path(dir)), H4_FOREIGN_HOOK)
  expect_match(s$text, "remove the weft line", ignore.case = TRUE)
  expect_false(dir.exists(file.path(h4_common_dir(dir), "weft")))
})

test_that("4b G22: remove = TRUE with no hook installed is not an error", {
  dir <- h4_repo()
  expect_no_error(suppressMessages(weft::use_hooks(dir, remove = TRUE, lib = h4_lib())))
  expect_false(file.exists(hooks_path(dir)))
})

# ---- where it is written -------------------------------------------------------------------------

test_that("4b G22: in a linked worktree the hook goes to the hooks folder git reports (the main repository's)", {
  dir <- h4_repo()
  wt <- file.path(withr::local_tempdir(), "wt")
  g_ok_git(dir, "worktree", "add", "-q", "-b", "wt-branch", wt)
  wt <- normalizePath(wt)
  expect_true(file.exists(file.path(wt, "_weft.yml")))
  res <- h4_hooks(wt)
  want <- file.path(h4_git_path(wt, "hooks"), "commit-msg")
  expect_true(file.exists(want))
  expect_identical(readLines(want), h4_hook_expected())
  expect_identical(normalizePath(want), normalizePath(file.path(dir, ".git", "hooks", "commit-msg")))
  expect_identical(normalizePath(res), normalizePath(want))
})

test_that("4b G22/H33: a project in a subfolder of the repository still gets the one hook in the repository's git directory", {
  dir <- h4_repo(list(`book/ch1.qmd` = G_PROSE), weft = "book")
  h4_hooks(file.path(dir, "book"))
  expect_true(file.exists(hooks_path(dir)))
  expect_false(file.exists(file.path(dir, "book", ".git")))
})

# ---- refusals ------------------------------------------------------------------------------------

test_that("4b G22: not in a git work tree is a weft_tool_error, and nothing is written", {
  d <- u4_dir(list(`_weft.yml` = "draft: false"))
  before <- h4_snap(d)
  err <- tryCatch(suppressMessages(weft::use_hooks(d, lib = h4_lib())), error = function(e) e)
  expect_s3_class(err, "weft_tool_error")
  expect_s3_class(err, "weft_error")
  expect_identical(h4_snap(d), before)
})

test_that("4b G22: a folder with no _weft.yml is a weft_tool_error with the design's text, and nothing is written", {
  dir <- h4_repo(weft = character())
  before <- h4_snap_repo(dir)
  err <- tryCatch(suppressMessages(weft::use_hooks(dir, lib = h4_lib())), error = function(e) e)
  expect_s3_class(err, "weft_tool_error")
  expect_match(conditionMessage(err),
               "use_hooks() guards a weft project, a folder holding _weft.yml;", fixed = TRUE)
  expect_match(conditionMessage(err), "Run use_weft() first (rule 6.1.1).", fixed = TRUE)
  expect_identical(h4_snap_repo(dir), before)
})

test_that("4b G22: weft not found in lib is a weft_tool_error naming the libraries, and nothing is written", {
  dir <- h4_repo()
  empty <- normalizePath(withr::local_tempdir())
  before <- h4_snap_repo(dir)
  err <- tryCatch(suppressMessages(weft::use_hooks(dir, lib = empty)), error = function(e) e)
  expect_s3_class(err, "weft_tool_error")
  expect_match(conditionMessage(err), empty, fixed = TRUE)
  expect_identical(h4_snap_repo(dir), before)
})

test_that("4b G22: git not on the PATH is a weft_tool_error", {
  dir <- h4_repo()
  nogit <- withr::local_tempdir()
  err <- withr::with_envvar(c(PATH = nogit),
    tryCatch(suppressMessages(weft::use_hooks(dir, lib = h4_lib())), error = function(e) e))
  expect_s3_class(err, "weft_tool_error")
  expect_false(file.exists(hooks_path(dir)))
})

# ---- nothing outside -----------------------------------------------------------------------------

test_that("4b G3: use_hooks() writes nothing in HOME, the cache folder or the repository's parent", {
  rp <- h4_repo_in_parent()
  before <- h4_outside_snap(rp$parent)
  h4_hooks(rp$dir)
  h4_hooks(rp$dir)
  h4_hooks(rp$dir, remove = TRUE)
  expect_identical(h4_outside_snap(rp$parent), before)
})

test_that("4b G3: use_hooks() with a foreign hook writes nothing in HOME, the cache folder or the parent either", {
  rp <- h4_repo_in_parent()
  writeLines(H4_FOREIGN_HOOK, hooks_path(rp$dir))
  before <- h4_outside_snap(rp$parent)
  h4_hooks(rp$dir)
  expect_identical(h4_outside_snap(rp$parent), before)
})
