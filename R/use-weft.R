# use_weft() and status(): the installers in order from one plan, and the report
# of what is installed (design-4 G38, G39, G32, H26, H35).

QUARTO_COPIES <- c(
  "_extensions/weft-check/_extension.yml" = "_extension.yml",
  "_extensions/weft-check/weft-check.lua" = "weft-check.lua",
  "_weft/pre-render.R"                    = "weft-pre-render.R",
  "_weft/post-render.R"                   = "weft-post-render.R")

# ---- use_weft() -----------------------------------------------------------------

#' Set up a project for weft: every installer, from one plan
#'
#' Runs, in order, [use_setup()], [use_quarto()] (a Quarto project only),
#' [use_dictionary()], [use_hooks()] (in a git work tree), [use_ci()] (when
#' `origin` is on github.com) and [use_agent_docs()], then sets the
#' `weft_version` line of `_weft.yml` to the installed version (it updates an
#' existing line in place). Run it again after updating weft to bring the files
#' weft installed up to date.
#'
#' It plans every step first, prints the plan (`weft will set up <root>:`, then
#' one line per step), and then writes. When any step cannot be done safely (a
#' `_quarto.yml` or front matter it cannot edit, a link or a folder in a file's
#' place) it writes nothing and stops with that step's message. A step that
#' fails while writing (a folder that cannot be written to) undoes what the
#' earlier steps wrote: files it created are removed and files it changed are
#' put back, and the message says what was undone. It never asks,
#' whether the session is interactive or not: the call is the consent.
#' `suppressMessages()` silences it. [dict_vale()] is not called: it is a tool,
#' not set-up.
#'
#' @param path A folder or one document, as for [use_setup()].
#' @return The paths written, invisibly (`character()` when nothing changed).
#' @export
use_weft <- function(path = ".") {
  setup <- setup_plan(path, "auto")
  root <- setup$root
  steps <- list()
  add <- function(fn, what, run) steps[[length(steps) + 1L]] <<- list(fn = fn, what = what, run = run)

  # use_setup(), and the version line
  vline <- version_line_update(root, setup)
  setup_what <- c(
    vapply(Filter(function(w) !is.null(w$new), setup$writes),
           function(w) sprintf("%s (%s)", w$rel, w$state), ""),
    if (!is.null(vline)) "_weft.yml (edit)")
  add("use_setup", if (length(setup_what)) paste(setup_what, collapse = ", ") else "nothing to change",
      function() {
        written <- character()
        if (length(setup_what)) {
          rel <- suppressMessages(use_setup(path))
          written <- file.path(root, rel)
        }
        v <- version_line_update(root, NULL)
        if (!is.null(v)) {
          write_lines_atomic(v, file.path(root, "_weft.yml"), file_eol(file.path(root, "_weft.yml")))
          written <- c(written, file.path(root, "_weft.yml"))
        }
        unique(written)
      })

  # use_quarto()
  if (!is.null(find_quarto_root(root))) {
    qroot <- find_quarto_root(root)
    q <- quarto_plan(qroot)
    add("use_quarto", if (length(q)) paste(q, collapse = ", ") else "nothing to change",
        function() {
          if (!length(q)) return(character())
          rel <- suppressMessages(use_quarto(qroot))
          file.path(qroot, rel)
        })
  }

  # use_dictionary()
  d <- dictionary_plan(root)
  add("use_dictionary", if (length(d)) paste(d, collapse = ", ") else "nothing to change",
      function() {
        if (!length(d)) return(character())
        rel <- suppressMessages(use_dictionary(root))
        file.path(root, rel)
      })

  # use_hooks(), use_ci()
  g <- git_state(root)
  if (!g$ok) {
    add("use_hooks", "skipped: not a git repository", function() character())
    add("use_ci", "skipped: not a git repository", function() character())
  } else {
    hp <- hooks_plan(root)
    add("use_hooks", items_what(hp$items), function() {
      done <- write_items(hp$items)
      if (nzchar(hp$notes)) message(hp$notes)
      vapply(done, `[[`, "", "path")
    })
    if (origin_on_github(git_origin(root))) {
      cp <- ci_plan(root)
      add("use_ci", items_what(cp$items), function() vapply(write_items(cp$items), `[[`, "", "path"))
    } else {
      add("use_ci", "skipped: origin is not on GitHub", function() character())
    }
  }

  # use_agent_docs()
  ap <- agent_docs_plan(root)
  add("use_agent_docs", items_what(ap$items), function() {
    done <- write_items(ap$items)
    if (nzchar(ap$note)) message(ap$note)
    vapply(done, `[[`, "", "path")
  })

  message("weft will set up ", root, ":")
  for (s in steps) message(sprintf("  %-15s %s", s$fn, s$what))

  # a step that fails undoes what the earlier ones wrote (review 4, #10): every file a step can touch is
  # copied first, and put back (or removed, when it was new) if any step stops
  cand <- unique(c(
    vapply(setup$writes, `[[`, "", "path"), file.path(root, "_weft.yml"),
    if (!is.null(find_quarto_root(root))) {
      qr <- find_quarto_root(root)
      c(file.path(qr, names(QUARTO_COPIES)), file.path(qr, QUARTO_MARKERS))
    },
    file.path(root, "dict.yml"), file.path(root, "_weft", "dict.schema.json"),
    if (g$ok) vapply(hp$items, `[[`, "", "path"),
    if (g$ok && exists("cp", inherits = FALSE)) vapply(cp$items, `[[`, "", "path"),
    vapply(ap$items, `[[`, "", "path")))
  snap <- install_snapshot(cand)
  on.exit(unlink(snap$dir, recursive = TRUE), add = TRUE)

  written <- character()
  tryCatch({
    for (s in steps) written <- c(written, s$run())
  }, error = function(e) {
    undone <- install_rollback(snap, root)
    msg <- sub("(?s)\\s*(Nothing was written\\.|Written before it failed:.*)$", "", conditionMessage(e), perl = TRUE)
    msg <- paste0(msg, if (length(undone)) {
      sprintf(" use_weft() undid what it had written, so the project is as it was: %s.", paste(undone, collapse = ", "))
    } else {
      " Nothing was written."
    })
    if (inherits(e, "weft_tool_error")) tool_abort(msg) else stop(e)
  })
  written <- unique(written)
  if (length(written)) {
    message("Wrote: ", paste(rel_label(written, root), collapse = ", "))
  } else {
    message("Nothing to change: the project is already set up.")
  }
  invisible(written)
}

