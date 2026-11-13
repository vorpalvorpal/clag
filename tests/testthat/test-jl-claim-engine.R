# Package 6h: @claim on the julia engine (N55, N57, N58, N23, N25b, N86, N89; messages E15, E55 of
# dev/design-6.md section 7). Written before the code. Made-up values only. Helper: helper-julia-engine.R.
# Skipped when quarto or julia is absent. Three renders serve the file: a bare project (no filter, so the
# blocks stay in the HTML), a project set up by use_quarto() (the report), and one document with no
# `error: true` (the render stops).
#
# READINGS of the note (see the report, "Spec gaps"):
#  - N57 says the block is displayed and then ClaimFailed is thrown. MEASURED against
#    QuartoNotebookRunner 0.18.5: a `display()` made in a cell that then raises is NOT kept, even with
#    `error: true` (stdout is kept, and so is `output: asis` text). So the tests that need a block from a
#    cell that ENDS in the throw (labels f4 here, and the report of the filter's failed claim) are written
#    per the design and may not be satisfiable as N57 is worded; what they need is listed in the report.
#    The tests that catch ClaimFailed inside the cell (label f2), and the warned checks (no throw), do not
#    depend on this;
#  - the members of a check object after the ones N23 names, and whether passing checks of one call are in
#    the block, are not pinned; only the failed ones are read;
#  - the `expr` of a call with several checks or a level is pinned only by its start (N58 gives the
#    example `@claim n > 10` for the plain form);
#  - `why` of a check that did not give a Bool is read as containing `gave a {type}, not true or false`.

jle_kill_at_file_end()

CLAIM_PRE <- c("```{julia}", "#| include: false", "using Weft", "using Statistics", "```", "")

cell_jl <- function(label, ..., opts = character()) {
  c("```{julia}", paste0("#| label: ", label), "#| echo: false", opts, c(...), "```", "")
}

RAW_QMD <- c(
  "---", "title: Raw", "execute:", "  error: true", "---", "",
  CLAIM_PRE,
  cell_jl("w0", "n = 7"),
  cell_jl("w1", "@claim n > 10 level=:warn"),
  cell_jl("w2", "@claim mean([1.0, 2.0]) (_ > 0.5) (_ < 1) level=:warn"),
  cell_jl("w3", "@claim n (undefined_thing > 1) level=:warn"),
  cell_jl("w4", "@claim n (_ + 1) level=:warn"),
  cell_jl("w5",
          "for f in [\"other.md\", \"other.qmd\", \"other.ipynb\", \"other.jl\", \"other.txt\"]",
          "    include_string(@__MODULE__, \"\\n\\n@claim n > 10 level=:warn\", f)",
          "end"),
  cell_jl("f1", "@claim n > 1"),
  cell_jl("f2",
          "try",
          "    @claim n > 10",
          "catch e",
          "    println(\"caught \", e isa Weft.ClaimFailed)",
          "    println(sprint(showerror, e))",
          "end"),
  cell_jl("f4", "@claim n > 10"),
  "The end."
)

WARN_QMD <- c(
  "---", "title: Warn", "---", "",
  CLAIM_PRE,
  cell_jl("wc", "n = 7", "@claim n > 10 level=:warn"),
  "Some prose."
)

FAIL_QMD <- c(
  "---", "title: Fail", "---", "",
  CLAIM_PRE,
  cell_jl("chk", "n = 7", "@claim n > 10", opts = "#| error: true"),
  "Some prose."
)

STOP_QMD <- c(
  "---", "title: Stop", "---", "",
  CLAIM_PRE,
  cell_jl("stp", "n = 7", "@claim n > 10"),
  "Some prose."
)

raw_claims <- function() {
  if (!is.null(.jle$claim_raw)) return(.jle$claim_raw)
  dir <- jle_project(list(`raw.qmd` = RAW_QMD), filter = FALSE)
  res <- jle_render(dir, "raw.qmd")
  html <- jle_read(dir, "raw.html")
  cells <- jle_cells(html)
  .jle$claim_raw <- list(res = res, html = html, cells = cells)
}

claim_blocks <- function(label) {
  s <- raw_claims()
  jle_html_blocks(s$cells[[label]] %||% "")
}

failed_checks <- function(b) Filter(function(ch) isFALSE(ch$ok), b$checks)

ENV_CLAIM <- '^\\{"weft":1,"lang":"julia","run":null,"at":[0-9]+,'

test_that("control: the bare project renders, and the cells that ran are the cells written", {
  s <- raw_claims()
  expect_identical(s$res$status, 0L, label = s$res$log)
  expect_true(all(c("w1", "w2", "w3", "w4", "w5", "f1", "f2", "f4") %in% names(s$cells)), label = paste(names(s$cells), collapse = " "))
})

