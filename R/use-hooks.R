# use_hooks(): the commit-msg git hook that runs the commit gate (design-4 G21,
# G22, G40, G41; H11, H12, H31, H33).

#' Install the commit-msg hook that runs the commit gate
#'
#' Writes a `commit-msg` git hook that runs [gate()] on each commit (rules
#' 6.1 to 6.3). It says what it will write before it writes anything, and
#' running it again changes nothing. `suppressMessages()` silences it.
#'
#' The script is POSIX `sh`, written to the repository's hooks folder (the one
#' `git rev-parse --git-path hooks` names, so a linked worktree uses the main
#' repository's). It records the `Rscript` and the library paths of the session
#' that ran `use_hooks()`, and runs R with `--no-init-file`, so the project's
#' `.Rprofile` (renv, [weft_setup()]) is not read by the hook. When R or weft
#' cannot be found the commit fails with a message that names `use_hooks()` and
#' `git commit --no-verify`; the latter skips the hook for one commit.
#'
#' * No `commit-msg` hook, and `core.hooksPath` unset: the hook is written.
#' * A hook weft wrote (it has a `weft-file: use_hooks` line) and has not been
#'   edited: rewritten when its text would differ, else kept. Edited: left as
#'   it is, unless `overwrite = TRUE`.
#' * Another tool's hook, or `core.hooksPath` set (a hook manager): left alone,
#'   also under `overwrite = TRUE`. The script goes to
#'   `<git common dir>/weft/commit-msg`, and the call prints the line to add to
#'   the hook your setup runs (and a `repo: local` entry when there is a
#'   `.pre-commit-config.yaml`).
#'
#' `remove = TRUE` deletes the hook when it is weft's (edited or not) and the
#' folder `<git common dir>/weft/` (the script copy and the gate's cache). Another
#' tool's hook is left, and the call says to remove the weft line from it.
#'
#' @param path A directory in the project, which must hold `_weft.yml` and be
#'   inside a git work tree.
#' @param remove Remove the hook instead of installing it.
#' @param overwrite Replace a hook weft wrote that has since been edited.
#' @param rscript The `Rscript` the hook runs. Default: the one of this R.
#' @param lib The library paths the hook gives R, which must hold weft.
#'   Default: `.libPaths()`.
#' @return The paths written, invisibly (`character()` when nothing changed).
#' @export
use_hooks <- function(path = ".", remove = FALSE, overwrite = FALSE, rscript = NULL, lib = NULL) {
  root <- install_root(path, "use_hooks")
  if (!file.exists(file.path(root, "_weft.yml"))) {
    tool_abort(sprintf(paste0("use_hooks() guards a weft project, a folder holding _weft.yml; %s has none. ",
                              "Run use_weft() first (rule 6.1.1)."), root))
  }
  if (isTRUE(remove)) return(hooks_remove(root))
  plan <- hooks_plan(root, overwrite = overwrite, rscript = rscript, lib = lib)
  announce_items(root, plan$items)
  done <- write_items(plan$items)
  for (n in plan$notes) message(n)
  finish_install(done, "the commit-msg hook")
}

HOOK_STATE_FN <- "use_hooks"

