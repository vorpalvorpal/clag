# Stage 1h: a list that can be empty. The `list` governor key on a span, and
# the `none` key on a value with a collapse class. Contract: dev/design-1h.md.
#
# Fast checks go through weft_str() (outside a knit a failure is an error with
# a class) and the scanner (construct errors found from the source). One
# rmarkdown batch and one Quarto batch cover the central cases in a render.

PRE_1H <- c(
  "none_ch <- character(0); one_ch <- 'a'; two_ch <- c('a', 'b'); three_ch <- c('a', 'b', 'c')",
  "sites <- c('North', 'South', 'East')",
  "flagged <- character(0); flagged1 <- 'Ridge'; flagged3 <- c('Ridge', 'Dam', 'Weir')"
)

# weft_str() with some variables in scope (the caller's frame is the environment)
hs <- function(src, ...) {
  vars <- list(...)
  for (n in names(vars)) assign(n, vars[[n]])
  weft::weft_str(src)
}

# the scanner's construct errors for a source, as b_errs() in helper-1b.R
h_scan <- function(src, good = NULL, label = src) {
  b_expect_scan_error(src, good, label = label)
}

A3 <- "[No sites were | # was | # were]{list=\"v\"}"
A2 <- "[# was | # were]{list=\"v\"}"
A4 <- "[none | # | both # | all #]{list=\"v\"}"

# ---- list: the arm is chosen by length ---------------------------------------

test_that("1h list: three arms are zero, one, other by length", {
  expect_identical(hs(A3, v = character(0)), "No sites were")
  expect_identical(hs(A3, v = "a"), "a was")
  expect_identical(hs(A3, v = c("a", "b")), "a and b were")
  expect_identical(hs(A3, v = c("a", "b", "c")), "a, b and c were")
  # control: the same words under n pick by a count and are unchanged
  expect_identical(hs("[no sites | a site | # sites]{n=\"2\"}"), "2 sites")
})

test_that("1h list: two arms are one, other (a length of zero is a failed claim, tested below)", {
  expect_identical(hs(A2, v = "a"), "a was")
  expect_identical(hs(A2, v = c("a", "b")), "a and b were")
  expect_identical(hs(A2, v = c("a", "b", "c")), "a, b and c were")
  expect_identical(hs("[# was | # were]{n=\"1\"}"), "1 was")                   # control
})

test_that("1h list: four arms are zero, one, two, other by length", {
  expect_identical(hs(A4, v = character(0)), "none")
  expect_identical(hs(A4, v = "a"), "a")
  expect_identical(hs(A4, v = c("a", "b")), "both a and b")
  expect_identical(hs(A4, v = c("a", "b", "c")), "all a, b and c")
  expect_identical(hs(A4, v = letters[1:4]), "all a, b, c and d")
})

test_that("1h list: the span stands in a sentence and the text around it is untouched", {
  expect_identical(hs("[No sites were | # was | # were]{list=\"v\"} flagged.", v = c("A", "B")),
                   "A and B were flagged.")
  expect_identical(hs("[No sites were | # was | # were]{list=\"v\"} flagged.", v = character(0)),
                   "No sites were flagged.")
})

# ---- list: what a vector can be ----------------------------------------------

test_that("1h list: character, factor, numeric, logical and Date vectors", {
  expect_identical(hs(A3, v = c("x", "y")), "x and y were")
  expect_identical(hs(A3, v = factor(c("lo", "hi"))), "lo and hi were")
  expect_identical(hs(A3, v = factor(character(0))), "No sites were")
  # numeric with no class prints as a bare value prints; no numeric guard
  expect_identical(hs(A3, v = c(3, 7, 1200)), "3, 7 and 1200 were")
  expect_identical(hs(A3, v = 3), "3 was")
  expect_identical(hs(A3, v = numeric(0)), "No sites were")
  expect_identical(hs(A3, v = c(TRUE, FALSE)), "TRUE and FALSE were")
  expect_identical(hs(A3, v = logical(0)), "No sites were")
  d <- as.Date(c("2026-03-01", "2026-04-02"))
  expect_identical(hs(A3, v = d), "2026-03-01 and 2026-04-02 were")
  expect_identical(hs(A3, v = as.Date(character(0))), "No sites were")
})

