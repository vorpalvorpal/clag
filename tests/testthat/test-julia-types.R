# Stage 5J-a: reading Julia values, outside a knit (J1, J2, J6 to J8, J14,
# 1.11, 2.12.15, 2.12.16). J1 row by row through jl_value(): kind, R type and
# value. Every refusal's class and exact message (J7). J6's lists. The typed
# record (jl_record(), fixed in helper-5j.R). Julia's state (J14). Julia is
# shared by every test in the file, so every test uses names of its own
# (t_j5_...). A scalar `missing` is never read in this process: it is read in
# the file's one fresh process (J14), so that a crash fails the test and does
# not kill the run.

S_ <- function(name) sprintf("`jl_value(\"%s\")`", name)
nm_ <- function(id) paste0("t_j5_", id)

# ---- J1: scalars, as records and as R values ------------------------------------

# id, julia expression, record kind, record value (NULL: not checked), R value
SCALARS_J <- list(
  list("true",    "true",                  "bool",   TRUE,  TRUE),
  list("false",   "false",                 "bool",   FALSE, FALSE),
  list("i32",     "Int32(7)",              "int",    "7",   7L),
  list("big7",    "big(7)",                "int",    "7",   7L),
  list("u8",      "UInt8(200)",            "int",    "200", 200L),
  list("i8n",     "Int8(-5)",              "int",    "-5",  -5L),
  list("i128",    "Int128(5)",             "int",    "5",   5L),
  list("u128",    "UInt128(9)",            "int",    "9",   9L),
  list("int0",    "0",                     "int",    "0",   0L),
  list("i31m",    "2^31 - 1",              "int",    "2147483647",  2147483647L),
  list("i31mn",   "-(2^31 - 1)",           "int",    "-2147483647", -2147483647L),
  list("i31",     "2^31",                  "int",    "2147483648",  2147483648),
  list("i31n",    "-(2^31)",               "int",    "-2147483648", -2147483648),
  list("i40",     "2^40",                  "int",    "1099511627776", 1099511627776),
  list("i53",     "2^53",                  "int",    "9007199254740992",  9007199254740992),
  list("i53n",    "-(2^53)",               "int",    "-9007199254740992", -9007199254740992),
  list("b31",     "big(2)^31",             "int",    "2147483648",  2147483648),
  list("b53",     "big(2)^53",             "int",    "9007199254740992",  9007199254740992),
  list("u32",     "UInt32(2)^31",          "int",    "2147483648",  2147483648),
  list("f01",     "0.1",                   "float",  "0.1", 0.1),
  list("f25",     "2.5",                   "float",  "2.5", 2.5),
  list("f22",     "1e22",                  "float",  NULL,  1e22),
  list("f3",      "3.0",                   "float",  NULL,  3),
  list("fneg",    "-3.25",                 "float",  "-3.25", -3.25),
  list("f32",     "Float32(0.1)",          "float",  "0.10000000149011612", 0.10000000149011612),
  list("f32b",    "Float32(2.5)",          "float",  "2.5", 2.5),
  list("f16",     "Float16(0.1)",          "float",  "0.0999755859375", 0.0999755859375),
  list("str",     "\"abc\"",               "string", "abc", "abc"),
  list("stremp",  "\"\"",                  "string", "",    ""),
  list("strnon",  "\"héllo 中文 \U0001F600\"", "string",
       "héllo 中文 \U0001F600", "héllo 中文 \U0001F600"),
  list("strnum",  "\"42\"",                "string", "42",  "42"),
  list("substr",  "SubString(\"hello\", 1, 3)", "string", "hel", "hel"),
  list("char",    "'a'",                   "string", "a",   "a"),
  list("charnon", "'é'",              "string", "é", "é"),
  list("sym",     ":north",                "string", "north", "north"),
  list("date",    "Dates.Date(2026, 11, 13)", "date", "2026-11-13", as.Date("2026-11-13")),
  list("datelp",  "Dates.Date(2024, 2, 29)",  "date", "2024-02-29", as.Date("2024-02-29")),
  list("zerod",   "fill(3)",               "int",    "3",   3L)
)

