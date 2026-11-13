# The `targets` pipeline (dev/design-2e.md, 2e-1): tar_dict(), tar_dict_deps(),
# the walker that finds what code reads, the scan of a rendered report's
# sources (rule 4.6.5), what a chapter reads when it is knitted (7.2.2) and
# the conditions `tar_meta()` holds (7.4.1).

need_targets <- function() {
  rlang::check_installed("targets", reason = "to define a pipeline")
}

pipeline_abort <- function(msg) weft_abort(msg, "weft_pipeline_error")

# ---- the walker (P9) --------------------------------------------------------------------------

TAR_READERS <- c("tar_read", "tar_load", "tar_read_raw", "tar_load_raw")

# A walker over R code. `add(code)` walks a call, an expression vector, or a
# character vector of lines of code; `result()` is what `code_reads()` returns;
# `store_exprs()` holds the `store` expressions that were not literal strings.
reads_walker <- function(envir = globalenv(), keys = character()) {
  keys <- as.character(keys)
  st <- new.env(parent = emptyenv())
  st$keys <- character()
  st$all <- FALSE
  st$unknown <- character()
  st$reads <- list()       # list(name, store, expr) for each target read
  st$seen <- character()
  st$visited <- list()
  st$scopes <- list()
  st$params <- character() # the arguments of the function being walked
  st$cur <- NULL           # the name of the function being walked
  st$locals <- character() # the names that function assigns in its body
  st$wrappers <- list()
  st$names <- NULL
  st$files <- character()  # literal paths given to source() and sys.source()

  add_key <- function(k) {
    if (k %in% keys) st$keys <- c(st$keys, k) else st$unknown <- c(st$unknown, k)
  }
  lit_chr <- function(e) if (is.character(e) && length(e) == 1L && !is.na(e)) e else NULL

  lookup <- function(nm) {
    f <- get0(nm, envir = envir, inherits = FALSE, mode = "function")
    if (is.function(f)) return(f)
    for (sc in st$scopes) {
      f <- get0(nm, envir = sc, inherits = FALSE, mode = "function")
      if (is.function(f)) return(f)
    }
    NULL
  }

  walk_fn <- function(f, label) {
    old <- list(params = st$params, cur = st$cur)
    on.exit({ st$params <- old$params; st$cur <- old$cur }, add = TRUE)
    st$params <- c(st$params, names(formals(f)))
    st$cur <- label
    oldloc <- st$locals
    on.exit(st$locals <- oldloc, add = TRUE)
    st$locals <- setdiff(assigned_in(body(f)), names(formals(f)))
    walk(formals(f))
    walk(body(f))
  }

  follow <- function(nm) {
    if (nm %in% st$seen) return(invisible())
    f <- lookup(nm)
    if (!is.function(f) || is.primitive(f)) return(invisible())
    st$seen <- c(st$seen, nm)
    st$visited <- c(st$visited, list(f))
    walk_fn(f, nm)
    # the functions bound in the closure's own environment
    ce <- environment(f)
    if (!is.null(ce) && !identical(ce, envir) && !identical(ce, globalenv()) &&
        !nzchar(environmentName(ce)) && !identical(ce, emptyenv())) {
      st$scopes <- c(st$scopes, list(ce))
      for (n2 in ls(ce, all.names = TRUE)) {
        g <- get0(n2, envir = ce, inherits = FALSE, mode = "function")
        if (!is.function(g) || is.primitive(g)) next
        if (any(vapply(st$visited, identical, NA, g))) next
        st$visited <- c(st$visited, list(g))
        walk_fn(g, n2)
      }
    }
    invisible()
  }

  # `g()` may dispatch to any `g.<class>` in the pipeline's environment
  follow_methods <- function(g) {
    if (!grepl("^[A-Za-z.][A-Za-z0-9._]*$", g)) return(invisible())
    if (is.null(st$names)) st$names <- ls(envir, all.names = TRUE)
    pre <- paste0(g, ".")
    for (m in st$names[startsWith(st$names, pre)]) follow(m)
    invisible()
  }

  # the strings a `name`/`names` argument gives (literal strings, or `c()` of them)
  # (`sym`: a bare symbol is a name too, for a reader that embraces its argument)
  literal_names <- function(v, sym = FALSE) {
    one <- function(e) {
      l <- lit_chr(e)
      if (is.null(l) && sym && is.symbol(e) && nzchar(as.character(e))) l <- as.character(e)
      l
    }
    l <- one(v)
    if (!is.null(l)) return(l)
    if (is.call(v) && identical(v[[1L]], quote(c))) {
      return(unlist(lapply(as.list(v)[-1L], one)))
    }
    character()
  }

  # the default of a formal argument of `f`, or NULL when it has none
  formal_default <- function(f, nm) {
    fm <- formals(f)
    if (is.null(nm) || !nm %in% names(fm) || identical(fm[[nm]], quote(expr = ))) return(NULL)
    fm[[nm]]
  }

  # the names a function assigns in its body
  assigned_in <- function(e) {
    out <- character()
    if (is.call(e)) {
      if (as.character(e[[1L]])[1L] %in% c("<-", "=", "<<-") && length(e) == 3L && is.symbol(e[[2L]])) {
        out <- as.character(e[[2L]])
      }
      for (a in as.list(e)) if (!missing(a)) out <- c(out, assigned_in(a))
    }
    out
  }

  add_read <- function(nm, store, expr) {
    st$reads[[length(st$reads) + 1L]] <- list(name = nm, store = store, expr = expr)
  }

  record_target <- function(fname, x) {
    raw <- endsWith(fname, "_raw")
    load <- startsWith(fname, "tar_load")
    args <- as.list(x)[-1L]
    an <- names(args)
    if (is.null(an)) an <- rep("", length(args))
    want <- if (load) "names" else "name"
    i <- which(an == want)[1L]
    if (is.na(i)) i <- which(an == "")[1L]
    store <- NA_character_
    sexpr <- NULL
    j <- which(an == "store")[1L]
    if (!is.na(j)) {
      l <- lit_chr(args[[j]])
      if (!is.null(l)) store <- l else sexpr <- args[[j]]
    }
    # an argument of the function being walked, given as the name: a reader
    wrapper_param <- NULL
    embraced <- FALSE
    unparam <- function(e) {
      emb <- FALSE
      # {{ x }}, !!enquo(x), !!ensym(x) (bare or rlang::-qualified), and !!x
      if (is.call(e) && identical(e[[1L]], quote(`{`)) && length(e) == 2L &&
          is.call(e[[2L]]) && identical(e[[2L]][[1L]], quote(`{`)) && length(e[[2L]]) == 2L) {
        e <- e[[2L]][[2L]]
        emb <- TRUE
      } else {
        while (is.call(e) && identical(e[[1L]], quote(`!`)) && length(e) == 2L) e <- e[[2L]]
        if (is.call(e) && length(e) == 2L) {
          h <- e[[1L]]
          if (is.call(h) && length(h) == 3L && is.symbol(h[[1L]]) &&
              as.character(h[[1L]]) %in% c("::", ":::") && is.symbol(h[[3L]])) h <- h[[3L]]
          if (is.symbol(h) && as.character(h) %in% c("enquo", "ensym")) {
            e <- e[[2L]]
            emb <- TRUE
          }
        }
      }
      if (is.symbol(e) && as.character(e) %in% st$params) {
        if (emb) embraced <<- TRUE
        as.character(e)
      } else NULL
    }
    names_found <- character()
    if (!is.na(i)) {
      v <- args[[i]]
      one <- function(e) {
        l <- lit_chr(e)
        if (!is.null(l)) return(l)
        pm <- unparam(e)
        if (!is.null(pm)) {
          wrapper_param <<- pm
          return(NULL)
        }
        if (!raw && is.symbol(e) && nzchar(as.character(e))) return(as.character(e))
        NULL
      }
      names_found <- if (is.call(v) && identical(v[[1L]], quote(c))) {
        unlist(lapply(as.list(v)[-1L], one))
      } else {
        one(v)
      }
    }
    sp <- if (!is.null(sexpr)) unparam(sexpr) else NULL
    # a store held in a local of the reader cannot be worked out from outside it (rule 7.2.2)
    if (is.null(sp) && !is.null(sexpr) && length(st$locals) && any(all.vars(sexpr) %in% st$locals)) {
      sexpr <- quote(stop("the store is a local of the reader"))
    }
    if (!is.null(wrapper_param) && !is.null(st$cur)) {
      st$wrappers[[st$cur]] <- list(param = wrapper_param, store = store, embraced = embraced,
                                    expr = if (is.null(sp)) sexpr else NULL, store_param = sp)
    }
    for (nm in as.character(names_found)) add_read(nm, store, sexpr)
    rest <- args[setdiff(seq_along(args), i)]
    for (a in rest) if (!missing(a)) walk(a)
    invisible()
  }

  # a call of a function of the author's that reads the target it is given
  call_wrapper <- function(x, hname) {
    w <- st$wrappers[[hname]]
    f <- lookup(hname)
    if (is.null(w) || is.null(f)) return(invisible())
    mc <- tryCatch(match.call(f, x, expand.dots = FALSE), error = function(e) NULL)
    if (is.null(mc)) return(invisible())
    # an argument the call omits takes the reader's default
    arg <- mc[[w$param]]
    if (is.null(arg)) arg <- formal_default(f, w$param)
    nms <- literal_names(arg, sym = isTRUE(w$embraced))
    if (!length(nms)) return(invisible())
    store <- w$store
    expr <- w$expr
    if (!is.null(w$store_param)) {
      a <- mc[[w$store_param]]
      if (is.null(a)) a <- formal_default(f, w$store_param)
      if (!is.null(a)) {
        l <- lit_chr(a)
        if (!is.null(l)) store <- l else expr <- a
      }
    }
    for (nm in nms) add_read(nm, store, expr)
    invisible()
  }

  is_string_dict <- function(e) is.character(e) && "dict" %in% e

  walk <- function(x) {
    if (is.symbol(x)) {
      nm <- as.character(x)
      if (!nzchar(nm)) return(invisible())
      if (identical(nm, "dict")) st$all <- TRUE else follow(nm)
      return(invisible())
    }
    if (is.pairlist(x) || is.expression(x) || (is.list(x) && !is.call(x))) {
      for (a in as.list(x)) if (!missing(a)) walk(a)
      return(invisible())
    }
    if (!is.call(x)) return(invisible())
    head <- x[[1L]]
    n <- length(x)
    hname <- if (is.symbol(head)) as.character(head) else ""
    if (hname %in% c("::", ":::")) return(invisible())
    # `targets::tar_read` and friends
    fname <- hname
    if (is.call(head) && length(head) == 3L && is.symbol(head[[1L]]) &&
        as.character(head[[1L]]) %in% c("::", ":::") && is.symbol(head[[2L]]) &&
        identical(as.character(head[[2L]]), "targets") && is.symbol(head[[3L]])) {
      fname <- as.character(head[[3L]])
    }
    if (fname %in% TAR_READERS) return(record_target(fname, x))
    # get("dict"), get0("dict"), mget("dict"), exists("dict"): every key
    bname <- fname
    if (is.call(head) && length(head) == 3L && is.symbol(head[[1L]]) &&
        as.character(head[[1L]]) %in% c("::", ":::") && is.symbol(head[[3L]]) &&
        identical(as.character(head[[2L]]), "base")) bname <- as.character(head[[3L]])
    if (bname %in% c("get", "get0", "mget", "exists")) {
      for (a in as.list(x)[-1L]) {
        if (is_string_dict(a) ||
            (is.call(a) && identical(a[[1L]], quote(c)) &&
             any(vapply(as.list(a)[-1L], is_string_dict, NA)))) st$all <- TRUE
      }
    }
    if (bname %in% c("source", "sys.source") && n >= 2L) {
      an <- names(x)
      if (is.null(an)) an <- rep("", n)
      k <- which(an == "file")[1L]
      if (is.na(k)) k <- setdiff(which(an == ""), 1L)[1L]
      if (!is.na(k)) {
        l <- lit_chr(x[[k]])
        if (!is.null(l)) st$files <- c(st$files, l)
      }
    }
    if (identical(hname, "function") && n >= 3L) {
      old <- st$params
      on.exit(st$params <- old, add = TRUE)
      st$params <- c(st$params, names(x[[2L]]))
      walk(x[[2L]])
      walk(x[[3L]])
      return(invisible())
    }
    if (hname %in% c("$", "[[", "[") && n >= 3L && is.symbol(x[[2L]]) &&
        identical(as.character(x[[2L]]), "dict")) {
      if (hname == "$") {
        k <- if (is.symbol(x[[3L]])) as.character(x[[3L]]) else lit_chr(x[[3L]])
        if (!is.null(k)) add_key(k) else st$all <- TRUE
        return(invisible())
      }
      if (hname == "[[" && n == 3L && !is.null(lit_chr(x[[3L]]))) {
        add_key(lit_chr(x[[3L]]))
        return(invisible())
      }
      st$all <- TRUE
      for (a in as.list(x)[-(1:2)]) if (!missing(a)) walk(a)
      return(invisible())
    }
    if (hname %in% c("$", "@") && n == 3L) {
      walk(x[[2L]])
      return(invisible())
    }
    if (hname %in% c("<-", "=", "<<-") && n == 3L && is.symbol(x[[2L]]) &&
        identical(as.character(x[[2L]]), "dict")) {
      walk(x[[3L]])
      return(invisible())
    }
    if (nzchar(hname)) {
      follow(hname)
      follow_methods(hname)
      call_wrapper(x, hname)
    }
    for (a in as.list(x)) if (!missing(a)) walk(a)
    invisible()
  }

  add <- function(code) {
    ex <- if (is.character(code)) {
      if (!length(code) || all(is.na(code))) return(invisible())
      tryCatch(as.list(parse(text = paste(code[!is.na(code)], collapse = "\n"), keep.source = FALSE)),
               error = function(e) list())
    } else if (is.expression(code)) {
      as.list(code)
    } else if (is.null(code)) {
      list()
    } else {
      list(code)
    }
    for (e in ex) walk(e)
    invisible()
  }

  result <- function() {
    nm <- vapply(st$reads, function(r) r$name, "")
    sr <- vapply(st$reads, function(r) r$store, "")
    tg <- unique(data.frame(name = as.character(nm), store = as.character(sr),
                            stringsAsFactors = FALSE))
    rownames(tg) <- NULL
    list(keys = if (st$all) sort(unique(keys), method = "radix") else
           sort(unique(st$keys), method = "radix"),
         all = st$all,
         unknown = sort(unique(st$unknown), method = "radix"),
         targets = tg)
  }
  # every read with the `store` expression it gave when that was not a literal
  store_exprs <- function() st$reads
  list(add = add, result = result, store_exprs = store_exprs, source_files = function() st$files,
       set_all = function() st$all <- TRUE)
}

