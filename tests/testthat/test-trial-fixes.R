# Six fixes found by a trial on a real manuscript (T1 to T6). Written before the code, from the
# specification; generic fixtures only. Helpers: helper-4a.R, helper-4c.R, helper-2e1.R,
# helper-closing.R, helper-2d.R, helper-3.R, helper-3d.R. ASCII only.

# ---- T1: verify() with no baseline _weft.yml lists no tier-2 findings -----------------------------

# documents committed, `_weft.yml` written afterwards and left uncommitted
t1_proj <- function(env = parent.frame()) {
  p <- v4_proj(list("ch1.qmd" = c("Intro.", "", V4_CLAIM_WORD, "", V4_CLAIM_WORD)), git = TRUE,
               weft_yml = NULL, env = env)
  f3_write(file.path(p$top, "_weft.yml"), "draft: false")
  p
}

t1_passed <- function(r) {
  expect_null(r$err, label = if (!is.null(r$err)) conditionMessage(r$err) else "no error")
  expect_s3_class(r$value, "weft_verify")
  expect_true(r$value$ok)
}

# a baseline commit of `before` (holding _weft.yml), then `after` committed
t1_two <- function(before, after, env = parent.frame()) {
  p <- v4_proj(before, git = TRUE, env = env)
  base <- g_head(p$top)
  g_apply(p$top, after)
  g_add(p$top)
  g_commit(p$top, "second")
  list(p = p, base = base)
}

test_that("T1 (control): the fixture holds tier-2 findings when judged without a baseline", {
  v4_env()
  p <- t1_proj()
  x <- lints(p$root, tier = 2)
  expect_gte(sum(x$rule == "claim-word"), 1L)
  # no git at all: every line counts as added, so they are listed
  q <- v4_proj(list("ch1.qmd" = c("Intro.", "", V4_CLAIM_WORD)))
  expect_gte(nrow(v4_verify(q$root, static = TRUE)$value$tier2), 1L)
})

test_that("T1: a baseline commit without _weft.yml lists no tier-2 findings", {
  v4_env()
  p <- t1_proj()
  r <- v4_verify(p$root, static = TRUE)
  t1_passed(r)
  expect_identical(nrow(r$value$tier2), 0L)
  expect_false(v4_has_section(r$report, "Tier-2 findings on added lines"))
})

test_that("T1: the report says once that tier 2 was not judged, and why", {
  v4_env()
  p <- t1_proj()
  r <- v4_verify(p$root, static = TRUE)
  nt <- grep("tier 2.*not judged", r$value$notes, ignore.case = TRUE, value = TRUE)
  expect_length(nt, 1L)
  expect_match(nt, "_weft.yml", fixed = TRUE)
  expect_equal(sum(grepl("tier 2.*not judged", r$report, ignore.case = TRUE)), 1L)
  # the existing note about the baseline is kept
  expect_true(any(grepl("nothing counts as added", r$value$notes, fixed = TRUE)))
})

test_that("T1 (control): with _weft.yml in the baseline commit there is no such note", {
  v4_env()
  s <- t1_two(
    list("ch1.qmd" = c("Intro.", "", V4_CLAIM_WORD)),
    list("ch1.qmd" = c("Intro.", "", V4_CLAIM_WORD, "", "All `r m` rivers rose.")))
  r <- v4_verify(s$p$root, since = s$base, static = TRUE)
  expect_false(any(grepl("tier 2.*not judged", r$value$notes, ignore.case = TRUE)))
  expect_identical(nrow(r$value$tier2), 1L)
})

# ---- T2: a reader whose store is a parameter with an evaluable default ----------------------------

t2_hash_in <- function(dir, name = "fit") e1_data_hash(dir, name)

test_that("T2: a reader with store = here::here() as its default records the read against that store, with its hash", {
  skip_if_not_installed("here")
  dir <- e1_plain_dir()
  res <- cl_render(c("```{r}",
                     "read_res <- function(name, store = here::here(\"_targets\")) targets::tar_read_raw(name, store = store)",
                     "v <- read_res(\"fit\")", "```", "", "Text."), dir,
                   code = "here::i_am(\"doc.Rmd\")")
  expect_false(res$failed)
  expect_length(d2_of_class(res, "weft_ledger_warning"), 0L)
  tg <- e1_header(dir)$targets
  expect_identical(names(tg), "_targets")
  expect_identical(tg[["_targets"]][["fit"]], t2_hash_in(dir))
})

