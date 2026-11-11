## Two routes to the citation keys of a bibliography file.
pandoc_bin <- function() { q <- Sys.which("quarto"); if (nzchar(q)) c(q, "pandoc") else c(Sys.which("pandoc")) }
keys_pandoc <- function(path) {
  ext <- tolower(tools::file_ext(path)); pb <- pandoc_bin()
  from <- switch(ext, bib = "biblatex", bibtex = "bibtex", json = "csljson", yaml = , yml = "markdown", stop("unknown bib extension ", ext))
  src <- path; tmp <- NULL
  if (from == "markdown") {                      # plain CSL YAML has no `---`: Pandoc's --bibliography accepts it, the markdown reader does not
    x <- readLines(path, warn = FALSE, encoding = "UTF-8")
    if (!grepl("^---\\s*$", x[1])) { tmp <- tempfile(fileext = ".yaml"); writeLines(c("---", x, "---"), tmp, useBytes = TRUE); src <- tmp }
  }
  out <- system2(pb[1], c(pb[-1], "-f", from, "-t", "csljson", shQuote(src)), stdout = TRUE, stderr = FALSE)
  j <- jsonlite::fromJSON(paste(out, collapse = "\n"), simplifyVector = FALSE)
  vapply(j, function(x) x$id, "")
}
keys_native <- function(path) {
  ext <- tolower(tools::file_ext(path))
  if (ext %in% c("bib", "bibtex")) {
    x <- readLines(path, warn = FALSE, encoding = "UTF-8")
    m <- regmatches(x, regexec("^\\s*@([A-Za-z]+)\\s*[{(]\\s*([^,[:space:]]+)\\s*,", x))
    m <- Filter(length, m); m <- Filter(function(z) !tolower(z[2]) %in% c("comment", "string", "preamble"), m)
    vapply(m, `[`, "", 3)
  } else if (ext == "json") vapply(jsonlite::fromJSON(path, simplifyVector = FALSE), function(x) x$id, "")
  else if (ext %in% c("yaml", "yml")) { y <- yaml::read_yaml(path); r <- if (is.list(y) && !is.null(y$references)) y$references else y
    vapply(r, function(x) as.character(x$id), "") }
  else stop("unknown ext")
}
