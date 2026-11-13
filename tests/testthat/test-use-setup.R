# 4d: use_setup() (G35, G36, G41, H29, H30, G32), what it writes into a
# project, what it says, what it returns, when it refuses. No render here
# (test-activation-cli.R renders); the Rmd specifics are in test-use-setup-rmd.R.
#
# WHAT STAYS UNTESTED (design-4.md G37, "Not tested"):
#   - the Render and Knit buttons of RStudio and Positron (RStudio's Knit
#     starts R in the document's folder, which may not hold the .Rprofile);
#   - chunks run interactively, and the inline preview;
#   - a real renv library (a stub renv/activate.R stands in);
#   - Windows (symbolic-link cases skip there).

qproj <- function(files = list()) u4_dir(c(list(`_quarto.yml` = U4_QUARTO_YML), files))

# ---- the .Rprofile (G36) ----------------------------------------------------

test_that("4d G36: a Quarto project with no .Rprofile gets exactly the four lines", {
  dir <- qproj(list(`index.qmd` = u4_qmd()))
  u4_use(dir)
  expect_identical(u4_read(dir, ".Rprofile"), U4_RPROFILE)
})

test_that("4d G35: a Quarto project writes the .Rprofile route, not front-matter lines", {
  dir <- qproj(list(`index.qmd` = u4_qmd()))
  u4_use(dir)
  expect_false(any(grepl("weft_setup", u4_read(dir, "index.qmd"), fixed = TRUE)))
  expect_false(any(grepl("opts_knit", u4_read(dir, "index.qmd"), fixed = TRUE)))
})

test_that("4d G36: an existing .Rprofile keeps the author's lines; the comment and the activation line are appended", {
  orig <- c("options(digits = 4)", "x <- 1")
  dir <- qproj(list(.Rprofile = orig))
  u4_use(dir)
  now <- u4_read(dir, ".Rprofile")
  expect_identical(now[seq_along(orig)], orig)
  tail <- now[-seq_along(orig)]
  tail <- tail[nzchar(trimws(tail))]
  expect_identical(tail, c(U4_RPROFILE[1], U4_RPROFILE[4]))
  # H30: the author's own file is already what R reads, so ~/.Rprofile is not sourced again
  expect_false(any(grepl("source(\"~/.Rprofile\")", now, fixed = TRUE)))
})

test_that("4d G36: with a renv line already there, weft's lines come after it", {
  orig <- c("source(\"renv/activate.R\")")
  dir <- qproj(list(.Rprofile = orig))
  u4_use(dir)
  now <- u4_read(dir, ".Rprofile")
  expect_identical(now[1], orig)
  expect_true(which(now == U4_ACTIVATE) > 1L)
  expect_identical(sum(now == U4_ACTIVATE), 1L)
})

test_that("4d G36: with renv's lines in the middle and later lines of the author's, weft's lines go after the last line", {
  orig <- c("source(\"renv/activate.R\")", "options(warn = 1)", "# the end")
  dir <- qproj(list(.Rprofile = orig))
  u4_use(dir)
  now <- u4_read(dir, ".Rprofile")
  expect_identical(now[seq_along(orig)], orig)
  expect_identical(now[length(now)], U4_ACTIVATE)
})

test_that("4d G36: an .Rprofile that already has an uncommented weft_setup() line is kept, byte for byte", {
  orig <- c("source(\"renv/activate.R\")",
            "if (requireNamespace(\"weft\", quietly = TRUE)) weft::weft_setup()",
            "options(warn = 1)")
  dir <- qproj(list(.Rprofile = orig))
  before <- u4_md5(dir)[".Rprofile"]
  u4_use(dir)
  expect_identical(u4_md5(dir)[".Rprofile"], before)
  expect_identical(u4_read(dir, ".Rprofile"), orig)
})

test_that("4d G36: a commented-out weft_setup() line does not count; the line is appended", {
  orig <- c("# weft::weft_setup()", "x <- 1")
  dir <- qproj(list(.Rprofile = orig))
  u4_use(dir)
  now <- u4_read(dir, ".Rprofile")
  expect_identical(now[seq_along(orig)], orig)
  expect_identical(now[length(now)], U4_ACTIVATE)
})

test_that("4d G36: an .Rprofile with no final newline still keeps its last line whole", {
  dir <- qproj()
  writeLines("x <- 1", file.path(dir, ".Rprofile"), sep = "")
  u4_use(dir)
  now <- u4_read(dir, ".Rprofile")
  expect_identical(now[1], "x <- 1")
  expect_identical(now[length(now)], U4_ACTIVATE)
})

