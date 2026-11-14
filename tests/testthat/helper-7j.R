# Package 7j: helpers for the tests of F9, checks of one value compared (dev/design-7.md section 2 I,
# N120 to N151). ASCII only. Invented content only.
#
# NAMES CHOSEN BY THE TEST WRITER (the design does not name them; the implementer matches them):
#   weft:::checks_read(src)       the reader of N120 to N126, N149 to N151. `src` is a read_source() result
#                                 (read_src() of helper-3.R). Returns a data frame, one row per check, sorted by
#                                 line then column, with at least the columns line (integer), role, level,
#                                 value, op, other, cond (NA when not readable), key (N124 key orientation,
#                                 NA when not readable), text, always, rebound.
#   weft:::check_implies(a, b, filter = FALSE)
#                                 does readable check `a` imply readable check `b` (N127 to N130)? a and b are
#                                 one-row data frames (columns value, op, other, as the reader gives them; a
#                                 bool check has op "is" and other "TRUE" or "FALSE"). `filter` is TRUE when b is
#                                 checked by the Lua filter (no double guard, N130). Returns TRUE or FALSE.
#   weft:::check_covered(b, new)  is the gone check `b` (one row) covered (N131) by the rows `new` (a data frame
#                                 of the reader's shape, with level, always, rebound)? Returns TRUE or FALSE.
#   weft:::dec_cmp(a, b)          named by the design: -1, 0 or 1 for two decimal texts.
#   weft:::CHECK_UNSAFE_FNS       named by the design.
# The rows these helpers build carry the reader's columns, so the relation can be tested with no file.

# the rows of the reader for `lines` of a document (an .Rmd: the knitr hooks resolve it; a plain .qmd with no
# R chunk is resolved by the filter)
j7_read <- function(lines, ext = "Rmd", ...) {
  weft:::checks_read(read_src(lines, ext = ext, ...))
}

# an executed R chunk (a label, for a chunk the gate sees as new: the lint rule chunk-label)
j7_chunk <- function(..., label = NULL) c(if (is.null(label)) "```{r}" else paste0("```{r ", label, "}"), c(...), "```")

# the rows of a document that is one chunk of `code`
j7_code <- function(code, ...) j7_read(j7_chunk(code), ...)

# the rows of one claim `claim(v, <arg>)`: a check with no `.` is read as written (N123)
j7_arg <- function(arg) j7_code(sprintf("claim(v, %s)", arg))

# the rows of one guard `if="<cond>"` in a document resolved by `ext`
j7_guard <- function(cond, ext = "Rmd") j7_read(sprintf("A [phrase]{if=\"%s\"} here.", cond), ext = ext)

# ---- rows for the relation (no file) ----------------------------------------------------------------------

J7_MIRROR <- c("<" = ">", "<=" = ">=", ">" = "<", ">=" = "<=", "==" = "==", "!=" = "!=")

# is the text of an operand a literal (number, string, date, bool, quantity)?
j7_is_literal <- function(x) {
  grepl("^-?[0-9.]+(e-?[0-9]+)?$", x) || grepl("^['\"]", x) || x %in% c("TRUE", "FALSE") || grepl("^u\\(", x)
}

# a one-row data frame in the reader's shape from the text of a readable check in N124 form
j7_row <- function(cond, level = "fail", always = TRUE, rebound = FALSE, line = 1L, role = "claim") {
  if (grepl("^!?[A-Za-z_.][A-Za-z0-9_.]*$", cond)) {
    value <- sub("^!", "", cond)
    op <- "is"
    other <- if (startsWith(cond, "!")) "FALSE" else "TRUE"
  } else {
    m <- regmatches(cond, regexec("^(.+?) (<=|>=|==|!=|<|>) (.+)$", cond, perl = TRUE))[[1]]
    stopifnot(length(m) == 4L)
    value <- m[[2]]
    op <- m[[3]]
    other <- m[[4]]
  }
  key <- cond
  if (op != "is" && !j7_is_literal(other) && identical(sort(c(value, other), method = "radix")[[1]], other)) {
    key <- paste(other, J7_MIRROR[[op]], value)
  }
  data.frame(file = "d.Rmd", line = as.integer(line), role = role, level = level, value = value, op = op,
             other = other, cond = cond, key = key, text = cond, always = always, rebound = rebound,
             stringsAsFactors = FALSE)
}

# several rows
j7_rows <- function(conds, ...) do.call(rbind, lapply(conds, j7_row, ...))

# ---- documents for the gate -----------------------------------------------------------------------------------

# words that tell paragraphs apart, so that a diff can only delete the paragraph a test means
J7_WORDS <- c("amber", "bravo", "cedar", "delta", "ember", "fjord", "grove", "heron", "ivory", "jasper", "kestrel", "lumen")

# a one-line paragraph holding one guard
j7_par <- function(cond, word = "exceeded the limit") sprintf("The site [%s]{if=\"%s\"} on most days.", word, cond)

# paragraphs, one per condition, blank lines between: paragraph i is on line 2 * i - 1. `ids` picks the word of
# each paragraph (so a document with a paragraph left out keeps the others' words); `word` overrides them.
j7_gdoc <- function(conds, ids = seq_along(conds), word = NULL) {
  out <- character()
  for (i in seq_along(conds)) {
    out <- c(out, if (i > 1L) "", j7_par(conds[[i]], if (is.null(word)) sprintf("%s limit", J7_WORDS[[ids[[i]]]]) else word))
  }
  out
}
# the line of paragraph i of j7_gdoc()
j7_gline <- function(i) 2L * i - 1L

# paragraphs holding one inline claim each
j7_cdoc <- function(claims, ids = seq_along(claims)) {
  out <- character()
  for (i in seq_along(claims)) {
    out <- c(out, if (i > 1L) "", sprintf("The %s peak was `r %s`{.num} today.", J7_WORDS[[ids[[i]]]], claims[[i]]))
  }
  out
}

# E80 to its end: from the header to the line before the next "commit-msg:" line
j7_block <- function(rep) {
  i <- grep("^commit-msg: [0-9]+ checks? gone since HEAD", rep)
  if (length(i) != 1L) return(character())
  nxt <- grep("^commit-msg: ", rep)
  nxt <- nxt[nxt > i]
  rep[i:(if (length(nxt)) nxt[[1]] - 1L else length(rep))]
}

# one file's part of the block of N137: the heading, then each row (line, shown, verdict text), then a blank line
j7_file_lines <- function(file, rows) {
  out <- sprintf("  %s, as in HEAD", file)
  for (r in rows) out <- c(out, sprintf("    %5d  %s", r$line, r$shown), paste0(strrep(" ", 11L), r$verdict))
  c(out, "")
}

J7_E80 <- "(information: what still checks each; rule 6.3.7)"
J7_E88 <- "not read: weft compares only comparisons whose sides are names, dictionary reads, value expressions or literals (rule 3.10)"
