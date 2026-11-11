# The arms of every governed span of a document, found by the scanner
# alone (rule 3.7.1). No R is evaluated.

ARM_ROLES <- list(
  n = list(`1` = "always", `2` = c("one", "other"),
           `3` = c("zero", "one", "other"), `4` = c("zero", "one", "two", "other")),
  `if` = list(`1` = "always", `2` = c("true", "false")),
  sign = list(`2` = c("positive", "negative"), `3` = c("positive", "negative", "zero"))
)

arm_roles <- function(key, narms) {
  r <- ARM_ROLES[[key]][[as.character(narms)]]
  if (is.null(r)) NULL else r
}

#' List the arms of every governed span of a document
#'
#' Reads one or more `.qmd` or `.Rmd` files with the scanner and lists, for
#' every `n`, `if` and `sign` span, each of its arms: the span's place, the
#' key and its expression, the arm's role and the text the author wrote. The
#' spans are those in prose, in captions, in front-matter fields and in
#' literal `weft_str()` strings. No R is run: the file is parsed, never
#' evaluated, so an expression that stops, writes a file or names an unknown
#' object does nothing.
#'
#' A file with a construct error is still listed. The errors are in the
#' attribute `errors`, and the print method ends with them. A span whose arm
#' count is not one the key accepts is not listed; it is one of the errors.
#' So is an `n` span with more than one arm in a document whose `lang` is not
#' English, because weft ships no other plural rules (rules 1.6.4, 1.6.5).
#'
#' Only the spans of the files given are listed; a document that a chunk
#' includes with `child=` is listed only when it is given too.
#'
#' @param file One path, or several, to documents.
#' @return A data frame of class `weft_arms`, one row per arm, with the
#'   columns `file`, `line` (where the span starts), `context`, `span` (the
#'   span's number in the result, in document order), `key` (`"n"`, `"if"`
#'   or `"sign"`), `expr` (the key's value), `arm` (the arm's index in its
#'   span), `role` (`"always"`, `"one"`, `"other"`, `"zero"`, `"two"`,
#'   `"true"`, `"false"`, `"positive"` or `"negative"`), `text` (the arm as
#'   written, trimmed), and `parent_span` and `parent_arm` (the span and arm
#'   it is nested in, or `NA`).
#' @seealso [rehearse()], which knits a document under several sets of
#'   parameters and reports which arms they chose.
#' @export
arms <- function(file) {
  file <- as.character(file)
  if (!length(file) || anyNA(file)) {
    weft_abort("`file` must be one path, or several.", "weft_arms_error")
  }
  frames <- list()
  errs <- list()
  offset <- 0L
  for (f in file) {
    if (!file.exists(f)) weft_abort(sprintf("%s does not exist.", f), "weft_arms_error")
    one <- arms_one(f, offset)
    offset <- offset + length(unique(one$arms$span))
    frames[[length(frames) + 1L]] <- structure(one$arms, chunks = one$chunks)
    errs[[length(errs) + 1L]] <- one$errors
  }
  out <- do.call(rbind, frames)
  rownames(out) <- NULL
  errors <- do.call(rbind, errs)
  rownames(errors) <- NULL
  meta <- do.call(rbind, lapply(frames, attr, "chunks"))
  structure(out, class = c("weft_arms", "data.frame"), errors = errors, chunks = meta)
}

arms_empty <- function() {
  data.frame(file = character(), line = integer(), context = character(),
             span = integer(), key = character(), expr = character(),
             arm = integer(), role = character(), text = character(),
             parent_span = integer(), parent_arm = integer(),
             stringsAsFactors = FALSE)
}

