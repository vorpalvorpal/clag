# 4b: use_weft() (G38, G41, H26, G32, H35). The plan, the order, that it never asks, that it writes
# nothing when any step would fail, the version line, the return value.
#
# use_weft() calls use_hooks(), which looks for weft in the library path; under pkgload the working
# tree is not in one, so these tests put the test library first on .libPaths() (h4_weft()).
#
# READINGS ASSUMED:
#   - the plan is printed as messages: the header `weft will set up <root>:`, then one line per step
#     in the order use_setup, use_quarto (Quarto project only), use_dictionary, use_hooks, use_ci,
#     use_agent_docs, each `sprintf("  %-15s %s", fn, what)`;
#   - for a project that is not a Quarto project the use_quarto line is either absent or starts with
#     `skipped`;
#   - no git: use_hooks says `skipped: not a git repository` and use_ci a `skipped: ` line (its text
#     is G38's `origin is not on GitHub` or the git one);
#   - the return value is the character vector of every path written (absolute or relative to the root);
#   - a step that cannot be done stops the whole call with that step's weft_tool_error, with the
#     repository (outside the git index) byte-identical;
#   - an unrecorded or older `weft_version` line is set to the installed version in place.

GH <- "https://github.com/example-org/example-repo.git"
uw_repo <- function(files = list(`index.qmd` = u4_qmd()), origin = GH, env = parent.frame()) {
  h4_repo(files, weft = character(), origin = origin, env = env)
}
uw_plan_lines <- function(s) s$lines[grepl("^  use_[a-z_]+ ", s$lines)]
uw_fn <- function(lines, fn) lines[grepl(paste0("^  ", fn, " "), lines)]

test_that("4b G38: the plan has the header and one line per step, in the design's order", {
  dir <- uw_repo()
  withr::local_libpaths(h4_lib(), action = "prefix")
  s <- h4_say(weft::use_weft(dir))
  expect_true(paste0("weft will set up ", dir, ":") %in% s$lines)
  plan <- uw_plan_lines(s)
  fns <- sub("^  (use_[a-z_]+) .*$", "\\1", plan)
  fns <- fns[fns != "use_quarto"]
  expect_identical(fns, c("use_setup", "use_dictionary", "use_hooks", "use_ci", "use_agent_docs"))
  # each line is "  %-15s %s"
  expect_true(all(grepl("^  use_[a-z_]+ +\\S", plan)))
  expect_true(all(substr(plan, 19L, 19L) != " "))
})

test_that("4b G38: the summary is printed before anything is written", {
  dir <- uw_repo()
  withr::local_libpaths(h4_lib(), action = "prefix")
  early <- NULL
  h4_say(weft::use_weft(dir), first = function() {
    early <<- c(weft_yml = file.exists(file.path(dir, "_weft.yml")),
                dict = file.exists(file.path(dir, "dict.yml")),
                hook = file.exists(h4_hook_path(dir)),
                ci = file.exists(file.path(dir, ".github")),
                agents = file.exists(file.path(dir, "AGENTS.md")))
  })
  expect_false(any(early))
})

test_that("4b G38: a git project with a GitHub origin gets every step: the files are there", {
  dir <- uw_repo()
  res <- h4_weft(dir)
  expect_true(file.exists(file.path(dir, "_weft.yml")))
  # the front-matter route (no Quarto project): the document is activated
  expect_true(any(grepl("weft::weft_setup()", u4_read(dir, "index.qmd"), fixed = TRUE)))
  expect_true(file.exists(file.path(dir, "dict.yml")))
  expect_true(file.exists(file.path(dir, "_weft", "dict.schema.json")))
  expect_identical(readLines(h4_hook_path(dir)), h4_hook_expected(lib = .libPaths()))
  expect_identical(readLines(file.path(dir, ".github", "workflows", "weft.yml")), h4_ci_expected("."))
  expect_true(file.exists(file.path(dir, "AGENTS.md")))
  expect_true(file.exists(file.path(dir, ".agents", "skills", "weft", "SKILL.md")))
  rel <- u4_rel(res, dir)
  expect_true(all(c("_weft.yml", "dict.yml", "AGENTS.md", ".github/workflows/weft.yml",
                    ".agents/skills/weft/SKILL.md", ".git/hooks/commit-msg") %in% rel))
})

test_that("4b G38: use_weft() returns the paths written, invisibly", {
  dir <- uw_repo()
  withr::local_libpaths(h4_lib(), action = "prefix")
  suppressMessages(expect_invisible(weft::use_weft(dir)))
})

