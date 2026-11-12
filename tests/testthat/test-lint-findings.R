# Package 3a: lints(), lint_rules(), weft_findings, print(). Contract: dev/design-3.md
# L1 L2 L3 L5 L6 L7 L9 (read) L14. Helpers: helper-3.R.

# ---- L1 exports -----------------------------------------------------------------

test_that("3a L1: lints(), lint_rules() and recall_check() are exported", {
  ex <- getNamespaceExports("weft")
  expect_true(all(c("lints", "lint_rules", "recall_check") %in% ex))
  expect_true(is.function(weft::lints))
  expect_identical(
    names(formals(lints)),
    c("path", "files", "rules", "tier", "reader")
  )
})

test_that("3a L2: lints() argument defaults", {
  f <- formals(lints)
  expect_identical(f$path, ".")
  expect_null(f$files)
  expect_null(f$rules)
  expect_equal(eval(f$tier), 1)
  expect_identical(eval(f$reader)[1], "weft")
  expect_setequal(eval(f$reader), c("weft", "pandoc"))
})

# ---- L5 the findings structure ----------------------------------------------------

test_that("3a L5: a finding has exactly the documented columns, in order, with their types", {
  x <- lint_one(c("Text.", "", F3_BAD_LIT))
  expect_findings_shape(x)
  expect_gte(nrow(x), 1L)
  expect_identical(typeof(x$line), "integer")
  expect_identical(typeof(x$col), "integer")
  expect_identical(typeof(x$end_line), "integer")
  expect_identical(typeof(x$tier), "integer")
})

test_that("3a L5: the columns of a construct finding hold file, rule, tier, spec, context, text, message", {
  x <- lint_one(c("Some prose.", "", paste("See", F3_BAD_LIT, "here.")), ext = "qmd")
  r <- lf_one(x, "construct")
  expect_identical(r$file, "doc.qmd")
  expect_identical(r$line, 3L)
  expect_identical(r$col, 5L)
  expect_identical(r$end_line, 3L)
  expect_identical(r$tier, 1L)
  expect_identical(r$spec, "1.8.10")
  expect_identical(r$context, "prose")
  expect_identical(r$text, F3_BAD_LIT)
  expect_match(r$message, "weft-literal", fixed = TRUE)
  expect_match(r$message, "\\(rule 1\\.8\\.10\\)")
  expect_true(is.na(r$hint))
  expect_true(is.na(r$sentence))
})

test_that("3a L5: file is relative to the root with / separators, also in subfolders", {
  x <- lint_fixture(list(
    "a.qmd" = F3_BAD_LIT,
    "chapters/b.qmd" = F3_BAD_LIT,
    "chapters/deep/c.Rmd" = F3_BAD_LIT
  ))
  expect_setequal(x$file, c("a.qmd", "chapters/b.qmd", "chapters/deep/c.Rmd"))
})

test_that("3a L5: an empty result has the columns and types of a non-empty one", {
  x <- lint_one(c("Plain prose with no constructs.", "", "More prose."))
  expect_equal(nrow(x), 0L)
  expect_findings_shape(x)
  expect_identical(length(attr(x, "notes")), 0L)
})

test_that("3a L5: an empty result over a folder with no documents", {
  root <- lint_proj(list("notes.txt" = "nothing"))
  x <- lints(root)
  expect_equal(nrow(x), 0L)
  expect_findings_shape(x)
})

test_that("3a L2/L5: findings are sorted by file, line, col, rule", {
  x <- lint_fixture(list(
    "z.qmd" = c(F3_BAD_LIT, "", F3_BAD_TWO),
    "a.qmd" = c("x", "", paste(F3_BAD_LIT, F3_BAD_TWO), "", F3_BAD_PARSE),
    "m/b.qmd" = F3_BAD_LIT
  ))
  expect_gte(nrow(x), 6L)
  o <- order(x$file, x$line, x$col, x$rule, method = "radix")
  expect_identical(o, seq_len(nrow(x)))
  # two findings on one line are ordered by column
  a <- x[x$file == "a.qmd" & x$line == 3L, ]
  expect_identical(a$col, sort(a$col))
  expect_equal(nrow(a), 2L)
})

