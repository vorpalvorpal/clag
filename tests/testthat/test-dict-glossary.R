# Package 2c: dict_glossary(). Contract: dev/design-2c.md "dict_glossary(...)", rules 4.7.1,
# 4.3.3, 2.1.8, C2-C7, C38. `~` in an expected string is U+00A0. Helpers: helper-2c.R.

# the glossary of the fixture, as the contract prints it (default configuration)
GLOSS_ENTRIES <- list(
  core_len      = c("core length (0.5~m)", "Length of each sediment core."),
  method_change = c("Method change (2014)", "First year of the instrument method."),
  min_samples   = c("minimum sample size (5)", "Fewest samples a site needs before its mean is reported."),
  salinity_res  = c("`salinity_res` (0.01~PSU)", "Logger resolution for salinity."),
  study_area    = c("`study_area` (Northern catchment)", "Name used for the study region."),
  survey_start  = c("`survey_start` (1 June 2024)", "First day of the summer survey."),
  trend_word    = c("`trend_word`", "Wording for the ratio of this year's mean to last year's."),
  zone_lab      = c("zone names", "Display names for the survey zones.")
)
FILE_ORDER <- c("min_samples", "core_len", "salinity_res", "method_change", "survey_start",
                "study_area", "zone_lab", "trend_word")

gloss_text <- function(keys, values = TRUE) {
  ent <- vapply(keys, function(k) {
    v <- GLOSS_ENTRIES[[k]]
    h <- if (values) v[1] else sub(" \\(.*\\)$", "", v[1])
    paste0(h, "\n:   ", v[2])
  }, "")
  c2(paste0("\n", paste(ent, collapse = "\n\n"), "\n\n"))
}

fx_dict <- function() read_dict(c2_fixture())
gl <- function(...) as.character(dict_glossary(...))

test_that("2c glossary: the fixture's glossary is exactly the contract's example, and is a knit_asis string (4.7.1, C2)", {
  r <- dict_glossary(fx_dict())
  expect_s3_class(r, "knit_asis")
  expect_identical(as.character(r), gloss_text(names(GLOSS_ENTRIES)))
  expect_identical(as.character(r), c2(paste0("\n",
    "core length (0.5~m)\n:   Length of each sediment core.\n\n",
    "Method change (2014)\n:   First year of the instrument method.\n\n",
    "minimum sample size (5)\n:   Fewest samples a site needs before its mean is reported.\n\n",
    "`salinity_res` (0.01~PSU)\n:   Logger resolution for salinity.\n\n",
    "`study_area` (Northern catchment)\n:   Name used for the study region.\n\n",
    "`survey_start` (1 June 2024)\n:   First day of the summer survey.\n\n",
    "`trend_word`\n:   Wording for the ratio of this year's mean to last year's.\n\n",
    "zone names\n:   Display names for the survey zones.\n\n")))
})

test_that("2c glossary: values = FALSE drops the parentheses from the headings (C4)", {
  expect_identical(gl(fx_dict(), values = FALSE), gloss_text(names(GLOSS_ENTRIES), values = FALSE))
  expect_false(grepl("(", gl(fx_dict(), values = FALSE), fixed = TRUE))
})

test_that("2c glossary: sort = FALSE keeps file order (C5)", {
  expect_identical(gl(fx_dict(), sort = FALSE), gloss_text(FILE_ORDER))
  expect_identical(gl(fx_dict(), sort = FALSE, values = FALSE), gloss_text(FILE_ORDER, values = FALSE))
})

test_that("2c glossary: sorting is by the lower-cased heading text (term or key without backticks), radix, ties by key (C5)", {
  d <- c2_dict(c(
    "b_key: {value: Bee, type: string, definition: \"b.\", term: Zeta}",
    "a_key: {value: Ay, type: string, definition: \"a.\", term: alpha}",
    "c_key: {value: Cee, type: string, definition: \"c.\"}",
    "t2: {value: T2, type: string, definition: \"t2.\", term: same}",
    "t1: {value: T1, type: string, definition: \"t1.\", term: Same}"))
  out <- strsplit(gl(d, values = FALSE), "\n", fixed = TRUE)[[1]]
  heads <- out[seq(2, length(out), by = 3)]
  # alpha, c_key, same (key t1: "Same"), same (key t2), Zeta -> lower-case, radix, ties by key
  expect_identical(heads, c("alpha", "`c_key`", "Same", "same", "Zeta"))
})

