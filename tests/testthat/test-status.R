# 4b: status() (G39, G40, G32, 9.5.3): what it reports for a bare project, a fully installed one and
# the partial states, `next` per missing step, its print, and that it writes nothing.
#
# READINGS ASSUMED (the design lists the states but not every mapping):
#   - the parts are, in this order: setup, activation, quarto, dictionary, hooks, ci, agent docs,
#     draft, verify_skip, strict;
#   - `quarto` is `n/a` for a project that is not a Quarto project;
#   - `draft: true` is state `off`, a non-empty `verify_skip` is `off` with the parts named in the
#     detail; `strict` set is `ok` with the ids in the detail;
#   - a hook that is ours but from an older template, or whose recorded Rscript is gone, is `outdated`;
#     ours and edited is `edited`; another tool's hook has "foreign" or "another" in its detail;
#   - `next` is the full sentence (`Next: run weft::<fn>() to <purpose>.`, or `Nothing to install. Run
#     weft::verify() to check the project.`); an `edited` part never makes a next step;
#   - the setup part's next function is use_setup() or use_weft() when only the recorded version
#     is outdated;
#   - an unrecorded weft_version is reported in the detail as "not recorded".

GH_ST <- "https://github.com/example-org/example-repo.git"
PARTS <- c("setup", "activation", "quarto", "dictionary", "hooks", "ci", "agent docs", "draft",
           "verify_skip", "strict")
STATES <- c("ok", "missing", "outdated", "edited", "off", "n/a")

st_full <- function(files = list(`index.qmd` = u4_qmd()), env = parent.frame()) {
  dir <- h4_repo(files, weft = character(), origin = GH_ST, env = env)
  h4_weft(dir, env = env)
  dir
}
st_next <- function(st) attr(st, "next", exact = TRUE)
st_wf <- function(dir) file.path(dir, ".github", "workflows", "weft.yml")
st_skill <- function(dir) file.path(dir, ".agents", "skills", "weft", "SKILL.md")
st_set_yml <- function(dir, lines) writeLines(lines, file.path(dir, "_weft.yml"))

test_that("4b G39: status() returns a weft_status: a data frame part, state, detail with a `next` attribute", {
  dir <- st_full()
  st <- h4_status(dir)
  expect_s3_class(st, "weft_status")
  expect_s3_class(st, "data.frame")
  expect_identical(names(st), c("part", "state", "detail"))
  expect_identical(st$part, PARTS)
  expect_true(all(st$state %in% STATES))
  expect_true(is.character(st_next(st)) && length(st_next(st)) == 1L)
})

test_that("4b G39: a bare project (no _weft.yml, nothing installed) reports each part as missing or not applicable", {
  d <- u4_dir(list(`index.qmd` = u4_qmd()))
  git_env(); h4_env()
  st <- h4_status(d)
  expect_identical(st$part, PARTS)
  expect_identical(h4_state(st, "setup"), "missing")
  expect_identical(h4_state(st, "activation"), "missing")
  expect_identical(h4_detail(st, "activation"), "no .Rprofile line and no front-matter route")
  expect_identical(h4_state(st, "quarto"), "n/a")
  expect_identical(h4_state(st, "dictionary"), "missing")
  expect_true(h4_state(st, "hooks") %in% c("missing", "n/a"))
  expect_true(h4_state(st, "ci") %in% c("missing", "n/a"))
  expect_identical(h4_state(st, "agent docs"), "missing")
  expect_identical(h4_state(st, "draft"), "ok")
  expect_identical(h4_state(st, "verify_skip"), "ok")
  expect_match(st_next(st), "^Next: run weft::use_setup\\(\\) to ")
})

test_that("4b G39: a fully installed project: every part is ok (quarto n/a), and there is nothing to install", {
  dir <- st_full()
  st <- h4_status(dir)
  expect_true(all(st$state[st$part != "quarto"] == "ok"))
  expect_identical(h4_state(st, "quarto"), "n/a")
  expect_identical(st_next(st), "Nothing to install. Run weft::verify() to check the project.")
})

