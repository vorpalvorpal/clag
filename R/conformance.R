# The conformance table (dev/design-5.md, amendment item 3). A fixed corpus of
# values is run through the formatter path a `.num`, `.word`, `.and` class or an
# `n` span runs, and written to tests/testthat/_conformance/. A test compares
# the live rows with the files on every run: the files are the definition of
# "what weft prints". Regenerate them after a deliberate change with
#   weft:::conformance_write("tests/testthat/_conformance",
#                            sets = c("numbers", "words", "lists", weft:::CONF_NEW_SETS))
# and review the diff.

conf_cols <- c("value", "classes", "keys", "text", "record")

conf_frame <- function(value, classes, keys, text) {
  data.frame(value = as.character(value), classes = as.character(classes),
             keys = as.character(keys), text = as.character(text),
             record = rep("", length(value)), stringsAsFactors = FALSE)
}

# The JSON record (schema 1, N22 and N47) of an R value, for the `record` column. A stand-in
# for the general record maker of R/values.R: only what the conformance corpus needs (scalars
# and atomic vectors). A float's text is the shortest of 15, 16 and 17 significant digits that
# reads back as the same double.
conformance_record <- function(x) {
  kind <- function(e) {
    if (is.factor(e)) e <- as.character(e)
    if (is.logical(e)) "bool"
    else if (is.integer(e)) "int"
    else if (is.double(e)) "float"
    else if (is.character(e)) "string"
    else if (inherits(e, "Date")) "date"
    else "missing"
  }
  scalar <- function(e) {
    if (is.factor(e)) e <- as.character(e)
    if (length(e) == 1L && !is.na(e) && !(is.double(e) && !is.finite(e))) {
      return(switch(kind(e),
        bool = paste0("{\"t\":\"bool\",\"v\":", if (e) "true" else "false", "}"),
        int = paste0("{\"t\":\"int\",\"v\":\"", sprintf("%d", e), "\"}"),
        float = {
          s <- sprintf("%.17g", e)
          for (f in c("%.15g", "%.16g", "%.17g")) {
            s <- sprintf(f, e)
            if (as.numeric(s) == e) break
          }
          paste0("{\"t\":\"float\",\"v\":\"", s, "\"}")
        },
        string = paste0("{\"t\":\"string\",\"v\":", json_string(e), "}"),
        date = paste0("{\"t\":\"date\",\"v\":\"", format(e), "\"}")))
    }
    why <- if (is.double(e) && is.nan(e)) "NaN"
           else if (is.double(e) && is.infinite(e)) { if (e > 0) "Inf" else "-Inf" }
           else "NA"
    paste0("{\"t\":\"missing\",\"why\":\"", why, "\"}")
  }
  if (length(x) == 1L) return(scalar(x))
  elems <- vapply(seq_along(x), function(i) scalar(x[[i]]), "")
  keys <- if (is.null(names(x))) "null" else
    paste0("[", paste(vapply(names(x), json_string, ""), collapse = ","), "]")
  paste0("{\"t\":\"list\",\"v\":[", paste(elems, collapse = ","), "],\"of\":\"", kind(x),
         "\",\"keys\":", keys, "}")
}

# The record of a row's value. Since 6f the general record maker of R/values.R makes it: it
# agrees with conformance_record() on every row of the first three sets (a Date, which
# conformance_record() reads as a float, is the one difference) and knows dates.
conf_add_records <- function(d) {
  d$record <- vapply(d$value, function(v) {
    values_record(eval(parse(text = v), envir = baseenv()))$json
  }, "", USE.NAMES = FALSE)
  d
}

# the keys of a row as formatter arguments
conf_args <- function(keys) {
  if (!nzchar(keys)) return(list())
  parts <- strsplit(keys, " ", fixed = TRUE)[[1]]
  out <- as.list(sub("^[^=]*=", "", parts))
  names(out) <- sub("=.*$", "", parts)
  for (nm in intersect(names(out), c("digits", "sigfig", "trunc"))) out[[nm]] <- as.integer(out[[nm]])
  out
}

conf_text <- function(f, value, keys) {
  as.character(unclass(do.call(f, c(list(eval(parse(text = value), envir = baseenv())),
                                    conf_args(keys)))))
}

conf_unique <- function(d) d[!duplicated(d[c("value", "classes", "keys")]), , drop = FALSE]

