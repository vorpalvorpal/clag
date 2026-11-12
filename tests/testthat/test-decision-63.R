# Decision 63 (dev/decisions.md): four small decided items. ASCII only. Made-up values only.
if (!exists("i2_text")) source(Filter(file.exists, c(testthat::test_path("helper-2i.R"), testthat::test_path("..", "helper-2i.R")))[[1]])
if (!exists("cl_units_clean")) source(Filter(file.exists, c(testthat::test_path("helper-closing.R"), testthat::test_path("..", "helper-closing.R")))[[1]])

# ---- W1: the units cache is on disk by default --------------------------------------------------------------

# a fresh cache folder, no package-check variable, and an empty session copy; restored when the test ends
w1_fresh <- function(env = parent.frame()) {
  cache <- withr::local_tempdir(.local_envir = env)
  withr::local_envvar(R_USER_CACHE_DIR = cache, "_R_CHECK_PACKAGE_NAME_" = NA, .local_envir = env)
  uc <- weft:::un_cache
  tb <- uc$tables
  tbk <- uc$tables_key
  withr::defer({ uc$tables <- tb; uc$tables_key <- tbk }, envir = env)
  uc$tables <- NULL
  invisible(cache)
}

w1_disk_files <- function(cache) list.files(cache, recursive = TRUE)

test_that("decision 63 W1: with weft.units_cache unset, the disk copy is written", {
  cache <- w1_fresh()
  withr::local_options(weft.units_cache = NULL)
  a <- weft:::ud_tables()
  expect_true(is.data.frame(a$v) && is.data.frame(a$pf))
  key <- weft:::ud_tables_key()
  skip_if(is.null(key))
  f <- weft:::ud_tables_file(key)
  expect_true(file.exists(f))
  expect_true(startsWith(normalizePath(f, mustWork = FALSE), normalizePath(cache)))
})

test_that("decision 63 W1: with weft.units_cache unset, a new session reads the disk copy back", {
  w1_fresh()
  uc <- weft:::un_cache
  withr::local_options(weft.units_cache = NULL)
  a <- weft:::ud_tables()
  key <- weft:::ud_tables_key()
  skip_if(is.null(key))
  expect_true(file.exists(weft:::ud_tables_file(key)))
  uc$tables <- NULL
  expect_identical(weft:::ud_tables()$v, a$v)
})

test_that("decision 63 W1: weft.units_cache = FALSE writes nothing to disk", {
  cache <- w1_fresh()
  withr::local_options(weft.units_cache = FALSE)
  a <- weft:::ud_tables()
  expect_true(is.data.frame(a$v))                    # still answered, from the read
  key <- weft:::ud_tables_key()
  skip_if(is.null(key))
  expect_false(file.exists(weft:::ud_tables_file(key)))
  expect_identical(w1_disk_files(cache), character())
})

test_that("decision 63 W1: weft.units_cache = FALSE does not read a copy that is on disk", {
  cache <- w1_fresh()
  uc <- weft:::un_cache
  withr::local_options(weft.units_cache = TRUE)
  a <- weft:::ud_tables()
  key <- weft:::ud_tables_key()
  skip_if(is.null(key))
  f <- weft:::ud_tables_file(key)
  expect_true(file.exists(f))                        # control: written under TRUE
  # put a marker in the copy; a read from disk would return it, a read of the database would not
  planted <- a
  planted$v <- a$v[0L, , drop = FALSE]
  saveRDS(planted, f)
  uc$tables <- NULL
  withr::local_options(weft.units_cache = FALSE)
  expect_identical(weft:::ud_tables()$v, a$v)
  # and under TRUE the planted copy is the one read (so the test above tells the two apart)
  uc$tables <- NULL
  withr::local_options(weft.units_cache = TRUE)
  b <- weft:::ud_tables()
  skip_if(identical(b$v, a$v), "the copy on disk is not read back as saved, so the planted marker cannot be told")
  expect_identical(nrow(b$v), 0L)
})

test_that("decision 63 W1 control: weft.units_cache = TRUE writes the disk copy, as before", {
  w1_fresh()
  withr::local_options(weft.units_cache = TRUE)
  weft:::ud_tables()
  key <- weft:::ud_tables_key()
  skip_if(is.null(key))
  expect_true(file.exists(weft:::ud_tables_file(key)))
})

test_that("decision 63 W1: a package check's variable still stops the disk copy writing", {
  cache <- w1_fresh()
  withr::local_envvar("_R_CHECK_PACKAGE_NAME_" = "weft")
  withr::local_options(weft.units_cache = NULL)
  weft:::ud_tables()
  expect_identical(w1_disk_files(cache), character())
})

