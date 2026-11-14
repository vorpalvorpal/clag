# Package 7j: checks(), the report of checks grouped by value, and its print (dev/design-7.md N141 to N146, E91 to E93).
# Small projects on disk, built with lint_proj() of helper-3.R; nothing is run.

E93 <- function(n) sprintf("checked in %d places with the same condition: check it once where the value is made", n)
cut60 <- function(x) ifelse(nchar(x) > 60, paste0(substr(x, 1, 57), "..."), x)

pr <- function(x) cli::ansi_strip(utils::capture.output(print(x)))

cmsg <- function(expr) tryCatch({ expr; NA_character_ }, error = function(e) conditionMessage(e))
cclass <- function(expr) tryCatch({ expr; NA_character_ }, error = function(e) class(e)[[1]])

# ---- the value (N142) ---------------------------------------------------------------------------------------------------

test_that("7j N142: checks() gives a weft_checks data frame, one row per check, with the documented columns", {
  a <- c('A [one]{if="x > 5"} and [two]{if="y < 2"} here.', "",
         "```{r}", 'claim(w, . > 1, level = "warn")', "claim(all(w), .)", "```", "",
         'A [high | low]{if="x >= 5"} here.')
  b <- 'A [it]{if="z == \'a\'"} here.'
  root <- lint_proj(list("b.Rmd" = b, "a.Rmd" = a))
  x <- checks(root)
  expect_s3_class(x, "weft_checks")
  expect_s3_class(x, "data.frame")
  expect_identical(names(x), c("file", "line", "role", "level", "value", "op", "other", "cond", "text", "always",
                               "rebound", "flag", "repeated"))
  expect_type(x$file, "character")
  expect_type(x$line, "integer")
  expect_type(x$role, "character")
  expect_type(x$level, "character")
  expect_type(x$cond, "character")
  expect_type(x$text, "character")
  expect_type(x$always, "logical")
  expect_type(x$rebound, "logical")
  expect_type(x$flag, "character")
  expect_type(x$repeated, "integer")
  expect_true(is.character(attr(x, "notes")))
  expect_identical(nrow(x), 6L)
  # sorted by file, line and column
  expect_identical(x$file, c(rep("a.Rmd", 5L), "b.Rmd"))
  expect_identical(x$line, c(1L, 1L, 4L, 5L, 8L, 1L))
  expect_identical(x$role, c("guard", "guard", "claim", "claim", "branch", "guard"))
  expect_identical(x$level, c("fail", "fail", "warn", "fail", NA, "fail"))
  expect_identical(x$value, c("x", "y", "w", NA, "x", "z"))
  expect_identical(x$op, c(">", "<", ">", NA, ">=", "=="))
  expect_identical(x$other, c("5", "2", "1", NA, "5", "'a'"))
  expect_identical(x$cond, c("x > 5", "y < 2", "w > 1", NA, "x >= 5", "z == 'a'"))
  expect_identical(x$text[[4]], "claim(all(w), .)")
  expect_identical(x$always, rep(TRUE, 6L))
  expect_identical(x$rebound, rep(FALSE, 6L))
  # x is checked against 5 with > and >=: flagged, in both rows of the group; the rest are not
  expect_identical(x$flag, c("operators", "", "", "", "operators", ""))
  expect_identical(x$repeated, c(1L, 1L, 1L, NA, NA, 1L))
})

# ---- N143: flags ------------------------------------------------------------------------------------------------------------------

