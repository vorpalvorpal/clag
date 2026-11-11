# Package 2a: the dictionary in a knit (init_knit(), dict, dict_local, u()).
# Contract: dev/design-2.md "In a knit", "dict_local", D2, D13-D15, D18, D22, section 9.
# Renders go through helper-render.R; most run in this process so that
# last_knit() can be read. The cases that must not see library(weft) run in a
# child process, where only weft::weft_setup() has been called.

# project files for a render: the fixture dictionary, plus any extras
kn <- function(lines, front = NULL, files = list(), draft = FALSE, dict = TRUE,
               in_process = TRUE, ...) {
  if (dict && is.null(files[["dict.yml"]])) files[["dict.yml"]] <- a2_fixture_lines()
  render_rmd(lines, front = front, files = files, in_process = in_process,
             env = if (draft) c(WEFT_DRAFT = "1") else NULL, ...)
}

all_text <- function(res) paste(res$text, collapse = "\n")

# every failure row's text, one string
fail_text <- function(res) {
  f <- res$knit$failures
  if (!NROW(f)) return("")
  paste(unlist(f), collapse = " ")
}

# a local dictionary in front matter: two entries, one of them named like a project key
LOCAL_FRONT <- c(
  "weft:",
  "  dict_local:",
  "    site_class:",
  "      value: {yes: Allowed, no: Barred, upper: Top}",
  "      type: labels",
  "      definition: \"Local site classes.\"",
  "      why: \"This chapter classes sites differently.\"",
  "    core_len:",
  "      value: \"local text\"",
  "      type: string",
  "      definition: \"A local core length.\"",
  "      why: \"Chapter-specific.\""
)

# chunk code that reads the objects and saves what it saw, so the test reads real conditions
PROBE <- c(
  "```{r probe}",
  "conds <- list(",
  "  amb = tryCatch(dict$core_len, error = function(e) e),",
  "  nolocal = tryCatch(dict_local$min_samples, error = function(e) e),",
  "  nokey = tryCatch(dict_local$zzz_none, error = function(e) e),",
  "  proj = dict$min_samples,",
  "  other = dict$reach_len,",
  "  loc = dict_local$core_len,",
  "  lab = as.character(dict_local$site_class('yes')),",
  "  lk = attr(dict, 'local_keys'),",
  "  lscope = attr(dict_local, 'scope'),",
  "  lfile = attr(dict_local, 'file'),",
  "  nlocal = length(dict_local),",
  "  ndict = length(dict)",
  ")",
  "saveRDS(conds, 'conds.rds')",
  "```",
  "",
  "Probed."
)

probe_conds <- function(res) readRDS(file.path(res$dir, "conds.rds"))

# ---- dict and u() are there with no library(weft) ----------------------------------------------

DOC_A <- c(
  "```{r seen}",
  "saveRDS(list(is_dict = inherits(dict, 'weft_dict'), local = inherits(dict_local, 'weft_dict'),",
  "             attached = 'package:weft' %in% search()), 'seen.rds')",
  "```",
  "",
  "P1 Min `r dict$min_samples`{.num} end",
  "",
  "P2 Len `r as.numeric(u(35, m))` and `r as.numeric(u(5, mg/L))` and `r as.numeric(dict$core_len)` end",
  "",
  "P3 Year `r dict$method_change`{.num} end",
  "",
  "P4 Next `r dict$method_change + 1`{.num} end",
  "",
  "P5 Bare `r dict$method_change` end",
  "",
  "P6 Plain `r 2014`{.num} end",
  "",
  "P7 Large `r 12345`{.num} end"
)

test_that("2a knit: dict and u() work in chunk code and inline with only weft_setup() called, no library(weft) (2.1.5, D18)", {
  res <- kn(DOC_A, in_process = FALSE)
  expect_false(res$failed, label = res$message)
  txt <- all_text(res)
  expect_match(txt, "P1 Min 5 end", fixed = TRUE)
  expect_match(txt, "P2 Len 35 and 5 and 0.5 end", fixed = TRUE)
  seen <- readRDS(file.path(res$dir, "seen.rds"))
  expect_true(seen$is_dict)
  expect_true(seen$local)               # dict_local is always there, empty, when dict.yml exists (D14)
  expect_false(seen$attached)           # the control: library(weft) never ran in that session
})

