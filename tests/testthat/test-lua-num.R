# Package 6a: the Lua number printer (dev/design-6.md: rule N85, the conformance rules N130 and N131, and
# the carrier record of N47 as far as the conformance tables' new `record` column needs it).
#
# WHAT THESE TESTS FIX (the implementer builds to this; helper-lua.R holds the Lua interface in full)
# ----------------------------------------------------------------------------------------------------
# 1. inst/quarto/weftlib/num.lua returns a table with `format(record, class, keys, config)` returning
#    `text, info`; it has no side effect on load; anything it does not implement fails loudly with
#    error(), never a pass-through. See the header of helper-lua.R for the arguments, the `info` fields
#    and the messages.
#
# 2. R/conformance.R: conformance_rows() returns FIVE character columns, in this order:
#      value, classes, keys, text, record
#    `record` is the JSON record (schema 1, N22) that N47 makes of `value`, one compact line, no tab:
#      TRUE/FALSE -> {"t":"bool","v":true}; an integer of length 1 -> {"t":"int","v":"<digits>"};
#      a finite double of length 1 -> {"t":"float","v":"<text>"} where <text> is the first of
#      sprintf("%.15g"), "%.16g", "%.17g" that reads back as the same double; a string ->
#      {"t":"string","v":"..."}; a Date -> {"t":"date","v":"YYYY-MM-DD"}; NA, NaN, Inf, -Inf ->
#      {"t":"missing","why":"NA"} and so on; an atomic vector of length 0 or 2 or more ->
#      {"t":"list","v":[<scalar records>],"of":"<kind or missing>","keys":null or [names]}.
#    Member order is free; the JSON must be valid. conformance_write(dir) writes numbers.tsv, words.tsv
#    and lists.tsv with the header line "value<TAB>classes<TAB>keys<TAB>text<TAB>record" and the other
#    format rules of test-conformance.R; it does not write exact.tsv. The three committed files are
#    regenerated with it.
#
# 3. tests/testthat/_conformance/exact.tsv, hand-curated (not generated). UTF-8, no BOM, LF, a final
#    newline, NO comment lines. First line "record<TAB>classes<TAB>keys<TAB>text"; then one line per
#    row, three tabs per line, nothing quoted. `record` is compact JSON of kind "int" or "decimal" only
#    (floats are the generated tables' business); `classes` is "num" or "pct"; `keys` is "", "digits=k"
#    or "sigfig=s"; `text` is what the printer must print, derived by hand from rule N85 and 1.4.13
#    (U+2212 for the minus, "," for the thousands mark, "." for the decimal mark, default digits 1).
#    The minimum the note requires (these tests check it, and check every text against an independent
#    exact oracle in helper-lua.R, exact_oracle(), which skips only a sigfig rounding that carries into
#    a new digit):
#      - at least 50 rows; no two rows alike in (record, classes, keys);
#      - at least 8 "int" rows, their digit counts running from at most 17 to at least 40, one negative;
#      - at least 8 "decimal" rows, their significant digits running from at most 17 to at least 30, one
#        negative, one written with an exponent ("e"), one whole ("5.000"), one non-whole with no key;
#      - ties at every position: for each k in 0 to 6 a "num" decimal row with digits=k whose fraction
#        has exactly k + 1 places and ends in 5;
#      - keys digits=0 to digits=6 and sigfig=1 to sigfig=5 each used at least once;
#      - at least 8 "pct" rows, with a digits key on one and a sigfig key on another;
#      - a negative row whose text rounds to zero and so carries no minus sign.

IMPLEMENTED <- c("num", "pct")
CONF5 <- c("value", "classes", "keys", "text", "record")
EXACT_COLS <- c("record", "classes", "keys", "text")

cdir <- function() test_path("_conformance")

read_tsv <- function(path) {
  utils::read.delim(path, header = TRUE, sep = "\t", quote = "", comment.char = "",
                    colClasses = "character", na.strings = character(), check.names = FALSE,
                    stringsAsFactors = FALSE, encoding = "UTF-8", fileEncoding = "UTF-8",
                    blank.lines.skip = FALSE)
}

# the first rows where `got` and `want` differ, as a message
first_diffs <- function(d, got, want, n = 6) {
  bad <- which(is.na(got) | got != want)
  bad <- utils::head(bad, n)
  paste0(length(which(is.na(got) | got != want)), " of ", length(want),
         " rows differ; first differences:\n",
         paste(vapply(bad, function(i) {
           sprintf("  row %d: %s | %s | %s\n    printed:   %s\n    committed: %s", i,
                   d$record[i], d$classes[i], d$keys[i], got[i], want[i])
         }, character(1)), collapse = "\n"))
}

for_each_pandoc <- function(f) {
  skip_if_no_lua_pandoc()
  for (p in lua_pandocs()) f(p)
}

# run a table of rows with a `text` column through the printer and compare, whole columns
expect_table_prints <- function(d, p, config = NULL, what = "") {
  d <- d[d$classes %in% IMPLEMENTED, , drop = FALSE]
  res <- lua_num_table(d, config = config, pandoc = p)
  got <- ifelse(res$ok, res$text, paste0("<<error: ", res$err, ">>"))
  expect(identical(got, d$text),
         paste0(what, " (pandoc ", p$version, "): ", first_diffs(d, got, d$text)))
  invisible(res)
}

# ---- the record of N47, by an independent oracle -----------------------------------------------------

