# The lints for named values (rules 5.12.1, 5.12.2; N144, N145 of dev/design-6.md): a name used with no
# publisher in sight, and a chunk that publishes where its output is dropped. Both read the document's rows
# and chunk table, which the reader already holds: nothing is read or parsed twice.

# ---- named-unpublished (5.12.1) ----------------------------------------------------------------

# The NAME tokens of a condition (N9): string literals taken out, numbers and reserved words are not names.
cond_names <- function(x) {
  x <- gsub("'[^']*'", " ", x)
  m <- gregexpr("(?<![A-Za-z0-9_.])[A-Za-z_][A-Za-z0-9_.]*", x, perl = TRUE)[[1L]]
  if (m[1L] < 0L) return(character())
  nm <- regmatches(x, list(m))[[1L]]
  nm[vapply(nm, is_weft_name, NA)]
}

# The names the filter's constructs use, one entry per row: a named value its NAME, a span its governor's
# names. Rows with an error are left to the `construct` lint.
named_uses <- function(rows) {
  i <- which(rows$resolver %in% "filter" & rows$kind %in% c("named", "n", "if", "sign", "list") &
               is.na(rows$error))
  nm <- lapply(i, function(k) {
    e <- trim_ws(rows$expr[k])
    switch(rows$kind[k],
           named = e,
           `if` = cond_names(e),
           if (is_weft_name(e)) e else character())
  })
  list(row = rep(i, lengths(nm)), name = unlist(nm, use.names = FALSE) %||% character())
}

# The `weft-values` blocks of a text (N20): the attribute text of the opening fence and the body.
values_blocks <- function(lines) {
  open <- grep("^[ \t]*(`{3,}|~{3,})[ \t]*\\{[^}]*\\.weft-values[^}]*\\}[ \t]*$", lines)
  lapply(open, function(k) {
    fence <- regmatches(lines[k], regexpr("`{3,}|~{3,}", lines[k]))
    close_re <- paste0("^[ \t]*", substr(fence, 1L, 1L), "{", nchar(fence), ",}[ \t]*$")
    rest <- if (k < length(lines)) lines[(k + 1L):length(lines)] else character()
    j <- which(grepl(close_re, rest))[1L]
    list(attrs = lines[k], body = if (is.na(j)) rest else rest[seq_len(j - 1L)])
  })
}

# The names a JSON text of schema 1 publishes, or `character()` when it does not read.
values_keys <- function(text) {
  x <- tryCatch(jsonlite::fromJSON(text, simplifyVector = FALSE), error = function(e) NULL)
  if (!is.list(x) || !is.list(x$values)) return(character())
  names(x$values) %||% character()
}

# What a text publishes or runs, for the search of N144: the code of its executed chunks, the keys of its
# hand-written blocks and of the values files they read, and the same of the files it includes (at most 8
# deep).
named_sources <- function(lines, chunks, dir, root, depth = 0L) {
  out <- list(code = character(), keys = character())
  if (nrow(chunks)) {
    run <- chunks$eval %in% TRUE
    out$code <- unlist(chunks$code[run], use.names = FALSE) %||% character()
  }
  for (b in values_blocks(lines)) {
    f <- regmatches(b$attrs[1L], regexec("file[ \t]*=[ \t]*\"([^\"]*)\"", b$attrs[1L]))[[1L]]
    if (length(f)) {
      p <- if (startsWith(f[2L], "/")) file.path(root, substring(f[2L], 2L)) else file.path(dir, f[2L])
      txt <- tryCatch(read_source_text_or_null(p), error = function(e) NULL)
      if (!is.null(txt)) out$keys <- c(out$keys, values_keys(txt))
    } else {
      out$keys <- c(out$keys, values_keys(paste(b$body, collapse = "\n")))
    }
  }
  if (depth < 8L) {
    inc <- regmatches(lines, regexec("\\{\\{<[ \t]*include[ \t]+([^ \t>]+)[ \t]*>\\}\\}", lines))
    for (m in inc[lengths(inc) > 0L]) {
      p <- if (startsWith(m[2L], "/")) file.path(root, substring(m[2L], 2L)) else file.path(dir, m[2L])
      il <- tryCatch(read_source_lines(p), error = function(e) NULL)
      if (is.null(il)) next
      ich <- chunk_table(il, labelled_chunks(dequote_chunks(il)))
      sub <- named_sources(il, ich, dirname(p), root, depth + 1L)
      out$code <- c(out$code, sub$code)
      out$keys <- c(out$keys, sub$keys)
    }
  }
  out
}

