# Stage 1e: rehearse() (rules 3.7.2, 3.7.3, 3.7.4; design-1e "rehearse(file, cases)").
# Each case is a fresh R process (2-3 s); the main fixture is rehearsed once
# and shared (e1_main() in helper-1e.R).

E1_ROLES <- list(
  found = c("zero", "one", "other"), survey = c("true", "false"),
  trend = c("positive", "negative", "zero"), several = c("true", "false"),
  big = c("true", "false"), odd = c("true", "false"),
  cap = c("zero", "one", "other")
)

test_that("3.7.3: rehearse() returns a weft_rehearsal with cases, arms, unreached and unevaluated", {
  m <- e1_main()
  r <- m$res
  expect_s3_class(r, "weft_rehearsal")
  expect_true(all(c("cases", "arms", "unreached", "unevaluated") %in% names(r)))
  expect_equal(names(r$cases), names(E1_MAIN_CASES))
  for (cs in r$cases) {
    expect_true(all(c("ok", "error", "failures", "chosen") %in% names(cs)))
    expect_true(is.data.frame(cs$failures))
    expect_true(is.data.frame(cs$chosen))
    expect_true(all(c("span", "file", "line", "key", "expr", "arm", "role",
                      "text") %in% names(cs$chosen)))
  }
})

test_that("3.7.3: chosen gives, per case, the arm each evaluated span chose, with role and text; span numbers match arms(file)", {
  m <- e1_main()
  sp <- e1_main_spans()
  for (case in names(E1_MAIN_CHOSEN)) {
    want <- E1_MAIN_CHOSEN[[case]]
    ch <- m$res$cases[[case]]$chosen
    # exactly the spans the case evaluated, one row each
    expect_equal(nrow(ch), length(want), label = case)
    expect_setequal(ch$span, unlist(sp[names(want)]))
    for (nm in names(want)) {
      row <- ch[ch$span == sp[[nm]], ]
      lab <- paste(case, nm)
      expect_equal(nrow(row), 1L, label = lab)
      expect_equal(row$arm, unname(want[nm]), label = lab)
      expect_equal(row$role, E1_ROLES[[nm]][want[[nm]]], label = lab)
      # the row is the row of arms(file): same line, key, expr and arm text
      a <- m$arms[m$arms$span == sp[[nm]] & m$arms$arm == want[[nm]], ]
      expect_equal(row$text, a$text, label = lab)
      expect_equal(row$line, a$line, label = lab)
      expect_equal(row$key, a$key, label = lab)
      expect_equal(row$expr, a$expr, label = lab)
    }
  }
  # spot checks on the words
  expect_equal(m$res$cases$usual$chosen$text[m$res$cases$usual$chosen$span == sp$found],
               "# sites")
  expect_equal(m$res$cases$single$chosen$text[m$res$cases$single$chosen$span == sp$trend],
               "flat")
})

test_that("3.7.3: a nested span is evaluated only when its arm is chosen", {
  m <- e1_main()
  sp <- e1_main_spans()
  expect_true(sp$big %in% m$res$cases$usual$chosen$span)
  expect_false(sp$big %in% m$res$cases$empty$chosen$span)
  expect_false(sp$big %in% m$res$cases$single$chosen$span)
  # the span nested in an arm that no case chose is evaluated by no case
  for (cs in m$res$cases) expect_false(sp$zz %in% cs$chosen$span)
})

test_that("3.7.3: ok and failures: the cases that pass are ok with no failures", {
  r <- e1_main()$res
  for (case in c("usual", "single")) {
    cs <- r$cases[[case]]
    expect_true(cs$ok, label = case)
    expect_equal(nrow(cs$failures), 0L, label = case)
    expect_true(is.na(cs$error), label = case)
  }
})

test_that("3.7.3: the failing case reports its failed claim (kind and line) and still runs to its end", {
  m <- e1_main()
  sp <- e1_main_spans()
  cs <- m$res$cases$empty
  expect_false(cs$ok)
  expect_true(is.na(cs$error))
  expect_equal(nrow(cs$failures), 1L)
  expect_equal(cs$failures$kind, "failed claim")
  expect_equal(cs$failures$line, E1_MAIN$claim)
  expect_true(all(c("kind", "file", "line", "chunk", "expr", "detail") %in%
                    names(cs$failures)))
  # the render did not stop at the failure: the spans before and after it
  # (the caption span precedes the claim; the others come before it) were chosen
  expect_true(sp$cap %in% cs$chosen$span)
  expect_equal(nrow(cs$chosen), length(E1_MAIN_CHOSEN$empty))
})

test_that("3.7.3: the case after a failing one still runs and reports its own choices", {
  r <- e1_main()$res
  # `empty` is the second of three cases; `single` follows it
  expect_equal(names(r$cases), c("usual", "empty", "single"))
  expect_true(r$cases$single$ok)
  expect_equal(nrow(r$cases$single$chosen), length(E1_MAIN_CHOSEN$single))
})