n47_float_text <- function(x) {
  for (f in c("%.15g", "%.16g", "%.17g")) {
    s <- sprintf(f, x)
    if (as.numeric(s) == x) return(s)
  }
  sprintf("%.17g", x)
}

n47_scalar <- function(x) {
  if (is.logical(x) && !is.na(x)) return(list(t = "bool", v = x))
  if (is.factor(x)) x <- as.character(x)
  if (is.integer(x) && !is.na(x)) return(list(t = "int", v = sprintf("%d", x)))
  if (is.double(x) && is.finite(x)) return(list(t = "float", v = n47_float_text(x)))
  if (is.character(x) && !is.na(x)) return(list(t = "string", v = x))
  if (inherits(x, "Date") && !is.na(x)) return(list(t = "date", v = format(x)))
  why <- if (is.na(x) && !is.nan(x)) "NA" else if (is.nan(x)) "NaN" else if (x > 0) "Inf" else "-Inf"
  list(t = "missing", why = why)
}

# does the JSON `rec` agree with the R value `x` (N47)? returns "" or a reason
record_disagrees <- function(rec, x) {
  if (!isTRUE(jsonlite::validate(rec))) return("not valid JSON")
  r <- jsonlite::fromJSON(rec, simplifyVector = FALSE)
  if (!is.list(r) || is.null(names(r)) || !is.character(r$t)) return("no member t")
  if (!r$t %in% c("bool", "int", "float", "decimal", "string", "date", "list", "missing", "error")) {
    return(paste("unknown kind", r$t))
  }
  one <- function(r, e) {
    w <- n47_scalar(e)
    if (!identical(r$t, w$t)) return(paste0("kind ", r$t, ", wanted ", w$t))
    if (w$t == "missing") return(if (identical(r$why, w$why)) "" else paste0("why ", r$why, ", wanted ", w$why))
    if (!identical(r$v, w$v)) return(paste0("v ", format(r$v), ", wanted ", format(w$v)))
    if (w$t == "int" && !grepl("^-?(0|[1-9][0-9]*)$", r$v)) return("int digits break N22")
    if (w$t == "float" && !grepl("^-?[0-9]+(\\.[0-9]+)?([eE][+-]?[0-9]+)?$", r$v)) return("float text breaks N22")
    ""
  }
  if (length(x) == 1L) return(one(r, x))
  if (!identical(r$t, "list")) return(paste0("kind ", r$t, ", wanted list"))
  if (!is.character(r$of) || length(r$of) != 1L) return("list without `of`")
  if (length(r$v) != length(x)) return(paste0("list has ", length(r$v), " elements, wanted ", length(x)))
  for (i in seq_along(x)) {
    bad <- one(r$v[[i]], x[[i]])
    if (nzchar(bad)) return(paste0("element ", i, ": ", bad))
  }
  if (!is.null(names(x))) {
    if (!identical(unlist(r$keys), names(x))) return("keys differ from names")
  } else if (!is.null(r$keys) && length(r$keys)) return("keys given for an unnamed vector")
  ""
}

# ---- Pandoc and the module ------------------------------------------------------------------------------

test_that("6a: Pandoc found for the Lua tests is 3.1 or later (an older one is a failure, not a skip)", {
  skip_if_no_lua_pandoc()
  for (p in lua_pandocs()) {
    expect_true(lua_version_ok(p), info = paste("pandoc", p$version, "via", p$label))
  }
})

test_that("6a N80: weftlib/num.lua exists, returns a table with format(), and has no side effect on load", {
  skip_if_no_lua_pandoc()
  path <- lua_num_path()
  expect_true(file.exists(path), info = path)
  if (!file.exists(path)) return(invisible())
  dir <- withr::local_tempdir()
  script <- file.path(dir, "load.lua")
  writeLines(c(
    "local before = {}",
    "for k in pairs(_G) do before[k] = true end",
    "local num = dofile(arg[1])",
    "local added = {}",
    "for k in pairs(_G) do if not before[k] then added[#added + 1] = k end end",
    "io.stderr:write('type=', type(num), ' format=', type(num.format), ' globals=', #added, '\\n')"
  ), script)
  for (p in lua_pandocs()) {
    r <- lua_run(script, path, pandoc = p)
    expect_identical(r$status, 0L, info = r$stderr)
    expect_identical(r$stdout, "", info = "loading prints nothing")
    expect_match(r$stderr, "type=table format=function globals=0", fixed = TRUE)
  }
  # run alone, as the note says a weftlib module can be (N80)
  for (p in lua_pandocs()) {
    r <- lua_run(path, pandoc = p)
    expect_identical(r$status, 0L, info = r$stderr)
    expect_identical(r$stdout, "")
  }
})

test_that("6a: format() works with keys and config left out", {
  skip_if_no_lua_pandoc()
  path <- lua_num_path()
  expect_true(file.exists(path), info = path)
  if (!file.exists(path)) return(invisible())
  dir <- withr::local_tempdir()
  script <- file.path(dir, "nil.lua")
  writeLines(c(
    "local num = dofile(arg[1])",
    "local a, ia = num.format({t = 'float', v = '3.14159'}, 'num')",
    "local b = num.format({t = 'int', v = '1234567'}, 'num', nil, nil)",
    "local c = num.format({t = 'decimal', v = '0.5'}, 'pct', {}, {})",
    "io.stdout:write(a, '|', b, '|', c, '|', tostring(type(ia)))"
  ), script)
  for (p in lua_pandocs()) {
    r <- lua_run(script, path, pandoc = p)
    expect_identical(r$stdout, "3.1|1,234,567|50%|table", info = r$stderr)
  }
})

