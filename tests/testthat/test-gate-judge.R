# Package 4a: judging (dev/design-4.md G9, G10, G16, G18, G20; decisions H3, H4, H5, H16).
# Fixtures use rule `construct` (3a) and `numeral` (3b). Tests marked [3b] / [3d] need that package's rule.

# the design's verdict for each shared case (these cases are also the parity cases of test-gate-cache.R)
test_that("4a G9, G10: the shared cases give their verdicts", {
  for (cs in g_cases()) {
    d <- cs$build(environment())
    res <- g_gate(d, cs$msg)
    expect_identical(res$ok, cs$ok, label = cs$name)
  }
})

# ---- G9: construct errors ---------------------------------------------------------------------------------

test_that("4a G9: a construct error on the new side of a changed document fails, listed in errors", {
  d <- g_scenario(list("ch1.qmd" = G_PROSE), list("ch1.qmd" = g_bad_doc()))
  res <- g_gate(d)
  expect_false(res$ok)
  expect_s3_class(res$errors, "weft_findings")
  expect_identical(nrow(res$errors), 1L)
  expect_identical(res$errors$rule, "construct")
  expect_identical(res$errors$line, 3L)
  expect_match(res$errors$file, "ch1\\.qmd$")
  expect_match(res$errors$text, "a site", fixed = TRUE)
})

test_that("4a G9: a construct error HEAD already held still fails when its document is changed", {
  d <- g_scenario(list("ch1.qmd" = g_bad_doc()), list("ch1.qmd" = c(g_bad_doc(), "", "Edited.")))
  res <- g_gate(d)
  expect_false(res$ok)
  expect_identical(nrow(res$errors), 1L)
})

test_that("4a G9: a construct error in a document the commit does not change is not counted", {
  d <- g_scenario(list("ch1.qmd" = g_bad_doc(), "ch2.qmd" = G_PROSE), list("ch2.qmd" = c(G_PROSE, "", "Edited.")))
  res <- g_gate(d)
  expect_true(res$ok)
  expect_identical(nrow(res$errors), 0L)
})

test_that("4a G9: a construct error in a deleted document is not counted", {
  d <- g_scenario(list("ch1.qmd" = g_bad_doc(), "ch2.qmd" = G_PROSE), list("ch1.qmd" = NULL))
  expect_true(g_gate(d)$ok)
})

test_that("4a H4: a file that is not UTF-8 (rule read) is a construct error", {
  d <- g_scenario(list("ch1.qmd" = G_PROSE),
                  list("ch1.qmd" = c(charToRaw("Caf"), as.raw(0xE9), charToRaw(" by the river.\n"))))
  res <- g_gate(d)
  expect_false(res$ok)
  expect_true("read" %in% res$errors$rule)
})

test_that("4a H4 [3b]: a span cut by a re-wrap (rule block-start) is a construct error", {
  d <- g_scenario(list("ch1.qmd" = c("Sites: [a site | # sites]{n=\"n_sites\"} here.")),
                  list("ch1.qmd" = c("Sites: [a site |", "```", "code", "```", "b]{n=\"n_sites\"} here.")))
  res <- g_gate(d)
  expect_false(res$ok)
  expect_true("block-start" %in% res$errors$rule)
})

# ---- G10: findings added ---------------------------------------------------------------------------------------

test_that("4a G10: a new numeral fails; excess holds the key with its counts; added holds the instance", {
  d <- g_scenario(list("ch1.qmd" = G_PROSE), list("ch1.qmd" = g_num_doc("45%")))
  res <- g_gate(d)
  expect_false(res$ok)
  expect_identical(nrow(res$excess), 1L)
  expect_identical(res$excess$rule, "numeral")
  expect_identical(res$excess$text, "45%")
  expect_identical(as.integer(res$excess$base), 0L)
  expect_identical(as.integer(res$excess$new), 1L)
  expect_identical(nrow(res$added), 1L)
  expect_identical(res$added$rule, "numeral")
  expect_identical(res$added$line, 3L)
  expect_identical(nrow(res$errors), 0L)
})

test_that("4a G10: a finding already at HEAD is not new (its document may change)", {
  d <- g_scenario(list("ch1.qmd" = g_num_doc("45%")), list("ch1.qmd" = c(g_num_doc("45%"), "", "Edited.")))
  res <- g_gate(d)
  expect_true(res$ok)
  expect_identical(nrow(res$excess), 0L)
  expect_identical(nrow(res$added), 0L)
})