test_that("2c glossary: an empty dictionary gives the empty string (4.7.1)", {
  d <- c2_dict("# nothing here")
  expect_length(d, 0L)
  r <- dict_glossary(d)
  expect_identical(as.character(r), "")
})

test_that("2c glossary: whitespace runs in a definition and a string value become one space, markdown stays as written (4.7.1)", {
  d <- c2_dict(c(
    "a:",
    "  value: \"Two   spaces\\nand a newline\"",
    "  type: string",
    "  term: \"*emph* term\"",
    "  definition: |",
    "    First line,",
    "      second **bold** line.",
    ""))
  expect_identical(gl(d), "\n*emph* term (Two spaces and a newline)\n:   First line, second **bold** line.\n\n")
})

test_that("2c glossary: labels and breaks show no value, even with values = TRUE (C6)", {
  out <- gl(fx_dict())
  expect_true(grepl("\n`trend_word`\n:", out, fixed = TRUE))
  expect_true(grepl("\nzone names\n:", out, fixed = TRUE))
})

test_that("2c glossary: why is never shown, and a local dictionary is accepted (4.3.3, C7)", {
  res <- render_rmd(
    c("Body."),
    front = c("weft:", "  dict_local:",
              "    site_class:", "      value: {yes: Allowed, no: Barred}", "      type: labels",
              "      definition: \"Local site classes.\"", "      why: \"This chapter classes sites differently.\"",
              "    core_len:", "      value: \"local text\"", "      type: string",
              "      definition: \"A local core length.\"", "      why: \"Chapter-specific.\""),
    files = list(dict.yml = c2_fixture_lines()), format = "knit", in_process = TRUE)
  expect_false(res$failed, label = res$message)
  out <- gl(res$knit$dict_local)
  expect_identical(out, paste0("\n`core_len` (local text)\n:   A local core length.\n\n",
                               "`site_class`\n:   Local site classes.\n\n"))
  expect_false(grepl("differently", out, fixed = TRUE))
  expect_false(grepl("Chapter-specific", out, fixed = TRUE))
})

test_that("2c glossary: it writes nothing (P10)", {
  d <- fx_dict()   # read before the working directory changes
  dir <- c2_proj(list(dict.yml = c2_fixture_lines()))
  withr::local_dir(dir)
  before <- c2_tree(dir)
  dict_glossary()
  dict_glossary(d)
  expect_identical(c2_tree(dir), before)
})

# ---- dict = NULL outside a knit --------------------------------------------------------------

test_that("2c glossary: dict = NULL outside a knit reads dict.yml at the project root (C7)", {
  dir <- c2_proj(list(dict.yml = c2_fixture_lines()))
  withr::local_dir(dir)
  expect_identical(gl(), gloss_text(names(GLOSS_ENTRIES)))
})

test_that("2c glossary: dict = NULL from a subfolder reads the dict.yml at the root marked by _weft.yml (C7)", {
  dir <- c2_proj(list(dict.yml = c2_fixture_lines(), `_weft.yml` = "digits: 1"))
  dir.create(file.path(dir, "chapters"))
  withr::local_dir(file.path(dir, "chapters"))
  expect_identical(gl(), gloss_text(names(GLOSS_ENTRIES)))
})

test_that("2c glossary: dict = NULL with no dict.yml is a weft_tool_error naming the root, dict and use_dictionary() (Errors)", {
  dir <- c2_proj()
  withr::local_dir(dir)
  e <- c2_err(dict_glossary())
  c2_expect_cond(e, "weft_tool_error")
  c2_expect_msg(e, "dict_glossary(): there is no dict.yml at ", "; give `dict`, or create one with use_dictionary().")
  expect_true(grepl(basename(dir), c2_msg(e), fixed = TRUE))
})

