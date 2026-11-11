# Usage: Rscript run.R   (add trailing "# battery-ok" comment if hook blocks)
root <- normalizePath(".")
yml <- function(era = 2014, def = "Boundary between eras.", sal = 0.01, extra = FALSE, reorder = FALSE) {
  a <- sprintf('era_split:    {value: %s, type: year, definition: "%s"}', era, def)
  b <- sprintf('salinity_res: {value: %s, type: quantity, unit: PSU, definition: "Logger resolution."}', sal)
  c <- 'tier_lab:     {value: {reference: Reference, urban: Urban}, type: labels, definition: "Tier names."}'
  l <- if (reorder) c(b, a, c) else c(a, b, c)
  if (extra) l <- c(l, 'newkey: {value: 1, type: quantity, definition: "x"}')
  l
}
setup <- function(name, design, env = character()) {
  d <- file.path(root, "work", name); unlink(d, recursive = TRUE); dir.create(file.path(d, "R"), recursive = TRUE)
  file.copy(file.path(root, "common", "tar_dict.R"), d)
  file.copy(file.path(root, "common", paste0("R/funcs_", design, ".R")), file.path(d, "R/funcs.R"))
  file.copy(file.path(root, "common", paste0("targets_", design, ".R")), file.path(d, "_targets.R"))
  setwd(d); do.call(Sys.setenv, as.list(env)); writeLines(yml(), "dict.yml"); d
}
step <- function(label, ...) {
  cat("\n== ", label, "\n")
  writeLines(yml(...), "dict.yml")
  o <- targets::tar_outdated(callr_arguments = list(show = FALSE))
  cat("tar_outdated: ", paste(sort(o), collapse = ", "), "\n")
  targets::tar_make(reporter = "silent")
  p <- targets::tar_progress()
  cat("ran:          ", paste(sort(p$name[p$progress == "completed"]), collapse = ", "), "\n")
  cat("skipped:      ", paste(sort(p$name[p$progress == "skipped"]), collapse = ", "), "\n")
}
scenarios <- function() {
  step("initial build")
  step("no change (writes identical yml)")
  step("edit era_split value 2014->2015", era = 2015)
  step("restore", era = 2014)
  step("edit ONLY era_split definition string", def = "Changed words.")
  step("restore")
  step("edit salinity_res value", sal = 0.02)
  step("restore")
  step("add new key (unused)", extra = TRUE)
  step("remove it again")
  step("reorder keys (salinity first)", reorder = TRUE)
}
for (cfg in list(
  list("A_value", "A", c(WHOLE = "0")),
  list("A_wholeentry", "A", c(WHOLE = "1")),
  list("B_fns_exact", "B", c(FNS = "exact")),
  list("B_fns_whole", "B", c(FNS = "whole")))) {
  cat("\n\n############ ", cfg[[1]], "\n")
  setup(cfg[[1]], cfg[[2]], cfg[[3]])
  scenarios()
  setwd(root)
}