# ---- routes (G35) -----------------------------------------------------------

test_that("4d G35: route auto is rprofile in a Quarto project and front-matter without one", {
  q <- qproj(list(`a.qmd` = u4_qmd()))
  u4_use(q)
  expect_true(file.exists(file.path(q, ".Rprofile")))

  d <- u4_dir(list(`a.qmd` = u4_qmd()))
  u4_use(d)
  expect_false(file.exists(file.path(d, ".Rprofile")))
  expect_true(u4_has_run(u4_front(file.path(d, "a.qmd")), U4_OPTS_KNIT))
})

test_that("4d G35: a folder inside a Quarto project is set up at the project root (found upwards)", {
  q <- qproj(list(`chapters/one.qmd` = u4_qmd()))
  u4_use(file.path(q, "chapters"))
  expect_true(file.exists(file.path(q, ".Rprofile")))
  expect_false(file.exists(file.path(q, "chapters", ".Rprofile")))
  expect_true(file.exists(file.path(q, "_weft.yml")))
})

test_that("4d G35: route = 'front-matter' in a Quarto project writes the front-matter lines in each .qmd and no .Rprofile", {
  q <- qproj(list(`index.qmd` = u4_qmd(), `chapters/one.qmd` = u4_qmd()))
  u4_use(q, route = "front-matter")
  expect_false(file.exists(file.path(q, ".Rprofile")))
  for (f in c("index.qmd", "chapters/one.qmd")) {
    expect_true(u4_has_run(u4_front(file.path(q, f)), U4_OPTS_KNIT), label = f)
  }
})

test_that("4d G35: route = 'rprofile' outside a Quarto project writes the .Rprofile in the folder", {
  d <- u4_dir(list(`a.qmd` = u4_qmd()))
  u4_use(d, route = "rprofile")
  expect_identical(u4_read(d, ".Rprofile"), U4_RPROFILE)
  expect_false(any(grepl("opts_knit", u4_read(d, "a.qmd"), fixed = TRUE)))
})

test_that("4d G35: an unknown route is an error and nothing is written", {
  d <- u4_dir(list(`a.qmd` = u4_qmd()))
  before <- u4_md5(d)
  expect_error(suppressMessages(weft::use_setup(d, route = "bogus")), "should be one of|route")
  expect_identical(u4_md5(d), before)
})

# ---- the front-matter route in a .qmd (G35, 9.2.1, 9.2.8) --------------------

test_that("4d G35: the front-matter route writes the three lines under `knitr:`, keeps the rest, and the front matter still parses", {
  d <- u4_dir(list(`a.qmd` = c("---", "title: \"Survey results\"", "format:", "  html:", "    toc: true",
                               "---", "", "Some text.")))
  u4_use(d)
  f <- file.path(d, "a.qmd")
  expect_true(u4_has_run(u4_front(f), U4_OPTS_KNIT))
  y <- u4_yaml(f)
  expect_identical(y$title, "Survey results")
  expect_true(y$format$html$toc)
  expect_identical(y$knitr$opts_knit$weft, "!expr weft::weft_setup()")
  expect_identical(y$engine, "knitr")
  # the body is untouched
  expect_identical(tail(u4_read(d, "a.qmd"), 2L), c("", "Some text."))
})

test_that("4d G35: an existing `knitr:` key with other settings gains opts_knit / weft and keeps them", {
  d <- u4_dir(list(
    `a.qmd` = c("---", "title: a", "knitr:", "  opts_chunk:", "    echo: false", "---", "", "x"),
    `b.qmd` = c("---", "title: b", "knitr:", "  opts_knit:", "    root.dir: \"..\"", "---", "", "x")
  ))
  u4_use(d)
  ya <- u4_yaml(file.path(d, "a.qmd"))
  expect_false(ya$knitr$opts_chunk$echo)
  expect_identical(ya$knitr$opts_knit$weft, "!expr weft::weft_setup()")
  yb <- u4_yaml(file.path(d, "b.qmd"))
  expect_identical(yb$knitr$opts_knit$root.dir, "..")
  expect_identical(yb$knitr$opts_knit$weft, "!expr weft::weft_setup()")
})

test_that("4d G35: a document that already has the weft line is left alone (no second line)", {
  d <- u4_dir(list(`a.qmd` = c("---", "title: a", "engine: knitr", U4_OPTS_KNIT, "---", "", "x")))
  before <- u4_md5(d)["a.qmd"]
  u4_use(d)
  expect_identical(u4_md5(d)["a.qmd"], before)
})

# ---- engine: knitr (G35, H29, 9.2.8) ----------------------------------------

