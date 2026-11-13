# Package 6R, the R side: failing tests for the findings of dev/review-stage6.md and the stage-6 items
# of dev/open-findings.md, from the review and its rulings only ("Rulings (orchestrator, 14 Nov)").
# Every test is labelled "review-6 #N" (a finding of the review) or "open-6 #N" (an open finding).
# Written before the fixes: each test that is not a control fails today, and says why in its comment.
#
# READINGS where a ruling leaves exact text open (behaviour is asserted, never invented wording):
#  - #2: the scanner's error text for a leading space is not ruled; the tests assert `!is.na(error)` and a
#    finding of the `construct` rule;
#  - #6: the text of the new `publish-hidden` finding is not ruled; rule, file, line and the name are pinned;
#  - #11: the state words are the ones status() already has (`outdated`, `missing`); the detail is pinned only
#    to name the file;
#  - #14: N47's sentence "a length-1 named vector is a scalar" is replaced by ruling 14 (a list of one);
#  - open-6 #18: only the tokens of the `_quarto.yml` form (`julia:`, `env:`, `JULIA_LOAD_PATH=`) are pinned.
#
# Helpers: helper-6b.R, helper-6d.R, helper-3.R, helper-4a.R, helper-4b.R, helper-4d.R, helper-julia-engine.R,
# helper-jupyter.R. ASCII only.

# ---- review-6 #2: a governor value that starts with a space (the scanner half) -------------------------------

SP2_SPANS <- c(n_dq = "A [one | many]{n=\" k\"} B.",
               if_dq = "A [one | many]{if=\" ok\"} B.")

sp2_rows <- function(x) x[x$kind %in% c("n", "if"), , drop = FALSE]

test_that("review-6 #2: a governor value with a leading space is a construct error on the row, in a document the filter resolves", {
  for (nm in names(SP2_SPANS)) {
    lines <- w6d_doc(c("Intro.", "", SP2_SPANS[[nm]]))
    r <- sp2_rows(w6d_scan(lines))
    expect_identical(nrow(r), 1L, label = paste(nm, "one row"))
    if (nrow(r) != 1L) next
    # today the scanner trims the value and accepts it: error is NA
    expect_false(is.na(r$error), label = paste(nm, "the row has an error"))
    expect_identical(r$resolver, "filter", label = nm)
  }
})

test_that("review-6 #2: the construct lint reports it, once, at the line of the span", {
  for (nm in names(SP2_SPANS)) {
    lines <- w6d_doc(c("Intro.", "", SP2_SPANS[[nm]]))
    x <- w6d_find(lines, "construct")
    expect_identical(nrow(x), 1L, label = nm)
    if (nrow(x) != 1L) next
    expect_identical(x$rule, "construct", label = nm)
    expect_identical(x$file, "a.qmd", label = nm)
    expect_identical(x$line, which(lines == SP2_SPANS[[nm]]), label = nm)
  }
})

test_that("review-6 #2 control: a trailing space stays legal, and a leading space in a knitr document is the hooks' (they read the source)", {
  for (src in c("A [one | many]{n=\"k \"} B.", "A [one | many]{if=\"ok \"} B.", "A [one | many]{if=\"ok\"} B.")) {
    lines <- w6d_doc(c("Intro.", "", src))
    r <- sp2_rows(w6d_scan(lines))
    expect_identical(nrow(r), 1L, label = src)
    expect_true(all(is.na(r$error)), label = src)
    expect_identical(nrow(w6d_find(lines, "construct")), 0L, label = src)
  }
  rmd <- w6d_scan(c("Intro.", "", "A [one | many]{if=\" ok\"} B."), name = "a.Rmd")
  expect_true(all(is.na(rmd$error)))
})

test_that("review-6 #2 control: the single-quoted form `{if=' ok'}` is already a construct error (rule 1.2.3, single quotes), and stays one", {
  lines <- w6d_doc(c("Intro.", "", "A [one | many]{if=' ok'} B."))
  r <- sp2_rows(w6d_scan(lines))
  expect_identical(nrow(r), 1L)
  expect_false(is.na(r$error))
  expect_identical(nrow(w6d_find(lines, "construct")), 1L)
})

# ---- review-6 #6: publish-hidden fires on a hidden cell that assigns a name the prose uses ------------------