test_that("4b G38: a Quarto project also gets use_quarto's files and the .Rprofile route", {
  dir <- uw_repo(list(`_quarto.yml` = U4_QUARTO_YML, `index.qmd` = u4_qmd()))
  withr::local_libpaths(h4_lib(), action = "prefix")
  s <- h4_say(weft::use_weft(dir))
  fns <- sub("^  (use_[a-z_]+) .*$", "\\1", uw_plan_lines(s))
  expect_identical(fns, c("use_setup", "use_quarto", "use_dictionary", "use_hooks", "use_ci", "use_agent_docs"))
  expect_true(file.exists(file.path(dir, "_extensions", "weft-check", "weft-check.lua")))
  expect_true(file.exists(file.path(dir, "_weft", "pre-render.R")))
  expect_identical(u4_read(dir, ".Rprofile"), U4_RPROFILE)
})

test_that("4b G38: a project that is not a Quarto project does not get the Quarto files", {
  dir <- uw_repo()
  h4_weft(dir)
  expect_false(dir.exists(file.path(dir, "_extensions")))
  expect_false(file.exists(file.path(dir, "_weft", "pre-render.R")))
})

test_that("4b G38: not a git repository: use_hooks is skipped with the design's reason, use_ci is skipped, the rest is written", {
  d <- u4_dir(list(`index.qmd` = u4_qmd()))
  git_env()
  h4_env()
  withr::local_libpaths(h4_lib(), action = "prefix")
  s <- h4_say(weft::use_weft(d))
  expect_true(sprintf("  %-15s %s", "use_hooks", "skipped: not a git repository") %in% s$lines)
  expect_match(uw_fn(s$lines, "use_ci"), "^  use_ci +skipped: ")
  expect_false(dir.exists(file.path(d, ".github")))
  expect_false(dir.exists(file.path(d, ".git")))
  expect_true(file.exists(file.path(d, "_weft.yml")))
  expect_true(file.exists(file.path(d, "dict.yml")))
  expect_true(file.exists(file.path(d, "AGENTS.md")))
})

test_that("4b G38: an origin that is not on GitHub: use_ci is skipped with the design's reason, the hook is installed", {
  dir <- uw_repo(origin = "https://git.example.invalid/example-org/example-repo.git")
  withr::local_libpaths(h4_lib(), action = "prefix")
  s <- h4_say(weft::use_weft(dir))
  expect_true(sprintf("  %-15s %s", "use_ci", "skipped: origin is not on GitHub") %in% s$lines)
  expect_false(dir.exists(file.path(dir, ".github")))
  expect_true(file.exists(h4_hook_path(dir)))
})

test_that("4b G38: no origin at all: use_ci is skipped", {
  dir <- uw_repo(origin = NULL)
  withr::local_libpaths(h4_lib(), action = "prefix")
  s <- h4_say(weft::use_weft(dir))
  expect_match(uw_fn(s$lines, "use_ci"), "^  use_ci +skipped: ")
  expect_false(dir.exists(file.path(dir, ".github")))
})

test_that("4b G38: an ssh GitHub origin counts as on GitHub", {
  dir <- uw_repo(origin = "git@github.com:example-org/example-repo.git")
  h4_weft(dir)
  expect_true(file.exists(file.path(dir, ".github", "workflows", "weft.yml")))
})

test_that("4b G38: the weft_version line is set to the installed version", {
  dir <- uw_repo()
  h4_weft(dir)
  x <- u4_read(dir, "_weft.yml")
  expect_true(any(grepl(paste0("^weft_version:\\s*[\"']?", u4_version(), "[\"']?\\s*$"), x)))
  expect_identical(sum(grepl("^weft_version:", x)), 1L)
})

test_that("4b G32/G38: an older weft_version line is updated in place, the author's other lines kept in order", {
  dir <- uw_repo(list(`index.qmd` = u4_qmd(),
                      `_weft.yml` = c("draft: false", "weft_version: 0.0.0.1", "label_words: [Station]")))
  h4_weft(dir)
  x <- u4_read(dir, "_weft.yml")
  expect_identical(x[1], "draft: false")
  expect_match(x[2], paste0("^weft_version:\\s*[\"']?", u4_version()), perl = TRUE)
  expect_identical(x[3], "label_words: [Station]")
  expect_length(x, 3L)
})

test_that("4b G32/G38: an _weft.yml with no weft_version line gets one, the author's lines kept", {
  dir <- uw_repo(list(`index.qmd` = u4_qmd(), `_weft.yml` = c("draft: false", "label_words: [Station]")))
  h4_weft(dir)
  x <- u4_read(dir, "_weft.yml")
  expect_true(all(c("draft: false", "label_words: [Station]") %in% x))
  expect_identical(sum(grepl("^weft_version:", x)), 1L)
})

