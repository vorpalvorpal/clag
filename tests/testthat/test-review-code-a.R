# Regression tests for code review A, the rendering core
# (dev/review-code-a.md, proposals 1 to 10, readings from its Rulings).
# Each title starts "review-code-a #n:".

rca_txt <- function(x) as.character(x)
rca_minus <- intToUtf8(0x2212)

rca_dir <- function(env = parent.frame()) {
  d <- withr::local_tempdir(.local_envir = env)
  normalizePath(d)
}

rca_write_bytes <- function(path, bytes) {
  con <- file(path, "wb")
  on.exit(close(con))
  writeBin(bytes, con)
  invisible(path)
}

rca_cfg_commas <- function() {
  cfg <- weft:::default_config()
  cfg$decimal_mark <- ","
  cfg$big_mark <- "."
  cfg
}

rca_af <- function(v, cls, keys = list(), cfg = weft:::default_config()) {
  rca_txt(weft:::apply_formatters(v, cls, keys, cfg))
}

# ---- 1: digits and sigfig past double precision --------------------------

test_that("review-code-a #1: sigfig past 15 digits pads with zeros, never the binary tail", {
  expect_equal(rca_txt(fmt_num(0.1, sigfig = 25)),
               paste0("0.1", strrep("0", 24)))
  expect_equal(rca_txt(fmt_num(0.1, sigfig = 17)),
               paste0("0.1", strrep("0", 16)))
})

test_that("review-code-a #1: digits past 15 significant digits pads with zeros", {
  expect_equal(rca_txt(fmt_num(0.1, digits = 20)),
               paste0("0.1", strrep("0", 19)))
  # fifteen significant digits of a third, then zeros to 20 places
  expect_equal(rca_txt(fmt_num(1 / 3, digits = 20)),
               paste0("0.", strrep("3", 15), strrep("0", 5)))
  expect_equal(rca_txt(fmt_num(123.456, digits = 15)),
               paste0("123.456", strrep("0", 12)))
})

test_that("review-code-a #1: a large number with decimals and a negative number", {
  # 9 integer digits, 10 places: 19 significant digits asked for
  expect_equal(rca_txt(fmt_num(123456789.5, digits = 10)), "123,456,789.5000000000")
  expect_equal(rca_txt(fmt_num(1234.5678, digits = 14)), "1,234.56780000000000")
  expect_equal(rca_txt(fmt_num(-0.1, sigfig = 20)),
               paste0(rca_minus, "0.1", strrep("0", 19)))
  expect_equal(rca_txt(fmt_num(-0.1, digits = 20)),
               paste0(rca_minus, "0.1", strrep("0", 19)))
})

test_that("review-code-a #1: ordinary calls are unchanged (neighbour guard)", {
  expect_equal(rca_txt(fmt_num(3.14159, sigfig = 3)), "3.14")
  expect_equal(rca_txt(fmt_num(2.5, digits = 2)), "2.50")
  expect_equal(rca_txt(fmt_num(0.012345, sigfig = 2)), "0.012")
  expect_equal(rca_txt(fmt_num(1234.5, digits = 1)), "1,234.5")
  expect_equal(rca_txt(fmt_num(0.1, sigfig = 15)), paste0("0.1", strrep("0", 14)))
})

test_that("review-code-a #1: an absurd digits is a weft construct error, not a plain R error", {
  e <- tryCatch(fmt_num(1, digits = 9000), error = function(e) e)
  expect_s3_class(e, "error")
  expect_true(inherits(e, "weft_error"),
              label = paste("class of the error:", paste(class(e), collapse = "/")))
})

# ---- 2: .a before a number with a decimal comma --------------------------

test_that("review-code-a #2: with a comma decimal mark, 18,5 takes 'an'", {
  cfg <- rca_cfg_commas()
  expect_equal(rca_af(18.5, c(".num", ".a"), cfg = cfg), "an 18,5")
  expect_equal(rca_af(11.25, c(".num", ".a"), list(digits = 2), cfg = cfg), "an 11,25")
  expect_equal(rca_af(8.5, c(".num", ".a"), cfg = cfg), "an 8,5")
})

test_that("review-code-a #2: with a comma decimal mark, 1,5 takes 'a' (neighbour guard)", {
  cfg <- rca_cfg_commas()
  expect_equal(rca_af(1.5, c(".num", ".a"), cfg = cfg), "a 1,5")
  expect_equal(rca_af(1800, c(".num", ".a"), cfg = cfg), "a 1.800")
  expect_equal(rca_af(18000, c(".num", ".a"), cfg = cfg), "an 18.000")
})

