## Block-start locator spike.   Rscript run.R [--quick]     (--quick skips the timing section)
## Needs: knitr, rmarkdown, quarto on PATH. Everything is written under ./out (inputs/ holds a copy of
## each file knitr actually read, which is the truth source for the comparison).
## Methods compared against `knit_concord` (kc, unexported) and against an independent chunk scanner (analysis.R):
##   cs  content search, one string, fixed-string forward search from the previous block's end   (exported API only)
##   cl  content search, vector of lines                                                         (exported API only)
##   rx  regex fallback for blocks whose inline code does not round-trip                         (exported API only)
##   pb  public options knitr.progress.linenums/simple/output, read back inside the hook          (exported API only)
source(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), "lib.R"))
source(file.path(ROOT, "analysis.R")); source(file.path(ROOT, "stress.R")); source(file.path(ROOT, "cases.R"))
QUICK <- "--quick" %in% commandArgs(TRUE)
unlink(OUT, recursive = TRUE); dir.create(OUT)
file.copy(file.path(ROOT, "lines.R"), file.path(OUT, "lines.R"))
LOG <- file.path(OUT, "log.tsv"); INP <- file.path(OUT, "inputs"); PBF <- file.path(OUT, "pb.txt")
writeLines(sprintf('options(knitr.progress.linenums = TRUE, knitr.progress.simple = TRUE, knitr.progress.output = "%s")', PBF), file.path(OUT, "pb.Rprofile"))
file.copy(file.path(OUT, "pb.Rprofile"), file.path(OUT, "early.Rprofile"))
cat('source("lines.R"); lines_install()\n', file = file.path(OUT, "early.Rprofile"), append = TRUE)   # hooks live BEFORE the first block
writeLines("a <- commandArgs(TRUE); knitr::knit(a[1], a[2], quiet = FALSE)", file.path(OUT, "knit_pb.R"))
writeLines(c("args <- commandArgs(TRUE)", "rmarkdown::render(args[1], output_format = args[2], quiet = FALSE)"), file.path(OUT, "render_rmd_pb.R"))
HEADER_CHUNK <- c("```{r}", "#| include: false", 'source("lines.R"); lines_install()', "LOG <- character()", "lg <- function(tag, v = '') v", "```", "")

## run one document with a given engine; every engine runs with the pb options (via R_PROFILE_USER)
run_doc <- function(path, engine, tag, methods = "cs,cl,rx,kc,pb,fr", strict = "1", pb = TRUE, early = FALSE) {
  Sys.setenv(LINES_LOG = LOG, LINES_TAG = tag, LINES_METHODS = methods, LINES_STRICT = strict,
             R_PROFILE_USER = if (early) file.path(OUT, "early.Rprofile") else if (pb) file.path(OUT, "pb.Rprofile") else "")
  f <- basename(path); old <- setwd(dirname(path)); on.exit(setwd(old))
  t0 <- Sys.time()
  log <- suppressWarnings(switch(engine,
    knit = system2(RSCRIPT, c("knit_pb.R", shQuote(f), shQuote(sub("\\.[A-Za-z]+$", ".knit.md", f))), stdout = TRUE, stderr = TRUE),
    rmarkdown = system2(RSCRIPT, c("render_rmd_pb.R", shQuote(f), "html_document"), stdout = TRUE, stderr = TRUE),
    quarto = system2(QUARTO, c("render", shQuote(f), "--to", "html"), stdout = TRUE, stderr = TRUE)))
  Sys.unsetenv("R_PROFILE_USER")
  st <- attr(log, "status") %||% 0L
  if (st != 0L) cat(sprintf("   [%s %s] RENDER FAILED: %s\n", engine, tag, substr(paste(tail(log, 6), collapse = " | "), 1, 300)))
  invisible(list(ok = st == 0L, secs = as.numeric(difftime(Sys.time(), t0, units = "secs"))))
}
results <- function(tag_rx, mode = "top") {
  d <- read_log(LOG); if (is.null(d)) return(NULL)
  d <- d[grepl(tag_rx, d$tag), ]; align(d, INP)
}
wr_raw <- function(lines, path, eol = "\n", final = TRUE, bom = FALSE) {
  s <- paste(lines, collapse = eol); if (final) s <- paste0(s, eol)
  con <- file(path, "wb"); on.exit(close(con))
  if (bom) writeBin(as.raw(c(0xEF, 0xBB, 0xBF)), con)
  writeBin(charToRaw(enc2utf8(s)), con)
}
H <- function(x) cat("\n", strrep("=", 78), "\n", x, "\n", strrep("=", 78), "\n", sep = "")

