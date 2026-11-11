source("/private/tmp/claude-501/-Users-rjs-dev-clag/bb4358e7-968a-4a0e-b048-468bd4e2be97/scratchpad/spike-cite/harness.R")
for (f in c("lit_forms_q_docx.docx", "lit_forms_q_html.html", "lit_forms_r_word_document.docx")) { t <- if (grepl("html$", f)) html_txt(f) else docx_txt(f); cat(f, ": 'why' occurrences in text:", lengths(regmatches(t, gregexpr("why", t))), "\n") }
for (f in c("lit_basic_q_docx.docx", "lit_basic_r_word_document.docx", "lit_basic_q_html.html", "lit_basic_r_html_document.html")) { t <- if (grepl("html$", f)) html_txt(f) else docx_txt(f)
  cat(f, ": ", grepl("0.45 µm were used", t, fixed = TRUE), grepl("filtered through 0.45 µm membranes and stored at 4 °C", t, fixed = TRUE), "| arm+caption:", grepl("5 sites", t), grepl("Caption with 0.45 µm pores", t, fixed = TRUE), "\n") }
t <- typ_txt("lit_basic_q_typst.pdf"); cat("typ:", grepl("0.45 µm were used", t, fixed = TRUE), grepl("stored at 4 °C", t, fixed = TRUE), "\n")
cat(grep("0.45|SOP", strsplit(t, "\n")[[1]], value = TRUE), sep = "\n")
