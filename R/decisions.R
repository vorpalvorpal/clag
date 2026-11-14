# The `decisions:` setting and the resolver behind `decision:` (rules 4.5.1-4.5.4,
# 9.1.8). Contract: dev/design-2c.md "The decision: resolver".

DECISIONS_FORMS <- paste0(
  "`github`, `github:<owner>/<repo>`, a file pattern holding `{id}` ",
  "(as decisions/{id}-*.md), or a function written pkg::fun")

# What the setting `decisions` asks for, as list(kind = "github" | "glob" |
# "function", ...), or a weft_config_error (rule 9.1.8).
decisions_route <- function(resolver) {
  is_one <- is.character(resolver) && length(resolver) == 1L && !is.na(resolver)
  if (is_one) {
    if (identical(resolver, "github")) return(list(kind = "github", owner = NULL, repo = NULL))
    m <- regmatches(resolver, regexec("^github:([A-Za-z0-9-]+)/([A-Za-z0-9._-]+)$", resolver))[[1L]]
    if (length(m) == 3L) return(list(kind = "github", owner = m[2L], repo = m[3L]))
    if (grepl("{id}", resolver, fixed = TRUE)) return(list(kind = "glob", pattern = resolver))
    # the route's own name in another letter case is a slip, not a function
    if (grepl("^github(:|$)", resolver, ignore.case = TRUE)) {
      weft_abort(sprintf(paste0("The setting `decisions` must be %s; got `%s`: did you mean `%s`? ",
                                "The route names are written in lower case (rule 9.1.8)."),
                         DECISIONS_FORMS, resolver,
                         sub("^github", "github", resolver, ignore.case = TRUE)),
                 "weft_config_error")
    }
    if (grepl("^[A-Za-z.][A-Za-z0-9._]*$", resolver) ||
        grepl("^[A-Za-z.][A-Za-z0-9.]*::[A-Za-z.][A-Za-z0-9._]*$", resolver)) {
      return(list(kind = "function", fun = resolver))
    }
  }
  got <- if (is_one) resolver else paste(deparse(resolver, width.cutoff = 500L), collapse = " ")
  weft_abort(sprintf("The setting `decisions` must be %s; got `%s` (rule 9.1.8).",
                     DECISIONS_FORMS, got), "weft_config_error")
}

has_curl <- function() requireNamespace("curl", quietly = TRUE)

# The owner and repository of a github.com remote URL, or NULL. The host may be
# in any letter case, and ssh.github.com is GitHub too; a repository name is
# letters, digits, `.`, `_` and `-`.
parse_github_remote <- function(url) {
  if (!is.character(url) || length(url) != 1L || is.na(url)) return(NULL)
  own <- "([A-Za-z0-9-]+)/([A-Za-z0-9._-]+?)(?:\\.git)?/?$"
  rx <- c(paste0("^https?://(?:[^/@]+@)?(?:www\\.)?(?i:github\\.com)(?::[0-9]+)?/", own),
          paste0("^[A-Za-z0-9_-]+@(?i:github\\.com):", own),
          paste0("^ssh://(?:[A-Za-z0-9_-]+@)?(?i:(?:ssh\\.)?github\\.com)(?::[0-9]+)?/", own))
  for (r in rx) {
    m <- regmatches(url, regexec(r, url, perl = TRUE))[[1L]]
    if (length(m) == 3L && nzchar(m[2L]) && nzchar(m[3L])) return(c(owner = m[2L], repo = m[3L]))
  }
  NULL
}

# One GET of the GitHub API. The only code in weft that touches the network.
# list(status = <integer or NA>, error = <NULL or string>).
github_fetch <- function(url, token) {
  if (!has_curl()) {
    return(list(status = NA_integer_,
                error = "the curl package is not installed; install.packages(\"curl\")"))
  }
  h <- curl::new_handle()
  hdr <- c(Accept = "application/vnd.github+json", `User-Agent` = "weft (R package)",
           `X-GitHub-Api-Version` = "2022-11-28")
  if (!is.null(token)) hdr[["Authorization"]] <- paste("Bearer", token)
  do.call(curl::handle_setheaders, c(list(h), as.list(hdr)))
  curl::handle_setopt(h, timeout = 10L, followlocation = TRUE)
  tryCatch({
    res <- curl::curl_fetch_memory(url, h)
    list(status = as.integer(res$status_code), error = NULL)
  }, error = function(e) list(status = NA_integer_, error = conditionMessage(e)))
}

