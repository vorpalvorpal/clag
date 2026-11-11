# Stage 1g: a small number under the default digits prints to its first
# non-zero decimal (1e-9 noise tolerance), and an empty governed span takes
# one adjacent space with it. Contract: dev/design-1g.md.
#
# Renders are slow, so the markup rows of each topic are batched into one
# document and read back by case. Quarto is used for a few central cases only.
# Markdown rendering collapses runs of spaces, so exact spacing is read from
# weft_str() and from format = "knit" (the raw text weft wrote).

PRE_1G <- c(
  "fl <- FALSE; tr <- TRUE; k <- 3; o <- 1; d3 <- 3"
)

# a batch of one-paragraph cases through one engine
g_cases <- function(cases, engine = "rmd", format = "md", ...) {
  body <- batch_cases(cases)
  res <- if (engine == "rmd") {
    render_rmd(body, code = PRE_1G, format = format, ...)
  } else {
    render_qmd(body, code = PRE_1G, ...)
  }
  if (res$failed) stop("the batch did not render: ", substr(res$message, 1, 400), call. = FALSE)
  list(res = res, got = unlist(split_cases(res, length(cases))))
}

# ---- 1. a small number under the default digits -----------------------------

test_that("1g small: fmt_num and fmt_pct print a small number to its first non-zero decimal", {
  expect_equal(b_txt(fmt_num(0.04)), "0.04")
  expect_equal(b_txt(fmt_num(0.0449)), "0.04")
  expect_equal(b_txt(fmt_num(0.00061)), "0.0006")
  expect_equal(b_txt(fmt_num(-0.04)), paste0(B_MINUS, "0.04"))
  expect_equal(b_txt(fmt_pct(0.0004)), "0.04%")
  expect_equal(b_txt(fmt_pct(-0.0004)), paste0(B_MINUS, "0.04%"))
  expect_equal(b_txt(fmt_num(1e-6)), "0.000001")
})

test_that("1g small: the record's number is the number printed", {
  expect_equal(b_rec(fmt_num(0.0449))$number, 0.04)
  expect_equal(b_rec(fmt_num(0.04))$number, 0.04)
})

test_that("1g small: floating-point noise is zero and prints 0", {
  expect_equal(b_txt(fmt_num(0.1 + 0.2 - 0.3)), "0")
  expect_equal(b_txt(fmt_num(1e-12)), "0")
  expect_equal(b_txt(fmt_num(-1e-12)), "0")
  expect_false(grepl(B_MINUS, b_txt(fmt_num(-1e-12)), fixed = TRUE))
  expect_equal(b_txt(fmt_pct(1e-12)), "0%")
  expect_equal(b_txt(fmt_pct(-1e-12)), "0%")
  # control: a difference that is not noise prints its digits, cleanly
  expect_equal(b_txt(fmt_num(0.3 - 0.26)), "0.04")
})

test_that("1g small: digits or sigfig given on the call print as asked", {
  expect_equal(b_txt(fmt_num(0.04, digits = 1)), "0.0")
  expect_equal(b_txt(fmt_num(0.04, digits = 0)), "0")
  expect_equal(b_txt(fmt_num(0.04, digits = 2)), "0.04")
  expect_equal(b_txt(fmt_num(0.00061, digits = 2)), "0.00")
  expect_equal(b_txt(fmt_pct(0.0004, digits = 1)), "0.0%")
  expect_equal(b_txt(fmt_num(0.0449, sigfig = 2)), "0.045")
  expect_equal(b_txt(fmt_pct(0.0004, sigfig = 2)), "0.040%")
})

test_that("1g small: a vector is printed element by element", {
  expect_equal(b_txt(fmt_num(c(3.2, 0.04))), c("3.2", "0.04"))
  expect_equal(b_txt(fmt_num(c(0.04, 0.0449, 0.00061, 12))), c("0.04", "0.04", "0.0006", "12"))
  expect_equal(b_txt(fmt_num(c(0.1 + 0.2 - 0.3, 0.3 - 0.26))), c("0", "0.04"))
})

