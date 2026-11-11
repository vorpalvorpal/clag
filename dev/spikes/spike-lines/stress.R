## Stress document generator: ~330 text blocks of awkward shapes. Returns character vector of lines.
gen_stress <- function(engine = "rmarkdown", n = 330L, seed = 42L, install = TRUE) {
  set.seed(seed)
  hdr <- if (engine == "quarto") c("---", "format: html", "---", "") else c("---", "output: html_document", "---", "")
  L <- c(hdr, "```{r}", "#| include: false", if (install) 'source("lines.R"); lines_install()', "k <- 1", "```", "")
  dup <- "Duplicate paragraph `r k` here."
  shapes <- c("plain", "dup", "dup", "blank", "ws", "tab", "trap", "fence", "uni", "multi", "comment", "long", "adjacent", "bq", "tick4", "twolines", "trap2")
  for (i in seq_len(n)) {
    s <- sample(shapes, 1)
    body <- switch(s,
      plain = c(sprintf("Plain %d with `r k` and more.", i), "", sprintf("Second para %d.", i)),
      dup = c(dup),
      blank = character(),
      ws = c("   ", "\t"),
      tab = c(sprintf("\tIndented `r k ` code-ish %d", i), "    four spaces `r k`"),
      trap = NULL, trap2 = NULL,                      # handled below (chunk first)
      fence = c("```markdown", "inside fence `r 1+1` and [a | b]{n=\"n\"}", "```", sprintf("after fence %d", i)),
      uni = c(sprintf("Café ☃ `r k` naïve 日本語 %d \U0001F600", i)),
      multi = c(sprintf("`r 1``r 2` and `r 3` then `r 4`: %d", i)),
      comment = c(sprintf("<!-- note %d `r k` -->", i)),
      long = c(paste0("L", i, " ", strrep("word `r k` ", 300))),
      adjacent = c(sprintf("before adjacent %d", i)),
      bq = c(sprintf("> quote `r k` %d", i), ">", "> more"),
      tick4 = c("````markdown", "```r", "not a chunk `r 1`", "```", "````"),
      twolines = c(dup, dup))
    if (s == "trap2") {          # text block [dup] directly after a chunk whose code holds the same line
      L <- c(L, "```{r, eval=FALSE, include=FALSE}", "invisible(0)", dup, "```", dup, "```{r}", "invisible(0)", "```", "")
      next
    }
    if (s == "trap") {
      L <- c(L, "```{r, eval=FALSE, include=FALSE}", "invisible(0)", dup, "```", "", dup, "")        # the same line sits inside the chunk right above
      next
    }
    L <- c(L, "", body, "")
    code <- switch(sample(1:4, 1), c("```{r}", "invisible(0)", "```"), c("```{r, include=FALSE}", "x <- 1", "```"),
                   c("````{r}", "y <- '```'", "````"), c("```{r, eval=FALSE, include=FALSE}", dup, "```"))
    L <- c(L, code)
    if (s == "adjacent") L <- c(L, "```{r}", "invisible(2)", "```")   # two chunks, no text block between
  }
  c(L, "", "The end `r k`")
}
