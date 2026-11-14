# Package 6c: running the resolver filter (inst/quarto/weft.lua, then weft-check.lua) through plain
# Pandoc (dev/design-6.md, section 5, "Lua from testthat" and the 6c file list). ASCII only.
#
# Builds on helper-lua.R (lua_pandoc(), lua_pandocs(), skip_if_no_lua_pandoc(), lua_version_ok()).
#
# HELPERS
#   filter_path(name)            the shipped Lua file (a path; it may be absent: the tests then FAIL).
#   filter_md(md, files, to, env, weft_yml, ...)
#                                writes doc.md (and `files`) into a temporary project, runs
#                                `pandoc doc.md --lua-filter weft.lua --lua-filter weft-check.lua -t <to>`
#                                and returns list(output, stderr, status, files, dir, collected).
#   carrier(...)                 a weft-values block (four backticks) from NAME = record-JSON pairs.
#   fr_*()                       the records of N22 as compact JSON text; fr_with() adds record checks.
#   filter_cases(cases, blocks)  one document, one paragraph per case, run through the filter; `got` holds
#                                the output paragraphs by case name, `line` the source line of each case.
#   fm_msg                       the message texts of section 7 (E1 to E35), built from their templates.
#   fm_entry(), fm_headings()    pick the report's entries and headings out of stderr (N86).
#
# A test fails, it does not skip, while inst/quarto/weft.lua does not exist: filter_md() records a failed
# expectation naming the missing file, and Pandoc's own non-zero status follows. Skips are only for a
# missing Pandoc (skip_if_no_lua_pandoc()).

filter_path <- function(name = "weft.lua") {
  p <- system.file("quarto", name, package = "weft")
  if (nzchar(p)) p else file.path(system.file(package = "weft"), "quarto", name)
}

fm_or <- function(a, b) if (is.null(a)) b else a

# ---- running -----------------------------------------------------------------------------------------

# md        the document, a character vector (lines) or one string.
# files     a named list: project-relative path -> text (a character vector of lines), written first.
# to        Pandoc's writer. env: a named character vector of environment variables for the run
#           (WEFT_DRAFT, WEFT_COLLECT and WEFT_RUN are unset otherwise).
# weft_yml  the text of the project's _weft.yml (lines), or NULL for none.
# name      the document's project-relative path; run_in the project-relative folder Pandoc runs in.
# args      extra Pandoc arguments (before the input); extra_inputs more input files after the document.
# filters   the Lua filters to run, in order (default: weft.lua then weft-check.lua).
# collect   NULL; or TRUE (an empty collection file) or lines to seed it with: WEFT_COLLECT names it.
filter_md <- function(md, files = list(), to = "html", env = character(), weft_yml = NULL,
                      name = "doc.md", run_in = ".", args = character(), extra_inputs = character(),
                      filters = c("weft.lua", "weft-check.lua"), collect = NULL, pandoc = NULL) {
  skip_if_no_lua_pandoc()
  pandoc <- fm_or(pandoc, lua_pandoc())
  for (f in filters) {
    p <- filter_path(f)
    ok <- file.exists(p)
    testthat::expect(ok, sprintf("inst/quarto/%s is missing: the filter is not built yet", f))
  }
  dir <- withr::local_tempdir(.local_envir = parent.frame())
  dir <- normalizePath(dir, winslash = "/")
  put <- function(rel, text) {
    path <- file.path(dir, rel)
    dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
    con <- file(path, "wb")
    on.exit(close(con))
    writeBin(charToRaw(enc2utf8(paste0(paste(text, collapse = "\n"), "\n"))), con)
  }
  for (f in names(files)) put(f, files[[f]])
  if (!is.null(weft_yml)) put("_weft.yml", weft_yml)
  put(name, md)
  dir.create(file.path(dir, run_in), showWarnings = FALSE, recursive = TRUE)
  coll <- NULL
  vars <- c(WEFT_DRAFT = NA, WEFT_COLLECT = NA, WEFT_RUN = NA)
  if (!is.null(collect)) {
    coll <- file.path(dir, "collected.jsonl")
    if (isTRUE(collect)) file.create(coll) else put("collected.jsonl", collect)
    vars[["WEFT_COLLECT"]] <- coll
  }
  for (n in names(env)) vars[[n]] <- env[[n]]
  withr::local_envvar(vars)
  withr::local_dir(file.path(dir, run_in))
  rel <- function(p) {
    if (run_in %in% c(".", "")) return(p)
    pre <- paste0(run_in, "/")
    if (startsWith(p, pre)) return(substring(p, nchar(pre) + 1L))
    paste0(strrep("../", length(strsplit(run_in, "/", fixed = TRUE)[[1]])), p)
  }
  out <- file.path(dir, "out.txt")
  errf <- tempfile("pd-err-")
  on.exit(unlink(errf), add = TRUE)
  flt <- unlist(lapply(filters, function(f) c("--lua-filter", shQuote(filter_path(f)))))
  a <- c(pandoc$pre, "-f", "markdown", "-t", to, "--wrap=none", "-o", shQuote(out), flt,
         vapply(args, shQuote, ""), shQuote(rel(name)), vapply(extra_inputs, function(x) shQuote(rel(x)), ""))
  status <- suppressWarnings(system2(pandoc$cmd, a, stdout = FALSE, stderr = errf))
  rd <- function(f) {
    if (!file.exists(f)) return("")
    paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  }
  written <- list()
  for (d in c(".weft", "_weft")) {
    root <- file.path(dir, d)
    if (!dir.exists(root)) next
    for (r in list.files(root, recursive = TRUE, all.files = TRUE)) written[[file.path(d, r)]] <- rd(file.path(root, r))
  }
  list(output = rd(out), stderr = rd(errf), status = as.integer(status), files = written, dir = dir,
       collected = if (is.null(coll)) NULL else readLines(coll, warn = FALSE, encoding = "UTF-8"),
       md = paste(md, collapse = "\n"))
}