# Copy the files in `paths` that exist (and note the folders that do not), so that install_rollback() can
# put the project back. Returns list(dir, files, dirs).
install_snapshot <- function(paths) {
  dir <- tempfile("weft-undo-")
  dir.create(dir)
  paths <- paths[!is.na(paths)]
  have <- file.exists(paths) & !dir.exists(paths)
  copies <- character()
  modes <- character()
  for (i in which(have)) {
    to <- file.path(dir, as.character(i))
    if (file.copy(paths[i], to, copy.mode = TRUE)) {
      copies[paths[i]] <- to
      modes[paths[i]] <- format(file.info(paths[i])$mode)
    }
  }
  new_dirs <- character()
  for (p in paths[!have]) {
    d <- dirname(p)
    while (!dir.exists(d) && !identical(d, dirname(d))) {
      new_dirs <- c(new_dirs, d)
      d <- dirname(d)
    }
  }
  list(dir = dir, paths = paths, copies = copies, modes = modes, dirs = unique(new_dirs))
}

# Put back what install_snapshot() saw: a file that was there is restored when it changed, a file that was
# not is removed, and folders made since are removed when empty. Returns the labels of what was undone.
install_rollback <- function(snap, root) {
  undone <- character()
  for (p in snap$paths) {
    was <- p %in% names(snap$copies)
    if (was) {
      same <- file.exists(p) && identical(unname(tools::md5sum(p)), unname(tools::md5sum(snap$copies[[p]])))
      if (!same) {
        copy_atomic(snap$copies[[p]], p)
        undone <- c(undone, rel_label(p, root))
      }
    } else if (file.exists(p) && !dir.exists(p)) {
      unlink(p)
      undone <- c(undone, rel_label(p, root))
    }
  }
  for (d in snap$dirs[order(nchar(snap$dirs), decreasing = TRUE)]) {
    if (dir.exists(d) && !length(list.files(d, all.files = TRUE, no.. = TRUE))) unlink(d, recursive = TRUE)
  }
  undone
}

