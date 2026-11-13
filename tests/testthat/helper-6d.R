# Helpers for the package 6d tests (the static side of named values, rules N140 to N150 of
# dev/design-6.md; messages E1 to E6, E9, E70 to E75). They sit beside helper-3.R, helper-3d.R,
# helper-4a.R, helper-4d.R and helper-6k.R and reuse lint_one(), lint_fixture(), lint_proj(), f3_write(),
# f3d_doc(), g_scenario(), g_gate(), u4_dir(), u4_use() and cc6k(). Nothing here reads R/ or inst/.
# Every project is a temporary folder; every git repository is a temporary one with git isolated by g_repo().
#
# THE INTERFACE THE TESTS FIX (the note leaves it open):
#  - a scanner row of a named value has kind "named", `expr` the NAME, and a column `resolver` ("filter" or
#    "hooks") on every row of weft:::scan_file(). The scanner is read through scan_file(path).
#  - findings are read through lints() (lint_one()): the rule `construct` for construct errors (message the
#    scanner's error, spec the first "rule x.y.z" of it, text the construct as written), `engine`,
#    `named-unpublished`, `publish-hidden`, `publish-hidden-auto`.
#
# ---- helpers here ------------------------------------------------------------------------------
#   w6d_doc(body, chunks, front)  the lines of a .qmd on the jupyter engine (front matter engine: jupyter)
#   w6d_py(...), w6d_jl(...), w6d_r(...)   the lines of a chunk of that engine (options first, as #| lines)
#   w6d_scan(lines, name, files)  weft:::scan_file() of a document in a fresh project
#   w6d_find(lines, rule, ...)    the findings of one rule for a document (rules = NULL, then filtered)
#   w6d_msgs(x)                   the messages of a findings frame
#   W6D_FILTER_YML                a _quarto.yml that lists the filter weft-check under filters:
#   W6D_E*                        the exact message texts of the design's section 7

W6D_FILTER_YML <- c("project:", "  type: default", "filters:", "  - weft-check")
W6D_PLAIN_YML <- c("project:", "  type: default")

w6d_doc <- function(body, chunks = character(), front = "engine: jupyter") {
  c("---", front, "---", "", body, if (length(chunks)) c("", chunks))
}

w6d_chunk <- function(engine, code, opts = character()) {
  c(paste0("```{", engine, "}"), if (length(opts)) paste0("#| ", opts), code, "```")
}
w6d_py <- function(code, opts = character()) w6d_chunk("python", code, opts)
w6d_jl <- function(code, opts = character()) w6d_chunk("julia", code, opts)
w6d_r <- function(code, opts = character()) w6d_chunk("r", code, opts)

# weft:::scan_file() of `lines` written as `name` in a fresh project holding `files` too
w6d_scan <- function(lines, name = "a.qmd", files = list(), env = parent.frame()) {
  root <- lint_proj(c(stats::setNames(list(lines), name), files), env = env)
  weft:::scan_file(file.path(root, name))
}

# the findings of `rule` for a document `lines` (written as `name`) in a project with `files`
w6d_find <- function(lines, rule, name = "a.qmd", files = list(), tier = 1:2, weft_yml = NULL,
                     env = parent.frame()) {
  x <- lint_fixture(c(stats::setNames(list(lines), name), files), rules = NULL, tier = tier,
                    weft_yml = weft_yml, env = env)
  lf_by_rule(x, rule)
}

w6d_msgs <- function(x) as.character(x$message)

# ---- the messages of section 7 -------------------------------------------------------------------

W6D_E1 <- function(text) {
  sprintf(paste0("`%s` is not a name, so it cannot carry a weft class: a named value holds one name. ",
                 "Bind the value to a name in code (rule 1.12.3)."), text)
}
W6D_E2 <- function(cls) {
  sprintf("`.val` prints a value as it is and cannot take `.%s` (rule 1.12.2).", cls)
}
W6D_E3 <- function(part) {
  sprintf(paste0("`%s` is not a name or one comparison of names, numbers and 'strings'; bind the condition ",
                 "to a name in code (rule 1.12.4)."), part)
}
W6D_E3_TAIL <- paste0("is not a name or one comparison of names, numbers and 'strings'; bind the condition ",
                       "to a name in code (rule 1.12.4).")
W6D_E4 <- function(part) {
  sprintf("`%s` compares two literals and has no name, so it is always the same (rule 1.12.4).", part)
}
W6D_E5 <- function(value, key) {
  extra <- switch(key, n = ", `.` or `#id`", sign = " or `#id`", list = "")
  sprintf("`%s` is not a name for `%s`; it takes a name%s (rule 1.12.6).", value, key, extra)
}
W6D_E6 <- function(id) {
  sprintf(paste0("`#%s` names an id on a named value, which the hooks cannot read; refer to an id of the ",
                 "same form (rule 1.12.10)."), id)
}
W6D_E9 <- function(key) {
  sprintf("A named value takes no `%s`: a governor key belongs on a span (rule 1.3.3).", key)
}
W6D_E70 <- function(name) {
  sprintf(paste0("`%s` is used by name but no chunk of this document mentions it; publish it with put(), ",
                 "weft_put() or @put (rule 5.12.1)."), name)
}
# {opt} is the option as written, with or without code marks (the note does not say which)
W6D_E71 <- function(label, opt) {
  c(sprintf(paste0("chunk `%s` has %s, so what it publishes never reaches the document; publish in a chunk ",
                   "that shows its output, with echo: false if the code should not show (rule 5.12.2)."),
            label, opt),
    sprintf(paste0("chunk `%s` has `%s`, so what it publishes never reaches the document; publish in a chunk ",
                   "that shows its output, with echo: false if the code should not show (rule 5.12.2)."),
            label, opt))
}
W6D_E72 <- function(label, opt) {
  c(sprintf(paste0("chunk `%s` calls auto() and has %s, so the names it sets are not published ",
                   "(rule 5.12.2)."), label, opt),
    sprintf(paste0("chunk `%s` calls auto() and has `%s`, so the names it sets are not published ",
                   "(rule 5.12.2)."), label, opt))
}
W6D_E73 <- paste0("Or write each value as a name, `x`{.num}, and publish it in code: then no knitr is needed ",
                  "(rule 1.12.7).")
W6D_E74 <- function(file) {
  sprintf("%s holds named values, and the filter weft.lua is not installed: run use_quarto() (rule 5.8.9).", file)
}
W6D_E75 <- "A document on another engine can use named values instead (rule 1.12.7)."
