# Package 6g: verify() and the post-render script with documents the resolver filter checks
# (dev/design-6.md N120, N121, N122, N111; messages E36). Most tests use the stand-in `quarto` of
# helper-4c.R (v4_fake_quarto(): it writes the stamps a render would); one uses real Quarto on a set-up
# project, rendered once. ASCII only. Invented content.

vn_failed <- function(r) {
  expect_false(is.null(r$err), label = "verify() raised")
  expect_s3_class(r$err, "weft_verify_error")
  expect_false(r$err$result$ok)
}
vn_passed <- function(r) {
  expect_null(r$err, label = if (!is.null(r$err)) conditionMessage(r$err) else "no error")
  expect_true(r$value$ok)
}
vn_flat <- function(lines) gsub("\\s+", " ", paste(lines, collapse = " "))

E36 <- function(file) sprintf("%s: its values were not computed in this run (rule 2.13.8).", file)

# shell lines that write a stamp as the filter writes it (N110): `fresh` is a JSON literal
vn_sh_stamp <- function(source, fresh = "true", writers = "[\"knit\",\"filter\"]", failures = "", run = "$WEFT_RUN") {
  json <- sprintf(paste0("{\"source\":\"%s\",\"run\":\"%s\",\"executed\":\"2026-11-13 08:19:24\",\"checks\":2,",
                         "\"failures\":[%s],\"writers\":%s,\"named\":1,\"fresh\":%s}"),
                  source, run, failures, writers, fresh)
  c("mkdir -p .weft/stamps", sprintf("cat > '.weft/stamps/%s.json' <<STAMP_EOF", source), json, "STAMP_EOF")
}

vn_proj <- function(files = list("a.qmd" = V4_CONSTRUCT_DOC, "b.qmd" = V4_PLAIN_DOC), quarto_yml = V4_QUARTO_YML,
                    env = parent.frame()) {
  v4_proj(files, quarto_yml = quarto_yml, git = TRUE, env = env)
}

# ---- N120: a stamp with fresh false fails ---------------------------------------------------------------

test_that("N120, E36: a stamp of this run with `fresh` false fails verify(), naming the document", {
  v4_env()
  fq <- v4_fake_quarto(body = vn_sh_stamp("a.qmd", fresh = "false"))
  p <- vn_proj()
  r <- v4_verify(p$root)
  vn_failed(r)
  expect_true(grepl(E36("a.qmd"), vn_flat(r$report), fixed = TRUE))
  expect_identical(NROW(r$res$knit), 0L)               # no failure of its own: `fresh` alone fails it
  expect_false(grepl(E36("b.qmd"), vn_flat(r$report), fixed = TRUE))
})

test_that("N120: a stamp with `fresh` true, or null, passes (control)", {
  for (fresh in c("true", "null")) {
    v4_env()
    fq <- v4_fake_quarto(body = vn_sh_stamp("a.qmd", fresh = fresh))
    p <- vn_proj()
    r <- v4_verify(p$root)
    vn_passed(r)
    expect_false(grepl("its values were not computed in this run", vn_flat(r$report), fixed = TRUE), label = fresh)
  }
})

test_that("N120: a failure of source \"resolve\" in a stamp of this run fails verify() (control)", {
  v4_env()
  f <- paste0("{\"source\":\"resolve\",\"kind\":\"failed claim\",\"file\":\"a.qmd\",\"line\":3,\"chunk\":null,",
              "\"expr\":\"depth\",\"detail\":\"d\",\"hint\":null,\"option\":null,\"chunk_line\":null}")
  fq <- v4_fake_quarto(body = vn_sh_stamp("a.qmd", failures = f))
  p <- vn_proj()
  r <- v4_verify(p$root)
  vn_failed(r)
  expect_identical(NROW(r$res$knit), 1L)
  expect_identical(r$res$knit$kind, "failed claim")
})

test_that("N120, 8.3.4: a document with a construct and no stamp of this run fails (control)", {
  v4_env()
  fq <- v4_fake_quarto()
  p <- vn_proj()
  r <- v4_verify(p$root)
  vn_failed(r)
  expect_true(any(grepl("a.qmd", as.character(unlist(r$res$unexecuted)), fixed = TRUE)))
})

# ---- N122: kept kernels -----------------------------------------------------------------------------------

