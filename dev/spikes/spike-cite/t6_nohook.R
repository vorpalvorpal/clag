source("/private/tmp/claude-501/-Users-rjs-dev-clag/bb4358e7-968a-4a0e-b048-468bd4e2be97/scratchpad/spike-cite/harness.R")
body <- c('Inline span: [0.45 µm]{.weft-literal why="pore size, SOP 12"} done.', '',
 '::: {.weft-literal why="laboratory method, as specified in the SOP"}', 'Samples were filtered through 0.45 µm membranes and stored at 4 °C.', ':::')
mk("nohook", body, setup = FALSE, bib = "")
render_all("nohook")
