# usage: Rscript check.R file.html  -> prints FIRST/LATER paragraph text, plus date/meta oddities
f <- commandArgs(TRUE)[1]
if (!file.exists(f)) { cat("NO OUTPUT\n"); quit() }
d <- xml2::read_html(f, encoding="UTF-8")
p <- xml2::xml_text(xml2::xml_find_all(d, "//body//p"))
p <- trimws(gsub("\\s+"," ",p))
cat("  ", grep("^FIRST", p, value=TRUE), "\n")
cat("  ", grep("^LATER", p, value=TRUE), "\n")
oth <- p[!grepl("^(FIRST|LATER)", p)]
if (length(oth)) cat("   other <p>:", substr(paste(oth, collapse=" | "),1,200), "\n")
m <- xml2::xml_attr(xml2::xml_find_all(d, "//meta[@name]"), "content")
nm <- xml2::xml_attr(xml2::xml_find_all(d, "//meta[@name]"), "name")
mm <- paste0(nm, "=", m); cat("   meta:", paste(mm[!nm %in% c("viewport","generator")], collapse="; "), "\n")
