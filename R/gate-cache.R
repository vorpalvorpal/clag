# The commit gate's cache (design-4 G14, H1, H13): `<git common dir>/weft/cache/`,
# files `<layer>-<key>.rds`, three layers (`src`, `file`, `proj`), keys made by
# `cli::hash_md5()` from what the listing of a side already says (no file is read
# to make a key). An entry that will not read is a miss and is deleted. Writes go
# to a temporary name in the folder, then `file.rename()`.

GATE_CACHE_KEEP <- 800L
GATE_CACHE_MAX <- 1000L

gate_cache_new <- function(common) {
  g <- new.env(parent = emptyenv())
  g$enabled <- !identical(getOption("weft.gate_cache", TRUE), FALSE)
  g$dir <- file.path(common, "weft", "cache")
  g$ready <- FALSE
  g$notes <- character()
  g$mem <- new.env(parent = emptyenv())
  g
}

cache_disable <- function(cache, why) {
  if (cache$enabled) {
    cache$notes <- c(cache$notes, sprintf("the cache is not used: %s", why))
  }
  cache$enabled <- FALSE
}

cache_path <- function(cache, layer, key) file.path(cache$dir, sprintf("%s-%s.rds", layer, key))

cache_get <- function(cache, layer, key) {
  if (!cache$enabled) return(NULL)
  p <- cache_path(cache, layer, key)
  if (!file.exists(p)) return(NULL)
  v <- tryCatch(readRDS(p), error = function(e) NULL, warning = function(w) NULL)
  ok <- is.list(v) && identical(v$layer, layer)
  if (!ok) {
    unlink(p)
    return(NULL)
  }
  tryCatch(Sys.setFileTime(p, Sys.time()), error = function(e) NULL)
  v$value
}

cache_touch <- function(cache, layer, key) {
  if (!cache$enabled) return(invisible())
  p <- cache_path(cache, layer, key)
  if (file.exists(p)) tryCatch(Sys.setFileTime(p, Sys.time()), error = function(e) NULL)
  invisible()
}

cache_put <- function(cache, layer, key, value) {
  if (!cache$enabled) return(invisible())
  if (!cache$ready) {
    ok <- dir.exists(cache$dir) || suppressWarnings(dir.create(cache$dir, recursive = TRUE, showWarnings = FALSE))
    if (!ok || !dir.exists(cache$dir) || file.access(cache$dir, 2L) != 0L) {
      return(invisible(cache_disable(cache, sprintf("%s cannot be written", cache$dir))))
    }
    cache$ready <- TRUE
  }
  tmp <- tempfile(".tmp-", tmpdir = cache$dir)
  done <- tryCatch({
    saveRDS(list(layer = layer, value = value), tmp, compress = FALSE)
    file.rename(tmp, cache_path(cache, layer, key))
  }, error = function(e) FALSE, warning = function(w) FALSE)
  if (!isTRUE(done)) {
    unlink(tmp)
    cache_disable(cache, sprintf("%s cannot be written", cache$dir))
  }
  invisible()
}

# after a run with more than 1,000 entries, delete the oldest down to 800
cache_prune <- function(cache) {
  if (!cache$enabled || !cache$ready) return(invisible())
  f <- list.files(cache$dir, pattern = "\\.rds$", full.names = TRUE)
  if (length(f) <= GATE_CACHE_MAX) return(invisible())
  mt <- file.mtime(f)
  old <- f[order(mt, f)][seq_len(length(f) - GATE_CACHE_KEEP)]
  unlink(old)
  invisible()
}

# ---- keys -------------------------------------------------------------------------------------------------

# What identifies the installed code (review 4, #9): the version is the same across many reinstalls, so
# the md5 of the installed `R/weft.rdb` goes into the keys too; under `load_all()` there is no such file
# and the newest modification time of the source files stands in for it.
gate_code_identity <- function() {
  ns <- tryCatch(getNamespaceInfo(asNamespace("weft"), "path"), error = function(e) NULL)
  if (is.null(ns)) return("none")
  rdb <- file.path(ns, "R", "weft.rdb")
  if (file.exists(rdb)) return(paste0("rdb-", unname(tools::md5sum(rdb))))
  src <- list.files(file.path(ns, "R"), pattern = "\\.[Rr]$", full.names = TRUE)
  src <- c(src, list.files(file.path(ns, "inst"), recursive = TRUE, full.names = TRUE))
  if (!length(src)) return("none")
  paste0("src-", format(max(as.numeric(file.mtime(src)), na.rm = TRUE), digits = 17))
}

gate_versions <- function() {
  paste(as.character(utils::packageVersion("weft")), as.character(getRversion()), gate_code_identity(), sep = "|")
}

gate_key <- function(...) cli::hash_md5(paste(..., sep = "|"))
