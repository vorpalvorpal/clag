# 4b: use_agent_docs() (G34, G40, G41, H25, F4): the AGENTS.md block and the Claude skill.
#
# READINGS ASSUMED:
#   - a new AGENTS.md is exactly the block (start line, the template's lines, end line); the file's
#     other content is kept byte for byte, an appended block follows one blank line (G34);
#   - the block's hash is the md5 of the block's lines other than the start line (the inner lines and
#     the end line, joined by "\n"). The tests that only read a block accept the md5 of the inner lines
#     alone too; the tests that forge an older block use the first (literal G40) reading;
#   - the skill's marker is its last line, `<!-- weft-file: use_agent_docs <version> <hash> -->`,
#     the hash over the other lines (G40);
#   - a SKILL.md with no marker is another author's: left, no error, also under overwrite = TRUE;
#   - the project root is find_project_root(path): a folder holding _weft.yml.

ad_proj <- function(files = list()) u4_dir(c(list(`_weft.yml` = "draft: false"), files))
agents <- function(d) file.path(d, "AGENTS.md")
skill <- function(d) file.path(d, ".claude", "skills", "weft", "SKILL.md")
EDITED_MSG_AD <- "edited since weft wrote it; left as it is (use overwrite = TRUE to replace it)"
CLAUDE_ADVICE <- "Claude Code reads CLAUDE.md: add the line @AGENTS.md to it, or move the block there."

test_that("4b G34: a project with neither file gets exactly AGENTS.md and the skill, and nothing else", {
  d <- ad_proj()
  before <- tree(d)
  res <- h4_agent(d)
  expect_setequal(setdiff(tree(d), before), c("AGENTS.md", ".claude/skills/weft/SKILL.md"))
  expect_setequal(u4_rel(res, d), c("AGENTS.md", ".claude/skills/weft/SKILL.md"))
})

test_that("4b G34: use_agent_docs() returns the paths written, invisibly", {
  d <- ad_proj()
  suppressMessages(expect_invisible(weft::use_agent_docs(d)))
})

test_that("4b G34: a new AGENTS.md is the block: the start marker with version and hash, the template, the end marker", {
  d <- ad_proj()
  h4_agent(d)
  x <- readLines(agents(d))
  b <- h4_block_parse(x)
  expect_false(is.null(b))
  expect_identical(b$version, u4_version())
  expect_true(b$hash_ok)
  expect_identical(h4_trim_blank(b$inner), H4_AGENTS_INNER)
  expect_identical(h4_trim_blank(x), x)
  expect_identical(x[1], sprintf("<!-- weft:start use_agent_docs %s %s -->", u4_version(), b$hash))
  expect_identical(x[length(x)], "<!-- weft:end -->")
})

test_that("4b G34: the block text is the design's (heading, the four rules, the pointer to the skill)", {
  d <- ad_proj()
  h4_agent(d)
  inner <- h4_block_parse(readLines(agents(d)))$inner
  expect_true("## weft" %in% inner)
  expect_true(any(grepl("A failed claim is a finding to report to the author, not an error to clear.", inner, fixed = TRUE)))
  expect_true(any(grepl("Do not use", inner, fixed = TRUE)) && any(grepl("--no-verify", inner, fixed = TRUE)))
  expect_true(any(grepl("The weft skill (`.claude/skills/weft/`) has the detail.", inner, fixed = TRUE)))
})

test_that("4b G34: a file without the block gets it appended after the last line, one blank line before it, the rest untouched", {
  d <- ad_proj()
  orig <- c("# Agents", "", "Be kind to the build.", "", "- one", "- two")
  writeLines(orig, agents(d))
  h4_agent(d)
  x <- readLines(agents(d))
  expect_identical(x[seq_along(orig)], orig)
  expect_identical(x[length(orig) + 1L], "")
  expect_identical(h4_block_parse(x)$start, length(orig) + 2L)
  expect_identical(x[length(x)], "<!-- weft:end -->")
  expect_identical(length(x), length(orig) + 1L + length(h4_block_lines()))
})

test_that("4b G34: a file whose last line has no newline still gets the block on its own lines", {
  d <- ad_proj()
  writeBin(charToRaw("# Agents\n\nNo newline at the end"), agents(d))
  h4_agent(d)
  x <- readLines(agents(d), warn = FALSE)
  expect_identical(x[1:3], c("# Agents", "", "No newline at the end"))
  expect_identical(x[4], "")
  expect_false(is.null(h4_block_parse(x)))
})

test_that("4b G34: a second run changes nothing and says so", {
  d <- ad_proj(list(`AGENTS.md` = c("# Agents", "", "Mine.")))
  h4_agent(d)
  before <- h4_snap(d)
  s <- h4_say(weft::use_agent_docs(d))
  expect_match(s$text, "Nothing to change", fixed = TRUE)
  expect_identical(s$value, character())
  expect_identical(h4_snap(d), before)
})

