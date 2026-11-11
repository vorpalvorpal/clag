# Package 2c: use_dictionary(). Contract: dev/design-2c.md "use_dictionary(path = \".\")",
# rules 9.3.1, 9.3.3, P10, C15-C17. Helpers: helper-2c.R. Every write is in a temp project.

C2_STARTER <- c(
  "# yaml-language-server: $schema=_weft/dict.schema.json",
  "#",
  "# The project dictionary: the values this project chose, each with its",
  "# definition. Prose and code read an entry as dict$key. Every entry has a",
  "# value, a type and a definition; the types are number, quantity, year,",
  "# date, string, labels and breaks. See ?weft::dict_file for every field.",
  "#",
  "# A unit the units package does not know (sites, PSU) is registered when",
  "# this file is read; give it a name under `units:` in _weft.yml.",
  "#",
  "# Two examples follow. Remove the \"# \" before an entry's lines to use it.",
  "#",
  "# core_len:",
  "#   value: 50",
  "#   type: quantity",
  "#   unit: cm",
  "#   display: m            # read in cm, shown in m: dict$core_len is 0.5 m",
  "#   definition: \"Length of each sediment core.\"",
  "#   decision: 12          # the issue where the length was chosen",
  "#",
  "# study_area:",
  "#   value: \"Northern catchment\"",
  "#   type: string",
  "#   definition: \"Name used for the study region.\"",
  "#   avoid: [\"northern catchment\", \"North catchment\"]   # see dict_vale()"
)

SCHEMA_LINE <- "# yaml-language-server: $schema=_weft/dict.schema.json"

ud_lines <- function(root, dict, schema) {
  c(paste0("weft will write, under ", root, ":"),
    paste0("  dict.yml  (", dict, ")"),
    paste0("  _weft/dict.schema.json  (", schema, ")"))
}

NEW_DICT <- "new: a starter dictionary, with two examples commented out"
NEW_SCHEMA <- "new: the JSON Schema an editor checks dict.yml against"

test_that("2c exports: the four tools are exported and dict_glossary joins the attached functions (2.1.8, C38)", {
  expect_true(all(c("use_dictionary", "dict_glossary", "dict_vale", "dict_seed") %in%
                    getNamespaceExports("weft")))
  expect_true("dict_glossary" %in% weft:::inline_function_names())
})

test_that("2c DESCRIPTION: curl is in Suggests and not in Imports (C27, Dependencies)", {
  d <- read.dcf(system.file("DESCRIPTION", package = "weft"), fields = c("Imports", "Suggests"))
  expect_true(grepl("\\bcurl\\b", d[1, "Suggests"]))
  expect_false(grepl("\\bcurl\\b", d[1, "Imports"]))
})

test_that("2c use_dictionary: an empty folder gets the five messages in order, both files, and the paths back (9.3.1, 9.3.3)", {
  dir <- c2_proj()
  r <- c2_says(use_dictionary(dir))
  expect_identical(r$msgs, c(ud_lines(dir, NEW_DICT, NEW_SCHEMA),
                             "Wrote: dict.yml, _weft/dict.schema.json"))
  expect_identical(r$value, c("dict.yml", "_weft/dict.schema.json"))
  expect_false(r$visible)
  expect_identical(c2_tree(dir), c("_weft", "_weft/dict.schema.json", "dict.yml"))
  expect_identical(c2_bytes(file.path(dir, "dict.yml")), c2_bytes(c2_inst("dict.yml")))
  expect_identical(c2_bytes(file.path(dir, "_weft", "dict.schema.json")),
                   c2_bytes(c2_inst("dict.schema.json")))
})

test_that("2c use_dictionary: it says what it will write before the first file exists (P10, 9.3.1)", {
  dir <- c2_proj()
  seen <- NULL
  c2_says(use_dictionary(dir), on_first = function() {
    seen <<- c(dict = file.exists(file.path(dir, "dict.yml")),
               weft = file.exists(file.path(dir, "_weft")))
  })
  expect_false(is.null(seen))
  expect_false(any(seen))
})

test_that("2c use_dictionary: the shipped starter is exactly the contract's text, LF, final newline, no trailing space (C15)", {
  p <- c2_inst("dict.yml")
  expect_true(file.exists(p))
  raw <- c2_bytes(p)
  expect_identical(raw, charToRaw(paste0(paste(C2_STARTER, collapse = "\n"), "\n")))
  expect_false(as.raw(13) %in% raw)
  expect_false(any(grepl(" $", C2_STARTER)))
})

