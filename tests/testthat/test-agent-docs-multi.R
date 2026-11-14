# use_agent_docs() for more than one tool, and agent_docs() (dev/design-agent-docs.md, AD1-AD8).
#
# Written from the specification before the implementation. Helpers come from helper-4b.R,
# helper-4d.R and helper-quarto.R; the ones here are prefixed adm_ so that nothing depends on
# another test file. ASCII only.
#
# READINGS ASSUMED:
#   - a "copy" is <folder>/weft/SKILL.md plus <folder>/weft/references/{syntax,reports}.md;
#   - every written file ends with the marker `<!-- weft-file: use_agent_docs <version> <hash> -->`
#     (the hash over the other lines), as SKILL.md does today;
#   - agent_docs() output is read as everything it prints (messages and stdout);
#   - the order of returned paths is asserted only between folders (the order given), not within one.

ADM_PRESETS <- c(agents = ".agents/skills", claude = ".claude/skills", codex = ".agents/skills",
                 gemini = ".gemini/skills", opencode = ".opencode/skills",
                 kimi = ".kimi-code/skills", cursor = ".cursor/skills")
ADM_GH <- "https://github.com/example-org/example-repo.git"
ADM_EDITED <- "edited since weft wrote it; left as it is (use overwrite = TRUE to replace it)"
ADM_CLAUDE_NOTE <- "Claude Code reads CLAUDE.md: add the line @AGENTS.md to it, or move the block there."

adm_proj <- function(files = list()) u4_dir(c(list(`_weft.yml` = "draft: false"), files))
adm_files <- function(folder) file.path(folder, "weft", c("SKILL.md", "references/syntax.md", "references/reports.md"))
adm_path <- function(d, rel) file.path(d, rel)
adm_all_skill_files <- function(d) grep("(^|/)weft/(SKILL\\.md|references/)", tree(d), value = TRUE)
adm_edit <- function(f) {                       # append a line before the marker, leaving the marker as it was
  x <- readLines(f)
  writeLines(append(x, "My own rule.", after = length(x) - 1L), f)
}
adm_stale <- function(f) {                      # an older, unedited copy
  x <- readLines(f)
  writeLines(h4_forge(x, function(b) c(b[1:2], "An older line.", b[-(1:2)])), f)
}
# the call must fail on the value of `skills`, not because the argument does not exist yet
adm_bad <- function(d, skills) {
  err <- tryCatch(suppressMessages(weft::use_agent_docs(d, skills = skills)), error = function(e) e)
  testthat::expect_s3_class(err, "error")
  testthat::expect_false(grepl("unused argument", conditionMessage(err), fixed = TRUE))
  invisible(err)
}
adm_front <- function(f) {
  x <- readLines(f)
  end <- which(x == "---")[2]
  yaml::yaml.load(paste(x[2:(end - 1L)], collapse = "\n"))
}

# ---- AD1: the argument -------------------------------------------------------------------------

test_that("AD1: the default writes the skill into .agents/skills and .claude/skills", {
  d <- adm_proj()
  h4_agent(d)
  expect_true(file.exists(adm_path(d, ".agents/skills/weft/SKILL.md")))
  expect_true(file.exists(adm_path(d, ".claude/skills/weft/SKILL.md")))
  expect_setequal(grep("SKILL\\.md$", tree(d), value = TRUE),
                  c(".agents/skills/weft/SKILL.md", ".claude/skills/weft/SKILL.md"))
})

test_that("AD1: each preset name writes into its folder and nowhere else", {
  for (nm in names(ADM_PRESETS)) {
    d <- adm_proj()
    h4_agent(d, skills = nm)
    expect_identical(grep("SKILL\\.md$", tree(d), value = TRUE),
                     paste0(ADM_PRESETS[[nm]], "/weft/SKILL.md"), label = nm)
  }
})

