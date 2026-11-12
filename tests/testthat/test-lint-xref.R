# Package 3d: cross-references and anchors (L33: xref, anchor-twice, ref-label, anchor-unused, xref-code),
# rules 5.7.1 and 5.7.2. Contract: dev/design-3.md L33 and the table after L35. Helpers: helper-3.R, helper-3d.R.

xr <- function(files, rules = "xref", ...) f3d_run(files, rules, ...)

# a Quarto chunk that defines the figure anchor `id`
fig_chunk <- function(id, cap = "Depth", alt = "A plot") {
  c("```{r}", paste0("#| label: ", id), paste0("#| fig-cap: \"", cap, "\""), paste0("#| fig-alt: \"", alt, "\""), "plot(1)", "```")
}

# ---- the registry ---------------------------------------------------------------------------------

test_that("3d L6: lint_rules() lists the 3d rules with their tiers", {
  r <- lint_rules()
  tier_of <- function(id) r$tier[r$id == id]
  for (id in c("cite-key", "cite-bare", "citation-key", "xref", "anchor-twice", "ref-label", "section-anchor",
               "chunk-label", "file-link", "config-place", "engine", "figure", "table-caption")) {
    expect_identical(tier_of(id), 1L, label = paste("tier of", id))
  }
  expect_identical(tier_of("anchor-unused"), 2L)
  expect_identical(tier_of("xref-code"), 2L)
})

# ---- xref: a reference to no anchor ----------------------------------------------------------------

test_that("3d L33 xref: @fig-depth with no anchor anywhere is a finding; a label in another chapter resolves it", {
  a <- c("# Results {#sec-r}", "", "See @fig-depth.")
  x <- xr(list("a.qmd" = a))
  expect_findings_shape(x)
  expect_texts(x, "xref", "fig-depth")
  r <- lf_one(x, "xref", "fig-depth")
  expect_identical(r$tier, 1L)
  expect_identical(r$spec, "5.7.1")
  expect_identical(r$file, "a.qmd")
  expect_identical(r$line, 3L)
  expect_true(r$col %in% (f3d_col(a, "@fig-depth") + 0:1))
  # the figure is defined in another chapter
  expect_none(xr(list("a.qmd" = a, "b.qmd" = c("# Data {#sec-d}", "", fig_chunk("fig-depth")))), "xref")
})

test_that("3d L33 xref: each reference form, under .qmd", {
  # one line, the ids reported
  forms <- list(
    list("See @fig-a.",                       "fig-a"),
    list("See -@fig-a.",                      "fig-a"),
    list("See (@fig-a).",                     "fig-a"),
    list("See @fig-a, and @fig-a2.",          c("fig-a", "fig-a2")),
    list("See [@fig-a; @tbl-b].",             c("fig-a", "tbl-b")),
    list("See [-@fig-a, p. 3].",              "fig-a"),
    list("See @tbl-b.",                       "tbl-b"),
    list("See @sec-c.",                       "sec-c"),
    list("See @eq-d.",                        "eq-d"),
    list("See @lst-e and @thm-f.",            c("lst-e", "thm-f")),
    list("See [the data](#nothing).",         "nothing"),
    list("See [the data](#sec-g).",           "sec-g"),
    # no reference: code, comments, e-mail
    list("See `@fig-a`.",                     character()),
    list("See <!-- @fig-a -->.",              character()),
    list("Mail me@fig-a.org.",                character())
  )
  for (f in forms) {
    x <- xr(list("a.qmd" = c("Prose.", "", f[[1]])))
    expect_texts(x, "xref", f[[2]])
    expect_true(all(x$line == 3L), label = f[[1]])
  }
})

test_that("3d L33 xref: bookdown references and anchors under .Rmd", {
  # defined: a chunk label x is also fig:x and tab:x; (\#fig:x), (\#tab:x), (\#eq:x) define their own
  chunk <- c("```{r depth, fig.cap=\"Depth\", fig.alt=\"A plot\"}", "plot(1)", "```")
  ok <- list(
    c(chunk, "", "See \\@ref(fig:depth)."),
    c(chunk, "", "See \\@ref(tab:depth)."),
    c("(\\#fig:cap) Depth", "", "See \\@ref(fig:cap)."),
    c("Table: (\\#tab:sites) Sites", "", "See \\@ref(tab:sites)."),
    c("$$x = 1$$ (\\#eq:mean)", "", "See \\@ref(eq:mean)."),
    c("# Methods {#methods}", "", "See \\@ref(methods).")
  )
  for (lines in ok) expect_none(xr(list("a.Rmd" = lines)), "xref")
  bad <- list(
    list("See \\@ref(fig:ghost).",  "fig:ghost"),
    list("See \\@ref(tab:ghost).",  "tab:ghost"),
    list("See \\@ref(eq:ghost).",   "eq:ghost"),
    list("See \\@ref(ghost).",      "ghost"),
    list("See \\@ref(fig:a) and \\@ref(tab:b).", c("fig:a", "tab:b"))
  )
  for (b in bad) {
    x <- xr(list("a.Rmd" = c("Prose.", "", b[[1]])))
    expect_texts(x, "xref", b[[2]])
    expect_true(all(x$line == 3L))
  }
})

