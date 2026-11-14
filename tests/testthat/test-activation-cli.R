# 4d: activation from the command line (G37), each in a FRESH process started
# in a temporary project, so R reads the project's own .Rprofile. See
# helper-4d.R for how a child is isolated (HOME in a temp folder, R_PROFILE_USER
# unset, R_LIBS on the test library, R_USER_CACHE_DIR in a temp folder).
#
# WHAT STAYS UNTESTED (design-4.md G37): the Render and Knit buttons of RStudio
# and Positron; chunks run interactively and the inline preview; a real renv
# library (a stub renv/activate.R stands in); Windows. Also 9.2.3: there is no
# project-wide route under rmarkdown, so the .Rprofile reaching an .Rmd is
# checked only because it works when R is started in the project root.

skip_on_cran()

WEFT_ON <- "cat('FUNCS=', 'weft:functions' %in% search(), sep = '')"
funcs_on <- function(r) grepl("FUNCS=TRUE", r$out, fixed = TRUE)
funcs_off <- function(r) grepl("FUNCS=FALSE", r$out, fixed = TRUE)

qproj_set_up <- function(files = list(), ...) {
  q <- u4_quarto_project(files)
  u4_use(q, ...)
  q
}

# an .Rmd project activated by the .Rprofile alone: the exact G36 file by
# hand, the filter beside the document and named in pandoc_args, and no
# weft line anywhere in the document
rmd_rprofile_only <- function(body = U4_BODY, profile = U4_RPROFILE) {
  d <- u4_dir(list(
    .Rprofile = profile,
    `doc.Rmd` = u4_rmd(c("title: \"t\"", "output:", "  md_document:", "    variant: markdown",
                         paste0("    ", U4_FILTER_ARGS)), body)
  ))
  copy_filters(d)
  d
}

# 6d: the filters beside a document: weft-check.lua, weft-output.lua (7d, N50), and the resolver weft.lua with its weftlib/ (as use_setup()
# copies them; a file the package does not ship yet is not copied)
copy_filters <- function(d) {
  src <- dirname(weft_filter_path())
  for (f in c("weft-check.lua", "weft-output.lua", "weft.lua")) {
    if (file.exists(file.path(src, f))) file.copy(file.path(src, f), file.path(d, f), overwrite = TRUE)
  }
  if (dir.exists(file.path(src, "weftlib"))) file.copy(file.path(src, "weftlib"), d, recursive = TRUE)
}

# ---- the .Rprofile puts weft on the search path ------------------------------

test_that("4d G37: a fresh R started in a project set up by use_setup() has weft:functions on the search path", {
  q <- qproj_set_up(list(`index.qmd` = u4_qmd()))
  r <- u4_r(q, WEFT_ON)
  expect_identical(r$status, 0L, info = r$out)
  expect_true(funcs_on(r), info = r$out)
})

test_that("4d G37 (control): the same project without the .Rprofile lines is not activated", {
  q <- u4_quarto_project(list(`index.qmd` = u4_qmd(engine = TRUE)))
  expect_false(file.exists(file.path(q, ".Rprofile")))
  r <- u4_r(q, WEFT_ON)
  expect_identical(r$status, 0L, info = r$out)
  expect_true(funcs_off(r), info = r$out)
})

test_that("4d G37 (control): an .Rprofile with other content does not activate weft", {
  q <- u4_dir(list(.Rprofile = "options(digits = 4)"))
  r <- u4_r(q, WEFT_ON)
  expect_true(funcs_off(r), info = r$out)
})

test_that("4d G36: with weft not in the library R still starts (the requireNamespace() guard) and nothing is activated", {
  skip_if(is.null(u4_libs_without_weft()), "cannot build a library path without weft here")
  q <- qproj_set_up(list(`index.qmd` = u4_qmd()))
  r <- u4_r(q, WEFT_ON, u4_env(u4_home(), with_weft = FALSE))
  expect_identical(r$status, 0L, info = r$out)
  expect_true(funcs_off(r), info = r$out)
})

