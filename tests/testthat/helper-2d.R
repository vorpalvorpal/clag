# Helpers for the 2d tests (the ledger and the condition log). Contract: dev/design-2d.md.
# Non-ASCII is written as \uXXXX. The six characters of an escape are written "\\u00a0" (a
# backslash, "u00a0"); a literal U+00A0 is "\u00a0". Made-up content only.

# Source a helper that lives in tests/testthat/ when its function is not defined yet.
d2_need <- function() {
  need <- c(render_rmd = "helper-render.R", tree = "helper-quarto.R", e1_write = "helper-1e.R")
  for (i in seq_along(need)) {
    if (!exists(names(need)[i])) {
      p <- Filter(file.exists, c(testthat::test_path(need[[i]]), testthat::test_path("..", need[[i]])))
      if (length(p)) source(p[[1]], local = globalenv())
    }
  }
}
d2_need()

.d2 <- new.env()

# compute once per session (the renders are slow); the value is a list
d2_memo <- function(key, f) {
  if (is.null(.d2[[key]])) .d2[[key]] <- f()
  .d2[[key]]
}

D2_SETUP <- list("_weft.yml" = "draft: false")

# one document knitted in this process (format "knit" by default), in a set-up project unless
# `set_up = FALSE`; the same arguments as render_rmd()
d2_render <- function(lines, set_up = TRUE, files = NULL, env = NULL, format = "knit", may_fail = FALSE, ...) {
  if (set_up) files <- c(D2_SETUP[!(names(D2_SETUP) %in% names(files))], files)
  res <- render_rmd(lines, files = files, env = env, format = format, in_process = TRUE, ...)
  if (!may_fail) testthat::expect_false(res$failed, label = paste("the render failed:", res$message))
  res
}

# the ledger and condition-log paths of a render
d2_path <- function(dir, source = "doc.Rmd", output = "doc", conditions = FALSE) {
  file.path(dir, "_weft", "ledger", source,
            paste0(output, if (conditions) ".conditions.jsonl" else ".jsonl"))
}

# the raw bytes of a file
d2_bytes <- function(p) {
  testthat::expect_true(file.exists(p), label = paste("file exists:", p))
  if (!file.exists(p)) stop("missing file ", p, call. = FALSE)
  readBin(p, "raw", file.size(p))
}

# the lines of a file as UTF-8 strings, split on "\n" only
d2_lines <- function(p) {
  b <- d2_bytes(p)
  if (!length(b)) return(character())
  s <- rawToChar(b)
  Encoding(s) <- "UTF-8"
  x <- strsplit(s, "\n", fixed = TRUE)[[1]]
  x
}

# a line as a list (JSON object), numbers as numbers, null as NULL
d2_json <- function(line) jsonlite::fromJSON(line, simplifyVector = FALSE)

# the entries of a ledger file (header dropped), each a list
d2_entries <- function(p) lapply(d2_lines(p)[-1], d2_json)
d2_header <- function(p) d2_json(d2_lines(p)[1])

# the entries whose fields match `...` (compared with identical on the field's value)
d2_pick <- function(entries, ...) {
  want <- list(...)
  Filter(function(e) all(vapply(names(want), function(n) identical(e[[n]], want[[n]]), NA)), entries)
}

# the one entry that matches `...`; fails with a message when there is not exactly one
d2_one <- function(entries, ...) {
  hit <- d2_pick(entries, ...)
  testthat::expect_length(hit, 1L)
  if (length(hit) != 1L) stop("no unique entry for ", paste(names(list(...)), list(...), sep = "=", collapse = ", "), call. = FALSE)
  hit[[1]]
}

# the entries of a render's own ledger
d2_ledger <- function(res, ...) d2_entries(d2_path(res$dir, ...))

# the lines of a render's condition log, as lists, header dropped
d2_conds <- function(res, ...) d2_entries(d2_path(res$dir, ..., conditions = TRUE))

# a knit in this process that keeps the classed conditions (warnings and messages) it raised
d2_run <- function(lines, set_up = TRUE, files = NULL, env = NULL, format = "knit", dir = NULL,
                   code = NULL, front = NULL, name = "doc", setup = TRUE, may_fail = FALSE) {
  if (format == "md") skip_if_not(rmarkdown::pandoc_available(), "pandoc is not available")
  if (set_up) files <- c(D2_SETUP[!(names(D2_SETUP) %in% names(files))], files)
  d <- write_doc(lines, setup, code, front, files, name, "rmd", dir = dir)
  withr::local_envvar(if (is.null(env)) character() else env)
  withr::local_dir(d$dir)
  withr::defer(weft_restore_knitr())
  conds <- list()
  err <- NULL
  withCallingHandlers(
    tryCatch({
      if (format == "knit") {
        knitr::knit(d$name, paste0(name, ".md"), quiet = TRUE, envir = new.env())
      } else {
        f <- rmarkdown::md_document(variant = "markdown", pandoc_args = "--wrap=none")
        f$knitr$opts_chunk$echo <- FALSE
        rmarkdown::render(d$name, f, output_file = paste0(name, ".md"), quiet = TRUE, envir = new.env())
      }
    }, error = function(e) err <<- e),
    warning = function(w) { conds[[length(conds) + 1L]] <<- w; invokeRestart("muffleWarning") },
    message = function(m) { conds[[length(conds) + 1L]] <<- m; invokeRestart("muffleMessage") }
  )
  if (!may_fail) testthat::expect_null(err, label = "the render's error")
  list(dir = d$dir, error = err, failed = !is.null(err), conds = conds,
       knit = tryCatch(weft:::last_knit(), error = function(e) NULL))
}

