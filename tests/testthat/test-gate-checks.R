# Package 7j: the gate's lines on checks (dev/design-7.md section 2 I, N132 to N140, N149 to N151; messages E80
# to E90). Git scenarios through g_scenario() and g_gate() of helper-4a.R. Many documents share a scenario: the
# keys of N133 are counted over the project, so each document uses names of its own. Information only (D36):
# the verdict, n_removed and the trailer wanted are those of the construct count.

gc_cols <- c("project", "file", "line", "cond", "level", "verdict", "by", "by_line", "remains")

gc_row <- function(res, file, line = NULL) {
  r <- res$checks[res$checks$file == file, , drop = FALSE]
  if (!is.null(line)) r <- r[r$line == line, , drop = FALSE]
  r
}

# ---- the documents of the verdict scenario ---------------------------------------------------------------

gc_before <- function() {
  list(
    # the owner's case: nine `>` and one `>=` (paragraph 4)
    "g01.Rmd" = j7_gdoc(sprintf("foo %s bar", c(">", ">", ">", ">=", rep(">", 6)))),
    # the mirror: nine `>=` and one `>` (paragraph 5)
    "g02.Rmd" = j7_gdoc(sprintf("baz %s qux", c(rep(">=", 4), ">", rep(">=", 5)))),
    # ten identical guards
    "g03.Rmd" = j7_gdoc(rep("s1 > t1", 10)),
    # a check of a pair nothing else in the document checks
    "g04.Rmd" = j7_gdoc(c("n1 > 1", "n2 > 3")),
    # a warned claim that implies the guard
    "g05.Rmd" = c(j7_chunk('claim(w1, . > 5, level = "warn")'), "", j7_par("w1 > 3")),
    # a name assigned twice
    "g06.Rmd" = c(j7_chunk("w2 <- 1", "w2 <- 2"), "", j7_par("w2 > 3", "amber"), "", j7_par("w2 > 3", "bravo")),
    # a claim that is not readable, alone
    "g07.Rmd" = c(j7_chunk("claim(u1, all(. > 0))"), "", j7_par("k7 > 1")),
    # a claim that is not readable, twice (a note line tells the two apart)
    "g08.Rmd" = j7_chunk("claim(u2, all(. > 0))", "# first note", "claim(u2, all(. > 0))", "# second note"),
    # a document that is deleted
    "g09.Rmd" = j7_gdoc(c("dd1 > 1", "dd2 > 1", "dd3 > 1")),
    # a guard moved to the other document, a guard rewritten as a claim, the prose around a guard edited
    "g10a.Rmd" = j7_gdoc("mv1 > 1"),
    "g10b.Rmd" = "Nothing here yet.",
    "g11.Rmd" = j7_gdoc("rw1 > 1"),
    "g12.Rmd" = j7_gdoc("ed1 > 1"),
    # three identical guards
    "g13.Rmd" = j7_gdoc(rep("id1 > 1", 3))
  )
}

gc_after <- function() {
  list(
    "g01.Rmd" = j7_gdoc(rep("foo > bar", 9), ids = c(1:3, 5:10)),
    "g02.Rmd" = j7_gdoc(rep("baz >= qux", 9), ids = c(1:4, 6:10)),
    "g03.Rmd" = j7_gdoc(rep("s1 > t1", 9), ids = c(1:3, 5:10)),
    "g04.Rmd" = j7_gdoc("n1 > 1"),
    "g05.Rmd" = j7_chunk('claim(w1, . > 5, level = "warn")'),
    "g06.Rmd" = c(j7_chunk("w2 <- 1", "w2 <- 2"), "", j7_par("w2 > 3", "amber")),
    "g07.Rmd" = j7_par("k7 > 1"),
    "g08.Rmd" = j7_chunk("claim(u2, all(. > 0))", "# first note"),
    "g09.Rmd" = NULL,
    "g10a.Rmd" = "Nothing here now.",
    "g10b.Rmd" = j7_gdoc("mv1 > 1"),
    "g11.Rmd" = j7_chunk("claim(rw1, . > 1)", label = "rewritten"),
    "g12.Rmd" = j7_gdoc("ed1 > 1", word = "went past the limit"),
    "g13.Rmd" = j7_gdoc(rep("id1 > 1", 2), ids = c(1L, 3L))
  )
}

