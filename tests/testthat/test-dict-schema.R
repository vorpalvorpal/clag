# Package 2c: the JSON Schema inst/dict/dict.schema.json against read_dict(). Contract:
# dev/design-2c.md "The schema", "How the schema and read_dict() agree", C18-C20, E1, E2.
# The validator is tested on a tiny schema in test-helper-schema.R.

BASE <- "base: {value: 1, type: number, definition: \"Base.\"}"

# `lines` is the whole dict.yml; read_dict() reads it from a temp file
reads <- function(lines) {
  dir <- c2_proj(list(dict.yml = lines), parent.frame())
  tryCatch(read_dict(file.path(dir, "dict.yml")), error = function(e) e)
}
rd_ok <- function(lines) inherits(reads(lines), "weft_dict")
rd_refuses <- function(lines) inherits(reads(lines), "weft_dict_error")

test_that("2c schema: the schema file is valid JSON, draft-07, and the helper knows every keyword in it (C18, C20)", {
  skip_if_not_installed("jsonlite")
  p <- schema_file()
  expect_true(file.exists(p))
  s <- jsonlite::fromJSON(p, simplifyVector = FALSE)
  expect_identical(s[["$schema"]], "http://json-schema.org/draft-07/schema#")
  expect_identical(schema_unknown_keywords(s), character())
})

test_that("2c schema: the schema file ends with a newline, two-space indentation, no tabs (the contract's file)", {
  skip_if_not_installed("jsonlite")
  raw <- c2_bytes(schema_file())
  expect_identical(raw[length(raw)], as.raw(10))
  txt <- rawToChar(raw)
  expect_false(grepl("\t", txt, fixed = TRUE))
  expect_match(txt, "\n  \"title\": \"weft dictionary\"", fixed = TRUE)
})

# ---- both accept -----------------------------------------------------------------------------

ACCEPT <- list(
  "the 2a fixture" = readLines(testthat::test_path("_dict", "dict.yml"), warn = FALSE),
  "the 2c fixture" = readLines(testthat::test_path("_dict-tools", "dict.yml"), warn = FALSE),
  "an empty file" = character(),
  "number as a literal string" = "a: {value: \"1e-3\", type: number, definition: x}",
  "year as a string" = "a: {value: \"2014\", type: year, definition: x}",
  "labels keyed yes and no" = "a: {value: {yes: Included, no: Excluded}, type: labels, definition: x}",
  "breaks bound .inf" = c("a:", "  value:", "    - {below: 1, phrase: x}", "    - {below: .inf, phrase: y}",
                          "  type: breaks", "  definition: x"),
  "a string decision" = "a: {value: 1, type: number, definition: x, decision: \"zones-2023\"}",
  "an integer decision" = "a: {value: 1, type: number, definition: x, decision: 7}",
  "display on a quantity" = "a: {value: 50, type: quantity, unit: cm, display: m, definition: x}",
  "avoid as one string on a string entry" = "a: {value: Alpha, type: string, avoid: beta, definition: x}",
  "avoid with a term on a number" = "a: {value: 1, type: number, term: one thing, avoid: [uno], definition: x}",
  "term on every type" = c("a: {value: 1, type: number, term: aa, definition: x}",
                           "b: {value: 2014, type: year, term: bb, definition: x}"),
  "a date" = "a: {value: 2024-06-01, type: date, definition: x}",
  "a quantity written as a string" = "a: {value: \"3.5\", type: quantity, unit: m, definition: x}"
)

test_that("2c schema: the starter, shipped and uncommented, passes the schema and read_dict() (C15, C19)", {
  skip_if_not_installed("jsonlite")
  src <- readLines(c2_inst("dict.yml"), warn = FALSE)
  expect_true(rd_ok(src))
  expect_true(schema_ok(src))
  from <- grep("^# core_len:", src)[1]
  src[from:length(src)] <- sub("^# ?", "", src[from:length(src)])
  expect_true(rd_ok(src))
  expect_true(schema_ok(src))
})

for (nm in names(ACCEPT)) {
  local({
    nm <- nm; lines <- ACCEPT[[nm]]
    test_that(sprintf("2c schema accepts: %s is read by read_dict() and valid against the schema (C19)", nm), {
      skip_if_not_installed("jsonlite")
      expect_true(rd_ok(lines), label = "read_dict() reads it")
      expect_true(schema_ok(lines), label = paste(schema_errors(lines), collapse = "; "))
    })
  })
}

