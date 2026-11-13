# Package 6b, rules N40 to N44, N46, N48 and E40 to E45 (dev/design-6.md):
# weft_put() outside a knit, the names it accepts, claim() inside it, and
# weft_values_write(). Knits are in test-values-knit.R. Helpers: helper-6b.R.

# a clean environment for the calling test: no run id from the environment
local_no_run <- function(.env = parent.frame()) {
  withr::local_envvar(c(WEFT_RUN = NA_character_), .local_envir = .env)
}

err_of <- function(expr) {
  tryCatch({ expr; NULL }, weft_values_error = function(e) e)
}

# ---- exports -----------------------------------------------------------------

test_that("N1: weft_put() and weft_values_write() are exported functions", {
  ex <- getNamespaceExports("weft")
  expect_true(all(c("weft_put", "weft_values_write") %in% ex))
  expect_true(is.function(weft::weft_put))
  expect_true(is.function(weft::weft_values_write))
})

# ---- N40, N44: outside a knit ------------------------------------------------------

test_that("N44: outside a knit weft_put() returns the block's text, of class weft_values", {
  local_no_run()
  x <- weft::weft_put(depth = 3.14159)
  expect_s3_class(x, "weft_values")
  expect_true(is.character(x))
  blk <- b6_parse(x)
  expect_identical(blk$weft, 1L)
  expect_identical(blk$values$depth$t, "float")
  expect_identical(blk$values$depth$v, "3.14159")
})

test_that("N44: printing the result prints the block text", {
  local_no_run()
  x <- weft::weft_put(depth = 3.14159)
  out <- paste(capture.output(print(x)), collapse = "\n")
  expect_match(out, "\"depth\":{\"t\":\"float\",\"v\":\"3.14159\"}", fixed = TRUE)
  expect_match(out, "\"weft\":1", fixed = TRUE)
})

test_that("N44: nothing is stored: a later call holds only its own names", {
  local_no_run()
  weft::weft_put(first = 1)
  blk <- b6_parse(weft::weft_put(second = 2))
  expect_identical(names(blk$values), "second")
})

test_that("N40: several named arguments publish several names", {
  blk <- b6_parse(weft::weft_put(a = 1L, b = "x", c = TRUE))
  expect_setequal(names(blk$values), c("a", "b", "c"))
  expect_identical(blk$values$a$t, "int")
  expect_identical(blk$values$b$t, "string")
  expect_identical(blk$values$c$t, "bool")
})

test_that("N40: an unnamed argument that is a symbol publishes under the symbol's name", {
  depth <- 2.5
  n_sites <- 7L
  blk <- b6_parse(weft::weft_put(depth, n_sites))
  expect_setequal(names(blk$values), c("depth", "n_sites"))
  expect_identical(blk$values$depth$v, "2.5")
  expect_identical(blk$values$n_sites$v, "7")
  # mixed with a named argument
  blk <- b6_parse(weft::weft_put(depth, other = n_sites))
  expect_setequal(names(blk$values), c("depth", "other"))
})

test_that("N40: the expression is evaluated in the caller", {
  d <- data.frame(depth = c(1, 2, 6))
  blk <- b6_parse(weft::weft_put(depth = mean(d$depth), n = nrow(d)))
  expect_identical(blk$values$depth$v, "3")
  expect_identical(blk$values$n$v, "3")
})

test_that("N40: names with dots, a leading underscore and 64 characters are legal", {
  long <- paste0("a", strrep("b", 63))
  expect_identical(nchar(long), 64L)
  args <- list(1L, 2L, 3L, 4L, 5L)
  names(args) <- c("n.sites", "_hid", "A1", "x_y.z", long)
  blk <- b6_parse(do.call(weft::weft_put, args))
  expect_setequal(names(blk$values), names(args))
})

# ---- E40, E41, E43 ---------------------------------------------------------------

