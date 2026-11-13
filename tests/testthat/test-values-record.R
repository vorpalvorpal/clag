# Package 6b, rules N20 to N22, N45 and N47 (dev/design-6.md): the record an R
# value becomes, as the JSON weft_put() writes it. Outside a knit weft_put()
# returns the block's text (N44), which b6_parse() reads. Helpers: helper-6b.R.

# N47's number rule, written out: the first of %.15g, %.16g, %.17g that reads
# back as the same double
shortest_text <- function(x) {
  for (d in c(15L, 16L, 17L)) {
    s <- sprintf(paste0("%.", d, "g"), x)
    if (identical(as.numeric(s), x)) return(s)
  }
  s
}

number_re <- "^-?[0-9]+(\\.[0-9]+)?([eE][+-]?[0-9]+)?$"

# ---- scalars ---------------------------------------------------------------

test_that("N47: logical scalars are bool records, with JSON true and false", {
  b6_expect_rec(TRUE, b6_e_bool(TRUE))
  b6_expect_rec(FALSE, b6_e_bool(FALSE))
  # the JSON text itself holds the bare words, not strings
  expect_match(b6_text(weft::weft_put(v = TRUE)), "\"v\":{\"t\":\"bool\",\"v\":true}",
               fixed = TRUE)
})

test_that("N47: an integer scalar is an int record, its digits as a string", {
  b6_expect_rec(5L, b6_e_int("5"))
  b6_expect_rec(-3L, b6_e_int("-3"))
  b6_expect_rec(0L, b6_e_int("0"))
  b6_expect_rec(.Machine$integer.max, b6_e_int("2147483647"))
  expect_match(b6_text(weft::weft_put(v = 5L)), "\"v\":{\"t\":\"int\",\"v\":\"5\"}",
               fixed = TRUE)
})

test_that("N47: a finite double is a float record with the shortest round-trip text", {
  cases <- list(
    list(0.1, "0.1"),
    list(3.14159, "3.14159"),
    list(-2.5, "-2.5"),
    list(0, "0"),
    list(3, "3"),                       # whole doubles stay float
    list(100, "100"),
    list(1 / 3, "0.3333333333333333"),
    list(0.1 + 0.2, "0.30000000000000004"),
    list(2^53, "9007199254740992"),
    list(1e23, "1e+23"),
    list(1e15, "1e+15"),                # %.15g switches to an exponent at 15 digits
    list(1e-5, "1e-05"),
    list(-0.0, "-0")
  )
  for (cs in cases) {
    b6_expect_rec(cs[[1]], b6_e_float(cs[[2]]), info = paste("x =", cs[[2]]))
  }
})

test_that("N47: the float text is the first of %.15g, %.16g, %.17g that reads back, and matches N22's shape", {
  xs <- c(0.1, 0.2, 0.3, 1 / 3, 2 / 3, 0.1 + 0.2, pi, exp(1), sqrt(2), 1e23, 1e-7,
          123456.789, 2^53, 2^53 + 2, 1 / 7, 1e100, 5e-324,
          -0.0, 12345678901234567890, 0.007, 100)
  for (x in xs) {
    rec <- b6_rec(x)
    expect_identical(rec$t, "float", info = format(x, digits = 17))
    expect_identical(rec$v, shortest_text(x), info = format(x, digits = 17))
    expect_match(rec$v, number_re, info = format(x, digits = 17))
    expect_identical(as.numeric(rec$v), x, info = format(x, digits = 17))
  }
})

test_that("N47: a string, and a factor (its level), are string records", {
  b6_expect_rec("depth", b6_e_str("depth"))
  b6_expect_rec("", b6_e_str(""))
  b6_expect_rec(factor("north", levels = c("north", "south")), b6_e_str("north"))
  # control: the level, not the integer code
  b6_expect_rec(factor("south", levels = c("north", "south")), b6_e_str("south"))
})

test_that("N47: a string with quotes, a newline, a backslash and non-ASCII text survives the JSON", {
  s <- "a \"quote\", a back\\slash,\nand café − `````"
  rec <- b6_rec(s)
  expect_identical(rec$t, "string")
  expect_identical(rec$v, s)
  # one line, so a backtick run inside cannot close the four-backtick fence (N20)
  txt <- weft::weft_put(v = s)
  expect_false(grepl("\n", b6_text(txt), fixed = TRUE))
})

test_that("N47: a Date scalar is a date record, ISO form", {
  b6_expect_rec(as.Date("2026-11-13"), b6_e_date("2026-11-13"))
  b6_expect_rec(as.Date("2024-02-29"), b6_e_date("2024-02-29"))
})

# ---- missing ---------------------------------------------------------------

