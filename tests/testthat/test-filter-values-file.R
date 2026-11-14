# Package 6i: a values file read by the filter (dev/design-6.md N30, N28, N31, N24, N25, N26, N27, E32,
# and the file hashes of N112's ledger header). The files are written by hand (schema 1, N20 to N23)
# into the temporary project by filter_md(); plain Pandoc, weft.lua then weft-check.lua. ASCII only.
# Today a block with `file=` is a construct error, so the tests that read a file fail on that.

draft1 <- c(WEFT_DRAFT = "1")

# a values-file block: four backticks, class weft-values, a file attribute, an empty body (N30)
fv_block <- function(path, attrs = NULL) {
  a <- if (is.null(attrs)) sprintf('{.weft-values file="%s"}', path) else attrs
  c(paste0("````", a), "````")
}
# the text of a values file
fv_file <- function(..., members = NULL) carrier_json(..., members = members)
fv_use <- function(...) paste0("Use ", paste(sprintf("`%s`{.val}", c(...)), collapse = " "), ".")
fv_paras <- function(res) strsplit(trimws(res$output), "\n\n", fixed = TRUE)[[1]]

# E32's text with {reason} left open (the design does not fix it)
fv_e32 <- function(path) sprintf("^the values file %s cannot be read: .+ \\(rule 2\\.13\\.10\\)\\.$",
                                 gsub("([][{}()+*^$|\\\\?.])", "\\\\\\1", path))
fv_e12 <- "^a weft-values block that does not read: .+ \\(rule 2\\.13\\.1\\)\\.$"

# the entry of the first construct error in a report
fv_cerr <- function(res) fm_entry(res$stderr, "\\[construct error\\]")

SURVEY <- "_weft/values/survey.json"

# ---- controls that hold today -------------------------------------------------------------------------

test_that("control: a block without `file` still publishes, and a non-weft block with `file=` is code", {
  md <- c(carrier(d = fr_int("7")), "", "```{.json file=\"nope.json\"}", "{}", "```", "", fv_use("d"))
  res <- filter_md(md, to = "plain")
  expect_identical(res$status, 0L)
  expect_false(grepl("weft:", res$stderr, fixed = TRUE))
  expect_match(res$output, "Use 7.", fixed = TRUE)
  expect_match(res$output, "{}", fixed = TRUE)
})

# ---- N30: reading a file ------------------------------------------------------------------------------

test_that("N30, N31: a block with `file` and an empty body reads the file; the block leaves no trace", {
  files <- setNames(list(fv_file(depth = fr_float("3.14159"), n = fr_int("4"))), SURVEY)
  md <- c(fv_block(SURVEY), "", "Depth `depth`{.val} n `n`{.val}.")
  res <- filter_md(md, files = files)
  expect_identical(res$status, 0L)
  expect_identical(trimws(res$output), "<p>Depth 3.14159 n 4.</p>")
  expect_identical(res$stderr, "")
})

test_that("N30: the schema-1 members other than values (lang, run, at, cell, unknown) are ignored in a file", {
  files <- setNames(list(fv_file(d = fr_int("7"), members = paste0(
    '"lang":"none","run":null,"at":null,"cell":null,"future":{"x":[1]}'))), SURVEY)
  res <- filter_md(c(fv_block(SURVEY), "", fv_use("d")), files = files)
  expect_identical(res$status, 0L)
  expect_identical(trimws(res$output), "<p>Use 7.</p>")
})

test_that("N30, N20: other classes and attributes on the block are ignored, and the block may sit in a div or a quote", {
  files <- setNames(list(fv_file(a = fr_int("1"), b = fr_int("2"), c = fr_int("3"))), SURVEY)
  md <- c(fv_block(SURVEY, attrs = sprintf('{#vals .weft-values .extra data-x="y" file="%s"}', SURVEY)), "",
          "::: {.cell}", fv_block(SURVEY), ":::", "",
          paste0("> ", fv_block(SURVEY)), "",
          fv_use("a", "b", "c"))
  res <- filter_md(md, files = files, to = "plain")
  expect_identical(res$status, 0L)
  expect_identical(trimws(res$output), "Use 1 2 3.")
})

test_that("N30: a file with no values is read and adds nothing", {
  files <- setNames(list('{"weft":1,"values":{}}'), SURVEY)
  res <- filter_md(c(fv_block(SURVEY), "", "Plain text."), files = files)
  expect_identical(res$status, 0L)
  expect_identical(trimws(res$output), "<p>Plain text.</p>")
  expect_identical(res$stderr, "")
})

