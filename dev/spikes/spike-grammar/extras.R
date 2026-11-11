## Items 4-10. Sourced by run.R (or: Rscript extras.R). Prints findings to stdout.
if (!exists("ROOT")) source(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), "lib.R"))
unlink(list.files(OUT, pattern = "^x_", full.names = TRUE), recursive = TRUE)
rule <- function(t) cat("\n", strrep("=", 70), "\n", t, "\n", strrep("=", 70), "\n", sep = "")
qdoc <- function(name, body, setup = "", engine = "quarto", yaml = NULL, extra_files = list()) {
  ext <- if (engine == "quarto") ".qmd" else ".Rmd"
  L <- c(if (is.null(yaml)) doc_header(engine) else yaml, HEADER_CHUNK[1:2], 'source("setup.R"); clag_install()',
         'lg <- function(tag, v = "") { LOG <<- c(LOG, tag); v }; LOG <- character()', setup, "```", "", body)
  for (f in names(extra_files)) wr(extra_files[[f]], file.path(OUT, f))
  p <- file.path(OUT, paste0(name, ext)); wr(L, p); p
}
msg <- function(log) { m <- regmatches(log, regexpr("clag:[^\n]*", log)); if (length(m)) m else "(no clag: message)" }

## ---- 4 + 8: line numbers, includes -----------------------------------------------------------
rule("ITEM 4: exact line numbers (see also e_line_* in the matrix)")
for (engine in c("quarto", "rmarkdown")) {
  body <- c("Line A.", "", "Para with soft", "wrapped lines and a", "bad `r nosuch_x` on line 11 of the file.")
  p <- qdoc(paste0("x_line_", engine), body, engine = engine)
  L <- readLines(p); want <- grep("nosuch_x", L)
  r <- render_doc(p, engine); cat(sprintf("[%s] construct is on file line %d; message: %s\n", engine, want, msg(r$log)))
}
rule("ITEM 4/8: {{< include >}} (quarto)")
part <- c("Included line 1: value `r k`{.num}.", 'Included line 2: [# site | # sites]{n="n"}.', "Included line 3.")
setup <- "k <- 7.2; n <- 2"
body <- c("Before include.", "", "{{< include _part_ok.qmd >}}", "", "After include; value `r k`{.num}.")
p <- qdoc("x_inc_ok", body, setup, extra_files = list("_part_ok.qmd" = part))
r <- render_doc(p, "quarto"); cat("item 8 include of values+spans resolved?: ", r$ok, "\n")
if (r$ok) cat("  rendered text:", html_text(r$out), "\n")
body <- c("Before include.", "", "{{< include _part_ok.qmd >}}", "", "Line after the include,", "bad `r nosuch_after` here.")
p <- qdoc("x_inc_after", body, setup, extra_files = list("_part_ok.qmd" = part)); L <- readLines(p)
cat("error AFTER an include is on authored line", grep("nosuch_after", L), "of x_inc_after.qmd\n")
r <- render_doc(p, "quarto"); cat("  with include map (default):   ", msg(r$log), "\n")
p2 <- qdoc("x_inc_after_nomap", body, paste(setup, "; options(clag.map_includes = FALSE)"), extra_files = list("_part_ok.qmd" = part))
r <- render_doc(p2, "quarto"); cat("  WITHOUT include map (raw knitr):", msg(r$log), "  [expanded-file line, not authored line]\n")
part_bad <- c("Included line 1.", "Included line 2 has `r nosuch_in_part` in it.")
body <- c("Before.", "", "{{< include _part_bad.qmd >}}", "", "After.")
p <- qdoc("x_inc_err", body, extra_files = list("_part_bad.qmd" = part_bad)); r <- render_doc(p, "quarto")
cat("error INSIDE the included file (authored: _part_bad.qmd line 2): ", msg(r$log), "\n")

