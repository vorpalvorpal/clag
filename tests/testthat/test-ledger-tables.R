# 7c: F3, tables in the ledger (dev/design-7.md section 2.C, N30 to N40). Written before the code.
# Made-up content only; ASCII only. A "control" is a test that passes before the feature exists.
if (!exists("t7c_chunk")) source(Filter(file.exists, c(testthat::test_path("helper-7c.R"), testthat::test_path("..", "helper-7c.R")))[[1]])
d2_need()

kable_chunk <- function(label = "tbl-sites", yaml = "tbl-cap: \"Site table\"", df = T7C_DF) {
  t7c_chunk(label, c(df, "knitr::kable(d, format = 'pipe')"), yaml = yaml)
}

# the visible text of the fixture's kable, written out: white space collapsed (N33)
pipe_text <- function() {
  x <- knitr::kable(data.frame(site = c("A", "B"), depth = c(1.5, 2.5)), format = "pipe")
  trimws(gsub("[[:space:]]+", " ", paste(unclass(x), collapse = "\n")))
}

# ---- N30, N31, N32: one kable ---------------------------------------------------------------------

test_that("N30-N32: a labelled kable chunk gives one entry of kind table with the key and digest shape", {
  res <- t7c_knit(kable_chunk())
  t <- t7c_tables(res)
  expect_length(t, 1L)
  e <- t[[1]]
  expect_identical(e$kind, "table")
  expect_identical(e$expr, "tbl-sites")
  expect_identical(e$id, "tbl-sites")
  expect_identical(e$occ, 1L)
  expect_identical(e$file, "doc.Rmd")
  expect_identical(e$section, "")
  expect_identical(e$context, "chunk")
  expect_match(e$text, "^[0-9a-f]{16}$")
  expect_identical(e$text, t7c_hash(pipe_text()))
  expect_null(e$arm)
  expect_null(e$rel)
  expect_null(e$raw)
  expect_null(e$unit)
  expect_null(e$failed)
  expect_identical(e$dict, list())
  expect_identical(e$sentence, "Site table")
})

test_that("N32 + N34: one ledger line, byte for byte", {
  res <- t7c_knit(kable_chunk())
  line <- grep("\"kind\":\"table\"", d2_lines(d2_path(res$dir)), value = TRUE, fixed = TRUE)
  expect_length(line, 1L)
  want <- paste0("{\"file\":\"doc.Rmd\",\"section\":\"\",\"kind\":\"table\",\"expr\":\"tbl-sites\",\"occ\":1,",
                 "\"id\":\"tbl-sites\",\"context\":\"chunk\",\"text\":\"", t7c_hash(pipe_text()),
                 "\",\"arm\":null,\"rel\":null,\"raw\":null,\"unit\":null,\"failed\":null,\"dict\":[],",
                 "\"sentence\":\"Site table\"}")
  expect_identical(line, want)
  expect_lt(nchar(line, "bytes"), 300L)
})

test_that("N38: the ledger version stays 1, the columns are the v1 columns, and read_ledger() reads the file", {
  res <- t7c_knit(kable_chunk())
  expect_identical(d2_header(d2_path(res$dir))$version, 1L)
  expect_identical(names(t7c_tables(res)[[1]]), weft:::LEDGER_COLS)
  l <- weft:::read_ledger(d2_path(res$dir))
  expect_identical(sum(l$kind == "table"), 1L)
  expect_identical(weft:::LEDGER_VERSION, 1L)
})

# ---- N31: positions, unlabelled chunks ---------------------------------------------------------------

test_that("N31: two tables in one chunk get occ 1 and 2, with the chunk's label as id", {
  res <- t7c_knit(t7c_chunk("tbl-two", c(T7C_DF, "knitr::kable(d, format = 'pipe')",
                                         "knitr::kable(d[1, ], format = 'pipe')")))
  t <- t7c_tables(res)
  expect_length(t, 2L)
  expect_identical(vapply(t, function(e) e$occ, 1L), 1:2)
  expect_identical(vapply(t, function(e) e$expr, ""), c("tbl-two", "tbl-two"))
  expect_identical(vapply(t, function(e) e$id, ""), c("tbl-two", "tbl-two"))
  expect_false(identical(t[[1]]$text, t[[2]]$text))
})

