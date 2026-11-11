# Stage 1b: `cite` spans and the knit-time bibliography check
# (1.8.1 to 1.8.8, 5.3.1, 5.4.1, 5.4.4 to 5.4.6, 2.1.6).
#
# The documents are knitted in draft mode with knitr::knit() (format = "knit"),
# so the output is exactly what weft wrote: Pandoc's citeproc cannot rewrite
# `[@key]`, and the unknown-key markers (2.6.8) can be read. Under Quarto the
# front matter says `citeproc: false` for the same reason.

sc <- function(x, ...) weft:::scan_text(x, ...)

# ---- bibliography files ---------------------------------------------------------------

BIB_BIBTEX <- c(
  "@book{smith2020,",
  "  author = {Smith, Anna},",
  "  title = {Rivers of the Blue Mountains},",
  "  year = {2020},",
  "  publisher = {Example Press}",
  "}",
  "",
  "@article{doe:2018,",
  "  author = {Doe, Jane},",
  "  title = {Catchments},",
  "  journal = {Journal of Water},",
  "  year = {2018}",
  "}"
)
BIB_BIBLATEX <- c(
  "@online{bl2021,",
  "  author = {Lee, Sam},",
  "  title = {A web source},",
  "  date = {2021-05-01},",
  "  url = {https://example.org/bl2021}",
  "}",
  "",
  "@article{bl2022,",
  "  author = {Kim, Pat},",
  "  title = {Biblatex fields},",
  "  journaltitle = {Journal of Things},",
  "  date = {2022},",
  "  volume = {3}",
  "}"
)
BIB_CSLJSON <- c(
  "[",
  "  {\"id\": \"jsonkey2019\", \"type\": \"book\", \"title\": \"A CSL JSON book\",",
  "   \"author\": [{\"family\": \"Jones\", \"given\": \"Alex\"}],",
  "   \"issued\": {\"date-parts\": [[2019]]}}",
  "]"
)
BIB_CSLYAML <- c(
  "references:",
  "- id: yamlkey2017",
  "  type: book",
  "  title: A CSL YAML book",
  "  author:",
  "  - family: Brown",
  "    given: Chris",
  "  issued:",
  "    date-parts:",
  "    - - 2017"
)
BIB_FILES <- list("refs.bib" = BIB_BIBTEX, "refs-bl.bib" = BIB_BIBLATEX,
                  "refs.json" = BIB_CSLJSON, "refs.yaml" = BIB_CSLYAML)
BIB_FRONT <- c("bibliography:", "  - refs.bib", "  - refs-bl.bib", "  - refs.json", "  - refs.yaml")

# ---- the rows of the main document ------------------------------------------------------