test_that("4a G10: a finding moved within its file (paragraphs reordered) is not new", {
  d <- g_scenario(list("ch1.qmd" = g_num_doc(c("45%", "37%"))), list("ch1.qmd" = g_num_doc(c("37%", "45%"))))
  expect_true(g_gate(d)$ok)
})

test_that("4a G10: a finding moved to another file is not new", {
  d <- g_scenario(list("ch1.qmd" = g_num_doc("45%"), "ch2.qmd" = G_PROSE),
                  list("ch1.qmd" = G_PROSE, "ch2.qmd" = g_num_doc("45%")))
  expect_true(g_gate(d)$ok)
})

test_that("4a G10: renaming a file does not make its findings new", {
  d <- g_scenario(list("ch1.qmd" = g_num_doc("45%")), list("ch1.qmd" = NULL, "intro.qmd" = g_num_doc("45%")))
  res <- g_gate(d)
  expect_true(res$ok)
  expect_identical(nrow(res$excess), 0L)
})

test_that("4a G10: a finding removed passes", {
  d <- g_scenario(list("ch1.qmd" = g_num_doc(c("45%", "37%"))), list("ch1.qmd" = g_num_doc("45%")))
  expect_true(g_gate(d)$ok)
})

test_that("4a G10: the same text twice where once was there before fails; only the added line is listed", {
  d <- g_scenario(list("ch1.qmd" = g_num_doc("45%")), list("ch1.qmd" = g_num_doc(c("45%", "45%"))))
  res <- g_gate(d)
  expect_false(res$ok)
  expect_identical(nrow(res$excess), 1L)
  expect_identical(as.integer(res$excess$base), 1L)
  expect_identical(as.integer(res$excess$new), 2L)
  expect_identical(nrow(res$added), 1L)
  expect_identical(res$added$line, 5L)          # the paragraph added since HEAD, not the one on line 3
})

test_that("4a G10: a different text is a different key", {
  d <- g_scenario(list("ch1.qmd" = g_num_doc("45%")), list("ch1.qmd" = g_num_doc(c("45%", "37%"))))
  res <- g_gate(d)
  expect_false(res$ok)
  expect_identical(res$excess$text, "37%")
})

test_that("4a G10, G16: a document new in the commit has every line added", {
  d <- g_scenario(list("ch1.qmd" = G_PROSE), list("ch2.qmd" = g_num_doc(c("45%", "45%"))))
  res <- g_gate(d)
  expect_false(res$ok)
  expect_identical(sort(res$added$line), c(3L, 5L))
})

test_that("4a G10, 6.2.4: removing an anchor an unchanged chapter cites fails, listed at the citing chapter [3d]", {
  d <- g_scenario(list("ch1.qmd" = c("## Limits {#sec-limits}", "", "Text."), "ch2.qmd" = c("", "See @sec-limits for more.")),
                  list("ch1.qmd" = c("## Limits {#sec-bounds}", "", "Text.")))
  res <- g_gate(d)
  expect_false(res$ok)
  expect_true("sec-limits" %in% res$excess$text[res$excess$rule == "xref"])
  # no instance of the key is on an added line, so every new-side instance is listed (H16)
  r <- g_df(res$added)
  r <- r[r$rule == "xref", ]
  expect_identical(nrow(r), 1L)
  expect_match(r$file, "ch2\\.qmd$")
  expect_identical(r$line, 2L)
  expect_false(any(grepl("ch2", res$changed)))
})

test_that("4a G10, H3: a label word dropped from _weft.yml fails although no document changed", {
  d <- g_scenario(list("ch1.qmd" = "Samples came from Station 7.", "_weft.yml" = c("draft: false", "label_words: [Station]")),
                  list("_weft.yml" = "draft: false"))
  expect_identical(sum(lints(d, rules = "numeral")$text == "7"), 1L)   # the premise: the work tree now holds it
  res <- g_gate(d)
  expect_false(res$ok)
  expect_true("7" %in% res$excess$text[res$excess$rule == "numeral"])
  expect_identical(nrow(res$errors), 0L)
})

