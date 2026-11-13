# Stage 5b: reading Python values, outside a knit (G4 to G8, 1.11, 2.12.5).
# G5 row by row through py_value(): kind, R type and value. Every refusal's
# class and exact message (G7). G6's lists. The typed record (the amendment)
# and the one function that turns it into an R value. numpy and pandas rows
# skip only when that module does not import. One Python session per file;
# every test uses names of its own (t_g5_...).
#
# The interface is fixed in helper-5.R (guest_record(), record_value()).

S_ <- function(name) sprintf("`py_value(\"%s\")`", name)

# one name per row: t_g5_<id>
nm_ <- function(id) paste0("t_g5_", id)

# ---- G5: scalars, as records and as R values ----------------------------------

# id, python expression, record kind, record value (NULL: not checked), R value
SCALARS <- list(
  list("true",    "True",                          "bool",    TRUE,  TRUE),
  list("false",   "False",                         "bool",    FALSE, FALSE),
  list("int0",    "0",                             "int",     "0",   0L),
  list("int5",    "5",                             "int",     "5",   5L),
  list("intneg",  "-7",                            "int",     "-7",  -7L),
  list("int31m",  "2**31 - 1",                     "int",     "2147483647",  2147483647L),
  list("int31mn", "-(2**31 - 1)",                  "int",     "-2147483647", -2147483647L),
  list("int31",   "2**31",                         "int",     "2147483648",  2147483648),
  list("int31n",  "-2**31",                        "int",     "-2147483648", -2147483648),
  list("int53",   "2**53",                         "int",     "9007199254740992",  9007199254740992),
  list("int53n",  "-2**53",                        "int",     "-9007199254740992", -9007199254740992),
  list("flt01",   "0.1",                           "float",   "0.1", 0.1),
  list("flt25",   "2.5",                           "float",   "2.5", 2.5),
  list("flt22",   "1e22",                          "float",   NULL,  1e22),
  list("fltneg",  "-3.25",                         "float",   "-3.25", -3.25),
  list("fltint",  "3.0",                           "float",   NULL,  3),
  list("dec015",  "decimal.Decimal('0.15')",       "decimal", "0.15",  0.15),
  list("dec0150", "decimal.Decimal('0.150')",      "decimal", "0.150", 0.15),
  list("dec15",   "decimal.Decimal('123456789012345')",   "decimal", "123456789012345", 123456789012345),
  list("dec15p",  "decimal.Decimal('1.23456789012345')",  "decimal", "1.23456789012345", 1.23456789012345),
  list("decpad",  "decimal.Decimal('1.50000000000000000000')", "decimal", NULL, 1.5),
  list("dec1e20", "decimal.Decimal('1E+20')",      "decimal", NULL,  1e20),
  list("dec100",  "decimal.Decimal('100')",        "decimal", "100", 100),
  list("decneg",  "decimal.Decimal('-0.5')",       "decimal", "-0.5", -0.5),
  list("str",     "'abc'",                         "string",  "abc", "abc"),
  list("stremp",  "''",                            "string",  "",    ""),
  list("strnon",  "'caf\\u00e9 \\u4e2d\\u6587 \\U0001F600'", "string",
       "caf\u00e9 \u4e2d\u6587 \U0001F600", "caf\u00e9 \u4e2d\u6587 \U0001F600"),
  list("strnum",  "'42'",                          "string",  "42",  "42"),
  list("date",    "datetime.date(2026, 11, 13)",   "date",    "2026-11-13", as.Date("2026-11-13")),
  list("datelp",  "datetime.date(2024, 2, 29)",    "date",    "2024-02-29", as.Date("2024-02-29"))
)

for (row in SCALARS) local({
  id <- row[[1]]; expr <- row[[2]]; kind <- row[[3]]; v <- row[[4]]; want <- row[[5]]
  test_that(sprintf("G5: %s is a %s record and the R value %s", expr, kind,
                    paste(format(want), collapse = " ")), {
    skip_if_no_python()
    py_set(setNames(expr, nm_(id)))
    rec <- weft:::guest_record(py_obj(nm_(id)))
    expect_identical(rec$t, kind)
    if (!is.null(v)) expect_identical(rec$v, v)
    expect_identical(py_value(nm_(id)), want)
  })
})

test_that("G5: a bool is never an integer, and an int is never a bool", {
  skip_if_no_python()
  py_set(t_g5_b1 = "True", t_g5_i1 = "1")
  expect_identical(py_value("t_g5_b1"), TRUE)
  expect_identical(py_value("t_g5_i1"), 1L)
  expect_identical(weft:::guest_record(py_obj("t_g5_b1"))$t, "bool")
  expect_identical(weft:::guest_record(py_obj("t_g5_i1"))$t, "int")
})

