# Extracted from test-filter-direct.R:288

# prequel ----------------------------------------------------------------------
fmt_classes <- c(".num", ".pct", ".sci", ".p", ".date", ".no", ".word", ".count",
                 ".ord", ".and", ".or", ".pairs", ".range", ".ul", ".ol", ".dl")
draft_cases <- list(
  span   = "Found [one site | # sites]{n=\"k\"} here.",
  attr   = "Depth is 12.5{.num} here.",
  marker = "Depth 12.5<<weft: failed claim, line 4>> here.",
  code   = "Depth `r depth` here.",
  placeholder = paste0("Depth ", intToUtf8(0xE001), " here.")
)

# test -------------------------------------------------------------------------
dir <- tempfile("weft-collect-")
dir.create(dir)
coll <- file.path(dir, "failures.jsonl")
first <- "{\"kind\":\"failed claim\",\"file\":\"a.qmd\",\"line\":3}"
writeLines(first, coll)
for (nm in names(draft_cases)) {
    r <- run_filter(draft_cases[[nm]], env = c(WEFT_COLLECT = coll))
    expect_identical(r$status, 0L, label = paste("collecting,", nm))
  }
lines <- readLines(coll, warn = FALSE)
lines <- lines[nzchar(trimws(lines))]