# ---- both refuse -----------------------------------------------------------------------------

REFUSE <- list(
  "missing value" = c(BASE, "a:", "  type: number", "  definition: x"),
  "missing type" = c(BASE, "a:", "  value: 1", "  definition: x"),
  "missing definition" = c(BASE, "a:", "  value: 1", "  type: number"),
  "blank definition" = c(BASE, "a: {value: 1, type: number, definition: \"  \"}"),
  "unknown type" = c(BASE, "a: {value: 1, type: float, definition: x}"),
  "unknown field" = c(BASE, "a: {value: 1, type: number, definition: x, colour: red}"),
  "why in dict.yml" = c(BASE, "a: {value: 1, type: number, definition: x, why: because}"),
  "unit on a number" = c(BASE, "a: {value: 1, type: number, unit: m, definition: x}"),
  "quantity with no unit" = c(BASE, "a: {value: 1, type: quantity, definition: x}"),
  "display on a string" = c(BASE, "a: {value: x, type: string, display: m, definition: x}"),
  "key file" = c(BASE, "file: {value: 1, type: number, definition: x}"),
  "key 2x" = c(BASE, "2x: {value: 1, type: number, definition: x}"),
  "key if" = c(BASE, "if: {value: 1, type: number, definition: x}"),
  "key ..1" = c(BASE, "..1: {value: 1, type: number, definition: x}"),
  "key ..." = c(BASE, "...: {value: 1, type: number, definition: x}"),
  "year 214" = c(BASE, "a: {value: 214, type: year, definition: x}"),
  "year 2014.5" = c(BASE, "a: {value: 2014.5, type: year, definition: x}"),
  "date written 1 June 2024" = c(BASE, "a: {value: \"1 June 2024\", type: date, definition: x}"),
  "string given 0.10" = c(BASE, "a: {value: 0.10, type: string, definition: x}"),
  "labels empty" = c(BASE, "a: {value: {}, type: labels, definition: x}"),
  "labels with a number" = c(BASE, "a: {value: {x: 1}, type: labels, definition: x}"),
  "breaks empty" = c(BASE, "a: {value: [], type: breaks, definition: x}"),
  "breaks with both bounds" = c(BASE, "a:", "  value:", "    - {below: 1, at_most: 2, phrase: y}",
                                "    - {phrase: z}", "  type: breaks", "  definition: x"),
  "breaks item with no phrase" = c(BASE, "a:", "  value:", "    - {below: 1}", "    - {phrase: z}",
                                   "  type: breaks", "  definition: x"),
  "breaks item with an unknown field" = c(BASE, "a:", "  value:", "    - {below: 1, phrase: y, colour: red}",
                                          "    - {phrase: z}", "  type: breaks", "  definition: x"),
  "decision 0" = c(BASE, "a: {value: 1, type: number, definition: x, decision: 0}"),
  "decision empty" = c(BASE, "a: {value: 1, type: number, definition: x, decision: \"\"}"),
  "term blank" = c(BASE, "a: {value: 1, type: number, definition: x, term: \"  \"}"),
  "avoid empty list" = c(BASE, "a: {value: x, type: string, definition: x, avoid: []}"),
  "avoid with a blank item" = c(BASE, "a: {value: x, type: string, definition: x, avoid: [\"\"]}"),
  "avoid on a number with no term" = c(BASE, "a: {value: 1, type: number, definition: x, avoid: [nn]}"),
  "a top level that is a list" = c("- a", "- b")
)

for (nm in names(REFUSE)) {
  local({
    nm <- nm; lines <- REFUSE[[nm]]
    test_that(sprintf("2c schema refuses: %s is refused by read_dict() and by the schema (C19)", nm), {
      skip_if_not_installed("jsonlite")
      expect_true(rd_refuses(lines), label = "read_dict() refuses it")
      expect_false(schema_ok(lines), label = "the schema refuses it")
    })
  })
}

test_that("2c schema refuses: the control, a minimal valid entry, passes both (guards the cases above)", {
  skip_if_not_installed("jsonlite")
  expect_true(rd_ok(BASE))
  expect_true(schema_ok(BASE))
})