PH6_PROSE <- "We visited `n_sites`{.num} sites."

ph6_doc <- function(later, later_opts = "include: false", first = c("from weft import auto", "auto()", "n_sites = 10")) {
  chunks <- c(w6d_py(first, "label: first"), "", w6d_py(later, c("label: later", later_opts)))
  w6d_doc(PH6_PROSE, chunks)
}

ph6_find <- function(lines) w6d_find(lines, "publish-hidden")

test_that("review-6 #6: a hidden cell that assigns a name the prose uses, in a document that calls auto(), is a publish-hidden finding", {
  for (opt in c("include: false", "output: false")) {
    lines <- ph6_doc("n_sites = 12", opt)
    x <- ph6_find(lines)
    # today only a put() or auto() call in the hidden cell fires: no finding
    expect_identical(nrow(x), 1L, label = opt)
    if (nrow(x) != 1L) next
    expect_identical(x$rule, "publish-hidden", label = opt)
    expect_identical(x$file, "a.qmd", label = opt)
    expect_identical(x$line, which(lines == "```{python}")[2], label = opt)
    expect_true(grepl("n_sites", x$message, fixed = TRUE), label = opt)
    expect_true(grepl(sub(":.*$", "", opt), x$message, fixed = TRUE), label = paste(opt, "names the option"))
  }
})

test_that("review-6 #6: it does not fire without auto(), for a name the prose does not use, or for a hidden cell that only reads", {
  expect_identical(nrow(ph6_find(ph6_doc("n_sites = 12", first = c("n_sites = 10")))), 0L)
  expect_identical(nrow(ph6_find(ph6_doc("other_thing = 12"))), 0L)
  expect_identical(nrow(ph6_find(ph6_doc("print(n_sites)"))), 0L)
  # a cell that shows its output is not hidden
  expect_identical(nrow(ph6_find(ph6_doc("n_sites = 12", later_opts = "echo: false"))), 0L)
  # control: the finding that exists today still fires, for put()
  x <- ph6_find(ph6_doc("put(n_sites = 12)"))
  expect_gte(nrow(x), 1L)
})

# ---- review-6 #11: status() and the rollback hold weft.lua and weftlib/*.lua --------------------------------

st6_project <- function(env = parent.frame()) {
  dir <- u4_dir(list(`_quarto.yml` = U4_QUARTO_YML, `index.qmd` = u4_qmd()))
  git_env(env)
  h4_env(env)
  suppressMessages(utils::capture.output(weft::use_quarto(dir)))
  normalizePath(dir, winslash = "/")
}

test_that("review-6 #11 control: a project set up by use_quarto() has quarto ok", {
  dir <- st6_project()
  expect_identical(h4_state(h4_status(dir), "quarto"), "ok")
})

test_that("review-6 #11: a weft.lua that differs from the package's is outdated, and the detail names it", {
  dir <- st6_project()
  lua <- file.path(dir, "_extensions", "weft-check", "weft.lua")
  expect_true(file.exists(lua))
  writeLines(c(readLines(lua, warn = FALSE), "-- edited"), lua)
  st <- h4_status(dir)
  # today: ok, "extension, scripts and _quarto.yml entries are in place"
  expect_identical(h4_state(st, "quarto"), "outdated")
  expect_true(grepl("weft.lua", h4_detail(st, "quarto"), fixed = TRUE))
})

test_that("review-6 #11: a weftlib module that differs is outdated, and one that is absent is missing; each is named", {
  dir <- st6_project()
  lib <- file.path(dir, "_extensions", "weft-check", "weftlib")
  mods <- list.files(lib, pattern = "[.]lua$")
  expect_true("stamp.lua" %in% mods)
  writeLines(c(readLines(file.path(lib, "num.lua"), warn = FALSE), "-- edited"), file.path(lib, "num.lua"))
  st <- h4_status(dir)
  expect_identical(h4_state(st, "quarto"), "outdated")
  expect_true(grepl("num.lua", h4_detail(st, "quarto"), fixed = TRUE))
  unlink(file.path(lib, "stamp.lua"))
  st <- h4_status(dir)
  expect_identical(h4_state(st, "quarto"), "missing")
  expect_true(grepl("stamp.lua", h4_detail(st, "quarto"), fixed = TRUE))
})

