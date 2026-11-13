# Package 2e-2: changes() (dev/design-2e.md C1-C10, C13, C14). Written before the code.
# Fixtures are hand-written ledgers (helper-2e2.R) in temporary git repositories.
# Non-ASCII is written as \uXXXX. Made-up values only.

ENTRY_COLS <- c("ledger", "output", "file", "section", "kind", "expr", "occ", "id", "change", "structural",
                "claim_word", "rank", "stale", "text_before", "text_after", "arm_before", "arm_after",
                "raw_before", "raw_after", "sentence_before", "sentence_after")

# ---- the fixtures themselves ------------------------------------------------------------------

test_that("2e-2 helper: a hand-written ledger and condition log read back with the 2d readers", {
  dir <- e2x_project(git = FALSE)
  nb <- "1.5 km"
  p <- e2x_put_ledger(dir, "reports/a.qmd",
                      list(e2x_entry("len", nb, section = "quality", id = "len", raw = 1500, dict = "dict$limit",
                                     arm = "one", rel = "=", sentence = paste("Reach length was", nb, ".")),
                           e2x_entry("n", NA_character_, kind = "n", failed = "value error")),
                      conds = list(e2x_cond("fit", "Model failed.")),
                      dict = c(limit = "3f2a9c0d1e4b5a68"), files = c("reports/a.qmd" = "9b1c2d3e4f5a6b7c"),
                      targets = list("_targets" = c(fit = "51cfc97e3e0d005e", obs = NA_character_)))
  expect_match(readLines(p, warn = FALSE)[2], "1.5\\u00a0km", fixed = TRUE)
  expect_false(grepl(" ", paste(readLines(p, warn = FALSE), collapse = ""), fixed = TRUE))
  x <- weft:::read_ledger(p)
  expect_identical(nrow(x), 2L)
  expect_identical(x$text[1], nb)
  expect_true(is.na(x$text[2]))
  expect_identical(x$id[1], "len")
  expect_identical(x$raw[1], 1500)
  expect_identical(x$file, c("reports/a.qmd", "reports/a.qmd"))
  expect_identical(attr(x, "header")$source, "reports/a.qmd")
  cp <- file.path(dir, "_weft", "ledger", "reports", "a.qmd", "a.conditions.jsonl")
  cl <- weft:::read_condition_log(cp)
  expect_identical(cl$source, "fit")
  expect_identical(cl$class, "warning")
})

# ---- C1: errors -------------------------------------------------------------------------------

test_that("2e-2 C1: a root without _weft.yml is a weft_changes_error naming rule 9.3.2", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_project(set_up = FALSE)
  e <- expect_error(changes(path = dir), class = "weft_changes_error")
  expect_s3_class(e, "weft_error")
  expect_match(conditionMessage(e), "_weft.yml", fixed = TRUE)
  expect_match(conditionMessage(e), "9.3.2", fixed = TRUE)
})

test_that("2e-2 C1: git not on the path is a weft_changes_error", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(list(e2x_entry()), list(e2x_entry()))
  testthat::local_mocked_bindings(git_path = function() "", .package = "weft")
  e <- expect_error(changes(path = dir), class = "weft_changes_error")
  expect_match(conditionMessage(e), "needs git", fixed = TRUE)
})

test_that("2e-2 C1: a folder outside any work tree is a weft_changes_error", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_project(git = FALSE)
  e2x_put_ledger(dir, "a.qmd", list(e2x_entry()))
  e <- expect_error(changes(path = dir), class = "weft_changes_error")
  expect_match(conditionMessage(e), "not inside a git work tree", fixed = TRUE)
})

test_that("2e-2 C1: since that is not a commit is a weft_changes_error naming it and rule 7.3.1", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(list(e2x_entry()), list(e2x_entry()))
  e <- expect_error(changes(since = "nosuch", path = dir), class = "weft_changes_error")
  expect_match(conditionMessage(e), "nosuch", fixed = TRUE)
  expect_match(conditionMessage(e), "is not a commit", fixed = TRUE)
  expect_match(conditionMessage(e), "7.3.1", fixed = TRUE)
})

test_that("2e-2 C1: files naming a path with a ledger on neither side is a weft_changes_error", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(list(e2x_entry()), list(e2x_entry()))
  expect_error(changes(path = dir, files = "absent.qmd"), class = "weft_changes_error")
})

test_that("2e-2 C1: the root is found from a folder inside the project", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(list(e2x_entry(text = "1")), list(e2x_entry(text = "2")))
  dir.create(file.path(dir, "sub", "deeper"), recursive = TRUE)
  ch <- changes(path = file.path(dir, "sub", "deeper"))
  expect_identical(nrow(ch$entries), 1L)
  expect_identical(normalizePath(attr(ch, "root"), winslash = "/"), dir)
})

test_that("2e-2 C1: changes() returns a visible weft_changes with the five tables and its attributes", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(list(e2x_entry(text = "1")), list(e2x_entry(text = "2")))
  v <- withVisible(changes(path = dir))
  expect_true(v$visible)
  ch <- v$value
  expect_s3_class(ch, "weft_changes")
  expect_true(is.list(ch))
  expect_identical(names(ch), c("entries", "conditions", "stale", "ledgers", "findings"))
  expect_identical(names(ch$entries), ENTRY_COLS)
  expect_identical(names(ch$conditions), c("ledger", "output", "from", "source", "class", "text"))
  expect_identical(names(ch$stale), c("ledger", "output", "entries", "reason"))
  expect_identical(names(ch$ledgers), c("ledger", "output", "path", "status", "from", "note"))
  expect_identical(names(ch$findings), c("file", "line", "rule", "message"))
  expect_identical(nrow(ch$findings), 0L)
  expect_identical(attr(ch, "since"), "HEAD")
  expect_identical(attr(ch, "commit"), e2x_head(dir))
  expect_identical(normalizePath(attr(ch, "root"), winslash = "/"), dir)
})

