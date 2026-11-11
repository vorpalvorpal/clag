# Package 2a: the dictionary object, read_dict() and u() (no render).
# Contract: dev/design-2.md section 2 (2a), decisions D1-D22, section 9.
# Fixture: tests/testthat/_dict/dict.yml (the contract's example).
# Helpers: helper-2a.R.

FX_KEYS <- c("min_samples", "core_len", "reach_len", "sample_mass",
             "salinity_res", "coliform_limit", "site_density", "method_change",
             "survey_start", "region_name", "zone_lab", "trend_word")

fx <- function() read_dict(a2_fixture())

# ---- exports and methods ---------------------------------------------------------

test_that("2a exports: read_dict and u are exported, and the weft_dict methods are registered (2.1)", {
  expect_true(all(c("read_dict", "u") %in% getNamespaceExports("weft")))
  for (g in c("$", "[[", "[", "$<-", "[[<-", "[<-", "print", "as.list")) {
    expect_false(is.null(utils::getS3method(g, "weft_dict", optional = TRUE)),
                 label = paste("S3 method", g, "for weft_dict"))
  }
})

# ---- read_dict() on the fixture -----------------------------------------------------

test_that("2a read: the fixture reads as a weft_dict whose names are the keys in file order (4.1.1)", {
  d <- fx()
  expect_s3_class(d, "weft_dict")
  expect_identical(names(d), FX_KEYS)
  expect_identical(length(d), 12L)
})

test_that("2a read: each type is read as its R class (4.2.1)", {
  d <- fx()
  expect_true(is.numeric(d$min_samples))
  expect_false(inherits(d$min_samples, "units"))
  expect_equal(d$min_samples, 0.5 * 10)
  expect_s3_class(d$core_len, "units")
  expect_s3_class(d$salinity_res, "units")
  expect_type(d$method_change, "integer")
  expect_s3_class(d$method_change, "weft_year")
  expect_identical(as.integer(d$method_change), 2014L)
  expect_s3_class(d$survey_start, "Date")
  expect_identical(format(d$survey_start), "2024-06-01")
  expect_type(d$region_name, "character")
  expect_identical(d$region_name, "Northern catchment")
  expect_true(is.function(d$zone_lab))
  expect_true(is.function(d$trend_word))
})

test_that("2a read: a quantity is the value in its unit (4.2.1)", {
  d <- fx()
  expect_qty(d$core_len, 0.5, "m")
  expect_qty(d$sample_mass, 3, "kg")
  expect_qty(d$salinity_res, 0.01, "PSU")
  expect_qty(d$site_density, 4, "sites/ha")
  expect_qty(d$coliform_limit, 150, "CFU/100 mL")
})

test_that("2a read: labels is a lookup() function, and the YAML words yes and no stay text (4.2.3, D6)", {
  d <- fx()
  expect_identical(as.character(d$zone_lab("yes")), "Included")
  expect_identical(as.character(d$zone_lab("no")), "Excluded")
  expect_identical(as.character(d$zone_lab("upper")), "Upper reach")
  expect_identical(as.character(d$zone_lab(c("lower", "yes"))), c("Lower reach", "Included"))
  expect_error(d$zone_lab("middle"))                      # an unknown label is an error, as lookup()
})

test_that("2a read: breaks is a brk() function with below as < and at_most as <= (4.2.1)", {
  d <- fx()
  expect_identical(as.character(d$trend_word(c(0.9, 1, 1.05, 2))),
                   c("a fall in", "steady", "steady", "a rise in"))
  expect_identical(as.character(d$trend_word(0.95)), "steady")   # below is strict
})

