# use_ci(): the GitHub Actions workflow (design-4 G33, G40, G41, H23, F3).

#' Write the GitHub Actions workflow that runs weft's static checks
#'
#' Writes `.github/workflows/weft.yml` at the top of the git repository, which
#' is the only place GitHub reads workflows from, even when the weft project is
#' a subfolder (the workflow then checks that folder). On each pull request it
#' runs `weft::verify(static = TRUE)` from the merge base. The workflow installs
#' weft from `github::vorpalvorpal/weft`.
#'
#' It says what it will write before it writes anything. The file carries a
#' `weft-file` line with the weft version and a hash of its other lines: a file
#' weft wrote and nobody edited is replaced when its text would differ; an edited
#' one is left as it is unless `overwrite = TRUE`; a file with no such line is
#' another author's and is never replaced. `suppressMessages()` silences it.
#'
#' @param path A directory in the project, inside a git work tree.
#' @param overwrite Replace a workflow weft wrote that has since been edited.
#' @return The paths written, invisibly (`character()` when nothing changed).
#' @export
use_ci <- function(path = ".", overwrite = FALSE) {
  root <- install_root(path, "use_ci")
  plan <- ci_plan(root, overwrite)
  announce_items(plan$top, plan$items)
  done <- write_items(plan$items)
  finish_install(done, "the workflow")
}

CI_FN <- "use_ci"

ci_plan <- function(root, overwrite = FALSE) {
  g <- git_state(root)
  if (!g$ok) {
    tool_abort(sprintf(paste0("use_ci() writes a workflow at the top of a git repository, and %s is not ",
                              "in a git work tree (%s)."), root, g$reason))
  }
  top <- g$top
  rel <- if (identical(root, top)) "." else rel_label(root, top)
  wf <- file.path(top, ".github", "workflows", "weft.yml")
  place_check(wf, top)
  # the path goes into a single-quoted YAML scalar (a quote is doubled) and reaches the shell and R only
  # as an environment variable, never inside a string of either (review 4, #13)
  new <- fill_whole(read_lines_utf8(inst_file("ci", "weft.yml")), c("@PATH@" = gsub("'", "''", rel, fixed = TRUE)))
  it <- whole_item(wf, top, new, CI_FN, "runs weft::verify(static = TRUE) on each pull request",
                   overwrite)
  list(top = top, items = list(it))
}
