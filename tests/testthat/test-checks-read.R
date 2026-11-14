# Package 7j: the reader of checks (dev/design-7.md N120 to N126, N149 to N151), through read_src() of helper-3.R.
# Nothing is knitted. The reader is weft:::checks_read(src) (helper-7j.R names it and its columns).

# one row's fields as a list, for readable messages
rw <- function(r, i = 1L) as.list(r[i, c("role", "level", "value", "op", "other", "cond"), drop = FALSE])

expect_row <- function(r, value, op, other, cond = paste(value, op, other), level = "fail", role = "claim",
                       i = 1L, label = NULL) {
  label <- label %||% cond
  expect_gte(nrow(r), i)
  expect_identical(r$role[[i]], role, label = paste(label, "role"))
  expect_identical(r$level[[i]], level, label = paste(label, "level"))
  expect_identical(r$value[[i]], value, label = paste(label, "value"))
  expect_identical(r$op[[i]], op, label = paste(label, "op"))
  expect_identical(r$other[[i]], other, label = paste(label, "other"))
  expect_identical(r$cond[[i]], cond, label = paste(label, "cond"))
}

# ---- N120: what is a check ----------------------------------------------------------------------------------------

test_that("7j N120: a guard's comma parts are checks in a hooks document and in a filter document, the same", {
  for (ext in c("Rmd", "qmd")) {
    r <- j7_read("A [phrase]{if=\"x > 5, y != 'a'\"} here.", ext = ext)
    expect_identical(nrow(r), 2L, label = ext)
    expect_row(r, "x", ">", "5", role = "guard", i = 1L, label = paste(ext, "part 1"))
    expect_row(r, "y", "!=", "'a'", role = "guard", i = 2L, label = paste(ext, "part 2"))
    expect_identical(r$always, c(TRUE, TRUE))
    expect_identical(r$rebound, c(FALSE, FALSE))
    # an ordering of a string is not readable, in both
    r <- j7_read("A [phrase]{if=\"y <= 'a'\"} here.", ext = ext)
    expect_identical(nrow(r), 1L, label = ext)
    expect_identical(r$role, "guard")
    expect_identical(r$level, "fail")
    expect_true(is.na(r$cond), label = ext)
  }
})

test_that("7j N120: a branch is a check of role branch, with no level", {
  r <- j7_read("A [high | low]{if=\"x > 5\"} here.")
  expect_identical(nrow(r), 1L)
  expect_row(r, "x", ">", "5", role = "branch", level = NA_character_)
  expect_true(is.na(r$level))
  # a guard with the same condition is a guard, with a level
  r <- j7_read("A [high]{if=\"x > 5\"} here.")
  expect_identical(r$role, "guard")
  expect_identical(r$level, "fail")
})

test_that("7j N120, N123: the claim forms and the `.` the claim reads", {
  cases <- list(
    list("claim(foo, . > bar)", "foo", ">", "bar"),
    list("foo |> claim(. > 0)", "foo", ">", "0"),
    list("foo %>% claim(. > 0)", "foo", ">", "0"),
    list("n_up <- claim(sum(z), . >= 10)", "n_up", ">=", "10"),
    list("n_up = claim(sum(z), . >= 10)", "n_up", ">=", "10"),
    list("claim(sum(z), . >= 10) -> n_up", "n_up", ">=", "10"),
    list("sum(z) |> claim(. >= 10) -> n_up", "n_up", ">=", "10"),
    list("claim(sum(z), . >= 10)", "sum(z)", ">=", "10"),
    list("claim(x, y > 3)", "y", ">", "3"),
    list("n <- claim(max(turbidity), . < 5)", "n", "<", "5"))
  expect_length(cases, 10L)
  for (cs in cases) {
    r <- j7_code(cs[[1]])
    expect_identical(nrow(r), 1L, label = cs[[1]])
    expect_row(r, cs[[2]], cs[[3]], cs[[4]], label = cs[[1]])
    expect_identical(r$role, "claim")
    expect_identical(r$always, TRUE)
  }
})

