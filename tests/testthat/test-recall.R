# Package 3a: recall_check() (rule 9.5.1; contract dev/design-3.md L37-L39, K14).
# The source folders hold invented documents; the only rule that is built in 3a is `construct`,
# so findings are recorded against it ("[1]{.weft-literal}" with no why is a construct error).
# Helpers: helper-3.R.

# a findings table; any column not given is NA
rc_tab <- function(id, quote = NA_character_, file = NA_character_, line = NA_integer_,
                   rule = "construct") {
  n <- length(id)
  data.frame(id = id,
             quote = rep_len(as.character(quote), n),
             file = rep_len(as.character(file), n),
             line = rep_len(as.integer(line), n),
             rule = rep_len(as.character(rule), n),
             stringsAsFactors = FALSE)
}

rc_row <- function(x, rule) as.data.frame(unclass(x), stringsAsFactors = FALSE)[x$rule == rule, , drop = FALSE]

# the source folder of the main examples. Paragraphs at lines 1, 3, 5, 7; constructs at lines 1 and 7.
REC_A <- c(
  "The survey found that the lake was dry in the summer months of the long year [1]{.weft-literal} and then again later.",
  "",
  "A clean sentence about nothing in particular that has no problems at all here.",
  "",
  "Another clean paragraph is here and it also has no constructs of any kind in it.",
  "",
  "Final words with a bad [2]{.weft-literal} construct stuck in the middle of them."
)

rec_main <- function(env = parent.frame()) {
  src <- lint_proj(list("A.qmd" = REC_A), env = env)
  f <- rc_tab(
    id = c("f1", "f2", "f3", "f4", "f5", "f6"),
    quote = c("the lake was dry in the summer months of the long year",
              "A clean sentence about nothing in particular",
              "this text is nowhere in the documents at all",
              NA,
              "Another clean paragraph is here and it also",
              "Final words with a bad"),
    file = c(NA, NA, NA, "A.qmd", NA, NA),
    line = c(NA, NA, NA, 7L, NA, NA),
    rule = c("construct", "construct", "construct", "construct", "", NA)
  )
  list(src = src, f = f)
}

# ---- signature and result shape ---------------------------------------------------------------

test_that("3a L37: recall_check() has the documented arguments and defaults", {
  f <- formals(recall_check)
  expect_identical(names(f), c("findings", "source", "rules", "commit", "window", "nearly"))
  expect_null(f$rules)
  expect_null(f$commit)
  expect_equal(eval(f$window), 2)
  expect_equal(eval(f$nearly), 0.8)
})

test_that("3a L39: the result is a weft_recall data frame, one row per rule and a last row 'any'", {
  m <- rec_main()
  r <- recall_check(m$f, m$src, rules = "construct")
  expect_s3_class(r, "weft_recall")
  expect_s3_class(r, "data.frame")
  expect_identical(names(r), c("rule", "tier", "in_scope", "located", "reproduced", "recall",
                               "flagged", "sentences", "flagged_sentences", "share", "verdict"))
  expect_identical(r$rule, c("construct", "any"))
  expect_equal(r$tier[r$rule == "construct"], 1)
  expect_true(is.character(r$verdict))
  for (nm in c("in_scope", "located", "reproduced", "recall", "flagged", "sentences", "flagged_sentences", "share")) {
    expect_true(is.numeric(r[[nm]]), label = nm)
  }
})

test_that("3a L39: counts for the main example (in_scope, located, reproduced, flagged, sentences, share)", {
  m <- rec_main()
  r <- recall_check(m$f, m$src, rules = "construct")
  c1 <- rc_row(r, "construct")
  # in scope: f1 f2 f3 f4 and f6 (rule NA = every rule); f5 has rule "" and is in `any` only
  expect_equal(c1$in_scope, 5)
  # located: all but f3 (its quote is nowhere)
  expect_equal(c1$located, 4)
  # reproduced: a construct finding starts in the unit of f1 (line 1), f4 (lines 5-9) and f6 (line 7)
  expect_equal(c1$reproduced, 3)
  # the rule found two constructs, in two of the four sentences of the source
  expect_equal(c1$flagged, 2)
  expect_equal(c1$sentences, 4)
  expect_equal(c1$flagged_sentences, 2)
  expect_equal(c1$share, 0.5)
  expect_identical(c1$verdict, "ok")
})

