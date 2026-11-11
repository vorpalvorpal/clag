# Formatting (rules 1.4, 1.5.8-1.5.9, 3.2, 3.4): the printed record, the four
# fixed stages, the fmt_*() functions, glue_vec() and plural().

# ---- the class registry -------------------------------------------------

# Stage i, ii (main), iii; the text stage has no at-most-one rule.
NUMBER_CLASSES <- c(".num", ".pct", ".sci", ".p", ".date")
WORDING_CLASSES <- c(".word", ".count", ".ord")
COLLAPSE_CLASSES <- c(".and", ".or", ".pairs", ".range", ".ul", ".ol", ".dl")
TEXT_CLASSES <- c(".a", ".cap", ".strong", ".em")
RENDERER_KEYS <- c("digits", "sigfig", "sep", "last", "trunc")
# Named by the spec but not built in stage 1a: they stop with a construct
# error that says so.
NOT_BUILT_CLASSES <- c(".p", ".date", ".pairs", ".range", ".ul", ".ol", ".dl",
                       ".a", ".cap", ".weft-literal")

shipped_classes <- function() {
  c(NUMBER_CLASSES, ".no", WORDING_CLASSES, COLLAPSE_CLASSES, TEXT_CLASSES,
    ".weft-literal")
}

# The at-most-one group of a class, `NA` when it has none. `reg` is the
# configuration's `formatters` (1.4.8).
class_group <- function(cls, reg = list()) {
  out <- rep(NA_character_, length(cls))
  out[cls %in% NUMBER_CLASSES] <- "number"
  out[cls %in% WORDING_CLASSES] <- "wording"
  out[cls %in% COLLAPSE_CLASSES] <- "collapse"
  for (nm in intersect(cls, names(reg))) {
    st <- reg[[nm]][["stage"]] %||% "number"
    if (st != "text") out[cls == nm] <- st
  }
  out
}

# Every formatter class: those that make a construct a formatted one.
formatter_classes <- function(reg = list()) {
  c(NUMBER_CLASSES, ".no", WORDING_CLASSES, COLLAPSE_CLASSES, names(reg))
}

# ---- the printed record -------------------------------------------------

new_weft_text <- function(text, number = NULL, decimals = NULL, relation = NULL,
                          raw = NULL) {
  text <- as.character(text)
  n <- length(text)
  structure(
    text,
    class = c("weft_text", "character"),
    number = number %||% rep(NA_real_, n),
    decimals = decimals %||% rep(FALSE, n),
    relation = relation %||% rep("=", n),
    raw = raw %||% rep(NA_real_, n)
  )
}

#' @export
print.weft_text <- function(x, ...) {
  cat("<weft_text>\n")
  print(as.character(x), ...)
  invisible(x)
}

#' @export
format.weft_text <- function(x, ...) as.character(x)

# ---- errors -------------------------------------------------------------

no_value_error <- function(what = "A formatter") {
  weft_abort(paste0(what, " was given a missing value (NA, NaN, Inf, -Inf or ",
                    "a value of length zero)."), "weft_no_value")
}

value_error <- function(msg) weft_abort(msg, "weft_value_error")

construct_error <- function(msg) weft_abort(msg, "weft_construct_error")

# A missing value (1.3.4): an element that is NA, NaN, Inf or -Inf, or a
# value of length zero.
check_present <- function(x, what = "A formatter") {
  if (length(x) == 0L) no_value_error(what)
  if (is.list(x)) {
    for (el in x) check_present(el, what)
    return(invisible(x))
  }
  bad <- if (is.numeric(x)) !is.finite(x) else is.na(x)
  if (any(bad)) no_value_error(what)
  invisible(x)
}

# ---- numbers ------------------------------------------------------------

group_int <- function(digits, mark) {
  if (!nzchar(mark)) return(digits)
  gsub("(\\d)(?=(\\d{3})+$)", paste0("\\1", mark), digits, perl = TRUE)
}

is_whole <- function(v) abs(v - round(v)) < 1e-9