test_that("G5 + 1.11.2: big integers are held as digit strings in the record, exactly", {
  skip_if_no_python()
  py_set(t_g5_r53p = "2**53 + 1", t_g5_r70 = "2**70", t_g5_r70n = "-2**70",
         t_g5_r63 = "2**63", t_g5_r53pn = "-(2**53 + 1)")
  rec <- weft:::guest_record(py_obj("t_g5_r53p"))
  expect_identical(c(rec$t, rec$v), c("int", "9007199254740993"))
  rec <- weft:::guest_record(py_obj("t_g5_r53pn"))
  expect_identical(c(rec$t, rec$v), c("int", "-9007199254740993"))
  rec <- weft:::guest_record(py_obj("t_g5_r70"))
  expect_identical(c(rec$t, rec$v), c("int", "1180591620717411303424"))
  rec <- weft:::guest_record(py_obj("t_g5_r70n"))
  expect_identical(c(rec$t, rec$v), c("int", "-1180591620717411303424"))
  rec <- weft:::guest_record(py_obj("t_g5_r63"))
  expect_identical(c(rec$t, rec$v), c("int", "9223372036854775808"))
})

# ---- G5: missing ---------------------------------------------------------------

MISSING <- c(none = "None", nan = "float('nan')", inf = "math.inf",
             ninf = "-math.inf", decnan = "decimal.Decimal('NaN')",
             decinf = "decimal.Decimal('Infinity')",
             decninf = "decimal.Decimal('-Infinity')")

for (id in names(MISSING)) local({
  id <- id; expr <- MISSING[[id]]
  test_that(sprintf("G5 + 1.11.7: %s is missing: a record with a reason, and NA", expr), {
    skip_if_no_python()
    py_set(setNames(expr, nm_(id)))
    rec <- weft:::guest_record(py_obj(nm_(id)))
    expect_identical(rec$t, "missing")
    expect_true(is.character(rec$why) && length(rec$why) == 1L && nzchar(rec$why))
    expect_identical(py_value(nm_(id)), NA)
  })
})

# ---- G5: refusals --------------------------------------------------------------

# id, python (assignment right side), message builder f(S, type), setup lines
REFUSED <- list(
  list("r53p",   "2**53 + 1",    function(S, t) m1(S, "9007199254740993")),
  list("r53pn",  "-(2**53 + 1)", function(S, t) m1(S, "-9007199254740993")),
  list("r54",    "2**54",        function(S, t) m1(S, "18014398509481984")),
  list("r63",    "2**63",        function(S, t) m1(S, "9223372036854775808")),
  list("r70",    "2**70",        function(S, t) m1(S, "1180591620717411303424")),
  list("r70n",   "-2**70",       function(S, t) m1(S, "-1180591620717411303424")),
  list("d16",    "decimal.Decimal('1.234567890123456')",
       function(S, t) m2(S, "1.234567890123456", 16L)),
  list("d16i",   "decimal.Decimal('1234567890123456')",
       function(S, t) m2(S, "1234567890123456", 16L)),
  list("d16z",   "decimal.Decimal('0.1234567890123456')",
       function(S, t) m2(S, "0.1234567890123456", 16L)),
  list("d17n",   "decimal.Decimal('-1.2345678901234567')",
       function(S, t) m2(S, "-1.2345678901234567", 17L)),
  list("dt",     "datetime.datetime(2026, 11, 13, 10, 30)", function(S, t) m5(S, t)),
  list("dtmid",  "datetime.datetime(2026, 11, 13)",         function(S, t) m5(S, t)),
  list("set",    "{1, 2}",        function(S, t) m7(S, t)),
  list("fset",   "frozenset({1})", function(S, t) m7(S, t)),
  list("eset",   "set()",         function(S, t) m7(S, t)),
  list("cplx",   "complex(1, 2)", function(S, t) m6(S, t)),
  list("bytes",  "b'x'",          function(S, t) m6(S, t)),
  list("barr",   "bytearray(b'x')", function(S, t) m6(S, t)),
  list("frac",   "fractions.Fraction(1, 3)", function(S, t) m6(S, t)),
  list("func",   "len",           function(S, t) m6(S, t)),
  list("lam",    "(lambda q: q)", function(S, t) m6(S, t)),
  list("mod",    "sys",           function(S, t) m6(S, t)),
  list("tm",     "datetime.time(1, 2)", function(S, t) m6(S, t)),
  list("td",     "datetime.timedelta(days = 1)", function(S, t) m6(S, t)),
  list("rng",    "range(3)",      function(S, t) m6(S, t)),
  list("obj",    "object()",      function(S, t) m6(S, t)),
  list("inst",   "T5Cls()",       function(S, t) m6(S, t)),
  list("k1",     "{1: 'a'}",      function(S, t) m8(S, t)),
  list("kmix",   "{'a': 1, 2: 3}", function(S, t) m8(S, t)),
  list("knone",  "{None: 1}",     function(S, t) m8(S, t)),
  list("ktup",   "{(1, 2): 3}",   function(S, t) m8(S, t)),
  list("mx1",    "[1, 'a']",      function(S, t) m3(S, t, "integer, string")),
  list("mxb",    "[True, 1]",     function(S, t) m3(S, t, "bool, integer")),
  list("mxb2",   "[1, True]",     function(S, t) m3(S, t, "integer, bool")),
  list("mxfd",   "[1.5, decimal.Decimal('2')]", function(S, t) m3(S, t, "float, decimal")),
  list("mxifd",  "[1, 1.5, decimal.Decimal('2')]", function(S, t) m3(S, t, "integer, float, decimal")),
  list("mxt",    "('a', 1)",      function(S, t) m3(S, t, "string, integer")),
  list("mxisf",  "[1, 'a', 1.5]", function(S, t) m3(S, t, "integer, string, float")),
  list("mxifs",  "[1, 2.5, 'a']", function(S, t) m3(S, t, "integer, float, string")),
  list("mxnone", "[None, 1, 'a']", function(S, t) m3(S, t, "integer, string")),
  list("mxbs",   "[True, 'x']",   function(S, t) m3(S, t, "bool, string")),
  list("mxsd",   "['a', datetime.date(2026, 1, 2)]", function(S, t) m3(S, t, "string, date")),
  list("mxdict", "{'a': 1, 'b': 'x'}", function(S, t) m3(S, t, "integer, string")),
  list("nest",   "[[1]]",         function(S, t) m4(S, t, "list")),
  list("nestt",  "[(1,)]",        function(S, t) m4(S, t, "tuple")),
  list("nestd",  "[{'a': 1}]",    function(S, t) m4(S, t, "dict")),
  list("nests",  "[{1}]",         function(S, t) m4(S, t, "set")),
  list("nestn",  "[None, [1]]",   function(S, t) m4(S, t, "list")),
  list("nestm",  "{'a': [1]}",    function(S, t) m4(S, t, "list"))
)