test_that("2a read: attributes file, scope, entries, registered, local_keys (the object)", {
  p <- a2_fixture()
  d <- read_dict(p)
  expect_identical(attr(d, "file"), p)
  expect_identical(attr(d, "scope"), "project")
  expect_type(attr(d, "registered"), "character")
  expect_identical(attr(d, "local_keys"), character())
  e <- attr(d, "entries")
  expect_s3_class(e, "data.frame")
  expect_identical(names(e), c("key", "type", "definition", "unit", "decision", "why", "line"))
  expect_identical(e$key, FX_KEYS)
  expect_identical(e$type, c("number", "quantity", "quantity", "quantity", "quantity",
                             "quantity", "quantity", "year", "date", "string", "labels", "breaks"))
  expect_identical(e$definition[e$key == "core_len"], "Length of each sediment core.")
  expect_identical(e$unit[e$key == "core_len"], "m")
  expect_identical(e$unit[e$key == "coliform_limit"], "CFU/100 mL")
  expect_true(is.na(e$unit[e$key == "min_samples"]))
  expect_true(all(is.na(e$why)))
  # decision is character; NA where absent
  expect_identical(e$decision[e$key == "method_change"], "31")
  expect_identical(e$decision[e$key == "zone_lab"], "zones-2023")
  expect_true(is.na(e$decision[e$key == "core_len"]))
  # line is the line of the key's own `key:` line
  src <- a2_fixture_lines()
  want <- vapply(FX_KEYS, function(k) grep(paste0("^", k, ":"), src)[1], integer(1))
  expect_equal(unname(e$line), unname(want))
})

test_that("2a read: as.list() returns the plain named list of values (the object)", {
  d <- fx()
  l <- as.list(d)
  expect_identical(class(l), "list")
  expect_identical(names(l), FX_KEYS)
  expect_s3_class(l$core_len, "units")
  expect_identical(names(attributes(l)), "names")
})

test_that("2a read: reading is repeatable and read_dict() starts nothing (control)", {
  expect_equal(as.list(fx()), as.list(fx()))
})

# ---- $ and [[ -------------------------------------------------------------------------

test_that("2a access: $ and [[ return the value by exact key (4.1.2)", {
  d <- fx()
  expect_identical(d$min_samples, d[["min_samples"]])
  expect_qty(d$reach_len, 2, "m")
  expect_qty(d[["reach_len"]], 2, "m")
})

test_that("2a access: a partial name is an error, never a partial match or NULL (4.1.2)", {
  d <- fx()
  e <- a2_err(d$core)                          # `core_len` is held
  expect_weft_cond(e, "weft_dict_key_error", "dict$core")
  expect_match(conditionMessage(e), "`dict$core`", fixed = TRUE)
  expect_match(conditionMessage(e), "no such key", fixed = TRUE)
  expect_match(conditionMessage(e), a2_fixture(), fixed = TRUE)
  expect_match(conditionMessage(e), "rule 4.1.2", fixed = TRUE)
  e2 <- a2_err(d[["core"]])
  expect_weft_cond(e2, "weft_dict_key_error", "dict[['core']]")
  expect_match(conditionMessage(e2), "core", fixed = TRUE)
  # control: the exact name works
  expect_s3_class(d$core_len, "units")
})

test_that("2a access: an unknown key is a weft_dict_key_error naming the key and the file (4.1.2)", {
  d <- fx()
  e <- a2_err(d$nothing_like_it)
  expect_weft_cond(e, "weft_dict_key_error", "unknown key")
  expect_match(conditionMessage(e), "`dict$nothing_like_it`", fixed = TRUE)
  expect_match(conditionMessage(e), a2_fixture(), fixed = TRUE)
  expect_false(grepl("Did you mean", conditionMessage(e), fixed = TRUE))   # nothing within 2
  e2 <- a2_err(d[["nothing_like_it"]])
  expect_weft_cond(e2, "weft_dict_key_error", "unknown key [[")
})

test_that("2a access: a key within edit distance 2 of exactly one key is suggested (D21)", {
  d <- fx()
  e <- a2_err(d$core_lne)
  expect_weft_cond(e, "weft_dict_key_error", "dict$core_lne")
  expect_match(conditionMessage(e), "Did you mean `core_len`?", fixed = TRUE)
  e2 <- a2_err(d[["core_lne"]])
  expect_match(conditionMessage(e2), "Did you mean `core_len`?", fixed = TRUE)
  # with two keys equally close there is no suggestion
  d2 <- read_dict(a2_file(c(
    "abc1: {value: 1, type: number, definition: one}",
    "abc2: {value: 2, type: number, definition: two}")))
  e3 <- a2_err(d2$abc3)
  expect_weft_cond(e3, "weft_dict_key_error", "two near keys")
  expect_false(grepl("Did you mean", conditionMessage(e3), fixed = TRUE))
})