test_that("1h list: an integer vector, a named vector and a one-element number", {
  expect_identical(hs(A3, v = 1:3), "1, 2 and 3 were")
  expect_identical(hs(A3, v = c(a = "x", b = "y")), "x and y were")
})

# ---- list: classes and keys on the span act on # -----------------------------

test_that("1h list: a collapse class on the span changes the joining", {
  expect_identical(hs("[None | # was | # were]{list=\"v\" .or}", v = c("a", "b", "c")), "a, b or c were")
  expect_identical(hs("[None | # was | # were]{list=\"v\" .or}", v = "a"), "a was")
  expect_identical(hs("[None | # was | # were]{list=\"v\" .or}", v = character(0)), "None")
  # control: no class joins as .and
  expect_identical(hs("[None | # was | # were]{list=\"v\"}", v = c("a", "b", "c")), "a, b and c were")
})

test_that("1h list: trunc on the span shortens the list", {
  expect_identical(hs("[None | # was | # were]{list=\"v\" trunc=\"3\"}", v = letters[1:7]),
                   "a, b, c and 4 others were")
  # at or under trunc nothing is cut (control)
  expect_identical(hs("[None | # was | # were]{list=\"v\" trunc=\"3\"}", v = letters[1:3]),
                   "a, b and c were")
})

test_that("1h list: sep and last on the span", {
  expect_identical(hs("[None | # was | # were]{list=\"v\" sep=\"; \" last=\" & \"}", v = c("a", "b", "c")),
                   "a; b & c were")
  expect_identical(hs("[None | # was | # were]{list=\"v\" sep=\"; \"}", v = c("a", "b", "c")),
                   "a; b and c were")
})

test_that("1h list: a number class and digits format each element first", {
  expect_identical(hs("[None | # was | # were]{list=\"v\" .num digits=\"1\"}", v = c(1.54, 3.5)),
                   "1.5 and 3.5 were")
  expect_identical(hs("[None | # was | # were]{list=\"v\" .word}", v = c(1, 2)),
                   "one and two were")
  expect_identical(hs("[None | # was | # were]{list=\"v\" .num digits=\"1\"}", v = numeric(0)), "None")
})

test_that("1h list: a text class acts on the result", {
  expect_identical(hs("[None | # was | # were]{list=\"v\" .cap}", v = c("a", "b")), "A and b were")
  expect_identical(hs("[none | # was | # were]{list=\"v\" .cap}", v = character(0)), "None")
})

# ---- list: empty, and what is not a vector -----------------------------------

test_that("1h list: character(0), numeric(0) and a filter that matched nothing take the zero arm", {
  expect_identical(hs(A3, v = character(0)), "No sites were")
  expect_identical(hs(A3, v = numeric(0)), "No sites were")
  d <- data.frame(site = c("a", "b"), bad = c(FALSE, FALSE))
  expect_identical(hs(A3, v = d$site[d$bad]), "No sites were")
  # control: the filter matches two
  d$bad <- c(TRUE, TRUE)
  expect_identical(hs(A3, v = d$site[d$bad]), "a and b were")
})

test_that("1h list: empty with two arms is a failed claim that says to add an arm for the empty case", {
  expect_error(hs(A2, v = character(0)), class = "weft_claim_failed")
  expect_error(hs(A2, v = character(0)), "empty case", ignore.case = TRUE)
  expect_error(hs(A2, v = character(0)), "arm", ignore.case = TRUE)
  expect_error(hs(A2, v = numeric(0)), class = "weft_claim_failed")
  expect_identical(hs(A2, v = "a"), "a was")                                   # control
})

