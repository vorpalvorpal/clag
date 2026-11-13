# Package 6f: the six new conformance sets (dev/design-6.md N131): dates.tsv, sci.tsv, p.tsv, collapse.tsv
# (.pairs, .range, sep, last, trunc, serial_comma), text.tsv (.a, .cap, and the emphasis classes) and
# governors.tsv (n, sign and list arms). These are the R side: the committed files equal a fresh
# generation, the text of a row is what R's own formatter prints, the record is what the record maker of
# R/values.R makes, and the corpus covers what the rules name. The Lua side is test-lua-words.R.
#
# THE FORMAT OF A ROW (the five columns of 5h and 6a, with three conventions for the keys column)
#   * a space inside a key's value is written %20 and a % is written %25, so `sep="; "` is `sep=;%20`;
#   * `cfg.NAME=VALUE` is a setting of _weft.yml the row was printed under (`cfg.serial_comma=true`);
#   * `span=TEXT` (governors.tsv) is the prose before the attribute block, brackets included.
# A governor row's `classes` names the governor (n, sign or list) first and then its formatter and text
# classes; its `value` is the governor's value. A row of any other set names its classes as 5h does.

C6 <- CONF_6F
c6_path <- function(set) test_path("_conformance", paste0(set, ".tsv"))
C6_COLS <- c("value", "classes", "keys", "text", "record")

c6_live <- function(set) {
  d <- as.data.frame(weft:::conformance_rows(set), stringsAsFactors = FALSE)
  rownames(d) <- NULL
  d
}

c6_eval <- function(v) eval(parse(text = v), envir = baseenv())

c6_toks <- function(x) strsplit(x, " ", fixed = TRUE)

test_that("6f: conformance_rows() makes each new set with the five columns, deterministically", {
  for (s in C6) {
    d <- weft:::conformance_rows(s)
    expect_identical(names(d), C6_COLS, info = s)
    expect_true(all(vapply(d, is.character, logical(1))), info = s)
    expect_false(anyNA(d), info = s)
    expect_gt(nrow(d), 0L)
    expect_identical(c6_live(s), c6_live(s), info = s)
  }
})

test_that("6f: the default set is still the three sets of 5h, stacked", {
  stacked <- rbind(c6_live("numbers"), c6_live("words"), c6_live("lists"))
  rownames(stacked) <- NULL
  expect_identical(c6_live("all"), stacked)
})

test_that("6f: the committed files exist in the fixed format", {
  for (s in C6) {
    p <- c6_path(s)
    expect_true(file.exists(p), info = p)
    if (!file.exists(p)) next
    raw <- readBin(p, "raw", file.size(p))
    expect_false(identical(raw[1:3], as.raw(c(0xef, 0xbb, 0xbf))), info = paste(s, "no BOM"))
    expect_false(as.raw(13) %in% raw, info = paste(s, "LF line ends only"))
    expect_identical(raw[length(raw)], as.raw(10), info = paste(s, "final newline"))
    txt <- rawToChar(raw)
    Encoding(txt) <- "UTF-8"
    expect_true(validUTF8(txt), info = s)
    lines <- strsplit(txt, "\n", fixed = TRUE)[[1]]
    expect_identical(lines[1], paste(C6_COLS, collapse = "\t"), info = s)
    expect_true(all(lengths(regmatches(lines, gregexpr("\t", lines, fixed = TRUE))) == 4L),
                info = paste(s, "four tabs on every line"))
  }
})

test_that("6f: every row weft computes equals the committed row, and no row repeats", {
  for (s in C6) {
    p <- c6_path(s)
    if (!file.exists(p)) { expect_true(file.exists(p), info = p); next }
    live <- c6_live(s)
    file <- f6_read(s)
    expect(identical(live, file), paste0("set ", s, ": ", nrow(live), " live rows, ", nrow(file),
                                         " committed; the files are stale: regenerate with conformance_write()"))
    key <- paste(file$value, file$classes, file$keys, sep = "\r")
    expect_false(anyDuplicated(key) > 0, info = paste(s, "duplicate row"))
  }
})

test_that("6f: every value is base R on one line, and every record is the record maker's", {
  for (s in C6) {
    d <- f6_read(s)
    expect_false(any(grepl("[\t\n\r]", unlist(d))), info = s)
    for (i in seq_len(nrow(d))) {
      v <- tryCatch(c6_eval(d$value[i]), error = function(e) e)
      expect_false(inherits(v, "error"), info = paste(s, d$value[i]))
      if (inherits(v, "error")) next
      expect_true(isTRUE(jsonlite::validate(d$record[i])), info = paste(s, "record", d$value[i]))
      expect_identical(d$record[i], weft:::values_record(v)$json, info = paste(s, "record", d$value[i]))
    }
  }
})