test_that("3d L33 xref: every kind of anchor resolves a reference, in .qmd", {
  anchors <- list(
    c("## Methods {#sec-m}"),
    c("## Methods {.unnumbered #sec-m}"),
    c("::: {#sec-m}", "Some words.", ":::"),
    c("Some [words]{#sec-m} here."),
    c("![Alt words](m.png){#sec-m}"),
    c("$$", "x = 1", "$$ {#sec-m}"),
    c("| a | b |", "|---|---|", "| 1 | 2 |", "", ": Sites {#sec-m}"),
    c("```{r}", "#| label: sec-m", "x <- 1", "```"),
    c("```{r sec-m}", "x <- 1", "```"),
    c("```{r, label=\"sec-m\"}", "x <- 1", "```")
  )
  for (a in anchors) {
    expect_none(xr(list("a.qmd" = c(a, "", "See @sec-m."))), "xref")
  }
  # each kind under its own prefix
  for (id in c("fig-a", "tbl-a", "eq-a", "lst-a", "thm-a")) {
    lines <- c(paste0("::: {#", id, "}"), "Some words.", ":::", "", paste0("See @", id, "."))
    expect_none(xr(list("a.qmd" = lines)), "xref")
  }
})

test_that("3d L33 xref: a chunk label that does not start with a cross-reference prefix is no anchor", {
  lines <- c("```{r}", "#| label: depth", "x <- 1", "```", "", "See @depth-fig and @fig-depth.")
  x <- xr(list("a.qmd" = lines))
  # @depth-fig is a citation, not a cross-reference; @fig-depth is a reference to nothing
  expect_texts(x, "xref", "fig-depth")
})

test_that("3d L33 xref: a chunk with no explicit label defines nothing", {
  lines <- c("```{r}", "x <- 1", "```", "", "See @fig-unnamed-chunk-1.")
  expect_texts(xr(list("a.qmd" = lines)), "xref", "fig-unnamed-chunk-1")
})

test_that("3d L33 xref: a heading's automatic id resolves a #x link only", {
  lines <- c("## Results", "", "See [it](#results) and [it](#methods-and-data).", "", "## Methods and data")
  expect_none(xr(list("a.qmd" = lines)), "xref")
  # a reference by @ is not resolved by a heading's automatic id
  lines2 <- c("## Results", "", "See @sec-results.")
  expect_texts(xr(list("a.qmd" = lines2)), "xref", "sec-results")
})

test_that("3d L33 xref: a weft #id on a construct is no anchor", {
  lines <- c("The depth is `r x`{.num #sec-foo} m.", "", "See @sec-foo.")
  x <- xr(list("a.qmd" = lines))
  expect_texts(x, "xref", "sec-foo")
})

test_that("3d L33 xref: a .md chapter's anchors resolve references from a document, and a .md file is never linted", {
  files <- list("a.qmd" = c("See @sec-md.", "", "See @sec-gone."),
                "notes.md" = c("# Notes {#sec-md}", "", "See @sec-also-gone and [x](#nowhere)."))
  x <- xr(files)
  expect_texts(x, "xref", "sec-gone")
  expect_identical(unique(x$file), "a.qmd")
  # a .md file's own broken heading is no finding of any rule
  y <- xr(files, rules = NULL)
  expect_false("notes.md" %in% y$file)
})

test_that("3d L33 xref: a reference in a chapter resolves to an anchor in a file of a book, whatever _quarto.yml lists", {
  files <- list("_quarto.yml" = c("project:", "  type: book", "book:", "  chapters:", "    - index.qmd", "    - a.qmd"),
                "index.qmd" = c("# Home {#sec-home}", "", "See @fig-in-a, @sec-b and @sec-nowhere."),
                "a.qmd" = c("# A {#sec-a}", "", fig_chunk("fig-in-a"), "", "Back to @sec-home."),
                "b.qmd" = c("# B {#sec-b}", ""))
  x <- xr(files)
  expect_texts(x, "xref", "sec-nowhere")
  expect_identical(lf_one(x, "xref")$file, "index.qmd")
})

