# use_quarto() (9.3.1, design note "The Quarto side"). No render here: this
# file only looks at what the function says and writes.

project_yml <- function(extra = NULL) {
  c("project:", "  type: default", extra, "format: html")
}

# what use_quarto() says: messages and printed output, in order
use_quarto_says <- function(dir, first_message_hook = NULL) {
  txt <- character()
  out <- utils::capture.output(
    withCallingHandlers(
      weft::use_quarto(dir),
      message = function(m) {
        if (!is.null(first_message_hook) && !length(txt)) first_message_hook()
        txt <<- c(txt, conditionMessage(m))
        invokeRestart("muffleMessage")
      }
    )
  )
  paste(c(txt, out), collapse = "\n")
}

written_files <- c(
  "_extensions/weft-check/_extension.yml",
  "_extensions/weft-check/weft-check.lua",
  "_weft/pre-render.R",
  "_weft/post-render.R",
  "_weft.yml"
)

fresh_project <- function(yml = project_yml()) {
  dir <- tempfile("weft-uq-")
  dir.create(dir)
  dir <- normalizePath(dir)
  writeLines(yml, file.path(dir, "_quarto.yml"))
  writeLines(c("---", "title: Home", "---", "", "Some text."), file.path(dir, "index.qmd"))
  dir
}

as_chr <- function(x) as.character(unlist(x))

test_that("9.3.1: use_quarto() writes exactly the files the design note lists", {
  dir <- fresh_project()
  before <- tree(dir)
  suppressMessages(utils::capture.output(weft::use_quarto(dir)))
  added <- setdiff(tree(dir), before)
  expect_setequal(added, written_files)
  # nothing that was there has gone
  expect_true(all(before %in% tree(dir)))
  for (f in written_files) {
    expect_true(file.size(file.path(dir, f)) > 0, label = paste(f, "is not empty"))
  }
})

test_that("9.3.1: use_quarto() says what it will write, before it writes", {
  dir <- fresh_project()
  early <- NULL
  says <- use_quarto_says(dir, first_message_hook = function() {
    early <<- file.exists(file.path(dir, "_weft")) ||
      file.exists(file.path(dir, "_extensions"))
  })
  expect_false(early, label = "something was already written at the first message")
  expect_match(says, "weft-check")
  expect_match(says, "pre-render")
  expect_match(says, "post-render")
  expect_match(says, "_weft.yml", fixed = TRUE)
  expect_match(says, "_quarto.yml", fixed = TRUE)
})

test_that("design note: the filter is installed as a project extension, and the shipped filter is the one written", {
  dir <- fresh_project()
  suppressMessages(utils::capture.output(weft::use_quarto(dir)))
  ext <- yaml::read_yaml(file.path(dir, "_extensions/weft-check/_extension.yml"))
  expect_false(is.null(ext))
  # an extension that contributes a filter (Quarto's own requirement)
  expect_true(!is.null(ext$contributes$filters) || !is.null(ext$contributes))
  shipped <- weft_filter_path()
  expect_identical(unname(tools::md5sum(file.path(dir, "_extensions/weft-check/weft-check.lua"))),
                   unname(tools::md5sum(shipped)))
})

test_that("design note: _quarto.yml names the filter and the two scripts", {
  dir <- fresh_project()
  suppressMessages(utils::capture.output(weft::use_quarto(dir)))
  y <- yaml::read_yaml(file.path(dir, "_quarto.yml"))
  expect_true("weft-check" %in% as_chr(y$filters))
  expect_true(any(grepl("_weft/pre-render.R", as_chr(y$project$`pre-render`), fixed = TRUE)))
  expect_true(any(grepl("_weft/post-render.R", as_chr(y$project$`post-render`), fixed = TRUE)))
  # the scripts it names are the ones it wrote
  expect_true(file.exists(file.path(dir, "_weft/pre-render.R")))
  expect_true(file.exists(file.path(dir, "_weft/post-render.R")))
})