test_that("1g small: ordinary values are unchanged", {
  expect_equal(b_txt(fmt_num(3.14)), "3.1")
  expect_equal(b_txt(fmt_num(12)), "12")
  expect_equal(b_txt(fmt_num(0)), "0")
  expect_equal(b_txt(fmt_pct(0)), "0%")
  expect_equal(b_txt(fmt_num(0.06)), "0.1")
  expect_equal(b_txt(fmt_pct(0.0123)), "1.2%")
})

test_that("1g small: no weft_value_error is raised for a number that prints as zero", {
  expect_no_error(fmt_num(0.04))
  expect_no_error(fmt_num(-0.04))
  expect_no_error(fmt_num(1e-6))
  expect_no_error(fmt_num(c(3, 0.04)))
  expect_no_error(fmt_pct(0.0004))
  expect_no_error(fmt_pct(-0.0004))
  e <- tryCatch({ fmt_num(0.04); NULL }, error = function(e) e)
  expect_false(inherits(e, "weft_value_error"))
})

test_that("1g small: .no replaces only a printed zero", {
  expect_equal(b_txt(fmt_no(1e-6)), "0.000001")
  expect_equal(b_txt(fmt_no(0.04)), "0.04")
  expect_equal(b_txt(fmt_no(1e-12)), "no")
  expect_equal(b_txt(fmt_no(0)), "no")        # control
})

G_SMALL <- c(
  "`r 0.04`{.num}",                                              # 1
  "`r 0.0004`{.pct}",                                            # 2
  "`r 0.04`",                                                    # 3  a bare value: stock printing
  "`r -0.04`{.num}",                                             # 4
  "[up # | down # | flat]{sign=\"0.02\"}",                       # 5  positive arm, # prints 0.02
  "[up # | down # | flat]{sign=\"-0.02\"}",                      # 6  negative arm
  "[up # | down # | flat]{sign=\"1e-12\"}",                      # 7  below 1e-9: zero arm
  "[up # | down # | flat]{sign=\"0.02\" digits=\"1\"}",          # 8  digits given: 0.0, zero arm
  "[up # | down # | flat]{sign=\"0.02\" digits=\"2\"}",          # 9  control: 0.02 prints, positive
  "`r 1e-12`{.no}",                                              # 10
  "`r 1e-12`{.num}",                                             # 11
  "`r c(3.2, 0.04)`{.num .and}",                                 # 12
  "`r 0.04`{.num digits=\"1\"}",                                 # 13 as asked
  "`r 0.04`{.num sigfig=\"1\"}",                                 # 14
  "`r 0.1 + 0.2 - 0.3`{.num}",                                   # 15
  "`r 0.3 - 0.26`{.num}",                                        # 16
  "`r 3.14`{.num} and `r 12`{.num} and `r 0`{.num}",             # 17 controls
  "`r -1e-12`{.num}",                                            # 18
  "`r 0.00061`{.num} and `r 0.0449`{.num}",                      # 19
  "[small | large]{if=\"0.04 > 0\"} and `r 0.04`{#g1id .num} then [up # | down # | flat]{sign=\"#g1id\"}" # 20
)
G_SMALL_WANT <- c(
  "0.04", "0.04%", "0.04", paste0(B_MINUS, "0.04"),
  "up 0.02", "down 0.02", "flat", "flat", "up 0.02",
  "no", "0", "3.2 and 0.04", "0.0", "0.04", "0", "0.04",
  "3.1 and 12 and 0", "0", "0.0006 and 0.04",
  "small and 0.04 then up 0.04"
)

test_that("1g small: in markup under rmarkdown, each form prints by the rule and a sign governor follows what prints", {
  b <- g_cases(G_SMALL)
  expect_equal(unesc(b$got), G_SMALL_WANT)
})

