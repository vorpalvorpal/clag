cat(format(Sys.time()), "pre ALL=", Sys.getenv("QUARTO_PROJECT_RENDER_ALL"), "FILES=", Sys.getenv("QUARTO_PROJECT_INPUT_FILES"), "
", file="log.txt", append=TRUE)
