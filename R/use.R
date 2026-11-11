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
#' two scripts under `project: pre-render:` and `post-render:`. Everything
#' else in `_quarto.yml` is kept, and the comments too when the file is
#' simple enough to edit as text. Running it again changes nothing.
#'
#' The scripts are plain base R and run when weft is not installed. The
#' pre-render script fails the render, before anything renders, on a `.qmd`
#' that holds a construct and has no `engine: knitr` in its own front matter
#' (9.2.8). It also opens the collection file `.weft/failures.jsonl`, which
#' the filter and the documents append to and the post-render script reports.
#'
#' @param path The project root: a directory holding `_quarto.yml`. Where
#'   there is none, `use_quarto()` stops: it does not turn a directory into a
#'   Quarto project.
#' @return The paths it wrote or changed, relative to `path`, invisibly.
#' @export
use_quarto <- function(path = ".") {
  if (!dir.exists(path)) {
    stop("`path` is not a directory: ", path, call. = FALSE)
  }
  path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  yml_name <- c("_quarto.yml", "_quarto.yaml")
  yml_name <- yml_name[file.exists(file.path(path, yml_name))][1]
  if (is.na(yml_name)) {
    stop("`", path, "` has no _quarto.yml, so it is not a Quarto project. ",
         "Create the project first (`quarto create project`), then run use_quarto().",
         call. = FALSE)
  }

  src <- function(f) {
    p <- system.file("quarto", f, package = "weft")
    if (!nzchar(p)) stop("weft's own file inst/quarto/", f, " is missing", call. = FALSE)
    p
  }
  copies <- c(
    "_extensions/weft-check/_extension.yml" = "_extension.yml",
    "_extensions/weft-check/weft-check.lua" = "weft-check.lua",
    "_weft/pre-render.R"                    = "weft-pre-render.R",
    "_weft/post-render.R"                   = "weft-post-render.R"
  )
  sources <- vapply(copies, src, "")
  names(sources) <- names(copies)
  weft_yml <- file.path(path, "_weft.yml")
  make_weft_yml <- !file.exists(weft_yml)

  message("weft will write, under ", path, ":")
  message("  _extensions/weft-check/_extension.yml and weft-check.lua  (the weft-check filter)")
  message("  _weft/pre-render.R   (fails a .qmd with constructs and no `engine: knitr`; opens .weft/failures.jsonl)")
  message("  _weft/post-render.R  (reports what the render collected)")
  message(if (make_weft_yml) "  _weft.yml  (new, empty but for a comment)"
          else "  _weft.yml  (exists: left as it is)")
  message("  ", yml_name, "  (adds the filter weft-check, and the two scripts under project:)")

  written <- character()
  for (rel in names(sources)) {
    dest <- file.path(path, rel)
    dir.create(dirname(dest), showWarnings = FALSE, recursive = TRUE)
    if (!file.exists(dest) ||
        !identical(unname(tools::md5sum(dest)), unname(tools::md5sum(sources[[rel]])))) {
      file.copy(sources[[rel]], dest, overwrite = TRUE)
      written <- c(written, rel)
    }
  }
  if (make_weft_yml) {
    writeLines(c("# weft settings for this project. Every key has a default;",
                 "# add only what you change (digits, decimal_mark, draft, ...)."),
               weft_yml)
    written <- c(written, "_weft.yml")
  }

  qy <- file.path(path, yml_name)
  old <- readLines(qy, warn = FALSE, encoding = "UTF-8")
  new <- quarto_yml_with_weft(old)
  if (!identical(new, old)) {
    writeLines(new, qy, useBytes = TRUE)
    written <- c(written, yml_name)
  }

  message(if (length(written)) paste0("Wrote: ", paste(written, collapse = ", "))
          else "Nothing to change: the project is already set up.")
  invisible(written)
}

# ---- editing _quarto.yml ----------------------------------------------------

weft_pre_entry  <- "_weft/pre-render.R"
weft_post_entry <- "_weft/post-render.R"

# the lines of _quarto.yml with weft added; the same lines when it is there
quarto_yml_with_weft <- function(lines) {
  y <- yaml::yaml.load(paste(c(lines, ""), collapse = "\n"))
  if (is.null(y)) y <- list()
  if (!is.list(y)) stop("_quarto.yml is not a YAML mapping", call. = FALSE)
  as_chr <- function(x) as.character(unlist(x))
  need <- list(
    filters = !"weft-check" %in% as_chr(y$filters),
    pre     = !any(as_chr(y$project[["pre-render"]]) == weft_pre_entry),
    post    = !any(as_chr(y$project[["post-render"]]) == weft_post_entry)
  )
  if (!any(unlist(need))) return(lines)

  edited <- tryCatch({
    x <- lines
    if (need$filters) x <- yml_add_item(x, character(), "filters", "weft-check")
    if (need$pre)  x <- yml_add_item(x, "project", "pre-render", weft_pre_entry)
    if (need$post) x <- yml_add_item(x, "project", "post-render", weft_post_entry)
    chk <- yaml::yaml.load(paste(c(x, ""), collapse = "\n"))
    ok <- "weft-check" %in% as_chr(chk$filters) &&
      weft_pre_entry %in% as_chr(chk$project[["pre-render"]]) &&
      weft_post_entry %in% as_chr(chk$project[["post-render"]])
    # nothing else may have changed
    y2 <- y
    y2$filters <- c(as_chr(y$filters), if (need$filters) "weft-check")
    ok && identical(names(chk), c(names(y), setdiff(names(chk), names(y)))) &&
      identical(chk[setdiff(names(chk), c("filters", "project"))],
                y[setdiff(names(y), c("filters", "project"))]) && x
  }, error = function(e) FALSE)
  if (is.character(edited)) return(edited)

  # the file is too unusual to edit as text: rewrite it from its parsed form
  # (what it says is kept; its comments are not)
  as_seq <- function(x, add) as.list(unique(c(as_chr(x), add)))
  y$filters <- as_seq(y$filters, "weft-check")
  if (is.null(y$project)) y$project <- list()
  y$project[["pre-render"]]  <- as_seq(y$project[["pre-render"]], weft_pre_entry)
  y$project[["post-render"]] <- as_seq(y$project[["post-render"]], weft_post_entry)
  strsplit(sub("\n$", "", yaml::as.yaml(y, indent.mapping.sequence = TRUE)), "\n")[[1]]
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