# ---- C1: no commit yet ----------------------------------------------------------------------

test_that("2e-2 C1: with no commit yet every ledger is new, commit is NA, and the print says so", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_project()
  e2x_put_ledger(dir, "a.qmd", list(e2x_entry("x", "1"), e2x_entry("y", "2")))
  ch <- changes(path = dir)
  expect_identical(nrow(ch$entries), 2L)
  expect_identical(ch$entries$change, c("added", "added"))
  expect_identical(ch$ledgers$status, "new")
  expect_true(is.na(attr(ch, "commit")))
  out <- e2x_print(ch)
  expect_true(any(grepl("(no commit yet)", out, fixed = TRUE)))
  expect_true(any(grepl("new, 2 entries", out, fixed = TRUE)))
})

# ---- C7: change, no change --------------------------------------------------------------------

test_that("2e-2 C14: an unchanged project prints exactly one line, with the 7-character commit", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(list(e2x_entry()), list(e2x_entry()))
  ch <- changes(path = dir)
  expect_identical(nrow(ch$entries), 0L)
  expect_identical(nrow(ch$conditions), 0L)
  expect_identical(nrow(ch$stale), 0L)
  expect_identical(names(ch$entries), ENTRY_COLS)
  out <- e2x_print(ch)
  expect_identical(out[nzchar(trimws(out))],
                   sprintf("weft: no changes since HEAD (%s); 1 ledger compared.", substr(e2x_head(dir), 1, 7)))
})

test_that("2e-2 C7: a changed text is one changed row with both texts and sentences, no reason, rank 1", {
  skip_if(Sys.which("git") == "")
  r <- e2x_rows(e2x_entry("ratio", "0.82", section = "quality", raw = 0.82, rel = "=",
                          sentence = "The ratio was 0.82 today."),
                e2x_entry("ratio", "0.91", section = "quality", raw = 0.91, rel = "=",
                          sentence = "The ratio was 0.91 today."))
  expect_identical(nrow(r), 1L)
  expect_identical(r$change, "changed")
  expect_identical(r$ledger, "a.qmd")
  expect_identical(r$output, "a")
  expect_identical(r$file, "a.qmd")
  expect_identical(r$section, "quality")
  expect_identical(r$kind, "value")
  expect_identical(r$expr, "ratio")
  expect_identical(r$occ, 1L)
  expect_true(is.na(r$id))
  expect_identical(r$structural, "")
  expect_true(is.na(r$claim_word))
  expect_identical(r$rank, 1L)
  expect_false(r$stale)
  expect_identical(c(r$text_before, r$text_after), c("0.82", "0.91"))
  expect_identical(c(r$raw_before, r$raw_after), c(0.82, 0.91))
  expect_identical(c(r$sentence_before, r$sentence_after), c("The ratio was 0.82 today.", "The ratio was 0.91 today."))
  expect_true(is.na(r$arm_before))
  expect_true(is.na(r$arm_after))
})

test_that("2e-2 C7: a different raw with the same text is not a change", {
  skip_if(Sys.which("git") == "")
  r <- e2x_rows(e2x_entry("ratio", "0.82", raw = 0.8234), e2x_entry("ratio", "0.82", raw = 0.8249))
  expect_identical(nrow(r), 0L)
})

test_that("2e-2 C7: a different arm with the same text is a change; null and the empty string differ", {
  skip_if(Sys.which("git") == "")
  r <- e2x_rows(e2x_entry("k", "x", kind = "sign", arm = "positive"),
                e2x_entry("k", "x", kind = "sign", arm = "negative"))
  expect_identical(nrow(r), 1L)
  expect_identical(c(r$arm_before, r$arm_after), c("positive", "negative"))
  r2 <- e2x_rows(e2x_entry("k", "", kind = "if"), e2x_entry("k", NA_character_, kind = "if", failed = "value error"))
  expect_identical(nrow(r2), 1L)
  expect_identical(r2$text_before, "")                      # the empty string on the before side
  expect_true(is.na(r2$text_after))                         # null on the after side
  # and the other way round
  r3 <- e2x_rows(e2x_entry("k", NA_character_, kind = "if", failed = "value error"), e2x_entry("k", "", kind = "if"))
  expect_identical(nrow(r3), 1L)
  expect_true(is.na(r3$text_before))
  expect_identical(r3$text_after, "")
})

test_that("2e-2 C7: a sentence that differs alone is not a change", {
  skip_if(Sys.which("git") == "")
  r <- e2x_rows(e2x_entry("x", "1", sentence = "One thing."), e2x_entry("x", "1", sentence = "Another thing."))
  expect_identical(nrow(r), 0L)
})

# ---- C8: structural reasons ------------------------------------------------------------------

test_that("2e-2 C8: arm one to other on an n entry is `arm one -> other`", {
  skip_if(Sys.which("git") == "")
  r <- e2x_rows(e2x_entry("n_sites", "1 site", kind = "n", arm = "one", rel = "="),
                e2x_entry("n_sites", "2 sites", kind = "n", arm = "other", rel = "="))
  expect_identical(r$structural, "arm one -> other")
})

test_that("2e-2 C8: an if entry whose arm goes to null is `arm true -> none`", {
  skip_if(Sys.which("git") == "")
  r <- e2x_rows(e2x_entry("ratio < dict$limit", ", below", kind = "if", arm = "true"),
                e2x_entry("ratio < dict$limit", "", kind = "if"))
  expect_identical(r$structural, "arm true -> none")
})

test_that("2e-2 C8: an arm change on a kind outside n, if, sign and list is not an arm reason", {
  skip_if(Sys.which("git") == "")
  r <- e2x_rows(e2x_entry("x", "a", kind = "value", arm = "one"), e2x_entry("x", "b", kind = "value", arm = "other"))
  expect_identical(r$structural, "")
})

