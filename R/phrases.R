# Phrase functions (rules 3.5, 3.3, 1.6.8): wording that arithmetic or a key
# fixes. of_n(), about(), ci(), pm(), clamp(), lookup() and brk().

# The phrase functions that print words print English (1.6.8). Called during a
# knit under another `lang`, they stop with a construct error.
check_english <- function(fn) {
  s <- active_state()
  l <- tolower(sub("[-_].*$", "", s$lang %||% ""))
  if (nzchar(l) && l != "en") {
    construct_error(sprintf(
      "`%s()` prints English words, and the document's `lang` is `%s` (rule 1.6.8).",
      fn, s$lang))
  }
  invisible()
}

# Mark a weft_text as finished wording: a number or wording class on it is a
# value error (1.4.1, 1.4.12).
as_phrase <- function(x) {
  attr(x, "phrase") <- TRUE
  x
}

# One finite number of length one, from an argument of a phrase function.
one_number <- function(x, fn, arg, unit_ok = TRUE) {
  # a quantity: of_n() and about() take its number; the others cannot place the unit (D28)
  x <- if (unit_ok) bare_number(x) else no_unit(x, fn)
  # a weft_text from a formatter passes its number on (3.4.2)
  if (inherits(x, "weft_text") && length(x) == 1L && is.numeric(attr(x, "number")) &&
      !is.na(attr(x, "number"))) {
    x <- attr(x, "number")
  }
  if (length(x) == 0L) no_value_error(sprintf("%s()", fn))
  if (length(x) > 1L) {
    value_error(sprintf("`%s` of %s() must be a single number, not a vector.", arg, fn))
  }
  if (is.na(x) || (is.numeric(x) && !is.finite(x))) no_value_error(sprintf("%s()", fn))
  if (!is.numeric(x)) {
    value_error(sprintf("`%s` of %s() must be a number, not a %s.", arg, fn, class(x)[1L]))
  }
  as.numeric(x)
}

# A number as `.num` prints it, under the project's settings.
print_num <- function(x, digits = NULL, sigfig = NULL, cfg = current_config(), plus = FALSE,
                      class = ".num") {
  format_numbers(x, class, list(digits = digits, sigfig = sigfig), cfg, plus = plus)
}

#' Phrase functions
#'
#' Wording that arithmetic fixes (rule 3.5). Each returns a `weft_text`.
#' They print English words, so under a `lang` weft does not ship they are a
#' construct error (rule 1.6.8).
#'
#' * `of_n(k, n, singular, plural)` prints "none of the 4 sites", "the only
#'   site", "both sites", "all 5 sites" or "3 of the 7 sites". Its number is
#'   `k`, so an `n` span after it agrees with it (rule 3.5.2).
#' * `about(x, to, tolerance)` prints "nearly half", "just over half" or
#'   "half". `to` is one of 1/4, 1/3, 1/2, 2/3 and 3/4. `x` and `to` are
#'   compared as percentages rounded to whole numbers. An `x` further than
#'   `tolerance` from `to` is a value error, because the sentence would be
#'   false. The default tolerance is the setting `about_tolerance`
#'   (0.05).
#' * `ci(est, lo, hi, level, digits, sigfig, plus, pct, short)` prints "2.1
#'   (95% CI 1.3 to 2.9)". The default level is the setting `ci_level` (0.95).
#'   `plus = TRUE` signs the three numbers as `.plus` does; `pct = TRUE`
#'   prints each as `.pct` does; `short = TRUE` (default: the setting
#'   `ci_short`) leaves out "95% CI", and a `level` given with the short form
#'   is a `weft_value_error`.
#' * `pm(est, se, digits, sigfig)` prints the estimate, a plus-minus sign
#'   and the standard error.
#'   When `digits` and `sigfig` are not given and a number of `ci()` or
#'   `pm()` that is not zero prints as zero, one warned check of kind
#'   "printed as zero" is recorded for the call, as for [fmt_num()].
#' * `clamp(x, floor, ceiling)` prints the value as `.num` does inside the
#'   bounds, and "< floor" or "> ceiling" outside, with the relation of the
#'   printed record set (rule 3.5.4).
#'
#' Given a quantity (a `units` value, see [u()]), `of_n()` and `about()` use
#' its number and print no unit: they print words. `ci()`, `pm()` and
#' `clamp()` do not take a quantity that has a unit (rule 4.4.8) and stop
#' with a `weft_value_error`; pass the numbers, or format the parts with
#' [fmt_num()]; so does a formatter's text that carries a unit. Given two
#' quantities, `of_n()` converts `n` to the unit of `k`, and `about()` converts
#' `x` to the unit of `to`; units that do not convert are a `weft_value_error`.
#' A ratio, which has no unit left, is a number.
#'
#' @param k,n Whole numbers, `0 <= k <= n`, `n > 0`.
#' @param singular,plural The noun, in each form.
#' @param x A number.
#' @param to The target of `about()`.
#' @param tolerance The largest distance from `to` that `about()` accepts.
#' @param est,lo,hi,se Numbers.
#' @param level The confidence level of `ci()`, as a proportion.
#' @param plus,pct,short `TRUE` or `FALSE` (`short` also `NULL`) for `ci()`; see above.
#' @param digits,sigfig Decimal places or significant figures, as for
#'   [fmt_num()].
#' @param floor,ceiling The bounds of `clamp()`; `NULL` for none.
#' @return A `weft_text`.
#' @examples
#' of_n(3, 7, "site", "sites")
#' about(0.49)
#' ci(2.1, 1.3, 2.9)
#' pm(2.1, 0.3)
#' clamp(150, ceiling = 99)
#' @name phrases
NULL