test_that("3a L5: findings that differ only in text are not duplicates", {
  x <- lint_one(c("`r x +` and `r y -`"))
  expect_equal(nrow(lf_by_rule(x, "construct")), 2L)
})

# ---- L2 lints() arguments ----------------------------------------------------------

test_that("3a L2: path may be a folder, a file inside a project, or '.' as the working folder", {
  root <- lint_proj(list("a.qmd" = F3_BAD_LIT, "sub/b.qmd" = F3_BAD_TWO), weft_yml = "numeral_years: false")
  x1 <- lints(root, tier = 1:2)
  expect_setequal(x1$file, c("a.qmd", "sub/b.qmd"))
  withr::with_dir(root, {
    x2 <- lints(tier = 1:2)
    expect_setequal(x2$file, c("a.qmd", "sub/b.qmd"))
  })
  # a file path: findings are for that file, named relative to the root (design: silent
  # whether other files are reported too; only the named file's rows are checked)
  x3 <- lints(file.path(root, "sub", "b.qmd"), tier = 1:2)
  expect_true("sub/b.qmd" %in% x3$file)
  expect_false(any(grepl("^/|\\\\", x3$file)))
})

test_that("3a L2: a project need not be set up (no _weft.yml means the defaults)", {
  root <- lint_proj(list("a.qmd" = F3_BAD_LIT))
  expect_false(file.exists(file.path(root, "_weft.yml")))
  expect_no_error(lints(root))
  x <- lints(root)
  expect_true("construct" %in% x$rule)
})

test_that("3a L2: files limits the findings reported, as relative or absolute paths", {
  root <- lint_proj(list("a.qmd" = F3_BAD_LIT, "b.qmd" = F3_BAD_TWO, "c.Rmd" = F3_BAD_PARSE))
  all <- lints(root, tier = 1:2)
  expect_setequal(all$file, c("a.qmd", "b.qmd", "c.Rmd"))
  expect_setequal(lints(root, files = "b.qmd", tier = 1:2)$file, "b.qmd")
  expect_setequal(lints(root, files = file.path(root, "a.qmd"), tier = 1:2)$file, "a.qmd")
  expect_setequal(lints(root, files = c("a.qmd", "c.Rmd"), tier = 1:2)$file, c("a.qmd", "c.Rmd"))
  # the unnamed documents are still read (L3), only not reported
  expect_equal(nrow(lints(root, files = "b.qmd", tier = 1:2)), nrow(all[all$file == "b.qmd", ]))
})

test_that("3a L2: files accepts .qmd, .Rmd and .rmd", {
  root <- lint_proj(list("a.qmd" = F3_BAD_LIT, "b.Rmd" = F3_BAD_LIT, "c.rmd" = F3_BAD_LIT))
  for (f in c("a.qmd", "b.Rmd", "c.rmd")) {
    expect_setequal(lints(root, files = f, tier = 1:2)$file, f)
  }
})

test_that("3a L2: rules selects ids from lint_rules(); NULL is every rule", {
  root <- lint_proj(list("a.qmd" = c(F3_BAD_LIT, "", F3_BAD_TWO)))
  all <- lints(root, tier = 1:2)
  sel <- lints(root, rules = "construct", tier = 1:2)
  expect_setequal(unique(sel$rule), "construct")
  expect_equal(nrow(sel), nrow(all[all$rule == "construct", ]))
  expect_equal(nrow(lints(root, rules = c("construct", "numeral"), tier = 1:2)), nrow(sel))
  # a rule that exists but finds nothing here
  none <- lints(root, rules = "numeral", tier = 1:2)
  expect_equal(nrow(none), 0L)
  expect_findings_shape(none)
})