test_that("2e-2 C8: -2 to 3 is a sign flip (and, by the definitions, crosses 1.0)", {
  skip_if(Sys.which("git") == "")
  r <- e2x_rows(e2x_entry("d", "-2", raw = -2), e2x_entry("d", "3", raw = 3))
  expect_identical(r$structural, "sign flip, crosses 1.0")
})

test_that("2e-2 C8: 0 to 4 crosses 0 (and, by the definitions, crosses 1.0)", {
  skip_if(Sys.which("git") == "")
  r <- e2x_rows(e2x_entry("d", "0", raw = 0), e2x_entry("d", "4", raw = 4))
  expect_identical(r$structural, "crosses 0, crosses 1.0")
})

test_that("2e-2 C8: 4 to 0 crosses 0 as well", {
  skip_if(Sys.which("git") == "")
  r <- e2x_rows(e2x_entry("d", "4", raw = 4), e2x_entry("d", "0", raw = 0))
  expect_identical(r$structural, "crosses 0, crosses 1.0")
})

test_that("2e-2 C8: 0.98 to 1.04 crosses 1.0 only", {
  skip_if(Sys.which("git") == "")
  r <- e2x_rows(e2x_entry("r", "0.98", raw = 0.98), e2x_entry("r", "1.04", raw = 1.04))
  expect_identical(r$structural, "crosses 1.0")
})

test_that("2e-2 C8: 3 to 45 is an order of magnitude; 9.9 to 10.1 is nothing", {
  skip_if(Sys.which("git") == "")
  r <- e2x_rows(e2x_entry("m", "3", raw = 3), e2x_entry("m", "45", raw = 45))
  expect_identical(r$structural, "order of magnitude")
  r2 <- e2x_rows(e2x_entry("m", "9.9", raw = 9.9), e2x_entry("m", "10.1", raw = 10.1))
  expect_identical(nrow(r2), 1L)
  expect_identical(r2$structural, "")
})

test_that("2e-2 C8: a null raw on either side skips the numeric reasons", {
  skip_if(Sys.which("git") == "")
  r <- e2x_rows(e2x_entry("m", "3", raw = NA_real_), e2x_entry("m", "45", raw = 45))
  expect_identical(r$structural, "")
})

DICT_LIMIT <- function(v) sprintf("limit: {value: %s, type: number, definition: \"The limit.\"}", v)

test_that("2e-2 C8: a raw that crosses a dictionary value read by the entry is `crosses dict$limit`", {
  skip_if(Sys.which("git") == "")
  r <- e2x_rows(e2x_entry("ratio", "0.8", raw = 0.8, dict = "dict$limit"),
                e2x_entry("ratio", "0.9", raw = 0.9, dict = "dict$limit"),
                dict_before = DICT_LIMIT(0.85))
  expect_identical(r$structural, "crosses dict$limit")
})

test_that("2e-2 C8: the same raw is a crossing when the dictionary value moved past it", {
  skip_if(Sys.which("git") == "")
  r <- e2x_rows(e2x_entry("ratio", "0.8 (old)", raw = 0.8, dict = "dict$limit"),
                e2x_entry("ratio", "0.8 (new)", raw = 0.8, dict = "dict$limit"),
                dict_before = DICT_LIMIT(0.85), dict_after = DICT_LIMIT(0.75))
  expect_identical(r$structural, "crosses dict$limit")
})

test_that("2e-2 C8: a value that stays on one side of the dictionary value is not a crossing", {
  skip_if(Sys.which("git") == "")
  r <- e2x_rows(e2x_entry("ratio", "0.8", raw = 0.8, dict = "dict$limit"),
                e2x_entry("ratio", "0.82", raw = 0.82, dict = "dict$limit"),
                dict_before = DICT_LIMIT(0.85))
  expect_identical(r$structural, "")
})

test_that("2e-2 C8: a threshold named by another entry in the same sentence counts", {
  skip_if(Sys.which("git") == "")
  sb <- "The ratio was 0.8, below the limit."
  sa <- "The ratio was 0.9, below the limit."
  dir <- e2x_scenario(
    list(e2x_entry("ratio", "0.8", raw = 0.8, section = "q", sentence = sb),
         e2x_entry("ratio < dict$limit", ", below the limit", kind = "if", arm = "true", section = "q",
                   dict = "dict$limit", sentence = sb)),
    list(e2x_entry("ratio", "0.9", raw = 0.9, section = "q", sentence = sa),
         e2x_entry("ratio < dict$limit", ", below the limit", kind = "if", arm = "true", section = "q",
                   dict = "dict$limit", sentence = sa)),
    dict_before = DICT_LIMIT(0.85))
  r <- changes(path = dir)$entries
  expect_identical(nrow(r), 1L)
  expect_identical(r$expr, "ratio")
  expect_identical(r$structural, "crosses dict$limit")
})

test_that("2e-2 C8: a side whose dict.yml is absent gives no threshold", {
  skip_if(Sys.which("git") == "")
  r <- e2x_rows(e2x_entry("ratio", "0.8", raw = 0.8, dict = "dict$limit"),
                e2x_entry("ratio", "0.9", raw = 0.9, dict = "dict$limit"),
                dict_before = NULL, dict_after = DICT_LIMIT(0.85))
  expect_identical(r$structural, "")
})

test_that("2e-2 C8: reasons are joined in C8's order, arm first", {
  skip_if(Sys.which("git") == "")
  r <- e2x_rows(e2x_entry("n_x", "1 site", kind = "n", arm = "one", raw = 0.5),
                e2x_entry("n_x", "20 sites", kind = "n", arm = "other", raw = 20))
  expect_identical(r$structural, "arm one -> other, crosses 1.0, order of magnitude")
})

# ---- C9: claim words and rank ------------------------------------------------------------------

