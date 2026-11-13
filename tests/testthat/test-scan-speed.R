# The scanner's whole-text matches on a non-ASCII document (dev/lint-profile.md, hot spot 1). R turns each
# match's byte offset into a character offset from the start of the string, so blank lines x length was
# quadratic: 14 s of a 36 s one-file lint on a 21-chapter book. new_scan() now matches through gmatch().

ss_doc <- function(paras) {
  one <- c("Café depth is `r depth`{.num} m at the 中文 site.", "",
           "The level [rose | fell]{if=\"up\"} again — see @fig-a.", "")
  rep(one, paras)
}

# The cost of a construct is the same in either text (about 0.3 ms), so the measure is the non-ASCII
# document against its ASCII twin, not a fixed time. Before the change the non-ASCII one took more than
# twice as long (5.1 s against 2.3 s here).
test_that("scan speed: a non-ASCII document scans about as fast as its ASCII twin", {
  skip_on_cran()
  lines <- ss_doc(4000L)
  twin <- chartr("\u00e9\u4e2d\u6587\u2014", "ezw-", lines)
  got <- NULL
  plain <- cpu_time(weft:::scan_document(twin, file = NA_character_))
  elapsed <- cpu_time(got <- weft:::scan_document(lines, file = NA_character_))
  expect_identical(sum(got$kind != "bare"), 8000L)
  expect_lt(elapsed, 1.5 * plain + 0.3)
})

test_that("scan speed: the rows of a non-ASCII document are those of its ASCII twin, position for position", {
  lines <- ss_doc(40L)
  twin <- chartr("é中文—", "ezw-", lines)
  expect_identical(nchar(twin), nchar(lines))
  a <- weft:::scan_document(lines, file = NA_character_)
  b <- weft:::scan_document(twin, file = NA_character_)
  pos <- intersect(names(a), c("kind", "line", "col", "start", "end", "line_end", "col_end"))
  expect_gt(length(pos), 2L)
  expect_identical(a[pos], b[pos])
})