test_that("6f: a row's keys use only the conventions: render keys, cfg.NAME and span", {
  for (s in C6) {
    d <- f6_read(s)
    for (k in d$keys[nzchar(d$keys)]) {
      for (p in strsplit(k, " ", fixed = TRUE)[[1]]) {
        nm <- sub("=.*$", "", p)
        expect_true(nm %in% c("digits", "sigfig", "sep", "last", "trunc", "none", "span", "label") ||
                      startsWith(nm, "cfg."), info = paste(s, p))
        expect_false(grepl("%[^2]|%2[^05]", p), info = paste(s, "only %20 and %25 are escapes:", p))
      }
    }
  }
})

# ---- the text is what R's formatter prints ------------------------------------------------------------

c6_oracle <- function(d, i) {
  k <- f6_keys(d$keys[i])
  toks <- c6_toks(d$classes[i])[[1]]
  num <- function(x) as.integer(x)
  opts <- k$opts
  for (nm in intersect(names(opts), c("digits", "sigfig", "trunc"))) opts[[nm]] <- num(opts[[nm]])
  cfg <- lapply(k$cfg, function(v) if (v %in% c("true", "false")) v == "true" else v)
  f6_r_text(c6_eval(d$value[i]), paste0(".", toks), opts, cfg)
}

test_that("6f: the text of a row without a governor is what apply_formatters() prints, and fmt_*() agrees on one class", {
  checked <- 0L
  fmts <- list(date = fmt_date, sci = fmt_sci, p = fmt_p, range = fmt_range, pairs = fmt_pairs,
               and = fmt_and, or = fmt_or, a = fmt_a, cap = fmt_cap, strong = fmt_strong, em = fmt_em)
  for (s in setdiff(C6, "governors")) {
    d <- f6_read(s)
    for (i in seq_len(nrow(d))) {
      want <- c6_oracle(d, i)
      expect_identical(d$text[i], want, info = paste(s, d$value[i], d$classes[i], d$keys[i]))
      toks <- c6_toks(d$classes[i])[[1]]
      k <- f6_keys(d$keys[i])
      if (length(toks) == 1L && toks %in% names(fmts) && !length(k$cfg)) {
        args <- k$opts
        for (nm in intersect(names(args), c("digits", "sigfig", "trunc"))) args[[nm]] <- as.integer(args[[nm]])
        got <- paste(suppressWarnings(as.character(unclass(do.call(fmts[[toks]], c(list(c6_eval(d$value[i])), args))))),
                     collapse = ", ")
        expect_identical(d$text[i], got, info = paste("fmt_*():", s, d$value[i], d$classes[i], d$keys[i]))
        checked <- checked + 1L
      }
    }
  }
  expect_gte(checked, 200L)
})

test_that("6f: the text of a governor row is what weft_str() prints for the span", {
  d <- f6_read("governors")
  for (i in seq_len(nrow(d))) {
    x <- c6_eval(d$value[i])
    k <- f6_keys(d$keys[i])
    toks <- c6_toks(d$classes[i])[[1]]
    gov <- intersect(toks, c("n", "sign", "list"))
    fcl <- setdiff(toks, gov)
    attrs <- c(if (length(fcl)) paste0(".", fcl), sprintf("%s=\"x\"", gov),
               vapply(names(k$opts), function(nm) sprintf("%s=\"%s\"", nm, k$opts[[nm]]), ""))
    cfg <- lapply(k$cfg, function(v) v == "true")
    got <- f6_with_cfg(cfg, as.character(weft_str(paste0(k$span, "{", paste(attrs, collapse = " "), "}"))))
    expect_identical(d$text[i], got, info = paste(d$value[i], d$classes[i], d$keys[i]))
  }
})

# ---- what the corpus covers ---------------------------------------------------------------------------

