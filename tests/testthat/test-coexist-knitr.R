# Package 6g: one knitr document with both kinds of construct (dev/design-6.md N130h to N133h, N92,
# N110 to N113). The N92 cases run through plain Pandoc (filter_md()); the coexistence cases render a
# set-up Quarto project: one render shared by the tests of its file. ASCII only. Invented content.

# ---- N92: a leftover span in a knitr document -------------------------------------------------------------

CK_BLOCK <- g6_block(rising = fr_bool(TRUE), a = fr_int("1"))
ck_doc <- function(span, front = NULL) c(front, CK_BLOCK, "", paste0("Case ", span, " end."))
CK_FIT <- "[up | down]{if=\"rising\"}"
CK_BAD <- "[up | down]{if=\"a + 1 > b\"}"
CK_BAD_N <- "[one | many]{n=\"3\"}"
CK_ENGINE <- c("---", "engine: knitr", "---", "")
CK_CHUNK <- c("---", "title: \"t\"", "---", "", "```{r}", "1 + 1", "```", "")

ck_leftover <- function(res, file, key) {
  expect_identical(res$status, 1L)
  expect_true(grepl(sprintf("weft-check: 1 leftover weft construct in %s", file), res$stderr, fixed = TRUE))
  expect_true(grepl(sprintf("a span still carries the key `%s`", key), res$stderr, fixed = TRUE))
  # weft.lua did not report it: no construct error, no report of its own
  expect_false(grepl("[construct error]", res$stderr, fixed = TRUE))
  expect_false(grepl("is not a name or one comparison", res$stderr, fixed = TRUE))
  expect_false(grepl("(^|\n)weft: [0-9]+ failure", res$stderr))
}

test_that("N92: in an .Rmd a leftover span whose governor fits N9 is resolved", {
  res <- filter_md(ck_doc(CK_FIT), to = "plain", name = "doc.Rmd")
  expect_identical(res$status, 0L)
  expect_identical(trimws(strsplit(trimws(res$output), "\n", fixed = TRUE)[[1]][1]), "Case up end.")
  expect_false(grepl("weft", res$stderr, fixed = TRUE))
})

test_that("N92: in an .Rmd a leftover span whose governor does not fit is left for weft-check.lua", {
  ck_leftover(filter_md(ck_doc(CK_BAD), to = "plain", name = "doc.Rmd"), "doc.Rmd", "if")
  ck_leftover(filter_md(ck_doc(CK_BAD_N), to = "plain", name = "doc.Rmd"), "doc.Rmd", "n")
})

test_that("N92, N14: a .qmd with `engine: knitr`, and one with an executed {r} chunk and no engine, are knitr documents", {
  ck_leftover(filter_md(ck_doc(CK_BAD, CK_ENGINE), to = "plain", name = "doc.qmd"), "doc.qmd", "if")
  ck_leftover(filter_md(c(CK_CHUNK, ck_doc(CK_BAD)), to = "plain", name = "doc.qmd"), "doc.qmd", "if")
  res <- filter_md(ck_doc(CK_FIT, CK_ENGINE), to = "plain", name = "doc.qmd")
  expect_identical(res$status, 0L)
  expect_true(grepl("Case up end.", res$output, fixed = TRUE))
  res <- filter_md(c(CK_CHUNK, ck_doc(CK_FIT)), to = "plain", name = "doc.qmd")
  expect_identical(res$status, 0L)
  expect_true(grepl("Case up end.", res$output, fixed = TRUE))
})

test_that("N92: the left span is still reported when the render is a draft: weft-check.lua's own report, no exit", {
  res <- filter_md(ck_doc(CK_BAD), to = "plain", name = "doc.Rmd", env = c(WEFT_DRAFT = "1"))
  expect_identical(res$status, 0L)
  expect_true(grepl("weft-check: 1 leftover weft construct in doc.Rmd", res$stderr, fixed = TRUE))
  expect_false(grepl("[construct error]", res$stderr, fixed = TRUE))
})

test_that("N14, N92: in a document that is not knitr (a .md, a .qmd with no R) the filter reports the construct error as before (control)", {
  for (nm in c("doc.md", "doc.qmd")) {
    res <- filter_md(ck_doc(CK_BAD), to = "plain", name = nm)
    expect_identical(res$status, 1L, label = nm)
    expect_true(grepl("[construct error]", res$stderr, fixed = TRUE), label = nm)
    expect_true(grepl(fm_msg$E3("a + 1 > b"), res$stderr, fixed = TRUE), label = nm)
    expect_false(grepl("weft-check:", res$stderr, fixed = TRUE), label = nm)
    res <- filter_md(ck_doc(CK_BAD_N), to = "plain", name = nm)
    expect_identical(res$status, 1L, label = nm)
    expect_true(grepl("[construct error]", res$stderr, fixed = TRUE), label = nm)
  }
})

