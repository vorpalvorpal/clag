# The conformance table (dev/design-5.md, amendment item 3). A fixed corpus of
# values is run through the formatter path a `.num`, `.word`, `.and` class or an
# `n` span runs, and written to tests/testthat/_conformance/. A test compares
# the live rows with the files on every run: the files are the definition of
# "what weft prints". Regenerate them after a deliberate change with
#   weft:::conformance_write("tests/testthat/_conformance")
# and review the diff.

conf_cols <- c("value", "classes", "keys", "text")

conf_frame <- function(value, classes, keys, text) {
  data.frame(value = as.character(value), classes = as.character(classes),
             keys = as.character(keys), text = as.character(text),
             stringsAsFactors = FALSE)
}

# the keys of a row as formatter arguments
conf_args <- function(keys) {
  if (!nzchar(keys)) return(list())
  parts <- strsplit(keys, " ", fixed = TRUE)[[1]]
  out <- as.list(sub("^[^=]*=", "", parts))
  names(out) <- sub("=.*$", "", parts)
  for (nm in intersect(names(out), c("digits", "sigfig"))) out[[nm]] <- as.integer(out[[nm]])
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
    "2^53 + 2", "2^64", "2^70", "1e22", "1e23", "-(2^53)", "-(2^70)", "1e300",
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
  d <- conf_unique(d)
  fs <- list(num = fmt_num, pct = fmt_pct)
  d$text <- vapply(seq_len(nrow(d)), function(i) {
    suppressWarnings(conf_text(fs[[d$classes[i]]], d$value[i], d$keys[i]))
  }, "")
  rownames(d) <- NULL
  d
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
  d
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
  rownames(d) <- NULL
  d
}

conformance_rows <- function(set = c("all", "numbers", "words", "lists")) {
  set <- match.arg(set)
  out <- switch(set,
    numbers = conf_numbers_rows(),
    words = conf_words_rows(),
    lists = conf_lists_rows(),
    all = rbind(conf_numbers_rows(), conf_words_rows(), conf_lists_rows()))
  rownames(out) <- NULL
  out[conf_cols]
}

conformance_write <- function(dir) {
  paths <- character()
  for (s in c("numbers", "words", "lists")) {
    d <- conformance_rows(s)
    lines <- c(paste(conf_cols, collapse = "\t"),
               do.call(paste, c(unname(as.list(d)), sep = "\t")))
    p <- file.path(dir, paste0(s, ".tsv"))
    write_lines_atomic(lines, p)
    paths[[s]] <- p
  }
  invisible(paths)
}
