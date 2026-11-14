# Stage 8, G1 (dev/design-8.md GN1, GN4, GN5): ONE table of cases for the setting `chunk_claims`, run
# against the four places that read it, so that they cannot drift. The table is
# _conformance/chunk-claims.tsv; its columns:
#   case      a name (it is also the name of the case's folder)
#   weft_yml  the text of the project's _weft.yml ("" for none); \n is a newline and \r a carriage return
#   front     the whole text of the document doc.qmd ("" for a document with no front matter and the
#             body "Text."), written the same way
#   want      stop or collect: what a reader that accepts the value returns (GN4); for a row whose
#             `problem` is yes, the value the default stands in for
#   problem   yes when the value is not stop or collect: R stops with E30 (GN1, N70), the Lua config
#             reports a problem (E33, what = "stop or collect") and uses the default (GN5), and the two
#             guest readers return stop (GN4)
# The case yml-two-folders-up puts _weft.yml two folders above the document; every other case has the
# document and the file in one folder.
# The readers: R's read_config() (and read_front_matter()), weftlib/config.lua's config.load() driven
# through `pandoc lua`, Python's weft._config.chunk_claims(source, folder), and Julia's
# Weft.chunk_claims_setting(source, folder). Each has its own test_that, with its own skip.
# ASCII only.

.tcc <- new.env()

tcc_unesc <- function(x) gsub("\\n", "\n", gsub("\\r", "\r", x, fixed = TRUE), fixed = TRUE)

tcc_table <- function() {
  if (!is.null(.tcc$table)) return(.tcc$table)
  p <- test_path("_conformance", "chunk-claims.tsv")
  testthat::expect(file.exists(p), paste("the committed set is missing:", p))
  d <- utils::read.delim(p, header = TRUE, sep = "\t", quote = "", comment.char = "", colClasses = "character",
                         na.strings = character(), check.names = FALSE, stringsAsFactors = FALSE,
                         encoding = "UTF-8", fileEncoding = "UTF-8", blank.lines.skip = FALSE)
  d$weft_yml <- tcc_unesc(d$weft_yml)
  d$front <- tcc_unesc(d$front)
  .tcc$table <- d
  d
}

# writes every case under one temporary folder; returns the table with root, docdir and doc (paths)
tcc_projects <- function(env = parent.frame()) {
  d <- tcc_table()
  base <- withr::local_tempdir(.local_envir = env)
  base <- normalizePath(base, winslash = "/")
  put <- function(path, text) {
    dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
    con <- file(path, "wb")
    writeBin(charToRaw(enc2utf8(text)), con)
    close(con)
  }
  d$root <- file.path(base, d$case)
  d$docdir <- ifelse(d$case == "yml-two-folders-up", file.path(d$root, "a", "b"), d$root)
  d$doc <- file.path(d$docdir, "doc.qmd")
  for (i in seq_len(nrow(d))) {
    if (nzchar(d$weft_yml[i])) put(file.path(d$root[i], "_weft.yml"), d$weft_yml[i])
    put(d$doc[i], if (nzchar(d$front[i])) d$front[i] else "Text.\n")
  }
  d
}

test_that("GN1: the table has the sixteen cases, in the five columns, with a want of stop or collect", {
  d <- tcc_table()
  expect_identical(names(d), c("case", "weft_yml", "front", "want", "problem"))
  expect_identical(nrow(d), 16L)
  expect_false(anyDuplicated(d$case) > 0)
  expect_true(all(d$want %in% c("stop", "collect")))
  expect_true(all(d$problem %in% c("", "yes")))
  expect_identical(sum(d$problem == "yes"), 2L)
})