test_that("1g small: a project default digits in _weft.yml does not count as given", {
  cases <- c("`r 0.04`{.num}", "`r 0.0004`{.pct}", "`r 3.14`{.num}",
             "`r 0.04`{.num digits=\"1\"}", "[up # | down # | flat]{sign=\"0.02\"}")
  b <- g_cases(cases, files = list("_weft.yml" = "digits: 1"))
  # the default digits (1) still apply where nothing small is involved (3.14);
  # a small number prints its first non-zero decimal; digits on the construct counts
  expect_equal(unesc(b$got), c("0.04", "0.04%", "3.1", "0.0", "up 0.02"))
})

test_that("1g small: no value error is collected in a knit", {
  res <- render_rmd(batch_cases(G_SMALL), code = PRE_1G, in_process = TRUE,
                    env = c(WEFT_DRAFT = "1"))
  expect_false(res$failed, label = res$message)
  expect_equal(NROW(res$knit$failures), 0L)
})

test_that("1g small: under Quarto", {
  b <- g_cases(c("`r 0.04`{.num}", "`r 0.0004`{.pct}",
                 "[up # | down # | flat]{sign=\"0.02\"} and `r 1e-12`{.no}"), engine = "qmd")
  expect_equal(unesc(b$got), c("0.04", "0.04%", "up 0.02 and no"))
})

# ---- 2. an empty arm and the space beside it --------------------------------

ws <- function(src, env = parent.frame()) {
  fl <- FALSE; tr <- TRUE; k <- 3; o <- 1; d3 <- 3
  weft::weft_str(src)
}

test_that("1g space: a space on both sides, the one before the span is removed", {
  expect_identical(ws('a [x | ]{if="fl"} b'), "a b")
  expect_identical(ws('a [x | ]{if="tr"} b'), "a x b")                     # control
  expect_identical(ws('one [x | ]{if="fl"} two three'), "one two three")
  expect_identical(ws('a [ | x]{if="tr"} b'), "a b")                       # first arm empty
})

test_that("1g space: at the start of the string and followed by a space, that space is removed", {
  expect_identical(ws('[x | ]{if="fl"} b'), "b")
  expect_identical(ws('[x | ]{if="tr"} b'), "x b")                         # control
})

test_that("1g space: preceded by a space and followed by one of . , ; : ! ? ) the space before is removed", {
  for (p in c(".", ",", ";", ":", "!", "?")) {
    expect_identical(ws(paste0('fell [sharply | ]{if="fl"}', p)), paste0("fell", p), label = p)
    expect_identical(ws(paste0('fell [sharply | ]{if="fl"}', p, ' Then')), paste0("fell", p, " Then"), label = p)
  }
  expect_identical(ws('(it fell [sharply | ]{if="fl"})'), "(it fell)")
  # controls: the span prints, so nothing moves
  expect_identical(ws('fell [sharply | ]{if="tr"}.'), "fell sharply.")
  expect_identical(ws('fell [sharply | ]{if="tr"})'), "fell sharply)")
})

test_that("1g space: preceded by a space and followed by the end of the string, the space before is removed", {
  expect_identical(ws('it fell [sharply | ]{if="fl"}'), "it fell")
  expect_identical(ws('it fell [sharply | ]{if="tr"}'), "it fell sharply")  # control
})

test_that("1g space: otherwise nothing is removed", {
  # no space on either side
  expect_identical(ws('a[x | ]{if="fl"}b'), "ab")
  # a space before and a letter or digit straight after: the space stays
  expect_identical(ws('a [x | ]{if="fl"}b'), "a b")
  # a letter before and a space after: the space stays
  expect_identical(ws('a[x | ]{if="fl"} b'), "a b")
  # the span is the whole string
  expect_identical(ws('[x | ]{if="fl"}'), "")
  # the span at the start, followed by a letter
  expect_identical(ws('[x | ]{if="fl"}b'), "b")
  # the span at the end, with no space before
  expect_identical(ws('a[x | ]{if="fl"}'), "a")
  # a punctuation mark before, a space after
  expect_identical(ws('a, [x | ]{if="fl"}b'), "a, b")
  # only one space of several is taken
  expect_identical(ws('a  [x | ]{if="fl"}  b'), "a   b")
})