## ============================== 1. stress documents ============================================
H("1. STRESS (about 330 text blocks each; duplicates, blank/whitespace/tab blocks, traps, unicode, fences, long lines)")
SL <- gen_stress("rmarkdown")
variants <- list(
  s_lf        = list(eol = "\n",   final = TRUE),
  s_crlf      = list(eol = "\r\n", final = TRUE),
  s_noeol     = list(eol = "\n",   final = FALSE),
  s_crlf_noeol = list(eol = "\r\n", final = FALSE),
  s_bom       = list(eol = "\n",   final = TRUE, bom = TRUE))
for (nm in names(variants)) {
  v <- variants[[nm]]; wr_raw(SL, file.path(OUT, paste0(nm, ".Rmd")), v$eol, v$final, isTRUE(v$bom))
  run_doc(file.path(OUT, paste0(nm, ".Rmd")), "knit", nm)
  summarise(results(paste0("^", nm, "$")), paste("knit", nm))
}
wr_raw(SL, file.path(OUT, "s_lf_nonstrict.Rmd")); run_doc(file.path(OUT, "s_lf_nonstrict.Rmd"), "knit", "s_nonstrict", strict = "0")
summarise(results("^s_nonstrict$"), "knit strict=FALSE (no bounds)", record = FALSE)
cat("   ^ with the chunk-boundary check off, a text block identical to a line inside the preceding chunk is matched there\n")
wr_raw(SL, file.path(OUT, "s_render.Rmd")); run_doc(file.path(OUT, "s_render.Rmd"), "rmarkdown", "s_render")
summarise(results("^s_render$"), "rmarkdown::render .Rmd")
SQ <- gen_stress("quarto")
wr_raw(SQ, file.path(OUT, "s_quarto.qmd")); run_doc(file.path(OUT, "s_quarto.qmd"), "quarto", "s_quarto")
summarise(results("^s_quarto$"), "quarto render .qmd (intermediate)")
wr_raw(SQ, file.path(OUT, "s_quarto_crlf.qmd"), "\r\n"); run_doc(file.path(OUT, "s_quarto_crlf.qmd"), "quarto", "s_quarto_crlf")
summarise(results("^s_quarto_crlf$"), "quarto render .qmd CRLF")

H("1b. EARLY INSTALL (hooks installed from R_PROFILE_USER, so the YAML-bearing first block is seen too; doc has no install chunk)")
SE <- gen_stress("rmarkdown", install = FALSE)
wr_raw(SE, file.path(OUT, "e_knit.Rmd")); run_doc(file.path(OUT, "e_knit.Rmd"), "knit", "e_knit", early = TRUE); summarise(results("^e_knit$"), "early: knit .Rmd")
wr_raw(SE, file.path(OUT, "e_crlf.Rmd"), "\r\n"); run_doc(file.path(OUT, "e_crlf.Rmd"), "knit", "e_crlf", early = TRUE); summarise(results("^e_crlf$"), "early: knit .Rmd CRLF")
wr_raw(SE, file.path(OUT, "e_render.Rmd")); run_doc(file.path(OUT, "e_render.Rmd"), "rmarkdown", "e_render", early = TRUE); summarise(results("^e_render$"), "early: rmarkdown::render")
wr_raw(gen_stress("quarto", install = FALSE), file.path(OUT, "e_quarto.qmd")); run_doc(file.path(OUT, "e_quarto.qmd"), "quarto", "e_quarto", early = TRUE); summarise(results("^e_quarto$"), "early: quarto render")
cat("   first-block row (should start at line 1 and contain the YAML header):\n")
d <- read_log(LOG); print(head(d[d$tag == "e_knit", c("tag", "n", "kc", "cs", "cl", "pb", "fr", "nchar", "first")], 2), row.names = FALSE)

