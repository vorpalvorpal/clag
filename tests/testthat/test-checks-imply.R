# Package 7j: the relation "one check implies another" and coverage (dev/design-7.md N127 to N131, N130's dec_cmp()).
# No files: rows are built from the text of a readable check (helper-7j.R, j7_row()). The relation is
# weft:::check_implies(a, b, filter = FALSE), coverage weft:::check_covered(b, new).

OPS <- c("<", "<=", ">", ">=", "==", "!=")

imp <- function(a, b, filter = FALSE) weft:::check_implies(j7_row(a), j7_row(b), filter = filter)

# ---- N128: two names, all 36 cells ------------------------------------------------------------------------------

test_that("7j N128: two names, with the two checks oriented the same way, exactly the 10 cells of the table", {
  tab <- rbind(
    "<"  = c(TRUE,  TRUE,  FALSE, FALSE, FALSE, TRUE),
    "<=" = c(FALSE, TRUE,  FALSE, FALSE, FALSE, FALSE),
    ">"  = c(FALSE, FALSE, TRUE,  TRUE,  FALSE, TRUE),
    ">=" = c(FALSE, FALSE, FALSE, TRUE,  FALSE, FALSE),
    "==" = c(FALSE, FALSE, FALSE, FALSE, TRUE,  FALSE),
    "!=" = c(FALSE, FALSE, FALSE, FALSE, FALSE, TRUE))
  expect_identical(sum(tab), 10L)
  n <- 0L
  for (i in seq_along(OPS)) for (j in seq_along(OPS)) {
    n <- n + 1L
    expect_identical(imp(paste("x", OPS[[i]], "y"), paste("x", OPS[[j]], "y")), tab[[i, j]],
                     label = sprintf("x %s y => x %s y", OPS[[i]], OPS[[j]]))
  }
  expect_identical(n, 36L)
})

test_that("7j N127: the same two names in either orientation are one pair", {
  # `y > x` is `x < y`
  expect_true(imp("x < y", "y > x"))
  expect_true(imp("x < y", "y >= x"))
  expect_true(imp("y > x", "x != y"))
  expect_true(imp("y > x", "x <= y"))
  expect_false(imp("x < y", "y < x"))
  expect_false(imp("x < y", "y <= x"))
  expect_false(imp("x <= y", "y > x"))
  # a different pair never
  expect_false(imp("x < y", "x < z"))
  expect_false(imp("x < y", "w < y"))
  # identity: the same key implies itself
  expect_true(imp("x > y", "x > y"))
})

# ---- N129: a name against a literal, 36 cells for each of a < b, a = b, a > b ----------------------------------------------

# the cell of N129 for the sign of (a - b): "lt" is a < b, "le" a <= b, "gt", "ge", "eq", "ne"; "F" never
N129 <- rbind(
  "<"  = c("le", "le", "F",  "F",  "F",  "le"),
  "<=" = c("lt", "le", "F",  "F",  "F",  "lt"),
  ">"  = c("F",  "F",  "ge", "ge", "F",  "ge"),
  ">=" = c("F",  "F",  "gt", "ge", "F",  "gt"),
  "==" = c("lt", "le", "gt", "ge", "eq", "ne"),
  "!=" = c("F",  "F",  "F",  "F",  "F",  "eq"))
cell_holds <- function(cell, s) {
  switch(cell, F = FALSE, lt = s < 0, le = s <= 0, gt = s > 0, ge = s >= 0, eq = s == 0, ne = s != 0)
}

# `lits` gives the text of the a, b pairs for the sign -1, 0, 1 (a < b, a = b, a > b)
check_table <- function(lits, who, subj = "x", filter = FALSE) {
  n <- 0L
  n_true <- 0L
  for (s in c(-1L, 0L, 1L)) {
    a <- lits[[as.character(s)]][[1]]
    b <- lits[[as.character(s)]][[2]]
    for (i in seq_along(OPS)) for (j in seq_along(OPS)) {
      want <- cell_holds(N129[[i, j]], s)
      n <- n + 1L
      n_true <- n_true + want
      expect_identical(imp(paste(subj, OPS[[i]], a), paste(subj, OPS[[j]], b), filter = filter), want,
                       label = sprintf("%s: %s %s %s => %s %s %s", who, subj, OPS[[i]], a, subj, OPS[[j]], b))
    }
  }
  expect_identical(n, 108L)
  # N129: 30 of the 108 cells hold
  expect_identical(n_true, 30L)
}