test_that("2e-2 C9: structural first, then a claim word, then the rest", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(
    list(e2x_entry("o", "10", section = "s3", raw = 10, sentence = "Flow was 10 units today."),
         e2x_entry("r", "100", section = "s2", raw = 100, sentence = "Flow rose to 100 units today."),
         e2x_entry("s", "0.98", section = "s1", raw = 0.98, sentence = "The ratio was 0.98 today.")),
    list(e2x_entry("o", "15", section = "s3", raw = 15, sentence = "Flow was 15 units today."),
         e2x_entry("r", "102", section = "s2", raw = 102, sentence = "Flow rose to 102 units today."),
         e2x_entry("s", "1.04", section = "s1", raw = 1.04, sentence = "The ratio was 1.04 today.")))
  r <- changes(path = dir)$entries
  expect_identical(r$expr, c("s", "r", "o"))
  expect_identical(r$rank, 1:3)
  expect_identical(r$structural, c("crosses 1.0", "", ""))
  expect_identical(r$claim_word, c(NA_character_, "rose", NA_character_))
})

test_that("2e-2 C9: structural entries are ordered by the first reason's place, then by rel", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(
    list(e2x_entry("a", "0.98", section = "s1", raw = 0.98),
         e2x_entry("b", "3", section = "s2", raw = 3),
         e2x_entry("c", "-2", section = "s3", raw = -2)),
    list(e2x_entry("a", "1.04", section = "s1", raw = 1.04),
         e2x_entry("b", "45", section = "s2", raw = 45),
         e2x_entry("c", "3", section = "s3", raw = 3)))
  r <- changes(path = dir)$entries
  # first reasons: c sign flip (2), a crosses 1.0 (4), b order of magnitude (6)
  expect_identical(r$expr, c("c", "a", "b"))
})

test_that("2e-2 C9: a value printed as `three` is not its own claim word, another word still counts", {
  skip_if(Sys.which("git") == "")
  r <- e2x_rows(e2x_entry("n", "three", raw = 3, sentence = "There were three sites."),
                e2x_entry("n", "four", raw = 4, sentence = "There were four sites."))
  expect_true(is.na(r$claim_word))
  r2 <- e2x_rows(e2x_entry("n", "three", raw = 3, sentence = "There were three sites, all open."),
                 e2x_entry("n", "four", raw = 4, sentence = "There were four sites, all open."))
  expect_identical(r2$claim_word, "all")
})

test_that("2e-2 C9: a claim word is matched as a whole word, ignoring case", {
  skip_if(Sys.which("git") == "")
  r <- e2x_rows(e2x_entry("n", "5", raw = 5, sentence = "Allowances were 5 today."),
                e2x_entry("n", "6", raw = 6, sentence = "Allowances were 6 today."))
  expect_true(is.na(r$claim_word))
  r2 <- e2x_rows(e2x_entry("n", "5", raw = 5, sentence = "ALL sites were 5 today."),
                 e2x_entry("n", "6", raw = 6, sentence = "ALL sites were 6 today."))
  expect_identical(r2$claim_word, "all")
})

test_that("2e-2 C9: among the rest, a claim word first, then a larger relative change; NA last", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(
    list(e2x_entry("p", "10", section = "s1", raw = 10, sentence = "Flow was 10 units."),
         e2x_entry("q", "10", section = "s2", raw = 10, sentence = "Flow was 10 units."),
         e2x_entry("t", "x", section = "s3", raw = NA_real_, sentence = "Name was x."),
         e2x_entry("u", "100", section = "s4", raw = 100, sentence = "Flow rose to 100 units.")),
    list(e2x_entry("p", "11", section = "s1", raw = 11, sentence = "Flow was 11 units."),
         e2x_entry("q", "15", section = "s2", raw = 15, sentence = "Flow was 15 units."),
         e2x_entry("t", "y", section = "s3", raw = NA_real_, sentence = "Name was y."),
         e2x_entry("u", "101", section = "s4", raw = 101, sentence = "Flow rose to 101 units.")))
  r <- changes(path = dir)$entries
  expect_identical(r$expr, c("u", "q", "p", "t"))
})

# ---- added and removed -------------------------------------------------------------------------

test_that("2e-2 C7: a changed expression is one removed and one added, with no rank", {
  skip_if(Sys.which("git") == "")
  r <- e2x_rows(e2x_entry("median(flow)", "2.9", section = "flow", sentence = "The median was 2.9 ML/d."),
                e2x_entry("max(flow)", "12", section = "flow", sentence = "Peak flow was 12 ML/d."))
  expect_identical(nrow(r), 2L)
  expect_setequal(r$change, c("added", "removed"))
  rem <- r[r$change == "removed", ]
  add <- r[r$change == "added", ]
  expect_identical(rem$expr, "median(flow)")
  expect_identical(add$expr, "max(flow)")
  expect_identical(rem$text_before, "2.9")
  expect_true(is.na(rem$text_after))
  expect_true(is.na(rem$sentence_after))
  expect_identical(add$text_after, "12")
  expect_true(is.na(add$text_before))
  expect_identical(add$sentence_after, "Peak flow was 12 ML/d.")
  expect_true(all(is.na(r$rank)))
})

test_that("2e-2 C7: an entry with an id keeps its key when it moves section", {
  skip_if(Sys.which("git") == "")
  r <- e2x_rows(e2x_entry("ratio", "0.82", section = "one", id = "ratio"),
                e2x_entry("ratio", "0.82", section = "two", id = "ratio"))
  expect_identical(nrow(r), 0L)
})

test_that("2e-2 C7: an entry with an id and changed text is one changed row carrying the id", {
  skip_if(Sys.which("git") == "")
  r <- e2x_rows(e2x_entry("ratio", "0.82", section = "one", id = "ratio"),
                e2x_entry("ratio", "0.91", section = "two", id = "ratio"))
  expect_identical(nrow(r), 1L)
  expect_identical(r$change, "changed")
  expect_identical(r$id, "ratio")
})