test_that("AD1: codex and agents together write .agents/skills once", {
  d <- adm_proj()
  s <- h4_say(weft::use_agent_docs(d, skills = c("codex", "agents")))
  expect_false(anyDuplicated(u4_rel(s$value, d)) > 0L)
  expect_identical(sum(u4_rel(s$value, d) == ".agents/skills/weft/SKILL.md"), 1L)
  expect_identical(sum(grepl("\\.agents/skills/weft/SKILL\\.md", s$lines)), 1L)
  expect_identical(grep("SKILL\\.md$", tree(d), value = TRUE), ".agents/skills/weft/SKILL.md")
  # the same folder spelt two ways is also written once
  d2 <- adm_proj()
  s2 <- h4_say(weft::use_agent_docs(d2, skills = c("agents", ".agents/skills/")))
  expect_identical(sum(u4_rel(s2$value, d2) == ".agents/skills/weft/SKILL.md"), 1L)
})

test_that("AD1: an item with a slash is a folder, relative to the project root", {
  d <- adm_proj()
  h4_agent(d, skills = "tools/skills")
  expect_true(file.exists(adm_path(d, "tools/skills/weft/SKILL.md")))
  expect_true(file.exists(adm_path(d, "tools/skills/weft/references/syntax.md")))
  expect_false(any(grepl("^\\.(agents|claude)/", tree(d))))
})

test_that("AD1: an item starting with a dot is a folder, and a trailing slash is dropped", {
  d <- adm_proj()
  res <- h4_agent(d, skills = ".foo/skills/")
  expect_true(file.exists(adm_path(d, ".foo/skills/weft/SKILL.md")))
  expect_false(any(grepl("//", u4_rel(res, d), fixed = TRUE)))
  d2 <- adm_proj()
  h4_agent(d2, skills = ".bare")
  expect_true(file.exists(adm_path(d2, ".bare/weft/SKILL.md")))
})

test_that("AD1: a name that is not a preset is an error listing the presets, and nothing is written", {
  d <- adm_proj()
  before <- tree(d)
  err <- tryCatch(suppressMessages(weft::use_agent_docs(d, skills = "bogus")), error = function(e) e)
  expect_s3_class(err, "error")
  msg <- conditionMessage(err)
  expect_match(msg, "bogus", fixed = TRUE)
  for (p in names(ADM_PRESETS)) expect_match(msg, p, fixed = TRUE)
  expect_identical(tree(d), before)
})

test_that("AD1: an absolute path is an error, and nothing is written", {
  d <- adm_proj()
  out <- tempfile("adm-out-")
  before <- tree(d)
  adm_bad(d, skills = out)
  adm_bad(d, skills = "/tmp/skills")
  expect_identical(tree(d), before)
  expect_false(dir.exists(out))
})

test_that("AD1: a path with a .. part is an error, and nothing is written", {
  d <- adm_proj()
  before <- tree(d)
  adm_bad(d, skills = "../outside/skills")
  adm_bad(d, skills = "a/../b")
  expect_identical(tree(d), before)
  expect_false(dir.exists(file.path(dirname(d), "outside")))
})

test_that("AD1: skills = character() writes only the AGENTS.md block", {
  d <- adm_proj()
  res <- h4_agent(d, skills = character())
  expect_setequal(tree(d), c("_weft.yml", "AGENTS.md"))
  expect_identical(u4_rel(res, d), "AGENTS.md")
})

test_that("AD1: NA, an empty string and a non-character value are errors", {
  d <- adm_proj()
  before <- tree(d)
  adm_bad(d, skills = NA_character_)
  adm_bad(d, skills = NA)
  adm_bad(d, skills = "")
  adm_bad(d, skills = c("agents", NA))
  adm_bad(d, skills = c("agents", ""))
  adm_bad(d, skills = 1)
  adm_bad(d, skills = TRUE)
  adm_bad(d, skills = list("agents"))
  expect_identical(tree(d), before)
})

test_that("AD1: the order of writing is the order given, and the returned paths follow it", {
  d <- adm_proj()
  res <- u4_rel(h4_agent(d, skills = c("claude", "agents")), d)
  expect_lt(min(grep("^\\.claude/", res)), min(grep("^\\.agents/", res)))
  d2 <- adm_proj()
  res2 <- u4_rel(h4_agent(d2), d2)
  expect_lt(min(grep("^\\.agents/", res2)), min(grep("^\\.claude/", res2)))
  d3 <- adm_proj()
  res3 <- u4_rel(h4_agent(d3, skills = c("tools/skills", "gemini", "claude")), d3)
  pos <- c(min(grep("^tools/", res3)), min(grep("^\\.gemini/", res3)), min(grep("^\\.claude/", res3)))
  expect_identical(order(pos), 1:3)
  expect_true("AGENTS.md" %in% res3)
})