conf_numbers_rows <- function() {
  vals <- character()
  # every magnitude from 1e-6 to 1e14
  for (k in -6:14) {
    vals <- c(vals, paste0(c("1", "2.5", "3.14159", "9.87654", "1.2345"), "e", k))
  }
  vals <- c(vals,
    # ties, as written
    "0.15", "0.25", "0.35", "0.45", "0.05", "0.5", "1.5", "2.5", "3.5", "-2.5",
    "-0.15", "-0.5", "-1.5", "1.005", "2.675", "0.285", "10.5", "99.5", "0.995",
    "1234.5", "12345.5",
    # floating-point noise
    "0.1 + 0.2", "0.1 + 0.2 - 0.3", "1e-12", "-1e-12", "1 - 0.9", "0.3 + 1e-12",
    "100 * 1.1", "1/3", "2/3", "22/7", "pi", "-pi", "exp(1)", "sqrt(2)", "1e6/3",
    "0.1 * 3", "1 - 1e-12", "5e-10", "1e-9", "1e-8",
    # zero, integers, whole doubles, negatives
    "0", "0L", "1", "1L", "7L", "-7L", "12", "100", "999", "1000", "1001", "9999",
    "10000", "99999", "100000", "999999", "1000000", "1234567L", "1234567",
    "123456789012", "2147483647L", "-2147483647L", "2147483648", "-2147483648",
    "-1", "-1000", "-1234567.891", "1234567.891", "123456789.5", "12345678",
    "99999999", "1e14", "100000000000001", "99999999999999.5",
    # beyond 15 significant digits
    "999999999999999", "999999999999998", "1e15", "1e15 + 1", "2^53 - 1", "2^53",
    "2^53 + 2", "2^64", "2^70", "1e22", "1e23", "-(2^53)", "-(2^70)",
    "-999999999999999")
  d <- conf_frame(vals, "num", "", "")
  # digits 0 to 6 and sigfig 1 to 5 over a spread of values
  spread <- c("pi", "-pi", "2.5", "0.15", "1234.5678", "0.000123456", "1e6/3",
              "0.1 + 0.2 - 0.3", "999999999999999", "2^53", "12345678L", "1005/1000",
              "0.5", "-2.5", "100", "0")
  keyed <- character()
  keyval <- character()
  for (k in 0:6) {
    keyed <- c(keyed, spread)
    keyval <- c(keyval, rep(paste0("digits=", k), length(spread)))
  }
  for (k in 1:5) {
    keyed <- c(keyed, spread)
    keyval <- c(keyval, rep(paste0("sigfig=", k), length(spread)))
  }
  d <- rbind(d, conf_frame(keyed, "num", keyval, ""))
  # percentages
  pv <- c("0", "0.5", "0.15", "0.25", "2.5", "12.5", "50", "99.5", "100", "-3.456",
          "1234.5", "1/3", "0.1 + 0.2", "0.1 + 0.2 - 0.3", "1e-6", "1e6", "42L", "-0.15")
  d <- rbind(d, conf_frame(pv, "pct", "", ""))
  pk <- c("0.15", "2.5", "1/3", "12.5", "-3.456", "99.5", "1234.5", "0.5")
  for (k in 0:3) d <- rbind(d, conf_frame(pk, "pct", paste0("digits=", k), ""))
  for (k in 1:3) d <- rbind(d, conf_frame(pk, "pct", paste0("sigfig=", k), ""))
  # an explicit plus sign (design-7 N14)
  plus_vals <- c("1.25", "-1.25", "0", "-0", "0.04", "-0.04", "1e-10", "1234.5")
  d <- rbind(d, conf_frame(plus_vals, "num plus", "", ""),
             conf_frame("0.999", "num plus", "digits=2", ""),
             conf_frame(c("0.12", "-0.12", plus_vals), "pct plus", "", ""))
  d <- conf_unique(d)
  fs <- list(num = fmt_num, pct = fmt_pct,
             `num plus` = function(x, ...) fmt_num(x, ..., plus = TRUE),
             `pct plus` = function(x, ...) fmt_pct(x, ..., plus = TRUE))
  d$text <- vapply(seq_len(nrow(d)), function(i) {
    suppressWarnings(conf_text(fs[[d$classes[i]]], d$value[i], d$keys[i]))
  }, "")
  rownames(d) <- NULL
  conf_add_records(d)
}

# a plural form printed by an `n` span, as weft_str() resolves it
conf_n_text <- function(value, one, many) {
  x <- eval(parse(text = value), envir = baseenv())
  weft_str(paste0("[# ", one, " | # ", many, "]{n=\"x\"}"))
}

