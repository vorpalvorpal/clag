f1 <- function(x) if (is.null(x)) "NULL" else if (is.list(x) && !is.null(names(x))) paste0("{", paste(names(x), collapse = ","), "}") else paste(unlist(x), collapse = ",")
dg <- function(x) if (is.list(x) && !is.null(x$digits)) paste0("digits=", x$digits) else f1(x)
rel <- function(p) sub(".*/spike-frontmatter/", "", p)
for (f in sort(list.files("C/cases", "probe_(chunk|hook)\\.rds$", recursive = TRUE, full.names = TRUE))) {
  r <- readRDS(f); e <- r$execute_info; q <- r$quarto_inspect
  cat(sprintf("%-55s md_names=%s weft=%s bib=%s lang=%s | exec_info: weft=%s lang=%s bib=%s proj_names=%s | inspect: weft=%s bib=%s lang=%s | PROJ_DIR=%s wd=%s\n",
    sub("C/cases/", "", sub("probe_", "", f)), f1(r$metadata_names), dg(r$md_weft), f1(r$md_bibliography), f1(r$md_lang),
    if (is.list(e)) dg(e$fm_weft) else e, if (is.list(e)) f1(e$fm_lang) else "-", if (is.list(e)) f1(e$fm_bib) else "-", if (is.list(e)) f1(e$project_names) else "-",
    if (is.list(q)) dg(q$weft) else substr(q, 1, 60), if (is.list(q)) f1(q$bib) else "-", if (is.list(q)) f1(q$lang) else "-",
    rel(r$quarto_env$QUARTO_PROJECT_DIR %||% "unset"), rel(r$wd)))
  if (is.list(q)) cat("      inspect used:", sub(".*/C/cases/", "", q$used %||% "-"), "secs:", round(q$secs %||% NA, 2), "\n")
}
`%||%` <- function(a, b) if (is.null(a)) b else a
