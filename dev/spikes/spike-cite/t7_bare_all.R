source("/private/tmp/claude-501/-Users-rjs-dev-clag/bb4358e7-968a-4a0e-b048-468bd4e2be97/scratchpad/spike-cite/harness.R")
body <- c(
'# Heading: [Depth 10 m]{cite="smith2020"} per @smith2020', '',
'Para: @smith2020 found [10 m]{cite="smith2020"} upstream; [see @smith2020, p. 4; @jones2019] gave [3 m]{cite="smith2020; jones2019"}.', '',
'- list: -@smith2020 found [10 m]{cite="smith2020"}', '',
'> quote: [10 m]{cite="jones2019"} per @jones2019.', '',
'| a | b |', '|---|---|', '| @smith2020 | [10 m]{cite="smith2020"} |', '',
'Note.^[Inside: [10 m]{cite="smith2020"} per @smith2020.] Def.[^1]', '', '[^1]: Def: [10 m]{cite="jones2019"} per @jones2019.', '',
'```{r}', '#| label: fig-a', '#| fig-cap: |', '#|   Cap: [10 m]{cite="smith2020"} per @smith2020.', 'plot(1:3)', '```', '', '# Refs', '', '::: {#refs}', ':::')
mk("bare_all", body); render_all("bare_all")
