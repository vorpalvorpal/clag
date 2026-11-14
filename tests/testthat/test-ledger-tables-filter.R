# G2 (dev/design-8.md, GT1 to GT14): table digests for documents the knitr hooks do not handle. The filter
# (inst/quarto/weft.lua) records a ledger entry of kind `table` for each table inside a `.cell` Div.
# Plain Pandoc through filter_md() (helper-filter.R, helper-6g.R): no Quarto, no Jupyter, no Julia.
# Written before the code; ASCII only; made-up content. Expected digests are computed here from the
# canonical text written out by hand (GT3), never taken from the filter.
# A "control" is a test that passes before the feature exists.

tt_hash <- function(text) cli::hash_raw_xxhash64(charToRaw(enc2utf8(text)))

tt_ledger <- "_weft/ledger/doc.md/out.jsonl"

tt_run <- function(md, weft_yml = G6_YML, env = c(WEFT_RUN = "R1"), ...) {
  filter_md(md, weft_yml = weft_yml, env = env, ...)
}

# every entry of the ledger file, as parsed lists; an absent file gives none (the tests then fail on
# the counts, not on a missing file)
tt_all <- function(res, path = tt_ledger) {
  txt <- res$files[[path]]
  if (is.null(txt)) return(list())
  lapply(strsplit(txt, "\n", fixed = TRUE)[[1]][-1], g6_json)
}
tt_tables <- function(res, path = tt_ledger) Filter(function(e) identical(e$kind, "table"), tt_all(res, path))
tt_by_expr <- function(es, expr) Filter(function(e) identical(e$expr, expr), es)
tt_texts <- function(es) vapply(es, function(e) e$text, "")
tt_table_lines <- function(res, path = tt_ledger) {
  grep("\"kind\":\"table\"", strsplit(res$files[[path]], "\n", fixed = TRUE)[[1]], value = TRUE, fixed = TRUE)
}

# a cell Div: `label` is the whole id, so "cell-tbl-sites" is jupyter-style and "pub" julia-style
tt_cell <- function(label, body, attrs = "") {
  head <- if (is.null(label)) sprintf("::: {.cell%s}", attrs) else sprintf("::: {#%s .cell%s}", label, attrs)
  c(head, "", body, "", ":::", "")
}

TT_PIPE <- c("| a | b |", "|---|---|", "| 1 | 2 |")
TT_CANON <- "a\tb\n1\t2"
TT_HTML_AB <- paste0("<table><thead><tr><th>a</th><th>b</th></tr></thead>",
                     "<tbody><tr><td>1</td><td>2</td></tr></tbody></table>")
tt_raw <- function(x) c("```{=html}", x, "```")
TT_BLOCK <- g6_block(depth = fr_float("12.5"), run = "R1", at = 1794822900L)

# ---- GT3 to GT6: the exact form of one entry ---------------------------------------------------------------

test_that("GT3, GT4, GT5, GT6: a pipe table in a jupyter-style cell gives one entry with the exact fields", {
  res <- tt_run(c("## Sites", "", tt_cell("cell-tbl-sites", TT_PIPE)))
  expect_identical(res$status, 0L)
  es <- tt_tables(res)
  expect_length(es, 1L)
  e <- es[[1]]
  expect_identical(e$kind, "table")
  expect_identical(e$expr, "tbl-sites")
  expect_identical(e$id, "tbl-sites")
  expect_identical(e$occ, 1L)
  expect_identical(e$file, "doc.md")
  expect_identical(e$section, "sites")
  expect_identical(e$context, "chunk")
  expect_identical(e$text, t7c_hash("a\tb\n1\t2"))
  expect_match(e$text, "^[0-9a-f]{16}$")
  expect_identical(e$sentence, "a b 1 2")
  expect_identical(e$writer, "filter")
  for (f in c("arm", "rel", "raw", "unit", "failed")) expect_null(e[[f]], label = f)
  expect_identical(e$dict, list())
  line <- tt_table_lines(res)
  for (frag in c("\"arm\":null", "\"rel\":null", "\"raw\":null", "\"unit\":null", "\"failed\":null",
                 "\"dict\":[]", "\"writer\":\"filter\"")) {
    expect_true(any(grepl(frag, line, fixed = TRUE)), label = frag)
  }
})