test_that("4b G39: a fully installed Quarto project: quarto is ok too", {
  dir <- st_full(list(`_quarto.yml` = U4_QUARTO_YML, `index.qmd` = u4_qmd()))
  st <- h4_status(dir)
  expect_true(all(st$state == "ok"))
})

# ---- setup ---------------------------------------------------------------------------------------

test_that("4b G39: setup is ok when the recorded version is the installed one, and the detail says so", {
  dir <- st_full()
  st <- h4_status(dir)
  v <- u4_version()
  expect_identical(h4_state(st, "setup"), "ok")
  expect_identical(h4_detail(st, "setup"), sprintf("_weft.yml records weft %s (installed: %s)", v, v))
})

test_that("4b G39/G32: a recorded version that differs is outdated, naming both versions", {
  dir <- st_full()
  st_set_yml(dir, c("draft: false", "weft_version: 0.0.0.1"))
  st <- h4_status(dir)
  expect_identical(h4_state(st, "setup"), "outdated")
  expect_match(h4_detail(st, "setup"), "0.0.0.1", fixed = TRUE)
  expect_match(h4_detail(st, "setup"), u4_version(), fixed = TRUE)
  expect_match(st_next(st), "^Next: run weft::use_(setup|weft)\\(\\) to ")
})

test_that("4b G39/G32: no recorded version: the detail says it is not recorded", {
  dir <- st_full()
  st_set_yml(dir, "draft: false")
  st <- h4_status(dir)
  expect_match(h4_detail(st, "setup"), "not recorded", fixed = TRUE)
})

test_that("4b G39: a project with no _weft.yml has setup missing", {
  dir <- st_full()
  unlink(file.path(dir, "_weft.yml"))
  expect_identical(h4_state(h4_status(dir), "setup"), "missing")
})

# ---- activation ----------------------------------------------------------------------------------

test_that("4b G39: the front-matter route in every document is activation ok", {
  dir <- st_full()
  expect_identical(h4_state(h4_status(dir), "activation"), "ok")
})

test_that("4b G39: a document without the route: activation is missing, with the design's detail, and next is use_setup()", {
  dir <- st_full()
  writeLines(u4_qmd(engine = TRUE), file.path(dir, "index.qmd"))
  st <- h4_status(dir)
  expect_identical(h4_state(st, "activation"), "missing")
  expect_identical(h4_detail(st, "activation"), "no .Rprofile line and no front-matter route")
  expect_identical(st_next(st), "Next: run weft::use_setup() to activate weft in the documents.")
})

test_that("4b G39: the .Rprofile route is found (Quarto project)", {
  dir <- st_full(list(`_quarto.yml` = U4_QUARTO_YML, `index.qmd` = u4_qmd()))
  expect_true(file.exists(file.path(dir, ".Rprofile")))
  expect_identical(h4_state(h4_status(dir), "activation"), "ok")
  unlink(file.path(dir, ".Rprofile"))
  expect_identical(h4_state(h4_status(dir), "activation"), "missing")
})

test_that("4b G39: .qmd files lacking `engine: knitr` are named, the first three only", {
  files <- stats::setNames(rep(list(u4_qmd(engine = TRUE)), 4L), paste0(c("a", "b", "c", "d"), ".qmd"))
  dir <- st_full(c(list(`_quarto.yml` = U4_QUARTO_YML), files))
  for (f in names(files)) writeLines(u4_qmd(engine = FALSE), file.path(dir, f))
  st <- h4_status(dir)
  expect_false(identical(h4_state(st, "activation"), "ok"))
  det <- h4_detail(st, "activation")
  expect_match(det, "a.qmd", fixed = TRUE)
  expect_match(det, "b.qmd", fixed = TRUE)
  expect_match(det, "c.qmd", fixed = TRUE)
  expect_false(grepl("d.qmd", det, fixed = TRUE))
})

