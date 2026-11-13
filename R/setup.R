# Activation: `use_setup()` (rules 9.2.1, 9.2.7, 9.2.8), the project `.Rprofile`
# route, the front-matter edits, and the version record (rule 9.5.4).
# Contract: dev/design-4.md (G32, G35, G36, G41).

# ---- the version record (G32) -----------------------------------------------

# The `weft_version` a project records in `_weft.yml`, read as text and not
# parsed (a file that is not valid YAML elsewhere still yields it). NA when the
# file, the key or its value is absent (`null` and an empty value count as
# absent). The spelling written is kept.
recorded_version <- function(root) {
  f <- file.path(root, "_weft.yml")
  if (!file.exists(f) || dir.exists(f)) return(NA_character_)
  x <- read_source_lines(f)
  i <- grep("^weft_version\\s*:", x)
  if (!length(i)) return(NA_character_)
  v <- trimws(sub("^weft_version\\s*:", "", x[i[1]]))
  if (grepl("^[\"']", v)) {
    q <- substr(v, 1L, 1L)
    v <- sub(sprintf("^%s([^%s]*).*$", q, q), "\\1", v)
  } else {
    v <- trimws(sub("(^|\\s+)#.*$", "", v))
  }
  if (!nzchar(v) || v %in% c("null", "~", "Null", "NULL")) return(NA_character_)
  v
}

weft_version_string <- function() as.character(utils::packageVersion("weft"))

# ---- the files use_setup() writes -------------------------------------------

RPROFILE_COMMENT <- paste0("# weft: activates weft in every knit of this project ",
                           "(weft::use_setup(), rule 9.2.1).")
RPROFILE_SOURCE <- paste0("# R reads this file instead of your ~/.Rprofile; ",
                          "the next line keeps yours.")
RPROFILE_HOME <- "if (file.exists(\"~/.Rprofile\")) source(\"~/.Rprofile\")"
RPROFILE_ACTIVATE <- "if (requireNamespace(\"weft\", quietly = TRUE)) weft::weft_setup()"
FM_WEFT_LINE <- "weft: !expr weft::weft_setup()"
FM_FILTER_ARGS <- "pandoc_args: [\"--lua-filter\", \"weft-check.lua\"]"

#' Activate weft in a project's documents
#'
#' Sets up the activation of weft (rule 9.2): the project `.Rprofile` that
#' calls [weft_setup()] in every knit, or the same call in each document's front
#' matter, together with the `_weft.yml` that records the weft version. It says
#' what it will write before it writes anything, and running it again changes
#' nothing. `suppressMessages()` silences it.
#'
#' `path` is a folder or one `.qmd`, `.Rmd` or `.rmd` file. A folder in a
#' Quarto project (a `_quarto.yml` here or above it) is set up at the project
#' root. The `route` is `"rprofile"` in a Quarto project and `"front-matter"`
#' otherwise, unless you choose.
#'
#' It writes:
#'
#' * `_weft.yml`, when there is none (a comment and `weft_version:`), or the
#'   `weft_version:` line appended to one that lacks it. An existing line is
#'   left as it is.
#' * route `"rprofile"`: the `.Rprofile` at the project root. A new file
#'   sources `~/.Rprofile` first, because R reads one profile only; an
#'   existing file gains a comment and the activation line after its last
#'   line (after `source("renv/activate.R")`, so weft is found in renv's
#'   library). A file that already calls `weft::weft_setup()` is kept.
#' * route `"front-matter"`: `knitr: opts_knit: weft: !expr weft::weft_setup()`
#'   in each document's front matter.
#' * `engine: knitr` in each `.qmd` that has no `engine:` or `jupyter:` key and
#'   is not another engine's alone (a Python-only page stays Jupyter), except
#'   files and folders whose names start with `_` or `.` (includes).
#' * for an `.Rmd` outside a Quarto project, `weft-check.lua` beside the
#'   document (weft's own file: kept when identical, replaced when it differs)
#'   and, under each format of `output:`, `pandoc_args: ["--lua-filter",
#'   "weft-check.lua"]`.
#'
#' Front matter is edited as text and checked by parsing it again. When an
#' edit cannot be made safely (flow-style `knitr:` or `pandoc_args`, a YAML
#' anchor, another `weft:` value under `opts_knit`), or a file's place holds a
#' folder or a symbolic link, nothing is written, and the error prints the lines
#' to add by hand.
#'
#' @param path A folder or one document. Default: the current folder.
#' @param route `"auto"`, `"rprofile"` or `"front-matter"`.
#' @return The paths written, relative to the root, invisibly (`character()`
#'   when nothing changed).
#' @export
use_setup <- function(path = ".", route = c("auto", "rprofile", "front-matter")) {
  route <- match.arg(route)
  plan <- setup_plan(path, route)

  changed <- Filter(function(w) !is.null(w$new), plan$writes)
  if (!length(changed)) {
    message("Nothing to change: the project is already set up.")
    return(invisible(character()))
  }
  message("weft will write, under ", plan$root, ":")
  for (w in changed) {
    message(sprintf("  %s  (%s: %s)", w$rel, w$state, w$purpose))
  }

  written <- character()
  for (w in changed) {
    dir.create(dirname(w$path), showWarnings = FALSE, recursive = TRUE)
    ok <- tryCatch({
      if (!is.null(w$copy_from)) {
        copy_atomic(w$copy_from, w$path)
      } else {
        write_lines_atomic(w$new, w$path, w$eol)
        TRUE
      }
    }, error = function(e) FALSE, warning = function(w) FALSE)
    if (!ok) {
      tool_abort(sprintf("weft could not write %s. %s", w$path,
                         if (length(written)) paste0("Written before it failed: ",
                                                     paste(written, collapse = ", "), ".")
                         else "Nothing was written."))
    }
    written <- c(written, w$rel)
  }
  message("Wrote: ", paste(written, collapse = ", "))
  invisible(written)
}

