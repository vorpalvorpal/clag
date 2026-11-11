# Stage 1e: arms() (rule 3.7.1; design-1e "arms(file)").

arms_main <- function() {
  if (is.null(.e1_cache$arms)) {
    path <- e1_write(E1_ARMS_LINES, "doc.Rmd")
    .e1_cache$arms <- list(path = path, dir = dirname(path), x = arms(path))
  }
  .e1_cache$arms
}

test_that("3.7.1: arms() returns a data frame of class weft_arms with the documented columns", {
  x <- arms_main()$x
  expect_s3_class(x, "weft_arms")
  expect_s3_class(x, "data.frame")
  expect_true(all(c("file", "line", "context", "span", "key", "expr", "arm",
                    "role", "text", "parent_span", "parent_arm") %in% names(x)))
  expect_equal(nrow(x), E1_ARMS_NROW)
  expect_equal(length(unique(x$span)), E1_ARMS_NSPAN)
  # control: the numbering is not one span per row
  expect_lt(length(unique(x$span)), nrow(x))
})

test_that("3.7.1: every arm of n (1-4 arms), if (1 and 2 arms) and sign (2 and 3 arms) is listed with its role, key, expr, text and line", {
  x <- arms_main()$x
  for (s in E1_ARMS_SPEC) {
    line <- e1_line(E1_ARMS_LINES, s$at)
    r <- e1_rows(x, line, s$expr)
    lab <- paste0(s$key, "=", s$expr)
    expect_equal(nrow(r), length(s$role), label = lab)
    r <- r[order(r$arm), ]
    expect_equal(r$arm, seq_along(s$role), label = lab)
    expect_equal(r$role, s$role, label = lab)
    expect_equal(r$text, s$text, label = lab)
    expect_equal(unique(r$key), s$key, label = lab)
    expect_equal(unique(r$context), s$context, label = lab)
    expect_equal(length(unique(r$span)), 1L, label = lab)
    expect_true(all(is.na(r$parent_span)), label = lab)
    expect_true(all(is.na(r$parent_arm)), label = lab)
  }
})

test_that("3.7.1: the file column names the document", {
  x <- arms_main()$x
  expect_equal(unique(basename(x$file)), "doc.Rmd")
})

test_that("3.7.1: spans are numbered in document order, the arms of a span sharing its number", {
  x <- arms_main()$x
  expect_false(is.unsorted(x$span))
  # the front-matter span comes first; the weft_str spans come last
  expect_equal(x$context[1], "front-matter")
  expect_equal(x$context[nrow(x)], "weft_str")
  # prose spans are numbered in the order of their lines
  pro <- unique(x[x$context == "prose", c("span", "line")])
  expect_false(is.unsorted(pro$line))
  # a control: the arms of one span share a number, so the numbers repeat
  expect_true(any(duplicated(x$span)))
})

test_that("3.7.1: a span nested in an arm is listed under that arm, two levels deep", {
  x <- arms_main()$x
  line <- e1_line(E1_ARMS_LINES, "Nested [p")
  outer <- e1_rows(x, line, "c1")
  middle <- e1_rows(x, line, "c2")
  inner <- e1_rows(x, line, "c3")
  expect_equal(nrow(outer), 2L)
  expect_equal(nrow(middle), 2L)
  expect_equal(nrow(inner), 2L)
  expect_equal(outer$role[order(outer$arm)], c("one", "other"))
  expect_equal(middle$role[order(middle$arm)], c("true", "false"))
  expect_equal(inner$text[order(inner$arm)], c("r1", "r2"))
  # the outer span is top level
  expect_true(all(is.na(outer$parent_span)))
  # the middle span is under arm 1 of the outer span
  expect_true(all(middle$parent_span == unique(outer$span)))
  expect_true(all(middle$parent_arm == 1L))
  # the inner span is under arm 1 of the middle span
  expect_true(all(inner$parent_span == unique(middle$span)))
  expect_true(all(inner$parent_arm == 1L))
  # the arm that holds the nested span still carries the author's text, trimmed
  oa1 <- outer$text[outer$arm == 1L]
  expect_match(oa1, "^p ", perl = TRUE)
  expect_match(oa1, "r1 | r2", fixed = TRUE)
  expect_equal(outer$text[outer$arm == 2L], "t")
  # numbering: parents come before the spans nested in them
  expect_lt(unique(outer$span), unique(middle$span))
  expect_lt(unique(middle$span), unique(inner$span))
})

test_that("3.7.1: values, text spans and non-literal weft_str() calls are not listed", {
  x <- arms_main()$x
  expect_true(all(x$key %in% c("n", "if", "sign")))
  expect_false(any(x$expr %in% c("xval", "nolit")))
  expect_false(any(grepl("bold", x$text)))
  # control: the spans next to them are listed
  expect_true("n1" %in% x$expr)
  expect_true("wq" %in% x$expr)
})

