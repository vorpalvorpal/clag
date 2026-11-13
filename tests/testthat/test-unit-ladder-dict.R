# Package 2h: display: takes ONE unit (4.2.1, 4.2.7), after the rulings on the review of 2h (dev/design-2h.md,
# "Rulings on the review of 2h", findings 2, 3, 7, ruling a; they reverse L2 in part, L13 and L14). A `display:`
# with more than one rung (a `|` string or a list of more than one item) is a read_dict() problem that says to
# write the ladder in a `unit` key at the use; a one-item list stays one unit. `~` in an expected string is
# U+00A0. Made-up content only.
if (!exists("h2_dict")) source(Filter(file.exists, c(testthat::test_path("helper-2h.R"), testthat::test_path("..", "helper-2h.R")))[[1]])
h2_need()
for (h in c("helper-2c.R", "helper-schema.R")) {
  if (!file.exists(testthat::test_path(h)) && file.exists(testthat::test_path("..", h))) source(testthat::test_path("..", h))
}

# a dictionary of two quantity entries, 2000 m and 900 m, both with the single `display` unit
dd <- function(display = "km", env = parent.frame()) {
  read_dict(f2_dict_file(c(
    sprintf("x: {value: 2000, type: quantity, unit: m, display: %s, definition: \"A long length.\"}", display),
    sprintf("y: {value: 900, type: quantity, unit: m, display: %s, definition: \"A short length.\"}", display),
    "plain: {value: 0.5, type: quantity, unit: m, definition: \"No display.\"}",
    "n: {value: 5, type: number, definition: \"A count.\"}"), env))
}

# the weft_dict_error a read raises, with the problems among the old ones
# A good entry (`okk`) sits among the lines: it must not be named, so a read that refuses everything
# does not pass for the right reason.
OKK <- "okk: {value: 2000, type: quantity, unit: m, display: \"km\", definition: x}"
dd_err <- function(lines, env = parent.frame()) {
  e <- f2_cond(read_dict(f2_dict_file(c(OKK, lines), env)))
  f2_has_class(e, "weft_dict_error")
  expect_false(grepl("unknown field", f2_msg(e), fixed = TRUE))
  expect_false(grepl("`okk`", f2_msg(e), fixed = TRUE), label = "the good entry is not a problem")
  e
}

# what a ladder in `display:` must say: the key, the field, that the ladder goes in a `unit` key, and the rule
# the neighbouring problems cite (4.2.7), cited once
expect_ladder_problem <- function(e, key = "w") {
  m <- f2_msg(e)
  line <- grep(sprintf("`%s`", key), strsplit(m, "\n", fixed = TRUE)[[1]], fixed = TRUE, value = TRUE)
  expect_length(line, 1L)
  expect_true(grepl("display", line, fixed = TRUE), label = paste("the field display is named:", line))
  expect_true(grepl("`unit` key", line, fixed = TRUE) || grepl("`unit=`", line, fixed = TRUE),
              label = paste("it says to use a unit key:", line))
  expect_equal(lengths(regmatches(line, gregexpr("(rule ", line, fixed = TRUE))), 1L, label = paste("one rule cited:", line))
  expect_true(grepl("(rule 4.2.7)", line, fixed = TRUE), label = line)
}

# ---- display: one unit; a one-item list is the unit (kept) ---------------------------------------------------------------

test_that("2h 4.2.7: a single display unit converts the entry when the dictionary is read, as a string and as a one-item list", {
  h2_restore()
  for (disp in c("km", "[km]")) {
    d <- dd(disp)
    expect_s3_class(d$x, "units")
    expect_equal(units::deparse_unit(d$x), "km", label = disp)
    expect_equal(as.numeric(d$x), 2, label = disp)
    expect_equal(units::deparse_unit(d$y), "km", label = disp)
    expect_equal(as.numeric(d$y), 0.9, label = disp)
  }
  d <- dd("m")
  expect_equal(units::deparse_unit(d$x), "m")
  expect_equal(as.numeric(d$x), 2000)
})

