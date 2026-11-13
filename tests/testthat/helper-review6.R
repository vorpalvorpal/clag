# Package 6L (the filter's review fixes): helpers for test-review6-filter.R, test-review6-filter-2.R and
# test-conformance-review6.R (dev/review-stage6.md and its rulings). ASCII only. Builds on helper-filter.R
# (filter_md(), carrier(), fr_*(), fm_msg, filter_cases(), expect_cases()), helper-6g.R and helper-6f.R.
#
#   r6_rec_checks(record, checks_json)   a record with a raw `checks` member (any JSON text).
#   r6_paras(res)                        the output paragraphs of a plain-text run.
#   r6_valid_utf8(x)                     TRUE when the string is valid UTF-8 and holds no U+FFFD.

r6_rec_checks <- function(record, checks_json) {
  sub("\\}$", sprintf(',"checks":%s}', checks_json), record)
}

r6_paras <- function(res) {
  trimws(strsplit(trimws(res$output), "\n\n", fixed = TRUE)[[1]])
}

r6_valid_utf8 <- function(x) {
  x <- enc2utf8(x)
  validUTF8(x) && !grepl("\ufffd", x, fixed = TRUE)
}

# the whole block of a plain run: a text of `n` bytes that is valid JSON for a values file
r6_padded_json <- function(bytes) {
  head <- '{"weft":1,"values":{}}'
  paste0(head, strrep(" ", bytes - nchar(head)))
}