test_that("3a L39: recall is reproduced over located (assumed: the design does not give the formula)", {
  m <- rec_main()
  r <- recall_check(m$f, m$src, rules = "construct")
  c1 <- rc_row(r, "construct")
  expect_equal(c1$recall, c1$reproduced / c1$located)
})

test_that("3a L39: the any row counts every finding, including those with no rule, over all rules together", {
  m <- rec_main()
  r <- recall_check(m$f, m$src, rules = "construct")
  a <- rc_row(r, "any")
  expect_equal(a$in_scope, 6)
  expect_equal(a$located, 5)
  # f5 is located at a sentence with no finding, f2 too
  expect_equal(a$reproduced, 3)
  expect_equal(a$sentences, 4)
  expect_equal(a$flagged_sentences, 2)
  expect_equal(a$share, 0.5)
})

test_that("3a L39: a finding with several rules counts in each; rule NA counts in every rule row", {
  src <- lint_proj(list("A.qmd" = REC_A))
  f <- rc_tab(id = c("a", "b", "c"),
              quote = c("Final words with a bad", "A clean sentence about nothing", "Another clean paragraph is here"),
              rule = c("numeral;construct", NA, "numeral"))
  r <- recall_check(f, src, rules = c("construct", "numeral"))
  expect_identical(r$rule, c("construct", "numeral", "any"))
  expect_equal(rc_row(r, "construct")$in_scope, 2)
  expect_equal(rc_row(r, "numeral")$in_scope, 3)
  expect_equal(rc_row(r, "any")$in_scope, 3)
  # numeral is not built in 3a: it flags nothing, reproduces nothing
  expect_equal(rc_row(r, "numeral")$flagged, 0)
  expect_equal(rc_row(r, "numeral")$reproduced, 0)
})

test_that("3a L39: rules = NULL gives a row for every rule of lint_rules(), then 'any'", {
  m <- rec_main()
  r <- recall_check(m$f, m$src)
  expect_identical(r$rule, c(lint_rules()$id, "any"))
  expect_true("construct" %in% r$rule)
})

test_that("3a L39: attribute matches has id, located, file, line, rules for every finding; unlocated names the rest", {
  m <- rec_main()
  r <- recall_check(m$f, m$src, rules = "construct")
  mt <- attr(r, "matches")
  expect_s3_class(mt, "data.frame")
  expect_true(all(c("id", "located", "file", "line", "rules") %in% names(mt)))
  expect_equal(nrow(mt), 6L)
  expect_identical(mt$located[match(c("f1", "f2", "f3", "f4", "f5", "f6"), mt$id)], c(TRUE, TRUE, FALSE, TRUE, TRUE, TRUE))
  expect_identical(mt$file[mt$id == "f1"], "A.qmd")
  expect_identical(as.integer(mt$line[mt$id == "f1"]), 1L)
  un <- attr(r, "unlocated")
  expect_false(is.null(un))
  ids <- if (is.data.frame(un)) un$id else as.character(un)
  expect_identical(ids, "f3")
})

test_that("3a L39: print() shows the table and the verdicts", {
  m <- rec_main()
  r <- recall_check(m$f, m$src, rules = "construct")
  out <- paste(capture.output(print(r)), collapse = "\n")
  expect_match(out, "construct", fixed = TRUE)
  expect_match(out, "any", fixed = TRUE)
  expect_match(out, "ok", fixed = TRUE)
  vis <- NULL
  capture.output(vis <- withVisible(print(r))$visible)
  expect_false(vis)
  capture.output(y <- print(r))
  expect_identical(y, r)
})

# ---- locating by quote ---------------------------------------------------------------------------

# one sentence with a known normalised text, and a finding in it
SENT <- "Zebra stripes appear on every single animal in the northern reserve during the dry season according to the surveyors who counted them carefully over many weeks [1]{.weft-literal}."
NORM <- tolower(sub(" \\[1\\].*$", "", SENT))

loc_one <- function(quote, files = list("S.qmd" = c(SENT, "", "An unrelated closing paragraph about nothing."))) {
  src <- lint_proj(files)
  f <- rc_tab("q", quote = quote)
  r <- recall_check(f, src, rules = "construct")
  attr(r, "matches")$located[[1]]
}

