# Package B (dev/refactor-sweep.md, B1 to B3): ONE table of cases, run against every copy of a rule, so the
# copies cannot drift. The table is _conformance/grammar.tsv, read with the reader of the other conformance
# tables (f6_read(), helper-6f.R); its columns:
#   kind     cond (the value of an `if` span), name (a NAME, N6) or doc (a whole document)
#   text     the case, percent-escaped (%20 space, %25 percent, and here also %0A newline, %09 tab, %0D
#            return, which f6_unesc() does not know and gr_unesc() adds)
#   verdict  cond: ok, E3 or E4.  name: ok or bad.  doc: filter (the Lua filter resolves the document) or
#            knitr (the knitr hooks do).
#   message  cond rows of E3 and E4 only, where the text of the message is compared (may be empty)
#
# THE COPIES (what each kind runs against):
#   cond  R filter_governor_errors("if", .); Lua cond.parse (+ cond.message); the pre-render script
#   name  R is_weft_name() and values_name_ok(); Lua cond.is_name and weft-check.lua's own is_name (driven
#         through its Code check); Python is_name; Julia is_name
#   doc   R filter_resolves(); Lua config.source_is_knitr (the move of B2)
# Decisions: where Lua and R disagreed on the whitespace in a condition, R's rule wins (only a space or a tab
# around the operator; a newline there is E3); a name with a trailing newline is no name anywhere; the upward
# search for `.weft/run` is the document's folder and 8 parents, 9 folders, in all three Lua searches.
# ASCII only.

.gr <- new.env()

gr_unesc <- function(x) {
  x <- gsub("%0A", "\n", x, fixed = TRUE)
  x <- gsub("%09", "\t", x, fixed = TRUE)
  x <- gsub("%0D", "\r", x, fixed = TRUE)
  f6_unesc(x)
}

gr_table <- function() {
  if (!is.null(.gr$table)) return(.gr$table)
  d <- f6_read("grammar")
  d$text <- gr_unesc(d$text)
  d$message <- gr_unesc(d$message)
  d$id <- seq_len(nrow(d))
  .gr$table <- d
  d
}

gr_hex <- function(x) {
  vapply(x, function(s) paste(sprintf("%02x", as.integer(charToRaw(enc2utf8(s)))), collapse = ""), "",
         USE.NAMES = FALSE)
}

gr_unhex <- function(h) {
  vapply(h, function(s) {
    if (!nzchar(s)) return("")
    r <- as.raw(strtoi(substring(s, seq(1L, nchar(s), 2L), seq(2L, nchar(s), 2L)), 16L))
    out <- rawToChar(r)
    Encoding(out) <- "UTF-8"
    out
  }, "", USE.NAMES = FALSE)
}

# One expectation for a whole column: every row that disagrees is named in the failure.
gr_agree <- function(rows, got, what, want = rows$verdict) {
  expect_length(got, nrow(rows))
  expect_gt(nrow(rows), 0L)
  shown <- encodeString(substr(gsub("\n", "\\n", rows$text, fixed = TRUE), 1L, 50L), quote = "'")
  bad <- sprintf("%s [%s] row %d: want %s, got %s", what, shown, rows$id, want, got)[is.na(got) | got != want]
  expect_identical(bad, character())
}

gr_rows <- function(kind) {
  d <- gr_table()
  d[d$kind == kind, , drop = FALSE]
}

gr_split_lines <- function(text) strsplit(text, "\n", fixed = TRUE)[[1L]]

# ---- the table itself ---------------------------------------------------------------------------------------

test_that("grammar.tsv: the three kinds, their verdicts, and no case twice", {
  d <- gr_table()
  expect_setequal(unique(d$kind), c("cond", "name", "doc"))
  expect_true(all(d$verdict[d$kind == "cond"] %in% c("ok", "E3", "E4")))
  expect_true(all(d$verdict[d$kind == "name"] %in% c("ok", "bad")))
  expect_true(all(d$verdict[d$kind == "doc"] %in% c("filter", "knitr")))
  for (k in c("cond", "name", "doc")) {
    v <- d$verdict[d$kind == k]
    expect_gt(length(unique(v)), 1L, label = paste("both sides of the rule are in the table:", k))
  }
  expect_identical(anyDuplicated(d[, c("kind", "text")]), 0L)
  # a message only where there is an error to quote
  with_msg <- d[nzchar(d$message), ]
  expect_gt(nrow(with_msg), 5L)
  expect_true(all(with_msg$kind == "cond" & with_msg$verdict %in% c("E3", "E4")))
  # the cases the decisions name are in
  expect_true("x\n" %in% d$text[d$kind == "name"])
  expect_true("x\n< 3" %in% d$text[d$kind == "cond"])
  expect_true(any(d$kind == "name" & nchar(d$text) == 65L & d$verdict == "bad"))
  expect_gte(sum(d$kind == "name" & nchar(d$text) == 64L & d$verdict == "ok"), 1L)
})

