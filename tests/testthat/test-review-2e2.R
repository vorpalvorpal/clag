# Regression tests for the review of 2e-2 (dev/review-2e2.md) and its rulings (dev/design-2e.md,
# "Rulings on the review of 2e-2"). Fixtures are hand-written ledgers (helper-2e2.R) in temporary git
# repositories. Non-ASCII is written as \uXXXX. Made-up values only.

DICT_Q <- function(v = 1, unit = "km")
  sprintf("lim: {value: %s, unit: %s, type: quantity, definition: \"The limit.\"}", v, unit)
DICT_N <- function(v) sprintf("limit: {value: %s, type: number, definition: \"The limit.\"}", v)

# four entries of one source, for the rename tests; x1 gets `first`/`raw1`
ren_entries <- function(file, first = "3", raw1 = 3) {
  list(e2x_entry("x1", first, section = "s", kind = "bare", raw = raw1, file = file,
                 sentence = paste("Total", first, "here.")),
       e2x_entry("x2", "2", section = "s", file = file), e2x_entry("x3", "3", section = "s", file = file),
       e2x_entry("x4", "4", section = "s", file = file))
}

# ---- 1: a renamed source is paired ---------------------------------------------------------------

test_that("review 2e2 #1: a rename with the old ledger left on disk and outputs a and b is `renamed`", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_project()
  e2x_put_ledger(dir, "a.qmd", ren_entries("a.qmd"))
  e2x_commit(dir)
  unlink(file.path(dir, "a.qmd"))
  e2x_put_ledger(dir, "b.qmd", ren_entries("b.qmd", "30", 30))
  expect_true(file.exists(file.path(dir, "_weft", "ledger", "a.qmd", "a.jsonl")))
  ch <- changes(path = dir)
  expect_identical(ch$ledgers$ledger[ch$ledgers$status == "renamed"], "b.qmd")
  expect_identical(ch$ledgers$from[ch$ledgers$ledger == "b.qmd"], "a.qmd")
  expect_false("new" %in% ch$ledgers$status)
  expect_identical(nrow(ch$entries), 1L)
  expect_identical(ch$entries$change, "changed")
  expect_identical(ch$entries$expr, "x1")
  expect_identical(ch$entries$file, "b.qmd")
  expect_identical(ch$entries$structural, "order of magnitude")
  expect_true(any(grepl("b.qmd (b): renamed from a.qmd", e2x_print(ch), fixed = TRUE)))
})

test_that("review 2e2 #1: the same with the old ledger folder deleted", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_project()
  e2x_put_ledger(dir, "a.qmd", ren_entries("a.qmd"))
  e2x_commit(dir)
  unlink(file.path(dir, "_weft", "ledger", "a.qmd"), recursive = TRUE)
  unlink(file.path(dir, "a.qmd"))
  e2x_put_ledger(dir, "b.qmd", ren_entries("b.qmd", "30", 30))
  ch <- changes(path = dir)
  expect_identical(ch$ledgers$status, "renamed")
  expect_identical(ch$entries$structural, "order of magnitude")
})

test_that("review 2e2 #1: control, equal output names pair with the old ledger left on disk", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_project()
  e2x_put_ledger(dir, "a.qmd", ren_entries("a.qmd"), output = "out")
  e2x_commit(dir)
  unlink(file.path(dir, "a.qmd"))
  e2x_put_ledger(dir, "b.qmd", ren_entries("b.qmd", "30", 30), output = "out")
  ch <- changes(path = dir)
  expect_identical(ch$ledgers$status[ch$ledgers$ledger == "b.qmd"], "renamed")
})

test_that("review 2e2 #1: an old source that still exists is not a rename candidate", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_project()
  e2x_put_ledger(dir, "a.qmd", ren_entries("a.qmd"))
  e2x_commit(dir)
  e2x_put_ledger(dir, "b.qmd", ren_entries("b.qmd", "30", 30))
  ch <- changes(path = dir)
  st <- setNames(ch$ledgers$status, ch$ledgers$ledger)
  expect_identical(st[["b.qmd"]], "new")
})

test_that("review 2e2 #1: outputs that differ and are not each their source's base name pair nothing", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_project()
  e2x_put_ledger(dir, "a.qmd", ren_entries("a.qmd"), output = "a")
  e2x_commit(dir)
  unlink(file.path(dir, "a.qmd"))
  e2x_put_ledger(dir, "b.qmd", ren_entries("b.qmd"), output = "report")
  ch <- changes(path = dir)
  expect_false("renamed" %in% ch$ledgers$status)
})

# ---- 2, 4, 5: names ------------------------------------------------------------------------------

