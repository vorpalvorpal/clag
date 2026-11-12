# Hashes shared by the ledger header (2e-1) and the third state (2e-2).
# dev/design-2e.md P13, P14: xxhash64 of bytes, 16 hex characters.

# Is `targets` installed? Every part of 2e asks through here (P17), so a test
# can pretend it is not.
has_targets <- function() requireNamespace("targets", quietly = TRUE)

# The hash of a file's bytes with every CR LF made LF, or NA_character_ for a
# file that cannot be read (written `null` in a header).
file_hash <- function(path) {
  b <- tryCatch(readBin(path, "raw", file.size(path)), error = function(e) NULL,
                warning = function(w) NULL)
  if (is.null(b)) return(NA_character_)
  if (length(b) > 1L) {
    cr <- b[-length(b)] == as.raw(13L) & b[-1L] == as.raw(10L)
    b <- b[!c(cr, FALSE)]
  }
  cli::hash_raw_xxhash64(b)
}

DICT_DOC_FIELDS <- c("definition", "decision", "why", "term", "avoid")

# Names sorted byte by byte at every level, so field order changes nothing (P14).
sort_names <- function(x) {
  if (!is.list(x)) return(x)
  if (!is.null(names(x))) x <- x[order(names(x), method = "radix")]
  lapply(x, sort_names)
}

# A named character vector, key -> hash, in file order: the canonical JSON of
# each entry's YAML mapping (names sorted at every level) without the fields that
# print nothing in prose.
dict_entry_hashes <- function(path) {
  y <- yaml::read_yaml(path)
  if (!length(y)) return(stats::setNames(character(), character()))
  vapply(y, function(e) {
    if (is.list(e)) e <- sort_names(e[setdiff(names(e), DICT_DOC_FIELDS)])
    cli::hash_raw_xxhash64(charToRaw(enc2utf8(as.character(
      jsonlite::toJSON(e, auto_unbox = TRUE, digits = NA)))))
  }, "")
}