test_that("T2: a reader with a file.path() default store records the read against that store, with its hash", {
  dir <- e1_plain_dir()
  res <- cl_render(c("```{r}",
                     "read_res <- function(name, store = file.path(getwd(), \"_targets\")) targets::tar_read_raw(name, store = store)",
                     "v <- read_res(\"fit\")", "```", "", "Text."), dir)
  expect_false(res$failed)
  expect_length(d2_of_class(res, "weft_ledger_warning"), 0L)
  expect_identical(e1_header(dir)$targets[["_targets"]][["fit"]], t2_hash_in(dir))
})

test_that("T2: a reader defined in a sourced project file, with a file.path() default store, records the read", {
  dir <- e1_plain_dir()
  res <- cl_render(c("```{r}", "source(\"R/readers.R\", local = TRUE)", "v <- read_res(\"fit\")", "```", "", "Text."), dir,
                   files = list("R/readers.R" = paste("read_res <- function(name, store = file.path(getwd(), \"_targets\"))",
                                                      "  targets::tar_read_raw(name, store = store)")))
  expect_false(res$failed)
  expect_length(d2_of_class(res, "weft_ledger_warning"), 0L)
  expect_identical(e1_header(dir)$targets[["_targets"]][["fit"]], t2_hash_in(dir))
})

test_that("T2 (control): a reader whose store default depends on another argument stays unresolved and warns once", {
  dir <- e1_plain_dir()
  res <- cl_render(c("```{r}",
                     "read_res <- function(name, base, store = file.path(base, \"_targets\")) targets::tar_read_raw(name, store = store)",
                     "v <- read_res(\"fit\", \"nowhere\")", "```", "", "Text."), dir)
  expect_false(res$failed)
  w <- d2_of_class(res, "weft_ledger_warning")
  expect_length(w, 1L)
  expect_true(grepl("7.2.2", e1_flat(d2_msgs(w)), fixed = TRUE))
})

test_that("T2: a wrapper that computes the target name is reported as a read whose name could not be worked out", {
  dir <- e1_plain_dir()
  res <- cl_render(c("```{r}",
                     "read_res <- function(x, store = \"_targets\") targets::tar_read_raw(paste0(\"fi\", x), store = store)",
                     "v <- read_res(\"t\")", "```", "", "Text."), dir)
  expect_false(res$failed)
  w <- d2_of_class(res, "weft_ledger_warning")
  expect_length(w, 1L)
  m <- e1_flat(d2_msgs(w))
  expect_match(m, "name", fixed = TRUE)
  expect_match(m, "could not be worked out", fixed = TRUE)
  expect_match(m, "7.2.2", fixed = TRUE)
  # no target is invented for it
  expect_length(e1_header(dir)$targets, 0L)
})

# ---- T3: source() through here::here() and file.path() --------------------------------------------

t3_files <- list("R/helpers.R" = "hf <- function() 1")

test_that("T3 (control): source(\"R/helpers.R\") puts the file among the header's files", {
  dir <- e1_tmp()
  e1_render(c("```{r}", "source(\"R/helpers.R\", local = TRUE)", "```", "", "Text."), dir, files = t3_files)
  f <- e1_header(dir)$files
  expect_identical(f[["R/helpers.R"]], weft:::file_hash(file.path(dir, "R", "helpers.R")))
})

test_that("T3: source(here::here(\"R\", \"helpers.R\")) is a file input like source(\"R/helpers.R\")", {
  # never run: here::here() would point at the session's project, not at the fixture
  dir <- e1_tmp()
  e1_render(c("```{r}", "if (FALSE) source(here::here(\"R\", \"helpers.R\"))", "```", "", "Text."), dir,
            files = t3_files)
  f <- e1_header(dir)$files
  expect_true("R/helpers.R" %in% names(f))
  expect_identical(f[["R/helpers.R"]], weft:::file_hash(file.path(dir, "R", "helpers.R")))
})

