by <- function(n) {
  arm <- if (n == 1) 1 else 2
  knitr::asis_output(sprintf('[]{.clag-pick arm="%d" text="%s"}', arm, format(n)))
}
