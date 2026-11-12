# Package 2e-1: what a chapter reads, the three new header fields, and the conditions held by
# tar_meta() (dev/design-2e.md P12-P18; dev/design-2d.md D4, D15, D27, D28). Written before the code.
# Made-up values only. Targets cases build a plain pipeline (no weft calls in _targets.R) with
# stock targets first. Renders are shared between tests through e1_memo().
if (!exists("e1_render")) source(Filter(file.exists, c(testthat::test_path("helper-2e1.R"), testthat::test_path("..", "helper-2e1.R")))[[1]])

DICT5 <- list(a = 1, b = 2, c = 3, d = 4, e = 9)

# ---- the dictionary, P12-P14 ---------------------------------------------------------------------

dict_doc <- function() e1_memo("reads-dict", function() {
  dir <- e1_tmp()
  lines <- c(
    "Inline `r dict$a`.", "",
    "```{r b}", "b_val <- dict[[\"b\"]]", "```", "",
    "```{r fn}", "h <- function() dict$c", "x <- h()", "```", "",
    "```{r skipped, eval=FALSE}", "dict$d", "```", "",
    "The count was `r 3`[, below the limit]{if=\"3 < dict$e\"}.")
  res <- e1_render(lines, dir, dict = e1_dict_lines(DICT5))
  res$dict_path <- file.path(dir, "dict.yml")
  res
})

test_that("2e-1 P13: the header holds dict, files and targets after the four fixed fields, in that order", {
  res <- dict_doc()
  line <- e1_header_line(res$dir)
  expect_true(startsWith(line, "{\"weft\":\"ledger\",\"version\":1,\"source\":\"doc.Rmd\",\"output\":\"doc\",\"dict\":{"))
  expect_identical(names(e1_header(res$dir)), c("weft", "version", "source", "output", "dict", "files", "targets"))
  # nothing was read from a store: targets is an empty object, not absent or an array
  expect_true(endsWith(line, "\"targets\":{}}"))
})

test_that("2e-1 P12: dict holds the keys read by inline R, a chunk, a function a chunk calls and an entry's expression", {
  res <- dict_doc()
  h <- e1_header(res$dir)
  expect_identical(names(h$dict), c("a", "b", "c", "e"))
})

test_that("2e-1 P12: a chunk with eval=FALSE adds nothing", {
  dk <- names(e1_header(dict_doc()$dir)$dict)
  expect_true("a" %in% dk)
  expect_false("d" %in% dk)
})

test_that("2e-1 P13 + P14: the values are weft:::dict_entry_hashes() of the key, 16 hex characters", {
  res <- dict_doc()
  hs <- weft:::dict_entry_hashes(res$dict_path)
  h <- e1_header(res$dir)$dict
  expect_identical(unlist(h), hs[names(h)])
  expect_true(all(grepl("^[0-9a-f]{16}$", unlist(h))))
  expect_named(hs, names(DICT5))
})

test_that("2e-1 P12: names(dict) records every key", {
  dir <- e1_tmp()
  res <- e1_render(c("```{r}", "n <- length(names(dict))", "```", "", "Done."), dir,
                   dict = e1_dict_lines(DICT5))
  expect_identical(names(e1_header(res$dir)$dict), names(DICT5)[order(names(DICT5))])
})

test_that("2e-1 P13: a document that reads no key and no target has three empty objects", {
  res <- d2_render(c("Value `r 1`."))
  line <- e1_header_line(res$dir)
  expect_true(endsWith(gsub("[0-9a-f]{16}", "<h>", line),
                       "\"dict\":{},\"files\":{\"doc.Rmd\":\"<h>\"},\"targets\":{}}"))
})

test_that("2e-1 P13: names inside each object are sorted byte by byte", {
  dir <- e1_tmp()
  d <- list(ab = 2, aa = 1, a_b = 5)
  res <- e1_render(c("`r dict$ab` `r dict$aa` `r dict$a_b`"), dir, dict = e1_dict_lines(d))
  # byte order: "_" (0x5f) sorts before "a" (0x61), which no locale collation does
  expect_identical(names(e1_header(res$dir)$dict), c("a_b", "aa", "ab"))
})