for (row in REFUSED) local({
  id <- row[[1]]; expr <- row[[2]]; msg <- row[[3]]
  test_that(sprintf("G5 + G7: %s is refused with its exact message", expr), {
    skip_if_no_python()
    py_set("class T5Cls:\n    pass", setNames(expr, nm_(id)))
    type <- py_type_name(nm_(id))
    expect_refused5(py_value(nm_(id)), msg(S_(nm_(id)), type))
  })
})

test_that("G7: {type} is module + qualname with builtins. removed", {
  skip_if_no_python()
  py_set(t_g5_ty1 = "{1}", t_g5_ty2 = "complex(1, 2)", t_g5_ty3 = "decimal.Decimal('0.1')",
         t_g5_ty4 = "datetime.datetime(2026, 1, 1)", t_g5_ty5 = "fractions.Fraction(1, 3)",
         t_g5_ty6 = "b'x'")
  expect_identical(py_type_name("t_g5_ty1"), "set")
  expect_refused5(py_value("t_g5_ty1"), m7(S_("t_g5_ty1"), "set"))
  expect_refused5(py_value("t_g5_ty2"), m6(S_("t_g5_ty2"), "complex"))
  expect_refused5(py_value("t_g5_ty4"), m5(S_("t_g5_ty4"), "datetime.datetime"))
  expect_refused5(py_value("t_g5_ty5"), m6(S_("t_g5_ty5"), "fractions.Fraction"))
  expect_refused5(py_value("t_g5_ty6"), m6(S_("t_g5_ty6"), "bytes"))
})

test_that("G4a: a refusal is a weft_guest_value_error, also weft_value_error and weft_error", {
  skip_if_no_python()
  py_set(t_g5_cl = "2**70")
  e <- expect_error(py_value("t_g5_cl"), class = "weft_guest_value_error")
  expect_s3_class(e, "weft_value_error")
  expect_s3_class(e, "weft_error")
  expect_false(inherits(e, "weft_guest_error"))
})

test_that("G5: a refusal in the record is an error record, with the subject left as {S}", {
  skip_if_no_python()
  py_set(t_g5_er = "{1, 2}", t_g5_er2 = "[1, 'a']", t_g5_er3 = "datetime.datetime(2026, 1, 1)")
  for (n in c("t_g5_er", "t_g5_er2", "t_g5_er3")) {
    rec <- weft:::guest_record(py_obj(n))
    expect_identical(rec$t, "error")
    expect_true(is.character(rec$why) && length(rec$why) == 1L)
    expect_true(grepl("{S}", rec$why, fixed = TRUE))
  }
  expect_match(weft:::guest_record(py_obj("t_g5_er"))$why, "which has no order", fixed = TRUE)
  expect_refused5(weft:::record_value(weft:::guest_record(py_obj("t_g5_er")), "`py$foo`"),
                  m7("`py$foo`", "set"))
})

# ---- G6: lists -----------------------------------------------------------------

LISTS <- list(
  list("[1, 2]",              c(1L, 2L), "int"),
  list("[1, 2.5]",            c(1, 2.5), "float"),
  list("[1.5, 2]",            c(1.5, 2), "float"),
  list("[1, None]",           c(1L, NA), "int"),
  list("[None, 1]",           c(NA, 1L), "int"),
  list("[None, None]",        c(NA, NA), "missing"),
  list("[None]",              NA,        "missing"),
  list("[1, 2**31]",          c(1, 2147483648), "int"),
  list("[2**31 - 1, -(2**31 - 1)]", c(2147483647L, -2147483647L), "int"),
  list("[2**53, 1]",          c(9007199254740992, 1), "int"),
  list("[1, decimal.Decimal('0.5')]", c(1, 0.5), "decimal"),
  list("[decimal.Decimal('0.5'), decimal.Decimal('0.25')]", c(0.5, 0.25), "decimal"),
  list("[decimal.Decimal('0.5'), None]", c(0.5, NA), "decimal"),
  list("[1, 2.5, None]",      c(1, 2.5, NA), "float"),
  list("[1.5, float('nan')]", c(1.5, NA), "float"),
  list("['a', 'b']",          c("a", "b"), "string"),
  list("['a', None]",         c("a", NA), "string"),
  list("['caf\\u00e9', '\\u4e2d']", c("caf\u00e9", "\u4e2d"), "string"),
  list("[True, False]",       c(TRUE, FALSE), "bool"),
  list("[True, None, False]", c(TRUE, NA, FALSE), "bool"),
  list("[datetime.date(2026, 1, 2)]", as.Date("2026-01-02"), "date"),
  list("[None, datetime.date(2026, 1, 2)]", as.Date(c(NA, "2026-01-02")), "date"),
  list("(1, 2)",              c(1L, 2L), "int"),
  list("('a', 'b')",          c("a", "b"), "string"),
  list("[]",                  logical(0), "missing"),
  list("()",                  logical(0), "missing"),
  list("{}",                  logical(0), "missing")
)

