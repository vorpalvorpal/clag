# G2 (dev/design-8.md, GT1 to GT9, section 4): two slow renders, one on the jupyter engine and one on the
# julia engine, each with a labelled `tbl-` cell that displays an HTML table and one that displays a
# Markdown pipe table. The filter (inst/quarto/weft.lua) must write a ledger entry of kind `table` for
# each, whose `text` is the digest of the canonical text (GT3, GT4). Written before the code; ASCII only.
# Skipped when quarto or the engine is absent. Jupyter wants QUARTO_PYTHON (helper-jupyter.R).
#
# Not tested here: pandas (design: only under skip_if_no_py_module("pandas"); the renders use the
# python of QUARTO_PYTHON, which skip_if_no_py_module() does not look at, so it is left out to keep each
# render to one and the result independent of the library's HTML).

jle_kill_at_file_end()

te_hash <- function(text) cli::hash_raw_xxhash64(charToRaw(enc2utf8(text)))

# the table entries of every ledger a render wrote under dir (conditions logs excluded)
te_entries <- function(dir) {
  root <- file.path(dir, "_weft", "ledger")
  f <- if (dir.exists(root)) list.files(root, pattern = "\\.jsonl$", recursive = TRUE, full.names = TRUE) else character()
  f <- f[!grepl("\\.conditions\\.jsonl$", f)]
  es <- unlist(lapply(f, function(p) {
    l <- readLines(p, warn = FALSE, encoding = "UTF-8")
    lapply(l[-1], function(x) jsonlite::fromJSON(x, simplifyVector = FALSE))
  }), recursive = FALSE)
  Filter(function(e) identical(e$kind, "table"), es)
}

TE_CANON <- "a\tb\n1\t2"
TE_HTML <- paste0("<table class=\\\"dataframe\\\"><thead><tr><th>a</th><th>b</th></tr></thead>",
                  "<tbody><tr><td>1</td><td>2</td></tr></tbody></table>")

test_that("GT2 to GT6: a jupyter render records the HTML table and the Markdown table with the digest of their cells", {
  skip_if_no_jupyter()
  qmd <- c("---", "title: Tables", "jupyter: python3", "---", "",
           "```{python}", "#| label: tbl-sites", "#| echo: false",
           "from IPython.display import HTML, Markdown, display",
           sprintf("display(HTML(\"%s\"))", TE_HTML), "```", "",
           "```{python}", "#| label: tbl-md", "#| echo: false",
           "display(Markdown(\"| a | b |\\n|---|---|\\n| 1 | 2 |\"))", "```")
  dir <- qm_project(list("tables.qmd" = qmd))
  r <- qm_render(dir, "tables.qmd")
  expect_identical(r$status, 0L, info = paste(utils::tail(r$stderr, 12), collapse = "\n"))
  es <- te_entries(dir)
  expect_length(es, 2L)
  by <- stats::setNames(es, vapply(es, function(e) e$expr, ""))
  expect_setequal(names(by), c("tbl-sites", "tbl-md"))
  for (e in by) {
    expect_identical(e$text, te_hash(TE_CANON))
    expect_identical(e$kind, "table")
    expect_identical(e$context, "chunk")
    expect_identical(e$occ, 1L)
    expect_identical(e$writer, "filter")
    expect_identical(e$file, "tables.qmd")
  }
  expect_identical(by[["tbl-sites"]]$id, "tbl-sites")
  expect_identical(by[["tbl-md"]]$id, "tbl-md")
})

test_that("GT2 to GT6: a julia-engine render records the HTML table and the Markdown table with the digest of their cells", {
  skip_if_no_julia_engine()
  qmd <- c("---", "title: Tables", "---", "",
           "```{julia}", "#| label: tbl-sites", "#| echo: false",
           sprintf("display(\"text/html\", \"%s\")", TE_HTML), "```", "",
           "```{julia}", "#| label: pub", "#| echo: false",
           "display(\"text/markdown\", \"| a | b |\\n|---|---|\\n| 1 | 2 |\")", "```")
  dir <- jle_project(list("tables.qmd" = qmd))
  r <- jle_render(dir, "tables.qmd")
  expect_identical(r$status, 0L, info = paste(utils::tail(r$stderr, 12), collapse = "\n"))
  es <- te_entries(dir)
  expect_length(es, 2L)
  by <- stats::setNames(es, vapply(es, function(e) e$expr, ""))
  expect_setequal(names(by), c("tbl-sites", "pub"))
  for (e in by) {
    expect_identical(e$text, te_hash(TE_CANON))
    expect_identical(e$kind, "table")
    expect_identical(e$context, "chunk")
    expect_identical(e$occ, 1L)
    expect_identical(e$writer, "filter")
    expect_identical(e$file, "tables.qmd")
  }
  expect_identical(by[["pub"]]$id, "pub")
})
