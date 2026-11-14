# Package 6f: the remaining classes in the resolver filter (dev/design-6.md N100, section 5). ASCII only.
#
# Builds on helper-filter.R (filter_md(), carrier(), fr_*(), fm_msg, fm_headings(), rx_claims()).
#
# HELPERS
#   CONF_6F                  the six sets 6f adds to the conformance tables (N131).
#   f6_read(set)             a committed set as a data frame of character columns.
#   f6_keys(keys)            a `keys` cell as list(opts, cfg, span): the renderer keys (name -> text,
#                            spaces decoded from %20), the settings of `_weft.yml` (cfg.NAME=VALUE) and the
#                            prose before the attribute block of a governor row (span=TEXT).
#   f6_rows(d)               every row of a set through the filter, one Pandoc run per distinct setting
#                            of `_weft.yml`, and the expected text of every row through a second run of the
#                            same document with no filter (the text of a row is markdown, rule 1.4.10, and
#                            Pandoc reads it): list(got, want, status, stderr), got and want in HTML.
#   f6_expect_rows(d, r, what)  one expectation per row, naming it.
#   f6_cases_html(cases, blocks, ...)  a document of cases through the filter with the HTML writer: each
#                            case is a div, so a case may hold several blocks. `got` is by case name.
#   f6_want_html(cases)      the same cases through Pandoc with no filter: the HTML of what R would print,
#                            as markdown.
#   f6_with_cfg(cfg, expr)   run R code under a configuration (the R formatters are the oracle).
#
# THE ROWS OF THE TABLES, AS A DOCUMENT
# Row i is named `v<i>`; its record is the `record` column; the case is the paragraph "A <construct> z."
# where the construct is, for a row with no governor, `v<i>`{.CLASS ... key="value"} (a code span, 1.12.1),
# and for a governor row the `span` key's prose followed by {.CLASS ... GOV="v<i>" key="value"}. The old
# `n` rows of words.tsv (keys singular= and plural=) are the span [# singular | # plural]{n="v<i>"}.

CONF_6F <- c("dates", "sci", "p", "collapse", "text", "governors")

f6_read <- function(set) {
  p <- test_path("_conformance", paste0(set, ".tsv"))
  testthat::expect(file.exists(p), paste("the committed set is missing:", p))
  if (!file.exists(p)) return(data.frame(value = character(), classes = character(), keys = character(),
                                         text = character(), record = character()))
  utils::read.delim(p, header = TRUE, sep = "\t", quote = "", comment.char = "", colClasses = "character",
                    na.strings = character(), check.names = FALSE, stringsAsFactors = FALSE,
                    encoding = "UTF-8", fileEncoding = "UTF-8", blank.lines.skip = FALSE)
}

f6_unesc <- function(x) gsub("%25", "%", gsub("%20", " ", x, fixed = TRUE), fixed = TRUE)

f6_keys <- function(keys) {
  out <- list(opts = list(), cfg = list(), span = NULL)
  if (!nzchar(keys)) return(out)
  for (p in strsplit(keys, " ", fixed = TRUE)[[1]]) {
    k <- sub("=.*$", "", p)
    v <- f6_unesc(sub("^[^=]*=", "", p))
    if (k == "span") out$span <- v
    else if (startsWith(k, "cfg.")) out$cfg[[substring(k, 5L)]] <- v
    else out$opts[[k]] <- v
  }
  out
}

# the markdown of the construct of a row, and the settings it needs
f6_construct <- function(classes, keys, name) {
  k <- f6_keys(keys)
  toks <- strsplit(classes, " ", fixed = TRUE)[[1]]
  gov <- intersect(toks, c("n", "sign", "list"))
  fcl <- setdiff(toks, gov)
  span <- k$span
  if (!is.null(k$opts$singular)) {
    span <- sprintf("[# %s | # %s]", k$opts$singular, k$opts$plural)
    k$opts$singular <- NULL
    k$opts$plural <- NULL
  }
  attrs <- c(if (length(fcl)) paste0(".", fcl), if (length(gov)) sprintf("%s=\"%s\"", gov, name),
             vapply(names(k$opts), function(nm) sprintf("%s=\"%s\"", nm, k$opts[[nm]]), ""))
  if (length(gov)) paste0(span, "{", paste(attrs, collapse = " "), "}")
  else paste0("`", name, "`{", paste(attrs, collapse = " "), "}")
}