test_that("7j N129: a name against numbers, all 36 cells for a < b, a = b and a > b (108 cases)", {
  check_table(list("-1" = c("3", "5"), "0" = c("5", "5"), "1" = c("5", "3")), "numbers")
})

test_that("7j N129: the same 108 cases on dates", {
  check_table(list("-1" = c("'2024-01-31'", "'2024-02-01'"), "0" = c("'2024-02-01'", "'2024-02-01'"),
                   "1" = c("'2024-02-01'", "'2024-01-31'")), "dates", subj = "d")
})

test_that("7j N129: the same 108 cases on quantities of one unit", {
  check_table(list("-1" = c("u(3, NTU)", "u(5, NTU)"), "0" = c("u(5, NTU)", "u(5, NTU)"),
                   "1" = c("u(5, NTU)", "u(3, NTU)")), "quantities")
})

test_that("7j N129: the same 108 cases in a filter guard, where the literals are exact decimals", {
  check_table(list("-1" = c("3", "5"), "0" = c("5", "5"), "1" = c("5", "3")), "filter", filter = TRUE)
})

test_that("7j N129: quantities in two units, never; a number against a date, never", {
  n <- 0L
  for (a in c("u(3, NTU)", "u(5, NTU)")) for (b in c("u(3, kNTU)", "u(5, kNTU)", "u(0.06, kNTU)")) {
    for (i in seq_along(OPS)) for (j in seq_along(OPS)) {
      n <- n + 1L
      expect_false(imp(paste("x", OPS[[i]], a), paste("x", OPS[[j]], b)), label = paste(OPS[[i]], a, OPS[[j]], b))
    }
  }
  expect_identical(n, 216L)
  # kinds that differ are not one pair: a number, a date, a string, a quantity
  expect_false(imp("x > 5", "x > '2024-01-01'"))
  expect_false(imp("x > 5", "x > u(3, NTU)"))
  expect_false(imp("x == 'a'", "x == '2024-01-01'"))
  expect_false(imp("d == '2024-01-31'", "d == 'abc'"))
  expect_false(imp("x == 5", "x == 'a'"))
})

test_that("7j N129: strings and bools, the four cells of == and !=", {
  # strings
  expect_true(imp("x == 'a'", "x == 'a'"))
  expect_true(imp("x == 'a'", "x != 'b'"))
  expect_false(imp("x == 'a'", "x != 'a'"))
  expect_false(imp("x == 'a'", "x == 'b'"))
  expect_true(imp("x != 'a'", "x != 'a'"))
  expect_false(imp("x != 'a'", "x != 'b'"))
  expect_false(imp("x != 'a'", "x == 'a'"))
  expect_false(imp("x != 'a'", "x == 'b'"))
  # bools
  expect_true(imp("x == TRUE", "x == TRUE"))
  expect_true(imp("x == TRUE", "x != FALSE"))
  expect_false(imp("x == TRUE", "x != TRUE"))
  expect_false(imp("x == TRUE", "x == FALSE"))
  expect_true(imp("x != TRUE", "x != TRUE"))
  expect_false(imp("x != TRUE", "x == FALSE"))
  expect_false(imp("x != TRUE", "x != FALSE"))
})

test_that("7j N129: the bool checks `x` and `!x` against each of the six bool forms", {
  forms <- c("x", "!x", "x == TRUE", "x == FALSE", "x != TRUE", "x != FALSE")
  expect_identical(vapply(forms, function(f) imp("x", f), NA, USE.NAMES = FALSE), c(TRUE, FALSE, TRUE, FALSE, FALSE, TRUE))
  expect_identical(vapply(forms, function(f) imp("!x", f), NA, USE.NAMES = FALSE), c(FALSE, TRUE, FALSE, TRUE, TRUE, FALSE))
  # nothing else implies a bool check: `x == TRUE` passes on the number 1, the bare `x` does not
  for (a in c("x == TRUE", "x != FALSE")) expect_false(imp(a, "x"), label = a)
  for (a in c("x == FALSE", "x != TRUE")) expect_false(imp(a, "!x"), label = a)
  # another value, never
  expect_false(imp("x", "y"))
})