gc_scenario <- function(env = parent.frame()) g_scenario(gc_before(), gc_after(), env = env)

# ---- the verdicts, the table of the result and the printed block ------------------------------------------------

test_that("7j N133 to N140: each verdict, the rows of res$checks, and the block of E80 line for line", {
  d <- gc_scenario()
  res <- g_gate(d)
  ck <- res$checks
  expect_s3_class(ck, "data.frame")
  expect_identical(names(ck), gc_cols)
  expect_type(ck$project, "character")
  expect_type(ck$file, "character")
  expect_type(ck$line, "integer")
  expect_type(ck$cond, "character")
  expect_type(ck$level, "character")
  expect_type(ck$verdict, "character")
  expect_type(ck$by, "character")
  expect_type(ck$by_line, "integer")
  expect_type(ck$remains, "character")
  expect_identical(nrow(ck), 12L)
  # sorted by project, file and line
  expect_identical(order(ck$project, ck$file, ck$line), seq_len(nrow(ck)))

  # g01: the owner's case. The `>=` guard (paragraph 4, line 7) is implied by `foo > bar` (first at line 1)
  r <- gc_row(res, "g01.Rmd")
  expect_identical(nrow(r), 1L)
  expect_identical(r$line, j7_gline(4L))
  expect_identical(r$cond, "foo >= bar")
  expect_identical(r$level, "fail")
  expect_identical(r$verdict, "implied")
  expect_identical(r$by, "foo > bar")
  expect_identical(r$by_line, 1L)
  expect_true(is.na(r$remains))

  # g02: the mirror. The `>` guard (paragraph 5, line 9): looser, nine `>=` remain
  r <- gc_row(res, "g02.Rmd")
  expect_identical(nrow(r), 1L)
  expect_identical(r$line, j7_gline(5L))
  expect_identical(r$cond, "baz > qux")
  expect_identical(r$verdict, "looser")
  expect_true(is.na(r$by) && is.na(r$by_line))
  expect_identical(r$remains, "`baz >= qux` (9 places)")

  # g03: one of ten identical. The row listed is the one on the deleted line (paragraph 4), not the last (N134)
  r <- gc_row(res, "g03.Rmd")
  expect_identical(nrow(r), 1L)
  expect_identical(r$line, j7_gline(4L))
  expect_identical(r$verdict, "same")
  expect_identical(r$by, "s1 > t1")
  expect_identical(r$by_line, 1L)

  # g04: no check of that pair remains
  r <- gc_row(res, "g04.Rmd")
  expect_identical(r$line, j7_gline(2L))
  expect_identical(r$cond, "n2 > 3")
  expect_identical(r$verdict, "none")
  expect_true(is.na(r$by) && is.na(r$remains))

  # g05: only a warned check implies it
  r <- gc_row(res, "g05.Rmd")
  expect_identical(r$line, 5L)
  expect_identical(r$cond, "w1 > 3")
  expect_identical(r$verdict, "warned")

  # g06: the name is assigned twice
  r <- gc_row(res, "g06.Rmd")
  expect_identical(r$line, 8L)
  expect_identical(r$verdict, "rebound")

  # g07: not readable, nothing like it remains
  r <- gc_row(res, "g07.Rmd")
  expect_identical(r$line, 2L)
  expect_identical(r$cond, "claim(u1, all(. > 0))")
  expect_identical(r$verdict, "unread")

  # g08: not readable, the same text remains elsewhere in the document
  r <- gc_row(res, "g08.Rmd")
  expect_identical(r$line, 4L)
  expect_identical(r$cond, "claim(u2, all(. > 0))")
  expect_identical(r$verdict, "same")
  expect_identical(r$by_line, 2L)

  # g09: a deleted document, three rows
  r <- gc_row(res, "g09.Rmd")
  expect_identical(nrow(r), 3L)
  expect_identical(r$verdict, rep("deleted", 3L))
  expect_identical(r$line, j7_gline(1:3))

  # g13: one of three identical, the middle one
  r <- gc_row(res, "g13.Rmd")
  expect_identical(r$line, j7_gline(2L))
  expect_identical(r$verdict, "same")

  # a guard moved to another document, rewritten as a claim, the prose around it edited: nothing is gone
  expect_false(any(res$checks$file %in% c("g10a.Rmd", "g10b.Rmd", "g11.Rmd", "g12.Rmd")))

  # the printed block: E80, then per file in path order (N137)
  rep <- g_report(res)
  want <- c(
    paste("commit-msg: 12 checks gone since HEAD", J7_E80),
    j7_file_lines("g01.Rmd", list(list(line = 7, shown = "foo >= bar",
      verdict = "covered: `foo > bar` at line 1 implies it"))),
    j7_file_lines("g02.Rmd", list(list(line = 9, shown = "baz > qux",
      verdict = "looser: nothing that remains implies it; remaining on baz against qux: `baz >= qux` (9 places)"))),
    j7_file_lines("g03.Rmd", list(list(line = 7, shown = "s1 > t1",
      verdict = "covered: the same check remains, at line 1 and 8 other places"))),
    j7_file_lines("g04.Rmd", list(list(line = 3, shown = "n2 > 3",
      verdict = "looser: no check of n2 against a number remains in g04.Rmd"))),
    j7_file_lines("g05.Rmd", list(list(line = 5, shown = "w1 > 3",
      verdict = "looser: only a warned check implies it, `w1 > 5` at line 2, and a warned check fails nothing"))),
    j7_file_lines("g06.Rmd", list(list(line = 8, shown = "w2 > 3",
      verdict = "not judged: `w2` is assigned in more than one place in g06.Rmd, so no other check is taken to cover this one"))),
    j7_file_lines("g07.Rmd", list(list(line = 2, shown = "claim(u1, all(. > 0))", verdict = J7_E88))),
    j7_file_lines("g08.Rmd", list(list(line = 4, shown = "claim(u2, all(. > 0))",
      verdict = "covered: the same check remains, at line 2"))),
    c("  g09.Rmd, as in HEAD", "    the document is gone, and its 3 checks with it", ""),
    j7_file_lines("g13.Rmd", list(list(line = 3, shown = "id1 > 1",
      verdict = "covered: the same check remains, at line 1 and 1 other place"))))
  expect_identical(j7_block(rep), want)

  # the block comes after the block of constructs removed and before the time line
  i_rm <- grep("weft constructs? removed, and the message does not say so", rep)
  i_e80 <- grep("checks gone since HEAD", rep)
  expect_length(i_rm, 1L)
  expect_gt(i_e80, i_rm)
  expect_match(rep[[length(rep)]], "^commit-msg: T s$")
})