test_that("1h list: NULL is not an empty list; it is a no-value failure and never prints the zero arm", {
  expect_error(hs(A3, v = NULL), class = "weft_no_value")
  out <- tryCatch(hs(A3, v = NULL), error = function(e) conditionMessage(e))
  expect_false(grepl("No sites were", out, fixed = TRUE) && !grepl("[No sites", out, fixed = TRUE))
  expect_error(hs(A4, v = NULL), class = "weft_no_value")
  expect_error(hs(A2, v = NULL), class = "weft_no_value")
})

test_that("1h list: an R list and a data frame are no-value failures", {
  expect_error(hs(A3, v = list()), class = "weft_no_value")
  expect_error(hs(A3, v = list("a", "b")), class = "weft_no_value")
  expect_error(hs(A3, v = data.frame(site = c("a", "b"))), class = "weft_no_value")
  expect_error(hs(A3, v = data.frame()), class = "weft_no_value")
})

test_that("1h list: a misspelt column is a no-value failure, not a quiet zero arm", {
  d <- data.frame(site = c("a", "b"))
  expect_error(hs("[No sites were | # was | # were]{list=\"d$nosuch\"}", d = d), class = "weft_no_value")
  expect_identical(hs("[No sites were | # was | # were]{list=\"d$site\"}", d = d), "a and b were")  # control
})

test_that("1h list: an NA element is a no-value failure", {
  expect_error(hs(A3, v = c("a", NA)), class = "weft_no_value")
  expect_error(hs(A3, v = NA_character_), class = "weft_no_value")
  expect_error(hs(A3, v = c(1, NA)), class = "weft_no_value")
  expect_identical(hs(A3, v = c("a", "b")), "a and b were")                    # control
})

# ---- list: construct errors --------------------------------------------------

test_that("1h list: # in the zero arm is a construct error found from the source", {
  h_scan("[# none | # was | # were]{list=\"v\"}", good = A3)
  h_scan("[# none | # was | # were | # many]{list=\"v\"}", good = A4)
})

test_that("1h list: one arm is a construct error", {
  h_scan("[# flagged]{list=\"v\"}", good = A2)
})

test_that("1h list: an id on a list span is a construct error", {
  h_scan("[No sites | # was | # were]{#lst list=\"v\"}", good = A3)
  h_scan("[No sites | # was | # were]{list=\"v\" #lst}", good = A3)
})

test_that("1h list: list=\".\" is a construct error", {
  h_scan("[No sites | # was | # were]{list=\".\"}", good = A3)
})

test_that("1h list: the construct errors also stop weft_str() with the construct class", {
  expect_error(hs("[# none | # was | # were]{list=\"v\"}", v = "a"), class = "weft_construct_error")
  expect_error(hs("[# flagged]{list=\"v\"}", v = "a"), class = "weft_construct_error")
  expect_error(hs("[No sites | # was | # were]{list=\".\"}", v = "a"), class = "weft_construct_error")
})

# ---- list: nested spans, claim(), laziness -----------------------------------

test_that("1h list: an inner n=\".\" inherits the length as its count", {
  src <- "[none | # was | [# site | # sites]{n=\".\"}: #]{list=\"v\"}"
  expect_identical(hs(src, v = c("a", "b", "c")), "3 sites: a, b and c")
  expect_identical(hs(src, v = "a"), "a was")
  expect_identical(hs(src, v = character(0)), "none")
  expect_identical(hs("[none | [# site | # sites]{n=\".\"} | [# site | # sites]{n=\".\"}]{list=\"v\"}",
                      v = c("a", "b")), "2 sites")
})

test_that("1h list: claim() in the expression works as in any governor", {
  src <- "[none | # was | # were]{list=\"claim(v, all(nchar(.) == 1))\"}"
  expect_identical(hs(src, v = c("a", "b")), "a and b were")
  expect_error(hs(src, v = c("a", "bb")), class = "weft_claim_failed")
})