test_that("2e-1 P14: file_hash() is the xxhash64 of the bytes, and CR LF counts as LF", {
  d <- withr::local_tempdir()
  writeBin(charToRaw("abc"), file.path(d, "abc.txt"))
  expect_identical(weft:::file_hash(file.path(d, "abc.txt")), "78af5f94892f3950")
  writeBin(charToRaw("one\r\ntwo\r\n"), file.path(d, "crlf.txt"))
  writeBin(charToRaw("one\ntwo\n"), file.path(d, "lf.txt"))
  expect_identical(weft:::file_hash(file.path(d, "crlf.txt")), weft:::file_hash(file.path(d, "lf.txt")))
  writeBin(charToRaw("one\ntwo"), file.path(d, "other.txt"))
  expect_false(identical(weft:::file_hash(file.path(d, "other.txt")), weft:::file_hash(file.path(d, "lf.txt"))))
  expect_identical(weft:::file_hash(file.path(d, "lf.txt")),
                   cli::hash_raw_xxhash64(charToRaw("one\ntwo\n")))
})

test_that("2e-1 P14: a file that cannot be read has no hash (NA)", {
  d <- withr::local_tempdir()
  expect_true(is.na(weft:::file_hash(file.path(d, "absent.txt"))))
})

test_that("2e-1 P14: an entry's hash is the xxhash64 of the canonical JSON of its mapping, names sorted", {
  d <- withr::local_tempdir()
  p <- e1_dict(d, vals = list(a = 1))
  hs <- weft:::dict_entry_hashes(p)
  expect_identical(hs[["a"]], cli::hash_raw_xxhash64(charToRaw("{\"type\":\"number\",\"value\":1}")))
})

test_that("2e-1 P14: the order of an entry's fields does not change its hash; a changed value does", {
  d <- withr::local_tempdir()
  p1 <- file.path(d, "one.yml")
  p2 <- file.path(d, "two.yml")
  writeLines(c("a:", "  value: 1", "  type: number", "  definition: \"First.\""), p1)
  writeLines(c("a:", "  definition: \"First.\"", "  type: number", "  value: 1"), p2)
  expect_identical(weft:::dict_entry_hashes(p1), weft:::dict_entry_hashes(p2))
  writeLines(c("a:", "  type: number", "  value: 2", "  definition: \"First.\""), p2)
  expect_false(identical(weft:::dict_entry_hashes(p1)[["a"]], weft:::dict_entry_hashes(p2)[["a"]]))
})

test_that("2e-1 P14: a definition or a decision does not change an entry's hash; a value does", {
  d <- withr::local_tempdir()
  p <- e1_dict(d, vals = list(a = 1, b = 2), defs = list(a = "First."))
  h0 <- weft:::dict_entry_hashes(p)
  e1_dict(d, vals = list(a = 1, b = 2), defs = list(a = "A rewritten definition."), decision = list(a = 31))
  h1 <- weft:::dict_entry_hashes(p)
  expect_identical(h1, h0)
  e1_dict(d, vals = list(a = 7, b = 2))
  h2 <- weft:::dict_entry_hashes(p)
  expect_false(identical(h2[["a"]], h0[["a"]]))
  expect_identical(h2[["b"]], h0[["b"]])
})

test_that("2e-1 P14: changing a definition and re-rendering leaves the ledger byte-identical", {
  dir <- e1_tmp()
  lines <- c("Value `r dict$a`.")
  e1_render(lines, dir, dict = e1_dict_lines(list(a = 1, b = 2), list(a = "First.")))
  before <- d2_bytes(d2_path(dir))
  expect_identical(names(e1_header(dir)$dict), "a")
  e1_render(lines, dir, dict = e1_dict_lines(list(a = 1, b = 2), list(a = "A new definition.")))
  expect_identical(d2_bytes(d2_path(dir)), before)
})

test_that("2e-1 P14: changing a value changes that key's hash in the header and no other", {
  dir <- e1_tmp()
  lines <- c("Value `r dict$a` and `r dict$b`.")
  e1_render(lines, dir, dict = e1_dict_lines(list(a = 1, b = 2)))
  h0 <- e1_header(dir)$dict
  e1_render(lines, dir, dict = e1_dict_lines(list(a = 8, b = 2)))
  h1 <- e1_header(dir)$dict
  expect_false(identical(h1$a, h0$a))
  expect_identical(h1$b, h0$b)
})

# ---- the files, P13 ---------------------------------------------------------------------------------

test_that("2e-1 P13: files holds the source and a child, with file_hash() of each, paths with /", {
  dir <- e1_tmp()
  res <- e1_render(c("Before.", "", "```{r child=\"part.Rmd\"}", "```"), dir,
                   files = list("part.Rmd" = c("Part text `r 1`.")))
  f <- e1_header(dir)$files
  expect_identical(names(f), c("doc.Rmd", "part.Rmd"))
  expect_identical(f[["doc.Rmd"]], weft:::file_hash(file.path(dir, "doc.Rmd")))
  expect_identical(f[["part.Rmd"]], weft:::file_hash(file.path(dir, "part.Rmd")))
})