# ---- only read_dict() refuses ----------------------------------------------------------------

ONLY_READER <- list(
  "a leading zero" = c(BASE, "a: {value: 010, type: number, definition: x}"),
  "hex" = c(BASE, "a: {value: 0x1F, type: number, definition: x}"),
  "a merge key" = c("base: &b {value: 1, type: number, definition: x}", "a:", "  <<: *b"),
  "two documents" = c(BASE, "---", "a: {value: 1, type: number, definition: x}"),
  "a duplicate key" = c(BASE, "a: {value: 1, type: number, definition: x}",
                        "a: {value: 2, type: number, definition: y}"),
  "a date not in the calendar" = c(BASE, "a: {value: \"2024-02-30\", type: date, definition: x}"),
  "decreasing breaks" = c(BASE, "a:", "  value:", "    - {below: 2, phrase: x}", "    - {below: 1, phrase: y}",
                          "    - {phrase: z}", "  type: breaks", "  definition: x"),
  "a bare breaks item not last" = c(BASE, "a:", "  value:", "    - {phrase: z}", "    - {below: 1, phrase: y}",
                                    "  type: breaks", "  definition: x"),
  "value .inf under number" = c(BASE, "a: {value: .inf, type: number, definition: x}"),
  "a unit units refuses" = c(BASE, "a: {value: 1, type: quantity, unit: \"m^^2 kg!\", definition: x}"),
  "a display that does not convert" = c(BASE, "a: {value: 1, type: quantity, unit: m, display: kg, definition: x}")
)

for (nm in names(ONLY_READER)) {
  local({
    nm <- nm; lines <- ONLY_READER[[nm]]
    test_that(sprintf("2c schema, reader only: %s is refused by read_dict() (the schema's answer is not asserted)", nm), {
      expect_true(rd_refuses(lines))
      # the control: its valid neighbour reads, so the refusal is about this case
      expect_true(rd_ok(BASE))
    })
  })
}

test_that("2c schema, reader only: each avoid conflict is refused by read_dict() as rule 4.7.4 (C9)", {
  cases <- list(
    own = c("a: {value: Alpha, type: string, avoid: [Alpha], definition: x}"),
    twice = c("a: {value: Alpha, type: string, avoid: [bb, bb], definition: x}"),
    other = c("a: {value: Alpha, type: string, avoid: [cc dd], definition: x}",
              "b: {value: Beta, type: string, avoid: [cc dd], definition: x}"),
    part = c("a: {value: Alpha, type: string, avoid: [Beta], definition: x}",
             "b: {value: Beta gamma, type: string, definition: x}")
  )
  for (nm in names(cases)) {
    e <- reads(cases[[nm]])
    expect_s3_class(e, "weft_dict_error")
    expect_true(grepl("(rule 4.7.4)", conditionMessage(e), fixed = TRUE), label = nm)
  }
})

# ---- E1, E2 ----------------------------------------------------------------------------------

test_that("2c schema E1: a bare true where text is meant reads as the text 'true' and the schema asks for quotes", {
  skip_if_not_installed("jsonlite")
  l1 <- c("a: {value: x, type: string, definition: true}")
  d <- reads(l1)
  expect_s3_class(d, "weft_dict")
  expect_identical(attr(d, "entries")$definition, "true")
  expect_false(schema_ok(l1))
  l2 <- c("a: {value: true, type: string, definition: x}")
  d2 <- reads(l2)
  expect_s3_class(d2, "weft_dict")
  expect_identical(d2$a, "true")
  expect_false(schema_ok(l2))
  # control: the quoted forms pass both
  l3 <- c("a: {value: \"true\", type: string, definition: \"true\"}")
  expect_true(rd_ok(l3))
  expect_true(schema_ok(l3))
})

test_that("2c schema E2: a key with a letter outside A-Z reads where R accepts it, and the schema refuses it", {
  skip_if_not_installed("jsonlite")
  key <- "café"
  skip_if_not(identical(make.names(key), key), "this locale does not accept the key")
  lines <- sprintf("%s: {value: 1, type: number, definition: x}", key)
  d <- reads(lines)
  expect_s3_class(d, "weft_dict")
  expect_identical(names(d), key)
  expect_false(schema_ok(lines))
})