test_that("GT5: a julia-style label gives the same expr and id as a jupyter-style one, and the same digest", {
  res <- tt_run(c(tt_cell("cell-pub", TT_PIPE), tt_cell("pub", TT_PIPE)))
  es <- tt_tables(res)
  expect_length(es, 2L)
  expect_identical(vapply(es, function(e) e$expr, ""), c("pub", "pub"))
  expect_identical(vapply(es, function(e) e$id, ""), c("pub", "pub"))
  expect_identical(vapply(es, function(e) e$occ, 1L), c(1L, 2L))
  expect_identical(es[[1]]$text, es[[2]]$text)
  expect_identical(es[[1]]$text, tt_hash(TT_CANON))
})

# ---- GT4: digest equality --------------------------------------------------------------------------------------

test_that("GT4, GT2: raw HTML, pandas-like HTML and a headless table with the same cells give the same digest", {
  pandas <- c("<style scoped>", "    .dataframe tbody tr th:only-of-type { vertical-align: middle; }",
              "</style>",
              "<table border=\"1\" id=\"t-9\" class=\"dataframe\">",
              "  <thead>", "    <tr style=\"text-align: right;\"><th>a</th><th>b</th></tr>", "  </thead>",
              "  <tbody>", "    <tr class=\"odd\"><td id=\"x\">1</td><td>2</td></tr>", "  </tbody>",
              "</table>")
  headless <- "<table><tbody><tr><td>a</td><td>b</td></tr><tr><td>1</td><td>2</td></tr></tbody></table>"
  res <- tt_run(c(tt_cell("tbl-pipe", TT_PIPE), tt_cell("tbl-html", tt_raw(TT_HTML_AB)),
                  tt_cell("tbl-pandas", tt_raw(pandas)), tt_cell("tbl-nohead", tt_raw(headless))))
  es <- tt_tables(res)
  expect_length(es, 4L)
  expect_setequal(vapply(es, function(e) e$expr, ""), c("tbl-pipe", "tbl-html", "tbl-pandas", "tbl-nohead"))
  expect_identical(tt_texts(es), rep(tt_hash(TT_CANON), 4L))
})

test_that("GT4: a bare HTML block (no fence) in a cell is read as a table as well", {
  res <- tt_run(tt_cell("tbl-bare", TT_HTML_AB))
  es <- tt_tables(res)
  expect_length(es, 1L)
  expect_identical(es[[1]]$text, tt_hash(TT_CANON))
})

test_that("GT4: one cell changed gives a different digest", {
  changed <- c("| a | b |", "|---|---|", "| 1 | 3 |")
  res <- tt_run(c(tt_cell("tbl-one", TT_PIPE), tt_cell("tbl-two", changed)))
  es <- tt_tables(res)
  expect_length(es, 2L)
  one <- tt_by_expr(es, "tbl-one")
  two <- tt_by_expr(es, "tbl-two")
  expect_length(one, 1L)
  expect_length(two, 1L)
  expect_identical(one[[1]]$text, tt_hash("a\tb\n1\t2"))
  expect_identical(two[[1]]$text, tt_hash("a\tb\n1\t3"))
  expect_false(identical(one[[1]]$text, two[[1]]$text))
})

test_that("GT4: a style-only change (classes, ids and styles added) is not a change", {
  styled <- paste0("<table class=\"dataframe fancy\" id=\"zz\"><thead><tr><th class=\"c\">a</th><th>b</th></tr></thead>",
                   "<tbody><tr><td style=\"color:red\">1</td><td>2</td></tr></tbody></table>")
  res <- tt_run(c(tt_cell("tbl-a", TT_HTML_AB), tt_cell("tbl-b", styled)))
  es <- tt_tables(res)
  expect_length(es, 2L)
  expect_identical(es[[1]]$text, es[[2]]$text)
})

# ---- GT3: the canonical text, edge cases -----------------------------------------------------------------------

