# Helpers for the stage 1e tests: arms() and rehearse() (rules 3.7.1-3.7.4).

# ---- small utilities -------------------------------------------------------

e1_write <- function(lines, name, dir = NULL, files = NULL) {
  if (is.null(dir)) dir <- tempfile("weft-1e-")
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  dir <- normalizePath(dir)
  path <- file.path(dir, name)
  writeLines(lines, path, useBytes = TRUE)
  for (f in names(files)) {
    p <- file.path(dir, f)
    dir.create(dirname(p), showWarnings = FALSE, recursive = TRUE)
    writeLines(files[[f]], p, useBytes = TRUE)
  }
  path
}

# the line of the one element that contains `pat` (fixed)
e1_line <- function(lines, pat) {
  w <- grep(pat, lines, fixed = TRUE)
  stopifnot(length(w) == 1L)
  w
}

# every file under a directory, dot files and empty directories included
e1_snapshot <- function(dir) {
  sort(list.files(dir, recursive = TRUE, all.files = TRUE, include.dirs = TRUE,
                  no.. = TRUE))
}

# make the development weft visible to the child R processes rehearse() starts
e1_libs <- function() {
  paste(c(weft_test_lib(), .libPaths()), collapse = .Platform$path.sep)
}
e1_with_libs <- function(code) {
  withr::with_envvar(c(R_LIBS = e1_libs()), code)
}

# the rows of a result for one span, picked by line and expression
e1_rows <- function(x, line, expr, context = NULL) {
  keep <- x$line == line & x$expr == expr
  if (!is.null(context)) keep <- keep & x$context == context
  x[keep, , drop = FALSE]
}
e1_span <- function(x, line, expr, context = NULL) {
  s <- unique(e1_rows(x, line, expr, context)$span)
  stopifnot(length(s) == 1L)
  s
}

# ---- the document for arms() ----------------------------------------------

E1_ARMS_LINES <- c(
  "---",
  "title: \"T\"",
  "abstract: |",
  "  Front [yes | no]{if=\"fm_flag\"} matter.",
  "---",
  "",
  "One [# item]{n=\"n1\"}.",
  "",
  "Two [a person | # people]{n=\"n2\"}.",
  "",
  "Three [no one | a person | # people]{n=\"n3\"}.",
  "",
  "Four [never | once | twice | # times]{n=\"n4\"}.",
  "",
  "Guard [All]{if=\"g1\"} models.",
  "",
  "Choice [met | not met]{if=\"stop('boom')\"}.",
  "",
  "Sign two [rose | fell]{sign=\"no_such_object\"}.",
  "",
  "Sign three [rose | fell | flat]{sign=\"file.create('SENTINEL.txt')\"}.",
  "",
  "Nested [p [q [r1 | r2]{if=\"c3\"} | s]{if=\"c2\"} | t]{n=\"c1\"}.",
  "",
  "Not spans `r xval`{.num} and [bold]{.strong} text.",
  "",
  "```{r capchunk}",
  "#| fig-cap: |",
  "#|   Cap [no plots | one plot | # plots]{n=\"cn\"}",
  "x <- weft_str(\"A [x | y]{if=\\\"wq\\\"} string\")",
  "y <- weft_str('[solo]{if=\"wq2\"}')",
  "z <- weft_str(paste0(\"[a | b]{if=\\\"nolit\\\"}\"))",
  "stop(\"this chunk must not run\")",
  "```",
  ""
)

# what arms() must list for the flat spans of E1_ARMS_LINES:
# pattern for the line, key, expr, context, roles, texts
E1_ARMS_SPEC <- list(
  list(at = "Front [yes", key = "if", expr = "fm_flag", context = "front-matter",
       role = c("true", "false"), text = c("yes", "no")),
  list(at = "One [#", key = "n", expr = "n1", context = "prose",
       role = "always", text = "# item"),
  list(at = "Two [a person", key = "n", expr = "n2", context = "prose",
       role = c("one", "other"), text = c("a person", "# people")),
  list(at = "Three [no one", key = "n", expr = "n3", context = "prose",
       role = c("zero", "one", "other"),
       text = c("no one", "a person", "# people")),
  list(at = "Four [never", key = "n", expr = "n4", context = "prose",
       role = c("zero", "one", "two", "other"),
       text = c("never", "once", "twice", "# times")),
  list(at = "Guard [All]", key = "if", expr = "g1", context = "prose",
       role = "always", text = "All"),
  list(at = "Choice [met", key = "if", expr = "stop('boom')", context = "prose",
       role = c("true", "false"), text = c("met", "not met")),
  list(at = "Sign two", key = "sign", expr = "no_such_object", context = "prose",
       role = c("positive", "negative"), text = c("rose", "fell")),
  list(at = "Sign three", key = "sign", expr = "file.create('SENTINEL.txt')",
       context = "prose", role = c("positive", "negative", "zero"),
       text = c("rose", "fell", "flat")),
  list(at = "Cap [no plots", key = "n", expr = "cn", context = "caption",
       role = c("zero", "one", "other"),
       text = c("no plots", "one plot", "# plots")),
  list(at = "A [x | y]", key = "if", expr = "wq", context = "weft_str",
       role = c("true", "false"), text = c("x", "y")),
  list(at = "'[solo]", key = "if", expr = "wq2", context = "weft_str",
       role = "always", text = "solo")
)
# the three nested spans add 6 arms; the flat ones add:
E1_ARMS_NROW <- sum(vapply(E1_ARMS_SPEC, function(s) length(s$role), 1L)) + 6L
E1_ARMS_NSPAN <- length(E1_ARMS_SPEC) + 3L