test_that("4b G34: a block from an older template is replaced in place; the text before and after is untouched", {
  d <- ad_proj()
  before <- c("# Agents", "", "Text above.", "")
  after <- c("", "Text below.", "", "- last")
  writeLines(c(before, h4_block_old(), after), agents(d))
  res <- h4_agent(d)
  x <- readLines(agents(d))
  expect_identical(x, c(before, h4_block_lines(), after))
  expect_identical(u4_rel(res, d), "AGENTS.md")
})

test_that("4b G40: an edited block is left as it is with the message; overwrite = TRUE replaces it, outside text kept", {
  d <- ad_proj()
  blk <- h4_block_lines()
  blk[3] <- paste(blk[3], "(my edit)")
  txt <- c("# Agents", "", blk, "", "After.")
  writeLines(txt, agents(d))
  s <- h4_say(weft::use_agent_docs(d))
  expect_identical(readLines(agents(d)), txt)
  expect_match(s$text, EDITED_MSG_AD, fixed = TRUE)
  h4_agent(d, overwrite = TRUE)
  expect_identical(readLines(agents(d)), c("# Agents", "", h4_block_lines(), "", "After."))
})

test_that("4b G34: text of the author's outside the block is untouched when the block is replaced, byte for byte", {
  d <- ad_proj()
  outside_top <- c("# Mine", "", "Keep  trailing spaces  ", "\ttab line", "")
  outside_bottom <- c("", "## Other section", "", "More.")
  writeLines(c(outside_top, h4_block_old(), outside_bottom), agents(d))
  h4_agent(d)
  x <- readLines(agents(d))
  expect_identical(x[seq_along(outside_top)], outside_top)
  expect_identical(x[(length(x) - length(outside_bottom) + 1L):length(x)], outside_bottom)
})

test_that("4b G34: the block is written once: a second run after an append does not add a second block", {
  d <- ad_proj(list(`AGENTS.md` = "# Agents"))
  h4_agent(d)
  h4_agent(d)
  x <- readLines(agents(d))
  expect_identical(sum(grepl("^<!-- weft:start", x)), 1L)
  expect_identical(sum(grepl("^<!-- weft:end -->$", x)), 1L)
})

# ---- the CLAUDE.md advice ------------------------------------------------------------------------

test_that("4b G34: CLAUDE.md present without @AGENTS.md: the advice is printed", {
  d <- ad_proj(list(`CLAUDE.md` = c("# Claude", "", "Hello.")))
  s <- h4_say(weft::use_agent_docs(d))
  expect_true(CLAUDE_ADVICE %in% s$lines)
  # CLAUDE.md itself is not touched
  expect_identical(u4_read(d, "CLAUDE.md"), c("# Claude", "", "Hello."))
})

test_that("4b G34: CLAUDE.md that already holds @AGENTS.md: no advice", {
  d <- ad_proj(list(`CLAUDE.md` = c("# Claude", "@AGENTS.md")))
  s <- h4_say(weft::use_agent_docs(d))
  expect_false(grepl("Claude Code reads CLAUDE.md", s$text, fixed = TRUE))
})

test_that("4b G34: no CLAUDE.md: no advice", {
  d <- ad_proj()
  s <- h4_say(weft::use_agent_docs(d))
  expect_false(grepl("Claude Code reads CLAUDE.md", s$text, fixed = TRUE))
  expect_false(file.exists(file.path(d, "CLAUDE.md")))
})

# ---- the skill -----------------------------------------------------------------------------------

test_that("4b G34: the skill's front matter names it weft and carries the design's description", {
  d <- ad_proj()
  h4_agent(d)
  x <- readLines(skill(d))
  expect_identical(x[1], "---")
  end <- which(x == "---")[2]
  fm <- yaml::yaml.load(paste(x[2:(end - 1L)], collapse = "\n"))
  expect_identical(fm$name, "weft")
  expect_identical(trimws(gsub("\\s+", " ", fm$description)), H4_SKILL_DESCRIPTION)
})

test_that("4b G34/G40: the skill's last line is the HTML-comment marker and its hash is that of the other lines", {
  d <- ad_proj()
  h4_agent(d)
  x <- readLines(skill(d))
  m <- h4_marker(x)
  expect_identical(m$idx, length(x))
  expect_match(x[length(x)], "^<!-- weft-file: use_agent_docs \\S+ [0-9a-f]{32} -->$")
  expect_identical(m$version, u4_version())
  expect_identical(m$hash, cli::hash_md5(paste(x[-length(x)], collapse = "\n")))
})

test_that("4b G34: the skill is ASCII and under 80 lines", {
  d <- ad_proj()
  h4_agent(d)
  raw <- readBin(skill(d), "raw", file.size(skill(d)))
  expect_true(all(raw < as.raw(128)))
  expect_lt(length(readLines(skill(d))), 80L)
})