## ---- 5: printing parity ----------------------------------------------------------------------
rule("ITEM 5: bare `r value` printing parity with stock knitr")
vals <- c('1234567.891', '0.00001234', '1e10', 'pi', '3L', '-1', '"text with *md*"', 'c(1,2,3)', 'c("a","b")', 'TRUE',
          'NULL', 'NA', 'Sys.Date()', 'factor("lvl")', 'knitr::asis_output("**b**")', 'I("x")', 'obj',
          '1/3', '123456789', '-0.5', 'c(1.5, NA)', 'list(1, "a")[[2]]', 'as.Date("2026-01-02")', 'matrix(1:2, 1)')
pbody <- sprintf("P%02d: `r %s` end", seq_along(vals), vals)
psetup <- c("Sys.Date <- function() as.Date('2026-01-02')",
            "obj <- structure('ab', class = 'thing')",
            "knit_print.thing <- function(x, ...) knitr::asis_output('KP-SHOULD-NOT-APPEAR-IN-INLINE')",
            "registerS3method('knit_print', 'thing', knit_print.thing, envir = asNamespace('knitr'))")
stock_yaml <- function(engine) doc_header(engine)
write_parity <- function(name, engine, clag) {
  ext <- if (engine == "quarto") ".qmd" else ".Rmd"
  L <- c(doc_header(engine), "```{r}", "#| include: false", if (clag) 'source("setup.R"); clag_install()', psetup, "```", "", pbody)
  p <- file.path(OUT, paste0(name, ext)); wr(L, p); p
}
pl <- function(txt, tag = "^P[0-9]+") { m <- regmatches(txt, gregexpr("P[0-9]{2}: .*? end", txt)); m[[1]] }
for (engine in c("rmarkdown", "quarto")) {
  a <- render_doc(write_parity(paste0("x_par_clag_", engine), engine, TRUE), engine)
  b <- render_doc(write_parity(paste0("x_par_stock_", engine), engine, FALSE), engine)
  if (!a$ok || !b$ok) { cat(engine, ": render failed\n", if (!a$ok) msg(a$log), if (!b$ok) substr(b$log, 1, 400), "\n"); next }
  ta <- pl(html_text(a$out)); tb <- pl(html_text(b$out))
  d <- which(ta != tb); cat(sprintf("[%s] %d values; differences (clag vs stock): %d\n", engine, length(ta), length(d)))
  for (k in d) cat("   clag :", ta[k], "\n   stock:", tb[k], "\n")
  if (engine == "rmarkdown") { cat("  stock output for the record:\n"); for (k in seq_along(tb)) cat("   ", tb[k], "\n") }
}
## raw knit output (before Pandoc), rmarkdown route: byte-for-byte
writeLines("args <- commandArgs(TRUE); knitr::knit(args[1], args[2], quiet = TRUE)", file.path(OUT, "knit_raw.R"))
raw <- function(p) { o <- sub("\\.Rmd$", ".raw.md", p); in_dir(OUT, system2(RSCRIPT, c("knit_raw.R", shQuote(basename(p)), shQuote(basename(o))), stdout = TRUE, stderr = TRUE)); readLines(o, warn = FALSE) }
ra <- raw(file.path(OUT, "x_par_clag_rmarkdown.Rmd")); rb <- raw(file.path(OUT, "x_par_stock_rmarkdown.Rmd"))
ra <- grep("^P[0-9]", ra, value = TRUE); rb <- grep("^P[0-9]", rb, value = TRUE)
cat("raw knitr .md lines identical (clag vs stock):", identical(ra, rb), "\n"); for (k in which(ra != rb)) cat("   clag:", ra[k], "\n   stock:", rb[k], "\n")