test_that("review-code-a #2: default marks, thousands separators do not count for the sound (neighbour guard)", {
  # "1,800" is read "one thousand eight hundred": a
  expect_equal(rca_af(1800, c(".num", ".a")), "a 1,800")
  expect_equal(rca_af(18000, c(".num", ".a")), "an 18,000")
  expect_equal(rca_af(11, c(".num", ".a")), "an 11")
  expect_equal(rca_af(8, c(".num", ".a")), "an 8")
  expect_equal(rca_af(8.5, c(".num", ".a")), "an 8.5")
  expect_equal(rca_af(18.5, c(".num", ".a")), "an 18.5")
  expect_equal(rca_af(1.5, c(".num", ".a")), "a 1.5")
})

# ---- 3: arms() agrees with the knit --------------------------------------

test_that("review-code-a #3a: an id defined in a caption is not an arms() error", {
  d <- rca_dir()
  f <- file.path(d, "doc.Rmd")
  writeLines(c("```{r}",
               "#| fig-cap: |",
               "#|   A plot of [one site | # sites]{n=\"k\" #nk}.",
               "plot(1)",
               "```", "",
               "Again [a site | # sites]{n=\"#nk\"} here."), f)
  a <- arms(f)
  expect_equal(nrow(attr(a, "errors")), 0L)
})

test_that("review-code-a #3a: an id defined nowhere is still an arms() error (neighbour guard)", {
  d <- rca_dir()
  f <- file.path(d, "doc.Rmd")
  writeLines(c("Again [a site | # sites]{n=\"#nowhere\"} here."), f)
  a <- arms(f)
  expect_gte(nrow(attr(a, "errors")), 1L)
  expect_match(paste(unlist(attr(a, "errors")), collapse = " "), "nowhere")
})

test_that("review-code-a #3b: arms() knows the project's registered classes", {
  d <- rca_dir()
  writeLines(c("formatters:", "  .compact:", "    function: base::format",
               "    stage: number"), file.path(d, "_weft.yml"))
  f <- file.path(d, "doc.Rmd")
  writeLines("We saw [a site | # sites]{n=\"x\" .num .compact}.", f)
  a <- arms(f)
  expect_gte(nrow(attr(a, "errors")), 1L)
  expect_match(paste(unlist(attr(a, "errors")), collapse = " "),
               "Two classes from one group")
  # control: one class from the group is no error
  g <- file.path(d, "doc2.Rmd")
  writeLines("We saw [a site | # sites]{n=\"x\" .compact}.", g)
  expect_equal(nrow(attr(arms(g), "errors")), 0L)
})

test_that("review-code-a #3c: the language comes from the merged Quarto metadata", {
  d <- rca_dir()
  info <- file.path(d, "info.json")
  writeLines('{"format": {"metadata": {"lang": "de"}}}', info)
  g <- file.path(d, "doc.Rmd")
  writeLines("We saw [a site | # sites]{n=\"x\"}.", g)
  # control: with no metadata the English two-arm span has no error
  withr::local_envvar(QUARTO_EXECUTE_INFO = NA)
  expect_equal(nrow(attr(arms(g), "errors")), 0L)
  withr::local_envvar(QUARTO_EXECUTE_INFO = info)
  expect_equal(weft:::document_lang(weft:::read_front_matter(g), g), "de")
  expect_gte(nrow(attr(arms(g), "errors")), 1L)
})

# ---- 4: the draft setting is true or false only --------------------------

test_that("review-code-a #4: draft: on, yes and 1 in _weft.yml are configuration errors naming the file", {
  withr::local_envvar(WEFT_DRAFT = NA)
  for (v in c("on", "yes", "1", "\"maybe\"")) {
    d <- rca_dir()
    writeLines(paste("draft:", v), file.path(d, "_weft.yml"))
    e <- tryCatch(weft:::read_config(d, front = list()), error = function(e) e)
    expect_true(inherits(e, "error"), info = paste("draft:", v, "raises an error"))
    msg <- if (inherits(e, "error")) conditionMessage(e) else ""
    expect_match(msg, "_weft.yml", fixed = TRUE, info = v)
    expect_match(msg, "draft", info = v)
  }
})

