# Package 3d: citations against the bibliography (L29 cite-key, L30 cite-bare, L31 citation-key, L32 the
# static bibliography). Rules 5.4.1 to 5.4.6. Contract: dev/design-3.md. Helpers: helper-3.R, helper-3d.R.

CITE_OFF <- 4L   # lines that cite_doc() puts before the body: "---", one front matter line, "---", ""
BIBS <- list("refs.bib" = F3D_BIBTEX, "refs.json" = F3D_CSLJSON, "refs.yaml" = F3D_CSLYAML)

# one document with `bibliography: refs.bib` and the three files beside it
cite_doc <- function(body, rules, ext = "qmd", front = "bibliography: [refs.bib, refs.json, refs.yaml]", files = list(), ...) {
  nm <- paste0("doc.", ext)
  f <- c(stats::setNames(list(f3d_doc(body, front)), nm), BIBS, files)
  f3d_run(f, rules, ...)
}

# ---- L29 cite-key ---------------------------------------------------------------------------------

# source (one paragraph), the keys flagged
CITE_KEY_CASES <- list(
  list(r"{A [10 m]{cite="smith2020"} depth.}",              character()),
  list(r"{A [10 m]{cite="ghost2001"} depth.}",              "ghost2001"),
  list(r"{A [10 m]{cite="@smith2020"} depth.}",             character()),
  list(r"{A [10 m]{cite="@ghost2001"} depth.}",             "ghost2001"),
  list(r"{A [10 m]{cite="@smith2020, p. 4"} depth.}",       character()),
  list(r"{A [10 m]{cite="@ghost2001, p. 4"} depth.}",       "ghost2001"),
  list(r"{A [10 m]{cite="-@ghost2001"} depth.}",            "ghost2001"),
  list(r"{A [10 m]{cite="see @ghost2001"} depth.}",         "ghost2001"),
  list(r"{A [10 m]{cite="@smith2020; @ghost2001"} depth.}", "ghost2001"),
  list(r"{A [10 m]{cite="@ghost1; @ghost2"} depth.}",       c("ghost1", "ghost2")),
  list(r"{A [10 m]{cite="smith2020; ghost2001"} depth.}",   "ghost2001"),
  list(r"{A [10 m]{cite="doe:2018"} depth.}",               character()),
  list(r"{A [10 m]{cite="@doe:2018"} depth.}",              character()),
  list(r"{A [10 m]{cite="jsonkey2019; yamlkey2017"} depth.}", character()),
  list(r"{A [10 m]{cite="@real2001"} depth.}",              character()),
  # a key that only appears in an @comment block, or inside a field value, is not in the bibliography
  list(r"{A [10 m]{cite="fakekey2001"} depth.}",            "fakekey2001"),
  list(r"{A [10 m]{cite="fakekey2002"} depth.}",            "fakekey2002")
)

test_that("3d L29: cite-key lists each key of a cite span that is not in the bibliography, both forms, in .qmd and .Rmd", {
  for (cs in CITE_KEY_CASES) {
    both <- f3_both(function(ext) cite_doc(c("Prose.", "", cs[[1]]), "cite-key", ext = ext))
    for (ext in names(both)) {
      x <- both[[ext]]
      expect_findings_shape(x)
      expect_texts(x, "cite-key", cs[[2]])
      if (nrow(x)) {
        expect_true(all(x$tier == 1L), label = cs[[1]])
        expect_true(all(x$spec == "5.4.1"), label = cs[[1]])
        expect_true(all(x$line == 3L + CITE_OFF), label = paste(ext, cs[[1]]))
      }
    }
  }
})

test_that("3d L29: with no bibliography at all, every key of a cite span fails", {
  x <- f3d_run(list("doc.qmd" = c(r"{A [10 m]{cite="smith2020"} and [3 m]{cite="@doe:2018"}.}")), "cite-key")
  expect_texts(x, "cite-key", c("smith2020", "doe:2018"))
})