put_or_skip <- function(dir, source, ..., output = NULL) {
  ok <- tryCatch({
    if (is.null(output)) e2x_put_ledger(dir, source, ...) else e2x_put_ledger(dir, source, ..., output = output)
    TRUE
  }, error = function(e) FALSE, warning = function(w) FALSE)
  testthat::skip_if_not(ok && file.exists(file.path(dir, "_weft", "ledger", source,
                        paste0(if (is.null(output)) sub("\\.[A-Za-z]+$", "", basename(source)) else output, ".jsonl"))),
                        "this file system refuses the name")
}

test_that("review 2e2 #2: a non-ASCII source name is compared", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_project()
  src <- "données.qmd"
  put_or_skip(dir, src, list(e2x_entry("x", "1")))
  e2x_commit(dir)
  put_or_skip(dir, src, list(e2x_entry("x", "2")))
  ch <- changes(path = dir)
  expect_identical(nrow(ch$entries), 1L)
  expect_identical(enc2utf8(ch$entries$ledger), src)
  expect_identical(c(ch$entries$text_before, ch$entries$text_after), c("1", "2"))
})

test_that("review 2e2 #2: a non-ASCII output name is compared", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_project()
  out <- "résumé"
  put_or_skip(dir, "a.qmd", list(e2x_entry("x", "1")), output = out)
  e2x_commit(dir)
  put_or_skip(dir, "a.qmd", list(e2x_entry("x", "2")), output = out)
  ch <- changes(path = dir)
  expect_identical(nrow(ch$entries), 1L)
  expect_identical(enc2utf8(ch$entries$output), out)
})

test_that("review 2e2 #2: a non-ASCII ledger present only at the commit is `deleted`", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_project()
  src <- "données.qmd"
  put_or_skip(dir, src, list(e2x_entry("x", "1")))
  e2x_commit(dir)
  unlink(file.path(dir, "_weft", "ledger"), recursive = TRUE)
  ch <- changes(path = dir)
  expect_identical(ch$ledgers$status, "deleted")
  expect_identical(enc2utf8(ch$ledgers$ledger), src)
})

test_that("review 2e2 #2: control, an ASCII name in the same layout compares", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(list(e2x_entry("x", "1")), list(e2x_entry("x", "2")))
  expect_identical(nrow(changes(path = dir)$entries), 1L)
})

test_that("review 2e2 #4: a ledger under a dot-folder is found, and compared", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_project()
  put_or_skip(dir, ".drafts/a.qmd", list(e2x_entry("x", "1")))
  e2x_commit(dir)
  put_or_skip(dir, ".drafts/a.qmd", list(e2x_entry("x", "2")))
  ch <- changes(path = dir)
  expect_identical(ch$ledgers$status, "compared")
  expect_identical(ch$ledgers$ledger, ".drafts/a.qmd")
  expect_identical(nrow(ch$entries), 1L)
  expect_identical(ch$entries$change, "changed")
})

test_that("review 2e2 #4: an output name that starts with a dot is found", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_project()
  put_or_skip(dir, "a.qmd", list(e2x_entry("x", "1")), output = ".hidden")
  e2x_commit(dir)
  put_or_skip(dir, "a.qmd", list(e2x_entry("x", "2")), output = ".hidden")
  ch <- changes(path = dir)
  expect_identical(ch$ledgers$status, "compared")
  expect_identical(nrow(ch$entries), 1L)
})

test_that("review 2e2 #5: a source name holding a double quote is found at the commit; unchanged prints no change", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_project()
  src <- "say \"hi\".qmd"
  put_or_skip(dir, src, list(e2x_entry("x", "1")))
  e2x_commit(dir)
  ch <- changes(path = dir)
  expect_identical(ch$ledgers$status, "compared")
  out <- e2x_print(ch)
  expect_identical(out[nzchar(trimws(out))],
                   sprintf("weft: no changes since HEAD (%s); 1 ledger compared.", substr(e2x_head(dir), 1, 7)))
})

test_that("review 2e2 #5: the same name with a changed value gives one changed row", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_project()
  src <- "say \"hi\".qmd"
  put_or_skip(dir, src, list(e2x_entry("x", "1")))
  e2x_commit(dir)
  put_or_skip(dir, src, list(e2x_entry("x", "2")))
  ch <- changes(path = dir)
  expect_identical(nrow(ch$entries), 1L)
  expect_identical(ch$entries$change, "changed")
})

test_that("review 2e2 #5: a backslash in the name is found at the commit", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_project()
  src <- "back\\slash.qmd"
  put_or_skip(dir, src, list(e2x_entry("x", "1")))
  e2x_commit(dir)
  ch <- changes(path = dir)
  expect_identical(ch$ledgers$status, "compared")
})