test_that("7j N120: the level of a claim, and decision is not a check", {
  r <- j7_code('claim(x, . > 0, level = "warn", decision = 31)')
  expect_identical(nrow(r), 1L)
  expect_row(r, "x", ">", "0", level = "warn")
  r <- j7_code("claim(x, . > 0, level = lv)")
  expect_identical(nrow(r), 1L)
  expect_row(r, "x", ">", "0", level = "unknown")
  r <- j7_code('claim(x, . > 0, level = "fail")')
  expect_row(r, "x", ">", "0", level = "fail")
  # two check arguments are two checks, in argument order
  r <- j7_code("claim(x, . > 0, . < 10)")
  expect_identical(nrow(r), 2L)
  expect_row(r, "x", ">", "0", i = 1L)
  expect_row(r, "x", "<", "10", i = 2L)
  # decision alone: no check
  expect_identical(nrow(j7_code('claim(x, decision = "d1")')), 0L)
  # an inline value holding a claim
  r <- j7_read("The count is `r claim(n_sites, . > 5)`{.num} here.")
  expect_identical(nrow(r), 1L)
  expect_row(r, "n_sites", ">", "5")
})

test_that("7j N120, N123: a claim in a function definition, or with `.` on a literal, is not readable", {
  r <- j7_code("f <- function(v) claim(v, . > 0)")
  expect_identical(nrow(r), 1L)
  expect_true(is.na(r$cond))
  r <- j7_code("g <- \\(v) claim(v, . > 0)")
  expect_identical(nrow(r), 1L)
  expect_true(is.na(r$cond))
  for (code in c("claim(5, . > 3)", "claim(runif(1), . < 1)")) {
    r <- j7_code(code)
    expect_identical(nrow(r), 1L, label = code)
    expect_true(is.na(r$cond), label = code)
  }
})

test_that("7j N120: not checks: governors, an eval: false chunk, indented code", {
  expect_identical(nrow(j7_read("A [site | sites]{n=\"k\"} and [it | they]{sign=\"d\"} here.")), 0L)
  expect_identical(nrow(j7_read(j7_chunk("#| eval: false", "claim(x, . > 0)"))), 0L)
  expect_identical(nrow(j7_read(c("Text.", "", "    claim(x, . > 0)", "", "More text."))), 0L)
  # control: the same claim in an executed chunk is a check
  expect_identical(nrow(j7_read(j7_chunk("claim(x, . > 0)"))), 1L)
})

test_that("7j N120, N121: Python and Julia claims are checks that are never readable", {
  r <- j7_read(c("```{python}", "claim(x > 1)", "```"))
  expect_identical(nrow(r), 1L)
  expect_identical(r$role, "claim")
  expect_true(is.na(r$cond))
  expect_match(r$text, "claim(x > 1)", fixed = TRUE)
  r <- j7_read(c("```{julia}", "@claim x > 1", "```"))
  expect_identical(nrow(r), 1L)
  expect_true(is.na(r$cond))
})

# ---- N121, N122, N124: what is readable, operands and the normal form ----------------------------------------------