items_what <- function(items) {
  ch <- Filter(function(w) w$state != "keep", items)
  if (!length(ch)) return("nothing to change")
  paste(vapply(ch, function(w) sprintf("%s (%s)", w$label, w$state), ""), collapse = ", ")
}

# the new lines of _weft.yml with its weft_version line set to the installed
# version, or NULL when there is no such line or it is already right. `setup`
# (a use_setup() plan) is looked at when _weft.yml is not written yet.
version_line_update <- function(root, setup) {
  f <- file.path(root, "_weft.yml")
  if (!file.exists(f) || dir.exists(f)) return(NULL)
  x <- read_source_lines(f)
  i <- grep("^weft_version\\s*:", x)
  if (!length(i)) return(NULL)
  now <- weft_version_string()
  if (identical(recorded_version(root), now)) return(NULL)
  x[i[1L]] <- paste0("weft_version: ", now)
  x
}

# use_quarto(): what it would write, as "file (state)"; errors when _quarto.yml
# cannot be edited
quarto_plan <- function(qroot) {
  yml <- QUARTO_MARKERS
  qy <- file.path(qroot, yml[file.exists(file.path(qroot, yml))][1L])
  old <- read_source_lines(qy)
  if (is.null(quarto_yml_with_weft(old))) {
    tool_abort(paste0("weft cannot edit ", basename(qy), " as text without risking what is in it, so it ",
                      "has changed nothing. Add these lines by hand, then run use_weft() again:\n\n",
                      paste(c("filters:", "  - weft-check", "project:", "  pre-render: _weft/pre-render.R",
                              "  post-render: _weft/post-render.R"), collapse = "\n")))
  }
  out <- character()
  for (rel in names(QUARTO_COPIES)) {
    dest <- file.path(qroot, rel)
    place_check(dest, qroot)
    src <- inst_file("quarto", QUARTO_COPIES[[rel]])
    if (!file.exists(dest)) {
      out <- c(out, sprintf("%s (new)", rel))
    } else if (!identical(unname(tools::md5sum(dest)), unname(tools::md5sum(src)))) {
      out <- c(out, sprintf("%s (replace)", rel))
    }
  }
  if (!identical(quarto_yml_with_weft(old), old)) out <- c(out, sprintf("%s (edit)", basename(qy)))
  out
}

# use_dictionary(): what it would write; errors when a place is blocked
dictionary_plan <- function(root) {
  dict <- file.path(root, "dict.yml")
  weft_dir <- file.path(root, "_weft")
  schema <- file.path(weft_dir, "dict.schema.json")
  place_check(dict, root)
  place_check(schema, root)
  if (is_link(weft_dir)) {
    tool_abort(sprintf("%s is a symbolic link, and weft does not write through links. Nothing was written.",
                       weft_dir))
  }
  out <- character()
  if (!file.exists(dict)) out <- c(out, "dict.yml (new)")
  src <- inst_file("dict", "dict.schema.json")
  if (!file.exists(schema)) {
    out <- c(out, "_weft/dict.schema.json (new)")
  } else if (!identical(unname(tools::md5sum(schema)), unname(tools::md5sum(src)))) {
    out <- c(out, "_weft/dict.schema.json (replace)")
  }
  out
}

# ---- status() ---------------------------------------------------------------------