test_that("GT3: U+00A0 becomes a space, runs of white space one space, and the ends of a cell are trimmed", {
  html <- paste0("<table><tr><td>&nbsp;a&nbsp;&nbsp;b </td><td>c\n   d\t e</td></tr>",
                 "<tr><td>  e  </td><td>f&nbsp;</td></tr></table>")
  es <- tt_tables(tt_run(tt_cell("tbl-ws", tt_raw(html))))
  expect_length(es, 1L)
  expect_identical(es[[1]]$text, tt_hash("a b\tc d e\ne\tf"))
})

test_that("GT3: a literal U+00A0 in a pipe table cell is a space, not a different digest", {
  nb <- c("| a b | c |", "|---|---|", "| 1 | 2 |")
  sp <- c("| a b | c |", "|---|---|", "| 1 | 2 |")
  es <- tt_tables(tt_run(c(tt_cell("tbl-nb", nb), tt_cell("tbl-sp", sp))))
  expect_length(es, 2L)
  expect_identical(es[[1]]$text, tt_hash("a b\tc\n1\t2"))
  expect_identical(es[[2]]$text, tt_hash("a b\tc\n1\t2"))
})

test_that("GT3: row and column spans are ignored, and inline markup in a cell is stringified", {
  html <- "<table><tr><td colspan=\"2\">x</td></tr><tr><td>y</td><td rowspan=\"1\">z</td></tr></table>"
  md_cell <- c("| *a* | **b** [c]{.k} |", "|---|---|", "| `1` | [2]{.k} |")
  es <- tt_tables(tt_run(c(tt_cell("tbl-span", tt_raw(html)), tt_cell("tbl-inline", md_cell))))
  expect_length(es, 2L)
  expect_identical(tt_by_expr(es, "tbl-span")[[1]]$text, tt_hash("x\ny\tz"))
  expect_identical(tt_by_expr(es, "tbl-inline")[[1]]$text, tt_hash("a\tb c\n1\t2"))
})

test_that("GT3: rows run head, then body rows, then foot", {
  html <- paste0("<table><thead><tr><th>H</th><th>h</th></tr></thead>",
                 "<tbody><tr><td>B1</td><td>b1</td></tr><tr><td>B2</td><td>b2</td></tr></tbody>",
                 "<tfoot><tr><td>F</td><td>f</td></tr></tfoot></table>")
  es <- tt_tables(tt_run(tt_cell("tbl-order", tt_raw(html))))
  expect_length(es, 1L)
  expect_identical(es[[1]]$text, tt_hash("H\th\nB1\tb1\nB2\tb2\nF\tf"))
})

test_that("GT3: an empty leading cell is kept (a pandas index column): rows are not trimmed", {
  html <- paste0("<table><thead><tr><th></th><th>a</th></tr></thead>",
                 "<tbody><tr><th>0</th><td>1</td></tr></tbody></table>")
  es <- tt_tables(tt_run(tt_cell("tbl-idx", tt_raw(html))))
  expect_length(es, 1L)
  expect_identical(es[[1]]$text, tt_hash("\ta\n0\t1"))
})

test_that("GT3: a table whose cells are all empty is not recorded; its neighbour is", {
  empty <- paste0("<table><thead><tr><th></th><th>&nbsp;</th></tr></thead>",
                  "<tbody><tr><td> </td><td></td></tr></tbody></table>")
  res <- tt_run(c(tt_cell("tbl-empty", tt_raw(empty)), tt_cell("tbl-full", TT_PIPE)))
  es <- tt_tables(res)
  expect_length(es, 1L)
  expect_identical(es[[1]]$expr, "tbl-full")
})

# ---- GT2: what is a table --------------------------------------------------------------------------------------

test_that("GT2: a table nested in a table cell counts once, as the outer table", {
  html <- "<table><tr><td><table><tr><td>inner</td></tr></table></td><td>outer</td></tr></table>"
  es <- tt_tables(tt_run(tt_cell("tbl-nest", tt_raw(html))))
  expect_length(es, 1L)
  expect_identical(es[[1]]$text, tt_hash("inner\touter"))
})

test_that("GT2: `<TABLE` in upper case is a table", {
  html <- "<TABLE><TR><TD>a</TD><TD>b</TD></TR><TR><TD>1</TD><TD>2</TD></TR></TABLE>"
  es <- tt_tables(tt_run(tt_cell("tbl-upper", tt_raw(html))))
  expect_length(es, 1L)
  expect_identical(es[[1]]$text, tt_hash(TT_CANON))
})

