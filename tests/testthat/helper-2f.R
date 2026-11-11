# Helpers for the 2f tests (unit names and unit settings). Contract: dev/design-2f.md.
# "~" in an expected string stands for U+00A0, the no-break space.

F2_MINUS <- "−"
F2_DEG <- "°"
F2_ENDASH <- "–"

f2 <- function(s) gsub("~", " ", s, fixed = TRUE)

# the text of a weft_text or character, attributes dropped (direct calls keep the raw U+00A0)
f2_tx <- function(x) as.character(unclass(x))

# a fresh project directory (an empty one when `yml` is NULL); removed when the test ends
f2_proj <- function(yml = NULL, env = parent.frame()) {
  root <- withr::local_tempdir(.local_envir = env)
  dir <- file.path(root, "proj")
  dir.create(dir)
  if (!is.null(yml)) writeLines(yml, file.path(dir, "_weft.yml"))
  dir
}

# undo Pandoc's backslash-space
f2_unesc <- function(x) gsub("\\ ", " ", x, fixed = TRUE)

# weft_str() run from inside a project (so _weft.yml is read), as plain text with U+00A0
f2_ws <- function(src, yml = NULL) {
  dir <- f2_proj(yml)
  f2_unesc(withr::with_dir(dir, weft_str(src)))
}

# the condition weft_str() raises, or NULL
f2_err <- function(src, yml = NULL) {
  dir <- f2_proj(yml)
  tryCatch({ withr::with_dir(dir, weft_str(src)); NULL }, error = function(e) e)
}

# the condition an expression raises, or NULL
f2_cond <- function(expr) tryCatch({ expr; NULL }, error = function(e) e)

f2_has_class <- function(e, class) {
  testthat::expect_false(is.null(e), label = "an error was raised")
  testthat::expect_true(inherits(e, class), label = paste("class", class))
  testthat::expect_true(inherits(e, "weft_error"), label = "class weft_error")
}

f2_msg <- function(e) if (is.null(e)) "" else conditionMessage(e)

# `fixed` pieces all occur in the message of `e`
f2_msg_has <- function(e, ...) {
  m <- f2_msg(e)
  for (p in c(...)) testthat::expect_true(grepl(p, m, fixed = TRUE),
                                          label = sprintf("message holds `%s` (message: %s)", p, m))
}

# several src -> want pairs through weft_str(), each labelled
f2_rows <- function(src, want, yml = NULL) {
  for (i in seq_along(src)) {
    testthat::expect_equal(f2_ws(src[[i]], yml), f2(want[[i]]), label = src[[i]])
  }
}

# a temp dictionary file from lines
f2_dict_file <- function(lines, env = parent.frame()) {
  p <- withr::local_tempfile(fileext = ".yml", .local_envir = env)
  writeLines(lines, p)
  p
}

# the dictionary that registers PSU, sites and CFU/100 mL, as the 2a fixture does
F2_REG_LINES <- c(
  "salinity_res: {value: 0.01, type: quantity, unit: PSU, definition: \"Logger resolution.\"}",
  "coliform_limit: {value: 150, type: quantity, unit: \"CFU/100 mL\", definition: \"Closing count.\"}",
  "site_density: {value: 4, type: quantity, unit: sites/ha, definition: \"Planned density.\"}"
)
f2_register <- function(env = parent.frame()) read_dict(f2_dict_file(F2_REG_LINES, env))

# one render in this process, draft mode so a failure is a marker; text is the knit output
f2_render <- function(lines, front = NULL, files = NULL, draft = TRUE, code = NULL) {
  render_rmd(lines, front = front, files = files, code = code, format = "knit",
             in_process = TRUE, env = if (draft) c(WEFT_DRAFT = "1") else c(WEFT_DRAFT = NA))
}

# the knit's collected failures as one string each
f2_failures <- function(res) {
  f <- res$knit$failures
  if (is.null(f) || !NROW(f)) return(character())
  vapply(seq_len(NROW(f)), function(i) paste(unlist(f[i, ]), collapse = " "), "")
}

# the output of case i of a batch rendered in knit format, markers split
f2_cases <- function(res, n) f2_unesc(split_cases(res, n))
