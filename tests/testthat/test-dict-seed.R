# Package 2c: dict_seed(). Contract: dev/design-2c.md "dict_seed(...)", rule 9.5.2, C22-C25.
# Fixture: tests/testthat/_seed/ (line numbers matter), copied to a temp folder so that the
# working folder is not the repository. Helpers: helper-2c.R.

SEED_COLS <- c("name", "value", "differs", "n", "files", "where")

# the fixture copied into a fresh project folder, which becomes the working folder
seed_proj <- function(env = parent.frame()) {
  dir <- c2_proj(list(), env)
  src <- testthat::test_path("_seed")
  file.copy(list.files(src, all.files = TRUE, no.. = TRUE, full.names = TRUE), dir, recursive = TRUE)
  withr::local_dir(dir, .local_envir = env)
  dir
}

# a fresh folder with the given files, as the working folder
seed_files <- function(files, env = parent.frame()) {
  dir <- c2_proj(files, env)
  withr::local_dir(dir, .local_envir = env)
  dir
}

expect_seed_frame <- function(x) {
  expect_s3_class(x, "data.frame")
  expect_identical(names(x), SEED_COLS)
  expect_type(x$name, "character")
  expect_type(x$value, "character")
  expect_type(x$differs, "logical")
  expect_type(x$n, "integer")
  expect_type(x$files, "character")
  expect_type(x$where, "character")
  expect_true(.row_names_info(x) <= 0, label = "automatic row names")
}

test_that("2c seed: the default run finds exactly the contract's rows, in its order (9.5.2, C22, C23)", {
  seed_proj()
  r <- suppressMessages(dict_seed())
  expect_seed_frame(r)
  expect_identical(r$name, c("alpha", "n_boot", "offset", "site_name", "zones"))
  expect_identical(r$n, c(3L, 3L, 2L, 2L, 2L))
  expect_identical(r$differs, c(FALSE, TRUE, FALSE, FALSE, FALSE))
  expect_identical(r$value, c("0.05", NA, "-1", "\"Northern catchment\"",
                              "c(upper = \"Upper reach\", lower = \"Lower reach\")"))
  expect_identical(r$files, c("ch1.qmd, ch2.Rmd, sub/ch3.qmd", "ch1.qmd, ch2.Rmd, sub/ch3.qmd",
                              "ch2.Rmd, sub/ch3.qmd", "ch1.qmd, ch2.Rmd", "ch1.qmd, ch2.Rmd"))
  expect_identical(r$where, c(
    "ch1.qmd:6: 0.05; ch2.Rmd:2: 0.05; sub/ch3.qmd:3: 0.05",
    "ch1.qmd:7: 1000; ch2.Rmd:3: 2000; sub/ch3.qmd:5: 1000",
    "ch2.Rmd:5: -1; sub/ch3.qmd:4: -1",
    "ch1.qmd:8: \"Northern catchment\"; ch2.Rmd:4: \"Northern catchment\"",
    paste0("ch1.qmd:9: c(upper = \"Upper reach\", lower = \"Lower reach\"); ",
           "ch2.Rmd:6: c(upper = \"Upper reach\", lower = \"Lower reach\")")))
})

test_that("2c seed: what is not a top-level literal in an evaluated R chunk is not listed (9.5.2, C22, C24)", {
  seed_proj()
  r <- suppressMessages(dict_seed(min_files = 1))
  expect_false(any(c("hidden", "x", "f", "broken") %in% r$name))
  # `inner` is listed once, from sub/ch3.qmd only (ch1's is inside a function)
  expect_identical(r$files[r$name == "inner"], "sub/ch3.qmd")
  expect_identical(r$n[r$name == "inner"], 1L)
  # Python's alpha (0.5), _freeze's alpha (9), eval = FALSE's alpha (0.1), R/consts.R's (0.01)
  alpha <- r[r$name == "alpha", ]
  expect_false(grepl("0.5|0.1|: 9|0.01", alpha$where))
  expect_identical(r$name, c("alpha", "n_boot", "offset", "site_name", "zones", "inner"))
  expect_identical(r$n, c(3L, 3L, 2L, 2L, 2L, 1L))
})