# What code reads: the dictionary keys, whether every key (`all`), the keys it
# names that `keys` lacks, and the targets it reads (P9).
code_reads <- function(code, envir = globalenv(), keys = character()) {
  w <- reads_walker(envir, keys)
  w$add(code)
  w$result()
}

# ---- tar_dict() (P2-P4) -----------------------------------------------------------------------

dict_path_ok <- function(path) {
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path) ||
      !file.exists(path) || dir.exists(path)) {
    pipeline_abort(sprintf("weft: `path` must name an existing dictionary file; got %s (rule 4.6.1).",
                           if (is.character(path) && length(path) == 1L && !is.na(path))
                             paste0("`", path, "`") else "something else"))
  }
  invisible(path)
}

# A global `dict` is refused (P5).
refuse_global_dict <- function() {
  if (exists("dict", envir = targets::tar_option_get("envir"), inherits = FALSE)) {
    pipeline_abort(paste0(
      "weft: `dict` is an object in the pipeline's environment (the global environment when ",
      "`callr_function = NULL`, so it may come from this R session), so targets tracks it and ",
      "every target that reads it re-runs when any entry changes, its definition included. ",
      "Remove `dict <- ...` from _targets.R, or `rm(dict)` in the session: tar_dict() provides ",
      "`dict` (rule 4.6.3)."))
  }
  invisible()
}