test_that("review-code-a #4: draft: true and false are read (neighbour guard)", {
  withr::local_envvar(WEFT_DRAFT = NA)
  d <- rca_dir()
  writeLines("draft: true", file.path(d, "_weft.yml"))
  expect_true(isTRUE(weft:::read_config(d, front = list())$draft))
  writeLines("draft: false", file.path(d, "_weft.yml"))
  expect_false(isTRUE(weft:::read_config(d, front = list())$draft))
})

test_that("review-code-a #4: WEFT_DRAFT other than true, false or 1 is an error; true, 1 and false are read", {
  d <- rca_dir()
  for (v in c("yes", "on")) {
    withr::local_envvar(WEFT_DRAFT = v)
    expect_error(weft:::read_config(d, front = list()), "WEFT_DRAFT", info = v)
  }
  # ruling of 13 Nov: 1 stays, as the usual spelling of a set environment variable
  withr::local_envvar(WEFT_DRAFT = "1")
  expect_true(isTRUE(weft:::read_config(d, front = list())$draft))
  withr::local_envvar(WEFT_DRAFT = "true")
  expect_true(isTRUE(weft:::read_config(d, front = list())$draft))
  withr::local_envvar(WEFT_DRAFT = "false")
  expect_false(isTRUE(weft:::read_config(d, front = list())$draft))
})

test_that("review-code-a #4: a knit of a document with draft: on stops before knitting, naming the file", {
  res <- render_rmd(c("Intro.", "", "Value `r claim(3, . > 100)` here."),
                    files = list("_weft.yml" = "draft: on"), format = "knit")
  expect_true(res$failed)
  expect_match(res$message, "_weft.yml", fixed = TRUE)
  expect_false(any(grepl("<<weft:", res$text, fixed = TRUE)))
})

# ---- 5: .date weekday names ----------------------------------------------

test_that("review-code-a #5: .date weekday names are English whatever LC_TIME is", {
  loc <- NULL
  old <- Sys.getlocale("LC_TIME")
  for (l in c("fr_FR.UTF-8", "de_DE.UTF-8")) {
    ok <- suppressWarnings(tryCatch(Sys.setlocale("LC_TIME", l), error = function(e) ""))
    if (nzchar(ok)) { loc <- l; break }
  }
  withr::defer(Sys.setlocale("LC_TIME", old))
  skip_if(is.null(loc), "no French or German locale installed")
  d <- as.Date("2024-03-05")   # a Tuesday
  expect_equal(weft:::format_dates(d, "%A %-d %B %Y"), "Tuesday 5 March 2024")
  expect_equal(weft:::format_dates(d, "%a %-d %b"), "Tue 5 Mar")
  expect_equal(weft:::format_dates(as.Date("2024-03-10"), "%A"), "Sunday")
})

test_that("review-code-a #5: .date weekday names in the C locale (neighbour guard)", {
  old <- Sys.getlocale("LC_TIME")
  Sys.setlocale("LC_TIME", "C")
  withr::defer(Sys.setlocale("LC_TIME", old))
  d <- as.Date("2024-03-05")
  expect_equal(weft:::format_dates(d, "%A %-d %B %Y"), "Tuesday 5 March 2024")
  expect_equal(weft:::format_dates(d, "%a"), "Tue")
  expect_equal(weft:::format_dates(d, "%-d %B %Y"), "5 March 2024")
})

# ---- 6: the post-render report keeps characters above U+FFFF ---------------

# unescape() is taken out of the installed post-render script by name (the
# script itself is not sourced; it runs where weft is not installed).
rca_unescape <- function() {
  f <- system.file("quarto", "weft-post-render.R", package = "weft")
  skip_if(!nzchar(f), "the post-render script is not installed")
  find <- function(e) {
    if (is.call(e)) {
      if ((identical(e[[1]], as.name("<-")) || identical(e[[1]], as.name("="))) &&
          identical(e[[2]], as.name("unescape")) && length(e) == 3L) return(e)
      for (i in seq_along(e)) {
        r <- find(e[[i]])
        if (!is.null(r)) return(r)
      }
    }
    NULL
  }
  e <- NULL
  for (x in as.list(parse(f, keep.source = FALSE))) {
    e <- find(x)
    if (!is.null(e)) break
  }
  if (is.null(e)) skip("no unescape() in the post-render script")
  env <- new.env(parent = baseenv())
  eval(e, env)
  env$unescape
}

rca_json_body <- function(x) {
  j <- weft:::json_string(x)
  sub('^"', "", sub('"$', "", j))
}