test_that("GT2: raw HTML with no table in it records nothing, even when it holds the characters `<table`", {
  res <- tt_run(c(tt_cell("a-div", tt_raw("<div><p>just text</p></div>")),
                  tt_cell("a-comment", tt_raw("<div><!-- <table> --><p>x</p></div>")),
                  tt_cell("tbl-real", TT_PIPE)))
  es <- tt_tables(res)
  expect_length(es, 1L)
  expect_identical(es[[1]]$expr, "tbl-real")
  expect_identical(es[[1]]$occ, 1L)
})

test_that("GT2: a table outside every cell is not recorded (a prose table)", {
  res <- tt_run(c(TT_PIPE, "", tt_cell("tbl-in", TT_PIPE), "", "<table><tr><td>p</td></tr></table>"))
  es <- tt_tables(res)
  expect_length(es, 1L)
  expect_identical(es[[1]]$expr, "tbl-in")
})

test_that("GT2: a Div that is not a cell does not make its table a cell table", {
  res <- tt_run(c("::: {#cell-tbl-x .callout}", "", TT_PIPE, "", ":::"))
  expect_length(tt_tables(res), 0L)
})

test_that("GT2: a CodeBlock, raw LaTeX, raw Typst and a RawInline in a cell record nothing", {
  body <- c("```", "   a  b", "   1  2", "```", "",
            "```{=latex}", "\\begin{tabular}{ll}a & b\\\\\\end{tabular}", "```", "",
            "```{=typst}", "#table(columns: 2, [a], [b])", "```", "",
            "Inline `<table><tr><td>x</td></tr></table>`{=html} here.")
  res <- tt_run(tt_cell("tbl-printed", body))
  expect_identical(res$status, 0L)
  expect_length(tt_tables(res), 0L)
})

test_that("GT2: a table at any depth inside a cell counts: here inside a Div inside the cell", {
  inner <- c("::: {.cell-output .cell-output-display}", "", TT_PIPE, "", ":::")
  es <- tt_tables(tt_run(tt_cell("cell-tbl-deep", inner)))
  expect_length(es, 1L)
  expect_identical(es[[1]]$expr, "tbl-deep")
  expect_identical(es[[1]]$text, tt_hash(TT_CANON))
})

# ---- GT5: the key ----------------------------------------------------------------------------------------------

test_that("GT5: two tables in one cell are occ 1 and 2 of the same expr", {
  second <- c("| c |", "|---|", "| 9 |")
  es <- tt_tables(tt_run(tt_cell("tbl-two", c(TT_PIPE, "", second))))
  expect_length(es, 2L)
  expect_identical(vapply(es, function(e) e$expr, ""), c("tbl-two", "tbl-two"))
  expect_identical(vapply(es, function(e) e$occ, 1L), c(1L, 2L))
  expect_identical(vapply(es, function(e) e$id, ""), c("tbl-two", "tbl-two"))
  expect_identical(tt_texts(es), c(tt_hash(TT_CANON), tt_hash("c\n9")))
})

test_that("GT2, GT5: one raw block that holds two tables gives two entries, occ 1 and 2, in order", {
  html <- paste0("<div>", TT_HTML_AB, "<table><tr><td>p</td></tr></table></div>")
  es <- tt_tables(tt_run(tt_cell("tbl-pair", tt_raw(html))))
  expect_length(es, 2L)
  expect_identical(vapply(es, function(e) e$occ, 1L), c(1L, 2L))
  expect_identical(tt_texts(es), c(tt_hash(TT_CANON), tt_hash("p")))
})

test_that("GT5: two unlabelled cells give expr \"\", id null, and occ 1 and 2", {
  second <- c("| c |", "|---|", "| 9 |")
  res <- tt_run(c(tt_cell(NULL, TT_PIPE), tt_cell(NULL, second)))
  es <- tt_tables(res)
  expect_length(es, 2L)
  expect_identical(vapply(es, function(e) e$expr, ""), c("", ""))
  expect_true(all(vapply(es, function(e) is.null(e$id), TRUE)))
  expect_identical(vapply(es, function(e) e$occ, 1L), c(1L, 2L))
  expect_identical(tt_texts(es), c(tt_hash(TT_CANON), tt_hash("c\n9")))
  expect_true(all(grepl("\"id\":null", tt_table_lines(res), fixed = TRUE)))
})

