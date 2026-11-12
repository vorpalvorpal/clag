# Package 3c: tar-name, dict-assign, dict-key, tar-cache, above-setup (5.8 rules 2, 3, 5, 6, 7).
# Contract: dev/design-3.md L34 (and K9, R3), the table of section L35 for these rows.
# Helpers: helper-3.R, helper-3c.R.

# a project with `doc.<ext>` and extra files, linted for one rule; returns the findings
h_lint <- function(doc, rule, ext = "qmd", extra = list(), weft_yml = NULL, env = parent.frame()) {
  files <- c(stats::setNames(list(doc), paste0("doc.", ext)), extra)
  lint_fixture(files, rules = rule, weft_yml = weft_yml, env = env)
}
h_texts <- function(...) { x <- h_lint(...); x$text }

# a document with one chunk (R, executed) holding `code`
h_doc <- function(code, ...) c(c3_para("Intro."), c3_chunk(code, ...))

# ---- tar-name (L34, K9, R3) -----------------------------------------------------------------

test_that("3c tar-name: each reading form names a target; absent ones are findings, present ones not", {
  skip_if_not_installed("targets")
  skip_on_cran()
  forms <- list(
    list(code = "x <- tar_read(NAME)",                 want = "NAME"),
    list(code = "tar_load(NAME)",                      want = "NAME"),
    list(code = "tar_load(c(fit, NAME))",              want = "NAME"),
    list(code = "tar_load(c(NAME, nope2))",            want = c("NAME", "nope2")),
    list(code = "x <- tar_read_raw(\"NAME\")",         want = "NAME"),
    list(code = "tar_load_raw(\"NAME\")",              want = "NAME"),
    list(code = "x <- targets::tar_read(NAME)",        want = "NAME"),
    list(code = "targets::tar_load(NAME)",             want = "NAME"),
    list(code = "targets::tar_read_raw(\"NAME\")",     want = "NAME")
  )
  for (ext in c("qmd", "Rmd")) {
    root <- lint_proj(list())
    c3_store(root, c("fit", "dat"))
    for (f in forms) {
      code <- gsub("NAME", "fitt", f$code, fixed = TRUE)
      want <- gsub("NAME", "fitt", f$want, fixed = TRUE)
      writeLines(h_doc(code), file.path(root, paste0("doc.", ext)))
      x <- lints(root, rules = "tar-name", tier = 1:2)
      expect_identical(sort(x$text), sort(want), label = paste0("[", ext, "] ", code))
      # the same form naming a present target is silent
      writeLines(h_doc(gsub("NAME", "fit", f$code, fixed = TRUE)), file.path(root, paste0("doc.", ext)))
      x <- lints(root, rules = "tar-name", tier = 1:2)
      expect_false("fit" %in% x$text, label = paste0("[", ext, "] present: ", f$code))
    }
    unlink(file.path(root, paste0("doc.", ext)))
  }
})

test_that("3c tar-name: tier 1, spec, context chunk and the line of the call", {
  skip_if_not_installed("targets")
  skip_on_cran()
  root <- lint_proj(list("doc.qmd" = h_doc(c("a <- 1", "x <- tar_read(fitt)"))))
  c3_store(root, c("fit"))
  x <- lints(root, rules = "tar-name", tier = 1:2)
  expect_findings_shape(x)
  r <- lf_one(x, "tar-name", "fitt")
  expect_identical(r$tier, 1L)
  expect_identical(r$context, "chunk")
  expect_identical(r$line, 8L)
  expect_identical(r$spec, lint_rules()$spec[lint_rules()$id == "tar-name"])
  expect_match(r$message, "(rule 5.8.2).", fixed = TRUE)   # 5.8 rule 2 (ASSUMPTION: spec reads 5.8.2)
})

test_that("3c tar-name: reads in inline expressions and governor expressions are checked too", {
  skip_if_not_installed("targets")
  skip_on_cran()
  doc <- c3_para("Value `r tar_read(nope)` and `r tar_read(fit)`.",
                 r"---(And [a | b]{if="tar_read(nope2) > 1"} and [a | b]{if="tar_read(fit) > 1"}.)---")
  for (ext in c("qmd", "Rmd")) {
    root <- lint_proj(stats::setNames(list(doc), paste0("doc.", ext)))
    c3_store(root, "fit")
    x <- lints(root, rules = "tar-name", tier = 1:2)
    expect_identical(sort(x$text), c("nope", "nope2"), label = ext)
    expect_true(all(x$context == "prose"))
  }
})