engine_files <- function() {
  py <- c("```{python}", "x = 1", "```")
  r <- c("```{r}", "x <- 1", "```")
  list(
    `index.qmd` = c("---", "title: Home", "---", "", "Text."),
    `chapters/one.qmd` = u4_qmd(),
    `both.qmd` = c("---", "title: both", "---", "", py, "", r),
    `has.qmd` = c("---", "title: has", "engine: knitr", "---", "", "Text."),
    `nofm.qmd` = c("Plain text, no front matter.", "", r),
    `jup.qmd` = c("---", "title: j", "engine: jupyter", "---", "", py),
    `jup2.qmd` = c("---", "title: j2", "jupyter: python3", "---", "", py),
    `py.qmd` = c("---", "title: p", "---", "", py),
    `_include.qmd` = c("---", "title: inc", "---", "", "Included text."),
    `_partials/p.qmd` = c("---", "title: part", "---", "", "Partial."),
    `.hidden/h.qmd` = c("---", "title: hid", "---", "", "Hidden.")
  )
}

test_that("4d G35/H29: engine: knitr goes into each .qmd that lacks an engine and is not another engine's", {
  q <- qproj(engine_files())
  before <- u4_md5(q)
  u4_use(q)
  after <- u4_md5(q)
  for (f in c("index.qmd", "chapters/one.qmd", "both.qmd")) {
    expect_identical(u4_yaml(file.path(q, f))$engine, "knitr", label = f)
  }
  # kept, or skipped: byte for byte
  for (f in c("has.qmd", "jup.qmd", "jup2.qmd", "py.qmd", "_include.qmd",
              "_partials/p.qmd", ".hidden/h.qmd")) {
    expect_identical(after[f], before[f], label = paste(f, "is unchanged"))
  }
  # engine: knitr was already there once, and stays once
  expect_identical(sum(grepl("^engine:", u4_read(q, "has.qmd"))), 1L)
})

test_that("4d G35: a .qmd with no front matter gets --- / engine: knitr / --- as its first lines, and its text after", {
  q <- qproj(engine_files())
  orig <- u4_read(q, "nofm.qmd")
  u4_use(q)
  now <- u4_read(q, "nofm.qmd")
  expect_identical(now[1:3], c("---", "engine: knitr", "---"))
  expect_identical(tail(now, length(orig)), orig)
})

test_that("4d G35: engine: knitr is a top-level key of the front matter and the other keys stay", {
  q <- qproj(list(`index.qmd` = c("---", "title: Home", "author: A. Author", "---", "", "Text.")))
  u4_use(q)
  y <- u4_yaml(file.path(q, "index.qmd"))
  expect_identical(y$engine, "knitr")
  expect_identical(y$title, "Home")
  expect_identical(y$author, "A. Author")
})

test_that("4d G35: under the front-matter route the engine line is written too (one line, the same everywhere)", {
  d <- u4_dir(list(`a.qmd` = u4_qmd()))
  u4_use(d)
  expect_identical(sum(grepl("^engine: knitr$", u4_front(file.path(d, "a.qmd")))), 1L)
})

test_that("4d G35: a single .qmd given by path is set up alone; its neighbours are not touched", {
  d <- u4_dir(list(`a.qmd` = u4_qmd(), `b.qmd` = u4_qmd()))
  before <- u4_md5(d)["b.qmd"]
  u4_use(file.path(d, "a.qmd"))
  expect_true(u4_has_run(u4_front(file.path(d, "a.qmd")), U4_OPTS_KNIT))
  expect_identical(u4_md5(d)["b.qmd"], before)
})

# ---- _weft.yml and the version line (G35, G32, H37) --------------------------

test_that("4d G35: a new _weft.yml has the two comment lines and the version line", {
  q <- qproj(list(`index.qmd` = u4_qmd()))
  u4_use(q)
  x <- u4_read(q, "_weft.yml")
  expect_identical(x[1:2], c("# weft settings for this project. Every key has a default;",
                             "# add only what you change."))
  expect_match(x[3], paste0("^weft_version: [\"']?", gsub(".", "\\.", u4_version(), fixed = TRUE), "[\"']?$"))
})

test_that("4d G35/G32: an existing _weft.yml without the line gains it, appended, and keeps its content", {
  q <- qproj(list(`index.qmd` = u4_qmd(), `_weft.yml` = c("digits: 2", "serial_comma: true")))
  u4_use(q)
  x <- u4_read(q, "_weft.yml")
  expect_identical(x[1:2], c("digits: 2", "serial_comma: true"))
  expect_match(x[length(x)], "^weft_version: ")
  expect_identical(sum(grepl("^weft_version:", x)), 1L)
  y <- yaml::read_yaml(file.path(q, "_weft.yml"))
  expect_identical(y$digits, 2L)
  expect_identical(as.character(y$weft_version), u4_version())
})