test_that("N30, N25, N90: the file is read where the block stands; a use above it takes the value published below (one value), a use below prints", {
  files <- setNames(list(fv_file(depth = fr_int("7"))), SURVEY)
  md <- c(fv_use("depth"), "", fv_block(SURVEY), "", "Below `depth`{.val} m.")
  res <- filter_md(md, files = files, to = "plain", env = draft1)
  expect_identical(res$status, 0L)
  # N90: the use above the block takes the one value the document publishes below
  expect_identical(fv_paras(res), c("Use 7.", "Below 7 m."))
  expect_false(grepl("no value", res$stderr, fixed = TRUE))
  # N94, E42: a name published nowhere is still no value
  res2 <- filter_md(c(fv_use("nowhere"), "", fv_block(SURVEY)), files = files, to = "plain", env = draft1)
  expect_identical(fv_paras(res2), "Use <<weft: no value, line 1>>.")
  expect_match(res2$stderr, f7_msg$E42("nowhere"), fixed = TRUE)
  expect_match(fm_headings(res2$stderr), rx_failures(1), all = FALSE)
})

test_that("N25, N26: a file block and in-document blocks publish in document order; the later replaces the earlier", {
  files <- list("_weft/values/one.json" = fv_file(x = fr_int("2"), only_file = fr_int("20")),
                "_weft/values/two.json" = fv_file(x = fr_int("5")))
  md <- c(carrier(x = fr_int("1"), only_doc = fr_int("10")), "",
          "A `x`{.val}.", "",
          fv_block("_weft/values/one.json"), "",
          "B `x`{.val} `only_doc`{.val} `only_file`{.val}.", "",
          carrier(x = fr_int("3")), "",
          "C `x`{.val}.", "",
          fv_block("_weft/values/two.json"), "",
          "D `x`{.val} `only_file`{.val}.")
  res <- filter_md(md, files = files, to = "plain")
  expect_identical(res$status, 0L)
  expect_identical(fv_paras(res), c("A 1.", "B 2 10 20.", "C 3.", "D 5 20."))
})

test_that("N26, N81: the title sees the last value, whether it came from a file or a block", {
  files <- setNames(list(fv_file(depth = fr_int("2"))), SURVEY)
  md <- c("---", 'title: "T `depth`{.val}"', "---", "", carrier(depth = fr_int("1")), "",
          "One `depth`{.val}.", "", fv_block(SURVEY), "", "Two `depth`{.val}.")
  res <- filter_md(md, files = files, to = "plain", args = "-s")
  expect_identical(res$status, 0L)
  expect_match(res$output, "T 2", fixed = TRUE)
  expect_match(res$output, "One 1.", fixed = TRUE)
  expect_match(res$output, "Two 2.", fixed = TRUE)
})

test_that("N30: the file is read afresh at each render, so a changed file gives the changed value", {
  md <- c(fv_block(SURVEY), "", fv_use("d"))
  r1 <- filter_md(md, files = setNames(list(fv_file(d = fr_int("1"))), SURVEY), to = "plain")
  r2 <- filter_md(md, files = setNames(list(fv_file(d = fr_int("2"))), SURVEY), to = "plain")
  expect_identical(trimws(r1$output), "Use 1.")
  expect_identical(trimws(r2$output), "Use 2.")
})

test_that("N30: the same file read twice in one document is not an error", {
  files <- setNames(list(fv_file(d = fr_int("7"))), SURVEY)
  md <- c(fv_block(SURVEY), "", fv_use("d"), "", fv_block(SURVEY), "", fv_use("d"))
  res <- filter_md(md, files = files, to = "plain")
  expect_identical(res$status, 0L)
  expect_identical(fv_paras(res), c("Use 7.", "Use 7."))
  expect_identical(res$stderr, "")
})

# ---- N30: the path forms -------------------------------------------------------------------------------

test_that("N30: a relative path is relative to the document's folder, not the working folder or the project root", {
  files <- list("ch1/data/v.json" = fv_file(d = fr_int("11")),
                "data/v.json" = fv_file(d = fr_int("99")))
  md <- c(fv_block("data/v.json"), "", fv_use("d"))
  for (run_in in c(".", "ch1")) {
    res <- filter_md(md, files = files, name = "ch1/doc.md", run_in = run_in, weft_yml = "draft: false",
                     to = "plain")
    expect_identical(res$status, 0L, label = paste("status, run in", run_in))
    expect_identical(trimws(res$output), "Use 11.", label = paste("output, run in", run_in))
  }
})

