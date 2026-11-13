# Package 4a: the 72 edits of dev/spikes/spike-gate/edits.R through the gate (dev/design-4.md section 5, G11, G12).
# The edits are data: tests/testthat/_gate/manuscript.R (the generator of a synthetic manuscript, ported from
# the spike) and tests/testthat/_gate/edits.R (the edits and their hand answers). Plus one extra, X01, where the
# ruling that counts claims apart (dev/review-4.md, design question 1) gives a different answer from a net total.
#
# Each test (a) counts constructs on the before and after texts with count_constructs() and checks that, per
# kind, the totals move by what the hand answer says (values and spans together; claims apart), and (b) runs
# the edit through the gate in a temporary git repository (baseline committed, the after text staged) and
# checks n_removed, that no trailer is refused exactly when N > 0, and that `Weft-Removed: N` passes.
# E16b has no hand answer: its expected N is the scanner's own count, as the design says.
#
# Keeping the documents free of unrelated findings: the gate judges the findings an edit ADDS, and every
# edit keeps the manuscript's text apart from the constructs it changes, so none is added; the manuscript
# has no typed numerals, and G_ENGINE is appended so that the `engine` finding does not fire. The document
# is held in one file, ch1.qmd.

ge <- new.env(parent = globalenv())
sys.source(test_path("_gate", "manuscript.R"), envir = ge)
sys.source(test_path("_gate", "edits.R"), envir = ge)

ge_cc <- function(lines) weft:::count_constructs(read_src(lines, ext = "qmd"))
# totals per kind group: values and spans together, claims apart
ge_tot <- function(x) c(vs = sum(x$kind %in% c("value", "span")), claim = sum(x$kind == "claim"))
# N under the ruling: each group's positive part of removed less added
ge_n <- function(rm, add) as.integer(max(0, rm[["claim"]] - add[["claim"]]) + max(0, rm[["vs"]] - add[["vs"]]))

test_that("4a edits: the fixture holds the 72 edits and the extra, each with a hand answer", {
  expect_length(ge$EDITS, 73L)
  expect_identical(sort(names(ge$EDITS)), sort(c(names(ge$EXPECT), "E16b")))
  expect_true(all(sprintf("E%02d", 1:71) %in% names(ge$EDITS)))
  # the hand answers are consistent with the rule
  for (x in ge$EXPECT) expect_identical(x$n, ge_n(x$rm, x$add), label = x$id)
})

for (id in names(ge$EDITS)) local({
  id <- id
  e <- ge$EDITS[[id]]
  test_that(paste0("4a edits ", id, ": ", e$desc), {
    skip_if_no_git()
    before <- c(ge$render_doc(ge$D0, 72), G_ENGINE)
    after <- c(ge$render_doc(e$f(ge$D0), e$width, e$hash_safe), G_ENGINE)
    cb <- ge_cc(before)
    ca <- ge_cc(after)
    tb <- ge_tot(cb)
    ta <- ge_tot(ca)
    if (identical(id, "E16b")) {
      # the scanner's count of working constructs: a wrap that breaks a construct (rule 5.3.4, or an error
      # such as a line that starts `# `) removes it, as G12 counts those the scanner reports no error on
      wb <- ge_tot(cb[!attr(cb, "errored"), ])
      wa <- ge_tot(ca[!attr(ca, "errored"), ])
      n <- ge_n(rm = c(vs = max(0, wb[["vs"]] - wa[["vs"]]), claim = max(0, wb[["claim"]] - wa[["claim"]])),
                add = c(vs = max(0, wa[["vs"]] - wb[["vs"]]), claim = max(0, wa[["claim"]] - wb[["claim"]])))
      expect_gt(n, 0L)
    } else {
      x <- ge$EXPECT[[id]]
      # (a) the totals move by the hand answer, per kind
      expect_equal(unname(ta - tb), unname(x$add - x$rm))
      n <- x$n
    }

    # (b) through the gate
    dir <- g_scenario(list("ch1.qmd" = before), list("ch1.qmd" = after))
    res <- g_gate(dir)
    expect_identical(res$n_removed, n)
    if (identical(id, "E16b")) {
      # the reflow breaks constructs (errors) and a heading (a finding): refused whatever the message says
      expect_false(res$ok)
      expect_identical(g_gate(dir, msg = c("Reflow", "", paste0("Weft-Removed: ", n)))$trailer, n)
      return(invisible())
    }
    # no construct error; the findings added are the edit's own (E03, E04) and no others
    expect_identical(nrow(res$errors), 0L)
    expect_identical(sort(res$added$rule), sort(as.character(e$finding)))
    clean <- is.null(e$finding)
    if (n > 0L) {
      expect_false(res$ok)
      expect_true(is.na(res$trailer))
      ok <- g_gate(dir, msg = c("Apply the edit", "", paste0("Weft-Removed: ", n)))
      expect_identical(ok$ok, clean)       # the trailer clears the removal and nothing else
      expect_identical(ok$trailer, n)
      expect_identical(ok$n_removed, n)
    } else {
      expect_identical(res$ok, clean)
    }
  })
})
