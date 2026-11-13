# use_agent_docs(): the AGENTS.md block and the Claude skill (design-4 G34, G40,
# G41, H25, F4).

#' Write the agent documents: an AGENTS.md block and a Claude skill
#'
#' Writes, under the project root, `.claude/skills/weft/SKILL.md` and a block
#' in `AGENTS.md` (created when absent) that tell a coding agent the rules of a
#' weft project: a failed claim is a finding to report, a check is never
#' changed to make a render pass, a commit that removes constructs carries the
#' `Weft-Removed` trailer, and values for one chapter go in `dict_local`.
#'
#' The block sits between `<!-- weft:start ... -->` and `<!-- weft:end -->`
#' lines, appended after the file's last line with one blank line before it;
#' the rest of the file is never touched. The start line and the skill's last
#' line carry the weft version and a hash. A block or skill weft wrote and
#' nobody edited is replaced when its text would differ; an edited one is left
#' as it is unless `overwrite = TRUE`; a `SKILL.md` with no weft line is
#' another author's and is never replaced. When `CLAUDE.md` exists and does not
#' hold `@AGENTS.md`, the call says to add that line. It says what it will
#' write first. `suppressMessages()` silences it.
#'
#' @param path A directory in the project.
#' @param overwrite Replace a block or skill weft wrote that has since been edited.
#' @return The paths written, invisibly (`character()` when nothing changed).
#' @export
use_agent_docs <- function(path = ".", overwrite = FALSE) {
  root <- install_root(path, "use_agent_docs")
  plan <- agent_docs_plan(root, overwrite)
  announce_items(root, plan$items)
  done <- write_items(plan$items)
  if (nzchar(plan$note)) message(plan$note)
  finish_install(done, "the agent documents")
}

AGENT_FN <- "use_agent_docs"
BLOCK_END <- "<!-- weft:end -->"
BLOCK_START_RE <- "^<!-- weft:start use_agent_docs "

# the block's lines (start, inner, end) for the shipped text
agent_block_lines <- function() {
  inner <- read_source_lines(inst_file("agent", "AGENTS.md"))
  h <- cli::hash_md5(paste(c(inner, BLOCK_END), collapse = "\n"))
  c(sprintf("<!-- weft:start use_agent_docs %s %s -->", weft_version_string(), h), inner, BLOCK_END)
}

# where the block is in `lines`: list(s, e, version, valid), NULL for none, or
# list(broken = TRUE) when a start line has no end line or an unreadable marker
block_find <- function(lines) {
  s <- grep(BLOCK_START_RE, lines)
  if (!length(s)) return(NULL)
  s <- s[1L]
  e <- which(trimws(lines) == BLOCK_END & seq_along(lines) > s)
  m <- regmatches(lines[s], regexec("^<!-- weft:start use_agent_docs (\\S+) ([0-9a-f]{32}) -->\\s*$",
                                   lines[s]))[[1L]]
  if (!length(e) || length(m) != 3L) return(list(broken = TRUE))
  e <- e[1L]
  inner <- lines[seq_len(e - s - 1L) + s]
  list(s = s, e = e, version = m[2L],
       valid = identical(m[3L], cli::hash_md5(paste(c(inner, lines[e]), collapse = "\n"))))
}

# the AGENTS.md item: the whole file's new lines
agents_item <- function(path, root, overwrite) {
  block <- agent_block_lines()
  purpose <- "the weft rules for coding agents"
  if (!file.exists(path)) {
    return(plan_item(path, root, "new", purpose, new = block))
  }
  old <- read_source_lines(path)
  eol <- file_eol(path)
  b <- block_find(old)
  if (is.null(b)) {
    return(plan_item(path, root, "edit", paste0("adds the weft block: ", purpose),
                     new = c(old, if (length(old)) "", block), eol = eol))
  }
  if (isTRUE(b$broken) || (!b$valid && !overwrite)) {
    return(plan_item(path, root, "edited", ""))
  }
  cur <- old[b$s:b$e]
  if (identical(cur, block)) return(plan_item(path, root, "keep", purpose))
  plan_item(path, root, "replace", purpose,
            new = c(old[seq_len(b$s - 1L)], block, old[-seq_len(b$e)]), eol = eol)
}

agent_docs_plan <- function(root, overwrite = FALSE) {
  agents <- file.path(root, "AGENTS.md")
  skill <- file.path(root, ".claude", "skills", "weft", "SKILL.md")
  place_check(agents, root)
  place_check(skill, root)
  new_skill <- fill_whole(read_source_lines(inst_file("agent", "SKILL.md")))
  items <- list(
    agents_item(agents, root, overwrite),
    whole_item(skill, root, new_skill, AGENT_FN, "the weft skill for coding agents", overwrite))
  claude <- file.path(root, "CLAUDE.md")
  note <- ""
  if (file.exists(claude) && !dir.exists(claude) &&
      !any(grepl("@AGENTS.md", read_source_lines(claude), fixed = TRUE))) {
    note <- "Claude Code reads CLAUDE.md: add the line @AGENTS.md to it, or move the block there."
  }
  list(items = items, note = note)
}

# the state of the AGENTS.md block against the installed version, for status():
# missing, edited, outdated, ok
block_status <- function(path) {
  if (!file.exists(path) || dir.exists(path)) return("missing")
  b <- block_find(read_source_lines(path))
  if (is.null(b)) return("missing")
  if (isTRUE(b$broken) || !b$valid) return("edited")
  if (!identical(b$version, weft_version_string())) "outdated" else "ok"
}