test_that("3d L29: a cite span in a table cell, a footnote and a caption is read as well as one in a paragraph", {
  body <- c(
    "| a | b |",
    "|---|---|",
    r"{| x | [1 m]{cite="ghost1"} |}",
    "",
    r"{Text.^[A note [2 m]{cite="ghost2"}.]}",
    "",
    "```{r}",
    "#| label: fig-d",
    "#| fig-cap: |",
    r"{#|   Depth [3 m]{cite="ghost3"} here.}",
    "plot(1)",
    "```")
  x <- cite_doc(body, "cite-key")
  expect_texts(x, "cite-key", c("ghost1", "ghost2", "ghost3"))
  expect_at(x, "cite-key", "ghost1", line = 3L + CITE_OFF)
  expect_at(x, "cite-key", "ghost2", line = 5L + CITE_OFF)
  expect_at(x, "cite-key", "ghost3", line = 10L + CITE_OFF)
})

test_that("3d L29: a cite span in a fenced block or an eval: false chunk's code is not a construct, so not read", {
  body <- c("```", r"{[1 m]{cite="ghost1"}}", "```", "", "Prose.")
  expect_none(cite_doc(body, "cite-key"))
})

# ---- L31 citation-key -----------------------------------------------------------------------------

# a paragraph, the keys flagged
CITATION_CASES <- list(
  list("As @smith2020 showed.",                         character()),
  list("As @ghost1 showed.",                            "ghost1"),
  list("As [@smith2020; @ghost2] showed.",              "ghost2"),
  list("As [-@ghost3] showed.",                         "ghost3"),
  list("As @ghost4 [p. 4] showed.",                     "ghost4"),
  list("As [see @ghost5, p. 4 and @smith2020] showed.", "ghost5"),
  list("As @{ghost6} showed.",                          "ghost6"),
  list("As @doe:2018 showed.",                          character()),
  list("As @smith2020, and @ghost7. Then more.",        "ghost7"),
  list("As @jsonkey2019 and @yamlkey2017 showed.",      character()),
  list("As [@real2001] showed.",                        character()),
  # not citations
  list("Write to me@ghost.org please.",                 character()),
  list("A price of 5 @ 3 each.",                        character()),
  list("As `@ghost8` showed.",                          character()),
  list("As <!-- @ghost9 --> showed.",                   character()),
  # cross-references are not citations, even when nothing defines them
  list("See @fig-depth and @tbl-sites.",                character()),
  list("See @sec-intro and @eq-mean.",                  character()),
  list("See @lst-code and @thm-main.",                  character()),
  # a key that merely begins like a cross-reference word is a citation
  list("See @figure2020.",                              "figure2020"),
  list("See @table-of-things.",                         "table-of-things")
)

test_that("3d L31: citation-key lists each citation key not in the bibliography, in .qmd and .Rmd", {
  for (cs in CITATION_CASES) {
    both <- f3_both(function(ext) cite_doc(c("Prose.", "", cs[[1]]), "citation-key", ext = ext))
    for (ext in names(both)) {
      x <- both[[ext]]
      expect_findings_shape(x)
      expect_texts(x, "citation-key", cs[[2]])
      if (nrow(x)) {
        expect_true(all(x$tier == 1L), label = cs[[1]])
        expect_true(all(x$spec == "5.4.3"), label = cs[[1]])
        expect_true(all(x$line == 3L + CITE_OFF), label = paste(ext, cs[[1]]))
      }
    }
  }
})

test_that("3d L31: the line and column of a missing key; the column is the @ or the key", {
  lines <- c("Prose.", "", "Then [@smith2020; @ghost2] shows.", "", "And @ghost4 too.")
  x <- cite_doc(lines, "citation-key")
  expect_at(x, "citation-key", "ghost2", line = 3L + CITE_OFF, col = f3d_col(lines, "@ghost2") + 0:1)
  expect_at(x, "citation-key", "ghost4", line = 5L + CITE_OFF, col = f3d_col(lines, "@ghost4") + 0:1)
})