test_that("3c tar-name: the store is the literal store=, else _targets.yaml's main: store:, else _targets", {
  skip_if_not_installed("targets")
  skip_on_cran()
  # a literal store=, from the root
  root <- lint_proj(list("doc.qmd" = h_doc(c("a <- tar_read(alt1, store = \"alt\")",
                                              "b <- tar_read(fit, store = \"alt\")",
                                              "c <- tar_read(fit)"))))
  c3_store(root, "fit")
  c3_store(root, "alt1", store = "alt")
  x <- lints(root, rules = "tar-name", tier = 1:2)
  expect_identical(x$text, "fit")
  expect_identical(x$line, 8L)                # only the read from the `alt` store
  # _targets.yaml names the store
  root <- lint_proj(list("doc.qmd" = h_doc(c("a <- tar_read(onlyhere)", "b <- tar_read(fit)")),
                         "_targets.yaml" = c("main:", "  store: mystore")))
  c3_store(root, "fit")                      # the default store holds `fit`, but it is not the store
  c3_store(root, "onlyhere", store = "mystore")
  x <- lints(root, rules = "tar-name", tier = 1:2)
  expect_identical(x$text, "fit")
  expect_identical(x$line, 8L)
})

test_that("3c tar-name: no store gives a note and no finding; targets are not required to be built by the lint", {
  root <- lint_proj(list("doc.qmd" = h_doc("x <- tar_read(anything)")))
  x <- lints(root, rules = "tar-name", tier = 1:2)
  expect_equal(nrow(x), 0L)
  notes <- attr(x, "notes")
  expect_gte(length(notes), 1L)
  expect_true(any(grepl("store|target", notes, ignore.case = TRUE)))
})

test_that("3c tar-name: the lint runs no project code (a _targets.R is not sourced)", {
  skip_if_not_installed("targets")
  skip_on_cran()
  root <- lint_proj(list("doc.qmd" = h_doc("x <- tar_read(fitt)"),
                         "_targets.R" = c("writeLines('ran', 'SENTINEL')", "list()"),
                         "dict.yml" = C3_DICT))
  c3_store(root, "fit")
  expect_false(file.exists(file.path(root, "SENTINEL")))
  x <- lints(root, rules = "tar-name", tier = 1:2)
  expect_identical(x$text, "fitt")
  expect_false(file.exists(file.path(root, "SENTINEL")))
})

test_that("3c tar-name: not read in an eval: false chunk or a non-R chunk", {
  skip_if_not_installed("targets")
  skip_on_cran()
  root <- lint_proj(list())
  c3_store(root, "fit")
  for (chunk in list(c3_chunk("x <- tar_read(nope)", "#| eval: false"),
                     c("```{r, eval=FALSE}", "x <- tar_read(nope)", "```"),
                     c3_chunk("x = tar_read(nope)", engine = "python"))) {
    writeLines(c(c3_para("Intro."), chunk), file.path(root, "doc.qmd"))
    x <- lints(root, rules = "tar-name", tier = 1:2)
    expect_equal(nrow(x), 0L, label = paste(chunk, collapse = " / "))
  }
})

test_that("3c tar-name: a chunk that does not parse is skipped, and a non-literal name is not guessed", {
  skip_if_not_installed("targets")
  skip_on_cran()
  root <- lint_proj(list("doc.qmd" = c(h_doc(c("x <- tar_read(nope)", "y <- (")),
                                       h_doc(c("nm <- 'a'", "tar_read_raw(nm)", "tar_load(all_of(nm))")))))
  c3_store(root, "fit")
  x <- lints(root, rules = "tar-name", tier = 1:2)
  expect_equal(nrow(x), 0L)
})

test_that("3c L6: lint_rules() lists the 3c hygiene rules at tier 1", {
  lr <- lint_rules()
  for (id in c("tar-name", "dict-assign", "dict-key", "tar-cache", "above-setup")) {
    expect_true(id %in% lr$id, label = id)
    expect_identical(lr$tier[lr$id == id], 1L, label = paste("tier of", id))
  }
})