strip_tags <- function(x) gsub("<[^>]+>", "", x)

# ---- the carrier (N20, N21, N22) ---------------------------------------------------------------------

jstr <- function(x) as.character(jsonlite::toJSON(x, auto_unbox = TRUE))

fr_str <- function(text) sprintf('{"t":"string","v":%s}', jstr(text))
fr_bool <- function(v) sprintf('{"t":"bool","v":%s}', if (isTRUE(v)) "true" else "false")
fr_date <- function(iso) sprintf('{"t":"date","v":"%s"}', iso)
fr_missing <- function(why) sprintf('{"t":"missing","why":%s}', jstr(why))
fr_error <- function(why) sprintf('{"t":"error","why":%s}', jstr(why))
# a list of int records
fr_list_int <- function(digits) {
  sprintf('{"t":"list","v":[%s],"of":"int","keys":null}',
          paste(vapply(digits, fr_int, ""), collapse = ","))
}
fr_list_str <- function(x) {
  sprintf('{"t":"list","v":[%s],"of":"string","keys":null}',
          paste(vapply(x, fr_str, ""), collapse = ","))
}
fr_list_float <- function(x) {
  sprintf('{"t":"list","v":[%s],"of":"float","keys":null}',
          paste(vapply(x, fr_float, ""), collapse = ","))
}

# one check object (N23). `level` NULL leaves the member out (absent means "fail"); `ok` TRUE, FALSE or NA
# (null); `why` NULL is null.
fr_check <- function(text, ok = FALSE, level = NULL, why = NULL, extra = "") {
  sprintf('{"text":%s,"ok":%s%s,"why":%s%s}', jstr(text),
          if (is.na(ok)) "null" else if (ok) "true" else "false",
          if (is.null(level)) "" else sprintf(',"level":"%s"', level),
          if (is.null(why)) "null" else jstr(why), extra)
}
# a record with use-site checks (N22 `checks`)
fr_with <- function(record, ...) {
  sub("\\}$", sprintf(',"checks":[%s]}', paste(c(...), collapse = ",")), record)
}