test_that("3d L31: a citation in a table cell, a footnote and a caption is read", {
  body <- c("| a | b |", "|---|---|", "| x | @ghost1 |", "", "Text.^[A note @ghost2.]", "",
            "```{r}", "#| label: fig-d", "#| fig-cap: |", "#|   Depth @ghost3 here.", "plot(1)", "```")
  x <- cite_doc(body, "citation-key")
  expect_texts(x, "citation-key", c("ghost1", "ghost2", "ghost3"))
})

test_that("3d L31: a key in a fenced block, an indented block or a chunk's code is not a citation", {
  body <- c("```{r}", "x <- \"@ghost1\"", "y@ghost2", "```", "", "~~~", "@ghost3", "~~~", "", "Prose.")
  expect_none(cite_doc(body, "citation-key"))
})

test_that("3d L31: bookdown's \\@ref() is no citation (.Rmd)", {
  body <- c("See \\@ref(fig:depth) and \\@ref(sec-intro).", "")
  expect_none(cite_doc(body, "citation-key", ext = "Rmd"))
})

test_that("3d L31: no bibliography at all, every citation key fails", {
  x <- f3d_run(list("doc.qmd" = c("As @smith2020 and [@doe:2018] showed.")), "citation-key")
  expect_texts(x, "citation-key", c("smith2020", "doe:2018"))
})

test_that("3d L31: a bibliography file that is named but missing is one finding at its bibliography: line", {
  for (ext in c("qmd", "Rmd")) {
    lines <- f3d_doc(c("As @smith2020 and @doe:2018 showed.", "Also @ghost1."),
                     front = c("title: T", "bibliography: gone.bib"))
    x <- f3d_run(stats::setNames(list(lines), paste0("doc.", ext)), "citation-key")
    r <- lf_by_rule(x, "citation-key")
    r <- r[r$text == "gone.bib", , drop = FALSE]
    expect_identical(nrow(r), 1L, label = paste(ext, "one finding for the missing file"))
    expect_identical(r$line, f3d_line(lines, "bibliography: gone.bib"))
    expect_identical(r$tier, 1L)
    expect_true(r$spec %in% c("5.4.3", "5.4.4"))
  }
})

test_that("3d L31: of two bibliography files, only the missing one is named", {
  lines <- f3d_doc(c("As @smith2020 showed."), front = c("bibliography:", "  - refs.bib", "  - gone.bib"))
  x <- f3d_run(c(list("doc.qmd" = lines), BIBS), "citation-key")
  expect_texts(x, "citation-key", "gone.bib")
  # the line of the key or of the list item
  expect_true(lf_one(x, "citation-key", "gone.bib")$line %in% c(f3d_line(lines, "bibliography:"), f3d_line(lines, "gone.bib")))
})

# ---- L32 the static bibliography -----------------------------------------------------------------

# a document whose body cites one key that the bibliography under test holds, and a ghost; the findings are
# the citation-key texts (only the ghost, when the bibliography is found)
probe <- function(files, doc, key, ...) {
  body <- c(paste0("Known @", key, " and unknown @ghost2001."))
  f <- files
  f[[doc]] <- f3d_doc(body, front = f[[doc]])
  f3d_run(f, c("citation-key", "cite-key"), ...)
}

test_that("3d L32: bibliography: a file in each of BibTeX, CSL JSON and CSL YAML, one string or a list", {
  for (case in list(list("bibliography: refs.bib", "smith2020"), list("bibliography: refs.json", "jsonkey2019"),
                    list("bibliography: refs.yaml", "yamlkey2017"),
                    list(c("bibliography:", "  - refs.bib", "  - refs.json"), "jsonkey2019"),
                    list("bibliography: [refs.bib, refs.yaml]", "yamlkey2017"))) {
    x <- probe(c(list(doc.qmd = case[[1]]), BIBS), "doc.qmd", case[[2]])
    expect_texts(x, "citation-key", "ghost2001")
  }
})

