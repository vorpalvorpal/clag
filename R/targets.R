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
# character vector of lines of code; `result()` is what `code_reads()` returns.
reads_walker <- function(envir = globalenv(), keys = character()) {
  keys <- as.character(keys)
  st <- new.env(parent = emptyenv())
  st$keys <- character()
  st$all <- FALSE
  st$unknown <- character()
  st$tname <- character()
  st$tstore <- character()
  st$seen <- character()

  add_key <- function(k) {
    if (k %in% keys) st$keys <- c(st$keys, k) else st$unknown <- c(st$unknown, k)
  }
  lit_chr <- function(e) if (is.character(e) && length(e) == 1L && !is.na(e)) e else NULL

  follow <- function(nm) {
    if (nm %in% st$seen) return(invisible())
    f <- get0(nm, envir = envir, inherits = FALSE, mode = "function")
    if (!is.function(f) || is.primitive(f)) return(invisible())
    st$seen <- c(st$seen, nm)
    walk(formals(f))
    walk(body(f))
    invisible()
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
    names_found <- character()
    if (!is.na(i)) {
      v <- args[[i]]
      one <- function(e) {
        l <- lit_chr(e)
        if (!is.null(l)) return(l)
        if (!raw && is.symbol(e) && nzchar(as.character(e))) return(as.character(e))
        NULL
      }
      names_found <- if (is.call(v) && identical(v[[1L]], quote(c))) {
        unlist(lapply(as.list(v)[-1L], one))
      } else {
        one(v)
      }
    }
    store <- NA_character_
    j <- which(an == "store")[1L]
    if (!is.na(j)) {
      l <- lit_chr(args[[j]])
      if (!is.null(l)) store <- l
    }
    for (nm in as.character(names_found)) {
      st$tname <- c(st$tname, nm)
      st$tstore <- c(st$tstore, store)
    }
    rest <- args[setdiff(seq_along(args), i)]
    for (a in rest) if (!missing(a)) walk(a)
    invisible()
  }

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
    tg <- unique(data.frame(name = as.character(st$tname), store = as.character(st$tstore),
                            stringsAsFactors = FALSE))
    rownames(tg) <- NULL
    list(keys = if (st$all) sort(unique(keys), method = "radix") else
           sort(unique(st$keys), method = "radix"),
         all = st$all,
         unknown = sort(unique(st$unknown), method = "radix"),
         targets = tg)
  }
  list(add = add, result = result)
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
      "weft: `dict` is an object in the pipeline's environment, so targets tracks it and every ",
      "target that reads it re-runs when any entry changes, its definition included. Remove ",
      "`dict <- ...` from _targets.R: tar_dict() provides `dict` (rule 4.6.3)."))
  }
  invisible()
}

#' Targets for a project dictionary
#'
#' `tar_dict()` makes a `targets` pipeline depend on the entries of `dict.yml`
#' it reads, and on nothing else in the file. It returns the targets
#' `dict_file` (the file) and `dict_<key>` (the value of each entry, as
#' [read_dict()] reads it), and attaches the dictionary as the object `dict` on
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
  while ("weft:dict" %in% search()) detach("weft:dict", character.only = TRUE)
  env <- new.env(parent = emptyenv())
  assign("dict", d, envir = env)
  get("attach", envir = baseenv())(env, name = "weft:dict", pos = 2L, warn.conflicts = FALSE)
  out <- list(targets::tar_target_raw("dict_file", path, format = "file"))
  for (k in names(d)) {
    out[[length(out) + 1L]] <- targets::tar_target_raw(
      paste0("dict_", k), bquote(weft::read_dict(dict_file)[[.(k)]]))
  }
  out
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
#' 4.6.5). A key that the dictionary does not hold is an error that lists every
#' target that reads one (rule 4.6.4).
#'
#' See [tar_dict()] for the limit with `crew` workers: the dictionary is not
#' visible to a parallel worker.
#'
#' @param targets A target object, or a list of target objects and lists,
#'   nested to any depth.
#' @param path The dictionary file, as given to [tar_dict()].
#' @return `targets`, in the same structure. The target objects are changed in
#'   place.
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
  own <- c("dict_file", paste0("dict_", keys))
  bad <- list()
  for (t in flat) {
    nm <- t$settings$name
    if (nm %in% own) next
    rep <- report_files(t)
    found <- character()
    if (!is.null(rep)) {
      for (f in rep) {
        if (!file.exists(f)) {
          pipeline_abort(sprintf(
            "weft: `%s` names the source %s, which does not exist (rule 4.6.5).", nm, f))
        }
        if (dir.exists(f) || !grepl("\\.(qmd|Rmd|rmd)$", f)) next
        r <- report_reads(f, envir, keys)
        found <- c(found, r$keys)
        for (u in r$unknown) bad[[length(bad) + 1L]] <- list(target = nm, file = f, key = u)
      }
    } else {
      r <- code_reads(t$command$expr, envir, keys)
      found <- r$keys
      for (u in r$unknown) bad[[length(bad) + 1L]] <- list(target = nm, file = NA_character_, key = u)
    }
    found <- sort(unique(found), method = "radix")
    if (length(found)) t$deps <- union(t$deps, paste0("dict_", found))
  }
  if (length(bad)) {
    lines <- vapply(bad, function(b) {
      d <- as.vector(utils::adist(b$key, keys))
      hint <- if (length(d) && min(d) <= 2L && sum(d == min(d)) == 1L) {
        sprintf(" Did you mean `%s`?", keys[which.min(d)])
      } else ""
      sprintf("  `%s`%s reads `dict$%s`, which %s does not hold (rule 4.6.4).%s", b$target,
              if (is.na(b$file)) "" else paste0(" (", b$file, ")"), b$key, path, hint)
    }, "")
    pipeline_abort(paste(c(sprintf("weft: %s: %d unknown key(s) read by the pipeline", path, length(bad)),
                           lines), collapse = "\n"))
  }
  targets
}