# The frame of the targets function that is evaluating a pipeline script, or
# NULL (a call made at the console, or in a test, has none). A second
# tar_dict() in the same evaluation is a second dictionary in one pipeline.
script_frame <- function() {
  # exported by targets but internal to it: looked up softly, so that a release that renames it
  # turns this check off (targets then refuses two dictionaries by its own duplicate-name error)
  inner <- get0("tar_callr_inner_try", envir = asNamespace("targets"), inherits = FALSE)
  if (!is.function(inner)) return(NULL)
  for (i in rev(seq_len(sys.nframe() - 1L))) {
    f <- tryCatch(sys.function(i), error = function(e) NULL)
    if (is.function(f) && identical(f, inner)) return(sys.frame(i))
  }
  NULL
}

#' Targets for a project dictionary
#'
#' `tar_dict()` makes a `targets` pipeline depend on the entries of `dict.yml`
#' it reads, and on nothing else in the file. It returns the targets
#' `dict_file` (the file), `dict_values` (the dictionary as [read_dict()]
#' reads it) and `dict_<key>` (the value of each entry), and attaches the dictionary as the object `dict` on
#' the search path, as `weft:dict`, so that commands and functions in the
#' pipeline find it (rule 4.6.1). Pass the result of the pipeline's targets to
#' [tar_dict_deps()], which adds to each target the entries it reads. A changed
#' value then re-runs exactly the targets that read it, and a changed
#' definition, a new key or a reordered file re-runs none (rule 4.6.3).
#'
#' Do not define `dict` in `_targets.R`: `targets` would track the whole object,
#' and every reader would re-run when any entry changed. That is an error.
#'
#' Limit: `dict` is attached in the session that defines the pipeline. A
#' parallel `crew` worker does not have it, so a function that reads `dict`
#' fails there with "object 'dict' not found". Pass the values the function
#' needs as arguments, or run the pipeline without workers.
#'
#' @param path The dictionary file, one string.
#' @return A list of target objects.
#' @examples
#' \dontrun{
#' # _targets.R
#' library(targets)
#' c(
#'   weft::tar_dict("dict.yml"),
#'   weft::tar_dict_deps(list(
#'     tar_target(limit_ok, dict$limit > 3)
#'   ))
#' )
#' }
#' @export
tar_dict <- function(path = "dict.yml") {
  need_targets()
  dict_path_ok(path)
  d <- read_dict(path)
  refuse_global_dict()
  fr <- script_frame()
  if (!is.null(fr) && identical(weft_env$dict_frame, fr)) {
    pipeline_abort(paste0(
      "weft: tar_dict() was called twice in one pipeline; a pipeline has one dictionary, and ",
      "the second would replace the `dict` the first attached (rule 4.6.1)."))
  }
  weft_env$dict_frame <- fr
  while ("weft:dict" %in% search()) detach("weft:dict", character.only = TRUE)
  env <- new.env(parent = emptyenv())
  attr(d, "weft_pipeline") <- TRUE
  assign("dict", d, envir = env)
  get("attach", envir = baseenv())(env, name = "weft:dict", pos = 2L, warn.conflicts = FALSE)
  mark <- function(t) {
    attr(t, "weft_dict") <- TRUE
    t
  }
  out <- list(mark(targets::tar_target_raw("dict_file", path, format = "file")),
              mark(targets::tar_target_raw("dict_values", quote(weft::read_dict(dict_file)))))
  for (k in names(unclass(d))) {
    out[[length(out) + 1L]] <- mark(targets::tar_target_raw(
      paste0("dict_", k), bquote(dict_values[[.(k)]])))
  }
  out
}

