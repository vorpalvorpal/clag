# Helpers for the stage 7h tests (dev/design-7.md, F8: the range dictionary type):
# test-dict-range.R. Nothing here edits another helper. Made-up content only.

# the dictionary lines of one range entry (key `band`)
r7h_band <- function(value = "[6.5, 8.5]", unit = NULL, display = NULL, extra = character(), key = "band") {
  sprintf("%s: {value: %s, type: range%s%s, definition: \"An acceptable band.\"%s}", key, value,
          if (!is.null(unit)) paste0(", unit: ", unit) else "",
          if (!is.null(display)) paste0(", display: ", display) else "",
          if (length(extra)) paste0(", ", paste(extra, collapse = ", ")) else "")
}

# a dictionary read from lines in a temp file
r7h_read <- function(lines, env = parent.frame()) read_dict(a2_file(lines, env))

# the error a read raises, with the path of the file it read
r7h_err <- function(lines, env = parent.frame()) {
  p <- a2_file(lines, env)
  list(path = p, error = a2_err(read_dict(p)))
}

# printed text with the non-breaking space made a plain one, so that a test does not depend on which
# space the package puts between a number and its unit
r7h_nb <- function(x) gsub(" ", " ", as.character(unclass(x)), fixed = TRUE)

# knit a document (in process) in a project whose dict.yml holds `dict_lines`; `code` runs in the
# setup chunk. The text of the output is the result's `text`.
r7h_knit <- function(body, dict_lines, code = NULL) {
  res <- render_rmd(body, code = code, files = list("dict.yml" = dict_lines), in_process = TRUE, format = "knit")
  testthat::expect_false(res$failed, label = paste("the knit failed:", res$message))
  res$all <- r7h_nb(paste(res$text, collapse = "\n"))
  res
}