# ---- information only (N139, D36) ----------------------------------------------------------------------------

test_that("7j N139: no verdict changes ok, n_removed or the trailer wanted", {
  d <- gc_scenario()
  res <- g_gate(d)
  expect_false(res$ok)
  expect_true(is.na(res$trailer))
  # the construct count of the scenario: 11 values and spans net of the moved guard, 1 claim net of the rewrite
  expect_identical(res$n_removed, 12L)
  expect_true(any(grepl("^commit-msg: 12 weft constructs removed, and the message does not say so$", g_report(res))))
  expect_identical(nrow(res$checks), 12L)
  # the right trailer passes, whatever the verdicts; the pass prints a note for each looser, unjudged, warned
  # or uncovered check (file and line order) and nothing for the rest (N138)
  res2 <- g_gate(d, c("Drop checks", "", "Weft-Removed: 12"))
  expect_true(res2$ok)
  expect_identical(res2$n_removed, 12L)
  expect_identical(res2$trailer, 12L)
  rep <- g_report(res2)
  expect_identical(rep[grepl("is gone and nothing that remains covers it", rep)], c(
    "commit-msg: note: g02.Rmd:9 in HEAD, `baz > qux`, is gone and nothing that remains covers it (rule 6.3.7)",
    "commit-msg: note: g04.Rmd:3 in HEAD, `n2 > 3`, is gone and nothing that remains covers it (rule 6.3.7)",
    "commit-msg: note: g05.Rmd:5 in HEAD, `w1 > 3`, is gone and nothing that remains covers it (rule 6.3.7)",
    "commit-msg: note: g06.Rmd:8 in HEAD, `w2 > 3`, is gone and nothing that remains covers it (rule 6.3.7)"))
  expect_false(any(grepl("more checks? gone", rep)))
  expect_length(j7_block(rep), 0L)
  expect_match(rep[[length(rep)]], "^commit-msg: weft passed \\(")
  # the same rows in the result
  expect_identical(res2$checks, res$checks)
})