test_that("2c use_dictionary: the starter reads as no keys; uncommented from `# core_len:` it reads as two keys (C15)", {
  dir <- c2_proj()
  suppressMessages(use_dictionary(dir))
  d0 <- read_dict(file.path(dir, "dict.yml"))
  expect_length(d0, 0L)
  src <- readLines(file.path(dir, "dict.yml"), warn = FALSE)
  from <- grep("^# core_len:", src)[1]
  src[from:length(src)] <- sub("^# ?", "", src[from:length(src)])
  p <- file.path(dir, "live.yml")
  writeLines(src, p)
  d <- read_dict(p)
  expect_identical(names(d), c("core_len", "study_area"))
  expect_qty(d$core_len, 0.5, "m")
  e <- attr(d, "entries")
  expect_identical(e$decision[e$key == "core_len"], "12")
  expect_identical(e$avoid[[which(e$key == "study_area")]], c("northern catchment", "North catchment"))
})

test_that("2c use_dictionary: a second run says only 'Nothing to change' and touches nothing (9.3.1)", {
  dir <- c2_proj()
  suppressMessages(use_dictionary(dir))
  files <- file.path(dir, c("dict.yml", "_weft/dict.schema.json"))
  old <- as.POSIXct("2001-02-03 04:05:06", tz = "UTC")
  for (f in files) Sys.setFileTime(f, old)
  before <- lapply(files, c2_bytes)
  r <- c2_says(use_dictionary(dir))
  expect_identical(r$msgs, "Nothing to change: dict.yml and its schema are in place.")
  expect_identical(r$value, character())
  expect_false(r$visible)
  expect_identical(lapply(files, c2_bytes), before)
  expect_equal(as.numeric(file.mtime(files)), rep(as.numeric(old), 2))
})

test_that("2c C16: an existing dict.yml is left byte for byte, said so, and the schema line is offered when missing", {
  dir <- c2_proj(list(dict.yml = c("a: {value: 1, type: number, definition: x}")))
  before <- c2_bytes(file.path(dir, "dict.yml"))
  r <- c2_says(use_dictionary(dir))
  expect_identical(r$msgs[1:4], c(ud_lines(dir, "exists: left as it is", NEW_SCHEMA),
                                  "Wrote: _weft/dict.schema.json"))
  expect_identical(r$value, "_weft/dict.schema.json")
  expect_identical(c2_bytes(file.path(dir, "dict.yml")), before)
  expect_true(length(r$msgs) > 4L)
  tail_txt <- paste(r$msgs[-(1:4)], collapse = "\n")
  expect_identical(tail_txt, paste0(
    "dict.yml has no schema line; for an editor to check it, add this as its first line:\n",
    "  # yaml-language-server: $schema=_weft/dict.schema.json"))
})

test_that("2c C16: with schema and dict.yml in place but no schema line, 'Nothing to change' is followed by the schema-line message", {
  dir <- c2_proj(list(dict.yml = c("a: {value: 1, type: number, definition: x}")))
  suppressMessages(use_dictionary(dir))
  r <- c2_says(use_dictionary(dir))
  expect_identical(r$msgs[1], "Nothing to change: dict.yml and its schema are in place.")
  expect_match(r$all, "dict.yml has no schema line; for an editor to check it, add this as its first line:", fixed = TRUE)
  expect_match(r$all, "  # yaml-language-server: $schema=_weft/dict.schema.json", fixed = TRUE)
  expect_identical(r$value, character())
})

test_that("2c C16: an existing dict.yml that has the schema line gets no schema-line message", {
  dir <- c2_proj(list(dict.yml = c(SCHEMA_LINE, "a: {value: 1, type: number, definition: x}")))
  r <- c2_says(use_dictionary(dir))
  expect_false(grepl("has no schema line", r$all, fixed = TRUE))
  expect_identical(r$msgs[2], "  dict.yml  (exists: left as it is)")
})

test_that("2c use_dictionary: a schema that differs from the shipped one is replaced, and the line says so (C17)", {
  dir <- c2_proj(list(`_weft/dict.schema.json` = "{}"))
  r <- c2_says(use_dictionary(dir))
  expect_identical(r$msgs, c(
    ud_lines(dir, NEW_DICT, "exists: replaced by the schema of this version of weft"),
    "Wrote: dict.yml, _weft/dict.schema.json"))
  expect_identical(c2_bytes(file.path(dir, "_weft", "dict.schema.json")),
                   c2_bytes(c2_inst("dict.schema.json")))
})

