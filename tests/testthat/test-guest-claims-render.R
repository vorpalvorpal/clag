# Stage 8, G1 (dev/design-8.md GN3, GN6, GN13, section 4 "Slow renders"): two real renders, one on the
# jupyter engine and one on the julia engine, each of a project with `chunk_claims: collect` and two
# cells that fail their claims. Under collect each cell goes on, so the page holds what the cells printed
# after the claim; the render still fails at the end (the post-render script of a project), and stderr lists
# both failed claims with the cells' labels.
# Skips: qm_render() (quarto and a Python with jupyter_client and ipykernel), and jle_render()
# (quarto and julia, WEFT_SKIP_JULIA). Made-up values only. ASCII only.
#
# READINGS of the design (see the report):
#  - "the exit status is not 0" is read as exactly 1, as for a failed claim in test-jupyter-render.R;
#  - the report's entries are matched as in test-jupyter-render.R: "  doc.qmd chunk <label>  ..." with the
#    claim's detail on the lines below, and a heading "weft: 2 claims failed".

jle_kill_at_file_end()

gr_read <- function(dir) qm_read(dir, "doc.html")

GR_PY_QMD <- c(
  "---", "title: Collect", "---", "",
  "```{python}", "#| label: first", "from weft import claim", "n = 7",
  "claim(n, '> 10')", "print('later output one')", "```", "",
  "```{python}", "#| label: second", "claim(n, '> 20')", "print('later output two')", "```", "",
  "Some prose.")

GR_JL_QMD <- c(
  "---", "title: Collect", "---", "",
  "```{julia}", "#| include: false", "using Weft", "```", "",
  "```{julia}", "#| label: first", "n = 7", "@claim n > 10", "println(\"later output one\")", "```", "",
  "```{julia}", "#| label: second", "@claim n > 20", "println(\"later output two\")", "```", "",
  "Some prose.")

gr_expect_report <- function(x, lines_at = NULL) {
  expect_identical(x$status, 1L, label = x$log)
  lines <- strsplit(x$stderr, "\n", fixed = TRUE)[[1]]
  heads <- grep("^weft: ", lines, value = TRUE)
  expect_true(any(grepl(rx_claims(2), heads)), label = paste(heads, collapse = " / "))
  # the jupyter filter locates a claim by its cell label; the julia filter, by its line
  if (is.null(lines_at)) {
    e1 <- fm_entry(x$stderr, "^  doc\\.qmd chunk first  ")
    e2 <- fm_entry(x$stderr, "^  doc\\.qmd chunk second  ")
  } else {
    e1 <- fm_entry(x$stderr, sprintf("^  doc\\.qmd:%d  ", lines_at[1]))
    e2 <- fm_entry(x$stderr, sprintf("^  doc\\.qmd:%d  ", lines_at[2]))
    expect_true(startsWith(sub("^  doc\\.qmd:[0-9]+  ", "", e1$head), "@claim n > 10"), label = e1$head)
    expect_true(startsWith(sub("^  doc\\.qmd:[0-9]+  ", "", e2$head), "@claim n > 20"), label = e2$head)
  }
  expect_true(e1$found, label = "an entry for the first claim")
  expect_true(e2$found, label = "an entry for the second claim")
  expect_match(paste(e1$detail, collapse = " "), "> 10 was false \\(value 7\\)")
  expect_match(paste(e2$detail, collapse = " "), "> 20 was false \\(value 7\\)")
}

test_that("GN3, GN6, GN13: on the jupyter engine two failing claims under collect leave both cells' later output in the page, the render fails, and stderr lists both claims with their labels", {
  dir <- qm_project(list(`doc.qmd` = GR_PY_QMD, `_weft.yml` = c("draft: false", "chunk_claims: collect")))
  x <- qm_render(dir)
  html <- gr_read(dir)
  expect_match(html, "later output one", fixed = TRUE)
  expect_match(html, "later output two", fixed = TRUE)
  gr_expect_report(x)
})

test_that("GN3, GN6, GN13: on the julia engine two failing claims under collect leave both cells' later output in the page, the render fails, and stderr lists both claims with their labels", {
  skip_if_no_julia_engine()
  dir <- jle_project(list(`doc.qmd` = GR_JL_QMD, `_weft.yml` = c("draft: false", "chunk_claims: collect")))
  x <- jle_render(dir)
  html <- gr_read(dir)
  expect_match(html, "later output one", fixed = TRUE)
  expect_match(html, "later output two", fixed = TRUE)
  gr_expect_report(x, lines_at = c(which(GR_JL_QMD == "@claim n > 10"), which(GR_JL_QMD == "@claim n > 20")))
})