test_that("GT5: the section is the identifier of the last Header above the table, and \"\" above every header", {
  res <- tt_run(c(tt_cell("tbl-top", TT_PIPE),
                  "# First part {#first}", "", tt_cell("tbl-a", TT_PIPE),
                  "## Second part", "", tt_cell("tbl-b", TT_PIPE),
                  "### Deep {#d3}", "", tt_cell(NULL, TT_PIPE)))
  es <- tt_tables(res)
  expect_length(es, 4L)
  expect_setequal(vapply(es, function(e) e$expr, ""), c("tbl-top", "tbl-a", "tbl-b", ""))
  sec <- function(expr) vapply(tt_by_expr(es, expr), function(e) e$section, "")
  expect_identical(sec("tbl-top"), "")
  expect_identical(sec("tbl-a"), "first")
  expect_identical(sec("tbl-b"), "second-part")
  expect_identical(sec(""), "d3")
})

test_that("GT5: occ is numbered within a section: unlabelled cells in two sections are each occ 1", {
  res <- tt_run(c("# One", "", tt_cell(NULL, TT_PIPE), "# Two", "", tt_cell(NULL, TT_PIPE)))
  es <- tt_tables(res)
  expect_length(es, 2L)
  expect_identical(vapply(es, function(e) e$section, ""), c("one", "two"))
  expect_identical(vapply(es, function(e) e$occ, 1L), c(1L, 1L))
})

# ---- GT6: the sentence ------------------------------------------------------------------------------------------

test_that("GT6: the sentence is the long caption, resolved, when there is one (it beats tbl-cap)", {
  blk <- g6_block(depth = fr_float("12.5"), run = "R1", at = 1794822900L)
  md <- c(blk, "", tt_cell("tbl-cap", c(TT_PIPE, "", ": Depth   of `depth`{.num} m", ""),
                           attrs = " tbl-cap=\"The attribute\""))
  es <- tt_tables(tt_run(md))
  expect_length(es, 1L)
  expect_identical(es[[1]]$sentence, "Depth of 12.5 m")
  expect_identical(es[[1]]$text, tt_hash(TT_CANON))
})

test_that("GT6: with no caption the cell's tbl-cap attribute is the sentence, white space squashed", {
  es <- tt_tables(tt_run(tt_cell("tbl-att", TT_PIPE, attrs = " tbl-cap=\"Site   table\"")))
  expect_length(es, 1L)
  expect_identical(es[[1]]$sentence, "Site table")
})

test_that("GT6: with neither, the sentence is the canonical text with TAB and LF as spaces", {
  es <- tt_tables(tt_run(tt_cell("tbl-none", TT_PIPE)))
  expect_length(es, 1L)
  expect_identical(es[[1]]$sentence, "a b 1 2")
})

test_that("GT6: an empty tbl-cap is no source; the canonical text is used", {
  es <- tt_tables(tt_run(tt_cell("tbl-blank", TT_PIPE, attrs = " tbl-cap=\"\"")))
  expect_length(es, 1L)
  expect_identical(es[[1]]$sentence, "a b 1 2")
})

test_that("GT6: the canonical-text sentence is cut at 80 characters with `...`, counting characters, not bytes", {
  w <- strrep("w", 9)
  e8 <- strrep("é", 8)
  r1 <- rep(w, 5)
  r2 <- c(e8, rep(w, 4))
  md <- tt_cell("tbl-long", c(paste0("| ", paste(r1, collapse = " | "), " |"), "|---|---|---|---|---|",
                              paste0("| ", paste(r2, collapse = " | "), " |"),
                              paste0("| ", paste(r1, collapse = " | "), " |")))
  canon <- paste(paste(r1, collapse = "\t"), paste(r2, collapse = "\t"), paste(r1, collapse = "\t"), sep = "\n")
  flat <- gsub("[\t\n]", " ", canon)
  expect_gt(nchar(flat), 80L)
  es <- tt_tables(tt_run(md))
  expect_length(es, 1L)
  expect_identical(es[[1]]$sentence, paste0(substr(flat, 1L, 80L), "..."))
  expect_identical(es[[1]]$text, tt_hash(canon))
})

