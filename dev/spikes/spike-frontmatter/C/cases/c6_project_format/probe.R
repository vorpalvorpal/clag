## probe(tag): record what the R session can see about the document's metadata
probe <- function(tag) {
  out <- Sys.getenv("PROBE_OUT", getwd())
  m <- tryCatch(rmarkdown::metadata, error = function(e) paste("ERR", conditionMessage(e)))
  env <- Sys.getenv(); qe <- env[grep("^QUARTO|^RSTUDIO_PANDOC|^RMARKDOWN|^R_QUARTO", names(env))]
  inp <- tryCatch(knitr::current_input(dir = TRUE), error = function(e) NA_character_)
  yfm <- tryCatch(rmarkdown::yaml_front_matter(inp), error = function(e) paste("ERR", conditionMessage(e)))
  qdoc <- if (nzchar(Sys.getenv("QUARTO_DOCUMENT_FILE"))) file.path(Sys.getenv("QUARTO_DOCUMENT_PATH"), Sys.getenv("QUARTO_DOCUMENT_FILE")) else inp
  t0 <- Sys.time()
  qi <- tryCatch({ i <- quarto::quarto_inspect(qdoc); list(names = names(i), project = i$config$project, bib = i$config$bibliography %||% i$formats[[1]]$metadata$bibliography,
                  lang = i$formats[[1]]$metadata$lang, weft = i$formats[[1]]$metadata$weft, config_names = names(i$config), dir = i$project$dir, secs = as.numeric(difftime(Sys.time(), t0, units = 'secs')), used = qdoc) },
                 error = function(e) paste("ERR", conditionMessage(e)))
  ei <- tryCatch({ f <- Sys.getenv("QUARTO_EXECUTE_INFO"); j <- jsonlite::read_json(f); list(file_exists = file.exists(f), names = names(j), format_names = names(j$format), format_metadata_names = names(j$format$metadata), fm_weft = j$format$metadata$weft, fm_lang = j$format$metadata$lang, fm_bib = j$format$metadata$bibliography, project_names = names(j$project), project_dir = j$project$dir, project_config_names = names(j$project$config)) }, error = function(e) paste("ERR", conditionMessage(e)))
  r <- list(tag = tag, wd = getwd(), input = inp,
    class_metadata = class(m), metadata_names = if (is.list(m)) names(m) else m,
    md_weft = if (is.list(m)) m$weft, md_bibliography = if (is.list(m)) m$bibliography, md_lang = if (is.list(m)) m$lang,
    yaml_front_matter_names = if (is.list(yfm)) names(yfm) else yfm,
    pandoc_to = knitr::opts_knit$get("rmarkdown.pandoc.to"),
    quarto_env = as.list(qe), execute_info = ei, quarto_inspect = qi)
  sink(file.path(out, paste0("probe_", tag, ".txt"))); on.exit(sink()); str(r, max.level = 4, give.attr = FALSE)
  saveRDS(r, file.path(out, paste0('probe_', tag, '.rds')))
  invisible(r)
}
`%||%` <- function(a, b) if (is.null(a)) b else a
## install a text hook that probes once (the first text block = front matter block)
probe_hook_install <- function() {
  done <- FALSE
  knitr::knit_hooks$set(text = function(x) { if (!done) { done <<- TRUE; probe("hook") }; x })
}