test_that("2e-2 C7: the second occurrence is keyed by occ", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(
    list(e2x_entry("x", "1", occ = 1L), e2x_entry("x", "2", occ = 2L)),
    list(e2x_entry("x", "1", occ = 1L), e2x_entry("x", "3", occ = 2L)))
  r <- changes(path = dir)$entries
  expect_identical(nrow(r), 1L)
  expect_identical(r$occ, 2L)
  expect_identical(c(r$text_before, r$text_after), c("2", "3"))
})

# ---- C10: conditions ---------------------------------------------------------------------------

test_that("2e-2 C10: a condition line not in the log at since is new, with the table's columns", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(list(e2x_entry()), list(e2x_entry()),
                      conds_before = list(e2x_cond("fit", "Old warning.")),
                      conds_after = list(e2x_cond("fit", "Old warning."),
                                         e2x_cond("fit2", "Model failed to converge with max|grad| = 0.0021.",
                                                  normalised = "Model failed to converge with max|grad| = <n>")))
  ch <- changes(path = dir)
  expect_identical(nrow(ch$conditions), 1L)
  expect_identical(ch$conditions$ledger, "a.qmd")
  expect_identical(ch$conditions$output, "a")
  expect_identical(ch$conditions$from, "chunk")
  expect_identical(ch$conditions$source, "fit2")
  expect_identical(ch$conditions$class, "warning")
  expect_identical(ch$conditions$text, "Model failed to converge with max|grad| = 0.0021.")
})

test_that("2e-2 C10: a line whose text differs only in a number (same normalised) is not new", {
  skip_if(Sys.which("git") == "")
  nz <- "Model failed to converge with max|grad| = <n>"
  dir <- e2x_scenario(list(e2x_entry()), list(e2x_entry()),
                      conds_before = list(e2x_cond("fit", "Model failed to converge with max|grad| = 0.0021.", normalised = nz)),
                      conds_after = list(e2x_cond("fit", "Model failed to converge with max|grad| = 0.0034.", normalised = nz)))
  expect_identical(nrow(changes(path = dir)$conditions), 0L)
})

test_that("2e-2 C10: a line that is gone now is not listed", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(list(e2x_entry()), list(e2x_entry()),
                      conds_before = list(e2x_cond("fit", "Old warning.")),
                      conds_after = list())
  expect_identical(nrow(changes(path = dir)$conditions), 0L)
})

test_that("2e-2 C10: a line differing in class or source from one then is new", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(list(e2x_entry()), list(e2x_entry()),
                      conds_before = list(e2x_cond("fit", "Same words.", class = "warning")),
                      conds_after = list(e2x_cond("fit", "Same words.", class = "message")))
  expect_identical(changes(path = dir)$conditions$class, "message")
})

test_that("2e-2 C10: a new ledger contributes all its condition lines; a deleted one none", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_project()
  e2x_put_ledger(dir, "gone.qmd", list(e2x_entry()), conds = list(e2x_cond("g", "Gone warning.")))
  e2x_commit(dir)
  unlink(file.path(dir, "_weft", "ledger", "gone.qmd"), recursive = TRUE)
  e2x_put_ledger(dir, "fresh.qmd", list(e2x_entry("z", "9")),
                 conds = list(e2x_cond("f1", "First fresh."), e2x_cond("f2", "Second fresh.")))
  ch <- changes(path = dir)
  expect_setequal(ch$conditions$source, c("f1", "f2"))
  expect_true(all(ch$conditions$ledger == "fresh.qmd"))
})

# ---- C3-C6: the ledgers -------------------------------------------------------------------------

rename_entries <- function(file, first = "1") {
  list(e2x_entry("x1", first, file = file), e2x_entry("x2", "2", file = file),
       e2x_entry("x3", "3", file = file), e2x_entry("x4", "4", file = file))
}

test_that("2e-2 C5: a renamed source with its ledger folder is `renamed`, from the old source, real changes only", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_project()
  e2x_put_ledger(dir, "a.qmd", rename_entries("a.qmd"), output = "report")
  e2x_commit(dir)
  unlink(file.path(dir, "_weft", "ledger", "a.qmd"), recursive = TRUE)
  unlink(file.path(dir, "a.qmd"))
  e2x_put_ledger(dir, "b.qmd", rename_entries("b.qmd", first = "9"), output = "report")
  ch <- changes(path = dir)
  expect_identical(nrow(ch$ledgers), 1L)
  expect_identical(ch$ledgers$ledger, "b.qmd")
  expect_identical(ch$ledgers$status, "renamed")
  expect_identical(ch$ledgers$from, "a.qmd")
  expect_identical(ch$ledgers$output, "report")
  expect_identical(nrow(ch$entries), 1L)
  expect_identical(ch$entries$change, "changed")
  expect_identical(ch$entries$expr, "x1")
  expect_identical(ch$entries$file, "b.qmd")
  expect_true(any(grepl("b.qmd (report): renamed from a.qmd", e2x_print(ch), fixed = TRUE)))
})

test_that("2e-2 C5: a renamed source with every entry alike lists no entry", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_project()
  e2x_put_ledger(dir, "a.qmd", rename_entries("a.qmd"), output = "report")
  e2x_commit(dir)
  unlink(file.path(dir, "_weft", "ledger", "a.qmd"), recursive = TRUE)
  e2x_put_ledger(dir, "b.qmd", rename_entries("b.qmd"), output = "report")
  ch <- changes(path = dir)
  expect_identical(ch$ledgers$status, "renamed")
  expect_identical(nrow(ch$entries), 0L)
})

test_that("2e-2 C5: fewer than half the entries matching pairs nothing (deleted and new)", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_project()
  e2x_put_ledger(dir, "a.qmd", rename_entries("a.qmd"), output = "report")
  e2x_commit(dir)
  unlink(file.path(dir, "_weft", "ledger", "a.qmd"), recursive = TRUE)
  e2x_put_ledger(dir, "b.qmd", list(e2x_entry("x1", "1"), e2x_entry("y2", "2"), e2x_entry("y3", "3"),
                                    e2x_entry("y4", "4")), output = "report")
  ch <- changes(path = dir)
  expect_setequal(ch$ledgers$status, c("deleted", "new"))
})