for (i in seq_along(LISTS)) local({
  expr <- LISTS[[i]][[1]]; want <- LISTS[[i]][[2]]; of <- LISTS[[i]][[3]]; id <- paste0("ls", i)
  test_that(sprintf("G6: %s is a list of %s and the R vector %s", expr, of,
                    paste(deparse(want), collapse = "")), {
    skip_if_no_python()
    py_set(setNames(expr, nm_(id)))
    rec <- weft:::guest_record(py_obj(nm_(id)))
    expect_identical(rec$t, "list")
    expect_identical(rec$of, of)
    expect_identical(py_value(nm_(id)), want)
  })
})

test_that("G6: a list record holds one scalar record per element, in order, as read", {
  skip_if_no_python()
  py_set(t_g5_lr = "[1, None, 3]", t_g5_lr2 = "['a', 'b']", t_g5_lr3 = "[1, 2.5]")
  rec <- weft:::guest_record(py_obj("t_g5_lr"))
  expect_length(rec$v, 3L)
  expect_identical(vapply(rec$v, function(r) r$t, ""), c("int", "missing", "int"))
  expect_identical(rec$v[[1]]$v, "1")
  expect_identical(rec$v[[3]]$v, "3")
  expect_null(rec$keys)
  rec2 <- weft:::guest_record(py_obj("t_g5_lr2"))
  expect_identical(vapply(rec2$v, function(r) r$v, ""), c("a", "b"))
  # promotion is in `of`; the elements stay as read
  rec3 <- weft:::guest_record(py_obj("t_g5_lr3"))
  expect_identical(rec3$of, "float")
  expect_identical(vapply(rec3$v, function(r) r$t, ""), c("int", "float"))
})

test_that("G6: integers with floats are floats; integers with decimals are decimals; float with decimal is refused", {
  skip_if_no_python()
  py_set(t_g5_p1 = "[1, 2.5]", t_g5_p2 = "[1, decimal.Decimal('0.5')]",
         t_g5_p3 = "[1.5, decimal.Decimal('2')]")
  expect_identical(typeof(py_value("t_g5_p1")), "double")
  expect_identical(typeof(py_value("t_g5_p2")), "double")
  expect_refused5(py_value("t_g5_p3"), m3(S_("t_g5_p3"), "list", "float, decimal"))
})

test_that("G6: an integer list is an R integer vector within +-(2^31 - 1), else a double vector", {
  skip_if_no_python()
  py_set(t_g5_i1 = "[1, 2, 3]", t_g5_i2 = "[1, 2**31]", t_g5_i3 = "[-2**31]")
  expect_identical(typeof(py_value("t_g5_i1")), "integer")
  expect_identical(typeof(py_value("t_g5_i2")), "double")
  expect_identical(py_value("t_g5_i3"), -2147483648)
})

test_that("G6: an integer list element beyond 2^53 refuses the whole read (M1)", {
  skip_if_no_python()
  py_set(t_g5_lb = "[1, 2**53 + 1]", t_g5_lb2 = "[2**70]")
  expect_refused5(py_value("t_g5_lb"), m1(S_("t_g5_lb"), "9007199254740993"))
  expect_refused5(py_value("t_g5_lb2"), m1(S_("t_g5_lb2"), "1180591620717411303424"))
})

test_that("G6: a decimal list element of more than 15 digits refuses the whole read (M2)", {
  skip_if_no_python()
  py_set(t_g5_ld = "[1, decimal.Decimal('1.234567890123456')]")
  expect_refused5(py_value("t_g5_ld"), m2(S_("t_g5_ld"), "1.234567890123456", 16L))
})

# ---- G6: mappings ----------------------------------------------------------------

