# Package 6g: the stamp the resolver filter writes (dev/design-6.md N110, N88; N111 for the failures it
# carries). Plain Pandoc through filter_md() (helper-filter.R, helper-6g.R). The stamp is
# `.weft/stamps/<stamp_file_name(source)>` in a set-up project (one with `_weft.yml`) only.
# ASCII only. Invented content.

ST_YML <- "serial_comma: true"   # a set-up project that says nothing about draft or the ledger
ST_AT <- 1794822900L
ST_KEYS <- c("source", "run", "executed", "checks", "failures", "writers", "named", "fresh")
ST_VALUES <- function(run = "R1", at = ST_AT) g6_block(depth = fr_float("12.5"), n = fr_int("4"), run = run, at = at)
ST_BODY <- "Depth `depth`{.num} m and `n`{.num} sites."

st_run <- function(md = c(ST_VALUES(), "", ST_BODY), env = c(WEFT_RUN = "R1"), ...) {
  filter_md(md, weft_yml = ST_YML, env = env, ...)
}

# a stamp as the hooks write it (R/collect.R: record_knit), one knit failure
ST_HOOKS_FAILURE <- paste0("{\"source\":\"knit\",\"kind\":\"failed claim\",\"file\":\"doc.md\",\"line\":3,",
                           "\"chunk\":null,\"expr\":\"x\",\"detail\":\"d\",\"hint\":null,\"option\":null,\"chunk_line\":null}")
st_hooks_stamp <- function(run = "R1", writers = NULL, failures = TRUE) {
  c("{",
    "  \"source\": \"doc.md\",",
    sprintf("  \"run\": \"%s\",", run),
    "  \"executed\": \"2026-11-13 08:19:24\",",
    "  \"checks\": 2,",
    if (failures) c("  \"failures\": [", paste0("    ", ST_HOOKS_FAILURE), "  ]") else "  \"failures\": []",
    if (!is.null(writers)) c(",", sprintf("  \"writers\": %s", writers)),
    "}")
}

test_that("N110: a set-up project gets one stamp: R's members in R's order, then writers, named and fresh", {
  res <- st_run()
  expect_identical(res$status, 0L)
  stamps <- grep("^\\.weft/stamps/", names(res$files), value = TRUE)
  expect_identical(stamps, G6_STAMP)
  s <- g6_stamp(res)
  expect_identical(names(s), ST_KEYS)
  expect_identical(s$source, "doc.md")
  expect_identical(s$run, "R1")
  expect_identical(s$executed, g6_local_time(ST_AT))
  expect_identical(s$failures, list())
  expect_identical(unlist(s$writers), "filter")
  expect_identical(s$named, 2L)
  expect_true(isTRUE(s$fresh))
  expect_true(is.numeric(s$checks) && s$checks >= 1)
})

test_that("N110: `executed` is the oldest `at` of the blocks, in local time", {
  older <- 1794822000L
  md <- c(ST_VALUES(at = ST_AT), "", g6_block(other = fr_int("1"), run = "R1", at = older), "", ST_BODY)
  s <- g6_stamp(st_run(md))
  expect_identical(s$executed, g6_local_time(older))
  # the order of the blocks does not matter
  md <- c(g6_block(other = fr_int("1"), run = "R1", at = older), "", ST_VALUES(at = ST_AT), "", ST_BODY)
  expect_identical(g6_stamp(st_run(md))$executed, g6_local_time(older))
})

test_that("N110: with no block `executed` is now, `named` is 0 and `fresh` is null", {
  before <- Sys.time()
  res <- st_run(c("Plain text, no weft construct."))
  expect_identical(res$status, 0L)
  s <- g6_stamp(res)
  expect_identical(names(s), ST_KEYS)
  expect_identical(s$run, "R1")
  expect_match(fm_or(s$executed, ""), "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$")
  t <- as.POSIXct(fm_or(s$executed, ""), format = "%Y-%m-%d %H:%M:%S")
  expect_true(!is.na(t) && abs(as.numeric(difftime(t, before, units = "secs"))) < 120)
  expect_identical(s$named, 0L)
  expect_true("fresh" %in% names(s))
  expect_null(s$fresh)
})

test_that("N110, N91: `fresh` is true when every block's run is the current run, false when one differs or is null", {
  cases <- list(
    same = list(md = c(ST_VALUES(run = "R1"), "", ST_BODY), fresh = TRUE),
    differs = list(md = c(ST_VALUES(run = "R0"), "", ST_BODY), fresh = FALSE),
    no_run = list(md = c(g6_block(depth = fr_float("12.5"), n = fr_int("4"), at = ST_AT), "", ST_BODY), fresh = FALSE),
    one_of_two = list(md = c(ST_VALUES(run = "R1"), "", g6_block(m = fr_int("1"), run = "R0"), "", ST_BODY), fresh = FALSE)
  )
  for (nm in names(cases)) {
    res <- st_run(cases[[nm]]$md)
    expect_identical(res$status, 0L, label = paste("status for", nm))  # a stale run fails nothing (N91)
    expect_identical(g6_stamp(res)$fresh, cases[[nm]]$fresh, label = paste("fresh for", nm))
  }
  # no current run (no WEFT_RUN, no .weft/run): null, whatever the blocks say
  res <- st_run(c(ST_VALUES(run = "R0"), "", ST_BODY), env = character())
  expect_identical(res$status, 0L)
  expect_null(g6_stamp(res)$fresh)
})

test_that("N110, N91: the current run may come from .weft/run, and is then the stamp's `run`", {
  res <- st_run(c(ST_VALUES(run = "R2"), "", ST_BODY), env = character(), files = list(".weft/run" = "R2"))
  s <- g6_stamp(res)
  expect_identical(s$run, "R2")
  expect_true(isTRUE(s$fresh))
})