test_that("4a G10, H3: and adding the label word to _weft.yml removes the finding", {
  d <- g_scenario(list("ch1.qmd" = "Samples came from Station 7.", "_weft.yml" = "draft: false"),
                  list("_weft.yml" = c("draft: false", "label_words: [Station]")))
  expect_true(g_gate(d)$ok)
})

test_that("4a G10, H16: when no instance is on an added line, every new-side instance of the key is listed", {
  # HEAD holds 45% twice; the commit rewords nothing but drops a different numeral and adds a third elsewhere,
  # so the key's excess comes from a changed project file instead: label word dropped, two instances
  d <- g_scenario(list("ch1.qmd" = c("Station 7 here.", "", "Station 7 there."), "_weft.yml" = c("draft: false", "label_words: [Station]")),
                  list("_weft.yml" = "draft: false"))
  res <- g_gate(d)
  expect_false(res$ok)
  expect_identical(nrow(res$added), 2L)
  expect_identical(sort(res$added$line), c(1L, 3L))
})

test_that("4a G10: a tier-2 finding is not judged and not reported (6.2.7)", {
  d <- g_repo(list("ch1.qmd" = G_PROSE))
  g_write(d, "ch1.qmd", c(G_PROSE, "", F3D_CLAIMS[[1]]))
  g_add(d)
  tier2 <- lints(d, rules = "claim-word", tier = 2)                        # the premise: the work tree has one
  if (!expect_precondition("claim-word" %in% tier2$rule, "claim-word flags the sentence in the work tree")) return(invisible())
  res <- g_gate(d)
  expect_true(res$ok)
  expect_identical(nrow(res$added), 0L)
  expect_identical(nrow(res$excess), 0L)
  expect_false(any(grepl("claim-word", g_report(res))))
})

test_that("4a G9-G10: draft mode does not change the gate (WEFT_DRAFT and draft: true)", {
  for (cs in g_cases()) {
    d <- cs$build(environment())
    base <- g_sig(g_gate(d, cs$msg))
    withr::with_envvar(c(WEFT_DRAFT = "1"), env <- g_sig(g_gate(d, cs$msg)))
    expect_identical(env, base, label = paste("WEFT_DRAFT:", cs$name))
  }
  d <- g_scenario(list("ch1.qmd" = G_PROSE), list("ch1.qmd" = g_num_doc("45%"), "_weft.yml" = "draft: true"))
  expect_false(g_gate(d)$ok)
  d2 <- g_scenario(list("ch1.qmd" = G_PROSE, "_weft.yml" = "draft: true"), list("ch1.qmd" = c(G_PROSE, "", "More.")))
  expect_true(g_gate(d2)$ok)
})

# ---- G18: a side whose lints() stops ----------------------------------------------------------------------

test_that("4a G18: a bad _weft.yml on the new side fails the commit with that message", {
  d <- g_scenario(list("ch1.qmd" = G_PROSE), list("_weft.yml" = c("draft: false", "label_words: [Station")))
  premise <- tryCatch(lints(d), error = function(e) e)
  expect_s3_class(premise, "weft_config_error")
  res <- g_gate(d)
  expect_false(res$ok)
  expect_true(any(grepl(conditionMessage(premise), paste(attr(res, "report"), collapse = " "), fixed = TRUE)) ||
                any(grepl("_weft.yml", g_report(res), fixed = TRUE)))
})

test_that("4a G18: a bad _weft.yml at HEAD means findings are not compared, with a note naming the file", {
  d <- g_scenario(list("ch1.qmd" = G_PROSE, "_weft.yml" = c("draft: false", "label_words: [Station")),
                  list("ch1.qmd" = g_num_doc("45%"), "_weft.yml" = "draft: false"))
  res <- g_gate(d)
  expect_true(res$ok)
  expect_true(any(grepl("_weft.yml", res$notes, fixed = TRUE)))
  expect_true(any(grepl("^commit-msg: note: .*_weft\\.yml", g_report(res))))
})

# ---- G20: the report ---------------------------------------------------------------------------------------