test_that("review-6 #11: a missing weft.lua is missing", {
  dir <- st6_project()
  unlink(file.path(dir, "_extensions", "weft-check", "weft.lua"))
  st <- h4_status(dir)
  expect_identical(h4_state(st, "quarto"), "missing")
  expect_true(grepl("weft.lua", h4_detail(st, "quarto"), fixed = TRUE))
})

test_that("review-6 #11 control: a use_weft() that fails puts weft.lua and the weftlib modules back as they were (and removes none it made)", {
  skip_on_os("windows")
  skip_if(identical(Sys.info()[["user"]], "root"), "root can write into a read-only folder")
  files <- list(`_quarto.yml` = U4_QUARTO_YML, `index.qmd` = u4_qmd(), `.Rprofile` = "options(digits = 4)")
  dir <- h4_repo(files, weft = character(), origin = "https://github.com/example-org/example-repo.git")
  suppressMessages(utils::capture.output(weft::use_quarto(dir)))
  ext <- file.path(dir, "_extensions", "weft-check")
  lua <- file.path(ext, "weft.lua")
  mod <- file.path(ext, "weftlib", "num.lua")
  gone <- file.path(ext, "weftlib", "stamp.lua")
  writeLines("-- stale weft.lua", lua)
  writeLines("-- stale num.lua", mod)
  unlink(gone)
  hooks <- file.path(dir, ".git", "hooks")
  dir.create(hooks, showWarnings = FALSE)
  Sys.chmod(hooks, "555")
  withr::defer(Sys.chmod(hooks, "755"))
  skip_if(file.access(hooks, 2L) == 0L, "the folder is still writable here")
  withr::local_libpaths(h4_lib(), action = "prefix")
  err <- tryCatch(suppressMessages(utils::capture.output(weft::use_weft(dir))), error = function(e) e)
  expect_s3_class(err, "error")
  expect_identical(readLines(lua, warn = FALSE), "-- stale weft.lua")
  expect_identical(readLines(mod, warn = FALSE), "-- stale num.lua")
  expect_false(file.exists(gone))
})

# ---- review-6 #14 (R half), ruling 14: a named vector of length 1 is a list of one with its key -------------

test_that("review-6 #14: values_record(c(a = 1.25)) is a list record of one element, with keys [\"a\"]", {
  r <- weft:::values_record(c(a = 1.25))
  expect_null(r$code)
  expect_identical(r$json, "{\"t\":\"list\",\"v\":[{\"t\":\"float\",\"v\":\"1.25\"}],\"of\":\"float\",\"keys\":[\"a\"]}")
})

test_that("review-6 #14: the same for an integer, a string, a logical and a Date of length 1 with a name", {
  expect_identical(weft:::values_record(c(a = 2L))$json,
                   "{\"t\":\"list\",\"v\":[{\"t\":\"int\",\"v\":\"2\"}],\"of\":\"int\",\"keys\":[\"a\"]}")
  expect_identical(weft:::values_record(c(k = "x"))$json,
                   "{\"t\":\"list\",\"v\":[{\"t\":\"string\",\"v\":\"x\"}],\"of\":\"string\",\"keys\":[\"k\"]}")
  expect_identical(weft:::values_record(c(ok = TRUE))$json,
                   "{\"t\":\"list\",\"v\":[{\"t\":\"bool\",\"v\":true}],\"of\":\"bool\",\"keys\":[\"ok\"]}")
  d <- c(when = as.Date("2026-11-13"))
  expect_identical(weft:::values_record(d)$json,
                   "{\"t\":\"list\",\"v\":[{\"t\":\"date\",\"v\":\"2026-11-13\"}],\"of\":\"date\",\"keys\":[\"when\"]}")
})

test_that("review-6 #14: through weft_put() the record is a list of one with its key, and the key is the vector's name, not the argument's", {
  rec <- b6_rec(c(depth = 3.5))
  expect_identical(rec$t, "list")
  expect_identical(unlist(rec$keys), "depth")
  expect_identical(rec$of, "float")
  expect_length(rec$v, 1L)
  expect_identical(rec$v[[1]]$v, "3.5")
  blk <- b6_parse(weft::weft_put(alpha = c(depth = 3.5)))
  expect_identical(unlist(blk$values$alpha$keys), "depth")
})