test_that("7j N143: each flag, and each case that is not flagged", {
  cases <- list(
    f01 = list(c("x < 5", "x <= 5"), c("operators", "operators")),
    f02 = list(c("x > 5", "x >= 5"), c("operators", "operators")),
    f03 = list(c("x > 5", "x > 3"), c("literals", "literals")),
    f04 = list(c("x > 5", "x >= 5", "x > 3"), rep("operators; literals", 3L)),
    f05 = list(c("x == 5", "x == 6"), c("literals", "literals")),
    f06 = list(c("x", "!x"), c("literals", "literals")),
    f07 = list(c("x < 5", "x <= 3"), c("literals", "literals")),
    f08 = list(c("x > 0", "x < 10"), c("", "")),
    f09 = list(c("x != 1", "x != 2"), c("", "")),
    f10 = list(c("x == 5", "x >= 5"), c("", "")),
    f11 = list(c("x > a", "x > b"), c("", "")),
    f12 = list(c("x > 5", "x > '2024-01-01'"), c("", "")),
    f13 = list(c("x < u(5, NTU)", "x < u(3, kNTU)"), c("", "")),
    f14 = list(c("x < u(5, NTU)", "x < u(3, NTU)"), c("literals", "literals")),
    f15 = list(c("x > 5", "x > 5"), c("", "")),
    f16 = list(c("x < 5", "x > 3"), c("", "")),
    f17 = list(c("x > a", "x >= a"), c("operators", "operators")),
    f18 = list(c("x == 5", "x != 5"), c("", "")),
    f19 = list(c("x > 5", "y >= 5"), c("", "")))
  files <- lapply(cases, function(cs) j7_gdoc(cs[[1]]))
  names(files) <- paste0(names(cases), ".Rmd")
  # a branch takes part
  files[["f20.Rmd"]] <- c(j7_par("x > 5"), "", "The site [a | b]{if=\"x >= 5\"} on most days.")
  # a warned check takes part
  files[["f21.Rmd"]] <- c(j7_chunk('claim(x, . >= 5, level = "warn")'), "", j7_par("x > 5"))
  # a row that is not readable has no flag
  files[["f22.Rmd"]] <- c(j7_gdoc(c("x > 5", "x >= 5")), "", j7_chunk("claim(x, all(. > 0))"))
  # a group is within one file
  files[["f23a.Rmd"]] <- j7_gdoc("x > 5")
  files[["f23b.Rmd"]] <- j7_gdoc("x >= 5")
  x <- checks(lint_proj(files))
  expected_rows <- sum(vapply(cases, function(cs) length(cs[[1]]), 0L)) + 2L + 2L + 3L + 2L
  expect_identical(nrow(x), expected_rows)
  for (nm in names(cases)) {
    expect_identical(x$flag[x$file == paste0(nm, ".Rmd")], cases[[nm]][[2]], label = nm)
  }
  expect_identical(x$flag[x$file == "f20.Rmd"], c("operators", "operators"))
  expect_identical(x$flag[x$file == "f21.Rmd"], c("operators", "operators"))
  expect_identical(x$flag[x$file == "f22.Rmd"], c("operators", "operators", ""))
  expect_identical(x$flag[x$file %in% c("f23a.Rmd", "f23b.Rmd")], c("", ""))
  expect_length(cases, 19L)
})

# ---- N144, N145: repeated and the hint --------------------------------------------------------------------------------------

test_that("7j N144, N145: repeated, and the hint at repeats = 3 and repeats = 2", {
  three <- j7_gdoc(rep("x > 5", 3))
  two <- j7_gdoc(rep("x > 5", 2))
  root <- lint_proj(list("three.Rmd" = three, "two.Rmd" = two))
  x <- checks(root)
  expect_identical(x$repeated[x$file == "three.Rmd"], rep(3L, 3L))
  expect_identical(x$repeated[x$file == "two.Rmd"], rep(2L, 2L))
  txt <- pr(x)
  # the hint under the line of three, none under the line of two
  i3 <- grep("^three\\.Rmd$", txt)
  i2 <- grep("^two\\.Rmd$", txt)
  expect_length(i3, 1L)
  expect_length(i2, 1L)
  expect_identical(txt[i3 + 3L], paste0("      ", E93(3L)))
  expect_identical(sum(grepl("check it once where the value is made", txt)), 1L)
  expect_false(grepl("check it once", txt[i2 + 3L]))
  # repeats = 2 puts it under both
  txt2 <- pr(checks(root, repeats = 2L))
  expect_identical(sum(grepl("check it once where the value is made", txt2)), 2L)
  expect_true(paste0("      ", E93(2L)) %in% txt2)
  expect_true(paste0("      ", E93(3L)) %in% txt2)
  # a whole number written as a double is accepted
  expect_identical(pr(checks(root, repeats = 2)), txt2)
})