test_that("1h list: only the chosen arm is evaluated", {
  src <- "[[a | b]{if=\"stop('boom')\"} | # was | # were]{list=\"v\"}"
  expect_identical(hs(src, v = "s"), "s was")
  expect_error(hs(src, v = character(0)), regexp = "boom")                     # the chosen arm is evaluated
  expect_identical(hs("[[a | b]{if=\"stop('boom')\"} | # was | # were]{list=\"v\"}", v = c("s", "t")),
                   "s and t were")
})

test_that("1h list: n=\"flagged\" with a vector is still a failure (rule 1.5.11 stands)", {
  expect_error(hs("[none | # was | # were]{n=\"v\"}", v = c("a", "b", "c")))
  expect_error(hs("[none | # was | # were]{n=\"v\"}", v = c("a", "b")))
  # control: the same vector under list is fine
  expect_identical(hs("[none | # was | # were]{list=\"v\"}", v = c("a", "b")), "a and b were")
})

# ---- list: language ----------------------------------------------------------

test_that("1h list: under a lang that is not shipped a list span with more than one arm is a construct error, as n is", {
  b <- batch_cases(c("x [none | # was | # were]{list=\"flagged\"} y", "z [one | other]{n=\"2\"} w"))
  res <- render_rmd(b, code = PRE_1H, front = "lang: de", env = c(WEFT_DRAFT = "1"),
                    format = "knit", in_process = TRUE)
  expect_false(res$failed, label = substr(res$message, 1, 300))
  got <- unlist(split_cases(res, 2))
  # the n span (control, rule 1.6.5) and the list span both give a marker
  expect_match(unesc(got[2]), "construct error", fixed = TRUE)
  expect_match(unesc(got[1]), "construct error", fixed = TRUE)
})

test_that("1h list: under lang en-AU a list span works (English on its primary subtag)", {
  b <- batch_cases("x [none | # was | # were]{list=\"flagged3\"} y")
  res <- render_rmd(b, code = PRE_1H, front = "lang: en-AU")
  expect_false(res$failed, label = res$message)
  expect_equal(unesc(unlist(split_cases(res, 1))), "x Ridge, Dam and Weir were y")
})

# ---- list: arms() and rehearse() ---------------------------------------------

E1H_LINES <- c(
  "---",
  "title: \"t\"",
  "params:",
  "  v: [\"a\", \"b\"]",
  "---",
  "",
  "```{r setup, include=FALSE}",
  "weft::weft_setup()",
  "```",
  "",
  "Three [No sites were | # was | # were]{list=\"v\"} flagged.",
  "",
  "Two [# was | # were]{list=\"v\"} flagged.",
  "",
  "Four [none | one | two | # many]{list=\"v\"} flagged.",
  ""
)

test_that("1h list: arms() lists a list span with key list and the roles of n", {
  path <- e1_write(E1H_LINES, "h.Rmd")
  x <- arms(path)
  for (s in list(
    list(at = "Three [", roles = c("zero", "one", "other"),
         text = c("No sites were", "# was", "# were")),
    list(at = "Two [", roles = c("one", "other"), text = c("# was", "# were")),
    list(at = "Four [", roles = c("zero", "one", "two", "other"),
         text = c("none", "one", "two", "# many"))
  )) {
    r <- x[x$line == e1_line(E1H_LINES, s$at), ]
    r <- r[order(r$arm), ]
    expect_equal(r$role, s$roles, label = s$at)
    expect_equal(r$text, s$text, label = s$at)
    expect_equal(unique(r$key), "list", label = s$at)
    expect_equal(unique(r$expr), "v", label = s$at)
    expect_equal(length(unique(r$span)), 1L, label = s$at)
  }
  # control: an n span still lists with key n
  y <- arms(e1_write(c(E1H_LINES, "Control [a | # b]{n=\"2\"}.", ""), "h2.Rmd"))
  expect_equal(unique(y$key[y$line == length(E1H_LINES) + 1L]), "n")
})

