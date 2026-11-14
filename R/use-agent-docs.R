# use_agent_docs(): the AGENTS.md block and the Claude skill (design-4 G34, G40,
# G41, H25, F4).

#' Write the agent documents: an AGENTS.md block and a skill
#'
#' Writes, under the project root, a block in `AGENTS.md` (created when
#' absent) and the weft skill, that tell a coding agent the rules of a weft
#' project: a failed claim is a finding to report, a check is never changed to
#' make a render pass, a commit that removes constructs carries the
#' `Weft-Removed` trailer, and values for one chapter go in `dict_local`.
#'
#' The skill is `<folder>/weft/SKILL.md` with `references/syntax.md` and
#' `references/reports.md` beside it, written into each skills folder named by
#' `skills`. The same texts go into every folder. [agent_docs()] prints the
#' installed package's version of each.
#'
#' The `AGENTS.md` block sits between `<!-- weft:start ... -->` and
#' `<!-- weft:end -->` lines, appended after the file's last line with one
#' blank line before it; the rest of the file is never touched. The start line
#' and the last line of each skill file carry the weft version and a hash.
#' Each file is judged alone: one weft wrote and nobody edited is replaced when
#' its text would differ; an edited one is left as it is unless
#' `overwrite = TRUE`; a file with no weft line is another author's and is never
#' replaced. One copy being edited does not stop the others being written.
#'
#' When `CLAUDE.md` exists and does not hold `@AGENTS.md`, or `GEMINI.md`
#' exists and holds neither `@AGENTS.md` nor `@./AGENTS.md`, the call says to
#' add that line; neither file is written. It says what it will write first.
#' `suppressMessages()` silences it.
#'
#' @param path A directory in the project.
#' @param overwrite Replace a block or skill file weft wrote that has since
#'   been edited.
#' @param skills The skills folders to write into: a character vector of
#'   preset names or folders relative to the project root. The presets are
#'   `agents` (`.agents/skills`), `claude` (`.claude/skills`), `codex`
#'   (`.agents/skills`), `gemini` (`.gemini/skills`), `opencode`
#'   (`.opencode/skills`), `kimi` (`.kimi-code/skills`) and `cursor`
#'   (`.cursor/skills`). An item with a `/` or starting with `.` is a folder; an
#'   absolute path or one with a `..` part is an error. Folders that come to the
#'   same place are written once. `character()` writes the `AGENTS.md` block
#'   only.
#' @return The paths written, invisibly (`character()` when nothing changed):
#'   `AGENTS.md` first, then the skill files folder by folder in the order
#'   given.
#' @export
use_agent_docs <- function(path = ".", overwrite = FALSE, skills = c("agents", "claude")) {
  root <- install_root(path, "use_agent_docs")
  dirs <- skills_dirs(skills)
  plan <- agent_docs_plan(root, overwrite, dirs)
  announce_items(root, plan$items)
  done <- write_items(plan$items)
  for (n in plan$notes) message(n)
  if (length(done)) {
    # the announcement already named each file once: count them here
    message("Wrote: ", length(done), if (length(done) == 1L) " file" else " files", ", listed above.")
    return(invisible(vapply(done, `[[`, "", "path")))
  }
  finish_install(done, "the agent documents", plural = TRUE)
}

#' Print the agent documents of the installed package
#'
#' With no `topic`, prints the topics, one per line. With a topic (`"skill"`,
#' `"syntax"` or `"reports"`), prints that document as the installed package
#' ships it, without its marker line. The copies [use_agent_docs()] writes into
#' a project can be older than the package; this prints the version that
#' matches the installed code. Nothing is written.
#'
#' The text has the installed package's version in the `skill` front matter,
#' where [use_agent_docs()] writes the same version into a copy.
#'
#' @param topic `NULL`, or one of `"skill"`, `"syntax"`, `"reports"`.
#' @return The text as a character vector of lines, invisibly (the topics when
#'   `topic` is `NULL`).
#' @export
agent_docs <- function(topic = NULL) {
  topics <- agent_topics()
  if (is.null(topic)) {
    w <- max(nchar(names(topics)))
    lines <- sprintf("%-*s  %s", w, names(topics), unname(topics))
    cat(lines, sep = "\n")
    return(invisible(lines))
  }
  if (!is.character(topic) || length(topic) != 1L || is.na(topic) || !topic %in% names(topics)) {
    tool_abort(sprintf("agent_docs(): unknown topic %s. The topics are: %s.",
                       paste(format(topic), collapse = " "), paste(names(topics), collapse = ", ")))
  }
  lines <- agent_plain_lines(agent_topic_file(topic))
  cat(lines, sep = "\n")
  invisible(lines)
}

# a shipped document's lines with the marker line dropped and `@VERSION@` filled: what agent_docs()
# prints and what the repository's skills/ folder holds
agent_plain_lines <- function(file) {
  x <- read_source_lines(file)
  x <- x[!grepl("weft-file:", x, fixed = TRUE)]
  unname(subst_fixed(x, "@VERSION@", weft_version_string()))
}

# Write the skill as the repository's `skills/weft/` folder (SKILL.md and references/*.md) under `dir`,
# for the Agent Skills layout and the Claude Code plugin. Not use_agent_docs(): no marker line, as the
# copy is not one a project holds. Returns the paths written, relative to `dir`.
agent_repo_skill <- function(dir) {
  src <- skill_sources()
  out <- file.path("skills", "weft", names(src))
  for (i in seq_along(src)) {
    f <- file.path(dir, out[[i]])
    dir.create(dirname(f), recursive = TRUE, showWarnings = FALSE)
    con <- file(f, open = "wb")
    writeBin(charToRaw(paste0(paste(agent_plain_lines(src[[i]]), collapse = "\n"), "\n")), con)
    close(con)
  }
  out
}

