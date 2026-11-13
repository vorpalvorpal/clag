#' Set up a Quarto project for weft
#'
#' Installs the `weft-check` Lua filter (rule 2.5.3) as a project extension,
#' and the `pre-render` and `post-render` scripts (rules 2.5.4, 2.6.6, 2.9.4),
#' and names them in `_quarto.yml`. It says what it will write before it
#' writes anything.
#'
#' It writes:
#'
#' * `_extensions/weft-check/_extension.yml` and `weft-check.lua`
#' * `_weft/pre-render.R` and `_weft/post-render.R`
#' * `_weft.yml`, only when there is none (empty but for a comment)
#'
#' and edits `_quarto.yml`: `weft-check` is added under `filters:`, and the
#' two scripts under `project: pre-render:` and `post-render:`. The file is
#' edited as text, line by line, and never rewritten from parsed YAML: every
#' other line, comments and anchors included, stays as it was. When the edit
#' cannot be made safely (a flow-style `filters: [a, b]`, say) `use_quarto()`
#' stops before it writes anything and prints the lines to add by hand.
#' Running it again changes nothing.
#'
#' The scripts are plain base R and run when weft is not installed. The
#' pre-render script fails the render, before anything renders, on a `.qmd`
#' that holds a construct and has no `engine: knitr` in its own front matter
#' (9.2.8). It also opens the collection file `.weft/failures.jsonl`, which
#' the filter and the documents append to and the post-render script reports.
#'
#' @param path A directory in the project. `use_quarto()` walks up from it to
#'   the directory that holds `_quarto.yml`, says which directory it took,
#'   and writes there. Where there is none, it stops: it does not turn a
#'   directory into a Quarto project.
#' @return The paths it wrote or changed, relative to `path`, invisibly.
#' @export
use_quarto <- function(path = ".") {
  if (!dir.exists(path)) {
    tool_abort(paste0("use_quarto(): `path` is not a directory: ", path))
  }
  start <- normalizePath(path, winslash = "/", mustWork = TRUE)
  path <- find_quarto_root(start)
  if (is.null(path)) {
    tool_abort(paste0("use_quarto(): `", start, "` has no _quarto.yml, so it is not in a Quarto project. ",
                      "Create the project first (`quarto create project`), then run use_quarto()."))
  }
  hit <- QUARTO_MARKERS[file.exists(file.path(path, QUARTO_MARKERS))][1]
  yml_name <- hit
  if (!identical(path, start)) {
    message("weft: the Quarto project is at ", path, " (it holds _quarto.yml); using that directory.")
  }

  # the edit of _quarto.yml is worked out first: when it cannot be made safely,
  # nothing is written
  qy <- file.path(path, yml_name)
  old <- read_source_lines(qy)
  new <- quarto_yml_with_weft(old)
  if (is.null(new)) {
    tool_abort(paste0("use_quarto(): weft cannot edit ", yml_name, " as text without risking what is in it, so it has ",
                      "changed nothing. Add these lines by hand, then run use_quarto() again:\n\n",
                      paste(c("filters:", "  - weft-check", "project:", "  pre-render: _weft/pre-render.R",
                              "  post-render: _weft/post-render.R"), collapse = "\n"),
                      "\n\n(merge them into the `filters:` and `project:` entries the file already has; ",
                      "each of those holds a list, and `weft-check` and the two scripts go into it.)"))
  }

  src <- function(f) {
    p <- system.file("quarto", f, package = "weft")
    if (!nzchar(p)) tool_abort(paste0("weft's own file inst/quarto/", f, " is missing"))
    p
  }
  copies <- quarto_copies()
  sources <- vapply(copies, src, "")
  names(sources) <- names(copies)
  weft_yml <- file.path(path, "_weft.yml")
  make_weft_yml <- !file.exists(weft_yml)

  # never through a link, and every refusal before the first write
  targets <- c(names(sources), "_weft", "_extensions", "_extensions/weft-check",
               "_extensions/weft-check/weftlib", "_weft.yml", yml_name)
  for (rel in targets) {
    l <- Sys.readlink(file.path(path, rel))
    if (!is.na(l) && nzchar(l)) {
      tool_abort(sprintf(paste0("use_quarto(): %s is a symbolic link, and weft never writes through one; ",
                                "nothing was written. Replace it with a plain file or folder, or move it away."),
                         file.path(path, rel)))
    }
  }

  message("weft will write, under ", path, ":")
  message("  _extensions/weft-check/_extension.yml, weft.lua, weftlib/ and weft-check.lua  (the weft filters)")
  message("  _weft/pre-render.R   (fails a .qmd with constructs and no `engine: knitr`; opens .weft/failures.jsonl)")
  message("  _weft/post-render.R  (reports what the render collected)")
  message(if (make_weft_yml) "  _weft.yml  (new, empty but for a comment)"
          else "  _weft.yml  (exists: left as it is)")
  message("  ", yml_name, "  (adds the filter weft-check, and the two scripts under project:)")

  written <- character()
  failed <- function(rel) {
    if (length(written)) message("Wrote: ", paste(written, collapse = ", "))
    tool_abort(sprintf("use_quarto(): could not write %s (%s).%s", rel, file.path(path, rel),
                       if (length(written)) paste0(" Written before it: ", paste(written, collapse = ", "), ".")
                       else " Nothing was written."))
  }
  for (rel in names(sources)) {
    dest <- file.path(path, rel)
    if (!file.exists(dest) ||
        !identical(unname(tools::md5sum(dest)), unname(tools::md5sum(sources[[rel]])))) {
      ok <- tryCatch({
        suppressWarnings(dir.create(dirname(dest), showWarnings = FALSE, recursive = TRUE))
        dir.exists(dirname(dest)) && copy_atomic(sources[[rel]], dest) && file.exists(dest)
      }, error = function(e) FALSE)
      if (!isTRUE(ok)) failed(rel)
      written <- c(written, rel)
    }
  }
  if (make_weft_yml) {
    ok <- tryCatch({
      write_lines_atomic(c("# weft settings for this project. Every key has a default;",
                           "# add only what you change (digits, decimal_mark, draft, ...)."),
                         weft_yml)
      file.exists(weft_yml)
    }, error = function(e) FALSE, warning = function(w) FALSE)
    if (!isTRUE(ok)) failed("_weft.yml")
    written <- c(written, "_weft.yml")
  }

  if (!identical(new, old)) {
    ok <- tryCatch({ write_lines_atomic(new, qy, file_eol(qy)); TRUE },
                   error = function(e) FALSE, warning = function(w) FALSE)
    if (!isTRUE(ok)) failed(yml_name)
    written <- c(written, yml_name)
  }

  message(if (length(written)) paste0("Wrote: ", paste(written, collapse = ", "))
          else "Nothing to change: the project is already set up.")
  # N74: a project with a jupyter-engine document needs the Python package in the Python Quarto uses
  if (project_has_jupyter_doc(path)) message(MSG_E61)
  # N74: a project with a julia-engine document needs the Julia package in the environment Quarto's julia uses
  if (project_has_julia_doc(path)) message(MSG_E62)
  invisible(written)
}