test_that("6f corpus, dates: every month, a leap day, single dates and vectors with and, or, sep and serial_comma", {
  d <- f6_read("dates")
  expect_gte(nrow(d), 20L)
  months <- c("January", "February", "March", "April", "May", "June", "July", "August", "September",
              "October", "November", "December")
  for (m in months) expect_true(any(grepl(paste0("^[0-9]+ ", m, " [0-9]{4}$"), d$text)), info = m)
  expect_true(any(d$text == "29 February 2024"), info = "leap day")
  expect_true(any(grepl("^[1-9] ", d$text[d$classes == "date"])), info = "no leading zero on the day")
  for (cl in c("date", "date and", "date or")) expect_true(cl %in% d$classes, info = cl)
  expect_true(any(grepl("sep=", d$keys)) && any(grepl("cfg.serial_comma=true", d$keys, fixed = TRUE)))
})

test_that("6f corpus, sci: digits 0 to 4, sigfig 1 to 5, a mantissa that rounds up to ten, tiny and huge values", {
  d <- f6_read("sci")
  expect_gte(nrow(d), 100L)
  keys <- lapply(d$keys, f6_keys)
  dig <- unlist(lapply(keys, function(k) k$opts$digits))
  sig <- unlist(lapply(keys, function(k) k$opts$sigfig))
  for (k in 0:4) expect_true(as.character(k) %in% dig, info = paste("digits", k))
  for (k in 1:5) expect_true(as.character(k) %in% sig, info = paste("sigfig", k))
  expect_true(any(grepl("^1.0 \u00d7 10\\^6\\^$", d$text[d$value %in% c("999000", "9.99e5")])), info = "9.99 rounds to ten")
  expect_true(any(grepl("\u2212", d$text)), info = "a minus")
  expect_true(any(grepl("10\\^\u2212[0-9]+\\^", d$text)), info = "a negative exponent")
  expect_true(any(grepl("\\^[0-9]{3}\\^", d$text)), info = "a three-digit exponent")
})

test_that("6f corpus, p: the three branches of rule 1.4.17 and the rows at their edges", {
  d <- f6_read("p")
  expect_gte(nrow(d), 40L)
  expect_true(all(c("p < 0.001", "p > 0.99", "p = 0.046", "p = 0.004", "p = 0.050", "p = 0.10", "p = 0.20") %in% d$text))
  expect_true(any(grepl("^p = 0\\.[0-9]{3}$", d$text)) && any(grepl("^p = 0\\.[0-9]{2}$", d$text)))
  v <- vapply(d$value, function(x) as.numeric(c6_eval(x)), 0, USE.NAMES = FALSE)
  for (x in c(0, 0.001, 0.0009999, 0.0995, 0.99, 1)) expect_true(any(v == x), info = paste("edge", x))
})

test_that("6f corpus, collapse: pairs, range, sep, last, trunc 1 to 5, none, serial_comma with and and or", {
  d <- f6_read("collapse")
  expect_gte(nrow(d), 130L)
  for (cl in c("pairs", "range", "and", "or")) expect_true(cl %in% d$classes, info = cl)
  keys <- lapply(d$keys, f6_keys)
  has <- function(nm) vapply(keys, function(k) nm %in% names(k$opts), NA)
  for (nm in c("sep", "last", "trunc", "none", "digits", "sigfig")) expect_true(any(has(nm)), info = nm)
  tr <- unlist(lapply(keys, function(k) k$opts$trunc))
  for (k in 1:5) expect_true(as.character(k) %in% tr, info = paste("trunc", k))
  ser <- vapply(keys, function(k) identical(k$cfg$serial_comma, "true"), NA)
  expect_true(any(ser & d$classes == "and") && any(ser & d$classes == "or") && any(ser & d$classes == "pairs"))
  expect_true(any(ser & has("trunc")), info = "serial comma with a truncated list")
  expect_true(any(ser & has("last")), info = "serial comma with last")
  expect_true(any(grepl("^[a-e], [a-e], [a-e], and [a-e]$", d$text)), info = "a, b, c, and d")
  expect_true(any(d$text == "a, b, and 2 others"), info = "the tail counts as an item (1.4.15)")
  expect_true(any(grepl("\u2212[0-9.]+ to \u2212[0-9.]+", d$text)), info = "negative range with to")
  expect_true(any(grepl("^[0-9.,]+\u2013[0-9.,]+$", d$text)), info = "range with an en dash")
  expect_true(any(d$classes == "range" & d$text %in% c("5", "2.5", "\u22123")), info = "a range that collapses")
  expect_true(any(grepl(" and [0-9]+ others?$", d$text)), info = "trunc tail")
  expect_true(any(grepl("^[A-Za-z]+ \\([0-9.,]+\\)", d$text[d$classes == "pairs"])), info = "pairs")
  expect_true(all(d$text != ""))
})