test_that("7j N124: operands and literals, each in its canonical form", {
  cases <- list(
    c("5 < x", "x > 5"), c("x >= 5.0", "x >= 5"), c("x > 1e3", "x > 1000"), c("x > .50", "x > 0.5"),
    c("x > -2L", "x > -2"), c("x > 5L", "x > 5"), c("x > -0", "x > 0"), c("x > 1e-25", "x > 1e-25"),
    c("x > 1e25", "x > 1e25"), c("x > 1.5e22", "x > 1.5e22"), c("x > 1e5", "x > 100000"),
    c("x == \"a\"", "x == 'a'"), c("x == 'a'", "x == 'a'"), c("x == \"it's\"", "x == \"it's\""),
    c("d >= \"2024-02-01\"", "d >= '2024-02-01'"), c("s == \"2024-13-45\"", "s == '2024-13-45'"),
    c("TRUE == x", "x == TRUE"), c("x != FALSE", "x != FALSE"), c("x < u(50, NTU)", "x < u(50, NTU)"),
    c("x < u(50.0, NTU)", "x < u(50, NTU)"), c("u(50, NTU) > x", "x < u(50, NTU)"),
    c("dict$k > 3", "dict$k > 3"), c("dict[[\"k\"]] > 3", "dict$k > 3"), c("dict$\"k\" > 3", "dict$k > 3"),
    c("dict_local$k > 3", "dict_local$k > 3"), c("(x > 5)", "x > 5"))
  code <- sprintf("claim(v, %s)", vapply(cases, `[[`, "", 1L))
  r <- j7_code(code)
  expect_identical(nrow(r), length(cases))
  expect_identical(r$cond, vapply(cases, `[[`, "", 2L))
  expect_false(anyNA(r$cond))
  expect_identical(r$role, rep("claim", length(cases)))
  # the fields are the cond split at its operator
  expect_identical(paste(r$value, r$op, r$other), r$cond)
})

test_that("7j N124: bool checks keep their own form, in a guard and as a claim", {
  r <- j7_read("A [p]{if=\"x, !y\"} and [q]{if=\"z\"} here.")
  expect_identical(nrow(r), 3L)
  expect_row(r, "x", "is", "TRUE", cond = "x", role = "guard", i = 1L)
  expect_row(r, "y", "is", "FALSE", cond = "!y", role = "guard", i = 2L)
  expect_row(r, "z", "is", "TRUE", cond = "z", role = "guard", i = 3L)
  r <- j7_read("A [p]{if=\"x, !y\"} here.", ext = "qmd")
  expect_identical(r$cond, c("x", "!y"))
  r <- j7_code(c("claim(x, .)", "claim(y, !.)", "claim(v, w)", "claim(v, !w)"))
  expect_identical(r$cond, c("x", "!y", "w", "!w"))
  expect_identical(r$op, rep("is", 4L))
  expect_identical(r$other, c("TRUE", "FALSE", "TRUE", "FALSE"))
  # `x == TRUE` is not the bool check `x`: a check passes only on a single TRUE (3.1.3)
  r <- j7_code(c("claim(v, x == TRUE)", "claim(v, x)"))
  expect_identical(r$op, c("==", "is"))
  expect_identical(r$cond, c("x == TRUE", "x"))
})

test_that("7j N124: the key orders two value operands by their text; the display keeps the first orientation", {
  r <- j7_code(c("claim(v, b < a)", "claim(v, a > b)", "claim(v, a < b)"))
  expect_identical(nrow(r), 3L)
  # every check on the pair is shown in the orientation of the first: `b < a`, so `a < b` is shown `b > a`
  expect_identical(r$cond, c("b < a", "b < a", "b > a"))
  expect_identical(r$key, c("a > b", "a > b", "a < b"))
  # an operand that is not a name sorts by its text too
  r <- j7_code("claim(v, x < 2 * lim)")
  expect_identical(r$key, "2 * lim > x")
})

test_that("7j N124: against a literal the value operand is on the left, the operator mirrored", {
  r <- j7_code(c("claim(v, 50 > max(t))", "claim(v, 5 <= x)", "claim(v, 5 == x)", "claim(v, 5 != x)"))
  expect_identical(r$cond, c("max(t) < 50", "x >= 5", "x == 5", "x != 5"))
  expect_identical(r$key, r$cond)
})