test_that("design note: _quarto.yml keeps what was there (scalars, lists, other keys)", {
  yml <- c(
    "project:",
    "  type: book",
    "  output-dir: out",
    "  pre-render: tools/mine.sh",
    "  post-render:",
    "    - tools/after-1.sh",
    "    - tools/after-2.sh",
    "filters:",
    "  - other.lua",
    "book:",
    "  title: \"Mine\"",
    "  chapters:",
    "    - index.qmd",
    "format:",
    "  html:",
    "    toc: true",
    "execute:",
    "  freeze: auto"
  )
  dir <- fresh_project(yml)
  suppressMessages(utils::capture.output(weft::use_quarto(dir)))
  y <- yaml::read_yaml(file.path(dir, "_quarto.yml"))
  expect_identical(y$project$type, "book")
  expect_identical(y$project$`output-dir`, "out")
  expect_true("tools/mine.sh" %in% as_chr(y$project$`pre-render`))
  expect_true(any(grepl("_weft/pre-render.R", as_chr(y$project$`pre-render`), fixed = TRUE)))
  expect_true(all(c("tools/after-1.sh", "tools/after-2.sh") %in% as_chr(y$project$`post-render`)))
  expect_true(any(grepl("_weft/post-render.R", as_chr(y$project$`post-render`), fixed = TRUE)))
  expect_true(all(c("other.lua", "weft-check") %in% as_chr(y$filters)))
  expect_identical(y$book$title, "Mine")
  expect_identical(as_chr(y$book$chapters), "index.qmd")
  expect_true(isTRUE(y$format$html$toc))
  expect_identical(y$execute$freeze, "auto")
})

test_that("9.3.1: use_quarto() is idempotent", {
  dir <- fresh_project(project_yml(c("  pre-render: tools/mine.sh")))
  suppressMessages(utils::capture.output(weft::use_quarto(dir)))
  tree1 <- tree(dir)
  sums1 <- tools::md5sum(file.path(dir, tree1))
  yml1 <- readLines(file.path(dir, "_quarto.yml"))
  suppressMessages(utils::capture.output(weft::use_quarto(dir)))
  suppressMessages(utils::capture.output(weft::use_quarto(dir)))
  expect_identical(tree(dir), tree1)
  expect_identical(unname(tools::md5sum(file.path(dir, tree1))), unname(sums1))
  expect_identical(readLines(file.path(dir, "_quarto.yml")), yml1)
  y <- yaml::read_yaml(file.path(dir, "_quarto.yml"))
  expect_identical(sum(as_chr(y$filters) == "weft-check"), 1L)
  expect_identical(sum(grepl("_weft/pre-render.R", as_chr(y$project$`pre-render`), fixed = TRUE)), 1L)
  expect_identical(sum(grepl("_weft/post-render.R", as_chr(y$project$`post-render`), fixed = TRUE)), 1L)
  expect_identical(sum(as_chr(y$project$`pre-render`) == "tools/mine.sh"), 1L)
})

test_that("9.3.1: _weft.yml is created when absent, empty but for a comment", {
  dir <- fresh_project()
  expect_false(file.exists(file.path(dir, "_weft.yml")))
  suppressMessages(utils::capture.output(weft::use_quarto(dir)))
  expect_true(file.exists(file.path(dir, "_weft.yml")))
  lines <- trimws(readLines(file.path(dir, "_weft.yml"), warn = FALSE))
  lines <- lines[nzchar(lines)]
  expect_gte(length(lines), 1L)
  expect_true(all(startsWith(lines, "#")), label = "every non-blank line is a comment")
  parsed <- yaml::read_yaml(file.path(dir, "_weft.yml"))
  expect_true(is.null(parsed) || length(parsed) == 0L)
})

test_that("9.3.1: an existing _weft.yml is left as it is", {
  dir <- fresh_project()
  mine <- c("# my settings", "digits: 2", "draft: false")
  writeLines(mine, file.path(dir, "_weft.yml"))
  suppressMessages(utils::capture.output(weft::use_quarto(dir)))
  expect_identical(readLines(file.path(dir, "_weft.yml")), mine)
  # and the rest was still written
  expect_true(all(setdiff(written_files, "_weft.yml") %in% tree(dir)))
})

test_that("9.3.2: use_quarto() writes no failure file, stamp or ledger of its own", {
  dir <- fresh_project()
  suppressMessages(utils::capture.output(weft::use_quarto(dir)))
  expect_false(dir.exists(file.path(dir, ".weft")))
})

test_that("9.3.1: the post-render and pre-render scripts are R scripts that parse", {
  dir <- fresh_project()
  suppressMessages(utils::capture.output(weft::use_quarto(dir)))
  for (f in c("_weft/pre-render.R", "_weft/post-render.R")) {
    expect_no_error(parse(file.path(dir, f)))
  }
})
