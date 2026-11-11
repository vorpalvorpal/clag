# Extra probes: Q2 value correctness, bare-dict fallback, `dict` as a target + function, callr NULL,
# key-name restrictions, 40-key clutter, Q3 quarto.  Run: Rscript extra.R
root <- normalizePath("."); library(targets)
yml <- function(era = 2014) c(sprintf("era_split: {value: %s, type: year, definition: d}", era),
  "salinity_res: {value: 0.01, type: quantity, definition: d}", "tier_lab: {value: {reference: Reference, urban: Urban}, type: labels, definition: d}")
fresh <- function(name, design = "B") {
  d <- file.path(root, "work", name); unlink(d, recursive = TRUE); dir.create(file.path(d, "R"), recursive = TRUE)
  file.copy(file.path(root, "common", "tar_dict.R"), d)
  file.copy(file.path(root, "common", paste0("R/funcs_", design, ".R")), file.path(d, "R/funcs.R"))
  file.copy(file.path(root, "common", paste0("targets_", design, ".R")), file.path(d, "_targets.R"))
  setwd(d); writeLines(yml(), "dict.yml"); d
}
ranset <- function() { p <- tar_progress(); paste(sort(p$name[p$progress == "completed"]), collapse = ", ") }
hdr <- function(x) cat("\n#####", x, "\n")

hdr("Q2a: B value correctness after edit (tar_read)")
Sys.setenv(FNS = "exact"); fresh("x_value")
tar_make(reporter = "silent"); cat("before:", tar_read(t_era), tar_read(t_fn_era), "\n")
writeLines(yml(2015), "dict.yml"); tar_make(reporter = "silent")
cat("after era=2015: t_era =", tar_read(t_era), " t_fn_era(2010<2015) =", tar_read(t_fn_era), " ran:", ranset(), "\n")
cat("tar_deps of t_fn_era in manifest network:\n")
print(tar_network(callr_arguments = list(show = FALSE))$edges |> subset(to %in% c("t_fn_era", "t_both")))

hdr("Q2b: callr_function = NULL gives same ran-set?")
writeLines(yml(2016), "dict.yml"); tar_make(callr_function = NULL, reporter = "silent")
cat("era=2016 in-process ran:", ranset(), "\n")