test_that("N57, N23: a warned claim displays one block with no values and one failed check, throws nothing, and returns the value", {
  s <- raw_claims()
  b <- claim_blocks("w1")
  expect_length(b$blocks, 1L)
  expect_match(b$texts, ENV_CLAIM)
  expect_match(b$texts, '"values":{}', fixed = TRUE)
  x <- blk(b, 1)
  expect_identical(as.integer(x$weft), 1L)
  expect_identical(x$lang, "julia")
  expect_length(x$values, 0L)
  ch <- failed_checks(x)
  expect_length(ch, 1L)
  ch <- ch[[1]]
  expect_identical(ch$text, "n > 10")
  expect_identical(ch$ok, FALSE)
  expect_identical(ch$level, "warn")
  expect_null(ch$why)
  expect_true(startsWith(ch$expr, "@claim n > 10"), label = ch$expr)
  expect_identical(list(ch$value$t, ch$value$v), list("int", "7"))
  # N57: the line of the macro call in the document
  expect_identical(as.integer(ch$line), as.integer(which(RAW_QMD == "@claim n > 10 level=:warn")))
  # nothing was thrown: the cell has no error output, and the value comes after the block
  cell <- s$cells[["w1"]]
  expect_false(grepl("cell-output-error", cell, fixed = TRUE))
  expect_true(grepl("<pre><code>7</code></pre>", cell, fixed = TRUE))
  expect_true(regexpr("weft-values", cell, fixed = TRUE) < regexpr("<pre><code>7</code></pre>", cell, fixed = TRUE))
})

test_that("N55, N57: each failed check of `@claim expr check...` is in the block, with the value of expr as a record", {
  b <- claim_blocks("w2")
  expect_length(b$blocks, 1L)
  ch <- failed_checks(blk(b, 1))
  expect_length(ch, 1L)
  expect_identical(ch[[1]]$text, "_ < 1")
  expect_identical(ch[[1]]$level, "warn")
  expect_identical(list(ch[[1]]$value$t, ch[[1]]$value$v), list("float", "1.5"))
  expect_true(grepl("^@claim mean\\(\\[1\\.0, 2\\.0\\]\\)", ch[[1]]$expr), label = ch[[1]]$expr)
})

test_that("N55, N57: a check that raises is a failed check whose why is `Type: message`; one that is not a Bool has a why of its own", {
  b3 <- blk(claim_blocks("w3"), 1)
  ch <- failed_checks(b3)
  expect_length(ch, 1L)
  expect_false(isTRUE(ch[[1]]$ok))
  expect_match(ch[[1]]$why, "^UndefVarError: ")
  expect_identical(ch[[1]]$level, "warn")
  b4 <- blk(claim_blocks("w4"), 1)
  ch <- Filter(function(c) !isTRUE(c$ok), b4$checks)
  expect_length(ch, 1L)
  expect_identical(ch[[1]]$text, "_ + 1")
  expect_true(grepl("gave a Int64, not true or false", ch[[1]]$why, fixed = TRUE), label = ch[[1]]$why)
})

test_that("N57: `line` is the line of the call when the source file ends .qmd, .md or .ipynb, else null", {
  b <- claim_blocks("w5")
  expect_length(b$blocks, 5L)
  line <- function(i) { ch <- failed_checks(blk(b, i)); if (length(ch)) ch[[1]]$line else NA }
  # the source is "\n\n@claim ..." : the call is on line 3 of the string
  expect_identical(as.integer(line(1)), 3L)
  expect_identical(as.integer(line(2)), 3L)
  expect_identical(as.integer(line(3)), 3L)
  expect_null(line(4))
  expect_null(line(5))
})

test_that("N57: the block is displayed before the throw, so a ClaimFailed caught in the cell still leaves it", {
  s <- raw_claims()
  b <- claim_blocks("f2")
  expect_length(b$blocks, 1L)
  ch <- failed_checks(blk(b, 1))
  expect_length(ch, 1L)
  expect_identical(ch[[1]]$text, "n > 10")
  expect_identical(ch[[1]]$expr, "@claim n > 10")
  expect_identical(ch[[1]]$level %||% "fail", "fail")
  expect_identical(list(ch[[1]]$value$t, ch[[1]]$value$v), list("int", "7"))
  expect_identical(jle_stdout_of(s$cells[["f2"]] %||% ""), paste0("caught true\n", jle_msg$E55("n > 10", "7")))
})

test_that("N57: a claim that passes displays nothing", {
  s <- raw_claims()
  expect_length(claim_blocks("f1")$blocks, 0L)
  expect_true(grepl("<pre><code>7</code></pre>", s$cells[["f1"]] %||% "", fixed = TRUE))
})