test_that("4a G20: the report, section by section, as the design shows it", {
  d <- g_scenario(list("book/ch1.qmd" = G_PROSE, "book/ch2.qmd" = G_PROSE, "book/ch3.qmd" = G_PROSE),
                  list("book/ch1.qmd" = c(g_bad_doc(), G_ENGINE),
                       "book/ch2.qmd" = g_num_doc("45%"),
                       "book/ch3.qmd" = c(G_PROSE, "", "", "Flow rose by 37% in May.")),
                  weft = "book")
  res <- g_gate(d)
  expect_false(res$ok)
  rep <- g_report(res)
  fl <- function(df, i) sprintf("    %5d  %s  %s", df$line[[i]], df$rule[[i]], df$message[[i]])
  pad <- function(df, i) strrep(" ", nchar(sprintf("    %5d  %s  ", df$line[[i]], df$rule[[i]])))
  e <- g_df(res$errors)
  a <- g_df(res$added)
  a <- a[order(a$file, a$line), ]
  expect_identical(nrow(e), 1L)
  expect_identical(nrow(a), 2L)
  want <- c(
    "commit-msg: 1 construct error",
    "  book/ch1.qmd",
    fl(e, 1),
    if (!is.na(e$hint[[1]])) paste0(pad(e, 1), e$hint[[1]]),
    "",
    "commit-msg: 2 findings added that HEAD did not hold",
    "  book/ch2.qmd",
    fl(a, 1),
    if (!is.na(a$hint[[1]])) paste0(pad(a, 1), a$hint[[1]]),
    "  book/ch3.qmd",
    fl(a, 2),
    if (!is.na(a$hint[[2]])) paste0(pad(a, 2), a$hint[[2]]),
    "",
    "commit-msg: T s")
  expect_identical(rep, want)
  expect_match(a$message[[1]], "(rule 5.2.1)", fixed = TRUE)
})

test_that("4a G20: the time line is last; a failing run ends in 'commit-msg: <seconds, one decimal> s'", {
  d <- g_scenario(list("ch1.qmd" = G_PROSE), list("ch1.qmd" = g_num_doc("45%")))
  res <- g_gate(d)
  raw <- attr(res, "report")
  expect_match(raw[[length(raw)]], "^commit-msg: [0-9]+\\.[0-9] s$")
  expect_identical(raw[[length(raw) - 1L]], "")
})

test_that("4a G20: notes come before the time line as 'commit-msg: note: <text>'", {
  d <- g_scenario(list("ch1.qmd" = G_PROSE, "ch2.qmd" = G_PROSE),
                  list("ch1.qmd" = c(G_PROSE, "", "More."), "ch2.qmd" = g_num_doc("45%")), weft = character())
  res <- g_gate(d)
  rep <- g_report(res)
  i <- which(rep == "commit-msg: note: no weft project (no _weft.yml)")
  expect_length(i, 1L)
  expect_true(i < length(rep))
})

test_that("4a G20: with a finding that has no hint no hint line follows it; the hint is aligned under the message", {
  d <- g_scenario(list("ch1.qmd" = G_PROSE), list("ch1.qmd" = g_num_doc("45%")))
  res <- g_gate(d)
  a <- g_df(res$added)
  rep <- g_report(res)
  i <- which(rep == sprintf("    %5d  %s  %s", a$line, a$rule, a$message))
  expect_length(i, 1L)
  expect_false(is.na(a$hint))
  expect_identical(rep[[i + 1L]], paste0(strrep(" ", nchar(sprintf("    %5d  %s  ", a$line, a$rule))), a$hint))
})

test_that("4a G20: one added finding: the header names HEAD", {
  d <- g_scenario(list("ch1.qmd" = G_PROSE), list("ch1.qmd" = g_num_doc("45%")))
  rep <- g_report(g_gate(d))
  expect_true(any(grepl("^commit-msg: 1 finding(s)? added that HEAD did not hold$", rep)))
})

test_that("4a G20: sections absent when empty: a construct error alone prints no 'added' section", {
  d <- g_scenario(list("ch1.qmd" = G_PROSE), list("ch1.qmd" = c(g_bad_doc(), G_ENGINE)))
  rep <- g_report(g_gate(d))
  expect_false(any(grepl("findings? added that HEAD did not hold", rep)))
  expect_false(any(grepl("weft constructs? removed", rep)))
  expect_true(any(grepl("^commit-msg: 1 construct error$", rep)))
})

test_that("4a G20: the gate's report goes through message(), not stdout", {
  d <- g_scenario(list("ch1.qmd" = G_PROSE), list("ch1.qmd" = g_num_doc("45%")))
  expect_message(out <- capture.output(gate(NULL, path = d)), "commit-msg:")
  expect_identical(out, character())
})
