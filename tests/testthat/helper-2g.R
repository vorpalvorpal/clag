# Helpers for the 2g tests (weft's default units). Contract: dev/design-2g.md.
# "~" in an expected string stands for U+00A0 (f2()). Non-ASCII is written as \uXXXX.
# The `units` database is session-global: a test that reads a configuration restores the
# default state (weft mode, no project rows) when it ends (g2_restore()).

# Source a helper that lives in tests/testthat/ when its function is not defined yet, whether
# the file runs from _2g/ or after it has been moved up.
g2_need <- function() {
  need <- c(f2_ws = "helper-2f.R", expect_qty = "helper-2a.R", render_rmd = "helper-render.R")
  for (i in seq_along(need)) {
    if (!exists(names(need)[i])) {
      p <- Filter(file.exists, c(testthat::test_path(need[[i]]), testthat::test_path("..", need[[i]])))
      if (length(p)) source(p[[1]], local = globalenv())
    }
  }
}
g2_need()

G2_ENDASH <- "–"
G2_DEG <- "°"

# the default state, now and when the calling test ends
g2_restore <- function(env = parent.frame()) {
  withr::local_envvar(WEFT_DRAFT = NA, .local_envir = env)
  withr::defer(weft:::read_config(f2_proj()), envir = env)
  invisible(NULL)
}

# read a configuration (project yml lines and/or front-matter list) as a console session would;
# the default state comes back when the calling test ends
g2_cfg <- function(yml = NULL, front = list(), env = parent.frame()) {
  g2_restore(env)
  weft:::read_config(f2_proj(yml, env = env), front = front)
}

# the condition a configuration read raises, or NULL; the default state comes back afterwards
g2_cfg_err <- function(yml = NULL, front = list(), env = parent.frame()) {
  g2_restore(env)
  f2_cond(weft:::read_config(f2_proj(yml, env = env), front = front))
}

# u(n, "<token>") for a token held in a string
g2_u <- function(n, token) eval(bquote(u(.(n), .(token))))

# the printed text of a quantity under the three forms and a conversion
g2_num <- function(x, ...) f2_tx(fmt_num(x, ...))
g2_nm <- function(x) f2_tx(fmt_num(x, unit_form = "name"))
g2_cv <- function(x, unit) f2_tx(fmt_num(x, unit = unit))

# a conversion factor of one unit string to another through units, NA if it does not convert
g2_factor <- function(from, to) {
  tryCatch(as.numeric(units::set_units(units::set_units(1, from, mode = "standard"), to,
                                       mode = "standard")),
           error = function(e) NA_real_)
}

# what the units database currently says about a set of tokens: its factor to a set of targets
G2_TOKENS <- c("pH", "mph", "nmi", "Ma", "ka", "gal", "NTU", "PSU", "CFU", "MPN", "ppm", "Sv", "Hz", "Bq")
G2_TARGETS <- c("H", "m", "m/s^2", "m/s", "kg", "mi/h", "yr", "1", "J/kg", "Gy", "ha", "phot", "L", "s^-1")
g2_sig <- function(tokens = G2_TOKENS, targets = G2_TARGETS) {
  m <- outer(tokens, targets, Vectorize(g2_factor))
  dimnames(m) <- list(tokens, targets)
  m
}

# a dictionary with one quantity row
g2_dict_row <- function(unit, extra = "", value = 3, env = parent.frame()) {
  f2_dict_file(sprintf("q: {value: %s, type: quantity, unit: \"%s\"%s, definition: \"A thing.\"}",
                       value, unit, extra), env)
}

# lines of Rscript output as KEY=value
g2_kv <- function(out, key) {
  hit <- grep(paste0("^", key, "="), out, value = TRUE)
  if (!length(hit)) return(NA_character_)
  sub(paste0("^", key, "="), "", hit[[length(hit)]])
}

# run code in a fresh R session with the development weft loaded (not attached by the code itself);
# skipped on CRAN. Returns the lines the child printed.
g2_child <- function(body) {
  testthat::skip_on_cran()
  # under R CMD check the package is installed and has no source folder to load
  testthat::skip_if_not(weft_is_dev(), "needs the development copy of weft")
  root <- weft_pkg_root()
  code <- paste0("suppressMessages(pkgload::load_all(", deparse(root), ", quiet = TRUE, helpers = FALSE))\n",
                 "options(warn = 1)\n", body)
  suppressWarnings(system2(file.path(R.home("bin"), "Rscript"),
                           c("--no-save", "--no-restore", "-e", shQuote(code)),
                           stdout = TRUE, stderr = TRUE))
}

# a test per table row: weft_str() of `src` in a project with `yml` prints `want`
g2_row <- function(src, want, yml = NULL, mode = "weft") {
  force(src); force(want); force(yml)
  testthat::test_that(sprintf("2g 4.4.21 table (%s): %s prints %s", mode, src, want), {
    g2_restore()
    testthat::expect_equal(f2_ws(src, yml), f2(want))
  })
}

# a test per table row that is a value error from weft_str()
g2_row_err <- function(src, yml = NULL, mode = "weft", class = "weft_value_error", has = NULL) {
  force(src); force(yml)
  testthat::test_that(sprintf("2g 4.4.21 table (%s): %s is a %s", mode, src, class), {
    g2_restore()
    e <- f2_err(src, yml)
    f2_has_class(e, class)
    if (!is.null(has)) f2_msg_has(e, has)
  })
}