test_that("1g space: a line break inside a paragraph counts as a space", {
  expect_identical(ws('a [x | ]{if="fl"}\nb'), "a\nb")
  expect_identical(ws('a\n[x | ]{if="fl"} b'), "a b")
  expect_identical(ws('a\n[x | ]{if="fl"}\nb'), "a\nb")
  expect_identical(ws('[x | ]{if="fl"}\nb'), "b")
  expect_identical(ws('fell\n[sharply | ]{if="fl"}.'), "fell.")
  # control: the span prints
  expect_identical(ws('a [x | ]{if="tr"}\nb'), "a x\nb")
  # a line break on one side only, and a letter on the other: nothing removed
  expect_identical(ws('a\n[x | ]{if="fl"}b'), "a\nb")
})

test_that("1g space: n and sign spans with an empty chosen arm take the space too", {
  expect_identical(ws('a [ | x]{n="o"} b'), "a b")                          # n: one, empty arm
  expect_identical(ws('a [x | ]{n="o"} b'), "a x b")                        # control: not the chosen arm
  expect_identical(ws('a [x | ]{n="k"} b'), "a b")                          # n: many, empty arm
  expect_identical(ws('fell [ | x]{n="o"}.'), "fell.")
  expect_identical(ws('[ | x]{n="o"} b'), "b")
  expect_identical(ws('a [ | x | y]{sign="d3"} b'), "a b")                 # sign: positive, empty
  expect_identical(ws('a [x | | y]{sign="-3"} b'), "a b")                   # sign: negative, empty
  expect_identical(ws('a [x | y | ]{sign="0"} b'), "a b")                   # sign: zero, empty
  expect_identical(ws('fell [x | y | ]{sign="0"}.'), "fell.")
  expect_identical(ws('a [x | y | ]{sign="d3"} b'), "a x b")                # control: prints
})

test_that("1g space: a nested empty span", {
  # the outer span's chosen arm is itself an empty span, so the outer prints nothing
  expect_identical(ws('a [[x | ]{if="fl"} | y]{if="tr"} b'), "a b")
  # an empty span inside a span that prints: the space rule applies inside the arm
  expect_identical(ws('a [p [x | ]{if="fl"} q | z]{if="tr"} b'), "a p q b")
  expect_identical(ws('a [p [x | ]{if="fl"}. | z]{if="tr"} b'), "a p. b")
})

test_that("1g space: two empty spans in a row each take one space", {
  expect_identical(ws('a [x | ]{if="fl"} [y | ]{if="fl"} b'), "a b")
  expect_identical(ws('fell [x | ]{if="fl"} [y | ]{if="fl"}.'), "fell.")
})

test_that("1g space: a span that prints something changes nothing around it", {
  expect_identical(ws('a [x | y]{if="fl"} b'), "a y b")
  expect_identical(ws('a [x | y]{if="tr"} b'), "a x b")
  expect_identical(ws('[x | y]{if="tr"} b'), "x b")
  expect_identical(ws('a [x | y]{if="tr"}.'), "a x.")
  expect_identical(ws('a [x | y]{if="tr"}'), "a x")
  expect_identical(ws('a  [x | y]{if="tr"}  b'), "a  x  b")
  expect_identical(ws('a [x | y]{if="tr"}\nb'), "a x\nb")
})

test_that("1g space: a value that prints an empty string is not a span and changes nothing", {
  expect_identical(ws("a `r ''` b"), "a  b")
  expect_identical(ws("a `r ''`."), "a .")
  expect_identical(ws("a `r ''`{.cap} b"), "a  b")
})