MSG_E61 <- paste0("Install the Python package in the Python Quarto uses: ",
                  "pip install \"git+https://github.com/vorpalvorpal/weft#subdirectory=inst/python\"")

MSG_E62 <- paste0("Install the Julia package: using Pkg; ",
                  "Pkg.add(url = \"https://github.com/vorpalvorpal/weft\", subdir = \"inst/julia/Weft\"). ",
                  "Quarto's Julia worker does not read JULIA_LOAD_PATH from the shell, so tell it where the ",
                  "package is in _quarto.yml: julia: {env: [\"JULIA_LOAD_PATH=<the folder that holds the Weft ",
                  "package>:\"]}, that is a julia: key with an env: list holding JULIA_LOAD_PATH=, a folder and ",
                  "a trailing colon.")

# Does Quarto run this .qmd on the jupyter engine (N74): `engine: jupyter` or a `jupyter:` key; with neither
# an `engine:` key nor an executed {r} chunk, a {python} chunk. `engine: knitr` (or any other) is not.
doc_is_jupyter <- function(lines) {
  fm <- character()
  if (length(lines) && grepl("^---[ \t\r]*$", lines[1L])) {
    cl <- which(grepl("^(---|\\.\\.\\.)[ \t\r]*$", lines[-1L]))
    if (length(cl)) fm <- lines[seq_len(cl[1L] - 1L) + 1L]
  }
  eng <- grep("^engine[ \t]*:", fm, value = TRUE)
  if (length(eng)) {
    v <- sub("(^|[ \t])#.*$", "", sub("^engine[ \t]*:", "", eng[1L]))
    v <- tolower(gsub("^[ \t\"']+|[ \t\"']+$", "", v))
    return(identical(v, "jupyter"))
  }
  if (any(grepl("^jupyter[ \t]*:", fm))) return(TRUE)
  any(grepl("^[ \t>]*`{3,}[ \t]*\\{[ \t]*python[ \t,}]", lines)) &&
    !any(grepl("^[ \t>]*`{3,}[ \t]*\\{[ \t]*[rR][ \t,}]", lines))
}