test_that("2a access: [[ with a number, or with anything but one string, is a weft_dict_key_error (4.1.2)", {
  d <- fx()
  expect_weft_cond(a2_err(d[[1]]), "weft_dict_key_error", "[[1]]")
  expect_weft_cond(a2_err(d[[1L]]), "weft_dict_key_error", "[[1L]]")
  expect_weft_cond(a2_err(d[[c("core_len", "reach_len")]]), "weft_dict_key_error", "[[two strings]]")
  expect_weft_cond(a2_err(d[[NULL]]), "weft_dict_key_error", "[[NULL]]")
  expect_weft_cond(a2_err(d[[TRUE]]), "weft_dict_key_error", "[[TRUE]]")
})

test_that("2a access: [ is a weft_dict_error that says to use dict$key or dict[[\"key\"]] (4.1.2)", {
  d <- fx()
  for (e in list(a2_err(d["core_len"]), a2_err(d[1:2]), a2_err(d[]))) {
    expect_weft_cond(e, "weft_dict_error", "dict[...]")
    expect_match(conditionMessage(e), "use dict$key or dict[[\"key\"]]", fixed = TRUE)
  }
})

test_that("2a access: the three assignment forms are a read-only weft_dict_error (4.1.4)", {
  d <- fx()
  errs <- list(
    a2_err({ d$core_len <- 1 }),
    a2_err({ d$brand_new <- 1 }),
    a2_err({ d[["core_len"]] <- 1 }),
    a2_err({ d[["brand_new"]] <- 1 }),
    a2_err({ d["core_len"] <- 1 }),
    a2_err({ d[c("a", "b")] <- 1:2 })
  )
  for (e in errs) {
    expect_weft_cond(e, "weft_dict_error", "assignment")
    expect_match(conditionMessage(e), "the dictionary is read-only; change dict.yml", fixed = TRUE)
    expect_match(conditionMessage(e), "rule 4.1.4", fixed = TRUE)
  }
  # the dictionary is unchanged
  expect_qty(d$core_len, 0.5, "m")
  expect_identical(names(d), FX_KEYS)
})

# ---- print ------------------------------------------------------------------------------

test_that("2a print: a header with the file and key count, then a line per key (the object)", {
  d <- fx()
  out <- capture.output(print(d))
  txt <- paste(out, collapse = "\n")
  expect_match(out[1], "<weft_dict>", fixed = TRUE)
  expect_match(out[1], a2_fixture(), fixed = TRUE)
  expect_match(out[1], "12 keys", fixed = TRUE)
  for (k in FX_KEYS) expect_match(txt, k, fixed = TRUE)
  expect_match(grep("core_len", out, value = TRUE)[1], "quantity", fixed = TRUE)
  expect_match(txt, "0.01 PSU", fixed = TRUE)
  expect_match(txt, "2024-06-01", fixed = TRUE)
  expect_match(txt, "4 labels", fixed = TRUE)
  expect_match(txt, "3 bands", fixed = TRUE)
})

# ---- schema errors ----------------------------------------------------------------------

BASE_ENTRY <- "base: {value: 1, type: number, definition: \"Base.\"}"
GOOD <- function(k = "a") sprintf("%s: {value: 1, type: number, definition: \"Fine.\"}", k)

