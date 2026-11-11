## Compare my line-based units with Pandoc's (commonmark_x+sourcepos) leaf blocks: start lines of Para/Plain/Header.
source("lib.R")
pandoc_leaf_lines <- function(file) {
  js <- system2("quarto", c("pandoc", "-f", "commonmark_x+sourcepos", "-t", "json", shQuote(file)), stdout = TRUE)
  j <- jsonlite::fromJSON(paste(js, collapse = "\n"), simplifyVector = FALSE)
  out <- list()
  walk <- function(bl, line = NA) for (b in bl) {
    if (b$t == "Div") {
      dp <- Filter(function(kv) kv[[1]] == "data-pos", b$c[[1]][[3]])
      ln <- if (length(dp)) as.integer(sub("^.*@([0-9]+):.*$", "\\1", dp[[1]][[2]])) else line
      walk(b$c[[2]], ln)
    } else if (b$t == "Header") { dp <- Filter(function(kv) kv[[1]] == "data-pos", b$c[[2]][[3]]); out[[length(out) + 1L]] <<- list(t = "Header", line = if (length(dp)) as.integer(sub("^.*@([0-9]+):.*$", "\\1", dp[[1]][[2]])) else NA, n = 0) }
    else if (b$t %in% c("Para", "Plain")) out[[length(out) + 1L]] <<- list(t = b$t, line = line, n = length(b$c))
    else if (b$t %in% c("BulletList", "OrderedList", "BlockQuote")) walk(if (b$t == "BulletList") unlist(b$c, recursive = FALSE) else if (b$t == "OrderedList") unlist(b$c[[2]], recursive = FALSE) else b$c, line)
    else out[[length(out) + 1L]] <<- list(t = b$t, line = line, n = 0)
  }
  walk(j$blocks); out
}
args <- commandArgs(TRUE); f <- args[1]
pl <- pandoc_leaf_lines(f); pt <- vapply(pl, `[[`, "", "t"); pn <- vapply(pl, `[[`, 0L, "line")
u <- extract_units(readLines(f)); un <- vapply(u, `[[`, 0L, "line")
cat(f, ": pandoc leaf blocks:", length(pl), " (", paste(names(table(pt)), table(pt), collapse = ", "), ")  my units:", length(u), "\n")
cat("units whose start line is not a pandoc leaf-start line:", sum(!(un %in% pn)), "\n")
print(u[!(un %in% pn)] |> lapply(function(x) c(x$line, x$type, substr(x$text, 1, 60))) |> do.call(what = rbind))
pp <- pl[!(pn %in% un) & pt %in% c("Para", "Plain", "Header")]
cat("pandoc Para/Plain/Header starts that are not one of my unit starts:", length(pp), "\n")
for (x in pp) cat("  line", x$line, x$t, "\n")