test_that("N122: .weft/run holds this run's id before the render, and quarto render gets --execute-daemon-restart", {
  v4_env()
  fq <- v4_fake_quarto(body = c("cp .weft/run \"$LOG/runfile\" 2>/dev/null", vn_sh_stamp("a.qmd")))
  p <- vn_proj()
  r <- v4_verify(p$root)
  vn_passed(r)
  run <- v4_log(fq, "run")
  expect_match(run, V4_RUN_RE)
  expect_identical(v4_log(fq, "runfile")[1], run)
  args <- v4_log(fq, "args")
  expect_identical(args[1], "render")
  expect_true("--execute-daemon-restart" %in% args)
})

test_that("N122: with files named, each `quarto render <file>` also gets --execute-daemon-restart", {
  v4_env()
  fq <- v4_fake_quarto(body = vn_sh_stamp("a.qmd"))
  p <- vn_proj()
  r <- v4_verify(p$root, files = "a.qmd")
  vn_passed(r)
  args <- v4_log(fq, "args")
  expect_true(all(c("render", "a.qmd", "--execute-daemon-restart") %in% args))
})

VN_JULIA_DOC <- c("---", "engine: julia", "---", "", "````{.weft-values}",
                  "{\"weft\":1,\"values\":{\"depth\":{\"t\":\"float\",\"v\":\"12.5\"}}}", "````", "",
                  "Depth `depth`{.num} here.")
VN_QUARTO_FILTER <- c(V4_QUARTO_YML, "filters:", "  - weft-check")

test_that("N122: a rendered document on the julia engine makes verify() run `quarto call engine julia kill` first, and say so", {
  v4_env()
  fq <- v4_fake_quarto(body = vn_sh_stamp("j.qmd"))
  p <- vn_proj(list("j.qmd" = VN_JULIA_DOC), quarto_yml = VN_QUARTO_FILTER)
  r <- v4_verify(p$root)
  renders <- v4_log(fq, "renders")
  expect_identical(renders[1], "call engine julia kill")
  expect_length(renders, 2L)
  expect_match(renders[2], "^render( |$)")
  expect_true(any(grepl("julia", r$report, ignore.case = TRUE)))
})

test_that("N122: with no document on the julia engine nothing is killed (control)", {
  v4_env()
  fq <- v4_fake_quarto(body = vn_sh_stamp("a.qmd"))
  p <- vn_proj()
  r <- v4_verify(p$root)
  vn_passed(r)
  renders <- v4_log(fq, "renders")
  expect_length(renders, 1L)
  expect_false(any(grepl("julia", renders, fixed = TRUE)))
  expect_false(any(grepl("julia", r$report, ignore.case = TRUE)))
})

# ---- N121, N111: the post-render script ------------------------------------------------------------------

# Runs the installed post-render script in a temporary project; returns list(status, stderr)
vn_post_render <- function(run_lines, stamps = list(), collection = NULL) {
  script <- system.file("quarto", "weft-post-render.R", package = "weft")
  expect_true(nzchar(script), label = "the post-render script is installed")
  d <- normalizePath(withr::local_tempdir(.local_envir = parent.frame()), winslash = "/")
  dir.create(file.path(d, ".weft", "stamps"), recursive = TRUE)
  writeLines(run_lines, file.path(d, ".weft", "run"))
  for (nm in names(stamps)) writeLines(stamps[[nm]], file.path(d, ".weft", "stamps", nm))
  if (!is.null(collection)) writeLines(collection, file.path(d, ".weft", "failures.jsonl"))
  writeLines("draft: false", file.path(d, "_weft.yml"))
  writeLines("Intro.", file.path(d, "doc.qmd"))
  err <- tempfile()
  withr::local_envvar(c(WEFT_DRAFT = NA, NO_COLOR = "1"))
  withr::local_dir(d)
  st <-suppressWarnings(system2(file.path(R.home("bin"), "Rscript"), c("--vanilla", shQuote(script)),
                                 stdout = FALSE, stderr = err))
  list(status = as.integer(st), stderr = paste(readLines(err, warn = FALSE), collapse = "\n"))
}

vn_stamp_text <- function(run = "R1", fresh = "false") {
  sprintf(paste0("{\"source\":\"doc.qmd\",\"run\":\"%s\",\"executed\":\"2026-11-01 09:00:00\",\"checks\":2,",
                 "\"failures\":[],\"writers\":[\"filter\"],\"named\":2,\"fresh\":%s}"), run, fresh)
}

test_that("N121: a stamp of this run with `fresh` false gets the freeze notice, and fails nothing", {
  r <- vn_post_render(c("R1", "doc.qmd"), list("doc.qmd.json" = vn_stamp_text()))
  expect_identical(r$status, 0L)
  expect_true(grepl("Served from freeze, not executed in this render (their checks did not run):", r$stderr, fixed = TRUE))
  expect_true(grepl("  doc.qmd: 2 constructs were not checked; last run 2026-11-01 09:00:00", r$stderr, fixed = TRUE))
})