test_that("7j N137: one check gone is '1 check'", {
  d <- g_scenario(list("s1.Rmd" = j7_gdoc(c("a1 > 1", "a2 > 1"))), list("s1.Rmd" = j7_gdoc("a1 > 1")))
  res <- g_gate(d)
  expect_false(res$ok)
  expect_identical(j7_block(g_report(res)), c(
    paste("commit-msg: 1 check gone since HEAD", J7_E80),
    j7_file_lines("s1.Rmd", list(list(line = 3, shown = "a2 > 1",
      verdict = "looser: no check of a2 against a number remains in s1.Rmd"))),
    NULL))
  expect_identical(res$checks$verdict, "none")
})

# ---- a pass: notes (N138) ------------------------------------------------------------------------------------

test_that("7j N133, N138: a bound edited with no construct removed passes with one note; a stricter bound with none", {
  d <- g_scenario(list("p1.Rmd" = j7_gdoc("x >= 5"), "p2.Rmd" = j7_gdoc("y >= 5")),
                  list("p1.Rmd" = j7_gdoc("x > 3"), "p2.Rmd" = j7_gdoc("y > 7")))
  res <- g_gate(d)
  expect_true(res$ok)
  expect_identical(res$n_removed, 0L)
  expect_identical(g_report(res), c(
    "commit-msg: note: p1.Rmd:1 in HEAD, `x >= 5`, is gone and nothing that remains covers it (rule 6.3.7)",
    "commit-msg: weft passed (2 changed files, T s)"))
  ck <- res$checks
  expect_identical(ck$file, c("p1.Rmd", "p2.Rmd"))
  expect_identical(ck$cond, c("x >= 5", "y >= 5"))
  expect_identical(ck$verdict, c("looser", "implied"))
  expect_identical(ck$by, c(NA, "y > 7"))
  expect_identical(ck$by_line, c(NA, 1L))
})

test_that("7j N138: six looser checks on a pass print five notes and then E90", {
  names6 <- paste0("a", 1:6)
  d <- g_scenario(list("p3.Rmd" = j7_gdoc(paste(names6, ">= 5"))), list("p3.Rmd" = j7_gdoc(paste(names6, "> 3"))))
  res <- g_gate(d)
  expect_true(res$ok)
  expect_identical(nrow(res$checks), 6L)
  expect_identical(res$checks$verdict, rep("looser", 6L))
  rep <- g_report(res)
  expect_identical(rep[-length(rep)], c(
    sprintf("commit-msg: note: p3.Rmd:%d in HEAD, `%s >= 5`, is gone and nothing that remains covers it (rule 6.3.7)",
            j7_gline(1:5), names6[1:5]),
    "commit-msg: note: and 1 more check gone with nothing that remains covering it; gate() lists them in `checks`"))
  expect_match(rep[[length(rep)]], "^commit-msg: weft passed \\(1 changed file, T s\\)$")
})

test_that("7j N133: a bound edited to a stricter one is not gone-and-uncovered; the verdict is 'implied'", {
  # control for the note above: only the weaker edit is reported, `x > 7` covers `x >= 5`
  d <- g_scenario(list("p4.Rmd" = j7_gdoc("x >= 5")), list("p4.Rmd" = j7_gdoc("x > 7")))
  res <- g_gate(d)
  expect_true(res$ok)
  expect_identical(g_report(res), "commit-msg: weft passed (1 changed file, T s)")
  expect_identical(res$checks$verdict, "implied")
})

# ---- the first commit, the cache ---------------------------------------------------------------------------------

test_that("7j N140: on a first commit res$checks has the columns and no rows", {
  d <- g_repo(list("ch1.Rmd" = j7_gdoc(c("x > 5", "x >= 5"))), commit = FALSE)
  res <- g_gate(d)
  expect_true(res$ok)
  expect_s3_class(res$checks, "data.frame")
  expect_identical(names(res$checks), gc_cols)
  expect_identical(nrow(res$checks), 0L)
})