test_that("4d G36: an .Rprofile that sources a stub renv/activate.R first still activates (weft is found in renv's library)", {
  skip_if(is.null(u4_libs_without_weft()), "cannot build a library path without weft here")
  d <- u4_dir(list(
    `_quarto.yml` = U4_QUARTO_YML,
    `index.qmd` = u4_qmd(),
    .Rprofile = "source(\"renv/activate.R\")",
    # the stub is the only way to the library that holds weft
    `renv/activate.R` = c("options(weft_stub_renv = TRUE)",
                          ".libPaths(c(Sys.getenv(\"WEFT_STUB_LIB\"), .libPaths()))")
  ))
  u4_use(d)
  now <- u4_read(d, ".Rprofile")
  expect_identical(now[1], "source(\"renv/activate.R\")")
  env <- u4_env(u4_home(), with_weft = FALSE, extra = c(WEFT_STUB_LIB = weft_test_lib()))
  r <- u4_r(d, paste0("cat('STUB=', isTRUE(getOption('weft_stub_renv')), ' ', sep = ''); ", WEFT_ON), env)
  expect_identical(r$status, 0L, info = r$out)
  expect_match(r$out, "STUB=TRUE", fixed = TRUE)
  expect_true(funcs_on(r), info = r$out)
})

test_that("4d H30/F5: the new project .Rprofile sources the author's ~/.Rprofile, so their own setup still runs", {
  d <- qproj_set_up(list(`index.qmd` = u4_qmd()))
  home <- u4_home(profile = "options(weft_home_marker = 'from-home')")
  r <- u4_r(d, paste0("cat('HOME=', getOption('weft_home_marker', 'none'), ' ', sep = ''); ", WEFT_ON),
            u4_env(home))
  expect_identical(r$status, 0L, info = r$out)
  expect_match(r$out, "HOME=from-home", fixed = TRUE)
  expect_true(funcs_on(r), info = r$out)
})

test_that("4d H30/F5: with no ~/.Rprofile the sourcing line is harmless", {
  d <- qproj_set_up(list(`index.qmd` = u4_qmd()))
  r <- u4_r(d, WEFT_ON, u4_env(u4_home()))
  expect_identical(r$status, 0L, info = r$out)
  expect_true(funcs_on(r), info = r$out)
})

test_that("4d G36: an author's existing .Rprofile keeps working after use_setup() appended to it", {
  d <- u4_dir(list(`_quarto.yml` = U4_QUARTO_YML, `index.qmd` = u4_qmd(),
                   .Rprofile = "options(weft_author_marker = 'mine')"))
  u4_use(d)
  r <- u4_r(d, paste0("cat('AUTHOR=', getOption('weft_author_marker', 'none'), ' ', sep = ''); ", WEFT_ON))
  expect_match(r$out, "AUTHOR=mine", fixed = TRUE)
  expect_true(funcs_on(r), info = r$out)
})

# ---- rmarkdown::render() in a fresh process ----------------------------------

test_that("4d G37: Rscript -e rmarkdown::render() resolves an .Rmd activated only by the .Rprofile", {
  d <- rmd_rprofile_only()
  r <- u4_render_rmd(d)
  expect_false(r$failed, info = r$log)
  expect_match(r$md, "Depth is 12.5 here.", fixed = TRUE)
  expect_match(r$md, "one site", fixed = TRUE)
  expect_no_match(r$md, "{.num}", fixed = TRUE)
  expect_no_match(r$md, "<<weft:", fixed = TRUE)
})

test_that("4d G37: the same through use_setup(route = 'rprofile'): its .Rprofile activates the document, with no weft_setup() call in it", {
  d <- u4_dir(list(`doc.Rmd` = u4_rmd()))
  u4_use(d, route = "rprofile")
  # make sure the filter is there under either reading of the .Rmd edits
  if (!file.exists(file.path(d, "weft-check.lua"))) copy_filters(d)
  r <- u4_render_rmd(d)
  expect_false(r$failed, info = r$log)
  expect_match(r$md, "Depth is 12.5 here.", fixed = TRUE)
  expect_no_match(r$md, "{.num}", fixed = TRUE)
})

test_that("4d G37: an .Rmd activated by its front matter (use_setup() on the folder, no .Rprofile) resolves", {
  d <- u4_dir(list(`doc.Rmd` = u4_rmd()))
  u4_use(d)
  expect_false(file.exists(file.path(d, ".Rprofile")))
  r <- u4_render_rmd(d)
  expect_false(r$failed, info = r$log)
  expect_match(r$md, "Depth is 12.5 here.", fixed = TRUE)
  expect_match(r$md, "Found one site here.", fixed = TRUE)
  expect_no_match(r$md, "{.num}", fixed = TRUE)
})