# ---- R ----------------------------------------------------------------------------------------------------------

gr_r_cond <- function(text) {
  e <- weft:::filter_governor_errors("if", text, FALSE)
  if (!length(e)) "ok" else if (grepl("compares two literals", e[[1L]], fixed = TRUE)) "E4" else "E3"
}

test_that("R: the scanner's grammar of `if` gives the table's verdict on every cond row", {
  r <- gr_rows("cond")
  gr_agree(r, vapply(r$text, gr_r_cond, "", USE.NAMES = FALSE), "R filter_governor_errors")
})

test_that("R: the E3 and E4 message of the scanner is the table's text", {
  r <- gr_rows("cond")
  r <- r[nzchar(r$message), ]
  expect_gt(nrow(r), 5L)
  got <- vapply(r$text, function(t) {
    e <- weft:::filter_governor_errors("if", t, FALSE)
    if (length(e)) e[[1L]] else NA_character_
  }, "", USE.NAMES = FALSE)
  gr_agree(r, got, "R message", want = r$message)
})

test_that("R: is_weft_name() and values_name_ok() give the table's verdict on every name row", {
  r <- gr_rows("name")
  want <- r$verdict
  gr_agree(r, ifelse(vapply(r$text, weft:::is_weft_name, NA, USE.NAMES = FALSE), "ok", "bad"),
           "R is_weft_name", want)
  gr_agree(r, ifelse(vapply(r$text, function(x) isTRUE(weft:::values_name_ok(x)), NA, USE.NAMES = FALSE),
                     "ok", "bad"), "R values_name_ok", want)
})

test_that("R: filter_resolves() gives the table's verdict on every doc row", {
  r <- gr_rows("doc")
  got <- vapply(r$text, function(t) {
    if (weft:::filter_resolves(gr_split_lines(t), "a.qmd")) "filter" else "knitr"
  }, "", USE.NAMES = FALSE)
  gr_agree(r, got, "R filter_resolves")
})

# ---- Lua: one pandoc process for the whole table ----------------------------------------------------------------

GR_LUA_DRIVER <- r"---(
local lib, wcpath, rowsf, outf = arg[1], arg[2], arg[3], arg[4]
local cond = dofile(lib .. "/cond.lua")
local config = dofile(lib .. "/config.lua")
local function unhex(h) return (h:gsub("%x%x", function(x) return string.char(tonumber(x, 16)) end)) end
local function hex(s) return (s:gsub(".", function(c) return string.format("%02x", c:byte()) end)) end

