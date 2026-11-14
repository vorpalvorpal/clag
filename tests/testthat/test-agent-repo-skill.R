# agent_repo_skill(): the repository's skills/weft/ folder, and the Claude Code manifests that serve it.
# ASCII only.

ars_files <- c("skills/weft/SKILL.md", "skills/weft/references/reports.md", "skills/weft/references/syntax.md")
ars_dir <- function(env = parent.frame()) {
  d <- normalizePath(tempfile("ars-"), mustWork = FALSE)
  dir.create(d)
  withr::defer(unlink(d, recursive = TRUE), envir = env)
  d
}
ars_gen <- function(env = parent.frame()) {
  d <- ars_dir(env)
  weft:::agent_repo_skill(d)
  d
}
ars_read <- function(f) readBin(f, "raw", file.info(f)$size)
# the repository root, or NULL when the source tree is not there (an installed package, R CMD check)
ars_root <- function() {
  for (p in c(testthat::test_path("..", ".."), testthat::test_path("..", "..", ".."))) {
    if (file.exists(file.path(p, "DESCRIPTION")) && dir.exists(file.path(p, "inst", "agent")) &&
        dir.exists(file.path(p, "dev"))) return(normalizePath(p))
  }
  NULL
}
ars_json_version <- function(f) {
  x <- jsonlite::fromJSON(f, simplifyVector = FALSE)
  x
}

test_that("agent_repo_skill writes exactly the three files, and returns their paths", {
  d <- ars_dir()
  res <- weft:::agent_repo_skill(d)
  expect_setequal(list.files(d, recursive = TRUE, all.files = TRUE, no.. = TRUE), ars_files)
  expect_setequal(res, ars_files)
})

test_that("agent_repo_skill: no marker line and no placeholder in any file", {
  d <- ars_gen()
  for (f in ars_files) {
    x <- readLines(file.path(d, f), warn = FALSE)
    expect_false(any(grepl("weft-file:", x, fixed = TRUE)), label = f)
    expect_false(any(grepl("@VERSION@|@HASH@", x)), label = f)
  }
})

test_that("agent_repo_skill: SKILL.md front matter has name weft and the package version", {
  d <- ars_gen()
  x <- readLines(file.path(d, "skills/weft/SKILL.md"), warn = FALSE)
  expect_identical(x[[1L]], "---")
  end <- which(x == "---")[2L]
  expect_false(is.na(end))
  fm <- x[2:(end - 1L)]
  expect_true("name: weft" %in% fm)
  expect_true(sprintf("  weft-version: \"%s\"", as.character(utils::packageVersion("weft"))) %in% fm)
  expect_true("metadata:" %in% fm)
})

test_that("agent_repo_skill: each file is the document agent_docs() prints", {
  d <- ars_gen()
  topics <- c(skill = "skills/weft/SKILL.md", reports = "skills/weft/references/reports.md",
              syntax = "skills/weft/references/syntax.md")
  for (t in names(topics)) {
    printed <- utils::capture.output(weft::agent_docs(t))
    expect_identical(readLines(file.path(d, topics[[t]]), warn = FALSE), printed, label = t)
  }
})

test_that("the committed skills/weft/ is what the generator writes now", {
  root <- ars_root()
  skip_if(is.null(root), "the source tree is not available")
  skip_if_not(dir.exists(file.path(root, "skills")), "skills/ is not in this tree")
  d <- ars_gen()
  for (f in ars_files) {
    expect_true(file.exists(file.path(root, f)), label = f)
    expect_identical(ars_read(file.path(root, f)), ars_read(file.path(d, f)), label = f)
  }
  expect_setequal(list.files(file.path(root, "skills"), recursive = TRUE, all.files = TRUE, no.. = TRUE),
                  sub("^skills/", "", ars_files))
})

test_that("the Claude Code manifests are valid JSON, at the package version, with plugin name weft", {
  root <- ars_root()
  skip_if(is.null(root), "the source tree is not available")
  skip_if_not(dir.exists(file.path(root, ".claude-plugin")), ".claude-plugin/ is not in this tree")
  v <- as.character(utils::packageVersion("weft"))
  plugin <- ars_json_version(file.path(root, ".claude-plugin", "plugin.json"))
  market <- ars_json_version(file.path(root, ".claude-plugin", "marketplace.json"))
  expect_identical(plugin$name, "weft")
  expect_identical(plugin$version, v)
  expect_length(market$plugins, 1L)
  expect_identical(market$plugins[[1L]]$name, "weft")
  expect_identical(market$plugins[[1L]]$version, v)
  expect_identical(market$plugins[[1L]]$source, "./")
  expect_identical(market$owner$name, "vorpalvorpal")
})