# ---- 3: identical expressions, one deleted ---------------------------------------------------------

three_k <- function(texts = c("3", "3", "3"), keep = 1:3) {
  s <- c("All %s samples passed.", "Another %s here.", "And %s again.")
  e <- lapply(1:3, function(i) e2x_entry("k", texts[i], section = "results", kind = "bare", occ = i,
                                         raw = as.numeric(texts[i]), sentence = sprintf(s[i], texts[i])))
  e[keep]
}
reocc <- function(es) { for (i in seq_along(es)) es[[i]]$occ <- i; es }

test_that("review 2e2 #3: deleting the first of three identical expressions removes that sentence", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(three_k(), reocc(three_k(keep = 2:3)))
  r <- changes(path = dir)$entries
  expect_identical(nrow(r), 1L)
  expect_identical(r$change, "removed")
  expect_identical(r$sentence_before, "All 3 samples passed.")
})

test_that("review 2e2 #3: deleting the middle one removes the middle sentence", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(three_k(), reocc(three_k(keep = c(1, 3))))
  r <- changes(path = dir)$entries
  expect_identical(nrow(r), 1L)
  expect_identical(r$change, "removed")
  expect_identical(r$sentence_before, "Another 3 here.")
})

test_that("review 2e2 #3: deleting the last one removes the last sentence (control)", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(three_k(), three_k(keep = 1:2))
  r <- changes(path = dir)$entries
  expect_identical(nrow(r), 1L)
  expect_identical(r$change, "removed")
  expect_identical(r$sentence_before, "And 3 again.")
})

test_that("review 2e2 #3: when the values differ, deleting the first is still one removed entry", {
  skip_if(Sys.which("git") == "")
  tx <- c("3", "4", "5")
  dir <- e2x_scenario(three_k(tx), reocc(three_k(tx, keep = 2:3)))
  r <- changes(path = dir)$entries
  expect_identical(nrow(r), 1L)
  expect_identical(r$change, "removed")
  expect_identical(r$text_before, "3")
})

test_that("review 2e2 #3: a value changed in one of the remaining occurrences is still reported", {
  skip_if(Sys.which("git") == "")
  tx <- c("3", "4", "5")
  after <- reocc(three_k(tx, keep = 2:3))
  after[[2]]$text <- "9"
  after[[2]]$sentence <- "And 9 again."
  dir <- e2x_scenario(three_k(tx), after)
  r <- changes(path = dir)$entries
  expect_setequal(r$change, c("removed", "changed"))
  expect_identical(r$text_before[r$change == "removed"], "3")
  expect_identical(r$text_after[r$change == "changed"], "9")
})

# ---- 6: an exact tenfold change ----------------------------------------------------------------------

test_that("review 2e2 #6: 0.07 to 0.7 is an order of magnitude, with its near variants", {
  skip_if(Sys.which("git") == "")
  for (p in list(c(0.07, 0.7), c(0.021, 0.21), c(0.029, 0.29), c(0.7, 0.07))) {
    r <- e2x_rows(e2x_entry("m", as.character(p[1]), raw = p[1]), e2x_entry("m", as.character(p[2]), raw = p[2]))
    expect_identical(r$structural, "order of magnitude", label = paste(p, collapse = " -> "))
  }
})

test_that("review 2e2 #6: controls, 0.06 to 0.6 flagged and 9.9 to 10.1 not", {
  skip_if(Sys.which("git") == "")
  r <- e2x_rows(e2x_entry("m", "0.06", raw = 0.06), e2x_entry("m", "0.6", raw = 0.6))
  expect_identical(r$structural, "order of magnitude")
  r2 <- e2x_rows(e2x_entry("m", "9.9", raw = 9.9), e2x_entry("m", "10.1", raw = 10.1))
  expect_identical(r2$structural, "")
  r3 <- e2x_rows(e2x_entry("m", "0.07", raw = 0.07), e2x_entry("m", "0.65", raw = 0.65))
  expect_identical(r3$structural, "")
})

# ---- 7: the unit of raw ---------------------------------------------------------------------------------

unit_rows <- function(b, a, ..., dict = DICT_Q()) {
  e2x_rows(e2x_entry("len", b$text, raw = b$raw, unit = b$unit, dict = "dict$lim"),
           e2x_entry("len", a$text, raw = a$raw, unit = a$unit, dict = "dict$lim"), dict_before = dict)
}