conf_words_rows <- function() {
  d <- conf_frame(character(), character(), character(), character())
  add <- function(vals, cl, f) {
    dd <- conf_frame(vals, cl, "", "")
    dd$text <- vapply(dd$value, function(v) conf_text(f, v, ""), "", USE.NAMES = FALSE)
    d <<- rbind(d, dd)
  }
  add(as.character(c(0:20, 25, 99, 100, 1000, 1234567)), "word", fmt_word)
  add(as.character(c(0:4, 10:14, 20:24, 31, 99, 100, 101, 102, 111, 112, 113, 121, 1000, 1001, 1234567)),
      "ord", fmt_ord)
  add(as.character(c(0:15, 99, 100, 1000, 1234567)), "count", fmt_count)
  add(as.character(c(0, 1, 2, 3, 9, 10, 11, 12, 100)), "no", fmt_no)
  gov <- c("0", "1", "2", "3", "11", "21", "100", "1000000")
  forms <- list(c("site", "sites"), c("child", "children"))
  for (f in forms) {
    dd <- conf_frame(gov, "n", paste0("singular=", f[1], " plural=", f[2]), "")
    dd$text <- vapply(gov, conf_n_text, "", one = f[1], many = f[2], USE.NAMES = FALSE)
    d <- rbind(d, dd)
  }
  d <- conf_unique(d)
  rownames(d) <- NULL
  conf_add_records(d)
}

conf_lists_rows <- function() {
  vecs <- c('"apples"', 'c("apples", "pears")', 'c("apples", "pears", "plums")',
            'c("apples", "pears", "plums", "figs")', "5", "c(1, 2.5)", "c(1, 2.5, 1000)",
            "c(0.15, 2, 1234567, -3)", "1:4", "c(0.1 + 0.2, 2^53)")
  d <- rbind(conf_frame(vecs, "and", "", ""), conf_frame(vecs, "or", "", ""))
  none <- c("character(0)", "numeric(0)")
  for (cl in c("and", "or")) {
    d <- rbind(d, conf_frame(none, cl, "none=nobody", ""))
    d <- rbind(d, conf_frame(vecs[2], cl, "none=nobody", ""))
  }
  d <- conf_unique(d)
  fs <- list(and = fmt_and, or = fmt_or)
  d$text <- vapply(seq_len(nrow(d)), function(i) conf_text(fs[[d$classes[i]]], d$value[i], d$keys[i]), "")
  # a vector with no collapse class under a number class prints element by element, joined by ", "
  # (rule 1.4.10; parity item A3): made by the 6f row maker, which joins the elements
  nc <- rbind(
    conf_frame(c("c(1, 2.5)", "c(1.25, 3.5)", "c(1234.5, 0.5, -3)", "1:3"), "num", "", ""),
    conf_frame("c(1.234, 5)", "num", "digits=1", ""),
    conf_frame(c("c(0.15, 12.5)", "c(25, 50, 100)"), "pct", "", ""),
    conf_frame(c("c(12345, 0.000123456)", "c(1.5e-7, 2500)"), "sci", "", ""),
    conf_frame(c("c(0.046, 0.0004)", "c(0.5, 0.99, 0.999)"), "p", "", ""),
    conf_frame("c(0.0004, 0.0003)", "num", "digits=1", ""))
  nc$text <- vapply(seq_len(nrow(nc)), function(i) conf_row_text(nc$value[i], nc$classes[i], nc$keys[i]), "")
  d <- rbind(d, nc)
  rownames(d) <- NULL
  conf_add_records(d)
}

# ---- the sets of package 6f (dev/design-6.md, N131) ------------------------------------------
#
# dates.tsv, sci.tsv, p.tsv, collapse.tsv, text.tsv and governors.tsv. Same five columns as the
# first three sets, made the same way: R's own formatter path (apply_formatters(), the engine
# under every fmt_*() and every construct) gives `text`, the record maker of R/values.R gives
# `record`. Two things differ from the first three sets, both because a row may now carry
# more than a few plain keys:
#   * In `keys`, a space inside a value is written %20 (and a % is written %25), so that a
#     key such as sep="; " keeps the one-space separation of the pairs: `sep=;%20`.
#   * Two more kinds of pair. `cfg.NAME=VALUE` is a setting of _weft.yml (serial_comma=true) the
#     row was made under. `span=TEXT` is, for a governor row, the prose that precedes the
#     attribute block, brackets included (`span=[#%20site%20|%20#%20sites]`, `span=file[%20|%20s]`);
#     the row's classes then name the governor (n, sign or list) first and the formatter and text
#     classes after it, and `value` is the governor's value.
# `classes` may hold several tokens, in any order (stage order is the formatter's business).