# The check the attached `dict` makes while a target runs: the running target
# must depend on the entry it reads (rule 4.6.2, 4.6.3).
dict_guard <- function(x, key = NULL) {
  if (!isTRUE(tryCatch(targets::tar_active(), error = function(e) FALSE))) return(invisible())
  # outside a running target tar_definition() gives its default: a pipeline script that reads
  # `dict` while it is being defined is not a target
  if (is.null(weft_env$no_target)) {
    weft_env$no_target <- targets::tar_target_raw("weft_no_target", quote(NULL))
  }
  def <- tryCatch(targets::tar_definition(default = weft_env$no_target), error = function(e) NULL)
  if (is.null(def) || identical(def, weft_env$no_target)) return(invisible())
  keys <- names(unclass(x))
  # with no keys a whole-dictionary read depends on nothing (rule 4.1)
  need <- if (is.null(key)) paste0("dict_", keys)[seq_along(keys)] else paste0("dict_", key)
  miss <- setdiff(need, def$deps)
  if (!length(miss)) return(invisible())
  nm <- def$settings$name
  what <- if (is.null(key)) {
    sprintf("reads the whole dictionary, and does not depend on %s",
            paste0("`", miss, "`", collapse = ", "))
  } else {
    sprintf("reads `dict$%s`, and does not depend on `%s`", key, miss)
  }
  pipeline_abort(sprintf(paste0(
    "weft: the target `%s` %s. Pass the target through tar_dict_deps(), which adds the entries ",
    "it reads; a read it cannot see, such as eval(parse(text = )), cannot be tracked (rule 4.6.2)."),
    nm, what))
}

# ---- tar_dict_deps() (P6-P8, P10) ---------------------------------------------------------------

#' Add the dictionary entries a pipeline reads to its targets
#'
#' `tar_dict_deps()` finds, in the command of each target and in the functions
#' it calls from the pipeline's environment, the entries of the dictionary it
#' reads (`dict$key`, `dict[["key"]]`; any other use of `dict` counts as
#' reading every entry), and adds `dict_<key>` to the target's dependencies
#' (rule 4.6.2). A target made by `tarchetypes::tar_quarto()` or
#' `tarchetypes::tar_render()` is read the same way through its source files:
#' chunk code, inline R and the code of constructs, included files too (rule
#' 4.6.5). Includes rooted at `/` resolve against the Quarto project root. A report
#' with a `child=` or include that the scan cannot resolve to a file (a computed path)
#' depends on every key. A key that the dictionary does not hold is an error that lists every
#' target that reads one (rule 4.6.4).
#'
#' See [tar_dict()] for the limit with `crew` workers: the dictionary is not
#' visible to a parallel worker.
#'
#' @param targets A target object, or a list of target objects and lists,
#'   nested to any depth.
#' @param path The dictionary file, as given to [tar_dict()].
#' @return `targets`, in the same structure. The target objects are changed in
#'   place, with the hooks of `tarchetypes`, which this function needs.
#' @examples
#' \dontrun{
#' weft::tar_dict_deps(list(targets::tar_target(t, dict$limit + 1)))
#' }
#' @export
tar_dict_deps <- function(targets, path = "dict.yml") {
  need_targets()
  refuse_global_dict()
  flat <- flatten_targets(targets)
  dict_path_ok(path)
  keys <- names(read_dict(path))
  envir <- targets::tar_option_get("envir")
  own <- c("dict_file", "dict_values", paste0("dict_", keys))
  # one dictionary, and the names it uses are its own
  mine <- vapply(flat, function(t) isTRUE(attr(t, "weft_dict")), NA)
  nms <- vapply(flat, function(t) t$settings$name, "")
  if (sum(nms == "dict_file" & mine) > 1L) {
    pipeline_abort(paste0(
      "weft: tar_dict() was called more than once in this pipeline; a pipeline has one ",
      "dictionary (rule 4.6.1)."))
  }
  clash <- unique(nms[!mine & nms %in% own])
  if (length(clash)) {
    pipeline_abort(sprintf(paste0(
      "weft: the target%s %s %s names tar_dict() uses (`dict_file`, `dict_values`, `dict_<key>`); ",
      "rename %s (rule 4.6.1)."),
      if (length(clash) == 1L) "" else "s", paste0("`", clash, "`", collapse = ", "),
      if (length(clash) == 1L) "has one of the" else "have",
      if (length(clash) == 1L) "it" else "them"))
  }
  bad <- list()
  plan <- vector("list", length(flat))
  for (i in seq_along(flat)) {
    t <- flat[[i]]
    nm <- t$settings$name
    if (isTRUE(attr(t, "weft_dict"))) next
    rep <- report_files(t)
    found <- character()
    if (!is.null(rep)) {
      for (f in rep) {
        if (!file.exists(f)) {
          pipeline_abort(sprintf(
            "weft: `%s` names the source %s, which does not exist (rule 4.6.5).", nm, f))
        }
        if (dir.exists(f)) next
        r <- report_reads(f, envir, keys)
        found <- c(found, r$keys)
        for (u in r$unknown) bad[[length(bad) + 1L]] <- list(target = nm, file = f, key = u)
      }
    } else {
      r <- code_reads(t$command$expr, envir, keys)
      found <- r$keys
      for (u in r$unknown) bad[[length(bad) + 1L]] <- list(target = nm, file = NA_character_, key = u)
    }
    plan[[i]] <- list(found = sort(unique(found), method = "radix"), report = !is.null(rep))
  }
  if (length(bad)) {
    lines <- vapply(bad, function(b) {
      sprintf("  `%s`%s reads `dict$%s`, which %s does not hold (rule 4.6.4).%s", b$target,
              if (is.na(b$file)) "" else paste0(" (", b$file, ")"), b$key, path,
              did_you_mean(b$key, keys))
    }, "")
    pipeline_abort(paste(c(sprintf("weft: %s: %d unknown key(s) read by the pipeline", path, length(bad)),
                           lines), collapse = "\n"))
  }
  for (i in seq_along(flat)) {
    if (!is.null(plan[[i]])) attach_dict_deps(flat[[i]], plan[[i]]$found, plan[[i]]$report)
  }
  targets
}

