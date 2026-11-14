# Package 7d: the rendered-output check under real Quarto (dev/design-7.md N50, N52, N56; section 5
# "test-output-quarto.R"). A project set up by use_quarto(), one document with `@sec-missing`,
# `{{< meta nosuch >}}` and "NA", rendered to html and to latex, no R in the render (engine: markdown).
# Three renders, each shared by the tests below: the default settings, `output_refs: warn`, and a clean
# document. They skip when Quarto is not installed.
#
# READINGS: the report entry is `  index.qmd #methods (html, latex)  [unresolved reference] ?@sec-missing`
# with the excerpt on the next line (N56). `{{< meta nosuch >}}` prints "?meta:nosuch". The failures
# heading is "weft: 2 failures", the warned one "weft: 1 warned check(s)" (the post-render script's own).

oq <- new.env()

OQ_QUARTO_YML <- c("project:", "  type: default", "format:", "  html: default", "  latex: default")

OQ_DOC <- c("---", "title: \"Notes\"", "engine: markdown", "number-sections: true", "---", "",
            "## Methods {#methods}", "",
            "See @sec-missing for details, and @sec-real for the real one.", "",
            "The shortcode {{< meta nosuch >}} is unknown.", "",
            "The mean was NA here.", "",
            "## Real {#sec-real}", "", "Nothing to see.")

OQ_CLEAN <- c("---", "title: \"Clean\"", "engine: markdown", "number-sections: true", "---", "",
              "## Methods {#sec-methods}", "",
              "See @sec-methods for details. The word Na and N/A are fine.")

oq_render <- function(key, doc, weft_yml = NULL) {
  if (is.null(oq[[key]])) {
    skip_if_no_quarto()
    dir <- mk_project(list(`_quarto.yml` = OQ_QUARTO_YML, `index.qmd` = doc))
    if (!is.null(weft_yml)) writeLines(weft_yml, file.path(dir, "_weft.yml"))
    oq[[key]] <- c(list(dir = dir), qrender(dir))
  }
  oq[[key]]
}

oq_lines <- function(r) strsplit(r$log, "\n", fixed = TRUE)[[1]]

test_that("N50: the filter runs after Quarto's cross-reference: '?@sec-missing' is one entry for both formats", {
  r <- oq_render("default", OQ_DOC)
  expect_identical(r$status, 1L)
  ls <- oq_lines(r)
  i <- grep("\\[unresolved reference\\] \\?@sec-missing$", ls)
  expect_length(i, 1L)
  if (length(i) == 1L) {
    expect_match(ls[i], "^  index\\.qmd #methods \\(html, latex\\)  \\[unresolved reference\\] \\?@sec-missing$")
    # the excerpt is on the next line, indented six spaces
    expect_match(ls[i + 1L], "^      .*See .*sec-missing")
  }
})

test_that("N52: '{{< meta nosuch >}}' is an unresolved reference, once, with the key as Quarto printed it", {
  r <- oq_render("default", OQ_DOC)
  ls <- oq_lines(r)
  i <- grep("\\[unresolved reference\\] \\?meta:nosuch$", ls)
  expect_length(i, 1L)
  if (length(i) == 1L) expect_match(ls[i], "\\(html, latex\\)")
})

test_that("N52: a reference that resolved is not a finding", {
  r <- oq_render("default", OQ_DOC)
  expect_identical(sum(grepl("\\[unresolved reference\\]", oq_lines(r))), 2L)
  expect_false(any(grepl("?@sec-real", r$log, fixed = TRUE)))
})

test_that("N53, N56: the missing value is one warned entry, the unresolved references are the failures", {
  r <- oq_render("default", OQ_DOC)
  ls <- oq_lines(r)
  expect_true(any(grepl(rx_failures(2L), ls)), label = r$log)
  expect_true(any(grepl(rx_warned(1L), ls)), label = r$log)
  i <- grep("\\[missing value in output\\] NA$", ls)
  expect_length(i, 1L)
  if (length(i) == 1L) expect_match(ls[i], "\\(html, latex\\)")
  # the warned entry comes after the failures
  expect_gt(i, grep(rx_failures(2L), ls)[1])
})

test_that("N51: output_refs: warn lets the render pass, and lists the references as warned", {
  r <- oq_render("warn", OQ_DOC, weft_yml = "output_refs: warn")
  expect_identical(r$status, 0L, label = r$log)
  ls <- oq_lines(r)
  expect_true(any(grepl(rx_warned(3L), ls)), label = r$log)
  expect_false(any(grepl("^weft: [0-9]+ failure", ls)))
  expect_length(grep("\\[unresolved reference\\] \\?@sec-missing$", ls), 1L)
  expect_length(grep("\\[unresolved reference\\] \\?meta:nosuch$", ls), 1L)
})

test_that("N50: a document with nothing wrong renders with exit 0 and no output-check entry", {
  r <- oq_render("clean", OQ_CLEAN)
  expect_identical(r$status, 0L, label = r$log)
  expect_false(any(grepl("\\[(unresolved reference|missing value in output|leftover markup)\\]", r$log)))
})