test_that("3a L38: a quote that is a substring of a sentence is located; one that is nowhere is not", {
  expect_true(loc_one("zebra stripes appear on every single animal in the northern reserve"))
  expect_false(loc_one("quokkas hop across the red desert at night in great numbers"))
})

test_that("3a L38: windows of 40 characters are taken every 20 (a match at offset 20 of 80 locates; at offset 10 of 60 does not)", {
  piece <- substr(NORM, 21, 60)
  expect_equal(nchar(piece), 40L)
  # 20 junk + the piece + 20 junk: the window starting at 20 is the piece
  expect_true(loc_one(paste0(strrep("q", 20), piece, strrep("x", 20))))
  # a window at 60 of a 100-character quote
  expect_true(loc_one(paste0(strrep("q", 60), piece)))
  # 10 junk + the piece + 10 junk: windows 0-39 and 20-59 both hold junk
  expect_false(loc_one(paste0(strrep("q", 10), piece, strrep("x", 10))))
})

test_that("3a L38: a quote shorter than 40 characters is used whole, if it has at least 12", {
  expect_true(loc_one("zebra stripe"))              # 12 characters
  expect_false(loc_one("zebra strip"))              # 11 characters
  expect_true(loc_one(substr(NORM, 7, 31)))          # 25 characters
  expect_false(loc_one(paste0(substr(NORM, 7, 31), "zzzz")))
  expect_true(loc_one(substr(NORM, 1, 40)))          # exactly 40
})

test_that("3a L38: quote and source are normalised alike: case, curly quotes, emphasis, backticks, white space, NFC", {
  doc <- "The \"Lake\" was *very* dry in the Caf\u00e9 area and it stayed dry for a long time [1]{.weft-literal}."
  files <- list("N.qmd" = c(doc, "", "Another paragraph."))
  quotes <- c(
    "The \u201cLake\u201d was very dry in the Caf\u00e9 area and it stayed dry",
    "THE \"LAKE\" WAS VERY DRY IN THE CAF\u00c9 AREA AND IT STAYED DRY",
    "The \"Lake\" was very dry in the Cafe\u0301 area and it stayed dry",
    "The  \"Lake\"  was\nvery   dry in the Caf\u00e9\narea and it stayed dry",
    "The \"Lake\" was **very** dry in the Caf\u00e9 area and it stayed dry",
    "The \"Lake\" was _very_ dry in the Caf\u00e9 area and it stayed dry",
    "The \"Lake\" was `very` dry in the Caf\u00e9 area and it stayed dry"
  )
  src <- lint_proj(files)
  f <- rc_tab(id = paste0("n", seq_along(quotes)), quote = quotes)
  r <- recall_check(f, src, rules = "construct")
  mt <- attr(r, "matches")
  expect_true(all(mt$located), label = paste("located:", paste(mt$id[!mt$located], collapse = ",")))
})

test_that("3a L38: a source with a line break inside the sentence is matched by a quote on one line", {
  files <- list("W.qmd" = c("The lake was dry in the summer months of the long year and then", "again it was dry [1]{.weft-literal}."))
  src <- lint_proj(files)
  f <- rc_tab("w", quote = "the long year and then again it was dry")
  r <- recall_check(f, src, rules = "construct")
  expect_true(attr(r, "matches")$located[[1]])
})

test_that("3a L38: only prose is searched: a quote of code, of a code span or of an attribute block is not located", {
  files <- list("P.qmd" = c("Prose words only here and a construct [1]{.weft-literal} too.", "", "```{r}", "zzchunkcode <- compute_everything(now)", "```"))
  src <- lint_proj(files)
  f <- rc_tab(c("c1", "c2"), quote = c("zzchunkcode <- compute_everything(now)", "{.weft-literal}"))
  r <- recall_check(f, src, rules = "construct")
  expect_false(any(attr(r, "matches")$located))
})

test_that("3a L38: the unit is every sentence a matched window overlaps", {
  files <- list("U.qmd" = c("Alpha beta gamma delta epsilon zeta. Eta theta iota kappa lambda mu [1]{.weft-literal}."))
  src <- lint_proj(files)
  both <- "alpha beta gamma delta epsilon zeta. eta theta iota"
  first_only <- "alpha beta gamma delta epsilon"
  f <- rc_tab(c("both", "first"), quote = c(both, first_only))
  r <- recall_check(f, src, rules = "construct")
  # the finding is in the second sentence: reached from the quote that overlaps it
  mt <- attr(r, "matches")
  expect_true(all(mt$located))
  c1 <- rc_row(r, "construct")
  expect_equal(c1$located, 2)
  expect_equal(c1$reproduced, 1)
})