test_that("7j N129: every example of the last paragraph", {
  # over the reals, not the integers
  expect_false(imp("x > 4", "x >= 5"))
  expect_true(imp("x > 5", "x > 3"))
  expect_true(imp("x >= 5", "x > 4"))
  expect_true(imp("x >= 5", "x > 4.999"))
  expect_false(imp("x >= 5", "x > 5"))
  expect_true(imp("x == 5", "x >= 5"))
  expect_true(imp("x == 5", "x != 3"))
  expect_true(imp("x < 0", "x != 0"))
  expect_true(imp("x != 0", "x != 0"))
  expect_false(imp("x != 0", "x != 1"))
  expect_false(imp("x != 0", "x < 1"))
  expect_true(imp("d >= '2024-02-01'", "d > '2024-01-31'"))
  expect_true(imp("x < u(50, NTU)", "x <= u(60, NTU)"))
  expect_false(imp("x < u(50, NTU)", "x < u(0.06, kNTU)"))
})

# ---- N130: exact decimals, the double guard --------------------------------------------------------------------------------

test_that("7j N130: a strict cell needs the doubles to differ too, when R checks the implied check", {
  # 0.1000000000000000001 and 0.1 are one double
  expect_identical(as.numeric("0.1000000000000000001"), as.numeric("0.1"))
  strict <- list(c("x >= 0.1000000000000000001", "x > 0.1"),      # a > b
                 c("x >= 0.1000000000000000001", "x != 0.1"),
                 c("x == 0.1000000000000000001", "x != 0.1"),     # a != b
                 c("x == 0.1", "x > 0.09999999999999999999"),
                 c("x == 0.1", "x < 0.1000000000000000001"),      # a < b
                 c("x <= 0.1", "x < 0.1000000000000000001"),
                 c("x <= 0.1", "x != 0.1000000000000000001"))
  for (cs in strict) {
    expect_false(imp(cs[[1]], cs[[2]], filter = FALSE), label = paste("R:", cs[[1]], "=>", cs[[2]]))
    expect_true(imp(cs[[1]], cs[[2]], filter = TRUE), label = paste("filter:", cs[[1]], "=>", cs[[2]]))
  }
  # a cell that needs only <=, >= or = holds under both readings: rounding keeps order
  expect_true(imp("x > 0.1000000000000000001", "x >= 0.1", filter = FALSE))
  expect_true(imp("x > 0.1000000000000000001", "x > 0.1", filter = FALSE))
  expect_true(imp("x == 0.1000000000000000001", "x >= 0.1", filter = FALSE))
  expect_true(imp("x == 0.1000000000000000001", "x >= 0.1", filter = TRUE))
  expect_false(imp("x == 0.1", "x == 0.1000000000000000001", filter = FALSE))   # a = b is exact
  expect_false(imp("x == 0.1", "x == 0.1000000000000000001", filter = TRUE))
  expect_false(imp("x >= 0.1", "x > 0.1000000000000000001", filter = TRUE))   # a < b: exact decimals say no too
  # numbers that differ as doubles are strict in both
  expect_true(imp("x >= 0.2", "x > 0.1", filter = FALSE))
  expect_true(imp("x >= 0.2", "x > 0.1", filter = TRUE))
})

test_that("7j N130: dec_cmp() on hand-checked pairs", {
  cases <- list(c("1", "2", -1), c("2", "1", 1), c("5", "5", 0), c("5.0", "5", 0), c("0.50", "0.5", 0), c("-0", "0", 0),
                c("0", "-0", 0), c("-5", "3", -1), c("3", "-5", 1), c("-3", "-5", 1), c("-5", "-3", -1),
                c("10", "9", 1), c("9", "10", -1), c("1e3", "1000", 0), c("1e3", "999.99", 1), c("1e-3", "0.001", 0),
                c("1e-25", "0", 1), c("0", "-1e-25", 1), c("1e-25", "1e-24", -1),
                c("1234567890123456789012345", "1234567890123456789012346", -1),
                c("0.1000000000000000001", "0.1", 1))
  for (cs in cases) {
    expect_identical(weft:::dec_cmp(cs[[1]], cs[[2]]), as.integer(cs[[3]]), label = paste(cs[[1]], "vs", cs[[2]]))
  }
})