# The block's JSON text: schema 1 with the given values (NAME = record JSON). `members` is extra JSON
# members text after `values` (for example '"checks":[...]'), without a leading comma.
carrier_json <- function(..., members = NULL, weft = "1") {
  v <- list(...)
  body <- paste(sprintf("%s:%s", vapply(names(v), jstr, ""), unlist(v)), collapse = ",")
  sprintf('{"weft":%s,"values":{%s}%s}', weft, body, if (is.null(members)) "" else paste0(",", members))
}
# The block as lines of markdown: four backticks, class weft-values.
carrier_raw <- function(text, attrs = "{.weft-values}", fence = "````") {
  c(paste0(fence, attrs), text, fence)
}
carrier <- function(..., members = NULL, attrs = "{.weft-values}") {
  carrier_raw(carrier_json(..., members = members), attrs = attrs)
}

# ---- documents of many cases -------------------------------------------------------------------------

# `blocks`: a list of character vectors (lines), each placed first, separated by blank lines. `cases`: a
# named character vector, one paragraph (or one small block) per case. Returns the markdown lines and the
# line number of the first line of each case.
fm_doc <- function(cases, blocks = list(), head = character()) {
  lines <- head
  add <- function(x) {
    first <- length(lines) + 1L
    x <- unlist(lapply(x, function(l) if (l == "") "" else strsplit(l, "\n", fixed = TRUE)[[1]]))
    lines <<- c(lines, x, "")
    first
  }
  if (!is.list(blocks)) blocks <- list(blocks)
  for (b in blocks) add(b)
  line <- integer()
  for (nm in names(cases)) line[[nm]] <- add(cases[[nm]])
  list(md = lines, line = line)
}

# Runs a document of cases through the filter (plain-text writer). The result has `got`: a named
# character vector of the output paragraphs by case name (NA when the output does not hold one paragraph
# per case), and `line`. draft = TRUE sets WEFT_DRAFT=1 so that the output is written when a case fails.
filter_cases <- function(cases, blocks = list(), draft = FALSE, to = "plain", head = character(),
                         env = character(), ...) {
  d <- fm_doc(cases, blocks, head)
  if (draft) env <- c(env, WEFT_DRAFT = "1")
  res <- filter_md(d$md, to = to, env = env, ...)
  paras <- if (nzchar(trimws(res$output))) strsplit(trimws(res$output), "\n\n", fixed = TRUE)[[1]] else character()
  paras <- trimws(paras)
  ok <- length(paras) == length(cases)
  testthat::expect(ok, sprintf(
    "the output holds one paragraph per case: %d paragraphs for %d cases (status %s; stderr: %s)",
    length(paras), length(cases), res$status, substr(gsub("\n", " / ", res$stderr), 1, 300)))
  res$got <- if (ok) stats::setNames(paras, names(cases)) else stats::setNames(rep(NA_character_, length(cases)), names(cases))
  res$line <- d$line
  res
}

# expected: a named character vector (names are case names). Each is compared with identical(); "{L}" in
# an expected text stands for the case's source line.
expect_cases <- function(res, expected) {
  for (nm in names(expected)) {
    want <- gsub("{L}", format(res$line[[nm]]), expected[[nm]], fixed = TRUE)
    testthat::expect_identical(unname(res$got[nm]), unname(want), label = paste("case", nm))
  }
}

# "A <span> z." for each case of a table list(name = c(span, text)); the expected "A <text> z."
tbl_cases <- function(tbl, pre = "A ", post = " z.") {
  list(cases = vapply(tbl, function(x) paste0(pre, x[[1]], post), ""),
       expected = vapply(tbl, function(x) paste0(pre, x[[2]], post), ""))
}

marker <- function(kind, line = NULL, chunk = NULL) {
  if (!is.null(line)) sprintf("<<weft: %s, line %d>>", kind, as.integer(line))
  else if (!is.null(chunk)) sprintf("<<weft: %s, chunk %s>>", kind, chunk)
  else sprintf("<<weft: %s>>", kind)
}

# ---- the report on stderr (N86) ----------------------------------------------------------------------

fm_lines <- function(stderr) strsplit(stderr, "\n", fixed = TRUE)[[1]]

# the lines that head a report section: "weft: ..."
fm_headings <- function(stderr) grep("^weft: ", fm_lines(stderr), value = TRUE)