arms_one <- function(path, offset = 0L) {
  rows <- scan_file(path)
  errors <- data.frame(file = character(), line = integer(), message = character(),
                       stringsAsFactors = FALSE)
  if (nrow(rows)) {
    bad <- which(!is.na(rows$error))
    if (length(bad)) {
      errors <- data.frame(file = rep(path, length(bad)), line = rows$line[bad],
                           message = rows$error[bad], stringsAsFactors = FALSE)
    }
  }
  gov <- if (nrow(rows)) which(rows$kind %in% names(ARM_ROLES)) else integer()
  # a two-arm or longer `n` in a language whose plural rules weft does not ship
  # is a construct error (1.6.4, 1.6.5): listed in `errors`, with no rows
  lang <- tolower(sub("[-_].*$", "", as.character(read_front_matter(path)$lang)[1L] %||% ""))
  if (!is.na(lang) && nzchar(lang) && lang != "en" && length(gov)) {
    plural <- gov[rows$kind[gov] == "n" & lengths(rows$arms[gov]) > 1L &
                    is.na(rows$error[gov])]
    if (length(plural)) {
      errors <- rbind(errors, data.frame(
        file = rep(path, length(plural)), line = rows$line[plural],
        message = sprintf(paste0("An `n` span with more than one arm needs the plural rules of `%s`, ",
                                 "which weft does not ship; English rules are never applied to another ",
                                 "language (rules 1.6.5, 1.6.7)."),
                          as.character(read_front_matter(path)$lang)[1L]),
        stringsAsFactors = FALSE))
      gov <- setdiff(gov, plural)
    }
  }
  # the place of each row among the rows that read alike: a knit records the
  # same number, and that is how a rehearsal tells apart the same span twice
  prose <- rows$context %in% c("prose", "front-matter")
  grp <- paste(ifelse(prose, "prose", rows$context), rows$line,
               rows$chunk, gsub("-", ".", rows$option, fixed = TRUE), rows$kind, rows$expr,
               sep = "\r")
  ord <- if (nrow(rows)) as.integer(stats::ave(seq_len(nrow(rows)), grp, FUN = seq_along)) else integer()
  gov <- Filter(function(k) !is.null(arm_roles(rows$kind[k], length(rows$arms[[k]]))), gov)
  no_chunks <- data.frame(span = integer(), chunk = character(), option = character(),
                          ord = integer(), stringsAsFactors = FALSE)
  if (!length(gov)) return(list(arms = arms_empty(), errors = errors, chunks = no_chunks))
  span_of <- rep(NA_integer_, nrow(rows))
  span_of[gov] <- offset + seq_along(gov)
  # the nearest governed span around a row, and the arm of it the row is in
  up <- function(k) {
    child <- k
    p <- rows$parent[k]
    while (!is.na(p)) {
      if (!is.na(span_of[p])) {
        a <- rows$arm[child]
        return(c(span_of[p], if (is.na(a)) 1L else a))
      }
      child <- p
      p <- rows$parent[p]
    }
    c(NA_integer_, NA_integer_)
  }
  parts <- lapply(gov, function(k) {
    a <- rows$arms[[k]]
    pa <- up(k)
    data.frame(file = path, line = rows$line[k], context = rows$context[k],
               span = span_of[k], key = rows$kind[k], expr = rows$expr[k],
               arm = seq_along(a), role = arm_roles(rows$kind[k], length(a)),
               text = as.character(a), parent_span = pa[1L], parent_arm = pa[2L],
               stringsAsFactors = FALSE)
  })
  # the chunk and option a caption span is in: a knit knows a caption by these
  chunks <- data.frame(span = span_of[gov], chunk = as.character(rows$chunk[gov]),
                       option = as.character(rows$option[gov]), ord = ord[gov],
                       stringsAsFactors = FALSE)
  list(arms = do.call(rbind, parts), errors = errors, chunks = chunks)
}

# ---- printing -------------------------------------------------------------

# The attribute braces of an arm's text are shown as `{..}`: the nested
# spans' own expressions are listed under their own headers.
# A newline in an arm is shown as a space.
elide_attrs <- function(x) {
  gsub("[ \t]*\r?\n[ \t]*", " ", gsub("\\{[^{}]*\\}", "{..}", x, perl = TRUE))
}

display_files <- function(files) {
  u <- unique(files)
  if (anyDuplicated(basename(u))) files else basename(files)
}

# Lines for the spans whose parent is (`parent`, `parent_arm`), arms under each.
format_arm_tree <- function(x, parent = NA_integer_, parent_arm = NA_integer_,
                            depth = 0L, shown = display_files(x$file)) {
  pad <- strrep("  ", depth)
  top <- if (is.na(parent)) is.na(x$parent_span) else
    (!is.na(x$parent_span) & x$parent_span == parent &
       !is.na(x$parent_arm) & x$parent_arm == parent_arm)
  spans <- unique(x$span[top])
  out <- character()
  for (sp in spans) {
    rows <- x[x$span == sp, , drop = FALSE]
    rows <- rows[order(rows$arm), , drop = FALSE]
    out <- c(out, sprintf("%s%s:%d  %s=\"%s\"", pad, shown[match(sp, x$span)],
                          rows$line[1L], rows$key[1L], rows$expr[1L]))
    for (i in seq_len(nrow(rows))) {
      out <- c(out, sprintf("%s  %d (%s)  %s", pad, rows$arm[i], rows$role[i],
                            elide_attrs(rows$text[i])),
               format_arm_tree(x, sp, rows$arm[i], depth + 2L, shown))
    }
  }
  out
}

#' @export
print.weft_arms <- function(x, ...) {
  if (!nrow(x)) {
    cat("No governed spans.\n")
  } else {
    cat(format_arm_tree(x), sep = "\n")
  }
  err <- attr(x, "errors")
  if (is.data.frame(err) && nrow(err)) {
    # named as the tree names them: by the same rule, over every file shown
    shown <- display_files(c(x$file, err$file))
    shown <- shown[length(x$file) + seq_len(nrow(err))]
    cat("", sprintf("%d construct error%s:", nrow(err), if (nrow(err) == 1L) "" else "s"),
        sprintf("  %s:%d  %s", shown, err$line,
                gsub("\n", " ", err$message)), sep = "\n")
  }
  invisible(x)
}