#' Check the `decision:` pointers of a dictionary
#'
#' Internal: `verify()` will call it. One row for every entry that has a
#' `decision`.
#'
#' @param dict A `weft_dict`.
#' @param resolver The `decisions` setting as a string, or `NULL` to read it
#'   from `_weft.yml` at `root` (default `"github"`).
#' @param root The project root, or `NULL` for the root of the dictionary's file.
#' @param fetch A function of a URL and a token that returns
#'   `list(status, error)`.
#' @return A data frame: `file`, `line`, `key`, `decision`, `resolved` (`TRUE`,
#'   `FALSE`, or `NA` for could not check) and `detail`.
#' @noRd
check_decisions <- function(dict, resolver = NULL, root = NULL, fetch = github_fetch) {
  e <- attr(dict, "entries")
  has <- !is.na(e$decision)
  out <- data.frame(file = rep(as.character(attr(dict, "file")), sum(has)),
                    line = as.integer(e$line[has]), key = e$key[has],
                    decision = e$decision[has], resolved = rep(NA, sum(has)),
                    detail = rep("", sum(has)), stringsAsFactors = FALSE)
  if (is.null(root)) root <- find_project_root(attr(dict, "file"))
  if (is.null(resolver)) {
    f <- file.path(root, "_weft.yml")
    resolver <- "github"
    if (file.exists(f)) {
      proj <- tryCatch(yaml_read_file(f), error = function(e) {
        weft_abort(paste0("Cannot read ", f, ": ", conditionMessage(e)), "weft_config_error")
      })
      if (is.list(proj) && "decisions" %in% names(proj) && !is.null(proj$decisions)) {
        resolver <- proj$decisions
      }
    }
  }
  route <- decisions_route(resolver)
  if (!nrow(out)) return(out)
  decisions_resolve(out, route, root, fetch)
}

# Resolve the pointers of a table with a `decision` column by one route, each distinct pointer once (N104):
# the table with `resolved` and `detail` filled in.
decisions_resolve <- function(out, route, root, fetch = github_fetch) {
  ptr <- unique(out$decision)
  res <- switch(route$kind,
    github = decisions_github(ptr, route, root, fetch),
    glob = decisions_glob(ptr, route$pattern, root),
    `function` = decisions_function(ptr, route$fun))
  i <- match(out$decision, ptr)
  out$resolved <- res$resolved[i]
  out$detail <- res$detail[i]
  out
}

