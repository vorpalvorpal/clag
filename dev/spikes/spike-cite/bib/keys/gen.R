set.seed(1); N <- 500
ids <- c("smith2020", "jones2019", sprintf("key%03d:x.y-z", 3:N))  # include punctuation keys
ids[10] <- "Doe_2018a"; ids[11] <- "o'brien2017"; ids[12] <- "ünï2021"
tit <- function(i) sprintf("Title number %d about catchments", i)
bt <- vapply(seq_len(N), function(i) sprintf("@article{%s,\n  author = {Author, A. and Other, B.},\n  title = {%s},\n  journal = {J. Things},\n  year = {%d},\n  volume = {%d}\n}\n", ids[i], tit(i), 1990+i%%30, i), "")
writeLines(bt, "n500_bibtex.bib")
bl <- vapply(seq_len(N), function(i) sprintf("@online{%s,\n  author = {Author, A. and Other, B.},\n  title = {%s},\n  date = {%d-03-04},\n  url = {https://example.org/%d},\n  urldate = {2024-01-01},\n  organization = {Org}\n}\n@article{%s_j,\n  author = {Author, A.},\n  title = {%s},\n  journaltitle = {J. Things},\n  date = {%d},\n  location = {Sydney}\n}\n", ids[i], tit(i), 1990+i%%30, i, ids[i], tit(i), 1990+i%%30), "")
# 500 entries total: use 250 online + 250 article
bl <- bl[seq_len(250)]; writeLines(bl, "n500_biblatex.bib")
cj <- lapply(seq_len(N), function(i) list(id=ids[i], type="article-journal", title=tit(i), author=list(list(family="Author", given="A.")), issued=list(`date-parts`=list(list(1990+i%%30))), `container-title`="J. Things"))
jsonlite::write_json(cj, "n500.json", auto_unbox=TRUE, pretty=TRUE)
y <- vapply(seq_len(N), function(i) sprintf("- id: '%s'\n  type: article-journal\n  title: %s\n  author:\n  - family: Author\n    given: A.\n  issued:\n    date-parts:\n    - - %d\n  container-title: J. Things\n", ids[i], tit(i), 1990+i%%30), "")
writeLines(c("references:", gsub("(^|\n)", "\\1  ", sub("\n$","",y)) , ""), "n500_cslyaml_wrapped.yaml")
writeLines(c("---", "references:", gsub("(^|\n)", "\\1", sub("\n$","",y)) , "---"), "n500_cslyaml_bare.yaml")
saveRDS(ids, "ids.rds")
yaml::write_yaml(list(references = cj), "n500_cslyaml.yaml")
writeLines(c("---", readLines("n500_cslyaml.yaml"), "---"), "n500_cslyaml_delim.yaml")