test_that("2c seed: the skipped attribute records the chunk that did not parse, and a message says so (9.5.2)", {
  seed_proj()
  r <- c2_says(dict_seed())
  sk <- attr(r$value, "skipped")
  expect_s3_class(sk, "data.frame")
  expect_identical(names(sk), c("file", "line", "message"))
  expect_identical(sk$file, "ch1.qmd")
  expect_identical(sk$line, 24L)
  expect_type(sk$message, "character")
  expect_true(nzchar(sk$message))
  expect_false(grepl("\n", sk$message, fixed = TRUE))
  expect_length(r$msgs, 1L)
  expect_match(r$msgs, "^dict_seed\\(\\): 1 piece\\(s\\) of code could not be parsed and were skipped; see attr\\(")
  expect_match(r$msgs, "\"skipped\"", fixed = TRUE)
})

test_that("2c seed: with nothing to skip, the skipped attribute has zero rows and no message is given (9.5.2)", {
  seed_files(list(`a.qmd` = c("```{r}", "k <- 1", "```"), `b.qmd` = c("```{r}", "k <- 1", "```")))
  r <- c2_says(dict_seed())
  sk <- attr(r$value, "skipped")
  expect_s3_class(sk, "data.frame")
  expect_identical(names(sk), c("file", "line", "message"))
  expect_identical(nrow(sk), 0L)
  expect_identical(r$msgs, character())
  expect_identical(r$value$name, "k")
})

test_that("2c seed: paths given are read in the order given, .R whole, and a differing value is listed with every assignment (C23, C25)", {
  seed_proj()
  r <- suppressMessages(dict_seed(paths = c("ch1.qmd", "R/consts.R")))
  expect_seed_frame(r)
  expect_identical(r$name, c("alpha", "site_name"))
  expect_identical(r$differs, c(TRUE, TRUE))
  expect_identical(r$value, c(NA_character_, NA_character_))
  expect_identical(r$n, c(2L, 2L))
  expect_identical(r$files, rep("ch1.qmd, R/consts.R", 2))
  expect_identical(r$where, c("ch1.qmd:6: 0.05; R/consts.R:1: 0.01",
                              "ch1.qmd:8: \"Northern catchment\"; R/consts.R:2: \"Southern catchment\""))
  r2 <- suppressMessages(dict_seed(paths = c("R/consts.R", "ch1.qmd")))
  expect_identical(r2$where[1], "R/consts.R:1: 0.01; ch1.qmd:6: 0.05")
  expect_identical(r2$files[1], "R/consts.R, ch1.qmd")
})

test_that("2c seed: a .R file is read only when named (C25)", {
  seed_proj()
  r <- suppressMessages(dict_seed(min_files = 1))
  expect_false(any(grepl("consts.R", r$files, fixed = TRUE)))
})

test_that("2c seed: a .R file that does not parse is skipped at line 1 and recorded (9.5.2)", {
  seed_files(list(`x.R` = c("a <- (", "b <- 1"), `y.R` = "b <- 1"))
  r <- c2_says(dict_seed(paths = c("x.R", "y.R"), min_files = 1))
  sk <- attr(r$value, "skipped")
  expect_identical(sk$file, "x.R")
  expect_identical(sk$line, 1L)
  expect_identical(r$value$name, "b")
  expect_identical(r$value$files, "y.R")
  expect_match(r$all, "1 piece(s) of code could not be parsed and were skipped", fixed = TRUE)
})

test_that("2c seed: a name assigned twice in one file counts one file, and where lists both assignments (9.5.2)", {
  seed_files(list(`a.R` = c("# top", "alpha <- 1", "alpha <- 2"), `b.R` = c("alpha <- 1")))
  r <- suppressMessages(dict_seed(paths = c("a.R", "b.R")))
  expect_identical(r$n, 2L)
  expect_identical(r$differs, TRUE)
  expect_identical(r$where, "a.R:2: 1; a.R:3: 2; b.R:1: 1")
  r1 <- suppressMessages(dict_seed(paths = "a.R", min_files = 2))
  expect_identical(nrow(r1), 0L)
})