test_that("review-6 #14 control: an unnamed length-1 vector stays a scalar, and a named vector of 2 is a list as before", {
  expect_identical(weft:::values_record(1.25)$json, "{\"t\":\"float\",\"v\":\"1.25\"}")
  expect_identical(weft:::values_record(2L)$json, "{\"t\":\"int\",\"v\":\"2\"}")
  expect_identical(weft:::values_record("x")$json, "{\"t\":\"string\",\"v\":\"x\"}")
  expect_identical(weft:::values_record(c(a = 1L, b = 2L))$json,
                   "{\"t\":\"list\",\"v\":[{\"t\":\"int\",\"v\":\"1\"},{\"t\":\"int\",\"v\":\"2\"}],\"of\":\"int\",\"keys\":[\"a\",\"b\"]}")
})

test_that("review-6 #14: the collapse.tsv row `c(A = 1.25)` with `.pairs` is back, with a list record of one and keys [\"A\"]", {
  p <- testthat::test_path("_conformance", "collapse.tsv")
  d <- utils::read.delim(p, sep = "\t", quote = "", stringsAsFactors = FALSE, na.strings = character(),
                         colClasses = "character", encoding = "UTF-8")
  i <- which(d$value == "c(A = 1.25)" & d$classes == "pairs" & d$keys == "")
  expect_length(i, 1L)
  if (length(i) != 1L) return(invisible())
  # today the row's record is the scalar {"t":"float","v":"1.25"}
  expect_identical(d$record[i],
                   "{\"t\":\"list\",\"v\":[{\"t\":\"float\",\"v\":\"1.25\"}],\"of\":\"float\",\"keys\":[\"A\"]}")
  # R prints the name: A (1.3) at the default digits
  expect_identical(d$text[i], "A (1.3)")
})

# ---- review-6 #13 (R half): the shortest text, for subnormals too ------------------------------------------

test_that("review-6 #13: values_record(5e-324) gives the shortest text that reads back, 5e-324", {
  # today: 4.94065645841247e-324 (%.15g reads back, but is not the shortest)
  expect_identical(weft:::values_record(5e-324)$json, "{\"t\":\"float\",\"v\":\"5e-324\"}")
  rec <- b6_rec(5e-324)
  expect_identical(rec$v, "5e-324")
  expect_identical(as.numeric(rec$v), 5e-324)
})

test_that("review-6 #13: other subnormals give their shortest digits; normal doubles keep the text they have", {
  expect_identical(weft:::values_record(1e-323)$json, "{\"t\":\"float\",\"v\":\"1e-323\"}")
  expect_identical(weft:::values_record(2.5e-323)$json, "{\"t\":\"float\",\"v\":\"2.5e-323\"}")
  # controls, true today
  expect_identical(weft:::values_record(0.1)$json, "{\"t\":\"float\",\"v\":\"0.1\"}")
  expect_identical(weft:::values_record(1e23)$json, "{\"t\":\"float\",\"v\":\"1e+23\"}")
  expect_identical(weft:::values_record(100000)$json, "{\"t\":\"float\",\"v\":\"100000\"}")
  expect_identical(weft:::values_record(-0)$json, "{\"t\":\"float\",\"v\":\"-0\"}")
})

# ---- review-6 #15: complex and raw are E45 ---------------------------------------------------------------

E45_6 <- function(cls) {
  sprintf(paste0("is an R %s, which weft does not publish. Publish a bool, number, string, Date, or a vector ",
                 "of one of these (rule 1.11.1)."), cls)
}

test_that("review-6 #15: values_record() of a complex and of a raw is an error record with E45", {
  for (cs in list(list(1 + 2i, "complex"), list(as.raw(255), "raw"), list(c(1 + 2i, 3i), "complex"),
                  list(as.raw(1:3), "raw"))) {
    r <- weft:::values_record(cs[[1]])
    # today: {"t":"string","v":"1+2i"} and {"t":"string","v":"ff"}
    expect_identical(r$code, "E45", label = cs[[2]])
    expect_identical(r$tail, E45_6(cs[[2]]), label = cs[[2]])
    j <- jsonlite::fromJSON(r$json, simplifyVector = FALSE)
    expect_identical(j$t, "error", label = cs[[2]])
    expect_identical(j$why, paste("{S}", E45_6(cs[[2]])), label = cs[[2]])
    expect_null(j$v)
  }
})