test_that("2e-2 C5: a tie between two new ledgers pairs nothing", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_project()
  e2x_put_ledger(dir, "a.qmd", rename_entries("a.qmd"), output = "report")
  e2x_commit(dir)
  unlink(file.path(dir, "_weft", "ledger", "a.qmd"), recursive = TRUE)
  e2x_put_ledger(dir, "b1.qmd", rename_entries("b1.qmd"), output = "report")
  e2x_put_ledger(dir, "b2.qmd", rename_entries("b2.qmd"), output = "report")
  ch <- changes(path = dir)
  expect_setequal(ch$ledgers$status, c("deleted", "new", "new"))
})

test_that("2e-2 C5: the larger share wins", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_project()
  e2x_put_ledger(dir, "a.qmd", rename_entries("a.qmd"), output = "report")
  e2x_commit(dir)
  unlink(file.path(dir, "_weft", "ledger", "a.qmd"), recursive = TRUE)
  e2x_put_ledger(dir, "b1.qmd", rename_entries("b1.qmd"), output = "report")
  e2x_put_ledger(dir, "b2.qmd", list(e2x_entry("x1", "1"), e2x_entry("x2", "2"), e2x_entry("y3", "3"),
                                     e2x_entry("y4", "4")), output = "report")
  ch <- changes(path = dir)
  st <- setNames(ch$ledgers$status, ch$ledgers$ledger)
  expect_identical(st[["b1.qmd"]], "renamed")
  expect_identical(st[["b2.qmd"]], "new")
})

test_that("2e-2 C6: a new chapter is `new`, its entries are rows but are not printed one by one", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(list(e2x_entry()), list(e2x_entry()))
  e2x_put_ledger(dir, "flow.qmd", list(e2x_entry("p", "1"), e2x_entry("q", "2"), e2x_entry("r", "3")))
  ch <- changes(path = dir)
  expect_identical(ch$ledgers$status[ch$ledgers$ledger == "flow.qmd"], "new")
  expect_identical(sum(ch$entries$ledger == "flow.qmd" & ch$entries$change == "added"), 3L)
  out <- e2x_print(ch)
  expect_true(any(grepl("flow.qmd (flow): new, 3 entries", out, fixed = TRUE)))
  expect_false(any(grepl("^  \\+ ", out)))
})

test_that("2e-2 C6: a ledger deleted from the working tree is `deleted`, and prints its count", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_project()
  e2x_put_ledger(dir, "a.qmd", list(e2x_entry("x", "1"), e2x_entry("y", "2")))
  e2x_commit(dir)
  unlink(file.path(dir, "_weft", "ledger", "a.qmd"), recursive = TRUE)
  ch <- changes(path = dir)
  expect_identical(ch$ledgers$status, "deleted")
  expect_identical(ch$ledgers$ledger, "a.qmd")
  out <- e2x_print(ch)
  expect_true(any(grepl("a.qmd (a): deleted, 2 entries", out, fixed = TRUE)))
  expect_false(any(grepl("^  - ", out)))
})

test_that("2e-2 C6: a ledger whose source is gone carries the note `source gone` and names the folder to delete", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_project()
  e2x_put_ledger(dir, "reports/sites.qmd", list(e2x_entry("x", "1")))
  e2x_commit(dir)
  unlink(file.path(dir, "reports", "sites.qmd"))
  ch <- changes(path = dir)
  expect_identical(ch$ledgers$status, "compared")
  expect_match(ch$ledgers$note, "source gone", fixed = TRUE)
  out <- e2x_print(ch)
  expect_true(any(grepl("reports/sites.qmd (sites): source gone; delete _weft/ledger/reports/sites.qmd/",
                        out, fixed = TRUE)))
})

test_that("2e-2 C4: a working-tree ledger with merge-conflict lines is `unreadable`, its note names the line", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(list(e2x_entry("x", "1")), list(e2x_entry("x", "1")))
  p <- file.path(dir, "_weft", "ledger", "a.qmd", "a.jsonl")
  good <- e2x_ledger_lines("a.qmd", "a", list(e2x_entry("x", "1"), e2x_entry("y", "2")))
  e2x_write(p, c(good[1:2], "<<<<<<< HEAD", good[3]))
  ch <- changes(path = dir)
  expect_identical(ch$ledgers$status, "unreadable")
  expect_match(ch$ledgers$note, "line 3 of", fixed = TRUE)
  expect_true(any(startsWith(e2x_print(ch), "  a.qmd (a): unreadable")))
})

test_that("2e-2 C4: a version above 1 reads as no entries and is `unreadable`", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(list(e2x_entry("x", "1")), list(e2x_entry("x", "1")))
  p <- file.path(dir, "_weft", "ledger", "a.qmd", "a.jsonl")
  e2x_write(p, c("{\"weft\":\"ledger\",\"version\":2,\"source\":\"a.qmd\",\"output\":\"a\"}",
                 e2x_entry_line(modifyList(e2x_entry("x", "5"), list(file = "a.qmd")))))
  ch <- changes(path = dir)
  expect_identical(ch$ledgers$status, "unreadable")
  expect_identical(nrow(ch$entries[ch$entries$change == "added", ]), 0L)
})

test_that("2e-2 C3: ledgers are matched by path, one per output; both outputs of a source are compared", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_project()
  e2x_put_ledger(dir, "a.qmd", list(e2x_entry("x", "1")), output = "html")
  e2x_put_ledger(dir, "a.qmd", list(e2x_entry("x", "1")), output = "pdf")
  e2x_commit(dir)
  e2x_put_ledger(dir, "a.qmd", list(e2x_entry("x", "2")), output = "pdf")
  ch <- changes(path = dir)
  expect_setequal(ch$ledgers$output, c("html", "pdf"))
  expect_identical(nrow(ch$entries), 1L)
  expect_identical(ch$entries$output, "pdf")
})