test_that("review-code-a #6: an astral character survives json_string() then unescape()", {
  unescape <- rca_unescape()
  for (ch in c("\U0001D465", "\U0001F600", "\U00020000")) {
    x <- paste0("x ", ch, " y")
    # the knit writes a surrogate pair: plain ASCII
    expect_false(grepl("[^ -~]", weft:::json_string(x)))
    expect_equal(unescape(rca_json_body(x)), x)
  }
  expect_equal(unescape(rca_json_body("\U0001F600\U0001F601")), "\U0001F600\U0001F601")
})

test_that("review-code-a #6: BMP characters and plain escapes still decode (neighbour guard)", {
  unescape <- rca_unescape()
  x <- intToUtf8(c(0x63, 0x61, 0x66, 0xE9, 0x20, 0x3B1, 0x20, 0x4E2D))
  expect_equal(unescape(rca_json_body(x)), x)
  expect_equal(unescape("a\\nb"), "a\nb")
})

# ---- 7: one reader of a source file --------------------------------------

test_that("review-code-a #7: a CR-only file has the same line numbers in arms() and the knit", {
  f <- file.path(rca_dir(), "cr.Rmd")
  rca_write_bytes(f, charToRaw("Line one.\r\rWe saw [a site | # sites]{n=\"x\"}.\r"))
  a <- arms(f)
  knit_line <- grep("We saw", weft:::read_view_lines(f), fixed = TRUE)
  expect_equal(knit_line, 3L)
  expect_equal(unique(a$line), 3L)
})

test_that("review-code-a #7: CRLF and a BOM give the line numbers of the plain file (neighbour guard)", {
  d <- rca_dir()
  body <- "Line one.\n\nWe saw [a site | # sites]{n=\"x\"}.\n"
  f1 <- file.path(d, "lf.Rmd")
  f2 <- file.path(d, "crlf.Rmd")
  f3 <- file.path(d, "bom.Rmd")
  rca_write_bytes(f1, charToRaw(body))
  rca_write_bytes(f2, charToRaw(gsub("\n", "\r\n", body, fixed = TRUE)))
  rca_write_bytes(f3, c(as.raw(c(0xEF, 0xBB, 0xBF)), charToRaw(body)))
  for (f in c(f1, f2, f3)) expect_equal(unique(arms(f)$line), 3L, info = basename(f))
})

test_that("review-code-a #7: a NUL byte is a weft_encoding_error naming the file", {
  f <- file.path(rca_dir(), "nul.Rmd")
  rca_write_bytes(f, c(charToRaw("A [a|b]{n=\"x\"}"), as.raw(0), charToRaw("z")))
  e <- tryCatch(arms(f), error = function(e) e)
  expect_s3_class(e, "weft_encoding_error")
  expect_match(conditionMessage(e), "nul.Rmd", fixed = TRUE)
})

test_that("review-code-a #7: invalid UTF-8 is a weft_encoding_error naming the file", {
  f <- file.path(rca_dir(), "latin1.Rmd")
  rca_write_bytes(f, c(charToRaw("Caf"), as.raw(0xE9), charToRaw(" [a|b]{n=\"x\"}\n")))
  e <- tryCatch(arms(f), error = function(e) e)
  expect_s3_class(e, "weft_encoding_error")
  expect_match(conditionMessage(e), "latin1.Rmd", fixed = TRUE)
})

# ---- 8: a failed file scan is a recorded failure -------------------------

test_that("review-code-a #8: a document whose whole-file scan fails does not knit ok", {
  d <- rca_dir()
  withr::local_dir(d)
  withr::local_envvar(WEFT_DRAFT = NA)
  withr::defer(weft_restore_knitr())
  txt <- c("```{r setup, include=FALSE}", "weft::weft_setup()", "x <- 3", "```", "",
           "Caf\xe9 line.", "", "We saw [a site | # sites]{n=\"x\"} here.", "",
           "Bad: `r claim(x, . > 5)` there.")
  rca_write_bytes("doc.Rmd", charToRaw(paste(txt, collapse = "\n")))
  err <- tryCatch({
    suppressWarnings(knitr::knit("doc.Rmd", quiet = TRUE, envir = new.env()))
    NULL
  }, error = function(e) e)
  fails <- tryCatch(weft::last_knit()$failures, error = function(e) NULL)
  recorded <- !is.null(err) || (!is.null(fails) && NROW(fails) > 0L)
  expect_true(recorded, label = "the knit stopped or recorded a failure")
  # the unevaluated claim must not reach the output silently
  if (is.null(err) && file.exists("doc.md")) {
    out <- readLines("doc.md", warn = FALSE)
    expect_false(any(grepl("claim(x, . > 5)", out, fixed = TRUE)))
  }
})