H_SPACE <- c(
  "Sadly [it | ]{if=\"fl\"} fell [sharply | ]{if=\"fl\"} on Monday.",      # 1  mid-sentence
  "[Sadly | ]{if=\"fl\"} it fell.",                                         # 2  start of block
  "It fell [sharply | ]{if=\"fl\"}",                                         # 3  end of block
  "It fell [sharply | ]{if=\"fl\"}.",                                       # 4  before a full stop
  "It fell [sharply | ]{if=\"fl\"}, then rose [slowly | ]{if=\"fl\"}; ok.", # 5  commas and semicolons
  "(It fell [sharply | ]{if=\"fl\"})",                                      # 6  before a bracket
  "- Item one [only | ]{if=\"fl\"}.\n- [Sadly | ]{if=\"fl\"} item two.",    # 7  list items
  "# Heading [here | ]{if=\"fl\"}",                                          # 8  heading
  "# [Old | ]{if=\"fl\"} Heading",                                          # 9  heading, start
  "It fell [sharply | slowly]{if=\"fl\"}."                                  # 10 control: prints
)

test_that("1g space: in rendered prose no stray space is left before punctuation or at a block edge", {
  b <- g_cases(H_SPACE)
  got <- unesc(b$got)
  expect_equal(got[1], "Sadly fell on Monday.")
  expect_equal(got[2], "it fell.")
  expect_equal(got[3], "It fell")
  expect_equal(got[4], "It fell.")
  expect_equal(got[5], "It fell, then rose; ok.")
  expect_equal(got[6], "(It fell)")
  expect_match(got[7], "- Item one.", fixed = TRUE)
  expect_match(got[7], "- item two.", fixed = TRUE)
  expect_equal(got[8], "# Heading")
  expect_match(got[9], "Heading", fixed = TRUE)
  expect_false(grepl("Old", got[9], fixed = TRUE))
  expect_equal(got[10], "It fell slowly.")
})

test_that("1g space: the raw text weft wrote has the space removed (knit, exact spacing)", {
  b <- g_cases(H_SPACE, format = "knit")
  got <- b$got
  expect_equal(got[1], "Sadly fell on Monday.")
  expect_equal(got[2], "it fell.")                 # no leading space at the start of the block
  expect_equal(got[3], "It fell")                  # no trailing space at the end of the block
  expect_equal(got[4], "It fell.")
  expect_equal(got[5], "It fell, then rose; ok.")
  expect_equal(got[6], "(It fell)")
  expect_equal(got[7], "- Item one.\n- item two.")
  expect_equal(got[8], "# Heading")
  expect_equal(got[10], "It fell slowly.")
})

test_that("1g space: a figure caption has the space removed", {
  lines <- c(
    "```{r fig, echo=FALSE, fig.cap='Fell [sharply | ]{if=\"fl\"}.'}",
    "plot(1)",
    "```",
    "",
    "```{r fig2, echo=FALSE, fig.cap='[Sadly | ]{if=\"fl\"} fell [sharply | ]{if=\"fl\"} again'}",
    "plot(1)",
    "```"
  )
  res <- render_rmd(lines, code = PRE_1G)
  expect_false(res$failed, label = res$message)
  expect_match(res$md, "![Fell.](", fixed = TRUE)
  expect_false(grepl("Fell .", res$md, fixed = TRUE))
  expect_match(res$md, "![fell again](", fixed = TRUE)
})

test_that("1g space: a front-matter field has the space removed", {
  lines <- c("---", "title: \"t\"", "abstract: |",
             "  Result [sharply | ]{if=\"1 > 2\"}.",
             "knitr:", "  opts_knit:", "    weft: !expr weft::weft_setup()",
             "---", "", "Body.", "")
  r <- rmd_html(lines)
  expect_false(r$failed, label = r$message)
  expect_match(r$html, "Result.", fixed = TRUE)
  expect_false(grepl("Result .", r$html, fixed = TRUE))
})

test_that("1g space: under Quarto", {
  b <- g_cases(c("It fell [sharply | ]{if=\"fl\"}.",
                 "Sadly [it | ]{if=\"fl\"} fell [sharply | slowly]{if=\"fl\"}.",
                 "- Item [only | ]{if=\"fl\"}."), engine = "qmd")
  got <- unesc(b$got)
  expect_equal(got[1], "It fell.")
  expect_equal(got[2], "Sadly fell slowly.")
  expect_match(got[3], "- Item.", fixed = TRUE)
})