# ---- dict-assign -------------------------------------------------------------------------------

ASSIGN_CASES <- list(
  list(code = "dict <- read_dict(\"dict.yml\")",  want = "dict"),
  list(code = "dict$lim <- 5",                     want = "dict$lim"),
  list(code = "dict = list()",                     want = "dict"),
  list(code = "5 -> dict",                         want = "dict"),
  list(code = "dict <<- x",                        want = "dict"),
  list(code = "x ->> dict",                        want = "dict"),
  list(code = "dict[[\"k\"]] <- 1",                want = "dict[[\"k\"]]"),
  list(code = "names(dict) <- c(\"a\")",           want = "names(dict)"),
  list(code = "dict$a$b <- 1",                     want = "dict$a$b"),
  list(code = "dict[[\"a\"]]$b <- 1",              want = "dict[[\"a\"]]$b"),
  list(code = "my_dict <- 1",                      want = character()),
  list(code = "dict_local$a <- 1",                 want = character()),
  list(code = "dict2 <- 1",                        want = character()),
  list(code = "dict.k <- 1",                       want = character()),
  list(code = "x <- dict$a",                       want = character()),
  list(code = "y$dict <- 1",                       want = character()),
  list(code = "assign(\"other\", 1)",              want = character()),
  list(code = "f(dict)",                           want = character()),
  list(code = "x <- list(dict = 1)",               want = character()),
  list(code = "dict == 1",                         want = character()),
  list(code = "x <- dict",                         want = character())
)

test_that("3c dict-assign: each assignment form and its near misses (qmd and Rmd)", {
  for (cs in ASSIGN_CASES) expect_c3(h_doc(cs$code), "dict-assign", cs$want, label = cs$code)
})

test_that("3c dict-assign: assign(\"dict\", ...) is an assignment to dict", {
  for (ext in c("qmd", "Rmd")) {
    x <- lint_one(h_doc("assign(\"dict\", x)"), rules = "dict-assign", ext = ext)
    expect_equal(nrow(x), 1L, label = ext)
    expect_true(x$text %in% c("dict", "\"dict\""), label = ext)   # ASSUMPTION: the target's name
  }
})

test_that("3c dict-assign: tier 1, spec, context chunk, line and column", {
  doc <- h_doc(c("a <- 1", "  dict$lim <- 5"))
  for (ext in c("qmd", "Rmd")) {
    x <- lint_one(doc, rules = "dict-assign", ext = ext)
    expect_findings_shape(x)
    r <- lf_one(x, "dict-assign", "dict$lim")
    expect_identical(r$tier, 1L)
    expect_identical(r$context, "chunk")
    expect_identical(c(r$line, r$col), c(8L, 3L))
    expect_identical(r$spec, lint_rules()$spec[lint_rules()$id == "dict-assign"])
    expect_match(r$message, "(rule 5.8.3).", fixed = TRUE)   # ASSUMPTION: spec 5.8.3
  }
})

test_that("3c dict-assign: the design's table row, both lines in one chunk", {
  doc <- h_doc(c("dict <- read_dict(\"dict.yml\")", "dict$lim <- 5"))
  x <- lint_one(doc, rules = "dict-assign")
  expect_identical(lf_texts(x), c("dict", "dict$lim"))
  expect_identical(lf_lines(x), c(7L, 8L))
})

test_that("3c dict-assign: not in an eval: false chunk, a non-R chunk, prose, or a chunk that does not parse", {
  expect_c3(h_doc("dict <- 1", "#| eval: false"), "dict-assign", character())
  expect_c3(c(c3_para("Intro."), "```{r, eval=FALSE}", "dict <- 1", "```"), "dict-assign", character())
  expect_c3(h_doc("dict = 1", engine = "python"), "dict-assign", character())
  expect_c3(c3_para("The code `dict <- 1` assigns."), "dict-assign", character())
  expect_c3(c("T.", "", "```", "dict <- 1", "```"), "dict-assign", character())
  expect_c3(h_doc(c("dict <- 1", "z <- (")), "dict-assign", character())
})

# ---- dict-key ----------------------------------------------------------------------------------