for (row in SCALARS_J) local({
  id <- row[[1]]; expr <- row[[2]]; kind <- row[[3]]; v <- row[[4]]; want <- row[[5]]
  test_that(sprintf("J1: %s is a %s record and the R value %s", expr, kind,
                    paste(format(want), collapse = " ")), {
    skip_if_no_julia()
    jl_set(setNames(expr, nm_(id)))
    rec <- weft:::jl_record(nm_(id))
    expect_identical(rec$t, kind)
    if (!is.null(v)) expect_identical(rec$v, v)
    expect_identical(jl_value(nm_(id)), want)
  })
})

test_that("J1: a Bool is never an integer, and an integer is never a Bool", {
  skip_if_no_julia()
  jl_set(t_j5_bb1 = "true", t_j5_ii1 = "1")
  expect_identical(jl_value("t_j5_bb1"), TRUE)
  expect_identical(jl_value("t_j5_ii1"), 1L)
  expect_identical(weft:::jl_record(nm_("bb1"))$t, "bool")
  expect_identical(weft:::jl_record(nm_("ii1"))$t, "int")
})

test_that("J1 + 2.12.16: UInt8(200) is 200L, where JuliaCall's own route gave raw 0xc8", {
  skip_if_no_julia()
  jl_set(t_j5_u8b = "UInt8(200)")
  v <- jl_value("t_j5_u8b")
  expect_type(v, "integer")
  expect_identical(v, 200L)
})

test_that("J1 + 1.11.2: big integers are held as digit strings in the record, exactly", {
  skip_if_no_julia()
  jl_set(t_j5_r53p = "2^53 + 1", t_j5_r70 = "big(2)^70", t_j5_r70n = "-(big(2)^70)",
         t_j5_rmax = "typemax(Int64)", t_j5_r53pn = "-(2^53 + 1)", t_j5_rumax = "typemax(UInt64)")
  rec <- weft:::jl_record(nm_("r53p"))
  expect_identical(c(rec$t, rec$v), c("int", "9007199254740993"))
  rec <- weft:::jl_record(nm_("r53pn"))
  expect_identical(c(rec$t, rec$v), c("int", "-9007199254740993"))
  rec <- weft:::jl_record(nm_("r70"))
  expect_identical(c(rec$t, rec$v), c("int", "1180591620717411303424"))
  rec <- weft:::jl_record(nm_("r70n"))
  expect_identical(c(rec$t, rec$v), c("int", "-1180591620717411303424"))
  rec <- weft:::jl_record(nm_("rmax"))
  expect_identical(c(rec$t, rec$v), c("int", "9223372036854775807"))
  rec <- weft:::jl_record(nm_("rumax"))
  expect_identical(c(rec$t, rec$v), c("int", "18446744073709551615"))
})

# ---- J1: missing -----------------------------------------------------------------

# a scalar `missing` is not here: it is read in the fresh process below
MISSING_J <- c(nothing = "nothing", nan = "NaN", inf = "Inf", ninf = "-Inf",
               nan32 = "NaN32", nan16 = "NaN16", inf32 = "Inf32", f64nan = "Float64(NaN)")

for (id in names(MISSING_J)) local({
  id <- id; expr <- MISSING_J[[id]]
  test_that(sprintf("J1 + 1.11.7: %s is missing: a record with a reason, and NA", expr), {
    skip_if_no_julia()
    jl_set(setNames(expr, nm_(paste0("m_", id))))
    rec <- weft:::jl_record(nm_(paste0("m_", id)))
    expect_identical(rec$t, "missing")
    expect_true(is.character(rec$why) && length(rec$why) == 1L && nzchar(rec$why))
    expect_identical(jl_value(nm_(paste0("m_", id))), NA)
  })
})

# ---- J1, J7: refusals ----------------------------------------------------------------