# Round half away from zero on the decimal number as written (the double is
# first read to 15 significant digits, so 0.15 is 0.15 and not 0.1499...).
round_half_away <- function(x, nd) {
  if (x == 0) return(0)
  sgn <- sign(x)
  a <- abs(x)
  if (nd >= 0) {
    y <- a * 10^nd
    if (!is.finite(y)) return(x)
    r <- floor(signif(y, 15) + 0.5) / 10^nd
  } else {
    p <- 10^(-nd)
    r <- floor(signif(a / p, 15) + 0.5) * p
  }
  sgn * r
}

# One number printed by rule 1.4.13: returns text, the number as printed and
# whether decimals show.
print_one <- function(v, digits, sigfig, cfg) {
  if (!is.null(sigfig)) {
    s <- if (v == 0) 0 else round_half_away(v, sigfig - 1L - floor(log10(abs(v))))
    nd <- if (s == 0) sigfig - 1L else max(sigfig - 1L - floor(log10(abs(s))), 0L)
  } else if (!is.null(digits)) {
    nd <- as.integer(digits)
    s <- round_half_away(v, nd)
  } else {
    nd <- if (is_whole(v)) 0L else as.integer(cfg$digits)
    s <- round_half_away(v, nd)
  }
  str <- sprintf(paste0("%.", nd, "f"), abs(s))
  num <- as.numeric(str)
  neg <- s < 0 && num != 0
  parts <- strsplit(str, ".", fixed = TRUE)[[1]]
  int <- parts[1]
  if (num >= 10000) int <- group_int(int, cfg$big_mark)
  txt <- if (length(parts) > 1L) paste0(int, cfg$decimal_mark, parts[2]) else int
  if (neg) {
    txt <- paste0(cfg$minus, txt)
    num <- -num
  }
  list(text = txt, number = num, decimals = nd > 0L)
}

key_number <- function(keys, name) {
  v <- keys[[name]]
  if (is.null(v)) return(NULL)
  out <- suppressWarnings(as.numeric(v))
  if (length(out) != 1L || is.na(out) || out < 0 || out != round(out)) {
    construct_error(sprintf("`%s` must be a whole number, not negative (got `%s`).",
                            name, paste(format(v), collapse = " ")))
  }
  out
}

format_numbers <- function(value, class, keys, cfg) {
  digits <- key_number(keys, "digits")
  sigfig <- key_number(keys, "sigfig")
  if (!is.null(sigfig) && sigfig < 1) {
    construct_error("`sigfig` must be at least 1.")
  }
  one <- function(v) {
    if (class == ".pct") {
      p <- print_one(if (isTRUE(cfg$pct_proportion)) v * 100 else v,
                     digits, sigfig, cfg)
      p$text <- paste0(p$text, "%")
      p
    } else if (class == ".sci") {
      sci_one(v, digits, sigfig, cfg)
    } else {
      print_one(v, digits, sigfig, cfg)
    }
  }
  res <- lapply(as.numeric(value), one)
  new_weft_text(
    vapply(res, `[[`, "", "text"),
    number = vapply(res, `[[`, 0, "number"),
    decimals = vapply(res, `[[`, NA, "decimals"),
    raw = as.numeric(value)
  )
}

sci_one <- function(v, digits, sigfig, cfg) {
  e <- if (v == 0) 0 else floor(log10(abs(v)))
  # 10^e is split in two so that a denormal number does not underflow
  m <- if (v == 0) 0 else (v / 10^(e %/% 2)) / 10^(e - e %/% 2)
  p <- print_one(m, digits, sigfig, cfg)
  if (abs(p$number) >= 10) {
    e <- e + 1
    p <- print_one(m / 10, digits, sigfig, cfg)
  }
  exp_txt <- if (e < 0) paste0(cfg$minus, abs(e)) else as.character(e)
  list(
    text = paste0(p$text, " \u00d7 10^", exp_txt, "^"),
    number = (p$number * 10^(e %/% 2)) * 10^(e - e %/% 2),
    decimals = p$decimals
  )
}

# ---- words --------------------------------------------------------------