test_that("review-6 #15: weft_put() of them behaves as E45 says: an error record, the other names still published", {
  blk <- b6_parse(weft::weft_put(ok = 1L, z = 1 + 2i, r = as.raw(255), also = "x"))
  expect_identical(blk$values$ok$t, "int")
  expect_identical(blk$values$also$t, "string")
  expect_identical(blk$values$z$t, "error")
  expect_identical(blk$values$z$why, paste("{S}", E45_6("complex")))
  expect_identical(blk$values$r$t, "error")
  expect_identical(blk$values$r$why, paste("{S}", E45_6("raw")))
})

test_that("review-6 #15: in a knit, a complex the prose names is an error record at the name", {
  res <- b6_knit(c(
    "```{r calc, include=FALSE}", "z <- 1 + 2i", "```", "",
    "Uses `z`{.val}."
  ))
  b6_expect_knitted(res)
  expect_length(res$blocks, 1L)
  rec <- res$blocks[[1]]$block$values$z
  expect_identical(rec$t, "error")
  expect_identical(rec$why, paste("{S}", E45_6("complex")))
})

test_that("review-6 #15 control: the kinds N47 lists are still records", {
  for (x in list(TRUE, 1L, 1.5, "a", as.Date("2026-11-13"), factor("a"), NA, NULL)) {
    expect_true(is.null(weft:::values_record(x)$code))
  }
})

# ---- review-6 #17 (writers' half, R): the run is looked for in the folder and 8 parents, file before env -----

run6_tree <- function(depth, line = "run-file", env = parent.frame()) {
  root <- normalizePath(withr::local_tempdir(.local_envir = env), winslash = "/")
  dir.create(file.path(root, ".weft"))
  writeLines(line, file.path(root, ".weft", "run"))
  here <- root
  for (i in seq_len(depth)) {
    here <- file.path(here, paste0("d", i))
    dir.create(here)
  }
  list(root = root, here = here)
}

test_that("review-6 #17: R finds .weft/run in the document's folder and 8 parents, and not in a ninth", {
  withr::local_envvar(c(WEFT_RUN = NA_character_))
  for (depth in c(0L, 1L, 7L, 8L)) {
    tr <- run6_tree(depth)
    withr::local_dir(tr$here)
    expect_identical(b6_parse(weft::weft_put(a = 1))$run, "run-file", label = paste("depth", depth))
  }
  tr <- run6_tree(9L)
  withr::local_dir(tr$here)
  expect_null(b6_parse(weft::weft_put(a = 1))$run)
})

test_that("review-6 #17: R takes the file before WEFT_RUN; beyond the search the env is used", {
  withr::local_envvar(c(WEFT_RUN = "env-run"))
  tr <- run6_tree(8L)
  withr::local_dir(tr$here)
  expect_identical(b6_parse(weft::weft_put(a = 1))$run, "run-file")
  tr9 <- run6_tree(9L)
  withr::local_dir(tr9$here)
  expect_identical(b6_parse(weft::weft_put(a = 1))$run, "env-run")
})

test_that("review-6 #17: Python and Julia look the same way (depth 8 found, 9 not; the file before WEFT_RUN)", {
  tr8 <- run6_tree(8L)
  tr9 <- run6_tree(9L)
  py <- py_plain(paste(
    "import os",
    "from weft import put",
    sprintf("os.environ['QUARTO_DOCUMENT_PATH'] = %s", deparse(tr8$here)),
    "put(a=1)",
    sprintf("os.environ['QUARTO_DOCUMENT_PATH'] = %s", deparse(tr9$here)),
    "put(a=1)",
    sep = "\n"), env = c(WEFT_RUN = "env-run"))
  expect_identical(py$status, 0L, label = py$stderr)
  runs <- regmatches(py$stdout, gregexpr("\"run\":(\"[^\"]*\"|null)", py$stdout))[[1]]
  expect_identical(runs, c("\"run\":\"run-file\"", "\"run\":\"env-run\""))
  jl <- jle_cases(c(
    sprintf("using Weft\nENV[\"QUARTO_DOCUMENT_PATH\"] = %s\nWeft.put(a=1)", deparse(tr8$here)),
    sprintf("using Weft\nENV[\"QUARTO_DOCUMENT_PATH\"] = %s\nWeft.put(a=1)", deparse(tr9$here))
  ), env = c(WEFT_RUN = "env-run"))
  expect_identical(jl[[1]]$blocks[[1]]$run, "run-file")
  expect_identical(jl[[2]]$blocks[[1]]$run, "env-run")
})

