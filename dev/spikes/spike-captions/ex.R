## usage: Rscript ex.R file.html -> prints captions, alts and xref text
f <- commandArgs(TRUE)[1]
d <- xml2::read_html(f, encoding = "UTF-8")
sq <- function(x) trimws(gsub("[[:space:]]+", " ", x))
cat("-- figcaption/caption:\n")
for (n in xml2::xml_find_all(d, "//figcaption|//caption|//p[@class='caption']|//div[@class='caption']|//*[contains(@class,'gt_caption')]")) cat("  ", sq(xml2::xml_text(n)), "\n")
cat("-- img alt:\n")
for (a in xml2::xml_attr(xml2::xml_find_all(d, "//img"), "alt")) cat("  ", a, "\n")
cat("-- xrefs / other:\n")
for (n in xml2::xml_find_all(d, "//a[contains(@class,'quarto-xref')]")) cat("  ", sq(xml2::xml_text(n)), "")
cat("\n-- GGCAPTION:\n"); for (n in xml2::xml_find_all(d, "//*[contains(text(),'GGCAPTION')]")) cat("  ", sq(xml2::xml_text(n)), "\n")
