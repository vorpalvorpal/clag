# Package 2e-2: the third state, ledger_state() (dev/design-2e.md C11, C12), and how changes() shows it.
# Fixtures are hand-written headers (helper-2e2.R); hashes are computed by the helper from P14's recipe.
# Made-up values only.

state_of <- function(dir, ...) weft:::ledger_state(dir, e2x_header(...))

# ---- the fixtures themselves ------------------------------------------------------------------

test_that("2e-2 helper: a header with nested 2e fields reads back, and the hashes are 16 hex characters", {
  dir <- e2x_state_project()
  h <- e2x_header(dict = e2x_dict_hashes(file.path(dir, "dict.yml")),
                  files = c("doc.qmd" = e2x_file_hash(file.path(dir, "doc.qmd"))),
                  targets = list("_targets" = c(fit = "51cfc97e3e0d005e")))
  expect_match(h$dict$a, "^[0-9a-f]{16}$")
  expect_match(h$files[["doc.qmd"]], "^[0-9a-f]{16}$")
  expect_identical(h$targets[["_targets"]][["fit"]], "51cfc97e3e0d005e")
  expect_false(identical(h$dict$a, h$dict$b))
  expect_identical(e2x_file_hash(file.path(dir, "doc.qmd")), e2x_file_hash(file.path(dir, "doc.qmd")))
})

test_that("2e-2 helper: the helper's hashes agree with 2e-1's file_hash() and dict_entry_hashes() once built", {
  ns <- asNamespace("weft")
  skip_if_not(exists("file_hash", ns) && exists("dict_entry_hashes", ns), "2e-1 is not built yet")
  dir <- e2x_state_project()
  expect_identical(weft:::file_hash(file.path(dir, "doc.qmd")), e2x_file_hash(file.path(dir, "doc.qmd")))
  expect_identical(weft:::dict_entry_hashes(file.path(dir, "dict.yml")), e2x_dict_hashes(file.path(dir, "dict.yml")))
})

# ---- C11: files ---------------------------------------------------------------------------------

test_that("2e-2 C11: files hashed from the files now is not stale, with no reasons and no notes", {
  dir <- e2x_state_project()
  st <- state_of(dir, files = c("doc.qmd" = e2x_file_hash(file.path(dir, "doc.qmd"))))
  expect_identical(names(st), c("stale", "reasons", "notes"))
  expect_false(st$stale)
  expect_identical(st$reasons, character())
  expect_identical(st$notes, character())
})

test_that("2e-2 C11: an edited file gives `<path> changed`", {
  dir <- e2x_state_project()
  h <- e2x_file_hash(file.path(dir, "doc.qmd"))
  e2x_write(file.path(dir, "doc.qmd"), c("# A document", "", "Other words."))
  st <- state_of(dir, files = c("doc.qmd" = h))
  expect_true(st$stale)
  expect_identical(st$reasons, "doc.qmd changed")
})

test_that("2e-2 C11: a deleted file gives `<path> is gone`", {
  dir <- e2x_state_project()
  h <- e2x_file_hash(file.path(dir, "doc.qmd"))
  unlink(file.path(dir, "doc.qmd"))
  st <- state_of(dir, files = c("doc.qmd" = h))
  expect_true(st$stale)
  expect_identical(st$reasons, "doc.qmd is gone")
})

test_that("2e-2 C11: a file in a subfolder is named by its path relative to the root", {
  dir <- e2x_state_project()
  e2x_write(file.path(dir, "parts", "intro.qmd"), "Hello.")
  h <- e2x_file_hash(file.path(dir, "parts", "intro.qmd"))
  e2x_write(file.path(dir, "parts", "intro.qmd"), "Hello again.")
  expect_identical(state_of(dir, files = c("parts/intro.qmd" = h))$reasons, "parts/intro.qmd changed")
})

test_that("2e-2 C11: a file with CR LF ends and the same file with LF agree (P14)", {
  dir <- e2x_state_project()
  p <- file.path(dir, "crlf.qmd")
  writeBin(charToRaw("one\r\ntwo\r\n"), p)
  h <- e2x_file_hash(p)
  writeBin(charToRaw("one\ntwo\n"), p)
  expect_false(state_of(dir, files = c("crlf.qmd" = h))$stale)
})