test_that("G6: a mapping with str keys is a list with names, in the mapping's order", {
  skip_if_no_python()
  py_set(t_g5_m1 = "{'a': 1.5, 'b': 2}", t_g5_m2 = "{'z': 1, 'a': 2}",
         t_g5_m3 = "{'a': 'x', 'b': None}", t_g5_m4 = "{'a': True}",
         t_g5_m5 = "{'a': None, 'b': 1}", t_g5_m6 = "collections.OrderedDict([('q', 1), ('p', 2)])",
         t_g5_m7 = "types.MappingProxyType({'a': 1})", t_g5_m8 = "{}")
  expect_identical(py_value("t_g5_m1"), c(a = 1.5, b = 2))
  expect_identical(py_value("t_g5_m2"), c(z = 1L, a = 2L))
  expect_identical(py_value("t_g5_m3"), c(a = "x", b = NA_character_))
  expect_identical(py_value("t_g5_m4"), c(a = TRUE))
  expect_identical(py_value("t_g5_m5"), c(a = NA, b = 1L))
  expect_identical(py_value("t_g5_m6"), c(q = 1L, p = 2L))
  expect_identical(py_value("t_g5_m7"), c(a = 1L))
  expect_identical(py_value("t_g5_m8"), logical(0))
  expect_null(names(py_value("t_g5_m8")))
})

test_that("G6: a mapping record carries its keys; any other list has none", {
  skip_if_no_python()
  py_set(t_g5_mk = "{'z': 1, 'a': 2}", t_g5_mk2 = "[1, 2]")
  rec <- weft:::guest_record(py_obj("t_g5_mk"))
  expect_identical(rec$t, "list")
  expect_identical(rec$keys, c("z", "a"))
  expect_null(weft:::guest_record(py_obj("t_g5_mk2"))$keys)
})

# ---- the record to the R value, by hand (no Python is touched) ------------------

test_that("record_value() turns each kind of record into its R form (2.12.5)", {
  rv <- function(rec) weft:::record_value(rec, "`py$x`")
  expect_identical(rv(list(t = "bool", v = TRUE)), TRUE)
  expect_identical(rv(list(t = "int", v = "7")), 7L)
  expect_identical(rv(list(t = "int", v = "2147483647")), 2147483647L)
  expect_identical(rv(list(t = "int", v = "-2147483647")), -2147483647L)
  expect_identical(rv(list(t = "int", v = "2147483648")), 2147483648)
  expect_identical(rv(list(t = "int", v = "9007199254740992")), 9007199254740992)
  expect_identical(rv(list(t = "int", v = "-9007199254740992")), -9007199254740992)
  expect_identical(rv(list(t = "float", v = "0.1")), 0.1)
  expect_identical(rv(list(t = "float", v = "1e+22")), 1e22)
  expect_identical(rv(list(t = "decimal", v = "0.15")), 0.15)
  expect_identical(rv(list(t = "decimal", v = "123456789012345")), 123456789012345)
  expect_identical(rv(list(t = "decimal", v = "1.50000000000000000000")), 1.5)
  expect_identical(rv(list(t = "decimal", v = "1E+2")), 100)
  expect_identical(rv(list(t = "string", v = "caf\u00e9")), "caf\u00e9")
  expect_identical(rv(list(t = "date", v = "2026-11-13")), as.Date("2026-11-13"))
  expect_identical(rv(list(t = "missing", v = NA_character_, why = "None")), NA)
})

test_that("record_value() holds the refusals of V2 and V3 (M1, M2), with the subject it is given", {
  rv <- function(rec, S = "`py$x`") weft:::record_value(rec, S)
  expect_refused5(rv(list(t = "int", v = "9007199254740993")), m1("`py$x`", "9007199254740993"))
  expect_refused5(rv(list(t = "int", v = "-9007199254740993")), m1("`py$x`", "-9007199254740993"))
  expect_refused5(rv(list(t = "int", v = "1180591620717411303424"), "`py_value(\"big\")`"),
                  m1("`py_value(\"big\")`", "1180591620717411303424"))
  expect_refused5(rv(list(t = "decimal", v = "1.234567890123456")),
                  m2("`py$x`", "1.234567890123456", 16L))
  expect_refused5(rv(list(t = "decimal", v = "1234567890123456")),
                  m2("`py$x`", "1234567890123456", 16L))
  expect_refused5(rv(list(t = "error", why = "{S} is a Python set, which has no order. Bind sorted() of it in a Python chunk (rule 1.11.4).")),
                  m7("`py$x`", "set"))
})

test_that("record_value() turns a list record into an atomic vector, with names from keys and the promotions", {
  rv <- function(rec) weft:::record_value(rec, "`py$x`")
  el <- function(t, v) list(t = t, v = v)
  miss <- list(t = "missing", v = NA_character_, why = "None")
  expect_identical(rv(list(t = "list", of = "int", keys = NULL, v = list(el("int", "1"), el("int", "2")))),
                   c(1L, 2L))
  expect_identical(rv(list(t = "list", of = "float", keys = NULL, v = list(el("int", "1"), el("float", "2.5")))),
                   c(1, 2.5))
  expect_identical(rv(list(t = "list", of = "int", keys = NULL, v = list(el("int", "1"), miss))), c(1L, NA))
  expect_identical(rv(list(t = "list", of = "int", keys = NULL, v = list(el("int", "1"), el("int", "2147483648")))),
                   c(1, 2147483648))
  expect_identical(rv(list(t = "list", of = "missing", keys = NULL, v = list(miss, miss))), c(NA, NA))
  expect_identical(rv(list(t = "list", of = "missing", keys = NULL, v = list())), logical(0))
  expect_identical(rv(list(t = "list", of = "int", keys = c("a", "b"), v = list(el("int", "1"), el("int", "2")))),
                   c(a = 1L, b = 2L))
  expect_identical(rv(list(t = "list", of = "string", keys = NULL, v = list(el("string", "a"), miss))),
                   c("a", NA))
  expect_refused5(rv(list(t = "list", of = "int", keys = NULL, v = list(el("int", "1"), el("int", "9007199254740993")))),
                  m1("`py$x`", "9007199254740993"))
})