test_that("2e-1 P12: a key read in a child is in the parent's header (a child has no header of its own)", {
  dir <- e1_tmp()
  res <- e1_render(c("```{r child=\"part.Rmd\"}", "```"), dir, dict = e1_dict_lines(list(a = 1, b = 2)),
                   files = list("part.Rmd" = c("Child `r dict$b`.")))
  expect_identical(names(e1_header(dir)$dict), "b")
  expect_false(file.exists(d2_path(dir, source = "part.Rmd", output = "part")))
})

test_that("2e-1 P12: a file in a subfolder is written relative to the root with /", {
  dir <- e1_tmp()
  res <- e1_render(c("```{r child=\"parts/part.Rmd\"}", "```"), dir,
                   files = list("parts/part.Rmd" = c("Child text.")))
  expect_true("parts/part.Rmd" %in% names(e1_header(dir)$files))
})

test_that("2e-1 P12: a render served partly from the chunk cache writes the same header as the first", {
  dir <- e1_tmp()
  lines <- c("```{r cached, cache=TRUE}", "v <- dict$a", "```", "", "Value `r v`.")
  d <- e1_dict_lines(list(a = 1, b = 2))
  e1_render(lines, dir, dict = d)
  first <- e1_header_line(dir)
  expect_true(dir.exists(file.path(dir, "cache")))
  e1_render(lines, dir, dict = d)
  expect_identical(e1_header_line(dir), first)
  expect_identical(names(e1_header(dir)$dict), "a")
})

# ---- targets, P13, P15, P18 -------------------------------------------------------------------------

READ_FIT <- c("```{r fit}", "fit_val <- tar_read(fit)", "```", "", "Inline `r targets::tar_read(fit)`.")

fit_render <- function() e1_memo("reads-fit", function() {
  dir <- e1_plain_dir()
  res <- e1_render(READ_FIT, dir)
  res$hash <- e1_data_hash(dir, "fit")
  res
})

test_that("2e-1 P13: targets is {\"_targets\":{\"fit\":<data hash>}} with tar_meta()'s hash", {
  res <- fit_render()
  expect_true(endsWith(gsub("[0-9a-f]{16}", "<h>", e1_header_line(res$dir)),
                       "\"targets\":{\"_targets\":{\"fit\":\"<h>\"}}}"))
  expect_identical(e1_header(res$dir)$targets[["_targets"]][["fit"]], res$hash)
  expect_identical(names(e1_header(res$dir)$targets), "_targets")
})

test_that("2e-1 P18: last_knit()$reads holds dict, files and targets as in the header", {
  res <- fit_render()
  r <- res$knit$reads
  expect_named(r, c("dict", "files", "targets"))
  expect_identical(r$targets, list("_targets" = c(fit = res$hash)))
  expect_identical(names(r$files), "doc.Rmd")
  expect_type(r$files, "character")
  expect_identical(unname(r$files), e1_header(res$dir)$files[["doc.Rmd"]])
})

test_that("2e-1 P15: the targets read give condition lines: fit's two warnings are one line, text as targets stored it", {
  res <- fit_render()
  ln <- d2_lines(d2_path(res$dir, conditions = TRUE))
  expect_true("{\"from\":\"target\",\"source\":\"fit\",\"class\":\"warning\",\"normalised\":\"first <n>. second\",\"text\":\"first 5. second\"}" %in% ln)
})

test_that("2e-1 P15 + P16: a target upstream of one read is in the log; one not read or upstream is not", {
  res <- fit_render()
  ln <- d2_lines(d2_path(res$dir, conditions = TRUE))
  expect_true("{\"from\":\"target\",\"source\":\"up\",\"class\":\"warning\",\"normalised\":\"upstream warned <n> times\",\"text\":\"upstream warned 3 times\"}" %in% ln)
  expect_false(any(grepl("\"source\":\"other\"", ln, fixed = TRUE)))
  expect_false(any(grepl("other warned", ln, fixed = TRUE)))
})

test_that("2e-1 P15: target lines are not in last_knit()$conditions; 2d sorts them into the log", {
  res <- fit_render()
  expect_false(any(grepl("first 5", unlist(res$knit$conditions), fixed = TRUE)))
  cl <- res$knit$condition_log
  expect_s3_class(cl, "weft_condition_log")
  expect_true(all(c("fit", "up") %in% cl$source[cl$from == "target"]))
  # D15 order: sorted on from, source, class, normalised byte by byte
  keys <- paste(cl$from, cl$source, cl$class, cl$normalised, sep = "\r")
  expect_identical(keys, keys[order(keys, method = "radix")])
})