decisions_github <- function(ptr, route, root, fetch) {
  n <- length(ptr)
  resolved <- rep(FALSE, n)
  detail <- sprintf("`%s` is not an issue number; the github resolver takes whole numbers (rule 4.5.3)", ptr)
  num <- grepl("^[1-9][0-9]{0,9}$", ptr)
  num[num] <- as.numeric(ptr[num]) <= .Machine$integer.max
  if (!any(num)) return(list(resolved = resolved, detail = detail))
  fail <- function(msg) {
    resolved[num] <<- NA
    detail[num] <<- paste0("could not check: ", msg)
  }
  gone <- function() list(resolved = resolved, detail = detail)
  # 1. the repository
  none <- function(why) sprintf(
    "no GitHub repository (%s); set decisions: github:<owner>/<repo> in _weft.yml", why)
  if (!is.null(route$owner)) {
    repo <- c(owner = route$owner, repo = route$repo)
  } else if (!nzchar(git_path())) {
    fail(none("git is not installed")); return(gone())
  } else {
    # the remote of a repository that is the project's own, not of one that holds it
    top <- git_lines(root, c("rev-parse", "--show-toplevel"))
    if (length(top)) {
      top <- normalizePath(top[1L], mustWork = FALSE)
      here <- normalizePath(root, mustWork = FALSE)
      if (!identical(top, here) && !startsWith(top, paste0(sub("/+$", "", here), "/"))) {
        fail(none("the git repository above the project belongs to another project")); return(gone())
      }
    }
    url <- git_lines(root, c("remote", "get-url", "origin"))
    if (!length(url)) {
      fail(none("no git remote `origin`")); return(gone())
    }
    repo <- parse_github_remote(url[1L])
    if (is.null(repo)) {
      fail(none("the remote `origin` is not on github.com")); return(gone())
    }
  }
  o <- repo[["owner"]]; r <- repo[["repo"]]
  # 2. the token
  var <- NULL
  token <- NULL
  for (v in c("GITHUB_PAT", "GITHUB_TOKEN")) {
    if (nzchar(Sys.getenv(v))) { var <- v; token <- Sys.getenv(v); break }
  }
  one_line <- function(x) trimws(gsub("[[:space:]]+", " ", x))
  # one request: whatever `fetch` does, the answer is list(status, error), and
  # the token is never in the text of an error
  call <- function(url) {
    a <- tryCatch(fetch(url, token), error = function(e) {
      list(status = NA_integer_, error = paste0("the request failed: ", conditionMessage(e)))
    })
    st <- if (is.list(a)) suppressWarnings(as.integer(a$status)) else NULL
    if (!is.list(a) || length(st) != 1L) {
      return(list(status = NA_integer_, error = "the request gave an answer weft cannot read"))
    }
    err <- a$error
    err <- if (is.character(err) && length(err) >= 1L && !is.na(err[1L])) one_line(err[1L]) else NULL
    if (!is.null(err) && !is.null(token)) err <- gsub(token, "<token>", err, fixed = TRUE)
    list(status = st, error = err)
  }
  refused <- function(st, err, repo_call) {
    if (is.na(st)) return(sprintf("GitHub could not be reached (%s)", err %||% "no answer"))
    if (st == 404L && repo_call) {
      return(if (is.null(token)) sprintf(
        "%s/%s is not visible (private without a token, or misnamed); set GITHUB_PAT", o, r)
        else sprintf("%s/%s is not visible with the token in %s", o, r, var))
    }
    if (st == 401L) {
      return(if (is.null(token)) "GitHub answered 401, though no token was sent; set GITHUB_PAT"
             else sprintf("GitHub refused the token in %s (401)", var))
    }
    if (st == 410L) {
      return(sprintf(paste0("GitHub answered 410: issues are turned off for %s/%s (as in a fork); ",
                            "set decisions: github:<owner>/<repo> in _weft.yml to name the repository that has them"),
                     o, r))
    }
    if (st %in% c(403L, 429L)) {
      return(if (is.null(token)) sprintf(paste0(
        "GitHub refused the request (%d), usually its limit of 60 requests an hour ",
        "without a token; set GITHUB_PAT"), st)
        else sprintf("GitHub refused the request (%d) with the token in %s", st, var))
    }
    sprintf("GitHub answered %d", st)
  }
  base <- sprintf("https://api.github.com/repos/%s/%s", o, r)
  # 3, 4. the repository, then each number
  a <- call(base)
  if (!identical(a$status, 200L)) {
    fail(refused(a$status, a$error, TRUE)); return(gone())
  }
  for (k in which(num)) {
    a <- call(paste0(base, "/issues/", ptr[k]))
    st <- a$status
    if (identical(st, 200L)) {
      resolved[k] <- TRUE
      detail[k] <- sprintf("%s/%s#%s exists", o, r, ptr[k])
    } else if (identical(st, 404L)) {
      resolved[k] <- FALSE
      detail[k] <- sprintf("%s/%s has no issue or pull request #%s", o, r, ptr[k])
    } else {
      later <- num & seq_len(n) >= k
      resolved[later] <- NA
      detail[later] <- paste0("could not check: ", refused(st, a$error, FALSE))
      break
    }
  }
  list(resolved = resolved, detail = detail)
}

