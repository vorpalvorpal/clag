# Package 2f: display: on a quantity dictionary entry (4.2.7, U18).
# Contract: dev/design-2f.md "display:" under "Configuration and dictionary fields", "Errors" (weft_dict_error).
# `~` in an expected string is U+00A0. Made-up content only.
if (!exists("f2_ws")) source(testthat::test_path("helper-2f.R"))
if (!exists("render_rmd")) source(testthat::test_path("..", "helper-render.R"))

DISP <- c(
  "reach_len:",
  "  value: 2000",
  "  type: quantity",
  "  unit: m",
  "  display: km",
  "  definition: \"Length of the surveyed reach.\"",
  "core_len: {value: 0.5, type: quantity, unit: m, definition: \"Length of each core.\"}",
  "min_n: {value: 5, type: number, definition: \"Fewest samples.\"}"
)
rdisp <- function(lines = DISP, env = parent.frame()) read_dict(f2_dict_file(lines, env))
# weft_str() with a `dict` the caller's frame holds
wsd <- function(src, dict) f2_unesc(withr::with_dir(f2_proj(), weft_str(src)))

# the message of the weft_dict_error a read raises
disp_err <- function(lines, env = parent.frame()) {
  e <- f2_cond(read_dict(f2_dict_file(lines, env)))
  f2_has_class(e, "weft_dict_error")
  # display is a known field: the problem is about its value, not "unknown field"
  expect_false(grepl("unknown field", f2_msg(e), fixed = TRUE))
  expect_false(grepl("the fields are value, type, definition, unit, decision, why", f2_msg(e), fixed = TRUE))
  e
}

test_that("2f display: the value is read in unit and converted to display (4.2.7)", {
  d <- rdisp()
  expect_s3_class(d$reach_len, "units")
  expect_equal(as.numeric(d$reach_len), 2)
  expect_equal(as.character(units(d$reach_len)), "km")
  expect_equal(as.numeric(units::set_units(d$reach_len, "m", mode = "standard")), 2000)
})

test_that("2f display: an entry with no display is unchanged (control)", {
  d <- rdisp(DISP[7:8])
  expect_equal(as.numeric(d$core_len), 0.5)
  expect_equal(as.character(units(d$core_len)), "m")
  expect_equal(d$min_n, 5)
  d2 <- rdisp()                                  # and the same entries beside one with a display
  expect_equal(as.numeric(d2$core_len), 0.5)
  expect_equal(as.character(units(d2$core_len)), "m")
})

test_that("2f display: a display equal to unit changes nothing", {
  d <- rdisp(c("w: {value: 3, type: quantity, unit: m, display: m, definition: x}"))
  expect_equal(as.numeric(d$w), 3)
  expect_equal(as.character(units(d$w)), "m")
})

test_that("2f display: it converts with a factor too, and registers a display unit as unit is (4.2.7, 4.4.7)", {
  d <- rdisp(c("r: {value: 48, type: quantity, unit: zzda/d, display: zzda/h, definition: x}"))
  expect_equal(as.numeric(d$r), 2)
  expect_equal(as.character(units(d$r)), "zzda/h")
  expect_no_error(u(1, zzda))
})

test_that("2f display: it prints in the display unit, as a symbol and as a name (4.2.7)", {
  d <- rdisp()
  expect_equal(wsd("`r dict$reach_len`{.num}", d), f2("2~km"))
  expect_equal(wsd("`r dict$reach_len`{.uname}", d), f2("2~kilometres"))
  expect_equal(f2_tx(fmt_num(d$reach_len)), f2("2~km"))
})

test_that("2f display: unit= at the use converts back and wins (precedence: the use is nearest)", {
  d <- rdisp()
  expect_equal(wsd("`r dict$reach_len`{.num unit=\"m\"}", d), f2("2,000~m"))
  expect_equal(wsd("`r dict$reach_len`{unit=\"m\" .uname}", d), f2("2,000~metres"))
  expect_equal(f2_tx(fmt_num(d$reach_len, unit = "m")), f2("2,000~m"))
})

test_that("2f display: arithmetic, checks, # and drop_units() see the display unit (U18)", {
  d <- rdisp()
  expect_equal(as.numeric(d$reach_len * 2), 4)
  expect_equal(as.character(units(d$reach_len * 2)), "km")
  expect_equal(as.numeric(units::drop_units(d$reach_len)), 2)
  expect_true(d$reach_len > units::set_units(1, "km"))
  expect_equal(wsd("[# was | # were]{n=\"dict$reach_len\"}", d), f2("2~km were"))
  expect_equal(wsd("[# long]{n=\"dict$reach_len * 2\" .uname}", d), f2("4~kilometres long"))
})

test_that("2f display: the entries attribute gains a display column, NA where absent (4.2.7)", {
  d <- rdisp()
  e <- attr(d, "entries")
  expect_true("display" %in% names(e))
  expect_equal(e$display[e$key == "reach_len"], "km")
  expect_true(is.na(e$display[e$key == "core_len"]))
  expect_true(is.na(e$display[e$key == "min_n"]))
  expect_equal(e$unit[e$key == "reach_len"], "m")          # unit is still the unit the value was written in
  expect_true(all(c("key", "type", "definition", "unit", "decision", "why", "line") %in% names(e)))
})

