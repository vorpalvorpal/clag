# Package 2c: the schema helper itself, on a tiny inline schema, so that a broken
# validator cannot hide a failure (C20). Contract: dev/design-2c.md "helper-schema.R".

TINY <- jsonlite::fromJSON(simplifyVector = FALSE, txt = '{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "tiny",
  "type": "object",
  "required": ["n"],
  "additionalProperties": false,
  "propertyNames": { "$ref": "#/definitions/key" },
  "properties": {
    "n": { "type": "integer", "minimum": 1, "maximum": 9 },
    "s": { "type": "string", "pattern": "^a" },
    "e": { "enum": ["x", "y"] },
    "c": { "const": "k" },
    "arr": { "type": "array", "minItems": 2, "items": { "type": "number" } },
    "obj": { "type": "object", "minProperties": 1, "additionalProperties": { "type": "string" } },
    "any": { "anyOf": [ { "type": "string" }, { "type": "boolean" } ] },
    "all": { "allOf": [ { "type": "number" }, { "minimum": 3 } ] },
    "no": { "not": { "type": "string" } },
    "cond": { "if": { "type": "string" }, "then": { "pattern": "^z" } },
    "never": false,
    "always": true,
    "ref": { "$ref": "#/definitions/key" }
  },
  "definitions": { "key": { "type": "string", "pattern": "^[a-z]+$" } }
}')

tok <- function(x) !length(schema_check(x, TINY))
J <- function(...) structure(list(...), json_array = TRUE)

test_that("2c helper: schema_view reads sequences as arrays, true and false as booleans, yes and no as text", {
  x <- schema_view(c("a: [1, 2]", "b: true", "c: False", "d: yes", "e: no", "f: 3", "g: 0.5", "h: ~"))
  expect_identical(jtype(x$a), "array")
  expect_identical(x$b, TRUE)
  expect_identical(x$c, FALSE)
  expect_identical(x$d, "yes")
  expect_identical(x$e, "no")
  expect_identical(jtype(x$f), "integer")
  expect_identical(jtype(x$g), "number")
  expect_identical(jtype(x$h), "null")
})

test_that("2c helper: schema_view keeps octal and hex as text, an empty list as an array, and an empty document as an empty object", {
  x <- schema_view(c("a: 010", "b: 0x1F", "c: []", "d: {}", "e: 2024-06-01", "f: .inf"))
  expect_identical(x$a, "010")
  expect_identical(x$b, "0x1F")
  expect_identical(jtype(x$c), "array")
  expect_identical(jtype(x$d), "object")
  expect_identical(jtype(x$e), "string")
  expect_identical(jtype(x$f), "number")
  e <- schema_view(character())
  expect_identical(jtype(e), "object")
  expect_length(e, 0L)
  expect_identical(jtype(schema_view("- a\n- b")), "array")
  expect_identical(jtype(schema_view("just text")), "string")
})

test_that("2c helper: jtype follows the contract's rules", {
  expect_identical(jtype(NULL), "null")
  expect_identical(jtype(TRUE), "boolean")
  expect_identical(jtype(2), "integer")
  expect_identical(jtype(2.5), "number")
  expect_identical(jtype(Inf), "number")
  expect_identical(jtype("a"), "string")
  expect_identical(jtype(list(a = 1)), "object")
  expect_identical(jtype(J(1)), "array")
  expect_true(jtype_is(2, "number"))
  expect_false(jtype_is(2.5, "integer"))
})

test_that("2c helper: a valid instance passes and each keyword rejects its violation", {
  expect_true(tok(list(n = 3)))
  expect_false(tok(list()))                                    # required
  expect_false(tok(list(n = 3, extra = 1)))                    # additionalProperties false
  expect_false(tok(list(n = 3.5)))                             # type integer
  expect_false(tok(list(n = 0)))                               # minimum
  expect_false(tok(list(n = 10)))                              # maximum
  expect_true(tok(list(n = 3, s = "abc")))
  expect_false(tok(list(n = 3, s = "xbc")))                    # pattern
  expect_false(tok(list(n = 3, s = 4)))                        # type string
  expect_true(tok(list(n = 3, e = "x")))
  expect_false(tok(list(n = 3, e = "z")))                      # enum
  expect_true(tok(list(n = 3, c = "k")))
  expect_false(tok(list(n = 3, c = "j")))                      # const
  expect_true(tok(list(n = 3, arr = J(1, 2))))
  expect_false(tok(list(n = 3, arr = J(1))))                   # minItems
  expect_false(tok(list(n = 3, arr = J(1, "a"))))              # items
  expect_false(tok(list(n = 3, arr = list(a = 1, b = 2))))     # an object is not an array
  expect_true(tok(list(n = 3, obj = list(a = "x"))))
  expect_false(tok(list(n = 3, obj = structure(list(), names = character()))))   # minProperties
  expect_false(tok(list(n = 3, obj = list(a = 1))))            # additionalProperties schema
})

test_that("2c helper: anyOf, allOf, not, if/then, boolean schemas, $ref and propertyNames", {
  expect_true(tok(list(n = 3, any = "a")))
  expect_true(tok(list(n = 3, any = TRUE)))
  expect_false(tok(list(n = 3, any = 5)))                      # anyOf
  expect_true(tok(list(n = 3, all = 4)))
  expect_false(tok(list(n = 3, all = 2)))                      # allOf
  expect_true(tok(list(n = 3, no = 1)))
  expect_false(tok(list(n = 3, no = "s")))                     # not
  expect_true(tok(list(n = 3, cond = "zed")))
  expect_false(tok(list(n = 3, cond = "abc")))                 # then applies
  expect_true(tok(list(n = 3, cond = 5)))                      # if fails: then does not apply
  expect_false(tok(list(n = 3, never = 1)))                    # a false schema
  expect_true(tok(list(n = 3, always = 1)))                    # a true schema
  expect_true(tok(list(n = 3, ref = "abc")))
  expect_false(tok(list(n = 3, ref = "ABC")))                  # $ref
  expect_false(tok(list(`Bad` = 1, n = 3)))                    # propertyNames
})

test_that("2c helper: any other keyword in a schema is a failure, and schema_unknown_keywords finds it", {
  expect_error(schema_check(1, list(format = "email")), "not interpreted")
  expect_error(schema_check(list(a = 1), list(properties = list(a = list(patternProperties = list())))),
               "not interpreted")
  expect_identical(schema_unknown_keywords(TINY), character())
  expect_identical(schema_unknown_keywords(list(properties = list(a = list(format = "x")))), "format")
  expect_identical(schema_unknown_keywords(list(definitions = list(a = list(uniqueItems = TRUE)))), "uniqueItems")
  expect_error(schema_check(1, list(`$ref` = "http://elsewhere/x")), "not interpreted")
})