decisions_glob <- function(ptr, pattern, root) {
  n <- length(ptr)
  resolved <- rep(FALSE, n)
  detail <- character(n)
  root <- sub("/+$", "", root)
  # a relative pattern is a pattern after the root: the glob runs in the root, so
  # that no character of the root's own path is read as a pattern character
  absolute <- grepl("^(/|~|[A-Za-z]:[/\\\\])", pattern)
  if (!absolute) {
    owd <- tryCatch(setwd(root), error = function(e) NULL)
    if (is.null(owd)) {
      detail[] <- "the project folder cannot be entered"
      return(list(resolved = resolved, detail = detail))
    }
    on.exit(setwd(owd), add = TRUE)
  }
  rootn <- normalizePath(root, mustWork = FALSE)
  inside <- function(p) {
    np <- normalizePath(p, mustWork = FALSE)
    startsWith(np, paste0(rootn, "/"))
  }
  for (k in seq_len(n)) {
    if (grepl("[*?/\\\\]|\\[|\\]", ptr[k])) {
      detail[k] <- sprintf("`%s` holds a character a file pattern cannot match literally (* ? [ ] / \\)", ptr[k])
      next
    }
    pat <- gsub("{id}", ptr[k], pattern, fixed = TRUE)
    hits <- Sys.glob(if (absolute) pat else paste0("./", pat))
    if (!absolute) hits <- sub("^\\./", "", hits)
    # a file, not a folder or a dangling link, and inside the project
    hits <- hits[file.exists(hits) & !dir.exists(hits)]
    hits <- hits[vapply(hits, inside, NA)]
    if (!length(hits)) {
      detail[k] <- paste("no file matches", pat)
      next
    }
    hits <- sort(hits, method = "radix")
    first <- rel_to(hits[1L], root)
    resolved[k] <- TRUE
    detail[k] <- if (length(hits) > 1L) sprintf("%s and %d more", first, length(hits) - 1L) else first
  }
  list(resolved = resolved, detail = detail)
}

decisions_function <- function(ptr, fun) {
  fn <- tryCatch({
    if (grepl("::", fun, fixed = TRUE)) {
      parts <- strsplit(fun, "::", fixed = TRUE)[[1L]]
      get(parts[2L], envir = asNamespace(parts[1L]), mode = "function")
    } else get(fun, envir = globalenv(), mode = "function", inherits = FALSE)
  }, error = function(e) NULL)
  if (is.null(fn)) {
    weft_abort(sprintf("Cannot find the decisions function `%s` (rule 9.1.8).", fun),
               "weft_config_error")
  }
  n <- length(ptr)
  resolved <- rep(NA, n)
  detail <- character(n)
  for (k in seq_len(n)) {
    v <- tryCatch(fn(ptr[k]), error = function(e) e)
    if (inherits(v, "error")) {
      msg <- trimws(sub("\n.*$", "", trimws(conditionMessage(v))))
      detail[k] <- if (nzchar(msg)) sprintf("could not check: %s failed: %s", fun, msg)
                   else sprintf("could not check: %s failed with an empty message", fun)
    } else if (is.logical(v) && length(v) == 1L && !is.na(v)) {
      resolved[k] <- v
      detail[k] <- sprintf("%s returned %s", fun, if (v) "TRUE" else "FALSE")
    } else if (is.logical(v) && length(v) == 1L) {
      detail[k] <- sprintf("could not check: %s returned NA", fun)
    } else {
      what <- if (is.null(v)) "NULL" else {
        cls <- class(v)[1L]
        sprintf("%s %s of length %d", if (grepl("^[AEIOUaeiou]", cls)) "an" else "a", cls, length(v))
      }
      detail[k] <- sprintf("could not check: %s returned %s, not TRUE, FALSE or NA", fun, what)
    }
  }
  list(resolved = resolved, detail = detail)
}