test_that("review 2e2 #7: 1.2 km (raw 1200 m) to 0.8 km (raw 800 m) crosses a limit of 1 km", {
  skip_if(Sys.which("git") == "")
  r <- unit_rows(list(text = "1.2 km", raw = 1200, unit = "m"), list(text = "0.8 km", raw = 800, unit = "m"))
  expect_identical(r$structural, "crosses dict$lim")
})

test_that("review 2e2 #7: near variants, the same unit and another convertible unit", {
  skip_if(Sys.which("git") == "")
  r <- unit_rows(list(text = "1.2 km", raw = 1.2, unit = "km"), list(text = "0.8 km", raw = 0.8, unit = "km"))
  expect_identical(r$structural, "crosses 1.0, crosses dict$lim")
  r2 <- unit_rows(list(text = "1.2 km", raw = 1200000, unit = "mm"), list(text = "0.8 km", raw = 800000, unit = "mm"))
  expect_identical(r2$structural, "crosses dict$lim")
  r3 <- unit_rows(list(text = "800 m", raw = 800, unit = "m"), list(text = "1.2 km", raw = 1200, unit = "m"))
  expect_identical(r3$structural, "crosses dict$lim")
})

test_that("review 2e2 #7: a change that stays on one side of the limit, once converted, is not a crossing", {
  skip_if(Sys.which("git") == "")
  r <- unit_rows(list(text = "1.2 km", raw = 1200, unit = "m"), list(text = "1.1 km", raw = 1100, unit = "m"))
  expect_identical(r$structural, "")
  r2 <- unit_rows(list(text = "0.5 km", raw = 500, unit = "m"), list(text = "0.6 km", raw = 600, unit = "m"))
  expect_identical(r2$structural, "")
})

test_that("review 2e2 #7: a plain number against a quantity threshold gives no crossing reason", {
  skip_if(Sys.which("git") == "")
  r <- unit_rows(list(text = "0.8", raw = 0.8, unit = NA_character_), list(text = "1.2", raw = 1.2, unit = NA_character_))
  expect_false(grepl("dict$lim", r$structural, fixed = TRUE))
  r2 <- unit_rows(list(text = "0.8", raw = 0.8, unit = NA_character_), list(text = "1.2 km", raw = 1.2, unit = "km"))
  expect_false(grepl("dict$lim", r2$structural, fixed = TRUE))
})

test_that("review 2e2 #7: units that do not convert to the threshold's give no crossing reason", {
  skip_if(Sys.which("git") == "")
  r <- unit_rows(list(text = "1.2 s", raw = 1.2, unit = "s"), list(text = "0.8 s", raw = 0.8, unit = "s"))
  expect_false(grepl("dict$lim", r$structural, fixed = TRUE))
})

test_that("review 2e2 #7: old ledger lines without the field still read and compare", {
  skip_if(Sys.which("git") == "")
  r <- unit_rows(list(text = "1.2 km", raw = 1200, unit = NULL), list(text = "0.8 km", raw = 800, unit = NULL))
  expect_identical(nrow(r), 1L)
  expect_false(grepl("dict$lim", r$structural, fixed = TRUE))
  r2 <- unit_rows(list(text = "1.2 km", raw = 1200, unit = NULL), list(text = "0.8 km", raw = 800, unit = "m"))
  expect_identical(nrow(r2), 1L)
  expect_identical(r2$change, "changed")
})

test_that("review 2e2 #7: a number threshold is still compared with a unitless raw whose unit is null", {
  skip_if(Sys.which("git") == "")
  r <- e2x_rows(e2x_entry("ratio", "0.8", raw = 0.8, unit = NA_character_, dict = "dict$limit"),
                e2x_entry("ratio", "0.9", raw = 0.9, unit = NA_character_, dict = "dict$limit"),
                dict_before = DICT_N(0.85))
  expect_identical(r$structural, "crosses dict$limit")
})

test_that("review 2e2 #7: the field is read back by the 2d reader (a unit string or null)", {
  lines <- e2x_ledger_lines("a.qmd", "a", list(e2x_entry("x", "1", raw = 1200, unit = "m"),
                                               e2x_entry("y", "2", raw = 2, unit = NA_character_)))
  expect_match(lines[2], "\"raw\":1200,\"unit\":\"m\",\"failed\"", fixed = TRUE)
  expect_match(lines[3], "\"raw\":2,\"unit\":null,\"failed\"", fixed = TRUE)
  x <- weft:::read_ledger(lines = lines)
  expect_identical(nrow(x), 2L)
})

# ---- 8: the entry's own text is removed as a whole word ------------------------------------------------