dk_texts <- function(body, ext = "qmd", dict = C3_DICT, front = NULL, extra = list()) {
  doc <- if (is.null(front)) c3_para(body) else c(front, "", body)
  files <- c(stats::setNames(list(doc), paste0("doc.", ext)), extra)
  if (!is.null(dict)) files <- c(files, list("dict.yml" = dict))
  x <- lint_fixture(files, rules = "dict-key")
  x$text
}

test_that("3c dict-key: reads of a key that dict.yml does not hold, in every form (qmd and Rmd)", {
  for (ext in c("qmd", "Rmd")) {
    expect_identical(dk_texts("`r dict$limt`", ext), "limt", label = ext)
    expect_identical(dk_texts("`r dict$limit`", ext), character(), label = ext)
    expect_identical(dk_texts("`r dict$sites`", ext), character(), label = ext)
    # in chunk code, each of the four forms
    for (f in c("dict$limt", "dict$\"limt\"", "dict[[\"limt\"]]", "dict[['limt']]")) {
      doc <- h_doc(paste0("x <- ", f))
      expect_identical(h_texts(doc, "dict-key", ext, extra = list("dict.yml" = C3_DICT)), "limt",
                       label = paste(ext, f))
    }
    for (f in c("dict$limit", "dict$\"sites\"", "dict[[\"limit\"]]", "dict[['sites']]")) {
      doc <- h_doc(paste0("x <- ", f))
      expect_identical(h_texts(doc, "dict-key", ext, extra = list("dict.yml" = C3_DICT)), character(),
                       label = paste(ext, f))
    }
  }
})

test_that("3c dict-key: only the top-level key is checked", {
  expect_identical(dk_texts("`r dict$limit$value` and `r dict$limit$bogus`"), character())
  expect_identical(dk_texts("`r dict$limt$value`"), "limt")
})

test_that("3c dict-key: the message suggests the nearest key", {
  x <- lint_fixture(list("doc.qmd" = c3_para("`r dict$limt`"), "dict.yml" = C3_DICT),
                                     rules = "dict-key")
  r <- lf_one(x, "dict-key", "limt")
  expect_match(r$message, "Did you mean", fixed = TRUE)
  expect_match(r$message, "limit", fixed = TRUE)
  expect_identical(r$tier, 1L)
  expect_identical(r$context, "prose")
  expect_identical(r$line, 3L)
  expect_identical(r$spec, lint_rules()$spec[lint_rules()$id == "dict-key"])
  expect_match(r$message, "(rule 5.8.6).", fixed = TRUE)   # ASSUMPTION: spec 5.8.6
})

test_that("3c dict-key: position of the key in a chunk and in prose", {
  x <- lint_fixture(list("doc.qmd" = c(c3_para("Ab `r dict$limt` cd."),
                                       c3_chunk(c("a <- 1", "  y <- dict$limt"))),
                         "dict.yml" = C3_DICT), rules = "dict-key")
  expect_identical(lf_lines(x), c(3L, 8L))
  expect_identical(x$context, c("prose", "chunk"))
  # ASSUMPTION: the finding starts at the key (the `text`), as for every lint
  expect_identical(lf_cols(x), c(12L, 13L))
})

test_that("3c dict-key: a key that the document also defines locally is ambiguous; dict_local needs a local key", {
  front <- c("---", "title: T", "weft:", "  dict_local:", "    x:", "      value: 1", "      why: local", "---")
  # dict$x where the chapter defines a local x (and dict.yml does not hold it)
  expect_identical(dk_texts("`r dict$x`", front = front), "x")
  # even when dict.yml holds x as well
  expect_identical(dk_texts("`r dict$x`", front = front, dict = c(C3_DICT, "x:", "  value: 2")), "x")
  # dict_local$x is right; dict_local$y has no local y
  expect_identical(dk_texts("`r dict_local$x`", front = front), character())
  expect_identical(dk_texts("`r dict_local$y`", front = front), "y")
  # both in one chunk
  doc <- h_doc(c("a <- dict$x", "b <- dict_local$y", "c <- dict_local$x", "d <- dict$limit"))
  x <- lint_fixture(list("doc.qmd" = c(front, "", doc), "dict.yml" = C3_DICT), rules = "dict-key")
  expect_identical(sort(x$text), c("x", "y"))
  # a document with no weft: block has no local entries
  expect_identical(dk_texts("`r dict_local$z`"), "z")
  # a plain dict key is not ambiguous without a local one
  expect_identical(dk_texts("`r dict$limit`"), character())
})