test_that("1h list: rehearse() records the arm a list span chose", {
  path <- e1_write(E1H_LINES, "h3.Rmd")
  res <- e1_with_libs(rehearse(path, list(
    empty = list(v = character(0)),
    many  = list(v = c("a", "b", "c"))
  )))
  expect_s3_class(res, "weft_rehearsal")
  a <- arms(path)
  s3 <- unique(a$span[a$line == e1_line(E1H_LINES, "Three [")])
  ch_e <- res$cases$empty$chosen
  ch_m <- res$cases$many$chosen
  expect_equal(ch_e$arm[ch_e$span == s3], 1L)
  expect_equal(ch_e$role[ch_e$span == s3], "zero")
  expect_equal(ch_e$key[ch_e$span == s3], "list")
  expect_equal(ch_m$arm[ch_m$span == s3], 3L)
  expect_equal(ch_m$role[ch_m$span == s3], "other")
})

# ---- none: a value with a collapse class -------------------------------------

test_that("1h none: a zero-length atomic vector prints the key's text under each collapse class", {
  expect_identical(hs("`r v`{.and none=\"none\"}", v = character(0)), "none")
  expect_identical(hs("`r v`{.or none=\"nothing\"}", v = character(0)), "nothing")
  expect_identical(hs("`r v`{.pairs none=\"no means\"}", v = numeric(0)), "no means")
  expect_identical(hs("`r v`{.ul none=\"none\"}", v = character(0)), "none")
  expect_identical(hs("`r v`{.ol none=\"none\"}", v = character(0)), "none")
  expect_identical(hs("`r v`{.dl none=\"none\"}", v = character(0)), "none")
  # also other atomic types
  expect_identical(hs("`r v`{.and none=\"none\"}", v = numeric(0)), "none")
  expect_identical(hs("`r v`{.and none=\"none\"}", v = logical(0)), "none")
  expect_identical(hs("`r v`{.and none=\"none\"}", v = factor(character(0))), "none")
})

test_that("1h none: the text is inline, also for a list class (no bullet, no number)", {
  for (cls in c(".ul", ".ol", ".dl")) {
    out <- hs(sprintf("`r v`{%s none=\"none at all\"}", cls), v = character(0))
    expect_identical(out, "none at all", label = cls)
    expect_false(grepl("\n", out, fixed = TRUE), label = cls)
  }
})

test_that("1h none: a text class acts on the none text", {
  expect_identical(hs("`r v`{.and .cap none=\"none\"}", v = character(0)), "None")
  expect_identical(hs("`r v`{.and .strong none=\"none\"}", v = character(0)), "**none**")
  expect_identical(hs("`r v`{.and .strong none=\"none\"}", v = c("a", "b")), "**a and b**")   # control
})

test_that("1h none: without none an empty value is still a no-value failure (control)", {
  expect_error(hs("`r v`{.and}", v = character(0)), class = "weft_no_value")
  expect_error(hs("`r v`{.or}", v = character(0)), class = "weft_no_value")
  expect_error(hs("`r v`{.pairs}", v = numeric(0)), class = "weft_no_value")
  expect_error(hs("`r v`{.ul}", v = character(0)), class = "weft_no_value")
  expect_error(hs("`r v`{.ol}", v = character(0)), class = "weft_no_value")
  expect_error(hs("`r v`{.dl}", v = character(0)), class = "weft_no_value")
})