claim_of <- function(text, sentence, text_after = "12", sentence_after = "Plain words here.") {
  r <- e2x_rows(e2x_entry("n", text, raw = 10, sentence = sentence),
                e2x_entry("n", text_after, raw = 12, sentence = sentence_after))
  r$claim_word
}

test_that("review 2e2 #8: `ten` inside `Often` is not removed as the value, so it is not its own claim word", {
  skip_if(Sys.which("git") == "")
  expect_true(is.na(claim_of("ten", "Often ten sites.")))
})

test_that("review 2e2 #8: `one` inside `Someone` likewise", {
  skip_if(Sys.which("git") == "")
  expect_true(is.na(claim_of("one", "Someone saw one site.")))
})

test_that("review 2e2 #8: a real claim word beside the embedded text is still found", {
  skip_if(Sys.which("git") == "")
  expect_identical(claim_of("ten", "Often ten sites, all open."), "all")
})

test_that("review 2e2 #8: a `none` left once the value is removed counts (whole word)", {
  skip_if(Sys.which("git") == "")
  expect_identical(claim_of("one", "None but one site."), "none")
})

test_that("review 2e2 #8: control, the whole-word value alone has no claim word", {
  skip_if(Sys.which("git") == "")
  expect_true(is.na(claim_of("Ten", "Ten sites.")))
})

# ---- 9: the hash of an entry ignores field order -------------------------------------------------------------

test_that("review 2e2 #9: dict_entry_hashes() ignores the order of an entry's fields and sees a value change", {
  f <- withr::local_tempfile(fileext = ".yml")
  g <- withr::local_tempfile(fileext = ".yml")
  h <- withr::local_tempfile(fileext = ".yml")
  writeLines("lim: {value: 0.85, type: number, definition: \"A limit.\"}", f)
  writeLines("lim: {type: number, value: 0.85, definition: \"A limit.\"}", g)
  writeLines("lim: {value: 0.9, type: number, definition: \"A limit.\"}", h)
  expect_identical(weft:::dict_entry_hashes(f), weft:::dict_entry_hashes(g))
  expect_false(identical(weft:::dict_entry_hashes(f), weft:::dict_entry_hashes(h)))
  # near variants: a reworded definition changes nothing; a changed type does
  k <- withr::local_tempfile(fileext = ".yml")
  writeLines("lim: {value: 0.85, type: number, definition: \"Other words.\"}", k)
  expect_identical(weft:::dict_entry_hashes(f), weft:::dict_entry_hashes(k))
})

test_that("review 2e2 #9: the helper's own hash agrees with weft's, reordered or not", {
  f <- withr::local_tempfile(fileext = ".yml")
  writeLines(c("lim: {type: number, definition: x, value: 0.85}", "b: {value: 2, type: number, definition: y}"), f)
  expect_identical(e2x_dict_hashes(f), weft:::dict_entry_hashes(f))
})

test_that("review 2e2 #9: a reordered entry is not stale; a changed value is", {
  dir <- e2x_state_project()
  e2x_write(file.path(dir, "dict.yml"), "lim: {value: 0.85, type: number, definition: \"A limit.\"}")
  hs <- weft:::dict_entry_hashes(file.path(dir, "dict.yml"))
  e2x_write(file.path(dir, "dict.yml"), "lim: {type: number, value: 0.85, definition: \"A limit.\"}")
  st <- weft:::ledger_state(dir, e2x_header(dict = hs))
  expect_false(st$stale)
  expect_identical(st$reasons, character())
  e2x_write(file.path(dir, "dict.yml"), "lim: {type: number, value: 0.9, definition: \"A limit.\"}")
  expect_identical(weft:::ledger_state(dir, e2x_header(dict = hs))$reasons, "dict$lim changed")
})

# ---- 10: (not re-rendered) on every listed entry of a stale ledger -----------------------------------------------

test_that("review 2e2 #10: changed, added and removed rows of a stale ledger all carry (not re-rendered)", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_project()
  e2x_put_ledger(dir, "a.qmd", list(e2x_entry("x", "1"), e2x_entry("med", "2", section = "flow")))
  e2x_commit(dir)
  e2x_put_ledger(dir, "a.qmd", list(e2x_entry("x", "9"), e2x_entry("max", "7", section = "flow")),
                 files = c("a.qmd" = "0000000000000000"))
  ch <- changes(path = dir)
  expect_true(all(ch$entries$stale))
  out <- e2x_print(ch)
  expect_true(any(grepl("^  ~ a.qmd  value  x \\(not re-rendered\\)$", out)))
  expect_true(any(grepl("^  \\+ a.qmd#flow  value  max \\(not re-rendered\\)$", out)))
  expect_true(any(grepl("^  - a.qmd#flow  value  med \\(not re-rendered\\)$", out)))
})