test_that("N47: NA of any type is a missing record with why \"NA\"", {
  for (x in list(NA, NA_integer_, NA_real_, NA_character_, as.Date(NA),
                 factor(NA, levels = "a"))) {
    b6_expect_rec(x, b6_e_miss("NA"), info = paste(class(x), collapse = "/"))
  }
})

test_that("N47: NaN, Inf and -Inf are missing records, why the word", {
  b6_expect_rec(NaN, b6_e_miss("NaN"))
  b6_expect_rec(Inf, b6_e_miss("Inf"))
  b6_expect_rec(-Inf, b6_e_miss("-Inf"))
})

test_that("N47: NULL is a missing record with why \"NULL\"", {
  b6_expect_rec(NULL, b6_e_miss("NULL"))
})

test_that("N22: a missing record has no value (absent or null)", {
  rec <- b6_rec(NA_real_)
  expect_identical(rec$t, "missing")
  expect_null(rec$v)
})

# ---- named scalars ---------------------------------------------------------

test_that("N47: a length-1 named vector is a scalar and its name is dropped", {
  b6_expect_rec(c(a = 2L), b6_e_int("2"))
  b6_expect_rec(c(depth = 3.5), b6_e_float("3.5"))
  b6_expect_rec(c(k = "x"), b6_e_str("x"))
  rec <- b6_rec(c(depth = 3.5))
  expect_identical(rec$t, "float")
})

# ---- vectors ---------------------------------------------------------------

test_that("N47: an atomic vector of two or more is a list record with `of` its kind", {
  b6_expect_rec(c(1L, 2L, 3L),
                b6_e_list("int", list(b6_e_int("1"), b6_e_int("2"), b6_e_int("3"))))
  b6_expect_rec(c(1.5, 2),
                b6_e_list("float", list(b6_e_float("1.5"), b6_e_float("2"))))
  b6_expect_rec(c("a", "b"),
                b6_e_list("string", list(b6_e_str("a"), b6_e_str("b"))))
  b6_expect_rec(c(TRUE, FALSE),
                b6_e_list("bool", list(b6_e_bool(TRUE), b6_e_bool(FALSE))))
  b6_expect_rec(as.Date(c("2026-01-02", "2026-03-04")),
                b6_e_list("date", list(b6_e_date("2026-01-02"), b6_e_date("2026-03-04"))))
})

test_that("N47: a factor of length 2 or more is a list of strings (the levels)", {
  b6_expect_rec(factor(c("n", "s"), levels = c("s", "n")),
                b6_e_list("string", list(b6_e_str("n"), b6_e_str("s"))))
})

test_that("N47: elements that are NA, NaN or Inf are missing records inside the list, and `of` is the kind of the rest", {
  b6_expect_rec(c(1L, NA),
                b6_e_list("int", list(b6_e_int("1"), b6_e_miss("NA"))))
  b6_expect_rec(c(1, NaN, Inf, -Inf),
                b6_e_list("float", list(b6_e_float("1"), b6_e_miss("NaN"),
                                        b6_e_miss("Inf"), b6_e_miss("-Inf"))))
  b6_expect_rec(c("a", NA),
                b6_e_list("string", list(b6_e_str("a"), b6_e_miss("NA"))))
})

test_that("N47: a vector whose every element is missing has `of` \"missing\"", {
  b6_expect_rec(c(NA, NA),
                b6_e_list("missing", list(b6_e_miss("NA"), b6_e_miss("NA"))))
  b6_expect_rec(c(NA_real_, NaN),
                b6_e_list("missing", list(b6_e_miss("NA"), b6_e_miss("NaN"))))
})

test_that("N47: names of a vector give `keys`, and an unnamed vector has none", {
  b6_expect_rec(c(a = 1L, b = 2L),
                b6_e_list("int", list(b6_e_int("1"), b6_e_int("2")), keys = c("a", "b")))
  b6_expect_rec(c(x = "p", y = "q", z = "r"),
                b6_e_list("string", list(b6_e_str("p"), b6_e_str("q"), b6_e_str("r")),
                          keys = c("x", "y", "z")))
  rec <- b6_rec(c(1L, 2L))
  expect_null(rec$keys)
  # keys is as long as v
  rec <- b6_rec(c(a = 1, b = 2))
  expect_length(rec$keys, length(rec$v))
})

test_that("N47: a vector of length zero is a list record with no elements", {
  b6_expect_rec(integer(0), b6_e_list("int", list()))
  b6_expect_rec(numeric(0), b6_e_list("float", list()))
  b6_expect_rec(character(0), b6_e_list("string", list()))
  b6_expect_rec(logical(0), b6_e_list("bool", list()))
  b6_expect_rec(as.Date(character()), b6_e_list("date", list()))
  # control: NULL is not a zero-length vector, it is missing
  expect_identical(b6_rec(NULL)$t, "missing")
})

