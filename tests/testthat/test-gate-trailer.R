# Package 4a: the Weft-Removed trailer and the removal listing (dev/design-4.md G12, G13, G20, H15).
# Fixture: a document of five values, one per paragraph (lines 1, 3, 5, 7, 9); the commit keeps two.

v5 <- g_vals(c("a1", "a2", "a3", "a4", "a5"))
v2 <- v5[1:3]
rm3 <- function(env = parent.frame()) g_scenario(list("ch1.qmd" = v5), list("ch1.qmd" = v2), env = env)

cut70 <- function(x) ifelse(nchar(x) > 70, paste0(substr(x, 1, 67), "..."), x)

test_that("4a G13: no message file is a message with no trailer: a removal fails", {
  d <- rm3()
  res <- g_gate(d)
  expect_false(res$ok)
  expect_true(is.na(res$trailer))
  expect_identical(res$n_removed, 3L)
})

test_that("4a G12, G20: the removal is listed from HEAD, with file, line, kind and text", {
  d <- rm3()
  res <- g_gate(d)
  r <- res$removed
  expect_identical(names(r), c("project", "file", "line", "kind", "text"))
  expect_identical(nrow(r), 3L)
  expect_identical(r$line, c(5L, 7L, 9L))
  expect_true(all(grepl("ch1\\.qmd$", r$file)))
  expect_identical(r$kind, rep("value", 3L))
  expect_true(all(mapply(grepl, c("`r a3`", "`r a4`", "`r a5`"), r$text, MoreArgs = list(fixed = TRUE))))
})

test_that("4a G20: the removal report, header, listing and advice", {
  d <- rm3()
  res <- g_gate(d)
  rep <- g_report(res)
  expect_true("commit-msg: 3 weft constructs removed, and the message does not say so" %in% rep)
  expect_true("  ch1.qmd, as in HEAD" %in% rep)
  r <- res$removed
  for (i in seq_len(nrow(r))) expect_true(sprintf("    %5d  %s", r$line[[i]], cut70(r$text[[i]])) %in% rep)
  tr <- trimws(rep)
  expect_true("If the removal is intended, add this line at the end of the commit" %in% tr)
  expect_true("message, after a blank line:" %in% tr)
  expect_true("Weft-Removed: 3" %in% tr)
  expect_true("or commit with: git commit --trailer \"Weft-Removed: 3\"" %in% tr)
  raw <- attr(res, "report")
  expect_match(raw[[length(raw)]], "^commit-msg: [0-9]+\\.[0-9] s$")
})

test_that("4a G13: the right count passes", {
  d <- rm3()
  res <- g_gate(d, c("Drop three readings", "", "Weft-Removed: 3"))
  expect_true(res$ok)
  expect_identical(res$trailer, 3L)
  expect_identical(res$n_removed, 3L)
  expect_identical(nrow(res$removed), 3L)       # the listing is still made
})

test_that("4a G13, G20: a wrong count fails, and the header names it; the advice says 'Change that line to:'", {
  d <- rm3()
  res <- g_gate(d, c("Drop readings", "", "Weft-Removed: 2"))
  expect_false(res$ok)
  expect_identical(res$trailer, 2L)
  rep <- g_report(res)
  expect_true("commit-msg: 3 weft constructs removed, and the message says Weft-Removed: 2" %in% rep)
  tr <- trimws(rep)
  expect_true(any(grepl("Change that line to:", tr, fixed = TRUE)))
  expect_true("Weft-Removed: 3" %in% tr)
  expect_false(any(grepl("does not say so", rep)))
})

test_that("4a G13: a count that is too large is wrong too", {
  d <- rm3()
  res <- g_gate(d, c("Drop readings", "", "Weft-Removed: 5"))
  expect_false(res$ok)
})

test_that("4a G13: the key is matched without regard to case; the value may lack a space or have spaces", {
  d <- rm3()
  for (line in c("weft-removed: 3", "WEFT-REMOVED: 3", "Weft-Removed:3", "Weft-Removed:   3  ")) {
    res <- g_gate(d, c("Drop readings", "", line))
    expect_true(res$ok, label = line)
    expect_identical(res$trailer, 3L, label = line)
  }
})

test_that("4a G13, H15: with several trailers the last counts", {
  d <- rm3()
  expect_true(g_gate(d, c("Drop", "", "Weft-Removed: 2", "Weft-Removed: 3"))$ok)
  res <- g_gate(d, c("Drop", "", "Weft-Removed: 3", "Weft-Removed: 2"))
  expect_false(res$ok)
  expect_identical(res$trailer, 2L)
})

test_that("4a G13, H15: a value that is not a whole number in digits is a wrong number", {
  d <- rm3()
  for (v in c("three", "-1", "3.5", "3 items", "")) {
    res <- g_gate(d, c("Drop", "", paste("Weft-Removed:", v)))
    expect_false(res$ok, label = paste0("[", v, "]"))
    expect_true(is.na(res$trailer), label = paste0("[", v, "]"))
  }
})

test_that("4a G13: other trailers beside Weft-Removed do not disturb it", {
  d <- rm3()
  res <- g_gate(d, c("Drop", "", "Signed-off-by: A Writer <writer@example.invalid>", "Weft-Removed: 3",
                     "Reviewed-by: B Reader <reader@example.invalid>"))
  expect_true(res$ok)
})