DEC_PAIRS <- list(
  c("-5", "3"), c("3", "-5"), c("-3", "-5"), c("-5", "-3"), c("0", "0"), c("0", "-0"), c("-0", "0"), c("-0", "-0"),
  c("0", "1e-30"), c("0", "-1e-30"), c("1e3", "1000"), c("1e3", "999.99"), c("1e-3", "0.001"), c("1.5e2", "150"),
  c("2e2", "1e3"), c("5.0", "5"), c("5.10", "5.1"), c("0.50", "0.5"), c("0.50", "0.51"),
  c("1234567890123456789012345", "1234567890123456789012346"), c("0.1000000000000000001", "0.1"),
  c("1e25", "10000000000000000000000000"), c("1e25", "9999999999999999999999999"),
  c("-1e25", "-9999999999999999999999999"), c("123456789012345678901234567890", "123456789012345678901234567891"),
  c("0.0000000000000000000000001", "0"), c("1e-25", "1e-24"), c("100", "99"), c("9", "10"), c("10", "9"),
  c("0.9", "0.10"), c("0.001", "0.0009"), c("-0.001", "-0.0009"), c("12.5", "12.50"), c("7", "7.0000000000000000000001"),
  c("-7", "-7.0000000000000000000001"), c("1e2", "99.99999999999999999999"), c("3.14159", "3.1416"))

test_that("7j N130: dec_cmp() equals cond.lua's num_cmp() on a shared list of pairs", {
  skip_if_no_lua_pandoc()
  expect_gte(length(DEC_PAIRS), 30L)
  lib <- system.file("quarto", "weftlib", "cond.lua", package = "weft")
  expect_true(nzchar(lib))
  script <- withr::local_tempfile(fileext = ".lua")
  pairs <- withr::local_tempfile(fileext = ".txt")
  writeLines(c(
    "local cond = dofile(arg[1])",
    "for line in io.lines(arg[2]) do",
    "  local a, b = line:match('^(%S+) (%S+)$')",
    "  print(cond.num_cmp(a, b))",
    "end"), script)
  writeLines(vapply(DEC_PAIRS, paste, "", collapse = " "), pairs)
  out <- lua_run(script, c(lib, pairs))
  expect_identical(out$status, 0L, info = out$stderr)
  lua <- as.integer(strsplit(out$stdout, "\n", fixed = TRUE)[[1]])
  expect_length(lua, length(DEC_PAIRS))
  r <- vapply(DEC_PAIRS, function(p) weft:::dec_cmp(p[[1]], p[[2]]), 0L)
  expect_identical(r, lua)
  expect_true(all(c(-1L, 0L, 1L) %in% r))
})

# ---- the relation across expressions (N127, N151) -----------------------------------------------------------------------

test_that("7j N127, N151: an expression is an operand, and compared by its normal form only", {
  expect_true(imp("max(t) < lim", "max(t) <= lim"))
  expect_true(imp("max(t) < lim", "max(t) != lim"))
  expect_false(imp("max(t) < lim", "max(t) > lim"))
  expect_true(imp("max(t) < u(50, NTU)", "max(t) <= u(60, NTU)"))
  expect_false(imp("max(t) < u(50, NTU)", "max(t) < u(40, NTU)"))
  expect_true(imp("x < 2 * lim", "x <= 2 * lim"))
  expect_false(imp("x < 2 * lim", "x < lim"))
  expect_false(imp("x < 2 * lim", "x < 3 * lim"))
  expect_false(imp("x < 2 * lim", "x < lim * 2"))
  expect_true(imp("x < 2 * lim", "x < 2 * lim"))
  # two expressions that are not one normal form: unrelated both ways
  expect_false(imp("max(t) < 5", "max(t, na.rm = TRUE) < 5"))
  expect_false(imp("max(t, na.rm = TRUE) < 5", "max(t) < 5"))
  # a dictionary read is a value operand too
  expect_true(imp("dict$k > 5", "dict$k > 3"))
  expect_true(imp("x > dict$k", "x >= dict$k"))
  expect_false(imp("x > dict$k", "x > dict$j"))
})

test_that("7j N127: a check that is not on the same pair is implied only by identity", {
  expect_false(imp("x > 5", "y > 3"))
  expect_false(imp("x > y", "x > 5"))
  expect_true(imp("x > y", "x > y"))
})