test_that("7j N121: not readable, one case for each form", {
  not_read <- c("all(x)", "x > 5 && y", "x > 5 || y", "x %in% s", "x > Inf", "x > NaN", "x > NA", "x > 0x10", "x > NULL",
                "x > 1/3", "'a' < x", "x < 'a'", "x > TRUE", "x > x", "max(x) > max( x )", "5 > 3", "'a' == 'b'",
                "is.na(x)", "!any(x)", "x + 1", "x[1]", "x > 1i", "x > 2 * 3")
  r <- j7_code(sprintf("claim(v, %s)", not_read))
  expect_identical(nrow(r), length(not_read))
  for (i in seq_along(not_read)) expect_true(is.na(r$cond[[i]]), label = not_read[[i]])
  # the text is kept for them (white space collapsed)
  expect_identical(r$text[[3]], "claim(v, x > 5 || y)")
  # control: the comparisons beside them are read
  r <- j7_code(c("claim(v, x > 5)", "claim(v, x == 'a')"))
  expect_false(anyNA(r$cond))
})

test_that("7j N121: `claim(all(x), .)` is not a bool check, and `!` on a call is not one either", {
  r <- j7_code(c("claim(all(x), .)", "claim(max(x), !.)"))
  expect_identical(nrow(r), 2L)
  expect_true(all(is.na(r$cond)))
})

test_that("7j N121: in a filter document a guard part is read as before, and a call is a construct error", {
  r <- j7_read("A [p]{if=\"max(t) < 50\"} here.", ext = "qmd")
  expect_identical(nrow(r), 1L)
  expect_true(is.na(r$cond))
  expect_identical(r$role, "guard")
  # the same guard in a hooks document reads as a claim does
  r <- j7_read("A [p]{if=\"max(t) < 50\"} here.", ext = "Rmd")
  expect_identical(nrow(r), 1L)
  expect_row(r, "max(t)", "<", "50", role = "guard")
})

test_that("7j N122: a dictionary read of a key the document also defines locally is not readable", {
  doc <- c(f3_fm("weft:", "  dict_local:", "    k:", "      value: 1", "      why: local"), j7_chunk("claim(v, dict$k > 3)", "claim(v, dict$j > 3)",
                                                                "claim(v, max(dict$k) > 5)"))
  r <- j7_read(doc)
  expect_identical(nrow(r), 3L)
  expect_true(is.na(r$cond[[1]]))
  expect_identical(r$cond[[2]], "dict$j > 3")
  expect_true(is.na(r$cond[[3]]))
})

# ---- N123 rule 4, N149 to N151: expression operands --------------------------------------------------------------

test_that("7j N149: one expression, four spellings, one normal form", {
  code <- c("claim(max(turbidity), . < u(50, NTU))",
            "turbidity |> max() |> claim(. < u(50, NTU))",
            "claim(max( turbidity ), . < u(50, NTU))",
            "claim((max(turbidity)), . < u(50, NTU))",
            "claim(max(  # the peak", "  turbidity), . < u(50, NTU))")
  r <- j7_code(code)
  expect_identical(nrow(r), 5L)
  expect_identical(r$value, rep("max(turbidity)", 5L))
  expect_identical(r$op, rep("<", 5L))
  expect_identical(r$other, rep("u(50, NTU)", 5L))
  expect_identical(r$cond, rep("max(turbidity) < u(50, NTU)", 5L))
})

test_that("7j N149: strings and numbers inside an expression are written as deparse() writes them", {
  r <- j7_code(c("claim(f(x, 'a'), . > 0)", "claim(f(x, 5.0), . > 0)", "claim(f(x, 1e3), . > 0)", "claim(f(x, 5L), . > 0)"))
  expect_identical(r$value, c("f(x, \"a\")", "f(x, 5)", "f(x, 1000)", "f(x, 5L)"))
  # the literal on the other side is written as N124 writes a literal
  r <- j7_code("claim(f(x, 5.0), . > 5.0)")
  expect_identical(r$cond, "f(x, 5) > 5")
})