# ---- every row of the committed tables ----------------------------------------------------------------

test_that("6a: the committed numbers.tsv has the record column, and every num and pct row prints its text", {
  d <- read_tsv(file.path(cdir(), "numbers.tsv"))
  expect_identical(names(d), CONF5)
  if (!"record" %in% names(d)) return(invisible())
  expect_gte(sum(d$classes %in% IMPLEMENTED), 300)
  expect_true(all(d$classes %in% IMPLEMENTED), info = "numbers.tsv holds only classes the first stage implements")
  for_each_pandoc(function(p) expect_table_prints(d, p, what = "numbers.tsv"))
})

test_that("6a: the committed words.tsv and lists.tsv carry the record column too", {
  for (s in c("words", "lists")) {
    d <- read_tsv(file.path(cdir(), paste0(s, ".tsv")))
    expect_identical(names(d), CONF5, info = s)
  }
})

# ---- the record column -------------------------------------------------------------------------------

test_that("6a N131: conformance_rows() returns the record column, for every set", {
  d <- weft:::conformance_rows()
  expect_identical(names(d), CONF5)
  expect_true(all(vapply(d, is.character, logical(1))))
  expect_false(anyNA(d))
  for (s in c("numbers", "words", "lists")) {
    x <- weft:::conformance_rows(s)
    expect_identical(names(x), CONF5, info = s)
    expect_false(any(grepl("[\t\n\r]", x$record)), info = s)
  }
})

test_that("6a N131: the record of every committed row is valid JSON of the record schema and agrees with value", {
  for (s in c("numbers", "words", "lists")) {
    d <- read_tsv(file.path(cdir(), paste0(s, ".tsv")))
    expect_true("record" %in% names(d), info = s)
    if (!"record" %in% names(d)) next
    bad <- character()
    for (i in seq_len(nrow(d))) {
      x <- eval(parse(text = d$value[i]), baseenv())
      why <- record_disagrees(d$record[i], x)
      if (nzchar(why)) bad <- c(bad, sprintf("  row %d (%s): %s", i, d$value[i], why))
    }
    expect(length(bad) == 0, paste0(s, ": ", length(bad), " records disagree with value; first:\n",
                                    paste(utils::head(bad, 6), collapse = "\n")))
  }
})

test_that("6a N131: the live rows carry the same records as the committed files, row for row", {
  for (s in c("numbers", "words", "lists")) {
    live <- weft:::conformance_rows(s)
    file <- read_tsv(file.path(cdir(), paste0(s, ".tsv")))
    expect_true("record" %in% names(file), info = s)
    if (!"record" %in% names(file)) next
    expect_identical(live$record, file$record, info = s)
  }
})

test_that("6a N131: float records are the shortest of 15, 16 and 17 digits that read back", {
  d <- read_tsv(file.path(cdir(), "numbers.tsv"))
  expect_true("record" %in% names(d))
  if (!"record" %in% names(d)) return(invisible())
  fl <- d[grepl('"t":"float"', d$record, fixed = TRUE), ]
  expect_gt(nrow(fl), 100)
  for (i in seq_len(nrow(fl))) {
    x <- eval(parse(text = fl$value[i]), baseenv())
    expect_identical(jsonlite::fromJSON(fl$record[i])$v, n47_float_text(x), info = fl$value[i])
  }
  want <- c("0.1 + 0.2" = "0.30000000000000004", "1/3" = "0.3333333333333333", "2^53" = "9007199254740992",
            "1e23" = "1e+23", "0.1" = "0.1")
  for (v in names(want)) {
    r <- d$record[d$value == v][1]
    if (is.na(r)) next
    expect_identical(jsonlite::fromJSON(r)$v, unname(want[v]), info = v)
  }
})

test_that("6a N131: conformance_write() writes the five-column files byte for byte, and no exact.tsv", {
  out <- file.path(withr::local_tempdir(), "regen")
  paths <- weft:::conformance_write(out)
  expect_setequal(list.files(out), paste0(c("numbers", "words", "lists"), ".tsv"))
  expect_false("exact.tsv" %in% basename(unlist(paths)))
  for (s in c("numbers", "words", "lists")) {
    a <- readBin(file.path(out, paste0(s, ".tsv")), "raw", 1e8)
    b <- readBin(file.path(cdir(), paste0(s, ".tsv")), "raw", 1e8)
    expect_identical(a, b, info = s)
    first <- strsplit(rawToChar(a), "\n", fixed = TRUE)[[1]][1]
    expect_identical(first, paste(CONF5, collapse = "\t"), info = s)
  }
})

# ---- the hand-curated exact.tsv ---------------------------------------------------------------------------

exact_rows <- function() {
  p <- file.path(cdir(), "exact.tsv")
  expect_true(file.exists(p), info = "tests/testthat/_conformance/exact.tsv")
  if (!file.exists(p)) return(NULL)
  read_tsv(p)
}

exact_v <- function(d) vapply(d$record, function(r) jsonlite::fromJSON(r)$v, "", USE.NAMES = FALSE)
exact_t <- function(d) vapply(d$record, function(r) jsonlite::fromJSON(r)$t, "", USE.NAMES = FALSE)
exact_k <- function(d, key) {
  vapply(strsplit(d$keys, " ", fixed = TRUE), function(k) {
    m <- grep(paste0("^", key, "="), k, value = TRUE)
    if (length(m)) sub("^[^=]*=", "", m[1]) else NA_character_
  }, "")
}
sig_digits <- function(v) nchar(sub("^0+", "", gsub("[-.]|[eE].*$", "", v)))