# ---- AD2: what is written ------------------------------------------------------------------------

test_that("AD2: SKILL.md and both references exist in each folder", {
  d <- adm_proj()
  h4_agent(d, skills = c("agents", "claude", "gemini"))
  for (f in c(".agents/skills", ".claude/skills", ".gemini/skills")) {
    for (p in adm_files(f)) expect_true(file.exists(adm_path(d, p)), label = p)
  }
})

test_that("AD2: the copies are byte-identical across folders", {
  d <- adm_proj()
  h4_agent(d, skills = c("agents", "claude", "kimi"))
  for (rel in c("SKILL.md", "references/syntax.md", "references/reports.md")) {
    m <- unname(tools::md5sum(adm_path(d, file.path(c(".agents/skills", ".claude/skills", ".kimi-code/skills"),
                                                   "weft", rel))))
    expect_identical(length(unique(m)), 1L, label = rel)
  }
})

test_that("AD2: the AGENTS.md block appears once however many folders are written", {
  d <- adm_proj()
  h4_agent(d, skills = c("agents", "claude", "gemini"))
  x <- readLines(adm_path(d, "AGENTS.md"))
  expect_identical(sum(grepl("^<!-- weft:start", x)), 1L)
  expect_identical(sum(x == "<!-- weft:end -->"), 1L)
  h4_agent(d, skills = c("agents", "claude", "gemini"))
  x <- readLines(adm_path(d, "AGENTS.md"))
  expect_identical(sum(grepl("^<!-- weft:start", x)), 1L)
})

# ---- AD3: each copy stands alone -----------------------------------------------------------------

test_that("AD3: an edited copy is left and reported, while a stale copy in the other folder is replaced", {
  d <- adm_proj()
  h4_agent(d)
  cur <- readLines(adm_path(d, ".agents/skills/weft/SKILL.md"))
  claude <- adm_path(d, ".claude/skills/weft/SKILL.md")
  adm_edit(claude)
  edited <- readLines(claude)
  adm_stale(adm_path(d, ".agents/skills/weft/SKILL.md"))
  s <- h4_say(weft::use_agent_docs(d))
  expect_identical(readLines(claude), edited)
  expect_identical(readLines(adm_path(d, ".agents/skills/weft/SKILL.md")), cur)
  expect_match(s$text, ADM_EDITED, fixed = TRUE)
  expect_match(s$text, ".claude/skills/weft/SKILL.md", fixed = TRUE)
  expect_true(".agents/skills/weft/SKILL.md" %in% u4_rel(s$value, d))
  expect_false(".claude/skills/weft/SKILL.md" %in% u4_rel(s$value, d))
})

test_that("AD3: overwrite = TRUE replaces an edited copy", {
  d <- adm_proj()
  h4_agent(d)
  claude <- adm_path(d, ".claude/skills/weft/SKILL.md")
  orig <- readLines(claude)
  adm_edit(claude)
  h4_agent(d, overwrite = TRUE)
  expect_identical(readLines(claude), orig)
})

test_that("AD3: an edited reference is left and reported, and the other folder's copy is still written", {
  d <- adm_proj()
  h4_agent(d, skills = "agents")
  ref <- adm_path(d, ".agents/skills/weft/references/reports.md")
  adm_edit(ref)
  edited <- readLines(ref)
  s <- h4_say(weft::use_agent_docs(d))
  expect_identical(readLines(ref), edited)
  expect_match(s$text, ADM_EDITED, fixed = TRUE)
  expect_match(s$text, ".agents/skills/weft/references/reports.md", fixed = TRUE)
  expect_true(file.exists(adm_path(d, ".claude/skills/weft/references/reports.md")))
})