test_that("3d L33 xref: file#id links, to a project document", {
  # b.qmd absent: no xref (file-link reports it)
  expect_none(xr(list("a.qmd" = "See [x](b.qmd#sec-b).\n")), "xref")
  # b.qmd without sec-b
  files <- list("a.qmd" = "See [x](b.qmd#sec-b).\n", "b.qmd" = "# B {#sec-other}\n")
  x <- xr(files)
  expect_texts(x, "xref", "sec-b")
  expect_identical(x$file, "a.qmd")
  # b.qmd with sec-b
  expect_none(xr(list("a.qmd" = "See [x](b.qmd#sec-b).\n", "b.qmd" = "# B {#sec-b}\n")), "xref")
  # sec-b is in c.qmd, not in b.qmd: none in that file
  files <- list("a.qmd" = "See [x](b.qmd#sec-b).\n", "b.qmd" = "# B {#sec-other}\n", "c.qmd" = "# C {#sec-b}\n")
  expect_texts(xr(files), "xref", "sec-b")
  # the link target from a subfolder, relative to the document
  files <- list("ch/a.qmd" = "See [x](b.qmd#sec-b) and [y](../c.qmd#sec-c).\n", "ch/b.qmd" = "# B {#sec-b}\n",
                "c.qmd" = "# C {#sec-c}\n")
  expect_none(xr(files), "xref")
})

test_that("3d L33 xref: file#id to a file that is not a project document is not checked", {
  files <- list("a.qmd" = "See [x](report.pdf#page=2) and [y](page.html#top).\n", "report.pdf" = "x", "page.html" = "<p>x</p>")
  expect_none(xr(files), "xref")
})

test_that("3d L33 xref: an anchor under a files limit still counts; a finding is reported only for the files", {
  files <- list("a.qmd" = c("See @sec-b and @sec-gone-a."), "b.qmd" = c("# B {#sec-b}", "", "See @sec-gone-b."))
  root <- lint_proj(files)
  x <- lints(root, files = "a.qmd", rules = "xref", tier = 1:2)
  expect_texts(x, "xref", "sec-gone-a")
  x <- lints(root, files = "b.qmd", rules = "xref", tier = 1:2)
  expect_texts(x, "xref", "sec-gone-b")
})

test_that("3d L33 xref: position, with front matter above and a reference deep in a paragraph", {
  lines <- c("---", "title: T", "---", "", "Some words here and then @fig-depth appears.")
  x <- xr(list("a.qmd" = lines))
  expect_at(x, "xref", "fig-depth", line = 5L, col = f3d_col(lines, "@fig-depth") + 0:1)
})

# ---- anchor-twice -----------------------------------------------------------------------------------

test_that("3d L33 anchor-twice: {#sec-a} in two chapters is one finding, at the second, naming the first", {
  files <- list("a.qmd" = c("# A {#sec-a}"), "b.qmd" = c("Some words.", "", "# B {#sec-a}"))
  x <- xr(files, "anchor-twice")
  expect_findings_shape(x)
  expect_texts(x, "anchor-twice", "sec-a")
  r <- lf_one(x, "anchor-twice")
  expect_identical(r$file, "b.qmd")
  expect_identical(r$line, 3L)
  expect_identical(r$tier, 1L)
  expect_identical(r$spec, "5.7.1")
  expect_match(r$message, "a.qmd", fixed = TRUE)
  expect_match(r$message, "\\(rule 5\\.7\\.1\\)\\.$")
})

test_that("3d L33 anchor-twice: three definitions give two findings, one per later definition", {
  files <- list("a.qmd" = "# A {#sec-a}\n", "b.qmd" = "# B {#sec-a}\n", "c.qmd" = "# C {#sec-a}\n")
  x <- xr(files, "anchor-twice")
  expect_identical(sort(x$file), c("b.qmd", "c.qmd"))
})

test_that("3d L33 anchor-twice: twice in one file is a finding at the second line", {
  lines <- c("# A {#sec-a}", "", "Words.", "", "## B {#sec-a}")
  x <- xr(list("a.qmd" = lines), "anchor-twice")
  expect_at(x, "anchor-twice", "sec-a", line = 5L, col = f3d_col(lines, "#sec-a") + 0:1)
  expect_identical(nrow(x), 1L)
})