spell_int <- function(n) {
  ones <- c("zero", "one", "two", "three", "four", "five", "six", "seven",
            "eight", "nine", "ten", "eleven", "twelve", "thirteen", "fourteen",
            "fifteen", "sixteen", "seventeen", "eighteen", "nineteen")
  tens <- c("", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy",
            "eighty", "ninety")
  if (n < 20) return(ones[n + 1])
  if (n < 100) {
    t <- n %/% 10
    o <- n %% 10
    return(if (o == 0) tens[t + 1] else paste0(tens[t + 1], "-", ones[o + 1]))
  }
  big <- function(unit, name) {
    q <- n %/% unit
    r <- n %% unit
    paste0(spell_int(q), " ", name, if (r > 0) paste0(" ", spell_int(r)))
  }
  if (n < 1000) return(big(100, "hundred"))
  if (n < 1e6) return(big(1000, "thousand"))
  if (n < 1e9) return(big(1e6, "million"))
  NA_character_
}

ordinal_suffix <- function(n) {
  # from the printed digits, so a very large number does not lose accuracy
  ds <- sprintf("%.0f", n)
  last2 <- as.integer(substring(ds, max(nchar(ds) - 1L, 1L)))
  last <- last2 %% 10L
  if (last2 %in% 11:13) "th"
  else if (last == 1) "st"
  else if (last == 2) "nd"
  else if (last == 3) "rd"
  else "th"
}

# ---- the four stages ----------------------------------------------------