# ---- planning: everything is worked out before anything is written -----------

is_link <- function(p) {
  l <- suppressWarnings(Sys.readlink(p))
  !is.na(l) && nzchar(l)
}

doc_kind <- function(f) {
  if (grepl("\\.qmd$", f, ignore.case = TRUE)) "qmd"
  else if (grepl("\\.rmd$", f, ignore.case = TRUE)) "rmd"
  else NA_character_
}

setup_plan <- function(path, route) {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !file.exists(path)) {
    tool_abort(sprintf("use_setup(): `path` does not exist: %s", format(path)))
  }
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  single <- !dir.exists(path)
  if (single && is.na(doc_kind(path))) {
    tool_abort(sprintf("use_setup(): %s is not a .qmd, .Rmd or .rmd document.", path))
  }
  start <- if (single) dirname(path) else path
  qroot <- find_quarto_root(start)
  in_quarto <- !is.null(qroot)
  root <- if (in_quarto) qroot else start
  if (route == "auto") route <- if (in_quarto) "rprofile" else "front-matter"

  docs <- if (single) path else {
    file.path(path, project_doc_paths(path, "setup"))
  }
  rel <- function(p) {
    pre <- paste0(root, "/")
    if (startsWith(p, pre)) substring(p, nchar(pre) + 1L) else p
  }

  writes <- list()
  add <- function(path, new, state, purpose, copy_from = NULL) {
    writes[[length(writes) + 1L]] <<- list(path = path, rel = rel(path), new = new,
                                           state = state, purpose = purpose,
                                           copy_from = copy_from,
                                           eol = if (state == "new") "\n" else file_eol(path))
  }
  # a folder or a link where a file should be: refuse before anything is written
  check_place <- function(p) {
    if (dir.exists(p)) {
      tool_abort(sprintf("%s is a folder, and weft needs a file there. Nothing was written.", p))
    }
    if (is_link(p)) {
      tool_abort(sprintf(paste0("%s is a symbolic link, and weft does not write through links. ",
                                "Nothing was written."), p))
    }
  }
  read <- read_source_lines

  # .Rprofile
  if (route == "rprofile") {
    rp <- file.path(root, ".Rprofile")
    check_place(rp)
    if (!file.exists(rp)) {
      add(rp, c(RPROFILE_COMMENT, RPROFILE_SOURCE, RPROFILE_HOME, RPROFILE_ACTIVATE),
          "new", "activates weft in every knit of this project")
    } else {
      old <- read(rp)
      if (!any(grepl("weft::weft_setup\\s*\\(", sub("#.*$", "", old)))) {
        add(rp, c(old, "", RPROFILE_COMMENT, RPROFILE_ACTIVATE),
            "edit", "adds the weft activation line after yours")
      }
    }
  }

  # _weft.yml
  wy <- file.path(root, "_weft.yml")
  check_place(wy)
  ver_line <- paste0("weft_version: ", weft_version_string())
  if (!file.exists(wy)) {
    add(wy, c("# weft settings for this project. Every key has a default;",
              "# add only what you change.", ver_line),
        "new", "settings, and the weft version that set the project up")
  } else {
    old <- read(wy)
    if (!any(grepl("^weft_version\\s*:", old))) {
      add(wy, c(old, ver_line), "edit", "adds the weft_version line")
    }
  }

  # documents
  problems <- list()
  lua_dirs <- character()
  for (d in docs) {
    check_place(d)
    kind <- doc_kind(d)
    old <- read(d)
    want <- list(
      opts_knit = route == "front-matter",
      engine = kind == "qmd",
      filter = kind == "rmd" && !in_quarto
    )
    res <- tryCatch(fm_plan_doc(old, want),
                    weft_fm_unsafe = function(e) e)
    if (inherits(res, "weft_fm_unsafe")) {
      problems[[length(problems) + 1L]] <- list(file = rel(d), reason = conditionMessage(res),
                                                hand = res$hand)
      next
    }
    if (!identical(res$lines, old)) {
      add(d, res$lines, "edit", paste(res$what, collapse = " and "))
    }
    if (want$filter) lua_dirs <- union(lua_dirs, dirname(d))
  }
  if (length(problems)) {
    msgs <- vapply(problems, function(p) {
      paste0(p$file, ": ", p$reason, "\n\n", paste(p$hand, collapse = "\n"))
    }, "")
    tool_abort(paste0(
      "weft cannot edit the front matter of ", length(problems), " document",
      if (length(problems) > 1L) "s", " as text without risking what is in it, so it has ",
      "changed nothing. Add these lines by hand, then run use_setup() again.\n\n",
      paste(msgs, collapse = "\n\n")))
  }

  # the filter, beside each .Rmd that names it
  if (length(lua_dirs)) {
    src <- system.file("quarto", "weft-check.lua", package = "weft")
    if (!nzchar(src)) tool_abort("weft's own file inst/quarto/weft-check.lua is missing.")
    for (dd in sort(lua_dirs)) {
      dest <- file.path(dd, "weft-check.lua")
      check_place(dest)
      if (!file.exists(dest)) {
        add(dest, character(), "new", "the weft-check filter for rmarkdown", copy_from = src)
      } else if (!identical(unname(tools::md5sum(dest)), unname(tools::md5sum(src)))) {
        add(dest, character(), "replace", "weft's own filter file, which differs", copy_from = src)
      }
    }
  }

  # report order: .Rprofile, _weft.yml, documents, filters (as planned)
  list(root = root, route = route, writes = writes)
}