test_that("4a G13, G12: a trailer on a commit that removes nothing is ignored, whatever it says", {
  d <- g_scenario(list("ch1.qmd" = G_PROSE), list("ch1.qmd" = c(G_PROSE, "", "More.")))
  for (v in c("4", "three", "0")) {
    res <- g_gate(d, c("Edit", "", paste("Weft-Removed:", v)))
    expect_true(res$ok, label = v)
  }
})

test_that("4a G13: a message file as git writes it with -m and with -F (real commit-msg files)", {
  d <- rm3()
  m1 <- g_capture_msg(d, c("-m", "Drop readings", "-m", "Weft-Removed: 3"))
  expect_true(g_gate(d, m1)$ok)
  m2 <- g_capture_msg(d, c("-m", "Drop readings", "-m", "Weft-Removed: 2"))
  expect_false(g_gate(d, m2)$ok)
  f <- g_msg(c("Drop readings", "", "Details about it.", "", "# a comment line", "Weft-Removed: 3"))
  m3 <- g_capture_msg(d, c("-F", f))
  expect_true(g_gate(d, m3)$ok)
})

test_that("4a G13: a message with the editor's comment lines and status block (git commit -e)", {
  d <- rm3()
  m <- g_capture_msg(d, c("-e", "-m", "Drop readings", "-m", "Weft-Removed: 3"))
  expect_true(any(grepl("^#", readLines(m))))      # the premise: the status block is there
  res <- g_gate(d, m)
  expect_true(res$ok)
  expect_identical(res$trailer, 3L)
})

test_that("4a G13: a trailer typed inside a comment line is not a trailer", {
  d <- rm3()
  res <- g_gate(d, c("Drop readings", "", "# Weft-Removed: 3"))
  expect_false(res$ok)
  expect_true(is.na(res$trailer))
})

# ---- G12: the listing ------------------------------------------------------------------------------------------

test_that("4a G12: of a text held b times at HEAD and n < b times now, the last b - n base instances are listed", {
  base <- c("First `r a1`{.num} here.", "", "Middle `r a2`{.num}.", "", "Again `r a1`{.num} there.")
  d <- g_scenario(list("ch1.qmd" = base), list("ch1.qmd" = base[1:3]))
  res <- g_gate(d)
  expect_identical(res$n_removed, 1L)
  expect_identical(nrow(res$removed), 1L)
  expect_identical(res$removed$line, 5L)
  expect_match(res$removed$text, "`r a1`", fixed = TRUE)
})

test_that("4a G12, 6.3.4: the listing is longer than N when the commit also adds a construct", {
  base <- g_vals(c("a1", "a2", "a3"))
  new <- c(g_vals("a1"), "", "The new one is `r b9`{.num}.")
  d <- g_scenario(list("ch1.qmd" = base), list("ch1.qmd" = new))
  res <- g_gate(d)
  expect_identical(res$n_removed, 1L)               # 3 before, 2 after
  expect_identical(nrow(res$removed), 2L)           # a2 and a3 are gone
  expect_false(res$ok)
  expect_true(any(trimws(g_report(res)) == "Weft-Removed: 1"))
  expect_true(g_gate(d, c("Rework", "", "Weft-Removed: 1"))$ok)
})

test_that("4a G12: the listing is sorted by file and then line, over several files", {
  d <- g_scenario(list("b.qmd" = g_vals(c("b1", "b2")), "a.qmd" = g_vals(c("a1", "a2"))),
                  list("b.qmd" = g_vals("b1"), "a.qmd" = g_vals("a1")))
  res <- g_gate(d)
  expect_identical(res$n_removed, 2L)
  expect_identical(order(res$removed$file, res$removed$line), seq_len(nrow(res$removed)))
  expect_match(res$removed$file[[1]], "a\\.qmd$")
})

test_that("4a G20: construct text longer than 70 characters is cut to 67 and '...'", {
  long <- "claim(a_long_variable_name_for_the_first_site_count, . > 10 & b_long_variable_name_for_second < 5)"
  expect_gt(nchar(long), 70L)
  base <- c("```{r chk-long}", long, "```")
  d <- g_scenario(list("ch1.qmd" = base), list("ch1.qmd" = c("```{r chk-long}", "x <- 1", "```")))
  res <- g_gate(d)
  expect_identical(res$n_removed, 1L)
  rep <- g_report(res)
  expect_true(any(endsWith(rep, paste0(substr(long, 1, 67), "..."))))
  expect_false(any(grepl(long, rep, fixed = TRUE)))
})

# ---- new and deleted files against an empty version -------------------------------------------------------------

test_that("4a G12: a deleted document removes its constructs (a trailer is demanded)", {
  d <- g_scenario(list("ch1.qmd" = G_PROSE, "ch2.qmd" = g_vals(c("a1", "a2"))), list("ch2.qmd" = NULL))
  res <- g_gate(d)
  expect_false(res$ok)
  expect_identical(res$n_removed, 2L)
  expect_true(all(grepl("ch2\\.qmd$", res$removed$file)))
  expect_true(g_gate(d, c("Remove chapter two", "", "Weft-Removed: 2"))$ok)
})

test_that("4a G12: a new document is compared with an empty version: nothing is removed", {
  d <- g_scenario(list("ch1.qmd" = G_PROSE), list("ch2.qmd" = c(g_vals(c("a1", "a2")), G_ENGINE)))
  res <- g_gate(d)
  expect_true(res$ok)
  expect_identical(max(0, res$n_removed), 0)
  expect_identical(nrow(res$removed), 0L)
})