# Format `value` by the classes and renderer keys of a construct (1.4.1).
# `keys` is a named list or character vector of renderer keys. The knitr
# resolver of a later package calls this too. Returns a weft_text. With
# `governor = TRUE` only stages i and ii run, and a construct with no
# formatter class, `digits` or `sigfig` uses `config$governor_class`
# (1.5.7, 1.5.18).
apply_formatters <- function(value, classes = character(), keys = list(),
                             config = current_config(), governor = FALSE) {
  cfg <- config
  reg <- cfg$formatters %||% list()
  classes <- unique(as.character(classes))
  keys <- as.list(keys)
  names(keys) <- tolower(names(keys))
  keys <- keys[!vapply(keys, is.null, NA)]

  if (governor) {
    has_fmt <- any(!is.na(class_group(classes, reg))) || ".no" %in% classes ||
      !is.null(keys$digits) || !is.null(keys$sigfig)
    if (!has_fmt) classes <- c(classes, cfg$governor_class)
  }

  proj <- function(stage) {
    nm <- intersect(classes, names(reg))
    nm[vapply(nm, function(k) identical(reg[[k]][["stage"]] %||% "number", stage), NA)]
  }

  # construct errors that need no value
  grp <- class_group(classes, reg)
  for (g in unique(grp[!is.na(grp)])) {
    if (sum(grp == g, na.rm = TRUE) > 1L) {
      construct_error(sprintf(
        "Two classes from one group (%s) in one construct: %s (rule 1.4.2).",
        g, paste(classes[which(grp == g)], collapse = " ")))
    }
  }
  if (!is.null(keys$digits) && !is.null(keys$sigfig)) {
    construct_error("`digits` and `sigfig` together are an error (rule 1.4.7).")
  }
  nb <- intersect(classes, NOT_BUILT_CLASSES)
  if (length(nb)) {
    construct_error(sprintf("The class `%s` is not built yet.", nb[1]))
  }
  if (!is.null(keys$trunc)) construct_error("The key `trunc` is not built yet.")
  unit_cls <- intersect(classes, c(".pct", ".sci"))
  wording_cls <- c(intersect(classes, WORDING_CLASSES), proj("wording"))
  if (length(unit_cls) && length(wording_cls)) {
    construct_error(sprintf(
      "`%s` with `%s` in one construct is an error: the wording class would drop what `%s` prints (rule 1.4.1).",
      unit_cls[1], wording_cls[1], unit_cls[1]))
  }

  what <- "A formatter"
  if (!inherits(value, "weft_text")) check_present(value, what)
  if (is.factor(value)) value <- as.character(value)

  # stage i: number. `digits` or `sigfig` imply `.num` (1.4.7).
  ncls <- c(intersect(classes, c(".num", ".pct", ".sci")), proj("number"))
  if (!length(ncls) && (!is.null(keys$digits) || !is.null(keys$sigfig))) {
    ncls <- ".num"
  }
  rec <- NULL
  if (length(ncls)) {
    cls <- ncls[1]
    if (inherits(value, "weft_text")) {
      # a number formatter formats the raw value afresh (1.7.8)
      num <- attr(value, "raw")
      if (is.null(num)) num <- attr(value, "number")
      if (!is.numeric(num) || anyNA(num)) {
        value_error("A number formatter needs a number, and this value has none.")
      }
      value <- num
    }
    if (!is.numeric(value)) {
      value_error(sprintf("`%s` needs a number; the value is of class %s.",
                          cls, class(value)[1]))
    }
    if (cls %in% names(reg)) {
      rec <- apply_project(reg[[cls]], value, value)
    } else {
      rec <- format_numbers(value, cls, keys, cfg)
    }
  } else if (inherits(value, "weft_text")) {
    rec <- value
  } else if (is.numeric(value)) {
    rec <- format_numbers(value, ".num", keys, cfg)
  } else {
    rec <- new_weft_text(as.character(value))
  }
  text <- as.character(rec)
  number <- attr(rec, "number")
  decimals <- attr(rec, "decimals")
  relation <- attr(rec, "relation")
  raw <- attr(rec, "raw") %||% rep(NA_real_, length(text))

  # stage ii: wording
  is_no <- rep(FALSE, length(text))
  if (".no" %in% classes) {
    is_no <- !is.na(number) & number == 0 & !decimals & relation == "="
    text[is_no] <- "no"
  }
  if (length(wording_cls)) {
    w <- wording_cls[1]
    if (w %in% names(reg)) {
      text <- as.character(apply_project(reg[[w]], new_weft_text(text, number, decimals, relation), NULL))
    } else {
      chk <- !is_no
      bad <- chk & (is.na(number) | relation != "=" | decimals %in% TRUE |
                      (!is.na(number) & (number < 0 | number != round(number))))
      if (any(bad)) {
        value_error(sprintf(
          "`%s` needs a whole number that is not negative, judged as printed (rule 1.4.12); got %s.",
          w, paste0("\"", text[bad][1], "\"")))
      }
      for (k in which(chk)) {
        nk <- number[k]
        intk <- group_int(sprintf("%.0f", nk), cfg$big_mark)
        text[k] <- switch(
          w,
          ".word" = if (nk >= cfg$word_limit) text[k] else spell_or(nk, text[k]),
          ".count" = if (nk >= cfg$count_threshold) text[k] else spell_or(nk, text[k]),
          ".ord" = paste0(if (nk >= 10000) intk else sprintf("%.0f", nk),
                          ordinal_suffix(nk))
        )
      }
    }
  }

  if (!governor) {
    # stage iii: collapse
    ccls <- c(intersect(classes, c(".and", ".or")), proj("collapse"))
    if (length(ccls)) {
      cl <- ccls[1]
      if (cl %in% names(reg)) {
        text <- as.character(apply_project(reg[[cl]], text, NULL))
        text <- text[1]
      } else {
        sep <- keys$sep %||% ", "
        last <- keys$last %||% (if (cl == ".and") " and " else " or ")
        text <- as.character(glue_vec(text, sep = sep, last = last))
      }
      number <- NA_real_
      decimals <- FALSE
      relation <- "="
      raw <- NA_real_
    }

    # stage iv: text (an empty string stays empty, 1.2.6)
    wrap <- function(text, mark) {
      nz <- nzchar(text)
      text[nz] <- paste0(mark, text[nz], mark)
      text
    }
    if (".em" %in% classes) text <- wrap(text, "*")
    if (".strong" %in% classes) text <- wrap(text, "**")
    for (nm in proj("text")) {
      text <- as.character(apply_project(reg[[nm]], text, NULL))
    }
  }

  new_weft_text(text, number, decimals, relation, raw)
}

spell_or <- function(n, fallback) {
  s <- spell_int(n)
  if (is.na(s)) fallback else s
}