test_that("1h none: a non-empty value ignores none", {
  expect_identical(hs("`r v`{.and none=\"none\"}", v = c("a", "b", "c")), "a, b and c")
  expect_identical(hs("`r v`{.or none=\"none\"}", v = c("a", "b")), "a or b")
  expect_identical(hs("`r v`{.and none=\"none\"}", v = "a"), "a")
  expect_identical(hs("`r v`{.pairs none=\"none\"}", v = c(A = 1, B = 2)), "A (1) and B (2)")
  expect_identical(trimws(hs("`r v`{.ul none=\"none\"}", v = c("a", "b"))), "- a\n- b")
})

test_that("1h none: none=\"\" and none of only spaces are construct errors", {
  h_scan("`r v`{.and none=\"\"}", good = "`r v`{.and none=\"none\"}")
  h_scan("`r v`{.and none=\"  \"}", good = "`r v`{.and none=\"none\"}")
  h_scan("`r v`{.ul none=\"\"}", good = "`r v`{.ul none=\"none\"}")
  expect_error(hs("`r v`{.and none=\"\"}", v = character(0)), class = "weft_construct_error")
  expect_error(hs("`r v`{.and none=\"  \"}", v = character(0)), class = "weft_construct_error")
})

test_that("1h none: none with no collapse class, on a span, or on a cite span is a construct error", {
  h_scan("`r v`{none=\"none\"}", good = "`r v`{.and none=\"none\"}")
  h_scan("`r v`{.num none=\"none\"}", good = "`r v`{.and none=\"none\"}")
  h_scan("`r v`{.strong none=\"none\"}", good = "`r v`{.and none=\"none\"}")
  h_scan("[a | b]{if=\"TRUE\" none=\"none\"}", good = "[a | b]{if=\"TRUE\"}")
  h_scan("[a]{.strong none=\"none\"}", good = "[a]{.strong}")
  h_scan("[10 m]{cite=\"smith2020\" none=\"none\"}", good = "[10 m]{cite=\"smith2020\"}")
  expect_error(hs("`r v`{none=\"none\"}", v = "a"), class = "weft_construct_error")
  expect_error(hs("[a | b]{if=\"TRUE\" none=\"none\"}"), class = "weft_construct_error")
})

test_that("1h none: NULL with none is still a no-value failure", {
  expect_error(hs("`r v`{.and none=\"none\"}", v = NULL), class = "weft_no_value")
  expect_error(hs("`r v`{.ul none=\"none\"}", v = NULL), class = "weft_no_value")
  expect_error(hs("`r v`{.and none=\"none\"}", v = list()), class = "weft_no_value")
  expect_error(hs("`r v`{.and none=\"none\"}", v = c("a", NA)), class = "weft_no_value")
})

test_that("1h none: function forms take none = NULL and print it for a zero-length vector", {
  expect_equal(b_txt(fmt_and(character(0), none = "none")), "none")
  expect_equal(b_txt(fmt_or(character(0), none = "none")), "none")
  expect_equal(b_txt(fmt_pairs(numeric(0), none = "none")), "none")
  expect_equal(b_txt(fmt_ul(character(0), none = "none")), "none")
  expect_equal(b_txt(fmt_ol(character(0), none = "none")), "none")
  expect_equal(b_txt(fmt_dl(character(0), none = "none")), "none")
  expect_true("none" %in% names(formals(fmt_and)))
  expect_null(formals(fmt_and)$none)
  for (f in list(fmt_and, fmt_or, fmt_pairs, fmt_ul, fmt_ol, fmt_dl)) {
    expect_true("none" %in% names(formals(f)))
  }
})

test_that("1h none: function forms without none still fail on an empty vector; a non-empty one ignores none", {
  expect_error(fmt_and(character(0)), class = "weft_no_value")
  expect_error(fmt_or(character(0)), class = "weft_no_value")
  expect_error(fmt_pairs(numeric(0)), class = "weft_no_value")
  expect_error(fmt_ul(character(0)), class = "weft_no_value")
  expect_error(fmt_and(NULL, none = "none"), class = "weft_no_value")
  expect_equal(b_txt(fmt_and(c("a", "b"), none = "none")), "a and b")
  expect_equal(b_txt(fmt_and(c("a", "b"), none = NULL)), "a and b")
})