test_that("6a N131: exact.tsv has the fixed format", {
  p <- file.path(cdir(), "exact.tsv")
  expect_true(file.exists(p), info = p)
  if (!file.exists(p)) return(invisible())
  raw <- readBin(p, "raw", file.size(p))
  expect_false(identical(raw[1:3], as.raw(c(0xef, 0xbb, 0xbf))), info = "no BOM")
  expect_false(as.raw(13) %in% raw, info = "LF only")
  expect_identical(raw[length(raw)], as.raw(10), info = "final newline")
  txt <- rawToChar(raw); Encoding(txt) <- "UTF-8"
  expect_true(validUTF8(txt))
  lines <- strsplit(txt, "\n", fixed = TRUE)[[1]]
  expect_identical(lines[1], paste(EXACT_COLS, collapse = "\t"))
  expect_true(all(lengths(regmatches(lines, gregexpr("\t", lines, fixed = TRUE))) == 3L),
              info = "three tabs on every line")
  expect_false(any(startsWith(lines, "#")), info = "no comment lines")
  d <- exact_rows()
  expect_identical(names(d), EXACT_COLS)
  expect_true(all(d$classes %in% IMPLEMENTED))
  expect_true(all(grepl("^(digits=[0-6]|sigfig=[1-5])?$", d$keys)))
  expect_true(all(vapply(d$record, jsonlite::validate, logical(1))))
  expect_true(all(exact_t(d) %in% c("int", "decimal")))
  expect_false(anyDuplicated(paste(d$record, d$classes, d$keys, sep = "\r")) > 0)
})

test_that("6a N131: exact.tsv holds the minimum rows the note requires", {
  d <- exact_rows()
  if (is.null(d)) return(invisible())
  v <- exact_v(d); t <- exact_t(d)
  expect_gte(nrow(d), 50)
  ints <- v[t == "int"]
  expect_gte(length(ints), 8)
  nd <- nchar(sub("^-", "", ints))
  expect_lte(min(nd), 17); expect_gte(max(nd), 40)
  expect_true(any(startsWith(ints, "-")), info = "a negative int")
  decs <- v[t == "decimal"]
  expect_gte(length(decs), 8)
  sg <- sig_digits(decs)
  expect_lte(min(sg), 17); expect_gte(max(sg), 30)
  expect_true(any(startsWith(decs, "-")), info = "a negative decimal")
  expect_true(any(grepl("[eE]", decs)), info = "a decimal written with an exponent")
  expect_true(any(grepl("^-?[0-9]+\\.0+$", decs)), info = "a whole decimal such as 5.000")
  expect_true(any(t == "decimal" & d$keys == "" & grepl("\\.", v) & !grepl("^-?[0-9]+\\.0+$", v) &
                    !grepl("[eE]", v)), info = "a non-whole decimal with no key")
  dg <- exact_k(d, "digits"); sf <- exact_k(d, "sigfig")
  for (k in 0:6) expect_true(as.character(k) %in% dg, info = paste("digits", k))
  for (k in 1:5) expect_true(as.character(k) %in% sf, info = paste("sigfig", k))
  for (k in 0:6) {
    fr <- ifelse(grepl("\\.", v), sub("^[^.]*\\.", "", v), "")
    tie <- t == "decimal" & d$classes == "num" & !is.na(dg) & dg == as.character(k) &
      !grepl("[eE]", v) & nchar(fr) == k + 1L & grepl("5$", fr)
    expect_true(any(tie), info = paste("a decimal tie at digits =", k))
  }
  pct <- d$classes == "pct"
  expect_gte(sum(pct), 8)
  expect_true(any(pct & !is.na(dg)) && any(pct & !is.na(sf)), info = "pct with digits and with sigfig")
  expect_true(any(startsWith(v, "-") & grepl("^0(\\.0+)?%?$", d$text)),
              info = "a negative row that rounds to zero prints no minus")
})

test_that("6a N131: every text in exact.tsv is what rule N85 gives, by an independent exact oracle", {
  d <- exact_rows()
  if (is.null(d)) return(invisible())
  v <- exact_v(d)
  dg <- exact_k(d, "digits")
  want <- vapply(seq_len(nrow(d)), function(i) {
    exact_oracle(v[i], d$classes[i], digits = if (is.na(dg[i])) NULL else dg[i],
                 sigfig = { s <- exact_k(d[i, ], "sigfig"); if (is.na(s)) NULL else as.integer(s) })
  }, "")
  skip <- is.na(want)
  bad <- which(!skip & want != d$text)
  expect(length(bad) == 0,
         paste0(length(bad), " texts differ from the oracle; first:\n",
                paste(vapply(utils::head(bad, 6), function(i) {
                  sprintf("  row %d: %s %s %s\n    file:   %s\n    oracle: %s", i, v[i], d$classes[i],
                          d$keys[i], d$text[i], want[i])
                }, ""), collapse = "\n")))
  expect_lt(sum(skip), 5, label = "rows the oracle leaves open")
})

test_that("6a N85: every row of exact.tsv prints exactly its text through the Lua printer", {
  d <- exact_rows()
  if (is.null(d)) return(invisible())
  for_each_pandoc(function(p) expect_table_prints(d, p, what = "exact.tsv"))
})

