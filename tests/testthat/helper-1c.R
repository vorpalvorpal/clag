# Helpers for the stage-1c tests (captions, weft_str(), front matter, the
# scanner's contexts, the trial bugs). They sit beside helper-render.R and
# helper-quarto.R and use write_doc(), weft_test_lib(), weft_restore_knitr()
# and skip_if_no_quarto() from them; nothing here edits those.
#
#   file_line()      the line of a document (as written to the file) that
#                    holds a fixed string
#   qmd_html()       a whole .qmd (lines include the YAML) through
#                    `quarto render` to HTML. Markdown output drops captions
#                    (Quarto emits a placeholder), HTML keeps them.
#   rmd_html()       a whole .Rmd through rmarkdown::render() to HTML, in this
#                    process; res$knit is weft:::last_knit()
#   html_text()      visible text of an HTML string, squished
#   html_captions()  the text of each <figcaption>
#   html_alts()      the alt="" attributes
#   no_uuid()        an HTML string with Quarto's per-render ids removed
#   expect_never_raw()  the invariant of "silence is impossible": a render
#                    either fails or has no raw construct in its output

file_line <- function(lines, pattern, nth = 1L) {
  w <- grep(pattern, lines, fixed = TRUE)
  stopifnot(length(w) >= nth)
  w[nth]
}

html_text <- function(html) {
  x <- gsub("(?s)<(script|style)[^>]*>.*?</\\1>", " ", html, perl = TRUE)
  x <- gsub("<[^>]*>", " ", x)
  x <- gsub("&nbsp;| ", " ", x)
  x <- gsub("&lt;", "<", x, fixed = TRUE)
  x <- gsub("&gt;", ">", x, fixed = TRUE)
  x <- gsub("&quot;", "\"", x, fixed = TRUE)
  x <- gsub("&amp;", "&", x, fixed = TRUE)
  gsub("[[:space:]]+", " ", trimws(x))
}

html_captions <- function(html) {
  m <- regmatches(html, gregexpr("(?s)<figcaption[^>]*>.*?</figcaption>", html, perl = TRUE))[[1]]
  vapply(m, html_text, "", USE.NAMES = FALSE)
}

html_alts <- function(html) {
  m <- regmatches(html, gregexpr("alt=\"[^\"]*\"", html))[[1]]
  trimws(gsub("[[:space:]]+", " ", sub("^alt=\"", "", sub("\"$", "", m))))
}

no_uuid <- function(html) {
  gsub("[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", "UUID", html)
}

read_html_file <- function(path) {
  if (!file.exists(path)) return("")
  paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

# `lines` is the whole file, YAML included. Returns failed, message, log,
# html, text (visible text), captions, alts, dir, file, offset (always 0).
qmd_html <- function(lines, env = NULL, files = NULL, name = "doc", dir = NULL) {
  skip_if_no_quarto()
  d <- write_doc(lines, FALSE, NULL, NULL, files, name, "qmd", dir = dir)
  lib <- weft_test_lib()
  env <- c(NO_COLOR = "1", env)
  if (nzchar(lib)) env <- c(R_LIBS = lib, env)
  old <- setwd(d$dir)
  on.exit(setwd(old), add = TRUE)
  log <- suppressWarnings(system2(
    Sys.which("quarto"), c("render", shQuote(d$name), "--to", "html"),
    stdout = TRUE, stderr = TRUE,
    env = sprintf("%s=%s", names(env), unname(env))
  ))
  status <- attr(log, "status")
  failed <- !is.null(status) && status != 0
  html <- read_html_file(file.path(d$dir, paste0(name, ".html")))
  list(failed = failed, log = paste(log, collapse = "\n"),
       message = if (failed) paste(log, collapse = "\n") else "",
       html = no_uuid(html), text = html_text(html),
       captions = html_captions(html), alts = html_alts(html),
       dir = d$dir, file = d$name, offset = 0L)
}

rmd_html <- function(lines, env = NULL, files = NULL, name = "doc", dir = NULL) {
  skip_if_not(rmarkdown::pandoc_available(), "pandoc is not available")
  d <- write_doc(lines, FALSE, NULL, NULL, files, name, "rmd", dir = dir)
  withr::local_envvar(if (is.null(env)) character() else env)
  withr::local_dir(d$dir)
  withr::defer(weft_restore_knitr())
  failed <- FALSE
  err <- NULL
  logv <- character()
  withCallingHandlers(
    tryCatch(
      rmarkdown::render(
        d$name,
        rmarkdown::html_document(self_contained = FALSE, theme = NULL,
                                 highlight = NULL, mathjax = NULL),
        output_file = paste0(name, ".html"), quiet = TRUE, envir = new.env()
      ),
      error = function(e) {
        failed <<- TRUE
        err <<- list(message = conditionMessage(e), class = class(e))
      }
    ),
    message = function(m) {
      logv <<- c(logv, conditionMessage(m)); invokeRestart("muffleMessage")
    },
    warning = function(w) {
      logv <<- c(logv, paste0("Warning: ", conditionMessage(w)))
      invokeRestart("muffleWarning")
    }
  )
  knit <- tryCatch(weft:::last_knit(), error = function(e) NULL)
  html <- read_html_file(file.path(d$dir, paste0(name, ".html")))
  list(failed = failed, error = err,
       message = if (is.null(err)) "" else err$message,
       log = logv, knit = knit, html = html, text = html_text(html),
       captions = html_captions(html), alts = html_alts(html),
       dir = d$dir, file = d$name, offset = 0L)
}

# the invariant of design-1c "Trial bugs" item 1: a construct left raw never
# passes silently. `raw` is a fixed string that only a raw construct holds.
expect_never_raw <- function(res, raw = "]{", label = "") {
  out <- paste(c(res$md, res$html, res$text), collapse = "\n")
  testthat::expect_true(
    isTRUE(res$failed) || !grepl(raw, out, fixed = TRUE),
    label = paste("a raw construct was printed with a zero exit", label)
  )
}

# the markers of 2.6.8 as Pandoc writes them in HTML text (already
# unescaped by html_text()); for a knit() text use unesc()
