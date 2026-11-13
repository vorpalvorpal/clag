# Helpers for the 2i tests (fixes from the stage 2 trial). Contract: dev/design-2i.md I1-I14.
# "~" in an expected string stands for U+00A0 (f2()). Non-ASCII is written as \uXXXX. Made-up values only.
# The `units` database is session-global: a test that installs a unit of its own uses a made-up
# token unique to that test, and the tokens may not end in a digit.

if (!exists("h2_row")) {
  p <- Filter(file.exists, c(testthat::test_path("helper-2h.R"), testthat::test_path("..", "helper-2h.R")))
  if (length(p)) source(p[[1]], local = globalenv())
}
h2_need()

# weft_str() of `src` run in an empty project (or one with `yml`); the text with U+00A0, the
# warnings it raised (as condition objects) and the error it raised, if any
i2_run <- function(src, yml = NULL) {
  h2_restore(parent.frame())
  ws <- list()
  err <- NULL
  v <- withCallingHandlers(
    tryCatch(f2_ws(src, yml), error = function(e) { err <<- e; NA_character_ }),
    warning = function(w) { ws[[length(ws) + 1L]] <<- w; invokeRestart("muffleWarning") })
  list(v = v, w = ws, e = err)
}

i2_unit_warnings <- function(r) Filter(function(w) inherits(w, "weft_unit_warning"), r$w)

# the text printed, with an error shown as "ERROR: class: message"
i2_text <- function(src, yml = NULL) {
  r <- i2_run(src, yml)
  if (!is.null(r$e)) paste0("ERROR: ", class(r$e)[1], ": ", conditionMessage(r$e)) else r$v
}

# `r <value>`{<attrs>}
i2_cx <- function(value, attrs) paste0("`r ", value, "`{", attrs, "}")

# a project unit with a name and no symbol (a count noun)
I2_SITE <- c("units:", "  zzsite:", "    name: site")

# ---- changes() fixtures ------------------------------------------------------------------------------------

# the lines of print(x, ...)
i2_print <- function(x, ...) capture.output(print(x, ...))

# the design's big project (as test-changes.R builds it): a structural arm change, a crossing of 1.0, a
# claim word, an added and a removed entry, a new condition, a new ledger and a ledger whose source is gone
i2_big_project <- function(env = parent.frame()) {
  dir <- e2x_project(env = env)
  s_b <- "The mean ratio was 0.98, below the limit."
  s_a <- "The mean ratio was 1.04."
  survey_b <- list(
    e2x_entry("ratio < dict$limit", ", below the limit", kind = "if", section = "quality", arm = "true",
              dict = "dict$limit", sentence = s_b),
    e2x_entry("ratio", "0.98", section = "quality", id = "ratio", raw = 0.98, sentence = s_b),
    e2x_entry("n_obs", "40", raw = 40, sentence = "There are 40 rows."))
  survey_a <- list(
    e2x_entry("ratio < dict$limit", "", kind = "if", section = "quality", dict = "dict$limit", sentence = s_a),
    e2x_entry("ratio", "1.04", section = "quality", id = "ratio", raw = 1.04, sentence = s_a),
    e2x_entry("n_obs", "40", raw = 40, sentence = "There are 40 rows."))
  water_b <- list(
    e2x_entry("n_sites", "14", kind = "bare", raw = 14, sentence = "All 14 sites were visited."),
    e2x_entry("median(flow)", "2.9 ML/d", section = "flow", sentence = "The median was 2.9 ML/d."))
  water_a <- list(
    e2x_entry("n_sites", "15", kind = "bare", raw = 15, sentence = "All 15 sites were visited."),
    e2x_entry("max(flow)", "12 ML/d", section = "flow", sentence = "Peak flow was 12 ML/d."))
  e2x_put_ledger(dir, "reports/survey.qmd", survey_b, output = "survey")
  e2x_put_ledger(dir, "reports/water.qmd", water_b, output = "site-a")
  e2x_put_ledger(dir, "reports/sites-2023.qmd", list(e2x_entry("x", "1")), output = "sites-2023")
  e2x_commit(dir)
  e2x_put_ledger(dir, "reports/survey.qmd", survey_a, output = "survey",
                 files = c("reports/survey.qmd" = "0000000000000000"),
                 conds = list(e2x_cond("fit", "Model failed to converge with max|grad| = 0.0021.", from = "target",
                                       normalised = "Model failed to converge with max|grad| = <n>")))
  e2x_put_ledger(dir, "reports/water.qmd", water_a, output = "site-a")
  e2x_put_ledger(dir, "reports/flow.qmd", list(e2x_entry("p", "1"), e2x_entry("q", "2"), e2x_entry("r", "3")),
                 output = "flow")
  unlink(file.path(dir, "reports", "sites-2023.qmd"))
  dir
}

I2_SECTIONS <- c("Not re-rendered", "Structural changes", "Other changes, ranked", "Added", "Removed",
                 "New conditions", "Ledgers")