test_that("3a L38: the finding's files are searched first, but the quote is found in other documents too", {
  src <- lint_proj(list(
    "A.qmd" = c("Prose in A about herons and reeds by the lake shore [1]{.weft-literal}."),
    "B.qmd" = c("Prose in B about herons and reeds by the lake shore [1]{.weft-literal}.")
  ))
  f <- rc_tab("x", quote = "about herons and reeds by the lake shore", file = "B.qmd")
  r <- recall_check(f, src, rules = "construct")
  mt <- attr(r, "matches")
  expect_true(mt$located[[1]])
  expect_identical(mt$file[[1]], "B.qmd")
  # the only copy is in B though the finding names A
  src2 <- lint_proj(list(
    "A.qmd" = c("Nothing relevant here at all."),
    "B.qmd" = c("Prose in B about herons and reeds by the lake shore [1]{.weft-literal}.")
  ))
  f2 <- rc_tab("y", quote = "about herons and reeds by the lake shore", file = "A.qmd")
  r2 <- recall_check(f2, src2, rules = "construct")
  expect_true(attr(r2, "matches")$located[[1]])
  expect_identical(attr(r2, "matches")$file[[1]], "B.qmd")
})

test_that("3a L37: file may hold several paths split on ';', ',' or white space", {
  src <- lint_proj(list(
    "A.qmd" = c("Nothing relevant here at all."),
    "B.qmd" = c("Prose in B about herons and reeds by the lake shore [1]{.weft-literal}.")
  ))
  for (fl in c("A.qmd;B.qmd", "A.qmd,B.qmd", "A.qmd B.qmd", "A.qmd, B.qmd", "A.qmd ; B.qmd")) {
    f <- rc_tab("m", quote = "about herons and reeds by the lake shore", file = fl)
    r <- recall_check(f, src, rules = "construct")
    expect_true(attr(r, "matches")$located[[1]], label = fl)
    expect_identical(attr(r, "matches")$file[[1]], "B.qmd", label = fl)
  }
})

test_that("3a L37: the same findings under .qmd and .Rmd locate and reproduce alike", {
  res <- f3_both(function(ext) {
    src <- lint_proj(stats::setNames(list(REC_A), paste0("A.", ext)))
    f <- rc_tab(c("f1", "f2"), quote = c("the lake was dry in the summer months of the long year",
                                          "A clean sentence about nothing in particular"))
    r <- recall_check(f, src, rules = "construct")
    rc_row(r, "construct")[, c("located", "reproduced")]
  })
  expect_equal(res$qmd, res$Rmd)
  expect_equal(res$qmd$located, 2)
  expect_equal(res$qmd$reproduced, 1)
})

# ---- locating by file and line ----------------------------------------------------------------------

# paragraphs at lines 1, 3, 5, ... 13; the construct is in the paragraph at line 9
line_doc <- function() {
  lines <- character(0)
  for (k in 1:7) {
    lines <- c(lines, if (k == 5) sprintf("Paragraph %s has a construct [1]{.weft-literal} in it.", k) else
      sprintf("Paragraph %s is a plain sentence with nothing wrong.", k), "")
  }
  lines
}

by_line <- function(line, ..., window = 2L) {
  src <- lint_proj(list("B.qmd" = line_doc()))
  f <- rc_tab("l", file = "B.qmd", line = line)
  r <- recall_check(f, src, rules = "construct", window = window, ...)
  list(r = r, c1 = rc_row(r, "construct"))
}

test_that("3a L38: without a quote the sentences on lines line +/- window of file are the unit", {
  expect_equal(by_line(9L)$c1$reproduced, 1)
  expect_equal(by_line(7L)$c1$reproduced, 1)    # lines 5-9 hold the sentence at 9
  expect_equal(by_line(11L)$c1$reproduced, 1)   # lines 9-13
  expect_equal(by_line(5L)$c1$reproduced, 0)    # lines 3-7
  expect_equal(by_line(12L)$c1$reproduced, 0)   # lines 10-14
  for (ln in c(5L, 7L, 9L, 12L)) expect_equal(by_line(ln)$c1$located, 1, label = paste("located at", ln))
})