# ---- the two features in a render --------------------------------------------

H_CASES <- c(
  "[No sites were | # was | # were]{list=\"flagged\"} flagged.",                    # 1 zero
  "[No sites were | # was | # were]{list=\"flagged1\"} flagged.",                   # 2 one
  "[No sites were | # was | # were]{list=\"flagged3\"} flagged.",                   # 3 other
  "[None | # was | # were]{list=\"flagged3\" .or trunc=\"2\"} flagged.",             # 4 keys on the span
  "Flagged sites: `r flagged`{.and none=\"none\"}.",                                 # 5 none
  "Flagged sites: `r flagged3`{.and none=\"none\"}.",                                # 6 non-empty ignores none
  "Flagged sites: `r flagged`{.and .cap none=\"none\"}",                             # 7 text class on none
  "`r flagged`{.ul none=\"No sites flagged.\"}",                                     # 8 list class, inline text
  "[No sites were | # was | # were]{list=\"sites\"} sampled.",                      # 9 control on another vector
  "[None | # was | # were]{list=\"flagged\" .cap}"                                   # 10
)
H_WANT <- c(
  "No sites were flagged.", "Ridge was flagged.", "Ridge, Dam and Weir were flagged.",
  "Ridge or Dam were flagged.", "Flagged sites: none.", "Flagged sites: Ridge, Dam and Weir.",
  "Flagged sites: None", "No sites flagged.", "North, South and East were sampled.", "None"
)

test_that("1h render: central cases of list and none in prose under rmarkdown", {
  body <- batch_cases(H_CASES)
  res <- render_rmd(body, code = PRE_1H)
  expect_false(res$failed, label = substr(res$message, 1, 400))
  expect_equal(unesc(unlist(split_cases(res, length(H_CASES)))), H_WANT)
})

test_that("1h render: list and none in a figure caption under rmarkdown", {
  lines <- c(
    "```{r fig, echo=FALSE, fig.cap='[No sites were | # was | # were]{list=\"flagged\"} flagged; sites: `r flagged3`{.and none=\"none\"}.'}",
    "plot(1)",
    "```",
    "",
    "```{r fig2, echo=FALSE, fig.cap='Flagged: `r flagged`{.and none=\"none\"}.'}",
    "plot(1)",
    "```"
  )
  res <- render_rmd(lines, code = PRE_1H)
  expect_false(res$failed, label = substr(res$message, 1, 400))
  expect_match(res$md, "![No sites were flagged; sites: Ridge, Dam and Weir.](", fixed = TRUE)
  expect_match(res$md, "![Flagged: none.](", fixed = TRUE)
})

test_that("1h render: an unknown object in a list governor fails the render and never prints the zero arm", {
  # NULL is not an empty list: the render must not print the zero arm
  res <- render_rmd(batch_cases("[No sites were | # was | # were]{list=\"nosuchobject\"} flagged."),
                    code = PRE_1H)
  expect_true(res$failed)
  expect_false(grepl("No sites were flagged", res$md, fixed = TRUE))
})

test_that("1h render: under Quarto, central cases of list and none", {
  cases <- c(
    "[No sites were | # was | # were]{list=\"flagged\"} flagged.",
    "[No sites were | # was | # were]{list=\"flagged3\"} flagged.",
    "Flagged sites: `r flagged`{.and none=\"none\"}."
  )
  body <- batch_cases(cases)
  res <- render_qmd(body, code = PRE_1H)
  expect_false(res$failed, label = substr(res$message, 1, 400))
  expect_equal(unesc(unlist(split_cases(res, length(cases)))),
               c("No sites were flagged.", "Ridge, Dam and Weir were flagged.",
                 "Flagged sites: none."))
})