test_that("N110: `named` counts the constructs the filter resolved, a governed span among them", {
  md <- c(g6_block(depth = fr_float("12.5"), rising = fr_bool(TRUE), run = "R1", at = ST_AT), "",
          "Depth `depth`{.num} m. [up | down]{if=\"rising\"} ok.")
  expect_identical(g6_stamp(st_run(md))$named, 2L)
})

test_that("N110: the hooks' stamp of the same run is merged: writers both, counts added, the knit failure kept", {
  for (writers in list(NULL, "[\"knit\"]")) {
    res <- st_run(files = list(".weft/stamps/doc.md.json" = st_hooks_stamp(writers = writers)))
    expect_identical(res$status, 0L)
    s <- g6_stamp(res)
    expect_identical(names(s), ST_KEYS, label = paste("members with writers", fm_or(writers, "absent")))
    expect_identical(s$source, "doc.md")
    expect_identical(s$run, "R1")
    expect_identical(s$executed, "2026-11-13 08:19:24")   # the hooks' time stays
    expect_identical(unlist(s$writers), c("knit", "filter"))
    expect_identical(s$named, 2L)
    expect_true(isTRUE(s$fresh))
    expect_true(s$checks > 2)                              # the filter's counts are added to the hooks' 2
    expect_length(s$failures, 1L)
    expect_identical(s$failures[[1]]$source, "knit")
    expect_identical(s$failures[[1]]$kind, "failed claim")
    expect_identical(s$failures[[1]]$line, 3L)
  }
})

test_that("N110: a stamp of another run is not merged: a new stamp replaces it, writers only the filter", {
  res <- st_run(files = list(".weft/stamps/doc.md.json" = st_hooks_stamp(run = "OLD")))
  s <- g6_stamp(res)
  expect_identical(s$run, "R1")
  expect_identical(unlist(s$writers), "filter")
  expect_identical(s$failures, list())
  expect_identical(s$executed, g6_local_time(ST_AT))
  expect_identical(s$named, 2L)
})

test_that("N110, N111: the filter's failures join the stamp's `failures` with source \"resolve\"", {
  cases <- c(claim = "Depth `depth`{.num} m.")
  blocks <- list(g6_block(depth = fr_with(fr_int("7"), fr_check("> 10")), run = "R1", at = ST_AT))
  d <- fm_doc(cases, blocks)
  L <- d$line[["claim"]]
  # alone
  res <- filter_md(d$md, weft_yml = ST_YML, env = c(WEFT_RUN = "R1", WEFT_DRAFT = "1"))
  s <- g6_stamp(res)
  expect_length(s$failures, 1L)
  f <- s$failures[[1]]
  expect_identical(f$source, "resolve")
  expect_identical(f$kind, "failed claim")
  expect_identical(f$file, "doc.md")
  expect_identical(f$line, L)
  expect_true(grepl(fm_msg$E14("> 10", "7"), f$detail, fixed = TRUE))
  # beside the hooks' failure
  res <- filter_md(d$md, weft_yml = ST_YML, env = c(WEFT_RUN = "R1", WEFT_DRAFT = "1"),
                   files = list(".weft/stamps/doc.md.json" = st_hooks_stamp()))
  s <- g6_stamp(res)
  expect_identical(vapply(s$failures, function(x) x$source, ""), c("knit", "resolve"))
})

test_that("N86, N88, N110: the stamp is written before the exit, and draft mode changes only the exit", {
  cases <- c(claim = "Depth `depth`{.num} m.")
  blocks <- list(g6_block(depth = fr_with(fr_int("7"), fr_check("> 10")), run = "R1", at = ST_AT))
  d <- fm_doc(cases, blocks)
  hard <- filter_md(d$md, weft_yml = ST_YML, env = c(WEFT_RUN = "R1"))
  soft <- filter_md(d$md, weft_yml = ST_YML, env = c(WEFT_RUN = "R1", WEFT_DRAFT = "1"))
  expect_identical(hard$status, 1L)
  expect_identical(soft$status, 0L)
  expect_false(is.null(hard$files[[G6_STAMP]]))
  expect_identical(hard$files[[G6_STAMP]], soft$files[[G6_STAMP]])
  expect_identical(g6_stamp(hard)$failures[[1]]$kind, "failed claim")
})

test_that("N110: the stamp's file name is R's stamp_file_name(source), for a nested and for an awkward source", {
  res <- st_run(c(ST_VALUES(), "", ST_BODY), name = "ch/a.md")
  expect_identical(grep("^\\.weft/stamps/", names(res$files), value = TRUE), ".weft/stamps/ch__a.md.json")
  expect_identical(g6_stamp(res, ".weft/stamps/ch__a.md.json")$source, "ch/a.md")
  res <- st_run(c(ST_VALUES(), "", ST_BODY), name = "a__b.md")
  want <- file.path(".weft/stamps", weft:::stamp_file_name("a__b.md"))
  expect_identical(grep("^\\.weft/stamps/", names(res$files), value = TRUE), want)
  expect_identical(g6_stamp(res, want)$source, "a__b.md")
})

test_that("N110: outside a set-up project (no _weft.yml) the filter writes no stamp and no ledger (control)", {
  res <- filter_md(c(ST_VALUES(), "", ST_BODY), env = c(WEFT_RUN = "R1"))
  expect_identical(res$status, 0L)
  expect_length(res$files, 0L)
  expect_match(res$output, "12.5", fixed = TRUE)   # it still resolved the values
})