test_that("6a N85: the independent oracle agrees with R on the committed numbers.tsv rows it can read", {
  d <- read_tsv(file.path(cdir(), "numbers.tsv"))
  checked <- 0L; bad <- character()
  for (i in seq_len(nrow(d))) {
    x <- eval(parse(text = d$value[i]), baseenv())
    v <- if (is.integer(x)) sprintf("%d", x) else n47_float_text(x)
    if (!is.integer(x) && (sig_digits(v) > 15 || (x != 0 && abs(x) < 1e-9) ||
                           (x != round(x) && abs(x - round(x)) < 1e-9))) next
    k <- exact_k(d[i, ], "digits"); s <- exact_k(d[i, ], "sigfig")
    o <- exact_oracle(v, d$classes[i], digits = if (is.na(k)) NULL else k,
                      sigfig = if (is.na(s)) NULL else as.integer(s))
    if (is.na(o)) next
    checked <- checked + 1L
    if (!identical(o, d$text[i])) bad <- c(bad, sprintf("%s %s %s: oracle %s, R %s", d$value[i], d$classes[i], d$keys[i], o, d$text[i]))
  }
  expect_gt(checked, 250L)
  expect_identical(bad, character())
})

# ---- float and int records of one whole value ------------------------------------------------------------

test_that("6a N85: a float record and an int record of the same whole value up to 2^53 print the same", {
  whole <- c("0", "1", "7", "42", "999", "1000", "65536", "1234567", "2147483647", "123456789012",
             "999999999999999", "9007199254740991", "9007199254740992")
  grid <- expand.grid(v = c(whole, paste0("-", whole[-1])), cls = IMPLEMENTED,
                      key = c("", "digits=0", "digits=2", "sigfig=3", "sigfig=5"), stringsAsFactors = FALSE)
  # .pct multiplies by 100: a float then passes 2^53 and is read to 15 significant digits, as R does, while
  # an int record stays exact, so the two may differ there by rule (N85). Keep .pct to values below 2^53 / 100.
  grid <- grid[!(grid$cls == "pct" & abs(as.numeric(grid$v)) * 100 > 2^53), ]
  fl <- data.frame(record = rec_float(grid$v), classes = grid$cls, keys = grid$key, stringsAsFactors = FALSE)
  it <- data.frame(record = rec_int(grid$v), classes = grid$cls, keys = grid$key, stringsAsFactors = FALSE)
  for_each_pandoc(function(p) {
    a <- lua_num_table(fl, pandoc = p); b <- lua_num_table(it, pandoc = p)
    expect_true(all(a$ok) && all(b$ok))
    bad <- which(a$text != b$text)
    expect(length(bad) == 0, paste0("float and int differ (pandoc ", p$version, "): ",
                                    paste(utils::head(sprintf("%s %s %s: float %s, int %s", grid$v[bad], grid$cls[bad],
                                                              grid$key[bad], a$text[bad], b$text[bad]), 5), collapse = "; ")))
  })
})

# ---- cases, one process per Pandoc --------------------------------------------------------------------------

cfg <- function(...) as.character(jsonlite::toJSON(list(...), auto_unbox = TRUE))
case <- function(record, text, classes = "num", keys = "", config = "") {
  data.frame(record = record, classes = classes, keys = keys, text = text, config = config,
             stringsAsFactors = FALSE)
}
M <- "−"
z22 <- strrep("0", 22)