CITE_ROWS <- list(
  b_row("K01", "[10 m in the upper catchment]{cite=\"@smith2020\"}.",
        "1.8.1 + 1.8.3: citation form: the prose, a space, then [@key]",
        want = "K01 10 m in the upper catchment [@smith2020]."),
  b_row("K02", "@smith2020 found [10 m]{cite=\"smith2020\"} in the upper catchment.",
        "1.8.1: bare form: the prose only",
        want = "K02 @smith2020 found 10 m in the upper catchment."),
  b_row("K03", "[10 m]{cite=\"@smith2020, p. 4\"}.", "1.8.3: a locator, exactly as given",
        want = "K03 10 m [@smith2020, p. 4]."),
  b_row("K04", "[10 m]{cite=\"@smith2020; @doe:2018\"}.", "1.8.3: several sources separated by ;",
        want = "K04 10 m [@smith2020; @doe:2018]."),
  b_row("K05", "[10 m]{cite=\"-@smith2020\"}.", "1.8.3: -@key, the year alone",
        want = "K05 10 m [-@smith2020]."),
  b_row("K06", "[10 m]{cite=\"see @smith2020\"}.", "1.8.3: a prefix",
        want = "K06 10 m [see @smith2020]."),
  b_row("K07", "[10 m]{cite=\"notakey and @jsonkey2019\"}.",
        "1.8.6: words before the @ are a prefix; only jsonkey2019 is a key (no failure for notakey)",
        want = "K07 10 m [notakey and @jsonkey2019]."),
  b_row("K08", "[10 m]{cite=\"@smith2020\" .strong}.", "1.8.7: a text class acts on the prose",
        want = "K08 **10 m** [@smith2020]."),
  b_row("K09", "[10 m]{cite=\"@smith2020\" .smallcaps}.", "1.8.7: pass-through attributes act on the prose",
        want = "K09 [10 m]{.smallcaps} [@smith2020]."),
  b_row("K10", "[a|b #c]{cite=\"@smith2020\"}.", "1.8.2: | and # are ordinary characters",
        want = "K10 a|b #c [@smith2020]."),
  b_row("K11", "[mean `r k`{.num} m]{cite=\"@smith2020\"}.", "1.8.2: the bracket is prose and holds values",
        want = "K11 mean 3 m [@smith2020]."),
  b_row("K12", "[a]{cite=\"@smith2020\"} [b]{cite=\"@yamlkey2017\"}.",
        "1.8.3: nothing is moved and adjacent spans are not merged",
        want = "K12 a [@smith2020] b [@yamlkey2017]."),
  b_row("K13", "[x]{cite=\"@jsonkey2019\"}.", "5.4.5: a key from CSL JSON resolves",
        want = "K13 x [@jsonkey2019]."),
  b_row("K14", "[x]{cite=\"@yamlkey2017\"}.", "5.4.5: a key from CSL YAML resolves",
        want = "K14 x [@yamlkey2017]."),
  b_row("K15", "[x]{cite=\"@bl2021\"}.", "5.4.5: a BibLaTeX @online entry resolves",
        want = "K15 x [@bl2021]."),
  b_row("K16", "[x]{cite=\"@bl2022\"}.", "5.4.5: a BibLaTeX @article entry (journaltitle) resolves",
        want = "K16 x [@bl2022]."),
  b_row("K17", "[x]{cite=\"@doe:2018\"}.", "5.4.5: a BibTeX key with a colon resolves",
        want = "K17 x [@doe:2018]."),
  b_row("K18", "[x]{cite=\"smith2020; yamlkey2017; bl2021\"}.", "1.8.4: bare keys separated by ;",
        want = "K18 x."),
  b_row("K19", "[`r k`{.word} [site | sites]{n=\"k\"}]{cite=\"@smith2020\"}.",
        "1.8.2: the bracket holds governed spans",
        want = "K19 three sites [@smith2020]."),
  b_row("K20", "[x]{cite=\"@nokey2020\"} end.", "1.8.5 + 2.6.8: an unknown key, citation form: a marker after the span's text",
        rx = "^K20 x.*<<weft: unknown key, line @L@>>"),
  b_row("K21", "[y]{cite=\"nokey2021\"} end.", "1.8.5 + 2.6.8: an unknown key, bare form",
        rx = "^K21 y.*<<weft: unknown key, line @L@>>"),
  b_row("K22", "[z]{cite=\"see @nokey2022\"} end.", "1.8.6 + 1.8.5: the key after the @ is checked, in a prefix form",
        rx = "^K22 z.*<<weft: unknown key, line @L@>>")
)
CITE_UNKNOWN <- c("K20", "K21", "K22")

cite_main <- local({
  cache <- NULL
  function() {
    if (!is.null(cache)) return(cache)
    b <- b_body(CITE_ROWS)
    res <- render_rmd(b$lines, code = PRE_B, front = BIB_FRONT, files = BIB_FILES,
                      env = c(WEFT_DRAFT = "1"), format = "knit", in_process = TRUE)
    res$b <- b
    cache <<- res
    res
  }
})

# ---- the scanner ------------------------------------------------------------------------