test_that("3c dict-key: with no dict.yml every dict$ read is a finding", {
  for (ext in c("qmd", "Rmd")) {
    expect_identical(dk_texts("`r dict$limit`", ext, dict = NULL), "limit", label = ext)
    expect_identical(sort(dk_texts("`r dict$a` and `r dict$b`", ext, dict = NULL)), c("a", "b"), label = ext)
    expect_identical(h_texts(h_doc("x <- dict[[\"k\"]]"), "dict-key", ext), "k", label = ext)
  }
  # no read at all, no finding
  expect_identical(dk_texts("Plain prose.", dict = NULL), character())
})

test_that("3c dict-key: not read in a non-R chunk, a code span without R, or a fence", {
  expect_identical(h_texts(h_doc("x = d['dict$limt']", engine = "python"), "dict-key",
                           extra = list("dict.yml" = C3_DICT)), character())
  expect_identical(dk_texts("The code `dict$limt` reads."), character())
  doc <- c("T.", "", "```", "dict$limt", "```")
  expect_identical(h_texts(doc, "dict-key", extra = list("dict.yml" = C3_DICT)), character())
})

# ---- tar-cache ---------------------------------------------------------------------------------

tc_texts <- function(chunks, front = NULL, ext = "qmd", extra = list()) {
  doc <- c(front, if (!is.null(front)) "", c3_para("Intro."), chunks)
  h_texts(doc, "tar-cache", ext, extra = extra)
}
READ_FIT <- "x <- tar_read(fit)"
FM_EXEC_CACHE <- c("---", "title: T", "execute:", "  cache: true", "---")

test_that("3c tar-cache: a chunk's own cache option, option and header forms (qmd and Rmd)", {
  for (ext in c("qmd", "Rmd")) {
    expect_identical(tc_texts(c3_chunk(READ_FIT, "#| cache: true"), ext = ext), "fit", label = ext)
    expect_identical(tc_texts(c("```{r, cache=TRUE}", READ_FIT, "```"), ext = ext), "fit", label = ext)
    expect_identical(tc_texts(c3_chunk(READ_FIT), ext = ext), character(), label = ext)
    expect_identical(tc_texts(c3_chunk(READ_FIT, "#| cache: false"), ext = ext), character(), label = ext)
    # cache on, no target read
    expect_identical(tc_texts(c3_chunk("x <- 1", "#| cache: true"), ext = ext), character(), label = ext)
    # every target read in a chunk is a finding
    expect_setequal(tc_texts(c3_chunk("tar_load(c(fit, dat))", "#| cache: true"), ext = ext), c("fit", "dat"))
    for (fn in c("tar_load(fit)", "tar_read_raw(\"fit\")", "tar_load_raw(\"fit\")", "targets::tar_read(fit)")) {
      expect_identical(tc_texts(c3_chunk(fn, "#| cache: true"), ext = ext), "fit", label = paste(ext, fn))
    }
  }
})

test_that("3c tar-cache: an earlier literal knitr::opts_chunk$set(cache = TRUE)", {
  setup <- c3_chunk("knitr::opts_chunk$set(cache = TRUE)")
  expect_identical(tc_texts(c(setup, "", c3_chunk(READ_FIT))), "fit")
  # a chunk's own false wins
  expect_identical(tc_texts(c(setup, "", c3_chunk(READ_FIT, "#| cache: false"))), character())
  # set after the chunk, set to something not literal, set to FALSE: no
  expect_identical(tc_texts(c(c3_chunk(READ_FIT), "", setup)), character())
  expect_identical(tc_texts(c(c3_chunk("knitr::opts_chunk$set(cache = flag)"), "", c3_chunk(READ_FIT))), character())
  expect_identical(tc_texts(c(c3_chunk("knitr::opts_chunk$set(cache = FALSE)"), "", c3_chunk(READ_FIT))), character())
  # a later FALSE turns it off again
  expect_identical(tc_texts(c(setup, "", c3_chunk("knitr::opts_chunk$set(cache = FALSE)"), "",
                              c3_chunk(READ_FIT))), character())
  for (ext in c("qmd", "Rmd")) {
    expect_identical(tc_texts(c(setup, "", c3_chunk(READ_FIT)), ext = ext), "fit", label = ext)
  }
})