test_that("AD3: a foreign SKILL.md in one folder is never replaced while the other folder is written", {
  d <- adm_proj()
  mine <- c("---", "name: weft", "description: mine", "---", "My skill.")
  f3_write(adm_path(d, ".agents/skills/weft/SKILL.md"), mine)
  s <- h4_say(weft::use_agent_docs(d))
  expect_identical(readLines(adm_path(d, ".agents/skills/weft/SKILL.md")), mine)
  expect_match(s$text, "not written by weft", fixed = TRUE)
  expect_true(file.exists(adm_path(d, ".claude/skills/weft/SKILL.md")))
  expect_true(file.exists(adm_path(d, ".claude/skills/weft/references/syntax.md")))
  suppressMessages(weft::use_agent_docs(d, overwrite = TRUE))
  expect_identical(readLines(adm_path(d, ".agents/skills/weft/SKILL.md")), mine)
})

test_that("AD3: a foreign file under references/ is never replaced while the other folder is written", {
  d <- adm_proj()
  mine <- c("# my syntax notes", "Not weft's.")
  f3_write(adm_path(d, ".claude/skills/weft/references/syntax.md"), mine)
  s <- h4_say(weft::use_agent_docs(d))
  expect_identical(readLines(adm_path(d, ".claude/skills/weft/references/syntax.md")), mine)
  expect_match(s$text, "not written by weft", fixed = TRUE)
  expect_true(file.exists(adm_path(d, ".agents/skills/weft/references/syntax.md")))
  expect_true(file.exists(adm_path(d, ".claude/skills/weft/SKILL.md")))
  suppressMessages(weft::use_agent_docs(d, overwrite = TRUE))
  expect_identical(readLines(adm_path(d, ".claude/skills/weft/references/syntax.md")), mine)
})

test_that("AD3: a stale unedited reference is replaced without overwrite", {
  d <- adm_proj()
  h4_agent(d)
  ref <- adm_path(d, ".agents/skills/weft/references/syntax.md")
  cur <- readLines(ref)
  adm_stale(ref)
  h4_agent(d)
  expect_identical(readLines(ref), cur)
})

test_that("AD3: a second call with nothing to do returns character() and says so", {
  d <- adm_proj()
  h4_agent(d)
  before <- h4_snap(d)
  s <- h4_say(weft::use_agent_docs(d))
  expect_identical(s$value, character())
  expect_match(s$text, "Nothing to change", fixed = TRUE)
  expect_identical(h4_snap(d), before)
})

test_that("AD3: the announcement has one line per file, before anything is written", {
  d <- adm_proj()
  early <- NULL
  s <- h4_say(weft::use_agent_docs(d),
              first = function() early <<- length(adm_all_skill_files(d)) > 0L || file.exists(adm_path(d, "AGENTS.md")))
  expect_false(early)
  expect_match(s$text, "weft will write", fixed = TRUE)
  for (f in c(".agents/skills", ".claude/skills")) {
    for (p in adm_files(f)) {
      expect_identical(sum(grepl(p, s$lines, fixed = TRUE)), 1L, label = p)
    }
  }
  expect_true(any(grepl("AGENTS\\.md", s$lines)))
  expect_match(s$text, "Wrote: ", fixed = TRUE)
})

test_that("AD3: a folder where a skill file should be is an error and nothing is written", {
  d <- adm_proj(list(`.claude/skills/weft/references/syntax.md/keep.txt` = "x"))
  before <- tree(d)
  err <- tryCatch(suppressMessages(weft::use_agent_docs(d)), error = function(e) e)
  expect_s3_class(err, "weft_tool_error")
  expect_identical(tree(d), before)
})

# ---- AD4: the skill is thin ----------------------------------------------------------------------

test_that("AD4: the front matter has name weft, a description, and metadata weft-version", {
  d <- adm_proj()
  h4_agent(d)
  for (f in c(".agents/skills", ".claude/skills")) {
    fm <- adm_front(adm_path(d, file.path(f, "weft/SKILL.md")))
    expect_identical(fm$name, "weft")
    expect_true(is.character(fm$description) && nzchar(trimws(fm$description)))
    expect_identical(as.character(fm$metadata[["weft-version"]]), u4_version())
  }
})