# One warned check for the numbers a phrase printed (stage 1i): `parts` are
# the results of print_num(); those that printed a number as zero under the
# default digits are counted together.
note_zero_parts <- function(parts) {
  zs <- Filter(Negate(is.null), lapply(parts, attr, "zero"))
  if (!length(zs)) return(invisible(NULL))
  z <- list(idx = seq_len(sum(vapply(zs, function(z) length(z$idx), 1L))),
            value = zs[[1L]]$value, printed = zs[[1L]]$printed)
  note_zero(zero_message(z))
}

#' @rdname phrases
#' @export
of_n <- function(k, n, singular, plural) {
  check_english("of_n")
  if (missing(singular) || missing(plural)) {
    value_error("of_n() needs both the singular and the plural noun.")
  }
  n <- match_units(k, n, "of_n")   # two quantities compare in the first's unit (3.5.7)
  k <- one_number(k, "of_n", "k")
  n <- one_number(n, "of_n", "n")
  if (k < 0 || n < 0 || !is_whole(k) || !is_whole(n)) {
    value_error("`k` and `n` of of_n() must be whole numbers that are not negative.")
  }
  if (n == 0) value_error("`n` of of_n() must be more than zero.")
  if (k > n) value_error(sprintf("`k` of of_n() (%s) is more than `n` (%s).", format(k), format(n)))
  nn <- as.character(print_num(n))
  noun <- if (n == 1) singular else plural
  txt <- if (k == 0) {
    sprintf("none of the %s %s", nn, noun)
  } else if (k == n && n == 1) {
    sprintf("the only %s", singular)
  } else if (k == n && n == 2) {
    sprintf("both %s", plural)
  } else if (k == n) {
    sprintf("all %s %s", nn, plural)
  } else {
    sprintf("%s of the %s %s", as.character(print_num(k)), nn, noun)
  }
  as_phrase(new_weft_text(txt, number = k, decimals = FALSE, relation = "=", raw = k))
}

ABOUT_TARGETS <- list(
  list(to = 1 / 4, word = "a quarter"), list(to = 1 / 3, word = "a third"),
  list(to = 1 / 2, word = "half"), list(to = 2 / 3, word = "two-thirds"),
  list(to = 3 / 4, word = "three-quarters"))

