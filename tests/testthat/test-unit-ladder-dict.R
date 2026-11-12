# Package 2h: display: as a ladder (4.2.1, 4.2.7, L13, L14). Contract: dev/design-2h.md "Interactions"
# (display:), "Errors" (weft_dict_error), "Tests". `~` in an expected string is U+00A0. Made-up content only.
if (!exists("h2_dict")) source(Filter(file.exists, c(testthat::test_path("helper-2h.R"), testthat::test_path("..", "helper-2h.R")))[[1]])
h2_need()
for (h in c("helper-2c.R", "helper-schema.R")) {
  if (!file.exists(testthat::test_path(h)) && file.exists(testthat::test_path("..", h))) source(testthat::test_path("..", h))
}

# a dictionary of two quantity entries, 2000 m and 900 m, both with the ladder `display`
dd <- function(display = "m|km", env = parent.frame()) {
  read_dict(f2_dict_file(c(
    sprintf("x: {value: 2000, type: quantity, unit: m, display: %s, definition: \"A long length.\"}", display),
    sprintf("y: {value: 900, type: quantity, unit: m, display: %s, definition: \"A short length.\"}", display),
    "plain: {value: 0.5, type: quantity, unit: m, definition: \"No display.\"}",
    "n: {value: 5, type: number, definition: \"A count.\"}"), env))
}

# the weft_dict_error a read raises, with the problems among the old ones
# A good ladder entry (`okk`) sits among the lines: it must not be named, so a read that cannot
# read a ladder at all (and so refuses `okk` too) does not pass for the right reason.
OKK <- "okk: {value: 2000, type: quantity, unit: m, display: \"m|km\", definition: x}"
dd_err <- function(lines, env = parent.frame()) {
  e <- f2_cond(read_dict(f2_dict_file(c(OKK, lines), env)))
  f2_has_class(e, "weft_dict_error")
  expect_false(grepl("unknown field", f2_msg(e), fixed = TRUE))
  expect_false(grepl("`okk`", f2_msg(e), fixed = TRUE), label = "the good ladder entry is not a problem")
  e
}

# ---- display: as a string and as a list; picked once, when the dictionary is read (L13) ------------------------

test_that("2h L13: a ladder display picks the entry's rung from its value when the dictionary is read", {
  h2_restore()
  d <- dd()
  expect_s3_class(d$x, "units")
  expect_equal(as.numeric(d$x), 2)
  expect_equal(units::deparse_unit(d$x), "km")
  expect_equal(as.numeric(d$y), 900)
  expect_equal(units::deparse_unit(d$y), "m")
  expect_equal(as.numeric(units::set_units(d$x, "m", mode = "standard")), 2000)
})

test_that("2h L2: a YAML list as display is a ladder", {
  h2_restore()
  d <- dd("[m, km]")
  expect_equal(units::deparse_unit(d$x), "km")
  expect_equal(as.numeric(d$x), 2)
  expect_equal(units::deparse_unit(d$y), "m")
  d2 <- dd("[mm, m, km]")
  expect_equal(units::deparse_unit(d2$x), "km")
  expect_equal(units::deparse_unit(d2$y), "m")
})

test_that("2h L13: a ladder of one, as a string or a one-item list, is today's display exactly (control)", {
  h2_restore()
  for (disp in c("km", "[km]")) {
    d <- dd(disp)
    expect_equal(units::deparse_unit(d$x), "km", label = disp)
    expect_equal(as.numeric(d$x), 2, label = disp)
    expect_equal(units::deparse_unit(d$y), "km", label = disp)
    expect_equal(as.numeric(d$y), 0.9, label = disp)
  }
  d <- dd("m")
  expect_equal(units::deparse_unit(d$x), "m")
  expect_equal(as.numeric(d$x), 2000)
})

test_that("2h L13: an entry with no display, and a number, are unchanged beside entries with a ladder (control)", {
  h2_restore()
  d <- dd()
  expect_equal(as.numeric(d$plain), 0.5)
  expect_equal(units::deparse_unit(d$plain), "m")
  expect_equal(d$n, 5)
})