test_that("N22: no list record holds a list (elements are scalar records)", {
  rec <- b6_rec(c(1, 2, NA))
  for (e in rec$v) expect_false(identical(e$t, "list"))
})

test_that("N29/E42: a vector of 10000 elements is published, one of 10001 is refused", {
  rec <- b6_rec(seq_len(10000))
  expect_identical(rec$t, "list")
  expect_length(rec$v, 10000L)
  expect_error(weft::weft_put(big = seq_len(10001)), class = "weft_values_error")
  err <- tryCatch(weft::weft_put(big = seq_len(10001)), weft_values_error = function(e) e)
  expect_match(conditionMessage(err), "is a list of 10001 elements; weft publishes at most 10000",
               fixed = TRUE)
  expect_match(conditionMessage(err), "big", fixed = TRUE)
})

# ---- bit64 -----------------------------------------------------------------

test_that("N47: a bit64 integer64 is an int record, its digits", {
  skip_if_not_installed("bit64")
  b6_expect_rec(bit64::as.integer64(42), b6_e_int("42"))
  b6_expect_rec(bit64::as.integer64("9007199254740993"), b6_e_int("9007199254740993"))
  b6_expect_rec(bit64::as.integer64("-123456789012345678"), b6_e_int("-123456789012345678"))
  expect_identical(b6_rec(bit64::NA_integer64_)$t, "missing")
})

# ---- values the note refuses ----------------------------------------------

test_that("E44: a units quantity is refused, with its message and the weft_values_error class", {
  u <- units::set_units(5, "m")
  expect_error(weft::weft_put(depth = u), class = "weft_values_error")
  err <- tryCatch(weft::weft_put(depth = u), weft_values_error = function(e) e)
  expect_s3_class(err, "weft_error")
  expect_match(conditionMessage(err), "depth", fixed = TRUE)
  expect_match(conditionMessage(err),
               "is a units quantity; named values carry no units. Publish the number in the unit you mean (rule 2.13.3).",
               fixed = TRUE)
})

test_that("E45: a data frame, a list, a POSIXct and a function are error records naming their class", {
  cases <- list(
    list(data.frame(a = 1), "data.frame"),
    list(list(1, 2), "list"),
    list(as.POSIXct("2026-11-13 10:15:00", tz = "UTC"), "POSIXct"),
    list(function(x) x, "function")
  )
  for (cs in cases) {
    rec <- b6_rec(cs[[1]])
    expect_identical(rec$t, "error", info = cs[[2]])
    expect_null(rec$v)
    expect_true(startsWith(rec$why, "{S}"), info = cs[[2]])
    expect_match(rec$why,
                 sprintf("is an R %s, which weft does not publish. Publish a bool, number, string, Date, or a vector of one of these (rule 1.11.1).",
                         cs[[2]]),
                 fixed = TRUE)
  }
})

test_that("E45: a refusal of one name does not stop the other names of the call", {
  blk <- b6_parse(weft::weft_put(ok = 1L, bad = data.frame(a = 1), also = "x"))
  expect_identical(blk$values$ok$t, "int")
  expect_identical(blk$values$bad$t, "error")
  expect_identical(blk$values$also$t, "string")
})

# ---- the JSON written ---------------------------------------------------------

test_that("N20/N21: the block is one JSON object of schema 1, valid, with the fixed key order", {
  txt <- b6_text(weft::weft_put(depth = 3.14159))
  expect_true(jsonlite::validate(txt))
  blk <- b6_read_json(txt)
  expect_identical(blk$weft, 1L)
  expect_identical(blk$lang, "r")
  expect_true(is.list(blk$values))
  keys <- b6_keys(txt)
  expect_identical(keys[1:2], c("weft", "lang"))
  expect_true(all(match(c("weft", "lang", "run", "at", "values"), keys) ==
                    sort(match(c("weft", "lang", "run", "at", "values"), keys))))
  expect_true(startsWith(txt, "{\"weft\":1,\"lang\":\"r\",\"run\":"))
  # compact, no spaces after the colons, and the record's t before v
  expect_match(txt, "\"values\":{\"depth\":{\"t\":\"float\",\"v\":\"3.14159\"}}", fixed = TRUE)
})

test_that("N21: `at` is whole seconds since 1970 (an integer number in the JSON)", {
  before <- as.numeric(Sys.time())
  txt <- b6_text(weft::weft_put(a = 1))
  after <- as.numeric(Sys.time())
  expect_match(txt, "\"at\":[0-9]+[,}]")
  at <- b6_read_json(txt)$at
  expect_true(at >= floor(before) - 1 && at <= ceiling(after) + 1)
})

