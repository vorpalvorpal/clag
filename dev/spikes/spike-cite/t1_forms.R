source("/private/tmp/claude-501/-Users-rjs-dev-clag/bb4358e7-968a-4a0e-b048-468bd4e2be97/scratchpad/spike-cite/harness.R")
body <- c(
'## Heading with [a catchment]{cite="@smith2020"} here', '',
'Plain sentence end: the depth was [10 m in the upper catchment]{cite="@smith2020"}.', '',
'Locator: the depth was [10 m]{cite="@smith2020, p. 4"} upstream.', '',
'Prefix: the depth was [10 m]{cite="see @smith2020"} upstream.', '',
'Two keys: the depth was [10 m]{cite="@smith2020; @jones2019"} upstream.', '',
'Suppress author: the depth was [10 m]{cite="-@smith2020"} upstream.', '',
'Before punctuation: the depth was [10 m]{cite="@smith2020"}, and the width [3 m]{cite="@jones2019"}; ok.', '',
'Unquoted: the depth was [10 m]{cite=@smith2020} upstream.', '',
'Braced key: the depth was [10 m]{cite="@{smith2020}"} upstream.', '',
'- list item with [10 m]{cite="@smith2020"} in it',
'- second item', '',
'> block quote with [10 m]{cite="@jones2019"} in it', '',
'| col A | col B |',
'|-------|-------|',
'| [10 m]{cite="@smith2020"} | plain |', '',
'Inline footnote.^[A note with [10 m]{cite="@smith2020"} in it.] And a definition footnote.[^1]', '',
'[^1]: Definition note with [10 m]{cite="@jones2019"} in it.', '',
'```{r}',
'#| label: fig-a',
'#| fig-cap: |',
'#|   Caption with [10 m]{cite="@smith2020"} in it.',
'plot(1:3)',
'```', '',
'Cross-ref to @fig-a here.', '',
'## Refs', '', '::: {#refs}', ':::')
mk("forms", body)
render_all("forms")