test_that("GN1, N70: R's reader gives want for each case, and stops with E30 where the value is not stop or collect", {
  withr::local_envvar(WEFT_DRAFT = NA)
  d <- tcc_projects()
  for (i in seq_len(nrow(d))) {
    r <- d[i, ]
    read <- function() suppressWarnings(
      weft:::read_config(r$root, front = weft:::read_front_matter(r$doc)$weft, doc = r$doc))
    if (r$problem == "yes") {
      e <- tryCatch({ read(); NULL }, condition = function(e) e)
      expect_s3_class(e, "weft_config_error")
      expect_identical(if (is.null(e)) "" else conditionMessage(e),
                       "The setting `chunk_claims` must be stop or collect.", label = r$case)
    } else {
      expect_identical(read()$chunk_claims, r$want, label = r$case)
    }
  }
})

TCC_LUA <- '
local lib = arg[1]
local config = dofile(lib .. "/config.lua")
for i = 2, #arg do
  local dir = arg[i]
  local f = io.open(dir .. "/doc.qmd", "rb")
  local text = f and f:read("a") or nil
  if f then f:close() end
  local cfg, problems = config.load("doc.qmd", text, dir)
  local ps = {}
  for _, p in ipairs(problems) do
    ps[#ps + 1] = { file = p.file, key = p.key, value = p.value, what = p.what }
  end
  io.write(pandoc.json.encode({ chunk_claims = cfg.chunk_claims, nproblems = #ps, problems = ps }), "\\n")
end
'

test_that("GN5: the Lua config gives want for each case; a bad value is a problem (E33, what = `stop or collect`) and the default is used", {
  skip_if_no_lua_pandoc()
  d <- tcc_projects()
  script <- file.path(dirname(d$root[1]), "driver.lua")
  writeLines(TCC_LUA, script)
  res <- lua_run(script, c(dirname(lua_num_path()), d$docdir))
  lines <- strsplit(res$stdout, "\n", fixed = TRUE)[[1]]
  expect_identical(length(lines), nrow(d), label = paste("one line per case;", res$stderr))
  if (length(lines) != nrow(d)) return(invisible())
  out <- lapply(lines, jsonlite::fromJSON, simplifyVector = FALSE)
  for (i in seq_len(nrow(d))) {
    r <- d[i, ]
    x <- out[[i]]
    expect_identical(x$chunk_claims, r$want, label = r$case)
    if (r$problem == "yes") {
      expect_identical(x$nproblems, 1L, label = paste(r$case, "problems"))
      expect_identical(x$problems[[1]]$key, "chunk_claims", label = r$case)
      expect_identical(x$problems[[1]]$what, "stop or collect", label = r$case)
    } else {
      expect_identical(x$nproblems, 0L, label = paste(r$case, "problems"))
    }
  }
})

test_that("GN4: Python's weft._config.chunk_claims(source, folder) gives want for each case; a bad value is stop", {
  skip_if_no_jupyter()
  d <- tcc_projects()
  spec <- file.path(dirname(d$root[1]), "spec.json")
  writeLines(jsonlite::toJSON(list(source = d$doc, folder = d$docdir), auto_unbox = FALSE), spec)
  code <- paste(
    "import json",
    "from weft import _config",
    sprintf("s = json.load(open('%s'))", spec),
    "for src, folder in zip(s['source'], s['folder']):",
    "    print(_config.chunk_claims(src, folder))",
    sep = "\n")
  x <- py_plain(code)
  expect_identical(x$status, 0L, label = x$stderr)
  expect_identical(strsplit(x$stdout, "\n", fixed = TRUE)[[1]], d$want)
})

test_that("GN4: Julia's Weft.chunk_claims_setting(source, folder) gives want for each case; a bad value is stop", {
  skip_if_julia_disabled()
  d <- tcc_projects()
  q <- function(x) paste0("\"", x, "\"")
  code <- c("using Weft",
            sprintf("for (src, folder) in [%s]",
                    paste(sprintf("(%s, %s)", q(d$doc), q(d$docdir)), collapse = ", ")),
            "    println(Weft.chunk_claims_setting(src, folder))",
            "end")
  r <- jle_cases(paste(code, collapse = "\n"))[[1]]
  expect_identical(r$emsg, "", label = "the Julia reader ran")
  expect_identical(strsplit(sub("\n$", "", r$out), "\n", fixed = TRUE)[[1]], d$want)
})