test_that("2f display: the display column exists, all NA, when no entry has one (4.2.7)", {
  d <- rdisp(c("a: {value: 1, type: quantity, unit: m, definition: x}"))
  e <- attr(d, "entries")
  expect_true("display" %in% names(e))
  expect_true(all(is.na(e$display)))
})

test_that("2f display: print() shows the display unit (4.2.7)", {
  d <- rdisp()
  out <- paste(capture.output(print(d)), collapse = "\n")
  line <- grep("reach_len", strsplit(out, "\n", fixed = TRUE)[[1]], value = TRUE)
  expect_length(line, 1L)
  expect_match(line, "2 km", fixed = TRUE)
  expect_false(grepl("2000", line, fixed = TRUE))
})

test_that("2f display: it is registered into the pipeline as the converted value, so a rebuilt dict is km as well (U18)", {
  d <- rdisp()
  d2 <- rdisp()
  expect_equal(as.character(units(d2$reach_len)), as.character(units(d$reach_len)))
  expect_equal(as.numeric(d2$reach_len), as.numeric(d$reach_len))
})

# ---- the three problems (4.2.6) ----------------------------------------------------------------------------------------

test_that("2f display problems: display on another type is a dictionary problem naming the key (4.2.6, 4.2.7)", {
  e <- disp_err(c("n: {value: 5, type: number, display: km, definition: x}"))
  f2_msg_has(e, "n", "display")
  e2 <- disp_err(c("s: {value: abc, type: string, display: km, definition: x}"))
  f2_msg_has(e2, "s", "display")
})

test_that("2f display problems: a display that does not parse (4.2.6)", {
  e <- disp_err(c("w: {value: 2, type: quantity, unit: m, display: \"not a unit!!\", definition: x}"))
  f2_msg_has(e, "w", "display")
})

test_that("2f display problems: a display that unit does not convert to (4.2.6)", {
  e <- disp_err(c("w: {value: 2, type: quantity, unit: m, display: kg, definition: x}"))
  f2_msg_has(e, "w", "display")
})

test_that("2f display problems: they sit among the dictionary's other problems, one line each (4.2.6)", {
  e <- disp_err(c("w: {value: 2, type: quantity, unit: m, display: kg, definition: x}",
                  "n: {value: 5, type: number, display: km, definition: x}"))
  m <- f2_msg(e)
  f2_msg_has(e, "`w`", "`n`")
  expect_gte(lengths(regmatches(m, gregexpr("display", m, fixed = TRUE))), 2L)
})

test_that("2f display problems: a read with a display problem registers nothing from it and gives no dictionary (4.2.6)", {
  e <- disp_err(c("w: {value: 2, type: quantity, unit: zzdb/s, display: kg, definition: x}"))
  expect_error(u(1, zzdb))
})

# ---- in a knit: dict.yml and dict_local (4.2.7) -------------------------------------------------------------------------------

DISP_CASES <- c(
  "`r dict$reach_len`{.num}",             # 1 project dictionary
  "`r dict$reach_len`{.uname}",           # 2
  "`r dict_local$lenx`{.num}",            # 3 local dictionary entry with display
  "`r dict_local$lenx`{.num unit=\"m\"}"  # 4 unit= wins
)
DISP_WANT <- c("2~km", "2~kilometres", "3~km", "3,000~m")

disp_render <- local({
  cache <- NULL
  function() {
    if (is.null(cache)) {
      cache <<- render_rmd(
        batch_cases(DISP_CASES),
        front = c("weft:", "  dict_local:", "    lenx:",
                  "      value: 3000", "      type: quantity", "      unit: m", "      display: km",
                  "      definition: \"A local length.\"", "      why: \"Chapter-specific.\""),
        files = list("dict.yml" = DISP), in_process = TRUE, env = c(WEFT_DRAFT = "1"))
    }
    cache
  }
})

test_that("2f display: in a knit, dict.yml and dict_local apply display when read (4.2.7)", {
  res <- disp_render()
  expect_false(res$failed, label = res$message)
  skip_if(res$failed, "the batch did not render")
  got <- f2_unesc(split_cases(res, length(DISP_CASES)))
  for (i in seq_along(DISP_WANT)) expect_equal(got[i], f2(DISP_WANT[i]), label = DISP_CASES[i])
})

test_that("2f display: a display problem in the project dictionary stops a knit with a dictionary error (4.2.6)", {
  res <- render_rmd(c("`r 1`{.num}"), files = list("dict.yml" = c("w: {value: 2, type: quantity, unit: m, display: kg, definition: x}")),
                    in_process = TRUE, env = c(WEFT_DRAFT = NA))
  expect_true(res$failed)
  expect_true("weft_dict_error" %in% res$error$class)
  expect_match(res$message, "display", fixed = TRUE)
  expect_false(grepl("unknown field", res$message, fixed = TRUE))
})