test_that("3.7.1 + 3.7.3: params not given by a case take the document's defaults", {
  m <- e1_main()
  sp <- e1_main_spans()
  # `usual` gives only count: delta defaults to 1.5 (positive), flag to TRUE
  ch <- m$res$cases$usual$chosen
  expect_equal(ch$role[ch$span == sp$trend], "positive")
  expect_equal(ch$role[ch$span == sp$survey], "true")
  # control: the case that gives delta and flag gets the other arms
  ch2 <- m$res$cases$empty$chosen
  expect_equal(ch2$role[ch2$span == sp$trend], "negative")
  expect_equal(ch2$role[ch2$span == sp$survey], "false")
  # a count that can be negative: sign takes its arm from the number
  expect_equal(m$res$cases$single$chosen$role[m$res$cases$single$chosen$span == sp$trend], "zero")
})

test_that("3.7.3: arms is arms(file) with one logical column per case and reached", {
  m <- e1_main()
  sp <- e1_main_spans()
  a <- m$res$arms
  base <- m$arms
  expect_equal(nrow(a), nrow(base))
  expect_true(all(names(base) %in% names(a)))
  expect_true(all(c(names(E1_MAIN_CASES), "reached") %in% names(a)))
  for (case in c(names(E1_MAIN_CASES), "reached")) expect_type(a[[case]], "logical")
  for (case in names(E1_MAIN_CASES)) {
    want <- E1_MAIN_CHOSEN[[case]]
    chosen_key <- paste(unlist(sp[names(want)]), unname(want))
    expect_equal(a[[case]], paste(a$span, a$arm) %in% chosen_key, label = case)
  }
  expect_equal(a$reached, a$usual | a$empty | a$single)
  # controls: some arms are reached and some are not
  expect_true(any(a$reached))
  expect_false(all(a$reached))
})

test_that("3.7.3: unreached is exactly the arms no case chose; unevaluated is exactly the span nested in a never-chosen arm", {
  m <- e1_main()
  sp <- e1_main_spans()
  ur <- m$res$unreached
  expect_true(is.data.frame(ur))
  key <- paste(ur$span, ur$arm)
  expect_setequal(key, c(paste(sp$big, 2), paste(sp$odd, 2),
                         paste(sp$zz, 1), paste(sp$zz, 2)))
  expect_equal(nrow(ur), 4L)
  # the rows are rows of arms
  expect_equal(unique(ur$text[ur$span == sp$zz]) |> sort(), c("yy", "zz"))
  expect_false(any(ur$reached))
  ue <- m$res$unevaluated
  expect_true(is.data.frame(ue))
  expect_equal(unique(ue$span), sp$zz)
  expect_equal(unique(ue$line), E1_MAIN$odd)
  expect_equal(unique(ue$expr), "TRUE")
})

test_that("3.7.2: the document's folder holds exactly the same files after rehearse() as before, figure and caption chunk included", {
  m <- e1_main()
  # the main fixture draws a figure with a caption; nothing was written
  expect_equal(e1_snapshot(m$dir), "main.Rmd")
})

test_that("3.7.1: the print method reports case by case, the failure's file:line, the arms chosen, then unreached arms and unevaluated spans", {
  r <- e1_main()$res
  out <- capture.output(print(r))
  expect_gt(length(out), 0L)
  txt <- paste(out, collapse = "\n")
  for (case in names(E1_MAIN_CASES)) expect_match(txt, case, fixed = TRUE)
  first <- vapply(names(E1_MAIN_CASES), function(cn) grep(cn, out, fixed = TRUE)[1], 1L)
  expect_false(is.unsorted(first))
  # the failure of `empty` is reported with its file:line
  expect_match(txt, sprintf("main\\.Rmd:%d\\b", E1_MAIN$claim))
  # the arm a span chose: the chosen words appear
  expect_match(txt, "# sites", fixed = TRUE)
  # then the unreached arms and the unevaluated spans
  expect_match(txt, "reach", ignore.case = TRUE)
  expect_match(txt, "evaluat", ignore.case = TRUE)
  expect_match(txt, sprintf("main\\.Rmd:%d\\b", E1_MAIN$odd))
})

test_that("3.7.3: a chunk that stops with an ordinary error sets error for that case, and the next case still runs", {
  path <- e1_write(E1_STOP_LINES, "stop.Rmd")
  r <- e1_with_libs(rehearse(path, list(
    broke = list(boom = TRUE),
    fine  = list(boom = FALSE)
  )))
  expect_s3_class(r, "weft_rehearsal")
  expect_false(r$cases$broke$ok)
  expect_true(is.character(r$cases$broke$error))
  expect_false(is.na(r$cases$broke$error))
  expect_match(r$cases$broke$error, "kaboom")
  # the next case ran, and is clean
  expect_true(r$cases$fine$ok)
  expect_true(is.na(r$cases$fine$error))
  ch <- r$cases$fine$chosen
  expect_equal(nrow(ch), 2L)
  expect_equal(ch$role, c("true", "true"))
  expect_equal(sort(ch$line), c(e1_line(E1_STOP_LINES, "Before ["),
                                e1_line(E1_STOP_LINES, "After [")))
  # the stopped case did not get to the span after the chunk
  expect_lt(nrow(r$cases$broke$chosen), 2L)
  # the working directory is the document's: the author's own chunk wrote here
  expect_true(file.exists(file.path(dirname(path), "ran.txt")))
})