## ============================== 2. the existing case matrix ===================================
H("2. CASE MATRIX (cases.R): one group document per engine + every case as its own document (knit)")
for (engine in c("quarto", "rmarkdown")) {
  active <- Filter(function(cs) engine %in% cs$engines, cases)
  b <- build_doc(paste0("m_", engine), active, engine)
  run_doc(b$path, engine, paste0("m_", engine))
  summarise(results(paste0("^m_", engine, "$")), sprintf("matrix group doc, %s (%d cases)", engine, length(active)))
}
for (cs in cases) { b <- build_doc(paste0("c_", cs$id), list(cs), "rmarkdown"); run_doc(b$path, "knit", paste0("c_", cs$id)) }
a <- results("^c_"); summarise(a, sprintf("matrix solo docs, knit (%d docs)", length(cases)))

## ============================== 3. extras ======================================================
H("3. EXTRAS")
part <- c("Included line 1: value `r k`{.num}.", 'Included line 2: [# site | # sites]{n="n"}.', "Included line 3.")
mkq <- function(name, body, files = list(), yaml = c("---", "format: html", "---", "")) {
  for (f in names(files)) wr(files[[f]], file.path(OUT, f))
  p <- file.path(OUT, paste0(name, ".qmd"))
  wr(c(yaml, HEADER_CHUNK[1:2], 'source("lines.R"); lines_install()', "k <- 7; n <- 2", "```", "", body), p); p
}
p <- mkq("x_inc", c("Before include `r k`.", "", "{{< include _part.qmd >}}", "", "After include `r k`.", "", "```{r}", "invisible(1)", "```", "", "Tail `r k`."), list("_part.qmd" = part))
run_doc(p, "quarto", "x_inc"); a <- results("^x_inc$"); summarise(a, "quarto {{< include >}}")
cat("   (truth is relative to the expanded intermediate file knitr reads; authored x_inc.qmd lines differ after the include)\n")
p <- mkq("x_inc2", c("{{< include _outer.qmd >}}", "", "After `r k`."), list("_outer.qmd" = c("Outer start `r k`", "", "{{< include _part.qmd >}}", "", "Outer end"), "_part.qmd" = part))
run_doc(p, "quarto", "x_inc2"); summarise(results("^x_inc2$"), "quarto nested include")

body <- c('Q-form `{r} k` end.', "", "Second `{r} k + 1`{.num} end.", "", "```{r}", "invisible(1)", "```", "", "Plain `r k` and `{r} k`.")
p <- mkq("x_qform", body); run_doc(p, "quarto", "x_qform"); summarise(results("^x_qform$"), "quarto `{r}` inline form")
cat("   intermediate shows:", grep("QuartoInline", readLines(file.path(INP, "x_qform__x_qform.rmarkdown")), value = TRUE)[1], "\n")

## inline forms that do not round-trip through "`r code`"
odd <- c("---", "title: odd", "---", "", "```{r}", 'source("lines.R"); lines_install()', "```", "",
         "A `r#1+1` hash form.", "", "```{r}", "invisible(1)", "```", "", "B trailing `r 1+1  ` blanks.", "",
         "```{r}", "invisible(1)", "```", "", "C `r 1+1` plain control.", "", "```{r}", "invisible(1)", "```", "", "D `r  1+1` two spaces.", "")