test_that("3d L33 anchor-twice: anchors of different kinds share one namespace", {
  kinds <- list(
    c("## H {#fig-x}"),
    c("::: {#fig-x}", "Words.", ":::"),
    c("Some [words]{#fig-x}."),
    c("![Alt](a.png){#fig-x}"),
    c("$$ x $$ {#fig-x}"),
    c("| a |", "|---|", "| 1 |", "", ": Cap {#fig-x}"),
    fig_chunk("fig-x")
  )
  for (i in seq_along(kinds)) for (j in seq_along(kinds)) {
    if (i == j) next
    files <- list("a.qmd" = kinds[[i]], "b.qmd" = kinds[[j]])
    x <- xr(files, "anchor-twice")
    expect_identical(nrow(x), 1L, label = sprintf("kinds %d and %d", i, j))
  }
})

test_that("3d L33 anchor-twice: a .md chapter's anchor counts", {
  files <- list("a.qmd" = "# A {#sec-a}\n", "notes.md" = "# N {#sec-a}\n")
  x <- xr(files, "anchor-twice")
  expect_identical(nrow(x), 1L)
})

test_that("3d L33 anchor-twice: two headings with the same text and no ids give no finding, nor do repeated weft #ids", {
  lines <- c("## Results", "", "Words.", "", "## Results", "", "A `r x`{.num #k} and `r y`{.num #k}.")
  expect_none(xr(list("a.qmd" = lines), "anchor-twice"))
})

test_that("3d L33 anchor-twice: .Rmd's (\\#tab:x) twice", {
  lines <- c("Table: (\\#tab:sites) A", "", "Table: (\\#tab:sites) B")
  expect_identical(nrow(xr(list("a.Rmd" = lines), "anchor-twice")), 1L)
})

test_that("3d L33 anchor-twice: findings follow the files limit; the first definition may be in another file", {
  files <- list("a.qmd" = "# A {#sec-a}\n", "b.qmd" = "# B {#sec-a}\n")
  root <- lint_proj(files)
  expect_none(lints(root, files = "a.qmd", rules = "anchor-twice", tier = 1:2))
  x <- lints(root, files = "b.qmd", rules = "anchor-twice", tier = 1:2)
  expect_identical(x$file, "b.qmd")
})

# ---- ref-label --------------------------------------------------------------------------------------

test_that("3d L33 ref-label: a governed span whose text is a reference-definition label of the document", {
  lines <- c(r"{We counted [a site | # sites]{n="k"} here.}", "", "[a site | # sites]: https://x.org")
  both <- f3_both(function(ext) xr(stats::setNames(list(lines), paste0("a.", ext)), "ref-label"))
  for (x in both) {
    expect_identical(nrow(x), 1L)
    expect_identical(x$tier, 1L)
    expect_identical(x$spec, "5.7.1")
    expect_identical(x$line, 1L)
  }
})

test_that("3d L33 ref-label: case and white space are folded; every governed kind counts", {
  spans <- c(r"{[A  Site]{n="k"}}", r"{[a site]{if="x"}}", r"{[a site]{sign="x"}}", r"{[a site]{list="x"}}",
             r"{[a site]{cite="smith2020"}}", r"{[a site]{.weft-literal why="r"}}")
  for (s in spans) {
    x <- xr(list("a.qmd" = c(paste("See", s, "here."), "", "[a SITE]: https://x.org")), "ref-label")
    expect_identical(nrow(x), 1L, label = s)
  }
})

test_that("3d L33 ref-label: the label in another document is no clash; a non-governing span is none", {
  files <- list("a.qmd" = r"{We counted [a site]{n="k"} here.}", "b.qmd" = "[a site]: https://x.org\n")
  expect_none(xr(files, "ref-label"))
  expect_none(xr(list("a.qmd" = c("We counted [a site]{.smallcaps} here.", "", "[a site]: https://x.org")), "ref-label"))
  # a governed span with no matching definition
  expect_none(xr(list("a.qmd" = c(r"{We counted [a site]{n="k"} here.}", "", "[other]: https://x.org")), "ref-label"))
})

# ---- anchor-unused (tier 2) -------------------------------------------------------------------------

test_that("3d L33 anchor-unused: a fig, tbl or eq anchor that nothing names is a tier-2 finding", {
  files <- list("a.qmd" = c(fig_chunk("fig-depth"), "", "$$ x = 1 $$ {#eq-m}", "", "| a |", "|---|", "| 1 |", "",
                            ": Sites {#tbl-s}", "", "# H {#sec-h}"))
  x <- xr(files, "anchor-unused")
  expect_findings_shape(x)
  expect_texts(x, "anchor-unused", c("fig-depth", "eq-m", "tbl-s"))
  expect_true(all(x$tier == 2L))
  expect_true(all(x$spec == "5.7.2"))
  expect_at(x, "anchor-unused", "fig-depth", line = 2L)
  expect_at(x, "anchor-unused", "eq-m", line = 8L)
})

