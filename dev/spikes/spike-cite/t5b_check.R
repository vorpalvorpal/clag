source("/private/tmp/claude-501/-Users-rjs-dev-clag/bb4358e7-968a-4a0e-b048-468bd4e2be97/scratchpad/spike-cite/harness.R")
reasons <- c("pore size", "laboratory method", "cap reason", "split across", "nested in a div", "in a list item", "in a block quote", "four colons",
             "a, b", "lab's", "see #12", "a | b || c", "brackets [x]", "unquoted_reason", "#12 | x", "unq", "order first", "with id", "two classes", "div order first")
for (nm in c("lit_basic", "lit_split", "lit_nest", "lit_chars", "lit_forms")) for (cm in COMBOS) {
  tag <- if (cm[1] == "quarto") "q" else "r"; ext <- c(html = "html", docx = "docx", typst = "pdf", html_document = "html", word_document = "docx")[[cm[2]]]
  f <- paste0(nm, "_", tag, "_", cm[2], ".", ext)
  raw <- if (ext == "html") paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n") else if (ext == "docx") docx_xml(f) else typ_txt(f)
  if (ext == "html") raw <- sub("<script.*?</script>", "", raw)
  hits <- reasons[vapply(reasons, grepl, NA, x = raw, fixed = TRUE)]
  if (nm == "lit_forms") hits <- setdiff(hits, "kept")           # lit_forms holds a deliberate non-literal why and a fenced div
  body <- if (ext == "html") html_txt(f) else if (ext == "docx") docx_txt(f) else typ_txt(f)
  intact <- all(vapply(c("0.45 µm", "4 °C")[1], function(s) TRUE, NA))
  cat(sprintf("%-10s %-14s why-text-hits: %s | has 'data-why' or ' why=': %s\n", nm, paste(cm, collapse = "/"), if (length(hits)) paste(hits, collapse = ";") else "none",
              grepl("data-why| why=", raw)))
}
