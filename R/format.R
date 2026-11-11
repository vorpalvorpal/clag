# Formatting (rules 1.4, 1.5.8-1.5.9, 3.2, 3.4): the printed record, the four
# fixed stages, the fmt_*() functions, glue_vec() and plural().

# ---- the class registry -------------------------------------------------

# Stage i, ii (main), iii; the text stage has no at-most-one rule.
NUMBER_CLASSES <- c(".num", ".pct", ".sci", ".p", ".date")
WORDING_CLASSES <- c(".word", ".count", ".ord")
COLLAPSE_CLASSES <- c(".and", ".or", ".pairs", ".range", ".ul", ".ol", ".dl")
TEXT_CLASSES <- c(".a", ".cap", ".strong", ".em")
RENDERER_KEYS <- c("digits", "sigfig", "sep", "last", "trunc", "none")
LIST_CLASSES <- c(".ul", ".ol", ".dl")

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
  if (identical(attr(value, "weft_type"), "year")) cfg$thousands_from <- Inf
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
                             join = NULL, on_zero = note_zero) {
  cfg <- config
  reg <- cfg$formatters %||% list()
  classes <- unique(as.character(classes))
  keys <- as.list(keys)
  names(keys) <- tolower(names(keys))
  keys <- keys[!vapply(keys, is.null, NA)]
  if (inherits(value, "POSIXlt")) value <- as.POSIXct(value)
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
    if (length(bad_cls) || !is.null(keys$digits) || !is.null(keys$sigfig)) {
      value_error(sprintf(
        "`%s` cannot format \"%s\": it is finished wording, not a number (rules 1.4.1, 1.4.12).",
        c(bad_cls, "digits")[1L], as.character(value)[1L]))
    }
  }

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
  if (length(intersect(classes, c(".p", ".date"))) &&
      (!is.null(keys$digits) || !is.null(keys$sigfig))) {
    construct_error(sprintf("`digits` and `sigfig` do not apply to `%s`.",
                            intersect(classes, c(".p", ".date"))[1L]))
  }
  unit_cls <- intersect(classes, c(".pct", ".sci"))
  wording_cls <- c(intersect(classes, WORDING_CLASSES), proj("wording"))
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

  # stage i: number. `digits` or `sigfig` imply `.num` (1.4.7).
  ncls <- c(intersect(classes, NUMBER_CLASSES), proj("number"))
  if (!length(ncls) && (!is.null(keys$digits) || !is.null(keys$sigfig))) {
    ncls <- ".num"
  }
  rec <- NULL
  clamp_rel <- NULL
  zero <- NULL
  if (length(ncls)) {
    cls <- ncls[1]
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

  # stage ii: wording
  is_no <- rep(FALSE, length(text))
  if (".no" %in% classes) {
    is_no <- !is.na(number) & number == 0 & !decimals & relation == "="
    if (!governor) is_no[zero$idx] <- TRUE   # a printed zero, "0.0" too (stage 1i)
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
          ".ord" = paste0(if (nk >= (cfg$thousands_from %||% 1000)) intk else sprintf("%.0f", nk),
                          ordinal_suffix(nk))
        )
      }
    }
  }

  collapsed <- FALSE
  if (governor) {
    # a governor is never collapsed, except that `.range` makes one printed
    # range of its two ends (1.5.11): the span takes the plural unless both
    # ends print "1"
    if (".range" %in% classes) {
      text <- collapse_range(text, number, cfg, raw)
      one <- identical(text, "1")
      number <- if (one) 1 else NA_real_
      decimals <- FALSE
      relation <- "="
      raw <- NA_real_
    }
  } else {
    # stage iii: collapse
    ccls <- c(intersect(classes, COLLAPSE_CLASSES), proj("collapse"))
    if (!length(ccls) && !is.null(trunc)) ccls <- ".and"
    if (length(ccls)) {
      cl <- ccls[1]
      if (cl %in% names(reg)) {
        text <- as.character(apply_project(reg[[cl]], text, NULL))
        text <- text[1]
      } else if (cl == ".range") {
        text <- collapse_range(text, number, cfg, raw)
      } else if (cl %in% c(".pairs", ".dl")) {
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
        text <- collapse_list(cl, text, nms)
      } else {
        sep <- keys$sep %||% ", "
        last <- keys$last %||% (if (cl == ".or") " or " else " and ")
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
    if (!length(ccls) && !is.null(join) && length(text) > 1L) {
      text <- paste(text, collapse = join)
      collapsed <- TRUE
      number <- NA_real_
      decimals <- FALSE
      relation <- "="
      raw <- NA_real_
    }

    text <- text_stage(text)
  }

  if (!governor && !is.null(zero)) on_zero(zero_message(zero))

  out <- new_weft_text(text, number, decimals, relation, raw)
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
#' @param trunc The number of items a collapse shows before "and N others".
#' @param none Text to print in place of a collapse when `x` is a vector of
#'   length zero (`fmt_and()`, `fmt_or()`, `fmt_pairs()`, `fmt_ul()`,
#'   `fmt_ol()`, `fmt_dl()`). The default, `NULL`, makes an empty vector a
#'   `weft_no_value` error. `NULL` itself is always an error.
#' @export
fmt_and <- function(x, sep = ", ", last = NULL, trunc = NULL, none = NULL) {
  apply_formatters(x, ".and", list(sep = sep, last = last, trunc = trunc, none = none))
}

#' @rdname fmt
#' @export
fmt_or <- function(x, sep = ", ", last = NULL, trunc = NULL, none = NULL) {
  apply_formatters(x, ".or", list(sep = sep, last = last, trunc = trunc, none = none))
}

#' @rdname fmt
#' @export
fmt_p <- function(x) apply_formatters(x, ".p")

#' @rdname fmt
#' @export
fmt_date <- function(x) apply_formatters(x, ".date")

#' @rdname fmt
#' @export
fmt_range <- function(x, digits = NULL, sigfig = NULL) {
  apply_formatters(x, ".range", list(digits = digits, sigfig = sigfig))
}

#' @rdname fmt
#' @export
fmt_pairs <- function(x, sep = ", ", last = NULL, trunc = NULL, none = NULL) {
  apply_formatters(x, ".pairs", list(sep = sep, last = last, trunc = trunc, none = none))
}

#' @rdname fmt
#' @export
fmt_ul <- function(x, none = NULL) apply_formatters(x, ".ul", list(none = none))

#' @rdname fmt
#' @export
fmt_ol <- function(x, none = NULL) apply_formatters(x, ".ol", list(none = none))

#' @rdname fmt
#' @export
fmt_dl <- function(x, none = NULL) apply_formatters(x, ".dl", list(none = none))

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