CASES <- do.call(rbind, list(
  # half away from zero on the number as written (float: read to 15 digits)
  case(rec_float("0.15"), "0.2", keys = "digits=1"),
  case(rec_float("0.25"), "0.3"),
  case(rec_float("0.35"), "0.4"),
  case(rec_float("2.5"), "3", keys = "digits=0"),
  case(rec_float("0.5"), "1", keys = "digits=0"),
  case(rec_float("1.5"), "2", keys = "digits=0"),
  case(rec_float("-2.5"), paste0(M, "3"), keys = "digits=0"),
  case(rec_float("-0.5"), paste0(M, "1"), keys = "digits=0"),
  case(rec_float("-0.15"), paste0(M, "0.2"), keys = "digits=1"),
  case(rec_float("1.005"), "1.01", keys = "digits=2"),
  case(rec_float("2.675"), "2.68", keys = "digits=2"),
  case(rec_float("0.285"), "0.29", keys = "digits=2"),
  case(rec_float("0.15"), "15%", classes = "pct", keys = "digits=0"),
  # exact: ties on the value as written, beyond a double
  case(rec_dec("0.125"), "0.13", keys = "digits=2"),
  case(rec_dec("-0.125"), paste0(M, "0.13"), keys = "digits=2"),
  case(rec_dec("0.5"), "1", keys = "digits=0"),
  case(rec_dec("2.5"), "3", keys = "digits=0"),
  case(rec_dec("-2.5"), paste0(M, "3"), keys = "digits=0"),
  case(rec_dec("0.0005"), "0.001", keys = "digits=3"),
  case(rec_dec("1.45"), "1.5", keys = "digits=1"),
  case(rec_dec("2.675"), "2.68", keys = "digits=2"),
  case(rec_dec("1.449999999999999999999"), "1.4", keys = "digits=1"),
  case(rec_dec("1.4500000000000000000001"), "1.5", keys = "digits=1"),
  case(rec_dec("0.1000000000000000055511151231257827"), "0.1", keys = "digits=1"),
  case(rec_dec("12345678901234567890.25"), "12,345,678,901,234,567,890.3", keys = "digits=1"),
  case(rec_dec("12345678901234567890.25"), "12,345,678,901,234,567,890.3"),
  case(rec_dec("12345678901234567890.5"), "12,345,678,901,234,567,890.5"),
  case(rec_dec(paste0("0.", z22, "125")), paste0("0.", z22, "13"), keys = "sigfig=2"),
  case(rec_dec("2.5"), "3", keys = "sigfig=1"),
  case(rec_dec("0.15"), "0.2", keys = "sigfig=1"),
  # whole when every fraction digit is 0; otherwise the default digits
  case(rec_dec("5.000"), "5"),
  case(rec_dec("5.000"), "5.00", keys = "digits=2"),
  case(rec_dec("-0.0"), "0"),
  case(rec_dec("3.0000000000000000001"), "3.0"),
  case(rec_dec("1.5e3"), "1,500"),
  case(rec_dec("1.5e-3"), "0.0015", keys = "digits=4"),
  case(rec_dec("1.2345678901234567890e19"), "12,345,678,901,234,567,890"),
  # ints of any size print every digit
  case(rec_int("0"), "0"),
  case(rec_int("9007199254740993"), "9,007,199,254,740,993"),
  case(rec_int("9007199254740993"), "9,007,199,254,740,993.00", keys = "digits=2"),
  case(rec_int("9007199254740993"), "9,010,000,000,000,000", keys = "sigfig=3"),
  case(rec_int("-1234567890123456789012345678901234567890"),
       paste0(M, "1,234,567,890,123,456,789,012,345,678,901,234,567,890")),
  case(rec_int("123456789012345678901234"), "123,460,000,000,000,000,000,000", keys = "sigfig=5"),
  case(rec_int("12345"), "12,345", keys = "digits=0"),
  case(rec_int("5"), "5.00", keys = "digits=2"),
  case(rec_int("100"), "100.0", keys = "sigfig=4"),
  # a float beyond 2^53 is read to 15 significant digits
  case(rec_float("1.2345678901234567e+19"), "12,345,678,901,234,600,000"),
  case(rec_float("1.1805916207174113e+21"), "1,180,591,620,717,410,000,000"),
  case(rec_float("1e+23"), "100,000,000,000,000,000,000,000"),
  case(rec_float("1.0e23"), "100,000,000,000,000,000,000,000"),
  # .pct moves the point, exactly
  case(rec_dec("0.125"), "12.5%", classes = "pct", keys = "digits=1"),
  case(rec_dec("0.12345678901234567890123"), "12.346%", classes = "pct", keys = "digits=3"),
  case(rec_int("123456789012345678"), "12,345,678,901,234,567,800%", classes = "pct"),
  case(rec_dec("0.005"), "1%", classes = "pct", keys = "digits=0"),
  case(rec_float("0.5"), "50%", classes = "pct"),
  case(rec_float("1234.5"), "123,450%", classes = "pct"),
  case(rec_int("5"), "500%", classes = "pct"),
  # negative zero and a minus that rounds away
  case(rec_float("-0"), "0"),
  case(rec_float("-0"), "0.0", keys = "digits=1"),
  case(rec_float("-0.0"), "0"),
  case(rec_float("-0.04"), "0.0"),
  case(rec_float("-0.04"), "0", keys = "digits=0"),
  case(rec_float("-0.4"), "0", keys = "digits=0"),
  case(rec_float("-0.0004"), "0.0%", classes = "pct"),
  case(rec_float("-0.0004"), "0%", classes = "pct", keys = "digits=0"),
  case(rec_dec("-0.0049"), "0.00", keys = "digits=2"),
  case(rec_dec("-0.005"), paste0(M, "0.01"), keys = "digits=2"),
  case(rec_dec("-0.00004"), "0.00%", classes = "pct", keys = "digits=2"),
  case(rec_float("-1e-12"), "0"),
  case(rec_float("5.551115123125783e-17"), "0"),
  case(rec_float("5.551115123125783e-17"), "0.0", keys = "digits=1"),
  case(rec_float("5.551115123125783e-17"), "0%", classes = "pct"),
  # the thousands mark, default from 1000
  case(rec_int("999"), "999"),
  case(rec_int("1000"), "1,000"),
  case(rec_int("-1000"), paste0(M, "1,000")),
  case(rec_float("999.5"), "999.5"),
  case(rec_float("1234.5"), "1,234.5"),
  # configuration: marks, thousands_from, minus, digits
  case(rec_float("1234567.891"), "1 234 567.9", config = cfg(big_mark = " ")),
  case(rec_float("1234567.891"), "1 234 567.9", config = cfg(big_mark = " ")),
  case(rec_float("1234567.891"), "1.234.567,9", config = cfg(big_mark = ".", decimal_mark = ",")),
  case(rec_float("1234567.891"), "1'234'567.9", config = cfg(big_mark = "'")),
  case(rec_int("1234567890123456789012"), "1 234 567 890 123 456 789 012", config = cfg(big_mark = " ")),
  case(rec_dec("1234567.125"), "1 234 567,13", keys = "digits=2", config = cfg(big_mark = " ", decimal_mark = ",")),
  case(rec_float("1234.5"), "123 450%", classes = "pct", config = cfg(big_mark = " ")),
  case(rec_float("3.14159"), "3,1", config = cfg(decimal_mark = ",")),
  case(rec_dec("0.123"), "12,3%", classes = "pct", keys = "digits=1", config = cfg(decimal_mark = ",")),
  case(rec_int("9999"), "9999", config = cfg(thousands_from = 10000L)),
  case(rec_int("10000"), "10,000", config = cfg(thousands_from = 10000L)),
  case(rec_int("-9999"), paste0(M, "9999"), config = cfg(thousands_from = 10000L)),
  case(rec_float("9999.5"), "9999.5", config = cfg(thousands_from = 10000L)),
  case(rec_int("1234567"), "1,234,567", config = cfg(thousands_from = 1000L)),
  case(rec_float("-2.5"), "-2.5", config = cfg(minus = "-")),
  case(rec_dec("-0.125"), "-0.13", keys = "digits=2", config = cfg(minus = "-")),
  case(rec_int("-1234"), "-1,234", config = cfg(minus = "-")),
  case(rec_float("-0.0004"), "0.0%", classes = "pct", config = cfg(minus = "-")),
  case(rec_float("3.14159"), "3.14", config = cfg(digits = 2L)),
  case(rec_float("3"), "3", config = cfg(digits = 2L)),
  case(rec_float("3.14159"), "3.1", keys = "digits=1", config = cfg(digits = 2L)),
  case(rec_float("3.14159"), "3.14", keys = "sigfig=3", config = cfg(digits = 4L)),
  case(rec_dec("2.675"), "2.675", config = cfg(digits = 3L)),
  case(rec_float("0.04"), "0.040", config = cfg(digits = 3L)),
  case(rec_float("0.0004"), "0.00", config = cfg(digits = 2L)),
  case(rec_float("1234.5"), "1,234.5", config = cfg(digits = 1L, big_mark = ",", decimal_mark = ".")),
  case(rec_float("1234567.891"), "1.234.567,891", config = cfg(digits = 3L, big_mark = ".", decimal_mark = ","))
))