test_that("T3: source(file.path(\"R\", \"helpers.R\")) is a file input like source(\"R/helpers.R\")", {
  dir <- e1_tmp()
  e1_render(c("```{r}", "source(file.path(\"R\", \"helpers.R\"), local = TRUE)", "```", "", "Text."), dir,
            files = t3_files)
  f <- e1_header(dir)$files
  expect_true("R/helpers.R" %in% names(f))
  expect_identical(f[["R/helpers.R"]], weft:::file_hash(file.path(dir, "R", "helpers.R")))
})

# ---- T4: print() of a lint table without its hint column ------------------------------------------

t4_lints <- function(env = parent.frame()) {
  lint_fixture(list("a.qmd" = c("Prose.", "", "See @fig-depth.")), rules = "xref", env = env)
}

test_that("T4: print() of a lint table with the hint column dropped prints the remaining columns", {
  x <- t4_lints()
  expect_gte(nrow(x), 1L)
  y <- x[setdiff(names(x), "hint")]
  expect_false("hint" %in% names(y))
  out <- NULL
  expect_no_error(out <- capture.output(print(y)))
  expect_true(any(grepl("xref", out, fixed = TRUE)))
  expect_true(any(grepl("a.qmd", out, fixed = TRUE)))
})

test_that("T4: the same with zero rows", {
  x <- t4_lints()
  y <- x[0, setdiff(names(x), "hint")]
  expect_identical(nrow(y), 0L)
  expect_no_error(capture.output(print(y)))
})

test_that("T4 (control): print() of the whole table still works", {
  x <- t4_lints()
  expect_true(any(grepl("xref", capture.output(print(x)), fixed = TRUE)))
})

# ---- T5: a bare inline value that prints a missing or non-finite value is a warned check ----------

t5_code <- c("miss_v <- NA", "nan_v <- NaN", "inf_v <- Inf", "ninf_v <- -Inf", "ok_v <- 3", "txt_v <- \"fine\"",
             "mix_v <- c(1, NA)")

t5_knit <- function(lines, files = NULL) d2_run(lines, code = t5_code, files = files)

t5_rows <- function(res) paste(apply(res$knit$warnings, 1L, paste, collapse = " "), collapse = "\n")

test_that("T5: a bare value printing NA, NaN, Inf or -Inf records one warned check each and never fails the render", {
  res <- t5_knit(c("A `r miss_v` a.", "", "B `r nan_v` b.", "", "C `r inf_v` c.", "", "D `r ninf_v` d."))
  expect_false(res$failed)
  k <- res$knit
  expect_equal(nrow(k$warnings), 4L)
  expect_equal(nrow(k$failures), 0L)
  for (e in c("miss_v", "nan_v", "inf_v", "ninf_v")) {
    expect_equal(sum(grepl(e, k$warnings$expr, fixed = TRUE)), 1L, label = e)
  }
})

test_that("T5: the message names the expression and the printed text, and says the value is bare", {
  res <- t5_knit(c("A `r miss_v` a.", "", "B `r ninf_v` b."))
  d <- res$knit$warnings$detail
  a <- d[grepl("miss_v", res$knit$warnings$expr, fixed = TRUE)]
  expect_length(a, 1L)
  expect_match(a, "miss_v", fixed = TRUE)
  expect_match(a, "NA", fixed = TRUE)
  expect_match(a, "bare", ignore.case = TRUE)
  b <- d[grepl("ninf_v", res$knit$warnings$expr, fixed = TRUE)]
  expect_match(b, "-Inf", fixed = TRUE)
})

test_that("T5: each is a raised condition of class weft_bare_missing_warning and weft_warning", {
  res <- t5_knit(c("A `r miss_v` a.", "", "B `r inf_v` b."))
  w <- d2_of_class(res, "weft_bare_missing_warning")
  expect_length(w, 2L)
  for (x in w) {
    expect_s3_class(x, "weft_warning")
    expect_match(conditionMessage(x), "bare", ignore.case = TRUE)
  }
})