# ---- G8: py_value() --------------------------------------------------------------

test_that("G8: py_value(name) reads a name in main; a path steps by key, then attribute", {
  skip_if_no_python()
  py_set("class T5Obj:\n    pass",
         t_g5_cfg = "{'depth': 2.5, 'items': 5, 'inner': {'depth': 7}, 'tags': ['a', 'b']}",
         t_g5_obj = "T5Obj()")
  py_set("t_g5_obj.depth = 4", "t_g5_obj.cfg = {'depth': 9}", "t_g5_obj.name = 'zed'")
  expect_identical(py_value("t_g5_cfg", "depth"), 2.5)
  expect_identical(py_value("t_g5_cfg", "inner", "depth"), 7L)
  expect_identical(py_value("t_g5_cfg", "tags"), c("a", "b"))
  # a mapping's key wins over a method of the same name
  expect_identical(py_value("t_g5_cfg", "items"), 5L)
  # an attribute when it is not a mapping
  expect_identical(py_value("t_g5_obj", "depth"), 4L)
  expect_identical(py_value("t_g5_obj", "name"), "zed")
  # key after attribute
  expect_identical(py_value("t_g5_obj", "cfg", "depth"), 9L)
})

test_that("G8: py_value() reads the last object by G5, so a path ends in a refusal like a name does", {
  skip_if_no_python()
  py_set(t_g5_pc = "{'big': 2**53 + 1, 'ok': 3}")
  expect_refused5(pyv("t_g5_pc", "big"), m1("`py_value(\"t_g5_pc\", \"big\")`", "9007199254740993"))
  expect_identical(py_value("t_g5_pc", "ok"), 3L)
})

test_that("G8: a step that is not one non-empty string is a weft_error with the stated text", {
  skip_if_no_python()
  expect_refused5(py_value(1), m_args, class = "weft_error")
  expect_refused5(py_value(""), m_args, class = "weft_error")
  expect_refused5(py_value(c("a", "b")), m_args, class = "weft_error")
  expect_refused5(py_value(NA_character_), m_args, class = "weft_error")
  expect_refused5(py_value(NULL), m_args, class = "weft_error")
  expect_refused5(py_value("t_g5_cfg", 2), m_args, class = "weft_error")
  expect_refused5(py_value("t_g5_cfg", ""), m_args, class = "weft_error")
})

test_that("G8: py_value() works outside a knit and without library(reticulate)", {
  skip_if_no_python()
  py_set(t_g5_out = "12")
  expect_identical(py_value("t_g5_out"), 12L)
  expect_false("package:reticulate" %in% search())
})

test_that("G4: py_value is exported", {
  expect_true("py_value" %in% getNamespaceExports("weft"))
})

# ---- G8, G7: M13 to M16 --------------------------------------------------------

test_that("M13: a name that is not in main is a weft_guest_error with the stated text", {
  skip_if_no_python()
  e <- expect_error(py_value("t_g5_nosuch_zz"), class = "weft_guest_error")
  expect_s3_class(e, "weft_error")
  expect_false(inherits(e, "weft_guest_value_error"))
  expect_identical(msg5(e), m13("py_value(\"t_g5_nosuch_zz\")", "t_g5_nosuch_zz"))
  expect_refused5(pyv("t_g5_nosuch_zz", "x"),
                  m13("py_value(\"t_g5_nosuch_zz\", \"x\")", "t_g5_nosuch_zz"),
                  class = "weft_guest_error")
})

test_that("M14: a step that is neither a key nor an attribute is a weft_guest_error", {
  skip_if_no_python()
  py_set("class T5Obj2:\n    pass", t_g5_c14 = "{'depth': 1}", t_g5_o14 = "T5Obj2()")
  py_set("t_g5_o14.cfg = {'depth': 1}")
  expect_refused5(pyv("t_g5_c14", "zzz"),
                  m14("py_value(\"t_g5_c14\", \"zzz\")", "py_value(\"t_g5_c14\")", "zzz"),
                  class = "weft_guest_error")
  expect_refused5(pyv("t_g5_o14", "cfg", "zzz"),
                  m14("py_value(\"t_g5_o14\", \"cfg\", \"zzz\")", "py_value(\"t_g5_o14\", \"cfg\")", "zzz"),
                  class = "weft_guest_error")
})

test_that("M15: without reticulate (the seam) a read is a weft_guest_error", {
  withr::local_options(weft.reticulate = FALSE)
  expect_refused5(py_value("t_g5_x"), m15("py_value(\"t_g5_x\")"), class = "weft_guest_error")
})