test_that("2h 4.2.7: an entry with no display, and a number, are unchanged beside entries with a display (control)", {
  h2_restore()
  d <- dd()
  expect_equal(as.numeric(d$plain), 0.5)
  expect_equal(units::deparse_unit(d$plain), "m")
  expect_equal(d$n, 5)
})

test_that("2h review #2: the unit an entry is held in does not depend on its value, so drop_units() is stable (ruling a)", {
  h2_restore()
  for (v in c(800, 8000)) {
    d <- read_dict(f2_dict_file(sprintf("a: {value: %s, type: quantity, unit: m, display: km, definition: x}", v)))
    expect_equal(units::deparse_unit(d$a), "km", label = v)
    expect_equal(as.numeric(units::drop_units(d$a)), v / 1000, label = v)
  }
})

# ---- the entry is held in its display unit: arithmetic, checks, #, drop_units, the pipeline ------------------------------

test_that("2h 4.2.7: arithmetic, # and drop_units() see the held unit", {
  h2_restore()
  d <- dd()
  expect_equal(as.numeric(d$x * 3), 6)
  expect_equal(units::deparse_unit(d$x * 3), "km")
  expect_equal(as.numeric(units::drop_units(d$x)), 2)
  expect_equal(as.numeric(units::drop_units(d$y)), 0.9)
  expect_true(d$x > units::set_units(1, "km"))
  expect_equal(h2_wsd("[# was | # were]{n=\"dict$x\"}", d), f2("2~km were"))
  expect_equal(h2_wsd("[# was | # were]{n=\"dict$y\"}", d), f2("0.9~km were"))
})

test_that("2h 4.2.7: .num of the entry prints in the held unit, and a computed value stays in it", {
  h2_restore()
  d <- dd()
  expect_equal(h2_wsd("`r dict$x`{.num}", d), f2("2~km"))
  expect_equal(h2_wsd("`r dict$y`{.num}", d), f2("0.9~km"))
  expect_equal(h2_wsd("`r dict$x * 3`{.num}", d), f2("6~km"))
  expect_equal(h2_wsd("`r dict$y * 1000`{.num}", d), f2("900~km"))
  expect_equal(f2_tx(fmt_num(d$x)), f2("2~km"))
  expect_equal(f2_tx(fmt_num(d$x * 3)), f2("6~km"))
})

test_that("2h 4.4.23: a ladder at the use is the way to a ladder on a computed value", {
  h2_restore()
  d <- dd()
  expect_equal(h2_wsd("`r dict$y * 1000`{.num unit=\"m|km\"}", d), f2("900~km"))
  expect_equal(h2_wsd("`r dict$y * 3`{.num unit=\"m|km\"}", d), f2("2.7~km"))
  expect_equal(h2_wsd("`r dict$y`{.num unit=\"m|km\"}", d), f2("900~m"))
})

# ---- precedence: unit at the use wins over display: (4.4.15) ---------------------------------------------------------------

test_that("2h 4.4.15: unit at the use, one unit or a ladder, wins over the display unit", {
  h2_restore()
  d <- dd()
  expect_equal(h2_wsd("`r dict$x`{.num unit=\"mm|m\"}", d), f2("2,000~m"))     # 2 km held: mm 2e6, m 2000: m is nearer
  expect_equal(h2_wsd("`r dict$x`{.num unit=\"m\"}", d), f2("2,000~m"))
  expect_equal(h2_wsd("`r dict$x`{.num unit=\"mm|m|km\"}", d), f2("2~km"))
  expect_equal(h2_wsd("`r dict$y`{.num unit=\"mm|m\"}", d), f2("900~m"))
  expect_equal(h2_wsd("`r dict$y`{.num unit=\"mm|m|km\"}", d), f2("900~m"))
  expect_equal(h2_wsd("`r dict$x`{.uname unit=\"mm|m\"}", d), f2("2,000~metres"))
  expect_equal(f2_tx(fmt_num(d$x, unit = "mm|m")), f2("2,000~m"))
})

# ---- the entries column and print() --------------------------------------------------------------------------------------