# Does any .qmd of the project below `root` run on the jupyter engine?
project_has_jupyter_doc <- function(root) {
  docs <- project_doc_paths(root, "setup")
  docs <- docs[grepl("\\.qmd$", docs, ignore.case = TRUE)]
  for (d in docs) {
    lines <- tryCatch(read_source_lines(file.path(root, d)), error = function(e) character())
    if (doc_is_jupyter(lines)) return(TRUE)
  }
  FALSE
}

# Does Quarto run this .qmd on the julia engine (N74): `engine: julia`; with no `engine:` or `jupyter:` key, a
# {julia} chunk and no {r} or {python} chunk. `engine: knitr` (JuliaCall) or any other is not.
doc_is_julia <- function(lines) {
  fm <- character()
  if (length(lines) && grepl("^---[ \t\r]*$", lines[1L])) {
    cl <- which(grepl("^(---|\\.\\.\\.)[ \t\r]*$", lines[-1L]))
    if (length(cl)) fm <- lines[seq_len(cl[1L] - 1L) + 1L]
  }
  eng <- grep("^engine[ \t]*:", fm, value = TRUE)
  if (length(eng)) {
    v <- sub("(^|[ \t])#.*$", "", sub("^engine[ \t]*:", "", eng[1L]))
    v <- tolower(gsub("^[ \t\"']+|[ \t\"']+$", "", v))
    return(identical(v, "julia"))
  }
  if (any(grepl("^jupyter[ \t]*:", fm))) return(FALSE)
  chunk <- function(l) any(grepl(sprintf("^[ \t>]*`{3,}[ \t]*\\{[ \t]*%s[ \t,}]", l), lines, ignore.case = TRUE))
  chunk("julia") && !chunk("r") && !chunk("python")
}

# Does any .qmd of the project below `root` run on the julia engine?
project_has_julia_doc <- function(root) {
  docs <- project_doc_paths(root, "setup")
  docs <- docs[grepl("\\.qmd$", docs, ignore.case = TRUE)]
  for (d in docs) {
    lines <- tryCatch(read_source_lines(file.path(root, d)), error = function(e) character())
    if (doc_is_julia(lines)) return(TRUE)
  }
  FALSE
}

# The state of the `python` row of status() (N74): can `import weft` run in the Python Quarto would use.
status_python <- function(root) {
  py <- Sys.getenv("QUARTO_PYTHON", "")
  if (!nzchar(py)) py <- unname(Sys.which("python3"))
  if (!nzchar(py)) {
    return(list(state = "not checked", detail = "no Python found (QUARTO_PYTHON, then python3 on the PATH)"))
  }
  st <- suppressWarnings(tryCatch(system2(py, c("-I", "-c", shQuote("import weft")), stdout = FALSE, stderr = FALSE),
                                  error = function(e) 127L))
  if (identical(as.integer(st), 0L)) {
    list(state = "ok", detail = sprintf("`import weft` works in %s", py))
  } else {
    list(state = "missing", detail = sprintf("`import weft` fails in %s; %s", py, MSG_E61))
  }
}

# ---- editing _quarto.yml ----------------------------------------------------

weft_pre_entry  <- "_weft/pre-render.R"
weft_post_entry <- "_weft/post-render.R"

# the lines of _quarto.yml with weft added; the same lines when it is there;
# NULL when the file cannot be edited as text without risk. The file is never
# rewritten from its parsed form: that would turn `true` into `yes` (which
# Quarto's YAML 1.2 refuses), drop the comments and expand the anchors.
quarto_yml_with_weft <- function(lines) {
  load <- function(x) yaml_read_text(c(x, ""))
  y <- tryCatch(load(lines), error = function(e) NULL)
  if (is.null(y)) {
    if (any(nzchar(trimws(lines[!grepl("^\\s*#", lines)])))) return(NULL)
    y <- list()
  }
  if (!is.list(y)) return(NULL)
  if (!is.null(y$project) && !is.list(y$project)) return(NULL)
  as_chr <- function(x) as.character(unlist(x))
  need <- list(
    filters = !"weft-check" %in% as_chr(y$filters),
    pre     = !any(as_chr(y$project[["pre-render"]]) == weft_pre_entry),
    post    = !any(as_chr(y$project[["post-render"]]) == weft_post_entry)
  )
  if (!any(unlist(need))) return(lines)

  tryCatch({
    x <- lines
    if (need$filters) x <- yml_add_item(x, character(), "filters", "weft-check")
    if (need$pre)  x <- yml_add_item(x, "project", "pre-render", weft_pre_entry)
    if (need$post) x <- yml_add_item(x, "project", "post-render", weft_post_entry)
    chk <- load(x)
    seq_of <- function(v) if (is.null(v)) list() else as.list(v)
    ok <- is.list(chk) &&
      identical(names(chk)[names(chk) %in% names(y)], names(y)) &&
      identical(chk[setdiff(names(chk), c("filters", "project"))],
                y[setdiff(names(y), c("filters", "project"))]) &&
      identical(seq_of(chk$filters),
                c(seq_of(y$filters), if (need$filters) list("weft-check"))) &&
      identical(chk$project[setdiff(names(chk$project), c("pre-render", "post-render"))],
                y$project[setdiff(names(y$project), c("pre-render", "post-render"))]) &&
      identical(as_chr(chk$project[["pre-render"]]),
                c(as_chr(y$project[["pre-render"]]), if (need$pre) weft_pre_entry)) &&
      identical(as_chr(chk$project[["post-render"]]),
                c(as_chr(y$project[["post-render"]]), if (need$post) weft_post_entry))
    if (isTRUE(ok)) x else NULL
  }, error = function(e) NULL)
}