test_that("2h L13: the ladder picks from the value converted into each rung, whatever unit the value is written in", {
  h2_restore()
  d <- read_dict(f2_dict_file(c(
    "a: {value: 150, type: quantity, unit: cm, display: \"m|km\", definition: \"A length.\"}",
    "b: {value: 0.002, type: quantity, unit: mg/L, display: \"ug/L|mg/L\", definition: \"A concentration.\"}",
    "c: {value: 0.25, type: quantity, unit: m, display: \"mm|m|km\", definition: \"A length.\"}")))
  expect_equal(units::deparse_unit(d$a), "m")
  expect_equal(as.numeric(d$a), 1.5)
  expect_equal(units::deparse_unit(d$b), "ug L-1")   # deparse_unit() writes a quotient so
  expect_equal(as.numeric(d$b), 2)
  expect_equal(units::deparse_unit(d$c), "mm")
  expect_equal(as.numeric(d$c), 250)
})

test_that("2h L13: the pick uses the as-printed number, so 999.96 m goes to km", {
  h2_restore()
  d <- read_dict(f2_dict_file("w: {value: 999.96, type: quantity, unit: m, display: \"m|km\", definition: \"A length.\"}"))
  expect_equal(units::deparse_unit(d$w), "km")
})

# ---- the entry is held in that rung: arithmetic, checks, #, drop_units, the pipeline -----------------------------------

test_that("2h L13: arithmetic, # and drop_units() see the held unit", {
  h2_restore()
  d <- dd()
  expect_equal(as.numeric(d$x * 3), 6)
  expect_equal(units::deparse_unit(d$x * 3), "km")
  expect_equal(as.numeric(units::drop_units(d$x)), 2)
  expect_equal(as.numeric(units::drop_units(d$y)), 900)
  expect_true(d$x > units::set_units(1, "km"))
  expect_equal(h2_wsd("[# was | # were]{n=\"dict$x\"}", d), f2("2~km were"))
  expect_equal(h2_wsd("[# was | # were]{n=\"dict$y\"}", d), f2("900~m were"))
})

test_that("2h L13: .num of the entry prints in the held rung; a computed value stays in it", {
  h2_restore()
  d <- dd()
  expect_equal(h2_wsd("`r dict$x`{.num}", d), f2("2~km"))
  expect_equal(h2_wsd("`r dict$y`{.num}", d), f2("900~m"))
  expect_equal(h2_wsd("`r dict$x * 3`{.num}", d), f2("6~km"))
  expect_equal(h2_wsd("`r dict$y * 3`{.num}", d), f2("2,700~m"))
  # the ladder does not travel: 900 m times 1000 stays in m, and does not move to km
  expect_equal(h2_wsd("`r dict$y * 1000`{.num}", d), f2("900,000~m"))
  suppressWarnings(expect_equal(h2_wsd("`r dict$x / 1000`{.num}", d), f2("0.0~km")))
  expect_equal(f2_tx(fmt_num(d$x)), f2("2~km"))
  expect_equal(f2_tx(fmt_num(d$x * 3)), f2("6~km"))
})

test_that("2h L13: a ladder at the use is the way to a ladder on a computed value", {
  h2_restore()
  d <- dd()
  expect_equal(h2_wsd("`r dict$y * 1000`{.num unit=\"m|km\"}", d), f2("900~km"))
  expect_equal(h2_wsd("`r dict$y * 3`{.num unit=\"m|km\"}", d), f2("2.7~km"))
})

# ---- precedence: unit at the use wins over display: (4.4.15) ---------------------------------------------------------------