# the hook's plan: list(items, notes)
hooks_plan <- function(root, overwrite = FALSE, rscript = NULL, lib = NULL) {
  g <- git_state(root)
  if (!g$ok) {
    tool_abort(sprintf(paste0("use_hooks() needs a git work tree, and %s is not in one (%s). ",
                              "Run git init first."), root, g$reason))
  }
  if (is.null(rscript)) {
    rscript <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
  }
  if (is.null(lib)) lib <- .libPaths()
  if (!length(find.package("weft", lib.loc = lib, quiet = TRUE))) {
    tool_abort(sprintf(paste0("use_hooks() cannot find weft in the libraries the hook would use: %s. ",
                              "Install weft there, or pass `lib`."), paste(lib, collapse = ", ")))
  }
  script <- fill_whole(read_lines_utf8(inst_file("hooks", "commit-msg")),
                       c("@RSCRIPT@" = sh_quote(rscript),
                         "@LIBS@" = sh_quote(paste(lib, collapse = .Platform$path.sep))))

  manager <- git_hooks_path_set(root)
  hooks_dir <- git_dir_of(root, c("rev-parse", "--git-path", "hooks"))
  common <- git_dir_of(root, c("rev-parse", "--git-common-dir"))
  hook <- file.path(hooks_dir, "commit-msg")
  copy <- file.path(common, "weft", "commit-msg")

  items <- list()
  notes <- character()
  purpose <- "runs the weft commit gate"
  beside <- manager
  if (!manager) {
    place_check(hook)
    it <- whole_item(hook, root, script, HOOK_STATE_FN, purpose, overwrite, exec = TRUE)
    it$mode <- "755"
    items[[1L]] <- it
    beside <- it$state == "foreign"
  } else {
    notes <- c(notes, "core.hooksPath is set, so weft does not write into a hooks folder of its own.")
  }
  if (beside) {
    place_check(copy)
    it <- whole_item(copy, root, script, HOOK_STATE_FN, "the script, for your hook manager to run",
                     overwrite, exec = TRUE)
    it$mode <- "755"
    items[[length(items) + 1L]] <- it
    notes <- c(notes,
               "Add this line to the commit-msg hook your setup runs:",
               "  sh \"$(git rev-parse --git-common-dir)/weft/commit-msg\" \"$1\"")
    if (file.exists(file.path(root, ".pre-commit-config.yaml")) ||
        file.exists(file.path(g$top, ".pre-commit-config.yaml"))) {
      notes <- c(notes,
                 "For pre-commit, add to .pre-commit-config.yaml:",
                 "  - repo: local",
                 "    hooks:",
                 "      - id: weft-commit-msg",
                 "        name: weft commit gate",
                 "        entry: sh -c 'sh \"$(git rev-parse --git-common-dir)/weft/commit-msg\" \"$1\"' weft",
                 "        language: system",
                 "        stages: [commit-msg]",
                 "        always_run: true")
    }
  }
  list(items = items, notes = paste(notes, collapse = "\n"))
}

hooks_remove <- function(root) {
  g <- git_state(root)
  if (!g$ok) {
    tool_abort(sprintf("use_hooks() needs a git work tree, and %s is not in one (%s).", root, g$reason))
  }
  manager <- git_hooks_path_set(root)
  hooks_dir <- git_dir_of(root, c("rev-parse", "--git-path", "hooks"))
  common <- git_dir_of(root, c("rev-parse", "--git-common-dir"))
  hook <- file.path(hooks_dir, "commit-msg")
  weft_dir <- file.path(common, "weft")
  message("weft will remove, under ", root, ":")
  removed <- character()
  foreign <- manager
  if (!manager && file.exists(hook)) {
    old <- read_lines_utf8(hook)
    if (!is.null(marker_parse(old, HOOK_STATE_FN))) {
      message(sprintf("  %s  (remove: the weft commit-msg hook)", rel_label(hook, root)))
      unlink(hook)
      removed <- c(removed, hook)
    } else {
      foreign <- TRUE
    }
  }
  if (dir.exists(weft_dir)) {
    message(sprintf("  %s  (remove: the script copy and the gate's cache)", rel_label(weft_dir, root)))
    unlink(weft_dir, recursive = TRUE)
    removed <- c(removed, weft_dir)
  }
  if (foreign) {
    message("The commit-msg hook is another tool's, so it was left as it is: remove the weft line ",
            "from it by hand.")
  }
  if (length(removed)) {
    message("Removed: ", paste(rel_label(removed, root), collapse = ", "))
  } else if (!foreign) {
    message("Nothing to remove: no weft hook is installed.")
  }
  invisible(removed)
}