test_that("N31: an unlabelled chunk has expr empty and id null; a second one gets occ 2", {
  res <- t7c_knit(c(t7c_chunk(NULL, c(T7C_DF, "knitr::kable(d, format = 'pipe')")),
                    t7c_chunk(NULL, c(T7C_DF, "knitr::kable(d[1, ], format = 'pipe')"))))
  t <- t7c_tables(res)
  expect_length(t, 2L)
  for (e in t) {
    expect_identical(e$expr, "")
    expect_null(e$id)
    expect_identical(e$context, "chunk")
  }
  expect_identical(vapply(t, function(e) e$occ, 1L), 1:2)
})

# ---- N30: asis text, and what is not recorded ----------------------------------------------------------

test_that("N30: text printed in a results='asis' chunk gives one entry per cat() call", {
  res <- t7c_knit(t7c_chunk("asis-two", c("cat('First text\\n\\n')", "cat('Second text\\n\\n')"),
                            opts = "echo=FALSE, results='asis'"))
  t <- t7c_tables(res)
  expect_length(t, 2L)
  expect_identical(vapply(t, function(e) e$text, ""), c(t7c_hash("First text"), t7c_hash("Second text")))
  expect_identical(vapply(t, function(e) e$occ, 1L), 1:2)
  expect_identical(t[[1]]$expr, "asis-two")
})

test_that("N30: verbatim output, include=FALSE, results='hide', empty and tag-only text record nothing; the kable still does", {
  doc <- c(kable_chunk("tbl-keep"),
           t7c_chunk("verb", c(T7C_DF, "print(d)")),
           t7c_chunk("hidden", c(T7C_DF, "knitr::kable(d, format = 'pipe')"), opts = "include=FALSE"),
           t7c_chunk("quiet", c(T7C_DF, "knitr::kable(d, format = 'pipe')"), opts = "echo=FALSE, results='hide'"),
           t7c_chunk("blank", "cat('\\n')", opts = "echo=FALSE, results='asis'"),
           t7c_chunk("tagonly", "cat('<div class=\"x\"></div>\\n<!-- note -->\\n')", opts = "echo=FALSE, results='asis'"))
  res <- t7c_knit(doc)
  t <- t7c_tables(res)
  expect_identical(vapply(t, function(e) e$expr, ""), "tbl-keep")
})

test_that("N30: a figure records no table entry (the kable beside it does)", {
  skip_if_not_installed("grDevices")
  doc <- c(kable_chunk("tbl-fig"),
           t7c_chunk("fig", "plot(1:3)", opts = "echo=FALSE, fig.path='figs/'"))
  res <- t7c_knit(doc)
  expect_identical(vapply(t7c_tables(res), function(e) e$expr, ""), "tbl-fig")
})

# ---- N32: the caption ------------------------------------------------------------------------------------

test_that("N32: the sentence is tab.cap when there is no tbl-cap, and tbl-cap when both are given", {
  res <- t7c_knit(c(kable_chunk("tbl-a", yaml = NULL, df = T7C_DF) |> sub(pattern = "echo=FALSE", replacement = "echo=FALSE, tab.cap='Depth table'", fixed = TRUE),
                    kable_chunk("tbl-b", yaml = "tbl-cap: \"Wins\"") |> sub(pattern = "echo=FALSE", replacement = "echo=FALSE, tab.cap='Loses'", fixed = TRUE)))
  t <- t7c_tables(res)
  expect_length(t, 2L)
  expect_identical(d2_one(t, expr = "tbl-a")$sentence, "Depth table")
  expect_identical(d2_one(t, expr = "tbl-b")$sentence, "Wins")
})