test_that("3a L2: tier filters rules; construct is tier 1", {
  root <- lint_proj(list("a.qmd" = F3_BAD_LIT))
  expect_true("construct" %in% lints(root, tier = 1)$rule)
  expect_true("construct" %in% lints(root, tier = 1:2)$rule)
  expect_equal(nrow(lints(root, tier = 2)), 0L)
  expect_true(all(lints(root, tier = 1:2)$tier %in% 1:2))
})

test_that("3a L2/K17: the default tier is 1 (only tier-1 findings)", {
  root <- lint_proj(list("a.qmd" = c(F3_BAD_LIT, "", "Plain prose, all sites rose.")))
  x <- lints(root)
  expect_true(all(x$tier == 1L))
  expect_identical(x, lints(root, tier = 1))
})

test_that("3a L2: the same results under .qmd and .Rmd", {
  r <- f3_both(function(ext) {
    x <- lint_one(c("Prose.", "", paste("A", F3_BAD_TWO, "b.")), ext = ext)
    x[, setdiff(names(x), "file")]
  })
  expect_identical(unclass(r$qmd)[F3_COLS[-1]], unclass(r$Rmd)[F3_COLS[-1]])
  expect_gte(nrow(r$qmd), 1L)
})

# ---- L3 the file set ---------------------------------------------------------------

test_that("3a L3: documents under _, . and renv folders are not read; .md files are never linted", {
  x <- lint_fixture(list(
    "top.qmd" = F3_BAD_LIT,
    "x.rmd" = F3_BAD_LIT,
    "sub/deep/y.Rmd" = F3_BAD_LIT,
    "_extra/h.qmd" = F3_BAD_LIT,
    ".hidden/h.qmd" = F3_BAD_LIT,
    "renv/h.qmd" = F3_BAD_LIT,
    "sub/_private/h.qmd" = F3_BAD_LIT,
    "notes.md" = F3_BAD_LIT,
    "sub/readme.md" = F3_BAD_LIT
  ))
  expect_setequal(x$file, c("top.qmd", "x.rmd", "sub/deep/y.Rmd"))
})

test_that("3a L3: files naming a document does not stop other documents being read", {
  # a clean file named in `files` while another file has the error: no findings reported
  root <- lint_proj(list("a.qmd" = "Clean prose.", "b.qmd" = F3_BAD_LIT))
  x <- lints(root, files = "a.qmd", tier = 1:2)
  expect_equal(nrow(x), 0L)
  expect_findings_shape(x)
})

# ---- L14 errors --------------------------------------------------------------------

test_that("3a L14: path must be one existing path (weft_lint_error)", {
  root <- lint_proj(list("a.qmd" = "x"))
  e <- f2_cond(lints(file.path(root, "nope")))
  f2_has_class(e, "weft_lint_error")
  e <- f2_cond(lints(c(root, root)))
  f2_has_class(e, "weft_lint_error")
  e <- f2_cond(lints(character(0)))
  f2_has_class(e, "weft_lint_error")
  e <- f2_cond(lints(NA_character_))
  f2_has_class(e, "weft_lint_error")
  e <- f2_cond(lints(1))
  f2_has_class(e, "weft_lint_error")
})

test_that("3a L14: a files entry that is missing, outside the root or of another extension is an error naming all of them", {
  root <- lint_proj(list("a.qmd" = "x", "notes.md" = "y", "c.txt" = "z"))
  outside <- withr::local_tempfile(fileext = ".qmd")
  writeLines("x", outside)
  e <- f2_cond(lints(root, files = c("missing.qmd", "notes.md", "c.txt", outside)))
  f2_has_class(e, "weft_lint_error")
  f2_msg_has(e, "missing.qmd", "notes.md", "c.txt")
  expect_true(grepl(basename(outside), f2_msg(e), fixed = TRUE))
  # one bad entry among good ones still fails
  e2 <- f2_cond(lints(root, files = c("a.qmd", "missing.qmd")))
  f2_has_class(e2, "weft_lint_error")
  f2_msg_has(e2, "missing.qmd")
})