# ---- 9: an unreadable bibliography is not "missing keys" -----------------

rca_cite_doc <- function(bib_name, bib_lines) {
  render_rmd(c("A source [x]{cite=\"@smith2020\"}."),
             front = c(paste("bibliography:", bib_name)),
             files = setNames(list(bib_lines), bib_name), format = "knit")
}

test_that("review-code-a #9: a CSL JSON file that does not parse is reported as unreadable, naming it", {
  res <- rca_cite_doc("refs.json", '[{"id": "smith2020", "title": "a"}, {"id": oops: "x"}]')
  all <- paste(c(res$message, res$log, res$text), collapse = "\n")
  expect_true(res$failed || grepl("weft:", all, fixed = TRUE))
  expect_match(all, "refs.json", fixed = TRUE)
  expect_match(all, "could not be read|unreadable", ignore.case = TRUE)
})

test_that("review-code-a #9: a YAML bibliography that does not parse is reported as unreadable, naming it", {
  res <- rca_cite_doc("refs.yaml", c("- id: smith2020", "  title: [unclosed"))
  all <- paste(c(res$message, res$log, res$text), collapse = "\n")
  expect_match(all, "refs.yaml", fixed = TRUE)
  expect_match(all, "could not be read|unreadable", ignore.case = TRUE)
})

test_that("review-code-a #9: a readable file with the key missing is still 'not in the bibliography' (neighbour guard)", {
  res <- rca_cite_doc("refs.json", '[{"id": "other2021", "title": "a"}]')
  all <- paste(c(res$message, res$log, res$text), collapse = "\n")
  expect_match(all, "not in the bibliography", fixed = TRUE)
  expect_false(grepl("could not be read|unreadable", all, ignore.case = TRUE))
})

test_that("review-code-a #9: a readable file with the key present knits cleanly (neighbour guard)", {
  res <- rca_cite_doc("refs.json", '[{"id": "smith2020", "title": "a"}]')
  expect_false(res$failed, label = res$message)
})

# ---- 10: a stamp that cannot be written ----------------------------------

test_that("review-code-a #10: an unwritable stamp folder gives a warning or message that says so", {
  skip_on_os("windows")
  skip_if(identical(Sys.info()[["user"]], "root"), "root can write anywhere")
  d <- rca_dir()
  writeLines("draft: false", file.path(d, "_weft.yml"))
  writeLines("x", file.path(d, "doc.Rmd"))
  sd <- file.path(d, ".weft", "stamps")
  dir.create(sd, recursive = TRUE)
  Sys.chmod(sd, "0555")
  withr::defer(Sys.chmod(sd, "0755"))
  skip_if(suppressWarnings(file.create(file.path(sd, "probe"))), "the folder is writable anyway")
  s <- weft:::new_state()
  s$input_path <- file.path(d, "doc.Rmd")
  s$input_name <- "doc.Rmd"
  seen <- character()
  withCallingHandlers(
    weft:::record_knit(s, weft:::failures_frame(s)),
    warning = function(w) {
      seen <<- c(seen, conditionMessage(w)); invokeRestart("muffleWarning")
    },
    message = function(m) {
      seen <<- c(seen, conditionMessage(m)); invokeRestart("muffleMessage")
    }
  )
  expect_gte(length(seen), 1L)
  expect_match(paste(seen, collapse = " "), "stamp", ignore.case = TRUE)
  expect_match(paste(seen, collapse = " "), "could not be written", fixed = TRUE)
})

test_that("review-code-a #10: a writable stamp folder is silent (neighbour guard)", {
  d <- rca_dir()
  writeLines("draft: false", file.path(d, "_weft.yml"))
  writeLines("x", file.path(d, "doc.Rmd"))
  dir.create(file.path(d, ".weft", "stamps"), recursive = TRUE)
  s <- weft:::new_state()
  s$input_path <- file.path(d, "doc.Rmd")
  s$input_name <- "doc.Rmd"
  expect_no_warning(expect_no_message(
    weft:::record_knit(s, weft:::failures_frame(s))
  ))
})