-- weft-check.lua's own is_name is a local function: it is reached through its check of a code span with a
-- weft class. A named one is "a named value was not resolved", any other is "carries the weft class".
local function wc_name(s)
  local buf = {}
  local real = io.stderr
  io.stderr = { write = function(_, ...) for _, x in ipairs({ ... }) do buf[#buf + 1] = tostring(x) end return true end }
  dofile(wcpath)
  local ok, e = pcall(Pandoc, pandoc.Pandoc({ pandoc.Para({ pandoc.Code(s, pandoc.Attr("", { "num" })) }) }))
  io.stderr = real
  local out = table.concat(buf)
  if not ok then return "error" end
  if out:find("a named value was not resolved", 1, true) then return "ok" end
  if out:find("carries the weft class", 1, true) then return "bad" end
  return "none"
end

local out = assert(io.open(outf, "wb"))
for line in io.lines(rowsf) do
  local id, kind, h = line:match("^(%d+)\t(%a+)\t(%x*)$")
  local text = unhex(h)
  local verdict, msg, extra = "", "-", ""
  if kind == "cond" then
    local ok, nodes, err = pcall(cond.parse, text)
    if not ok then verdict = "error"
    elseif nodes then verdict = "ok"
    else
      verdict = err.id
      if cond.message then
        local okm, m = pcall(cond.message, err)
        if okm and type(m) == "string" then msg = "m" .. hex(m) end
      end
    end
  elseif kind == "name" then
    verdict = cond.is_name(text) and "ok" or "bad"
    extra = wc_name(text)
  elseif kind == "doc" then
    if not config.source_is_knitr then verdict = "missing"
    else
      local ok, r = pcall(config.source_is_knitr, "a.qmd", text)
      verdict = (not ok) and "error" or (r and "knitr" or "filter")
    end
  end
  out:write(id, "\t", kind, "\t", verdict, "\t", msg, "\t", extra, "\n")
end
out:close()
)---"

gr_lua <- function() {
  if (!is.null(.gr$lua)) return(.gr$lua)
  skip_if_no_lua_pandoc()
  d <- gr_table()
  dir <- withr::local_tempdir()
  writeLines(paste(d$id, d$kind, gr_hex(d$text), sep = "\t"), file.path(dir, "rows.tsv"))
  writeLines(GR_LUA_DRIVER, file.path(dir, "driver.lua"), useBytes = TRUE)
  withr::local_envvar(c(WEFT_DRAFT = "1", WEFT_COLLECT = NA, WEFT_RUN = NA))
  lib <- file.path(dirname(filter_path("weft.lua")), "weftlib")
  res <- lua_run(file.path(dir, "driver.lua"),
                 c(lib, filter_path("weft-check.lua"), file.path(dir, "rows.tsv"), file.path(dir, "out.tsv")))
  outf <- file.path(dir, "out.tsv")
  lines <- if (file.exists(outf)) readLines(outf, warn = FALSE) else character()
  expect(length(lines) == nrow(d),
         sprintf("the Lua driver wrote %d lines for %d rows (status %d): %s", length(lines), nrow(d), res$status,
                 substr(res$stderr, 1L, 500L)))
  parts <- strsplit(paste0(lines, "\t\t\t\t\t"), "\t", fixed = TRUE)
  x <- data.frame(id = as.integer(vapply(parts, `[`, "", 1L)), verdict = vapply(parts, `[`, "", 3L),
                  msg = vapply(parts, `[`, "", 4L), wc = vapply(parts, `[`, "", 5L), stringsAsFactors = FALSE)
  .gr$lua <- x[match(d$id, x$id), , drop = FALSE]
  .gr$lua
}

test_that("Lua: cond.parse gives the table's verdict on every cond row", {
  d <- gr_table()
  x <- gr_lua()
  k <- d$kind == "cond"
  gr_agree(d[k, ], x$verdict[k], "Lua cond.parse")
})

test_that("Lua: cond.message(err) is the table's text, the one R gives, for every cond row with a message", {
  d <- gr_table()
  x <- gr_lua()
  k <- d$kind == "cond" & nzchar(d$message)
  expect_gt(sum(k), 5L)
  has <- startsWith(x$msg[k], "m")
  expect_true(all(has), label = "cond.message exists and returns a string for an E3 or E4 error")
  got <- gr_unhex(substring(x$msg[k], 2L))
  got[!has] <- NA_character_
  gr_agree(d[k, ], got, "Lua cond.message", want = d$message[k])
})

test_that("Lua: cond.is_name gives the table's verdict on every name row", {
  d <- gr_table()
  x <- gr_lua()
  k <- d$kind == "name"
  gr_agree(d[k, ], x$verdict[k], "Lua cond.is_name")
})

test_that("Lua: weft-check.lua's own is_name (through its check of a code span) gives the table's verdict", {
  d <- gr_table()
  x <- gr_lua()
  k <- d$kind == "name"
  gr_agree(d[k, ], x$wc[k], "weft-check is_name")
})

test_that("Lua: config.source_is_knitr gives the table's verdict on every doc row", {
  d <- gr_table()
  x <- gr_lua()
  k <- d$kind == "doc"
  expect_false(any(x$verdict[k] == "missing"), label = "config.source_is_knitr is exported by weftlib/config.lua")
  gr_agree(d[k, ], x$verdict[k], "Lua source_is_knitr")
})

# ---- the pre-render script: one Rscript run, one .qmd per cond row ----------------------------------------------

test_that("pre-render script: a file holding the condition stops the render exactly when the table says E3 or E4", {
  script <- system.file("quarto", "weft-pre-render.R", package = "weft")
  expect_true(nzchar(script) && file.exists(script))
  d <- gr_table()
  r <- d[d$kind == "cond" & !grepl("[\r\n]", d$text), , drop = FALSE]
  expect_gt(nrow(r), 50L)
  doc <- function(cond) c("---", "title: t", "---", "",
                          sprintf("The level [rose | fell]{if=\"%s\"} again.", cond))
  files <- c(list("_quarto.yml" = c("project:", "  type: default", "format: html")),
             stats::setNames(lapply(r$text, doc), sprintf("c%03d.qmd", r$id)))
  root <- lint_proj(files)
  withr::local_envvar(c(QUARTO_PROJECT_INPUT_FILES = NA, WEFT_RUN = NA))
  out <- suppressWarnings(withr::with_dir(root, system2(file.path(R.home("bin"), "Rscript"), shQuote(script),
                                                         stdout = TRUE, stderr = TRUE)))
  status <- { st <- attr(out, "status"); if (is.null(st)) 0L else as.integer(st) }
  stopped <- sub("^  (c[0-9]+\\.qmd): holds a weft construct.*$", "\\1",
                 grep("^  c[0-9]+\\.qmd: holds a weft construct", out, value = TRUE))
  expect_identical(status, 1L)
  got <- ifelse(sprintf("c%03d.qmd", r$id) %in% stopped, "not ok", "ok")
  gr_agree(r, got, "pre-render", want = ifelse(r$verdict == "ok", "ok", "not ok"))
})

# ---- Python and Julia: one process each, all name rows ----------------------------------------------------------

test_that("Python: is_name gives the table's verdict on every name row", {
  py <- py_exe6k()
  d <- gr_rows("name")
  dir <- withr::local_tempdir()
  writeLines(paste(d$id, gr_hex(d$text), sep = "\t"), file.path(dir, "names.tsv"))
  script <- file.path(dir, "run.py")
  writeLines(c(
    "import sys",
    "from weft import _backend",
    "for line in open(sys.argv[1], encoding='utf-8'):",
    "    i, h = line.rstrip('\\n').split('\\t')",
    "    s = bytes.fromhex(h).decode('utf-8')",
    "    print(i + '\\t' + ('ok' if _backend.is_name(s) else 'bad'))"), script)
  out <- suppressWarnings(system2(py, c(shQuote(script), shQuote(file.path(dir, "names.tsv"))),
                                  env = paste0("PYTHONPATH=", py_lib6k()), stdout = TRUE, stderr = FALSE))
  expect_length(out, nrow(d))
  p <- strsplit(out, "\t", fixed = TRUE)
  got <- vapply(p, `[`, "", 2L)[match(d$id, as.integer(vapply(p, `[`, "", 1L)))]
  gr_agree(d, got, "Python is_name")
})

test_that("Julia: is_name gives the table's verdict on every name row", {
  skip_if_no_julia_engine()
  d <- gr_rows("name")
  dir <- withr::local_tempdir()
  f <- file.path(dir, "names.tsv")
  writeLines(paste(d$id, gr_hex(d$text), sep = "\t"), f)
  code <- c(
    "using Weft",
    sprintf("for line in eachline(\"%s\")", normalizePath(f, winslash = "/")),
    "    i, h = split(line, '\\t'; limit = 2)",
    "    s = String(hex2bytes(h))",
    "    println(i, \"\\t\", Weft.is_name(s) ? \"ok\" : \"bad\")",
    "end")
  x <- jle_cases(paste(code, collapse = "\n"))[[1L]]
  expect_false(is.na(x$out), label = x$stderr)
  lines <- strsplit(sub("\n$", "", x$out), "\n", fixed = TRUE)[[1L]]
  lines <- lines[grepl("^[0-9]+\t(ok|bad)$", lines)]
  expect_length(lines, nrow(d))
  p <- strsplit(lines, "\t", fixed = TRUE)
  got <- vapply(p, `[`, "", 2L)[match(d$id, as.integer(vapply(p, `[`, "", 1L)))]
  gr_agree(d, got, "Julia is_name")
})

# ---- B3: the upward search for .weft/run is 9 folders in all three Lua searches ---------------------------------

GR_B3_DRIVER <- r"---(
local lib, wcpath = arg[1], arg[2]
local config = dofile(lib .. "/config.lua")
local cwd = pandoc.system.get_working_directory()
local p = config.find_upward(cwd, ".weft/run")
print("config\t" .. (p and "found" or "none"))
-- weft-check.lua, as under Quarto (a `quarto` global): its collection file is this folder's, which names the
-- run R9; .weft/run (further up) names R8, so a collection file the run did not open is not in use. When the
-- search does not reach .weft/run, the file is taken for the run's and the report says "(collected)".
quarto = {}
local buf = {}
local real = io.stderr
io.stderr = { write = function(_, ...) for _, x in ipairs({ ... }) do buf[#buf + 1] = tostring(x) end return true end }
dofile(wcpath)
pcall(Pandoc, pandoc.Pandoc({ pandoc.Para({ pandoc.Code("x", pandoc.Attr("", { "num" })) }) }))
io.stderr = real
local out = table.concat(buf)
print("check\t" .. (out:find("(collected)", 1, true) and "collected" or (out:find("(draft mode)", 1, true) and "run-found" or "silent")))
)---"

# a project with `.weft/run` at the root and a document folder `depth` folders down
gr_b3_tree <- function(depth, env = parent.frame()) {
  root <- normalizePath(withr::local_tempdir(.local_envir = env), winslash = "/")
  deep <- paste(c(root, paste0("d", seq_len(depth))), collapse = "/")
  dir.create(deep, recursive = TRUE)
  dir.create(file.path(root, ".weft"))
  writeLines("R8", file.path(root, ".weft", "run"))
  dir.create(file.path(deep, ".weft"))
  writeLines("{\"run\":\"R9\"}", file.path(deep, ".weft", "failures.jsonl"))
  list(root = root, deep = deep)
}

gr_b3_run <- function(depth) {
  tr <- gr_b3_tree(depth)
  drv <- withr::local_tempfile(fileext = ".lua")
  writeLines(GR_B3_DRIVER, drv)
  withr::local_envvar(c(WEFT_DRAFT = "1", WEFT_COLLECT = NA, WEFT_RUN = NA))
  lib <- file.path(dirname(filter_path("weft.lua")), "weftlib")
  res <- lua_run(drv, c(lib, filter_path("weft-check.lua")), dir = tr$deep)
  expect_identical(res$status, 0L, label = res$stderr)
  kv <- strsplit(strsplit(res$stdout, "\n", fixed = TRUE)[[1L]], "\t", fixed = TRUE)
  stats::setNames(vapply(kv, `[`, "", 2L), vapply(kv, `[`, "", 1L))
}

test_that("B3: a .weft/run 8 parents above the document's folder is found by weftlib/config.lua and weft-check.lua", {
  skip_if_no_lua_pandoc()
  got <- gr_b3_run(8L)
  expect_identical(got[["config"]], "found")
  expect_identical(got[["check"]], "run-found")
})

test_that("B3 control: 9 parents above is one folder too far for both searches", {
  skip_if_no_lua_pandoc()
  got <- gr_b3_run(9L)
  expect_identical(got[["config"]], "none")
  expect_identical(got[["check"]], "collected")
})

# The stamp's `run` of a document `depth` folders below the project root, where only the root has .weft/run.
gr_b3_filter <- function(depth) {
  sub <- paste(paste0("d", seq_len(depth)), collapse = "/")
  files <- list("serial_comma: true", "R8")
  names(files) <- c(file.path(sub, "_weft.yml"), ".weft/run")
  res <- filter_md("Hello.", files = files, name = file.path(sub, "doc.md"), run_in = sub,
                   filters = "weft.lua", env = c(WEFT_RUN = NA))
  stamp <- file.path(res$dir, sub, ".weft", "stamps", "doc.md.json")
  expect_true(file.exists(stamp), label = paste("the filter wrote the stamp, depth", depth))
  if (!file.exists(stamp)) return(NA_character_)
  s <- jsonlite::fromJSON(paste(readLines(stamp, warn = FALSE), collapse = "\n"))
  if (is.null(s$run) || !nzchar(s$run)) NA_character_ else s$run
}

test_that("B3: weft.lua's own search finds a .weft/run 8 parents above the document's folder, and not 9", {
  skip_if_no_lua_pandoc()
  expect_identical(gr_b3_filter(8L), "R8")
  expect_true(is.na(gr_b3_filter(9L)))
})

# ---- open finding 20: unit= on an `if` span ---------------------------------------------------------------------

test_that("open finding 20: unit= on an `if` span is an error in the filter, as it is on n, sign and list spans", {
  skip_if_no_lua_pandoc()
  for (span in c("[a | b]{n=\"s\" unit=\"m\"}", "[a | b]{sign=\"s\" unit=\"m\"}")) {
    res <- filter_md(c(carrier(x = fr_float("2"), s = fr_float("2")), "", paste("Level", span, "end.")),
                     filters = "weft.lua")
    expect_identical(res$status, 1L, label = paste("control:", span))
    expect_true(grepl("`unit=`", res$stderr, fixed = TRUE), label = paste("control names unit=:", span))
  }
  res <- filter_md(c(carrier(x = fr_float("2")), "", "Level [a | b]{if=\"x < 3\" unit=\"m\"} end."),
                   filters = "weft.lua")
  expect_identical(res$status, 1L)
  expect_true(grepl("`unit=`", res$stderr, fixed = TRUE), label = res$stderr)
  # and the same span without unit= is fine (the harness is not failing for another reason)
  ok <- filter_md(c(carrier(x = fr_float("2")), "", "Level [a | b]{if=\"x < 3\"} end."), filters = "weft.lua")
  expect_identical(ok$status, 0L)
  expect_true(grepl("Level a end.", ok$output, fixed = TRUE))
})