test_that("decision 63 W1: during the tests the user cache folder is a temporary one (setup-cache.R)", {
  d <- normalizePath(tools::R_user_dir("weft", "cache"), mustWork = FALSE)
  home_cache <- normalizePath(file.path("~", "Library", "Caches"), mustWork = FALSE)
  expect_false(startsWith(d, file.path(home_cache, "org.R-project.R")))
  expect_false(startsWith(d, normalizePath(file.path("~", ".cache"), mustWork = FALSE)))
  tmp_parent <- normalizePath(dirname(tempdir()), mustWork = FALSE)
  expect_true(startsWith(d, tmp_parent) || startsWith(d, dirname(tempdir())))
})

# ---- W2: dict_unmark is exported ----------------------------------------------------------------------------

test_that("decision 63 W2: dict_unmark is exported", {
  expect_true("dict_unmark" %in% getNamespaceExports("weft"))
})

test_that("decision 63 W2: a target made by tar_dict_deps() calls weft::dict_unmark, not weft:::dict_unmark", {
  testthat::skip_if_not_installed("targets")
  testthat::skip_on_cran()
  d <- e1_tmp()
  e1_dict(d)
  withr::local_dir(d)
  res <- weft::tar_dict_deps(list(targets::tar_target(w2y, dict$a + 1)))
  tg <- Filter(function(t) identical(t$settings$name, "w2y"), res)
  expect_length(tg, 1L)
  cmd <- paste(deparse(tg[[1L]]$command$expr), collapse = "\n")
  expect_true(grepl("weft::dict_unmark", cmd, fixed = TRUE))
  expect_false(grepl("weft:::dict_unmark", cmd, fixed = TRUE))
})

# ---- W3: a compound prints as typed, names included ----------------------------------------------------------

# W3 passes or fails today as the code stands; where it passes it documents the rule
test_that("decision 63 W3: a compound prints as typed, with a name in it", {
  expect_equal(i2_text('`r u(5, "kilometre/hr")`{.num}'), f2("5~kilometre/hr"))
  expect_equal(i2_text('`r u(5, "km/hour")`{.num}'), f2("5~km/hour"))
})

test_that("decision 63 W3 control: a lone name prints as its symbol", {
  expect_equal(i2_text('`r u(5, "kilometre")`{.num}'), f2("5~km"))
})

# ---- W4: units a dictionary registers go with the project ------------------------------------------------------

# weft_str() wraps what an evaluation raises (class weft_no_value) and keeps its message, so a refusal is
# a weft_unit_error itself, or an error whose message is u()'s "not a unit the units database knows"
w4_refused <- function(e) {
  !is.null(e) && (inherits(e, "weft_unit_error") ||
    grepl("is not a unit the units database knows", conditionMessage(e), fixed = TRUE))
}

W4_SRC <- "`r u(3, zzdu)`{.num}"
W4_B <- c("units:", "  zzdu:", "    is: 2 m")

w4_dict <- function(env = parent.frame()) {
  f2_dict_file("zzd: {value: 3, type: quantity, unit: zzdu, definition: \"A made-up unit.\"}", env = env)
}

test_that("decision 63 W4: a unit project A's dictionary registered is unknown in project E", {
  cl_units_clean()
  d <- weft::read_dict(w4_dict())
  expect_identical(attr(d, "registered"), "zzdu")        # control: A registered it
  expect_silent(units::as_units("zzdu"))
  r <- i2_run(W4_SRC)                                    # project E, no such unit
  expect_false(is.null(r$e))
  expect_true(w4_refused(r$e))
})

test_that("decision 63 W4: project B defining the same unit in _weft.yml reads without error after A", {
  cl_units_clean()
  weft::read_dict(w4_dict())
  r <- i2_run(W4_SRC, W4_B)
  expect_null(r$e)
})

test_that("decision 63 W4 control: a unit nobody registered is refused in E, and accepted where _weft.yml defines it", {
  cl_units_clean()
  src <- "`r u(3, zzdc)`{.num}"
  r <- i2_run(src)
  expect_true(w4_refused(r$e))
  expect_null(i2_run(src, c("units:", "  zzdc:", "    is: 2 m"))$e)
})

test_that("decision 63 W4: within one project a dictionary's unit outlives weft_str() and a re-read of the configuration", {
  cl_units_clean()
  withr::defer(cl_units_clean())
  dir <- f2_proj()
  writeLines("zzs: {value: 3, type: quantity, unit: zzsame, definition: \"A made-up unit.\"}", file.path(dir, "dict.yml"))
  withr::with_dir(dir, {
    d <- weft::read_dict("dict.yml")
    expect_identical(attr(d, "registered"), "zzsame")
    for (i in 1:2) expect_null(tryCatch({ weft_str("`r u(3, zzsame)`{.num}"); NULL }, error = function(e) e))
    weft:::read_config(dir)
    expect_silent(units::as_units("zzsame"))
    expect_null(tryCatch({ u(3, zzsame); NULL }, error = function(e) e))
  })
})