#' What weft has installed in a project
#'
#' Reports the state of each part of the set-up: `setup` (`_weft.yml` and the
#' version it records), `activation`, `quarto`, `dictionary`, `hooks`, `ci`,
#' `agent docs`, `draft`, `verify_skip` and `strict`. It writes nothing, starts
#' no R process and uses no network.
#'
#' `state` is one of `ok`, `missing`, `outdated` (weft's file is from another
#' version, or the hook's recorded `Rscript` has gone), `edited` (a file weft
#' wrote has been changed by hand: it is left alone and never makes a next
#' step), `off` (draft mode on, or parts of `verify()` skipped) and `n/a`. The
#' `next` attribute is the first part, in the order of [use_weft()], that is
#' `missing` or `outdated`, as a sentence; otherwise it says there is nothing to
#' install.
#'
#' @param path A directory in the project.
#' @return A `weft_status`: a data frame with `part`, `state` and `detail`, and
#'   the attribute `next`.
#' @export
status <- function(path = ".") {
  root <- install_root(path, "status")
  rows <- list()
  nexts <- list()
  add <- function(part, state, detail, fn = NA_character_, purpose = NA_character_) {
    rows[[length(rows) + 1L]] <<- data.frame(part = part, state = state, detail = detail,
                                             stringsAsFactors = FALSE)
    if (state %in% c("missing", "outdated") && !is.na(fn)) {
      nexts[[length(nexts) + 1L]] <<- sprintf("Next: run weft::%s() to %s.", fn, purpose)
    }
  }
  inst <- weft_version_string()
  wy <- file.path(root, "_weft.yml")
  cfg <- tryCatch(if (file.exists(wy) && !dir.exists(wy)) yaml_read_file(wy) else NULL,
                  error = function(e) NULL)
  if (!is.list(cfg)) cfg <- list()

  # setup
  if (!file.exists(wy)) {
    add("setup", "missing", "no _weft.yml", "use_setup", "write _weft.yml and record the weft version")
  } else {
    rec <- recorded_version(root)
    if (is.na(rec)) {
      add("setup", "ok", sprintf("_weft.yml does not record a weft version (not recorded; installed: %s)", inst))
    } else if (!identical(rec, inst)) {
      add("setup", "outdated", sprintf("_weft.yml records weft %s (installed: %s)", rec, inst),
          "use_weft", "update the files weft installed and the record")
    } else {
      add("setup", "ok", sprintf("_weft.yml records weft %s (installed: %s)", rec, inst))
    }
  }

  # activation
  act <- status_activation(root)
  add("activation", act$state, act$detail, "use_setup", "activate weft in the documents")

  # quarto
  q <- status_quarto(root)
  add("quarto", q$state, q$detail, "use_quarto", "install the Quarto filter and scripts")

  # dictionary
  dict <- file.path(root, "dict.yml")
  schema <- file.path(root, "_weft", "dict.schema.json")
  src <- system.file("dict", "dict.schema.json", package = "weft")
  if (!file.exists(dict)) {
    add("dictionary", "missing", "no dict.yml", "use_dictionary", "write the starter dictionary and its schema")
  } else if (!file.exists(schema)) {
    add("dictionary", "missing", "dict.yml has no schema (_weft/dict.schema.json)",
        "use_dictionary", "write the starter dictionary and its schema")
  } else if (nzchar(src) && !identical(unname(tools::md5sum(schema)), unname(tools::md5sum(src)))) {
    add("dictionary", "outdated", "_weft/dict.schema.json is not this version's schema",
        "use_dictionary", "write the starter dictionary and its schema")
  } else {
    add("dictionary", "ok", "dict.yml and its schema are in place")
  }

  # hooks, ci
  g <- git_state(root)
  if (!g$ok) {
    add("hooks", "n/a", g$reason)
    add("ci", "n/a", g$reason)
  } else {
    h <- status_hook(root)
    add("hooks", h$state, h$detail, "use_hooks", "install the commit-msg hook")
    c_ <- status_ci(root, g$top)
    add("ci", c_$state, c_$detail, "use_ci", "write the GitHub Actions workflow")
  }

  # agent docs
  skill <- file.path(root, ".claude", "skills", "weft", "SKILL.md")
  bs <- block_status(file.path(root, "AGENTS.md"))
  ss <- file_status(skill, AGENT_FN)
  ss <- if (ss == "foreign") "edited" else ss
  worst <- c("missing", "outdated", "edited", "ok")
  st <- worst[min(match(c(bs, ss), worst))]
  bits <- c(sprintf("AGENTS.md block: %s", bs), sprintf("skill: %s", ss))
  add("agent docs", st, if (st == "ok") "the AGENTS.md block and the skill are current" else
        paste(bits, collapse = "; "),
      "use_agent_docs", "write the AGENTS.md block and the weft skill")

  # draft, verify_skip, strict
  if (isTRUE(cfg$draft)) {
    add("draft", "off", "draft: true, so nothing is checked in a render or a commit")
  } else {
    add("draft", "ok", "draft mode is off")
  }
  vs <- as.character(unlist(cfg$verify_skip))
  if (length(vs)) {
    add("verify_skip", "off", paste("verify() skips:", paste(vs, collapse = ", ")))
  } else {
    add("verify_skip", "ok", "verify() skips nothing")
  }
  sr <- as.character(unlist(cfg$strict))
  if (length(sr)) {
    add("strict", "ok", paste("strict rules:", paste(sr, collapse = ", ")))
  } else {
    add("strict", "ok", "no rule is strict")
  }

  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  attr(out, "next") <- if (length(nexts)) nexts[[1L]] else
    "Nothing to install. Run weft::verify() to check the project."
  attr(out, "root") <- root
  class(out) <- c("weft_status", "data.frame")
  out
}

