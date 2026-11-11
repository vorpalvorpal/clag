pend <- list(); O <- ""; C <- ""
fmts <- list(num = function(v) list(text = format(round(v)), number = round(v)),
             word = function(v) list(text = c("zero","one","two","three")[v$number + 1], number = v$number))
attrs <- function(a) list(
  cls = regmatches(a, gregexpr("(?<=\\.)[A-Za-z][A-Za-z0-9_-]*(?=\\s|$)", a, perl = TRUE))[[1]],
  kv  = { m <- regmatches(a, gregexpr("([a-z]+)=\"([^\"]*)\"", a, perl = TRUE))[[1]]
          setNames(sub("^[a-z]+=\"(.*)\"$", "\\1", m), sub("=.*", "", m)) })
# value -> claims on the RAW value -> formatter classes left to right -> text + printed number
run <- function(expr, a, what) {
  val <- eval(parse(text = expr), knitr::knit_global())
  for (chk in a$kv[names(a$kv) == "claim"])
    if (!isTRUE(eval(parse(text = chk), list(. = val), knitr::knit_global())))
      stop("Claim on ", what, " failed: ", chk, " with . = ", format(val), call. = FALSE)
  out <- list(text = format(val), number = val)
  for (f in a$cls) { if (is.null(fmts[[f]])) stop("unknown formatter .", f, call. = FALSE)
    out <- fmts[[f]](if (f == "num") val else out) }
  out
}
knitr::knit_hooks$set(evaluate.inline = function(code, envir) { pend[[length(pend) + 1]] <<- code; paste0(O, length(pend), C) })
knitr::knit_hooks$set(text = function(x) {
  txt <- paste(x, collapse = "\n")
  rs <- "\\[([^\\[\\]]*)\\]\\{([^}]*\\bn=\"[^}]*)\\}"          # bracket + attribute block holding n=
  while (grepl(rs, txt, perl = TRUE)) {
    m <- regmatches(txt, regexec(rs, txt, perl = TRUE))[[1]]; a <- attrs(m[3])
    r <- run(a$kv[["n"]], a, paste0("[", m[2], "]"))
    arms <- trimws(strsplit(m[2], "|", fixed = TRUE)[[1]])
    arm <- arms[if (identical(r$text, "1") || identical(r$text, "one")) 1 else 2]   # chosen from the PRINTED value
    txt <- sub(m[1], gsub("#", r$text, arm, fixed = TRUE), txt, fixed = TRUE)
  }
  rv <- paste0(O, "([0-9]+)", C, "(?:\\{([^}]*)\\})?")            # code span + optional attribute block
  while (grepl(rv, txt, perl = TRUE)) {
    m <- regmatches(txt, regexec(rv, txt, perl = TRUE))[[1]]; code <- pend[[as.integer(m[2])]]
    txt <- sub(m[1], run(code, attrs(m[3]), paste0("`r ", code, "`"))$text, txt, fixed = TRUE)
  }
  txt
})