test_that("7j N132: the cache entry holds the checks, and a warm run, a cold run and no cache give the same rows", {
  withr::local_options(weft.gate_cache = TRUE)
  d <- gc_scenario()
  n_cold <- g_count_reads(cold <- g_gate(d))
  n_warm <- g_count_reads(warm <- g_gate(d))
  expect_gt(n_cold, 0L)
  expect_identical(n_warm, 0L)
  expect_identical(nrow(cold$checks), 12L)
  expect_identical(warm$checks, cold$checks)
  expect_identical(g_report(warm), g_report(cold))
  files <- g_cache_files(d)
  entries <- lapply(files[grepl("/file-", files)], function(f) readRDS(f)$value)
  expect_gt(length(entries), 0L)
  expect_true(any(vapply(entries, function(e) is.list(e) && !is.null(e$checks), NA)))
  off <- withr::with_options(c(weft.gate_cache = FALSE), g_gate(d))
  expect_identical(off$checks, cold$checks)
})

# ---- expressions (N149 to N151) -----------------------------------------------------------------------------------

gx_claim <- function(arg, v = "max(turbidity)") sprintf("claim(%s, %s)", v, arg)

gx_before <- function() {
  c50 <- function(v) gx_claim(". < u(50, NTU)", v)
  list(
    # one of three identical claims
    "x01.Rmd" = j7_cdoc(rep(c50("max(ta)"), 3)),
    # the stricter claim goes, two looser remain
    "x02.Rmd" = j7_cdoc(c(c50("max(tb)"), c50("max(tb)"), gx_claim(". < u(40, NTU)", "max(tb)"))),
    # the non-strict one goes, the strict one remains
    "x03.Rmd" = j7_cdoc(c(gx_claim(". <= u(50, NTU)", "max(tc)"), c50("max(tc)"))),
    # respaced and piped, nothing gone
    "x04.Rmd" = j7_cdoc(c(c50("max(td)"), gx_claim(". < u(40, NTU)", "max(td)"))),
    # rewritten with a package prefix: gone, and nothing else on max(te)
    "x05.Rmd" = j7_cdoc(c50("max(te)")),
    # a name assigned twice
    "x06.Rmd" = c(j7_chunk("tf <- 1", "tf <- 2"), "", j7_cdoc(c(c50("max(tf)"), c50("max(tf)")))),
    # a claim that draws random numbers
    "x07.Rmd" = j7_cdoc(c("claim(runif(n), . < 0.5)", c50("max(tg)")))
  )
}

gx_after <- function() {
  c50 <- function(v) gx_claim(". < u(50, NTU)", v)
  list(
    "x01.Rmd" = j7_cdoc(rep(c50("max(ta)"), 2), ids = c(1L, 3L)),
    "x02.Rmd" = j7_cdoc(c(c50("max(tb)"), c50("max(tb)"))),
    "x03.Rmd" = j7_cdoc(c50("max(tc)"), ids = 2L),
    "x04.Rmd" = j7_cdoc(c(gx_claim(". < u(50, NTU)", "max( td )"),
                          "td |> max() |> claim(. < u(40, NTU))")),
    "x05.Rmd" = j7_cdoc(c50("base::max(te)")),
    "x06.Rmd" = c(j7_chunk("tf <- 1", "tf <- 2"), "", j7_cdoc(c50("max(tf)"))),
    "x07.Rmd" = j7_cdoc(c50("max(tg)"), ids = 2L)
  )
}