test_that("review 2e2 #10: control, in a ledger that is not stale no line carries it", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(list(e2x_entry("x", "1"), e2x_entry("med", "2")), list(e2x_entry("x", "9"), e2x_entry("max", "7")))
  out <- e2x_print(changes(path = dir))
  expect_false(any(grepl("not re-rendered", out, fixed = TRUE)))
})

# ---- 11: a store that cannot be read -----------------------------------------------------------------------------

make_pipeline2 <- function(dir) {
  e2x_write(file.path(dir, "_targets.R"),
            c("library(targets)", "list(tar_target(fit, 1 + 1), tar_target(obs, 3))"))
  withr::with_dir(dir, targets::tar_make(callr_function = NULL, reporter = "silent"))
}

test_that("review 2e2 #11: a store whose meta file is gone is a note, not stale", {
  skip_if_not_installed("targets")
  dir <- e2x_state_project()
  make_pipeline2(dir)
  m <- targets::tar_meta(fields = "data", store = file.path(dir, "_targets"))
  h <- e2x_header(targets = list("_targets" = c(fit = m$data[m$name == "fit"], obs = m$data[m$name == "obs"])))
  expect_false(weft:::ledger_state(dir, h)$stale)
  unlink(file.path(dir, "_targets", "meta", "meta"))
  st <- weft:::ledger_state(dir, h)
  expect_false(st$stale)
  expect_identical(st$reasons, character())
  expect_identical(st$notes, "the store _targets could not be read; the pipeline was not checked")
})

test_that("review 2e2 #11: control, a store that does not exist is the other note", {
  skip_if_not_installed("targets")
  dir <- e2x_state_project()
  st <- weft:::ledger_state(dir, e2x_header(targets = list("_targets" = c(fit = "0123456789abcdef"))))
  expect_identical(st$notes, "the store _targets does not exist; the pipeline was not checked")
})

# ---- 12: the output in "Not re-rendered" and "New conditions" ----------------------------------------------------------

test_that("review 2e2 #12: two outputs of one source are told apart in both sections", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_project()
  es <- list(e2x_entry("x", "1"), e2x_entry("y", "2"))
  e2x_put_ledger(dir, "a.qmd", es, output = "site-a")
  e2x_put_ledger(dir, "a.qmd", es, output = "site-b")
  e2x_commit(dir)
  e2x_put_ledger(dir, "a.qmd", es, output = "site-a", files = c("a.qmd" = "0000000000000000"),
                 conds = list(e2x_cond("fit", "Model failed to converge.")))
  e2x_put_ledger(dir, "a.qmd", es, output = "site-b", files = c("a.qmd" = "0000000000000000"),
                 conds = list(e2x_cond("fit", "Other warning.")))
  out <- e2x_print(changes(path = dir))
  expect_true("  a.qmd (site-a): 2 entries; a.qmd changed" %in% out)
  expect_true("  a.qmd (site-b): 2 entries; a.qmd changed" %in% out)
  expect_true("  ! a.qmd (site-a)  chunk fit  warning: Model failed to converge." %in% out)
  expect_true("  ! a.qmd (site-b)  chunk fit  warning: Other warning." %in% out)
})

test_that("review 2e2 #12: control, an output that is the base name adds nothing", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_project()
  es <- list(e2x_entry("x", "1"), e2x_entry("y", "2"))
  e2x_put_ledger(dir, "a.qmd", es)
  e2x_commit(dir)
  e2x_put_ledger(dir, "a.qmd", es, files = c("a.qmd" = "0000000000000000"),
                 conds = list(e2x_cond("fit", "New one.")))
  out <- e2x_print(changes(path = dir))
  expect_true("  a.qmd: 2 entries; a.qmd changed" %in% out)
  expect_true("  ! a.qmd  chunk fit  warning: New one." %in% out)
})

# ---- 13: an unreadable ledger on one side prints a count ------------------------------------------------------------

test_that("review 2e2 #13: a ledger in a newer format at since does not list every current entry", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_project()
  p <- file.path(dir, "_weft", "ledger", "a.qmd", "a.jsonl")
  e2x_write(p, c("{\"weft\":\"ledger\",\"version\":2,\"source\":\"a.qmd\",\"output\":\"a\"}"))
  e2x_write(file.path(dir, "a.qmd"), "doc")
  e2x_commit(dir)
  e2x_put_ledger(dir, "a.qmd", list(e2x_entry("x", "1"), e2x_entry("y", "2"), e2x_entry("z", "3")))
  ch <- changes(path = dir)
  expect_identical(ch$ledgers$status, "unreadable")
  out <- e2x_print(ch)
  expect_false(any(grepl("^  \\+ ", out)))
  expect_false("Added" %in% out)
  expect_true(any(startsWith(out, "  a.qmd (a): unreadable")))
})