conf_esc <- function(x) gsub(" ", "%20", gsub("%", "%25", x, fixed = TRUE), fixed = TRUE)
conf_unesc <- function(x) gsub("%25", "%", gsub("%20", " ", x, fixed = TRUE), fixed = TRUE)

conf_parse_keys <- function(keys) {
  out <- list(opts = list(), cfg = list(), span = NULL)
  if (!nzchar(keys)) return(out)
  for (p in strsplit(keys, " ", fixed = TRUE)[[1]]) {
    k <- sub("=.*$", "", p)
    v <- conf_unesc(sub("^[^=]*=", "", p))
    if (k == "span") {
      out$span <- v
    } else if (startsWith(k, "cfg.")) {
      out$cfg[[substring(k, 5L)]] <- if (v %in% c("true", "false")) v == "true" else v
    } else {
      out$opts[[k]] <- if (k %in% c("digits", "sigfig", "trunc")) as.integer(v) else v
    }
  }
  out
}

conf_with_config <- function(cfg, expr) {
  old <- weft_env$config
  on.exit(weft_env$config <- old)
  if (length(cfg)) weft_env$config <- utils::modifyList(current_config(), cfg)
  expr
}

# What the row prints: a governed span through weft_str(), anything else through apply_formatters().
conf_row_text <- function(value, classes, keys) {
  x <- eval(parse(text = value), envir = baseenv())
  k <- conf_parse_keys(keys)
  toks <- strsplit(classes, " ", fixed = TRUE)[[1]]
  gov <- intersect(toks, c("n", "sign", "list"))
  conf_with_config(k$cfg, {
    if (length(gov)) {
      fcl <- setdiff(toks, gov)
      attrs <- c(if (length(fcl)) paste0(".", fcl), sprintf("%s=\"x\"", gov),
                 vapply(names(k$opts), function(nm) sprintf("%s=\"%s\"", nm, k$opts[[nm]]), ""))
      as.character(weft_str(paste0(k$span, "{", paste(attrs, collapse = " "), "}")))
    } else {
      # a vector that no collapse class joins prints joined by ", " (rule 1.4.10)
      paste(suppressWarnings(as.character(unclass(
        apply_formatters(x, paste0(".", toks), k$opts)))), collapse = ", ")
    }
  })
}

conf_finish <- function(d) {
  d <- conf_unique(d)
  d$text <- vapply(seq_len(nrow(d)), function(i) {
    conf_row_text(d$value[i], d$classes[i], d$keys[i])
  }, "")
  rownames(d) <- NULL
  conf_add_records(d)
}

conf_dates_rows <- function() {
  d <- c("2024-03-05", "2024-01-31", "2024-02-29", "2023-02-28", "2024-04-09",
         "2024-05-10", "2024-06-15", "2024-07-04", "2024-08-21", "2024-09-30",
         "2024-10-01", "2024-11-13", "2024-12-25", "1999-12-31", "2000-01-01",
         "2026-11-13", "1900-03-01", "2099-07-09")
  vals <- sprintf("as.Date(\"%s\")", d)
  out <- conf_frame(vals, "date", "", "")
  vecs <- c("as.Date(c(\"2024-01-05\", \"2024-12-25\"))",
            "as.Date(c(\"2024-01-05\", \"2024-06-15\", \"2024-12-25\"))")
  out <- rbind(out, conf_frame(vecs, "date", "", ""),
               conf_frame(vecs, "date and", "", ""), conf_frame(vecs, "date or", "", ""),
               conf_frame(vecs[2], "date and", "sep=;%20", ""),
               conf_frame(vecs[2], "date and", "cfg.serial_comma=true", ""))
  # date_format beyond the default (rules 1.12.11 and 1.6.8; parity item A4): each token the filter reads
  # (%d %-d %e %m %-m %B %b %A %a %Y %y %j %%) with literal text, on a leap day, a century year that is
  # not a leap year, and weekdays across a century
  fmts <- c("%d/%m/%Y", "%-d/%-m/%Y", "%e %B %Y", "%A %-d %B", "%a %b %y", "%j of %Y", "%d%% of %B",
            "Day %j, %A %d %b %Y", "%Y-%m-%d")
  dts <- c("2024-02-29", "2000-02-29", "1900-03-01", "2100-03-01", "1999-12-31", "2026-11-13",
           "2024-03-05")
  for (f in fmts) {
    out <- rbind(out, conf_frame(sprintf("as.Date(\"%s\")", dts), "date",
                                 paste0("cfg.date_format=", conf_esc(f)), ""))
  }
  # a vector under a non-default format, and a collapse class
  out <- rbind(out, conf_frame(vecs[2], "date and", paste0("cfg.date_format=", conf_esc("%a %d/%m/%y")), ""))
  conf_finish(out)
}