test_that("E40: an unnamed argument that is not a symbol is refused", {
  expect_error(weft::weft_put(1 + 2), class = "weft_values_error")
  expect_error(weft::weft_put("a"), class = "weft_values_error")
  expect_error(weft::weft_put(n = 1, mean(c(1, 2))), class = "weft_values_error")
  e <- err_of(weft::weft_put(nrow(data.frame(a = 1))))
  expect_s3_class(e, "weft_error")
  expect_match(conditionMessage(e), "weft_put() takes named arguments or names", fixed = TRUE)
  expect_match(conditionMessage(e), "weft_put(n = nrow(d)) or weft_put(n)", fixed = TRUE)
})

test_that("E41: a name that is not a NAME is refused, with the name in the message", {
  bad <- c("1a", "a-b", "a b", "café", "a.", paste0("a", strrep("b", 64)))
  for (nm in bad) {
    args <- list(1L)
    names(args) <- nm
    e <- err_of(do.call(weft::weft_put, args))
    expect_s3_class(e, "weft_values_error")
    expect_match(conditionMessage(e), "is not a name weft can publish", fixed = TRUE)
    expect_match(conditionMessage(e), "ASCII letters, digits, _ and ., starting with a letter or _",
                 fixed = TRUE)
    expect_match(conditionMessage(e), nm, fixed = TRUE)
  }
})

test_that("E41: the reserved words of N6 are not names", {
  for (nm in c("TRUE", "FALSE", "True", "False", "true", "false", "NA", "NULL", "None",
               "nothing", "missing", "Inf", "NaN")) {
    args <- list(1L)
    names(args) <- nm
    expect_error(do.call(weft::weft_put, args), class = "weft_values_error", info = nm)
  }
  # control: a word that only starts like one is a name
  expect_no_error(weft::weft_put(NAN = 1, nothing_else = 1, Infinity = 1))
})

test_that("E41: an unnamed symbol that is not a NAME is refused the same way", {
  `a-b` <- 1
  e <- err_of(weft::weft_put(`a-b`))
  expect_s3_class(e, "weft_values_error")
  expect_match(conditionMessage(e), "is not a name weft can publish", fixed = TRUE)
})

test_that("E43: a name given twice in one call is refused", {
  e <- err_of(weft::weft_put(n = 1, n = 2))
  expect_s3_class(e, "weft_values_error")
  expect_match(conditionMessage(e), "is given twice in one weft_put() call", fixed = TRUE)
  expect_match(conditionMessage(e), "n", fixed = TRUE)
  n <- 3
  expect_error(weft::weft_put(n, n = 2), class = "weft_values_error")
  expect_error(weft::weft_put(n, n), class = "weft_values_error")
})

test_that("E40 to E44: a call with one refused argument is refused as a whole", {
  expect_error(weft::weft_put(good = 1, `bad-name` = 2), class = "weft_values_error")
  expect_error(weft::weft_put(good = 1, 2 + 2), class = "weft_values_error")
  expect_error(weft::weft_put(good = 1, u = units::set_units(1, "m")), class = "weft_values_error")
})

# ---- N41: claim() in weft_put() ----------------------------------------------------

test_that("N41: a failing claim() argument is recorded on the value, and nothing is raised", {
  n <- 5
  expect_no_error(x <- weft::weft_put(n = claim(n, . > 10)))
  expect_no_warning(weft::weft_put(n = claim(n, . > 10)))
  rec <- b6_parse(x)$values$n
  expect_identical(rec$t, "float")
  expect_identical(rec$v, "5")
  expect_length(rec$checks, 1L)
  chk <- rec$checks[[1]]
  expect_identical(chk$text, ". > 10")
  expect_identical(chk$ok, FALSE)
  expect_true(is.null(chk$level) || identical(chk$level, "fail"))
  expect_true(is.null(chk$why) || is.character(chk$why))
})

test_that("N41: a passing check has ok true", {
  n <- 50
  rec <- b6_parse(weft::weft_put(n = claim(n, . > 10)))$values$n
  expect_length(rec$checks, 1L)
  expect_identical(rec$checks[[1]]$ok, TRUE)
  expect_identical(rec$checks[[1]]$text, ". > 10")
})

test_that("N41/N23: each check is its own object, in order, with its own outcome", {
  n <- 50
  lim <- 100
  rec <- b6_parse(weft::weft_put(n = claim(n, . > 10, . < lim, . %% 2 == 1)))$values$n
  expect_length(rec$checks, 3L)
  texts <- vapply(rec$checks, function(ch) ch$text, "")
  expect_identical(texts, c(". > 10", ". < lim", ". %% 2 == 1"))
  oks <- vapply(rec$checks, function(ch) isTRUE(ch$ok), NA)
  expect_identical(oks, c(TRUE, TRUE, FALSE))
})