test_that("3a L37: window sets the half-width in lines", {
  expect_equal(by_line(8L, window = 0L)$c1$reproduced, 0)
  expect_equal(by_line(9L, window = 0L)$c1$reproduced, 1)
  expect_equal(by_line(6L, window = 3L)$c1$reproduced, 1)    # lines 3-9
  expect_equal(by_line(6L, window = 2L)$c1$reproduced, 0)    # lines 4-8
  expect_equal(by_line(3L, window = 6L)$c1$reproduced, 1)
})

test_that("3a L38: a quote wins over file and line when both are given", {
  src <- lint_proj(list("B.qmd" = line_doc()))
  f <- rc_tab("l", quote = "Paragraph 5 has a construct", file = "B.qmd", line = 1L)
  r <- recall_check(f, src, rules = "construct")
  expect_equal(rc_row(r, "construct")$reproduced, 1)
})

test_that("3a L38: a finding with a quote nowhere in the source and no line is unlocated", {
  src <- lint_proj(list("B.qmd" = line_doc()))
  f <- rc_tab("u", quote = "this quote is nowhere in any document here")
  r <- recall_check(f, src, rules = "construct")
  expect_false(attr(r, "matches")$located[[1]])
  expect_equal(rc_row(r, "construct")$located, 0)
})

# ---- verdicts --------------------------------------------------------------------------------------------

# 15 paragraphs; the first `flagged_n` carry a construct error; paragraph k is "Observation about the <word> station was recorded plainly"
WORDS <- c("alpha", "bravo", "charlie", "delta", "echo", "foxtrot", "golf", "hotel", "india", "juliet",
           "kilo", "lima", "mike", "november", "oscar")

verdict_doc <- function(flagged_n) {
  out <- character(0)
  for (k in seq_along(WORDS)) {
    out <- c(out, sprintf("Observation about the %s station was recorded plainly%s.", WORDS[[k]],
                          if (k <= flagged_n) " [1]{.weft-literal}" else ""), "")
  }
  out
}

verdict_of <- function(flagged_n, located_at, ..., rule = "construct") {
  src <- lint_proj(list("V.qmd" = verdict_doc(flagged_n)))
  f <- rc_tab(id = paste0("v", seq_along(located_at)),
              quote = sprintf("Observation about the %s station was", WORDS[located_at]))
  r <- recall_check(f, src, rules = "construct", ...)
  rc_row(r, rule)
}

test_that("3a L39: 'reproduces none' needs located >= 3 and reproduced == 0 (at the threshold)", {
  # 3 located, none reproduced (paragraphs 13-15 have no construct), 5 of 15 flagged
  c1 <- verdict_of(5, 13:15)
  expect_equal(c1$located, 3)
  expect_equal(c1$reproduced, 0)
  expect_identical(c1$verdict, "reproduces none")
  # 2 located: below the threshold
  c2 <- verdict_of(5, 14:15)
  expect_equal(c2$located, 2)
  expect_identical(c2$verdict, "ok")
  # 3 located, one reproduced
  c3 <- verdict_of(5, c(1, 14, 15))
  expect_equal(c3$reproduced, 1)
  expect_identical(c3$verdict, "ok")
  # 4 located, none reproduced
  expect_identical(verdict_of(5, 12:15)$verdict, "reproduces none")
})

test_that("3a L39: 'flags nearly everything' when share >= nearly (0.8 by default, at the threshold)", {
  # 12 of 15 flagged: share 0.8
  c1 <- verdict_of(12, 1L)
  expect_equal(c1$sentences, 15)
  expect_equal(c1$flagged_sentences, 12)
  expect_equal(c1$share, 0.8)
  expect_identical(c1$verdict, "flags nearly everything")
  # 11 of 15: below
  c2 <- verdict_of(11, 1L)
  expect_equal(c2$share, 11 / 15)
  expect_identical(c2$verdict, "ok")
  # 13 of 15: above
  expect_identical(verdict_of(13, 1L)$verdict, "flags nearly everything")
})

test_that("3a L37/L39: nearly moves the threshold", {
  expect_identical(verdict_of(11, 1L, nearly = 0.7)$verdict, "flags nearly everything")
  expect_identical(verdict_of(12, 1L, nearly = 0.9)$verdict, "ok")
  expect_identical(verdict_of(15, 1L, nearly = 1)$verdict, "flags nearly everything")
})

