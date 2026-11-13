# weft pre-render script (rules 2.5.4, 2.6.6, 9.2.8). Written by
# weft::use_quarto() and run by Quarto before anything renders.
#
# Plain base R, so it works when weft is not installed or loadable.
#
# 1. Reads every .qmd the render will process and fails, naming the file, on
#    one that holds an R construct (an inline R value with an attribute block,
#    or a span whose governor is not a name or one comparison, rules 1.12.4 and
#    1.12.5) and has no `engine: knitr` in its own front matter (an `engine:`
#    in _quarto.yml or _metadata.yml does not count). Named values and spans of
#    that grammar are the filter's and need no knitr (rule 1.12.7).
# 2. Opens the collection file, .weft/failures.jsonl, empty. Documents and the
#    weft-check filter append to it while the render runs; the post-render
#    script reports it and removes it (2.6.6, 2.9.5). Also writes .weft/run,
#    the render's id and its files, for the freeze report (2.9.2).

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
  # A line with its code spans and escapes taken out, as Pandoc reads it (1.9):
  # code spans become blanks, except a code span that starts with `r `, `R ` or
  # `{r}` and is followed by an attribute block (a value construct), which is
  # returned as it is in `value`; `\\[`, `\\]` and `\\{` are blanked.
  plain_of <- function(x) {
    value <- FALSE
    m <- gregexpr("(?<!`)(`+)(?!`)(.+?)(?<!`)\\1(?!`)", x, perl = TRUE)[[1]]
    if (m[1] > 0L) {
      len <- attr(m, "match.length")
      for (k in rev(seq_along(m))) {
        span <- substr(x, m[k], m[k] + len[k] - 1L)
        rest <- substring(x, m[k] + len[k])
        inner <- sub("^`+[ ]?", "", sub("[ ]?`+$", "", span))
        if (grepl("^(r |R |\\{r\\})", inner) && grepl("^\\{[^}]*\\}", rest)) value <- TRUE
        substr(x, m[k], m[k] + len[k] - 1L) <- strrep(" ", len[k])
      }
    }
    x <- gsub("\\\\[][{}()`*_#<>|\\\\]", "  ", x)
    list(text = x, value = value)
  }
  # ---- the grammar of a span's governor, as regular expressions (rules 1.12.4, 1.12.5) ----
  reserved <- c("TRUE", "FALSE", "True", "False", "true", "false", "NA", "NULL", "None", "nothing",
                "missing", "Inf", "NaN")
  is_name <- function(x) {
    grepl("^[A-Za-z_][A-Za-z0-9_.]{0,63}\\z", x, perl = TRUE) && !grepl("[.]$", x) && !(x %in% reserved)
  }
  operand <- "(?:'[^'\\\\]*'|-?[0-9]+(?:\\.[0-9]+)?(?:[eE][+-]?[0-9]+)?|[A-Za-z_][A-Za-z0-9_.]*)"
  comparison <- paste0("^(", operand, ")[ \t]*(<=|>=|==|!=|<|>)[ \t]*(", operand, ")$")
  cond_ok <- function(part) {
    part <- gsub("^[ \t]+|[ \t]+$", "", part)
    if (is_name(part)) return(TRUE)
    # `!NAME`: the negation of one bool name; `!` before anything else is not in the grammar
    if (startsWith(part, "!") && is_name(substring(part, 2))) return(TRUE)
    m <- regmatches(part, regexec(comparison, part, perl = TRUE))[[1]]
    if (!length(m)) return(FALSE)
    ops <- m[c(2, 4)]
    lit <- grepl("^['0-9-]", ops)
    if (all(lit)) return(FALSE)
    all(lit | vapply(ops, is_name, NA))
  }
  # the comma-separated parts of a condition: a comma inside a 'string' splits nothing
  cond_parts <- function(x) {
    ch <- strsplit(x, "")[[1]]
    parts <- character()
    cur <- character()
    inq <- FALSE
    for (c in ch) {
      if (c == "'") inq <- !inq
      if (c == "," && !inq) {
        parts <- c(parts, paste(cur, collapse = ""))
        cur <- character()
      } else cur <- c(cur, c)
    }
    c(parts, paste(cur, collapse = ""))
  }
  governor_ok <- function(key, v) {
    v <- gsub("^[ \t]+|[ \t]+$", "", v)
    switch(key,
      "if" = all(vapply(cond_parts(v), cond_ok, NA)),
      n = is_name(v) || v == "." || grepl("^#[^[:space:]]+$", v),
      sign = is_name(v) || grepl("^#[^[:space:]]+$", v),
      list = is_name(v),
      TRUE)
  }
  # does a span's attribute block on this line hold a governor outside the grammar: `]{... if="..." ...}`
  span_bad <- function(text) {
    m <- gregexpr("\\]\\{[^}]*\\}", text, perl = TRUE)[[1]]
    if (m[1] < 0) return(FALSE)
    for (blk in regmatches(text, list(m))[[1]]) {
      kv <- gregexpr(paste0("(?<![A-Za-z0-9_.-])(n|if|sign|list)[[:space:]]*=[[:space:]]*",
                            "(?:\"[^\"]*\"|'[^']*'|[^[:space:]}\"']+)"),
                     blk, perl = TRUE, ignore.case = TRUE)[[1]]
      if (kv[1] < 0) next
      for (one in regmatches(blk, list(kv))[[1]]) {
        key <- tolower(sub("^([A-Za-z]+).*$", "\\1", one))
        val <- sub("^[A-Za-z]+[[:space:]]*=[[:space:]]*", "", one)
        val <- sub("^([\"'])(.*)\\1$", "\\2", val)
        if (!governor_ok(key, val)) return(TRUE)
      }
    }
    FALSE
  }
  # the first line holding an R construct: an inline R value with an attribute block, or a span whose
  # governor is outside the grammar. A named value, and a span of the grammar, are the filter's.
  first_construct <- function(prose) {
    for (j in seq_along(prose)) {
      p <- plain_of(prose[j])
      if (p$value || span_bad(p$text)) return(j)
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
        "_metadata.yml does not count). A document on another engine can use named values instead ",
        "(rule 1.12.7).\n", sep = "", file = stderr())
    quit(save = "no", status = 1L)
  }

  # ---- open the collection file -------------------------------------------
  # The run: an id on the first line of .weft/run, then the source files this
  # render processes. The collection file opens with a line that names the
  # run, so that a file left behind by a render that stopped is known for what
  # it is and not used by a later knit (2.6.6). Each executed knit stamps its
  # document with the id; the post-render script takes a document whose stamp
  # carries another id to have been served from freeze (2.9.2).
  dir.create(file.path(root, ".weft"), showWarnings = FALSE, recursive = TRUE)
  # What weft keeps under .weft/ is not for committing (review 2e-1, D).
  ignore <- file.path(root, ".weft", ".gitignore")
  if (!file.exists(ignore)) writeLines("*", ignore)
  id <- Sys.getenv("WEFT_RUN", "")
  if (!nzchar(id)) {
    id <- sprintf("%s-%d-%06d", format(Sys.time(), "%Y%m%dT%H%M%S"), Sys.getpid(),
                  sample.int(999999L, 1L))
  }
  rels <- substring(normalizePath(files, winslash = "/"), nchar(root) + 2L)
  writeLines(c(id, rels), file.path(root, ".weft", "run"))
  writeLines(sprintf("{\"run\":\"%s\"}", id), file.path(root, ".weft", "failures.jsonl"))
  invisible()
})