test_that("2c use_dictionary: a current schema beside a missing dict.yml: 'exists and is current' and only dict.yml written (C17)", {
  dir <- c2_proj()
  suppressMessages(use_dictionary(dir))
  unlink(file.path(dir, "dict.yml"))
  r <- c2_says(use_dictionary(dir))
  expect_identical(r$msgs, c(
    ud_lines(dir, NEW_DICT, "exists and is current: left as it is"), "Wrote: dict.yml"))
  expect_identical(r$value, "dict.yml")
})

test_that("2c use_dictionary: from a subfolder of a project it says the root and writes there (rule 9.3.1 step 2)", {
  root <- c2_proj(list(`_weft.yml` = "digits: 1"))
  sub <- file.path(root, "chapters", "one")
  dir.create(sub, recursive = TRUE)
  r <- c2_says(use_dictionary(sub))
  expect_identical(r$msgs[1],
                   sprintf("weft: the project root is %s (it holds _weft.yml); writing there.", root))
  expect_identical(r$msgs[2], paste0("weft will write, under ", root, ":"))
  expect_true(file.exists(file.path(root, "dict.yml")))
  expect_true(file.exists(file.path(root, "_weft", "dict.schema.json")))
  expect_identical(c2_tree(sub), character())
  expect_identical(r$value, c("dict.yml", "_weft/dict.schema.json"))
})

test_that("2c use_dictionary: a root held by _quarto.yml names that marker (step 2)", {
  root <- c2_proj(list(`_quarto.yml` = "project:\n  type: default"))
  sub <- file.path(root, "a")
  dir.create(sub)
  r <- c2_says(use_dictionary(sub))
  expect_identical(r$msgs[1],
                   sprintf("weft: the project root is %s (it holds _quarto.yml); writing there.", root))
  expect_true(file.exists(file.path(root, "dict.yml")))
})

test_that("2c use_dictionary: a folder that is its own root gives no root message (step 2)", {
  root <- c2_proj(list(`_weft.yml` = "digits: 1"))
  r <- c2_says(use_dictionary(root))
  expect_false(any(grepl("the project root is", r$msgs, fixed = TRUE)))
})

test_that("2c use_dictionary: it writes nothing outside dict.yml and _weft/dict.schema.json (P10)", {
  dir <- c2_proj(list(`keep.txt` = "x", `sub/other.yml` = "y"))
  before <- c2_tree(dir)
  suppressMessages(use_dictionary(dir))
  expect_identical(setdiff(c2_tree(dir), before), c("_weft", "_weft/dict.schema.json", "dict.yml"))
  expect_true(all(before %in% c2_tree(dir)))
})

test_that("2c use_dictionary: a path that is a file, missing, NA or not one string is a weft_tool_error and writes nothing (step 1)", {
  dir <- c2_proj(list(`afile.txt` = "x"))
  before <- c2_tree(dir)
  e1 <- c2_err(use_dictionary(file.path(dir, "afile.txt")))
  c2_expect_cond(e1, "weft_tool_error")
  c2_expect_msg(e1, "use_dictionary(): `path` must be a directory; got `", file.path(dir, "afile.txt"))
  e2 <- c2_err(use_dictionary(file.path(dir, "nope")))
  c2_expect_cond(e2, "weft_tool_error")
  c2_expect_msg(e2, "use_dictionary(): `path` must be a directory; got `", file.path(dir, "nope"))
  c2_expect_cond(c2_err(use_dictionary(NA)), "weft_tool_error")
  c2_expect_cond(c2_err(use_dictionary(NA_character_)), "weft_tool_error")
  e3 <- c2_err(use_dictionary(c(dir, dir)))
  c2_expect_cond(e3, "weft_tool_error")
  c2_expect_msg(e3, "`path` must be a directory; got `something else`.")
  e4 <- c2_err(use_dictionary(1))
  c2_expect_cond(e4, "weft_tool_error")
  c2_expect_msg(e4, "got `something else`.")
  expect_identical(c2_tree(dir), before)
})

test_that("2c use_dictionary: it never asks, interactive or not, and suppressMessages() silences it (step 7, P10)", {
  d1 <- c2_proj()
  rlang::local_interactive(FALSE)
  expect_silent(suppressMessages(use_dictionary(d1)))
  d2 <- c2_proj()
  rlang::local_interactive(TRUE)
  r <- c2_says(use_dictionary(d2))
  expect_identical(c2_tree(d1), c2_tree(d2))
  expect_identical(r$value, c("dict.yml", "_weft/dict.schema.json"))
  expect_identical(length(r$msgs), 4L)
  d3 <- c2_proj()
  expect_no_message(suppressMessages(use_dictionary(d3)))
  expect_true(file.exists(file.path(d3, "dict.yml")))
})
