# The bibliography of a document, for the knit-time check of `cite` spans
# (rules 1.8.5, 5.4.4 to 5.4.6, 2.1.6). Keys are read in R from BibTeX,
# BibLaTeX, CSL JSON and CSL YAML files; Pandoc is not called.

# The keys of one bibliography file, by its extension. A file that cannot be
# read has no keys.
read_bib_keys <- function(path) {
  ext <- tolower(tools::file_ext(path))
  txt <- tryCatch(paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n"),
                  error = function(e) NA_character_)
  if (is.na(txt)) return(character())
  ids_of <- function(refs) {
    if (!is.list(refs)) return(character())
    out <- vapply(refs, function(r) {
      id <- if (is.list(r)) r$id else NULL
      if (is.null(id) || length(id) != 1L) NA_character_ else as.character(id)
    }, "")
    out[!is.na(out)]
  }
  if (ext %in% c("bib", "bibtex", "biblatex")) {
    m <- gregexpr("(?<![A-Za-z0-9_])@([A-Za-z]+)[ \t\r\n]*[{(][ \t\r\n]*([^,[:space:]{}()]+)[ \t\r\n]*,",
                  txt, perl = TRUE)[[1L]]
    if (m[1L] < 0L) return(character())
    hits <- regmatches(txt, list(m))[[1L]]
    type <- tolower(sub("^@([A-Za-z]+).*$", "\\1", hits))
    key <- sub("^@[A-Za-z]+[ \t\r\n]*[{(][ \t\r\n]*([^,[:space:]{}()]+).*$", "\\1", hits)
    return(key[!(type %in% c("comment", "string", "preamble"))])
  }
  if (ext == "json") {
    x <- tryCatch(yaml::yaml.load(txt, eval.expr = FALSE), error = function(e) NULL)
    if (is.null(x) && requireNamespace("jsonlite", quietly = TRUE)) {
      x <- tryCatch(jsonlite::fromJSON(txt, simplifyVector = FALSE), error = function(e) NULL)
    }
    if (is.list(x) && !is.null(names(x)) && !is.null(x$references)) x <- x$references
    return(ids_of(x))
  }
  if (ext %in% c("yaml", "yml")) {
    x <- tryCatch(yaml::yaml.load(txt, eval.expr = FALSE), error = function(e) NULL)
    if (is.list(x) && !is.null(names(x)) && !is.null(x$references)) x <- x$references
    return(ids_of(x))
  }
  character()
}

# The bibliography files and inline references a block of metadata names.
metadata_bibliography <- function(meta) {
  if (!is.list(meta)) return(list(files = character(), keys = character()))
  files <- as.character(unlist(meta$bibliography))
  refs <- meta$references
  keys <- character()
  if (is.list(refs)) {
    keys <- vapply(refs, function(r) {
      id <- if (is.list(r)) r$id else NULL
      if (is.null(id) || length(id) != 1L) NA_character_ else as.character(id)
    }, "")
    keys <- keys[!is.na(keys)]
  }
  list(files = files, keys = keys)
}

# Quarto's merged metadata, which holds the project's own bibliography
# (2.1.6): the file named by QUARTO_EXECUTE_INFO, else quarto_inspect().
quarto_metadata <- function(path) {
  info <- Sys.getenv("QUARTO_EXECUTE_INFO", "")
  if (nzchar(info) && file.exists(info)) {
    x <- tryCatch(yaml::yaml.load_file(info, eval.expr = FALSE), error = function(e) NULL)
    if (!is.null(x)) return(x$format$metadata)
  }
  if (!is.null(path) && !is.na(path) && requireNamespace("quarto", quietly = TRUE)) {
    qmd <- sub("\\.rmarkdown$", ".qmd", path)
    if (file.exists(qmd) && grepl("\\.qmd$", qmd)) {
      x <- tryCatch(quarto::quarto_inspect(qmd), error = function(e) NULL)
      return(x$formats[[1L]]$metadata)
    }
  }
  NULL
}

# Every citation key the document's bibliography holds (5.4.4): the files named
# by `bibliography:` and the entries under `references:` in the front matter
# and in Quarto's merged metadata, and the files named by the `bibliography`
# setting. Read once per knit.
bibliography_keys <- function(s) {
  if (!is.null(s$bib_keys)) return(s$bib_keys)
  path <- s$input_path
  has_path <- !is.null(path) && !is.na(path)
  docdir <- if (has_path) dirname(path) else getwd()
  root <- if (has_path) find_project_root(path) else getwd()
  from_meta <- list(metadata_bibliography(s$front),
                    metadata_bibliography(quarto_metadata(if (has_path) path else NULL)))
  where <- function(p, bases) {
    if (grepl("^(/|~|[A-Za-z]:[/\\\\])", p)) return(path.expand(p))
    for (b in bases) {
      cand <- file.path(b, p)
      if (file.exists(cand)) return(cand)
    }
    NA_character_
  }
  files <- c(
    vapply(unlist(lapply(from_meta, `[[`, "files")), where, "", bases = c(docdir, root)),
    vapply(as.character(unlist(s$config$bibliography)), where, "", bases = c(root, docdir)))
  files <- unique(files[!is.na(files)])
  keys <- c(unlist(lapply(from_meta, `[[`, "keys")),
            unlist(lapply(files, read_bib_keys)))
  s$bib_keys <- unique(as.character(keys))
  s$bib_keys
}
