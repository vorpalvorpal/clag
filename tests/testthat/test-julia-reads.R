# Stage 5J-b: what a Julia chunk reads (J4, J21, J22, 2.12.19). The files
# Julia's include() loads from the project are files the chapter read, in the
# ledger's header (7.2.2) and in last_knit()$reads$files; a literal path given
# to JuliaCall::julia_source() in R chunk code is one too; the walker that
# finds dictionary entries and targets reads R chunks only. Documents are
# knitted in this process in a set-up project, except the cases about a fresh
# process (Julia never started; the literal julia_source()), which share one
# child process (no Julia is wanted before them). Julia is shared by the file.

WYR <- "draft: false"

reads_main <- function() {
  if (is.null(.w5j$reads)) {
    outside <- tempfile("weft-5j-outside-")
    dir.create(outside)
    writeLines("t_j5r_outside = 7", file.path(outside, "out.jl"))
    .w5j$reads_outside <- file.path(normalizePath(outside), "out.jl")
    lines <- c(
      "```{julia j4}",
      "include(\"helper.jl\");",
      "include(\".cache/hidden.jl\");",
      "include(\"site-packages/sp.jl\");",
      "include(\"venv/v.jl\");",
      "include(\"renv/r.jl\");",
      "include(\"@DIR@/abs.jl\");",
      sprintf("include(\"%s\");", .w5j$reads_outside),
      "```", "",
      "Done.", "")
    .w5j$reads <- k5j(lines, weft_yml = WYR, files = list(
      "helper.jl" = c("include(\"sub/inner.jl\")", "t_j5r_helper = 1"),
      "sub/inner.jl" = "t_j5r_inner = 2",
      ".cache/hidden.jl" = "t_j5r_hidden = 3",
      "site-packages/sp.jl" = "t_j5r_sp = 4",
      "venv/v.jl" = "t_j5r_venv = 5",
      "renv/r.jl" = "t_j5r_renv = 6",
      "abs.jl" = "t_j5r_abs = 8"))
  }
  .w5j$reads
}

test_that("the reads document knits to its end", {
  res <- reads_main()
  expect_false(res$failed, label = res$message)
})

test_that("J4: helper.jl, its nested sub/inner.jl and a file included by absolute path are in the header's files, with their hashes", {
  res <- reads_main()
  h <- d2_header(d2_path(res$dir))
  expect_setequal(names(h$files), c("doc.Rmd", "helper.jl", "sub/inner.jl", "abs.jl"))
  for (f in c("helper.jl", "sub/inner.jl", "abs.jl")) {
    expect_identical(h$files[[f]], weft:::file_hash(file.path(res$dir, f)), label = f)
    expect_match(h$files[[f]], "^[0-9a-f]{16}$")
  }
  expect_identical(names(h$files), sort(names(h$files), method = "radix"))
})

test_that("J4: last_knit()$reads$files holds the same entries", {
  res <- reads_main()
  f <- res$reads$files
  expect_setequal(names(f), c("doc.Rmd", "helper.jl", "sub/inner.jl", "abs.jl"))
  expect_identical(f[["sub/inner.jl"]], weft:::file_hash(file.path(res$dir, "sub/inner.jl")))
})

test_that("J4: a file under .cache/, site-packages, venv or renv is not there, and neither is a file outside the project", {
  res <- reads_main()
  nm <- names(d2_header(d2_path(res$dir))$files)
  expect_false(any(grepl("^\\.cache", nm)))
  expect_false(any(grepl("site-packages|venv|renv", nm)))
  expect_false(any(grepl("out.jl", nm, fixed = TRUE)))
  expect_false(any(startsWith(nm, "/")))
  expect_false(any(grepl("t_j5r_outside", nm, fixed = TRUE)))
})