test_that("T5: the condition log holds the warning, as a prose warning", {
  res <- t5_knit(c("A `r miss_v` a."))
  ln <- d2_lines(d2_path(res$dir, conditions = TRUE))
  hit <- grep("miss_v", ln, fixed = TRUE, value = TRUE)
  expect_length(hit, 1L)
  expect_match(hit, "\"from\":\"prose\"", fixed = TRUE)
  expect_match(hit, "\"class\":\"warning\"", fixed = TRUE)
})

test_that("T5 (control): a bare value that prints a number, text, or a vector that merely holds an NA records nothing", {
  res <- t5_knit(c("A `r ok_v` a.", "", "B `r txt_v` b.", "", "C `r mix_v` c.", "", "D `r 1 + 1` d."))
  expect_false(res$failed)
  expect_equal(nrow(res$knit$warnings), 0L)
  expect_length(d2_of_class(res, "weft_bare_missing_warning"), 0L)
})

test_that("T5: bare_missing: false in _weft.yml turns it off", {
  res <- t5_knit(c("A `r miss_v` a.", "", "B `r inf_v` b."),
                 files = list("_weft.yml" = c("draft: false", "bare_missing: false")))
  expect_false(res$failed)
  expect_equal(nrow(res$knit$warnings), 0L)
  expect_length(d2_of_class(res, "weft_bare_missing_warning"), 0L)
  expect_length(d2_of_class(res, "weft_config_warning"), 0L)   # a known setting, not an unknown one
})

test_that("T5: it is on by default, and bare_missing: true is the same as the default", {
  res <- t5_knit(c("A `r miss_v` a."), files = list("_weft.yml" = c("draft: false", "bare_missing: true")))
  expect_equal(nrow(res$knit$warnings), 1L)
  expect_length(d2_of_class(res, "weft_config_warning"), 0L)
})

# ---- T6: anchor_calls ------------------------------------------------------------------------------

T6_YML <- c("anchor_calls:", "  - fun: tbl", "    arg: id", "    prefix: \"tbl-\"")
t6_chunk <- function(call) c("```{r}", call, "```")
t6_run <- function(chunk, rules = "xref", prose = "", yml = T6_YML, extra = list()) {
  lines <- c("Intro.", "", if (nzchar(prose)) c(prose, ""), t6_chunk(chunk))
  lint_fixture(c(list("a.qmd" = lines), extra), rules = rules, weft_yml = yml)
}

test_that("T6 (control): without anchor_calls @tbl-depths is an unknown reference", {
  x <- t6_run("tbl(x, id = \"depths\")", prose = "See @tbl-depths.", yml = NULL)
  expect_texts(x, "xref", "tbl-depths")
})

test_that("T6: a tbl(x, id = \"depths\") call defines the anchor tbl-depths", {
  x <- t6_run("tbl(x, id = \"depths\")", prose = "See @tbl-depths.")
  expect_none(x, "xref")
})

test_that("T6: an anchor made by a call that nothing references is anchor-unused, at the call's line", {
  x <- t6_run("tbl(x, id = \"depths\")", rules = "anchor-unused")
  expect_texts(x, "anchor-unused", "tbl-depths")
  expect_at(x, "anchor-unused", "tbl-depths", line = 5L)   # "Intro.", "", fence, then the call
  y <- t6_run("tbl(x, id = \"depths\")", rules = "anchor-unused", prose = "See @tbl-depths.")
  expect_none(y, "anchor-unused")
})

test_that("T6: two calls with the same id are anchor-twice, in one chunk or two files", {
  x <- t6_run(c("tbl(x, id = \"depths\")", "tbl(y, id = \"depths\")"), rules = "anchor-twice")
  expect_texts(x, "anchor-twice", "tbl-depths")
  expect_at(x, "anchor-twice", "tbl-depths", line = 6L)
  y <- t6_run("tbl(x, id = \"depths\")", rules = "anchor-twice",
              extra = list("b.qmd" = c("Words.", "", t6_chunk("tbl(z, id = \"depths\")"))))
  expect_texts(y, "anchor-twice", "tbl-depths")
  # a call twice with different ids is fine
  z <- t6_run(c("tbl(x, id = \"depths\")", "tbl(y, id = \"flows\")"), rules = "anchor-twice")
  expect_none(z, "anchor-twice")
})

