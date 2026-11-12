# Helpers for the 3c tests (the code and construct lints). Contract: dev/design-3.md.
# Builds on helper-3.R (lint_one(), lint_proj(), lf_*). ASCII only.

# the 3c rule ids and their tiers (design section 1 / L22-L28, L34)
R3C_TIER <- c("literal-value" = 1L, "inert-check" = 1L,
              "value-constant" = 2L, "value-format" = 2L,
              "lone-bar" = 2L, "if-zero" = 2L, "name" = 2L,
              "tar-name" = 1L, "dict-assign" = 1L, "dict-key" = 1L,
              "tar-cache" = 1L, "above-setup" = 1L)

# a paragraph between two others: the construct sits on line 3
c3_para <- function(...) c("Some prose before.", "", c(...), "", "Some prose after.")

# the `text` of each finding of `rule` over `lines` as one document of extension `ext`
c3_texts <- function(lines, rule, ext = "qmd", ...) {
  x <- lint_one(lines, rules = rule, ext = ext, ...)
  x$text[x$rule == rule]
}

# Expect the findings' `text` of `rule` over `lines` to be exactly `want` (order ignored,
# duplicates kept), under every extension in `ext`.
expect_c3 <- function(lines, rule, want = character(), ext = c("qmd", "Rmd"), label = NULL, ...) {
  if (is.null(label)) label <- paste(lines, collapse = " / ")
  for (e in ext) {
    got <- c3_texts(lines, rule, e, ...)
    testthat::expect_identical(sort(got), sort(as.character(want)),
                               label = sprintf("[%s] %s texts for: %s", e, rule, label))
  }
}

# a table of cases (list of list(src =, want =)) each inside a paragraph
expect_c3_cases <- function(cases, rule, ext = c("qmd", "Rmd")) {
  for (cs in cases) expect_c3(c3_para(cs$src), rule, cs$want, ext = ext, label = cs$src)
}

# front matter holding `abstract` as a block scalar (so constructs are allowed there)
c3_abstract <- function(...) c("---", "title: T", "abstract: |", paste0("  ", c(...)), "---", "", "Body.")

# a chunk with `#|` options
c3_chunk <- function(code, ..., engine = "r") {
  opts <- c(...)
  c(paste0("```{", engine, "}"), opts, code, "```")
}

# Build a real targets store under `root/<store>` holding the targets `names`, without
# running anything the lints may later run: the pipeline is a script named build-<store>.R
# (not _targets.R). Needs `targets`; skips otherwise.
c3_store <- function(root, names = c("fit", "dat"), store = "_targets", env = parent.frame()) {
  testthat::skip_if_not_installed("targets")
  testthat::skip_on_cran()
  script <- file.path(root, paste0("build-", gsub("[^A-Za-z0-9]", "", store), ".R"))
  writeLines(c("library(targets)",
               paste0("list(", paste0("tar_target(", names, ", 1L)", collapse = ", "), ")")), script)
  # a fresh R process (the default callr_function), so no object of the test session
  # becomes a target dependency
  withr::with_dir(root, targets::tar_make(script = script, store = store, reporter = "silent"))
  invisible(file.path(root, store))
}

# the dictionary file used by the dict-key tests: top-level keys `limit` and `sites`
C3_DICT <- c("limit:", "  value: 5", "sites:", "  value: 12")