# id, julia (right side), message builder f(S, type)
REFUSED_J <- list(
  list("r53p",   "2^53 + 1",          function(S, t) jm1(S, t, "9007199254740993")),
  list("r53pn",  "-(2^53 + 1)",       function(S, t) jm1(S, t, "-9007199254740993")),
  list("r54",    "2^54",              function(S, t) jm1(S, t, "18014398509481984")),
  list("rmax",   "typemax(Int64)",    function(S, t) jm1(S, t, "9223372036854775807")),
  list("rmin",   "typemin(Int64)",    function(S, t) jm1(S, t, "-9223372036854775808")),
  list("r70",    "big(2)^70",         function(S, t) jm1(S, t, "1180591620717411303424")),
  list("r70n",   "-(big(2)^70)",      function(S, t) jm1(S, t, "-1180591620717411303424")),
  list("r128",   "Int128(2)^70",      function(S, t) jm1(S, t, "1180591620717411303424")),
  list("rumax",  "typemax(UInt64)",   function(S, t) jm1(S, t, "18446744073709551615")),
  list("rb53p",  "big(2)^53 + 1",     function(S, t) jm1(S, t, "9007199254740993")),
  list("rat",    "1//3",              function(S, t) jm2(S, t)),
  list("rat0",   "0//1",              function(S, t) jm2(S, t)),
  list("pi",     "pi",                function(S, t) jm2(S, t)),
  list("euler",  "ℯ",            function(S, t) jm2(S, t)),
  list("bigf",   "big(0.1)",          function(S, t) jm2(S, t)),
  list("dt",     "Dates.DateTime(2026, 11, 13, 10, 30)", function(S, t) jm5(S, t)),
  list("dtmid",  "Dates.DateTime(2026, 11, 13)",         function(S, t) jm5(S, t)),
  list("cplx",   "1 + 2im",           function(S, t) jm6(S, t)),
  list("func",   "sin",               function(S, t) jm6(S, t)),
  list("time",   "Dates.Time(1, 2)",  function(S, t) jm6(S, t)),
  list("pair",   "1 => 2",            function(S, t) jm6(S, t)),
  list("mod",    "Main",              function(S, t) jm6(S, t)),
  list("struc",  "T_j5_S(1.5, Dict(\"depth\" => 1))", function(S, t) jm6(S, t)),
  list("dict",   "Dict(\"a\" => 1)",  function(S, t) jm7(S, t)),
  list("dictsym","Dict(:a => 1)",     function(S, t) jm7(S, t)),
  list("dicte",  "Dict{String, Int64}()", function(S, t) jm7(S, t)),
  list("dictf",  "Dict(\"a\" => 1.5, \"b\" => 2)", function(S, t) jm7(S, t)),
  list("set",    "Set([1])",          function(S, t) jm7(S, t)),
  list("sete",   "Set{Int64}()",      function(S, t) jm7(S, t)),
  list("badstr", "String([0xff])",    function(S, t) jm17(S, t)),
  list("badchr", "reinterpret(Char, 0xff000000)", function(S, t) jm17(S, t)),
  list("mx1",    "Any[1, \"a\"]",     function(S, t) jm3(S, t, "integer, string")),
  list("mxb",    "Any[true, 1]",      function(S, t) jm3(S, t, "bool, integer")),
  list("mxb2",   "Any[1, true]",      function(S, t) jm3(S, t, "integer, bool")),
  list("mxtup",  "(1, \"a\")",        function(S, t) jm3(S, t, "integer, string")),
  list("mxnt",   "(a = 1, b = \"x\")", function(S, t) jm3(S, t, "integer, string")),
  list("mxisf",  "Any[1, \"a\", 1.5]", function(S, t) jm3(S, t, "integer, string, float")),
  list("mxifs",  "Any[1, 2.5, \"a\"]", function(S, t) jm3(S, t, "integer, float, string")),
  list("mxmiss", "Any[missing, 1, \"a\"]", function(S, t) jm3(S, t, "integer, string")),
  list("mxsd",   "Any[\"a\", Dates.Date(2026, 1, 2)]", function(S, t) jm3(S, t, "string, date")),
  list("nest",   "[[1], [2]]",        function(S, t) jm4(S, t, "Vector{Int64}")),
  list("nestt",  "Any[(1,)]",         function(S, t) jm4(S, t, "Tuple{Int64}")),
  list("nestd",  "Any[Dict(\"a\" => 1)]", function(S, t) jm4(S, t, "Dict{String, Int64}")),
  list("nests",  "Any[Set([1])]",     function(S, t) jm4(S, t, "Set{Int64}")),
  list("nestn",  "Any[missing, [1]]", function(S, t) jm4(S, t, "Vector{Int64}")),
  list("nestnt", "Any[(a = 1,)]",     function(S, t) jm4(S, t, "@NamedTuple{a::Int64}")),
  list("el53",   "[1, 2^53 + 1]",     function(S, t) jm1(S, "Int64", "9007199254740993")),
  list("elrat",  "[1//2]",            function(S, t) jm2(S, "Rational{Int64}")),
  list("elcplx", "[1 + 2im]",         function(S, t) jm6(S, "Complex{Int64}")),
  list("eldt",   "[Dates.DateTime(2026, 1, 2)]", function(S, t) jm5(S, "DateTime"))
)

