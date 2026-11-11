source("/private/tmp/claude-501/-Users-rjs-dev-clag/bb4358e7-968a-4a0e-b048-468bd4e2be97/scratchpad/spike-cite/harness.R")
S <- 'smith2020'
C <- function(...) paste0('[10 m]{cite="', paste(c(...), collapse = "; "), '"}')
cases <- list(
 list("b01_same_para", "pass", c('@smith2020 found [10 m]{cite="smith2020"} upstream.')),
 list("b02_next_para", "fail", c('[10 m]{cite="smith2020"} found upstream.', '', '@smith2020 says so.')),
 list("b03_bracketed", "pass", c('Depth [10 m]{cite="smith2020"} found [@smith2020].')),
 list("b04_suppress", "pass", c('Depth [10 m]{cite="smith2020"} found -@smith2020.')),
 list("b05_complex", "pass", c('Depth [10 m]{cite="smith2020; jones2019"} found [see @smith2020, p. 4; @jones2019].')),
 list("b06_one_missing", "fail", c('Depth [10 m]{cite="smith2020; jones2019"} found [see @smith2020, p. 4].')),
 list("b07_longer_key", "fail", c('Depth [10 m]{cite="smith2020"} found @smith2020a here.')),
 list("b08_cite_after", "pass", c('Depth [10 m]{cite="smith2020"} found by @smith2020.')),
 list("b09_heading_pass", "pass", c('# Depth [10 m]{cite="smith2020"} per @smith2020')),
 list("b10_heading_next", "fail", c('# Depth [10 m]{cite="smith2020"}', '@smith2020 says so.')),
 list("b11_tight_list_other_item", "fail", c('- @smith2020 first item', '- second [10 m]{cite="smith2020"} item')),
 list("b12_list_same_item", "pass", c('- @smith2020 and [10 m]{cite="smith2020"} item', '- second item')),
 list("b13_loose_list_other_item", "fail", c('- @smith2020 first item', '', '- second [10 m]{cite="smith2020"} item')),
 list("b14_table_same_row", "pass", c('| a | b |', '|---|---|', '| @smith2020 | [10 m]{cite="smith2020"} |')),
 list("b15_table_other_row", "fail", c('| a | b |', '|---|---|', '| @smith2020 | x |', '| [10 m]{cite="smith2020"} | y |')),
 list("b16_table_cite_in_header", "fail", c('| @smith2020 | b |', '|---|---|', '| [10 m]{cite="smith2020"} | y |')),
 list("b17_note_inside_pass", "pass", c('Text.^[Note: [10 m]{cite="smith2020"} per @smith2020.] More.')),
 list("b18_note_cite_outside", "fail", c('Text per @smith2020.^[Note: [10 m]{cite="smith2020"}.] More.')),
 list("b19_span_outside_cite_in_note", "fail", c('Text [10 m]{cite="smith2020"}.^[Note per @smith2020.] More.')),
 list("b20_def_note_pass", "pass", c('Text[^1].', '', '[^1]: Note: [10 m]{cite="smith2020"} per @smith2020.')),
 list("b21_def_note_cite_in_body", "fail", c('Text per @smith2020[^1].', '', '[^1]: Note: [10 m]{cite="smith2020"}.')),
 list("b22_blockquote_pass", "pass", c('> Quote [10 m]{cite="smith2020"}', '> per @smith2020.')),
 list("b23_wrapped_lines", "pass", c('Depth [10 m]{cite="smith2020"} was found', 'in the upper catchment', 'by @smith2020.')),
 list("b24_code_span_not_cite", "fail", c('Depth [10 m]{cite="smith2020"} (write `@smith2020`).')),
 list("b25_email_not_cite", "fail", c('Depth [10 m]{cite="smith2020"} (mail foo@smith2020).')),
 list("b26_braced_key", "pass", c('Depth [10 m]{cite="smith2020"} per @{smith2020}.')),
 list("b27_unknown_bare", "fail", c('@smith2020 found [10 m]{cite="nosuchkey"} upstream.')),
 list("b28_unknown_citation_form", "fail", c('Depth [10 m]{cite="@nosuchkey"} upstream.')),
 list("b29_unknown_second_key", "fail", c('Depth [10 m]{cite="@smith2020; @nosuchkey"} upstream.')),
 list("b30_inline_value_in_bare", "pass", c('@smith2020 found [`r x`{.dec1} m]{cite="smith2020"} upstream.')),
 list("b31_div_same_para", "pass", c('::: {.callout-note}', '@smith2020 found [10 m]{cite="smith2020"}.', ':::')),
 list("b32_div_split_para", "fail", c('::: {.callout-note}', '[10 m]{cite="smith2020"}.', '', '@smith2020 found.', ':::')),
 list("b33_across_chunk", "fail", c('[10 m]{cite="smith2020"} found.', '', '```{r}', 'invisible(1)', '```', '', '@smith2020 says.')),
 list("b34_caption_pass", "pass", c('```{r}', '#| label: fig-a', '#| fig-cap: |', '#|   Caption [10 m]{cite="smith2020"} per @smith2020.', 'plot(1:3)', '```')),
 list("b35_caption_cite_in_body", "fail", c('Body per @smith2020.', '', '```{r}', '#| label: fig-a', '#| fig-cap: |', '#|   Caption [10 m]{cite="smith2020"}.', 'plot(1:3)', '```')),
 list("b36_caption_cite_after_chunk", "fail", c('```{r}', '#| label: fig-a', '#| fig-cap: |', '#|   Caption [10 m]{cite="smith2020"}.', 'plot(1:3)', '```', '', 'Body per @smith2020.')),
 list("b37_cite_with_n", "fail", c('@smith2020 found [10 m | 2 m]{cite="smith2020" n="n_sites"}.')),
 list("b38_empty_key_list", "fail", c('@smith2020 found [10 m]{cite="smith2020;"}.')),
 list("b39_at_in_bare", "pass", c('@smith2020 found [10 m]{cite="smith2020 and @jones2019"}.')),
 list("b40_table_two_rows_pass", "pass", c('| a | b |', '|---|---|', '| [10 m]{cite="smith2020"} @smith2020 | x |'))
)
args <- commandArgs(TRUE); only <- if (length(args)) args else NULL
out <- list()
for (cs in cases) { nm <- cs[[1]]; if (!is.null(only) && !nm %in% only) next
  mk(nm, cs[[3]])
  for (cm in list(c("quarto", "html"), c("rmarkdown", "html_document"))) {
    r <- render(nm, cm[1], cm[2])
    msg <- if (r$ok) "" else { l <- strsplit(r$log, "\n")[[1]]; paste(substr(grep("clag:", l, value = TRUE)[1] %||% substr(r$log, 1, 200), 1, 260)) }
    got <- if (r$ok) "pass" else "fail"
    out[[length(out) + 1]] <- data.frame(case = nm, engine = cm[1], expect = cs[[2]], got = got, match = got == cs[[2]], msg = msg)
  }
}
res <- do.call(rbind, out); write.csv(res, "../bare_results.csv", row.names = FALSE)
print(res[, c("case", "engine", "expect", "got", "match")], row.names = FALSE)
cat("\nMISMATCHES:\n"); print(res[!res$match, ], row.names = FALSE)
cat("\nERROR MESSAGES (quarto):\n"); for (i in which(res$engine == "quarto" & res$got == "fail")) cat(res$case[i], ":", res$msg[i], "\n")