# ---- quarto --------------------------------------------------------------------------------------

test_that("4b G39: a Quarto project without use_quarto's files has quarto missing, next use_quarto()", {
  dir <- st_full(list(`_quarto.yml` = U4_QUARTO_YML, `index.qmd` = u4_qmd()))
  unlink(file.path(dir, "_extensions"), recursive = TRUE)
  unlink(file.path(dir, "_weft", "pre-render.R"))
  unlink(file.path(dir, "_weft", "post-render.R"))
  writeLines(U4_QUARTO_YML, file.path(dir, "_quarto.yml"))
  st <- h4_status(dir)
  expect_identical(h4_state(st, "quarto"), "missing")
  expect_match(st_next(st), "^Next: run weft::use_quarto\\(\\) to ")
})

test_that("4b G39: an extension file that differs from the shipped one (md5) is not ok", {
  dir <- st_full(list(`_quarto.yml` = U4_QUARTO_YML, `index.qmd` = u4_qmd()))
  lua <- file.path(dir, "_extensions", "weft-check", "weft-check.lua")
  writeLines(c(readLines(lua), "-- changed"), lua)
  expect_true(h4_state(h4_status(dir), "quarto") %in% c("edited", "outdated"))
})

test_that("4b G39: a _quarto.yml that lost the weft entries is not ok", {
  dir <- st_full(list(`_quarto.yml` = U4_QUARTO_YML, `index.qmd` = u4_qmd()))
  writeLines(U4_QUARTO_YML, file.path(dir, "_quarto.yml"))
  expect_true(h4_state(h4_status(dir), "quarto") %in% c("missing", "outdated"))
})

# ---- dictionary ----------------------------------------------------------------------------------

test_that("4b G39: dictionary is missing without dict.yml, with next use_dictionary()", {
  dir <- st_full()
  unlink(file.path(dir, "dict.yml"))
  st <- h4_status(dir)
  expect_identical(h4_state(st, "dictionary"), "missing")
  expect_match(st_next(st), "^Next: run weft::use_dictionary\\(\\) to ")
})

test_that("4b G39: a schema that is not the shipped one (not current) is not ok", {
  dir <- st_full()
  sch <- file.path(dir, "_weft", "dict.schema.json")
  writeLines("{}", sch)
  expect_true(h4_state(h4_status(dir), "dictionary") %in% c("outdated", "edited"))
})

# ---- hooks ---------------------------------------------------------------------------------------

test_that("4b G39: the hook ours, current, with its Rscript present: hooks ok", {
  dir <- st_full()
  expect_identical(h4_state(h4_status(dir), "hooks"), "ok")
})

test_that("4b G39: no hook: missing, with next use_hooks()", {
  dir <- st_full()
  unlink(h4_hook_path(dir))
  st <- h4_status(dir)
  expect_identical(h4_state(st, "hooks"), "missing")
  expect_match(st_next(st), "^Next: run weft::use_hooks\\(\\) to ")
})

test_that("4b G39/G40: an edited hook is edited and makes no next step", {
  dir <- st_full()
  writeLines(c(readLines(h4_hook_path(dir)), "# mine"), h4_hook_path(dir))
  st <- h4_status(dir)
  expect_identical(h4_state(st, "hooks"), "edited")
  expect_identical(st_next(st), "Nothing to install. Run weft::verify() to check the project.")
})

test_that("4b G39/G40: a hook from an older template is outdated, with next use_hooks()", {
  dir <- st_full()
  old <- h4_forge(readLines(h4_hook_path(dir)), function(b) sub("rules 6.1 to 6.3", "rules 6.1 to 6.2", b, fixed = TRUE))
  writeLines(old, h4_hook_path(dir))
  st <- h4_status(dir)
  expect_identical(h4_state(st, "hooks"), "outdated")
  expect_match(st_next(st), "^Next: run weft::use_hooks\\(\\) to ")
})