test_that("3a L14: an unknown rule id is an error with a suggestion from did_you_mean()", {
  root <- lint_proj(list("a.qmd" = "x"))
  e <- f2_cond(lints(root, rules = "construtc"))
  f2_has_class(e, "weft_lint_error")
  f2_msg_has(e, "construtc", "Did you mean", "construct")
  e <- f2_cond(lints(root, rules = c("construct", "zzzzzz")))
  f2_has_class(e, "weft_lint_error")
  f2_msg_has(e, "zzzzzz")
})

test_that("3a L14: tier outside 1:2 is an error", {
  root <- lint_proj(list("a.qmd" = "x"))
  for (t in list(3, 0, c(1, 3), -1, NA, "one", integer(0))) {
    e <- f2_cond(lints(root, tier = t))
    f2_has_class(e, "weft_lint_error")
  }
})

test_that("3a L2/L14: reader is one of weft and pandoc; other values are errors", {
  root <- lint_proj(list("a.qmd" = F3_BAD_LIT))
  # the validation error class is not named by the design for match.arg-style
  # failures; any error is accepted here
  expect_error(lints(root, reader = "bogus"))
  expect_error(lints(root, reader = c("weft", "pandoc", "x")))
  expect_error(lints(root, reader = 1))
  # the default and the explicit "weft" agree
  expect_identical(lints(root, reader = "weft", tier = 1:2), lints(root, tier = 1:2))
})

test_that("3a L14/L15: reader = 'pandoc' with no Pandoc found is a weft_lint_error naming weft.pandoc", {
  has_fn <- exists("pandoc_path", envir = asNamespace("weft"), inherits = FALSE)
  skip_if(!has_fn, "pandoc_path() is 3b's")
  skip_if(nzchar(weft:::pandoc_path()), "a Pandoc is installed here")
  root <- lint_proj(list("a.qmd" = "x"))
  e <- f2_cond(lints(root, reader = "pandoc"))
  f2_has_class(e, "weft_lint_error")
  f2_msg_has(e, "needs Pandoc", "weft.pandoc", "2.10.3")
})

test_that("3a L1/L15: reader = 'weft' (the default) works with Pandoc unreachable", {
  empty <- withr::local_tempdir()
  withr::local_envvar(PATH = empty, WEFT_PANDOC = "")
  withr::local_options(weft.pandoc = NULL)
  root <- lint_proj(list("a.qmd" = F3_BAD_LIT))
  expect_no_error(lints(root))
  x <- lints(root)
  expect_true("construct" %in% x$rule)
})

test_that("3a L14: lints errors are also weft_error", {
  e <- f2_cond(lints(tempfile("nope")))
  f2_has_class(e, "weft_lint_error")
  expect_true(inherits(e, "weft_error"))
})

# ---- L6 lint_rules() ----------------------------------------------------------------

# the ids of design section 1, in its order (a subsequence of lint_rules()$id; `read`
# and `xref-code` are named elsewhere in the design and may sit anywhere)
F3_IDS <- c("numeral", "construct", "block-start", "lone-bar", "if-zero", "name",
            "inert-check", "long-guard", "cite-key", "cite-bare", "citation-key",
            "claim-word", "literal-value", "value-constant", "value-format",
            "xref", "anchor-twice", "ref-label", "anchor-unused",
            "section-anchor", "chunk-label", "tar-name", "dict-assign", "file-link",
            "above-setup", "dict-key", "tar-cache", "config-place", "engine",
            "figure", "table-caption")
F3_TIERS <- c(numeral = 1, construct = 1, `block-start` = 1, `lone-bar` = 2, `if-zero` = 2,
              name = 2, `inert-check` = 1, `long-guard` = 2, `cite-key` = 1,
              `cite-bare` = 1, `citation-key` = 1, `claim-word` = 2,
              `literal-value` = 1, `value-constant` = 2, `value-format` = 2,
              xref = 1, `anchor-twice` = 1, `ref-label` = 1, `anchor-unused` = 2,
              `section-anchor` = 1, `chunk-label` = 1, `tar-name` = 1,
              `dict-assign` = 1, `file-link` = 1, `above-setup` = 1, `dict-key` = 1,
              `tar-cache` = 1, `config-place` = 1, engine = 1, figure = 1,
              `table-caption` = 1)