# name, lines, key (NULL: no key), field(s) the problem line must name, other text it must hold
SCHEMA_CASES <- list(
  list("missing value", c(BASE_ENTRY, "a:", "  type: number", "  definition: x"), "a", "value"),
  list("missing type", c(BASE_ENTRY, "a:", "  value: 1", "  definition: x"), "a", "type"),
  list("missing definition", c(BASE_ENTRY, "a:", "  value: 1", "  type: number"), "a", "definition"),
  list("blank definition", c(BASE_ENTRY, "a: {value: 1, type: number, definition: \"  \"}"), "a", "definition"),
  list("unknown type", c(BASE_ENTRY, "a: {value: 1, type: float, definition: x}"), "a", "type",
       c("float", "number", "quantity", "year", "date", "string", "labels", "breaks")),
  list("unknown field", c(BASE_ENTRY, "a: {value: 1, type: number, definition: x, colour: red}"), "a", "colour",
       c("value", "type", "definition", "unit", "decision", "why")),
  list("unit on a number", c(BASE_ENTRY, "a: {value: 1, type: number, unit: m, definition: x}"), "a", "unit"),
  list("unit on a string", c(BASE_ENTRY, "a: {value: x, type: string, unit: m, definition: x}"), "a", "unit"),
  list("quantity without unit", c(BASE_ENTRY, "a: {value: 1, type: quantity, definition: x}"), "a", "unit"),
  list("key file", c(BASE_ENTRY, "file: {value: 1, type: number, definition: x}"), "file", "file"),
  list("key 2x", c(BASE_ENTRY, "2x: {value: 1, type: number, definition: x}"), "2x", "2x"),
  list("key if", c(BASE_ENTRY, "if: {value: 1, type: number, definition: x}"), "if", "if"),
  list("year 214", c(BASE_ENTRY, "a: {value: 214, type: year, definition: x}"), "a", "value"),
  list("year 2014.5", c(BASE_ENTRY, "a: {value: 2014.5, type: year, definition: x}"), "a", "value"),
  list("date 2024-02-30", c(BASE_ENTRY, "a: {value: \"2024-02-30\", type: date, definition: x}"), "a", "value"),
  list("string given 0.10", c(BASE_ENTRY, "a: {value: 0.10, type: string, definition: x}"), "a", "value"),
  list("number that is a string but not a literal", c(BASE_ENTRY, "a: {value: \"abc\", type: number, definition: x}"), "a", "value"),
  list("labels empty", c(BASE_ENTRY, "a: {value: {}, type: labels, definition: x}"), "a", "value"),
  list("labels with a number value", c(BASE_ENTRY, "a: {value: {lo: 1}, type: labels, definition: x}"), "a", "value"),
  list("breaks bound decreases",
       c(BASE_ENTRY, "a:", "  value:", "    - {below: 2, phrase: x}", "    - {below: 1, phrase: y}",
         "    - {phrase: z}", "  type: breaks", "  definition: x"), "a", "value"),
  list("breaks bare item not last",
       c(BASE_ENTRY, "a:", "  value:", "    - {phrase: z}", "    - {below: 1, phrase: y}",
         "  type: breaks", "  definition: x"), "a", "value"),
  list("breaks with both below and at_most",
       c(BASE_ENTRY, "a:", "  value:", "    - {below: 1, at_most: 2, phrase: y}", "    - {phrase: z}",
         "  type: breaks", "  definition: x"), "a", "value"),
  list("decision 0", c(BASE_ENTRY, "a: {value: 1, type: number, definition: x, decision: 0}"), "a", "decision"),
  list("decision empty string", c(BASE_ENTRY, "a: {value: 1, type: number, definition: x, decision: \"\"}"), "a", "decision"),
  list("why in dict.yml", c(BASE_ENTRY, "a: {value: 1, type: number, definition: x, why: because}"), "a", "why")
)

for (case in SCHEMA_CASES) {
  local({
    nm <- case[[1]]; lines <- case[[2]]; key <- case[[3]]; field <- case[[4]]
    extra <- if (length(case) >= 5) case[[5]] else character()
    test_that(sprintf("2a schema: %s is one weft_dict_error naming the file, the key, the field and the line (4.2.1, D5)", nm), {
      p <- a2_file(lines)
      e <- a2_err(read_dict(p))
      expect_weft_cond(e, "weft_dict_error", nm)
      msg <- conditionMessage(e)
      expect_true(startsWith(msg, sprintf("weft: %s: 1 problem(s) in the dictionary", p)),
                  label = "the message starts with the summary line")
      line <- grep(paste0("^", key, ":"), lines)[1]
      pl <- grep(sprintf("%s:%d: `%s`", p, line, key), strsplit(msg, "\n")[[1]],
                 fixed = TRUE, value = TRUE)
      expect_length(pl, 1L)
      expect_match(pl, field, fixed = TRUE)
      expect_match(pl, "(rule ", fixed = TRUE)
      for (x in extra) expect_match(msg, x, fixed = TRUE)
    })
  })
}