test_that("2h 4.4.15: unit at the use wins over a ladder display, and picks from the value in the rung the dictionary gave it", {
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

test_that("2h 4.2.7: the display column holds the rungs joined by |, NA where absent", {
  h2_restore()
  for (disp in c("m|km", "[m, km]", "\"m | km\"")) {
    e <- attr(dd(disp), "entries")
    expect_equal(e$display[e$key == "x"], "m|km", label = disp)
    expect_equal(e$display[e$key == "y"], "m|km", label = disp)
    expect_true(is.na(e$display[e$key == "plain"]), label = disp)
    expect_true(is.na(e$display[e$key == "n"]), label = disp)
  }
  e <- attr(dd("[mm, m, km]"), "entries")
  expect_equal(e$display[e$key == "x"], "mm|m|km")
  expect_equal(e$unit[e$key == "x"], "m")                     # unit is still the unit the value was written in
  e1 <- attr(dd("km"), "entries")
  expect_equal(e1$display[e1$key == "x"], "km")               # control: a single display
})

test_that("2h 4.2.7: print() shows the unit the entry is held in", {
  h2_restore()
  out <- strsplit(paste(capture.output(print(dd())), collapse = "\n"), "\n", fixed = TRUE)[[1]]
  lx <- grep("^\\s*x ", out, value = TRUE)
  ly <- grep("^\\s*y ", out, value = TRUE)
  expect_length(lx, 1L)
  expect_length(ly, 1L)
  expect_match(lx, "2 km", fixed = TRUE)
  expect_match(ly, "900 m", fixed = TRUE)
  expect_false(grepl("2000", lx, fixed = TRUE))
  expect_false(grepl("m|km", paste(out, collapse = "\n"), fixed = TRUE))
})

test_that("2h 2c: the glossary prints the held unit", {
  h2_restore()
  g <- gsub(" ", "~", as.character(dict_glossary(dd())), fixed = TRUE)
  expect_true(grepl("`x` (2~km)", g, fixed = TRUE), label = g)
  expect_true(grepl("`y` (900~m)", g, fixed = TRUE), label = g)
})

# ---- L14: the shipped default digits, whatever _weft.yml sets ------------------------------------------------------------------

test_that("2h L14: a _weft.yml with digits: 3 does not change the pick; a read in a pipeline and a knit agree", {
  h2_restore()
  f <- f2_dict_file("w: {value: 999.96, type: quantity, unit: m, display: \"m|km\", definition: \"A length.\"}")
  plain <- read_dict(f)
  with3 <- withr::with_dir(f2_proj("digits: 3"), read_dict(f))
  expect_equal(units::deparse_unit(plain$w), "km")
  expect_equal(units::deparse_unit(with3$w), "km")
  expect_equal(as.numeric(with3$w), as.numeric(plain$w))
  g2_restore()
})

test_that("2h L14: in a knit with digits: 3 in _weft.yml, the entry is held in the same rung", {
  res <- render_rmd("`r dict$w`{.num}", files = list(
    "_weft.yml" = "digits: 3",
    "dict.yml" = "w: {value: 999.96, type: quantity, unit: m, display: \"m|km\", definition: \"A length.\"}"),
    in_process = TRUE, env = c(WEFT_DRAFT = "1"))
  expect_false(res$failed, label = res$message)
  skip_if(res$failed, "the document did not render")
  expect_true(grepl("km", paste(res$text, collapse = " "), fixed = TRUE))
  expect_false(grepl("999", paste(res$text, collapse = " "), fixed = TRUE))
})

# ---- problems (4.2.6): per rung, in one error with the old ones ------------------------------------------------------------------

test_that("2h 4.2.7: a rung the value does not convert to is a problem naming the key, the field and the rung", {
  e <- dd_err("w: {value: 1, type: quantity, unit: m, display: \"m|kg\", definition: x}")
  f2_msg_has(e, "`w`", "display", "kg")
  e <- dd_err("w: {value: 1, type: quantity, unit: m, display: [m, kg], definition: x}")
  f2_msg_has(e, "`w`", "display", "kg")
})

test_that("2h 4.2.7: a rung that does not parse, or is a twin, is a problem naming the rung", {
  e <- dd_err("w: {value: 1, type: quantity, unit: m, display: \"m|not a unit!!\", definition: x}")
  f2_msg_has(e, "`w`", "display", "not a unit!!")
  e <- dd_err("w: {value: 2, type: quantity, unit: Sv, display: \"mSv|Sv|Gy\", definition: x}")
  f2_msg_has(e, "`w`", "display", "Gy")
})

test_that("2h 4.2.7: an empty or repeated rung is a problem naming the key and the field", {
  for (disp in c("\"m||km\"", "\"m|\"", "\"|m\"", "\"m|km|m\"", "\"m| m\"")) {
    e <- dd_err(sprintf("w: {value: 1, type: quantity, unit: m, display: %s, definition: x}", disp))
    f2_msg_has(e, "`w`", "display")
  }
  e <- dd_err("w: {value: 1, type: quantity, unit: m, display: \"m|km|m\", definition: x}")
  f2_msg_has(e, "`m`")
})

test_that("2h 4.2.7: two rungs of the same size are a problem naming both", {
  e <- dd_err("w: {value: 1, type: quantity, unit: m, display: \"m|metre\", definition: x}")
  f2_msg_has(e, "`w`", "display", "metre")
  e <- dd_err("w: {value: 1, type: quantity, unit: L, display: [L, \"dm^3\"], definition: x}")
  f2_msg_has(e, "`w`", "display", "dm^3")
})

test_that("2h 4.2.7: a list item holding | is a problem", {
  e <- dd_err("w: {value: 1, type: quantity, unit: m, display: [mm, \"m|km\"], definition: x}")
  f2_msg_has(e, "`w`", "display")
})

test_that("2h 4.2.7: a blank or null list item is a problem", {
  e <- dd_err("w: {value: 1, type: quantity, unit: m, display: [m, \"\"], definition: x}")
  f2_msg_has(e, "`w`", "display")
  e <- dd_err("w: {value: 1, type: quantity, unit: m, display: [m, ~], definition: x}")
  f2_msg_has(e, "`w`", "display")
})

test_that("2h 4.2.7: a value that is neither a string nor a list of strings is a problem", {
  for (disp in c("5", "{a: b}", "[5, km]", "true")) {
    e <- dd_err(sprintf("w: {value: 1, type: quantity, unit: m, display: %s, definition: x}", disp))
    f2_msg_has(e, "`w`", "display")
  }
})

test_that("2h 4.2.7: the display problems sit among the dictionary's others, one line each, in one error", {
  e <- dd_err(c("a: {value: 1, type: quantity, unit: m, display: \"m|kg\", definition: x}",
                "b: {value: 1, type: quantity, unit: m, display: \"m||km\", definition: x}",
                "c: {value: 1, type: quantity, unit: m, display: \"m|metre\", definition: x}",
                "d: {value: 1, type: quantity, unit: m, display: [mm, \"m|km\"], definition: x}",
                "e: {value: 5, type: number, display: \"m|km\", definition: x}",
                "f: {value: 1, type: number}"))
  f2_msg_has(e, "`a`", "`b`", "`c`", "`d`", "`e`", "`f`", "kg", "metre")
  m <- f2_msg(e)
  expect_gte(lengths(regmatches(m, gregexpr("display", m, fixed = TRUE))), 5L)
})

test_that("2h 4.2.7: a read with a ladder problem registers nothing from it", {
  e <- dd_err("w: {value: 2, type: quantity, unit: zzh2db/s, display: \"zzh2db/s|kg\", definition: x}")
  f2_msg_has(e, "kg")
  expect_error(u(1, zzh2db))
})

test_that("2h 4.2.6 control: a good ladder beside a bad one reads nothing, and the good one alone reads", {
  expect_s3_class(read_dict(f2_dict_file(OKK)), "weft_dict")
  dd_err("w: {value: 1, type: quantity, unit: m, display: \"m|kg\", definition: x}")
})

# ---- the schema (inst/dict/dict.schema.json) accepts what read_dict() reads -------------------------------------------------

test_that("2h 4.2.1: the schema accepts a ladder display as a string and as a list, and refuses an empty list", {
  skip_if_not_installed("jsonlite")
  skip_if_not(exists("schema_errors"), "the schema helper is not loaded")
  base <- "a: {value: 2000, type: quantity, unit: m, display: %s, definition: x}"
  for (disp in c("\"m|km\"", "[m, km]", "[mm, m, km]", "[km]")) {
    expect_identical(schema_errors(sprintf(base, disp)), character(), label = disp)
  }
  expect_gt(length(schema_errors(sprintf(base, "[]"))), 0L)
  expect_gt(length(schema_errors(sprintf(base, "[5]"))), 0L)
})

# ---- in a knit: dict.yml, dict_local, {unit=} over a ladder ---------------------------------------------------------------

LD_DICT <- c(
  "x: {value: 2000, type: quantity, unit: m, display: \"m|km\", definition: \"A long length.\"}",
  "y: {value: 900, type: quantity, unit: m, display: \"m|km\", definition: \"A short length.\"}",
  "z: {value: 1500, type: quantity, unit: m, display: [m, km], definition: \"A listed length.\"}"
)
LD_CASES <- c(
  "`r dict$x`{.num}",                       # 1 picks km
  "`r dict$y`{.num}",                       # 2 picks m
  "`r dict_local$lx`{.num}",                # 3 a local entry with a ladder: km
  "`r dict$x`{.num unit=\"mm|m\"}",         # 4 unit at the use wins
  "`r dict$x * 3`{.num}",                   # 5 arithmetic keeps the held unit
  "`r dict$x`{.uname}",                     # 6 name of the held unit
  "`r dict$z`{.num}",                       # 7 a YAML list
  "`r dict_local$ly`{.num}"                 # 8 a local entry that stays m
)
LD_WANT <- c("2~km", "900~m", "3~km", "2,000~m", "6~km", "2~kilometres", "1.5~km", "800~m")

ld_render <- local({
  cache <- NULL
  function() {
    if (is.null(cache)) {
      cache <<- render_rmd(
        batch_cases(LD_CASES),
        front = c("weft:", "  dict_local:", "    lx:",
                  "      value: 3000", "      type: quantity", "      unit: m", "      display: \"m|km\"",
                  "      definition: \"A local length.\"", "      why: \"Chapter-specific.\"",
                  "    ly:",
                  "      value: 800", "      type: quantity", "      unit: m", "      display: [m, km]",
                  "      definition: \"Another local length.\"", "      why: \"Chapter-specific.\""),
        files = list("dict.yml" = LD_DICT), in_process = TRUE, env = c(WEFT_DRAFT = "1"))
    }
    cache
  }
})

test_that("2h 4.2.7: in a knit, dict.yml and dict_local apply a ladder display when read", {
  res <- ld_render()
  expect_false(res$failed, label = res$message)
  skip_if(res$failed, "the batch did not render")
  got <- f2_unesc(split_cases(res, length(LD_CASES)))
  for (i in seq_along(LD_WANT)) expect_equal(got[i], f2(LD_WANT[i]), label = LD_CASES[i])
})

test_that("2h 4.2.6: a ladder problem in the project dictionary stops a knit with a dictionary error", {
  res <- render_rmd("`r 1`{.num}", files = list("dict.yml" = c(OKK, "w: {value: 2, type: quantity, unit: m, display: \"m|kg\", definition: x}")),
                    in_process = TRUE, env = c(WEFT_DRAFT = NA))
  expect_true(res$failed)
  expect_true("weft_dict_error" %in% res$error$class)
  expect_match(res$message, "display", fixed = TRUE)
  expect_match(res$message, "kg", fixed = TRUE)
  expect_false(grepl("`okk`", res$message, fixed = TRUE))
})