# One target with the entries it reads as dependencies, and its value cleaned of the dictionary marker. The
# work is tarchetypes' own, through its exported hooks, which keep up with `targets`: `tar_hook_before()`
# names the `dict_<key>` targets ahead of the command (and sets the dependencies from the new command), and
# `tar_hook_outer()` wraps the command in `weft::dict_unmark()` and keeps the dependencies as they are. The
# hooks return a copy; its `command` and `deps` are put back on `t`, so the target object is changed in
# place, as `tar_dict_deps()` documents. A report target (`tar_quarto()`, `tar_render()`, ...) gets the
# first hook only: its value is a file, and tarchetypes 0.14.0 puts the dependencies from its source files
# into the command (`deps = list(...)`), so the hook, which re-reads them from the new command, keeps them
# (tried with tar_render(); the tests in test-tar-dict-quarto.R cover tar_quarto()). A target whose command
# is more than one expression, which the hooks refuse, keeps its dependencies by a direct union
# (`union_dict_deps()`), the one place weft edits `t$deps` itself.
attach_dict_deps <- function(t, found, report) {
  if (length(t$command$expr) != 1L) {
    if (length(found)) union_dict_deps(t, found)
    return(invisible(t))
  }
  need_tarchetypes()
  out <- list(t)
  if (length(found)) {
    syms <- lapply(paste0("dict_", found), as.name)
    out <- tarchetypes::tar_hook_before_raw(out, hook = as.call(c(list(as.name("{")), syms)),
                                            set_deps = TRUE)
  }
  if (!report) {
    e <- out[[1L]]$command$expr[[1L]]
    already <- is.call(e) && identical(e[[1L]], quote(weft::dict_unmark))
    if (!already) {
      out <- tarchetypes::tar_hook_outer_raw(out, hook = quote(weft::dict_unmark(.x)), set_deps = FALSE)
    }
  }
  t$command <- out[[1L]]$command
  t$deps <- out[[1L]]$deps
  invisible(t)
}

# The one direct edit of a target's dependencies (see attach_dict_deps()).
union_dict_deps <- function(t, found) {
  t$deps <- union(t$deps, paste0("dict_", found))
  invisible(t)
}

need_tarchetypes <- function() {
  if (!requireNamespace("tarchetypes", quietly = TRUE)) {
    pipeline_abort(paste0("weft: tar_dict_deps() needs the tarchetypes package, which adds the dictionary ",
                          "entries to a target through its hooks; install it with install.packages(\"tarchetypes\")."))
  }
  invisible()
}

# A target's value never carries the marker of the attached dictionary: a copy that one target
# stores reads freely in another, which depends on that target (rule 4.6.2). The command is
# wrapped in `dict_unmark()`, so the value is cleaned before it is stored (attach_dict_deps()).

#' Remove the dictionary marker from a target's value
#'
#' Generated target commands call this; it is not for direct use.
#' It returns `x` without the marker of the attached dictionary, in `x` and in its lists.
#'
#' @param x A target's value.
#' @return `x`, without the marker.
#' @keywords internal
#' @export
dict_unmark <- function(x) {
  if (!is.null(attr(x, "weft_pipeline"))) attr(x, "weft_pipeline") <- NULL
  if (is.list(x) && !is.data.frame(x) && is.null(oldClass(x))) {
    for (i in seq_along(x)) {
      v <- x[[i]]
      if (is.list(v) || !is.null(attr(v, "weft_pipeline"))) x[i] <- list(dict_unmark(v))
    }
  }
  x
}

flatten_targets <- function(x) {
  if (inherits(x, "tar_target")) return(list(x))
  if (is.list(x) && !is.data.frame(x)) return(unlist(lapply(x, flatten_targets), recursive = FALSE))
  pipeline_abort(paste0("weft: `targets` must be a target or a list of targets, nested to any depth ",
                        "(rule 4.6.2)."))
}