test_that("1.1.5 + design: a cite span is a row of kind cite; the cite value is its expr", {
  r <- sc("A [10 m]{cite=\"@smith2020\"} figure.")
  expect_equal(nrow(r), 1L)
  expect_equal(r$kind, "cite")
  expect_equal(r$expr, "@smith2020")
  expect_identical(r$error, NA_character_)
  r2 <- sc("[10 m]{cite=\"smith2020; jones2019\"}")
  expect_equal(r2$kind, "cite")
  expect_equal(r2$expr, "smith2020; jones2019")
})

test_that("1.8.2: a cite span has no arms: | and # are ordinary characters", {
  r <- sc("[a|b #c]{cite=\"@smith2020\"}")
  expect_equal(r$kind, "cite")
  expect_identical(r$error, NA_character_)
})

test_that("1.8.1 + 1.8.3 + 1.8.4 + 1.8.6: the legal forms of a cite value are not errors", {
  legal <- c("@smith2020", "@smith2020, p. 4", "@smith2020; @jones2019", "-@smith2020",
             "see @smith2020", "smith2020 and @jones2019", "smith2020", "smith2020; jones2019",
             "a_b", "2020smith", "a:b.c-d", "@a:b.c-d")
  for (v in legal) {
    expect_identical(b_errs(sprintf("[x]{cite=\"%s\"}", v)), character(), label = v)
  }
})

test_that("1.8.4 + 5.3.1: a bare-form cite value that is not keys only is a construct error", {
  b_expect_scan_error("[x]{cite=\"see smith2020\"}", "[x]{cite=\"smith2020\"}")
  b_expect_scan_error("[x]{cite=\"smith2020, jones2019\"}", "[x]{cite=\"smith2020; jones2019\"}")
  b_expect_scan_error("[x]{cite=\"smith2020 jones2019\"}")
  b_expect_scan_error("[x]{cite=\"p. 4\"}")
})

test_that("1.8.5 + 5.3.1: a key outside Pandoc's key grammar is a construct error", {
  b_expect_scan_error("[x]{cite=\"smith!2020\"}", "[x]{cite=\"smith2020\"}")
  b_expect_scan_error("[x]{cite=\"-smith2020\"}")
  b_expect_scan_error("[x]{cite=\"smüith2020 ;; x\"}")
})

test_that("1.8.7 + 5.3.1: a formatter class on a cite span is a construct error; text classes and pass-through are not", {
  b_expect_scan_error("[x]{.num cite=\"@smith2020\"}", "[x]{.strong cite=\"@smith2020\"}")
  b_expect_scan_error("[x]{cite=\"@smith2020\" .pct}")
  b_expect_scan_error("[x]{cite=\"smith2020\" .and}")
  expect_identical(b_errs("[x]{cite=\"@smith2020\" .smallcaps}"), character())
  expect_identical(b_errs("[x]{cite=\"@smith2020\" .cap .em}"), character())
})

test_that("1.7.5 + 5.3.1: an #id on a cite span is a construct error", {
  b_expect_scan_error("[x]{#zc cite=\"@smith2020\"}", "[x]{cite=\"@smith2020\"}")
})

test_that("1.1.5 + 5.3.1: cite with another governor key is one construct and an error", {
  b_expect_scan_error("[a | b]{cite=\"@smith2020\" n=\"k\"}", "[a | b]{n=\"k\"}")
  b_expect_scan_error("[a | b]{cite=\"@smith2020\" if=\"flag\"}")
})

test_that("1.3.3 + 5.3.1: cite on a value is a construct error", {
  b_expect_scan_error("`r x`{cite=\"@smith2020\"}", "`r x`{.num}")
})

test_that("1.2.3: a quote or backslash in a cite value is a construct error", {
  b_expect_scan_error("[x]{cite='@smith2020'}", "[x]{cite=\"@smith2020\"}")
})

test_that("1.9.1: a Pandoc citation bracket is not a construct (left alone)", {
  expect_equal(nrow(sc("As shown [@smith2020]. And [see @jones2019, p. 3].")), 0L)
})