test_that("review 2e2 #13: an unreadable ledger only now prints no entry lines either", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(list(e2x_entry("q", "1")), list(e2x_entry("q", "1")))
  e2x_write(file.path(dir, "_weft", "ledger", "b.qmd", "b.jsonl"),
            c("{\"weft\":\"ledger\",\"version\":2,\"source\":\"b.qmd\",\"output\":\"b\"}",
              e2x_entry_line(modifyList(e2x_entry("x", "1"), list(file = "b.qmd")))))
  e2x_write(file.path(dir, "b.qmd"), "doc")
  out <- e2x_print(changes(path = dir))
  expect_false(any(grepl("^  \\+ ", out)))
})

test_that("review 2e2 #13: control, a readable new ledger still prints a count", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(list(e2x_entry("q", "1")), list(e2x_entry("q", "1")))
  e2x_put_ledger(dir, "b.qmd", list(e2x_entry("x", "1"), e2x_entry("y", "2")))
  out <- e2x_print(changes(path = dir))
  expect_true(any(grepl("b.qmd (b): new, 2 entries", out, fixed = TRUE)))
})

# ---- 14: files accepts a leading ./ -------------------------------------------------------------------------------------

test_that("review 2e2 #14: files = './a.qmd' is the same as 'a.qmd'", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_project()
  e2x_put_ledger(dir, "a.qmd", list(e2x_entry("x", "1")))
  e2x_put_ledger(dir, "sub/b.qmd", list(e2x_entry("x", "1")))
  e2x_commit(dir)
  e2x_put_ledger(dir, "a.qmd", list(e2x_entry("x", "2")))
  e2x_put_ledger(dir, "sub/b.qmd", list(e2x_entry("x", "2")))
  plain <- changes(path = dir, files = "a.qmd")
  dotted <- changes(path = dir, files = "./a.qmd")
  expect_identical(dotted$entries$ledger, "a.qmd")
  expect_identical(dotted$ledgers$ledger, plain$ledgers$ledger)
  nested <- changes(path = dir, files = "./sub/b.qmd")
  expect_identical(nested$entries$ledger, "sub/b.qmd")
})

test_that("review 2e2 #14: a ./ path naming no ledger is still a weft_changes_error", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(list(e2x_entry()), list(e2x_entry()))
  expect_error(changes(path = dir, files = "./absent.qmd"), class = "weft_changes_error")
})

# ---- A: a renamed section -------------------------------------------------------------------------------------------------

test_that("review 2e2 A: entries of a renamed section are paired and reported as changed, with the old anchor", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(
    list(e2x_entry("v", "-3", section = "results", raw = -3, sentence = "The shift was -3."),
         e2x_entry("u", "5", section = "intro", raw = 5, sentence = "Five here.")),
    list(e2x_entry("v", "3", section = "results-for-2024", raw = 3, sentence = "The shift was 3."),
         e2x_entry("u", "5", section = "intro", raw = 5, sentence = "Five here.")))
  ch <- changes(path = dir)
  r <- ch$entries
  expect_identical(nrow(r), 1L)
  expect_identical(r$change, "changed")
  expect_identical(r$expr, "v")
  expect_match(r$structural, "sign flip", fixed = TRUE)
  expect_identical(c(r$text_before, r$text_after), c("-3", "3"))
  out <- e2x_print(ch)
  expect_true(any(grepl("(section renamed from #results)", out, fixed = TRUE)))
})

test_that("review 2e2 A: an unchanged value in a renamed section is no row at all", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(list(e2x_entry("v", "4", section = "results")),
                      list(e2x_entry("v", "4", section = "results-for-2024")))
  expect_identical(nrow(changes(path = dir)$entries), 0L)
})

test_that("review 2e2 A: entries that differ in expression are not paired (added and removed)", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(list(e2x_entry("v", "1", section = "results")),
                      list(e2x_entry("w", "1", section = "results-for-2024")))
  r <- changes(path = dir)$entries
  expect_setequal(r$change, c("added", "removed"))
})

test_that("review 2e2 A: when the old anchor still exists now, nothing is paired", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(list(e2x_entry("v", "-3", section = "results", raw = -3)),
                      list(e2x_entry("w", "1", section = "results"),
                           e2x_entry("v", "3", section = "extra", raw = 3)))
  ch <- changes(path = dir)
  expect_false("changed" %in% ch$entries$change)
  expect_false(any(grepl("section renamed", e2x_print(ch), fixed = TRUE)))
})