test_that("2h 4.2.7: the display column holds the unit, NA where absent", {
  h2_restore()
  for (disp in c("km", "[km]")) {
    e <- attr(dd(disp), "entries")
    expect_equal(e$display[e$key == "x"], "km", label = disp)
    expect_equal(e$display[e$key == "y"], "km", label = disp)
    expect_true(is.na(e$display[e$key == "plain"]), label = disp)
    expect_true(is.na(e$display[e$key == "n"]), label = disp)
    expect_equal(e$unit[e$key == "x"], "m", label = disp)        # unit is still the unit the value was written in
  }
})

test_that("2h 4.2.7: print() shows the unit the entry is held in", {
  h2_restore()
  out <- strsplit(paste(capture.output(print(dd())), collapse = "\n"), "\n", fixed = TRUE)[[1]]
  lx <- grep("^\\s*x ", out, value = TRUE)
  ly <- grep("^\\s*y ", out, value = TRUE)
  expect_length(lx, 1L)
  expect_length(ly, 1L)
  expect_match(lx, "2 km", fixed = TRUE)
  expect_match(ly, "0.9 km", fixed = TRUE)
  expect_false(grepl("2000", lx, fixed = TRUE))
})

test_that("2h 2c: the glossary prints the held unit", {
  h2_restore()
  g <- gsub("\u00a0", "~", as.character(dict_glossary(dd())), fixed = TRUE)
  expect_true(grepl("`x` (2~km)", g, fixed = TRUE), label = g)
  expect_true(grepl("`y` (0.9~km)", g, fixed = TRUE), label = g)
})

# ---- ruling a: a ladder in display: is a read_dict() problem that says to use a `unit` key ---------------------------------

test_that("2h ruling a: a | string in display is a problem naming the key, the field and the unit key (rule 4.2.7)", {
  h2_restore()
  for (disp in c("\"m|km\"", "\"mm|m|km\"", "\"m | km\"", "\"m|metre\"", "\"m|kg\"")) {
    e <- dd_err(sprintf("w: {value: 1, type: quantity, unit: m, display: %s, definition: x}", disp))
    expect_ladder_problem(e)
  }
})

test_that("2h ruling a: a list of more than one item in display is a problem naming the key, the field and the unit key (rule 4.2.7)", {
  h2_restore()
  for (disp in c("[m, km]", "[mm, m, km]", "[m, m]", "[km, m]")) {
    e <- dd_err(sprintf("w: {value: 1, type: quantity, unit: m, display: %s, definition: x}", disp))
    expect_ladder_problem(e)
  }
  e <- dd_err("w: {value: 1, type: quantity, unit: L, display: [L, \"dm^3\"], definition: x}")
  expect_ladder_problem(e)
})

test_that("2h ruling a: a one-item list holding | is a ladder too, and is a problem (YAML reads [m|km] as m|km)", {
  h2_restore()
  e <- dd_err("w: {value: 1, type: quantity, unit: m, display: [\"m|km\"], definition: x}")
  expect_ladder_problem(e)
})

test_that("2h ruling a: a ladder problem is raised at read, so no entry is held in a value-dependent unit (finding 2)", {
  h2_restore()
  for (v in c(800, 8000)) {
    e <- f2_cond(read_dict(f2_dict_file(sprintf("a: {value: %s, type: quantity, unit: m, display: \"m|km\", definition: x}", v))))
    f2_has_class(e, "weft_dict_error")
    f2_msg_has(e, "`a`", "display")
  }
})

test_that("2h ruling a: the ladder problems sit among the dictionary's others, one line each, in one error", {
  e <- dd_err(c("a: {value: 1, type: quantity, unit: m, display: kg, definition: x}",
                "b: {value: 1, type: quantity, unit: m, display: \"m|km\", definition: x}",
                "c: {value: 1, type: quantity, unit: m, display: [m, km], definition: x}",
                "d: {value: 1, type: quantity, unit: m, display: [mm, \"m|km\"], definition: x}",
                "e: {value: 5, type: number, display: km, definition: x}",
                "f: {value: 1, type: number}"))
  f2_msg_has(e, "`a`", "`b`", "`c`", "`d`", "`f`", "kg", "(rule 4.2.7)")
  m <- f2_msg(e)
  for (k in c("b", "c", "d")) expect_ladder_problem(e, k)
  expect_gte(lengths(regmatches(m, gregexpr("display", m, fixed = TRUE))), 4L)
})

