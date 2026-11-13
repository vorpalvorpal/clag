# Package 6g: the ledger the resolver filter writes (dev/design-6.md N112, with 7.1.3 to 7.1.5 and the
# entry layout of R's ledger, dev/design-2d.md D4 and D8). Plain Pandoc through filter_md(): the output
# is `out.txt`, so the output name is "out" and the file is `_weft/ledger/doc.md/out.jsonl`.
# ASCII only. Invented content.

LG_FIELDS <- c("file", "section", "kind", "expr", "occ", "id", "context", "text", "arm", "rel", "raw")

lg_run <- function(md, files = list(), weft_yml = G6_YML, env = c(WEFT_RUN = "R1"), ...) {
  filter_md(md, files = files, weft_yml = weft_yml, env = env, ...)
}

LG_BLOCK <- g6_block(depth = fr_float("12.5"), n_sites = fr_int("3"), rising = fr_bool(TRUE),
                     a = fr_int("1"), b = fr_int("2"), run = "R1", at = 1794822900L)
LG_DOC <- c(LG_BLOCK, "", "## Data", "",
            "Depth `depth`{.num} and again `depth`{.num}. Found [one site | # sites]{n=\"n_sites\"} here. [up | down]{if=\"rising\"} ok.",
            "",
            "[`a`{.num} apples | `b`{.num} pears]{if=\"rising\"} here.")

test_that("N112: every construct the filter resolved has an entry, keyed by 7.1.4, written by \"filter\"", {
  res <- lg_run(LG_DOC)
  expect_identical(res$status, 0L)
  es <- g6_entries(res)
  # a named value is kind "value", a span its key; a chosen arm's named value has its own entry; the
  # named value in the arm not chosen (b) has none; the two `if` spans on `rising` are occurrences 1 and 2
  expect_setequal(g6_keys(es), c("value|depth|1", "value|depth|2", "value|a|1", "n|n_sites|1",
                                 "if|rising|1", "if|rising|2"))
  expect_length(es, 6L)
  for (e in es) {
    expect_identical(e$writer, "filter")
    expect_identical(e$file, "doc.md")
    expect_identical(e$section, "data")
    expect_identical(e$context, "prose")
    expect_null(e$id)
    expect_null(e$failed)
  }
})

test_that("N112: the entry's fields are R's, in R's order, with the printed text, the arm and the raw value", {
  es <- g6_entries(lg_run(LG_DOC))
  d <- g6_pick(es, "value", "depth", 1)
  expect_identical(names(d)[seq_along(LG_FIELDS)], LG_FIELDS)
  expect_identical(d$text, "12.5")
  expect_null(d$arm)
  expect_identical(d$rel, "=")
  expect_equal(d$raw, 12.5)
  d2 <- g6_pick(es, "value", "depth", 2)
  expect_identical(d2$text, "12.5")
  a <- g6_pick(es, "value", "a", 1)
  expect_identical(a$text, "1")
  expect_equal(a$raw, 1)
  n <- g6_pick(es, "n", "n_sites", 1)
  expect_identical(n$text, "3 sites")
  expect_identical(n$arm, "other")
  expect_identical(n$rel, "=")
  expect_equal(n$raw, 3)
  i1 <- g6_pick(es, "if", "rising", 1)
  expect_identical(i1$text, "up")
  expect_identical(i1$arm, "true")
  i2 <- g6_pick(es, "if", "rising", 2)
  expect_identical(i2$arm, "true")
})

test_that("N112: the raw value of a string or a missing record is null, a float's is its number", {
  blk <- g6_block(site = fr_str("north"), f = fr_float("3.14159"), run = "R1")
  es <- g6_entries(lg_run(c(blk, "", "Site `site`{.val} and `f`{.num}.")))
  expect_null(g6_pick(es, "value", "site", 1)$raw)
  expect_identical(g6_pick(es, "value", "site", 1)$text, "north")
  expect_equal(g6_pick(es, "value", "f", 1)$raw, 3.14159)
  expect_identical(g6_pick(es, "value", "f", 1)$text, "3.14159")
})

test_that("N112: the expression of a span is its governor value with runs of spaces made one; an id is kept", {
  md <- c(LG_BLOCK, "", "Many [x | y]{if=\"n_sites  >   2\"} here, and `depth`{#d .num} too.")
  es <- g6_entries(lg_run(md))
  e <- g6_pick(es, "if", "n_sites > 2", 1)
  expect_identical(e$text, "x")
  expect_identical(e$arm, "true")
  d <- g6_pick(es, "value", "depth", 1)
  expect_identical(d$id, "d")
})