yml_indent <- function(x) nchar(sub("^( *).*$", "\\1", x))
yml_blank  <- function(x) !nzchar(trimws(x)) | grepl("^\\s*#", x)

# last line of the block that starts at line i (a `key:` line at `indent`)
yml_block_end <- function(lines, i, indent) {
  end <- i
  j <- i + 1L
  while (j <= length(lines)) {
    l <- lines[j]
    if (!yml_blank(l)) {
      ind <- yml_indent(l)
      if (ind < indent || (ind == indent && !grepl("^\\s*-(\\s|$)", l))) break
      end <- j
    }
    j <- j + 1L
  }
  end
}

# find `key:` at the top level, or inside the block of `parent`; NULL if none
yml_find <- function(lines, key, parent = character()) {
  lo <- 1L; hi <- length(lines); indent <- 0L
  if (length(parent)) {
    p <- yml_find(lines, parent)
    if (is.null(p)) return(NULL)
    lo <- p$line + 1L; hi <- p$end
    if (lo > hi) return(NULL)
    body <- lo:hi
    body <- body[!yml_blank(lines[body])]
    if (!length(body)) return(NULL)
    indent <- yml_indent(lines[body[1]])
  }
  pat <- sprintf("^ {%d}%s\\s*:", indent, gsub("([.-])", "\\\\\\1", key))
  idx <- grep(pat, lines[lo:hi]) + lo - 1L
  if (!length(idx)) return(NULL)
  i <- idx[1]
  list(line = i, indent = indent, end = yml_block_end(lines, i, indent))
}

# add `item` to the sequence at `key` (under `parent`), creating what is missing
yml_add_item <- function(lines, parent, key, item) {
  par <- if (length(parent)) yml_find(lines, parent) else NULL
  if (length(parent) && is.null(par)) {
    return(c(lines, paste0(parent, ":"), paste0("  ", key, ":"), paste0("    - ", item)))
  }
  if (length(parent)) {
    head <- lines[par$line]
    if (grepl(":\\s*[^#[:space:]]", head)) stop("flow or scalar parent")
  }
  f <- yml_find(lines, key, parent)
  if (is.null(f)) {
    if (!length(parent)) return(c(lines, paste0(key, ":"), paste0("  - ", item)))
    # first child's indentation, else two spaces
    body <- if (par$end > par$line) (par$line + 1L):par$end else integer()
    body <- body[!yml_blank(lines[body])]
    ci <- if (length(body)) yml_indent(lines[body[1]]) else par$indent + 2L
    pad <- strrep(" ", ci)
    return(append(lines, c(paste0(pad, key, ":"), paste0(pad, "  - ", item)), after = par$end))
  }
  head <- lines[f$line]
  val <- trimws(sub("#.*$", "", sub("^[^:]*:", "", head)))
  pad <- strrep(" ", f$indent)
  if (nzchar(val)) {
    if (grepl("^[\\[{|>&*!]", val)) stop("flow, anchored or block-scalar value")
    # a scalar becomes a list of the old value and the new one
    val <- gsub("^[\"']|[\"']$", "", val)
    new <- c(paste0(pad, key, ":"), paste0(pad, "  - ", val), paste0(pad, "  - ", item))
    return(append(lines[-f$line], new, after = f$line - 1L))
  }
  items <- which(grepl("^\\s*-(\\s|$)", lines[seq_along(lines)]) &
                 seq_along(lines) > f$line & seq_along(lines) <= f$end)
  ipad <- if (length(items)) strrep(" ", yml_indent(lines[items[1]])) else paste0(pad, "  ")
  last <- if (length(items)) f$end else f$line
  append(lines, paste0(ipad, "- ", item), after = last)
}