# ---- B: crossing 1.0 is strict --------------------------------------------------------------------------------------------

test_that("review 2e2 B: starting or ending at exactly 1 is not a crossing", {
  skip_if(Sys.which("git") == "")
  r <- e2x_rows(e2x_entry("v", "1", raw = 1), e2x_entry("v", "1.2", raw = 1.2))
  expect_identical(r$structural, "")
  r2 <- e2x_rows(e2x_entry("v", "1.2", raw = 1.2), e2x_entry("v", "1", raw = 1))
  expect_identical(r2$structural, "")
  r3 <- e2x_rows(e2x_entry("v", "0.5", raw = 0.5), e2x_entry("v", "1", raw = 1))
  expect_identical(r3$structural, "")
})

test_that("review 2e2 B: a count going 1 to 2 has its arm reason only", {
  skip_if(Sys.which("git") == "")
  r <- e2x_rows(e2x_entry("n", "1 site", kind = "n", arm = "one", raw = 1),
                e2x_entry("n", "2 sites", kind = "n", arm = "other", raw = 2))
  expect_identical(r$structural, "arm one -> other")
})

test_that("review 2e2 B: controls, a strict crossing of 1 and crossing 0 are still reported", {
  skip_if(Sys.which("git") == "")
  expect_identical(e2x_rows(e2x_entry("v", "0.98", raw = 0.98), e2x_entry("v", "1.04", raw = 1.04))$structural,
                   "crosses 1.0")
  expect_identical(e2x_rows(e2x_entry("v", "1.04", raw = 1.04), e2x_entry("v", "0.98", raw = 0.98))$structural,
                   "crosses 1.0")
  expect_identical(e2x_rows(e2x_entry("v", "-0.5", raw = -0.5), e2x_entry("v", "0", raw = 0))$structural, "crosses 0")
  expect_identical(e2x_rows(e2x_entry("v", "0", raw = 0), e2x_entry("v", "0.5", raw = 0.5))$structural, "crosses 0")
})

# ---- C: _weft/ git-ignored -------------------------------------------------------------------------------------------------

test_that("review 2e2 C: an ignored _weft/ gets one note under Ledgers", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_project()
  e2x_write(file.path(dir, ".gitignore"), "_weft/")
  e2x_put_ledger(dir, "a.qmd", list(e2x_entry("x", "1")))
  e2x_commit(dir)
  e2x_put_ledger(dir, "a.qmd", list(e2x_entry("x", "2")))
  out <- e2x_print(changes(path = dir))
  i <- which(out == "Ledgers")
  expect_length(i, 1L)
  expect_identical(sum(grepl("ignored", out[-seq_len(i)], fixed = TRUE)), 1L)
})

test_that("review 2e2 C: control, a tracked _weft/ has no such note", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(list(e2x_entry("x", "1")), list(e2x_entry("x", "2")))
  expect_false(any(grepl("ignored", e2x_print(changes(path = dir)), fixed = TRUE)))
})

# ---- D: an orphan ledger is not stale ---------------------------------------------------------------------------------------

test_that("review 2e2 D: a ledger whose source is gone keeps its note and has no third state", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_project()
  e2x_write(file.path(dir, "dict.yml"), E2X_DICT)
  e2x_put_ledger(dir, "a.qmd", list(e2x_entry("x", "1")))
  h <- e2x_file_hash(file.path(dir, "a.qmd"))
  hs <- e2x_dict_hashes(file.path(dir, "dict.yml"))
  e2x_put_ledger(dir, "a.qmd", list(e2x_entry("x", "1")), files = c("a.qmd" = h), dict = c(a = hs[["a"]]))
  e2x_commit(dir)
  unlink(file.path(dir, "a.qmd"))
  e2x_write(file.path(dir, "dict.yml"), c("a: {value: 9, type: number, definition: x}", E2X_DICT[2]))
  ch <- changes(path = dir)
  expect_identical(nrow(ch$stale), 0L)
  expect_match(ch$ledgers$note, "source gone", fixed = TRUE)
  expect_false("Not re-rendered" %in% e2x_print(ch))
})

test_that("review 2e2 D: control, the same ledger with its source present is stale", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_project()
  e2x_put_ledger(dir, "a.qmd", list(e2x_entry("x", "1")), files = c("a.qmd" = "0000000000000000"))
  e2x_commit(dir)
  ch <- changes(path = dir)
  expect_identical(ch$stale$reason, "a.qmd changed")
})
