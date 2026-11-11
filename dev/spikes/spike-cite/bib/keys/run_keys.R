source("../../weft_keys.R")
ids <- readRDS("ids.rds"); exp_bl <- c(ids[1:250], paste0(ids[1:250], "_j"))
files <- c("n500_bibtex.bib", "n500_biblatex.bib", "n500.json", "n500_cslyaml.yaml", "n500_cslyaml_delim.yaml")
res <- NULL
for (f in files) for (route in c("pandoc", "native")) {
  fn <- get(paste0("keys_", route)); k <- NULL
  t <- system.time(k <- tryCatch(fn(f), error = function(e) paste("ERROR", conditionMessage(e))))[["elapsed"]]
  want <- if (f == "n500_biblatex.bib") exp_bl else ids
  res <- rbind(res, data.frame(file = f, route = route, n = length(k), secs = round(t, 2),
     same_set = setequal(k, want), missing = paste(head(setdiff(want, k), 3), collapse = ";"), extra = paste(head(setdiff(k, want), 3), collapse = ";")))
}
print(res, row.names = FALSE)