test_that("2e-1 P15: the log carries forward the text of a line it already has (D16)", {
  dir <- e1_plain_dir()
  e1_render(READ_FIT, dir)
  p <- d2_path(dir, conditions = TRUE)
  old <- d2_lines(p)
  # a hand-edited text under the same key survives a re-render
  edited <- sub("\"text\":\"first 5. second\"", "\"text\":\"first 5. second (kept)\"", old, fixed = TRUE)
  writeLines(edited, p, useBytes = TRUE)
  e1_render(READ_FIT, dir)
  expect_true(any(grepl("first 5. second (kept)", d2_lines(p), fixed = TRUE)))
})

test_that("2e-1 P15: a pattern's branches that each warn give one line, under the pattern's name", {
  script <- c("library(targets)", "list(",
              "  tar_target(idx, 1:3),",
              "  tar_target(brx, {warning('branch warned'); 1}, pattern = map(idx)))")
  dir <- e1_plain_dir(script)
  res <- e1_render(c("```{r}", "v <- tar_read(brx)", "```"), dir)
  ln <- d2_conds(res)
  hit <- d2_pick(ln, from = "target")
  expect_length(hit, 1L)
  expect_identical(hit[[1]]$source, "brx")
  expect_identical(hit[[1]]$normalised, "branch warned")
  # the pattern's own row is the hash in the header
  expect_identical(e1_header(res$dir)$targets[["_targets"]][["brx"]], e1_data_hash(dir, "brx"))
})

test_that("2e-1 P15: a target that errored (error = \"null\") upstream of the read gives a line of class error", {
  script <- c("library(targets)", "list(",
              "  tar_target(bad, stop('bad thing 4'), error = 'null'),",
              "  tar_target(fit, {bad; 1}))")
  dir <- e1_plain_dir(script)
  res <- e1_render(c("```{r}", "v <- tar_read(fit)", "```"), dir)
  ln <- d2_pick(d2_conds(res), from = "target", class = "error")
  expect_length(ln, 1L)
  expect_identical(ln[[1]]$source, "bad")
  expect_identical(ln[[1]]$text, "bad thing 4")
  expect_identical(ln[[1]]$normalised, "bad thing <n>")
})

# ---- the severity list on target conditions, P15 ----------------------------------------------------

HESSIAN <- c("library(targets)", "list(",
             "  tar_target(fit, {warning('non-positive-definite Hessian matrix'); 1}))")

test_that("2e-1 P15: a target warning that matches the severity list fails the render (not draft)", {
  dir <- e1_plain_dir(HESSIAN)
  res <- e1_render(c("```{r}", "v <- tar_read(fit)", "```"), dir, may_fail = TRUE)
  expect_true(res$failed)
  expect_true(grepl("target fit: warning: non-positive-definite Hessian matrix", res$message, fixed = TRUE))
})

test_that("2e-1 P15: in draft mode it is listed as a failure of kind condition and is not a log line", {
  dir <- e1_plain_dir(HESSIAN)
  res <- e1_render(c("```{r}", "v <- tar_read(fit)", "```"), dir, env = c(WEFT_DRAFT = "1"))
  expect_false(res$failed, label = res$message)
  f <- unlist(res$knit$failures)
  expect_true(any(grepl("target fit: warning: non-positive-definite Hessian matrix", f, fixed = TRUE)))
  expect_length(d2_pick(d2_conds(res), from = "target"), 0L)
  expect_false(any(grepl("Hessian", d2_lines(d2_path(res$dir, conditions = TRUE)), fixed = TRUE)))
})

# ---- upstream, P16 ----------------------------------------------------------------------------------

test_that("2e-1 P16: with no pipeline script the render warns weft_ledger_warning; the log has fit's line and not up's", {
  dir <- e1_plain_dir()
  file.rename(file.path(dir, "_targets.R"), file.path(dir, "_targets.R.off"))
  res <- d2_run(READ_FIT, dir = dir, code = E1_LIB)
  expect_false(res$failed)
  w <- d2_of_class(res, "weft_ledger_warning")
  expect_length(w, 1L)
  msg <- e1_flat(d2_msgs(w))
  expect_true(grepl("the targets upstream of fit", msg, fixed = TRUE))
  expect_true(grepl("were not read", msg, fixed = TRUE))
  expect_true(grepl("rule 7.4.1", msg, fixed = TRUE))
  sources <- vapply(d2_pick(d2_conds(res), from = "target"), `[[`, "", "source")
  expect_identical(sources, "fit")
})