# ---- since, files, writes nothing -----------------------------------------------------------------

test_that("2e-2 C1: since an older commit compares with that commit; commit is its full hash", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_project()
  e2x_put_ledger(dir, "a.qmd", list(e2x_entry("x", "1")))
  e2x_commit(dir, "one")
  e2x_put_ledger(dir, "a.qmd", list(e2x_entry("x", "2")))
  e2x_commit(dir, "two")
  e2x_put_ledger(dir, "a.qmd", list(e2x_entry("x", "3")))
  e2x_commit(dir, "three")
  expect_identical(nrow(changes(path = dir)$entries), 0L)
  ch <- changes(since = "HEAD~2", path = dir)
  expect_identical(nrow(ch$entries), 1L)
  expect_identical(c(ch$entries$text_before, ch$entries$text_after), c("1", "3"))
  expect_identical(attr(ch, "since"), "HEAD~2")
  expect_identical(attr(ch, "commit"), trimws(e2x_git(dir, "rev-parse", "HEAD~2")))
  ch1 <- changes(since = "HEAD~1", path = dir)
  expect_identical(c(ch1$entries$text_before, ch1$entries$text_after), c("2", "3"))
})

test_that("2e-2 C1: files limits the comparison to the ledgers of those sources", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_project()
  e2x_put_ledger(dir, "a.qmd", list(e2x_entry("x", "1")))
  e2x_put_ledger(dir, "b.qmd", list(e2x_entry("x", "1")))
  e2x_commit(dir)
  e2x_put_ledger(dir, "a.qmd", list(e2x_entry("x", "2")))
  e2x_put_ledger(dir, "b.qmd", list(e2x_entry("x", "2")))
  expect_setequal(changes(path = dir)$entries$ledger, c("a.qmd", "b.qmd"))
  ch <- changes(path = dir, files = "a.qmd")
  expect_identical(ch$entries$ledger, "a.qmd")
  expect_identical(ch$ledgers$ledger, "a.qmd")
})

test_that("2e-2 C2: changes() writes nothing: files, sizes, times and git status are the same", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(list(e2x_entry("x", "1")), list(e2x_entry("x", "2")),
                      conds_before = list(), conds_after = list(e2x_cond("fit", "New.")))
  e2x_put_ledger(dir, "fresh.qmd", list(e2x_entry("p", "1")))
  before <- e2x_snapshot(dir)
  st_before <- e2x_git(dir, "status", "--porcelain")
  ch <- changes(path = dir)
  expect_gt(nrow(ch$entries), 0L)
  invisible(e2x_print(ch))
  expect_identical(e2x_snapshot(dir), before)
  expect_identical(e2x_git(dir, "status", "--porcelain"), st_before)
})

# ---- C14: the printed layout --------------------------------------------------------------------

test_that("2e-2 C14: the first line gives since, the commit, the counts, with singular for one", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(list(e2x_entry("x", "1")), list(e2x_entry("x", "2")))
  out <- e2x_print(changes(path = dir))
  expect_identical(out[1], sprintf("weft changes since HEAD (%s): 1 ledger compared; 1 changed, 0 added, 0 removed; 0 new conditions",
                                   substr(e2x_head(dir), 1, 7)))
  dir2 <- e2x_scenario(list(e2x_entry("x", "1")), list(e2x_entry("x", "2")),
                       conds_before = list(), conds_after = list(e2x_cond("fit", "New one.")))
  out2 <- e2x_print(changes(path = dir2))
  expect_match(out2[1], "; 1 new condition$")
})

test_that("2e-2 C14: a changed entry prints its location, kind, expr, and the before and after sentences", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(
    list(e2x_entry("ratio", "0.82", section = "quality", id = "ratio", raw = 0.82, sentence = "The ratio was 0.82 today.")),
    list(e2x_entry("ratio", "0.91", section = "quality", id = "ratio", raw = 0.91, sentence = "The ratio was 0.91 today.")))
  out <- e2x_print(changes(path = dir))
  i <- which(out == "  ~ a.qmd#quality  value  ratio {#ratio}")
  expect_length(i, 1L)
  expect_identical(out[i + 1L], "      before: The ratio was 0.82 today.")
  expect_identical(out[i + 2L], "      after:  The ratio was 0.91 today.")
  expect_true("Other changes, ranked" %in% out)
})

test_that("2e-2 C14: (output) is shown when it differs from the source's base name", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_project()
  e2x_put_ledger(dir, "a.qmd", list(e2x_entry("x", "1")), output = "site-a")
  e2x_commit(dir)
  e2x_put_ledger(dir, "a.qmd", list(e2x_entry("x", "2")), output = "site-a")
  out <- e2x_print(changes(path = dir))
  expect_true(any(grepl("^  ~ a.qmd \\(site-a\\)  value  x$", out)))
})

test_that("2e-2 C14: a failed construct after prints (failed: <failed>)", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(list(e2x_entry("x", "0.82", sentence = "The ratio was 0.82.")),
                      list(e2x_entry("x", NA_character_, failed = "value error", sentence = "The ratio was .")))
  out <- e2x_print(changes(path = dir))
  expect_true("      after:  (failed: value error)" %in% out)
})

test_that("2e-2 C14: sentences print as stored, U+00A0 as itself", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(list(e2x_entry("len", "1.5 km", sentence = "Reach length was 1.5 km.")),
                      list(e2x_entry("len", "1.6 km", sentence = "Reach length was 1.6 km.")))
  ch <- changes(path = dir)
  expect_identical(ch$entries$sentence_after, "Reach length was 1.6 km.")
  out <- e2x_print(ch)
  expect_true(any(grepl("after:  Reach length was 1.6 km.", out, fixed = TRUE)))
})