test_that("3d L33 anchor-unused: a reference anywhere in the project, in any form, names the anchor", {
  defs <- c(fig_chunk("fig-depth"), "", "$$ x = 1 $$ {#eq-m}", "", "::: {#tbl-s}", "Words.", ":::")
  for (ref in c("See @fig-depth, @eq-m and @tbl-s.", "See [@fig-depth; @eq-m; @tbl-s].", "See -@fig-depth, -@eq-m and -@tbl-s.",
                "See [a](#fig-depth), [b](#eq-m), [c](#tbl-s).")) {
    expect_none(xr(list("a.qmd" = defs, "b.qmd" = ref), "anchor-unused"))
  }
})

test_that("3d L33 anchor-unused: an unreferenced section, theorem or listing anchor is not listed", {
  lines <- c("# H {#sec-h}", "", "::: {#thm-t}", "Words.", ":::", "", "::: {#lst-l}", "Words.", ":::")
  expect_none(xr(list("a.qmd" = lines), "anchor-unused"))
})

test_that("3d L33 anchor-unused: a reference in another chapter counts under a files limit", {
  files <- list("a.qmd" = fig_chunk("fig-depth"), "b.qmd" = "See @fig-depth.\n")
  root <- lint_proj(files)
  expect_none(lints(root, files = "a.qmd", rules = "anchor-unused", tier = 1:2))
  files2 <- list("a.qmd" = fig_chunk("fig-depth"), "b.qmd" = "Nothing here.\n")
  expect_identical(nrow(lints(lint_proj(files2), files = "a.qmd", rules = "anchor-unused", tier = 1:2)), 1L)
})

test_that("3d L33 anchor-unused: bookdown anchors fig:, tab:, eq: under .Rmd", {
  x <- xr(list("a.Rmd" = c("Table: (\\#tab:sites) Sites", "", "$$x$$ (\\#eq:mean)")), "anchor-unused")
  expect_texts(x, "anchor-unused", c("tab:sites", "eq:mean"))
  used <- c("Table: (\\#tab:sites) Sites", "", "$$x$$ (\\#eq:mean)", "", "See \\@ref(tab:sites) and \\@ref(eq:mean).")
  expect_none(xr(list("a.Rmd" = used), "anchor-unused"))
})

test_that("3d L33 anchor-unused: tier 2 is not listed at the default tier", {
  root <- lint_proj(list("a.qmd" = fig_chunk("fig-depth")))
  expect_none(lints(root, rules = "anchor-unused"))
  expect_identical(nrow(lints(root, rules = "anchor-unused", tier = 2)), 1L)
})

# ---- xref-code (tier 2) -----------------------------------------------------------------------------

test_that("3d L33 xref-code: a code span whose whole text is a reference is a tier-2 finding", {
  lines <- c("# A {#sec-a}", "", "Write `@sec-a` for it and `@fig-nothing` too.")
  x <- xr(list("a.qmd" = lines), "xref-code")
  expect_findings_shape(x)
  expect_texts(x, "xref-code", c("@sec-a", "@fig-nothing"))
  expect_true(all(x$tier == 2L))
  expect_true(all(x$line == 3L))
  expect_true(all(is.na(x$hint) | nzchar(x$hint)))
})

test_that("3d L33 xref-code: code that merely holds a reference or an e-mail is not listed", {
  for (s in c("Write `see @sec-a` here.", "Write `me@x.org` here.", "Write `@` here.", "Write @sec-a here.", "Write `x` here.")) {
    expect_none(xr(list("a.qmd" = c("# A {#sec-a}", "", s)), "xref-code"))
  }
})

test_that("3d L33 xref-code: a code span is no reference, so it does not resolve one", {
  x <- xr(list("a.qmd" = "Write `@sec-a` here.\n"), c("xref", "xref-code"))
  expect_texts(x, "xref", character())
  expect_texts(x, "xref-code", "@sec-a")
})

# ---- the rules together ------------------------------------------------------------------------------

test_that("3d L33: a project of two chapters, one reference defined in one and used in the other", {
  files <- list("a.qmd" = c("# A {#sec-a}", "", fig_chunk("fig-d"), "", "See @sec-b."),
                "b.qmd" = c("# B {#sec-b}", "", "See @fig-d and @sec-a."))
  x <- xr(files, c("xref", "anchor-twice", "anchor-unused", "ref-label", "xref-code"))
  expect_none(x)
})