conf_sci_rows <- function() {
  vals <- c("12345", "0.000123456", "1", "0", "-2500", "999000", "9.99e5", "1.5e-7", "1e10",
            "-1e-10", "2.5", "99999", "123456789L", "2^53", "1e100", "-0.00099", "5e-324",
            "1.2345e22", "0.5", "10", "100", "3.14159", "-3.14159", "9.5", "9.96")
  out <- conf_frame(vals, "sci", "", "")
  spread <- c("12345", "0.000123456", "999000", "-2500", "3.14159", "1e10", "2.5", "0.5")
  for (k in 0:4) out <- rbind(out, conf_frame(spread, "sci", paste0("digits=", k), ""))
  for (k in 1:5) out <- rbind(out, conf_frame(spread, "sci", paste0("sigfig=", k), ""))
  conf_finish(out)
}

conf_p_rows <- function() {
  vals <- c("0", "1e-10", "0.0004", "0.00099", "0.000999", "0.0009999", "0.001", "0.0010001",
            "0.004", "0.0045", "0.00449", "0.00451", "0.0094999", "0.01", "0.046", "0.0495",
            "0.04949", "0.0499", "0.05", "0.0504", "0.0995", "0.09949", "0.0996", "0.1", "0.104",
            "0.105", "0.15", "0.155", "0.2", "0.5", "0.985", "0.989", "0.99", "0.9901", "0.995",
            "1", "0L", "1L", "1/3", "2/3", "0.0123456", "0.1 + 0.2")
  out <- conf_frame(vals, "p", "", "")
  # digits, a label and the settings (design-7 N28): each threshold, a tie, and 1 - 10^-d exactly
  for (d in 1:4) {
    lo <- 10^-d
    hi <- 1 - lo
    pv <- c("0", "1e-10", "0.00004", "0.0004", "0.004", "0.04", "0.046", "0.05", "0.12", "0.125", "0.25",
            "0.375", "0.5", "0.625", "0.75", "0.9", "0.96", "0.99", "0.9994", "0.9996", "0.99996",
            format(lo / 10, scientific = FALSE), format(lo, scientific = FALSE),
            format(lo * 1.5, scientific = FALSE), format(hi, digits = 15),
            format(hi + lo / 2, digits = 15), format(hi + lo / 10, digits = 15), "1", "1L")
    out <- rbind(out, conf_frame(unique(pv), "p", paste0("digits=", d), ""))
  }
  out <- rbind(out,
    conf_frame(c("0.046", "0.0004", "0.995", "0.12"), "p", "label=q", ""),
    conf_frame(c("0.046", "0.0004", "0.995", "0.12"), "p", "label=", ""),
    conf_frame(c("0.046", "0.0004", "0.12", "0.9996"), "p", "digits=3 label=q", ""),
    conf_frame(c("0.046", "0.0004", "0.12", "0.9996"), "p", "digits=3 label=", ""),
    conf_frame(c("0.046", "0.0004", "0.12", "0.9996"), "p", "cfg.p_digits=3", ""),
    conf_frame(c("0.046", "0.0004", "0.995"), "p", "cfg.p_label=q", ""),
    conf_frame(c("0.046", "0.995"), "p", "cfg.p_label=", ""),
    conf_frame(c("0.12", "0.046"), "p", "cfg.p_digits=3 cfg.p_label=q", ""),
    conf_frame(c("0.12", "0.0004"), "p", "digits=2 cfg.p_digits=3", ""),
    conf_frame(c("0.046", "0.0004"), "p", "label=p cfg.p_label=q", ""),
    conf_frame(c("0.046", "0.0004"), "p", "label= cfg.p_label=q", ""))
  conf_finish(out)
}