#' @export
print.weft_status <- function(x, ...) {
  cat("weft status: ", attr(x, "root"), "\n", sep = "")
  cat(sprintf("  %-12s %-9s %s", x$part, x$state, x$detail), sep = "\n")
  cat(attr(x, "next"), "\n", sep = "")
  invisible(x)
}

# ---- the parts of status() -----------------------------------------------------------

doc_files <- function(root) project_doc_paths(root, "setup")

# the front-matter lines of a document (character() when it has none)
use_doc_front <- function(lines) {
  if (!length(lines) || !grepl("^---\\s*$", lines[1L])) return(character())
  cl <- which(grepl("^(---|\\.\\.\\.)\\s*$", lines[-1L])) + 1L
  if (!length(cl)) return(character())
  lines[seq_len(cl[1L] - 1L)[-1L]]
}

# does a .qmd need `engine: knitr` (the rule of use_setup(): no engine: or
# jupyter: key, and not another engine's chunks alone)
qmd_lacks_engine <- function(lines) {
  fm <- use_doc_front(lines)
  if (any(grepl("^(engine|jupyter)\\s*:", fm))) return(FALSE)
  body <- if (length(fm)) lines[-seq_len(length(fm) + 2L)] else lines
  chunks <- sub("^\\s*`{3,}\\s*\\{\\s*([A-Za-z0-9_]+).*$", "\\1",
                grep("^\\s*`{3,}\\s*\\{\\s*[A-Za-z0-9_]+", body, value = TRUE))
  chunks <- tolower(chunks)
  !(any(chunks %in% c("python", "julia")) && !("r" %in% chunks))
}

status_activation <- function(root) {
  rp <- file.path(root, ".Rprofile")
  rprofile <- file.exists(rp) && !dir.exists(rp) &&
    any(grepl("weft::weft_setup\\s*\\(", sub("#.*$", "", read_source_lines(rp))))
  docs <- doc_files(root)
  texts <- lapply(file.path(root, docs), function(p) tryCatch(read_source_lines(p), error = function(e) character()))
  front <- length(docs) > 0L &&
    all(vapply(texts, function(x) any(grepl("weft::weft_setup", use_doc_front(x), fixed = TRUE)), NA))
  if (!rprofile && !front) {
    return(list(state = "missing", detail = "no .Rprofile line and no front-matter route"))
  }
  is_qmd <- grepl("\\.qmd$", docs, ignore.case = TRUE)
  lack <- docs[is_qmd][vapply(texts[is_qmd], qmd_lacks_engine, NA)]
  route <- if (rprofile) "the .Rprofile" else "front matter"
  # R reads the file R_PROFILE_USER names instead of the project's .Rprofile (review 4, #15)
  if (rprofile && !front && !is.na(Sys.getenv("R_PROFILE_USER", unset = NA))) {
    return(list(state = "off",
                detail = paste0("R_PROFILE_USER is set, so R does not read the project .Rprofile and the ",
                                "activation does not run; unset it, or use the front-matter route")))
  }
  if (length(lack)) {
    shown <- paste(utils::head(lack, 3L), collapse = ", ")
    more <- if (length(lack) > 3L) sprintf(" and %d more", length(lack) - 3L) else ""
    return(list(state = "missing",
                detail = sprintf("route found (%s); no `engine: knitr` in %s%s", route, shown, more)))
  }
  list(state = "ok", detail = sprintf("route found (%s)", route))
}