test_that("AD4: no field only one tool reads (no allowed-tools)", {
  d <- adm_proj()
  h4_agent(d)
  fm <- adm_front(adm_path(d, ".claude/skills/weft/SKILL.md"))
  expect_false("allowed-tools" %in% names(fm))
  expect_setequal(setdiff(names(fm), c("name", "description", "metadata")), character())
})

test_that("AD4: the name matches the parent folder", {
  d <- adm_proj()
  h4_agent(d, skills = c("agents", "claude", "tools/skills"))
  for (p in grep("/weft/SKILL\\.md$", tree(d), value = TRUE)) {
    expect_identical(adm_front(adm_path(d, p))$name, basename(dirname(p)), label = p)
  }
})

test_that("AD4: the body names the references by relative path and points to weft::agent_docs()", {
  d <- adm_proj()
  h4_agent(d)
  txt <- paste(readLines(adm_path(d, ".claude/skills/weft/SKILL.md")), collapse = "\n")
  expect_match(txt, "references/syntax.md", fixed = TRUE)
  expect_match(txt, "references/reports.md", fixed = TRUE)
  expect_match(txt, "weft::agent_docs()", fixed = TRUE)
})

test_that("AD4: SKILL.md is under 500 lines", {
  d <- adm_proj()
  h4_agent(d)
  expect_lt(length(readLines(adm_path(d, ".claude/skills/weft/SKILL.md"))), 500L)
})

test_that("AD4: the last line of every written file is the weft marker, with a valid hash", {
  d <- adm_proj()
  h4_agent(d)
  files <- adm_all_skill_files(d)
  expect_length(files, 6L)
  for (p in files) {
    x <- readLines(adm_path(d, p))
    m <- h4_marker(x)
    expect_false(is.null(m), label = p)
    expect_identical(m$idx, length(x), label = p)
    expect_match(x[length(x)], "^<!-- weft-file: use_agent_docs \\S+ [0-9a-f]{32} -->$")
    expect_identical(m$version, u4_version(), label = p)
    expect_identical(m$hash, cli::hash_md5(paste(x[-length(x)], collapse = "\n")), label = p)
  }
})

# ---- AD5: agent_docs() ---------------------------------------------------------------------------

test_that("AD5: agent_docs is exported", {
  expect_true("agent_docs" %in% getNamespaceExports("weft"))
})

test_that("AD5: agent_docs() lists skill, then reports, then syntax, each with a description", {
  s <- h4_say(weft::agent_docs())
  l <- trimws(s$lines[nzchar(trimws(s$lines))])
  i <- vapply(c("skill", "reports", "syntax"), function(t) grep(paste0("^", t, "\\b"), l)[1L], 1L)
  expect_false(anyNA(i))
  expect_identical(order(i), 1:3)
  for (t in names(i)) {
    rest <- trimws(sub(paste0("^", t, "\\b"), "", l[i[[t]]]))
    rest <- trimws(sub("^[-:=]+", "", rest))
    expect_gt(nchar(rest), 5L, label = t)
  }
})

test_that("AD5: agent_docs(topic) prints the document without the marker line and returns it invisibly", {
  for (t in c("syntax", "reports", "skill")) {
    s <- h4_say(expect_invisible(weft::agent_docs(t)))
    expect_false(grepl("weft-file:", s$text, fixed = TRUE), label = t)
    v <- paste(s$value, collapse = "\n")
    expect_true(is.character(s$value) && nzchar(trimws(v)), label = t)
    expect_false(grepl("weft-file:", v, fixed = TRUE), label = t)
    # what is printed is what is returned (up to line breaks and blank ends)
    expect_identical(gsub("\\s+", " ", trimws(s$text)), gsub("\\s+", " ", trimws(v)), label = t)
  }
})