# ---- N131: covered ---------------------------------------------------------------------------------------------------------

covers <- function(b, new, ...) {
  weft:::check_covered(j7_row(b, ...), new)
}

test_that("7j N131: identity, and one implying check, cover", {
  expect_true(covers("x >= 5", j7_rows("x >= 5")))
  expect_true(covers("x >= 5", j7_rows(c("y > 1", "x >= 5", "z < 2"))))
  expect_true(covers("x >= 3", j7_rows("x > 5")))
  expect_true(covers("x >= 3", j7_rows(c("y > 1", "x > 5"))))
  # the same key in the other orientation
  expect_true(covers("x < y", j7_rows("y > x")))
  # nothing on the pair, or a weaker check
  expect_false(covers("x >= 5", j7_rows("y >= 5")))
  expect_false(covers("x >= 5", j7_rows("x > 3")))
  expect_false(weft:::check_covered(j7_row("x >= 5"), j7_row("y > 1")[0, ]))
})

test_that("7j N131: a warned check covers only a warned one", {
  expect_false(covers("x >= 5", j7_rows("x > 5", level = "warn")))
  expect_true(covers("x >= 5", j7_rows("x > 5", level = "warn"), level = "warn"))
  expect_true(covers("x >= 5", j7_rows("x > 5", level = "fail"), level = "warn"))
  expect_true(covers("x >= 5", j7_rows("x >= 5", level = "warn"), level = "warn"))
  expect_false(covers("x >= 5", j7_rows("x >= 5", level = "warn")))
})

test_that("7j N131: a level that is unknown counts as warn when it covers and as fail when it is gone", {
  # it covers as a warned check: not a fail-level one
  expect_false(covers("x >= 5", j7_rows("x > 5", level = "unknown")))
  expect_true(covers("x >= 5", j7_rows("x > 5", level = "unknown"), level = "warn"))
  # it is gone as a fail-level check: a warned check does not cover it, a fail-level one does
  expect_false(covers("x >= 5", j7_rows("x > 5", level = "warn"), level = "unknown"))
  expect_true(covers("x >= 5", j7_rows("x > 5", level = "fail"), level = "unknown"))
  # unknown covering unknown: a warned check covering a fail-level one
  expect_false(covers("x >= 5", j7_rows("x > 5", level = "unknown"), level = "unknown"))
})

test_that("7j N131: a check that does not run always covers nothing", {
  expect_false(covers("x >= 5", j7_rows("x > 5", always = FALSE)))
  expect_false(covers("x >= 5", j7_rows("x >= 5", always = FALSE)))
  # one that does run always beside it covers
  new <- rbind(j7_row("x > 5", always = FALSE, line = 1L), j7_row("x > 6", always = TRUE, line = 3L))
  expect_true(weft:::check_covered(j7_row("x >= 5"), new))
})

test_that("7j N131: two checks are never combined, and implications are not chained", {
  expect_false(covers("x > 5", j7_rows(c("x >= 5", "x != 5"))))
  expect_true(covers("x > 5", j7_rows(c("x >= 5", "x != 5", "x > 5"))))   # control: one of them alone
  expect_false(covers("x > 5", j7_rows(c("x > y", "y > 5"))))
  expect_true(covers("x > 5", j7_rows(c("x > y", "y > 5", "x > 6"))))
})

test_that("7j N131: a rebound check is covered by nothing, not even its own key", {
  expect_false(covers("max(t) < 5", j7_rows("max(t) < 5", rebound = TRUE)))
  expect_true(covers("max(t) < 5", j7_rows("max(t) < 5", rebound = FALSE)))
  expect_false(covers("x > 3", j7_rows("x > 5", rebound = TRUE)))
})

test_that("7j N131: a check that is not readable is covered only by one with its key, the same text", {
  b <- j7_row("x > 5")
  b$cond <- NA_character_
  b$key <- "claim(x, all(. > 0))"
  b$text <- "claim(x, all(. > 0))"
  same <- b
  other <- b
  other$key <- "claim(x, all(. > 1))"
  other$text <- "claim(x, all(. > 1))"
  expect_true(weft:::check_covered(b, same))
  expect_false(weft:::check_covered(b, other))
  # a readable check on the same value does not cover it
  expect_false(weft:::check_covered(b, j7_rows("x > 5")))
})