test_that("2c glossary: a dict that is not a dictionary is a weft_tool_error naming its class (Errors)", {
  e <- c2_err(dict_glossary(list(a = 1)))
  c2_expect_cond(e, "weft_tool_error")
  c2_expect_msg(e, "dict_glossary(): `dict` must be a dictionary, as read_dict() returns; got list.")
  e2 <- c2_err(dict_glossary("dict.yml"))
  c2_expect_cond(e2, "weft_tool_error")
  c2_expect_msg(e2, "got character.")
})

test_that("2c glossary: values and sort must each be TRUE or FALSE (Errors)", {
  for (bad in list(NA, "yes", c(TRUE, FALSE), 1, NULL)) {
    e <- c2_err(dict_glossary(fx_dict(), values = bad))
    c2_expect_cond(e, "weft_tool_error")
    c2_expect_msg(e, "dict_glossary(): `values` must be TRUE or FALSE.")
    e2 <- c2_err(dict_glossary(fx_dict(), sort = bad))
    c2_expect_cond(e2, "weft_tool_error")
    c2_expect_msg(e2, "dict_glossary(): `sort` must be TRUE or FALSE.")
  }
  expect_s3_class(dict_glossary(fx_dict(), values = TRUE, sort = FALSE), "knit_asis")
})

# ---- configuration in force ------------------------------------------------------------------

glossary_doc <- function() c(
  "---", "title: \"t\"", "---", "",
  "```{r setup, include=FALSE}", "weft::weft_setup()", "```", "",
  "```{r}", "dict_glossary()", "```")

big_dict <- c("big: {value: 1200, type: number, term: big count, definition: \"A big count.\"}",
              "sal: {value: 0.01, type: quantity, unit: PSU, term: salinity step, definition: \"A step.\"}")

test_that("2c glossary C4: a thousands_from setting in force is the formatter's, so 1200 prints as 1200 (4.7.1)", {
  r <- rmd_html(glossary_doc(), files = list(dict.yml = big_dict, `_weft.yml` = "thousands_from: 10000"))
  expect_false(r$failed, label = r$message)
  expect_true(grepl("big count (1200)", gsub("&nbsp;| ", " ", r$html), fixed = TRUE))
})

test_that("2c glossary C4: with the default configuration 1200 prints with its thousands mark (control)", {
  r <- rmd_html(glossary_doc(), files = list(dict.yml = big_dict))
  expect_false(r$failed, label = r$message)
  expect_true(grepl("big count (1,200)", gsub("&nbsp;| ", " ", r$html), fixed = TRUE))
})

test_that("2c glossary C4: a units: name in _weft.yml changes nothing in the symbol form (9.1.7)", {
  yml <- c("units:", "  PSU:", "    name: practical salinity unit")
  r <- rmd_html(glossary_doc(), files = list(dict.yml = big_dict, `_weft.yml` = yml))
  expect_false(r$failed, label = r$message)
  expect_true(grepl("salinity step (0.01 PSU)", gsub("&nbsp;| ", " ", r$html), fixed = TRUE))
})

# ---- in a knit -------------------------------------------------------------------------------

test_that("2c glossary C38: a chunk calls dict_glossary() with no library(weft) and gets a definition list (2.1.8, 4.7.1)", {
  r <- rmd_html(glossary_doc(), files = list(dict.yml = c2_fixture_lines()))
  expect_false(r$failed, label = r$message)
  html <- gsub("&nbsp;| ", " ", r$html)
  expect_true(grepl("<dl>", html, fixed = TRUE))
  expect_true(grepl("<dt>core length (0.5 m)</dt>", html, fixed = TRUE))
  expect_match(html, "<dd>\\s*(<p>)?Length of each sediment core\\.", perl = TRUE)
})

test_that("2c glossary: in a knit with no dict.yml the knit stops with the weft_tool_error message (Errors)", {
  r <- rmd_html(glossary_doc())
  expect_true(r$failed)
  expect_match(r$message, "dict_glossary(): this document's project has no dict.yml; give `dict`.", fixed = TRUE)
})