# ---- the documents for rehearse() -----------------------------------------

E1_MAIN_LINES <- c(
  "---",
  "title: \"t\"",
  "params:",
  "  count: 2",
  "  delta: 1.5",
  "  flag: true",
  "---",
  "",
  "```{r setup, include=FALSE}",
  "weft::weft_setup()",
  "```",
  "",
  "```{r data, include=FALSE}",
  "n <- params$count",
  "delta <- params$delta",
  "flag <- params$flag",
  "```",
  "",
  "Found [no sites | one site | # sites]{n=\"n\"}.",
  "",
  "The survey was [complete | partial]{if=\"flag\"}.",
  "",
  "Trend [up | down | flat]{sign=\"delta\"}.",
  "",
  "[Several [big | small]{if=\"flag\"} sites | A site]{if=\"n > 1\"}.",
  "",
  "[Positive | Odd [zz | yy]{if=\"TRUE\"}]{if=\"n >= 0\"}.",
  "",
  "```{r depth, echo=FALSE, fig.cap='Plot of [no plots | one plot | # plots]{n=\"n\"}'}",
  "plot(1)",
  "```",
  "",
  "Count `r claim(n, . > 0)`{.num} here.",
  ""
)

# the lines of the main fixture
E1_MAIN <- list(
  found    = e1_line(E1_MAIN_LINES, "Found ["),
  survey   = e1_line(E1_MAIN_LINES, "The survey"),
  trend    = e1_line(E1_MAIN_LINES, "Trend ["),
  several  = e1_line(E1_MAIN_LINES, "[Several"),
  odd      = e1_line(E1_MAIN_LINES, "[Positive"),
  cap      = e1_line(E1_MAIN_LINES, "fig.cap="),
  claim    = e1_line(E1_MAIN_LINES, "Count `r claim")
)

E1_MAIN_CASES <- list(
  usual  = list(count = 3),
  empty  = list(count = 0, delta = -2, flag = FALSE),
  single = list(count = 1, delta = 0)
)

# one rehearsal of the main fixture, shared by the tests that only read it
.e1_cache <- new.env()
e1_main <- function() {
  if (is.null(.e1_cache$main)) {
    path <- e1_write(E1_MAIN_LINES, "main.Rmd")
    res <- e1_with_libs(rehearse(path, E1_MAIN_CASES))
    .e1_cache$main <- list(path = path, dir = dirname(path), res = res,
                           arms = arms(path))
  }
  .e1_cache$main
}

# the (span, arm) of the main fixture, by name, from arms(file)
e1_main_spans <- function() {
  a <- e1_main()$arms
  L <- E1_MAIN
  list(
    found   = e1_span(a, L$found, "n"),
    survey  = e1_span(a, L$survey, "flag"),
    trend   = e1_span(a, L$trend, "delta"),
    several = e1_span(a, L$several, "n > 1"),
    big     = e1_span(a, L$several, "flag"),
    odd     = e1_span(a, L$odd, "n >= 0"),
    zz      = e1_span(a, L$odd, "TRUE"),
    cap     = e1_span(a, L$cap, "n")
  )
}

# what each case must have chosen: span name -> arm index
E1_MAIN_CHOSEN <- list(
  usual  = c(found = 3, survey = 1, trend = 1, several = 1, big = 1, odd = 1, cap = 3),
  empty  = c(found = 1, survey = 2, trend = 2, several = 2, odd = 1, cap = 1),
  single = c(found = 2, survey = 1, trend = 3, several = 2, odd = 1, cap = 2)
)

# a document whose chunk stops when params$boom is TRUE
E1_STOP_LINES <- c(
  "---",
  "title: \"t\"",
  "params:",
  "  boom: false",
  "---",
  "",
  "```{r setup, include=FALSE}",
  "weft::weft_setup()",
  "knitr::opts_chunk$set(error = FALSE)",
  "file.create('ran.txt')",
  "```",
  "",
  "Before [a | b]{if=\"TRUE\"} the chunk.",
  "",
  "```{r boom}",
  "if (params$boom) stop(\"kaboom\")",
  "```",
  "",
  "After [x | y]{if=\"TRUE\"} the chunk.",
  ""
)

# a document that would write a cache and a figure in an ordinary knit
E1_WRITE_LINES <- c(
  "---",
  "title: \"t\"",
  "params:",
  "  count: 2",
  "---",
  "",
  "```{r setup, include=FALSE}",
  "weft::weft_setup()",
  "```",
  "",
  "```{r slow, cache=TRUE}",
  "n <- params$count",
  "```",
  "",
  "```{r fig, echo=FALSE}",
  "plot(1)",
  "```",
  "",
  "Found [one site | # sites]{n=\"n\"}.",
  ""
)

# the same document with a quarto header and its engine
E1_QMD_LINES <- c(
  "---",
  "title: \"t\"",
  "engine: knitr",
  "params:",
  "  count: 2",
  "---",
  "",
  "```{r setup, include=FALSE}",
  "weft::weft_setup()",
  "x <- params$count",
  "```",
  "",
  "Found `{r} x`{.num} [a site | # sites]{n=\"x\"} in prose.",
  "",
  "```{r}",
  "#| label: fig-a",
  "#| fig-cap: |",
  "#|   Plot of [a site | # sites]{n=\"x\"}",
  "plot(1)",
  "```",
  ""
)