test_that("7j N144: a branch is never counted in repeated, and a level counts apart", {
  doc <- c(j7_gdoc(rep("x > 5", 2)), "", "The site [a | b]{if=\"x > 5\"} on most days.", "",
           j7_chunk('claim(x, . > 5, level = "warn")'))
  x <- checks(lint_proj(list("r.Rmd" = doc)))
  expect_identical(x$role, c("guard", "guard", "branch", "claim"))
  expect_identical(x$level, c("fail", "fail", NA, "warn"))
  expect_identical(x$repeated, c(2L, 2L, NA, 1L))
  # nothing is repeated three times, so no hint
  expect_false(any(grepl("check it once", pr(x))))
})

# ---- N145: the print, byte for byte ---------------------------------------------------------------------------------------

mirror_doc <- function() {
  doc <- rep("", 130L)
  words <- rep(J7_WORDS, length.out = 20L)
  put_guard <- function(line, cond, k) doc[[line]] <<- j7_par(cond, words[[k]])
  for (k in seq_along(ge <- c(12, 20, 31, 40, 52, 70, 88, 97, 105))) put_guard(ge[[k]], "turb_max >= trigger", k)
  put_guard(64, "turb_max > trigger", 10L)
  put_chunk <- function(line, code) {
    doc[[line - 1L]] <<- "```{r}"
    doc[[line]] <<- code
    doc[[line + 1L]] <<- "```"
  }
  for (l in c(8, 44, 90)) put_chunk(l, "claim(n_up, . >= 10)")
  put_chunk(120, "claim(max(turb), . < u(50, NTU))")
  put_chunk(126, "claim(diffs, all(. > 0))")
  doc
}

test_that("7j N145: the print of section 2 I, line for line", {
  root <- lint_proj(list("report.qmd" = mirror_doc()))
  x <- checks(root)
  expect_identical(nrow(x), 15L)
  expect_identical(x$line[x$cond == "turb_max > trigger" & !is.na(x$cond)], 64L)
  want <- c(
    "weft checks: 15 checks of 3 values in 1 document; 1 value flagged",
    "",
    "report.qmd",
    "  n_up",
    "    n_up >= 10              3  lines 8, 44, 90",
    "      checked in 3 places with the same condition: check it once where the value is made",
    "  turb_max  [operators]",
    "    turb_max >= trigger     9  lines 12, 20, 31, 40, 52, 70, 88, 97, 105",
    # the rule of N145 puts the hint under every `check` line of at least `repeats` places, so under these nine
    "      checked in 9 places with the same condition: check it once where the value is made",
    "    turb_max > trigger      1  line 64",
    "  max(turb)",
    "    max(turb) < u(50, NTU)  1  line 120",
    "  not read",
    "    claim(diffs, all(. > 0))  1  line 126",
    "")
  expect_identical(pr(x), want)
})

test_that("7j N145: the print returns its argument invisibly", {
  x <- checks(lint_proj(list("a.Rmd" = j7_gdoc("x > 5"))))
  out <- utils::capture.output(v <- withVisible(print(x)))
  expect_false(v$visible)
  expect_identical(v$value, x)
  expect_gt(length(out), 0L)
})

test_that("7j N145: two values, one flagged, a hint, a warn line, a branch line, a not read block, eleven lines", {
  doc <- c(
    j7_gdoc(c("lvl > 5", "lvl >= 5", "lvl >= 5", "lvl >= 5")), "",                        # lines 1, 3, 5, 7
    "The site [high | low]{if=\"lvl >= 5\"} here.", "",                                   # line 9
    j7_chunk('claim(lvl, . > 5, level = "warn")', "claim(zz, all(. > 0))", "claim(qq, . %in% ok)"), "",   # 11 to 15
    j7_gdoc(rep("depth < 10", 11)))                                                       # lines 17, 19, ..., 37
  expect_identical(doc[[9]], "The site [high | low]{if=\"lvl >= 5\"} here.")
  expect_identical(doc[[12]], 'claim(lvl, . > 5, level = "warn")')
  expect_match(doc[[17]], "depth < 10", fixed = TRUE)
  expect_match(doc[[37]], "depth < 10", fixed = TRUE)
  x <- checks(lint_proj(list("rep.Rmd" = doc)))
  expect_identical(nrow(x), 19L)
  ln <- function(l) sprintf("    %-10s  %2d  %s", l[[1]], l[[2]], l[[3]])
  want <- c(
    "weft checks: 19 checks of 2 values in 1 document; 1 value flagged",
    "",
    "rep.Rmd",
    "  lvl  [operators]",
    ln(list("lvl > 5", 1, "line 1")),
    ln(list("lvl >= 5", 3, "lines 3, 5, 7")),
    paste0("      ", E93(3L)),
    paste0(ln(list("lvl >= 5", 1, "line 9")), "  (branch)"),
    paste0(ln(list("lvl > 5", 1, "line 12")), "  (warn)"),
    "  depth",
    ln(list("depth < 10", 11, "lines 17, 19, 21, 23, 25, 27, 29, 31, 33, 35, and 1 more")),
    paste0("      ", E93(11L)),
    "  not read",
    sprintf("    %-21s  %2d  %s", "claim(zz, all(. > 0))", 1L, "line 13"),
    sprintf("    %-21s  %2d  %s", "claim(qq, . %in% ok)", 1L, "line 14"),
    "")
  expect_identical(pr(x), want)
})

