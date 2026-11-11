# weft post-render script (rules 2.6.6, 2.9.4, 2.9.5). Written by
# weft::use_quarto(); run by Quarto after the render, in the project root.
#
# Plain base R: works when weft is not installed. This version reports what
# the collection file, .weft/failures.jsonl, holds, removes the file, and
# exits non-zero when it held anything (not in draft mode). The freeze report and the stamps of
# 2.9.x are added with the book reporting.

local({
  coll <- file.path(".weft", "failures.jsonl")
  if (!file.exists(coll)) return(invisible())
  lines <- readLines(coll, warn = FALSE, encoding = "UTF-8")
  lines <- lines[nzchar(trimws(lines))]
  unlink(coll)
  if (!length(lines)) return(invisible())

  field <- function(l, k) {
    m <- regmatches(l, regexec(sprintf("\"%s\":(\"((?:[^\"\\\\]|\\\\.)*)\"|[^,}]*)", k), l, perl = TRUE))[[1]]
    if (length(m) < 3) return("")
    v <- if (nzchar(m[3]) || startsWith(m[2], "\"")) m[3] else m[2]
    if (identical(v, "null")) "" else gsub("\\\\(.)", "\\1", v)
  }
  out <- vapply(lines, function(l) {
    where <- field(l, "file")
    ln <- field(l, "line")
    if (nzchar(ln)) where <- paste0(where, ":", ln)
    paste0("  ", if (nzchar(where)) paste0(where, ": ") else "",
           field(l, "kind"), " ", field(l, "message"), field(l, "text"))
  }, "", USE.NAMES = FALSE)
  cat(sprintf("weft: %d failure%s\n", length(out), if (length(out) == 1L) "" else "s"),
      out, sep = "\n", file = stderr())
  # draft mode reports and does not fail (9.4.3)
  draft <- tolower(Sys.getenv("WEFT_DRAFT", "")) %in% c("1", "true", "yes", "on")
  if (!draft && file.exists("_weft.yml")) {
    d <- grep("^draft:", readLines("_weft.yml", warn = FALSE), value = TRUE)
    if (length(d)) draft <- tolower(trimws(sub("#.*$", "", sub("^draft:", "", d[length(d)])))) %in% c("true", "yes", "1")
  }
  if (!draft) quit(save = "no", status = 1L)
})