f6_div_doc <- function(ids, bodies, head = character(), blocks = list()) {
  lines <- head
  for (b in blocks) lines <- c(lines, b, "")
  for (i in seq_along(ids)) {
    lines <- c(lines, sprintf("::: {#case-%s}", ids[i]), unlist(strsplit(bodies[i], "\n", fixed = TRUE)),
               ":::", "")
  }
  lines
}

f6_extract <- function(html, ids) {
  vapply(ids, function(id) {
    m <- regexec(sprintf("(?s)<div id=\"case-%s\">\n(.*?)\n</div>", id), html, perl = TRUE)
    g <- regmatches(html, m)[[1]]
    if (length(g) == 2L) g[2] else NA_character_
  }, "", USE.NAMES = FALSE)
}

# cases: a named character vector of markdown bodies. Returns the filter's result with `got` (HTML by case).
f6_cases_html <- function(cases, blocks = list(), head = character(), draft = TRUE, env = character(),
                          filters = c("weft.lua", "weft-check.lua"), ...) {
  ids <- sprintf("c%d", seq_along(cases))
  md <- f6_div_doc(ids, unname(cases), head, blocks)
  if (draft) env <- c(env, WEFT_DRAFT = "1")
  res <- filter_md(md, to = "html", env = env, filters = filters, ...)
  res$got <- stats::setNames(f6_extract(res$output, ids), names(cases))
  res
}

f6_want_html <- function(cases, head = character()) {
  res <- f6_cases_html(cases, head = head, draft = FALSE, filters = character())
  testthat::expect_identical(res$status, 0L, label = "Pandoc reads the expected texts")
  res$got
}

f6_rows <- function(d, head = character()) {
  n <- nrow(d)
  kk <- lapply(d$keys, f6_keys)
  cfgs <- vapply(kk, function(k) {
    # an empty value is written quoted: a bare `key:` is YAML's null, not the empty string
    v <- unlist(k$cfg)
    paste(sprintf("%s: %s", names(k$cfg), ifelse(nzchar(v), v, "\"\"")), collapse = "\n")
  }, "")
  nm <- sprintf("v%d", seq_len(n))
  got <- rep(NA_character_, n)
  status <- integer()
  stderr <- character()
  for (cf in unique(cfgs)) {
    idx <- which(cfgs == cf)
    block <- do.call(carrier, stats::setNames(as.list(d$record[idx]), nm[idx]))
    cases <- vapply(idx, function(i) paste0("A ", f6_construct(d$classes[i], d$keys[i], nm[i]), " z."), "")
    names(cases) <- nm[idx]
    res <- f6_cases_html(cases, list(block), head = head, weft_yml = if (nzchar(cf)) strsplit(cf, "\n")[[1]])
    got[idx] <- res$got
    status <- c(status, res$status)
    stderr <- c(stderr, res$stderr)
  }
  wcases <- stats::setNames(paste0("A ", d$text, " z."), nm)
  want <- f6_want_html(wcases, head = head)
  list(got = got, want = unname(want), status = status, stderr = stderr)
}

f6_expect_rows <- function(d, r, what) {
  testthat::expect_true(nrow(d) > 0L, label = paste(what, "has rows"))
  testthat::expect_false(any(grepl("not available in this version of weft.lua", r$stderr, fixed = TRUE)),
                         label = paste(what, ": no E20 in the report"))
  for (i in seq_len(nrow(d))) {
    ok <- !is.na(r$got[i]) && identical(r$got[i], r$want[i])
    testthat::expect(ok, sprintf("%s row %d (%s | %s | %s): got <%s>, want <%s>", what, i + 1L, d$value[i],
                                 d$classes[i], d$keys[i], r$got[i], r$want[i]))
  }
}

f6_with_cfg <- function(cfg, expr) {
  env <- weft:::weft_env
  old <- env$config
  on.exit(env$config <- old)
  env$config <- utils::modifyList(weft:::current_config(), cfg)
  expr
}

# what R prints, as one string, for an apply_formatters() call (the R side of a construct)
f6_r_text <- function(value, classes, keys = list(), cfg = list()) {
  f6_with_cfg(cfg, paste(suppressWarnings(as.character(unclass(
    weft:::apply_formatters(value, classes, keys)))), collapse = ", "))
}
