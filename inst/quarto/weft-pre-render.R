# weft pre-render script (rules 2.5.4, 2.6.6, 9.2.8). Written by
# weft::use_quarto() and run by Quarto before anything renders.
#
# Plain base R, so it works when weft is not installed or loadable.
#
# 1. Reads every .qmd the render will process and fails, naming the file, on
#    one that holds a weft construct and has no `engine: knitr` in its own
#    front matter (an `engine:` in _quarto.yml or _metadata.yml does not count).
# 2. Opens the collection file, .weft/failures.jsonl, empty. Documents and the
#    weft-check filter append to it while the render runs; the post-render
#    script reports it and removes it (2.6.6, 2.9.5).

local({
  root <- normalizePath(".", winslash = "/", mustWork = TRUE)

  read_lines <- function(f) {
    x <- tryCatch(readLines(f, warn = FALSE, encoding = "UTF-8"), error = function(e) character())
    x[!is.na(x)]
  }

  # ---- which .qmd files will this render process? --------------------------
  project_yml <- function() {
    for (n in c("_quarto.yml", "_quarto.yaml")) {
      if (file.exists(file.path(root, n))) return(read_lines(file.path(root, n)))
    }
    character()
  }
  yml <- project_yml()

  # string leaves of the book's chapters / appendices (a simple text read of
  # the YAML: every `something.qmd` named under the `book:` block)
  book_files <- function() {
    i <- grep("^book:\\s*(#.*)?$", yml)
    if (!length(i)) return(NULL)
    rest <- yml[-seq_len(i[1])]
    stop_at <- grep("^[^[:space:]#-]", rest)
    if (length(stop_at)) rest <- rest[seq_len(stop_at[1] - 1L)]
    m <- regmatches(rest, gregexpr("[^[:space:]\"',:\\[\\]{}]+\\.qmd", rest))
    out <- unique(unlist(m))
    if (length(out)) out else NULL
  }
  is_book <- any(grepl("^\\s+type:\\s*[\"']?book[\"']?\\s*(#.*)?$", yml))

  inputs <- Sys.getenv("QUARTO_PROJECT_INPUT_FILES", "")
  files <- if (nzchar(inputs)) {
    f <- strsplit(inputs, "[\r\n]+")[[1]]
    f <- f[nzchar(f)]
    f <- ifelse(grepl("^(/|[A-Za-z]:[/\\\\])", f), f, file.path(root, f))
    f[grepl("\\.qmd$", f, ignore.case = TRUE)]
  } else {
    all <- list.files(root, pattern = "\\.qmd$", recursive = TRUE, full.names = TRUE,
                      ignore.case = TRUE)
    rel <- substring(all, nchar(root) + 2L)
    keep <- !grepl("(^|/)[_.]", rel) &
            !grepl("(^|/)(renv|site_libs|_freeze|_book|_site|node_modules|packrat)(/|$)", rel)
    out_dir <- sub("^\\s+output-dir:\\s*[\"']?([^\"'#]*?)[\"']?\\s*(#.*)?$", "\\1",
                   grep("^\\s+output-dir:", yml, value = TRUE))
    for (d in out_dir) if (nzchar(d)) keep <- keep & !startsWith(rel, paste0(sub("/$", "", d), "/"))
    all <- all[keep]
    if (is_book) {
      bf <- book_files()
      if (!is.null(bf)) all <- all[substring(all, nchar(root) + 2L) %in% sub("^\\./", "", bf)]
    }
    all
  }
  files <- files[file.exists(files)]

  # ---- does a file hold a construct? (without the weft scanner) -----------
  front_matter <- function(x) {
    if (!length(x) || !grepl("^---\\s*$", x[1])) return(character())
    end <- which(grepl("^(---|\\.\\.\\.)\\s*$", x[-1]))
    if (!length(end)) return(character())
    x[2:(end[1])]
  }
  has_engine_knitr <- function(fm) {
    any(grepl("^engine:\\s*[\"']?knitr[\"']?\\s*(#.*)?$", fm))
  }
  # prose lines: no front matter, no fenced code block (``` or ~~~)
  prose_of <- function(x) {
    fm <- front_matter(x)
    if (length(fm)) x <- x[-seq_len(length(fm) + 2L)]
    fence <- NULL
    keep <- logical(length(x))
    for (j in seq_along(x)) {
      m <- regmatches(x[j], regexec("^\\s{0,3}(`{3,}|~{3,})", x[j]))[[1]]
      if (is.null(fence)) {
        if (length(m)) fence <- m[2] else keep[j] <- TRUE
      } else if (length(m) && startsWith(m[2], substr(fence, 1, 1)) &&
                 nchar(m[2]) >= nchar(fence) && grepl("^\\s{0,3}[`~]+\\s*$", x[j])) {
        fence <- NULL
      }
    }
    x[keep]
  }
  first_construct <- function(prose) {
    # a span: ]{ ... } holding a weft key (any letter case) or a text class
    key  <- "\\]\\{([^}]*[[:space:]])?(n|if|sign|cite)[[:space:]]*="
    cls  <- "\\]\\{([^}]*[[:space:]])?\\.(a|cap|strong|em)([[:space:]}]|$)"
    # a value: a code span with an attribute block, its text R code
    code <- "`(r |R |\\{r\\})[^`]*`\\{[^}]*\\}"
    for (j in seq_along(prose)) {
      if (grepl(key, prose[j], ignore.case = TRUE, perl = TRUE) ||
          grepl(cls, prose[j], perl = TRUE) ||
          grepl(code, prose[j], perl = TRUE)) return(j)
    }
    NA_integer_
  }

  bad <- character()
  for (f in files) {
    x <- read_lines(f)
    if (has_engine_knitr(front_matter(x))) next
    pr <- prose_of(x)
    j <- first_construct(pr)
    if (!is.na(j)) {
      rel <- substring(normalizePath(f, winslash = "/"), nchar(root) + 2L)
      bad <- c(bad, sprintf("  %s: holds a weft construct (%s) and has no `engine: knitr` in its own front matter",
                            rel, trimws(substr(pr[j], 1, 60))))
    }
  }
  if (length(bad)) {
    cat("weft: the render stops before anything is rendered.\n", file = stderr())
    cat(bad, sep = "\n", file = stderr())
    cat("\nAdd `engine: knitr` to each file's own front matter (an `engine:` in _quarto.yml or\n",
        "_metadata.yml does not count), or run weft::use_setup().\n", sep = "", file = stderr())
    quit(save = "no", status = 1L)
  }

  # ---- open the collection file -------------------------------------------
  dir.create(file.path(root, ".weft"), showWarnings = FALSE, recursive = TRUE)
  file.create(file.path(root, ".weft", "failures.jsonl"))
  invisible()
})