test_that("3d L32: references: entries in the front matter count", {
  front <- c("references:", "- id: inlinekey", "  type: book", "  title: Inline", "- id: inline2", "  type: book", "  title: Two")
  x <- probe(list(doc.qmd = front), "doc.qmd", "inline2")
  expect_texts(x, "citation-key", "ghost2001")
})

test_that("3d L32: a bibliography and references: in the front matter are added together", {
  front <- c("bibliography: refs.bib", "references:", "- id: inlinekey", "  type: book", "  title: Inline")
  body <- "Both @smith2020 and @inlinekey but not @ghost2001."
  x <- f3d_run(c(list(doc.qmd = f3d_doc(body, front)), BIBS), "citation-key")
  expect_texts(x, "citation-key", "ghost2001")
})

test_that("3d L32: a file under a document's bibliography: is read from the document's folder", {
  # ch/refs.bib exists; the root has none
  files <- list("ch/a.qmd" = f3d_doc("Known @other2015 and @ghost2001.", "bibliography: refs.bib"),
                "ch/refs.bib" = F3D_BIBTEX2)
  expect_texts(f3d_run(files, "citation-key"), "citation-key", "ghost2001")
  # a file at the root only is not found from ch/: it is a missing file
  files2 <- list("ch/a.qmd" = f3d_doc("Known @other2015.", "bibliography: refs.bib"), "refs.bib" = F3D_BIBTEX2)
  x <- f3d_run(files2, "citation-key")
  expect_true("refs.bib" %in% f3d_texts(x, "citation-key"))
})

test_that("3d L32: _quarto.yml's bibliography is read from the root, for a document in a subfolder", {
  files <- list("_quarto.yml" = c("project:", "  type: book", "bibliography: refs.bib"),
                "ch/a.qmd" = "Known @smith2020 and @ghost2001.\n",
                "refs.bib" = F3D_BIBTEX)
  expect_texts(f3d_run(files, "citation-key"), "citation-key", "ghost2001")
})

test_that("3d L32: _quarto.yml's bibliography as a list, and its references:", {
  files <- list("_quarto.yml" = c("project:", "  type: book", "bibliography:", "  - refs.bib", "  - refs.json"),
                "a.qmd" = "Known @smith2020, @jsonkey2019 and @ghost2001.\n",
                "refs.bib" = F3D_BIBTEX, "refs.json" = F3D_CSLJSON)
  expect_texts(f3d_run(files, "citation-key"), "citation-key", "ghost2001")
  files <- list("_quarto.yml" = c("project:", "  type: book", "references:", "- id: qkey", "  type: book", "  title: Q"),
                "a.qmd" = "Known @qkey and @ghost2001.\n")
  expect_texts(f3d_run(files, "citation-key"), "citation-key", "ghost2001")
})

test_that("3d L32: a _metadata.yml applies to its folder and below, with paths from its own folder, not to a sibling folder", {
  files <- list("ch/_metadata.yml" = "bibliography: local.bib",
                "ch/local.bib" = F3D_BIBTEX2,
                "ch/a.qmd" = "Known @other2015 and @ghost1.\n",
                "ch/sub/b.qmd" = "Known @other2015 and @ghost2.\n",
                "other/c.qmd" = "Known @other2015 and @ghost3.\n")
  x <- f3d_run(files, "citation-key")
  expect_true(all(c("ghost1", "ghost2", "ghost3") %in% f3d_texts(x, "citation-key")))
  # the sibling folder does not see ch/_metadata.yml: its other2015 fails too
  expect_at(x, "citation-key", "other2015", line = 1L, file = "other/c.qmd")
  expect_false("other2015" %in% x$text[x$file %in% c("ch/a.qmd", "ch/sub/b.qmd")])
})

