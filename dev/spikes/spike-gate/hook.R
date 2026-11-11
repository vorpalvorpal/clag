## hook.R -- throwaway pre-commit hook body, for timing only.
##   Rscript --vanilla hook.R [--pandoc=quarto|direct] [--once] [--compare] [--range] files...
## Steps (each timed): load code, git show, scan, pandoc (sourcepos JSON), read JSON, [match].
t00 <- Sys.time(); HERE <- "/private/tmp/claude-501/-Users-rjs-dev-clag/bb4358e7-968a-4a0e-b048-468bd4e2be97/scratchpad/spike-gate"
args <- commandArgs(TRUE); opt <- args[startsWith(args, "--")]; files <- args[!startsWith(args, "--")]
pandoc_bin <- if ("--pandoc=direct" %in% opt) c("/Applications/quarto/bin/tools/aarch64/pandoc") else c("quarto", "pandoc")
once <- "--once" %in% opt; compare <- "--compare" %in% opt; range <- "--range" %in% opt
TM <- c(); tick <- function(nm, expr) { s <- Sys.time(); v <- force(expr); TM[nm] <<- (if (nm %in% names(TM)) TM[[nm]] else 0) + as.numeric(Sys.time() - s, units = "secs"); invisible(v) }
tick("load_code", { suppressMessages(library(jsonlite)); source(file.path(HERE, "lib.R")) })
rev_after <- if (range) "HEAD" else ""; rev_before <- if (range) "HEAD~1" else "HEAD"
show_last <- NULL
show <- function(rev, f) { show_last <<- system2("git", c("show", paste0(rev, ":", f)), stdout = TRUE, stderr = FALSE); invisible(show_last) }
pandoc_json <- function(paths, out) system2(pandoc_bin[1], c(pandoc_bin[-1], "-f", "commonmark_x+sourcepos", "-t", "json", "-o", out, paths))
res <- list(); texts <- list()
for (f in files) {
  la <- tick("git_show", show(rev_after, f)); la <- show_last; lb <- if (compare) { tick("git_show", show(rev_before, f)); show_last }
  if (compare) { m <- tick("scan_and_match", match_versions(lb, la)); res[[f]] <- length(m$events) }
  else { u <- tick("scan", extract_units(la, strict = TRUE)); res[[f]] <- length(u) }
  texts[[f]] <- list(after = la, before = lb)
}
## pandoc: one process per file, or one for all
versions <- if (compare) c("after", "before") else "after"
tmpdir <- tempfile("hook"); dir.create(tmpdir); n_json <- 0L; nblocks <- 0L
for (v in versions) {
  paths <- character(); k <- 0L
  for (f in files) { k <- k + 1L; p <- file.path(tmpdir, sprintf("%s-%03d.qmd", v, k)); writeLines(texts[[f]][[v]], p); paths <- c(paths, p) }
  if (once) { out <- file.path(tmpdir, paste0(v, "-all.json")); tick("pandoc", pandoc_json(paths, out)); j <- tick("read_json", read_json(out)); nblocks <- nblocks + length(j$blocks) }
  else for (p in paths) { out <- sub("\\.qmd$", ".json", p); tick("pandoc", pandoc_json(p, out)); j <- tick("read_json", read_json(out)); nblocks <- nblocks + length(j$blocks) }
}
unlink(tmpdir, recursive = TRUE)
TM["total_in_R"] <- as.numeric(Sys.time() - t00, units = "secs")
cat(sprintf("files=%d blocks=%d | %s\n", length(files), nblocks, paste(sprintf("%s=%.3f", names(TM), TM), collapse = " ")), file = stderr())