#' @rdname phrases
#' @export
about <- function(x, to = 1 / 2, tolerance = NULL) {
  check_english("about")
  x <- match_units(to, x, "about")   # `to` is the target, so `x` is converted to its unit
  # a ratio of twins (Sv/Gy) is no ratio of one thing
  if (inherits(x, "units")) {
    un <- attr(x, "units")
    sym <- function(v) structure(list(numerator = v, denominator = character()), class = "symbolic_units")
    tw <- unit_twin_problem(sym(un$denominator), sym(un$numerator), as.character(sym(un$numerator)))
    if (!is.null(tw)) value_error(paste0(tw, " (rule 4.4.14)."))
  }
  x <- one_number(x, "about", "x")
  tolerance <- tolerance %||% current_config()$about_tolerance %||% 0.05
  to <- one_number(to, "about", "to")
  hit <- Filter(function(t) abs(t$to - to) < 1e-9, ABOUT_TARGETS)
  if (!length(hit)) {
    value_error(paste0("`to` of about() must be one of 1/4, 1/3, 1/2, 2/3 and 3/4; got ",
                       format(to), "."))
  }
  word <- hit[[1L]]$word
  if (abs(x - to) * 100 > tolerance * 100 + 1e-9) {
    value_error(sprintf(
      "about(%s, to = %s): the value is further than the tolerance (%s) from the target, so \"%s\" would not be true.",
      format(x), format(to), format(tolerance), word))
  }
  xp <- round_half_away(x * 100, 0L)
  tp <- round_half_away(to * 100, 0L)
  txt <- if (xp == tp) word else if (xp < tp) paste("nearly", word) else paste("just over", word)
  as_phrase(new_weft_text(txt))
}

#' @rdname phrases
#' @export
ci <- function(est, lo, hi, level = NULL, digits = NULL, sigfig = NULL, plus = FALSE, pct = FALSE,
               short = NULL) {
  check_english("ci")
  check_flag(plus, "plus")
  check_flag(pct, "pct")
  if (!is.null(short) && (!is.logical(short) || length(short) != 1L || is.na(short))) {
    construct_error("`short` must be TRUE, FALSE or NULL.")
  }
  est <- one_number(est, "ci", "est", FALSE)
  lo <- one_number(lo, "ci", "lo", FALSE)
  hi <- one_number(hi, "ci", "hi", FALSE)
  cfg <- current_config()
  short <- short %||% isTRUE(cfg$ci_short)
  if (short && !is.null(level)) {
    value_error(sprintf(paste0("ci(): the short form prints no level, and `level = %s` was given; ",
                               "give `short = FALSE` to print it, or drop `level` (rule 3.5.3)."),
                        paste(format(level), collapse = " ")))
  }
  level <- one_number(level %||% cfg$ci_level %||% 0.95, "ci", "level")
  if (level <= 0 || level >= 1) value_error("`level` of ci() must be between 0 and 1.")
  if (lo > hi) value_error(sprintf("ci(): `lo` (%s) is more than `hi` (%s).", format(lo), format(hi)))
  if (est < lo || est > hi) {
    value_error(sprintf("ci(): `est` (%s) is outside the interval %s to %s.",
                        format(est), format(lo), format(hi)))
  }
  cls <- if (pct) ".pct" else ".num"
  pe <- print_num(est, digits, sigfig, cfg, plus, cls)
  pl <- print_num(lo, digits, sigfig, cfg, plus, cls)
  ph <- print_num(hi, digits, sigfig, cfg, plus, cls)
  note_zero_parts(list(pe, pl, ph))
  lv <- format(round(level * 100, 6), trim = TRUE)
  txt <- if (short) {
    sprintf("%s (%s to %s)", as.character(pe), as.character(pl), as.character(ph))
  } else {
    sprintf("%s (%s%% CI %s to %s)", as.character(pe), lv, as.character(pl), as.character(ph))
  }
  as_phrase(new_weft_text(txt, number = attr(pe, "number"), decimals = attr(pe, "decimals"),
                          relation = "=", raw = est))
}

#' @rdname phrases
#' @export
pm <- function(est, se, digits = NULL, sigfig = NULL) {
  est <- one_number(est, "pm", "est", FALSE)
  se <- one_number(se, "pm", "se", FALSE)
  if (se < 0) value_error(sprintf("pm(): `se` (%s) must not be negative.", format(se)))
  cfg <- current_config()
  pe <- print_num(est, digits, sigfig, cfg)
  ps <- print_num(se, digits, sigfig, cfg)
  note_zero_parts(list(pe, ps))
  as_phrase(new_weft_text(paste0(as.character(pe), " \u00b1 ", as.character(ps)),
                          number = attr(pe, "number"), decimals = attr(pe, "decimals"),
                          relation = "=", raw = est))
}