test_that("3c tar-cache: front matter, then _quarto.yml and _metadata.yml, each level on its own", {
  chunk <- c3_chunk(READ_FIT)
  # front matter execute: cache: true
  expect_identical(tc_texts(chunk, front = FM_EXEC_CACHE), "fit")
  # front matter knitr: opts_chunk: cache: true
  expect_identical(tc_texts(chunk, front = c("---", "title: T", "knitr:", "  opts_chunk:", "    cache: true", "---")),
                   "fit")
  # a chunk false over a document true
  expect_identical(tc_texts(c3_chunk(READ_FIT, "#| cache: false"), front = FM_EXEC_CACHE), character())
  # the document's false does not count
  expect_identical(tc_texts(chunk, front = c("---", "title: T", "execute:", "  cache: false", "---")), character())
  # _quarto.yml
  expect_identical(tc_texts(chunk, extra = list("_quarto.yml" = c("project:", "  type: default", "execute:", "  cache: true"))),
                   "fit")
  expect_identical(tc_texts(chunk, extra = list("_quarto.yml" = c("execute:", "  cache: false"))), character())
  # _metadata.yml of the document's folder
  doc <- c(c3_para("Intro."), chunk)
  x <- lint_fixture(list("sub/doc.qmd" = doc, "sub/_metadata.yml" = c("execute:", "  cache: true")), rules = "tar-cache")
  expect_identical(x$text, "fit")
  # a _metadata.yml of another folder is not this document's
  x <- lint_fixture(list("sub/doc.qmd" = doc, "other/_metadata.yml" = c("execute:", "  cache: true")), rules = "tar-cache")
  expect_equal(nrow(x), 0L)
})

test_that("3c tar-cache: the design's row with tar-name; tier 1; context chunk; the line of the read", {
  skip_if_not_installed("targets")
  skip_on_cran()
  doc <- c(c3_para("Intro."),
           c3_chunk(READ_FIT, "#| cache: true"), "",
           c3_chunk("y <- tar_read(fitt)"))
  root <- lint_proj(list("doc.qmd" = doc))
  c3_store(root, "fit")
  x <- lints(root, rules = c("tar-cache", "tar-name"), tier = 1:2)
  expect_identical(paste(x$rule, x$text), c("tar-cache fit", "tar-name fitt"))
  r <- x[x$rule == "tar-cache", ]
  expect_identical(r$tier, 1L)
  expect_identical(r$context, "chunk")
  expect_identical(r$line, 8L)
  expect_identical(r$spec, lint_rules()$spec[lint_rules()$id == "tar-cache"])
  expect_match(r$message, "(rule 5.8.7).", fixed = TRUE)   # ASSUMPTION: spec 5.8.7
})

test_that("3c tar-cache: not read in an eval: false chunk or a non-R chunk", {
  expect_identical(tc_texts(c3_chunk(READ_FIT, "#| cache: true", "#| eval: false")), character())
  expect_identical(tc_texts(c3_chunk("x = tar_read(fit)", "#| cache: true", engine = "python")), character())
})

# ---- above-setup -------------------------------------------------------------------------------

test_that("3c above-setup: a construct above a setup chunk is a finding at its line (the design's row)", {
  # setup chunk at line 20, construct at line 10
  lines <- rep("Filler.", 25)
  lines[1:3] <- c("---", "title: T", "---")
  lines[4] <- ""
  lines[10] <- r"---([a]{if="x"})---"
  lines[19] <- ""
  lines[20:22] <- c("```{r}", "weft::weft_setup()", "```")
  for (ext in c("qmd", "Rmd")) {
    x <- lint_one(lines, rules = "above-setup", ext = ext)
    expect_identical(lf_lines(x), 10L, label = ext)
    r <- lf_one(x, "above-setup")
    expect_identical(r$tier, 1L)
    expect_identical(r$context, "prose")
    expect_identical(r$spec, lint_rules()$spec[lint_rules()$id == "above-setup"])
    expect_match(r$message, "(rule 5.8.5).", fixed = TRUE)   # ASSUMPTION: spec 5.8.5
  }
  # the same with weft_setup() unqualified
  lines[21] <- "weft_setup()"
  expect_identical(lf_lines(lint_one(lines, rules = "above-setup")), 10L)
})