## ---- 6: Quarto `{r} x` form --------------------------------------------------------------------
rule("ITEM 6: Quarto inline form `{r} x`")
forms <- c('`{r} x`', '`{r} x`{.num}', '`{r} n`{.no .word}', '`{r} x`{claim=". > 1"}', '`{r} sites`{.or}', '`{r} x`{.num claim=". > 1"}', '`{r} nm`')
for (k in seq_along(forms)) {
  p <- qdoc(paste0("x_qi_", k), c(paste("R:", forms[k], "end")), 'x <- 1234.567; n <- 0; sites <- c("A","B","C"); nm <- "text"', "quarto")
  r <- render_doc(p, "quarto")
  cat(sprintf("  %-34s -> %s\n", forms[k], if (r$ok) sub(".*?(R: )", "R: ", html_text(r$out)) else paste("ERROR", msg(r$log))))
}
sp <- qdoc("x_qi_stock", "S: `{r} x` | `{r} nm` | `{r} n` end", 'x <- 1234.567; n <- 0; nm <- "text"', "quarto")
txt <- readLines(sp); txt <- txt[!grepl("clag_install", txt)]; wr(txt, sp); r <- render_doc(sp, "quarto")
cat("  stock knitr (no hooks) for `{r} x` | `{r} nm` | `{r} n`:", sub(".*?(S: )", "S: ", html_text(r$out)), "\n")

## ---- 7: captions ----------------------------------------------------------------------------------------
rule("ITEM 7: figure caption as prose (quarto)")
body <- c("::: {#fig-a}", "", "```{r}", "#| echo: false", "plot(1:3)", "```", "", 'Plot of `r n`{.num} [# site | # sites]{n="n"} (depth `r d`{.dec1}).', "", ":::", "", "As @fig-a shows, all is well.")
p <- qdoc("x_caption", body, "n <- 3; d <- 1.25"); r <- render_doc(p, "quarto")
if (!r$ok) cat("render failed:", substr(r$log, 1, 500), "\n") else {
  d <- xml2::read_html(r$out)
  cat("  figcaption  :", norm(xml2::xml_text(xml2::xml_find_all(d, "//figcaption"))), "\n")
  cat("  cross-ref   :", norm(xml2::xml_text(xml2::xml_find_all(d, "//a[@href='#fig-a']"))), "\n")
  cat("  figure id   :", length(xml2::xml_find_all(d, "//*[@id='fig-a']")), "element(s) with id=fig-a\n")
}

## ---- 9: docx / typst ------------------------------------------------------------------------------------
rule("ITEM 9: other formats")
dbody <- c('Value `r x`{.num}, checked `r n_gap`{claim=". > 10"}, pct `r p`{.pct .strong}, or `r sites`{.or}.', "",
           'There [were | was]{if="n > 1"} [# sample | # samples]{.no n="n"} from [a site | # sites]{n="m"}. [add more | ]{if="n_gap > 99"}Done.', "",
           "`r sites`{.ul}", "", '| A | B |', '|---|---|', '| [x \\| y]{n="m"} | `r x`{.num} |', "", 'Footnote^[has [# site | # sites]{n="m"}].')
dsetup <- 'x <- 3.7; n_gap <- 12; p <- 0.456; sites <- c("A","B","C"); n <- 3; m <- 1'
p <- qdoc("x_docx", dbody, dsetup, yaml = c("---", "format: docx", "---", ""))
r <- render_doc(p, "quarto", "docx")
if (!r$ok) cat("docx render failed:", substr(r$log, 1, 500), "\n") else {
  txt <- in_dir(OUT, system2(QUARTO, c("pandoc", shQuote(basename(r$out)), "-t", "plain", "--wrap=none"), stdout = TRUE))
  txt <- norm(paste(txt, collapse = " "))
  cat("  docx -> plain text:", txt, "\n")
  for (w in c("Value 4, checked 12, pct 46%, or A, B or C.", "There were 3 samples from a site. Done.", "- A - B - C", "x 4", "Footnote[1].", "has 1 site"))
    cat(sprintf("  %-5s contains '%s'\n", if (grepl(w, txt, fixed = TRUE)) "PASS" else "FAIL", w))
  z <- in_dir(OUT, system2(QUARTO, c("pandoc", shQuote(basename(r$out)), "-t", "native"), stdout = TRUE))
  cat("  .strong span survives into docx as a styled run? native AST has 'strong' class/style:",
      any(grepl("strong|Strong", z)), "\n")
}
p <- qdoc("x_typst", dbody, dsetup, yaml = c("---", "format:", "  typst:", "    keep-typ: true", "---", ""))
r <- render_doc(p, "quarto", "typst")
cat("typst render ok:", r$ok, "\n")
if (r$ok || file.exists(file.path(OUT, "x_typst.typ"))) {
  tp <- file.path(OUT, "x_typst.typ"); if (file.exists(tp)) { t <- paste(readLines(tp, warn = FALSE), collapse = " ")
    for (w in c("Value 4, checked 12, pct 46%", "There were 3 samples from a site", "has 1 site"))
      cat(sprintf("  %-5s .typ contains '%s'\n", if (grepl(w, t, fixed = TRUE)) "PASS" else "FAIL", w)) }
} else cat(substr(r$log, 1, 400), "\n")