# ---- the single-unit display problems stand (4.2.7) ------------------------------------------------------------------------------

test_that("2h 4.2.7: a display unit the value does not convert to, does not parse, or is a twin is a problem naming the key", {
  e <- dd_err("w: {value: 1, type: quantity, unit: m, display: kg, definition: x}")
  f2_msg_has(e, "`w`", "display", "kg")
  e <- dd_err("w: {value: 1, type: quantity, unit: m, display: \"not a unit!!\", definition: x}")
  f2_msg_has(e, "`w`", "display", "not a unit!!")
  e <- dd_err("w: {value: 2, type: quantity, unit: Sv, display: Gy, definition: x}")
  f2_msg_has(e, "`w`", "Gy")
})

test_that("2h 4.2.7: a blank or null list item is a problem", {
  e <- dd_err("w: {value: 1, type: quantity, unit: m, display: [m, \"\"], definition: x}")
  f2_msg_has(e, "`w`", "display")
  e <- dd_err("w: {value: 1, type: quantity, unit: m, display: [m, ~], definition: x}")
  f2_msg_has(e, "`w`", "display")
})

test_that("2h 4.2.7: an empty or repeated rung in display is a problem naming the key and the field", {
  for (disp in c("\"m||km\"", "\"m|\"", "\"|m\"", "\"m|km|m\"", "\"m| m\"")) {
    e <- dd_err(sprintf("w: {value: 1, type: quantity, unit: m, display: %s, definition: x}", disp))
    f2_msg_has(e, "`w`", "display")
  }
})

test_that("2h 4.2.7: a value that is neither a string nor a list of strings is a problem", {
  for (disp in c("5", "{a: b}", "[5, km]", "true")) {
    e <- dd_err(sprintf("w: {value: 1, type: quantity, unit: m, display: %s, definition: x}", disp))
    f2_msg_has(e, "`w`", "display")
  }
})

test_that("2h 4.2.7: a read with a display problem registers nothing from it", {
  e <- dd_err("w: {value: 2, type: quantity, unit: zzh2db/s, display: kg, definition: x}")
  f2_msg_has(e, "kg")
  expect_error(u(1, zzh2db), class = "weft_unit_error")
})

test_that("2h 4.2.6 control: a good entry beside a bad one reads nothing, and the good one alone reads", {
  expect_s3_class(read_dict(f2_dict_file(OKK)), "weft_dict")
  dd_err("w: {value: 1, type: quantity, unit: m, display: kg, definition: x}")
})

# ---- the schema (inst/dict/dict.schema.json) accepts what read_dict() reads -------------------------------------------------

test_that("2h 4.2.1: the schema accepts a display unit as a string and as a one-item list, and refuses an empty list", {
  skip_if_not_installed("jsonlite")
  base <- "a: {value: 2000, type: quantity, unit: m, display: %s, definition: x}"
  for (disp in c("\"km\"", "[km]")) {
    expect_identical(schema_errors(sprintf(base, disp)), character(), label = disp)
  }
  expect_gt(length(schema_errors(sprintf(base, "[]"))), 0L)
  expect_gt(length(schema_errors(sprintf(base, "[5]"))), 0L)
})

# ---- in a knit: dict.yml, dict_local, {unit=} over a display unit -----------------------------------------------------------