test_that("N20: the same call twice gives the same text, apart from the time", {
  a <- b6_text(weft::weft_put(x = 1.5, y = "s", z = c(1L, 2L)))
  b <- b6_text(weft::weft_put(x = 1.5, y = "s", z = c(1L, 2L)))
  strip <- function(s) sub("\"at\":[0-9]+", "\"at\":0", s)
  expect_identical(strip(a), strip(b))
  # a record of a list keeps t, v, of in a fixed order too
  rec <- b6_read_json(a)$values$z
  expect_identical(names(rec)[1:2], c("t", "v"))
})

test_that("N45: the names a source names", {
  p <- b6_write_doc(c(
    "---",
    "title: \"Depth `fm`{.num}\"",
    "---",
    "",
    "```{r}",
    "# the chunk may say `inchunk`{.num} too",
    "x <- 1",
    "```",
    "",
    "A value `depth`{.num} and `n.sites`{digits=\"2\"} and `_hid`{.val}.",
    "A span [one | many]{n=\"k\"} and [a | b]{if=\"flag\"} and [c | d]{sign=\"s\"}.",
    "A id `ided`{#id}, and `plain` code, and `spaced` {.num}.",
    "A guard [yes | no]{IF=\"cmp > 10, site == 'north', lim <= other\"}.",
    "A [lst]{list=\"items\"}."
  ))
  got <- sort(weft:::values_source_names(p))
  expect_identical(got, sort(c("fm", "inchunk", "depth", "n.sites", "_hid", "k", "flag", "s",
                               "cmp", "site", "lim", "other", "items", "ided")))
})

test_that("N45: strings in single quotes are removed from a governor value, numbers are not names", {
  p <- b6_write_doc(c(
    "[x | y]{if=\"site == 'north south', depth > 3.5, 2 < other\"}",
    "[x | y]{if=\"'only' != 'strings' and_not_this\"}"
  ))
  got <- sort(weft:::values_source_names(p))
  expect_true(all(c("site", "depth", "other") %in% got))
  expect_false(any(c("north", "south", "only", "strings") %in% got))
  expect_false("e" %in% got)
})

test_that("N45: a key written with spaces, or single quotes, or no quotes, is not read", {
  p <- b6_write_doc(c(
    "[a | b]{n = \"spaced\"}",
    "[a | b]{n='single'}",
    "[a | b]{n=bare}",
    "[a | b]{n=\"good\"}"
  ))
  got <- weft:::values_source_names(p)
  expect_true("good" %in% got)
  expect_false(any(c("spaced", "single", "bare") %in% got))
})

test_that("N45/N6: a reserved word is never a name", {
  p <- b6_write_doc(c(
    "`TRUE`{.val} `NA`{.val} `NULL`{.val} `Inf`{.val} `NaN`{.val} `None`{.val} `true`{.val}",
    "`nothing`{.val} `missing`{.val} `False`{.val} `real`{.val}",
    "[a | b]{if=\"x > NA, y == NULL, z\"}"
  ))
  got <- weft:::values_source_names(p)
  expect_false(any(c("TRUE", "NA", "NULL", "Inf", "NaN", "None", "true", "nothing", "missing",
                     "False") %in% got))
  expect_true(all(c("real", "x", "y", "z") %in% got))
})

test_that("N45: only a code span whose backtick, name, backtick, brace touch counts", {
  p <- b6_write_doc(c("`aa` {.num}", "`bb`", "`cc`{.num}", "`dd x`{.num}", "`ee`[x]"))
  got <- weft:::values_source_names(p)
  expect_true("cc" %in% got)
  expect_false(any(c("aa", "bb", "ee") %in% got))
})

test_that("N45: names in a file the source includes are taken, relative to the source, recursively", {
  dir <- withr::local_tempdir()
  dir.create(file.path(dir, "sub"))
  p <- b6_write_doc(c("A `top`{.num}.", "{{< include sub/one.Rmd >}}"), dir = dir,
                    extra = list("sub/one.Rmd" = c("A `mid`{.num}.", "{{< include two.Rmd >}}"),
                                 "sub/two.Rmd" = "A `deep`{.num}."))
  got <- sort(weft:::values_source_names(p))
  expect_identical(got, c("deep", "mid", "top"))
})

test_that("N45: an include that includes itself does not loop, and a missing include is not an error", {
  dir <- withr::local_tempdir()
  p <- b6_write_doc(c("`a`{.num}", "{{< include doc.Rmd >}}", "{{< include gone.Rmd >}}"),
                    dir = dir)
  got <- weft:::values_source_names(p)
  expect_identical(sort(got), "a")
})

test_that("N45: the result has no repeats", {
  p <- b6_write_doc(c("`a`{.num} `a`{.num} [x | y]{if=\"a > 1\"}"))
  expect_identical(weft:::values_source_names(p), "a")
})