for (row in REFUSED_J) local({
  id <- row[[1]]; expr <- row[[2]]; msg <- row[[3]]
  test_that(sprintf("J1 + J7: %s is refused with its exact message", expr), {
    skip_if_no_julia()
    jl_fixtures()
    jl_set(setNames(expr, nm_(id)))
    type <- jl_type(nm_(id))
    expect_refused5(jlv(nm_(id)), msg(S_(nm_(id)), type))
  })
})

test_that("J7: {type} is string(typeof(v)) as Main sees it", {
  skip_if_no_julia()
  jl_set(t_j5_ty1 = "Set([1])", t_j5_ty2 = "1 + 2im", t_j5_ty3 = "1//3", t_j5_ty4 = "pi",
         t_j5_ty5 = "Dates.DateTime(2026, 1, 1)", t_j5_ty6 = "Dict(\"a\" => 1.5)",
         t_j5_ty7 = "2^53 + 1", t_j5_ty8 = "big(2)^70")
  expect_refused5(jlv("t_j5_ty1"), jm7(S_("t_j5_ty1"), "Set{Int64}"))
  expect_refused5(jlv("t_j5_ty2"), jm6(S_("t_j5_ty2"), "Complex{Int64}"))
  expect_refused5(jlv("t_j5_ty3"), jm2(S_("t_j5_ty3"), "Rational{Int64}"))
  expect_refused5(jlv("t_j5_ty4"), jm2(S_("t_j5_ty4"), "Irrational{:π}"))
  expect_refused5(jlv("t_j5_ty5"), jm5(S_("t_j5_ty5"), "DateTime"))
  expect_refused5(jlv("t_j5_ty6"), jm7(S_("t_j5_ty6"), "Dict{String, Float64}"))
  expect_refused5(jlv("t_j5_ty7"), jm1(S_("t_j5_ty7"), "Int64", "9007199254740993"))
  expect_refused5(jlv("t_j5_ty8"), jm1(S_("t_j5_ty8"), "BigInt", "1180591620717411303424"))
})

test_that("J1 + J7: a DataFrame is refused (JM6), with its type as Main sees it", {
  skip_if_no_julia()
  skip_if_not(isTRUE(JuliaCall::julia_eval("isdefined(Main, :RCall) && isdefined(RCall, :DataFrames)")),
              "RCall has no DataFrames")
  jl_set(t_j5_df = "RCall.DataFrames.DataFrame(a = [1])")
  expect_identical(jl_type("t_j5_df"), "DataFrames.DataFrame")
  expect_refused5(jlv("t_j5_df"), jm6(S_("t_j5_df"), "DataFrames.DataFrame"))
})

test_that("J1 + J7: a DateTime is a DateTime after `using Dates`", {
  skip_if_no_julia()
  jl_set(t_j5_dtt = "Dates.DateTime(2026, 11, 13, 10, 30)")
  e <- expect_error(jl_value("t_j5_dtt"), class = "weft_guest_value_error")
  expect_true(grepl("is a Julia DateTime, which holds", msg5(e), fixed = TRUE))
})

