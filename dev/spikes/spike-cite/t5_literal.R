source("/private/tmp/claude-501/-Users-rjs-dev-clag/bb4358e7-968a-4a0e-b048-468bd4e2be97/scratchpad/spike-cite/harness.R")
basic <- c(
'Inline: pores of [0.45 µm]{.weft-literal why="pore size, SOP 12"} were used.', '',
'::: {.weft-literal why="laboratory method, as specified in the SOP"}',
'Samples were filtered through 0.45 µm membranes and stored at 4 °C.',
':::', '',
'Inside an arm: [a site | [0.45 µm]{.weft-literal why="pore size"} at # sites]{n="n_sites"}.', '',
'```{r}', '#| label: fig-a', '#| fig-cap: |', '#|   Caption with [0.45 µm]{.weft-literal why="cap reason"} pores.', 'plot(1:3)', '```')
mk("lit_basic", basic)
split <- c('::: {.weft-literal why="split across text blocks"}', 'First part, before the chunk.', '', '```{r}', 'cat("")', '```', '', 'Second part, after the chunk.', ':::')
mk("lit_split", split)
nest <- c(
'::: {.callout-note}', 'Outer note.', '',
'::: {.weft-literal why="nested in a div"}', 'Inner literal 0.45 µm.', ':::', ':::', '',
'- list item one', '',
'  ::: {.weft-literal why="in a list item"}', '  Literal in a list 4 °C.', '  :::', '',
'- list item two', '',
'> ::: {.weft-literal why="in a block quote"}', '> Literal in a quote 0.45 µm.', '> :::', '',
':::: {.weft-literal why="four colons"}', 'Four colon fence.', '::::')
mk("lit_nest", nest)
chars <- c(
'::: {.weft-literal why="a, b; c"}', 'comma semicolon', ':::', '',
'::: {.weft-literal why="the lab\'s SOP"}', 'apostrophe', ':::', '',
'::: {.weft-literal why="see #12 and # hash"}', 'hash', ':::', '',
'::: {.weft-literal why="a | b || c"}', 'bar', ':::', '',
'::: {.weft-literal why="brackets [x] {y} (z) ] }"}', 'brackets', ':::', '',
'::: {.weft-literal why=unquoted_reason}', 'unquoted', ':::', '',
'Spans: [s1]{.weft-literal why="a, b"} [s2]{.weft-literal why="lab\'s"} [s3]{.weft-literal why="#12 | x"} [s4]{.weft-literal why="[x] {y} ] }"} [s5]{.weft-literal why=unq}.')
mk("lit_chars", chars)
forms <- c(
'[o1]{why="order first" .weft-literal} [o2]{.weft-literal #lit1 why="with id" lang=en} [o3]{.weft-literal .extra why="two classes" data-k="keep"} [o4]{.weft-literal}.', '',
'::: {why="div order first" .weft-literal #d1 data-k="keep"}', 'div with id and extra attribute', ':::', '',
'[not literal]{.other why="kept: not weft-literal"}.', '',
'```markdown', '::: {.weft-literal why="inside a non-executed fence"}', 'x', ':::', '```')
mk("lit_forms", forms)
for (nm in c("lit_basic", "lit_split", "lit_nest", "lit_chars", "lit_forms")) render_all(nm)