test_that("3.7.1: spans in a caption option, a front-matter block scalar and a literal weft_str() string carry their context and the line in the file", {
  x <- arms_main()$x
  cap <- e1_rows(x, e1_line(E1_ARMS_LINES, "Cap [no plots"), "cn")
  expect_equal(unique(cap$context), "caption")
  fm <- e1_rows(x, 4L, "fm_flag")
  expect_equal(unique(fm$context), "front-matter")
  ws <- x[x$context == "weft_str", ]
  expect_setequal(unique(ws$expr), c("wq", "wq2"))
  expect_equal(unique(ws$line[ws$expr == "wq"]),
               e1_line(E1_ARMS_LINES, "A [x | y]"))
  expect_setequal(unique(x$context),
                  c("prose", "caption", "front-matter", "weft_str"))
})

test_that("3.7.1: arms() runs no R: effects, errors and unknown objects in the expressions and chunks do nothing", {
  a <- arms_main()
  # the document holds stop(), file.create() and an unknown object
  expect_false(file.exists(file.path(a$dir, "SENTINEL.txt")))
  expect_equal(sort(list.files(a$dir, all.files = TRUE, no.. = TRUE)), "doc.Rmd")
  # control: the expressions are really in the result
  expect_true("stop('boom')" %in% a$x$expr)
  expect_true("no_such_object" %in% a$x$expr)
})

test_that("3.7.1: several files at once are listed together, each row naming its file", {
  d <- tempfile("weft-1e-multi-"); dir.create(d)
  a <- e1_write(c("Alpha [a person | # people]{n=\"na\"}.", ""), "a.Rmd", d)
  b <- e1_write(c("---", "title: \"b\"", "engine: knitr", "---", "",
                  "Beta [met | not met]{if=\"cond_b\"}.", ""), "b.qmd", d)
  x <- arms(c(a, b))
  expect_s3_class(x, "weft_arms")
  expect_equal(nrow(x), 4L)
  expect_setequal(basename(x$file), c("a.Rmd", "b.qmd"))
  expect_equal(x$expr[basename(x$file) == "a.Rmd"], c("na", "na"))
  expect_equal(unique(x$expr[basename(x$file) == "b.qmd"]), "cond_b")
  expect_equal(x$line[basename(x$file) == "b.qmd"], c(6L, 6L))
  # control: one file alone lists only its own spans
  expect_equal(nrow(arms(a)), 2L)
})

test_that("3.7.1 + 1.6.4: a file with a construct error is still listed, and the errors are in the errors attribute", {
  lines <- c("Fine [ok | no]{if=\"cond_y\"}.", "",
             "Bad [a | b | c | d | e]{n=\"x\"}.", "")
  p <- e1_write(lines, "bad.Rmd")
  x <- arms(p)
  expect_s3_class(x, "weft_arms")
  expect_true("cond_y" %in% x$expr)
  err <- attr(x, "errors")
  expect_gte(length(if (is.data.frame(err)) err[[1]] else err), 1L)
  # the print method ends with the errors: the bad line's number is in the tail
  out <- capture.output(print(x))
  expect_true(any(grepl("3", tail(out, 3))))
  # control: a file with no error has no errors
  ok <- arms(e1_write(lines[1:2], "ok.Rmd"))
  err_ok <- attr(ok, "errors")
  expect_equal(length(if (is.data.frame(err_ok)) err_ok[[1]] else err_ok), 0L)
})

test_that("3.7.1: the print method shows file:line, the key and the expression, the arms under the span, and a nested span under its arm", {
  a <- arms_main()
  out <- capture.output(print(a$x))
  expect_gt(length(out), 0L)
  line_n3 <- e1_line(E1_ARMS_LINES, "Three [no one")
  hdr <- grep(sprintf("doc\\.Rmd:%d\\b", line_n3), out)
  expect_length(hdr, 1L)
  expect_match(out[hdr], "n")
  expect_match(out[hdr], "n3")
  # the arms of that span are listed after the header
  after <- paste(out[(hdr + 1):(hdr + 3)], collapse = "\n")
  expect_match(after, "no one")
  expect_match(after, "a person")
  expect_match(after, "# people", fixed = TRUE)
  # an if span's header names its key and condition
  ln_if <- e1_line(E1_ARMS_LINES, "Choice [met")
  expect_true(any(grepl(sprintf(":%d\\b.*if.*stop\\('boom'\\)", ln_if), out)))
  # nesting: the inner spans' headers are indented deeper than the outer one
  lead <- function(s) nchar(sub("^(\\s*).*$", "\\1", s))
  h_outer <- grep("c1", out)[1]
  h_mid   <- grep("c2", out)[1]
  h_inner <- grep("c3", out)[1]
  expect_lt(lead(out[h_outer]), lead(out[h_mid]))
  expect_lt(lead(out[h_mid]), lead(out[h_inner]))
})