test_that("N41: the check text is the check as written, a vector value is checked as a whole", {
  rec <- b6_parse(weft::weft_put(v = claim(c(3, 4), sum(.) == 7, all(. > 0))))$values$v
  expect_identical(rec$t, "list")
  texts <- vapply(rec$checks, function(ch) ch$text, "")
  expect_identical(texts, c("sum(.) == 7", "all(. > 0)"))
  expect_true(all(vapply(rec$checks, function(ch) isTRUE(ch$ok), NA)))
})

test_that("N41: level = \"warn\" is recorded as level warn, and nothing is raised or warned", {
  n <- 5
  expect_no_warning(x <- weft::weft_put(n = claim(n, . > 10, level = "warn")))
  chk <- b6_parse(x)$values$n$checks[[1]]
  expect_identical(chk$level, "warn")
  expect_identical(chk$ok, FALSE)
})

test_that("N41: `weft::claim()` is captured as `claim()` is", {
  n <- 5
  rec <- b6_parse(weft::weft_put(n = weft::claim(n, . > 10)))$values$n
  expect_length(rec$checks, 1L)
  expect_identical(rec$checks[[1]]$ok, FALSE)
})

test_that("N41/N23: a check that does not give a single TRUE, or raises, is not ok and is not raised", {
  n <- 5
  rec <- b6_parse(weft::weft_put(n = claim(n, c(TRUE, TRUE), stop("boom"), "yes")))$values$n
  expect_length(rec$checks, 3L)
  for (ch in rec$checks) expect_false(isTRUE(ch$ok))
})

test_that("N41: a check on a missing value is recorded, the value is a missing record", {
  n <- NA_real_
  rec <- b6_parse(weft::weft_put(n = claim(n, . > 10)))$values$n
  expect_identical(rec$t, "missing")
  expect_length(rec$checks, 1L)
  expect_false(isTRUE(rec$checks[[1]]$ok))
})

test_that("N41: only an argument that is itself a claim() call is captured; claim() elsewhere raises as ever", {
  n <- 5
  # claim() inside a larger expression runs eagerly (2.4.2) and stops
  expect_error(weft::weft_put(n = claim(n, . > 10) + 1), class = "weft_claim_failed")
  # claim() outside weft_put() is unchanged
  expect_error(claim(5, . > 10), class = "weft_claim_failed")
  # control: a passing claim in a larger expression is fine and carries no check
  rec <- b6_parse(weft::weft_put(n = claim(50, . > 10) + 1))$values$n
  expect_identical(rec$v, "51")
  expect_length(rec$checks, 0L)
})

test_that("N41: a value with no claim carries no checks", {
  rec <- b6_parse(weft::weft_put(n = 5))$values$n
  expect_length(rec$checks, 0L)
})

# ---- N48: run id -------------------------------------------------------------------

make_run_tree <- function(depth = 2, line = "run-abc", extra = NULL) {
  root <- normalizePath(withr::local_tempdir(.local_envir = parent.frame()))
  dir.create(file.path(root, ".weft"))
  writeLines(c(line, extra), file.path(root, ".weft", "run"))
  here <- root
  for (i in seq_len(depth)) {
    here <- file.path(here, paste0("d", i))
    dir.create(here)
  }
  list(root = root, here = here)
}

test_that("N48: the run is the first line of .weft/run found walking up from the folder", {
  tr <- make_run_tree(depth = 2, line = "run-abc", extra = "second line")
  withr::local_dir(tr$here)
  withr::local_envvar(c(WEFT_RUN = "from-env"))
  expect_identical(b6_parse(weft::weft_put(a = 1))$run, "run-abc")
})

test_that("N48: without a file, WEFT_RUN is used when set and not empty", {
  dir <- withr::local_tempdir()
  withr::local_dir(dir)
  withr::local_envvar(c(WEFT_RUN = "env-run-7"))
  expect_identical(b6_parse(weft::weft_put(a = 1))$run, "env-run-7")
})