test_that("N112: the lines are sorted by 7.1.5: file, section, kind, expression, occurrence", {
  es <- g6_entries(lg_run(LG_DOC))
  f <- vapply(es, function(e) e$file, ""); s <- vapply(es, function(e) e$section, "")
  k <- vapply(es, function(e) e$kind, ""); x <- vapply(es, function(e) e$expr, "")
  o <- vapply(es, function(e) as.integer(e$occ), 1L)
  expect_identical(order(f, s, k, x, o, method = "radix"), seq_along(es))
})

test_that("N112: the sentence is the block's text cut at the last '. ', '? ' or '! ' before the construct", {
  blk <- g6_block(north = fr_str("north"), run = "R1")
  md <- c(blk, "",
          "First one. Then `north`{.val} here.", "",
          "Why? Then `north`{.val} here.", "",
          "Stop! Then `north`{.val} here.", "",
          "Then `north`{.val} here. Last one.", "",
          "Why not\n`north`{.val} again.", "",
          "Dr. Smith saw `north`{.val} today.")
  es <- g6_entries(lg_run(md))
  expect_length(es, 6L)
  sentence <- function(i) g6_pick(es, "value", "north", i)$sentence
  expect_identical(sentence(1), "Then north here.")
  expect_identical(sentence(2), "Then north here.")
  expect_identical(sentence(3), "Then north here.")
  expect_match(fm_or(sentence(4), ""), "^Then north here\\.?$")       # cut at the first '. ' after: no 'Last one'
  expect_identical(sentence(5), "Why not north again.")    # a soft break is a space; no boundary before
  expect_identical(sentence(6), "Smith saw north today.")  # not ICU: 'Dr. ' is a boundary here
})

test_that("N112: with no ledger file the header has the source's hash and empty dict and targets", {
  res <- lg_run(c(LG_BLOCK, "", "Depth `depth`{.num}."))
  l <- g6_ledger_lines(res)
  expect_match(l[1], paste0("^\\{\"weft\":\"ledger\",\"version\":1,\"source\":\"doc\\.md\",\"output\":\"out\",",
                            "\"dict\":\\{\\},\"files\":\\{\"doc\\.md\":\"[0-9a-f]+\"\\},\"targets\":\\{\\}\\}$"))
})

test_that("N112: the header's `files` holds the source and every file of the include map, recursively", {
  md <- c(LG_BLOCK, "", "Intro.", "", "{{< include inc.md >}}", "", "Depth `depth`{.num}.")
  res <- lg_run(md, files = list("inc.md" = c("Inner.", "", "{{< include deep.md >}}"), "deep.md" = "Deepest."))
  h <- g6_header(res)
  expect_identical(names(h$files), c("deep.md", "doc.md", "inc.md"))
  expect_true(all(vapply(h$files, function(x) is.character(x) && grepl("^[0-9a-f]+$", x), NA)))
  expect_identical(h$dict, structure(list(), names = character()))
  expect_identical(h$targets, structure(list(), names = character()))
})

test_that("N112: a file's hash is taken with line ends made \\n, so CRLF and LF sources hash alike", {
  lf <- c(LG_BLOCK, "", "Depth `depth`{.num} here.")
  crlf <- paste0(lf, "\r")
  h1 <- g6_header(lg_run(lf))
  h2 <- g6_header(lg_run(crlf))
  expect_true(is.character(h1$files[["doc.md"]]) && nzchar(h1$files[["doc.md"]]))
  expect_identical(h1$files[["doc.md"]], h2$files[["doc.md"]])
})

LG_HOOKS_BARE <- paste0("{\"file\":\"doc.md\",\"section\":\"\",\"kind\":\"bare\",\"expr\":\"k\",\"occ\":1,\"id\":null,",
                        "\"context\":\"prose\",\"text\":\"3\",\"arm\":null,\"rel\":null,\"raw\":3,\"unit\":null,",
                        "\"failed\":null,\"dict\":[],\"sentence\":\"Value 3 here.\"}")
LG_HOOKS_ZZ <- paste0("{\"file\":\"doc.md\",\"section\":\"data\",\"kind\":\"value\",\"expr\":\"zz\",\"occ\":1,\"id\":null,",
                      "\"context\":\"prose\",\"text\":\"9\",\"arm\":null,\"rel\":\"=\",\"raw\":9,\"unit\":null,",
                      "\"failed\":null,\"dict\":[],\"sentence\":\"Hooks 9 here.\"}")