# ---- C11: the dictionary ------------------------------------------------------------------------

test_that("2e-2 C11: dictionary hashes that match are not stale", {
  dir <- e2x_state_project()
  st <- state_of(dir, dict = e2x_dict_hashes(file.path(dir, "dict.yml")))
  expect_false(st$stale)
  expect_identical(st$reasons, character())
})

test_that("2e-2 C11: a changed value gives `dict$a changed`; a changed definition gives nothing", {
  dir <- e2x_state_project()
  hs <- e2x_dict_hashes(file.path(dir, "dict.yml"))
  e2x_write(file.path(dir, "dict.yml"),
            c("a: {value: 5, type: number, definition: \"The first.\"}", E2X_DICT[2]))
  st <- state_of(dir, dict = hs)
  expect_true(st$stale)
  expect_identical(st$reasons, "dict$a changed")
  e2x_write(file.path(dir, "dict.yml"),
            c("a: {value: 1, type: number, definition: \"A new definition.\"}", E2X_DICT[2]))
  st2 <- state_of(dir, dict = hs)
  expect_false(st2$stale)
  expect_identical(st2$reasons, character())
})

test_that("2e-2 C11: a removed key gives `dict$a is gone`", {
  dir <- e2x_state_project()
  hs <- e2x_dict_hashes(file.path(dir, "dict.yml"))
  e2x_write(file.path(dir, "dict.yml"), E2X_DICT[2])
  st <- state_of(dir, dict = hs)
  expect_true(st$stale)
  expect_identical(st$reasons, "dict$a is gone")
})

test_that("2e-2 C11: a missing dict.yml gives `dict.yml is gone`", {
  dir <- e2x_state_project()
  hs <- e2x_dict_hashes(file.path(dir, "dict.yml"))
  unlink(file.path(dir, "dict.yml"))
  st <- state_of(dir, dict = hs)
  expect_true(st$stale)
  expect_true("dict.yml is gone" %in% st$reasons)
})

test_that("2e-2 C11: a dict.yml with problems is a note, not stale", {
  dir <- e2x_state_project()
  hs <- e2x_dict_hashes(file.path(dir, "dict.yml"))
  e2x_write(file.path(dir, "dict.yml"), c("a: [unclosed", "b: 2"))
  st <- state_of(dir, dict = hs)
  expect_false(st$stale)
  expect_identical(st$reasons, character())
  expect_identical(st$notes, "dict.yml has problems; the dictionary was not checked")
})

test_that("2e-2 C11: reasons come in the order dictionary entries, then files", {
  dir <- e2x_state_project()
  hs <- e2x_dict_hashes(file.path(dir, "dict.yml"))
  h <- e2x_file_hash(file.path(dir, "doc.qmd"))
  e2x_write(file.path(dir, "dict.yml"),
            c("a: {value: 5, type: number, definition: x}", "b: {value: 6, type: number, definition: y}"))
  e2x_write(file.path(dir, "doc.qmd"), "Changed.")
  st <- state_of(dir, dict = hs, files = c("doc.qmd" = h))
  expect_identical(st$reasons, c("dict$a changed", "dict$b changed", "doc.qmd changed"))
})

# ---- C11: a header without 2e's fields ------------------------------------------------------------

test_that("2e-2 C11: a header without dict, files and targets is not stale and has no notes", {
  dir <- e2x_state_project()
  st <- weft:::ledger_state(dir, e2x_header())
  expect_false(st$stale)
  expect_identical(st$reasons, character())
  expect_identical(st$notes, character())
})

test_that("2e-2 C11: a header with empty objects is not stale either", {
  dir <- e2x_state_project()
  st <- state_of(dir, dict = character(), files = character(), targets = list())
  expect_false(st$stale)
  expect_identical(st$reasons, character())
})

# ---- C11: targets ---------------------------------------------------------------------------------

make_pipeline <- function(dir, fit_code = "1 + 1") {
  e2x_write(file.path(dir, "_targets.R"),
            c("library(targets)", sprintf("list(tar_target(fit, %s), tar_target(obs, 3))", fit_code)))
  withr::with_dir(dir, targets::tar_make(callr_function = NULL, reporter = "silent"))
  invisible(dir)
}
meta_hash <- function(dir, name) {
  m <- targets::tar_meta(fields = "data", store = file.path(dir, "_targets"))
  m$data[m$name == name]
}