test_that("3a L6: lint_rules() is a data frame id, spec, tier, scope, what", {
  r <- lint_rules()
  expect_s3_class(r, "data.frame")
  expect_identical(names(r), c("id", "spec", "tier", "scope", "what"))
  expect_type(r$id, "character")
  expect_type(r$spec, "character")
  expect_true(is.numeric(r$tier))
  expect_type(r$scope, "character")
  expect_type(r$what, "character")
  expect_false(anyDuplicated(r$id) > 0)
  expect_true(all(r$scope %in% c("file", "project")))
  expect_true(all(r$tier %in% 1:2))
  expect_false(anyNA(r$what))
  expect_true(all(nzchar(r$what)))
})

test_that("3a L6: every rule of section 1 is listed, in section 1's order", {
  r <- lint_rules()
  expect_true(all(F3_IDS %in% r$id), label = paste("missing:", paste(setdiff(F3_IDS, r$id), collapse = ", ")))
  pos <- match(F3_IDS, r$id)
  expect_identical(pos, sort(pos))
})

test_that("3a L6: tiers are those of section 1", {
  r <- lint_rules()
  for (id in names(F3_TIERS)) {
    expect_equal(r$tier[r$id == id], F3_TIERS[[id]], label = paste("tier of", id))
  }
})

test_that("3a L6: specs are rule numbers; construct is a file-scope rule", {
  r <- lint_rules()
  expect_true(all(grepl("^[0-9]+(\\.[0-9]+)+$", r$spec[r$id %in% F3_IDS])))
  expect_match(r$spec[r$id == "numeral"], "^5\\.2\\.")
  expect_match(r$spec[r$id == "construct"], "^5\\.3\\.")
  expect_match(r$spec[r$id == "claim-word"], "^5\\.5\\.")
  expect_identical(r$scope[r$id == "construct"], "file")
})

test_that("3a L6: every id lint_rules() lists is accepted by lints(rules =)", {
  root <- lint_proj(list("a.qmd" = "Plain."))
  for (id in lint_rules()$id) {
    expect_no_error(lints(root, rules = id, tier = 1:2))
  }
})

# ---- L9 the read finding -----------------------------------------------------------

test_that("3a L9: a file that is not UTF-8 gives the finding read (tier 1, 5.1.3) and no other", {
  bytes <- c(charToRaw("Caf"), as.raw(0xE9), charToRaw(" "), charToRaw(F3_BAD_LIT), charToRaw("\n"))
  x <- lint_fixture(list("bad.qmd" = bytes, "ok.qmd" = F3_BAD_TWO))
  b <- x[x$file == "bad.qmd", ]
  expect_equal(nrow(b), 1L)
  expect_identical(b$rule, "read")
  expect_identical(b$tier, 1L)
  expect_identical(b$spec, "5.1.3")
  expect_true("construct" %in% x$rule[x$file == "ok.qmd"])
  expect_findings_shape(x)
})

test_that("3a L9: a UTF-8 file with a BOM and one with CRLF are read, not refused", {
  x <- lint_fixture(list(
    "bom.qmd" = list(lines = c("a", F3_BAD_LIT), bom = TRUE),
    "crlf.qmd" = list(lines = c("a", F3_BAD_LIT), eol = "\r\n")
  ))
  expect_false("read" %in% x$rule)
  expect_setequal(x$file[x$rule == "construct"], c("bom.qmd", "crlf.qmd"))
})

# ---- L7 printing -------------------------------------------------------------------

pr <- function(x, ...) capture.output(print(x, ...))