test_that("7j N149: what is not normalised stays a value of its own", {
  code <- c("claim(max((t)), . < 5)", "claim(base::max(t), . < 5)", "claim(round(t, 1), . < 5)",
            "claim(round(t, digits = 1), . < 5)", "claim(t %>% max(), . < 5)", "claim(max(t, na.rm = TRUE), . < 5)",
            "claim(max(t), . < 5)")
  r <- j7_code(code)
  expect_identical(nrow(r), length(code))
  expect_identical(r$value, c("max((t))", "base::max(t)", "round(t, 1)", "round(t, digits = 1)", "t %>% max()",
                              "max(t, na.rm = TRUE)", "max(t)"))
  expect_identical(anyDuplicated(r$value), 0L)
})

test_that("7j N151: an expression on either side, in a claim and in a hooks guard; arithmetic and indexing", {
  r <- j7_code(c("claim(v, x[1] > 5)", "claim(v, x + 1 > 5)", "claim(v, -x < 0)", "claim(v, x < 2 * lim)",
                 "claim(v, 50 > max(t))", "claim(v, max(a) > min(b))", "claim(v, nrow(subset(d, flow > 2)) > 5)"))
  expect_identical(nrow(r), 7L)
  expect_identical(r$value[1:3], c("x[1]", "x + 1", "-x"))
  expect_identical(r$cond[1:3], c("x[1] > 5", "x + 1 > 5", "-x < 0"))
  # `x < 2 * lim` is shown as written and keyed `2 * lim > x` ("2" sorts before "x")
  expect_identical(r$cond[[4]], "x < 2 * lim")
  expect_identical(r$key[[4]], "2 * lim > x")
  expect_identical(r$cond[[5]], "max(t) < 50")
  # two expressions, each in its normal form; the key puts the lower text first
  expect_identical(r$value[[6]], "max(a)")
  expect_identical(r$other[[6]], "min(b)")
  expect_identical(r$cond[[6]], "max(a) > min(b)")
  expect_identical(r$value[[7]], "nrow(subset(d, flow > 2))")
  # a guard of a hooks document
  r <- j7_read("A [p]{if=\"x < 2 * lim, max(t) < 50\"} here.")
  expect_identical(r$cond, c("x < 2 * lim", "max(t) < 50"))
})

test_that("7j D51: an expression that occurs once is read, a group of one", {
  r <- j7_code("claim(max(turbidity), . < u(50, NTU))")
  expect_identical(nrow(r), 1L)
  expect_identical(r$cond, "max(turbidity) < u(50, NTU)")
})

test_that("7j N150: not usable, one case for each item", {
  code <- c("claim(v, 1/3 < x)",                      # 1: no name read
           "claim(rnorm(1), . < 0.5)",                # 1: reads no name (and draws numbers)
           "claim(runif(n), . < 0.5)",                # 6: random draws
           "claim(base::sample(s, 1), . > 0)",        # 6: with a package
           "claim(v, Sys.time() - t0 > 5)",           # 6: the clock
           "claim(readLines(f)[1], . == 'y')",        # 6: input
           "claim(v, get(nm) > 5)",                   # 6: a read the parse data cannot see
           "claim(x, mean(.) > 3)",                   # 2: `.` inside an operand
           "x %>% max(.) %>% claim(. < 5)",           # 2: the placeholder of %>%
           "claim((y <- f(x)), . > 0)",               # 3: an assignment
           "claim(sapply(s, \\(v) v + 1), . > 0)",    # 3: a definition
           "claim({ f(x) }, . > 0)",                  # 4: a block
           "claim(obj$size(), . > 0)",                # 5: a method
           "claim(fs[[1]](x), . > 0)",                # 5: a call through anything but a name
           "claim(if (a) b else c, . > 0)",           # 4
           "claim(v, x > 1 + 1)")                     # 1: nothing read in the right side
  r <- j7_code(code)
  expect_identical(nrow(r), length(code))
  for (i in seq_along(code)) expect_true(is.na(r$cond[[i]]), label = code[[i]])
  # 7: a dictionary read of a key the document defines locally, inside an expression
  r <- j7_read(c(f3_fm("weft:", "  dict_local:", "    k:", "      value: 1", "      why: local"), j7_chunk("claim(v, max(dict$k) > 5)")))
  expect_identical(nrow(r), 1L)
  expect_true(is.na(r$cond))
  # controls: a usable expression beside them is read, and `dict$k` without a local k reads
  r <- j7_code(c("claim(max(x), . > 0)", "claim(v, max(dict$k) > 5)"))
  expect_identical(r$cond, c("max(x) > 0", "max(dict$k) > 5"))
})