test_that("N30: a path starting with / is relative to the project root, the folder holding _weft.yml", {
  files <- list("_weft/values/v.json" = fv_file(d = fr_int("11")),
                "ch1/_weft/values/v.json" = fv_file(d = fr_int("99")))
  md <- c(fv_block("/_weft/values/v.json"), "", fv_use("d"))
  for (run_in in c(".", "ch1")) {
    res <- filter_md(md, files = files, name = "ch1/doc.md", run_in = run_in, weft_yml = "draft: false",
                     to = "plain")
    expect_identical(res$status, 0L, label = paste("status, run in", run_in))
    expect_identical(trimws(res$output), "Use 11.", label = paste("output, run in", run_in))
  }
})

test_that("N30: with no _weft.yml the project root is the folder holding _quarto.yml", {
  files <- list("_quarto.yml" = c("project:", "  type: book"),
                "_weft/values/v.json" = fv_file(d = fr_int("11")),
                "ch1/_weft/values/v.json" = fv_file(d = fr_int("99")))
  md <- c(fv_block("/_weft/values/v.json"), "", fv_use("d"))
  res <- filter_md(md, files = files, name = "ch1/doc.md", to = "plain")
  expect_identical(res$status, 0L)
  expect_identical(trimws(res$output), "Use 11.")
})

test_that("N30: in a document at the project root both forms name the same file", {
  files <- setNames(list(fv_file(d = fr_int("4"))), SURVEY)
  md <- c(fv_block(SURVEY), "", fv_block(paste0("/", SURVEY)), "", fv_use("d"))
  res <- filter_md(md, files = files, weft_yml = "draft: false", to = "plain")
  expect_identical(res$status, 0L)
  expect_identical(trimws(res$output), "Use 4.")
})

# ---- E32: a file that cannot be read -----------------------------------------------------------------

test_that("N30, E32: a missing file is one construct error with E32's text, and adds no names", {
  for (p in c("_weft/values/nope.json", "/_weft/values/nope.json")) {
    md <- c(fv_block(p), "", fv_use("d"))
    res <- filter_md(md, to = "plain", env = draft1, weft_yml = "draft: false")
    expect_identical(res$status, 0L, label = p)
    expect_identical(trimws(res$output), "Use <<weft: no value, line 4>>.", label = p)
    e <- fv_cerr(res)
    expect_true(e$found, label = paste("a construct error for", p))
    expect_match(e$detail[[1]], fv_e32(p), label = p)
    expect_match(fm_headings(res$stderr), rx_failures(2), all = FALSE)
    # N94, E42: the name is published nowhere
    expect_match(res$stderr, f7_msg$E42("d"), fixed = TRUE)
    # without draft mode the render fails
    expect_identical(filter_md(md, to = "plain", weft_yml = "draft: false")$status, 1L, label = p)
  }
})

test_that("N30, E32, N89: a missing file in a cell is located by the cell", {
  md <- c("::: {#cell-load .cell}", fv_block("_weft/values/nope.json"), ":::", "", fv_use("d"))
  res <- filter_md(md, to = "plain", env = draft1)
  expect_identical(res$status, 0L)
  e <- fm_entry(res$stderr, "^  doc\\.md chunk load( |$)")
  expect_true(e$found)
  expect_match(e$head, "\\[construct error\\]")
  expect_match(e$detail[[1]], fv_e32("_weft/values/nope.json"))
})

test_that("N30, E32: a missing file leaves other blocks' names alone, and each missing file is its own error", {
  md <- c(carrier(a = fr_int("1")), "", fv_block("gone1.json"), "", fv_block("gone2.json"), "",
          "Use `a`{.val}.")
  res <- filter_md(md, to = "plain", env = draft1)
  expect_identical(res$status, 0L)
  expect_identical(trimws(res$output), "Use 1.")
  expect_match(fm_headings(res$stderr), rx_failures(2), all = FALSE)
  expect_match(res$stderr, "the values file gone1.json cannot be read: ", fixed = TRUE)
  expect_match(res$stderr, "the values file gone2.json cannot be read: ", fixed = TRUE)
})

