# Helpers for package 6g: stamps, collection, ledger and verify() for the resolver filter
# (dev/design-6.md N110 to N122, N130h to N133h, N92). ASCII only. Builds on helper-filter.R
# (filter_md(), carrier(), fr_*(), fm_msg, fm_doc()), helper-quarto.R and helper-4c.R.
#
#   g6_block()            a weft-values block with `run` and `at` members (N21).
#   g6_local_time()       R's "%Y-%m-%d %H:%M:%S" local form of whole seconds since 1970 (N110).
#   g6_stamp()            the parsed stamp of a filter_md() result (NULL, with a failed expectation, if none).
#   g6_ledger_lines()     the lines of the ledger file of a filter_md() result.
#   g6_entries()          the parsed entries of that file (header dropped).
#   g6_header()           the parsed header.

G6_YML <- c("draft: false", "ledger: true")
G6_YML_OFF <- c("draft: false", "ledger: false")
G6_LEDGER <- "_weft/ledger/doc.md/out.jsonl"
G6_STAMP <- ".weft/stamps/doc.md.json"

g6_block <- function(..., run = NULL, at = NULL) {
  m <- c(if (!is.null(run)) sprintf("\"run\":\"%s\"", run),
         if (!is.null(at)) sprintf("\"at\":%d", as.integer(at)))
  carrier(..., members = if (length(m)) paste(m, collapse = ",") else NULL)
}

g6_local_time <- function(at) format(as.POSIXct(at, origin = "1970-01-01"), "%Y-%m-%d %H:%M:%S")

g6_json <- function(text) jsonlite::fromJSON(text, simplifyVector = FALSE)

g6_stamp <- function(res, path = G6_STAMP) {
  txt <- res$files[[path]]
  testthat::expect(!is.null(txt), sprintf("the filter wrote %s (it wrote: %s)", path,
                                          paste(names(res$files), collapse = ", ")))
  if (is.null(txt)) return(NULL)
  g6_json(txt)
}

g6_ledger_lines <- function(res, path = G6_LEDGER) {
  txt <- res$files[[path]]
  testthat::expect(!is.null(txt), sprintf("the filter wrote %s (it wrote: %s)", path,
                                          paste(names(res$files), collapse = ", ")))
  if (is.null(txt)) return(character())
  strsplit(txt, "\n", fixed = TRUE)[[1]]
}

g6_entries <- function(res, path = G6_LEDGER) lapply(g6_ledger_lines(res, path)[-1], g6_json)
g6_header <- function(res, path = G6_LEDGER) {
  l <- g6_ledger_lines(res, path)
  if (!length(l)) return(NULL)
  g6_json(l[1])
}

# "kind|expr|occ" of each entry
g6_keys <- function(entries) {
  vapply(entries, function(e) paste(e$kind, e$expr, e$occ, sep = "|"), "")
}
g6_pick <- function(entries, kind, expr, occ = 1L) {
  hit <- Filter(function(e) identical(e$kind, kind) && identical(e$expr, expr) && identical(as.integer(e$occ), as.integer(occ)), entries)
  testthat::expect(length(hit) == 1L, sprintf("exactly one ledger entry for %s|%s|%d (got %d)", kind, expr, occ, length(hit)))
  if (length(hit)) hit[[1]] else list()
}