test_that("3a L7: print() shows a header, the file, then 'line:col  rule  message' rows", {
  x <- lint_fixture(list("chapters/results.qmd" = c("Text.", "", paste("See", F3_BAD_LIT), "", F3_BAD_TWO)),
                    rules = "construct", tier = 1:2)
  expect_equal(nrow(x), 2L)
  out <- pr(x)
  expect_identical(out[[1]], "weft lints: 2 findings in 1 file (2 tier 1, 0 tier 2)")
  expect_identical(out[[2]], "")
  expect_identical(out[[3]], "chapters/results.qmd")
  rows <- out[4:length(out)]
  l1 <- grep("^  3:5 +construct +", rows, value = TRUE)
  expect_length(l1, 1L)
  expect_match(l1, "weft-literal", fixed = TRUE)
  expect_match(l1, "\\(rule 1\\.8\\.10\\)\\.$")
  l2 <- grep("^  5:1 +construct +", rows, value = TRUE)
  expect_length(l2, 1L)
  expect_match(l2, "\\(rule 1\\.1\\.5\\)\\.$")
})

test_that("3a L7: print() returns its argument invisibly", {
  x <- lint_one(F3_BAD_LIT)
  expect_invisible(capture.output(y <- print(x)))
  expect_identical(y, x)
})

test_that("3a L7: print() groups findings under each file in file order", {
  x <- lint_fixture(list("b.qmd" = F3_BAD_LIT, "a.qmd" = F3_BAD_LIT), rules = "construct")
  out <- pr(x)
  expect_match(out[[1]], "^weft lints: 2 findings in 2 files \\(2 tier 1, 0 tier 2\\)$")
  ia <- which(out == "a.qmd")
  ib <- which(out == "b.qmd")
  expect_length(ia, 1L)
  expect_length(ib, 1L)
  expect_lt(ia, ib)
})

test_that("3a L7: a single finding reads '1 finding in 1 file' (design gives only the plural)", {
  x <- lint_one(F3_BAD_LIT)
  expect_equal(nrow(x), 1L)
  expect_identical(pr(x)[[1]], "weft lints: 1 finding in 1 file (1 tier 1, 0 tier 2)")
})

test_that("3a L7: no findings prints 'weft lints: no findings in N files.'", {
  root <- lint_proj(list("a.qmd" = "x", "b.qmd" = "y", "c.Rmd" = "z", "d/e.qmd" = "w"))
  out <- pr(lints(root))
  expect_identical(out, "weft lints: no findings in 4 files.")
})

test_that("3a L7: past max rows the printout ends '... and N more findings.'", {
  doc <- rep(c(F3_BAD_LIT, ""), 5)
  x <- lint_one(doc, rules = "construct")
  expect_equal(nrow(x), 5L)
  out <- pr(x, max = 2)
  expect_identical(out[[length(out)]], "... and 3 more findings.")
  expect_equal(sum(grepl(" construct ", out)), 2L)
  out_all <- pr(x, max = 200)
  expect_false(any(grepl("more finding", out_all)))
  expect_equal(sum(grepl(" construct ", out_all)), 5L)
  # the default max is 200
  expect_identical(pr(x), out_all)
})

test_that("3a L7: notes follow under 'Notes:'", {
  x <- lint_one(F3_BAD_LIT)
  attr(x, "notes") <- c("No store was found, so tar-name did not run.", "Second note.")
  out <- pr(x)
  i <- which(out == "Notes:")
  expect_length(i, 1L)
  tail_txt <- paste(out[(i + 1):length(out)], collapse = "\n")
  expect_match(tail_txt, "No store was found", fixed = TRUE)
  expect_match(tail_txt, "Second note.", fixed = TRUE)
})

test_that("3a L7: no 'Notes:' heading when there are no notes", {
  x <- lint_one(F3_BAD_LIT)
  expect_false(any(pr(x) == "Notes:"))
})

test_that("3a L7: printed text is ASCII", {
  x <- lint_one(c("Caf\u00e9 caf\u00e9 [1]{.weft-literal} \u2014 end."))
  expect_true(all(!grepl("[^\\x01-\\x7F]", pr(x), perl = TRUE)))
})