test_that("N57, E55: a failed claim whose cell ends in the throw displays its block, then the error with E55; the render goes on under `error: true`", {
  s <- raw_claims()
  # the error reached the cell, with the text of E55 (this part is true of the package today)
  expect_true(grepl(jle_msg$E55("n > 10", "7"), jle_unesc(s$cells[["f4"]] %||% ""), fixed = TRUE))
  expect_true(grepl("The end.", s$html, fixed = TRUE))
  # and the block was displayed first (see the READINGS: this needs a way past the engine dropping displays)
  b <- claim_blocks("f4")
  expect_length(b$blocks, 1L)
  expect_match(b$texts, ENV_CLAIM)
  ch <- failed_checks(blk(b, 1))
  expect_length(ch, 1L)
  expect_identical(ch[[1]]$expr, "@claim n > 10")
  expect_identical(ch[[1]]$text, "n > 10")
  expect_identical(ch[[1]]$ok, FALSE)
  expect_identical(list(ch[[1]]$value$t, ch[[1]]$value$v), list("int", "7"))
  expect_identical(as.integer(ch[[1]]$line), as.integer(which(RAW_QMD == "@claim n > 10")))
  # the block comes before the error in the cell
  cell <- s$cells[["f4"]] %||% ""
  expect_true(regexpr("weft-values", cell, fixed = TRUE) > 0 &&
                regexpr("weft-values", cell, fixed = TRUE) < regexpr("cell-output-error", cell, fixed = TRUE))
})

# ---- with the filter: the report ------------------------------------------------------------------------

filtered_claims <- function() {
  if (!is.null(.jle$claim_filtered)) return(.jle$claim_filtered)
  dir <- jle_project(list(`warn.qmd` = WARN_QMD, `fail.qmd` = FAIL_QMD))
  both <- jle_render(dir)
  dir2 <- jle_project(list(`stop.qmd` = STOP_QMD))
  stopped <- jle_render(dir2, "stop.qmd")
  .jle$claim_filtered <- list(both = both, stopped = stopped, dir = dir, warn_html = jle_read(dir, "warn.html"),
                              stop_html = jle_read(dir2, "stop.html"))
}

test_that("N25b, N86, E15, N89: a warned claim is listed under warned checks, located by its line, and fails nothing", {
  x <- filtered_claims()
  lines <- strsplit(x$both$stderr, "\n")[[1]]
  expect_true(any(grepl(rx_warned(1), lines)), label = "one warned check")
  l <- which(WARN_QMD == "@claim n > 10 level=:warn")
  e <- fm_entry(x$both$stderr, sprintf("^  warn\\.qmd:%d  ", l))
  expect_true(e$found)
  expect_true(startsWith(sub("^  warn\\.qmd:[0-9]+  ", "", e$head), "@claim n > 10"), label = e$head)
  expect_identical(e$detail, fm_msg$E14("n > 10", "7"))
  # the warned check does not make the document fail: it was written
  expect_true(grepl("Some prose.", jle_unesc(x$warn_html), fixed = TRUE))
  # and nothing of the carrier is left in it
  expect_false(grepl("weft-values", x$warn_html, fixed = TRUE))
})

test_that("N57, N25b, N86, E15: a failed claim under `error: true` is reported once with the line of the call, and the render exits 1", {
  x <- filtered_claims()
  expect_identical(x$both$status, 1L)
  lines <- strsplit(x$both$stderr, "\n")[[1]]
  heads <- grep("^weft: .*claim", lines, value = TRUE)
  expect_true(length(heads) >= 1L)
  expect_true(all(grepl(rx_claims(1), heads)))
  l <- which(FAIL_QMD == "@claim n > 10")
  e <- fm_entry(x$both$stderr, sprintf("^  fail\\.qmd:%d  ", l))
  expect_true(e$found)
  expect_true(grepl("@claim n > 10", e$head, fixed = TRUE), label = e$head)
  expect_identical(e$detail, fm_msg$E14("n > 10", "7"))
  expect_true(any(grepl("Do not loosen a claim to clear this.", lines, fixed = TRUE)))
})

test_that("N57, E55, measured 3: without `error: true` the render stops, and the error carries E55 and the cell's first line", {
  x <- filtered_claims()$stopped
  expect_true(x$status != 0L)
  log <- gsub("\033\\[[0-9;]*m", "", x$log)
  expect_true(grepl(jle_msg$E55("n > 10", "7"), log, fixed = TRUE), label = log)
  expect_true(grepl("Failed to run notebook", log, fixed = TRUE))
  fence <- which(STOP_QMD == "#| label: stp") - 1L
  expect_match(log, sprintf("stop\\.qmd:%d", fence))
  # the filter never ran, so it reports nothing, and no page was written
  expect_false(grepl("(^|\n)weft: [0-9]+ claim", x$stderr))
  expect_identical(filtered_claims()$stop_html, "")
})
