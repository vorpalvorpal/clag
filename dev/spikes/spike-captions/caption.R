## Caption support layered on the stand-in runtime (setup.R is an unmodified copy of
## spike-grammar/setup.R except clag_text() honours clag$where for error locations).
source("setup.R")
clag$where <- NULL

## Park `r code` (raw text in an option string, never seen by knitr's inline machinery)
## exactly as the evaluate.inline hook would, then run the ordinary scanner.
clag_str <- function(x, opt = NULL) {
  lab <- tryCatch(knitr::opts_current$get("label"), error = function(e) NULL)
  clag$where <- paste0("chunk '", if (is.null(lab)) "?" else lab, "'", if (!is.null(opt)) paste0(", option ", opt))
  on.exit(clag$where <- NULL)
  one <- function(s) {
    s <- paste(s, collapse = "\n")
    m <- gregexpr("`r +[^`]+`", s)
    regmatches(s, m) <- lapply(regmatches(s, m), function(p) vapply(p, function(q) {
      clag$pend[[length(clag$pend) + 1L]] <- sub("^`r +(.*)`$", "\\1", q)
      paste0(clag$O, length(clag$pend), clag$C) }, ""))
    trimws(clag_text(s))
  }
  vapply(as.character(x), one, "", USE.NAMES = FALSE)
}

## Mechanism B: opts_hook turns the string into a call; knitr's eval.after machinery
## (eng_r) evaluates it AFTER the chunk, in the chunk environment.
clag_install_captions <- function(opts = c("fig.cap", "fig.alt", "fig.subcap", "fig.scap", "tbl-cap"),
                                  after = TRUE) {
  if (after) knitr::opts_knit$set(eval.after = union(knitr::opts_knit$get("eval.after"), opts))
  ## eng_r does options[o] <- list(NULL) for every eval.after name; for an option Quarto does not
  ## know (tbl-cap) that NULL is forwarded as tbl-cap="{}" on every cell. Strip it again.
  if (after) {
    orig <- knitr::knit_hooks$get("chunk")
    knitr::knit_hooks$set(chunk = function(x, options) {
      for (o in setdiff(opts, c("fig.cap", "fig.scap", "fig.alt"))) if (is.null(options[[o]])) options[[o]] <- NULL
      orig(x, options)
    })
  }
  for (o in opts) local({
    o <- o
    knitr::opts_hooks$set(setNames(list(function(options) {
      v <- options[[o]]
      if (is.character(v) && any(grepl("`r |\\[", v)))
        options[[o]] <- as.expression(as.call(list(clag_str, v, o)))
      options
    }), o))
  })
}

## Mechanism A (control): opts_hook resolves the string immediately (BEFORE the chunk runs).
clag_install_captions_early <- function(opts = c("fig.cap", "fig.alt", "fig.subcap", "fig.scap", "tbl-cap")) {
  for (o in opts) local({
    o <- o
    knitr::opts_hooks$set(setNames(list(function(options) {
      v <- options[[o]]
      if (is.character(v) && any(grepl("`r |\\[", v))) options[[o]] <- clag_str(v, o)
      options
    }), o))
  })
}

## Mechanism C (control): wrap the chunk output hook; resolve option strings after the chunk ran.
## The plot hook has already baked fig.cap into `x` by then.
clag_install_captions_chunkhook <- function(opts = c("fig.cap", "fig.alt", "fig.subcap", "tbl-cap")) {
  orig <- knitr::knit_hooks$get("chunk")
  knitr::knit_hooks$set(chunk = function(x, options) {
    for (o in opts) { v <- options[[o]]; if (is.character(v)) options[[o]] <- clag_str(v, o) }
    orig(x, options)
  })
}