# ---- editing a document's front matter, as text -----------------------------

fm_unsafe <- function(reason, hand) {
  stop(structure(class = c("weft_fm_unsafe", "error", "condition"),
                 list(message = reason, call = NULL, hand = hand)))
}

fm_parse <- function(fm) {
  y <- yaml_read_text(c(fm, ""), handlers = list(expr = function(x) paste0("!expr ", x)))
  if (is.null(y)) list() else y
}

fm_hand_opts <- c("knitr:", "  opts_knit:", paste0("    ", FM_WEFT_LINE))
fm_hand_filter <- c("output:", "  html_document:", paste0("    ", FM_FILTER_ARGS),
                    "(under each format of `output:`; add \"--lua-filter\" and \"weft-check.lua\" to its pandoc_args)")

fm_inline <- function(line) {
  trimws(sub("(^|\\s+)#.*$", "", sub("^[^:]*:", "", line)))
}

fm_pad <- function(n) strrep(" ", n)

# the first non-blank line's indent inside lines (a, b], else `default`
fm_child_indent <- function(lines, a, b, default) {
  if (b <= a) return(default)
  body <- (a + 1L):b
  body <- body[!yml_blank(lines[body])]
  if (!length(body)) default else yml_indent(lines[body[1]])
}

# front matter lines (may be empty) -> list(lines =, what =) with what weft needs
fm_plan_doc <- function(old, want) {
  n <- length(old)
  has_fm <- n >= 1L && grepl("^---\\s*$", old[1])
  close <- NA_integer_
  if (has_fm) {
    cl <- which(grepl("^(---|\\.\\.\\.)\\s*$", old[-1L])) + 1L
    if (!length(cl)) fm_unsafe("its front matter is not closed", character())
    close <- cl[1]
  }
  fm <- if (has_fm) old[seq_len(close - 1L)[-1L]] else character()
  body <- if (has_fm) old[close:n][-1L] else old

  if (any(grepl("(^|[:-]\\s+)[&*][^[:space:]]", fm))) {
    fm_unsafe("its front matter has a YAML anchor or alias",
              c(if (want$opts_knit) fm_hand_opts, if (want$filter) fm_hand_filter,
                if (want$engine) "engine: knitr"))
  }
  y <- tryCatch(fm_parse(fm), error = function(e) NULL)
  if (is.null(y) || (length(fm) && !is.list(y))) {
    fm_unsafe("its front matter does not parse as YAML", character())
  }

  what <- character()
  new <- fm
  if (want$opts_knit) {
    r <- fm_add_opts_knit(new, y)
    if (!identical(r, new)) what <- c(what, "adds the weft setup line")
    new <- r
  }
  if (want$engine && !("engine" %in% names(y)) && !("jupyter" %in% names(y))) {
    chunks <- sub("^\\s*`{3,}\\s*\\{\\s*([A-Za-z0-9_]+).*$", "\\1",
                  grep("^\\s*`{3,}\\s*\\{\\s*[A-Za-z0-9_]+", body, value = TRUE))
    chunks <- tolower(chunks)
    other <- any(chunks %in% c("python", "julia"))
    if (!(other && !("r" %in% chunks))) {
      new <- c(new, "engine: knitr")
      what <- c(what, "adds engine: knitr")
    }
  }
  if (want$filter) {
    r <- fm_add_filter(new, y)
    if (!identical(r, new)) what <- c(what, "names the weft-check filter")
    new <- r
  }

  if (identical(new, fm)) return(list(lines = old, what = what))
  fm_check(fm, new, y, want)
  lines <- if (has_fm) c(old[1], new, old[close:n]) else c("---", new, "---", old)
  list(lines = lines, what = what)
}