test_that("6a N85: ties, exact decimals and ints, negative zero, marks and configuration, case by case", {
  expect_gte(nrow(CASES), 90)
  for_each_pandoc(function(p) {
    res <- lua_num_table(CASES[, c("record", "classes", "keys")], config = CASES$config, pandoc = p)
    got <- ifelse(res$ok, res$text, paste0("<<error: ", res$err, ">>"))
    bad <- which(got != CASES$text)
    expect(length(bad) == 0, paste0(
      length(bad), " of ", nrow(CASES), " cases differ (pandoc ", p$version, "); first:\n",
      paste(vapply(utils::head(bad, 8), function(i) {
        sprintf("  %s %s %s %s\n    printed: %s\n    wanted:  %s", CASES$record[i], CASES$classes[i],
                CASES$keys[i], CASES$config[i], got[i], CASES$text[i])
      }, ""), collapse = "\n")))
  })
})

test_that("6a N85: the configuration given to one call does not leak into the next", {
  rows <- do.call(rbind, list(
    case(rec_float("1234567.891"), "1 234 567,9"),
    case(rec_float("1234567.891"), "1,234,567.9"),
    case(rec_float("-2.5"), "-2.5"),
    case(rec_float("-2.5"), paste0(M, "2.5"))))
  cf <- c(cfg(big_mark = " ", decimal_mark = ","), "", cfg(minus = "-"), "")
  for_each_pandoc(function(p) {
    res <- lua_num_table(rows[, c("record", "classes", "keys")], config = cf, pandoc = p)
    expect_identical(res$text, rows$text)
  })
})

# ---- the printed record: zero, one, two, decimals ---------------------------------------------------------

test_that("6a N85: the printed info (zero, one, two, decimals, relation) comes from the printed text", {
  rows <- do.call(rbind, list(
    case(rec_float("0"), "0", keys = ""),
    case(rec_int("0"), "0"),
    case(rec_float("1"), "1"),
    case(rec_float("1"), "1.0", keys = "digits=1"),
    case(rec_float("2"), "2"),
    case(rec_int("2"), "2"),
    case(rec_float("0.04"), "0.0"),
    case(rec_float("-0.04"), "0.0"),
    case(rec_float("0.96"), "1.0", keys = "digits=1"),
    case(rec_float("1.04"), "1.0"),
    case(rec_float("1.5"), "1.5"),
    case(rec_float("3"), "3"),
    case(rec_dec("1.00"), "1")))
  #            zero   one    two    decimals
  want <- rbind(c(TRUE, FALSE, FALSE, FALSE),
                c(TRUE, FALSE, FALSE, FALSE),
                c(FALSE, TRUE, FALSE, FALSE),
                c(FALSE, TRUE, FALSE, TRUE),
                c(FALSE, FALSE, TRUE, FALSE),
                c(FALSE, FALSE, TRUE, FALSE),
                c(TRUE, FALSE, FALSE, TRUE),
                c(TRUE, FALSE, FALSE, TRUE),
                c(FALSE, TRUE, FALSE, TRUE),
                c(FALSE, TRUE, FALSE, TRUE),
                c(FALSE, FALSE, FALSE, TRUE),
                c(FALSE, FALSE, FALSE, FALSE),
                c(FALSE, TRUE, FALSE, FALSE))
  for_each_pandoc(function(p) {
    res <- lua_num_table(rows[, c("record", "classes", "keys")], pandoc = p)
    expect_true(all(res$ok), info = paste(res$err, collapse = "; "))
    expect_identical(res$text, rows$text)
    for (i in seq_len(nrow(rows))) {
      inf <- res$info[[i]]
      lab <- paste(rows$record[i], rows$keys[i])
      expect_identical(inf$zero, want[i, 1], info = paste("zero:", lab))
      expect_identical(inf$one, want[i, 2], info = paste("one:", lab))
      expect_identical(inf$two, want[i, 3], info = paste("two:", lab))
      expect_identical(inf$decimals, want[i, 4], info = paste("decimals:", lab))
      expect_identical(inf$relation, "=", info = lab)
    }
  })
})