test_that("J1 + J7: a matrix is refused with its dimensions (JM9)", {
  skip_if_no_julia()
  jl_set(t_j5_mat = "[1 2; 3 4]", t_j5_mat3 = "zeros(2, 2, 2)")
  expect_refused5(jlv("t_j5_mat"), jm9(S_("t_j5_mat"), 2L))
  expect_refused5(jlv("t_j5_mat3"), jm9(S_("t_j5_mat3"), 3L))
})

test_that("J1 + 1.11.2: BigInt past 2^53 and 2^53 + 1 are refused, 2^53 itself is read", {
  skip_if_no_julia()
  jl_set(t_j5_ok53 = "2^53", t_j5_no53 = "2^53 + 1")
  expect_identical(jl_value("t_j5_ok53"), 9007199254740992)
  expect_error(jl_value("t_j5_no53"), class = "weft_guest_value_error")
})

test_that("J1: a refusal is a weft_guest_value_error, also weft_value_error and weft_error, not a weft_guest_error", {
  skip_if_no_julia()
  jl_set(t_j5_cl = "big(2)^70")
  e <- expect_error(jl_value("t_j5_cl"), class = "weft_guest_value_error")
  expect_s3_class(e, "weft_value_error")
  expect_s3_class(e, "weft_error")
  expect_false(inherits(e, "weft_guest_error"))
})

test_that("J1: a refused read leaves Julia usable (J14)", {
  skip_if_no_julia()
  jl_set(t_j5_us = "big(2)^70")
  expect_error(jl_value("t_j5_us"), class = "weft_guest_value_error")
  expect_identical(JuliaCall::julia_eval("1 + 1"), 2L)
})

# ---- J6: lists ---------------------------------------------------------------------------

# id, julia expression, R value
LISTS_J <- list(
  list("l1",   "[1, 2, 3]",                          c(1L, 2L, 3L)),
  list("l2",   "1:3",                                c(1L, 2L, 3L)),
  list("l3",   "(1, 2.5)",                           c(1, 2.5)),
  list("l4",   "Any[1, 2.5]",                        c(1, 2.5)),
  list("l5",   "Union{Missing, Int}[1, missing, 3]", c(1L, NA, 3L)),
  list("l6",   "Union{Nothing, Int}[1, nothing]",    c(1L, NA)),
  list("l7",   "[missing, missing]",                 c(NA, NA)),
  list("l8",   "[]",                                 logical(0)),
  list("l9",   "Int[]",                              logical(0)),
  list("l10",  "String[]",                           logical(0)),
  list("l11",  "()",                                 logical(0)),
  list("l12",  "(;)",                                logical(0)),
  list("l13",  "[1, 2^31]",                          c(1, 2147483648)),
  list("l14",  "[\"a\", \"b\"]",                     c("a", "b")),
  list("l15",  "['a', 'b']",                         c("a", "b")),
  list("l16",  "[:a, :b]",                           c("a", "b")),
  list("l17",  "[Dates.Date(2026, 1, 2)]",           as.Date("2026-01-02")),
  list("l18",  "(a = 1.5, b = 2)",                   c(a = 1.5, b = 2)),
  list("l19",  "[true, 1]",                          c(1L, 1L)),
  list("l20",  "Any[1, 2]",                          c(1L, 2L)),
  list("l21",  "[true, false]",                      c(TRUE, FALSE)),
  list("l22",  "trues(2)",                           c(TRUE, TRUE)),
  list("l23",  "[1.5, NaN]",                         c(1.5, NA)),
  list("l24",  "[1.5, 2]",                           c(1.5, 2)),
  list("l25",  "[\"héllo\", missing]",          c("héllo", NA)),
  list("l26",  "(a = missing, b = nothing)",         c(a = NA, b = NA)),
  list("l27",  "[UInt8(200), UInt8(1)]",             c(200L, 1L)),
  list("l28",  "[2^40, 1]",                          c(1099511627776, 1)),
  list("l29",  "[1.0f0, 2.5f0]",                     c(1, 2.5)),
  list("l30",  "(1, 2, 3)",                          c(1L, 2L, 3L)),
  list("l31",  "[Dates.Date(2026, 1, 2), missing]",  c(as.Date("2026-01-02"), as.Date(NA))),
  list("l32",  "fill(\"x\")",                        "x")
)