test_that("7j N145: a name assigned twice, and an expression that reads one, are marked in the heading", {
  doc <- j7_chunk("turbidity <- 1", "turbidity <- 2", "x <- 1", "x <- 2",
                  "claim(max(turbidity), . < u(50, NTU))", "claim(x, . > 0)")
  x <- checks(lint_proj(list("c.Rmd" = doc)))
  expect_identical(nrow(x), 2L)
  expect_identical(x$rebound, c(TRUE, TRUE))
  ln <- function(cond, l) sprintf("    %-27s  %d  line %d", cond, 1L, l)
  expect_identical(pr(x), c(
    "weft checks: 2 checks of 2 values in 1 document; 0 values flagged",
    "",
    "c.Rmd",
    "  max(turbidity)  (reads a name assigned in more than one place)",
    ln("max(turbidity) < u(50, NTU)", 6L),
    "  x  (assigned in more than one place)",
    ln("x > 0", 7L),
    ""))
})

test_that("7j N145: no checks prints the second form of E92 alone", {
  root <- lint_proj(list("a.Rmd" = "Just words.", "b.qmd" = "More words."))
  x <- checks(root)
  expect_s3_class(x, "weft_checks")
  expect_identical(nrow(x), 0L)
  expect_identical(names(x), names(checks(lint_proj(list("a.Rmd" = j7_gdoc("x > 5"))))))
  expect_identical(pr(x), "weft checks: no checks in 2 documents")
  expect_identical(pr(checks(lint_proj(list("a.Rmd" = "Just words.")))), "weft checks: no checks in 1 document")
})

# ---- value expressions (N122, N143, N145) ---------------------------------------------------------------------------------

test_that("7j N143: one expression, spelled four ways, is one group, flagged and repeated", {
  doc <- j7_chunk(rep("claim(max(turbidity), . < u(50, NTU))", 3), "claim(max( turbidity ), . <= u(50, NTU))")
  x <- checks(lint_proj(list("e.Rmd" = doc)))
  expect_identical(nrow(x), 4L)
  expect_identical(x$value, rep("max(turbidity)", 4L))
  expect_identical(x$flag, rep("operators", 4L))
  expect_identical(x$repeated, c(3L, 3L, 3L, 1L))
  txt <- pr(x)
  expect_identical(txt[[1]], "weft checks: 4 checks of 1 value in 1 document; 1 value flagged")
  expect_true("  max(turbidity)  [operators]" %in% txt)
  expect_true(paste0("      ", E93(3L)) %in% txt)
  expect_identical(sum(grepl("check it once", txt)), 1L)
})

test_that("7j N143: max(t) and base::max(t) are two groups, not related", {
  doc <- j7_chunk("claim(max(t), . < 5)", "claim(base::max(t), . <= 5)")
  x <- checks(lint_proj(list("e.Rmd" = doc)))
  expect_identical(x$value, c("max(t)", "base::max(t)"))
  expect_identical(x$flag, c("", ""))
  txt <- pr(x)
  expect_true("  max(t)" %in% txt)
  expect_true("  base::max(t)" %in% txt)
  expect_identical(txt[[1]], "weft checks: 2 checks of 2 values in 1 document; 0 values flagged")
})