conf_collapse_rows <- function() {
  ltr <- "c(\"a\", \"b\", \"c\", \"d\", \"e\")"
  w4 <- "c(\"a\", \"b\", \"c\", \"d\")"
  out <- conf_frame(character(), character(), character(), character())
  add <- function(vals, cl, keys = "") out <<- rbind(out, conf_frame(vals, cl, keys, ""))
  # .pairs
  pv <- c("c(A = 1.2, B = 3.4, C = 5.6)", "c(A = 1.2, B = 3.4)", "c(A = 1.25)",
          "c(A = 1.2, B = 3.4, C = 5.6, D = 7.8)", "c(north = 10, south = 2.5)",
          "c(A = 1000, B = 0.15)", "c(a = \"x\", b = \"y\")")
  add(pv, "pairs")
  add(pv[c(1, 4)], "pairs", "trunc=2")
  add(pv[4], "pairs", "trunc=1")
  add(pv[1], "pairs", "sep=;%20")
  add(pv[1], "pairs", "cfg.serial_comma=true")
  add(pv[4], "pairs", "trunc=2 cfg.serial_comma=true")
  add(pv[1], "pairs", "last=,%20then%20")
  add("character(0)", "pairs", "none=nothing")
  add(pv[1], "num pairs", "digits=2")
  # .range
  rv <- c("c(3, 5)", "c(5, 5)", "c(-5, -3)", "c(-1, 2)", "c(0, 10)", "c(1.25, 3.5)", "c(1000, 2500)",
          "c(5L, 9L)", "c(2.5, 2.5)", "c(1234, 56789)", "c(0.15, 0.25)", "c(10, 10.04)",
          "c(-3, -3)", "c(0, 0)", "c(1e6, 2e6)")
  add(rv, "range")
  # an explicit plus sign (design-7 N14)
  add(c("c(1.2, 3.4)", "c(-0.5, 1.2)", "c(0, 1.2)", "c(1.2, 1.2)", "c(-3, -1)", "c(0, 0)", "c(3, 5)",
        "c(0.04, 1.2)", "c(1000, 2500)"), "range plus")
  for (k in 0:2) add(rv[c(3, 6, 7, 10)], "range", paste0("digits=", k))
  for (k in 1:3) add(rv[c(3, 6, 7, 10)], "range", paste0("sigfig=", k))
  # .and and .or: sep, last, trunc, serial_comma
  for (cl in c("and", "or")) {
    add(c(ltr, w4, "c(\"a\", \"b\")", "\"a\""), cl, "sep=;%20")
    add(c(ltr, w4, "c(\"a\", \"b\")"), cl, "last=/")
    add(c(ltr, w4), cl, "sep=;%20 last=;%20then%20")
    add(c(ltr, w4, "c(\"a\", \"b\", \"c\")"), cl, "last=,%20then%20")
    for (k in 1:5) add(ltr, cl, paste0("trunc=", k))
    add(w4, cl, "trunc=2")
    add("c(\"a\", \"b\")", cl, "trunc=1")
    add("\"a\"", cl, "trunc=1")
    add(c(ltr, w4, "c(\"a\", \"b\")", "\"a\"", "c(\"a\", \"b\", \"c\")"), cl, "cfg.serial_comma=true")
    add(c(ltr, w4), cl, "sep=;%20 cfg.serial_comma=true")
    for (k in 1:4) add(ltr, cl, paste0("trunc=", k, " cfg.serial_comma=true"))
    add(c(ltr, w4), cl, "last=,%20then%20 cfg.serial_comma=true")
    add(w4, cl, "last=/ cfg.serial_comma=true")
    add(ltr, cl, "sep=;%20 trunc=2 cfg.serial_comma=true")
    add(w4, cl, "trunc=2 cfg.serial_comma=true")
    add("character(0)", cl, "none=no%20sites")
    add("character(0)", cl, "none=no%20sites cfg.serial_comma=true")
  }
  # a number or wording class formats each element first (stage order)
  add("c(1234.5, 2, 0.15)", "num and", "digits=1")
  add("c(1234.5, 2, 0.15)", "num or", "digits=2 sep=;%20")
  add("c(0.12, 0.5)", "pct and")
  add("c(1, 2, 3)", "word and")
  add("c(1, 2, 3, 12)", "count or")
  add("c(1, 2, 3)", "ord and", "cfg.serial_comma=true")
  add("c(1, 2, 3, 4, 5)", "word and", "trunc=2")
  conf_finish(out)
}