test_that("4b H26/G38: it never asks, with the session interactive", {
  dir <- uw_repo()
  withr::local_libpaths(h4_lib(), action = "prefix")
  withr::local_options(rlang_interactive = TRUE)
  asked <- FALSE
  testthat::local_mocked_bindings(
    menu = function(...) { asked <<- TRUE; 1L },
    askYesNo = function(...) { asked <<- TRUE; TRUE },
    .package = "utils")
  expect_no_error(suppressMessages(weft::use_weft(dir)))
  expect_false(asked)
  expect_true(file.exists(file.path(dir, "AGENTS.md")))
})

test_that("4b H26/G38: it never asks, with the session non-interactive either", {
  dir <- uw_repo()
  withr::local_libpaths(h4_lib(), action = "prefix")
  withr::local_options(rlang_interactive = FALSE)
  expect_no_error(suppressMessages(weft::use_weft(dir)))
  expect_true(file.exists(file.path(dir, "AGENTS.md")))
})

# ---- all or nothing ------------------------------------------------------------------------------

test_that("4b G38: when use_setup() cannot edit a document nothing at all is written, and the step's message is the error", {
  dir <- uw_repo(list(
    `ok.qmd` = u4_qmd(),
    `flow.qmd` = c("---", "title: f", "knitr: {opts_chunk: {echo: false}}", "---", "", "x")))
  withr::local_libpaths(h4_lib(), action = "prefix")
  before <- h4_snap_repo(dir)
  err <- tryCatch(suppressMessages(weft::use_weft(dir)), error = function(e) e)
  expect_s3_class(err, "weft_tool_error")
  expect_match(conditionMessage(err), "weft: !expr weft::weft_setup()", fixed = TRUE)
  expect_identical(h4_snap_repo(dir), before)
})

test_that("4b G38/G41: a folder in the workflow's place stops the call before any other step writes", {
  dir <- uw_repo()
  wfd <- file.path(dir, ".github", "workflows", "weft.yml")
  dir.create(wfd, recursive = TRUE)
  writeLines("x", file.path(wfd, "keep.txt"))
  withr::local_libpaths(h4_lib(), action = "prefix")
  before <- h4_snap_repo(dir)
  err <- tryCatch(suppressMessages(weft::use_weft(dir)), error = function(e) e)
  expect_s3_class(err, "weft_tool_error")
  expect_match(conditionMessage(err), "weft.yml", fixed = TRUE)
  expect_identical(h4_snap_repo(dir), before)
})

test_that("4b G38/G41: a symbolic link in AGENTS.md's place stops the call before any other step writes", {
  skip_on_os("windows")
  dir <- uw_repo()
  target <- tempfile("h4-target-"); writeLines("# elsewhere", target)
  file.symlink(target, file.path(dir, "AGENTS.md"))
  withr::local_libpaths(h4_lib(), action = "prefix")
  before <- h4_snap_repo(dir)
  err <- tryCatch(suppressMessages(weft::use_weft(dir)), error = function(e) e)
  expect_s3_class(err, "weft_tool_error")
  expect_identical(h4_snap_repo(dir), before)
  expect_false(file.exists(file.path(dir, "_weft.yml")))
})

# ---- second run, other tools' hooks, nothing outside ---------------------------------------------

test_that("4b G38: a second run changes nothing and returns no paths", {
  dir <- uw_repo()
  h4_weft(dir)
  before <- h4_snap_repo(dir)
  res <- h4_weft(dir)
  expect_identical(h4_snap_repo(dir), before)
  expect_identical(as.character(res), character())
})

test_that("4b G12/G38: a foreign commit-msg hook is left, the advice is printed, the other steps still run", {
  dir <- uw_repo()
  writeLines(H4_FOREIGN_HOOK, h4_hook_path(dir))
  withr::local_libpaths(h4_lib(), action = "prefix")
  s <- h4_say(weft::use_weft(dir))
  expect_identical(readLines(h4_hook_path(dir)), H4_FOREIGN_HOOK)
  expect_true("  sh \"$(git rev-parse --git-common-dir)/weft/commit-msg\" \"$1\"" %in% s$lines)
  expect_true(file.exists(file.path(dir, "AGENTS.md")))
})

test_that("4b G3: use_weft() writes nothing in HOME, the cache folder or the repository's parent", {
  rp <- h4_repo_in_parent(list(`index.qmd` = u4_qmd()))
  unlink(file.path(rp$dir, "_weft.yml"))
  g_add(rp$dir); g_commit(rp$dir, "no weft yml")
  g_ok_git(rp$dir, "remote", "add", "origin", GH)
  before <- h4_outside_snap(rp$parent)
  h4_weft(rp$dir)
  expect_identical(h4_outside_snap(rp$parent), before)
})