# ---- the main document: exact output and markers -------------------------------------------------

test_that("1.8.1 to 1.8.7: cite spans write what the rules say, bibliography from the front matter (four file kinds)", {
  res <- cite_main()
  expect_false(res$failed, label = substr(res$message, 1, 300))
  b_need(res)
  b_check_lines(res, res$b, CITE_ROWS, "rmarkdown")
})

test_that("1.8.5 + 5.4.5: only the unknown keys are marked, and nothing else is", {
  res <- cite_main()
  b_need(res)
  txt <- unesc(res$text)
  n_marked <- sum(grepl("<<weft: unknown key", txt, fixed = TRUE))
  expect_equal(n_marked, length(CITE_UNKNOWN))
  expect_equal(sum(grepl("<<weft:", txt, fixed = TRUE)), length(CITE_UNKNOWN))
  # a known key in each of the four file kinds, and the 1.8.6 prefix word, have no marker
  for (tag in paste0("K", c("01", "07", "13", "14", "15", "16", "17"))) {
    line <- grep(paste0("^", tag, " "), txt, value = TRUE)
    expect_false(grepl("<<weft:", line, fixed = TRUE), label = tag)
  }
})

test_that("1.8.5 + 2.6.9: an unknown key is a collected failure of kind 'unknown citation key', one per key", {
  res <- cite_main()
  b_need(res)
  f <- res$knit$failures
  expect_equal(nrow(f), length(CITE_UNKNOWN))
  expect_setequal(f$kind, "unknown citation key")
  want_lines <- res$offset + res$b$at[match(CITE_UNKNOWN, vapply(CITE_ROWS, function(r) r$tag, ""))]
  expect_setequal(f$line, want_lines)
  # the record's detail names the key
  expect_true(any(grepl("nokey2020", paste(f$expr, f$detail))))
  expect_true(any(grepl("nokey2021", paste(f$expr, f$detail))))
  expect_true(any(grepl("nokey2022", paste(f$expr, f$detail))))
})

test_that("1.8.1: a cite span is a construct row of kind cite in last_knit()$constructs, evaluated", {
  res <- cite_main()
  b_need(res)
  cs <- res$knit$constructs
  ci_rows <- cs[cs$kind == "cite", ]
  expect_equal(nrow(ci_rows), sum(grepl("cite=", vapply(CITE_ROWS, function(r) r$src, ""), fixed = TRUE)))
  expect_true(all(ci_rows$evaluated))
})

# ---- other sources of the bibliography -------------------------------------------------------------

test_that("5.4.4: bibliography in _weft.yml, a single string in the front matter, and references: in the front matter all count", {
  rows <- list(
    b_row("C1", "[x]{cite=\"@cfgkey2016\"}.", "5.4.4: bibliography in _weft.yml (relative to the project root)",
          want = "C1 x [@cfgkey2016]."),
    b_row("C2", "[x]{cite=\"@inlinekey\"}.", "5.4.4: an entry under references: in the front matter",
          want = "C2 x [@inlinekey]."),
    b_row("C3", "[x]{cite=\"@singlekey\"}.", "5.4.4: bibliography: given as one string in the front matter",
          want = "C3 x [@singlekey]."),
    b_row("C4", "[x]{cite=\"@nokeyatall\"}.", "1.8.5: unknown against all three",
          rx = "^C4 x.*<<weft: unknown key, line @L@>>")
  )
  b <- b_body(rows)
  res <- render_rmd(
    b$lines, code = PRE_B, format = "knit", in_process = TRUE, env = c(WEFT_DRAFT = "1"),
    front = c("bibliography: single.bib", "references:", "- id: inlinekey", "  type: book",
              "  title: Inline", "  issued: 2015"),
    files = list(
      "_weft.yml" = c("bibliography:", "  - cfg.bib"),
      "cfg.bib" = "@book{cfgkey2016, author = {A, B}, title = {Cfg}, year = {2016}, publisher = {P}}",
      "single.bib" = "@book{singlekey, author = {A, B}, title = {Single}, year = {2012}, publisher = {P}}"
    ))
  expect_false(res$failed, label = substr(res$message, 1, 300))
  b_need(res)
  b_check_lines(res, b, rows, "rmarkdown")
  expect_equal(sum(grepl("<<weft:", unesc(res$text), fixed = TRUE)), 1L)
  expect_equal(nrow(res$knit$failures), 1L)
})

