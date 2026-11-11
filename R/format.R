# Formatting (rules 1.4, 1.5.8-1.5.9, 3.2, 3.4): the printed record, the four
# fixed stages, the fmt_*() functions, glue_vec() and plural().

# ---- the class registry -------------------------------------------------

# Stage i, ii (main), iii; the text stage has no at-most-one rule. The unit
# classes (.uname, .usym, .nounit) are one at-most-one group and no stage.
NUMBER_CLASSES <- c(".num", ".pct", ".sci", ".p", ".date")
WORDING_CLASSES <- c(".word", ".count", ".ord")
COLLAPSE_CLASSES <- c(".and", ".or", ".pairs", ".range", ".ul", ".ol", ".dl")
TEXT_CLASSES <- c(".a", ".cap", ".strong", ".em")
RENDERER_KEYS <- c("digits", "sigfig", "unit", "sep", "last", "trunc", "none")
LIST_CLASSES <- c(".ul", ".ol", ".dl")

shipped_classes <- function() {
  c(NUMBER_CLASSES, ".no", WORDING_CLASSES, COLLAPSE_CLASSES, UNIT_CLASSES, TEXT_CLASSES,
    ".weft-literal")
}

# The at-most-one group of a class, `NA` when it has none. `reg` is the
# configuration's `formatters` (1.4.8).
class_group <- function(cls, reg = list()) {
  out <- rep(NA_character_, length(cls))
  out[cls %in% NUMBER_CLASSES] <- "number"
  out[cls %in% WORDING_CLASSES] <- "wording"
  out[cls %in% COLLAPSE_CLASSES] <- "collapse"
  out[cls %in% UNIT_CLASSES] <- "unit"
  for (nm in intersect(cls, names(reg))) {
    st <- reg[[nm]][["stage"]] %||% "number"
    if (st != "text") out[cls == nm] <- st
  }
  out
}