test_that("GT6: a canonical text of exactly 80 characters is not cut; one of 81 is", {
  h80 <- strrep("x", 80)
  h81 <- strrep("y", 81)
  res <- tt_run(c(tt_cell("tbl-eighty", c(paste0("| ", h80, " |"), "|---|")),
                  tt_cell("tbl-eightyone", c(paste0("| ", h81, " |"), "|---|"))))
  es <- tt_tables(res)
  expect_length(es, 2L)
  expect_identical(es[[1]]$sentence, h80)
  expect_identical(es[[2]]$sentence, paste0(strrep("y", 80), "..."))
})

# ---- GT7: a named value in a caption keeps its own entry --------------------------------------------------------

test_that("GT7: changing a named value in a caption changes the value's entry, not the table's digest", {
  doc <- function(v) c(g6_block(depth = fr_float(v), run = "R1", at = 1794822900L), "",
                       tt_cell("tbl-d", c(TT_PIPE, "", ": Depth of `depth`{.num} m")))
  r1 <- tt_run(doc("12.5"))
  r2 <- tt_run(doc("13.5"))
  t1 <- tt_tables(r1)
  t2 <- tt_tables(r2)
  expect_length(t1, 1L)
  expect_length(t2, 1L)
  expect_identical(t1[[1]]$text, t2[[1]]$text)
  expect_identical(t1[[1]]$sentence, "Depth of 12.5 m")
  expect_identical(t2[[1]]$sentence, "Depth of 13.5 m")
  v1 <- tt_by_expr(Filter(function(e) identical(e$kind, "value"), tt_all(r1)), "depth")
  v2 <- tt_by_expr(Filter(function(e) identical(e$kind, "value"), tt_all(r2)), "depth")
  expect_length(v1, 1L)
  expect_length(v2, 1L)
  expect_identical(v1[[1]]$text, "12.5")
  expect_identical(v2[[1]]$text, "13.5")
})

# ---- GT8: the stamp --------------------------------------------------------------------------------------------

test_that("GT8: tables count in neither `checks` nor `named` of the stamp", {
  blk <- g6_block(depth = fr_float("12.5"), run = "R1", at = 1794822900L)
  body <- c("Depth `depth`{.num} m.", "")
  plain <- tt_run(c(blk, "", body))
  with <- tt_run(c(blk, "", body, tt_cell("tbl-a", TT_PIPE), tt_cell("tbl-b", TT_HTML_AB)))
  expect_length(tt_tables(with), 2L)                 # fails until the tables are recorded
  s0 <- g6_stamp(plain)
  s1 <- g6_stamp(with)
  expect_identical(s0$named, 1L)
  expect_identical(s1$named, s0$named)
  expect_identical(s1$checks, s0$checks)
})

# ---- GT9, GT1: when entries are written ------------------------------------------------------------------------

test_that("GT9: `ledger: false` writes no ledger file (control)", {
  res <- tt_run(tt_cell("tbl-a", TT_PIPE), weft_yml = G6_YML_OFF)
  expect_identical(res$status, 0L)
  expect_false(any(grepl("^_weft/ledger/", names(res$files))))
})

test_that("GT9: a project that is not set up (no _weft.yml) writes no ledger (control)", {
  res <- filter_md(tt_cell("tbl-a", TT_PIPE), env = c(WEFT_RUN = "R1"))
  expect_identical(res$status, 0L)
  expect_false(any(grepl("^_weft/ledger/", names(res$files))))
})

test_that("GT9: a failing run that is not a draft writes no ledger (control)", {
  md <- c(TT_BLOCK, "", "Depth `nothere`{.num} m.", "", tt_cell("tbl-a", TT_PIPE))
  res <- tt_run(md)
  expect_identical(res$status, 1L)
  expect_false(any(grepl("^_weft/ledger/", names(res$files))))
})