test_that("N48: without a file, and with WEFT_RUN unset or empty, the run is null", {
  dir <- withr::local_tempdir()
  withr::local_dir(dir)
  withr::local_envvar(c(WEFT_RUN = NA_character_))
  expect_null(b6_parse(weft::weft_put(a = 1))$run)
  withr::local_envvar(c(WEFT_RUN = ""))
  expect_null(b6_parse(weft::weft_put(a = 1))$run)
  expect_match(b6_text(weft::weft_put(a = 1)), "\"run\":null", fixed = TRUE)
})

test_that("N48: the file is searched upward only a few levels (at most 8)", {
  tr <- make_run_tree(depth = 12, line = "far-away")
  withr::local_dir(tr$here)
  withr::local_envvar(c(WEFT_RUN = NA_character_))
  expect_null(b6_parse(weft::weft_put(a = 1))$run)
})

test_that("N48: the run is read at each publish, never cached", {
  tr <- make_run_tree(depth = 1, line = "first")
  withr::local_dir(tr$here)
  withr::local_envvar(c(WEFT_RUN = NA_character_))
  expect_identical(b6_parse(weft::weft_put(a = 1))$run, "first")
  writeLines("second", file.path(tr$root, ".weft", "run"))
  expect_identical(b6_parse(weft::weft_put(a = 1))$run, "second")
  withr::local_envvar(c(WEFT_RUN = "e1"))
  unlink(file.path(tr$root, ".weft", "run"))
  expect_identical(b6_parse(weft::weft_put(a = 1))$run, "e1")
  withr::local_envvar(c(WEFT_RUN = "e2"))
  expect_identical(b6_parse(weft::weft_put(a = 1))$run, "e2")
})

# ---- N46: weft_values_write() --------------------------------------------------------

test_that("N46: weft_values_write() writes a values file and returns the path invisibly", {
  local_no_run()
  dir <- withr::local_tempdir()
  p <- file.path(dir, "survey.json")
  r <- withVisible(weft::weft_values_write(p, n = 3L, depth = 1.5, site = "north"))
  expect_false(r$visible)
  expect_identical(r$value, p)
  expect_true(file.exists(p))
})