test_that("2a knit: the year prints 2014 under .num, whatever thousands_from says, and 2015 after + 1; a bare value prints 2014 (4.2.1, D8)", {
  res <- kn(DOC_A, in_process = FALSE,
            files = list("_weft.yml" = "thousands_from: 500"))
  expect_false(res$failed, label = res$message)
  txt <- all_text(res)
  expect_match(txt, "P3 Year 2014 end", fixed = TRUE)
  expect_match(txt, "P4 Next 2015 end", fixed = TRUE)
  expect_match(txt, "P5 Bare 2014 end", fixed = TRUE)
  # controls: an ordinary number of the same size does get the mark, a year-sized one too
  expect_match(txt, "P6 Plain 2,014 end", fixed = TRUE)
  expect_match(txt, "P7 Large 12,345 end", fixed = TRUE)
})

# ---- last_knit()$dict, an unknown key in a construct, draft mode ------------------------------------

DOC_B <- c(
  "A1 Known `r dict$min_samples`{.num} here.",
  "",
  "A2 Bad `r dict$min_sampels`{.num} here.",
  "",
  "A3 Local `r length(dict_local)` here."
)

test_that("2a knit: last_knit()$dict is the object read from dict.yml, and $dict_local is the empty local object (2.1.5)", {
  res <- kn(DOC_B, draft = TRUE)
  expect_false(res$failed, label = res$message)
  k <- res$knit
  expect_s3_class(k$dict, "weft_dict")
  expect_identical(names(k$dict), c("min_samples", "core_len", "reach_len", "sample_mass",
                                    "salinity_res", "coliform_limit", "site_density",
                                    "method_change", "survey_start", "region_name",
                                    "zone_lab", "trend_word"))
  expect_equal(as.list(k$dict), as.list(read_dict(a2_fixture())))
  expect_identical(attr(k$dict, "scope"), "project")
  expect_s3_class(k$dict_local, "weft_dict")
  expect_identical(attr(k$dict_local, "scope"), "local")
  expect_length(k$dict_local, 0L)
  expect_match(all_text(res), "A3 Local 0 here.", fixed = TRUE)
})

test_that("2a knit: an unknown key under {.num} is a 'no value' failure whose detail names the key, and the render carries on in draft mode (2.1.5)", {
  res <- kn(DOC_B, draft = TRUE)
  expect_false(res$failed, label = res$message)
  f <- res$knit$failures
  expect_equal(NROW(f), 1L)                                   # A1 and A3 are controls: no failure
  expect_identical(f$kind, "no value")
  expect_true(grepl("min_sampels", paste(f$expr, f$detail), fixed = TRUE))
  expect_true(grepl("no such key", f$detail, fixed = TRUE))
  expect_equal(f$line, res$offset + 3L)
  expect_match(all_text(res), "A2 Bad <<weft: no value, line", fixed = TRUE)
  expect_match(all_text(res), "A1 Known 5 here.", fixed = TRUE)
})

test_that("2a knit: without draft mode the unknown key stops the render and the error names the key (2.1.5)", {
  res <- kn(DOC_B)
  expect_true(res$failed)
  expect_match(res$message, "min_sampels", fixed = TRUE)
})

test_that("2a knit: in a bare value the knit stops with the key error's message, as stock knitr stops (2.1.5)", {
  res <- kn(c("Bare `r dict$min_sampels` here."))
  expect_true(res$failed)
  expect_match(res$message, "min_sampels", fixed = TRUE)
  expect_match(res$message, "no such key", fixed = TRUE)
  expect_match(res$message, "Did you mean `min_samples`?", fixed = TRUE)
})

test_that("2a knit: in chunk code the knit stops with the key error's message (2.1.5)", {
  res <- kn(c("```{r}", "x <- dict$min_sampels", "```", "", "Body."))
  expect_true(res$failed)
  expect_match(res$message, "min_sampels", fixed = TRUE)
  expect_match(res$message, "no such key", fixed = TRUE)
})

# ---- dict_local --------------------------------------------------------------------------------------

test_that("2a knit: dict_local from front matter reads, with a yes: label, and no unknown-setting warning is raised (4.3.1, D13)", {
  res <- kn(PROBE, front = LOCAL_FRONT)
  expect_false(res$failed, label = res$message)
  c0 <- probe_conds(res)
  expect_identical(c0$lab, "Allowed")                         # yes stays text, not TRUE
  expect_identical(c0$loc, "local text")
  expect_identical(c0$nlocal, 2L)
  expect_identical(c0$ndict, 12L)
  expect_identical(c0$lscope, "local")
  expect_match(c0$lfile, "doc\\.Rmd$")
  expect_setequal(c0$lk, c("site_class", "core_len"))
  expect_false(any(grepl("nknown", res$log) & grepl("dict_local", res$log, fixed = TRUE)),
               label = "no unknown-setting warning for dict_local")
  # the record keeps both objects, and the project dict knows the local keys
  expect_setequal(attr(res$knit$dict, "local_keys"), c("site_class", "core_len"))
  expect_identical(names(res$knit$dict_local), c("site_class", "core_len"))
  e <- attr(res$knit$dict_local, "entries")
  expect_identical(e$why[e$key == "site_class"], "This chapter classes sites differently.")
  # a key the chapter does not define still reads from the project, even one near a local key
  expect_qty(c0$other, 2, "m")
  expect_equal(c0$proj, 5)
})