test_that("6a N85: info.number is the number as printed", {
  rows <- do.call(rbind, list(
    case(rec_float("3.14159"), "3.1", keys = "digits=1"),
    case(rec_float("3"), "3"),
    case(rec_float("-2.5"), paste0(M, "2.5")),
    case(rec_dec("0.125"), "0.13", keys = "digits=2"),
    case(rec_float("0.04"), "0.0"),
    case(rec_int("1234567"), "1,234,567")))
  want <- c(3.1, 3, -2.5, 0.13, 0, 1234567)
  for_each_pandoc(function(p) {
    res <- lua_num_table(rows[, c("record", "classes", "keys")], pandoc = p)
    got <- vapply(res$info, function(i) as.numeric(i$number), numeric(1))
    expect_equal(got, want, tolerance = 1e-12)
  })
})

# ---- not implemented is loud ------------------------------------------------------------------------------

test_that("6a N83, N85: an unimplemented class fails loudly, never a pass-through", {
  for (cl in c("sci", "word", "count", "ord", "no", "and", "p", "date", "uname", "usym", "nounit", "val", "foo")) {
    rows <- lua_row(rec_float("3.14159"), cl)
    for_each_pandoc(function(p) {
      r <- lua_num_table(rows, pandoc = p)
      expect_false(r$ok, info = cl)
      expect_identical(r$text, "", info = cl)
      expect_match(r$err, "not implemented", fixed = TRUE, info = cl)
      expect_match(r$err, paste0("(^|[^A-Za-z])", cl, "([^A-Za-z]|$)"), info = cl)
    })
  }
})

test_that("6a N83, N85: an unimplemented key fails loudly, and so do digits with sigfig", {
  bad <- c("unit=m", "unit_form=name", "trunc=3", "sep=x", "none=zero", "digits=1 unit=m")
  rows <- do.call(rbind, lapply(bad, function(k) lua_row(rec_float("3.14159"), "num", k)))
  for_each_pandoc(function(p) {
    r <- lua_num_table(rows, pandoc = p)
    expect_false(any(r$ok), info = paste(bad[r$ok], collapse = "; "))
    expect_true(all(r$text == ""))
    key <- sub("=.*$", "", sub("^digits=1 ", "", bad))
    for (i in seq_along(bad)) expect_match(r$err[i], key[i], fixed = TRUE, info = bad[i])
    expect_true(all(grepl("not implemented", r$err, fixed = TRUE)))
  })
  both <- lua_row(rec_float("3.14159"), "num", "digits=1 sigfig=2")
  for_each_pandoc(function(p) {
    r <- lua_num_table(both, pandoc = p)
    expect_false(r$ok)
    expect_true(nzchar(r$err))
  })
})

test_that("6a N83, N85: a record this printer cannot print fails loudly, naming its kind", {
  recs <- c(bool = '{"t":"bool","v":true}',
            string = '{"t":"string","v":"3.1"}',
            date = '{"t":"date","v":"2026-11-13"}',
            list = '{"t":"list","v":[{"t":"int","v":"1"},{"t":"int","v":"2"}],"of":"int","keys":null}',
            missing = '{"t":"missing","why":"NA"}',
            error = '{"t":"error","why":"the fit failed"}',
            nosuchkind = '{"t":"nosuchkind","v":"1"}')
  rows <- do.call(rbind, lapply(recs, lua_row))
  for_each_pandoc(function(p) {
    for (cl in IMPLEMENTED) {
      rows$classes <- cl
      r <- lua_num_table(rows, pandoc = p)
      expect_false(any(r$ok), info = paste(cl, paste(names(recs)[r$ok], collapse = ", ")))
      expect_true(all(r$text == ""))
      for (i in seq_along(recs)) expect_match(r$err[i], names(recs)[i], fixed = TRUE, info = paste(cl, names(recs)[i]))
    }
  })
})

test_that("6a N83, N85: a malformed record fails loudly", {
  recs <- c('{"t":"float"}', '{"t":"float","v":"abc"}', '{"t":"float","v":3.5}', '{"v":"3"}',
            '{"t":"int","v":"01"}', '{"t":"int","v":"1.5"}', '{"t":"int","v":"1e3"}', '{"t":"int","v":""}',
            '{"t":"decimal","v":"1,5"}', '{"t":"decimal","v":".5"}', '{"t":"decimal","v":"5."}',
            '{"t":"float","v":"NaN"}', '{"t":"float","v":"Inf"}', 'null', '3', '"3"', '[]')
  rows <- do.call(rbind, lapply(recs, lua_row))
  for_each_pandoc(function(p) {
    r <- lua_num_table(rows, pandoc = p)
    expect_false(any(r$ok), info = paste(recs[r$ok], collapse = "; "))
    expect_true(all(r$text == ""))
    expect_true(all(nzchar(r$err)))
  })
})

test_that("6a N85: a record with extra members (type, checks) still prints", {
  rows <- do.call(rbind, list(
    lua_row('{"t":"float","v":"3.14159","type":"numeric"}'),
    lua_row('{"t":"int","v":"7","type":"integer","checks":[{"text":"> 1","ok":true,"level":"fail","why":null}]}')))
  for_each_pandoc(function(p) {
    r <- lua_num_table(rows, pandoc = p)
    expect_identical(r$text, c("3.1", "7"), info = paste(r$err, collapse = "; "))
  })
})
