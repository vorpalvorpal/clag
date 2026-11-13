# Helpers for the stage 7a tests (dev/design-7.md, F1 and F2): test-plus.R,
# test-ci-forms.R and test-p-digits.R. Nothing here edits another helper.

P7_MINUS <- "\u2212"   # the minus glyph the package prints (the `minus` default)

# a weft_text or phrase as a plain character vector
p7_txt <- function(x) as.character(unclass(x))

# run `expr` under the package configuration modified by `cfg` (a list)
p7_with_cfg <- function(cfg, expr) {
  env <- weft:::weft_env
  old <- env$config
  on.exit(env$config <- old)
  env$config <- utils::modifyList(weft:::current_config(), cfg)
  force(expr)
}

# what the R side prints for a construct: classes and keys as the scanner
# would hand them to apply_formatters(); zero warnings are muffled
p7_app <- function(value, classes, keys = list(), cfg = list()) {
  p7_with_cfg(cfg, suppressWarnings(
    p7_txt(weft:::apply_formatters(value, classes, keys))))
}

# the full record of a construct's printed value
p7_rec <- function(value, classes, keys = list(), cfg = list()) {
  p7_with_cfg(cfg, suppressWarnings({
    x <- weft:::apply_formatters(value, classes, keys)
    list(text = p7_txt(x), number = attr(x, "number"),
         decimals = attr(x, "decimals"), relation = attr(x, "relation"))
  }))
}

# the weft_zero_warning conditions raised by `expr`
p7_zero_warnings <- function(expr) {
  ws <- list()
  value <- withCallingHandlers(expr, warning = function(w) {
    ws[[length(ws) + 1L]] <<- w
    invokeRestart("muffleWarning")
  })
  list(value = value,
       zero = Filter(function(w) inherits(w, "weft_zero_warning"), ws))
}

# the construct errors the scanner finds in a source text
p7_scan_errs <- function(text) {
  r <- weft:::scan_text(text, config = weft:::current_config())
  as.character(r$error[!is.na(r$error)])
}

# knit one document in process under a `_weft.yml` that holds `yml` (lines
# are added to `draft: false`); returns the output lines and the run
p7_knit <- function(lines, yml = character(), may_fail = FALSE) {
  res <- d2_run(lines, files = list("_weft.yml" = c("draft: false", yml)),
                may_fail = may_fail)
  out <- file.path(res$dir, "doc.md")
  res$text <- if (file.exists(out)) {
    x <- readLines(out, warn = FALSE, encoding = "UTF-8")
    # knitr::knit() keeps the YAML header that write_doc() puts on top: drop it
    if (length(x) && identical(x[1L], "---") && sum(x == "---") >= 2L) x <- x[-seq_len(which(x == "---")[2L])]
    x[nzchar(trimws(x))]
  } else {
    character()
  }
  res
}

# the message of an error from `expr`, or "" when none
p7_err_msg <- function(expr) {
  tryCatch({ expr; "" }, error = function(e) conditionMessage(e))
}

# g2_cfg() reads a configuration but only the knit hook installs one, so a
# direct call of a formatter would never see the settings. p7_cfg() installs
# what it read for the calling test and puts the earlier one back at its end.
p7_cfg <- function(yml = NULL, front = list(), env = parent.frame()) {
  cfg <- g2_cfg(yml, front = front, env = env)
  we <- weft:::weft_env
  old <- we$config
  we$config <- cfg
  withr::defer(we$config <- old, envir = env)
  invisible(cfg)
}