test_that("4b G39: a hook whose recorded Rscript is gone is outdated", {
  dir <- st_full()
  gone <- file.path(withr::local_tempdir(), "no-such-dir", "Rscript")
  h4_hooks(dir, rscript = gone)
  expect_identical(h4_state(h4_status(dir), "hooks"), "outdated")
})

test_that("4b G39: another tool's hook is reported as another tool's", {
  dir <- st_full()
  writeLines(H4_FOREIGN_HOOK, h4_hook_path(dir))
  st <- h4_status(dir)
  expect_match(h4_detail(st, "hooks"), "foreign|another|other", ignore.case = TRUE)
})

# ---- ci ------------------------------------------------------------------------------------------

test_that("4b G39: ci is ok when the workflow is ours and current", {
  dir <- st_full()
  expect_identical(h4_state(h4_status(dir), "ci"), "ok")
})

test_that("4b G39: a GitHub project without the workflow has ci missing, next use_ci()", {
  dir <- st_full()
  unlink(st_wf(dir))
  st <- h4_status(dir)
  expect_identical(h4_state(st, "ci"), "missing")
  expect_match(st_next(st), "^Next: run weft::use_ci\\(\\) to ")
})

test_that("4b G39/G40: an edited workflow is edited; an older template is outdated", {
  dir <- st_full()
  writeLines(c(readLines(st_wf(dir)), "# mine"), st_wf(dir))
  expect_identical(h4_state(h4_status(dir), "ci"), "edited")
  old <- h4_forge(h4_ci_expected("."), function(b) sub("fetch-depth: 0", "fetch-depth: 1", b, fixed = TRUE))
  writeLines(old, st_wf(dir))
  expect_identical(h4_state(h4_status(dir), "ci"), "outdated")
})

# ---- agent docs ----------------------------------------------------------------------------------

test_that("4b G39: agent docs ok when the block and the skill are ours and current", {
  dir <- st_full()
  expect_identical(h4_state(h4_status(dir), "agent docs"), "ok")
})

test_that("4b G39: AGENTS.md gone: missing, next use_agent_docs(); the skill alone gone: missing too", {
  dir <- st_full()
  unlink(file.path(dir, "AGENTS.md"))
  st <- h4_status(dir)
  expect_identical(h4_state(st, "agent docs"), "missing")
  expect_match(st_next(st), "^Next: run weft::use_agent_docs\\(\\) to ")
  h4_agent(dir)
  unlink(st_skill(dir))
  expect_identical(h4_state(h4_status(dir), "agent docs"), "missing")
})

test_that("4b G39/G40: an edited block is edited; an older block is outdated", {
  dir <- st_full()
  x <- readLines(file.path(dir, "AGENTS.md"))
  x[3] <- paste(x[3], "(my edit)")
  writeLines(x, file.path(dir, "AGENTS.md"))
  expect_identical(h4_state(h4_status(dir), "agent docs"), "edited")
  writeLines(h4_block_old(), file.path(dir, "AGENTS.md"))
  expect_identical(h4_state(h4_status(dir), "agent docs"), "outdated")
})

# ---- draft, verify_skip, strict ------------------------------------------------------------------

test_that("4b G39: draft off is ok; draft: true is off", {
  dir <- st_full()
  st_set_yml(dir, c("draft: true", paste0("weft_version: ", u4_version())))
  expect_identical(h4_state(h4_status(dir), "draft"), "off")
  st_set_yml(dir, c("draft: false", paste0("weft_version: ", u4_version())))
  expect_identical(h4_state(h4_status(dir), "draft"), "ok")
})

test_that("4b G39: verify_skip names the parts switched off", {
  dir <- st_full()
  st_set_yml(dir, c("verify_skip: [render, ledger]", paste0("weft_version: ", u4_version())))
  st <- h4_status(dir)
  expect_identical(h4_state(st, "verify_skip"), "off")
  expect_match(h4_detail(st, "verify_skip"), "render", fixed = TRUE)
  expect_match(h4_detail(st, "verify_skip"), "ledger", fixed = TRUE)
})