test_that("2e-2 C11: a target whose hash matches the store is not stale; after a change and a make it is", {
  skip_if_not_installed("targets")
  dir <- e2x_state_project()
  make_pipeline(dir)
  old <- meta_hash(dir, "fit")
  expect_match(old, "^[0-9a-f]{16}$")
  st <- state_of(dir, targets = list("_targets" = c(fit = old)))
  expect_false(st$stale)
  expect_identical(st$reasons, character())
  expect_identical(st$notes, character())
  make_pipeline(dir, "1 + 2")
  st2 <- state_of(dir, targets = list("_targets" = c(fit = old)))
  expect_true(st2$stale)
  expect_identical(st2$reasons, "target `fit` changed")
})

test_that("2e-2 C11: a null hash in the header against a target now is a change", {
  skip_if_not_installed("targets")
  dir <- e2x_state_project()
  make_pipeline(dir)
  st <- state_of(dir, targets = list("_targets" = c(fit = NA_character_)))
  expect_identical(st$reasons, "target `fit` changed")
})

test_that("2e-2 C11: a target name that is not in the store gives `target `x` is not in the store`", {
  skip_if_not_installed("targets")
  dir <- e2x_state_project()
  make_pipeline(dir)
  st <- state_of(dir, targets = list("_targets" = c(x = "0123456789abcdef")))
  expect_true(st$stale)
  expect_identical(st$reasons, "target `x` is not in the store")
})

test_that("2e-2 C11: several targets give reasons in header order, each only when it differs", {
  skip_if_not_installed("targets")
  dir <- e2x_state_project()
  make_pipeline(dir)
  st <- state_of(dir, targets = list("_targets" = c(fit = "0123456789abcdef", obs = meta_hash(dir, "obs"))))
  expect_identical(st$reasons, "target `fit` changed")
})

test_that("2e-2 C11: a deleted store is a note, not stale", {
  skip_if_not_installed("targets")
  dir <- e2x_state_project()
  make_pipeline(dir)
  old <- meta_hash(dir, "fit")
  unlink(file.path(dir, "_targets"), recursive = TRUE)
  st <- state_of(dir, targets = list("_targets" = c(fit = old)))
  expect_false(st$stale)
  expect_identical(st$reasons, character())
  expect_identical(st$notes, "the store _targets does not exist; the pipeline was not checked")
})

test_that("2e-2 C11: a store that never existed is the same note", {
  skip_if_not_installed("targets")
  dir <- e2x_state_project()
  st <- state_of(dir, targets = list("_targets" = c(fit = "0123456789abcdef")))
  expect_false(st$stale)
  expect_identical(st$notes, "the store _targets does not exist; the pipeline was not checked")
})

test_that("2e-2 C11: a store in a subfolder is named relative to the root", {
  skip_if_not_installed("targets")
  dir <- e2x_state_project()
  sub <- file.path(dir, "sub")
  dir.create(sub)
  make_pipeline(sub)
  old <- meta_hash(sub, "fit")
  st <- state_of(dir, targets = list("sub/_targets" = c(fit = old)))
  expect_false(st$stale)
  expect_identical(st$notes, character())
})

test_that("2e-2 C11: with targets absent the pipeline is not checked, with a note and no staleness", {
  dir <- e2x_state_project()
  h <- e2x_header(targets = list("_targets" = c(fit = "0123456789abcdef")))
  # base's requireNamespace(): weft's namespace has no binding of its own to mock
  testthat::local_mocked_bindings(requireNamespace = function(package, ..., quietly = FALSE) FALSE,
                                  .package = "base")
  st <- weft:::ledger_state(dir, h)
  expect_false(st$stale)
  expect_identical(st$reasons, character())
  expect_identical(st$notes, "targets is not installed; the pipeline was not checked")
})

# ---- changes() and the third state ---------------------------------------------------------------