test_that("3a L39: both verdicts are joined by '; '", {
  # 12 flagged; three located findings in the unflagged paragraphs 13-15: none reproduced
  c1 <- verdict_of(12, 13:15)
  expect_equal(c1$share, 0.8)
  expect_identical(c1$verdict, "reproduces none; flags nearly everything")
  # the nearly threshold lifted: reproduces none alone
  expect_identical(verdict_of(12, 13:15, nearly = 0.95)$verdict, "reproduces none")
})

test_that("3a L39: the any row has its own verdict", {
  src <- lint_proj(list("V.qmd" = verdict_doc(5)))
  f <- rc_tab(id = c("a", "b", "c"), quote = sprintf("Observation about the %s station was", WORDS[13:15]), rule = "")
  r <- recall_check(f, src, rules = "construct")
  a <- rc_row(r, "any")
  expect_equal(a$located, 3)
  expect_equal(a$reproduced, 0)
  expect_identical(a$verdict, "reproduces none")
  # the construct row has nothing in scope: nothing located, so ok
  expect_identical(rc_row(r, "construct")$verdict, "ok")
  expect_equal(rc_row(r, "construct")$in_scope, 0)
})

test_that("3a L39: print() shows a verdict that is not ok", {
  src <- lint_proj(list("V.qmd" = verdict_doc(12)))
  f <- rc_tab(id = paste0("v", 1:3), quote = sprintf("Observation about the %s station was", WORDS[13:15]))
  r <- recall_check(f, src, rules = "construct")
  out <- paste(capture.output(print(r)), collapse = "\n")
  expect_match(out, "reproduces none", fixed = TRUE)
  expect_match(out, "flags nearly everything", fixed = TRUE)
})

# ---- commit and source --------------------------------------------------------------------------------------

git_in <- function(repo, ...) {
  system2("git", c("-C", shQuote(repo), "-c", "user.name=tester", "-c", "user.email=tester@example.invalid",
                   "-c", "commit.gpgsign=false", "-c", "init.defaultBranch=main", ...),
          stdout = TRUE, stderr = TRUE)
}

tree_state <- function(dir) {
  fs <- list.files(dir, recursive = TRUE, all.files = TRUE, full.names = TRUE)
  fs <- fs[!grepl("/\\.git/", fs)]
  list(files = sub(paste0("^", dir, "/?"), "", fs), md5 = unname(tools::md5sum(fs)))
}

test_that("3a L37: the source folder is left untouched by a lint", {
  m <- rec_main()
  before <- tree_state(m$src)
  recall_check(m$f, m$src, rules = "construct")
  expect_identical(tree_state(m$src), before)
})

test_that("3a L37: commit lints the archive of that commit, in a temporary folder that is gone afterwards", {
  skip_if(Sys.which("git") == "", "git is not installed")
  repo <- lint_proj(list("A.qmd" = REC_A))
  git_in(repo, "init", "-q")
  git_in(repo, "add", "A.qmd")
  git_in(repo, "commit", "-q", "-m", "first")
  # the working tree then loses both constructs
  f3_write(file.path(repo, "A.qmd"), gsub(" \\[[12]\\]\\{\\.weft-literal\\}", "", REC_A))
  f <- rc_tab("f1", quote = "the lake was dry in the summer months of the long year")

  now <- recall_check(f, repo, rules = "construct")
  expect_equal(rc_row(now, "construct")$reproduced, 0)
  expect_equal(rc_row(now, "construct")$flagged, 0)

  tmp_before <- list.files(tempdir(), all.files = TRUE, no.. = TRUE)
  state_before <- tree_state(repo)
  at <- recall_check(f, repo, rules = "construct", commit = "HEAD")
  expect_equal(rc_row(at, "construct")$reproduced, 1)
  expect_equal(rc_row(at, "construct")$flagged, 2)
  tmp_after <- list.files(tempdir(), all.files = TRUE, no.. = TRUE)
  expect_setequal(tmp_after, tmp_before)
  expect_identical(tree_state(repo), state_before)
})