test_that("4d G32: an existing weft_version line is kept as it is, even when it differs (use_weft() updates it, use_setup() does not)", {
  q <- qproj(list(`index.qmd` = u4_qmd(), `_weft.yml` = c("digits: 2", "weft_version: 0.0.0.1")))
  before <- u4_md5(q)["_weft.yml"]
  u4_use(q)
  expect_identical(u4_md5(q)["_weft.yml"], before)
})

test_that("4d G32: the version use_setup() records is the one recorded_version() reads", {
  q <- qproj(list(`index.qmd` = u4_qmd()))
  u4_use(q)
  expect_identical(weft:::recorded_version(q), u4_version())
})

test_that("4d H37: use_quarto() alone still records no version (use_setup() adds the line)", {
  q <- u4_dir(list(`_quarto.yml` = U4_QUARTO_YML, `index.qmd` = u4_qmd()))
  suppressMessages(utils::capture.output(weft::use_quarto(q)))
  expect_false(any(grepl("^weft_version:", u4_read(q, "_weft.yml"))))
  u4_use(q)
  expect_true(any(grepl("^weft_version:", u4_read(q, "_weft.yml"))))
})

# ---- second run, return value, messages (G35, G41) ---------------------------

test_that("4d G35: a second run changes nothing and says there is nothing to change", {
  q <- qproj(list(`index.qmd` = u4_qmd(), `chapters/one.qmd` = u4_qmd()))
  u4_use(q)
  before <- u4_md5(q)
  says <- u4_says(q)
  expect_identical(u4_md5(q), before)
  expect_match(says, "Nothing to change", fixed = TRUE)
  expect_no_match(says, "Wrote:", fixed = TRUE)
})

test_that("4d G35: a second run on the front-matter route changes nothing either", {
  d <- u4_dir(list(`a.qmd` = u4_qmd(), `b.qmd` = u4_qmd()))
  u4_use(d)
  before <- u4_md5(d)
  says <- u4_says(d)
  expect_identical(u4_md5(d), before)
  expect_match(says, "Nothing to change", fixed = TRUE)
})

test_that("4d G41: the message names the root, then one line per file, then the files written", {
  q <- qproj(list(`index.qmd` = u4_qmd()))
  says <- u4_says(q)
  expect_match(says, "weft will write, under ", fixed = TRUE)
  expect_match(says, basename(q), fixed = TRUE)
  # one line per file: two spaces, the file, two spaces, (state: purpose)
  expect_match(says, "(^|\n)  \\.Rprofile  \\(new: [^)]+\\)")
  expect_match(says, "(^|\n)  _weft\\.yml  \\(new: [^)]+\\)")
  expect_match(says, "(^|\n)  index\\.qmd  \\([a-z]+: [^)]+\\)")
  m <- regmatches(says, regexpr("Wrote: [^\n]*", says))
  expect_length(m, 1L)
  for (f in c(".Rprofile", "_weft.yml", "index.qmd")) expect_match(m, f, fixed = TRUE)
})

test_that("4d G41: it says what it will write before it writes anything", {
  q <- qproj(list(`index.qmd` = u4_qmd()))
  early <- NULL
  u4_says(q, hook = function() {
    early <<- file.exists(file.path(q, ".Rprofile")) || file.exists(file.path(q, "_weft.yml"))
  })
  expect_false(early)
})

test_that("4d G41: it is silent under suppressMessages()", {
  q <- qproj(list(`index.qmd` = u4_qmd()))
  out <- utils::capture.output(suppressMessages(weft::use_setup(q)))
  expect_identical(out, character())
})

test_that("4d G41: it returns the paths it wrote, invisibly; nothing on a second run", {
  q <- qproj(list(`index.qmd` = u4_qmd()))
  expect_invisible(suppressMessages(weft::use_setup(q)))
  q2 <- qproj(list(`index.qmd` = u4_qmd()))
  res <- u4_use(q2)
  expect_type(res, "character")
  expect_setequal(u4_rel(res, q2), c(".Rprofile", "_weft.yml", "index.qmd"))
  res2 <- u4_use(q2)
  expect_length(res2, 0L)
})

test_that("4d G35: a front-matter project returns the documents and _weft.yml (and no .Rprofile)", {
  d <- u4_dir(list(`a.qmd` = u4_qmd()))
  res <- u4_use(d)
  expect_setequal(u4_rel(res, d), c("a.qmd", "_weft.yml"))
})