test_that("N46/N30: the file is a bare schema-1 JSON object, lang r, with the records of N47", {
  local_no_run()
  dir <- withr::local_tempdir()
  p <- file.path(dir, "survey.json")
  before <- as.numeric(Sys.time())
  weft::weft_values_write(p, n = 3L, depth = 1.5, site = "north", when = as.Date("2026-11-13"))
  after <- as.numeric(Sys.time())
  txt <- paste(readLines(p, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  expect_true(jsonlite::validate(txt))
  expect_true(startsWith(trimws(txt), "{"))
  expect_false(grepl("weft-values", txt, fixed = TRUE))
  blk <- b6_read_json(txt)
  expect_identical(blk$weft, 1L)
  expect_identical(blk$lang, "r")
  expect_null(blk$run)
  expect_true(blk$at >= floor(before) - 1 && blk$at <= ceiling(after) + 1)
  expect_identical(b6_core(blk$values$n), b6_e_int("3"))
  expect_identical(b6_core(blk$values$depth), b6_e_float("1.5"))
  expect_identical(b6_core(blk$values$site), b6_e_str("north"))
  expect_identical(b6_core(blk$values$when), b6_e_date("2026-11-13"))
  keys <- b6_keys(txt)
  expect_identical(keys[1:2], c("weft", "lang"))
})

test_that("N46: the same arguments as weft_put(): names, symbols, claim(), and the same refusals", {
  local_no_run()
  dir <- withr::local_tempdir()
  p <- file.path(dir, "v.json")
  depth <- 2.5
  n <- 5
  weft::weft_values_write(p, depth, k = claim(n, . > 10))
  blk <- b6_read_json(paste(readLines(p, warn = FALSE), collapse = "\n"))
  expect_setequal(names(blk$values), c("depth", "k"))
  expect_identical(blk$values$k$checks[[1]]$text, ". > 10")
  expect_identical(blk$values$k$checks[[1]]$ok, FALSE)
  expect_error(weft::weft_values_write(p, 1 + 2), class = "weft_values_error")
  expect_error(weft::weft_values_write(p, `a-b` = 1), class = "weft_values_error")
  expect_error(weft::weft_values_write(p, n = 1, n = 2), class = "weft_values_error")
  expect_error(weft::weft_values_write(p, u = units::set_units(1, "m")), class = "weft_values_error")
})

test_that("N46: no values gives an empty object, not an empty array", {
  local_no_run()
  dir <- withr::local_tempdir()
  p <- file.path(dir, "empty.json")
  weft::weft_values_write(p)
  txt <- paste(readLines(p, warn = FALSE), collapse = "\n")
  expect_true(jsonlite::validate(txt))
  expect_match(txt, "\"values\":{}", fixed = TRUE)
})

test_that("N46: the file is UTF-8 with LF line endings and no byte order mark", {
  local_no_run()
  dir <- withr::local_tempdir()
  p <- file.path(dir, "u.json")
  s <- "café − 5 ± 1"
  weft::weft_values_write(p, s = s, n = 1L)
  bytes <- readBin(p, "raw", file.size(p))
  expect_false(identical(bytes[1:3], as.raw(c(0xEF, 0xBB, 0xBF))))
  expect_false(as.raw(13) %in% bytes)
  txt <- rawToChar(bytes)
  expect_true(validUTF8(txt))
  Encoding(txt) <- "UTF-8"
  expect_identical(b6_read_json(txt)$values$s$v, s)
})

test_that("N46: a second write replaces the file as a whole", {
  local_no_run()
  dir <- withr::local_tempdir()
  p <- file.path(dir, "v.json")
  weft::weft_values_write(p, old = 1L, shared = "first")
  weft::weft_values_write(p, shared = "second", fresh = TRUE)
  blk <- b6_read_json(paste(readLines(p, warn = FALSE), collapse = "\n"))
  expect_setequal(names(blk$values), c("shared", "fresh"))
  expect_identical(blk$values$shared$v, "second")
})

test_that("N46: writing is atomic: a successful write leaves no other file, a refused one leaves the old file untouched", {
  local_no_run()
  dir <- withr::local_tempdir()
  p <- file.path(dir, "v.json")
  weft::weft_values_write(p, a = 1L)
  expect_identical(list.files(dir, all.files = TRUE, no.. = TRUE), "v.json")
  old <- readBin(p, "raw", file.size(p))

  expect_error(weft::weft_values_write(p, `bad-name` = 2L), class = "weft_values_error")
  expect_error(weft::weft_values_write(p, u = units::set_units(2, "m")), class = "weft_values_error")
  expect_identical(readBin(p, "raw", file.size(p)), old)
  expect_identical(list.files(dir, all.files = TRUE, no.. = TRUE), "v.json")

  # a refused first write makes no file at all
  q <- file.path(dir, "never.json")
  expect_error(weft::weft_values_write(q, 1 + 1), class = "weft_values_error")
  expect_false(file.exists(q))
  expect_identical(sort(list.files(dir, all.files = TRUE, no.. = TRUE)), c("v.json"))
})

test_that("N46: a relative path is relative to the working directory", {
  local_no_run()
  dir <- normalizePath(withr::local_tempdir())
  withr::local_dir(dir)
  weft::weft_values_write("rel.json", a = 1L)
  expect_true(file.exists(file.path(dir, "rel.json")))
})

test_that("N46/N48: `run` comes from .weft/run, and from WEFT_RUN when there is no file", {
  tr <- make_run_tree(depth = 1, line = "run-file-1")
  withr::local_dir(tr$here)
  withr::local_envvar(c(WEFT_RUN = "run-env"))
  p <- file.path(tr$here, "v.json")
  weft::weft_values_write(p, a = 1L)
  expect_identical(b6_read_json(paste(readLines(p, warn = FALSE), collapse = "\n"))$run, "run-file-1")
  unlink(file.path(tr$root, ".weft", "run"))
  weft::weft_values_write(p, a = 1L)
  expect_identical(b6_read_json(paste(readLines(p, warn = FALSE), collapse = "\n"))$run, "run-env")
})