test_that("3d L32: the bibliography setting of _weft.yml is read from the root, for a document in a subfolder", {
  for (yml in list("bibliography: refs.bib", c("bibliography:", "  - refs.bib"))) {
    files <- list("ch/a.qmd" = "Known @smith2020 and @ghost2001.\n", "refs.bib" = F3D_BIBTEX)
    expect_texts(f3d_run(files, "citation-key", weft_yml = yml), "citation-key", "ghost2001")
  }
})

test_that("3d L32: the document's, the project's and the setting's bibliographies are all added together", {
  files <- list("_quarto.yml" = c("project:", "  type: default", "bibliography: refs.bib"),
                "a.qmd" = f3d_doc("Known @smith2020, @jsonkey2019, @other2015 and @ghost2001.", "bibliography: refs.json"),
                "other.bib" = F3D_BIBTEX2, "refs.bib" = F3D_BIBTEX, "refs.json" = F3D_CSLJSON)
  x <- f3d_run(files, "citation-key", weft_yml = "bibliography: other.bib")
  expect_texts(x, "citation-key", "ghost2001")
})

test_that("3d L32: a project that lints with no Pandoc or Quarto reads the bibliography statically", {
  # a CSL YAML file that is not named references: at the top is not a bibliography of ids
  files <- list("a.qmd" = f3d_doc("Known @yamlkey2017 and @ghost2001.", "bibliography: refs.yaml"), "refs.yaml" = F3D_CSLYAML)
  expect_texts(f3d_run(files, "citation-key"), "citation-key", "ghost2001")
})

# ---- L30 cite-bare ----------------------------------------------------------------------------------

# a block, the keys flagged by cite-bare
CITE_BARE_CASES <- list(
  list(r"{@jones2019 found [10 m]{cite="jones2019"} deep.}",                  character()),
  list(r"{[10 m]{cite="jones2019"} deep.}",                                   "jones2019"),
  list(r"{-@jones2019 found [10 m]{cite="jones2019"} deep.}",                 character()),
  list(r"{@{jones2019} found [10 m]{cite="jones2019"} deep.}",                character()),
  list(r"{[@jones2019] found [10 m]{cite="jones2019"} deep.}",                character()),
  list(r"{@jones2019. And [10 m]{cite="jones2019"} deep.}",                   character()),
  list(r"{@jones2019 found [10 m]{cite="jones2019; smith2020"} deep.}",       "smith2020"),
  list(r"{@jones2019 and @smith2020 found [10 m]{cite="jones2019; smith2020"}.}", character()),
  list(r"{[10 m]{cite="jones2019; smith2020"} deep.}",                        c("jones2019", "smith2020")),
  # a longer key is not the key
  list(r"{@jones2019x found [10 m]{cite="jones2019"} deep.}",                 "jones2019"),
  # the citation form is not the bare form: it emits its own citation
  list(r"{[10 m]{cite="@jones2019"} deep.}",                                  character()),
  # a citation in code is not a citation
  list(r"{`@jones2019` found [10 m]{cite="jones2019"} deep.}",                "jones2019")
)

test_that("3d L30: cite-bare lists each key of a bare-form cite span that its block does not cite, in .qmd and .Rmd", {
  for (cs in CITE_BARE_CASES) {
    both <- f3_both(function(ext) cite_doc(c("Prose.", "", cs[[1]]), "cite-bare", ext = ext))
    for (ext in names(both)) {
      x <- both[[ext]]
      expect_findings_shape(x)
      expect_texts(x, "cite-bare", cs[[2]])
      if (nrow(x)) {
        expect_true(all(x$tier == 1L), label = cs[[1]])
        expect_true(all(x$spec == "5.4.2"), label = cs[[1]])
        expect_true(all(x$line == 3L + CITE_OFF), label = paste(ext, cs[[1]]))
      }
    }
  }
})

