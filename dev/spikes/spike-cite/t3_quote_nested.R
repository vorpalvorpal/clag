source("/private/tmp/claude-501/-Users-rjs-dev-clag/bb4358e7-968a-4a0e-b048-468bd4e2be97/scratchpad/spike-cite/harness.R")
BIB2 <- "bibliography: [refs.bib, refs_csl.json]"
## quoting: legal Pandoc citations written as attribute values
q <- c(
'Q1 entity quote: [10 m]{cite="@smith2020, ch. 2 &quot;Methods&quot;"} end.', '',
'Q3 entity backslash: [10 m]{cite="@smith2020, p.&#92; 4"} end.', '',
'Q4 braced key with spaces: [10 m]{cite="@{key with spaces}"} end.', '',
'Q5 URL key: [10 m]{cite="@{https://doi.org/10.1000/xyz}, p. 2"} end.', '',
'Q6 bracket in suffix: [10 m]{cite="@smith2020, p. 4 [sic]"} end.', '',
'Q7 apostrophes: [10 m]{cite="@smith2020, Smith\'s \'own\' table"} end.', '',
'Q8 semicolon and prefix: [10 m]{cite="see @smith2020, p. 4; also @jones2019, ch. 2"} end.', '',
'Q9 unquoted key: [10 m]{cite=@smith2020} end.')
mk("quote_ok", q, bib = BIB2); render_all("quote_ok", COMBOS[c(1,4)])
errs <- list(
  quote_err1 = 'Q: [10 m]{cite="@smith2020, ch. 2 \\"Methods\\""} end.',
  quote_err2 = 'Q: [10 m]{cite="@smith2020, \\S 4"} end.',
  quote_err3 = "Q: [10 m]{cite='@smith2020'} end.",
  quote_err4 = 'Q: [10 m]{cite=@smith2020"x} end.',
  quote_err5 = 'Q: [10 m]{cite="see \\"x\\" @smith2020"} end.',
  quote_err6 = 'Q: [10 m]{cite="@{quote\\"key}"} end.',
  quote_err7 = 'Q: [10 m]{cite="@{quote"key}"} end.',
  quote_err8 = 'Q: `r x`{.num claim="\\"a\\""} end.',
  quote_err9 = 'Q: [10 m]{.weft-literal why="the \\"SOP\\""} end.',
  quote_err11 = 'Q: [10 m]{cite=@{https://doi.org/10.1000/xyz}} end.',
  quote_err10 = 'Q: [10 m]{.weft-literal why="path C:\\SOP"} end.')
for (n in names(errs)) { mk(n, errs[[n]], bib = BIB2); r <- render(n, "quarto", "html"); l <- strsplit(r$log, "\n")[[1]]
  cat(n, "| ok =", r$ok, "|", substr(grep("clag:|rror", l, value = TRUE)[1], 1, 220), "\n") }
## nested
nest <- c(
'N1 citation form: values and a governed span inside: [depth `r x`{.dec1} m at [a site | # sites]{n="n_sites"}, a|b and #1 and \\| and \\#]{cite="@smith2020"} end.', '',
'N2 bare form: @smith2020 found [depth `r x`{.dec1} m at [a site | # sites]{n="n_sites"}, a|b and #1]{cite="smith2020"} end.', '',
'N3 cite span inside an arm: [a site | # sites, [10 m | x #y]{cite="@smith2020"}]{n="n_sites"} end.', '',
'N4 governed span inside a table cell, cite span with bar:', '',
'| a | b |', '|---|---|', '| [x \\| y # z]{cite="@smith2020"} | [a site | # sites]{n="n_sites"} |')
mk("nested", nest); render_all("nested")