test_that("2a schema: a duplicate key is an error naming the key (4.2.1, D6)", {
  p <- a2_file(c(BASE_ENTRY, GOOD("a"), "a: {value: 2, type: number, definition: y}"))
  e <- a2_err(read_dict(p))
  expect_weft_cond(e, "weft_dict_error", "duplicate key")
  expect_match(conditionMessage(e), "`a`", fixed = TRUE)
  expect_match(conditionMessage(e), p, fixed = TRUE)
})

test_that("2a schema: a YAML syntax error is one problem with no key, naming the file (read_dict)", {
  p <- a2_file(c(BASE_ENTRY, "a: [unclosed", "b: 2"))
  e <- a2_err(read_dict(p))
  expect_weft_cond(e, "weft_dict_error", "yaml syntax")
  msg <- conditionMessage(e)
  expect_true(startsWith(msg, sprintf("weft: %s: 1 problem(s) in the dictionary", p)))
  expect_false(grepl("`base`", msg, fixed = TRUE))
})

test_that("2a schema: a top level that is not a mapping is one problem with no key (read_dict)", {
  p <- a2_file(c("- a", "- b"))
  e <- a2_err(read_dict(p))
  expect_weft_cond(e, "weft_dict_error", "top-level list")
  expect_true(startsWith(conditionMessage(e), sprintf("weft: %s: 1 problem(s) in the dictionary", p)))
  p2 <- a2_file("just text")
  expect_weft_cond(a2_err(read_dict(p2)), "weft_dict_error", "top-level scalar")
})

test_that("2a schema: a file with two problems lists both in one message, each at its own line (D5)", {
  lines <- c(BASE_ENTRY,
             "a: {value: 1, type: number, unit: m, definition: x}",
             GOOD("fine"),
             "b: {value: 1, type: float, definition: x}")
  p <- a2_file(lines)
  e <- a2_err(read_dict(p))
  expect_weft_cond(e, "weft_dict_error", "two problems")
  msg <- conditionMessage(e)
  expect_true(startsWith(msg, sprintf("weft: %s: 2 problem(s) in the dictionary", p)))
  expect_match(msg, sprintf("%s:2: `a`", p), fixed = TRUE)
  expect_match(msg, sprintf("%s:4: `b`", p), fixed = TRUE)
  expect_false(grepl("`fine`", msg, fixed = TRUE))
})

test_that("2a schema: a valid file next to a failing one is control: nothing is half-read (D5)", {
  expect_s3_class(read_dict(a2_file(c(BASE_ENTRY, GOOD("a")))), "weft_dict")
  expect_error(read_dict(a2_file(c(BASE_ENTRY, GOOD("a"), "b: {type: number, definition: x}"))),
               class = "weft_dict_error")
})

test_that("2a read: path must be one string naming an existing file, else weft_dict_error (read_dict)", {
  expect_weft_cond(a2_err(read_dict(file.path(tempdir(), "no-such-dict-2a.yml"))), "weft_dict_error", "missing file")
  expect_weft_cond(a2_err(read_dict(c(a2_fixture(), a2_fixture()))), "weft_dict_error", "two paths")
  expect_weft_cond(a2_err(read_dict(1)), "weft_dict_error", "number path")
  expect_weft_cond(a2_err(read_dict(NA_character_)), "weft_dict_error", "NA path")
  expect_weft_cond(a2_err(read_dict(tempdir())), "weft_dict_error", "a directory")
})

test_that("2a read: the default path is dict.yml in the working directory (read_dict)", {
  withr::local_dir(withr::local_tempdir())
  expect_weft_cond(a2_err(read_dict()), "weft_dict_error", "no dict.yml")
  writeLines(GOOD("a"), "dict.yml")
  expect_identical(names(read_dict()), "a")
})

