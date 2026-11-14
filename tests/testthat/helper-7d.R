# Package 7d: helpers for the rendered-output check (dev/design-7.md section 2.D, N50 to N59).
# helper-filter.R is not edited: the design says filter_md() "gains an argument post = TRUE", which would mean
# changing it, so filter_md_post() here runs the existing filters and then weft-output.lua last.
# ASCII only.
#
#   filter_md_post(md, ..., pre)   filter_md() with the filters `pre` (default: weft.lua, weft-check.lua)
#                                  followed by inst/quarto/weft-output.lua. `pre = character()` runs the output
#                                  filter alone (needed where weft-check.lua would fail on the same text).
#                                  WEFT_OUTPUT_LOG is unset unless `env` sets it.
#   o7_run(md, ...)                filter_md_post() with WEFT_OUTPUT_LOG set to a fresh file; adds `log` (the
#                                  lines written to it) and `findings` (the parsed JSON lines of source
#                                  "output") to the result.
#   o7_parse(lines)                the records of source "output" in JSON lines.
#   o7_sec(id, ...)                a section: a heading with an explicit id, then the blocks.
#   o7_texts(res), o7_kinds(res)   the `text` and `kind` of each finding.

O7_PRE <- c("weft.lua", "weft-check.lua")

filter_md_post <- function(md, ..., pre = O7_PRE, env = character()) {
  if (!"WEFT_OUTPUT_LOG" %in% names(env)) env <- c(env, WEFT_OUTPUT_LOG = NA_character_)
  filter_md(md, ..., env = env, filters = c(pre, "weft-output.lua"))
}

o7_parse <- function(lines) {
  lines <- lines[grepl("^\\s*\\{", lines) & grepl("\"source\"\\s*:\\s*\"output\"", lines)]
  lapply(lines, function(l) jsonlite::fromJSON(l, simplifyVector = FALSE))
}

o7_run <- function(md, ..., env = character()) {
  log <- withr::local_tempfile(fileext = ".jsonl", .local_envir = parent.frame())
  env <- c(env, WEFT_OUTPUT_LOG = log)
  res <- filter_md_post(md, ..., env = env)
  res$log <- if (file.exists(log)) readLines(log, warn = FALSE, encoding = "UTF-8") else character()
  res$findings <- o7_parse(res$log)
  res
}

o7_sec <- function(id, ...) c(sprintf("## Section %s {#%s}", id, id), "", unlist(lapply(list(...), function(b) c(b, ""))))

o7_texts <- function(res) vapply(res$findings, function(f) as.character(f$text), "")
o7_kinds <- function(res) vapply(res$findings, function(f) as.character(f$kind), "")
o7_field <- function(res, k) vapply(res$findings, function(f) as.character(f[[k]]), "")

# the finding whose excerpt holds `frag` (NULL when there is none)
o7_by_excerpt <- function(res, frag) {
  for (f in res$findings) if (grepl(frag, f$excerpt, fixed = TRUE)) return(f)
  NULL
}