# SPEC GAP (see the report): whether a file that exists but does not decode is E32 ("cannot be read") or
# N28's E12/E13 is not stated. The tests accept either text; they pin that it is one construct error,
# located at the block, that no name is added, and that the failure is loud.
test_that("N28, N30: a file that does not hold schema 1 is one construct error and adds no names", {
  bad <- list(
    empty    = "",
    not_json = "not json at all",
    array    = "[1,2]",
    weft2    = '{"weft":2,"values":{"d":{"t":"int","v":"1"}}}',
    weft_str = '{"weft":"1","values":{"d":{"t":"int","v":"1"}}}',
    no_vals  = '{"weft":1}',
    vals_arr = '{"weft":1,"values":[]}',
    bad_key  = carrier_json(d = fr_int("1"), `1bad` = fr_int("2")),
    bad_word = carrier_json(d = fr_int("1"), `TRUE` = fr_int("2"))
  )
  for (id in names(bad)) {
    files <- setNames(list(bad[[id]]), SURVEY)
    md <- c("::: {#cell-f .cell}", fv_block(SURVEY), ":::", "", fv_use("d"))
    res <- filter_md(md, files = files, to = "plain", env = draft1)
    expect_identical(res$status, 0L, label = id)
    expect_identical(trimws(res$output), "Use <<weft: no value, line 6>>.", label = id)
    e <- fm_entry(res$stderr, "^  doc\\.md chunk f( |$)")
    expect_true(e$found, label = paste("an entry for", id))
    expect_match(e$head, "\\[construct error\\]", label = id)
    expect_true(grepl(fv_e32(SURVEY), e$detail[[1]]) || grepl(fv_e12, e$detail[[1]]), label = paste("text for", id))
    expect_match(fm_headings(res$stderr), rx_failures(2), all = FALSE)
    expect_identical(filter_md(md, files = files, to = "plain")$status, 1L, label = paste(id, "outside draft mode"))
  }
})

test_that("N28: a file that does not read adds none of its names, even those before the fault", {
  files <- setNames(list(carrier_json(ok = fr_int("1"), `1bad` = fr_int("2"))), SURVEY)
  res <- filter_md(c(fv_block(SURVEY), "", fv_use("ok")), files = files, to = "plain", env = draft1)
  expect_identical(trimws(res$output), "Use <<weft: no value, line 4>>.")
})

# ---- N25a, N25b: checks carried by a file ---------------------------------------------------------------

test_that("N25a: a record's failed check in a file counts where the name is used, and not when it is unused", {
  rec <- fr_with(fr_int("7"), fr_check("> 10"))
  files <- setNames(list(fv_file(d = rec, other = fr_int("1"))), SURVEY)
  used <- filter_md(c(fv_block(SURVEY), "", "Depth `d`{.val} m."), files = files, to = "plain", env = draft1)
  expect_identical(trimws(used$output), "Depth 7<<weft: failed claim, line 4>> m.")
  expect_match(fm_headings(used$stderr), rx_claims(1), all = FALSE)
  e <- fm_entry(used$stderr, "^  doc\\.md:4  ")
  expect_identical(e$detail, fm_msg$E14("> 10", "7"))
  unused <- filter_md(c(fv_block(SURVEY), "", "Other `other`{.val}."), files = files, to = "plain")
  expect_identical(unused$status, 0L)
  expect_identical(unused$stderr, "")
})

test_that("N25b: the file's own checks are claims, reported once, whether or not a name is used", {
  members <- paste0('"checks":[{"text":"n > 10","ok":false,"level":"fail","why":null,',
                    '"expr":"claim(n, . > 10)","value":{"t":"int","v":"7"},"line":null}]')
  files <- setNames(list(fv_file(n = fr_int("7"), members = members)), SURVEY)
  md <- c(fv_block(SURVEY), "", "No use.")
  res <- filter_md(md, files = files, to = "plain", env = draft1)
  expect_identical(res$status, 0L)
  expect_match(fm_headings(res$stderr), rx_claims(1), all = FALSE)
  expect_identical(filter_md(md, files = files, to = "plain")$status, 1L)
})

# ---- N27: one file, two chapters -------------------------------------------------------------------------

test_that("N27, N30: two chapters of one project read the same file and print the same values", {
  files <- setNames(list(fv_file(n = fr_int("4"), site = fr_str("north"))), SURVEY)
  a <- filter_md(c(fv_block("/_weft/values/survey.json"), "", "Chapter one: `n`{.val} at `site`{.val}."),
                 files = files, name = "ch1/a.md", weft_yml = "draft: false", to = "plain")
  b <- filter_md(c("Chapter two first.", "", fv_block("/_weft/values/survey.json"), "",
                   "Chapter two: `n`{.val} at `site`{.val}."),
                 files = files, name = "ch2/b.md", weft_yml = "draft: false", to = "plain")
  expect_identical(a$status, 0L)
  expect_identical(b$status, 0L)
  expect_identical(trimws(a$output), "Chapter one: 4 at north.")
  expect_identical(fv_paras(b), c("Chapter two first.", "Chapter two: 4 at north."))
  expect_identical(a$stderr, "")
  expect_identical(b$stderr, "")
})