# The source files of a report target (`tar_quarto()`, `tar_render()`,
# `tar_render_rep()`, `tar_quarto_rep()`), or NULL for any other target (P10).
report_files <- function(t) {
  ex <- t$command$expr
  if (length(ex) != 1L || !is.call(ex[[1L]])) return(NULL)
  cmd <- ex[[1L]]
  h <- paste(deparse(cmd[[1L]]), collapse = "")
  one <- function(p) if (is.character(p) && length(p) == 1L && !is.na(p)) p else NULL
  if (identical(h, "tarchetypes::tar_quarto_run")) {
    s <- tryCatch(eval(cmd[["sources"]], baseenv()), error = function(e) NULL)
    if (is.character(s)) return(s)
  } else if (h %in% c("tarchetypes::tar_render_run", "tarchetypes::tar_render_rep_run")) {
    p <- one(cmd[["path"]])
    if (!is.null(p)) return(p)
  } else if (identical(h, "tarchetypes::tar_quarto_rep_run")) {
    a <- tryCatch(eval(cmd[["args"]], baseenv()), error = function(e) NULL)
    p <- one(a$input)
    x <- tryCatch(eval(cmd[["extra_files"]], baseenv()), error = function(e) NULL)
    if (!is.null(p)) return(c(p, if (is.character(x)) x))
  }
  NULL
}

# The knitr child files and Quarto includes a document names, as written. The
# attribute `unresolved` is TRUE when a `child` option is not a string the scan
# can work out (a computed path), as that is a file it cannot follow.
document_children <- function(lines) {
  out <- character()
  unresolved <- FALSE
  strs <- function(txt) {
    v <- tryCatch(suppressWarnings(suppressMessages(eval(parse(text = txt, keep.source = FALSE), baseenv()))),
                  error = function(e) NULL)
    if (is.character(v)) v else {
      unresolved <<- TRUE
      character()
    }
  }
  lines <- tryCatch(dequote_chunks(lines), error = function(e) lines)
  for (ch in tryCatch(find_chunks(lines), error = function(e) list())) {
    o <- tryCatch(parse_header(ch$header)$opts$child, error = function(e) NULL)
    if (!is.null(o)) out <- c(out, strs(o$text))
    body <- lines[seq_len(max(0L, min(ch$close, length(lines) + 1L) - 1L - ch$open)) + ch$open]
    hit <- regmatches(body, regexec("^\\s*#\\|\\s*child:\\s*(.+?)\\s*$", body))
    for (h in hit) {
      if (length(h) == 2L) {
        y <- tryCatch(yaml_read_text(h[2L]), error = function(e) NULL)
        if (is.character(y)) out <- c(out, y) else unresolved <- TRUE
      }
    }
  }
  inc <- regmatches(lines, regexec("\\{\\{<\\s*include\\s+(\"[^\"]+\"|'[^']+'|[^ >]+)\\s*>\\}\\}", lines))
  for (h in inc) if (length(h) == 2L) out <- c(out, gsub("^[\"']|[\"']$", "", h[2L]))
  out <- unique(out[nzchar(out)])
  attr(out, "unresolved") <- unresolved
  out
}

# The Quarto project root of a document: the nearest folder above it (or its own)
# that holds `_quarto.yml` or `_quarto.yaml`, else the document's folder.
quarto_root <- function(path) {
  d <- norm_path(dirname(path))
  find_quarto_root(d) %||% d
}

BINARY_EXT <- c("png", "jpg", "jpeg", "gif", "bmp", "tif", "tiff", "webp", "ico", "pdf", "zip", "gz",
                "rds", "rda", "rdata", "xlsx", "xls", "docx", "pptx", "woff", "woff2", "ttf", "otf",
                "eot", "mp3", "mp4", "mov", "svg")

# What the R code of one document reads: the code of every chunk that is not
# `eval: false`, inline R in prose and front matter, and the code of
# constructs (P10), and the same for each knitr child and Quarto include it
# names, to any depth. A file that is not an R Markdown document is read as
# one too; an `.R` file is code.
report_reads <- function(path, envir, keys) {
  w <- reads_walker(envir, keys)
  seen <- character()
  todo <- path
  top <- path
  while (length(todo)) {
    f <- todo[[1L]]
    todo <- todo[-1L]
    key <- norm_path(f)
    if (key %in% seen || dir.exists(f) || !file.exists(f)) next
    seen <- c(seen, key)
    if (tolower(tools::file_ext(f)) %in% BINARY_EXT) next
    lines <- tryCatch(read_view_lines(f), error = function(e) character())
    if (!length(lines)) next
    if (grepl("\\.[Rr]$", f)) {
      w$add(paste(lines, collapse = "\n"))
      next
    }
    for (pc in tryCatch(seed_chunks(lines), error = function(e) list())) {
      w$add(paste(pc$code, collapse = "\n"))
    }
    rows <- tryCatch(scan_document(lines, file = f, config = NULL, project = ""),
                     error = function(e) NULL)
    if (!is.null(rows) && nrow(rows)) {
      for (x in c(rows$expr, unlist(rows$keys))) if (!is.na(x)) w$add(as.character(x))
    }
    kids <- document_children(lines)
    if (isTRUE(attr(kids, "unresolved"))) w$set_all()
    if (length(kids)) {
      base <- dirname(f)
      qroot <- quarto_root(f)
      cand <- vapply(kids, function(k) {
        c1 <- if (grepl("^/", k) && !grepl("^//", k)) {
          file.path(qroot, sub("^/+", "", k))
        } else if (is_abs_path(k)) k else file.path(base, k)
        if (file.exists(c1) && !dir.exists(c1)) c1 else if (file.exists(k) && !dir.exists(k)) k else NA_character_
      }, "")
      # a child or include that is not a file the scan can find: any key may be read there
      if (anyNA(cand)) w$set_all()
      todo <- c(todo, cand[!is.na(cand)])
    }
  }
  w$result()
}

# ---- paths ----------------------------------------------------------------------------------------

is_abs_path <- function(p) grepl("^(/|[A-Za-z]:[/\\\\]|\\\\\\\\)", p)

# normalizePath() that also resolves the folders of a path that does not exist.
norm_path <- function(p) {
  p <- gsub("\\\\", "/", p)
  if (file.exists(p)) return(normalizePath(p, winslash = "/", mustWork = FALSE))
  d <- dirname(p)
  if (identical(d, p)) return(p)
  paste0(sub("/+$", "", norm_path(d)), "/", basename(p))
}