#' @rdname phrases
#' @export
clamp <- function(x, floor = NULL, ceiling = NULL) {
  x <- no_unit(x, "clamp")
  if (length(x) == 0L) no_value_error("clamp()")
  if (is.logical(x) && all(is.na(x))) no_value_error("clamp()")
  if (!is.numeric(x)) value_error(sprintf("clamp() needs a number, not a %s.", class(x)[1L]))
  if (anyNA(x) || any(!is.finite(x))) no_value_error("clamp()")
  cfg <- current_config()
  fl <- if (!is.null(floor)) one_number(floor, "clamp", "floor", FALSE)
  ce <- if (!is.null(ceiling)) one_number(ceiling, "clamp", "ceiling", FALSE)
  if (!is.null(fl) && !is.null(ce) && fl > ce) {
    value_error(sprintf("clamp(): `floor` (%s) is more than `ceiling` (%s).", format(fl), format(ce)))
  }
  # a bound prints as written (3.5.1): to as many decimals as it has
  bound <- function(b) {
    nd <- 0L
    while (nd < 15L && abs(b - round(b, nd)) > 1e-12 * max(1, abs(b))) nd <- nd + 1L
    print_num(b, digits = nd, cfg = cfg)
  }
  one <- function(v) {
    if (!is.null(fl) && v < fl) {
      p <- bound(fl)
      list(text = paste0("< ", as.character(p)), number = attr(p, "number"),
           decimals = attr(p, "decimals"), relation = "<", raw = fl)
    } else if (!is.null(ce) && v > ce) {
      p <- bound(ce)
      list(text = paste0("> ", as.character(p)), number = attr(p, "number"),
           decimals = attr(p, "decimals"), relation = ">", raw = ce)
    } else {
      p <- print_num(v, cfg = cfg)
      list(text = as.character(p), number = attr(p, "number"),
           decimals = attr(p, "decimals"), relation = "=", raw = v)
    }
  }
  res <- lapply(as.numeric(x), one)
  out <- new_weft_text(vapply(res, `[[`, "", "text"),
                       number = vapply(res, `[[`, 0, "number"),
                       decimals = vapply(res, `[[`, NA, "decimals"),
                       relation = vapply(res, `[[`, "", "relation"),
                       raw = vapply(res, `[[`, 0, "raw"))
  # a number class after clamp() formats the bound and keeps the relation
  attr(out, "clamped") <- TRUE
  out
}

#' Phrases chosen by key or by range
#'
#' `lookup()` builds a function from a named character vector (rule 3.3.2):
#' the function takes a string or a factor (by label, never by integer code)
#' and stops with a `weft_value_error` on a key it does not hold. `brk()`
#' builds a function from formulas, tried in order (rule 3.3.3):
#' `brk(. < 0.95 ~ "a fall in", . <= 1.05 ~ "steady", TRUE ~ "a rise in")`.
#' A value no formula takes is a `weft_value_error`. Both functions vectorise,
#' and given `NA` they stop with a `weft_no_value` error and never fall
#' through to a default phrase (rule 3.3.5).
#'
#' @param map A named character vector: key to phrase.
#' @param ... Formulas whose left side is a condition on `.` and whose right
#'   side is the phrase.
#' @return A function of one argument.
#' @examples
#' tier <- lookup(c(hi = "high", lo = "low"))
#' tier("hi")
#' trend <- brk(. < 0.95 ~ "a fall in", . <= 1.05 ~ "steady", TRUE ~ "a rise in")
#' trend(c(0.9, 1, 2))
#' @export
lookup <- function(map) {
  if (is.list(map)) {
    if (!all(vapply(map, function(m) is.character(m) && length(m) == 1L, NA))) {
      construct_error("lookup() takes a named character vector (rule 3.3.2).")
    }
    map <- unlist(map)
  }
  if (!is.character(map) || is.null(names(map)) || any(!nzchar(names(map)))) {
    construct_error("lookup() takes a named character vector (rule 3.3.2).")
  }
  if (anyDuplicated(names(map))) {
    construct_error(sprintf("lookup() has a key written twice: \"%s\" (rule 3.3.2).",
                            names(map)[anyDuplicated(names(map))]))
  }
  force(map)
  function(x) {
    key <- as.character(x)
    if (length(key) == 0L || anyNA(key)) no_value_error("A lookup() function")
    miss <- !(key %in% names(map))
    if (any(miss)) {
      value_error(sprintf("lookup(): \"%s\" is not a key; the keys are %s (rule 3.3.2).",
                          key[miss][1L], paste0("\"", names(map), "\"", collapse = ", ")))
    }
    unname(map[key])
  }
}