test_that("3d L30: a citation in another paragraph does not count; the block is the innermost one", {
  body <- c("@jones2019 says something.", "", r"{[10 m]{cite="jones2019"} deep.}")
  x <- cite_doc(body, "cite-bare")
  expect_texts(x, "cite-bare", "jones2019")
  expect_at(x, "cite-bare", "jones2019", line = 3L + CITE_OFF)
})

test_that("3d L30: a paragraph that runs over several lines is one block", {
  body <- c("@jones2019 says", "something about", r"{[10 m]{cite="jones2019"} deep.}")
  expect_none(cite_doc(body, "cite-bare"))
})

test_that("3d L30: in a table, each cell is its own block", {
  body <- c("| a | b |", "|---|---|",
            r"{| @jones2019 | [10 m]{cite="jones2019"} |}",
            r"{| @jones2019 [10 m]{cite="jones2019"} | x |}")
  x <- cite_doc(body, "cite-bare")
  expect_texts(x, "cite-bare", "jones2019")
  expect_at(x, "cite-bare", "jones2019", line = 3L + CITE_OFF)
})

test_that("3d L30: in a list, each item is its own block", {
  body <- c("- @jones2019 first", r"{- [10 m]{cite="jones2019"} second}",
            r"{- @jones2019 [10 m]{cite="jones2019"} third}")
  x <- cite_doc(body, "cite-bare")
  expect_texts(x, "cite-bare", "jones2019")
  expect_at(x, "cite-bare", "jones2019", line = 2L + CITE_OFF)
})

test_that("3d L30: a footnote is its own block, apart from the paragraph that holds it", {
  body <- c(r"{Text @jones2019.^[A note [2 m]{cite="jones2019"}.]}", "",
            r"{Text.^[@jones2019 and [2 m]{cite="jones2019"}.]}")
  x <- cite_doc(body, "cite-bare")
  expect_texts(x, "cite-bare", "jones2019")
  expect_at(x, "cite-bare", "jones2019", line = 1L + CITE_OFF)
})

test_that("3d L30: a caption is its own block, apart from the body", {
  mk <- function(cap) c("@jones2019 is cited in the body.", "", "```{r}", "#| label: fig-d", "#| fig-cap: |",
                        paste0("#|   ", cap), "plot(1)", "```")
  x <- cite_doc(mk(r"{Depth [3 m]{cite="jones2019"} here.}"), "cite-bare")
  expect_texts(x, "cite-bare", "jones2019")
  expect_at(x, "cite-bare", "jones2019", line = 6L + CITE_OFF)
  expect_none(cite_doc(mk(r"{Depth @jones2019 [3 m]{cite="jones2019"} here.}"), "cite-bare"))
})

test_that("3d L30: cite-bare does not read the bibliography", {
  x <- f3d_run(list("doc.qmd" = r"{[10 m]{cite="notinanybib"} deep.}"), "cite-bare")
  expect_texts(x, "cite-bare", "notinanybib")
})

# ---- files, a book --------------------------------------------------------------------------------

test_that("3d L2: files limits the citation findings to the named files, and the bibliography still comes from the project", {
  files <- list("_quarto.yml" = c("project:", "  type: book", "bibliography: refs.bib", "book:", "  chapters:", "    - index.qmd", "    - a.qmd", "    - b.qmd"),
                "index.qmd" = "# Home {#sec-home}\n",
                "a.qmd" = "Known @smith2020 and @ghostA.\n",
                "b.qmd" = "Known @smith2020 and @ghostB.\n",
                "refs.bib" = F3D_BIBTEX)
  root <- lint_proj(files)
  all <- lints(root, rules = "citation-key", tier = 1:2)
  expect_setequal(paste(all$file, all$text), c("a.qmd ghostA", "b.qmd ghostB"))
  one <- lints(root, files = "a.qmd", rules = "citation-key", tier = 1:2)
  expect_identical(paste(one$file, one$text), "a.qmd ghostA")
})