lg_old <- function(expr, text) {
  sprintf(paste0("{\"file\":\"doc.md\",\"section\":\"data\",\"kind\":\"value\",\"expr\":\"%s\",\"occ\":1,\"id\":null,",
                 "\"context\":\"prose\",\"text\":\"%s\",\"arm\":null,\"rel\":\"=\",\"raw\":1,\"unit\":null,",
                 "\"failed\":null,\"dict\":[],\"sentence\":\"Old.\",\"writer\":\"filter\"}"), expr, text)
}
LG_HEADER <- paste0("{\"weft\":\"ledger\",\"version\":1,\"source\":\"doc.md\",\"output\":\"out\",\"dict\":{},",
                    "\"files\":{\"doc.md\":\"0123456789abcdef\"},\"targets\":{}}")

test_that("N112: it merges: the filter's earlier entries are dropped, the hooks' kept as written, its own added", {
  seed <- c(LG_HEADER, LG_HOOKS_BARE, lg_old("depth", "OLD"), lg_old("gone", "OLD"), LG_HOOKS_ZZ)
  md <- c(g6_block(depth = fr_float("12.5"), run = "R1"), "", "## Data", "", "Depth `depth`{.num} m.")
  res <- lg_run(md, files = setNames(list(seed), G6_LEDGER))
  expect_identical(res$status, 0L)
  l <- g6_ledger_lines(res)
  expect_match(l[1], "^\\{\"weft\":\"ledger\",\"version\":1,\"source\":\"doc\\.md\",\"output\":\"out\"")
  # the hooks' lines are kept byte for byte
  expect_true(LG_HOOKS_BARE %in% l)
  expect_true(LG_HOOKS_ZZ %in% l)
  es <- lapply(l[-1], g6_json)
  expect_setequal(g6_keys(es), c("bare|k|1", "value|depth|1", "value|zz|1"))   # `gone` dropped, `depth` once
  d <- g6_pick(es, "value", "depth", 1)
  expect_identical(d$text, "12.5")
  expect_identical(d$writer, "filter")
  expect_false(any(grepl("OLD", l, fixed = TRUE)))
  # sorted by 7.1.5
  f <- vapply(es, function(e) e$file, ""); s <- vapply(es, function(e) e$section, "")
  k <- vapply(es, function(e) e$kind, ""); x <- vapply(es, function(e) e$expr, "")
  o <- vapply(es, function(e) as.integer(e$occ), 1L)
  expect_identical(order(f, s, k, x, o, method = "radix"), seq_along(es))
})

test_that("N112: a second render of the same document leaves the ledger as it was, and replaces only its own", {
  md <- c(g6_block(depth = fr_float("12.5"), run = "R1"), "", "## Data", "", "Depth `depth`{.num} m.")
  seed <- c(LG_HEADER, LG_HOOKS_BARE, LG_HOOKS_ZZ)
  res1 <- lg_run(md, files = setNames(list(seed), G6_LEDGER))
  res2 <- lg_run(md, files = res1$files)
  expect_identical(res2$files[[G6_LEDGER]], res1$files[[G6_LEDGER]])
  # a changed value replaces the filter's entry and nothing else
  md3 <- c(g6_block(depth = fr_float("13.5"), run = "R1"), "", "## Data", "", "Depth `depth`{.num} m.")
  res3 <- lg_run(md3, files = res1$files)
  l <- g6_ledger_lines(res3)
  expect_true(LG_HOOKS_BARE %in% l && LG_HOOKS_ZZ %in% l)
  es <- lapply(l[-1], g6_json)
  expect_length(es, 3L)
  expect_identical(g6_pick(es, "value", "depth", 1)$text, "13.5")
})

test_that("N112: `ledger: false` writes no ledger, and a project that is not set up writes none either (control)", {
  md <- c(LG_BLOCK, "", "Depth `depth`{.num}.")
  off <- lg_run(md, weft_yml = G6_YML_OFF)
  expect_identical(off$status, 0L)
  expect_false(any(grepl("^_weft/ledger/", names(off$files))))
  plain <- filter_md(md, env = c(WEFT_RUN = "R1"))
  expect_identical(plain$status, 0L)
  expect_length(plain$files, 0L)
})
