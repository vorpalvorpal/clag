# Helpers for the 4d tests (use_setup(), the .Rprofile route, the filter under
# rmarkdown). They sit beside helper-render.R and helper-quarto.R and use
# weft_test_lib(), weft_filter_path(), skip_if_no_quarto(), skip_if_no_pandoc(),
# tree() and put_files(); nothing here edits them.
#
#   u4_dir()          a fresh, normalised temp project holding `files`
#   u4_use()          use_setup() with its messages dropped (returns its value)
#   u4_says()         what use_setup() says (messages and printed output)
#   u4_md5()          md5 of every file of a tree, named by relative path
#   u4_front()        the front matter lines of a document
#   u4_yaml()         the front matter parsed (the !expr tag is kept as text)
#   u4_rel()          paths returned by an installer, relative to the root
#   u4_env()          the environment of a fresh, isolated child process
#   u4_r()            Rscript -e in a directory, isolated
#   u4_render_rmd()   rmarkdown::render() of one document in a fresh process
#   u4_qrender()      quarto render in a directory, isolated

# ---- expected texts (G35, G36) ----------------------------------------------

U4_RPROFILE <- c(
  "# weft: activates weft in every knit of this project (weft::use_setup(), rule 9.2.1).",
  "# R reads this file instead of your ~/.Rprofile; the next line keeps yours.",
  "if (file.exists(\"~/.Rprofile\")) source(\"~/.Rprofile\")",
  "if (requireNamespace(\"weft\", quietly = TRUE)) weft::weft_setup()"
)
U4_ACTIVATE <- U4_RPROFILE[4]
U4_OPTS_KNIT <- c("knitr:", "  opts_knit:", "    weft: !expr weft::weft_setup()")
U4_FILTER_ARGS <- "pandoc_args: [\"--lua-filter\", \"weft.lua\", \"--lua-filter\", \"weft-check.lua\"]"
U4_LUA_ARGS <- c("--lua-filter", "weft.lua", "--lua-filter", "weft-check.lua")
U4_QUARTO_YML <-c("project:", "  type: default", "format: html")

u4_version <- function() as.character(utils::packageVersion("weft"))

# ---- projects ---------------------------------------------------------------

u4_dir <- function(files = list(), base = NULL) {
  if (is.null(base)) base <- tempfile("weft-4d-")
  dir.create(base, showWarnings = FALSE, recursive = TRUE)
  base <- normalizePath(base)
  put_files(base, files)
  base
}

u4_use <- function(dir, ...) {
  suppressMessages(utils::capture.output(res <- weft::use_setup(dir, ...)))
  res
}

# everything use_setup() says: messages and printed output, in order. `hook`
# runs at the first message (to look at the disk before anything is written).
u4_says <- function(dir, ..., hook = NULL) {
  txt <- character()
  out <- utils::capture.output(
    withCallingHandlers(
      weft::use_setup(dir, ...),
      message = function(m) {
        if (!is.null(hook) && !length(txt)) hook()
        txt <<- c(txt, conditionMessage(m))
        invokeRestart("muffleMessage")
      }
    )
  )
  paste(c(txt, out), collapse = "\n")
}

u4_md5 <- function(dir) {
  f <- tree(dir)
  if (!length(f)) return(structure(character(), names = character()))
  structure(unname(tools::md5sum(file.path(dir, f))), names = f)
}

u4_read <- function(dir, f) readLines(file.path(dir, f), warn = FALSE)

# the lines between the first two `---` lines
u4_front <- function(path) {
  x <- readLines(path, warn = FALSE)
  d <- which(trimws(x) == "---")
  if (length(d) < 2L || d[1] != 1L) return(character())
  x[seq_len(d[2] - 1L)[-1]]
}

u4_yaml <- function(path) {
  yaml::yaml.load(paste(u4_front(path), collapse = "\n"),
                  handlers = list(expr = function(x) paste0("!expr ", x)))
}

# does `needle` (a character vector) occur as consecutive elements of `x`?
u4_has_run <- function(x, needle) {
  n <- length(needle)
  if (length(x) < n) return(FALSE)
  any(vapply(seq_len(length(x) - n + 1L), function(i) {
    identical(x[i:(i + n - 1L)], needle)
  }, NA))
}

# paths an installer returned, relative to `root` (it may return either)
u4_rel <- function(paths, root) {
  pre <- paste0(normalizePath(root), "/")
  rel <- vapply(as.character(paths), function(p) {
    if (grepl("^(/|[A-Za-z]:)", p)) p <- normalizePath(p, mustWork = FALSE)
    if (startsWith(p, pre)) substring(p, nchar(pre) + 1L) else p
  }, "")
  unname(rel)
}

# ---- a fresh, isolated child process ---------------------------------------
#
# R reads ./.Rprofile only when R_PROFILE_USER is unset, so the child must NOT
# have it set (G37), not even to an empty file. The real ~/.Rprofile is kept
# out by pointing HOME at a temp folder (which may hold a marker profile).