# ---- empty file, number literals, yes/no ---------------------------------------------------

test_that("2a read: an empty file, or one holding only comments, is a dictionary with no keys (the file)", {
  for (lines in list(character(), "", "# only a comment", c("# one", "", "# two"))) {
    d <- read_dict(a2_file(lines))
    expect_s3_class(d, "weft_dict")
    expect_length(d, 0L)
    expect_identical(names(d), character())
    expect_equal(nrow(attr(d, "entries")), 0L)
  }
})

test_that("2a read: a number written as a string that is a literal reads as that double (D7)", {
  d <- read_dict(a2_file(c(
    "small: {value: \"1e-3\", type: number, definition: x}",
    "plain: {value: \"12.5\", type: number, definition: x}",
    "q: {value: \"2e2\", type: quantity, unit: m, definition: x}",
    "yr: {value: \"2014\", type: year, definition: x}")))
  expect_equal(d$small, 0.001)
  expect_type(d$small, "double")
  expect_equal(d$plain, 12.5)
  expect_qty(d$q, 200, "m")
  expect_identical(as.integer(d$yr), 2014L)
  expect_s3_class(d$yr, "weft_year")
})

test_that("2a read: yes, no, on, off, true and false stay as text, so a labels map keyed yes/no reads (D6)", {
  d <- read_dict(a2_file(c(
    "flags:",
    "  value: {yes: Y, no: N, on: On, off: Off, true: T, false: F}",
    "  type: labels",
    "  definition: x")))
  expect_identical(as.character(d$flags(c("yes", "no", "on", "off", "true", "false"))),
                   c("Y", "N", "On", "Off", "T", "F"))
})

test_that("2a read: a string value that looks like a YAML boolean stays text (D6)", {
  d <- read_dict(a2_file("s: {value: yes, type: string, definition: x}"))
  expect_identical(d$s, "yes")
})

test_that("2a read: an unquoted ISO date reads as a Date (D9)", {
  d <- read_dict(a2_file("when: {value: 2024-06-01, type: date, definition: x}"))
  expect_identical(d$when, as.Date("2024-06-01"))
})

test_that("2a read: a decision that is a whole number or text reads; it is not resolved (D11, 4.5.2)", {
  d <- read_dict(a2_file(c(
    "n: {value: 1, type: number, definition: x, decision: 7}",
    "s: {value: 1, type: number, definition: x, decision: \"glob-*\"}")))
  e <- attr(d, "entries")
  expect_identical(e$decision, c("7", "glob-*"))
})

# ---- units ---------------------------------------------------------------------------------

test_that("2a units: the fixture's own units read, and PSU, sites and CFU/100 mL are known after (4.4.7)", {
  d <- fx()
  expect_silent(units::as_units("PSU"))
  expect_silent(units::as_units("sites"))
  expect_silent(units::as_units("CFU/100 mL"))
  expect_silent(units::as_units("sites/ha"))
})

test_that("2a units: reading twice is silent and idempotent; a unit is installed once, and listed by `registered` and print() (4.4.7, D16)", {
  # letters only, and no other test uses these names
  lines <- c("wqzlen: {value: 3, type: quantity, unit: wqzlenx, definition: x}",
             "wqzrate: {value: 2, type: quantity, unit: \"wqzlenx/wqzcount\", definition: x}")
  p <- a2_file(lines)
  expect_error(units::as_units("wqzlenx"))                    # control: unknown before
  expect_silent(d1 <- read_dict(p))
  expect_setequal(attr(d1, "registered"), c("wqzlenx", "wqzcount"))
  expect_silent(units::as_units("wqzlenx"))
  expect_silent(d2 <- read_dict(p))                           # no error, no message, no warning
  expect_identical(attr(d2, "registered"), attr(d1, "registered"))   # stable across reads (review 2a #7)
  expect_equal(as.list(d1), as.list(d2))
  expect_match(paste(capture.output(print(d1)), collapse = "\n"), "Units registered: ", fixed = TRUE)
  expect_match(paste(capture.output(print(d1)), collapse = "\n"), "wqzlenx", fixed = TRUE)
})