test_that("4b G34: the skill's body covers the trailer, --trailer, lints(), verify(), dict_local, draft mode and the four rules", {
  d <- ad_proj()
  h4_agent(d)
  txt <- paste(readLines(skill(d)), collapse = "\n")
  for (needle in c("Weft-Removed", "git commit --trailer \"Weft-Removed: N\"", "weft::lints()", "weft::verify()",
                   "dict_local", "--no-verify", ".weft-literal", "claim()")) {
    expect_true(grepl(needle, txt, fixed = TRUE), label = needle)
  }
  expect_match(txt, "draft", ignore.case = TRUE)
})

test_that("4b G40: an edited skill is left with the message; overwrite = TRUE replaces it", {
  d <- ad_proj()
  h4_agent(d)
  orig <- readLines(skill(d))
  edited <- append(orig, "My own rule.", after = length(orig) - 1L)
  writeLines(edited, skill(d))
  s <- h4_say(weft::use_agent_docs(d))
  expect_identical(readLines(skill(d)), edited)
  expect_match(s$text, EDITED_MSG_AD, fixed = TRUE)
  h4_agent(d, overwrite = TRUE)
  expect_identical(readLines(skill(d)), orig)
})

test_that("4b G40: a skill from an older template (marker and hash valid) is replaced without overwrite", {
  d <- ad_proj()
  h4_agent(d)
  cur <- readLines(skill(d))
  old <- h4_forge(cur, function(b) c(b[1:2], "An older line.", b[-(1:2)]), version = "0.0.1")
  expect_true(h4_marker_valid(old))
  writeLines(old, skill(d))
  h4_agent(d)
  expect_identical(readLines(skill(d)), cur)
})

test_that("4b G40: a SKILL.md with no marker (someone else's) is left, with or without overwrite, and is not an error", {
  d <- ad_proj()
  mine <- c("---", "name: weft", "description: mine", "---", "My skill.")
  f3_write(skill(d), mine)
  expect_no_error(suppressMessages(weft::use_agent_docs(d)))
  expect_identical(readLines(skill(d)), mine)
  suppressMessages(weft::use_agent_docs(d, overwrite = TRUE))
  expect_identical(readLines(skill(d)), mine)
})

test_that("4b G41: it says what it will write before it writes, lists both files, then says what it wrote", {
  d <- ad_proj()
  early <- NULL
  s <- h4_say(weft::use_agent_docs(d),
              first = function() early <<- file.exists(agents(d)) || file.exists(skill(d)))
  expect_false(early)
  expect_match(s$text, "weft will write", fixed = TRUE)
  expect_match(s$text, "AGENTS.md", fixed = TRUE)
  expect_match(s$text, ".claude/skills/weft/SKILL.md  (new: ", fixed = TRUE)
  expect_match(s$text, "Wrote: ", fixed = TRUE)
})

test_that("4b G41: silent under suppressMessages()", {
  d <- ad_proj()
  expect_identical(utils::capture.output(suppressMessages(weft::use_agent_docs(d))), character())
})

test_that("4b G41: a folder in AGENTS.md's place is a weft_tool_error naming the path, and nothing is written", {
  d <- ad_proj(list(`AGENTS.md/keep.txt` = "x"))
  before <- h4_snap(d)
  err <- tryCatch(suppressMessages(weft::use_agent_docs(d)), error = function(e) e)
  expect_s3_class(err, "weft_tool_error")
  expect_match(conditionMessage(err), "AGENTS.md", fixed = TRUE)
  expect_identical(h4_snap(d), before)
})

test_that("4b G41: a symbolic link in AGENTS.md's place is a weft_tool_error, its target untouched and the skill not written", {
  skip_on_os("windows")
  d <- ad_proj()
  target <- tempfile("h4-target-"); writeLines("# elsewhere", target)
  file.symlink(target, agents(d))
  before <- unname(tools::md5sum(target))
  err <- tryCatch(suppressMessages(weft::use_agent_docs(d)), error = function(e) e)
  expect_s3_class(err, "weft_tool_error")
  expect_identical(unname(tools::md5sum(target)), before)
  expect_false(file.exists(skill(d)))
})

test_that("4b G41: a folder in the skill's place is a weft_tool_error, and AGENTS.md is not written either", {
  d <- ad_proj(list(`.claude/skills/weft/SKILL.md/keep.txt` = "x"))
  err <- tryCatch(suppressMessages(weft::use_agent_docs(d)), error = function(e) e)
  expect_s3_class(err, "weft_tool_error")
  expect_false(file.exists(agents(d)))
})

test_that("4b G34: it writes under the project root, found from a subfolder", {
  d <- ad_proj(list(`sub/ch1.qmd` = G_PROSE))
  h4_agent(file.path(d, "sub"))
  expect_true(file.exists(agents(d)))
  expect_true(file.exists(skill(d)))
  expect_false(file.exists(file.path(d, "sub", "AGENTS.md")))
})

test_that("4b G3: use_agent_docs() writes nothing in HOME, the cache folder or the parent of the project", {
  rp <- h4_repo_in_parent()
  before <- h4_outside_snap(rp$parent)
  h4_agent(rp$dir)
  h4_agent(rp$dir)
  expect_identical(h4_outside_snap(rp$parent), before)
})