test_that("N121: a stamp of this run with `fresh` true, or null, gets no freeze notice (control)", {
  for (fresh in c("true", "null")) {
    r <- vn_post_render(c("R1", "doc.qmd"), list("doc.qmd.json" = vn_stamp_text(fresh = fresh)))
    expect_identical(r$status, 0L)
    expect_false(grepl("Served from freeze", r$stderr, fixed = TRUE), label = fresh)
  }
})

VN_RESOLVE_LINE <- paste0("{\"source\":\"resolve\",\"kind\":\"failed claim\",\"file\":\"doc.qmd\",\"line\":5,",
                          "\"chunk\":null,\"expr\":\"`depth`{.num}\",\"detail\":\"> 10 was false (value 7)\",",
                          "\"hint\":null,\"option\":null,\"chunk_line\":null}")
VN_FILTER_LINE <- paste0("{\"source\":\"filter\",\"kind\":\"failed claim\",\"file\":\"doc.qmd\",\"line\":5,",
                         "\"chunk\":null,\"message\":\"the marker text\",\"text\":\"7<<weft: failed claim, line 5>>\"}")

test_that("N111: a `resolve` line is a failure as it stands, and explains the marker a `filter` line found (control)", {
  both <- vn_post_render(c("R1", "doc.qmd"), list(), c("{\"run\":\"R1\"}", VN_RESOLVE_LINE, VN_FILTER_LINE))
  expect_identical(both$status, 1L)
  expect_true(grepl("weft: 1 claim failed", both$stderr, fixed = TRUE))
  expect_false(grepl("weft: 2 ", both$stderr, fixed = TRUE))
  expect_true(grepl("  doc.qmd:5  `depth`{.num}", both$stderr, fixed = TRUE))
  expect_true(grepl("      > 10 was false (value 7)", both$stderr, fixed = TRUE))
  alone <- vn_post_render(c("R1", "doc.qmd"), list(), c("{\"run\":\"R1\"}", VN_FILTER_LINE))
  expect_identical(alone$status, 1L)
  expect_true(grepl("weft: 1 claim failed", alone$stderr, fixed = TRUE))
})

# ---- real Quarto: the filter's stamp reaches verify() -------------------------------------------------------

VN_HAND_DOC <- c("---", "title: \"a\"", "---", "", "````{.weft-values}",
                 "{\"weft\":1,\"values\":{\"depth\":{\"t\":\"float\",\"v\":\"12.5\"}}}", "````", "",
                 "Depth `depth`{.num} here.")
VN_KNITR_DOC <- c("---", "title: \"b\"", "engine: knitr", "---", "",
                  "```{r setup, include=FALSE}", "weft::weft_setup()", "weft::weft_put(depth = 12.5)", "```", "",
                  "Depth `depth`{.num} here.")

vn_real <- function() {
  if (is.null(v4_cache$vn)) {
    skip_if_no_quarto()
    v4_env(libs = TRUE)
    q <- v4_qproject(list(a = VN_HAND_DOC, b = VN_KNITR_DOC), freeze = FALSE)
    withr::defer(unlink(q$top, recursive = TRUE), teardown_env())
    fx <- list(q = q)
    fx$r <- v4_verify(q$root)
    fx$a <- v4_stamp(q$root, "a.qmd")
    fx$b <- v4_stamp(q$root, "b.qmd")
    v4_cache$vn <- fx
  }
  v4_cache$vn
}

test_that("N120, N91, E36: a hand-written block with no run is not fresh: verify() fails on that document only", {
  fx <- vn_real()
  vn_failed(fx$r)
  flat <- vn_flat(fx$r$report)
  expect_true(grepl(E36("a.qmd"), flat, fixed = TRUE))
  expect_false(grepl(E36("b.qmd"), flat, fixed = TRUE))
})

test_that("N110: the real render's stamps: a filter-only one with fresh false, a merged one with fresh true", {
  fx <- vn_real()
  a <- fx$a
  expect_false(is.null(a))
  expect_match(fm_or(a$run, ""), V4_RUN_RE)
  expect_identical(unlist(a$writers), "filter")
  expect_identical(a$named, 1L)
  expect_identical(a$fresh, FALSE)
  b <- fx$b
  expect_false(is.null(b))
  expect_identical(b$run, a$run)
  expect_identical(unlist(b$writers), c("knit", "filter"))
  expect_identical(b$named, 1L)
  expect_identical(b$fresh, TRUE)
})