test_that("7j N150: every function of CHECK_UNSAFE_FNS makes an expression unusable, with or without a package", {
  unsafe <- c("sample", "sample.int", "set.seed", "rbeta", "rbinom", "rcauchy", "rchisq", "rexp", "rf", "rgamma",
              "rgeom", "rhyper", "rlnorm", "rlogis", "rmultinom", "rnbinom", "rnorm", "rpois", "rsignrank", "rt",
              "runif", "rweibull", "rwilcox", "Sys.time", "Sys.Date", "date", "proc.time", "Sys.getenv", "Sys.getpid",
              "tempfile", "getwd", "readline", "readLines", "scan", "menu", "file.choose", "get", "get0", "mget",
              "exists", "eval", "evalq", "assign", "rm", "source", "library", "require", "attach", "options",
              "Sys.setenv", "setwd", "parent.frame", "sys.call", "sys.function", "environment")
  expect_length(unsafe, 55L)
  expect_setequal(weft:::CHECK_UNSAFE_FNS, unsafe)
  expect_identical(anyDuplicated(weft:::CHECK_UNSAFE_FNS), 0L)
  code <- c(sprintf("claim(v, %s(x) > 0)", unsafe), sprintf("claim(v, base::%s(x) > 0)", unsafe[1:3]),
            "claim(v, max(x) > 0)")
  r <- j7_code(code)
  expect_identical(nrow(r), length(code))
  expect_true(all(is.na(r$cond[seq_along(unsafe)])))
  expect_true(all(is.na(r$cond[length(unsafe) + 1:3])))
  expect_identical(r$cond[[length(code)]], "max(x) > 0")
})

test_that("7j N123 rule 4: an expression is not a bool check, and `.` is bound only as a whole operand", {
  r <- j7_code(c("claim(max(x) > 0, .)", "claim(v, mean(.) > 3)"))
  expect_identical(nrow(r), 2L)
  expect_true(all(is.na(r$cond)))
})

# ---- N126: runs always -----------------------------------------------------------------------------------------------

test_that("7j N126: a guard in an arm of a two-arm span does not run always", {
  r <- j7_read("Big [quite [very]{if=\"y > 1\"} | small]{if=\"x > 5\"} here, [sure]{if=\"z > 2\"} too.")
  expect_identical(nrow(r), 3L)
  expect_identical(r$cond[order(r$cond)], c("x > 5", "y > 1", "z > 2"))
  expect_identical(r$always[r$cond == "y > 1"], FALSE)
  expect_identical(r$always[r$cond == "x > 5"], TRUE)
  expect_identical(r$always[r$cond == "z > 2"], TRUE)
})

test_that("7j N126: a claim under if, else, for, while or repeat does not run always", {
  code <- c("claim(x, . > 0)",                      # always
            "{ claim(x, . > 1) }",                  # a block is not a condition
            "if (ok) claim(x, . > 2)",
            "if (ok) NULL else claim(x, . > 3)",
            "for (i in s) claim(x, . > 4)",
            "while (go) claim(x, . > 5)",
            "repeat { claim(x, . > 6); break }")
  r <- j7_code(code)
  expect_identical(nrow(r), length(code))
  expect_identical(r$always, c(TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE))
})

# ---- N125: rebound ------------------------------------------------------------------------------------------------------

rebound_of <- function(code, claim = "claim(x, . > 0)") {
  r <- j7_read(j7_chunk(code, claim))
  r$rebound[r$cond == "x > 0"]
}

