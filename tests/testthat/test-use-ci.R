# 4b: use_ci() (G33, G40, G41, H23, F3). The workflow is written at the repository's top, even when
# the project is a subfolder; its text is the design's template with @PATH@, @VERSION@ and @HASH@
# filled.
#
# READINGS ASSUMED:
#   - the marker is the first line; the hash is the md5 of the other lines joined by "\n" (G40);
#   - a file with no marker (another author's) is left, with a message and no error, also under
#     overwrite = TRUE (G40: "never replaced");
#   - a second project writing its own @PATH@ over our unedited workflow replaces it (G40: ours,
#     unedited, text differs: `replace`);
#   - use_ci() needs a git work tree, not a GitHub origin (use_weft() decides on the origin).

wf <- function(dir) file.path(dir, ".github", "workflows", "weft.yml")
EDITED_MSG_CI <- "edited since weft wrote it; left as it is (use overwrite = TRUE to replace it)"

test_that("4b G33: the workflow at the top of a repository whose project is the top is the template with path '.'", {
  dir <- h4_repo()
  res <- h4_ci(dir)
  expect_identical(readLines(wf(dir)), h4_ci_expected("."))
  expect_identical(u4_rel(res, dir), ".github/workflows/weft.yml")
})

test_that("4b G33: use_ci() returns the paths written, invisibly", {
  dir <- h4_repo()
  suppressMessages(expect_invisible(weft::use_ci(dir)))
})

test_that("4b G40: the marker is line 1 and its hash is the md5 of the other lines joined by newlines", {
  dir <- h4_repo()
  h4_ci(dir)
  x <- readLines(wf(dir))
  m <- h4_marker(x)
  expect_identical(m$idx, 1L)
  expect_identical(m$fn, "use_ci")
  expect_identical(m$version, u4_version())
  expect_identical(m$hash, cli::hash_md5(paste(x[-1], collapse = "\n")))
})

test_that("4b G33: the workflow is ASCII, has no placeholder left, and installs weft from github::vorpalvorpal/clag (F3)", {
  dir <- h4_repo()
  h4_ci(dir)
  raw <- readBin(wf(dir), "raw", file.size(wf(dir)))
  expect_true(all(raw < as.raw(128)))
  x <- readLines(wf(dir))
  expect_false(any(grepl("@[A-Z]+@", x)))
  expect_true(any(grepl("packages: github::vorpalvorpal/clag", x, fixed = TRUE)))
})

test_that("4b G33: a project in a subfolder: the file is written at the repository's top with that folder as @PATH@, and nothing in the subfolder", {
  dir <- h4_repo(list(`book/ch1.qmd` = G_PROSE), weft = "book")
  res <- h4_ci(file.path(dir, "book"))
  expect_true(file.exists(wf(dir)))
  expect_identical(readLines(wf(dir)), h4_ci_expected("book"))
  expect_false(dir.exists(file.path(dir, "book", ".github")))
  expect_identical(u4_rel(res, dir), ".github/workflows/weft.yml")
})

test_that("4b G33: a project two folders down has the relative path with a slash as @PATH@", {
  dir <- h4_repo(list(`docs/book/ch1.qmd` = G_PROSE), weft = "docs/book")
  h4_ci(file.path(dir, "docs", "book"))
  expect_identical(readLines(wf(dir)), h4_ci_expected("docs/book"))
})

test_that("4b G41: it says what it will write before it writes, then what it wrote", {
  dir <- h4_repo()
  early <- NULL
  s <- h4_say(weft::use_ci(dir), first = function() early <<- file.exists(wf(dir)))
  expect_false(early)
  expect_match(s$text, "weft will write", fixed = TRUE)
  expect_match(s$text, ".github/workflows/weft.yml  (new: ", fixed = TRUE)
  expect_match(s$text, "Wrote: ", fixed = TRUE)
})

test_that("4b G41: silent under suppressMessages()", {
  dir <- h4_repo()
  expect_identical(utils::capture.output(suppressMessages(weft::use_ci(dir))), character())
})

test_that("4b G33: a second run changes nothing and says so", {
  dir <- h4_repo()
  h4_ci(dir)
  before <- h4_snap_repo(dir)
  s <- h4_say(weft::use_ci(dir))
  expect_match(s$text, "Nothing to change", fixed = TRUE)
  expect_identical(s$value, character())
  expect_identical(h4_snap_repo(dir), before)
})