test_that("2c seed C22: only numbers, strings and c() of one kind count; text of a value as the contract says (9.5.2)", {
  src <- c("a_neg <- -1", "a_pos <- +3", "a_vec <- c(1, 2, 3)", "a_named <- c(x = 1, y = 2)",
           "a_mixed <- c(1, \"a\")", "a_partial <- c(x = 1, 2)", "a_lgl <- TRUE", "a_na <- NA",
           "a_null <- NULL", "a_super <<- 1", "assign(\"a_assign\", 1)", "a_cplx <- 1i",
           "a_str <- \"s\"", "a_int <- 5L", "a_expr <- 1 + 2", "a_sym <- pi",
           "a_date <- as.Date(\"2024-01-01\")", "a_strvec <- c(\"p\", \"q\")", "a_empty <- c()",
           "a_big <- 5e-2", "7 ->> a_rsuper", "a_fn <- function() 1", "a_call <- mean(1)")
  seed_files(list(`f1.R` = src, `f2.R` = src))
  r <- suppressMessages(dict_seed(paths = c("f1.R", "f2.R")))
  expect_setequal(r$name, c("a_neg", "a_pos", "a_vec", "a_named", "a_str", "a_int", "a_strvec", "a_big"))
  val <- function(nm) r$value[r$name == nm]
  expect_identical(val("a_neg"), "-1")
  expect_identical(val("a_pos"), "3")
  expect_identical(val("a_vec"), "c(1, 2, 3)")
  expect_identical(val("a_named"), "c(x = 1, y = 2)")
  expect_identical(val("a_str"), "\"s\"")
  expect_identical(val("a_int"), "5")
  expect_identical(val("a_strvec"), "c(\"p\", \"q\")")
  expect_identical(val("a_big"), "0.05")
  expect_true(all(r$n == 2L))
  expect_true(all(!r$differs))
})

test_that("2c seed: integers and doubles of the same number are the same value (9.5.2)", {
  seed_files(list(`a.R` = "k <- 2000L", `b.R` = "k <- 2000", `c.R` = "k <- 2e3"))
  r <- suppressMessages(dict_seed(paths = c("a.R", "b.R", "c.R")))
  expect_identical(r$value, "2000")
  expect_identical(r$differs, FALSE)
  expect_identical(r$n, 3L)
})

test_that("2c seed C24: eval = FALSE in a header, and #| eval: false (or no, any case), leave a chunk out; eval = TRUE and others stay (9.5.2)", {
  doc <- c(
    "```{r, eval = FALSE}", "k_hdr <- 1", "```", "",
    "```{r, eval=F}", "k_hdr_f <- 1", "```", "",
    "```{r}", "#| eval: false", "k_opt <- 1", "```", "",
    "```{r}", "#| eval: no", "k_no <- 1", "```", "",
    "```{r}", "#| eval: False", "k_case <- 1", "```", "",
    "```{r, eval = TRUE}", "k_kept <- 1", "```", "",
    "```{r}", "#| echo: false", "k_kept2 <- 1", "```")
  seed_files(list(`a.qmd` = doc, `b.qmd` = doc))
  r <- suppressMessages(dict_seed())
  expect_setequal(r$name, c("k_kept", "k_kept2"))
})

test_that("2c seed: engines r and R are read, others are not, and an unclosed chunk is read to the end of the file (9.5.2)", {
  doc <- c("```{R}", "k_cap <- 1", "```", "", "```{python}", "k_py = 1", "```", "",
           "```{r, echo = FALSE}", "k_opts <- 1", "```", "", "```{r}", "k_open <- 7")
  seed_files(list(`a.qmd` = doc, `b.qmd` = doc))
  r <- suppressMessages(dict_seed())
  expect_setequal(r$name, c("k_cap", "k_opts", "k_open"))
})