# Run a project formatter's function. Its result is a character vector or a
# weft_text; a weft_text brings its own record.
apply_project <- function(spec, x, number_source) {
  fn <- resolve_formatter(spec)
  out <- fn(x)
  if (inherits(out, "weft_text")) return(out)
  if (!is.character(out)) out <- as.character(out)
  if (!is.null(number_source)) {
    new_weft_text(out, raw = if (is.numeric(number_source) && length(number_source) == length(out)) as.numeric(number_source))
  } else if (inherits(x, "weft_text")) {
    new_weft_text(out, attr(x, "number"), attr(x, "decimals"), attr(x, "relation"), attr(x, "raw"))
  } else {
    out
  }
}

# ---- exported formatters ------------------------------------------------

#' Formatter functions
#'
#' Each `fmt_*()` function is the R form of a formatter class `.x`
#' (rule 3.4.1). It returns a `weft_text`: a character vector whose
#' attributes hold the printed record (rule 1.4.11), the number as printed,
#' whether decimals are shown, and the relation (`"="`, `"<"` or `">"`).
#' Passing a `weft_text` to another formatter carries the record forward
#' (rule 3.4.2).
#'
#' @param x The value to format. A `weft_text` from another formatter is
#'   accepted.
#' @param digits Decimal places. Not together with `sigfig`.
#' @param sigfig Significant figures. Not together with `digits`.
#' @param sep The text between items of a collapse.
#' @param last The text before the final item of a collapse.
#'
#' @details
#' A missing value (`NA`, `NaN`, `Inf`, `-Inf` or a value of length zero)
#' stops with an error of class `weft_no_value`. A value a class cannot take
#' (a decimal given to `fmt_word()`, say) stops with class
#' `weft_value_error`.
#'
#' @return A `weft_text`.
#' @examples
#' fmt_num(3.14159)
#' fmt_pct(0.12)
#' fmt_word(3)
#' fmt_and(c("a", "b", "c"))
#' @name fmt
NULL

#' @rdname fmt
#' @export
fmt_num <- function(x, digits = NULL, sigfig = NULL) {
  apply_formatters(x, ".num", list(digits = digits, sigfig = sigfig))
}

#' @rdname fmt
#' @export
fmt_pct <- function(x, digits = NULL, sigfig = NULL) {
  apply_formatters(x, ".pct", list(digits = digits, sigfig = sigfig))
}

#' @rdname fmt
#' @export
fmt_sci <- function(x, digits = NULL, sigfig = NULL) {
  apply_formatters(x, ".sci", list(digits = digits, sigfig = sigfig))
}

#' @rdname fmt
#' @export
fmt_no <- function(x) apply_formatters(x, ".no")

#' @rdname fmt
#' @export
fmt_word <- function(x) apply_formatters(x, ".word")

#' @rdname fmt
#' @export
fmt_count <- function(x) apply_formatters(x, ".count")

#' @rdname fmt
#' @export
fmt_ord <- function(x) apply_formatters(x, ".ord")

#' @rdname fmt
#' @export
fmt_and <- function(x, sep = ", ", last = " and ") {
  apply_formatters(x, ".and", list(sep = sep, last = last))
}

#' @rdname fmt
#' @export
fmt_or <- function(x, sep = ", ", last = " or ") {
  apply_formatters(x, ".or", list(sep = sep, last = last))
}

#' @rdname fmt
#' @export
fmt_strong <- function(x) apply_formatters(x, ".strong")

#' @rdname fmt
#' @export
fmt_em <- function(x) apply_formatters(x, ".em")

#' Join items into a phrase
#'
#' The collapse engine behind `.and`, `.or` and the list formatters
#' (rule 3.4.3): `glue_vec(c("a", "b", "c"))` is `"a, b and c"`. With two
#' items only `last` is used.
#'
#' @param x A character vector, or a `weft_text`.
#' @param sep The text between items.
#' @param last The text before the final item.
#' @return A `weft_text` of length one with no number.
#' @examples
#' glue_vec(c("a", "b", "c"))
#' glue_vec(c("a", "b", "c"), last = " or ")
#' @export
glue_vec <- function(x, sep = ", ", last = " and ") {
  x <- as.character(x)
  n <- length(x)
  if (n == 0L || anyNA(x)) no_value_error("A collapse")
  out <- if (n == 1L) {
    x
  } else if (n == 2L) {
    paste0(x[1], last, x[2])
  } else {
    paste0(paste(x[-n], collapse = sep), last, x[n])
  }
  new_weft_text(out)
}