# `path` relative to `root`, with `/`; both are absolute and normalised.
rel_path <- function(root, path) {
  r <- strsplit(sub("/+$", "", root), "/", fixed = TRUE)[[1L]]
  p <- strsplit(path, "/", fixed = TRUE)[[1L]]
  k <- 0L
  while (k < min(length(r), length(p)) && identical(r[k + 1L], p[k + 1L])) k <- k + 1L
  if (k == 0L) return(path)
  paste(c(rep("..", length(r) - k), p[seq_along(p) > k]), collapse = "/")
}

# ---- the label hook's record (T11) ----------------------------------------------------------------

# The code, `eval` and child of a chunk the option hook sees, children's and
# cached chunks included.
note_chunk_code <- function(s, options) {
  ch <- options$child
  child <- NULL
  if (is.character(ch) && length(ch)) {
    cp <- knitr::opts_knit$get("child.path")
    cur <- tryCatch(suppressWarnings(knitr::current_input(dir = TRUE)), error = function(e) NULL)
    bases <- c(if (is.character(cur) && length(cur) == 1L) dirname(cur),
               knitr::opts_knit$get("root.dir"), getwd())
    child <- vapply(ch, function(f) {
      f <- if (is.character(cp) && length(cp) == 1L && nzchar(cp)) file.path(cp, f) else f
      cand <- if (is_abs_path(f)) f else file.path(bases, f)
      hit <- cand[file.exists(cand)]
      if (length(hit)) norm_path(hit[[1L]]) else NA_character_
    }, "", USE.NAMES = FALSE)
    child <- child[!is.na(child)]
  }
  s$chunks[[length(s$chunks) + 1L]] <- list(code = options$code, eval = options$eval, child = child)
  invisible()
}

# ---- what a chapter reads (P12-P18) ------------------------------------------------------------------

# Called at the start of the `document` hook of a top-level knit, before the
# failures are counted: P15's failures belong with them.
chapter_reads <- function(s) {
  root <- ledger_root(s)
  if (is.na(root) || !is_set_up(root) || rehearsing()) return(invisible())
  # with `ledger: false` no reads are collected (rule 7.1.3)
  if (isFALSE(s$config$ledger)) return(invisible())
  keys <- names(s$dict)
  if (is.null(keys)) keys <- character()
  w <- reads_walker(knitr::knit_global(), keys)
  for (ch in s$chunks) {
    if (!identical(ch$eval, FALSE)) w$add(ch$code)
  }
  es <- ledger_entries(s)
  for (e in es) w$add(as.character(e$expr %||% NA_character_))
  r <- w$result()
  reads <- w$store_exprs()

  # the dictionary entries
  dict_h <- stats::setNames(character(), character())
  if (length(r$keys)) {
    hs <- tryCatch(dict_entry_hashes(file.path(root, "dict.yml")), error = function(e) character())
    dict_h <- stats::setNames(unname(hs[r$keys]), r$keys)
    dict_h[is.na(dict_h)] <- NA_character_
  }

  # the files
  src <- state_source(s, root)
  files <- c(src, unlist(lapply(es, function(e) as.character(e$file))))
  for (ch in s$chunks) files <- c(files, vapply(ch$child, function(p) rel_path(root, p), ""))
  for (p in w$source_files()) {
    files <- c(files, rel_path(root, norm_path(if (is_abs_path(p)) p else file.path(norm_path(getwd()), p))))
  }
  files <- unique(enc2utf8(files[!is.na(files) & nzchar(files)]))
  files <- files[files == src | file.exists(file.path(root, files))]
  files <- sort(files, method = "radix")
  files_h <- stats::setNames(vapply(files, function(f) file_hash(file.path(root, f)), "",
                                    USE.NAMES = FALSE), files)

  # the targets
  installed <- has_targets()
  wd <- norm_path(getwd())
  default_store <- if (installed) {
    tryCatch(targets::tar_config_get("store"), error = function(e) "_targets")
  } else "_targets"
  abs_of <- function(st) norm_path(if (is_abs_path(st)) st else file.path(wd, st))
  default_abs <- abs_of(default_store)
  # a store given as an expression is evaluated here, where the chapter has just run its code
  tg <- data.frame(name = vapply(reads, function(x) x$name, ""),
                   store = vapply(reads, function(x) x$store, ""), stringsAsFactors = FALSE)
  unresolved <- character()
  for (i in seq_along(reads)) {
    if (!is.null(reads[[i]]$expr) && is.na(tg$store[i])) {
      v <- tryCatch(eval(reads[[i]]$expr, knitr::knit_global()), error = function(e) NULL)
      if (is.character(v) && length(v) == 1L && !is.na(v) && nzchar(v)) {
        tg$store[i] <- v
      } else {
        unresolved <- c(unresolved, reads[[i]]$name)
      }
    }
  }
  tg <- unique(tg)
  rownames(tg) <- NULL
  if (length(unresolved)) {
    ledger_warn(sprintf(paste0(
      "weft: the `store` of the read of %s could not be worked out; the read is recorded under the ",
      "default store (rule 7.2.2)."), paste0("`", sort(unique(unresolved), method = "radix"), "`", collapse = ", ")))
  }
  tg$abs <- if (nrow(tg)) vapply(ifelse(is.na(tg$store), default_store, tg$store), abs_of, "") else character()
  tg$rel <- if (nrow(tg)) vapply(tg$abs, function(a) rel_path(root, a), "") else character()
  metas <- list()
  meta_of <- function(abs) {
    if (!installed) return(NULL)
    if (!is.null(metas[[abs]])) return(metas[[abs]])
    m <- if (file.exists(file.path(abs, "meta", "meta"))) {
      tryCatch(as.data.frame(targets::tar_meta(
        store = abs, fields = c("type", "data", "warnings", "error", "parent")),
        stringsAsFactors = FALSE), error = function(e) NULL)
    }
    metas[[abs]] <<- if (is.null(m)) FALSE else m
    metas[[abs]]
  }
  tg_h <- list()
  for (i in seq_len(nrow(tg))) {
    m <- meta_of(tg$abs[i])
    h <- NA_character_
    if (is.data.frame(m)) {
      j <- match(tg$name[i], m$name)
      if (!is.na(j) && !is.na(m$data[j])) h <- as.character(m$data[j])
    }
    tg_h[[tg$rel[i]]][[tg$name[i]]] <- h
  }
  if (length(tg_h)) {
    tg_h <- lapply(tg_h[order(names(tg_h), method = "radix")],
                   function(v) v[order(names(v), method = "radix")])
  }
  reads_chr <- lapply(tg_h, function(v) unlist(v))

  s$reads <- list(dict = dict_h, files = files_h, targets = reads_chr)
  as_obj <- function(v) as.list(v)
  s$ledger_header <- list(
    dict = as_obj(dict_h), files = as_obj(files_h),
    targets = lapply(tg_h, function(v) as.list(unlist(v))))
  if (length(tg_h) == 0L) s$ledger_header$targets <- stats::setNames(list(), character())

  if (installed && nrow(tg)) target_conditions(s, root, tg, default_abs, meta_of)
  invisible()
}