LD_DICT <- c(
  "x: {value: 2000, type: quantity, unit: m, display: km, definition: \"A long length.\"}",
  "y: {value: 900, type: quantity, unit: m, display: km, definition: \"A short length.\"}",
  "z: {value: 1500, type: quantity, unit: m, display: [km], definition: \"A listed length.\"}"
)
LD_CASES <- c(
  "`r dict$x`{.num}",                       # 1 km
  "`r dict$y`{.num}",                       # 2 km
  "`r dict_local$lx`{.num}",                # 3 a local entry with a display: km
  "`r dict$x`{.num unit=\"mm|m\"}",         # 4 unit at the use wins
  "`r dict$x * 3`{.num}",                   # 5 arithmetic keeps the held unit
  "`r dict$x`{.uname}",                     # 6 name of the held unit
  "`r dict$z`{.num}",                       # 7 a one-item list
  "`r dict_local$ly`{.num}",                # 8 a local entry, one-item list
  "`r dict$y`{.num unit=\"m|km\"}"          # 9 a ladder at the use
)
LD_WANT <- c("2~km", "0.9~km", "3~km", "2,000~m", "6~km", "2~kilometres", "1.5~km", "0.8~km", "900~m")

ld_front <- function(display_lines) {
  c("weft:", "  dict_local:", "    lx:",
    "      value: 3000", "      type: quantity", "      unit: m", display_lines,
    "      definition: \"A local length.\"", "      why: \"Chapter-specific.\"")
}

ld_render <- local({
  cache <- NULL
  function() {
    if (is.null(cache)) {
      cache <<- render_rmd(
        batch_cases(LD_CASES),
        front = c(ld_front("      display: km"),
                  "    ly:",
                  "      value: 800", "      type: quantity", "      unit: m", "      display: [km]",
                  "      definition: \"Another local length.\"", "      why: \"Chapter-specific.\""),
        files = list("dict.yml" = LD_DICT), in_process = TRUE, env = c(WEFT_DRAFT = "1"))
    }
    cache
  }
})

test_that("2h 4.2.7: in a knit, dict.yml and dict_local apply a single display unit when read", {
  res <- ld_render()
  expect_false(res$failed, label = res$message)
  if (res$failed) return(invisible())
  got <- f2_unesc(split_cases(res, length(LD_CASES)))
  for (i in seq_along(LD_WANT)) expect_equal(got[i], f2(LD_WANT[i]), label = LD_CASES[i])
})

test_that("2h ruling a: a ladder in dict.yml display stops a knit with a dictionary error that says to use a unit key", {
  for (disp in c("\"m|km\"", "[m, km]")) {
    res <- render_rmd("`r 1`{.num}", files = list("dict.yml" = c(OKK, sprintf("w: {value: 2, type: quantity, unit: m, display: %s, definition: x}", disp))),
                      in_process = TRUE, env = c(WEFT_DRAFT = NA))
    expect_true(res$failed, label = disp)
    expect_true("weft_dict_error" %in% res$error$class, label = disp)
    expect_match(res$message, "`w`", fixed = TRUE)
    expect_match(res$message, "display", fixed = TRUE)
    expect_match(res$message, "`unit` key", fixed = TRUE)
    expect_false(grepl("`okk`", res$message, fixed = TRUE))
  }
})

test_that("2h ruling a: a ladder in a dict_local display stops a knit with a dictionary error that says to use a unit key", {
  for (disp in c("      display: \"m|km\"", "      display: [m, km]")) {
    res <- render_rmd("`r 1`{.num}", front = ld_front(disp), in_process = TRUE, env = c(WEFT_DRAFT = NA))
    expect_true(res$failed, label = disp)
    expect_true("weft_dict_error" %in% res$error$class, label = disp)
    expect_match(res$message, "`lx`", fixed = TRUE)
    expect_match(res$message, "display", fixed = TRUE)
    expect_match(res$message, "`unit` key", fixed = TRUE)
  }
})

test_that("2h 4.2.6: a display problem in the project dictionary stops a knit with a dictionary error", {
  res <- render_rmd("`r 1`{.num}", files = list("dict.yml" = c(OKK, "w: {value: 2, type: quantity, unit: m, display: kg, definition: x}")),
                    in_process = TRUE, env = c(WEFT_DRAFT = NA))
  expect_true(res$failed)
  expect_true("weft_dict_error" %in% res$error$class)
  expect_match(res$message, "display", fixed = TRUE)
  expect_match(res$message, "kg", fixed = TRUE)
  expect_false(grepl("`okk`", res$message, fixed = TRUE))
})