# the conditions of a run of one class
d2_of_class <- function(res, class) Filter(function(c) inherits(c, class), res$conds)
d2_msgs <- function(conds) vapply(conds, conditionMessage, "")

# a render to a named output, through rmarkdown (so output_file is in the render frame)
d2_render_to <- function(dir, input, output_file, params = NULL, env = NULL) {
  skip_if_not(rmarkdown::pandoc_available(), "pandoc is not available")
  withr::local_envvar(if (is.null(env)) character() else env)
  withr::local_dir(dir)
  withr::defer(weft_restore_knitr())
  f <- rmarkdown::md_document(variant = "markdown", pandoc_args = "--wrap=none")
  f$knitr$opts_chunk$echo <- FALSE
  err <- NULL
  withCallingHandlers(
    tryCatch(rmarkdown::render(input, f, output_file = output_file, params = params, quiet = TRUE,
                               envir = new.env()),
             error = function(e) err <<- e),
    warning = function(w) invokeRestart("muffleWarning"),
    message = function(m) invokeRestart("muffleMessage"))
  list(error = err, knit = tryCatch(weft:::last_knit(), error = function(e) NULL))
}

# a temporary git repository: `dir` initialised, with a local identity only
d2_git <- function(dir, ...) {
  system2("git", c("-C", shQuote(dir), ...), stdout = TRUE, stderr = TRUE)
}
d2_git_init <- function(dir) {
  d2_git(dir, "init", "-q")
  d2_git(dir, "config", "user.name", "Test Writer")
  d2_git(dir, "config", "user.email", "test@example.invalid")
  d2_git(dir, "config", "commit.gpgsign", "false")
  invisible(dir)
}
d2_git_commit <- function(dir, msg = "snapshot") {
  d2_git(dir, "add", ".")
  d2_git(dir, "commit", "-q", "-m", shQuote(msg))
  invisible(dir)
}

# the example of dev/design-2d.md, with the file name of the test document
D2_VARS <- c("n_sites <- 14", "n_dry <- 3", "ratio <- 0.823457", "len <- u(1500, m)")
D2_EXAMPLE_BODY <- c(
  "Of the `r n_sites` sites, [# was | # were]{n=\"n_dry\"} dry.",
  "",
  "## Water quality {#quality}",
  "",
  "The mean ratio was `r ratio`{#ratio .num digits=\"2\"}[, below the limit]{if=\"ratio < dict$limit\"}.",
  "Reach length was `r len`{unit=\"m|km\"}."
)
D2_DICT <- c("limit: {value: 0.9, type: number, definition: \"The limit.\"}")

d2_example_lines <- function(file = "doc.Rmd", nbsp = "\\u00a0") {
  c(
    sprintf("{\"weft\":\"ledger\",\"version\":1,\"source\":\"%s\",\"output\":\"%s\"}", file,
            sub("\\.[A-Za-z]+$", "", basename(file))),
    sprintf("{\"file\":\"%s\",\"section\":\"\",\"kind\":\"bare\",\"expr\":\"n_sites\",\"occ\":1,\"id\":null,\"context\":\"prose\",\"text\":\"14\",\"arm\":null,\"rel\":null,\"raw\":14,\"unit\":null,\"failed\":null,\"dict\":[],\"sentence\":\"Of the 14 sites, 3 were dry.\"}", file),
    sprintf("{\"file\":\"%s\",\"section\":\"\",\"kind\":\"n\",\"expr\":\"n_dry\",\"occ\":1,\"id\":null,\"context\":\"prose\",\"text\":\"3 were\",\"arm\":\"other\",\"rel\":\"=\",\"raw\":3,\"unit\":null,\"failed\":null,\"dict\":[],\"sentence\":\"Of the 14 sites, 3 were dry.\"}", file),
    sprintf("{\"file\":\"%s\",\"section\":\"quality\",\"kind\":\"if\",\"expr\":\"ratio < dict$limit\",\"occ\":1,\"id\":null,\"context\":\"prose\",\"text\":\", below the limit\",\"arm\":\"always\",\"rel\":null,\"raw\":null,\"unit\":null,\"failed\":null,\"dict\":[\"dict$limit\"],\"sentence\":\"The mean ratio was 0.82, below the limit.\"}", file),
    sprintf("{\"file\":\"%s\",\"section\":\"quality\",\"kind\":\"value\",\"expr\":\"len\",\"occ\":1,\"id\":null,\"context\":\"prose\",\"text\":\"1.5%skm\",\"arm\":null,\"rel\":\"=\",\"raw\":1500,\"unit\":\"m\",\"failed\":null,\"dict\":[],\"sentence\":\"Reach length was 1.5%skm.\"}", file, nbsp, nbsp),
    sprintf("{\"file\":\"%s\",\"section\":\"quality\",\"kind\":\"value\",\"expr\":\"ratio\",\"occ\":1,\"id\":\"ratio\",\"context\":\"prose\",\"text\":\"0.82\",\"arm\":null,\"rel\":\"=\",\"raw\":0.823457,\"unit\":null,\"failed\":null,\"dict\":[],\"sentence\":\"The mean ratio was 0.82, below the limit.\"}", file)
  )
}