test_that("3a L37: commit accepts a hash and a branch name", {
  skip_if(Sys.which("git") == "", "git is not installed")
  repo <- lint_proj(list("A.qmd" = REC_A))
  git_in(repo, "init", "-q")
  git_in(repo, "add", "A.qmd")
  git_in(repo, "commit", "-q", "-m", "first")
  hash <- trimws(git_in(repo, "rev-parse", "HEAD")[[1]])
  f <- rc_tab("f1", quote = "the lake was dry in the summer months of the long year")
  r <- recall_check(f, repo, rules = "construct", commit = hash)
  expect_equal(rc_row(r, "construct")$reproduced, 1)
})

# ---- errors (weft_tool_error) --------------------------------------------------------------------------------

test_that("3a L39: a findings table with no id column, or with neither quote nor file and line, is a weft_tool_error", {
  src <- lint_proj(list("A.qmd" = REC_A))
  e <- f2_cond(recall_check(data.frame(quote = "x y z a b c d e f g h i"), src))
  f2_has_class(e, "weft_tool_error")
  e <- f2_cond(recall_check(data.frame(id = "a"), src))
  f2_has_class(e, "weft_tool_error")
  e <- f2_cond(recall_check(data.frame(id = "a", file = "A.qmd"), src))
  f2_has_class(e, "weft_tool_error")
  e <- f2_cond(recall_check(data.frame(id = "a", line = 3L), src))
  f2_has_class(e, "weft_tool_error")
  expect_true(inherits(e, "weft_error"))
})

test_that("3a L39: a line that is not a whole number is a weft_tool_error", {
  src <- lint_proj(list("A.qmd" = REC_A))
  e <- f2_cond(recall_check(data.frame(id = "a", file = "A.qmd", line = 2.5), src))
  f2_has_class(e, "weft_tool_error")
  e <- f2_cond(recall_check(data.frame(id = "a", file = "A.qmd", line = "three"), src))
  f2_has_class(e, "weft_tool_error")
  # a whole number held as a double is fine
  expect_no_error(recall_check(data.frame(id = "a", file = "A.qmd", line = 3), src, rules = "construct"))
})

test_that("3a L39: a source that is not a folder is a weft_tool_error", {
  f <- rc_tab("a", quote = "some quote that is long enough")
  e <- f2_cond(recall_check(f, file.path(tempdir(), "no-such-folder-for-recall")))
  f2_has_class(e, "weft_tool_error")
  one <- withr::local_tempfile(fileext = ".qmd")
  writeLines("x", one)
  e <- f2_cond(recall_check(f, one))
  f2_has_class(e, "weft_tool_error")
})

test_that("3a L39: an unknown commit is a weft_tool_error", {
  skip_if(Sys.which("git") == "", "git is not installed")
  repo <- lint_proj(list("A.qmd" = REC_A))
  git_in(repo, "init", "-q")
  git_in(repo, "add", "A.qmd")
  git_in(repo, "commit", "-q", "-m", "first")
  f <- rc_tab("a", quote = "the lake was dry in the summer months")
  tmp_before <- list.files(tempdir(), all.files = TRUE, no.. = TRUE)
  e <- f2_cond(recall_check(f, repo, commit = "deadbeefdeadbeef"))
  f2_has_class(e, "weft_tool_error")
  expect_setequal(list.files(tempdir(), all.files = TRUE, no.. = TRUE), tmp_before)
})

test_that("3a L39: git absent with a commit given is a weft_tool_error", {
  src <- lint_proj(list("A.qmd" = REC_A))
  empty <- withr::local_tempdir()
  withr::local_envvar(PATH = empty)
  f <- rc_tab("a", quote = "the lake was dry in the summer months")
  e <- f2_cond(recall_check(f, src, commit = "HEAD"))
  f2_has_class(e, "weft_tool_error")
})

test_that("3a L37: a commit on a source that is not a git repository is a weft_tool_error", {
  skip_if(Sys.which("git") == "", "git is not installed")
  src <- lint_proj(list("A.qmd" = REC_A))
  f <- rc_tab("a", quote = "the lake was dry in the summer months")
  e <- f2_cond(recall_check(f, src, commit = "HEAD"))
  f2_has_class(e, "weft_tool_error")
})

test_that("3a L37: an unknown rule id is an error (from lints())", {
  m <- rec_main()
  e <- f2_cond(recall_check(m$f, m$src, rules = "construtc"))
  f2_has_class(e, "weft_lint_error")
})