test_that("7j N125: a name assigned in more than one place is rebound, in R code", {
  expect_identical(rebound_of(c("x <- 1", "x <- 2")), TRUE)
  expect_identical(rebound_of(c("x <- 1", "x$a <- 2")), TRUE)
  expect_identical(rebound_of(c("x <- 1", "x[2] <- 2")), TRUE)
  expect_identical(rebound_of(c("x <- 1", "names(x) <- 'a'")), TRUE)
  expect_identical(rebound_of(c("x <- 1", "x = 2")), TRUE)
  expect_identical(rebound_of(c("x <- 1", "3 -> x")), TRUE)
  expect_identical(rebound_of(c("x <- 1", "assign('x', 2)")), TRUE)
  expect_identical(rebound_of("for (x in s) NULL"), TRUE)
  # not rebound: one assignment, a name never assigned, a `<<-` in a function, a published value
  expect_identical(rebound_of("x <- 1"), FALSE)
  expect_identical(rebound_of("y <- 1"), FALSE)
  expect_identical(rebound_of(c("x <- 1", "f <- function() x <<- 2")), FALSE)
  expect_identical(rebound_of(c("x <- 1", "weft_put('x', 2)")), FALSE)
  # a check on another name in the same document is not rebound
  r <- j7_read(j7_chunk("x <- 1", "x <- 2", "claim(x, . > 0)", "claim(y, . > 0)"))
  expect_identical(r$rebound, c(TRUE, FALSE))
})

test_that("7j N125: in Python, a line that begins with the name and `=` counts, and so does each `for`", {
  py <- function(...) c("```{python}", c(...), "```", "")
  r <- j7_read(c(py("x = 1"), py("x = 2"), j7_chunk("claim(x, . > 0)")))
  expect_identical(r$rebound[r$cond == "x > 0"], TRUE)
  r <- j7_read(c(py("x = 1"), py("x += 2"), j7_chunk("claim(x, . > 0)")))
  expect_identical(r$rebound[r$cond == "x > 0"], TRUE)
  r <- j7_read(c(py("for x in s:", "    pass"), j7_chunk("claim(x, . > 0)")))
  expect_identical(r$rebound[r$cond == "x > 0"], TRUE)
  # not rebound: comparisons are not assignments
  r <- j7_read(c(py("x = 1"), py("x == 1"), py("x == 1"), j7_chunk("claim(x, . > 0)")))
  expect_identical(r$rebound[r$cond == "x > 0"], FALSE)
})

test_that("7j N125: an expression is rebound when a name it reads, or a function it calls, is", {
  rb <- function(code, claim) {
    r <- j7_read(j7_chunk(code, claim))
    r$rebound[nrow(r)]
  }
  expect_identical(rb(c("turbidity <- 1", "turbidity <- 2"), "claim(max(turbidity), . < 5)"), TRUE)
  expect_identical(rb(c("turbidity <- c(1, 2)", "turbidity[3] <- NA"), "claim(max(turbidity), . < 5)"), TRUE)
  expect_identical(rb(c("f <- function(x) x", "f <- function(x) x + 1"), "claim(f(t), . < 5)"), TRUE)
  expect_identical(rb(c("max <- 1", "max <- 2"), "claim(base::max(t), . < 5)"), FALSE)
  expect_identical(rb(c("max <- 1", "max <- 2"), "claim(max(t), . < 5)"), TRUE)
  expect_identical(rb(character(), "claim(max(dict$k), . < 5)"), FALSE)
  expect_identical(rb("t <- 1", "claim(max(t), . < 5)"), FALSE)
})

test_that("7j N120: rows come in order of line and column", {
  r <- j7_read(c("First [a]{if=\"p > 1, q > 2\"} then [b]{if=\"r > 3\"}.", "", j7_chunk("claim(s, . > 4)")))
  expect_identical(r$cond, c("p > 1", "q > 2", "r > 3", "s > 4"))
  expect_identical(r$line, c(1L, 1L, 1L, 4L))
})