test_that("2a knit: dict$k where the chapter defines a local k is a weft_dict_ambiguous error naming dict_local$k (4.3.2)", {
  res <- kn(PROBE, front = LOCAL_FRONT)
  e <- probe_conds(res)$amb
  expect_weft_cond(e, "weft_dict_ambiguous", "dict$core_len")
  expect_match(conditionMessage(e), "`dict$core_len`: this chapter defines a local `core_len`; read it as `dict_local$core_len` (rule 4.3.2).",
               fixed = TRUE)
})

test_that("2a knit: dict_local$k with no local k is an error naming rule 4.3.2 and pointing at dict$k when the project holds it (4.3.2)", {
  res <- kn(PROBE, front = LOCAL_FRONT)
  c0 <- probe_conds(res)
  expect_weft_cond(c0$nolocal, "weft_dict_key_error", "dict_local$min_samples")
  m <- conditionMessage(c0$nolocal)
  expect_match(m, "`dict_local$min_samples`: this chapter defines no local `min_samples` (rule 4.3.2).", fixed = TRUE)
  expect_match(m, "The project's entry is `dict$min_samples`.", fixed = TRUE)
  # a key held by neither: the same error without the pointer
  expect_weft_cond(c0$nokey, "weft_dict_key_error", "dict_local$zzz_none")
  expect_match(conditionMessage(c0$nokey), "this chapter defines no local `zzz_none` (rule 4.3.2).", fixed = TRUE)
  expect_false(grepl("The project's entry", conditionMessage(c0$nokey), fixed = TRUE))
})

LOCAL_NO_WHY <- c(
  "weft:",
  "  dict_local:",
  "    loc_k:",
  "      value: 1",
  "      type: number",
  "      definition: \"A local value.\""
)

test_that("2a knit: a local entry without why stops the knit with weft_dict_error, in draft mode too (4.3.3, D15)", {
  for (draft in c(FALSE, TRUE)) {
    res <- kn(c("Body `r 1`{.num} text."), front = LOCAL_NO_WHY, draft = draft)
    lab <- if (draft) "draft" else "non-draft"
    expect_true(res$failed, label = paste(lab, "the knit stopped"))
    expect_true("weft_dict_error" %in% res$error$class, label = paste(lab, "class"))
    expect_match(res$message, "why", fixed = TRUE)
    expect_match(res$message, "`loc_k`", fixed = TRUE)
    expect_match(res$message, "doc.Rmd", fixed = TRUE)         # the document's path
    expect_match(res$message, "problem(s) in the dictionary", fixed = TRUE)
  }
})

test_that("2a knit: a local entry need not be in dict.yml and its type is not compared with the project's (D12)", {
  res <- kn(PROBE, front = LOCAL_FRONT)
  expect_false(res$failed, label = res$message)
  # site_class is not in dict.yml; core_len is a quantity there and a string here
  expect_false("site_class" %in% names(read_dict(a2_fixture())))
  expect_identical(probe_conds(res)$loc, "local text")
})

test_that("2a knit: a local dictionary with no project dict.yml still gives dict_local (4.3, D14)", {
  res <- kn(c("```{r}", "saveRDS(list(has_dict = exists('dict', inherits = FALSE), k = names(dict_local)), 'x.rds')", "```", "", "B."),
            front = LOCAL_FRONT, dict = FALSE)
  expect_false(res$failed, label = res$message)
  x <- readRDS(file.path(res$dir, "x.rds"))
  expect_identical(x$k, c("site_class", "core_len"))
  expect_false(x$has_dict)
  expect_null(res$knit$dict)
  expect_s3_class(res$knit$dict_local, "weft_dict")
})

test_that("2a knit: with neither dict.yml nor local entries nothing is assigned and last_knit() holds NULL for both (2.1.5)", {
  res <- kn(c("```{r}", "saveRDS(list(d = exists('dict', inherits = FALSE), l = exists('dict_local', inherits = FALSE)), 'x.rds')", "```", "", "B."),
            dict = FALSE)
  expect_false(res$failed, label = res$message)
  x <- readRDS(file.path(res$dir, "x.rds"))
  expect_false(x$d)
  expect_false(x$l)
  expect_null(res$knit$dict)
  expect_null(res$knit$dict_local)
})