test_that("6f corpus, text: .a by sound, .cap, and the emphasis classes", {
  d <- f6_read("text")
  expect_gte(nrow(d), 130L)
  a <- d[d$classes %in% c("a", "word a", "ord a", "num a"), ]
  expect_true(all(grepl("^an? ", a$text)))
  for (x in c("an 8", "an 11", "an 18", "an 80", "an 89", "an 800", "a 9", "a 12", "a 100", "a 1,000", "an 8,000",
              "an eight", "an eleven", "a one", "an 8th", "an 11th", "a 12th")) {
    expect_true(x %in% a$text, info = x)
  }
  cap <- d[grepl("cap", d$classes), ]
  expect_true(any(grepl("^[A-Z]", cap$text)) && any(cap$text == "Three"))
  expect_true(any(grepl("^\\*\\*.+\\*\\*$", d$text)) && any(grepl("^\\*[^*].*\\*$", d$text)))
  for (cl in c("a", "cap", "word a", "ord a", "num strong", "num em", "and strong")) {
    expect_true(cl %in% d$classes, info = cl)
  }
})

test_that("6f corpus, governors: n, sign and list with every arm count, ids aside", {
  d <- f6_read("governors")
  expect_gte(nrow(d), 350L)
  gov <- vapply(c6_toks(d$classes), function(t) intersect(t, c("n", "sign", "list"))[1], "")
  expect_setequal(unique(gov), c("n", "sign", "list"))
  arms <- vapply(d$keys, function(k) {
    sp <- f6_keys(k)$span
    if (is.null(sp)) return(NA_integer_)
    inner <- sub("^[^\\[]*\\[", "", sub("\\]$", "", sp))
    inner <- gsub("\\[[^]]*\\]\\{[^}]*\\}", "", inner)
    length(strsplit(inner, "|", fixed = TRUE)[[1]]) + as.integer(grepl("\\|[ ]*$", inner))
  }, 1L, USE.NAMES = FALSE)
  for (g in c("n", "list")) for (k in 2:4) {
    expect_true(any(gov == g & arms == k), info = paste(g, k, "arms"))
  }
  expect_true(any(gov == "n" & arms == 1L), info = "a one-arm template")
  for (k in 2:3) expect_true(any(gov == "sign" & arms == k), info = paste("sign", k, "arms"))
  expect_true(any(grepl("n range", d$classes, fixed = TRUE)), info = "n with .range (1.5.11)")
  spans <- vapply(d$keys, function(k) { s <- f6_keys(k)$span; if (is.null(s)) "" else s }, "")
  expect_true(any(grepl("n=\".\"", spans, fixed = TRUE)),
              info = "an inner n=\".\" (1.7.2)")
  expect_true(any(d$classes == "sign pct" & d$text == "did not change"), info = "sign zero judged as printed")
  expect_true(any(grepl("^file$|^files$", d$text)) && any(d$text == "site") && any(d$text == "sites"),
              info = "empty arms (1.5.12)")
  expect_true(any(d$text == "# one"), info = "a doubled # is the literal character (1.5.12)")
  expect_true(any(d$text == "1.0 sites"), info = "a printed 1.0 takes the other arm (1.5.9)")
  expect_true(any(d$text == "3\u20135 sites") && any(d$text == "1 site" & d$classes == "n range"))
  expect_true(any(d$text == "No sites were") && any(d$text == "3 sites: a, b and c"))
  expect_true(any(grepl("^rose by ", d$text)) && any(grepl("^fell by ", d$text)))
})

# ---- regeneration -------------------------------------------------------------------------------------

test_that("6f: conformance_write() writes the three first sets by default and, asked, the six new ones byte for byte as committed", {
  dflt <- file.path(withr::local_tempdir(), "dflt")
  weft:::conformance_write(dflt)
  expect_setequal(list.files(dflt), c("numbers.tsv", "words.tsv", "lists.tsv"))
  out <- file.path(withr::local_tempdir(), "regen")
  paths <- weft:::conformance_write(out, sets = c("numbers", "words", "lists", C6))
  want <- paste0(c("numbers", "words", "lists", C6), ".tsv")
  expect_setequal(list.files(out), want)
  expect_setequal(basename(unlist(paths)), want)
  for (s in C6) {
    p <- c6_path(s)
    if (!file.exists(p)) { expect_true(file.exists(p), info = p); next }
    expect_identical(readBin(file.path(out, paste0(s, ".tsv")), "raw", 1e8), readBin(p, "raw", 1e8), info = s)
  }
})