test_that("4d G37: the filter line fails a render of an .Rmd with constructs when weft is not in the library, and a plain .Rmd still renders", {
  skip_if(is.null(u4_libs_without_weft()), "cannot build a library path without weft here")
  env <- u4_env(u4_home(), with_weft = FALSE)
  d <- rmd_rprofile_only()
  r <- u4_render_rmd(d, env = env)
  expect_true(r$failed, info = r$log)
  expect_identical(r$md, "")
  plain <- rmd_rprofile_only(body = c("Plain text with `code` and a [link](https://example.org)."))
  r2 <- u4_render_rmd(plain, env = env)
  expect_false(r2$failed, info = r2$log)
  expect_match(r2$md, "Plain text", fixed = TRUE)
})

test_that("4d G37 (control): the filter alone, with no .Rprofile and no front-matter line, stops a document with constructs", {
  d <- rmd_rprofile_only(profile = "options(digits = 7)")
  r <- u4_render_rmd(d)
  expect_true(r$failed, info = r$log)
  expect_identical(r$md, "")
})

test_that("4d G37 (control): a project without the lines, and no filter, renders and leaves the construct unresolved", {
  d <- u4_dir(list(`doc.Rmd` = u4_rmd()))
  r <- u4_render_rmd(d)
  expect_false(r$failed, info = r$log)
  expect_match(r$md, "{.num}", fixed = TRUE)
})

# ---- a failing claim() stops the render; draft mode leaves the marker --------

test_that("4d G37: with weft active from the .Rprofile alone, a failing claim() stops the render", {
  d <- rmd_rprofile_only(body = c(U4_BODY, U4_CLAIM_FAIL))
  r <- u4_render_rmd(d)
  expect_true(r$failed, info = r$log)
  expect_identical(r$md, "")
  expect_match(r$log, "claim", ignore.case = TRUE)
})

test_that("4d G37: the same under draft mode (WEFT_DRAFT=1) renders and leaves the marker once, in place", {
  d <- rmd_rprofile_only(body = c(U4_BODY, U4_CLAIM_FAIL))
  r <- u4_render_rmd(d, env = u4_env(u4_home(), extra = c(WEFT_DRAFT = "1")))
  expect_false(r$failed, info = r$log)
  expect_identical(u4_n("<<weft: failed claim", r$md), 1L)
  expect_match(r$md, "The value 1<<weft: failed claim, line [0-9]+>> is claimed.")
  expect_match(r$md, "Depth is 12.5 here.", fixed = TRUE)
})

test_that("4d G37: a failing claim() stops a front-matter-activated .Rmd too", {
  d <- u4_dir(list(`doc.Rmd` = u4_rmd(body = c(U4_BODY, U4_CLAIM_FAIL))))
  u4_use(d)
  r <- u4_render_rmd(d)
  expect_true(r$failed, info = r$log)
  expect_identical(r$md, "")
})

# ---- not set up twice --------------------------------------------------------

test_that("4d G37: a document that also calls weft_setup() in a chunk is not set up twice (.Rprofile and chunk)", {
  body <- c("```{r setup, include=FALSE}", "weft::weft_setup()", "depth <- 12.5", "k <- 1", "```", "",
            "Depth is `r depth`{.num} here.", "", "Found [one site | # sites]{n=\"k\"} here.", U4_CLAIM_FAIL)
  d <- rmd_rprofile_only(body = body)
  r <- u4_render_rmd(d, env = u4_env(u4_home(), extra = c(WEFT_DRAFT = "1")))
  expect_false(r$failed, info = r$log)
  expect_match(r$md, "Depth is 12.5 here.", fixed = TRUE)
  expect_match(r$md, "Found one site here.", fixed = TRUE)
  expect_identical(u4_n("<<weft: failed claim", r$md), 1L)
})

test_that("4d G37: .Rprofile and front matter together do not set up twice", {
  d <- rmd_rprofile_only(body = c(U4_BODY, U4_CLAIM_FAIL))
  front <- c("title: \"t\"", "output:", "  md_document:", "    variant: markdown",
             paste0("    ", U4_FILTER_ARGS), U4_OPTS_KNIT)
  writeLines(u4_rmd(front, c(U4_BODY, U4_CLAIM_FAIL)), file.path(d, "doc.Rmd"))
  r <- u4_render_rmd(d, env = u4_env(u4_home(), extra = c(WEFT_DRAFT = "1")))
  expect_false(r$failed, info = r$log)
  expect_identical(u4_n("<<weft: failed claim", r$md), 1L)
  expect_match(r$md, "Depth is 12.5 here.", fixed = TRUE)
})