# The entry whose first line matches `head_regex`: list(head, detail, found) where detail holds the
# following lines that start with six spaces (without them). When there is none: head and detail NA and
# found FALSE, so that the expectations on them fail cleanly.
fm_entry <- function(stderr, head_regex) {
  ls <- fm_lines(stderr)
  i <- grep(head_regex, ls)
  if (!length(i)) return(list(head = NA_character_, detail = NA_character_, found = FALSE))
  i <- i[1]
  j <- i
  while (j < length(ls) && startsWith(ls[j + 1L], "      ")) j <- j + 1L
  list(head = ls[i], detail = if (j > i) substring(ls[(i + 1L):j], 7L) else character(), found = TRUE)
}

# Pluralisation of the headings is left open by the design ("claim(s)", "failure(s)"): both forms read.
rx_claims <- function(n) sprintf("^weft: %d claim(s|\\(s\\))? failed$", n)
rx_failures <- function(n) sprintf("^weft: %d failure(s|\\(s\\))?$", n)
rx_warned <- function(n) sprintf("^weft: %d warned check(s|\\(s\\))?$", n)

# ---- the messages of section 7 -----------------------------------------------------------------------

fm_msg <- list(
  E1 = function(text) sprintf("`%s` is not a name, so it cannot carry a weft class: a named value holds one name. Bind the value to a name in code (rule 1.12.3).", text),
  E2 = function(c) sprintf("`.val` prints a value as it is and cannot take `.%s` (rule 1.12.2).", c),
  E3 = function(part) sprintf("`%s` is not a name or one comparison of names, numbers and 'strings'; bind the condition to a name in code (rule 1.12.4).", part),
  E3_tail = "is not a name or one comparison of names, numbers and 'strings'; bind the condition to a name in code (rule 1.12.4).",
  E4 = function(part) sprintf("`%s` compares two literals and has no name, so it is always the same (rule 1.12.4).", part),
  E5 = function(value, key) {
    extra <- switch(key, n = ", `.` or `#id`", sign = " or `#id`", list = "")
    sprintf("`%s` is not a name for `%s`; it takes a name%s (rule 1.12.6).", value, key, extra)
  },
  E7 = function(key, v) sprintf("`%s` must be a whole number, not negative (got `%s`).", key, v),
  E8 = function(key, v) sprintf("`%s` must be at most 100 (got `%s`).", key, v),
  E9 = function(key) sprintf("A named value takes no `%s`: a governor key belongs on a span (rule 1.3.3).", key),
  E10 = function(name) sprintf("no value is published under the name `%s` in this document (rule 1.12.7).", name),
  E10_hint = function(name) sprintf("Publish it in code above: weft_put(%s = ...) in R, put(%s=...) in Python, @put %s in Julia. A cell with include: false or output: false publishes nothing on the jupyter and julia engines.", name, name, name),
  E11 = function(name, why) sprintf("`%s` is missing (%s) (rule 1.3.4).", name, why),
  E12 = function(reason) sprintf("a weft-values block that does not read: %s (rule 2.13.1).", reason),
  E13 = function(n) sprintf("a weft-values block of %s bytes; the limit is 5000000 (rule 2.13.1).", format(n, scientific = FALSE)),
  E14 = function(check, val, why = NULL) sprintf("%s was false (value %s)%s", check, val, if (is.null(why)) "" else paste0("; ", why)),
  E17 = function(c, needs, name, kind) sprintf("`.%s` needs a %s; `%s` is a %s (rule 1.4.3).", c, needs, name, kind),
  E18 = function(name, kind) sprintf("a condition must be true or false, and `%s` is a %s (rule 1.11.8).", name, kind),
  E19 = function(part, k1, k2) sprintf("`%s` compares a %s with a %s (rule 1.12.5).", part, k1, k2),
  E19_order = function(part) sprintf("`%s` orders two strings; strings compare only with == and != (rule 1.12.5).", part),
  E20_class = function(c) sprintf("`.%s` on a named value is not available in this version of weft.lua (rule 2.13.3).", c),
  E20_key = function(key) sprintf("`%s=` on a named value is not available in this version of weft.lua (rule 2.13.3).", key),
  E21 = function(c) sprintf("`.%s` is a project formatter, which is an R function; a named value cannot use it (rule 2.13.3).", c),
  E35 = "a named value was not resolved: the filter weft.lua is not installed before weft-check.lua (rule 2.5.3)."
)