fm_add_opts_knit <- function(fm, y) {
  k <- y$knitr
  if (!is.null(k) && !is.list(k)) {
    fm_unsafe("`knitr:` holds a value that is not a mapping", fm_hand_opts)
  }
  ki <- grep("^knitr\\s*:", fm)
  if (!length(ki)) return(c(fm, fm_hand_opts))
  ki <- ki[1]
  if (nzchar(fm_inline(fm[ki]))) {
    fm_unsafe("`knitr:` is written in flow style", fm_hand_opts)
  }
  kend <- yml_block_end(fm, ki, 0L)
  ci <- fm_child_indent(fm, ki, kend, 2L)
  oi <- which(seq_along(fm) > ki & seq_along(fm) <= kend &
              grepl(sprintf("^ {%d}opts_knit\\s*:", ci), fm))
  if (!length(oi)) {
    return(append(fm, c(paste0(fm_pad(ci), "opts_knit:"),
                        paste0(fm_pad(ci + 2L), FM_WEFT_LINE)), after = kend))
  }
  oi <- oi[1]
  if (nzchar(fm_inline(fm[oi]))) {
    fm_unsafe("`opts_knit:` is written in flow style", fm_hand_opts)
  }
  oend <- yml_block_end(fm, oi, ci)
  oc <- fm_child_indent(fm, oi, oend, ci + 2L)
  wi <- which(seq_along(fm) > oi & seq_along(fm) <= oend &
              grepl(sprintf("^ {%d}weft\\s*:", oc), fm))
  if (length(wi)) {
    if (identical(y$knitr$opts_knit$weft, "!expr weft::weft_setup()")) return(fm)
    fm_unsafe("`opts_knit:` already has a `weft:` entry with another value", fm_hand_opts)
  }
  append(fm, paste0(fm_pad(oc), FM_WEFT_LINE), after = oend)
}

filter_in_args <- function(args) {
  a <- as.character(unlist(args))
  length(a) >= 2L && any(a[-length(a)] == "--lua-filter" & a[-1L] == "weft-check.lua")
}