test_that("M16: when reticulate cannot start Python a read is a weft_guest_error (fresh process)", {
  skip_if_no_reticulate()
  out <- r5_fresh(c(
    "library(weft)",
    "e <- tryCatch(py_value(\"x\"), error = function(e) e)",
    "cat(paste(class(e), collapse = \" \"), \"\\n\", sep = \"\")",
    "cat(paste(conditionMessage(e), collapse = \" \"), \"\\n\", sep = \"\")"
  ), env = c(RETICULATE_PYTHON = "/nonexistent/weft-no-python"))
  expect_match(out[1], "weft_guest_error", fixed = TRUE)
  expect_false(grepl("weft_guest_value_error", out[1], fixed = TRUE))
  msg <- trimws(gsub("[[:space:]]+", " ", cli::ansi_strip(paste(out[-1], collapse = " "))))
  expect_true(startsWith(msg, m16_start("py_value(\"x\")")), label = msg)
  expect_match(msg, "(rule 2.12.6).", fixed = TRUE)
})

# ---- G16: Python's state is left alone -----------------------------------------------

test_that("G16: a refused read leaves no pending Python error", {
  skip_if_no_python()
  py_set(t_g5_pend = "2**70", t_g5_pend2 = "[1, 'a']", t_g5_pend3 = "{1, 2}")
  for (n in c("t_g5_pend", "t_g5_pend2", "t_g5_pend3")) {
    expect_error(py_value(n), class = "weft_guest_value_error")
    expect_identical(reticulate::py_eval("1 + 1"), 2L)
  }
  expect_error(py_value("t_g5_nosuch_zz"), class = "weft_guest_error")
  expect_identical(reticulate::py_eval("1 + 1"), 2L)
})

test_that("G16: a read assigns no name in Python's main module", {
  skip_if_no_python()
  py_set(t_g5_st = "{'a': [1, 2]}", t_g5_st2 = "[1, 'a']")
  before <- reticulate::py_eval("sorted(globals().keys())")
  invisible(py_value("t_g5_st"))
  invisible(py_value("t_g5_st", "a"))
  try(py_value("t_g5_st2"), silent = TRUE)
  try(py_value("t_g5_nosuch_zz"), silent = TRUE)
  after <- reticulate::py_eval("sorted(globals().keys())")
  expect_identical(after, before)
  expect_false(reticulate::py_eval("'weft_guest' in globals()"))
})

# ---- numpy ------------------------------------------------------------------------------

NUMPY <- list(
  list("bt",   "np.bool_(True)",       TRUE),
  list("bf",   "np.bool_(False)",      FALSE),
  list("i8",   "np.int8(5)",           5L),
  list("i16",  "np.int16(-5)",         -5L),
  list("i32",  "np.int32(7)",          7L),
  list("i64",  "np.int64(7)",          7L),
  list("u8",   "np.uint8(200)",        200L),
  list("u32",  "np.uint32(4294967295)", 4294967295),
  list("u64",  "np.uint64(5)",         5L),
  list("i40",  "np.int64(2**40)",      1099511627776),
  list("i53",  "np.int64(2**53)",      9007199254740992),
  list("f64",  "np.float64(3.14)",     3.14),
  list("f32",  "np.float32(0.5)",      0.5),
  list("f16",  "np.float16(0.5)",      0.5),
  list("nan",  "np.nan",               NA),
  list("nan32", "np.float32('nan')",   NA),
  list("pinf", "np.inf",               NA),
  list("ninf", "-np.inf",              NA),
  list("inf16", "np.float16('inf')",   NA),
  list("str",  "np.str_('abc')",       "abc"),
  list("dt64", "np.datetime64('2026-11-13')",      as.Date("2026-11-13")),
  list("dt64d", "np.datetime64('2026-11-13', 'D')", as.Date("2026-11-13")),
  list("nat",  "np.datetime64('NaT')", NA),
  list("a1",   "np.array([1, 2, 3])",  c(1L, 2L, 3L)),
  list("a2",   "np.array([1.5, 2.5])", c(1.5, 2.5)),
  list("a3",   "np.array([1.5, np.nan])", c(1.5, NA)),
  list("a4",   "np.array([True, False])", c(TRUE, FALSE)),
  list("a5",   "np.array(['a', 'b'])", c("a", "b")),
  list("a6",   "np.array([])",         logical(0)),
  list("a7",   "np.array([2**40, 1])", c(1099511627776, 1)),
  list("a8",   "np.array(5)",          5L),
  list("a9",   "np.array(2.5)",        2.5),
  list("a10",  "np.array([np.datetime64('2026-01-02')])", as.Date("2026-01-02")),
  list("a11",  "np.array([1, None], dtype = object)", c(1L, NA))
)

for (row in NUMPY) local({
  id <- row[[1]]; expr <- row[[2]]; want <- row[[3]]
  test_that(sprintf("G5 numpy: %s reads as %s", expr, paste(deparse(want), collapse = "")), {
    skip_if_no_py_module("numpy")
    py_set("import numpy as np", setNames(expr, nm_(paste0("np_", id))))
    expect_identical(py_value(nm_(paste0("np_", id))), want)
  })
})

test_that("G5 numpy: a float32 is widened exactly", {
  skip_if_no_py_module("numpy")
  py_set("import numpy as np", t_g5_np_f32 = "np.float32(0.1)")
  expect_identical(py_value("t_g5_np_f32"), reticulate::py_eval("float(np.float32(0.1))"))
  expect_false(identical(py_value("t_g5_np_f32"), 0.1))
})