test_that("AD5: agent_docs('syntax') is the installed reference text, less its marker", {
  src <- readLines(system.file("agent", "references", "syntax.md", package = "weft"))
  src <- src[!grepl("weft-file:", src, fixed = TRUE)]
  s <- h4_say(weft::agent_docs("syntax"))
  expect_identical(gsub("\\s+", " ", trimws(paste(s$value, collapse = "\n"))),
                   gsub("\\s+", " ", trimws(paste(src, collapse = "\n"))))
})

test_that("AD5: agent_docs('skill') is the installed SKILL.md, less its marker", {
  src <- readLines(system.file("agent", "SKILL.md", package = "weft"))
  src <- src[!grepl("weft-file:", src, fixed = TRUE)]
  s <- h4_say(weft::agent_docs("skill"))
  expect_identical(gsub("\\s+", " ", trimws(paste(s$value, collapse = "\n"))),
                   gsub("\\s+", " ", trimws(paste(src, collapse = "\n"))))
})

test_that("AD5: an unknown topic is an error listing the topics", {
  err <- tryCatch(weft::agent_docs("nonsense"), error = function(e) e)
  expect_s3_class(err, "error")
  msg <- conditionMessage(err)
  expect_match(msg, "nonsense", fixed = TRUE)
  for (t in c("skill", "reports", "syntax")) expect_match(msg, t, fixed = TRUE)
})

test_that("AD5: agent_docs() writes nothing", {
  d <- normalizePath(tempfile("adm-empty-"), mustWork = FALSE)
  dir.create(d)
  withr::local_dir(d)
  suppressMessages(utils::capture.output(weft::agent_docs()))
  suppressMessages(utils::capture.output(weft::agent_docs("syntax")))
  suppressMessages(utils::capture.output(weft::agent_docs("reports")))
  expect_identical(list.files(d, all.files = TRUE, recursive = TRUE, no.. = TRUE), character())
})

# ---- AD6: the notes ------------------------------------------------------------------------------

test_that("AD6: GEMINI.md without an import gets a note to add @AGENTS.md, and is not written", {
  d <- adm_proj(list(`GEMINI.md` = c("# Gemini", "", "Hello.")))
  s <- h4_say(weft::use_agent_docs(d))
  note <- s$lines[grepl("GEMINI\\.md", s$lines)]
  expect_true(any(grepl("@AGENTS.md", note, fixed = TRUE)))
  expect_identical(u4_read(d, "GEMINI.md"), c("# Gemini", "", "Hello."))
})

test_that("AD6: GEMINI.md with @AGENTS.md or @./AGENTS.md gets no note", {
  for (imp in c("@AGENTS.md", "@./AGENTS.md")) {
    d <- adm_proj(list(`GEMINI.md` = c("# Gemini", imp)))
    s <- h4_say(weft::use_agent_docs(d))
    expect_false(grepl("GEMINI", s$text, fixed = TRUE), label = imp)
    expect_identical(u4_read(d, "GEMINI.md"), c("# Gemini", imp), label = imp)
  }
})

test_that("AD6: no GEMINI.md: no note, and none is created", {
  d <- adm_proj()
  s <- h4_say(weft::use_agent_docs(d))
  expect_false(grepl("GEMINI", s$text, fixed = TRUE))
  expect_false(file.exists(adm_path(d, "GEMINI.md")))
})

test_that("AD6: the CLAUDE.md note is unchanged, and both notes can appear together", {
  d <- adm_proj(list(`CLAUDE.md` = "# Claude", `GEMINI.md` = "# Gemini"))
  s <- h4_say(weft::use_agent_docs(d))
  expect_true(ADM_CLAUDE_NOTE %in% s$lines)
  expect_true(any(grepl("GEMINI\\.md", s$lines) & grepl("@AGENTS.md", s$lines, fixed = TRUE)))
  expect_identical(u4_read(d, "CLAUDE.md"), "# Claude")
  expect_identical(u4_read(d, "GEMINI.md"), "# Gemini")
  d2 <- adm_proj(list(`CLAUDE.md` = c("# Claude", "@AGENTS.md")))
  s2 <- h4_say(weft::use_agent_docs(d2))
  expect_false(grepl("Claude Code reads CLAUDE.md", s2$text, fixed = TRUE))
})

# ---- AD7: status() and use_weft() ----------------------------------------------------------------

