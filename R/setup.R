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
FM_FILTER_ARGS <- paste0("pandoc_args: [\"--lua-filter\", \"weft.lua\", \"--lua-filter\", \"weft-check.lua\", ",
                         "\"--lua-filter\", \"weft-output.lua\"]")
# what use_setup() wrote before named values: the check alone
FM_FILTER_ARGS_OLD <- "pandoc_args: [\"--lua-filter\", \"weft-check.lua\"]"

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
#'   is not another engine's alone, except files and folders whose names start
#'   with `_` or `.` (includes). A page of another engine's chunks alone gains
#'   the line only when it holds an R construct: an R value (`` `r x`{.num} ``)
#'   or a span whose governor is outside the grammar of the filter. A page of
#'   named values (`` `depth`{.num} ``) and spans of that grammar, or with no
#'   construct, stays as it is.
#' * for an `.Rmd` outside a Quarto project, `weft.lua`, `weft-check.lua`,
#'   `weft-output.lua` and the folder `weftlib/` beside the document (weft's
#'   own files: kept when identical, replaced when they differ) and, under
#'   each format of `output:`, `pandoc_args: ["--lua-filter", "weft.lua",
#'   "--lua-filter", "weft-check.lua", "--lua-filter", "weft-output.lua"]`.
#'   A document set up before named values, which names only `weft-check.lua`,
#'   gets `weft.lua` named before it; one set up before the rendered-output
#'   check gets `weft-output.lua` named last.
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

  items <- Filter(function(w) !is.null(w$new), plan$items)
  if (length(items)) announce_items(plan$root, items)
  done <- write_items(items)
  finish_install(done, "the project")
  invisible(vapply(done, `[[`, "", "label"))
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
  items <- list()
  add <- function(path, new, state, purpose, copy_from = NULL) {
    items[[length(items) + 1L]] <<- plan_item(path, root, state, purpose, new = new,
                                              eol = if (state == "new") "\n" else file_eol(path),
                                              copy_from = copy_from)
  }
  # a folder or a link where a file should be, or a file where a folder should be: refuse before anything is
  # written
  check_place <- function(p) place_check(p, root)
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
      problems[[length(problems) + 1L]] <- list(file = rel_to(d, root), reason = conditionMessage(res),
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

  # the filters, beside each .Rmd that names them: weft.lua with its weftlib/, and weft-check.lua
  if (length(lua_dirs)) {
    srcs <- c("weft-check.lua" = system.file("quarto", "weft-check.lua", package = "weft"),
              "weft-output.lua" = system.file("quarto", "weft-output.lua", package = "weft"))
    for (nm in names(srcs)) {
      if (!nzchar(srcs[[nm]])) tool_abort(sprintf("weft's own file inst/quarto/%s is missing.", nm))
    }
    # weft.lua and weftlib/ are the resolver's own files (N80): copied when the package ships them
    qd <- system.file("quarto", package = "weft")
    lua <- file.path(qd, "weft.lua")
    if (file.exists(lua)) srcs <- c(srcs, "weft.lua" = lua)
    lib <- list.files(file.path(qd, "weftlib"), recursive = TRUE)
    if (length(lib)) srcs <- c(srcs, stats::setNames(file.path(qd, "weftlib", lib), file.path("weftlib", lib)))
    for (dd in sort(lua_dirs)) {
      for (rel_name in names(srcs)) {
        dest <- file.path(dd, rel_name)
        src <- srcs[[rel_name]]
        check_place(dest)
        what <- if (identical(rel_name, "weft-check.lua")) "the weft-check filter for rmarkdown" else
          if (identical(rel_name, "weft-output.lua")) "the rendered-output check for rmarkdown" else
          "the weft filter for rmarkdown"
        if (!file.exists(dest)) {
          add(dest, character(), "new", what, copy_from = src)
        } else if (!identical(unname(tools::md5sum(dest)), unname(tools::md5sum(src)))) {
          add(dest, character(), "replace", "weft's own filter file, which differs", copy_from = src)
        }
      }
    }
  }

  # report order: .Rprofile, _weft.yml, documents, filters (as planned)
  list(root = root, route = route, items = items)
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
                    paste0("(under each format of `output:`; add \"--lua-filter\", \"weft.lua\", \"--lua-filter\" and ",
                           "\"weft-check.lua\", \"--lua-filter\" and \"weft-output.lua\" to its pandoc_args)"))

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

# Does a .qmd need `engine: knitr`: no `engine:` or `jupyter:` key in its front matter, and not another
# engine's chunks alone. The one rule, used by use_setup() and by status().
qmd_needs_engine <- function(fm_names, body) {
  if (any(c("engine", "jupyter") %in% fm_names)) return(FALSE)
  chunks <- sub("^\\s*`{3,}\\s*\\{\\s*([A-Za-z0-9_]+).*$", "\\1",
                grep("^\\s*`{3,}\\s*\\{\\s*[A-Za-z0-9_]+", body, value = TRUE))
  chunks <- tolower(chunks)
  # a document of another engine's chunks alone is left as it is unless it holds an R construct (G41, N74)
  if (length(chunks) && !("r" %in% chunks)) {
    return(lines_hold_construct(body))
  }
  TRUE
}