test_that("1.8.5 + 5.4.4: with no bibliography at all every key fails, and the render fails once with the report", {
  src <- c("See [x]{cite=\"@smith2020\"} and [y]{cite=\"zzz2020\"}.", "", "Plain text `r k`{.word}.")
  res <- render_rmd(src, code = PRE_B, in_process = TRUE)
  expect_true(res$failed)
  expect_true("weft_failures" %in% res$error$class)
  f <- res$knit$failures
  expect_equal(nrow(f), 2L)
  expect_setequal(f$kind, "unknown citation key")
  expect_setequal(f$line, rep(res$offset + 1L, 2))
  expect_match(res$message, at_line(res, 1))
  expect_match(res$message, "smith2020", fixed = TRUE)
  expect_match(res$message, "zzz2020", fixed = TRUE)
  # the rest of the document was knitted
  last <- res$knit$constructs[res$knit$constructs$line == res$offset + 3L, ]
  expect_true(all(last$evaluated))
})

test_that("1.8.5: a known key in the bibliography is not a failure, so the render succeeds (non-draft)", {
  res <- render_rmd(c("See [x]{cite=\"@smith2020\"}."), code = PRE_B, format = "knit",
                    front = BIB_FRONT, files = BIB_FILES, in_process = TRUE)
  expect_false(res$failed, label = substr(res$message, 1, 300))
  expect_match(res$md, "See x [@smith2020].", fixed = TRUE)
  expect_equal(nrow(res$knit$failures), 0L)
})

test_that("1.8.3: the citation is written whatever markdown the span's prose holds", {
  res <- render_rmd(c("See [*italic* and `code`]{cite=\"@smith2020\"}."), code = PRE_B, format = "knit",
                    front = BIB_FRONT, files = BIB_FILES)
  expect_false(res$failed, label = substr(res$message, 1, 300))
  expect_match(res$md, "See *italic* and `code` [@smith2020].", fixed = TRUE)
})

# ---- Quarto: the project's own bibliography (2.1.6) ----------------------------------------------------

test_that("5.4.4 + 2.1.6: under Quarto the bibliography of _quarto.yml and of the front matter both count", {
  skip_if_no_quarto()
  rows <- list(
    b_row("Q1", "[x]{cite=\"@projkey2010\"}.", "2.1.6: a key from the project's bibliography",
          want = "Q1 x [@projkey2010]."),
    b_row("Q2", "[x]{cite=\"@jsonkey2019\"}.", "5.4.4: a key from the document's bibliography (CSL JSON)",
          want = "Q2 x [@jsonkey2019]."),
    b_row("Q3", "[x]{cite=\"@nokeyatall\"}.", "1.8.5: unknown",
          rx = "^Q3 x.*<<weft: unknown key, line @L@>>")
  )
  b <- b_body(rows)
  res <- render_qmd(
    b$lines, code = PRE_B, env = c(WEFT_DRAFT = "1"),
    front = c("citeproc: false", "bibliography: refs.json"),
    files = list(
      "_quarto.yml" = c("project:", "  type: default", "bibliography: proj.bib"),
      "proj.bib" = "@book{projkey2010, author = {A, B}, title = {Proj}, year = {2010}, publisher = {P}}",
      "refs.json" = BIB_CSLJSON
    ))
  expect_false(res$failed, label = substr(res$message, 1, 300))
  b_need(res)
  b_check_lines(res, b, rows, "quarto")
  expect_equal(sum(grepl("<<weft:", unesc(res$text), fixed = TRUE)), 1L)
})