adm_full <- function(env = parent.frame()) {
  dir <- h4_repo(list(`index.qmd` = u4_qmd()), weft = character(), origin = ADM_GH, env = env)
  h4_weft(dir, env = env)
  dir
}

test_that("AD7: use_weft() writes the skill into both default folders, references included", {
  dir <- adm_full()
  for (f in c(".agents/skills", ".claude/skills")) {
    for (p in adm_files(f)) expect_true(file.exists(adm_path(dir, p)), label = p)
  }
})

test_that("AD7: status() reports agent docs current when the block and every copy are current", {
  dir <- adm_full()
  expect_identical(h4_state(h4_status(dir), "agent docs"), "ok")
  h4_agent(dir, skills = c("agents", "claude", "gemini"))
  expect_identical(h4_state(h4_status(dir), "agent docs"), "ok")
})

test_that("AD7: a stale copy in a preset folder makes agent docs not current and names the folder", {
  dir <- adm_full()
  h4_agent(dir, skills = c("agents", "claude", "gemini"))
  adm_stale(adm_path(dir, ".gemini/skills/weft/SKILL.md"))
  st <- h4_status(dir)
  expect_false(identical(h4_state(st, "agent docs"), "ok"))
  expect_identical(h4_state(st, "agent docs"), "outdated")
  expect_match(h4_detail(st, "agent docs"), ".gemini/skills", fixed = TRUE)
})

test_that("AD7: a stale reference under .agents/skills is also found", {
  dir <- adm_full()
  adm_stale(adm_path(dir, ".agents/skills/weft/references/syntax.md"))
  st <- h4_status(dir)
  expect_false(identical(h4_state(st, "agent docs"), "ok"))
  expect_match(h4_detail(st, "agent docs"), ".agents/skills", fixed = TRUE)
})

test_that("AD7: a project with no copy at all is reported missing, as now", {
  d <- adm_proj()
  git_env(); h4_env()
  expect_identical(h4_state(h4_status(d), "agent docs"), "missing")
})

# ---- AD8: what is unchanged ------------------------------------------------------------------------

test_that("AD8: a project holding only an old .claude SKILL.md gains the .agents copy at the next call", {
  d <- adm_proj()
  h4_agent(d, skills = "claude")
  unlink(adm_path(d, ".claude/skills/weft/references"), recursive = TRUE)
  adm_stale(adm_path(d, ".claude/skills/weft/SKILL.md"))
  expect_false(dir.exists(adm_path(d, ".agents")))
  h4_agent(d)
  for (p in adm_files(".agents/skills")) expect_true(file.exists(adm_path(d, p)), label = p)
  for (p in adm_files(".claude/skills")) expect_true(file.exists(adm_path(d, p)), label = p)
  expect_identical(unname(tools::md5sum(adm_path(d, ".agents/skills/weft/SKILL.md"))),
                   unname(tools::md5sum(adm_path(d, ".claude/skills/weft/SKILL.md"))))
})

test_that("AD8: the AGENTS.md block's text handling is unchanged: an edited block is left, overwrite replaces it", {
  d <- adm_proj()
  blk <- h4_block_lines()
  blk[3] <- paste(blk[3], "(my edit)")
  writeLines(c("# Agents", "", blk, "", "After."), adm_path(d, "AGENTS.md"))
  s <- h4_say(weft::use_agent_docs(d))
  expect_match(s$text, ADM_EDITED, fixed = TRUE)
  expect_identical(readLines(adm_path(d, "AGENTS.md")), c("# Agents", "", blk, "", "After."))
  h4_agent(d, overwrite = TRUE)
  expect_identical(readLines(adm_path(d, "AGENTS.md")), c("# Agents", "", h4_block_lines(), "", "After."))
})

test_that("AD8: calls write nothing in HOME, the cache or the project's parent", {
  rp <- h4_repo_in_parent()
  before <- h4_outside_snap(rp$parent)
  h4_agent(rp$dir)
  h4_agent(rp$dir, skills = c("gemini", "tools/skills"))
  expect_identical(h4_outside_snap(rp$parent), before)
})