test_that("3.7.2: an unknown param name is an error before anything runs", {
  path <- e1_write(E1_STOP_LINES, "stop.Rmd")
  dir <- dirname(path)
  # the document's own setup chunk writes ran.txt whenever it is knitted
  expect_error(
    e1_with_libs(rehearse(path, list(a = list(boom = FALSE),
                                     b = list(nosuch = 1)))),
    "nosuch"
  )
  expect_false(file.exists(file.path(dir, "ran.txt")))
  # control: the same call without the bad name does knit the document
  e1_with_libs(rehearse(path, list(a = list(boom = FALSE))))
  expect_true(file.exists(file.path(dir, "ran.txt")))
})

test_that("3.7.2: nothing is written in a plain folder, with a cache=TRUE chunk and a figure; an ordinary knit of the same document does write them", {
  skip_if_not(rmarkdown::pandoc_available(), "pandoc is not available")
  path <- e1_write(E1_WRITE_LINES, "doc.Rmd")
  before <- e1_snapshot(dirname(path))
  r <- e1_with_libs(rehearse(path, list(two = list(count = 2),
                                        one = list(count = 1))))
  after <- e1_snapshot(dirname(path))
  expect_identical(after, before)
  expect_false(any(grepl("cache|figure|_files", after)))
  expect_true(r$cases$two$ok)
  expect_true(r$cases$one$ok)
  # the cases ran: the arms differ
  expect_equal(r$cases$two$chosen$role, "other")
  expect_equal(r$cases$one$chosen$role, "one")
  # control: an ordinary knit of the same document writes a cache and a figure
  # (rendered, not knitted bare: a bare knit defines no `params`)
  ctl <- render_rmd(E1_WRITE_LINES, setup = FALSE, format = "md")
  ctl_files <- e1_snapshot(ctl$dir)
  expect_false(ctl$failed, label = ctl$message)
  expect_true(any(grepl("cache", ctl_files)))
  expect_true(any(grepl("figure", ctl_files)))
})

test_that("3.7.2: nothing is written in a project folder that holds _weft.yml (no .weft/ stamp, ledger, collection or draft file)", {
  skip_if_not(rmarkdown::pandoc_available(), "pandoc is not available")
  cfg <- list("_weft.yml" = c("ci_level: 0.9"))
  # the claim fails in the second case, which would write a draft JSON and
  # a collection line in an ordinary draft-mode knit
  lines <- c(E1_WRITE_LINES, "Count `r claim(n, . > 5)`{.num}.", "")
  path <- e1_write(lines, "doc.Rmd", files = cfg)
  dir <- dirname(path)
  before <- e1_snapshot(dir)
  expect_true("_weft.yml" %in% before)
  r <- e1_with_libs(rehearse(path, list(a = list(count = 9), b = list(count = 1))))
  after <- e1_snapshot(dir)
  expect_identical(after, before)
  expect_false(any(grepl("\\.weft", after)))
  expect_false(any(grepl("failures", after)))
  # the failing case was collected in memory, not on disk
  expect_true(r$cases$a$ok)
  expect_false(r$cases$b$ok)
  expect_equal(r$cases$b$failures$kind, "failed claim")
})

test_that("3.7.2 + 1.10.1: a .qmd with engine: knitr, a #| fig-cap: caption and `{r} x` inline code rehearses, and writes nothing", {
  path <- e1_write(E1_QMD_LINES, "q.qmd")
  dir <- dirname(path)
  r <- e1_with_libs(rehearse(path, list(one = list(count = 1),
                                        many = list(count = 4))))
  expect_s3_class(r, "weft_rehearsal")
  expect_true(r$cases$one$ok)
  expect_true(r$cases$many$ok)
  expect_true(is.na(r$cases$one$error))
  lines <- c(e1_line(E1_QMD_LINES, "Found `{r}"),
             e1_line(E1_QMD_LINES, "#|   Plot of"))
  one <- r$cases$one$chosen
  many <- r$cases$many$chosen
  expect_equal(sort(one$line), lines)
  expect_equal(sort(many$line), lines)
  expect_equal(one$arm, c(1L, 1L))
  expect_equal(many$arm, c(2L, 2L))
  expect_equal(unique(one$role), "one")
  expect_equal(unique(many$role), "other")
  # no qmd output, no q_files
  expect_equal(e1_snapshot(dir), "q.qmd")
})