test_that("GT9: a failing run in draft mode still records its tables", {
  md <- c(TT_BLOCK, "", "Depth `nothere`{.num} m.", "", tt_cell("tbl-a", TT_PIPE))
  res <- tt_run(md, env = c(WEFT_RUN = "R1", WEFT_DRAFT = "1"))
  expect_identical(res$status, 0L)
  es <- tt_tables(res)
  expect_length(es, 1L)
  expect_identical(es[[1]]$text, tt_hash(TT_CANON))
})

test_that("GT1: a document the knitr hooks resolve (engine: knitr) records no table entries (control)", {
  md <- c("---", "engine: knitr", "---", "", tt_cell("tbl-a", TT_PIPE))
  res <- tt_run(md, name = "doc.qmd")
  expect_identical(res$status, 0L)
  all_lines <- unlist(lapply(res$files[grepl("^_weft/ledger/", names(res$files))],
                             function(x) strsplit(x, "\n", fixed = TRUE)[[1]]))
  expect_false(any(grepl("\"kind\":\"table\"", all_lines, fixed = TRUE)))
})

test_that("GT1: the same document with a jupyter engine records its table", {
  md <- c("---", "jupyter: python3", "---", "", tt_cell("tbl-a", TT_PIPE))
  res <- tt_run(md, name = "doc.qmd")
  expect_identical(res$status, 0L)
  es <- tt_tables(res, "_weft/ledger/doc.qmd/out.jsonl")
  expect_length(es, 1L)
  expect_identical(es[[1]]$file, "doc.qmd")
  expect_identical(es[[1]]$text, tt_hash(TT_CANON))
})

# ---- GT4: across Pandocs -----------------------------------------------------------------------------------------

test_that("GT4: every Pandoc from 3.1 gives the same digests for pipe, HTML and headless tables", {
  skip_if_no_lua_pandoc()
  headless <- "<table><tbody><tr><td>a</td><td>b</td></tr><tr><td>1</td><td>2</td></tr></tbody></table>"
  md <- c(tt_cell("tbl-pipe", TT_PIPE), tt_cell("tbl-html", tt_raw(TT_HTML_AB)),
          tt_cell("tbl-nohead", tt_raw(headless)))
  seen <- 0L
  for (p in lua_pandocs()) {
    if (!lua_version_ok(p)) next
    seen <- seen + 1L
    es <- tt_tables(tt_run(md, pandoc = p))
    expect_length(es, 3L)
    expect_identical(tt_texts(es), rep(tt_hash(TT_CANON), 3L), label = paste("digests under pandoc", p$version))
  }
  expect_gt(seen, 0L)
})

# ---- GT10: changes() --------------------------------------------------------------------------------------------

test_that("GT10, E70 to E72: two filter runs (one table changed, one dropped, one added) are listed by changes()", {
  skip_if(Sys.which("git") == "")
  run1 <- tt_run(c(tt_cell("tbl-sites", TT_PIPE), tt_cell("tbl-gone", c("| g |", "|---|", "| 7 |"))))
  run2 <- tt_run(c(tt_cell("tbl-sites", c("| a | b |", "|---|---|", "| 1 | 3 |")),
                   tt_cell("tbl-new", c("| n |", "|---|", "| 5 |"))))
  l1 <- run1$files[[tt_ledger]]
  l2 <- run2$files[[tt_ledger]]
  expect_false(is.null(l1))
  expect_false(is.null(l2))
  skip_if(is.null(l1) || is.null(l2), "the filter wrote no ledger")
  dir <- e2x_project()
  e2x_write(file.path(dir, "doc.md"), "# a document")
  e2x_write(file.path(dir, tt_ledger), l1)
  e2x_commit(dir)
  e2x_write(file.path(dir, tt_ledger), l2)
  out <- capture.output(print(weft::changes(path = dir)))
  expect_length(grep("table `tbl-sites` changed$", out), 1L)
  expect_length(grep("doc\\.md \\(out\\): 1 table added: tbl-new$", out), 1L)
  expect_length(grep("doc\\.md \\(out\\): 1 table removed: tbl-gone$", out), 1L)
  brief <- capture.output(print(weft::changes(path = dir), brief = TRUE))
  expect_length(grep("table `|tables? (added|removed)", brief), 0L)
})