test_that("7j N149 to N151: value expressions in the gate, each verdict and the block line for line", {
  d <- g_scenario(gx_before(), gx_after())
  res <- g_gate(d)
  ck <- res$checks
  expect_identical(nrow(ck), 6L)
  # x04: respacing and the native pipe change nothing
  expect_false("x04.Rmd" %in% ck$file)

  r <- gc_row(res, "x01.Rmd")
  expect_identical(r$line, j7_gline(2L))
  expect_identical(r$verdict, "same")
  expect_identical(r$cond, "max(ta) < u(50, NTU)")

  r <- gc_row(res, "x02.Rmd")
  expect_identical(r$line, j7_gline(3L))
  expect_identical(r$cond, "max(tb) < u(40, NTU)")
  expect_identical(r$verdict, "looser")
  expect_identical(r$remains, "`max(tb) < u(50, NTU)` (2 places)")

  r <- gc_row(res, "x03.Rmd")
  expect_identical(r$line, j7_gline(1L))
  expect_identical(r$cond, "max(tc) <= u(50, NTU)")
  expect_identical(r$verdict, "implied")
  expect_identical(r$by, "max(tc) < u(50, NTU)")
  expect_identical(r$by_line, 1L)

  r <- gc_row(res, "x05.Rmd")
  expect_identical(r$cond, "max(te) < u(50, NTU)")
  expect_identical(r$verdict, "none")

  r <- gc_row(res, "x06.Rmd")
  expect_identical(r$line, 8L)
  expect_identical(r$verdict, "rebound")

  r <- gc_row(res, "x07.Rmd")
  expect_identical(r$line, 1L)
  expect_identical(r$cond, "claim(runif(n), . < 0.5)")
  expect_identical(r$verdict, "unread")

  rep <- g_report(res)
  want <- c(
    paste("commit-msg: 6 checks gone since HEAD", J7_E80),
    j7_file_lines("x01.Rmd", list(list(line = 3, shown = "max(ta) < u(50, NTU)",
      verdict = "covered: the same check remains, at line 1 and 1 other place"))),
    j7_file_lines("x02.Rmd", list(list(line = 5, shown = "max(tb) < u(40, NTU)",
      verdict = "looser: nothing that remains implies it; remaining on max(tb) against a quantity in NTU: `max(tb) < u(50, NTU)` (2 places)"))),
    j7_file_lines("x03.Rmd", list(list(line = 1, shown = "max(tc) <= u(50, NTU)",
      verdict = "covered: `max(tc) < u(50, NTU)` at line 1 implies it"))),
    j7_file_lines("x05.Rmd", list(list(line = 1, shown = "max(te) < u(50, NTU)",
      verdict = "looser: no check of max(te) against a quantity in NTU remains in x05.Rmd"))),
    j7_file_lines("x06.Rmd", list(list(line = 8, shown = "max(tf) < u(50, NTU)",
      verdict = "not judged: `tf` is assigned in more than one place in x06.Rmd, so no other check is taken to cover this one"))),
    j7_file_lines("x07.Rmd", list(list(line = 1, shown = "claim(runif(n), . < 0.5)", verdict = J7_E88))))
  expect_identical(j7_block(rep), want)
})

# ---- the control: F9 changes no verdict, count or trailer on any scripted edit (N139) ------------------------------------

gk <- new.env(parent = globalenv())
sys.source(test_path("_gate", "manuscript.R"), envir = gk)
sys.source(test_path("_gate", "edits.R"), envir = gk)

test_that("7j N139: the scripted edits are all there, 72 and the extra", {
  expect_length(gk$EDITS, 73L)
  expect_true(all(sprintf("E%02d", 1:71) %in% names(gk$EDITS)))
})

for (id in names(gk$EDITS)) local({
  id <- id
  e <- gk$EDITS[[id]]
  test_that(paste0("7j N139 ", id, ": ok, n_removed and the trailer wanted are the construct count's; res$checks is there"), {
    skip_if_no_git()
    before <- c(gk$render_doc(gk$D0, 72), G_ENGINE)
    after <- c(gk$render_doc(e$f(gk$D0), e$width, e$hash_safe), G_ENGINE)
    d <- g_scenario(list("ch1.qmd" = before), list("ch1.qmd" = after))
    res <- g_gate(d)
    expect_s3_class(res$checks, "data.frame")
    expect_identical(names(res$checks), gc_cols)
    if (identical(id, "E16b")) {
      expect_false(res$ok)
      return(invisible())
    }
    n <- gk$EXPECT[[id]]$n
    expect_identical(res$n_removed, n)
    if (n > 0L) {
      expect_false(res$ok)
      expect_true(is.na(res$trailer))
    } else {
      expect_identical(res$ok, is.null(e$finding))
    }
    # a full report that has gone checks says how many, in E80
    if (nrow(res$checks) && !res$ok) {
      expect_true(any(grepl(sprintf("^commit-msg: %d checks? gone since HEAD", nrow(res$checks)), g_report(res))))
    }
  })
})