# libraries holding no weft (for the "weft is not installed" case); NULL when
# that cannot be arranged here
u4_libs_without_weft <- function() {
  l <- .libPaths()
  l <- l[!dir.exists(file.path(l, "weft"))]
  if (!any(dir.exists(file.path(l, "rmarkdown")))) return(NULL)
  l
}

u4_home <- function(profile = NULL) {
  h <- normalizePath(tempfile("weft-4d-home-"), mustWork = FALSE)
  dir.create(h)
  h <- normalizePath(h)
  if (!is.null(profile)) writeLines(profile, file.path(h, ".Rprofile"))
  h
}

u4_env <- function(home, with_weft = TRUE, extra = NULL) {
  empty <- tempfile("weft-4d-lib-"); dir.create(empty)
  libs <- if (with_weft) {
    lib <- weft_test_lib()
    c(if (nzchar(lib)) lib, .libPaths())
  } else {
    u4_libs_without_weft()
  }
  env <- c(
    HOME = home,
    R_PROFILE_USER = NA, R_PROFILE = NA, R_ENVIRON_USER = NA,
    R_LIBS = paste(libs, collapse = .Platform$path.sep),
    R_LIBS_USER = empty, R_LIBS_SITE = empty,
    R_USER_CACHE_DIR = tempfile("weft-4d-cache-"),
    WEFT_DRAFT = NA, WEFT_COLLECT = NA, WEFT_RUN = NA,
    NO_COLOR = "1"
  )
  for (n in names(extra)) env[[n]] <- extra[[n]]
  env
}

# Rscript -e <expr> started in `dir`, so R reads the project .Rprofile.
# Returns list(status, out) (out is stdout and stderr together).
u4_r <- function(dir, expr, env = u4_env(u4_home())) {
  withr::local_envvar(env)
  withr::local_dir(dir)
  out <- suppressWarnings(system2(
    file.path(R.home("bin"), "Rscript"), c("-e", shQuote(expr)),
    stdout = TRUE, stderr = TRUE
  ))
  st <- attr(out, "status")
  list(status = if (is.null(st)) 0L else st, out = paste(out, collapse = "\n"))
}

# rmarkdown::render(file) in a fresh process started in `dir`. Returns
# status, log, and `md` (the .md written beside the document, "" when none).
u4_render_rmd <- function(dir, file = "doc.Rmd", env = u4_env(u4_home())) {
  skip_if_no_pandoc()
  r <- u4_r(dir, sprintf("rmarkdown::render('%s', quiet = TRUE)", file), env)
  out <- file.path(dir, sub("\\.[Rr]md$", ".md", file))
  list(status = r$status, failed = r$status != 0L, log = r$out,
       # pandoc writes a marker's angle brackets escaped: undo that
       md = if (file.exists(out)) {
         gsub("\\\\([<>])", "\\1",
              paste(readLines(out, warn = FALSE, encoding = "UTF-8"), collapse = "\n"))
       } else "")
}

u4_qrender <- function(dir, args = character(), env = u4_env(u4_home())) {
  skip_if_no_quarto()
  withr::local_envvar(env)
  withr::local_dir(dir)
  log <- suppressWarnings(system2(Sys.which("quarto"), c("render", args),
                                  stdout = TRUE, stderr = TRUE))
  st <- attr(log, "status")
  list(status = if (is.null(st)) 0L else st, log = paste(log, collapse = "\n"))
}

u4_html <- function(dir, name) {
  f <- file.path(dir, paste0(name, ".html"))
  if (!file.exists(f)) return("")
  paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

# ---- documents --------------------------------------------------------------

# Never calls weft_setup(): values are formatted only when something outside
# the document activates weft.
U4_BODY <- c(
  "```{r setup, include=FALSE}",
  "depth <- 12.5",
  "k <- 1",
  "```",
  "",
  "Depth is `r depth`{.num} here.",
  "",
  "Found [one site | # sites]{n=\"k\"} here."
)
U4_CLAIM_FAIL <- c("", "The value `r claim(k, . > 100)` is claimed.")

u4_rmd <- function(front = c("title: \"t\"", "output:", "  md_document:",
                             "    variant: markdown"),
                   body = U4_BODY) {
  c("---", front, "---", "", body)
}

u4_qmd <- function(body = U4_BODY, title = "t", engine = FALSE) {
  c("---", sprintf("title: \"%s\"", title), if (engine) "engine: knitr", "---", "", body)
}

u4_quarto_project <- function(files = list()) {
  dir <- u4_dir(c(list(`_quarto.yml` = U4_QUARTO_YML), files))
  # the Quarto side (filter extension, pre/post-render scripts) as an author has it
  suppressMessages(utils::capture.output(weft::use_quarto(dir)))
  dir
}

u4_n <- function(pattern, x) {
  m <- gregexpr(pattern, x, fixed = TRUE)[[1]]
  if (identical(m[1], -1L)) 0L else length(m)
}