# Every formatter class: those that make a construct a formatted one.
formatter_classes <- function(reg = list()) {
  c(NUMBER_CLASSES, ".no", WORDING_CLASSES, COLLAPSE_CLASSES, UNIT_CLASSES, names(reg))
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
  if (num >= (cfg$thousands_from %||% 1000)) int <- group_int(int, cfg$big_mark)
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

# `bound` marks the elements that are a clamp() bound: under default digits
# one that would print as zero prints as written (stage 1i). The result
# carries `zero` when a number that is not zero printed as zero under default
# digits: the elements, the first value and what printed.
format_numbers <- function(value, class, keys, cfg, bound = NULL, range = FALSE) {
  digits <- key_number(keys, "digits")
  sigfig <- key_number(keys, "sigfig")
  if (!is.null(sigfig) && sigfig < 1) {
    construct_error("`sigfig` must be at least 1.")
  }
  # a year prints with no thousands mark (4.2.1)
  if (inherits(value, "weft_year")) cfg$thousands_from <- Inf
  value <- as.numeric(value)
  if (is.null(bound)) bound <- rep(FALSE, length(value))
  default <- is.null(digits) && is.null(sigfig) && class %in% c(".num", ".pct")
  # `.range` prints both ends to the default decimals; that is not a `digits` given
  if (range && default && !all(is_whole(value[is.finite(value)]))) digits <- cfg$digits
  hit <- rep(FALSE, length(value))
  shown <- rep("", length(value))
  one <- function(i) {
    v <- value[i]
    if (class == ".sci") return(sci_one(v, digits, sigfig, cfg))
    sv <- if (class == ".pct" && isTRUE(cfg$pct_proportion)) v * 100 else v
    p <- print_one(sv, digits, sigfig, cfg)
    if (default && p$number == 0 && sv != 0 && !is_whole(sv)) {
      if (bound[i]) {
        nd <- 0L
        while (nd < 15L && abs(sv - round(sv, nd)) > 1e-12 * max(1, abs(sv))) nd <- nd + 1L
        p <- print_one(sv, nd, NULL, cfg)
      } else {
        hit[i] <<- TRUE
        shown[i] <<- trimws(format(signif(sv, 12), scientific = FALSE, drop0trailing = TRUE))
      }
    }
    if (class == ".pct") p$text <- paste0(p$text, "%")
    p
  }
  res <- lapply(seq_along(value), one)
  out <- new_weft_text(
    vapply(res, `[[`, "", "text"),
    number = vapply(res, `[[`, 0, "number"),
    decimals = vapply(res, `[[`, NA, "decimals"),
    raw = value
  )
  if (any(hit)) {
    first <- which(hit)[1L]
    attr(out, "zero") <- list(idx = which(hit), value = shown[first],
                              printed = as.character(out)[first])
  }
  out
}

# What a number that printed as zero says (stage 1i).
zero_message <- function(z) {
  n <- length(z$idx)
  sprintf("%s printed as %s%s: add sigfig to show it, or digits to confirm it",
          paste0(z$value, if (endsWith(z$printed, "%")) "%" else ""), z$printed,
          if (n > 1L) sprintf(" (%d values printed as zero)", n) else "")
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

# ---- stage helpers (1b, 1d) ---------------------------------------------

EN_MONTHS <- c("January", "February", "March", "April", "May", "June", "July",
               "August", "September", "October", "November", "December")

# One date or date-time printed by the `date_format` setting. `%-d` and `%-m`
# (no leading zero) and the month names are expanded here, so the result does
# not depend on the platform's strftime or on the locale (English words,
# rule 1.6.8).
format_dates <- function(x, fmt) {
  lt <- if (inherits(x, "POSIXt")) as.POSIXlt(x) else as.POSIXlt(x, tz = "UTC")
  vapply(seq_along(lt$mday), function(i) {
    f <- fmt
    f <- gsub("%-d", as.character(lt$mday[i]), f, fixed = TRUE)
    f <- gsub("%-m", as.character(lt$mon[i] + 1L), f, fixed = TRUE)
    f <- gsub("%B", EN_MONTHS[lt$mon[i] + 1L], f, fixed = TRUE)
    f <- gsub("%b", substr(EN_MONTHS[lt$mon[i] + 1L], 1L, 3L), f, fixed = TRUE)
    format(lt[i], f)
  }, "")
}

# A p-value (1.4.3, dev/design-1f.md): "p < 0.001" below 0.001, three
# decimals when the value rounded to three decimals is below 0.1, two from
# there, "p > 0.99" above 0.99.
print_p <- function(p, cfg) {
  dm <- cfg$decimal_mark
  mk <- function(str, rel, num) {
    list(text = paste0("p ", rel, " ", sub(".", dm, str, fixed = TRUE)),
         number = num, decimals = TRUE, relation = rel)
  }
  if (p < 0.001) return(mk("0.001", "<", 0.001))
  if (p > 0.99) return(mk("0.99", ">", 0.99))
  s3 <- round_half_away(p, 3L)
  if (s3 < 0.1) {
    s <- sprintf("%.3f", s3)
    return(mk(s, "=", as.numeric(s)))
  }
  s <- sprintf("%.2f", round_half_away(p, 2L))
  mk(s, "=", as.numeric(s))
}

format_p <- function(value, cfg) {
  if (any(value < 0 | value > 1)) {
    value_error(sprintf("`.p` needs a value from 0 to 1; got %s.",
                        format(value[value < 0 | value > 1][1L])))
  }
  res <- lapply(as.numeric(value), print_p, cfg = cfg)
  new_weft_text(
    vapply(res, `[[`, "", "text"),
    number = vapply(res, `[[`, 0, "number"),
    decimals = rep(TRUE, length(res)),
    relation = vapply(res, `[[`, "", "relation"),
    raw = as.numeric(value))
}

# The sound a printed number or number word opens with: TRUE when it opens
# with a vowel sound (an eight, an 11, an 80, an eighteen thousand). Text that
# is neither is a value error (1.4.5, 5.3.2).
NUMBER_WORDS <- c("zero", "one", "two", "three", "four", "five", "six", "seven",
                  "eight", "nine", "ten", "eleven", "twelve", "thirteen",
                  "fourteen", "fifteen", "sixteen", "seventeen", "eighteen",
                  "nineteen", "twenty", "thirty", "forty", "fifty", "sixty",
                  "seventy", "eighty", "ninety", "hundred", "thousand", "million",
                  "billion")
vowel_sound <- function(text, minus = "\u2212") {
  orig <- text
  # emphasis marks and a minus sign do not count: "a \u22128", "an **8**"
  text <- sub("^[*_~]*", "", text)
  for (mk in c(minus, "-")) {
    if (nzchar(mk) && startsWith(text, mk) && grepl("^[0-9]", substring(text, nchar(mk) + 1L))) {
      return(FALSE)
    }
  }
  m <- regmatches(text, regexpr("^[0-9][0-9,]*", text))
  if (length(m)) {
    d <- gsub(",", "", m, fixed = TRUE)
    L <- nchar(d)
    k <- if (L %% 3L == 0L) 3L else L %% 3L
    g <- as.integer(substr(d, 1L, k))
    return(switch(as.character(k),
                  "1" = g == 8L,
                  "2" = g %in% c(11L, 18L, 80:89),
                  "3" = g >= 800L && g <= 899L))
  }
  w <- regmatches(text, regexpr("^[A-Za-z]+", text))
  if (length(w) && tolower(w) %in% NUMBER_WORDS) {
    return(tolower(w) %in% c("eight", "eleven", "eighteen", "eighty"))
  }
  value_error(sprintf(
    "`.a` applies to numbers and number words only; \"%s\" is neither (rule 1.4.5).",
    orig))
}

add_article <- function(text, minus = "\u2212") {
  vapply(text, function(t) {
    if (!nzchar(t)) return(t)
    paste0(if (vowel_sound(t, minus)) "an " else "a ", t)
  }, "", USE.NAMES = FALSE)
}

capitalise <- function(text) {
  vapply(text, function(t) {
    if (!nzchar(t)) return(t)
    lead <- attr(regexpr("^[^[:alnum:]]*", t), "match.length")
    if (lead >= nchar(t)) return(t)
    paste0(substr(t, 1L, lead), toupper(substr(t, lead + 1L, lead + 1L)),
           substr(t, lead + 2L, nchar(t)))
  }, "", USE.NAMES = FALSE)
}

# The collapse of `.range` (1.4.4): one number when both ends print the
# same, " to " when either end is negative, an en dash otherwise.
collapse_range <- function(text, number, cfg, raw = NULL) {
  if (length(text) != 2L) {
    value_error(sprintf(
      "`.range` needs a value of length 2; this has %d (rule 5.3.2).", length(text)))
  }
  ord <- if (is.numeric(raw) && length(raw) == 2L && !anyNA(raw)) raw else number
  if (!anyNA(ord) && ord[1L] > ord[2L]) {
    value_error(sprintf("`.range` needs its first end not above its second; got %s and %s.",
                        text[1L], text[2L]))
  }
  if (identical(text[1L], text[2L])) return(text[1L])
  neg <- any(number < 0, na.rm = TRUE) || any(startsWith(text, cfg$minus))
  paste0(text[1L], if (neg) " to " else "\u2013", text[2L])
}

# `.and`, `.or` and `.pairs` with `trunc` (1.4.7): the first `k` items, then
# "and N others".
collapse_items <- function(text, sep, last, trunc, serial = FALSE) {
  n <- length(text)
  if (!is.null(trunc) && n > trunc) {
    rest <- n - trunc
    # the tail counts as an item, so the serial comma needs trunc + 1 >= 3
    return(paste0(paste(text[seq_len(trunc)], collapse = sep),
                  if (serial && trunc >= 2L) serial_mark(sep) else "",
                  " and ", rest, if (rest == 1L) " other" else " others"))
  }
  if (serial && n >= 3L) last <- add_serial_comma(last, serial_mark(sep))
  as.character(glue_vec(text, sep = sep, last = last))
}

# " and " becomes ", and ": a comma before the joiner, unless it has one.
add_serial_comma <- function(last, mark = ",") {
  if (grepl("^[ ]*,", last)) last else paste0(mark, last)
}

# The mark before the last joiner: the separator without its trailing spaces
# (", " gives ","; "; " gives ";").
serial_mark <- function(sep) sub("[ \t]+$", "", sep)

# The list formatters (1.4.3): a block with a blank line before and after.
collapse_list <- function(cls, text, nms) {
  body <- switch(
    cls,
    ".ul" = paste0("- ", text, collapse = "\n"),
    ".ol" = paste0(seq_along(text), ". ", text, collapse = "\n"),
    ".dl" = paste0(nms, "\n:   ", text, collapse = "\n\n"))
  paste0("\n", body, "\n")
}

# ---- the four stages ----------------------------------------------------

# Format `value` by the classes and renderer keys of a construct (1.4.1).
# `keys` is a named list or character vector of renderer keys. The knitr
# resolver of a later package calls this too. Returns a weft_text. With
# `governor = TRUE` only stages i and ii run, and a construct with no
# formatter class, `digits` or `sigfig` uses `config$governor_class`
# (1.5.7, 1.5.18). `join` joins a vector that no collapse class joined.
apply_formatters <- function(value, classes = character(), keys = list(),
                             config = current_config(), governor = FALSE,
                             join = NULL, on_zero = note_zero, unit_form = NULL) {
  cfg <- config
  reg <- cfg$formatters %||% list()
  classes <- unique(as.character(classes))
  keys <- as.list(keys)
  names(keys) <- tolower(names(keys))
  keys <- keys[!vapply(keys, is.null, NA)]
  if (inherits(value, "POSIXlt")) value <- as.POSIXct(value)
  check_one_unit(value)
  proj <- function(stage) {
    nm <- intersect(classes, names(reg))
    nm[vapply(nm, function(k) identical(reg[[k]][["stage"]] %||% "number", stage), NA)]
  }
  # `unit` converts a quantity before anything else (4.4.14)
  if (!is.null(keys$unit)) value <- convert_unit(value, keys$unit)
  # the form a unit is asked to print in at the use: a unit class, or the
  # `unit_form` of a function (4.4.15)
  explicit <- unit_class_form(classes)
  if (is.na(explicit)) explicit <- unit_form
  # a quantity (2b, 2f): the number is formatted as a number is, the unit follows
  # in its symbol or its name. A governor carries its unit too, so `#` prints it
  # (4.4.4); its record does not. `un` is the unit, `tforms` the forms a text of a
  # quantity printed it in.
  un <- NULL
  tforms <- NULL
  carried <- NULL
  text_q <- FALSE
  ratio <- FALSE
  if (inherits(value, "units")) {
    if (unit_present(attr(value, "units"))) un <- attr(value, "units") else ratio <- TRUE
    value <- bare_number(value)
  } else if (inherits(value, "weft_text") && !is.null(attr(value, "units"))) {
    un <- attr(value, "units")
    tforms <- attr(value, "unit_form")
    carried <- nzchar(attr(value, "unit_suffix") %||% character())
    text_q <- TRUE
    value <- strip_unit(value)
  } else if (inherits(value, "weft_text")) {
    value <- strip_unit(value)
  }
  if (!is.null(explicit) && !identical(explicit, "auto") && is.null(un)) {
    what <- if (is.null(unit_form)) intersect(classes, UNIT_CLASSES)[1L] else "`unit_form`"
    value_error(sprintf("%s needs a quantity with a unit, and %s (rule 1.4.19).", what,
                        if (ratio) "this value has no unit left (a ratio)"
                        else sprintf("this value is not a quantity (class %s)", class(value)[1L])))
  }
  nms <- names(value)

  if (!is.null(keys$none)) {
    nn <- keys$none
    if (!is.character(nn) || length(nn) != 1L || is.na(nn) || !nzchar(trimws(nn))) {
      construct_error("`none` must be one string that is not empty or only spaces (rule 1.4.14).")
    }
    if (".range" %in% classes) {
      construct_error("`none` does not apply to `.range`: a range has two ends (rule 1.4.14).")
    }
  }

  # the result of of_n(), about(), ci() or pm() is finished wording: a number
  # or wording class on it is a value error (1.4.1, 1.4.12)
  if (isTRUE(attr(value, "phrase"))) {
    bad_cls <- c(intersect(classes, c(NUMBER_CLASSES, ".no", WORDING_CLASSES)),
                 intersect(classes, names(reg))[vapply(intersect(classes, names(reg)), function(k) {
                   !identical(reg[[k]][["stage"]] %||% "number", "text")
                 }, NA)])
    if (length(bad_cls) || !is.null(keys$digits) || !is.null(keys$sigfig) || !is.null(keys$unit)) {
      value_error(sprintf(
        "`%s` cannot format \"%s\": it is finished wording, not a number (rules 1.4.1, 1.4.12).",
        c(bad_cls, "digits")[1L], as.character(value)[1L]))
    }
  }

  if (governor) {
    has_fmt <- any(!is.na(class_group(classes, reg))) || ".no" %in% classes ||
      !is.null(keys$digits) || !is.null(keys$sigfig) || !is.null(keys$unit)
    if (!has_fmt) classes <- c(classes, cfg$governor_class)
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
  if (length(intersect(classes, c(".p", ".date"))) &&
      (!is.null(keys$digits) || !is.null(keys$sigfig))) {
    construct_error(sprintf("`digits` and `sigfig` do not apply to `%s`.",
                            intersect(classes, c(".p", ".date"))[1L]))
  }
  unit_cls <- intersect(classes, c(".pct", ".sci"))
  wording_cls <- c(intersect(classes, WORDING_CLASSES), proj("wording"))
  # a class that prints a number as a word: the unit's name follows it (4.4.2)
  spell_cls <- c(intersect(classes, c(".word", ".count", ".no")), proj("wording"))
  if (identical(unit_class_form(classes), "symbol") && length(spell_cls)) {
    construct_error(sprintf(paste0("`.usym` with `%s` is an error: a spelled number takes the unit's name, ",
                                   "and \"five m\" is not written (rule 1.4.19)."), spell_cls[1L]))
  }
  if (length(unit_cls) && length(wording_cls)) {
    construct_error(sprintf(
      "`%s` with `%s` in one construct is an error: the wording class would drop what `%s` prints (rule 1.4.1).",
      unit_cls[1], wording_cls[1], unit_cls[1]))
  }
  trunc <- NULL
  if (!is.null(keys$trunc)) {
    trunc <- key_number(keys, "trunc")
    if (trunc < 1) construct_error("`trunc` must be at least 1 (rule 1.4.7).")
  }

  # stage iv: text (an empty string stays empty, 1.2.6)
  text_stage <- function(text) {
    wrap <- function(text, mark) {
      nz <- nzchar(text)
      text[nz] <- paste0(mark, text[nz], mark)
      text
    }
    if (".a" %in% classes) text <- add_article(text, cfg$minus)
    if (".cap" %in% classes) text <- capitalise(text)
    if (".em" %in% classes) text <- wrap(text, "*")
    if (".strong" %in% classes) text <- wrap(text, "**")
    for (nm in proj("text")) {
      text <- as.character(apply_project(reg[[nm]], text, NULL))
    }
    text
  }

  # a zero-length atomic value under a collapse class prints `none` (stage 1h)
  if (!governor && !is.null(keys$none) && !is.null(value) && is.atomic(value) &&
      length(value) == 0L && !inherits(value, "weft_text") &&
      (length(intersect(classes, COLLAPSE_CLASSES)) || length(proj("collapse")))) {
    return(new_weft_text(text_stage(as.character(keys$none))))
  }

  what <- "A formatter"
  if (!inherits(value, "weft_text")) check_present(value, what)
  if (is.factor(value)) value <- as.character(value)

  # stage i: number. `digits`, `sigfig`, `unit` and a unit class imply `.num` (1.4.7).
  ncls <- c(intersect(classes, NUMBER_CLASSES), proj("number"))
  if (!length(ncls) && (!is.null(keys$digits) || !is.null(keys$sigfig) || !is.null(keys$unit) ||
                        !is.na(unit_class_form(classes)))) {
    ncls <- ".num"
  }

  # the form each unit prints in, judged on the classes and never on the data
  # (4.4.15, 4.4.19): a name may print where a class spells a number, or the
  # form is `name`, so the unit must have one; a symbol cannot follow a spelled
  # number
  lang <- current_lang()
  base_form <- cfg$unit_form %||% "auto"
  form_in_force <- if (is.null(explicit)) base_form else explicit
  keep_forms <- text_q && is.null(explicit) && !length(ncls) && !length(wording_cls) && !length(spell_cls)
  if (!is.null(un)) {
    if (keep_forms) {
      if (any(tforms == "name", na.rm = TRUE) && !lang_is_english(lang)) {
        construct_error(sprintf("A unit's name is English words, and the document's `lang` is `%s` (rule 1.6.8).", lang))
      }
    } else {
      if (form_in_force == "symbol" && length(spell_cls)) {
        value_error(sprintf(paste0(
          "`%s` cannot print a quantity under `unit_form: symbol` (set in %s): a spelled number takes the ",
          "unit's name, and \"three m\" is not written. Use `.uname` to print the name, `.nounit` to print ",
          "the number alone, or drop `%s` (rule 4.4.15)."),
          spell_cls[1L], cfg$unit_form_set %||% "the configuration", spell_cls[1L]))
      }
      if (form_in_force == "name" && !lang_is_english(lang)) {
        construct_error(sprintf(paste0("The unit's name is English words, and the document's `lang` is `%s`; ",
                                       "`unit_form = \"name\"` is not available (rule 1.6.8)."), lang))
      }
      if (form_in_force == "name" || (form_in_force == "auto" && length(spell_cls))) {
        invisible(unit_name_text(un, TRUE, cfg, lang))
      }
    }
  }
  rec <- NULL
  clamp_rel <- NULL
  zero <- NULL
  is_year <- inherits(value, "weft_year")
  if (length(ncls)) {
    cls <- ncls[1]
    if (!is.null(un) && cls %in% c(".pct", ".p", ".date")) {
      value_error(sprintf(paste0("`%s` cannot format a quantity in %s: give it a number ",
                                 "with no unit (rule 4.4.8)."), cls, as.character(un)))
    }
    if (cls == ".date") {
      if (!inherits(value, c("Date", "POSIXt"))) {
        value_error(sprintf("`.date` needs a Date or a date-time; the value is of class %s.",
                            class(value)[1]))
      }
      txt <- format_dates(value, cfg$date_format)
      rec <- new_weft_text(txt)
    } else {
      from_text <- inherits(value, "weft_text")
      was_warned <- from_text && isTRUE(attr(value, "warned"))
      if (from_text) {
        # a number formatter formats the raw value afresh (1.7.8)
        clamp_rel <- if (isTRUE(attr(value, "clamped"))) attr(value, "relation")
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
      } else if (cls == ".p") {
        rec <- format_p(value, cfg)
      } else {
        bound <- if (!is.null(clamp_rel) && length(clamp_rel) == length(value)) clamp_rel != "="
        rec <- format_numbers(value, cls, keys, cfg, bound)
        # a value a formatter already warned about is not warned about twice
        zero <- attr(rec, "zero")
        if (was_warned && is.null(clamp_rel)) zero <- NULL
        attr(rec, "zero") <- NULL
      }
      # clamp() keeps its relation: "< 1%" (3.5.4)
      if (!is.null(clamp_rel) && length(clamp_rel) == length(rec)) {
        mark <- clamp_rel != "="
        rec[mark] <- paste(clamp_rel[mark], as.character(rec)[mark])
        attr(rec, "relation") <- clamp_rel
      }
    }
  } else if (inherits(value, "weft_text")) {
    rec <- value
  } else if (is.numeric(value)) {
    # `.range` prints both ends to the same number of decimals (1.4.4)
    rec <- format_numbers(value, ".num", keys, cfg, range = ".range" %in% classes)
    zero <- attr(rec, "zero")
    attr(rec, "zero") <- NULL
  } else {
    rec <- new_weft_text(as.character(value))
  }
  text <- as.character(rec)
  number <- attr(rec, "number")
  decimals <- attr(rec, "decimals")
  relation <- attr(rec, "relation")
  raw <- attr(rec, "raw") %||% rep(NA_real_, length(text))
  n_el <- length(text)
  # the elements that carry the unit: all of them, or those of a text that did
  carry <- if (is.null(un)) rep(FALSE, n_el) else if (length(ncls) || is.null(carried) ||
                                                      length(carried) != n_el) {
    rep(TRUE, n_el)
  } else carried
  spelled <- rep(FALSE, n_el)
  placed <- FALSE

  # stage ii: wording
  is_no <- rep(FALSE, length(text))
  if (".no" %in% classes) {
    is_no <- !is.na(number) & number == 0 & !decimals & relation == "="
    if (!governor) is_no[zero$idx] <- TRUE   # a printed zero, "0.0" too (stage 1i)
    text[is_no] <- "no"
    spelled <- is_no
  }
  if (length(wording_cls)) {
    w <- wording_cls[1]
    if (w %in% names(reg)) {
      before <- text
      text <- as.character(apply_project(reg[[w]], new_weft_text(text, number, decimals, relation), NULL))
      if (length(text) == length(before)) spelled <- spelled | text != before
    } else {
      chk <- !is_no
      bad <- chk & (is.na(number) | relation != "=" | decimals %in% TRUE |
                      (!is.na(number) & (number < 0 | number != round(number))))
      if (any(bad)) {
        value_error(sprintf(
          "`%s` needs a whole number that is not negative, judged as printed (rule 1.4.12); got %s.",
          w, paste0("\"", text[bad][1], "\"")))
      }
      before <- text
      for (k in which(chk)) {
        nk <- number[k]
        intk <- group_int(sprintf("%.0f", nk), cfg$big_mark)
        text[k] <- switch(
          w,
          ".word" = if (nk >= cfg$word_limit) text[k] else spell_or(nk, text[k]),
          ".count" = if (nk >= cfg$count_threshold) text[k] else spell_or(nk, text[k]),
          ".ord" = paste0(if (!is_year && nk >= (cfg$thousands_from %||% 1000)) intk else sprintf("%.0f", nk),
                          ordinal_suffix(nk))
        )
      }
      # a spelled number takes the unit's name; digits and .ord keep the form in force
      if (w != ".ord") spelled <- spelled | text != before
    }
  }

  # the form of each element's unit (4.4.15) and the text that follows it
  forms <- rep(NA_character_, n_el)
  if (!is.null(un)) {
    forms <- vapply(seq_len(n_el), function(i) {
      if (!carry[i]) return(NA_character_)
      if (keep_forms && length(tforms) == n_el) return(tforms[i])
      switch(form_in_force, none = NA_character_, name = "name", symbol = "symbol",
             if (spelled[i]) "name" else "symbol")
    }, "")
  }
  is_one <- if (length(number) == n_el) {
    !is.na(number) & number == 1 & !decimals %in% TRUE & relation == "="
  } else rep(FALSE, n_el)
  memo <- new.env(parent = emptyenv())
  # what follows a number: the no-break space and the unit, in `form`, for a
  # plural number or not
  suffix_of <- function(form, plural) {
    if (is.na(form)) return("")
    key <- paste(form, plural)
    if (!is.null(memo[[key]])) return(memo[[key]])
    out <- if (form == "name") {
      paste0(UNIT_SEP, unit_name_text(un, plural, cfg, lang))
    } else {
      paste0(if (unit_space(un, cfg)) UNIT_SEP else "", unit_symbol_text(un, plural, cfg, lang))
    }
    memo[[key]] <- out
    out
  }
  elem_suffix <- vapply(seq_len(n_el), function(i) suffix_of(forms[i], !is_one[i]), "")
  add_unit <- function(txt) {
    if (length(txt) == length(elem_suffix)) paste0(txt, elem_suffix) else txt
  }
  out_forms <- forms
  out_suffix <- elem_suffix

  collapsed <- FALSE
  if (governor) {
    # a governor is never collapsed, except that `.range` makes one printed
    # range of its two ends (1.5.11): the span takes the plural unless both
    # ends print "1"
    if (".range" %in% classes) {
      lf <- forms[n_el]
      one_printed <- n_el == 2L && identical(text[1L], text[2L]) && is_one[1L]
      text <- collapse_range(text, number, cfg, raw)
      out_suffix <- suffix_of(lf, !one_printed)
      out_forms <- lf
      text <- paste0(text, out_suffix)
      placed <- !is.na(lf)
      number <- if (one_printed) 1 else NA_real_
      decimals <- FALSE
      relation <- "="
      raw <- NA_real_
    } else if (!is.null(un)) {
      placed <- any(!is.na(forms))
      text <- add_unit(text)
    }
  } else {
    # stage iii: collapse
    ccls <- c(intersect(classes, COLLAPSE_CLASSES), proj("collapse"))
    if (!length(ccls) && !is.null(trunc)) ccls <- ".and"
    if (length(ccls)) {
      cl <- ccls[1]
      if (cl %in% names(reg)) {
        placed <- any(!is.na(forms))
        text <- as.character(apply_project(reg[[cl]], add_unit(text), NULL))
        text <- text[1]
        out_forms <- forms[n_el]
        out_suffix <- elem_suffix[n_el]
      } else if (cl == ".range") {
        lf <- forms[n_el]
        one_printed <- n_el == 2L && identical(text[1L], text[2L]) && is_one[1L]
        text <- collapse_range(text, number, cfg, raw)
        out_suffix <- suffix_of(lf, !one_printed)
        out_forms <- lf
        text <- paste0(text, out_suffix)
        placed <- !is.na(lf)
      } else if (cl %in% c(".pairs", ".dl")) {
        placed <- any(!is.na(forms))
        text <- add_unit(text)
        out_forms <- forms[n_el]
        out_suffix <- elem_suffix[n_el]
        if (is.null(nms) || anyNA(nms) || any(!nzchar(nms))) {
          value_error(sprintf("`%s` needs a named vector; this one has no names.", cl))
        }
        if (cl == ".pairs") {
          sep <- keys$sep %||% ", "
          text <- collapse_items(paste0(nms, " (", text, ")"), sep, keys$last %||% " and ", trunc,
                                 serial = isTRUE(cfg$serial_comma) && is.null(keys$last))
        } else {
          text <- collapse_list(cl, text, nms)
        }
      } else if (cl %in% LIST_CLASSES) {
        placed <- any(!is.na(forms))
        text <- add_unit(text)
        out_forms <- forms[n_el]
        out_suffix <- elem_suffix[n_el]
        text <- collapse_list(cl, text, nms)
      } else {
        sep <- keys$sep %||% ", "
        last <- keys$last %||% (if (cl == ".or") " or " else " and ")
        # the unit once, after the last number printed, in that item's form; the
        # name is singular only when exactly one number prints and it is 1 (4.4.15)
        at <- if (!is.null(trunc) && length(text) > trunc) trunc else length(text)
        out_forms <- if (at >= 1L) forms[at] else NA_character_
        out_suffix <- ""
        if (!is.null(un) && at >= 1L && !is.na(forms[at])) {
          out_suffix <- suffix_of(forms[at], !(at == 1L && is_one[1L]))
          text[at] <- paste0(text[at], out_suffix)
          placed <- TRUE
        }
        text <- collapse_items(text, sep, last, trunc,
                               serial = isTRUE(cfg$serial_comma) && is.null(keys$last))
      }
      collapsed <- TRUE
      number <- NA_real_
      decimals <- FALSE
      relation <- "="
      raw <- NA_real_
    }

    # a vector no collapse class joined: an inline value prints as stock
    # prints an inline vector, joined by `join` (1.4.10 as ruled)
    if (!length(ccls) && !is.null(un)) {
      placed <- any(!is.na(forms))
      text <- add_unit(text)
    }
    if (!length(ccls) && !is.null(join) && length(text) > 1L) {
      text <- paste(text, collapse = join)
      collapsed <- TRUE
      number <- NA_real_
      decimals <- FALSE
      relation <- "="
      raw <- NA_real_
      out_forms <- out_forms[length(out_forms)]
      out_suffix <- out_suffix[length(out_suffix)]
    }

    text <- text_stage(text)
  }

  if (!governor && !is.null(zero)) on_zero(zero_message(zero))

  out <- new_weft_text(text, number, decimals, relation, raw)
  if (!is.null(un)) {
    # the unit's attributes (3.4.4): none when no element carries it
    attr(out, "unit_form") <- out_forms
    if (placed) {
      attr(out, "unit") <- unit_symbol_text(un, TRUE, cfg, lang)
      attr(out, "units") <- un
      attr(out, "unit_suffix") <- out_suffix
    }
  }
  if (!governor && !is.null(zero)) attr(out, "warned") <- TRUE
  if (!collapsed && !is.null(nms) && length(nms) == length(text)) names(out) <- nms
  out
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
#' @param unit The unit to print a quantity in, as a string: `fmt_num(u(150,
#'   "cm"), unit = "m")` is "1.5 m". The quantity is converted first, so the
#'   number, the unit and the arm an `n` span chooses are all in that unit. A
#'   unit the quantity cannot be converted to, and `unit` on a value that is
#'   not a quantity, are a `weft_value_error`. Like `digits`, it implies
#'   `.num`.
#' @param unit_form How a quantity's unit prints (rule 3.4.8): `NULL` (the
#'   setting `unit_form` in force: `"auto"` unless `_weft.yml` or the document
#'   says otherwise, and for a `weft_text` input given a collapse class alone,
#'   each element's own printed form), `"auto"` (the symbol after digits, the
#'   name after a spelled number), `"symbol"`, `"name"`, or `"none"` (the number
#'   alone). Anything else is a `weft_construct_error`, and so is `"symbol"` on
#'   `fmt_no()`, `fmt_word()` and `fmt_count()`, and `"name"` when the
#'   document's `lang` is not English. A form other than `"auto"` on a value
#'   with no unit is a `weft_value_error`. `fmt_pct()` and `fmt_p()` take none.
#' @param sep The text between items of a collapse.
#' @param last The text before the final item of a collapse. The default is
#'   " and " (" or " for `fmt_or()`), with a comma before it when the
#'   `serial_comma` setting is on and there are three or more items; a `last`
#'   given here is used as it is.
#'
#' @details
#' A missing value (`NA`, `NaN`, `Inf`, `-Inf` or a value of length zero)
#' stops with an error of class `weft_no_value`. A value a class cannot take
#' (a decimal given to `fmt_word()`, say) stops with class
#' `weft_value_error`.
#'
#' A number whose absolute value (for `fmt_pct()`, the percentage's) is below
#' 1e-9 is zero and prints "0". Any other number prints to the default
#' digits, however small: `fmt_num(0.04)` is "0.0" and `fmt_pct(0.0004)` is
#' "0.0%", never "-0.0". When neither `digits` nor `sigfig` is given (a
#' project default `digits` does not count) and `fmt_num()` or `fmt_pct()`
#' prints a number that is not zero with no digit other than 0, the loss is
#' not silent: a warned check of kind "printed as zero" is recorded as a
#' failed `claim(level = "warn")` is (see [claim()]), and outside a knit it is
#' a `warning()` of class `weft_zero_warning`. The value still prints. One
#' warning is recorded for each call, however many elements print as zero; its
#' message gives the first value, what printed and the count, and says to add
#' `sigfig` to show the number or `digits` to confirm the zero. A bound of
#' [clamp()] is never printed as zero: it prints as it was written.
#'
#' A `units` value (see [u()]) prints with its unit, after a no-break space.
#' The unit is its symbol or its name (rules 4.4.2, 4.4.15): the symbol after
#' digits ("5 m"), the name after a spelled number or "no" ("five metres"), and
#' `unit_form` can ask for either, or for none. The symbol text is Pandoc markdown:
#' an exponent is a superscript (`m^2^`, and `m` to the minus three as `m^-3^`
#' with a true minus sign), a product is a middle dot, a unit with no numerator is
#' written with negative powers, and characters markdown reads are escaped. A
#' name is singular only when its number prints "1" or "one". A wording class
#' that prints a word (`fmt_word()`, `fmt_count()`, `fmt_no()`) needs a name for
#' the unit, judged on the class and never on the data: a unit with none is a
#' `weft_value_error` (add it under `units:` in `_weft.yml`, or use
#' `unit_form = "none"`). `fmt_and()`, `fmt_or()`, `fmt_range()` and
#' [glue_vec()] print the unit once, after the last item, in that item's form;
#' `fmt_pairs()`, `fmt_ul()`, `fmt_ol()`, `fmt_dl()` and a vector no collapse
#' class joins print it with every element. `fmt_pct()`, `fmt_p()` and
#' `fmt_date()` on a quantity that still has a unit are a `weft_value_error`;
#' a ratio with no unit left is a plain number, and `unit_form` other than
#' `"auto"` on it is a `weft_value_error`. The result carries the attributes
#' `unit` (the symbol text, for a plural number), `unit_form` (`"symbol"`,
#' `"name"` or `NA` for each element) and `units` (the unit as the `units`
#' package gives it), so `fmt_and(fmt_num(u(c(3, 5), m)))` prints the unit once,
#' and a number or wording class given the text formats its `raw` value afresh in
#' the form then in force. The record's `number` and `raw` never hold the unit.
#' `#` in a span or [plural()] prints what the governor prints as a value, unit
#' included. See [fmt_unit()] for the unit alone.
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
fmt_num <- function(x, digits = NULL, sigfig = NULL, unit = NULL, unit_form = NULL) {
  check_unit_form(unit_form, "fmt_num")
  apply_formatters(x, ".num", list(digits = digits, sigfig = sigfig, unit = unit), unit_form = unit_form)
}

#' @rdname fmt
#' @export
fmt_pct <- function(x, digits = NULL, sigfig = NULL, unit = NULL) {
  apply_formatters(x, ".pct", list(digits = digits, sigfig = sigfig, unit = unit))
}

#' @rdname fmt
#' @export
fmt_sci <- function(x, digits = NULL, sigfig = NULL, unit = NULL, unit_form = NULL) {
  check_unit_form(unit_form, "fmt_sci")
  apply_formatters(x, ".sci", list(digits = digits, sigfig = sigfig, unit = unit), unit_form = unit_form)
}

#' @rdname fmt
#' @export
fmt_no <- function(x, unit_form = NULL) {
  check_unit_form(unit_form, "fmt_no", no_symbol = TRUE)
  apply_formatters(x, ".no", unit_form = unit_form)
}

#' @rdname fmt
#' @export
fmt_word <- function(x, unit_form = NULL) {
  check_unit_form(unit_form, "fmt_word", no_symbol = TRUE)
  apply_formatters(x, ".word", unit_form = unit_form)
}

#' @rdname fmt
#' @export
fmt_count <- function(x, unit_form = NULL) {
  check_unit_form(unit_form, "fmt_count", no_symbol = TRUE)
  apply_formatters(x, ".count", unit_form = unit_form)
}

#' @rdname fmt
#' @export
fmt_ord <- function(x, unit_form = NULL) {
  check_unit_form(unit_form, "fmt_ord")
  apply_formatters(x, ".ord", unit_form = unit_form)
}

#' @rdname fmt
#' @param trunc The number of items a collapse shows before "and N others".
#' @param none Text to print in place of a collapse when `x` is a vector of
#'   length zero (`fmt_and()`, `fmt_or()`, `fmt_pairs()`, `fmt_ul()`,
#'   `fmt_ol()`, `fmt_dl()`). The default, `NULL`, makes an empty vector a
#'   `weft_no_value` error. `NULL` itself is always an error.
#' @export
fmt_and <- function(x, sep = ", ", last = NULL, trunc = NULL, none = NULL, unit_form = NULL) {
  check_unit_form(unit_form, "fmt_and")
  apply_formatters(x, ".and", list(sep = sep, last = last, trunc = trunc, none = none), unit_form = unit_form)
}

#' @rdname fmt
#' @export
fmt_or <- function(x, sep = ", ", last = NULL, trunc = NULL, none = NULL, unit_form = NULL) {
  check_unit_form(unit_form, "fmt_or")
  apply_formatters(x, ".or", list(sep = sep, last = last, trunc = trunc, none = none), unit_form = unit_form)
}

#' @rdname fmt
#' @export
fmt_p <- function(x) apply_formatters(x, ".p")

#' @rdname fmt
#' @export
fmt_date <- function(x) apply_formatters(x, ".date")

#' @rdname fmt
#' @export
fmt_range <- function(x, digits = NULL, sigfig = NULL, unit = NULL, unit_form = NULL) {
  check_unit_form(unit_form, "fmt_range")
  apply_formatters(x, ".range", list(digits = digits, sigfig = sigfig, unit = unit), unit_form = unit_form)
}

#' @rdname fmt
#' @export
fmt_pairs <- function(x, sep = ", ", last = NULL, trunc = NULL, none = NULL, unit_form = NULL) {
  check_unit_form(unit_form, "fmt_pairs")
  apply_formatters(x, ".pairs", list(sep = sep, last = last, trunc = trunc, none = none), unit_form = unit_form)
}

#' @rdname fmt
#' @export
fmt_ul <- function(x, none = NULL, unit_form = NULL) {
  check_unit_form(unit_form, "fmt_ul")
  apply_formatters(x, ".ul", list(none = none), unit_form = unit_form)
}

#' @rdname fmt
#' @export
fmt_ol <- function(x, none = NULL, unit_form = NULL) {
  check_unit_form(unit_form, "fmt_ol")
  apply_formatters(x, ".ol", list(none = none), unit_form = unit_form)
}

#' @rdname fmt
#' @export
fmt_dl <- function(x, none = NULL, unit_form = NULL) {
  check_unit_form(unit_form, "fmt_dl")
  apply_formatters(x, ".dl", list(none = none), unit_form = unit_form)
}

#' @rdname fmt
#' @export
fmt_cap <- function(x) apply_formatters(x, ".cap")

#' @rdname fmt
#' @export
fmt_a <- function(x) apply_formatters(x, ".a")

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
  # a quantity: the unit once, after the last element, in its form (4.4.3); the
  # number prints as a plain number's does, with no rounding of its own
  check_one_unit(x)
  cfg <- current_config()
  lang <- current_lang()
  un <- NULL
  form <- NA_character_
  one <- FALSE
  if (inherits(x, "units")) {
    if (unit_present(attr(x, "units"))) {
      un <- attr(x, "units")
      form <- switch(cfg$unit_form %||% "auto", name = "name", "symbol")
    }
    one <- length(x) == 1L && isTRUE(as.numeric(x) == 1)
    x <- bare_number(x)
  } else if (inherits(x, "weft_text") && !is.null(attr(x, "units"))) {
    un <- attr(x, "units")
    uf <- attr(x, "unit_form")
    form <- if (length(x) > 0L && length(uf) == length(x)) uf[length(x)] else NA_character_
    if (!is.na(form) && length(attr(x, "unit_suffix")) != length(x)) form <- NA_character_
    n1 <- attr(x, "number")
    one <- length(x) == 1L && length(n1) == 1L && isTRUE(n1 == 1) && !isTRUE(attr(x, "decimals")[1L])
    x <- strip_unit(x)
  }
  x <- as.character(x)
  n <- length(x)
  if (n == 0L || anyNA(x)) no_value_error("A collapse")
  placed <- !is.null(un) && !is.na(form)
  suf <- ""
  if (placed) {
    suf <- if (form == "name") {
      paste0(UNIT_SEP, unit_name_text(un, !one, cfg, lang))
    } else {
      paste0(if (unit_space(un, cfg)) UNIT_SEP else "", unit_symbol_text(un, !one, cfg, lang))
    }
    x[n] <- paste0(x[n], suf)
  }
  out <- if (n == 1L) {
    x
  } else if (n == 2L) {
    paste0(x[1], last, x[2])
  } else {
    paste0(paste(x[-n], collapse = sep), last, x[n])
  }
  out <- new_weft_text(out)
  if (placed) {
    attr(out, "unit") <- unit_symbol_text(un, TRUE, cfg, lang)
    attr(out, "units") <- un
    attr(out, "unit_form") <- form
    attr(out, "unit_suffix") <- suf
  }
  out
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
    rec <- n   # `#` prints the text as it is, with its unit if it has one (4.4.4)
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