test_that("3c above-setup: every row kind above the chunk but bare values (and links) is a finding", {
  lines <- c("---", "title: T", "---", "",
             r"---(One [a]{if="x"} two.)---", "",                        # 5
             "Two `r x`{.num} here.", "",                                # 7
             r"---(Three [a | b]{n="k"} here.)---", "",                  # 9
             "Four `r x` bare.", "",                                     # 11: bare, not a finding
             "Five [1]{.weft-literal why=\"z\"} here.", "",              # 13: a literal row
             "```{r}", "weft::weft_setup()", "```", "",                  # 15-18
             r"---(After [a]{if="x"} the chunk.)---")                    # 20: below, not a finding
  for (ext in c("qmd", "Rmd")) {
    x <- lint_one(lines, rules = "above-setup", ext = ext)
    expect_identical(lf_lines(x), c(5L, 7L, 9L, 13L), label = ext)
  }
})

test_that("3c above-setup: front matter above the chunk is included", {
  lines <- c("---", "title: T", "abstract: |", "  Text `r x`{.num} here.", "---", "",
             "```{r}", "weft::weft_setup()", "```")
  x <- lint_one(lines, rules = "above-setup")
  expect_identical(lf_lines(x), 4L)
  expect_identical(lf_one(x, "above-setup")$context, "front-matter")
})

test_that("3c above-setup: the front-matter route and the .Rprofile route each stop the rule", {
  body <- c("", r"---(Para [a]{if="x"} here.)---", "", "```{r}", "weft::weft_setup()", "```")
  # no route: a finding
  expect_identical(lf_lines(lint_one(c("---", "title: T", "---", body), rules = "above-setup")), 5L)
  # front-matter route
  fm <- c("---", "title: T", "knitr:", "  opts_knit:", "    weft: !expr weft::weft_setup()", "---")
  expect_equal(nrow(lint_one(c(fm, body), rules = "above-setup")), 0L)
  # .Rprofile route
  rp <- list("doc.qmd" = c("---", "title: T", "---", body),
             ".Rprofile" = "if (requireNamespace(\"weft\", quietly = TRUE)) weft::weft_setup()")
  expect_equal(nrow(lint_fixture(rp, rules = "above-setup")), 0L)
  # an .Rprofile that does not call weft_setup is no route
  rp[[".Rprofile"]] <- "options(digits = 4)"
  expect_identical(lf_lines(lint_fixture(rp, rules = "above-setup")), 5L)
  # the same under .Rmd
  rp2 <- list("doc.Rmd" = c(fm, body), ".Rprofile" = "weft::weft_setup()")
  expect_equal(nrow(lint_fixture(rp2, rules = "above-setup")), 0L)
})

test_that("3c above-setup: nothing without a setup chunk that calls weft_setup()", {
  # no chunk at all
  expect_equal(nrow(lint_one(c(c3_para(r"---(A [a]{if="x"} b.)---")), rules = "above-setup")), 0L)
  # a chunk that only attaches the package (9.2.6: not a route)
  doc <- c(c3_para(r"---(A [a]{if="x"} b.)---"), c3_chunk("library(weft)"))
  expect_equal(nrow(lint_one(doc, rules = "above-setup")), 0L)
  # constructs below the setup chunk only
  doc <- c(c3_chunk("weft::weft_setup()"), "", r"---(A [a]{if="x"} b.)---")
  expect_equal(nrow(lint_one(doc, rules = "above-setup")), 0L)
})

test_that("3c L6/L14: rules = names every 3c id without error and a clean document gives no findings", {
  ids <- names(R3C_TIER)
  x <- lint_one(c("# Title {#sec-t}", "", "Plain prose with no values."), rules = ids)
  expect_equal(nrow(x), 0L)
  expect_findings_shape(x)
})