wr(odd, file.path(OUT, "x_odd.Rmd")); run_doc(file.path(OUT, "x_odd.Rmd"), "knit", "x_odd")
a <- summarise(results("^x_odd$"), "inline forms: r# / trailing / 2sp")
cat("   (cs NA = reconstruction `r code` != source; rx = regex fallback; lb = lower bound reported when both fail)\n")

## children
c1 <- c("", "Child1 text A `r 1`", "", "```{r}", "x <- 1", "```", "", "Parent text P2.", "", "Child1 last")
c2 <- c("Child2 text `r 2`", "", "```{r}", "y <- 1", "```", "", "Child2 tail")
par <- c("---", "title: p", "---", "", "```{r}", 'source("lines.R"); lines_install()', "```", "", "Parent text P1 `r 1`.", "",
         '```{r, child="_c1.Rmd"}', "```", "", "Parent text P2.", "", "```{r, results='asis'}",
         'cat(knitr::knit_child("_c2.Rmd", quiet = TRUE))', "```", "", "Parent text P3 `r 3`.", "")
wr(c1, file.path(OUT, "_c1.Rmd")); wr(c2, file.path(OUT, "_c2.Rmd")); wr(par, file.path(OUT, "x_child.Rmd"))
run_doc(file.path(OUT, "x_child.Rmd"), "knit", "x_child"); d <- read_log(LOG); d <- d[d$tag == "x_child", ]
cat("children. True block starts (counted by hand): x_child.Rmd 8, 13, 19; _c1.Rmd 1 and 7; _c2.Rmd 1 and 6 (_c2 is called by knit_child() from an asis chunk, with quiet = TRUE)\n")
print(d[, c("file", "mode", "kc", "cs", "cl", "pb", "fr", "rx", "lb", "first")], row.names = FALSE)
cat("   input copies made:", paste(list.files(INP, "^x_child"), collapse = ", "), "\n")

## knit(text=) : no file at all
t <- run_doc  # placeholder to keep the namespace tidy
txt_doc <- c("```{r}", 'source("lines.R"); lines_install()', "```", "", "Text input `r 1`.", "")
writeLines(c("Sys.setenv(LINES_LOG = commandArgs(TRUE)[1], LINES_TAG = 'x_text')",
             "txt <- c('```{r}', 'source(\"lines.R\"); lines_install()', '```', '', 'Text input `r 1`.', '')",
             "invisible(knitr::knit(text = txt, quiet = TRUE))"), file.path(OUT, "x_text.R"))
old <- setwd(OUT); system2(RSCRIPT, c("x_text.R", shQuote(LOG)), stdout = TRUE, stderr = TRUE); setwd(old)
d <- read_log(LOG); cat("knit(text=): ", paste(capture.output(print(d[d$tag == "x_text", c("file", "kc", "cs", "cl", "pb", "fr", "rx", "lb")], row.names = FALSE)), collapse = "\n  "), "\n")

## ============================== 4. summary table ================================================
H("4. TOTALS over every document above except the strict=FALSE run, children and text= (truth = independent scanner)")
S <- do.call(rbind, SUM); S$any_bad <- is.na(S$cs) | S$cs != S$truth | is.na(S$cl) | S$cl != S$truth
cat(sprintf("blocks %d | kc==truth %d | cs==truth %d | cl==truth %d | pb==truth %d of %d with pb | cs NA %d | cs wrong (not NA) %d | cl wrong %d\n",
            nrow(S), sum(S$kc == S$truth, na.rm = TRUE), sum(S$cs == S$truth, na.rm = TRUE), sum(S$cl == S$truth, na.rm = TRUE),
            sum(S$pb == S$truth, na.rm = TRUE), sum(!is.na(S$pb)), sum(is.na(S$cs)), sum(!is.na(S$cs) & S$cs != S$truth), sum(!is.na(S$cl) & S$cl != S$truth)))
saveRDS(S, file.path(OUT, "summary.rds"))

## ============================== 5. timing =======================================================
if (!QUICK) source(file.path(ROOT, "timing.R"))
source(file.path(ROOT, "routes.R"))