test_that("2a units: tokens are the runs of letters between digits, white space and operators; a known token is not installed again (4.4.7)", {
  p <- a2_file("a: {value: 1, type: quantity, unit: \"wqzjar^2 * m / (s)\", definition: x}")
  d <- read_dict(p)
  expect_identical(attr(d, "registered"), "wqzjar")           # m and s were already known
  expect_qty(d$a, 1, "wqzjar^2*m/s")
})

test_that("2a units: an unparseable unit is a problem naming the unit and the field (4.4.7)", {
  p <- a2_file(c(BASE_ENTRY, "a: {value: 1, type: quantity, unit: \")m\", definition: x}"))
  e <- a2_err(read_dict(p))
  expect_weft_cond(e, "weft_dict_error", ")m")
  msg <- conditionMessage(e)
  expect_true(startsWith(msg, sprintf("weft: %s: 1 problem(s) in the dictionary", p)))
  expect_match(msg, ")m", fixed = TRUE)
  expect_match(msg, sprintf("%s:2: `a`", p), fixed = TRUE)
  expect_match(msg, "unit", fixed = TRUE)
})

# ---- arithmetic (the units package's) -----------------------------------------------------

test_that("2a arithmetic: x * 100 is 50 m, x / y has no unit, x * y is m^2 (4.4.1)", {
  d <- fx()
  x <- d$core_len; y <- d$reach_len
  expect_qty(x * 100, 50, "m")
  r <- x / y
  expect_equal(as.numeric(r), 0.25)
  if (inherits(r, "units")) expect_identical(units::deparse_unit(r), "1")
  a <- x * y
  expect_equal(as.numeric(a), 1)
  expect_true(units::ud_are_convertible(units::deparse_unit(a), "m^2"))
  expect_equal(as.numeric(units::set_units(a, "m^2", mode = "standard")), 1)
})

test_that("2a arithmetic: x + dict$sample_mass errors with the units message 'cannot convert' (4.4.1)", {
  d <- fx()
  expect_error(d$core_len + d$sample_mass, "cannot convert")
  expect_qty(d$core_len + d$reach_len, 2.5, "m")                # control
})

test_that("2a arithmetic: dict$salinity_res * 2 is 0.02 PSU; 5 sites / 2 ha is 2.5 sites/ha (4.4.1)", {
  d <- fx()
  expect_qty(d$salinity_res * 2, 0.02, "PSU")
  expect_qty(u(5, sites) / u(2, ha), 2.5, "sites/ha")
})

test_that("2a arithmetic: x > 0.3 errors, and x > u(0.3, m) is TRUE (4.4.5)", {
  d <- fx()
  x <- d$core_len
  expect_error(x > 0.3, "both operands")
  expect_true(x > u(0.3, m))
  expect_false(x > u(60, cm))
})

# ---- u() ------------------------------------------------------------------------------------

test_that("2a u: a unit written as an expression is taken as written (4.4.6)", {
  fx()
  expect_qty(u(35, m), 35, "m")
  expect_qty(u(5, mg/L), 5, "mg/L")
  expect_qty(u(1, m^2), 1, "m^2")
  expect_qty(u(0.05, PSU), 0.05, "PSU")
  expect_qty(u(c(1, 2, 3), kg), c(1, 2, 3), "kg")
})

test_that("2a u: a unit given as a string reads too, and a project's own unit works once its dictionary has been read (4.4.6, 4.4.7)", {
  fx()
  expect_qty(u(150, "CFU/100 mL"), 150, "CFU/100 mL")
  expect_qty(u(1, "CFU/100 mL"), 1, "CFU/100 mL")
  expect_qty(u(3, "kg"), 3, "kg")
  expect_equal(u(150, "CFU/100 mL"), fx()$coliform_limit)
})

test_that("2a u: a units value is converted to the unit (4.4.6)", {
  d <- fx()
  r <- u(d$core_len, cm)
  expect_qty(r, 50, "cm")
  expect_equal(as.numeric(r), 50)
  expect_identical(units::deparse_unit(r), "cm")
})