# ---- plural() -----------------------------------------------------------

# Rule 1.5.9, English: the arm a printed record selects among `n_arms` arms.
# `record` is a weft_text of length one.
choose_arm_n <- function(record, n_arms) {
  num <- attr(record, "number")[1]
  exact <- identical(attr(record, "relation")[1], "=") &&
    !isTRUE(attr(record, "decimals")[1]) && !is.na(num)
  zero <- exact && num == 0
  one <- exact && num == 1
  two <- exact && num == 2
  switch(
    as.character(n_arms),
    "1" = 1L,
    "2" = if (one) 1L else 2L,
    "3" = if (zero) 1L else if (one) 2L else 3L,
    "4" = if (zero) 1L else if (one) 2L else if (two) 3L else 4L,
    construct_error(sprintf(
      "An `n` span takes 1 to 4 arms in English (rule 1.5.2); this has %d.", n_arms))
  )
}

# An arm with its escapes resolved (1.5.12), `#` replaced by `hash`.
resolve_arm <- function(arm, hash) {
  s <- trimws(arm)
  s <- gsub("\\\\([|#])", "\\1", s)            # the backslash goes first
  # then a run of `#`: pairs are literal, an odd one is the placeholder
  m <- gregexpr("#+", s)[[1]]
  if (m[1] != -1L) {
    runs <- regmatches(s, list(m))[[1]]
    rep <- vapply(nchar(runs), function(len) {
      paste0(strrep("#", len %/% 2L), if (len %% 2L == 1L) "\001" else "")
    }, "")
    regmatches(s, list(m)) <- list(rep)
  }
  s <- gsub("\001", hash, s, fixed = TRUE)
  gsub("||", "|", s, fixed = TRUE)
}

#' Choose a plural form
#'
#' The R form of an `n` span (rule 3.2.1): `plural(n, "a person", "# people")`.
#' Arms are separate arguments, in the order a span writes them (rule 3.2.2):
#' one arm is a template for `#`; two are one and other; three are zero, one
#' and other; four are zero, one, two and other. `#` stands for the governor
#' as printed by the default governor class. `||` and `##` are a literal
#' `|` and `#`; a backslash before either is removed.
#'
#' @param n A single number, or a `weft_text` from a formatter (selection then
#'   uses its printed record). A vector or a string is an error of class
#'   `weft_value_error` that says to write `length(x)`; a missing value is an
#'   error of class `weft_no_value`.
#' @param ... One to four arms, as strings.
#' @return A character vector of length one.
#' @examples
#' plural(1, "a person", "# people")
#' plural(3, "a person", "# people")
#' plural(0, "never", "once", "twice", "# times")
#' @export
plural <- function(n, ...) {
  arms <- as.character(unlist(list(...)))
  k <- length(arms)
  if (k < 1L || k > 4L) {
    construct_error(sprintf(
      "plural() takes one to four arms in English (rule 1.6.2); this has %d.", k))
  }
  cfg <- current_config()
  if (inherits(n, "weft_text")) {
    if (length(n) != 1L) {
      value_error("plural() needs a single number; write `length(x)` to count a vector.")
    }
    if (anyNA(attr(n, "number"))) {
      value_error(paste0("plural() needs a number, and this value has none; ",
                         "write `length(x)` to count items."))
    }
    rec <- n
  } else {
    if (length(n) == 0L) no_value_error("plural()")
    if (length(n) > 1L) {
      value_error("plural() needs a single number, not a vector; write `length(x)` to count one.")
    }
    if (!is.list(n) && (is.na(n) || (is.numeric(n) && !is.finite(n)))) {
      no_value_error("plural()")
    }
    if (!is.numeric(n)) {
      value_error(paste0("plural() needs a single number, not a ", class(n)[1],
                         "; write `length(x)` to count items."))
    }
    rec <- apply_formatters(n, character(), list(), cfg, governor = TRUE)
  }
  i <- choose_arm_n(rec, k)
  resolve_arm(arms[i], as.character(rec)[1])
}