## ---- 10: speed ------------------------------------------------------------------------------------------------
rule("ITEM 10: speed, 2000 paragraphs / 4000 constructs")
writeLines(c("a <- commandArgs(TRUE); t <- system.time(knitr::knit(a[1], a[2], quiet = TRUE)); cat(sprintf('%.2f', t[['elapsed']]))"), file.path(OUT, "time_knit.R"))
K <- 2000L
mk <- function(kind, name, chunk_every = 0L) {
  L <- c("---", "output: html_document", "---", "", "```{r}", "#| include: false", if (kind == "clag") 'source("setup.R"); clag_install()', "n <- 3", "```", "")
  for (k in seq_len(K)) {
    L <- c(L, switch(kind,
      clag = sprintf('Paragraph %d: value `r %d`{.num} samples at [a site | # sites]{n="n"} and more prose to make it realistic.', k, k),
      inline = sprintf('Paragraph %d: value `r %d` samples at plain sites and more prose to make it realistic.', k, k),
      plain = sprintf('Paragraph %d: value %d samples at plain sites and more prose to make it realistic.', k, k)), "")
    if (chunk_every > 0L && k %% chunk_every == 0L) L <- c(L, "```{r}", "#| include: false", "invisible(0)", "```", "")
  }
  p <- file.path(OUT, paste0(name, ".Rmd")); wr(L, p); p
}
tk <- function(p) { o <- sub("\\.Rmd$", ".md", p); as.numeric(in_dir(OUT, system2(RSCRIPT, c("time_knit.R", shQuote(basename(p)), shQuote(basename(o))), stdout = TRUE))) }
t1 <- tk(mk("clag", "x_sp_clag")); t2 <- tk(mk("plain", "x_sp_plain")); t3 <- tk(mk("inline", "x_sp_inline")); t4 <- tk(mk("clag", "x_sp_clag_blocks", 10L))
cat(sprintf("knitr::knit elapsed seconds (one text block of 2000 paras): clag %.2f | stock plain text %.2f | stock inline `r` (2000 evals, no spans) %.2f\n", t1, t2, t3))
cat(sprintf("clag with a chunk every 10 paragraphs (200 text-hook calls): %.2f\n", t4))
for (nm in c("x_sp_clag", "x_sp_plain")) { r <- render_doc(sub("\\.Rmd$", ".qmd", { f <- file.path(OUT, paste0(nm, ".Rmd")); q <- sub("\\.Rmd$", "_q.qmd", f); L <- readLines(f); L[2] <- "format: html"; L[1:4] <- c("---", "format: html", "---", ""); wr(L, q); q }), "quarto")
  cat(sprintf("quarto render --to html total, %s: %s %.1fs\n", nm, if (r$ok) "ok" else "FAILED", r$secs)) }

## ---- bonus: does stock knitr evaluate inline code inside a non-executed fence? ---------------------------------
rule("BONUS: stock knitr, `r 1+1` inside a ```markdown fence")
bp <- file.path(OUT, "x_fence_stock.Rmd"); wr(c("---", "output: md_document", "---", "", "```markdown", "x is `r 1+1`", "```"), bp)
in_dir(OUT, system2(RSCRIPT, c("time_knit.R", shQuote(basename(bp)), "x_fence_stock.md"), stdout = TRUE)); cat(readLines(file.path(OUT, "x_fence_stock.md")), sep = "\n")