conf_text_rows <- function() {
  out <- conf_frame(character(), character(), character(), character())
  add <- function(vals, cl, keys = "") out <<- rbind(out, conf_frame(vals, cl, keys, ""))
  # .a: by sound, on numbers and number words
  an <- c("0", "1", "2", "3", "8", "9", "10", "11", "12", "18", "19", "80", "81", "89", "90", "100",
          "800", "899", "900", "1000", "8000", "11000", "18000", "80000", "100000", "800000",
          "1e6", "8e6", "11e6", "18e9", "-8", "-3", "8.5", "12.5", "0.5", "1234567", "81234567",
          "811234567")
  add(an, "a")
  whole <- an[!grepl("^-|\\.", an)]
  add(whole[!whole %in% c("1e6", "8e6", "11e6", "18e9")], "word a")
  add(an[an %in% c("0", "1", "2", "3", "8", "9", "10", "11", "12", "18", "19", "80", "81", "89",
                   "90", "100", "800", "1000")], "ord a")
  add(an[c(5, 8, 10, 14, 17, 21, 22, 25, 29, 30)], "num a", "digits=1")
  add(c("8", "3", "11", "18", "-8", "1.25", "0", "80"), "num plus a")
  add(c("\"eight\"", "\"one\"", "\"eleven\"", "\"eighteen\"", "\"eighty\"", "\"ten\"", "\"hundred\"",
        "\"thousand\"", "\"Eight\""), "a")
  # .cap
  cv <- c("\"apples\"", "\"the site\"", "\"3 sites\"", "\"(note)\"", "\"already capital\"",
          "\"Capital\"", "\"\\u00e9lan\"", "\"x\"", "\"12 sites\"")
  add(cv, "cap")
  add(c("3", "11", "0"), "word cap")
  add(c("1", "2", "3", "11", "22"), "ord cap")
  add("c(\"apples\", \"pears\")", "and cap")
  add("c(\"apples\", \"pears\", \"plums\")", "cap and")
  add("8", "word a cap")
  add("\"eight\"", "a cap")
  # .strong and .em
  add(c("3", "-2.5", "1234567"), "num strong")
  add(c("3", "-2.5", "1234567"), "num em")
  add("c(\"apples\", \"pears\")", "and strong")
  add("c(\"apples\", \"pears\")", "and em")
  add("\"apples\"", "cap strong")
  add("\"apples\"", "em")
  add("5", "word strong")
  conf_finish(out)
}

