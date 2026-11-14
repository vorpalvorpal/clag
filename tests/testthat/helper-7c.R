# Helpers for the 7c tests (F3: tables in the ledger; dev/design-7.md section 2.C, N30 to N40).
# Names start t7c_. Made-up content only. ASCII only.
if (!exists("d2_render")) {
  p <- Filter(file.exists, c(testthat::test_path("helper-2d.R"), testthat::test_path("..", "helper-2d.R")))
  if (length(p)) source(p[[1]], local = globalenv())
}
d2_need()

# the digest N32 names: XXH3 as cli gives it, of the UTF-8 bytes of the text
t7c_hash <- function(x) cli::hash_raw_xxhash64(charToRaw(enc2utf8(x)))

# a chunk of a document: `label` NULL for an unlabelled chunk; `opts` the rest of the header;
# `yaml` lines go first in the body as `#|` options
t7c_chunk <- function(label, code, opts = "echo=FALSE", yaml = NULL) {
  hdr <- paste0("```{r", if (!is.null(label)) paste0(" ", label), if (nzchar(opts %||% "")) paste0(", ", opts), "}")
  c(hdr, if (length(yaml)) paste0("#| ", yaml), code, "```", "")
}

# the data of the fixtures: two sites, one depth each
T7C_DF <- "d <- data.frame(site = c('A', 'B'), depth = c(1.5, 2.5))"

# the table entries of a render's ledger (header dropped), in file order
t7c_tables <- function(res, ...) {
  Filter(function(e) identical(e$kind, "table"), d2_ledger(res, ...))
}

# a knit in a set-up project; the render must not fail
t7c_knit <- function(lines, ...) d2_render(lines, ...)

# a render of an .Rmd to an HTML fragment (so knitr sees an HTML output format), in a set-up project
t7c_html <- function(lines, dir = NULL, files = NULL) {
  skip_if_not(rmarkdown::pandoc_available(), "pandoc is not available")
  files <- c(D2_SETUP[!(names(D2_SETUP) %in% names(files))], files)
  d <- write_doc(lines, TRUE, NULL, NULL, files, "doc", "rmd", dir = dir)
  withr::local_dir(d$dir, .local_envir = parent.frame())
  withr::defer(weft_restore_knitr(), envir = parent.frame())
  err <- NULL
  tryCatch(
    rmarkdown::render(d$name, rmarkdown::html_fragment(), output_file = "doc.html", quiet = TRUE,
                      envir = new.env()),
    error = function(e) err <<- e)
  testthat::expect_null(err, label = "the HTML render's error")
  list(dir = d$dir, error = err, failed = !is.null(err))
}

# the text of the one table entry of a render, failing when there is not exactly one
t7c_digest <- function(res) {
  t <- t7c_tables(res)
  testthat::expect_length(t, 1L)
  if (length(t) != 1L) return(NA_character_)
  t[[1]]$text
}

# ---- a ledger fixture of tables, for changes() --------------------------------------------------

T7C_D1 <- "0123456789abcdef"
T7C_D2 <- "fedcba9876543210"

# a table entry as a ledger holds it (N31, N32)
t7c_entry <- function(label = "tbl-sites", text = T7C_D1, occ = 1L, caption = "Site table") {
  e2x_entry(expr = label, text = text, kind = "table", occ = occ,
            id = if (nzchar(label)) label else NA_character_, context = "chunk", sentence = caption)
}

# a project with a.qmd's ledger: `before` committed, `after` in the working tree; the printed lines
t7c_changes <- function(before, after, brief = FALSE, env = parent.frame()) {
  dir <- e2x_scenario(before, after, env = env)
  capture.output(print(weft::changes(path = dir), brief = brief))
}