AGENT_TOPICS <- c(skill = "the rules and the workflow (SKILL.md)",
                  reports = "how to read a failed render, a lint report and a refused commit",
                  syntax = "the constructs and their classes, one example each")
agent_topics <- function() AGENT_TOPICS
agent_topic_file <- function(topic) {
  if (topic == "skill") inst_file("agent", "SKILL.md") else inst_file("agent", "references", paste0(topic, ".md"))
}

SKILL_PRESETS <- c(agents = ".agents/skills", claude = ".claude/skills", codex = ".agents/skills",
                   gemini = ".gemini/skills", opencode = ".opencode/skills",
                   kimi = ".kimi-code/skills", cursor = ".cursor/skills")

# the folders (relative to the project root, once each, in order given) for `skills`
skills_dirs <- function(skills) {
  if (!is.character(skills) || anyNA(skills) || any(!nzchar(trimws(skills)))) {
    tool_abort("use_agent_docs(): `skills` must be a character vector of preset names or folders, with no NA and no empty string.")
  }
  out <- character()
  for (s in trimws(skills)) {
    if (!grepl("/", s, fixed = TRUE) && !startsWith(s, ".")) {
      if (!s %in% names(SKILL_PRESETS)) {
        tool_abort(sprintf("use_agent_docs(): %s is not a skills preset. The presets are: %s. Give a folder as a path with a / or starting with a dot.",
                           s, paste(names(SKILL_PRESETS), collapse = ", ")))
      }
      d <- SKILL_PRESETS[[s]]
    } else {
      d <- gsub("\\\\", "/", s)
      if (grepl("^(/|~|[A-Za-z]:)", d) || ".." %in% strsplit(d, "/", fixed = TRUE)[[1L]]) {
        tool_abort(sprintf("use_agent_docs(): %s is outside the project. Give a folder relative to the project root, with no .. part.", s))
      }
      d <- sub("^(\\./)+", "", d)
      d <- sub("/+$", "", gsub("/+", "/", d))
      if (!nzchar(d) || d == ".") {
        tool_abort(sprintf("use_agent_docs(): %s is not a skills folder.", s))
      }
    }
    out <- c(out, d)
  }
  unique(out)
}

# the shipped skill files: relative paths under a copy's weft/ folder, and the source of each
skill_sources <- function() {
  refs <- sort(list.files(inst_file("agent", "references"), pattern = "\\.md$"))
  c(list(`SKILL.md` = inst_file("agent", "SKILL.md")),
    stats::setNames(lapply(refs, function(r) inst_file("agent", "references", r)),
                    file.path("references", refs)))
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

agent_docs_plan <- function(root, overwrite = FALSE, dirs = c(".agents/skills", ".claude/skills")) {
  agents <- file.path(root, "AGENTS.md")
  place_check(agents, root)
  src <- skill_sources()
  texts <- lapply(src, function(f) fill_whole(read_source_lines(f), c("@VERSION@" = weft_version_string())))
  items <- list(agents_item(agents, root, overwrite))
  for (d in dirs) {
    for (rel in names(src)) {
      f <- file.path(root, d, "weft", rel)
      place_check(f, root)
      items[[length(items) + 1L]] <- whole_item(f, root, texts[[rel]], AGENT_FN,
                                                "the weft skill for coding agents", overwrite)
    }
  }
  notes <- character()
  for (spec in list(list("CLAUDE.md", "Claude Code", "@AGENTS.md"),
                    list("GEMINI.md", "Gemini CLI", c("@AGENTS.md", "@./AGENTS.md")))) {
    f <- file.path(root, spec[[1L]])
    if (file.exists(f) && !dir.exists(f)) {
      x <- read_source_lines(f)
      if (!any(vapply(spec[[3L]], function(k) any(grepl(k, x, fixed = TRUE)), TRUE))) {
        notes <- c(notes, sprintf("%s reads %s: add the line @AGENTS.md to it, or move the block there.",
                                  spec[[2L]], spec[[1L]]))
      }
    }
  }
  list(items = items, notes = notes)
}

# the state of the skill copies against the installed version, for status(): list(state, bits), where the
# state is missing (no copy anywhere), outdated, edited or ok, and `bits` names each copy that is not ok
skill_status <- function(root) {
  src <- names(skill_sources())
  worst <- c("missing", "outdated", "edited", "ok")
  found <- list()
  for (d in unique(unname(SKILL_PRESETS))) {
    sts <- vapply(src, function(rel) {
      s <- file_status(file.path(root, d, "weft", rel), AGENT_FN)
      if (s == "foreign") "edited" else s
    }, "")
    if (all(sts == "missing")) next
    skill_gone <- sts[["SKILL.md"]] == "missing"
    sts[sts == "missing"] <- "outdated"
    if (skill_gone) sts[] <- "missing"
    found[[d]] <- worst[min(match(sts, worst))]
  }
  if (!length(found)) return(list(state = "missing", bits = "skill: missing"))
  st <- worst[min(match(unlist(found), worst))]
  bad <- found[unlist(found) != "ok"]
  list(state = st,
       bits = if (length(bad)) sprintf("skill in %s: %s", names(bad), unlist(bad)) else "skill: ok")
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