test_that("N32: with no caption the sentence is the first 80 characters of the normalised text, then '...' when cut", {
  long <- trimws(strrep("abcdefghij ", 12))
  res <- t7c_knit(c(t7c_chunk("cap-long", "cat(strrep('abcdefghij ', 12), '\\n')", opts = "echo=FALSE, results='asis'"),
                    t7c_chunk("cap-short", "cat('Short text\\n')", opts = "echo=FALSE, results='asis'")))
  t <- t7c_tables(res)
  expect_identical(d2_one(t, expr = "cap-long")$sentence, paste0(substr(long, 1L, 80L), "..."))
  expect_identical(d2_one(t, expr = "cap-short")$sentence, "Short text")
})

# ---- N32: stability and sensitivity of the digest -----------------------------------------------------------

test_that("N32: the digest is equal across two knits of the same data, and differs when one cell changes", {
  a1 <- t7c_digest(t7c_knit(kable_chunk()))
  a2 <- t7c_digest(t7c_knit(kable_chunk()))
  b <- t7c_digest(t7c_knit(kable_chunk(df = "d <- data.frame(site = c('A', 'B'), depth = c(1.5, 2.6))")))
  expect_match(a1, "^[0-9a-f]{16}$")
  expect_identical(a1, a2)
  expect_false(identical(a1, b))
})

# ---- N33: the normalisation, one step at a time, through the knit -------------------------------------------

n33 <- list(
  comment = c("cat('Before <!-- a\\nmultiline note --> after\\n')", "Before after"),
  style_script = c("cat('<STYLE>.a { color: red; }</STYLE>Beta <Script type=\"x\">var q = 1;</Script>gamma\\n')",
                   "Beta gamma"),
  tags = c("cat('<table class=\"x\"><tr><td>1.5</td> <td>A</td></tr></table>\\n')", "1.5 A"),
  tag_no_gap = c("cat('x<b>y</b>\\n')", "xy"),
  bang_tag = c("cat('<!DOCTYPE html>Epsilon\\n')", "Epsilon"),
  less_than = c("cat('x < 5 and y > 3\\n')", "x < 5 and y > 3"),
  fence_format = c("cat('```{=html}\\n<b>Delta</b>\\n```\\n')", "Delta"),
  fence_plain = c("cat('```\\nplain\\n```\\n')", "plain"),
  white = c("cat('  a \\t b\\r\\n\\r\\n  c  \\n')", "a b c"),
  entities = c("cat('A &amp; B &lt;\\n')", "A &amp; B &lt;"),
  digits = c("cat('12.50 and 3.0\\n')", "12.50 and 3.0")
)

test_that("N33: each step of the normalisation gives the documented text, hashed", {
  doc <- unlist(lapply(names(n33), function(k) {
    t7c_chunk(paste0("n33-", gsub("_", "-", k)), n33[[k]][1], opts = "echo=FALSE, results='asis'")
  }))
  res <- t7c_knit(doc)
  t <- t7c_tables(res)
  expect_length(t, length(n33))
  for (k in names(n33)) {
    e <- d2_pick(t, expr = paste0("n33-", gsub("_", "-", k)))
    expect_length(e, 1L)
    if (length(e) == 1L) expect_identical(e[[1]]$text, t7c_hash(n33[[k]][2]), label = k)
  }
})

test_that("N33: a change of style or markup is not a change; a change of a visible character is", {
  one <- function(code) t7c_digest(t7c_knit(t7c_chunk("n33-s", code, opts = "echo=FALSE, results='asis'")))
  base <- one("cat('<td class=\"a\" id=\"x1\">7.5</td>\\n')")
  expect_identical(base, one("cat('<td class=\"b\" id=\"zz9\" style=\"color:red\">7.5</td>\\n')"))
  expect_false(identical(base, one("cat('<td class=\"a\" id=\"x1\">7.6</td>\\n')")))
})

# ---- N37: error and cache ------------------------------------------------------------------------------------

# knitr goes on after an error under error=TRUE, so the element after it reaches the document too
test_that("N37: a chunk with error=TRUE records every element that reached the document", {
  res <- t7c_knit(t7c_chunk("tbl-err", c("cat('Before the error\\n\\n')", "stop('boom')", "cat('After\\n\\n')"),
                            opts = "echo=FALSE, error=TRUE, results='asis'"))
  t <- t7c_tables(res)
  expect_length(t, 2L)
  expect_identical(t[[1]]$text, t7c_hash("Before the error"))
  expect_identical(t[[2]]$text, t7c_hash("After"))
})