for (row in LISTS_J) local({
  id <- row[[1]]; expr <- row[[2]]; want <- row[[3]]
  test_that(sprintf("J6: %s reads as %s", expr, paste(deparse(want), collapse = "")), {
    skip_if_no_julia()
    jl_set(setNames(expr, nm_(id)))
    expect_identical(jl_value(nm_(id)), want)
  })
})

test_that("J6: an integer list is an integer vector within the 32-bit range and a double vector beyond it", {
  skip_if_no_julia()
  jl_set(t_j5_li1 = "[1, 2^31 - 1]", t_j5_li2 = "[1, 2^31]")
  expect_type(jl_value("t_j5_li1"), "integer")
  expect_type(jl_value("t_j5_li2"), "double")
})

test_that("J6: an all-missing list is logical, an empty list is logical(0), with no names for (;)", {
  skip_if_no_julia()
  jl_set(t_j5_lm1 = "[missing, missing]", t_j5_lm2 = "(;)")
  expect_type(jl_value("t_j5_lm1"), "logical")
  expect_identical(jl_value("t_j5_lm2"), logical(0))
  expect_null(names(jl_value("t_j5_lm2")))
})

test_that("J6: the container's element type does not matter", {
  skip_if_no_julia()
  jl_set(t_j5_ct1 = "Any[1, 2]", t_j5_ct2 = "Number[1, 2]", t_j5_ct3 = "Real[1, 2.5]")
  expect_identical(jl_value("t_j5_ct1"), c(1L, 2L))
  expect_identical(jl_value("t_j5_ct2"), c(1L, 2L))
  expect_identical(jl_value("t_j5_ct3"), c(1, 2.5))
})

test_that("J6: a list's record is the kind, the elements and the keys of a NamedTuple", {
  skip_if_no_julia()
  jl_set(t_j5_rl1 = "[1, 2, 3]", t_j5_rl2 = "(a = 1.5, b = 2)", t_j5_rl3 = "[]",
         t_j5_rl4 = "[missing, missing]", t_j5_rl5 = "[1, 2^31]")
  rec <- weft:::jl_record("t_j5_rl1")
  expect_identical(rec$t, "list")
  expect_identical(rec$of, "int")
  expect_null(rec$keys)
  expect_length(rec$v, 3L)
  expect_identical(rec$v[[1]]$t, "int")
  expect_identical(rec$v[[1]]$v, "1")
  rec <- weft:::jl_record("t_j5_rl2")
  expect_identical(rec$of, "float")
  expect_identical(rec$keys, c("a", "b"))
  expect_identical(weft:::jl_record("t_j5_rl3")$of, "missing")
  expect_identical(weft:::jl_record("t_j5_rl4")$of, "missing")
  expect_identical(weft:::jl_record("t_j5_rl5")$of, "int")
})

# ---- J8: jl_value() -----------------------------------------------------------------------

test_that("J8: jl_value(name) reads a global of Main; a path steps by key, then field", {
  skip_if_no_julia()
  jl_fixtures()
  jl_set(t_j5_cfg = "Dict(\"depth\" => 2.5, \"inner\" => Dict(\"depth\" => 7), \"tags\" => [\"a\", \"b\"])",
         t_j5_cfgs = "Dict(:depth => 3.5)",
         t_j5_ntp = "(depth = 1.5, inner = (depth = 8,))",
         t_j5_st = "T_j5_S(4.5, Dict(\"depth\" => 9))",
         t_j5_modref = "T_j5_Mod")
  expect_identical(jl_value("t_j5_cfg", "depth"), 2.5)
  expect_identical(jl_value("t_j5_cfg", "inner", "depth"), 7L)
  expect_identical(jl_value("t_j5_cfg", "tags"), c("a", "b"))
  # a Symbol key when there is no String key
  expect_identical(jl_value("t_j5_cfgs", "depth"), 3.5)
  # a field of a NamedTuple, and one inside another
  expect_identical(jl_value("t_j5_ntp", "depth"), 1.5)
  expect_identical(jl_value("t_j5_ntp", "inner", "depth"), 8L)
  # a field of a struct, then a key of the Dict in it
  expect_identical(jl_value("t_j5_st", "depth"), 4.5)
  expect_identical(jl_value("t_j5_st", "cfg", "depth"), 9L)
  # a property of a module
  expect_identical(jl_value("t_j5_modref", "depth"), 4.5)
})