# Lines for the conditions held by the targets read and the targets upstream
# of them (P15, P16).
target_conditions <- function(s, root, tg, default_abs, meta_of) {
  rows <- list()
  seen <- character()
  for (abs in unique(tg$abs)) {
    m <- meta_of(abs)
    if (!is.data.frame(m) || !nrow(m)) next
    set <- unique(tg$name[tg$abs == abs])
    up <- upstream_targets(root, set, abs, if (identical(abs, default_abs)) norm_path(getwd()) else dirname(abs))
    if (!is.null(up$error)) {
      ledger_warn(sprintf(paste0(
        "weft: the targets upstream of %s were not read (%s); the condition log holds the ",
        "conditions of the targets the document reads (rule 7.4.1)."),
        paste(sort(set, method = "radix"), collapse = ", "), up$error))
    } else {
      set <- unique(c(set, up$targets))
    }
    par <- if ("parent" %in% names(m)) m$parent else rep(NA_character_, nrow(m))
    hit <- which(m$name %in% set | (!is.na(par) & par %in% set))
    for (i in hit) {
      source <- if (!is.na(par[i])) par[i] else m$name[i]
      for (cl in c("warning", "error")) {
        txt <- m[[if (cl == "warning") "warnings" else "error"]][i]
        if (is.null(txt) || is.na(txt) || !nzchar(txt)) next
        txt <- as.character(txt)
        norm <- normalise_condition(txt)
        key <- paste(source, cl, norm, sep = "\r")
        if (key %in% seen) next
        seen <- c(seen, key)
        pat <- severity_match(s$config, txt)
        if (!is.null(pat)) {
          add_failure(s, "condition", file = current_file_name(s),
                      detail = sprintf("target %s: %s: %s", source, cl, sub("\n.*$", "", txt)),
                      hint = severity_hint(pat))
        } else {
          rows[[length(rows) + 1L]] <- list(from = "target", source = source, class = cl,
                                           normalised = norm, text = txt)
        }
      }
    }
  }
  if (length(rows)) s$condition_rows <- c(s$condition_rows, rows)
  invisible()
}

# The last line of a condition's message, or of its parent's: `callr` puts the
# cause of an error in a subprocess after its own first line.
condition_cause <- function(e) {
  while (!is.null(e$parent) && inherits(e$parent, "condition")) e <- e$parent
  lines <- trimws(strsplit(conditionMessage(e), "\n", fixed = TRUE)[[1L]])
  lines <- lines[nzchar(lines) & !grepl("^See https?://", lines)]
  if (!length(lines)) return(class(e)[1L])
  sub("^(!|x|Error:)\\s*", "", lines[length(lines)])
}

# Every target upstream of `set`, in the store `store`, whose pipeline is run
# from the folder `dir`: list(targets, error). The edges are kept in
# .weft/targets/network.rds for each store, with the size and modification time
# of its meta/meta file and the script's path, and reused while those match (P16).
upstream_targets <- function(root, set, store, dir) {
  old <- setwd(dir)
  on.exit(setwd(old), add = TRUE)
  script <- tryCatch(targets::tar_config_get("script"), error = function(e) "_targets.R")
  script_abs <- norm_path(if (is_abs_path(script)) script else file.path(dir, script))
  if (!file.exists(script_abs)) {
    return(list(targets = character(),
                error = sprintf("there is no pipeline script at %s", rel_path(root, script_abs))))
  }
  script_rel <- rel_path(root, script_abs)
  skey <- rel_path(root, store)
  mi <- file.info(file.path(store, "meta", "meta"))
  sig <- c(size = mi$size, mtime = as.numeric(mi$mtime))
  cache <- file.path(root, ".weft", "targets", "network.rds")
  all <- if (file.exists(cache)) tryCatch(readRDS(cache), error = function(e) NULL) else NULL
  if (!is.list(all) || !is.list(all$stores)) all <- list(stores = list())
  hit <- all$stores[[skey]]
  edges <- NULL
  if (is.list(hit) && identical(hit$sig, sig) && identical(hit$script, script_rel)) edges <- hit$edges
  if (is.null(edges)) {
    net <- tryCatch(targets::tar_network(targets_only = TRUE, outdated = FALSE, script = script,
                                         store = store),
                    error = function(e) e)
    if (inherits(net, "error")) {
      return(list(targets = character(), error = condition_cause(net)))
    }
    edges <- as.data.frame(net$edges, stringsAsFactors = FALSE)
    if (!all(c("from", "to") %in% names(edges))) edges <- data.frame(from = character(), to = character())
    all$stores[[skey]] <- list(sig = sig, script = script_rel, edges = edges)
    tryCatch({
      weft_state_dir(root, "targets")
      write_rds_atomic(all, cache)
    }, error = function(e) NULL, warning = function(w) NULL)
  }
  up <- character()
  todo <- set
  while (length(todo)) {
    nxt <- unique(edges$from[edges$to %in% todo])
    nxt <- setdiff(nxt, c(up, set))
    up <- c(up, nxt)
    todo <- nxt
  }
  list(targets = up, error = NULL)
}