# the whole layout of the design's example
big_project <- function(env = parent.frame()) {
  dir <- e2x_project(env = env)
  s_b <- "The mean ratio was 0.98, below the limit."
  s_a <- "The mean ratio was 1.04."
  survey_b <- list(
    e2x_entry("ratio < dict$limit", ", below the limit", kind = "if", section = "quality", arm = "true",
              dict = "dict$limit", sentence = s_b),
    e2x_entry("ratio", "0.98", section = "quality", id = "ratio", raw = 0.98, sentence = s_b),
    e2x_entry("n_obs", "40", raw = 40, sentence = "There are 40 rows."))
  survey_a <- list(
    e2x_entry("ratio < dict$limit", "", kind = "if", section = "quality", dict = "dict$limit", sentence = s_a),
    e2x_entry("ratio", "1.04", section = "quality", id = "ratio", raw = 1.04, sentence = s_a),
    e2x_entry("n_obs", "40", raw = 40, sentence = "There are 40 rows."))
  water_b <- list(
    e2x_entry("n_sites", "14", kind = "bare", raw = 14, sentence = "All 14 sites were visited."),
    e2x_entry("median(flow)", "2.9 ML/d", section = "flow", sentence = "The median was 2.9 ML/d."))
  water_a <- list(
    e2x_entry("n_sites", "15", kind = "bare", raw = 15, sentence = "All 15 sites were visited."),
    e2x_entry("max(flow)", "12 ML/d", section = "flow", sentence = "Peak flow was 12 ML/d."))
  e2x_put_ledger(dir, "reports/survey.qmd", survey_b, output = "survey")
  e2x_put_ledger(dir, "reports/water.qmd", water_b, output = "site-a")
  e2x_put_ledger(dir, "reports/sites-2023.qmd", list(e2x_entry("x", "1")), output = "sites-2023")
  e2x_commit(dir)
  e2x_put_ledger(dir, "reports/survey.qmd", survey_a, output = "survey",
                 files = c("reports/survey.qmd" = "0000000000000000"),
                 conds = list(e2x_cond("fit", "Model failed to converge with max|grad| = 0.0021.", from = "target",
                                       normalised = "Model failed to converge with max|grad| = <n>")))
  e2x_put_ledger(dir, "reports/water.qmd", water_a, output = "site-a")
  e2x_put_ledger(dir, "reports/flow.qmd", list(e2x_entry("p", "1"), e2x_entry("q", "2"), e2x_entry("r", "3")),
                 output = "flow")
  unlink(file.path(dir, "reports", "sites-2023.qmd"))
  dir
}

test_that("2e-2 C14: the sections appear in the design's order, each marker on its own lines", {
  skip_if(Sys.which("git") == "")
  dir <- big_project()
  ch <- changes(path = dir)
  out <- e2x_print(ch)
  expect_match(out[1], "^weft changes since HEAD \\([0-9a-f]{7}\\): ")
  heads <- c("Not re-rendered", "Structural changes", "Other changes, ranked", "Added", "Removed",
             "New conditions", "Ledgers")
  idx <- vapply(heads, function(h) { i <- which(out == h); if (length(i) == 1L) i else NA_integer_ }, 1L)
  expect_false(anyNA(idx))
  expect_identical(order(idx), seq_along(heads))
  # content
  expect_true("  reports/survey.qmd: 3 entries; reports/survey.qmd changed" %in% out)
  expect_true("  ~ reports/survey.qmd#quality  if  ratio < dict$limit  [arm true -> none] (not re-rendered)" %in% out)
  expect_true("  ~ reports/survey.qmd#quality  value  ratio {#ratio}  [crosses 1.0] (not re-rendered)" %in% out)
  expect_true("      before: The mean ratio was 0.98, below the limit." %in% out)
  expect_true("      after:  The mean ratio was 1.04." %in% out)
  expect_true("  ~ reports/water.qmd (site-a)  bare  n_sites  [claim word \"all\"]" %in% out)
  expect_true("      before: All 14 sites were visited." %in% out)
  expect_true("  + reports/water.qmd#flow (site-a)  value  max(flow)" %in% out)
  expect_true("      Peak flow was 12 ML/d." %in% out)
  expect_true("  - reports/water.qmd#flow (site-a)  value  median(flow)" %in% out)
  expect_true("      The median was 2.9 ML/d." %in% out)
  expect_true("  ! reports/survey.qmd  target fit  warning: Model failed to converge with max|grad| = 0.0021." %in% out)
  expect_true("  reports/flow.qmd (flow): new, 3 entries" %in% out)
  expect_true("  reports/sites-2023.qmd (sites-2023): source gone; delete _weft/ledger/reports/sites-2023.qmd/" %in% out)
  # a compared ledger with no note is not listed under Ledgers
  expect_false(any(grepl("^  reports/water.qmd \\(site-a\\): ", out)))
  # structural order: the arm entry before the crosses-1.0 entry
  expect_lt(which(grepl("\\[arm true -> none\\]", out)), which(grepl("\\[crosses 1.0\\]", out)))
  # the same sections as tables
  expect_true(all(ch$entries$stale[ch$entries$ledger == "reports/survey.qmd"]))
  expect_false(any(ch$entries$stale[ch$entries$ledger == "reports/water.qmd"]))
  expect_identical(ch$stale$ledger, "reports/survey.qmd")
  expect_identical(ch$stale$output, "survey")
  expect_identical(ch$stale$entries, 3L)
  expect_identical(ch$stale$reason, "reports/survey.qmd changed")
  expect_identical(nrow(ch$conditions), 1L)
  expect_identical(ch$conditions$from, "target")
})

test_that("2e-2 C14: sections with no rows are not printed", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(list(e2x_entry("x", "1")), list(e2x_entry("x", "2")))
  out <- e2x_print(changes(path = dir))
  for (h in c("Not re-rendered", "Structural changes", "Added", "Removed", "New conditions", "Ledgers"))
    expect_false(h %in% out)
  expect_true("Other changes, ranked" %in% out)
})