test_that("T6: the call's anchor and a header-style anchor of the same id are anchor-twice", {
  x <- t6_run("tbl(x, id = \"depths\")", rules = "anchor-twice",
              extra = list("b.qmd" = c("Table text.", "", ": Depths {#tbl-depths}")))
  expect_texts(x, "anchor-twice", "tbl-depths")
})

test_that("T6: prefix is optional and defaults to the empty string", {
  yml <- c("anchor_calls:", "  - fun: tbl", "    arg: id")
  x <- t6_run("tbl(x, id = \"tbl-depths\")", prose = "See @tbl-depths.", yml = yml)
  expect_none(x, "xref")
  y <- t6_run("tbl(x, id = \"depths\")", prose = "See @tbl-depths.", yml = yml)
  expect_texts(y, "xref", "tbl-depths")
})

test_that("T6: arg is matched by name, or by position when it is an integer", {
  byname <- t6_run("tbl(id = \"depths\", x)", prose = "See @tbl-depths.")
  expect_none(byname, "xref")
  # a different name is not the id
  other <- t6_run("tbl(x, name = \"depths\")", prose = "See @tbl-depths.")
  expect_texts(other, "xref", "tbl-depths")
  pos <- c("anchor_calls:", "  - fun: tbl", "    arg: 2", "    prefix: \"tbl-\"")
  p1 <- t6_run("tbl(x, \"depths\")", prose = "See @tbl-depths.", yml = pos)
  expect_none(p1, "xref")
  p2 <- t6_run("tbl(\"depths\", x)", prose = "See @tbl-depths.", yml = pos)
  expect_texts(p2, "xref", "tbl-depths")
})

test_that("T6: only a literal string argument counts; a computed id is ignored silently", {
  for (code in c("tbl(x, id = paste0(\"dep\", \"ths\"))", "tbl(x, id = nm)", "tbl(x, id = 5)")) {
    x <- t6_run(code, rules = c("xref", "anchor-unused", "anchor-twice"), prose = "See @tbl-depths.")
    expect_identical(sort(x$text[x$rule == "xref"]), "tbl-depths", label = code)   # still undefined
    expect_false(any(x$rule %in% c("anchor-unused", "anchor-twice")), label = code)
  }
})

test_that("T6: a namespaced call pkg::tbl(...) counts", {
  x <- t6_run("mypkg::tbl(x, id = \"depths\")", prose = "See @tbl-depths.")
  expect_none(x, "xref")
})

test_that("T6: a call of another function with the same argument is not an anchor", {
  x <- t6_run("figure(x, id = \"depths\")", prose = "See @tbl-depths.")
  expect_texts(x, "xref", "tbl-depths")
})

test_that("T6: several entries, each defining its own anchors", {
  yml <- c("anchor_calls:", "  - fun: tbl", "    arg: id", "    prefix: \"tbl-\"",
           "  - fun: fig", "    arg: label", "    prefix: \"fig-\"")
  x <- t6_run(c("tbl(x, id = \"depths\")", "fig(y, label = \"flows\")"),
              prose = "See @tbl-depths and @fig-flows.", yml = yml)
  expect_none(x, "xref")
})

test_that("T6: a configuration fault is a weft_config_error naming anchor_calls", {
  bad <- list(
    c("anchor_calls:", "  - arg: id"),                         # no fun
    c("anchor_calls:", "  - fun: tbl"),                        # no arg
    c("anchor_calls:", "  - fun: 5", "    arg: id"),          # fun not a string
    c("anchor_calls:", "  - fun: [a, b]", "    arg: id"),     # fun not a string
    c("anchor_calls:", "  - fun: tbl", "    arg: id", "    prefix: 5"),
    "anchor_calls: tbl"
  )
  for (yml in bad) {
    e <- tryCatch(suppressWarnings(t6_run("tbl(x, id = \"depths\")", yml = yml)), error = function(e) e)
    expect_s3_class(e, "weft_config_error")
    expect_match(conditionMessage(e), "anchor_calls", fixed = TRUE)
  }
})