test_that("2a knit: dict_local in _weft.yml is a weft_config_error that says front matter (4.3.4, 9.1.2, D13)", {
  res <- kn(c("Body."),
            files = list("_weft.yml" = c(
              "dict_local:",
              "  k: {value: 1, type: number, definition: d, why: w}")))
  expect_true(res$failed)
  expect_true("weft_config_error" %in% res$error$class)
  expect_match(res$message, "`dict_local` is written in a document's front matter, not in _weft.yml (rules 4.3.4, 9.1.2).",
               fixed = TRUE)
})

# ---- a bad project dictionary, two knits -------------------------------------------------------------------

test_that("2a knit: a problem in dict.yml stops the knit with weft_dict_error, in draft mode too (4.1.1, D15)", {
  bad <- c("good: {value: 1, type: number, definition: ok}",
           "bad: {value: 1, type: number}")
  for (draft in c(FALSE, TRUE)) {
    res <- kn(c("Body `r 1`{.num} text."), files = list("dict.yml" = bad), draft = draft)
    lab <- if (draft) "draft" else "non-draft"
    expect_true(res$failed, label = paste(lab, "the knit stopped"))
    expect_true("weft_dict_error" %in% res$error$class, label = paste(lab, "class"))
    expect_match(res$message, "dict.yml", fixed = TRUE)
    expect_match(res$message, "`bad`", fixed = TRUE)
    expect_match(res$message, "definition", fixed = TRUE)
    expect_match(res$message, ":2: `bad`", fixed = TRUE)
  }
})

test_that("2a knit: every top-level knit re-creates the objects, so a second document with no local entries sees an empty dict_local (2.1.5, D14)", {
  r1 <- kn(PROBE, front = LOCAL_FRONT)
  expect_false(r1$failed, label = r1$message)
  expect_identical(probe_conds(r1)$nlocal, 2L)
  r2 <- kn(c(
    "```{r}",
    "saveRDS(list(n = length(dict_local), lk = attr(dict, 'local_keys'),",
    "             err = tryCatch(dict_local$core_len, error = function(e) e),",
    "             ok = dict$core_len), 'second.rds')",
    "```", "", "Second."))
  expect_false(r2$failed, label = r2$message)
  s <- readRDS(file.path(r2$dir, "second.rds"))
  expect_identical(s$n, 0L)
  expect_identical(s$lk, character())
  expect_weft_cond(s$err, "weft_dict_key_error", "dict_local$core_len in the second knit")
  expect_match(conditionMessage(s$err), "defines no local `core_len`", fixed = TRUE)
  expect_match(conditionMessage(s$err), "The project's entry is `dict$core_len`.", fixed = TRUE)
  expect_s3_class(s$ok, "units")                               # the project's core_len reads, no longer ambiguous
  expect_length(r2$knit$dict_local, 0L)
  expect_identical(attr(r2$knit$dict, "local_keys"), character())
})

# ---- a check against a bare number --------------------------------------------------------------------------

test_that("2a knit: a failed check against a bare number is a failed claim with the 4.4.5 hint; a check in the unit passes (4.4.5, D20)", {
  res <- kn(c(
    "```{r}",
    "ok <- claim(dict$core_len, . < u(1, m))",
    "```",
    "",
    "```{r}",
    "bad <- claim(dict$core_len, . < 1)",
    "```",
    "",
    "Body."))
  expect_true(res$failed)
  expect_match(res$message, "state the check's unit, as in . < u(0.45, ug) (rule 4.4.5)", fixed = TRUE)
  f <- res$knit$failures
  expect_equal(NROW(f), 1L)                                    # the check in the unit is no failure
  expect_identical(f$kind, "failed claim")
  expect_match(fail_text(res), "state the check's unit", fixed = TRUE)
})

# ---- Quarto -----------------------------------------------------------------------------------------------------

test_that("2a knit: under Quarto and rmarkdown, dict, u() and the year work inline (2.1.5, 4.2.1, D18)", {
  lines <- c("Min `r dict$min_samples`{.num} year `r dict$method_change`{.num} length `r as.numeric(u(35, m))` end.")
  both(lines, function(res, engine) {
    expect_false(res$failed, label = paste(engine, res$message))
    expect_match(res$md, "Min 5 year 2014 length 35 end.", fixed = TRUE, label = engine)
  }, files = list("dict.yml" = a2_fixture_lines()))
})