fm_add_filter <- function(fm, y) {
  oi <- grep("^output\\s*:", fm)
  if (!length(oi)) {
    return(c(fm, "output:", "  html_document:", paste0("    ", FM_FILTER_ARGS)))
  }
  oi <- oi[1]
  val <- fm_inline(fm[oi])
  if (nzchar(val)) {
    if (!grepl("^[A-Za-z][A-Za-z0-9_.:]*$", val)) {
      fm_unsafe("`output:` is not a plain format name or a block mapping", fm_hand_filter)
    }
    return(append(fm[-oi], c("output:", paste0("  ", val, ":"),
                             paste0("    ", FM_FILTER_ARGS)), after = oi - 1L))
  }
  oend <- yml_block_end(fm, oi, 0L)
  ci <- fm_child_indent(fm, oi, oend, 2L)
  idx <- which(seq_along(fm) > oi & seq_along(fm) <= oend)
  if (any(grepl(sprintf("^ {%d}-(\\s|$)", ci), fm[idx]))) {
    fm_unsafe("`output:` is a list, not a mapping of formats", fm_hand_filter)
  }
  fis <- idx[grepl(sprintf("^ {%d}[A-Za-z][^:[:space:]]*\\s*:", ci), fm[idx])]
  if (!length(fis)) fm_unsafe("`output:` has no format weft can edit", fm_hand_filter)
  for (fi in rev(fis)) {
    name <- sub("^\\s*([^:[:space:]]+)\\s*:.*$", "\\1", fm[fi])
    args <- if (is.list(y$output)) y$output[[name]]$pandoc_args else NULL
    if (filter_in_args(args)) next
    rest <- fm_inline(fm[fi])
    if (nzchar(rest)) {
      if (!rest %in% c("default", "null", "~")) {
        fm_unsafe(sprintf("the `%s` entry of `output:` is written in flow style", name),
                  fm_hand_filter)
      }
      fm <- append(fm[-fi], c(paste0(fm_pad(ci), name, ":"),
                              paste0(fm_pad(ci + 2L), FM_FILTER_ARGS)), after = fi - 1L)
      next
    }
    fend <- yml_block_end(fm, fi, ci)
    fc <- fm_child_indent(fm, fi, fend, ci + 2L)
    pi <- which(seq_along(fm) > fi & seq_along(fm) <= fend &
                grepl(sprintf("^ {%d}pandoc_args\\s*:", fc), fm))
    if (!length(pi)) {
      fm <- append(fm, paste0(fm_pad(fc), FM_FILTER_ARGS), after = fend)
      next
    }
    pi <- pi[1]
    if (nzchar(fm_inline(fm[pi]))) {
      fm_unsafe(sprintf("`pandoc_args:` of `%s` is written in flow style", name), fm_hand_filter)
    }
    pend <- yml_block_end(fm, pi, fc)
    items <- which(seq_along(fm) > pi & seq_along(fm) <= pend &
                   grepl("^\\s*-(\\s|$)", fm))
    ipad <- if (length(items)) yml_indent(fm[items[1]]) else fc + 2L
    fm <- append(fm, c(paste0(fm_pad(ipad), "- \"--lua-filter\""),
                       paste0(fm_pad(ipad), "- \"weft-check.lua\"")), after = pend)
  }
  fm
}

# the edit must leave everything else as parsed, and do what it was for
fm_check <- function(old_fm, new_fm, y, want) {
  bad <- function() {
    fm_unsafe("the edit could not be checked by parsing the result",
              c(if (want$opts_knit) fm_hand_opts, if (want$filter) fm_hand_filter,
                if (want$engine) "engine: knitr"))
  }
  y2 <- tryCatch(fm_parse(new_fm), error = function(e) NULL)
  if (is.null(y2) || !is.list(y2)) bad()
  drop <- function(z) {
    k <- z$knitr
    if (is.list(k)) {
      k$opts_knit$weft <- NULL
      if (!length(k$opts_knit)) k$opts_knit <- NULL
    }
    z$knitr <- if (is.list(k) && length(k)) k else NULL
    z$engine <- NULL
    z$output <- NULL
    if (!length(z)) list() else z
  }
  if (!identical(drop(y2), drop(y))) bad()
  if (want$opts_knit &&
      !identical(y2$knitr$opts_knit$weft, "!expr weft::weft_setup()")) bad()
  if (want$filter) {
    fmts <- if (is.list(y2$output)) names(y2$output) else character()
    if (!length(fmts)) bad()
    for (f in fmts) if (!filter_in_args(y2$output[[f]]$pandoc_args)) bad()
  }
  invisible(TRUE)
}