# ---- review-6 #20b: named-unpublished refuses a values file outside the root, as the filter does -----------

nu6 <- function(file_attr, doc_name = "a.qmd", file_at = NULL, env = parent.frame()) {
  body <- c("The `depth`{.num} here.", "", sprintf("````{.weft-values file=\"%s\"}", file_attr), "````")
  lines <- w6d_doc(body)
  root <- lint_proj(stats::setNames(list(lines), doc_name), weft_yml = "# weft", env = env)
  json <- "{\"weft\":1,\"values\":{\"depth\":{\"t\":\"float\",\"v\":\"1.5\"}}}"
  for (p in file_at) {
    target <- if (startsWith(p, "OUT/")) file.path(dirname(root), sub("^OUT/", "", p)) else file.path(root, p)
    dir.create(dirname(target), showWarnings = FALSE, recursive = TRUE)
    writeLines(json, target)
  }
  x <- lints(root, rules = NULL, tier = 1:2)
  lf_by_rule(x, "named-unpublished")
}

test_that("review-6 #20b: a values file that lies outside the project root does not publish its names", {
  x <- nu6("../vals.json", file_at = "OUT/vals.json")
  # today: the file is read, the name counts as published, and no finding is made
  expect_identical(nrow(x), 1L)
  expect_identical(x$message, W6D_E70("depth"))
  expect_identical(x$line, 5L)    # the line of the value's use (N144), not of the block
})

test_that("review-6 #20b control: a values file inside the root, by a relative path, a root path or a path with ../ that stays inside, publishes", {
  expect_identical(nrow(nu6("vals.json", file_at = "vals.json")), 0L)
  expect_identical(nrow(nu6("/vals.json", file_at = "vals.json")), 0L)
  expect_identical(nrow(nu6("../vals.json", doc_name = "sub/a.qmd", file_at = "vals.json")), 0L)
  # and a file that is not there publishes nothing
  expect_identical(nrow(suppressWarnings(nu6("nothere.json"))), 1L)
})

# ---- open-6 #18: E62 names the `_quarto.yml` form that was measured to work --------------------------------

e62_proj <- function(chunk) {
  dir <- tempfile("weft-e62-")
  dir.create(dir)
  dir <- normalizePath(dir, winslash = "/")
  writeLines(c("project:", "  type: default", "format: html"), file.path(dir, "_quarto.yml"))
  writeLines(c("---", "title: Home", "---", "", "Some text.", "", chunk), file.path(dir, "index.qmd"))
  withr::defer(unlink(dir, recursive = TRUE), envir = parent.frame())
  dir
}

e62_says <- function(dir) {
  msgs <- character()
  out <- utils::capture.output(withCallingHandlers(
    weft::use_quarto(dir),
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    }))
  c(msgs, out)
}

test_that("open-6 #18: for a julia-engine document use_quarto() names the _quarto.yml form: julia:, env: and JULIA_LOAD_PATH=", {
  s <- e62_says(e62_proj(c("```{julia}", "x = 1", "```")))
  txt <- paste(s, collapse = "\n")
  # today E62 only says Pkg.add(...), with no word of which environment
  expect_true(grepl("JULIA_LOAD_PATH=", txt, fixed = TRUE))
  expect_true(grepl("julia:", txt, fixed = TRUE))
  expect_true(grepl("env:", txt, fixed = TRUE))
})

test_that("open-6 #18 control: a project with no julia-engine document is told nothing of JULIA_LOAD_PATH", {
  for (chunk in list(c("```{r}", "x <- 1", "```"), c("```{python}", "x = 1", "```"), character())) {
    s <- e62_says(e62_proj(chunk))
    expect_false(any(grepl("JULIA_LOAD_PATH", s, fixed = TRUE)))
  }
})
