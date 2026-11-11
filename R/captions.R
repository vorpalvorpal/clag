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

# Why knitr will not evaluate the options of this chunk after it has run (a
# chunk that is not run, may be served from the cache, or is not R): the
# caption is left as it is, and a construct in it is a static error (2.3.5).
# A character vector of reasons, empty when the caption is resolved.
not_resolved_why <- function(cache, eval_off, engine) {
  why <- character()
  if (isTRUE(cache)) {
    why <- c(why, "has `cache: true`, so its caption is not resolved again when it is served from the cache")
  }
  if (isTRUE(eval_off)) why <- c(why, "has `eval: false`, so its code does not run")
  if (!identical(tolower(as.character(engine %||% "r")[1L]), "r")) {
    why <- c(why, sprintf("uses the `%s` engine, not R", engine))
  }
  why
}

caption_not_resolved <- function(options) {
  cache <- options$cache
  cache_on <- (is.logical(cache) && isTRUE(cache)) ||
    (is.numeric(cache) && isTRUE(cache > 0)) ||
    (is.character(cache) && truthy(cache))
  not_resolved_why(cache_on, isFALSE(options$eval), options$engine)
}

# The kinds of the constructs in the elements of a caption (bare inline R and
# links are not constructs: bare R in a caption stays literal, 1.1.8).
caption_construct_kinds <- function(v) {
  out <- character()
  for (e in v) {
    if (is.na(e)) next
    r <- scan_text(e)
    if (nrow(r)) out <- c(out, r$kind[is.na(r$parent) & !(r$kind %in% c("bare", "link"))])
  }
  out
}

caption_option_hook <- function(options, o) {
  v <- options[[o]]
  if (is.null(v)) return(options)
  ensure_knit()
  install_chunk_wrapper()
  # a caption that R computes (a call, a name, `!expr`) is data (2.2.4): knitr
  # evaluates it after the chunk as it does without weft, and it goes through
  # `weft_str()` when it holds markup. Only a literal string is resolved.
  if (!is.character(v)) return(options)
  kinds <- caption_construct_kinds(v)
  if (!length(kinds)) return(options)
  why <- caption_not_resolved(options)
  if (length(why)) {
    caption_unresolvable(options, o, kinds[1L], why)
    return(options)
  }
  # a call: evaluated by knitr after the chunk, in the chunk's environment
  options[[o]] <- as.call(list(caption_resolver, v, o))
  options
}

# A construct in a caption that cannot be resolved, found when the chunk's
# options are read (2.3.5): a construct error with the remedy. A caption the
# scan of the source has already reported is not reported twice.
caption_unresolvable <- function(options, o, kind, why) {
  s <- ensure_knit()
  label <- options$label %||% NA_character_
  F <- current_file_state(s)
  src_label <- source_chunk_label(F, label)
  name <- caption_option_name(o)
  if (!is.null(F) && !is.null(F$static) && nrow(F$static)) {
    norm <- function(x) gsub("-", ".", x, fixed = TRUE)
    if (any(F$static$context == "caption" & F$static$chunk %in% c(label, src_label) &
            norm(F$static$option) == norm(name))) return(invisible())
  }
  msg <- sprintf("A `%s` construct in a caption of chunk `%s`, which %s: %s.",
                 kind, label, paste(why, collapse = " and "), DIV_REMEDY)
  file <- current_file_name(s)
  if (isTRUE(s$config$draft)) {
    add_failure(s, "construct error", file = file, chunk = label,
                expr = sprintf("a `%s` construct", kind), detail = msg, option = name)
    return(invisible())
  }
  weft_abort(sprintf("weft: %s chunk %s, %s: %s", file, label, name, msg),
             c("weft_construct_error", "weft_located"))
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
  has <- vapply(x, function(e) !is.na(e) && length(caption_construct_kinds(e)) > 0L, NA)
  if (!any(has)) return(x)
  label <- current_chunk_label()
  name <- caption_option_name(option)
  ctx <- list(chunk = label, file = current_file_name(s), option = name, envir = env, strict = FALSE, context = "caption")
  for (i in which(has)) x[i] <- resolve_string(s, x[i], ctx)
  note_caption_recorded(s, label, option)
  x
}

# What the end-of-document check expects of a caption (2.5.2): its constructs,
# found in the source, are done.
note_caption_recorded <- function(s, label, option) {
  F <- current_file_state(s)
  if (is.null(F) || is.null(F$captions) || !nrow(F$captions)) return(invisible())
  label <- source_chunk_label(F, label)
  norm <- function(o) gsub("-", ".", o, fixed = TRUE)
  hit <- F$captions$chunk == label & norm(F$captions$option) == norm(option)
  if (any(hit)) F$recorded <- c(F$recorded, paste(F$captions$kind[hit], F$captions$line[hit]))
  invisible()
}