test_that("2c seed: the default file list takes .qmd, .Rmd and .rmd, recursively, but not under _*, .* or renv folders; shown relative and sorted (9.5.2)", {
  src <- c("```{r}", "k <- 1", "```")
  files <- setNames(rep(list(src), 9L), c("a.qmd", "sub/b.Rmd", "sub/deep/c.rmd", "_hidden/d.qmd",
                                          ".dot/e.qmd", "renv/f.qmd", "g.QMD", "notes.txt", "h.R"))
  seed_files(files)
  r <- suppressMessages(dict_seed(min_files = 1))
  expect_identical(r$files, "a.qmd, sub/b.Rmd, sub/deep/c.rmd")
  expect_identical(r$n, 3L)
})

test_that("2c seed: the root is the project root, so a subfolder run shows paths relative to it (9.5.2)", {
  dir <- seed_files(list(`_weft.yml` = "digits: 1",
                         `a.qmd` = c("```{r}", "k <- 1", "```"),
                         `sub/b.qmd` = c("```{r}", "k <- 1", "```")))
  withr::local_dir(file.path(dir, "sub"))
  r <- suppressMessages(dict_seed())
  expect_identical(r$files, "a.qmd, sub/b.qmd")
})

test_that("2c seed: min_files = 1 lists names from a single file (9.5.2)", {
  seed_files(list(`a.qmd` = c("```{r}", "only_here <- 1", "```")))
  expect_identical(nrow(suppressMessages(dict_seed())), 0L)
  expect_identical(suppressMessages(dict_seed(min_files = 1))$name, "only_here")
})

test_that("2c seed: nothing is evaluated and nothing is written (9.5.2, P10)", {
  doc <- c("```{r}", "stop(\"ran\")", "file.create(\"ran.flag\")", "x <- system(\"false\")",
           "k <- 1", "```")
  dir <- seed_files(list(`a.qmd` = doc, `b.qmd` = doc))
  before <- c2_tree(dir)
  r <- NULL
  expect_no_error(r <- suppressMessages(dict_seed()))
  expect_identical(r$name, "k")
  expect_identical(c2_tree(dir), before)
  expect_false(file.exists(file.path(dir, "ran.flag")))
  seed_proj()
  d2 <- getwd()
  before2 <- c2_tree(d2)
  suppressMessages(dict_seed())
  expect_identical(c2_tree(d2), before2)
})

test_that("2c seed: a missing file is a weft_tool_error naming each missing file (Errors)", {
  seed_proj()
  e <- c2_err(dict_seed(paths = c("nope.qmd", "ch1.qmd", "also.qmd")))
  c2_expect_cond(e, "weft_tool_error")
  c2_expect_msg(e, "dict_seed(): no such file: nope.qmd, also.qmd.")
})

test_that("2c seed: a file with another extension is a weft_tool_error (Errors)", {
  seed_files(list(`notes.txt` = "k <- 1", `a.qmd` = "x"))
  e <- c2_err(dict_seed(paths = c("a.qmd", "notes.txt")))
  c2_expect_cond(e, "weft_tool_error")
  c2_expect_msg(e, "dict_seed(): notes.txt is not a .qmd, .Rmd or .R file.")
})

test_that("2c seed: min_files must be a whole number from 1 (Errors)", {
  seed_proj()
  for (bad in list(0, 1.5, -2, "a", NA, c(1, 2), NULL, Inf)) {
    e <- c2_err(dict_seed(min_files = bad))
    c2_expect_cond(e, "weft_tool_error")
    c2_expect_msg(e, "dict_seed(): `min_files` must be a whole number from 1.")
  }
  expect_no_error(suppressMessages(dict_seed(min_files = 2L)))
})

test_that("2c seed: a folder with no documents gives the message and a zero-row result with the columns (9.5.2)", {
  seed_files(list(`readme.txt` = "x"))
  r <- c2_says(dict_seed())
  expect_length(r$msgs, 1L)
  expect_match(r$msgs, "^dict_seed\\(\\): no \\.qmd or \\.Rmd files under ")
  expect_match(r$msgs, "\\.$")
  expect_identical(nrow(r$value), 0L)
  expect_seed_frame(r$value)
  expect_identical(nrow(attr(r$value, "skipped")), 0L)
})
