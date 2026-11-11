# Spike implementation of tar_dict() + dependency declarer. Not production code.
`$.spike_dict` <- function(x, name) {
  u <- unclass(x)
  if (!name %in% names(u)) stop("unknown dict key: ", name, call. = FALSE)
  u[[name]]$value
}
spike_dict_obj <- function(path) structure(yaml::read_yaml(path), class = "spike_dict")
dict_key_value <- function(path, key, whole) {
  e <- yaml::read_yaml(path)[[key]]
  if (whole) e else e$value
}

# File target + one target per key (each reads the file directly; no whole-dict target).
tar_dict <- function(path, whole_entry = FALSE, whole_target = FALSE) {
  keys <- names(yaml::read_yaml(path))
  c(
    list(targets::tar_target_raw("dict_file", path, format = "file")),
    if (whole_target) list(targets::tar_target_raw("dict", quote(spike_dict_obj(dict_file)))),
    lapply(keys, function(k) targets::tar_target_raw(
      paste0("dict_", k),
      substitute(dict_key_value(dict_file, K, W), list(K = k, W = whole_entry))
    ))
  )
}

# Which keys does an expression read via dict$key / dict[["key"]]? Follows user functions in envir.
# A bare `dict` symbol (passed to a function, subset dynamically...) = all keys.
dict_keys_used <- function(e, keys, envir, seen = character(), fn_mode = "exact") {
  out <- character()
  walk <- function(e) {
    if (is.call(e)) {
      if ((identical(e[[1]], as.name("$")) || identical(e[[1]], as.name("[["))) && identical(e[[2]], as.name("dict"))) {
        k <- as.character(e[[3]])
        if (!k %in% keys) stop("unknown dict key in pipeline code: ", k, call. = FALSE)
        out <<- c(out, k); return(invisible())
      }
      for (i in seq_along(e)) if (!identical(e[[i]], quote(expr = ))) walk(e[[i]])
    } else if (is.name(e)) {
      nm <- as.character(e)
      if (nm == "dict") out <<- c(out, keys)
      else if (nzchar(nm) && !(nm %in% seen) && exists(nm, envir, inherits = FALSE) &&
               is.function(f <- get(nm, envir)) && !is.primitive(f)) {
        seen <<- c(seen, nm)
        k <- dict_keys_used(body(f), keys, envir, seen, fn_mode)
        if (fn_mode == "whole" && length(k)) k <- keys
        out <<- c(out, k)
      }
    }
  }
  walk(e); unique(out)
}

tar_dict_deps <- function(targets, path, fn_mode = "exact", envir = targets::tar_option_get("envir")) {
  keys <- names(yaml::read_yaml(path))
  tgts <- tarchetypes:::tar_copy_targets(targets)
  for (t in tgts) {
    used <- dict_keys_used(t$command$expr[[1]], keys, envir, fn_mode = fn_mode)
    if (length(used)) {
      d <- union(t$command$deps, paste0("dict_", used))
      t$command$deps <- d; t$deps <- d
    }
  }
  tgts
}