test_that("7j N145: an expression of 80 characters is cut at 60 in its heading and its line, w taken after cutting", {
  expr <- paste0("max(", strrep("a", 75), ")")
  expect_identical(nchar(expr), 80L)
  doc <- j7_chunk(sprintf("claim(%s, . < 5)", expr))
  x <- checks(lint_proj(list("e.Rmd" = doc)))
  expect_identical(x$value, expr)
  cond <- paste(expr, "< 5")
  expect_identical(nchar(cut60(cond)), 60L)
  expect_identical(pr(x), c(
    "weft checks: 1 check of 1 value in 1 document; 0 values flagged",
    "",
    "e.Rmd",
    paste0("  ", cut60(expr)),
    sprintf("    %-60s  %d  line 2", cut60(cond), 1L),
    ""))
})

# ---- arguments (N141, E91) ------------------------------------------------------------------------------------------------------

test_that("7j E91: repeats is a whole number from 2", {
  root <- lint_proj(list("a.Rmd" = j7_gdoc("x > 5")))
  for (bad in list(1, 2.5, "3", NA, c(3, 4), 1L, 0, -2, NULL)) {
    expect_identical(cclass(checks(root, repeats = bad)), "weft_lint_error", label = deparse(bad))
    expect_identical(cmsg(checks(root, repeats = bad)), "`repeats` must be a whole number from 2.", label = deparse(bad))
  }
  expect_s3_class(checks(root, repeats = 2L), "weft_checks")
  expect_s3_class(checks(root, repeats = 2), "weft_checks")
  expect_s3_class(checks(root, repeats = 10L), "weft_checks")
})

test_that("7j N141: path and files are read as lints() reads them, with its errors", {
  root <- lint_proj(list("a.Rmd" = j7_gdoc("x > 5"), "b.qmd" = j7_gdoc("y > 5"), "notes.md" = "A note."))
  for (call in list(
      quote(list(path = file.path(root, "missing"))),
      quote(list(path = c(root, root))),
      quote(list(path = root, files = "nope.qmd")),
      quote(list(path = root, files = 5)),
      quote(list(path = root, files = "notes.md")),
      quote(list(path = root, files = "../elsewhere.qmd")))) {
    args <- eval(call)
    want <- cmsg(do.call(lints, args))
    expect_false(is.na(want), label = deparse(call))
    expect_identical(cmsg(do.call(checks, args)), want, label = deparse(call))
    expect_identical(cclass(do.call(checks, args)), "weft_lint_error", label = deparse(call))
  }
  # files narrows the report set
  x <- checks(root, files = "b.qmd")
  expect_identical(unique(x$file), "b.qmd")
  expect_identical(nrow(x), 1L)
  x <- checks(root)
  expect_identical(sort(unique(x$file)), c("a.Rmd", "b.qmd"))
  # a path inside the project reports the documents under it
  dir.create(file.path(root, "sub"))
  f3_write(file.path(root, "sub", "c.Rmd"), j7_gdoc("z > 5"))
  expect_identical(unique(checks(file.path(root, "sub"))$file), "sub/c.Rmd")
})

test_that("7j N141: a document that is not valid UTF-8 is skipped with a note", {
  root <- lint_proj(list("ok.Rmd" = j7_gdoc("x > 5"), "bad.Rmd" = as.raw(c(0x41, 0xff, 0xfe, 0x20, 0x0a))))
  x <- checks(root)
  expect_identical(unique(x$file), "ok.Rmd")
  notes <- attr(x, "notes")
  expect_gt(length(notes), 0L)
  expect_true(any(grepl("bad.Rmd", notes, fixed = TRUE)))
})

test_that("7j N141: checks() reads the work tree and runs nothing", {
  root <- lint_proj(list("a.Rmd" = c(j7_chunk("stop('this must not run')", "claim(x, . > 0)"), "", j7_gdoc("x > 5"))))
  x <- checks(root)
  expect_identical(x$cond, c("x > 0", "x > 5"))
  f3_write(file.path(root, "a.Rmd"), j7_gdoc(c("x > 5", "x > 6")))
  expect_identical(checks(root)$cond, c("x > 5", "x > 6"))
})