status_quarto <- function(root) {
  qroot <- find_quarto_root(root)
  if (is.null(qroot)) return(list(state = "n/a", detail = "not a Quarto project"))
  missing <- character()
  differs <- character()
  for (rel in names(QUARTO_COPIES)) {
    dest <- file.path(qroot, rel)
    src <- system.file("quarto", QUARTO_COPIES[[rel]], package = "weft")
    if (!file.exists(dest)) missing <- c(missing, rel)
    else if (nzchar(src) && !identical(unname(tools::md5sum(dest)), unname(tools::md5sum(src)))) {
      differs <- c(differs, rel)
    }
  }
  yml <- QUARTO_MARKERS
  qy <- file.path(qroot, yml[file.exists(file.path(qroot, yml))][1L])
  old <- read_source_lines(qy)
  new <- quarto_yml_with_weft(old)
  entries <- !is.null(new) && identical(new, old)
  if (length(missing) || !entries) {
    what <- c(if (length(missing)) paste("missing:", paste(missing, collapse = ", ")),
              if (!entries) sprintf("%s lacks the weft entries", basename(qy)))
    return(list(state = "missing", detail = paste(what, collapse = "; ")))
  }
  if (length(differs)) {
    return(list(state = "outdated",
                detail = paste("differs from the shipped file:", paste(differs, collapse = ", "))))
  }
  list(state = "ok", detail = "extension, scripts and _quarto.yml entries are in place")
}

status_hook <- function(root) {
  manager <- git_hooks_path_set(root)
  hooks_dir <- git_dir_of(root, c("rev-parse", "--git-path", "hooks"))
  common <- git_dir_of(root, c("rev-parse", "--git-common-dir"))
  hook <- file.path(hooks_dir, "commit-msg")
  copy <- file.path(common, "weft", "commit-msg")
  inst <- weft_version_string()
  ours <- function(p, where) {
    s <- file_status(p, HOOK_STATE_FN)
    if (s %in% c("missing", "foreign")) return(list(state = s, detail = ""))
    if (s == "edited") return(list(state = "edited", detail = sprintf("%s was edited since weft wrote it", where)))
    lines <- read_source_lines(p)
    rs <- sub("^weft_rscript='(.*)'$", "\\1", grep("^weft_rscript='", lines, value = TRUE)[1L])
    rs <- gsub("'\\''", "'", rs, fixed = TRUE)
    if (s == "outdated") {
      return(list(state = "outdated", detail = sprintf("%s is from weft %s (installed: %s)", where,
                                                       marker_parse(lines, HOOK_STATE_FN)$version, inst)))
    }
    if (!is_executable(p)) {
      return(list(state = "outdated", detail = sprintf("%s is not executable, so git ignores it", where)))
    }
    if (is.na(rs) || !file.exists(rs)) {
      return(list(state = "outdated", detail = sprintf("%s records an Rscript that is gone: %s", where, rs)))
    }
    list(state = "ok", detail = sprintf("%s is weft %s, Rscript %s", where, inst, rs))
  }
  if (!manager) {
    r <- ours(hook, "the commit-msg hook")
    if (r$state != "foreign") {
      if (r$state == "missing") r$detail <- "no commit-msg hook"
      return(r)
    }
  }
  # another tool's hook, or core.hooksPath: weft's script copy sits beside the cache
  why <- if (manager) "core.hooksPath is set (a hook manager)" else "the commit-msg hook is another tool's"
  r <- ours(copy, "the script copy")
  if (r$state == "missing" || r$state == "foreign") {
    return(list(state = "missing",
                detail = sprintf("%s, and weft's script copy is not installed (%s)", why, "run use_hooks()")))
  }
  r$detail <- sprintf("%s; %s (whether your hook calls it is not checked)", why, r$detail)
  r
}

status_ci <- function(root, top) {
  wf <- file.path(top, ".github", "workflows", "weft.yml")
  s <- file_status(wf, CI_FN)
  switch(s,
    missing = if (origin_on_github(git_origin(root))) {
      list(state = "missing", detail = "no .github/workflows/weft.yml")
    } else {
      list(state = "n/a", detail = "origin is not on GitHub")
    },
    foreign = list(state = "edited", detail = "the workflow is not weft's (no weft-file line)"),
    edited = list(state = "edited", detail = "the workflow was edited since weft wrote it"),
    outdated = list(state = "outdated", detail = "the workflow is from another weft version"),
    list(state = "ok", detail = ".github/workflows/weft.yml is current"))
}