flatten_targets <- function(x) {
  if (inherits(x, "tar_target")) return(list(x))
  if (is.list(x) && !is.data.frame(x)) return(unlist(lapply(x, flatten_targets), recursive = FALSE))
  pipeline_abort(paste0("weft: `targets` must be a target or a list of targets, nested to any depth ",
                        "(rule 4.6.2)."))
}

# The source files of a report target (a `tar_quarto()` or `tar_render()`
# target), or NULL for any other target (P10).
report_files <- function(t) {
  ex <- t$command$expr
  if (length(ex) != 1L || !is.call(ex[[1L]])) return(NULL)
  cmd <- ex[[1L]]
  h <- paste(deparse(cmd[[1L]]), collapse = "")
  if (identical(h, "tarchetypes::tar_quarto_run")) {
    s <- tryCatch(eval(cmd[["sources"]], baseenv()), error = function(e) NULL)
    if (is.character(s)) return(s)
  } else if (identical(h, "tarchetypes::tar_render_run")) {
    p <- cmd[["path"]]
    if (is.character(p) && length(p) == 1L) return(p)
  }
  NULL
}

# What the R code of one document reads: the code of every chunk that is not
# `eval: false`, inline R in prose and front matter, and the code of
# constructs (P10).
report_reads <- function(path, envir, keys) {
  w <- reads_walker(envir, keys)
  lines <- tryCatch(read_view_lines(path), error = function(e) character())
  if (length(lines)) {
    for (pc in tryCatch(seed_chunks(lines), error = function(e) list())) {
      w$add(paste(pc$code, collapse = "\n"))
    }
    rows <- tryCatch(scan_document(lines, file = path, config = NULL, project = ""),
                     error = function(e) NULL)
    if (!is.null(rows) && nrow(rows)) {
      for (x in c(rows$expr, unlist(rows$keys))) if (!is.na(x)) w$add(as.character(x))
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
  keys <- names(s$dict)
  if (is.null(keys)) keys <- character()
  w <- reads_walker(knitr::knit_global(), keys)
  for (ch in s$chunks) {
    if (!identical(ch$eval, FALSE)) w$add(ch$code)
  }
  es <- ledger_entries(s)
  for (e in es) w$add(as.character(e$expr %||% NA_character_))
  r <- w$result()

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
  tg <- r$targets
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
    if (identical(abs, default_abs)) {
      up <- upstream_targets(root, set)
      if (!is.null(up$error)) {
        ledger_warn(sprintf(paste0(
          "weft: the targets upstream of %s were not read (%s); the condition log holds the ",
          "conditions of the targets the document reads (rule 7.4.1)."),
          paste(sort(set, method = "radix"), collapse = ", "), up$error))
      } else {
        set <- unique(c(set, up$targets))
      }
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

# Every target upstream of `set`: list(targets, error). The edges are kept in
# .weft/targets/network.rds with the run id and the script's path, and reused
# while both match (P16).
upstream_targets <- function(root, set) {
  script <- tryCatch(targets::tar_config_get("script"), error = function(e) "_targets.R")
  script_rel <- rel_path(root, norm_path(if (is_abs_path(script)) script else file.path(getwd(), script)))
  id <- run_id(root)
  cache <- file.path(root, ".weft", "targets", "network.rds")
  edges <- NULL
  if (nzchar(id) && file.exists(cache)) {
    old <- tryCatch(readRDS(cache), error = function(e) NULL)
    if (is.list(old) && identical(old$run, id) && identical(old$script, script_rel)) edges <- old$edges
  }
  if (is.null(edges)) {
    net <- tryCatch(targets::tar_network(targets_only = TRUE, outdated = FALSE, script = script),
                    error = function(e) e)
    if (inherits(net, "error")) {
      return(list(targets = character(), error = sub("\n.*$", "", conditionMessage(net))))
    }
    edges <- as.data.frame(net$edges, stringsAsFactors = FALSE)
    if (!all(c("from", "to") %in% names(edges))) edges <- data.frame(from = character(), to = character())
    if (nzchar(id)) {
      tryCatch({
        dir.create(dirname(cache), showWarnings = FALSE, recursive = TRUE)
        saveRDS(list(run = id, script = script_rel, edges = edges), cache)
      }, error = function(e) NULL, warning = function(w) NULL)
    }
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