hdr("Q2c: naive Design B, `dict` is a TARGET, function reads dict$x (no tar_dict_deps)")
d <- fresh("x_naive")
writeLines('library(targets); source("tar_dict.R"); source("R/funcs.R"); tar_option_set(packages="yaml")
list(tar_target(dict_file, "dict.yml", format="file"), tar_target(dict, spike_dict_obj(dict_file)),
 tar_target(t_fn_era, era_label(2010)))', "_targets.R")
r <- try(tar_make(reporter = "silent"), silent = TRUE); cat("make result:", as.character(r), "\n")
cat("edges into t_fn_era:\n"); print(subset(tar_network(callr_arguments = list(show = FALSE), targets_only = FALSE)$edges, to == "t_fn_era"))

hdr("Q2d: bare `dict` passed to function => all keys")
d <- fresh("x_bare")
writeLines("f <- function(d) d$era_split", "R/funcs.R")
writeLines('library(targets); source("tar_dict.R"); source("R/funcs.R"); dict <- spike_dict_obj("dict.yml")
c(tar_dict("dict.yml"), tar_dict_deps(list(tar_target(t1, f(dict))), "dict.yml"))', "_targets.R")
tar_make(reporter = "silent"); print(subset(tar_network(callr_arguments = list(show = FALSE))$edges, to == "t1"))

hdr("Q2e: unknown key in pipeline code")
d <- fresh("x_unk")
writeLines('library(targets); source("tar_dict.R"); dict <- spike_dict_obj("dict.yml")
c(tar_dict("dict.yml"), tar_dict_deps(list(tar_target(t1, dict$era_splt)), "dict.yml"))', "_targets.R")
print(try(tar_manifest(callr_function = NULL), silent = TRUE))
cat("runtime `$` on unknown key:", tryCatch(spike_dict_obj <- NULL, error = function(e) ""), "\n")
source(file.path(root, "common/tar_dict.R")); dd <- spike_dict_obj("dict.yml"); print(try(dd$nope, silent = TRUE)); cat("partial `dd$era`:", try(dd$era, silent = TRUE), "\n")

hdr("Q4a: key names as target names")
d <- fresh("x_names")
for (k in c("a.b", "a-b", "1abc", "a b", ".x", "tier_lab2", "UPPER", "dict", "é")) {
  y <- sprintf("'%s': {value: 1}", k); writeLines(y, "dict.yml")
  r <- try(tar_dict("dict.yml"), silent = TRUE)
  cat(sprintf("%-10s -> %s\n", k, if (inherits(r, "try-error")) paste("ERROR:", trimws(conditionMessage(attr(r, "condition")))) else "ok target dict_<key>"))
}

hdr("Q4b: 40 keys, manifest")
d <- fresh("x_many"); writeLines(sprintf("k%02d: {value: %d, definition: d}", 1:40, 1:40), "dict.yml")
writeLines('library(targets); source("tar_dict.R"); dict <- spike_dict_obj("dict.yml")
c(tar_dict("dict.yml"), tar_dict_deps(list(tar_target(u1, dict$k01 + dict$k02), tar_target(u2, dict$k40)), "dict.yml"))', "_targets.R")
m <- tar_manifest(callr_arguments = list(show = FALSE)); cat("manifest rows:", nrow(m), "\n")
t0 <- Sys.time(); tar_make(reporter = "silent"); cat("first make secs:", round(as.numeric(Sys.time() - t0), 1), "\n")
t0 <- Sys.time(); tar_make(reporter = "silent"); cat("no-op make secs:", round(as.numeric(Sys.time() - t0), 1), "\n")
ed <- tar_network(callr_arguments = list(show = FALSE))$edges; cat("graph edges:", nrow(ed), "\n")

hdr("Q3: quarto / tar_quarto")
if (nzchar(Sys.which("quarto"))) {
  for (mode in c("plain", "extra_files", "regex_deps")) {
    d <- fresh(paste0("x_q_", mode)); writeLines(yml(), "dict.yml")
    writeLines(c("---", "title: t", "---", "", "```{r}", "#| include: false", 'source("tar_dict.R"); dict <- spike_dict_obj("dict.yml")', "```", "",
      "The era ends in `r dict$era_split`."), "report.qmd")
    q <- switch(mode, plain = 'tar_quarto(report, "report.qmd", quiet = TRUE)',
      extra_files = 'tar_quarto(report, "report.qmd", extra_files = "dict.yml", quiet = TRUE)',
      regex_deps = 'tar_quarto(report, "report.qmd", quiet = TRUE)')
    wrap <- if (mode == "regex_deps") "tar_dict_qmd_deps(%s, 'report.qmd', 'dict.yml')" else "%s"
    writeLines(c('library(targets); library(tarchetypes); source("tar_dict.R")',
      'tar_dict_qmd_deps <- function(tgts, qmd, path) { keys <- unique(sub("^dict\\\\$", "", regmatches(readLines(qmd), gregexpr("dict\\\\$[A-Za-z0-9_]+", readLines(qmd)))|>unlist()))
        lapply(unlist(list(tgts), recursive=FALSE), function(t) { if (identical(t$settings$name, "report")) {dd <- paste0("dict_", keys); t$command$deps <- union(t$command$deps, dd); t$deps <- t$command$deps}; t }) }',
      sprintf("c(tar_dict('dict.yml'), %s)", sprintf(wrap, q)) ), "_targets.R")
    r <- try(tar_make(reporter = "silent", callr_function = NULL), silent = TRUE)
    if (inherits(r, "try-error")) { cat(mode, ": FIRST BUILD FAILED:", as.character(r), "\n"); next }
    cat("\n--", mode, "-- initial ran:", ranset(), "\n")
    writeLines(yml(2015), "dict.yml"); cat("edit era_split value: outdated =", paste(sort(tar_outdated(callr_function = NULL)), collapse = ", "), "\n")
    tar_make(reporter = "silent", callr_function = NULL); cat("  ran:", ranset(), "\n")
    writeLines(sub("definition: d}", "definition: new words}", yml(2015), fixed = TRUE), "dict.yml"); tar_make(reporter = "silent", callr_function = NULL); cat("edit definition only: ran:", ranset(), "\n")
    writeLines(sub("0.01", "0.02", yml(2015)), "dict.yml"); tar_make(reporter = "silent", callr_function = NULL); cat("edit salinity only (report reads only era_split): ran:", ranset(), "\n")
    cat("  html shows:", grep("ends in", readLines("report.html"), value = TRUE)[1], "\n")
  }
} else cat("quarto not on PATH\n")