# ---- nothing is written but where the contract says --------------------------

test_that("4d G3: nothing is written outside the project (neighbours, parent, HOME, cache)", {
  base <- u4_dir(list(`sibling.txt` = "stay", `other/x.qmd` = u4_qmd()))
  proj <- u4_dir(c(list(`_quarto.yml` = U4_QUARTO_YML, `index.qmd` = u4_qmd(),
                        `chapters/one.qmd` = u4_qmd())),
                 base = file.path(base, "proj"))
  home <- u4_home()
  cache <- tempfile("weft-4d-cache-"); dir.create(cache)
  withr::local_envvar(c(HOME = home, R_USER_CACHE_DIR = cache))
  outside <- function() list(base = u4_md5(base)[!startsWith(names(u4_md5(base)), "proj/")],
                             home = tree(home), cache = tree(cache))
  before <- outside()
  u4_use(proj)
  expect_identical(outside(), before)
  expect_true(file.exists(file.path(proj, ".Rprofile")))
})

# ---- refusals: weft_tool_error, and nothing written --------------------------

expect_refused <- function(dir, ..., pattern = NULL) {
  before <- u4_md5(dir)
  err <- tryCatch(suppressMessages(weft::use_setup(dir, ...)), error = function(e) e)
  expect_s3_class(err, "weft_tool_error")
  expect_s3_class(err, "weft_error")
  expect_identical(u4_md5(dir), before, label = "nothing was written")
  if (!is.null(pattern)) expect_match(conditionMessage(err), pattern, fixed = TRUE)
  invisible(err)
}

test_that("4d G41: a symbolic link in the .Rprofile's place is a weft_tool_error naming the path, and nothing is written", {
  skip_on_os("windows")
  q <- qproj(list(`index.qmd` = u4_qmd()))
  target <- tempfile("weft-4d-target-"); writeLines("x <- 1", target)
  file.symlink(target, file.path(q, ".Rprofile"))
  before_target <- unname(tools::md5sum(target))
  err <- tryCatch(suppressMessages(weft::use_setup(q)), error = function(e) e)
  expect_s3_class(err, "weft_tool_error")
  expect_match(conditionMessage(err), ".Rprofile", fixed = TRUE)
  expect_identical(unname(tools::md5sum(target)), before_target)
  expect_false(file.exists(file.path(q, "_weft.yml")))
  expect_identical(u4_read(q, "index.qmd"), u4_qmd())
})

test_that("4d G41: a folder in the place of _weft.yml is a weft_tool_error naming the path, and nothing is written", {
  q <- qproj(list(`index.qmd` = u4_qmd(), `_weft.yml/keep.txt` = "x"))
  expect_refused(q, pattern = "_weft.yml")
  expect_false(file.exists(file.path(q, ".Rprofile")))
})

test_that("4d G35: an unsafe front-matter edit (flow style) writes nothing at all and prints the lines to add by hand", {
  d <- u4_dir(list(
    `ok.qmd` = u4_qmd(),
    `flow.qmd` = c("---", "title: f", "knitr: {opts_chunk: {echo: false}}", "---", "", "x")
  ))
  err <- expect_refused(d)
  # the lines to add by hand are in the message
  expect_match(conditionMessage(err), "weft: !expr weft::weft_setup()", fixed = TRUE)
  expect_false(file.exists(file.path(d, "_weft.yml")))
})

test_that("4d G35: an existing `weft:` under opts_knit with another value writes nothing at all", {
  d <- u4_dir(list(
    `ok.qmd` = u4_qmd(),
    `other.qmd` = c("---", "title: o", "knitr:", "  opts_knit:", "    weft: !expr other::activate()",
                    "---", "", "x")
  ))
  err <- expect_refused(d)
  expect_match(conditionMessage(err), "weft::weft_setup()", fixed = TRUE)
})

test_that("4d G35: a front matter with an anchor writes nothing at all", {
  d <- u4_dir(list(
    `anch.qmd` = c("---", "title: &t Anchored", "subtitle: *t", "---", "", "x")
  ))
  expect_refused(d)
})

test_that("4d G35 (assumed): a path that does not exist, or a file of another kind, is a weft_tool_error", {
  d <- u4_dir(list(`notes.txt` = "x"))
  expect_error(suppressMessages(weft::use_setup(file.path(d, "missing"))), class = "weft_tool_error")
  expect_error(suppressMessages(weft::use_setup(file.path(d, "notes.txt"))), class = "weft_tool_error")
  expect_identical(tree(d), "notes.txt")
})