# ---- N130h, N131h, N132h: both kinds in one knitr .qmd, rendered once ---------------------------------------

CK_QMD <- function(lim = "20L") {
  c("---", "title: \"t\"", "engine: knitr", "---", "",
    "```{r setup, include=FALSE}",
    "weft::weft_setup()",
    "hk <- 12.5", "pa <- 1/3", "pb <- 1/3", "n_sites <- 4L", "rising <- TRUE", "depth <- 3.5",
    sprintf("weft::weft_put(lim = %s)", lim),
    "```", "",
    "## Data", "",
    "Hooks `r hk`{.num} and `r pa`{.num} here.", "",
    "Named `depth`{.num}, `lim`{.num} and `pb`{.num}. Found [one site | # sites]{n=\"n_sites\"} here. [up | down]{if=\"rising\"} ok.",
    "")
}

ck_cache <- new.env()

ck_project <- function(docs = list("doc.qmd" = CK_QMD())) {
  skip_if_no_quarto()
  v4_env(libs = TRUE)
  files <- c(docs, list("_quarto.yml" = c("project:", "  type: default", "format: html")))
  mk_project(files)
}

ck_read <- function(root, rel) {
  p <- file.path(root, rel)
  if (!file.exists(p)) return(NULL)
  paste(readLines(p, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

ck_entries <- function(root) {
  p <- file.path(root, "_weft", "ledger", "doc.qmd", "doc.jsonl")
  if (!file.exists(p)) return(NULL)
  l <- readLines(p, warn = FALSE, encoding = "UTF-8")
  list(lines = l, entries = lapply(l[-1], g6_json))
}

ck_two_renders <- function() {
  if (is.null(ck_cache$two)) {
    root <- ck_project()
    withr::defer(unlink(root, recursive = TRUE), teardown_env())
    fx <- list(root = root)
    fx$r1 <- qrender(root, "doc.qmd", env = c(WEFT_RUN = "R1"))
    fx$stamp1 <- ck_read(root, ".weft/stamps/doc.qmd.json")
    fx$led1 <- ck_entries(root)
    fx$html1 <- ck_read(root, "doc.html")
    writeLines(CK_QMD(lim = "30L"), file.path(root, "doc.qmd"))
    fx$r2 <- qrender(root, "doc.qmd", env = c(WEFT_RUN = "R2"))
    fx$stamp2 <- ck_read(root, ".weft/stamps/doc.qmd.json")
    fx$led2 <- ck_entries(root)
    fx$html2 <- ck_read(root, "doc.html")
    ck_cache$two <- fx
  }
  ck_cache$two
}

CK_KEYS <- c("value|hk|1", "value|pa|1", "n|n_sites|1", "if|rising|1", "value|depth|1", "value|lim|1", "value|pb|1")

test_that("N110, N130h: both kinds in one document give one stamp, with writers both and the filter's count", {
  fx <- ck_two_renders()
  expect_identical(fx$r1$status, 0L, label = fx$r1$log)
  expect_identical(list.files(file.path(fx$root, ".weft", "stamps")), "doc.qmd.json")
  expect_false(is.null(fx$stamp1))
  s <- g6_json(fx$stamp1)
  expect_identical(names(s), c("source", "run", "executed", "checks", "failures", "writers", "named", "fresh"))
  expect_identical(s$source, "doc.qmd")
  expect_identical(s$run, "R1")
  expect_identical(unlist(s$writers), c("knit", "filter"))
  expect_identical(s$named, 3L)             # depth, lim, pb: the hooks' own constructs are not counted
  expect_true(isTRUE(s$fresh))              # every block was written in this run
  expect_identical(s$failures, list())
  expect_gte(s$checks, 4)                   # the hooks' three constructs, and at least one of the filter's
})

test_that("N112, N113, N130h: one ledger file holds the hooks' entries and the filter's", {
  fx <- ck_two_renders()
  expect_identical(sort(list.files(file.path(fx$root, "_weft", "ledger"), recursive = TRUE)),
                   c("doc.qmd/doc.conditions.jsonl", "doc.qmd/doc.jsonl"))
  led <- fx$led1
  expect_false(is.null(led))
  es <- led$entries
  expect_setequal(g6_keys(es), CK_KEYS)
  for (e in es) {
    mine <- e$kind == "value" && e$expr %in% c("depth", "lim", "pb")
    expect_identical(identical(e$writer, "filter"), mine, label = paste(e$kind, e$expr))
  }
  expect_identical(g6_pick(es, "value", "depth", 1)$text, "3.5")
  expect_identical(g6_pick(es, "value", "lim", 1)$text, "20")
  expect_identical(g6_pick(es, "n", "n_sites", 1)$text, "4 sites")
  expect_identical(g6_pick(es, "if", "rising", 1)$text, "up")
  # sorted by 7.1.5 whichever writer wrote the line
  f <- vapply(es, function(e) e$file, ""); s <- vapply(es, function(e) e$section, "")
  k <- vapply(es, function(e) e$kind, ""); x <- vapply(es, function(e) e$expr, "")
  o <- vapply(es, function(e) as.integer(e$occ), 1L)
  expect_identical(order(f, s, k, x, o, method = "radix"), seq_along(es))
})

test_that("N131h: an R double published and used by name prints what `r x`{.num} prints", {
  fx <- ck_two_renders()
  es <- fx$led1$entries
  expect_false(is.null(es))
  by_hooks <- g6_pick(es, "value", "pa", 1)$text
  by_name <- g6_pick(es, "value", "pb", 1)$text
  expect_identical(by_name, by_hooks)
  txt <- gsub("<[^>]+>", "", fx$html1)
  expect_true(grepl(paste0("Named 3.5, 20 and ", by_name), txt, fixed = TRUE))
  expect_true(grepl(paste0("and ", by_hooks, " here"), txt, fixed = TRUE))
})

test_that("N132h: a span with a named governor and R arms in a knitr document is the hooks': one entry, not the filter's", {
  fx <- ck_two_renders()
  es <- fx$led1$entries
  e <- g6_pick(es, "if", "rising", 1)
  expect_false(identical(e$writer, "filter"))
  expect_true(grepl("Found 4 sites here. up ok.", gsub("<[^>]+>", "", fx$html1), fixed = TRUE))
})

test_that("N112: a second render replaces only the filter's entries: hooks' lines kept, no entry twice", {
  fx <- ck_two_renders()
  expect_identical(fx$r2$status, 0L, label = fx$r2$log)
  expect_false(is.null(fx$led2))
  es <- fx$led2$entries
  expect_setequal(g6_keys(es), CK_KEYS)
  expect_length(es, 7L)
  expect_identical(g6_pick(es, "value", "lim", 1)$text, "30")
  expect_false(any(grepl("\"text\":\"20\"", fx$led2$lines, fixed = TRUE)))
  hooks_lines <- function(l) l[-1][!grepl("\"writer\":\"filter\"", l[-1], fixed = TRUE)]
  expect_identical(hooks_lines(fx$led2$lines), hooks_lines(fx$led1$lines))
  expect_length(hooks_lines(fx$led2$lines), 4L)
  s <- g6_json(fx$stamp2)
  expect_identical(s$run, "R2")
  expect_identical(unlist(s$writers), c("knit", "filter"))
  expect_identical(s$named, 3L)
  expect_true(isTRUE(s$fresh))
  expect_identical(list.files(file.path(fx$root, ".weft", "stamps")), "doc.qmd.json")
})

# ---- N133h: double reporting ---------------------------------------------------------------------------------

CK_FAIL_QMD <- c("---", "title: \"t\"", "engine: knitr", "---", "",
                 "```{r setup, include=FALSE}",
                 "weft::weft_setup()",
                 "depth <- 7",
                 "weft::weft_put(gone = NA_real_)",
                 "```", "",
                 "The depth is `r claim(depth, . > 10)` here.", "",
                 "Gone `gone`{.num} here.", "")

test_that("N133h: in a project render both resolvers' failures go to the one post-render report", {
  root <- ck_project(list("doc.qmd" = CK_FAIL_QMD))
  r <- qrender(root, env = c(WEFT_RUN = "R1"))
  expect_identical(r$status, 1L)
  # the hooks' claim is reported once, by the post-render script (the hooks only collect it) ...
  expect_identical(n_matches("weft: 1 claim failed", r$log), 1L)
  expect_identical(n_matches("claim\\(depth", r$log), 1L)
  # ... and the post-render report, which starts at that heading, also holds the filter's failure,
  # under the other failures, once
  i <- regexpr("weft: 1 claim failed", r$log, fixed = TRUE)
  post <- if (i > 0) substring(r$log, i) else ""
  expect_identical(n_matches("weft: 1 failure\\b", post), 1L)
  expect_identical(n_matches("\\[no value\\] `gone`\\{\\.num\\}", post), 1L)
  # both are in the document's stamp, each by the resolver that owns it
  s <- g6_json(ck_read(root, ".weft/stamps/doc.qmd.json"))
  expect_identical(unlist(s$writers), c("knit", "filter"))
  expect_setequal(vapply(s$failures, function(f) paste(f$source, f$kind), ""),
                  c("knit failed claim", "resolve no value"))
})