# ---- quarto render -----------------------------------------------------------

q_files <- function(engine = FALSE) {
  list(
    `index.qmd` = u4_qmd(title = "Home", engine = engine),
    `chapters/two.qmd` = u4_qmd(title = "Two", engine = engine),
    `bad.qmd` = u4_qmd(c(U4_BODY, U4_CLAIM_FAIL), title = "Bad", engine = engine)
  )
}

q_state <- new.env()
q_set_up <- function() {
  if (is.null(q_state$dir)) {
    q_state$dir <- qproj_set_up(q_files())
    withr::defer(unlink(q_state$dir, recursive = TRUE), teardown_env())
  }
  q_state$dir
}

test_that("4d G37: quarto render resolves the constructs of documents at the root and in a subfolder, activated only by the .Rprofile", {
  skip_if_no_quarto()
  q <- q_set_up()
  # nothing in the documents calls weft_setup() or names it in the front matter
  for (f in c("index.qmd", "chapters/two.qmd")) {
    expect_false(any(grepl("weft_setup", u4_read(q, f), fixed = TRUE)), label = f)
  }
  expect_true(file.exists(file.path(q, ".Rprofile")))
  for (f in c("index.qmd", "chapters/two.qmd")) {
    r <- u4_qrender(q, f)
    expect_identical(r$status, 0L, info = r$log)
    html <- u4_html(q, sub("\\.qmd$", "", f))
    expect_match(html, "12.5", fixed = TRUE)
    expect_match(html, "one site", fixed = TRUE)
    expect_no_match(html, "{.num}", fixed = TRUE)
    expect_no_match(html, "weft: failed claim", fixed = TRUE)
  }
})

test_that("4d G37: under quarto render a failing claim() stops the render; in draft mode it leaves the marker once", {
  skip_if_no_quarto()
  q <- q_set_up()
  r <- u4_qrender(q, "bad.qmd")
  expect_false(identical(r$status, 0L), info = r$log)
  # the html may stay: under Quarto a failure is collected and reported at the end (rule 2.6.6)
  r2 <- u4_qrender(q, "bad.qmd", env = u4_env(u4_home(), extra = c(WEFT_DRAFT = "1")))
  expect_identical(r2$status, 0L, info = r2$log)
  expect_identical(u4_n("weft: failed claim", u4_html(q, "bad")), 1L)
})

test_that("4d G37 (control): the same project without use_setup(): documents with constructs, no .Rprofile, fail the render", {
  skip_if_no_quarto()
  q <- u4_quarto_project(q_files(engine = TRUE))
  expect_false(file.exists(file.path(q, ".Rprofile")))
  r <- u4_qrender(q, "index.qmd")
  expect_false(identical(r$status, 0L), info = r$log)
})

test_that("4d G37: a document with the front-matter route as well as the .Rprofile is not set up twice", {
  skip_if_no_quarto()
  q <- qproj_set_up(list(`bad.qmd` = u4_qmd(c(U4_BODY, U4_CLAIM_FAIL), title = "Bad")))
  u4_use(q, route = "front-matter")
  expect_true(u4_has_run(u4_front(file.path(q, "bad.qmd")), U4_OPTS_KNIT))
  expect_true(file.exists(file.path(q, ".Rprofile")))
  r <- u4_qrender(q, "bad.qmd", env = u4_env(u4_home(), extra = c(WEFT_DRAFT = "1")))
  expect_identical(r$status, 0L, info = r$log)
  html <- u4_html(q, "bad")
  expect_match(html, "12.5", fixed = TRUE)
  expect_identical(u4_n("weft: failed claim", html), 1L)
})

# ---- nothing leaks out of the project ----------------------------------------

test_that("4d G3: a render in a fresh process writes nothing outside the project, HOME or the cache folder it was given", {
  base <- u4_dir(list(`sibling.txt` = "stay"))
  proj <- u4_dir(list(`doc.Rmd` = u4_rmd()), base = file.path(base, "proj"))
  u4_use(proj)
  home <- u4_home()
  env <- u4_env(home)
  before <- u4_md5(base)[!startsWith(names(u4_md5(base)), "proj/")]
  home_before <- tree(home)
  r <- u4_render_rmd(proj, env = env)
  expect_false(r$failed, info = r$log)
  expect_identical(u4_md5(base)[!startsWith(names(u4_md5(base)), "proj/")], before)
  expect_identical(tree(home), home_before)
})
