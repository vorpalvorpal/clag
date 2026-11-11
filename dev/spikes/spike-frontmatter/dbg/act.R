cat("ACT called by:", deparse(sys.call(-4))[1], "\n", file=stderr())
if (is.null(getOption("weft.act"))) { source("setup.R"); clag_install(); options(weft.act = TRUE) }
TRUE