test_that("J8: only the last value is read, so a Dict may sit on the path and the last value is refused as J1 says", {
  skip_if_no_julia()
  jl_set(t_j5_pc = "Dict(\"big\" => 2^53 + 1, \"ok\" => 3, \"d\" => Dict(\"a\" => 1))")
  expect_refused5(jlv("t_j5_pc", "big"), jm1("`jl_value(\"t_j5_pc\", \"big\")`", "Int64", "9007199254740993"))
  expect_identical(jl_value("t_j5_pc", "ok"), 3L)
  expect_refused5(jlv("t_j5_pc", "d"), jm7("`jl_value(\"t_j5_pc\", \"d\")`", "Dict{String, Int64}"))
})

test_that("J8: a step that is not one non-empty string is a weft_error with the stated text", {
  skip_if_no_julia()
  expect_refused5(jl_value(1), m_args_j, class = "weft_error")
  expect_refused5(jl_value(""), m_args_j, class = "weft_error")
  expect_refused5(jl_value(c("a", "b")), m_args_j, class = "weft_error")
  expect_refused5(jl_value(NA_character_), m_args_j, class = "weft_error")
  expect_refused5(jl_value(NULL), m_args_j, class = "weft_error")
  expect_refused5(jl_value("t_j5_cfg", 2), m_args_j, class = "weft_error")
  expect_refused5(jl_value("t_j5_cfg", ""), m_args_j, class = "weft_error")
})

test_that("J8: jl_value() works outside a knit and without library(JuliaCall)", {
  skip_if_no_julia()
  jl_set(t_j5_out = "12")
  expect_identical(jl_value("t_j5_out"), 12L)
  expect_identical(weft::jl_value("t_j5_out"), 12L)
  expect_false("package:JuliaCall" %in% search())
})

test_that("J2: jl_value is exported and there is no jl object", {
  expect_true("jl_value" %in% getNamespaceExports("weft"))
  expect_false("jl" %in% getNamespaceExports("weft"))
  expect_false(exists("jl", envir = globalenv(), inherits = FALSE))
})

# ---- J8, J7: JM13 to JM15 ----------------------------------------------------------------

test_that("JM13: a name that is not in Main is a weft_guest_error with the stated text", {
  skip_if_no_julia()
  e <- expect_error(jl_value("t_j5_nosuch_zz"), class = "weft_guest_error")
  expect_s3_class(e, "weft_error")
  expect_false(inherits(e, "weft_guest_value_error"))
  expect_identical(msg5(e), jm13("jl_value(\"t_j5_nosuch_zz\")", "t_j5_nosuch_zz"))
  expect_refused5(jlv("t_j5_nosuch_zz", "x"),
                  jm13("jl_value(\"t_j5_nosuch_zz\", \"x\")", "t_j5_nosuch_zz"),
                  class = "weft_guest_error")
})

