cat(format(Sys.time()), "post ALL=", Sys.getenv("QUARTO_PROJECT_RENDER_ALL"), "
", file="log.txt", append=TRUE)