lint_named_unpublished <- function(src, ctx) {
  r <- src$rows
  if (!nrow(r) || !any(r$resolver %in% "filter" & r$kind %in% c("named", "n", "if", "sign", "list"))) {
    return(new_findings())
  }
  use <- named_uses(r)
  if (!length(use$name)) return(new_findings())
  first <- !duplicated(use$name)
  nm <- use$name[first]
  row <- use$row[first]
  found <- named_sources(src$lines, src$chunks, dirname(src$path), ctx$root)
  code <- paste(found$code, collapse = "\n")
  mentioned <- vapply(nm, function(x) {
    x %in% found$keys || (grepl(x, code, fixed = TRUE) &&
      grepl(paste0("(?<![A-Za-z0-9_.])", gsub(".", "\\.", x, fixed = TRUE), "(?![A-Za-z0-9_])"), code,
            perl = TRUE))
  }, NA)
  if (all(mentioned)) return(new_findings())
  nm <- nm[!mentioned]
  row <- row[!mentioned]
  finding_at(src, r$fstart[row], r$fend[row], "named-unpublished", nm,
             sprintf(paste0("`%s` is used by name but no chunk of this document mentions it; publish it with ",
                            "put(), weft_put() or @put (rule 5.12.1)."), nm),
             paste0("Publish it in code above: weft_put(name = ...) in R, put(name=...) in Python, @put name in Julia.",
                    # 6b publishes by itself only in a document that holds a named value (open finding, stage 6, 5)
                    if (!any(r$kind == "named")) {
                      paste0(" Under knitr, automatic publishing applies only to a document with a named value ",
                             "such as `x`{.val}; a governor's name needs weft_put().")
                    }),
             context = r$context[row])
}

# ---- publish-hidden (5.12.2) ---------------------------------------------------------------------

# The option that hides a chunk's output, as `include: false`, or NULL.
hidden_option <- function(opts) {
  for (nm in c("include", "output")) {
    v <- opts[[nm]]
    if (!is.null(v) && falsy(yaml_scalar_text(sub("^!expr[ \t]*", "", v)))) return(paste0(nm, ": false"))
  }
  NULL
}

# The lines of N59's kind that call `put` (and `auto`): a line whose first non-blank character is not `#`.
PUT_RE <- c(python = "(?<![A-Za-z0-9_.])(?:weft\\.)?put\\(",
            julia = "(?<![A-Za-z0-9_.])(?:Weft\\.)?(?:@put\\b|put\\()")
AUTO_RE <- "(?<![A-Za-z0-9_.])(?:weft\\.)?auto\\("

code_calls <- function(code, re) {
  code <- code[!grepl("^[ \t]*#", code)]
  any(grepl(re, code, perl = TRUE))
}

lint_publish_hidden <- function(src, ctx) {
  ch <- src$chunks
  if (!nrow(ch)) return(new_findings())
  eng <- tolower(ch$engine)
  cand <- which(eng %in% c("python", "julia") & ch$eval %in% TRUE)
  if (!length(cand) || dl_knitr_doc(src)) return(new_findings())
  out <- list()
  for (k in cand) {
    opt <- hidden_option(ch$options[[k]])
    if (is.null(opt)) next
    code <- ch$code[[k]]
    s <- src$line_start[ch$open[k]]
    e <- s + nchar(src$lines[ch$open[k]]) - 1
    if (code_calls(code, PUT_RE[[eng[k]]])) {
      out[[length(out) + 1L]] <- finding_at(
        src, s, e, "publish-hidden", ch$label[k],
        sprintf(paste0("chunk `%s` has %s, so what it publishes never reaches the document; publish in a chunk ",
                       "that shows its output, with echo: false if the code should not show (rule 5.12.2)."),
                ch$label[k], opt),
        "Use echo: false to hide the code, not include: false or output: false.", context = "chunk")
    }
    if (identical(eng[k], "python") && code_calls(code, AUTO_RE)) {
      out[[length(out) + 1L]] <- finding_at(
        src, s, e, "publish-hidden-auto", ch$label[k],
        sprintf(paste0("chunk `%s` calls auto() and has %s, so the names it sets are not published ",
                       "(rule 5.12.2)."), ch$label[k], opt),
        "Call auto() in a chunk that shows its output.", context = "chunk", spec = "5.12.2", tier = 2L)
    }
  }
  bind_findings(out)
}