test_that("4b G39: strict lists its rule ids in the detail", {
  dir <- st_full()
  st_set_yml(dir, c("strict: [numeral]", paste0("weft_version: ", u4_version())))
  st <- h4_status(dir)
  expect_match(h4_detail(st, "strict"), "numeral", fixed = TRUE)
})

# ---- next ----------------------------------------------------------------------------------------

test_that("4b G39: next is the first missing or outdated part in G38's order", {
  dir <- st_full()
  unlink(st_wf(dir))
  unlink(file.path(dir, "AGENTS.md"))
  expect_match(st_next(h4_status(dir)), "^Next: run weft::use_ci\\(\\) to ")
  unlink(file.path(dir, "dict.yml"))
  unlink(h4_hook_path(dir))
  expect_match(st_next(h4_status(dir)), "^Next: run weft::use_dictionary\\(\\) to ")
  writeLines(u4_qmd(engine = TRUE), file.path(dir, "index.qmd"))
  expect_match(st_next(h4_status(dir)), "^Next: run weft::use_setup\\(\\) to ")
})

# ---- print ---------------------------------------------------------------------------------------

test_that("4b G39: print shows the header, one line per part, and the Next line", {
  dir <- st_full()
  st <- h4_status(dir)
  lines <- h4_print_lines(st)
  expect_identical(lines[1], paste0("weft status: ", dir))
  body <- sprintf("  %-12s %-9s %s", st$part, st$state, st$detail)
  expect_identical(lines[2:(1 + nrow(st))], body)
  expect_identical(lines[length(lines)], st_next(st))
  expect_identical(lines[length(lines)], "Nothing to install. Run weft::verify() to check the project.")
})

test_that("4b G39: print of a project with a step missing ends in the Next line, as the design's example", {
  dir <- st_full()
  writeLines(u4_qmd(engine = TRUE), file.path(dir, "index.qmd"))
  st <- h4_status(dir)
  lines <- h4_print_lines(st)
  v <- u4_version()
  expect_true(sprintf("  setup        ok        _weft.yml records weft %s (installed: %s)", v, v) %in% lines)
  expect_true("  activation   missing   no .Rprofile line and no front-matter route" %in% lines)
  expect_identical(lines[length(lines)], "Next: run weft::use_setup() to activate weft in the documents.")
})

test_that("4b G39: print returns its argument invisibly", {
  dir <- st_full()
  st <- h4_status(dir)
  utils::capture.output(suppressMessages(expect_invisible(print(st))))
})

# ---- writes nothing ------------------------------------------------------------------------------

test_that("4b G39: status() writes nothing: the repository is byte-identical, and HOME, the cache and the parent too", {
  rp <- h4_repo_in_parent(list(`index.qmd` = u4_qmd()))
  g_ok_git(rp$dir, "remote", "add", "origin", GH_ST)
  h4_weft(rp$dir)
  before_repo <- h4_snap(rp$dir)
  before <- h4_outside_snap(rp$parent)
  h4_status(rp$dir)
  h4_status(rp$dir)
  expect_identical(h4_snap(rp$dir), before_repo)
  expect_identical(h4_outside_snap(rp$parent), before)
})

test_that("4b G39: status() of a bare project writes nothing either, and runs without git", {
  d <- u4_dir(list(`index.qmd` = u4_qmd()))
  git_env(); h4_env()
  before <- h4_snap(d)
  expect_no_error(h4_status(d))
  expect_identical(h4_snap(d), before)
})

test_that("4b G39: status() of a bare project in a git repository with no _weft.yml does not error", {
  dir <- h4_repo(list(`index.qmd` = u4_qmd()), weft = character())
  before <- h4_snap_repo(dir)
  st <- h4_status(dir)
  expect_identical(h4_state(st, "setup"), "missing")
  expect_identical(h4_snap_repo(dir), before)
})