# Does the text hold a construct that needs R: a scanner row other than bare, link or literal that the filter
# does not resolve. A named value, and a span whose governor fits N9 and N12, are the filter's and need no knitr;
# an R value, or a span outside the grammar, does.
lines_hold_construct <- function(lines) {
  rw <- tryCatch(scan_document(lines, file = NA_character_), error = function(e) NULL)
  if (is.null(rw) || !nrow(rw)) return(FALSE)
  held <- !rw$kind %in% c("bare", "link", "literal")
  # the scanner's "outside the filter's grammar" errors, by the rule each cites (1.12.4 to 1.12.6, 1.12.10)
  ours <- rw$resolver %in% "filter" &
    !(rw$kind != "named" & !is.na(rw$error) & grepl("(rule 1[.]12[.](4|5|6|10))", rw$error, fixed = FALSE))
  any(held & !ours)
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
  if (want$engine && qmd_needs_engine(names(y), body)) {
    new <- c(new, "engine: knitr")
    what <- c(what, "adds engine: knitr")
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

# The positions at which `--lua-filter <file>` is named in pandoc_args.
lua_filter_at <- function(args, file) {
  a <- as.character(unlist(args))
  if (length(a) < 2L) return(integer())
  which(a[-length(a)] == "--lua-filter" & a[-1L] == file)
}

# Does pandoc_args name weft.lua, then weft-check.lua, then weft-output.lua (N74, N50).
filter_in_args <- function(args) {
  w <- lua_filter_at(args, "weft.lua")
  k <- lua_filter_at(args, "weft-check.lua")
  o <- lua_filter_at(args, "weft-output.lua")
  length(w) > 0L && length(k) > 0L && length(o) > 0L && min(w) < max(k) && max(k) < max(o)
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
    # set up before named values: weft-check.lua alone, so weft.lua goes in before it
    old_only <- length(lua_filter_at(args, "weft-check.lua")) > 0L && !length(lua_filter_at(args, "weft.lua"))
    has_out <- length(lua_filter_at(args, "weft-output.lua")) > 0L
    if (nzchar(fm_inline(fm[pi]))) {
      flat <- gsub("\\s+", "", fm_inline(fm[pi]))
      if (flat %in% c("[\"--lua-filter\",\"weft-check.lua\"]",
                      "[\"--lua-filter\",\"weft.lua\",\"--lua-filter\",\"weft-check.lua\"]")) {
        fm[pi] <- paste0(fm_pad(fc), FM_FILTER_ARGS)
        next
      }
      fm_unsafe(sprintf("`pandoc_args:` of `%s` is written in flow style", name), fm_hand_filter)
    }
    pend <- yml_block_end(fm, pi, fc)
    items <- which(seq_along(fm) > pi & seq_along(fm) <= pend &
                   grepl("^\\s*-(\\s|$)", fm))
    ipad <- if (length(items)) yml_indent(fm[items[1]]) else fc + 2L
    if (old_only) {
      # the item `weft-check.lua`, and the `--lua-filter` before it
      k <- items[grepl("^\\s*-\\s*[\"']?weft-check[.]lua[\"']?\\s*(#.*)?$", fm[items])]
      if (!length(k)) fm_unsafe(sprintf("`pandoc_args:` of `%s` is written in a form weft cannot edit", name),
                                fm_hand_filter)
      at <- items[match(k[1L], items) - 1L]
      fm <- append(fm, c(paste0(fm_pad(yml_indent(fm[at])), "- \"--lua-filter\""),
                         paste0(fm_pad(yml_indent(fm[at])), "- \"weft.lua\"")), after = at - 1L)
      pend <- pend + 2L
    }
    if (old_only || length(lua_filter_at(args, "weft-check.lua")) > 0L) {
      # the resolver and the check are named: the output check goes last
      if (!has_out) {
        fm <- append(fm, c(paste0(fm_pad(ipad), "- \"--lua-filter\""),
                           paste0(fm_pad(ipad), "- \"weft-output.lua\"")), after = pend)
      }
      next
    }
    fm <- append(fm, c(paste0(fm_pad(ipad), "- \"--lua-filter\""),
                       paste0(fm_pad(ipad), "- \"weft.lua\""),
                       paste0(fm_pad(ipad), "- \"--lua-filter\""),
                       paste0(fm_pad(ipad), "- \"weft-check.lua\""),
                       paste0(fm_pad(ipad), "- \"--lua-filter\""),
                       paste0(fm_pad(ipad), "- \"weft-output.lua\"")), after = pend)
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