test_that("2a u: the unit is never evaluated as R, so a variable named like the unit is not read (4.4.6, D17)", {
  fx()
  m <- "this is not a unit"
  mg <- stop
  expect_qty(u(35, m), 35, "m")
  expect_qty(u(5, mg/L), 5, "mg/L")
  f <- function() { m <- list(); u(7, m) }
  expect_qty(f(), 7, "m")
})

test_that("2a u: u() does not register units; an unknown unit is a weft_unit_error naming it (4.4.6, D17)", {
  e <- a2_err(u(1, NTUqzx))
  expect_weft_cond(e, "weft_unit_error", "unknown unit")
  msg <- conditionMessage(e)
  expect_match(msg, "u()", fixed = TRUE)
  expect_match(msg, "`NTUqzx`", fixed = TRUE)
  expect_match(msg, "not a unit the units database knows", fixed = TRUE)
  expect_match(msg, "install_unit", fixed = TRUE)
  expect_match(msg, "4.4.7", fixed = TRUE)
  expect_weft_cond(a2_err(u(1, "NTUqzx")), "weft_unit_error", "unknown unit as a string")
  # and it is still unknown afterwards, so u() did not register it
  expect_weft_cond(a2_err(u(1, NTUqzx)), "weft_unit_error", "still unknown")
})

test_that("2a u: a unit that does not convert, a non-numeric value and a missing unit are weft_unit_errors (4.4.6)", {
  d <- fx()
  e <- a2_err(u(d$core_len, kg))
  expect_weft_cond(e, "weft_unit_error", "does not convert")
  expect_match(conditionMessage(e), "convert", fixed = TRUE)
  expect_weft_cond(a2_err(u("35", m)), "weft_unit_error", "character value")
  expect_weft_cond(a2_err(u(TRUE, m)), "weft_unit_error", "logical value")
  expect_weft_cond(a2_err(u(list(1), m)), "weft_unit_error", "list value")
  expect_weft_cond(a2_err(u(5)), "weft_unit_error", "missing unit")
  expect_weft_cond(a2_err(u(5, "")), "weft_unit_error", "blank unit")
})

# ---- checks against a bare number (4.4.5, D20) -------------------------------------------

test_that("2a claim: a check in the quantity's unit passes and returns the value (4.4.5)", {
  d <- fx()
  r <- claim(d$core_len, . < u(1, m))
  expect_qty(r, 0.5, "m")
})

test_that("2a claim: a check against a bare number fails as weft_claim_failed with the 4.4.5 hint (4.4.5, D20)", {
  d <- fx()
  e <- a2_err(claim(d$core_len, . < 1))
  expect_weft_cond(e, "weft_claim_failed", "bare number")
  # wherever the failure carries it: the message or a field of the condition
  txt <- paste(c(conditionMessage(e), unlist(lapply(unclass(e), function(x) if (is.character(x)) x))),
               collapse = "\n")
  expect_match(txt, "state the check's unit, as in . < u(0.45, ug) (rule 4.4.5)", fixed = TRUE)
  # control: an ordinary failed check has no such hint
  e2 <- a2_err(claim(5, . > 10))
  expect_s3_class(e2, "weft_claim_failed")
  expect_false(grepl("state the check's unit", paste(conditionMessage(e2), collapse = ""), fixed = TRUE))
})

# ---- years -----------------------------------------------------------------------------------

test_that("2a year: fmt_num of the year prints 2014 with no thousands mark; + 1 prints 2015 (4.2.1, D8)", {
  d <- fx()
  expect_identical(b_txt_2a(fmt_num(d$method_change)), "2014")
  expect_identical(b_txt_2a(fmt_num(d$method_change + 1)), "2015")
  # the attribute survives arithmetic
  expect_s3_class(d$method_change + 1, "weft_year")
  # control: a plain number of the same size prints a thousands mark by the house style
  expect_identical(b_txt_2a(fmt_num(12345)), "12,345")
})
