# Captions in chunk options (rules 1.10.1-1.10.4, 2.1.1 rows `opts_hooks` and
# `chunk`, 2.1.4, 2.3). The caption options are in knitr's `eval.after`
# list, and an option hook turns a caption string that contains a construct
# into a call, which knitr evaluates after the chunk's code has run, in the
# chunk's environment (2.3.1). The names knitr is handed: `fig.cap`,
# `fig.alt`, `fig.scap` and `fig.subcap` under both rmarkdown and Quarto
# (Quarto's `fig-cap`, `fig-alt` and `fig-subcap`), and `tbl-cap` under
# Quarto, which keeps the hyphen.

CAPTION_KNITR <- c("fig.cap", "fig.alt", "fig.scap", "fig.subcap", "tbl-cap")
# the options eng_r() would set to NULL on every chunk, that a chunk with no
# caption must not carry (2.1.1, `chunk`)
CAPTION_NULLABLE <- c("fig.subcap", "tbl-cap")

install_caption_hooks <- function() {
  knitr::opts_knit$set(eval.after = union(knitr::opts_knit$get("eval.after"), CAPTION_KNITR))
  for (o in CAPTION_KNITR) local({
    o <- o
    cur <- knitr::opts_hooks$get(o)
    if (is_weft_hook(cur)) return()
    new <- function(options) {
      if (is.function(cur)) options <- cur(options)
      caption_option_hook(options, o)
    }
    attr(new, "weft") <- TRUE
    knitr::opts_hooks$set(stats::setNames(list(new), o))
  })
  invisible()
}

# The `chunk` hook is wrapped late, from the first call of an option hook
# (2.1.4): it removes a NULL `tbl-cap` (and `fig.subcap`), which knitr's
# `eval.after` loop sets on every chunk and Quarto would forward to every cell.
install_chunk_wrapper <- function() {
  wrap_hook("chunk", function(prev) {
    function(x, options) {
      for (o in CAPTION_NULLABLE) {
        if (o %in% names(options) && is.null(options[[o]])) options[[o]] <- NULL
      }
      if (is.function(prev)) prev(x, options) else x
    }
  })
}

# TRUE when knitr will not evaluate the options of this chunk after it has run
# (a chunk that is not run, may be served from the cache, or is not R): its
# caption is left as it is, and a construct in it is a static error (2.3.5).
caption_not_resolved <- function(options) {
  isFALSE(options$eval) ||
    isTRUE(as.logical(options$cache)) ||
    (is.numeric(options$cache) && isTRUE(options$cache > 0)) ||
    !identical(tolower(as.character(options$engine %||% "r")[1L]), "r")
}

caption_option_hook <- function(options, o) {
  v <- options[[o]]
  if (is.null(v)) return(options)
  ensure_knit()
  install_chunk_wrapper()
  if (caption_not_resolved(options)) return(options)
  if (is.character(v)) {
    has <- any(vapply(v, function(e) !is.na(e) && nrow(scan_text(e)) > 0L, NA))
    if (!has) return(options)
  } else if (!is.language(v)) {
    return(options)
  }
  # a call: evaluated by knitr after the chunk, in the chunk's environment
  options[[o]] <- as.call(list(caption_resolver, v, o))
  options
}

# The name of an option as the author wrote it: Quarto's, when Quarto knits.
caption_option_name <- function(o) {
  p <- tryCatch(knit_input_path(), error = function(e) NULL)
  if (!is.null(p) && grepl("\\.rmarkdown$", p)) sub("^fig\\.", "fig-", o) else o
}

# Evaluated by knitr after the chunk: resolve the caption, as prose.
caption_resolver <- function(x, option) {
  env <- parent.frame()
  s <- active_state()
  if (is.null(s) || !is.character(x) || !length(x)) return(x)
  has <- vapply(x, function(e) !is.na(e) && nrow(scan_text(e)) > 0L, NA)
  if (!any(has)) return(x)
  label <- current_chunk_label()
  name <- caption_option_name(option)
  ctx <- list(chunk = label, option = name, envir = env, strict = FALSE, context = "caption")
  for (i in which(has)) x[i] <- resolve_string(s, x[i], ctx)
  note_caption_recorded(s, label, option)
  x
}

# What the end-of-document check expects of a caption (2.5.2): its constructs,
# found in the source, are done.
note_caption_recorded <- function(s, label, option) {
  F <- current_file_state(s)
  if (is.null(F) || is.null(F$captions) || !nrow(F$captions)) return(invisible())
  norm <- function(o) gsub("-", ".", o, fixed = TRUE)
  hit <- F$captions$chunk == label & norm(F$captions$option) == norm(option)
  if (any(hit)) F$recorded <- c(F$recorded, paste(F$captions$kind[hit], F$captions$line[hit]))
  invisible()
}