test_that("N27: names do not cross documents; a chapter that does not read the file has no value", {
  files <- setNames(list(fv_file(n = fr_int("4"))), SURVEY)
  res <- filter_md("Chapter: `n`{.val}.", files = files, to = "plain", env = draft1)
  expect_identical(trimws(res$output), "Chapter: <<weft: no value, line 1>>.")
})

# ---- N112: the ledger header's file hashes (needs 6g) -----------------------------------------------------

LF_YML <- c("draft: false", "ledger: true")
fv_md5 <- function(text_lines) {
  p <- tempfile("md5-")
  on.exit(unlink(p))
  writeBin(charToRaw(paste0(paste(text_lines, collapse = "\n"), "\n")), p)
  weft:::file_hash(p)
}

# needs 6g
test_that("N112, N30: the ledger header's files hold every values file read, with the hash of its bytes", {
  lines <- strsplit(fv_file(d = fr_int("7")), "\n", fixed = TRUE)[[1]]
  files <- setNames(list(lines), SURVEY)
  md <- c(fv_block(SURVEY), "", "Use `d`{.num}.")
  res <- filter_md(md, files = files, weft_yml = LF_YML, env = c(WEFT_RUN = "R1"))
  expect_identical(res$status, 0L)
  h <- g6_header(res)
  expect_setequal(names(h$files), c("doc.md", SURVEY))
  expect_identical(h$files[[SURVEY]], fv_md5(lines))
  expect_match(h$files[["doc.md"]], "^[0-9a-f]{16}$")
})

# needs 6g
test_that("N112: a values file's hash is taken with line ends made \\n, so CRLF and LF files hash alike", {
  lines <- c('{"weft":1,', ' "values":{"d":{"t":"int","v":"7"}}}')
  md <- c(fv_block(SURVEY), "", "Use `d`{.num}.")
  lf <- g6_header(filter_md(md, files = setNames(list(lines), SURVEY), weft_yml = LF_YML, env = c(WEFT_RUN = "R1")))
  crlf <- g6_header(filter_md(md, files = setNames(list(paste0(lines, "\r")), SURVEY), weft_yml = LF_YML,
                              env = c(WEFT_RUN = "R1")))
  expect_identical(lf$files[[SURVEY]], fv_md5(lines))
  expect_identical(crlf$files[[SURVEY]], lf$files[[SURVEY]])
})

# needs 6g
test_that("N112: a file read twice is listed once, and its hash follows the file's content", {
  md <- c(fv_block(SURVEY), "", "Use `d`{.num}.", "", fv_block(SURVEY))
  one <- g6_header(filter_md(md, files = setNames(list(fv_file(d = fr_int("1"))), SURVEY), weft_yml = LF_YML,
                             env = c(WEFT_RUN = "R1")))
  two <- g6_header(filter_md(md, files = setNames(list(fv_file(d = fr_int("2"))), SURVEY), weft_yml = LF_YML,
                             env = c(WEFT_RUN = "R1")))
  expect_identical(sum(names(one$files) == SURVEY), 1L)
  expect_identical(one$files[["doc.md"]], two$files[["doc.md"]])
  expect_false(identical(one$files[[SURVEY]], two$files[[SURVEY]]))
})

# needs 6g
test_that("N112: the source's and an include's entries are kept beside the values file's", {
  files <- list("inc.md" = "Inner.")
  files[[SURVEY]] <- fv_file(d = fr_int("7"))
  md <- c(fv_block(SURVEY), "", "{{< include inc.md >}}", "", "Use `d`{.num}.")
  h <- g6_header(filter_md(md, files = files, weft_yml = LF_YML, env = c(WEFT_RUN = "R1")))
  expect_setequal(names(h$files), c("doc.md", "inc.md", SURVEY))
})

# needs 6g
test_that("N112, N27: two chapters reading one file record the same hash for it", {
  files <- setNames(list(fv_file(d = fr_int("7"))), SURVEY)
  md <- c(fv_block(SURVEY), "", "Use `d`{.num}.")
  ha <- g6_header(filter_md(md, files = files, name = "a.md", weft_yml = LF_YML, env = c(WEFT_RUN = "R1")),
                  path = "_weft/ledger/a.md/out.jsonl")
  hb <- g6_header(filter_md(md, files = files, name = "b.md", weft_yml = LF_YML, env = c(WEFT_RUN = "R1")),
                  path = "_weft/ledger/b.md/out.jsonl")
  expect_true(SURVEY %in% names(ha$files))
  expect_identical(ha$files[[SURVEY]], hb$files[[SURVEY]])
})
