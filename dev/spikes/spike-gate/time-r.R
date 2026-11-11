## In-process timings (median of 5): JSON reading with jsonlite, and the stand-in scanner. Run after run-timing-1.sh.
suppressMessages({library(jsonlite)}); source("lib.R")
med <- function(expr_fn, n = 5) { t <- replicate(n, system.time(expr_fn())[["elapsed"]]); median(t) }
out <- list()
for (np in c(100, 500, 2000)) {
  f <- sprintf("out/timing/p%d.sp.json", np); f2 <- sprintf("out/timing/p%d.json", np); q <- sprintf("out/timing/docs/doc%d.qmd", np)
  lines <- readLines(q); txt <- paste(lines, collapse = "\n")
  j <- fromJSON(f, simplifyVector = FALSE)
  row <- data.frame(paragraphs = np, json_sp_MB = round(file.size(f) / 1e6, 2), json_nosp_MB = round(file.size(f2) / 1e6, 2),
    fromJSON_sp_s = med(function() fromJSON(f, simplifyVector = FALSE)),
    read_json_sp_s = med(function() read_json(f)),
    fromJSON_nosp_s = med(function() fromJSON(f2, simplifyVector = FALSE)),
    parsed_sp_object_MB = round(as.numeric(object.size(j)) / 1e6, 1),
    n_json_blocks = length(j$blocks),
    scan_whole_doc_s = med(function() scan_ids(txt, strict = TRUE), n = if (np == 2000) 3 else 5),
    scan_units_s = med(function() extract_units(lines, strict = TRUE), n = if (np == 2000) 3 else 5))
  out[[length(out) + 1L]] <- row
}
T <- do.call(rbind, out); print(T, row.names = FALSE); write.csv(T, "out/timing-r.csv", row.names = FALSE)
cat("\nconstructs found (whole-doc scan vs unit scan) 2000-para doc:", length(scan_ids(paste(readLines("out/timing/docs/doc2000.qmd"), collapse = "\n"), TRUE)),
    length(unlist(lapply(extract_units(readLines("out/timing/docs/doc2000.qmd"), TRUE), `[[`, "ids"))), "\n")