test_that("JM14: a step that is neither a key nor a field is a weft_guest_error", {
  skip_if_no_julia()
  jl_fixtures()
  jl_set(t_j5_c14 = "Dict(\"depth\" => 1)", t_j5_o14 = "T_j5_S(1.0, Dict(\"depth\" => 1))",
         t_j5_n14 = "(a = 1,)")
  expect_refused5(jlv("t_j5_c14", "zzz"),
                  jm14("jl_value(\"t_j5_c14\", \"zzz\")", "jl_value(\"t_j5_c14\")", "zzz"),
                  class = "weft_guest_error")
  expect_refused5(jlv("t_j5_o14", "cfg", "zzz"),
                  jm14("jl_value(\"t_j5_o14\", \"cfg\", \"zzz\")", "jl_value(\"t_j5_o14\", \"cfg\")", "zzz"),
                  class = "weft_guest_error")
  expect_refused5(jlv("t_j5_n14", "b"),
                  jm14("jl_value(\"t_j5_n14\", \"b\")", "jl_value(\"t_j5_n14\")", "b"),
                  class = "weft_guest_error")
})

test_that("JM15: without JuliaCall (the seam) a read is a weft_guest_error", {
  withr::local_options(weft.juliacall = FALSE)
  expect_refused5(jlv("t_j5_x"), jm15("jl_value(\"t_j5_x\")"), class = "weft_guest_error")
  e <- expect_error(jl_value("t_j5_x"), class = "weft_guest_error")
  expect_s3_class(e, "weft_error")
})

test_that("J8: a path step reads a Dict key when the Dict also has a field-like name", {
  skip_if_no_julia()
  # `values` and `keys` are functions of Dict, not fields; a key of that name is read as a key
  jl_set(t_j5_kw = "Dict(\"values\" => 5, \"keys\" => 6)")
  expect_identical(jl_value("t_j5_kw", "values"), 5L)
  expect_identical(jl_value("t_j5_kw", "keys"), 6L)
})

# ---- J14: a fresh process: missing, and Julia's Main -------------------------------------------------

# one child process: names(Main) before and after the first jl_value(), then
# the read of a scalar `missing` (last, since a crash would end the child)
fresh_types <- function() {
  if (is.null(.w5j$types)) {
    .w5j$types <- k5j_fresh(c(
      "JuliaCall::julia_setup(installJulia = FALSE, install = FALSE, verbose = FALSE)",
      "J <- JuliaCall::julia_command",
      "J('using Dates;')",
      "J('t_j5_own = 1;')",
      "J('t_j5_m = missing;')",
      "nm <- function() JuliaCall::julia_eval('string.(names(Main; all = true))')",
      "invisible(nm()); invisible(nm())",
      "before <- nm()",
      "J('t_j5_late = 3;')",
      "first <- weft::jl_value('t_j5_late')",
      "after <- nm()",
      "saveRDS(list(before = before, after = after, first = first), .out)",
      "cat('BEFORE_MISSING\\n')",
      "r <- weft::jl_value('t_j5_m')",
      "cat('MISSING_READ:', format(r), '\\n')",
      "cat('AFTER_MISSING:', JuliaCall::julia_eval('1 + 1'), '\\n')",
      "saveRDS(list(before = before, after = after, first = first, missing = r,",
      "             one_plus_one = JuliaCall::julia_eval('1 + 1')), .out)"))
  }
  .w5j$types
}

test_that("J14: reading a scalar `missing` returns NA and does not crash R (child process)", {
  skip_if_no_julia()
  res <- fresh_types()
  expect_identical(attr(res, "status"), 0L)
  out <- trimws(attr(res, "stdout"))
  expect_true("BEFORE_MISSING" %in% out)
  expect_true("MISSING_READ: NA" %in% out)
  expect_true("AFTER_MISSING: 2" %in% out)
  expect_identical(res$missing, NA)
  expect_identical(res$one_plus_one, 2L)
})

test_that("J14: the first jl_value() adds WeftGuest to Julia's Main and nothing else (child process)", {
  skip_if_no_julia()
  res <- fresh_types()
  skip_if(is.null(res$before), "the child saved nothing")
  expect_identical(res$first, 3L)
  hidden <- function(x) x[!startsWith(x, "#")]
  added <- setdiff(hidden(res$after), hidden(res$before))
  expect_setequal(added, c("WeftGuest", "t_j5_late"))
  expect_false("WeftGuest" %in% res$before)
  expect_length(setdiff(hidden(res$before), hidden(res$after)), 0L)
})