test_that("4b G40: our unedited workflow whose text would differ is replaced", {
  dir <- h4_repo(list(`book/ch1.qmd` = G_PROSE), weft = c(".", "book"))
  h4_ci(dir)
  s <- h4_say(weft::use_ci(file.path(dir, "book")))
  expect_identical(readLines(wf(dir)), h4_ci_expected("book"))
  expect_match(s$text, "(replace: ", fixed = TRUE)
})

test_that("4b G40: a workflow from an older template (marker and hash valid) is replaced without overwrite", {
  dir <- h4_repo()
  old <- h4_forge(h4_ci_expected("."), function(b) sub("fetch-depth: 0", "fetch-depth: 1", b, fixed = TRUE))
  expect_true(h4_marker_valid(old))
  f3_write(wf(dir), old)
  h4_ci(dir)
  expect_identical(readLines(wf(dir)), h4_ci_expected("."))
})

test_that("4b G40: an edited workflow is left as it is with the message; overwrite = TRUE replaces it", {
  dir <- h4_repo()
  h4_ci(dir)
  edited <- c(readLines(wf(dir)), "# mine")
  writeLines(edited, wf(dir))
  s <- h4_say(weft::use_ci(dir))
  expect_identical(readLines(wf(dir)), edited)
  expect_match(s$text, EDITED_MSG_CI, fixed = TRUE)
  expect_identical(s$value, character())
  res <- h4_ci(dir, overwrite = TRUE)
  expect_identical(readLines(wf(dir)), h4_ci_expected("."))
  expect_identical(u4_rel(res, dir), ".github/workflows/weft.yml")
})

test_that("4b G40: an existing workflow with no weft-file marker (someone else's) is never replaced, with or without overwrite, and is not an error", {
  dir <- h4_repo()
  mine <- c("name: weft", "on: [push]", "jobs: {}")
  f3_write(wf(dir), mine)
  s <- h4_say(weft::use_ci(dir))
  expect_identical(readLines(wf(dir)), mine)
  expect_identical(s$value, character())
  expect_true(nzchar(s$text))
  suppressMessages(weft::use_ci(dir, overwrite = TRUE))
  expect_identical(readLines(wf(dir)), mine)
})

test_that("4b G41: a folder in the workflow's place is a weft_tool_error naming the path, and nothing is written", {
  dir <- h4_repo()
  dir.create(wf(dir), recursive = TRUE)
  writeLines("x", file.path(wf(dir), "keep.txt"))
  before <- h4_snap_repo(dir)
  err <- tryCatch(suppressMessages(weft::use_ci(dir)), error = function(e) e)
  expect_s3_class(err, "weft_tool_error")
  expect_match(conditionMessage(err), "weft.yml", fixed = TRUE)
  expect_identical(h4_snap_repo(dir), before)
})

test_that("4b G41: a symbolic link in the workflow's place is a weft_tool_error, and its target is untouched", {
  skip_on_os("windows")
  dir <- h4_repo()
  target <- tempfile("h4-target-"); writeLines("name: other", target)
  dir.create(dirname(wf(dir)), recursive = TRUE)
  file.symlink(target, wf(dir))
  before <- unname(tools::md5sum(target))
  err <- tryCatch(suppressMessages(weft::use_ci(dir, overwrite = TRUE)), error = function(e) e)
  expect_s3_class(err, "weft_tool_error")
  expect_match(conditionMessage(err), "weft.yml", fixed = TRUE)
  expect_identical(unname(tools::md5sum(target)), before)
})

test_that("4b G33: not in a git work tree is a weft_tool_error, and nothing is written", {
  d <- u4_dir(list(`_weft.yml` = "draft: false"))
  before <- h4_snap(d)
  err <- tryCatch(suppressMessages(weft::use_ci(d)), error = function(e) e)
  expect_s3_class(err, "weft_tool_error")
  expect_s3_class(err, "weft_error")
  expect_identical(h4_snap(d), before)
})

test_that("4b G3: use_ci() writes only the workflow: nothing in HOME, the cache folder or the repository's parent, nothing else in the repository", {
  rp <- h4_repo_in_parent()
  before <- h4_outside_snap(rp$parent)
  before_repo <- h4_snap_repo(rp$dir)
  h4_ci(rp$dir)
  h4_ci(rp$dir)
  expect_identical(h4_outside_snap(rp$parent), before)
  after <- h4_snap_repo(rp$dir)
  expect_setequal(setdiff(names(after), names(before_repo)),
                  c(".github", ".github/workflows", ".github/workflows/weft.yml"))
  expect_identical(after[names(before_repo)], before_repo)
})