test_that("2e-1 P16: a store with its script present raises no weft_ledger_warning", {
  dir <- e1_plain_dir()
  res <- d2_run(READ_FIT, dir = dir, code = E1_LIB)
  expect_length(d2_of_class(res, "weft_ledger_warning"), 0L)
})

edge_script <- c("library(targets)", "list(",
                 "  tar_target(base, {warning('base warned'); 1}),",
                 "  tar_target(up, {warning('upstream warned 3 times'); base + 1}),",
                 "  tar_target(fit, {warning('first 5'); warning('second'); up + 1}))")

test_that("2e-1 P16 (review #4/B): the edges are cached on the store, so a make refreshes them even under the same run id", {
  dir <- e1_plain_dir()
  run <- function() e1_render(READ_FIT, dir, files = list(".weft/run" = "run-1"))
  run()
  expect_true(file.exists(file.path(dir, ".weft", "targets", "network.rds")))
  run()
  # the pipeline gains an edge (base -> up) and is rebuilt
  writeLines(edge_script, file.path(dir, "_targets.R"))
  e1_make(dir, plain = TRUE)
  sources <- vapply(d2_pick(d2_conds(run()), from = "target"), `[[`, "", "source")
  expect_true("base" %in% sources)
})

# ---- where it does not run, P17, P18 ----------------------------------------------------------------

test_that("2e-1 P17: a project that is not set up has no 2e fields, no target lines, reads NULL, no .weft/targets", {
  dir <- e1_plain_dir()
  res <- e1_render(READ_FIT, dir, set_up = FALSE)
  expect_null(res$knit$reads)
  expect_false(dir.exists(file.path(dir, "_weft")))
  expect_false(dir.exists(file.path(dir, ".weft", "targets")))
})

test_that("2e-1 P17: WEFT_REHEARSE=1 reads nothing: no ledger, no .weft/targets, reads NULL", {
  dir <- e1_plain_dir()
  res <- e1_render(READ_FIT, dir, env = c(WEFT_REHEARSE = "1"))
  expect_null(res$knit$reads)
  expect_false(file.exists(d2_path(dir)))
  expect_false(dir.exists(file.path(dir, ".weft", "targets")))
})

test_that("2e-1 P18: reads is NULL for a rehearsal of a set-up project too (P12 did not run)", {
  res <- d2_render(c("Value `r 1`."), env = c(WEFT_REHEARSE = "1"))
  expect_null(res$knit$reads)
})

test_that("2e-1 P17: with targets reported absent a function that reads fit but is never called records fit with a null hash", {
  dir <- e1_plain_dir()
  e1_no_targets()
  res <- e1_render(c("```{r}", "g <- function() tar_read(fit)", "```", "", "Text."), dir)
  expect_false(res$failed)
  line <- e1_header_line(res$dir)
  expect_true(endsWith(line, "\"targets\":{\"_targets\":{\"fit\":null}}}"))
  expect_length(d2_pick(d2_conds(res), from = "target"), 0L)
  expect_identical(res$knit$reads$targets[["_targets"]][["fit"]], NA_character_)
})

test_that("2e-1 P13: a store that does not exist gives a null hash and no condition lines", {
  dir <- e1_tmp()
  res <- e1_render(c("```{r}", "g <- function() tar_read(fit)", "```", "", "Text."), dir)
  expect_false(res$failed, label = res$message)
  expect_true(endsWith(e1_header_line(dir), "\"targets\":{\"_targets\":{\"fit\":null}}}"))
  expect_length(d2_pick(d2_conds(res), from = "target"), 0L)
})

test_that("2e-1 P13: a literal store argument is kept and written relative to the root", {
  proj <- e1_tmp()
  sub <- file.path(proj, "reports")
  other <- file.path(proj, "store-root")
  dir.create(sub)
  dir.create(other)
  e1_plain_dir(dir = other)
  res <- e1_render(c("```{r}", "v <- tar_read(fit, store = \"../store-root/_targets\")", "```"), dir = sub)
  tg <- e1_header(sub)$targets
  expect_identical(names(tg), "../store-root/_targets")
  expect_identical(names(tg[[1]]), "fit")
  expect_identical(tg[[1]][["fit"]], e1_data_hash(other, "fit"))
})
