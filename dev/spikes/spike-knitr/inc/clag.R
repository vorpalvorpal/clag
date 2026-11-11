# Stand-in compiler: {{expr}} -> `r expr`; skips {{< shortcodes; skips fenced code.
clag_compile <- function(lines) {
  in_fence <- FALSE; fence <- NULL
  for (i in seq_along(lines)) {
    m <- regmatches(lines[i], regexec("^\\s*(`{3,}|~{3,})", lines[i]))[[1]]
    if (length(m)) {
      if (!in_fence) { in_fence <- TRUE; fence <- m[2]; next }
      else if (startsWith(m[2], fence)) { in_fence <- FALSE; next }
    }
    if (!in_fence)
      lines[i] <- gsub("\\{\\{(?!<)([^{}]+)\\}\\}", "`r \\1`", lines[i], perl = TRUE)
  }
  lines
}

# Bootstrap: knit everything after the calling chunk, compiled, in this session.
# "Calling chunk" = first fenced chunk whose body contains the text `clag_self_compile(`
# (marker is the call itself; no label needed). Offset is recorded for error mapping.
clag_self_compile <- function() {
  path  <- knitr::current_input(dir = TRUE)
  lines <- readLines(path, warn = FALSE)
  open  <- grep("^\\s*```+\\s*\\{", lines)
  start <- NA; end <- NA
  for (o in open) {
    cl <- o + which(grepl("^\\s*```+\\s*$", lines[(o + 1):length(lines)]))[1]
    if (any(grepl("clag_self_compile(", lines[o:cl], fixed = TRUE))) { end <- cl; break }
  }
  if (is.na(end)) stop("clag: bootstrap chunk not found in ", path)
  rest <- lines[-seq_len(end)]
  # The parent has already registered every chunk label in the file; drop those
  # after the bootstrap chunk so the child can re-parse them without "Duplicate label".
  labs <- names(knitr::knit_code$get())
  me   <- knitr::opts_current$get("label")
  if (!is.null(me) && me %in% labs)
    knitr::knit_code$delete(labs[-seq_len(match(me, labs))])
  options(clag.line_offset = end, clag.input = path)
  out <- knitr::knit_child(text = clag_compile(rest), quiet = TRUE)
  knitr::knit_exit()
  knitr::asis_output(paste(out, collapse = "\n"))
}