test_that("G5 numpy: integers beyond 2^53 are refused, signed or unsigned (M1)", {
  skip_if_no_py_module("numpy")
  py_set("import numpy as np", t_g5_np_a = "np.int64(2**53 + 1)", t_g5_np_b = "np.uint64(2**64 - 1)",
         t_g5_np_c = "np.int64(-2**63)", t_g5_np_d = "np.array([1, 2**53 + 1])")
  expect_refused5(py_value("t_g5_np_a"), m1(S_("t_g5_np_a"), "9007199254740993"))
  expect_refused5(py_value("t_g5_np_b"), m1(S_("t_g5_np_b"), "18446744073709551615"))
  expect_refused5(py_value("t_g5_np_c"), m1(S_("t_g5_np_c"), "-9223372036854775808"))
  expect_refused5(py_value("t_g5_np_d"), m1(S_("t_g5_np_d"), "9007199254740993"))
})

test_that("G5 numpy: a datetime64 of any unit but D is refused (M5)", {
  skip_if_no_py_module("numpy")
  py_set("import numpy as np", t_g5_np_t1 = "np.datetime64('2026-11-13T10:30')",
         t_g5_np_t2 = "np.datetime64('2026-11', 'M')")
  expect_refused5(py_value("t_g5_np_t1"), m5(S_("t_g5_np_t1"), "numpy.datetime64"))
  expect_refused5(py_value("t_g5_np_t2"), m5(S_("t_g5_np_t2"), "numpy.datetime64"))
})

test_that("G5 numpy: arrays of 2 or more dimensions are refused (M9)", {
  skip_if_no_py_module("numpy")
  py_set("import numpy as np", t_g5_np_2d = "np.array([[1, 2], [3, 4]])",
         t_g5_np_3d = "np.zeros((2, 2, 2))")
  expect_refused5(py_value("t_g5_np_2d"), m9(S_("t_g5_np_2d"), 2L))
  expect_refused5(py_value("t_g5_np_3d"), m9(S_("t_g5_np_3d"), 3L))
})

test_that("G6 numpy: an array of mixed kinds is refused with the array's type (M3)", {
  skip_if_no_py_module("numpy")
  py_set("import numpy as np", t_g5_np_mx = "np.array(['a', 1], dtype = object)")
  expect_refused5(py_value("t_g5_np_mx"), m3(S_("t_g5_np_mx"), "numpy.ndarray", "string, integer"))
})

# ---- pandas -----------------------------------------------------------------------------

PANDAS <- list(
  list("s1",  "pd.Series([1, 2, 3])",       c(1L, 2L, 3L)),
  list("s2",  "pd.Series([1.5, 2.5])",      c(1.5, 2.5)),
  list("s3",  "pd.Series([1.5, None])",     c(1.5, NA)),
  list("s4",  "pd.Series(['a', 'b'])",      c("a", "b")),
  list("s5",  "pd.Series([True, False])",   c(TRUE, FALSE)),
  list("s6",  "pd.Series([], dtype = 'float64')", logical(0)),
  list("s7",  "pd.Series([1, None], dtype = 'Int64')", c(1L, NA)),
  list("s8",  "pd.Series(['a', None])",     c("a", NA)),
  list("na",  "pd.NA",                      NA),
  list("nat", "pd.NaT",                     NA)
)

for (row in PANDAS) local({
  id <- row[[1]]; expr <- row[[2]]; want <- row[[3]]
  test_that(sprintf("G5 pandas: %s reads as %s", expr, paste(deparse(want), collapse = "")), {
    skip_if_no_py_module("pandas")
    py_set("import pandas as pd", setNames(expr, nm_(paste0("pd_", id))))
    expect_identical(py_value(nm_(paste0("pd_", id))), want)
  })
})

test_that("G5 pandas: a Timestamp is refused (M5), a DataFrame is refused (M6)", {
  skip_if_no_py_module("pandas")
  py_set("import pandas as pd", t_g5_pd_ts = "pd.Timestamp('2026-11-13')",
         t_g5_pd_df = "pd.DataFrame({'a': [1, 2], 'b': ['x', 'y']})")
  expect_refused5(py_value("t_g5_pd_ts"), m5(S_("t_g5_pd_ts"), py_type_name("t_g5_pd_ts")))
  expect_refused5(py_value("t_g5_pd_df"), m6(S_("t_g5_pd_df"), py_type_name("t_g5_pd_df")))
})

test_that("G8 + G9 pandas: a column is read through an attribute step, as a list", {
  skip_if_no_py_module("pandas")
  py_set("import pandas as pd", t_g5_pd_df2 = "pd.DataFrame({'a': [1, 2], 'b': ['x', 'y']})")
  expect_identical(py_value("t_g5_pd_df2", "a"), c(1L, 2L))
  expect_identical(py_value("t_g5_pd_df2", "b"), c("x", "y"))
})

test_that("G6 pandas: a Series of mixed kinds is refused with the Series' type (M3)", {
  skip_if_no_py_module("pandas")
  py_set("import pandas as pd", t_g5_pd_mx = "pd.Series([1, 'a'], dtype = object)")
  expect_refused5(py_value("t_g5_pd_mx"),
                  m3(S_("t_g5_pd_mx"), py_type_name("t_g5_pd_mx"), "integer, string"))
})