test_that("N37: draft mode records tables as usual", {
  res <- t7c_knit(kable_chunk(), files = list("_weft.yml" = "draft: true"))
  t <- t7c_tables(res)
  expect_length(t, 1L)
  expect_identical(t[[1]]$expr, "tbl-sites")
  expect_identical(t[[1]]$text, t7c_hash(pipe_text()))
})

test_that("N36: a chunk served from the cache replays its table rows; the ledger is byte-identical", {
  skip_if_not(rmarkdown::pandoc_available(), "pandoc is not available")
  dir <- withr::local_tempdir()
  doc <- t7c_chunk("tbl-cached", c("cat('ran\\n', file = 'ran.txt', append = TRUE)", T7C_DF,
                                    "knitr::kable(d, format = 'pipe')"), opts = "echo=FALSE, cache=TRUE")
  r1 <- t7c_knit(doc, dir = dir, format = "md")
  expect_length(t7c_tables(r1), 1L)
  b1 <- d2_bytes(d2_path(dir))
  r2 <- t7c_knit(doc, dir = dir, format = "md")
  expect_length(readLines(file.path(dir, "ran.txt")), 1L)
  expect_length(t7c_tables(r2), 1L)
  expect_identical(d2_bytes(d2_path(dir)), b1)
})

# ---- controls: what passes before the feature -------------------------------------------------------------------

test_that("control N38: an inline value still gets its entry beside a table chunk, and the header is unchanged", {
  res <- t7c_knit(c("Depth `r dpt` m.", "", kable_chunk()), code = "dpt <- 4")
  l <- d2_ledger(res)
  expect_length(Filter(function(e) identical(e$kind, "bare") || identical(e$kind, "value"), l), 1L)
  expect_identical(d2_header(d2_path(res$dir))$version, 1L)
})

test_that("control N30: print(df) alone records no table entry", {
  res <- t7c_knit(t7c_chunk("verb-only", c(T7C_DF, "print(d)")))
  expect_length(t7c_tables(res), 0L)
})

test_that("control N39: ledger: false writes no ledger file, tables or not", {
  res <- t7c_knit(kable_chunk(), files = list("_weft.yml" = c("draft: false", "ledger: false")))
  expect_false(dir.exists(file.path(res$dir, "_weft", "ledger")))
})

# ---- N33 + M7/M8: gt, flextable, tinytable (HTML), where installed --------------------------------------------

pkg_table <- list(
  gt = list(
    base = "gt::gt(d)",
    cell = "gt::gt(dd)",
    style = "gt::tab_options(gt::gt(d), table.font.size = 20, table.background.color = '#eeeeee')"),
  flextable = list(
    base = "flextable::flextable(d)",
    cell = "flextable::flextable(dd)",
    style = "flextable::color(flextable::bold(flextable::flextable(d), part = 'header'), color = 'red', part = 'body')"),
  tinytable = list(
    base = "tinytable::tt(d)",
    cell = "tinytable::tt(dd)",
    style = "tinytable::style_tt(tinytable::tt(d), i = 1, bold = TRUE, color = 'red')")
)

for (pkg in names(pkg_table)) {
  local({
    pkg <- pkg
    spec <- pkg_table[[pkg]]
    render1 <- function(expr) {
      t7c_digest(t7c_html(t7c_chunk(paste0("tbl-", pkg),
                                    c(T7C_DF, "dd <- d; dd$depth[2] <- 2.6", expr), opts = "echo=FALSE")))
    }
    test_that(paste0("N33 M8: ", pkg, " rendered twice to HTML gives equal digests; one cell changes it; a style does not"), {
      skip_if_not_installed(pkg)
      a1 <- render1(spec$base)
      a2 <- render1(spec$base)
      expect_match(a1, "^[0-9a-f]{16}$")
      expect_identical(a1, a2)
      expect_false(identical(a1, render1(spec$cell)))
      expect_identical(a1, render1(spec$style))
    })
  })
}