stale_project <- function(files = c("a.qmd" = "0000000000000000"), ..., env = parent.frame()) {
  dir <- e2x_project(env = env)
  e2x_write(file.path(dir, "dict.yml"), E2X_DICT)
  e2x_put_ledger(dir, "a.qmd", list(e2x_entry("x", "1"), e2x_entry("y", "2"), e2x_entry("z", "3")),
                 files = files, ...)
  e2x_commit(dir)
  dir
}

test_that("2e-2 C12: a stale ledger is under `Not re-rendered` with its count and reason, though no entry differs", {
  skip_if(Sys.which("git") == "")
  dir <- stale_project()
  ch <- changes(path = dir)
  expect_identical(nrow(ch$entries), 0L)
  expect_identical(nrow(ch$stale), 1L)
  expect_identical(ch$stale$ledger, "a.qmd")
  expect_identical(ch$stale$output, "a")
  expect_identical(ch$stale$entries, 3L)
  expect_identical(ch$stale$reason, "a.qmd changed")
  out <- e2x_print(ch)
  expect_match(out[1], "^weft changes since HEAD \\([0-9a-f]{7}\\): 1 ledger compared; 0 changed, 0 added, 0 removed; 0 new conditions$")
  expect_true("Not re-rendered" %in% out)
  expect_true("  a.qmd: 3 entries; a.qmd changed" %in% out)
  expect_false(any(grepl("^weft: no changes", out)))
})

test_that("2e-2 C12: a ledger whose header hash matches its source is not stale", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_project()
  e2x_put_ledger(dir, "a.qmd", list(e2x_entry("x", "1")))
  e2x_put_ledger(dir, "a.qmd", list(e2x_entry("x", "1")),
                 files = c("a.qmd" = e2x_file_hash(file.path(dir, "a.qmd"))))
  e2x_commit(dir)
  ch <- changes(path = dir)
  expect_identical(nrow(ch$stale), 0L)
  out <- e2x_print(ch)
  expect_match(out[nzchar(out)][1], "^weft: no changes since HEAD")
})

test_that("2e-2 C12: one row per reason, and the print joins them with `; ` in C11's order", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_project()
  e2x_write(file.path(dir, "dict.yml"), E2X_DICT)
  hs <- e2x_dict_hashes(file.path(dir, "dict.yml"))
  e2x_put_ledger(dir, "a.qmd", list(e2x_entry("x", "1"), e2x_entry("y", "2")),
                 dict = c(a = hs[["a"]]), files = c("a.qmd" = "0000000000000000"))
  e2x_commit(dir)
  e2x_write(file.path(dir, "dict.yml"),
            c("a: {value: 7, type: number, definition: x}", E2X_DICT[2]))
  ch <- changes(path = dir)
  expect_identical(ch$stale$reason, c("dict$a changed", "a.qmd changed"))
  expect_identical(ch$stale$entries, c(2L, 2L))
  expect_true("  a.qmd: 2 entries; dict$a changed; a.qmd changed" %in% e2x_print(ch))
})

test_that("2e-2 C12: the entries of a stale ledger that changed carry stale = TRUE", {
  skip_if(Sys.which("git") == "")
  dir <- stale_project()
  e2x_put_ledger(dir, "a.qmd", list(e2x_entry("x", "9"), e2x_entry("y", "2"), e2x_entry("z", "3")),
                 files = c("a.qmd" = "0000000000000000"))
  ch <- changes(path = dir)
  expect_identical(nrow(ch$entries), 1L)
  expect_true(ch$entries$stale)
  out <- e2x_print(ch)
  expect_true(any(grepl("^  ~ a.qmd  value  x \\(not re-rendered\\)$", out)))
})

test_that("2e-2 C12: a header without 2e's fields leaves the ledger not stale in changes()", {
  skip_if(Sys.which("git") == "")
  dir <- e2x_scenario(list(e2x_entry("x", "1")), list(e2x_entry("x", "2")))
  ch <- changes(path = dir)
  expect_identical(nrow(ch$stale), 0L)
  expect_false(ch$entries$stale)
  expect_false("Not re-rendered" %in% e2x_print(ch))
})

test_that("2e-2 C2: judging the third state runs no pipeline and writes nothing", {
  skip_if(Sys.which("git") == "")
  dir <- stale_project()
  before <- e2x_snapshot(dir)
  invisible(changes(path = dir))
  expect_identical(e2x_snapshot(dir), before)
})