#' @rdname lookup
#' @export
brk <- function(...) {
  fs <- list(...)
  ok <- vapply(fs, function(f) inherits(f, "formula") && length(f) == 3L, NA)
  if (!length(fs) || !all(ok)) {
    construct_error("brk() takes formulas with a left and a right side, as in `. < 1 ~ \"low\"` (rule 3.3.3).")
  }
  function(x) {
    if (length(x) == 0L || anyNA(x)) no_value_error("A brk() function")
    vapply(seq_along(x), function(i) {
      xi <- x[[i]]
      for (f in fs) {
        env <- environment(f) %||% globalenv()
        cond <- eval(f[[2L]], list(. = xi), env)
        if (length(cond) == 1L && !is.na(cond) && isTRUE(as.logical(cond))) {
          ph <- eval(f[[3L]], list(. = xi), env)
          if (!is.character(ph) || length(ph) != 1L) {
            value_error("brk(): the right side of a formula must be one string (rule 3.3.3).")
          }
          return(ph)
        }
      }
      value_error(sprintf("brk(): no formula takes the value %s (rule 3.3.3).", format(xi)))
    }, "")
  }
}

# ---- in_range() (N112) ---------------------------------------------------------------

#' Is a value inside a range?
#'
#' `in_range(x, range)` is `TRUE` where `range[1] <= x` and `x <= range[2]`,
#' element by element, and `NA` where `x` is `NA`. The bounds are inside the
#' range. `range` is a `range` entry of the dictionary, as in
#' `in_range(do_mean, dict$do_band)`, or any two numbers in order.
#'
#' A quantity `x` is converted to the unit of the range. Units that do not
#' convert, a number against a range with a unit (or the reverse), and a
#' `range` that is not two numbers with the lower below the upper are a
#' `weft_value_error`. It is an R function: the filter has no dictionary, so
#' it is written in a governor's `if` where R evaluates it.
#'
#' @param x A number or a quantity (a `units` value, see [u()]).
#' @param range Two numbers, lower first; a `units` pair for a quantity.
#' @return A logical vector the length of `x`.
#' @examples
#' in_range(c(6, 7, 9), c(6.5, 8.5))
#' @export
in_range <- function(x, range) {
  bad <- function() value_error("in_range(): `range` must be two numbers, the lower first (rule 4.2.8).")
  r_units <- inherits(range, "units")
  if (!(is.numeric(range) || r_units) || length(range) != 2L) bad()
  rb <- as.numeric(range)
  if (anyNA(rb) || !all(is.finite(rb)) || !(rb[1L] < rb[2L])) bad()
  unit_name <- function(v) if (inherits(v, "units")) as.character(attr(v, "units")) else "no unit"
  cannot <- function() {
    value_error(sprintf("in_range(): `x` in %s cannot be compared with a range in %s (rule 4.2.8).",
                        unit_name(x), unit_name(range)))
  }
  x_units <- inherits(x, "units")
  if (x_units != r_units) cannot()
  if (!(is.numeric(x) || x_units)) cannot()
  if (x_units) {
    conv <- tryCatch(units::set_units(x, units::deparse_unit(range), mode = "standard"), error = function(e) NULL)
    if (is.null(conv)) cannot()
    x <- conv
  }
  xv <- as.numeric(x)
  r <- xv >= rb[1L] & xv <= rb[2L]
  r
}