conf_governors_rows <- function() {
  out <- conf_frame(character(), character(), character(), character())
  add <- function(vals, cl, span, extra = "") {
    keys <- paste(c(paste0("span=", conf_esc(span)), if (nzchar(extra)) extra), collapse = " ")
    out <<- rbind(out, conf_frame(vals, cl, keys, ""))
  }
  k <- c("0", "1", "2", "3", "11", "100", "1234", "1.5", "0.04", "1L", "2L")
  # n: arm counts 1 to 4
  add(k, "n", "[# site | # sites]")
  add(k, "n", "[# metre]")
  add(k, "n", "[no people | a person | # people]")
  add(k, "n", "[never | once | twice | # times]")
  add(k, "n", "[a person | # people]")
  add(k, "n", "file[ | s]")
  add(k, "n", "site[s | | s]")
  add(k, "n", "[## one | # many]")
  add(k, "n", "[# sample was taken | # samples were taken]")
  add(k, "n", "[# site | # sites]", "digits=1")
  add(k, "n", "[# site | # sites]", "digits=0")
  add(c("0", "1", "3", "1234", "0.15"), "n", "[# site | # sites]", "sigfig=2")
  add(c("0", "1", "3", "21"), "n word", "[# site | # sites]")
  add(c("0", "1", "3", "21"), "n cap", "[no sites | one site | # sites]")
  add(c("1", "3"), "n strong", "[# site | # sites]")
  add(c("0", "1", "2", "3"), "n", "[# sample[ | s]{n=\".\"} [was | were]{n=\".\"} taken]")
  add(c("0", "1", "2", "3"), "n",
      "[no sample was taken | # sample was taken | # samples were taken]")
  # n with .range
  add(c("c(3, 5)", "c(1, 1)", "c(0, 1)", "c(2, 2)", "c(0, 0)", "c(1, 2)", "c(1.5, 2)", "c(10, 20)",
        "c(1000, 2500)"), "n range", "[# site | # sites]")
  add(c("c(3, 5)", "c(1, 1)", "c(1.25, 3.5)"), "n range", "[# site | # sites]", "digits=1")
  # sign
  s2 <- "[rose by # | fell by #]"
  s3 <- "[rose by # | fell by # | did not change]"
  sv <- c("0.12", "-0.12", "0", "0.0004", "-0.0004", "1.5", "-1.5", "12", "-12", "0.5", "-0.5",
          "0.004", "1234.5", "-1234.5", "5L", "-5L", "0L")
  nz <- c("0.12", "-0.12", "1.5", "-1.5", "12", "-12", "0.5", "-0.5", "1234.5", "-1234.5", "5L", "-5L")
  add(c(nz, "0.004"), "sign pct", s2)
  add(sv, "sign pct", s3)
  add(sv, "sign pct", s3, "digits=0")
  add(sv, "sign pct", s3, "digits=2")
  add(sv, "sign", s3)
  add(nz, "sign", s2)
  add(sv, "sign num", s3, "digits=1")
  add(nz, "sign", "[up # | down #]")
  add(c("5", "-5", "1", "-1", "2", "-2", "0.5"), "sign",
      "[rose by # point[ | s]{n=\".\"} | fell by # point[ | s]{n=\".\"}]")
  add(c("5", "-5", "1", "-1", "0"), "sign",
      "[rose by # point[ | s]{n=\".\"} | fell by # point[ | s]{n=\".\"} | did not change]")
  add(c("0.12", "-0.12"), "sign pct strong", s2)
  # list
  l3 <- "[No sites were | # was | # were]"
  lv <- c("character(0)", "c(\"a\")", "c(\"a\", \"b\")", "c(\"a\", \"b\", \"c\")",
          "c(\"a\", \"b\", \"c\", \"d\")")
  add(lv, "list", l3)
  add(lv[2:5], "list", "[# was | # were]")
  add(lv, "list", "[none | # was | two were: # | # were]")
  add(lv, "list", "[none | one: # | two: # | several: #]")
  add(lv, "list", "[none | # was | [# site | # sites]{n=\".\"}: #]")
  add(lv, "list or", l3)
  add(lv, "list", l3, "trunc=2")
  add(lv, "list", l3, "sep=;%20")
  add(lv, "list", l3, "last=/")
  add(lv, "list", l3, "cfg.serial_comma=true")
  add(lv[3:5], "list strong", l3)
  add(lv[3:5], "list cap", l3)
  add(c("c(1, 2.5, 10)", "c(1.234, 5)", "5", "c(1, 2, 3)"), "list num", l3, "digits=2")
  add(c("c(1, 2.5, 10)", "5", "c(1, 2, 3)"), "list", l3)
  add(c("c(1, 2, 3)", "5L"), "list word", l3)
  add(c("as.Date(\"2024-03-05\")", "as.Date(c(\"2024-03-05\", \"2024-12-25\"))"), "list", l3)
  add(c("as.Date(\"2024-03-05\")", "as.Date(c(\"2024-03-05\", \"2024-12-25\"))"), "list date", l3)
  conf_finish(out)
}

CONF_NEW_SETS <- c("dates", "sci", "p", "collapse", "text", "governors")

# "all" is the three first sets stacked, as it was before 6f; the six sets of 6f are asked for by name.
conformance_rows <- function(set = c("all", "numbers", "words", "lists", CONF_NEW_SETS)) {
  set <- match.arg(set)
  out <- switch(set,
    numbers = conf_numbers_rows(),
    words = conf_words_rows(),
    lists = conf_lists_rows(),
    dates = conf_dates_rows(),
    sci = conf_sci_rows(),
    p = conf_p_rows(),
    collapse = conf_collapse_rows(),
    text = conf_text_rows(),
    governors = conf_governors_rows(),
    all = rbind(conf_numbers_rows(), conf_words_rows(), conf_lists_rows()))
  rownames(out) <- NULL
  out[conf_cols]
}

# Writes `sets`: by default the three first sets, as it did before 6f (test-lua-num.R pins that); the
# six sets of 6f are written with `sets = c("numbers", "words", "lists", CONF_NEW_SETS)`.
conformance_write <- function(dir, sets = c("numbers", "words", "lists")) {
  paths <- character()
  for (s in sets) {
    d <- conformance_rows(s)
    lines <- c(paste(conf_cols, collapse = "\t"),
               do.call(paste, c(unname(as.list(d)), sep = "\t")))
    p <- file.path(dir, paste0(s, ".tsv"))
    write_lines_atomic(lines, p)
    paths[[s]] <- p
  }
  invisible(paths)
}