test_that("J4 + 7.2.4: editing helper.jl or sub/inner.jl afterwards makes the chapter's entries \"not re-rendered\"", {
  skip_if(Sys.which("git") == "")
  res <- reads_main()
  dir <- res$dir
  d2_git_init(dir)
  d2_git_commit(dir)
  ch <- changes(path = dir)
  expect_false(any(grepl("helper.jl changed", ch$stale$reason, fixed = TRUE)))
  writeLines(c("include(\"sub/inner.jl\")", "t_j5r_helper = 99"), file.path(dir, "helper.jl"))
  ch <- changes(path = dir)
  expect_true(any(grepl("helper.jl changed", ch$stale$reason, fixed = TRUE)))
  writeLines("t_j5r_inner = 98", file.path(dir, "sub", "inner.jl"))
  ch <- changes(path = dir)
  expect_true(any(grepl("sub/inner.jl changed", ch$stale$reason, fixed = TRUE)))
})

# ---- J22: the reads walker reads R chunks only ---------------------------------------------

test_that("J22: a Julia chunk x = tar_read(\"fit\") adds no target, and v = dict[\"depth\"] adds no dictionary entry", {
  dict <- c("depth: {value: 3, type: number, definition: \"The depth.\"}",
            "other: {value: 4, type: number, definition: \"Another value.\"}")
  lines <- c(
    "```{julia j22}",
    "tar_read(x) = x;",
    "v = tar_read(\"fit\");",
    "dict = Dict(\"depth\" => 3);",
    "w = dict[\"depth\"];",
    "```", "",
    "```{r}",
    "rv <- dict$other",
    "```", "",
    "Done.", "")
  res <- k5j(lines, weft_yml = WYR, files = list("dict.yml" = dict))
  expect_false(res$failed, label = res$message)
  # the R chunk is read, so the walker works here; the Julia chunk adds nothing
  expect_identical(names(res$reads$dict), "other")
  expect_length(res$reads$targets, 0L)
  expect_identical(names(d2_header(d2_path(res$dir))$dict), "other")
})

# ---- J4, J21: one fresh process; no Julia is started before them --------------------------

fresh_reads <- function() {
  if (is.null(.w5j$fresh_reads)) {
    .w5j$fresh_reads <- k5j_fresh(r"---(
res <- list()
res$ronly <- knit1(c("Value `r 1`.", "", "```{r}", "x <- 1", "```"),
                   files = list("stray.jl" = "t_j5r_stray = 1"),
                   weft_yml = "draft: false")
res$loaded_after_ronly <- "JuliaCall" %in% loadedNamespaces()
saveRDS(res, .out)
res$src <- knit1(c("```{r}",
                   "JuliaCall::julia_setup(installJulia = FALSE, install = FALSE, verbose = FALSE)",
                   "JuliaCall::julia_source(\"tools.jl\")",
                   "library(JuliaCall)",
                   "julia_source(\"tools2.jl\")",
                   "```", "", "Done."),
                 files = list("tools.jl" = "t_j5r_tools = 1", "tools2.jl" = "t_j5r_tools2 = 2"),
                 weft_yml = "draft: false")
res$tools_hash <- weft:::file_hash(file.path(res$src$dir, "tools.jl"))
res$tools2_hash <- weft:::file_hash(file.path(res$src$dir, "tools2.jl"))
saveRDS(res, .out)
)---")
  }
  .w5j$fresh_reads
}

test_that("J4: a knit in which Julia never started records no file and does not start Julia (fresh process)", {
  skip_if_no_julia()
  res <- fresh_reads()
  skip_if(is.null(res$ronly), "the child saved nothing")
  expect_false(res$ronly$failed, label = res$ronly$message)
  expect_false(res$loaded_after_ronly)
  expect_identical(names(res$ronly$reads$files), "doc.Rmd")
})

test_that("J21: a literal path given to JuliaCall::julia_source() in R chunk code is a file the chapter read, with and without JuliaCall::", {
  skip_if_no_julia()
  res <- fresh_reads()
  skip_if(is.null(res$src), "the child saved nothing")
  expect_false(res$src$failed, label = res$src$message)
  f <- res$src$reads$files
  expect_setequal(names(f), c("doc.Rmd", "tools.jl", "tools2.jl"))
  expect_identical(f[["tools.jl"]], res$tools_hash)
  expect_identical(f[["tools2.jl"]], res$tools2_hash)
})
