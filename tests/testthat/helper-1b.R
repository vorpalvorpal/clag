# Helpers and fixture tables for the stage 1b / 1d tests (agreement and
# direction; phrases and lists). Rules are from PACKAGE-SCOPING.md, the
# internal contract is dev/design-1b.md (with dev/design-1a.md).
#
# It sits beside helper-render.R and uses render_rmd(), render_qmd(),
# batch_cases(), split_cases(), canon_md(), unesc(), at_line() and
# skip_if_no_quarto() from it. Nothing here edits those.
#
# The rows of the markup tables live here, in three batches, because every
# batch is rendered once per engine and shared by the test files:
#
#   A  sign, ids, .p, clamp(), .range, .date
#   B  .cap, .a, lookup(), brk(), phrase functions, .weft-literal
#   C  .pairs, trunc, .ul .ol .dl and the collapse interplay
#
# A test file asks for the rows of one group (b_expect_rows("A", "sign",
# "rmd")); the first to ask renders the batch, the rest read the cache.

B_MINUS <- "−"   # the default minus sign
B_EN <- "–"      # the en dash of a range

# ---- small things for direct tests -----------------------------------------

b_txt <- function(x) as.character(unclass(x))
b_rec <- function(x) {
  list(text = as.character(unclass(x)), number = attr(x, "number"),
       decimals = attr(x, "decimals"), relation = attr(x, "relation"))
}

# the construct errors the scanner finds, from the source alone
b_errs <- function(text) {
  r <- weft:::scan_text(text)
  e <- r$error[!is.na(r$error)]
  as.character(e)
}

# expect `bad` to be a construct error found from the source (and not the
# "not built yet" stop of stage 1a), and `good` to be clean
b_expect_scan_error <- function(bad, good = NULL, label = bad) {
  e <- b_errs(bad)
  testthat::expect_gte(length(e), 1L, label = paste("a construct error is found:", label))
  testthat::expect_false(any(grepl("not built yet", e)),
                         label = paste("not the 'not built yet' stop:", label))
  if (!is.null(good)) {
    testthat::expect_identical(b_errs(good), character(),
                               label = paste("the legal control has no error:", good))
  }
  invisible(e)
}

# stop the test (an error, so it fails and does not skip) when a document that
# should have rendered did not
b_need <- function(res) {
  if (isTRUE(res$failed)) {
    stop("the document did not render: ", substr(res$message, 1, 400), call. = FALSE)
  }
  invisible(res)
}

# ---- the setup the markup rows share ------------------------------------------

PRE_B <- c(
  "k <- 3; z <- 0; o <- 1; tw <- 2; x <- 1.2; neg <- -4",
  "flag <- TRUE; noflag <- FALSE",
  "sites <- c('A', 'B', 'C'); pair <- c('A', 'B'); solo <- 'A'",
  "means <- c(A = 1.2, B = 3.4, C = 5.6); pcts <- c(A = 0.12, B = 0.5)",
  "many <- letters[1:7]; lo <- 3; hi <- 5",
  "up <- 0.12; down <- -0.12; zero_chg <- 0; tiny <- 0.0001",
  "d3 <- 3; dneg3 <- -3; d1 <- 1; dm1 <- -1; d15 <- 1.5; dneg25 <- -2.5",
  "d1date <- as.Date('2024-06-03'); dts <- as.Date(c('2024-06-03', '2024-07-04'))",
  "of_n <- weft::of_n; about <- weft::about; ci <- weft::ci; pm <- weft::pm",
  "clamp <- weft::clamp; lookup <- weft::lookup; brk <- weft::brk",
  "tier_lab <- lookup(c(hi = 'high', lo = 'low'))",
  "fct <- factor('hi', levels = c('lo', 'hi'))",
  "trend <- brk(. < 0.95 ~ 'a fall in', . <= 1.05 ~ 'steady', TRUE ~ 'a rise in')",
  "only_neg <- brk(. < 0 ~ 'neg')",
  "cnt <- new.env()",
  "bump <- function(tag, v) { cnt[[tag]] <- (if (is.null(cnt[[tag]])) 0 else cnt[[tag]]) + 1; v }"
)

b_ok <- function(grp, rule, src, out, only = NULL) {
  list(grp = grp, rule = rule, src = src, out = out, only = only)
}

# ---- batch A: sign, ids, .p, clamp(), .range, .date -------------------------------

rows_sign <- list(
  b_ok("sign", "1.5.1 + 1.5.8: positive arm, # is the magnitude, .pct",
       r"---(Abundance [rose by # | fell by # | did not change]{.pct sign="up"}.)---",
       "Abundance rose by 12%."),
  b_ok("sign", "1.5.1 + 1.5.8: negative arm prints the magnitude without its sign",
       r"---(Abundance [rose by # | fell by # | did not change]{.pct sign="down"}.)---",
       "Abundance fell by 12%."),
  b_ok("sign", "1.5.1: three arms, zero arm",
       r"---(Abundance [rose by # | fell by # | did not change]{.pct sign="zero_chg"}.)---",
       "Abundance did not change."),
  b_ok("sign", "1.5.10: a change that prints as 0.0% takes the zero arm",
       r"---([rose by # | fell by # | did not change]{.pct sign="tiny"})---",
       "did not change"),
  b_ok("sign", "1.5.10 + 1.5.18: under the default class a small change prints 0.0 and takes the zero arm",
       r"---([up # | down # | flat]{sign="0.02"} and [up # | down # | flat]{sign="-0.02"})---",
       "flat and flat"),
  b_ok("sign", "1.5.10 + 1.4.7: digits 0 prints 0 and takes the zero arm",
       r"---([rose by # | fell by # | flat]{sign="-0.4" digits="0"})---",
       "flat"),
  b_ok("sign", "1.5.10 + 1.4.7: digits 0 on -1.4 prints 1 under the negative arm",
       r"---([rose by # | fell by # | flat]{sign="-1.4" digits="0"})---",
       "fell by 1"),
  b_ok("sign", "1.5.1: two arms, positive", r"---([rose | fell]{sign="d3"})---", "rose"),
  b_ok("sign", "1.5.1: two arms, negative", r"---([rose | fell]{sign="dneg3"})---", "fell"),
  b_ok("sign", "1.5.8: the magnitude under the default class (negative, 3)",
       r"---([rose by # | fell by #]{sign="dneg3"})---", "fell by 3"),
  b_ok("sign", "1.5.8 + 1.4.13: the magnitude of a decimal prints to the default digits",
       r"---([rose by # | fell by #]{sign="dneg25"})---", "fell by 2.5"),
  b_ok("sign", "1.5.7: a wording class on the governor",
       r"---([rose by # | fell by #]{.word sign="dneg3"})---", "fell by three"),
  b_ok("sign", "1.5.7: a text class acts on the chosen arm's final text",
       r"---([rose | fell]{.strong sign="dneg3"})---", "**fell**"),
  b_ok("sign", "1.2.6: pass-through on a sign span",
       r"---([rose | fell]{sign="d3" .smallcaps})---", "[rose]{.smallcaps}"),
  b_ok("sign", "1.5.6: a check in the governor's expression",
       r"---([rose | fell]{sign="claim(d3, . > 0)"})---", "rose"),
  b_ok("sign", "1.2.2: unquoted sign", r"---([rose | fell]{sign=d3})---", "rose"),
  b_ok("sign", "1.2.10: Sign is sign", r"---([rose | fell]{Sign="d3"})---", "rose"),
  b_ok("sign", "1.5.15: a value inside a sign arm",
       r"---([up `r k`{.word} | down]{sign="d3"})---", "up three"),
  b_ok("sign", "1.5.15: a sign span in a heading", "## [Up | Down]{sign=\"dneg3\"}", "## Down"),
  b_ok("sign", "1.5.16: a sign span in the chosen arm of an if span",
       r"---([[rose | fell]{sign="d3"} | none]{if="flag"})---", "rose"),
  b_ok("sign", "1.7.2: n=\".\" agrees with the magnitude (1, positive)",
       r"---([rose by # point[ | s]{n="."} | fell by # point[ | s]{n="."}]{sign="d1"})---",
       "rose by 1 point"),
  b_ok("sign", "1.7.2: n=\".\" agrees with the magnitude (-1 is 1, not -1)",
       r"---([rose by # point[ | s]{n="."} | fell by # point[ | s]{n="."}]{sign="dm1"})---",
       "fell by 1 point"),
  b_ok("sign", "1.7.2: n=\".\" agrees with the magnitude (-3)",
       r"---([rose by # point[ | s]{n="."} | fell by # point[ | s]{n="."}]{sign="dneg3"})---",
       "fell by 3 points"),
  b_ok("sign", "1.7.2 + 1.5.9: n=\".\" agrees with the magnitude as printed (1.5 is not one)",
       r"---([rose by # point[ | s]{n="."} | fell by # point[ | s]{n="."}]{sign="d15"})---",
       "rose by 1.5 points")
)

rows_ids <- list(
  b_ok("ids", "1.7.6 + 1.7.8: a back-reference to a value printed with decimals takes the other arm",
       r"---(Depth was `r 3.2`{#zid1 .num} m. The [core | cores]{n="#zid1"} ran.)---",
       "Depth was 3.2 m. The cores ran."),
  b_ok("ids", "1.7.6: a back-reference to a printed 1 takes the one arm",
       r"---(Depth was `r 1`{#zid2 .num} m. The [core | cores]{n="#zid2"} ran.)---",
       "Depth was 1 m. The core ran."),
  b_ok("ids", "1.7.8 + 1.7.9: with no formatter of its own the span uses the printed record (words)",
       r"---(Found `r k`{#zid3 .word} sites. Of these, [# core | # cores]{n="#zid3"}.)---",
       "Found three sites. Of these, three cores."),
  b_ok("ids", "1.7.8: the record (1.0 plural, no formatter) against a fresh format (digits 0, one) against a text class (still the record)",
       r"---(Value `r 1.04`{#zid4 .num digits="1"}. [# site | # sites]{n="#zid4"}; [# site | # sites]{n="#zid4" digits="0"}; [# site | # sites]{.strong n="#zid4"}.)---",
       "Value 1.0. 1.0 sites; 1 site; **1.0 sites**."),
  b_ok("ids", "1.7.8: pass-through attributes do not count as formatters",
       r"---(Value `r 1.04`{#zid5 .num digits="1"}. [# site | # sites]{.smallcaps n="#zid5"}.)---",
       "Value 1.0. [1.0 sites]{.smallcaps}."),
  b_ok("ids", "1.7.9: [#]{n=\"#d\"} prints the value again",
       r"---(Total `r 12345.678`{#zid6 .num}. Again [#]{n="#zid6"}.)---",
       "Total 12,345.7. Again 12,345.7."),
  b_ok("ids", "1.7.8: a formatter on the referring span formats the raw value afresh",
       r"---(Share `r 0.12`{#zid7 .pct}. Again [#]{.num n="#zid7"}.)---",
       "Share 12%. Again 0.1."),
  b_ok("ids", "1.7.2 + 1.7.6: sign takes a back-reference",
       paste0("Change `r -3`{#zid8 .num}. It [rose by # | fell by #]{sign=\"#zid8\"} points."),
       paste0("Change ", B_MINUS, "3. It fell by 3 points.")),
  b_ok("ids", "1.5.10 + 1.7.8: a back-reference to a change that printed 0.0 takes the zero arm",
       r"---(Change `r -0.02`{#zid9 .num}. It was [up | down | flat]{sign="#zid9"}.)---",
       "Change 0.0. It was flat."),
  b_ok("ids", "1.7.5: an id on a governed span names its printed occurrence",
       r"---(There were [# site | # sites]{n="k" #zid10}. [Was | Were]{n="#zid10"} all sampled?)---",
       "There were 3 sites. Were all sampled?"),
  b_ok("ids", "1.7.7: the referring spans evaluate nothing (the counter stays 1)",
       "Depth `r bump('zc1', 3)`{#zid12 .num} m. A [core | cores]{n=\"#zid12\"} and [core | cores]{n=\"#zid12\"}.\n\nRuns: `r cnt$zc1`.",
       "Depth 3 m. A cores and cores.\n\nRuns: 1."),
  b_ok("ids", "1.7.7: a check on the id's value ran once, not once per reference",
       "Depth `r claim(bump('zc2', 3), . > 0)`{#zid13 .num} m. [A | B]{n=\"#zid13\"}, [A | B]{n=\"#zid13\"}, [A | B]{n=\"#zid13\"}.\n\nRuns: `r cnt$zc2`.",
       "Depth 3 m. B, B, B.\n\nRuns: 1."),
  b_ok("ids", "1.5.16 + 1.7.11: an id defined in the chosen arm is referred to from inside the same arm",
       r"---([Depth `r 3`{#zid14 .num}; [core | cores]{n="#zid14"} | none]{if="flag"})---",
       "Depth 3; cores"),
  b_ok("ids", "1.5.16: a value in the arm that is not chosen does not run (its id does not exist)",
       r"---([A `r 1`{#zid15a .num} | B `r 2`{#zid15b .num}]{if="flag"})---",
       "A 1"),
  b_ok("ids", "1.2.8: an id on a value in a heading is not emitted",
       "## Depth `r 3.2`{#zid17 .num}", "## Depth 3.2"),
  b_ok("ids", "1.2.8 + 1.2.6: an id is not passed through with the other attributes",
       r"---(`r x`{#zid18 .num .smallcaps})---", "[1.2]{.smallcaps}")
)

rows_p <- list(
  b_ok("p", "1.4.3: .p, two decimals", r"---(Result: `r 0.03`{.p}.)---", "Result: p = 0.03."),
  b_ok("p", "design: .p keeps a trailing zero (two decimals from 0.01)",
       r"---(`r 0.2`{.p} and `r 0.5`{.p})---", "p = 0.20 and p = 0.50"),
  b_ok("p", "design: .p, three decimals below 0.01", r"---(`r 0.004`{.p})---", "p = 0.004"),
  b_ok("p", "1.4.3: .p is never p = 0.000", r"---(`r 0.0004`{.p})---", "p < 0.001"),
  b_ok("p", "design: .p of exactly 0.001 is not below it", r"---(`r 0.001`{.p})---", "p = 0.001"),
  b_ok("p", "design: .p above 0.99", r"---(`r 0.9991`{.p})---", "p > 0.99"),
  b_ok("p", "1.4.1: a text class after .p", r"---(`r 0.0004`{.p .strong})---", "**p < 0.001**"),
  b_ok("p", "1.4.1: .p then .cap", r"---(`r 0.03`{.p .cap})---", "P = 0.03"),
  b_ok("p", "1.4.1: .p then a collapse class",
       r"---(`r c(0.03, 0.0004)`{.p .and})---", "p = 0.03 and p < 0.001")
)

rows_clamp <- list(
  b_ok("clamp", "3.5.1: clamp() inside the bounds prints the value as .num does",
       r"---(Value `r clamp(5, 1, 99)`{.em}.)---", "Value *5*."),
  b_ok("clamp", "3.5.1: clamp() above the ceiling",
       r"---(Value `r clamp(150, 1, 99)`{.em}.)---", "Value *> 99*."),
  b_ok("clamp", "3.5.1: clamp() below the floor, and a text class keeps the bound",
       r"---(Value `r clamp(0.5, 1)`{.strong}.)---", "Value **< 1**."),
  b_ok("clamp", "1.5.9 + 3.5.4: a bound takes the other arm (even though its number is 1)",
       r"---([none | one | # many]{n="clamp(0.2, 1)"})---", "< 1 many")
)

rows_range <- list(
  b_ok("range", "1.4.3: .range, an en dash and no spaces",
       r"---(Sites `r c(3, 5)`{.range}.)---", paste0("Sites 3", B_EN, "5.")),
  b_ok("range", "1.4.4: both ends the same print one number", r"---(`r c(3, 3)`{.range})---", "3"),
  b_ok("range", "1.4.4: a negative end writes ' to ' (both negative)",
       r"---(`r c(-5, -3)`{.range})---", paste0(B_MINUS, "5 to ", B_MINUS, "3")),
  b_ok("range", "1.4.4: a negative end writes ' to ' (one negative)",
       r"---(`r c(-2, 3)`{.range})---", paste0(B_MINUS, "2 to 3")),
  b_ok("range", "design: decimals", r"---(`r c(1.5, 2.5)`{.range})---", paste0("1.5", B_EN, "2.5")),
  b_ok("range", "1.4.1: stage i then iii, each end printed by the number stage",
       r"---(`r c(0.1, 0.2)`{.pct .range})---", paste0("10%", B_EN, "20%")),
  b_ok("range", "1.4.4 + 1.4.7: ends that print the same under digits 0 print one number",
       r"---(`r c(2.9, 3.1)`{.range digits="0"})---", "3"),
  b_ok("range", "1.4.7: digits reaches both ends",
       r"---(`r c(3, 5)`{.range digits="1"})---", paste0("3.0", B_EN, "5.0")),
  b_ok("range", "9.1.5: the thousands mark inside a range",
       r"---(`r c(10000, 20000)`{.range})---", paste0("10,000", B_EN, "20,000")),
  b_ok("range", "1.4.1: stage ii then iii", r"---(`r c(2, 4)`{.word .range})---", paste0("two", B_EN, "four")),
  b_ok("range", "1.4.1: stage iv acts on the collapsed text", r"---(`r c(3, 5)`{.range .strong})---",
       paste0("**3", B_EN, "5**")),
  b_ok("range", "1.5.11: .range on n, the span takes the plural",
       r"---([# site | # sites]{.range n="c(lo, hi)"})---", paste0("3", B_EN, "5 sites")),
  b_ok("range", "1.5.11: .range on n, a range that collapses to a printed 1 takes the singular",
       r"---([# site | # sites]{.range n="c(1, 1)"})---", "1 site"),
  b_ok("range", "1.5.11: .range on n, a range that collapses to 2 takes the plural",
       r"---([# site | # sites]{.range n="c(2, 2)"})---", "2 sites"),
  b_ok("range", "1.5.11: .range on n, 0 to 1 takes the plural",
       r"---([# site | # sites]{.range n="c(0, 1)"})---", paste0("0", B_EN, "1 sites")),
  b_ok("range", "1.5.9 + 1.5.11: .range on n judges the ends as printed (digits 0)",
       r"---([# site | # sites]{.range n="c(1, 1.04)" digits="0"})---", "1 site"),
  b_ok("range", "1.4.4 + 1.5.11: .range on n with negative ends",
       r"---([# metre | # metres]{.range n="c(-5, -3)"})---",
       paste0(B_MINUS, "5 to ", B_MINUS, "3 metres"))
)

rows_date <- list(
  b_ok("date", "1.4.3 + design: .date, the default format", r"---(On `r d1date`{.date}.)---", "On 3 June 2024."),
  b_ok("date", "design: a day below ten has no leading zero",
       r"---(`r as.Date('2024-01-05')`{.date})---", "5 January 2024"),
  b_ok("date", "1.4.1: stage i then iii", r"---(`r dts`{.date .and})---", "3 June 2024 and 4 July 2024"),
  b_ok("date", "1.4.1: a text class after .date", r"---(`r d1date`{.date .strong})---", "**3 June 2024**"),
  b_ok("date", "design: .date takes a POSIXct",
       r"---(`r as.POSIXct('2024-12-31 23:00:00', tz = 'UTC')`{.date})---", "31 December 2024")
)

B_ROWS_A <- c(rows_sign, rows_ids, rows_p, rows_clamp, rows_range, rows_date)

# ---- batch B: .cap, .a, lookup(), brk(), phrases, .weft-literal -------------------

a_digit_rows <- lapply(
  list(c(8, "an 8"), c(11, "an 11"), c(18, "an 18"), c(80, "an 80"), c(85, "an 85"),
       c(800, "an 800"), c(899, "an 899"), c(1, "a 1"), c(12, "a 12"), c(100, "a 100"),
       c(8000, "an 8000"), c(11000, "an 11,000"), c(18000, "an 18,000")),
  function(v) b_ok("a", paste0("design: .a by sound, ", v[1], " (digits)"),
                   sprintf("`r %s`{.a}", v[1]), v[2]))
a_word_rows <- lapply(
  list(c(8, "an eight"), c(11, "an eleven"), c(18, "an eighteen"), c(80, "an eighty"),
       c(85, "an eighty-five"), c(1, "a one"), c(12, "a twelve")),
  function(v) b_ok("a", paste0("design: .a by sound, ", v[1], " (words)"),
                   sprintf("`r %s`{.word .a}", v[1]), v[2]))

rows_a <- c(
  a_digit_rows, a_word_rows,
  list(
    b_ok("a", "design: .a on a decimal", r"---(`r 8.5`{.a} and `r 1.5`{.a})---", "an 8.5 and a 1.5"),
    b_ok("a", "design: .a after .pct", r"---(`r 0.08`{.pct .a} and `r 0.12`{.pct .a})---", "an 8% and a 12%"),
    b_ok("a", "design: .a after .ord", r"---(`r 8`{.ord .a}, `r 11`{.ord .a} and `r 3`{.ord .a})---",
         "an 8th, an 11th and a 3rd"),
    b_ok("a", "1.4.1: .a then .cap, either order",
         r"---(`r 8`{.a .cap} and `r 8`{.cap .a})---", "An 8 and An 8"),
    b_ok("a", "1.4.1: .word .a .cap", r"---(`r 11`{.word .a .cap} and `r 12`{.word .a .cap})---",
         "An eleven and A twelve"),
    b_ok("a", "1.4.1: .a, .cap, then .strong wraps the article", r"---(`r 8`{.a .strong} and `r 8`{.a .cap .strong})---",
         "**an 8** and **An 8**"),
    b_ok("a", "1.4.3: .a on a text span, the spec's example (11 and 12)",
         r"---([11-year]{.a} and [12-year]{.a})---", "an 11-year and a 12-year"),
    b_ok("a", "1.4.3: .a on a number word in a text span",
         r"---([eleven-year]{.a} and [twelve-year]{.a})---", "an eleven-year and a twelve-year"),
    b_ok("a", "1.4.3: .a before a hyphenated unit",
         r"---(It was `r 11`{.a}-year study and `r 12`{.a}-year study.)---",
         "It was an 11-year study and a 12-year study.")
  )
)

rows_cap <- list(
  b_ok("cap", "1.4.3: .cap on a text span", r"---([results]{.cap})---", "Results"),
  b_ok("cap", "design: .cap skips leading emphasis marks (em)", r"---([*abc* def]{.cap})---", "*Abc* def"),
  b_ok("cap", "design: .cap skips leading emphasis marks (strong)", r"---([**bold** text]{.cap})---", "**Bold** text"),
  b_ok("cap", "design: .cap capitalises a non-ASCII letter", r"---([élan]{.cap})---", "Élan"),
  b_ok("cap", "1.3: `r k`{.word .cap} is Three, either order",
       r"---(`r k`{.word .cap} and `r k`{.cap .word})---", "Three and Three"),
  b_ok("cap", "1.4.1: .no .word .cap", r"---(`r z`{.no .word .cap})---", "No"),
  b_ok("cap", "1.5.7: .cap acts on the chosen arm's final text (n)",
       r"---([no sites | one site | # sites]{.cap n="z"})---", "No sites"),
  b_ok("cap", "1.5.7: .cap acts on the chosen arm (if, true)", r"---([a | b]{.cap if="flag"})---", "A"),
  b_ok("cap", "1.5.7: .cap acts on the chosen arm (if, false)", r"---([a | b]{.cap if="noflag"})---", "B"),
  b_ok("cap", "1.4.1: .cap with .strong, either order",
       r"---([results]{.cap .strong} and [results]{.strong .cap})---", "**Results** and **Results**"),
  b_ok("cap", "1.2.6 + 1.5.7: an empty chosen arm stays empty with .cap",
       r"---(x[ | y]{.cap if="flag"}z)---", "xz"),
  b_ok("cap", "1.4.1: .cap acts on the collapsed text", r"---(`r c('x', 'y')`{.and .cap})---", "X and Y"),
  b_ok("cap", "1.4.1: .cap after a phrase picked by lookup()", r"---(`r tier_lab('hi')`{.cap})---", "High"),
  b_ok("cap", "1.4.1: .cap after a phrase picked by brk()", r"---(`r trend(0.9)`{.cap} rates)---", "A fall in rates"),
  b_ok("cap", "1.4.1: .cap after about()", r"---(`r about(0.49)`{.cap})---", "Nearly half"),
  b_ok("cap", "1.4.1: .cap after of_n()", r"---(`r of_n(5, 5, 'site', 'sites')`{.cap})---", "All 5 sites"),
  b_ok("cap", "1.1.9: a text span after a sentence", r"---(Done. [results]{.cap} follow.)---", "Done. Results follow.")
)

rows_lookup <- list(
  b_ok("lookup", "3.3.1: lookup() in a bare value", r"---(Tier: `r tier_lab('hi')` here.)---", "Tier: high here."),
  b_ok("lookup", "3.3.1: brk() in a bare value, the first formula",
       r"---(`r trend(0.9)` rates)---", "a fall in rates"),
  b_ok("lookup", "3.3.3: brk(), the second formula (boundary included)", r"---(`r trend(1)`)---", "steady"),
  b_ok("lookup", "3.3.3: brk(), the last formula", r"---(`r trend(1.2)`)---", "a rise in"),
  b_ok("lookup", "design: lookup() vectorises, then a collapse class",
       r"---(`r tier_lab(c('hi', 'lo'))`{.and})---", "high and low"),
  b_ok("lookup", "design: brk() vectorises, then a collapse class",
       r"---(`r trend(c(0.5, 1, 2))`{.and})---", "a fall in, steady and a rise in"),
  b_ok("lookup", "1.4.1: a text class after lookup()", r"---(`r tier_lab('lo')`{.strong})---", "**low**"),
  b_ok("lookup", "3.3.2: a factor is looked up by label, never by integer code",
       r"---(`r tier_lab(fct)`)---", "high")
)

rows_phrases <- list(
  b_ok("phrases", "3.5.1: of_n(), k of n", r"---(Only `r of_n(3, 7, 'site', 'sites')` were sampled.)---",
       "Only 3 of the 7 sites were sampled."),
  b_ok("phrases", "3.5.1: of_n(), none", r"---(`r of_n(0, 4, 'site', 'sites')`)---", "none of the 4 sites"),
  b_ok("phrases", "3.5.1: of_n(), the only", r"---(`r of_n(1, 1, 'site', 'sites')`)---", "the only site"),
  b_ok("phrases", "3.5.1: of_n(), both", r"---(`r of_n(2, 2, 'site', 'sites')`)---", "both sites"),
  b_ok("phrases", "3.5.1: of_n(), all", r"---(`r of_n(5, 5, 'site', 'sites')`)---", "all 5 sites"),
  b_ok("phrases", "3.5.1: of_n(), 1 of n", r"---(`r of_n(1, 7, 'site', 'sites')`)---", "1 of the 7 sites"),
  b_ok("phrases", "3.5.2: an n span after of_n() agrees with k (1, singular)",
       r"---(`r of_n(1, 7, 'site', 'sites')`{#zidf1} [was | were]{n="#zidf1"} sampled.)---",
       "1 of the 7 sites was sampled."),
  b_ok("phrases", "3.5.2: an n span after of_n() agrees with k (3, plural)",
       r"---(`r of_n(3, 7, 'site', 'sites')`{#zidf2} [was | were]{n="#zidf2"} sampled.)---",
       "3 of the 7 sites were sampled."),
  b_ok("phrases", "3.5.2: an n span after of_n() agrees with k (the only)",
       r"---(`r of_n(1, 1, 'site', 'sites')`{#zidf3} [was | were]{n="#zidf3"} sampled.)---",
       "the only site was sampled."),
  b_ok("phrases", "3.5.2: an n span after of_n() agrees with k (none is 0, plural)",
       r"---(`r of_n(0, 4, 'site', 'sites')`{#zidf4} [was | were]{n="#zidf4"} sampled.)---",
       "none of the 4 sites were sampled."),
  b_ok("phrases", "3.5.2 + 1.4.11: of_n() given straight to n selects on its record",
       r"---([was | were]{n="of_n(1, 7, 'site', 'sites')"} and [was | were]{n="of_n(3, 7, 'site', 'sites')"})---",
       "was and were"),
  b_ok("phrases", "3.5.1: about(), half", r"---(`r about(0.5)`)---", "half"),
  b_ok("phrases", "3.5.1: about(), nearly", r"---(`r about(0.49)`)---", "nearly half"),
  b_ok("phrases", "3.5.1: about(), just over", r"---(`r about(0.51)`)---", "just over half"),
  b_ok("phrases", "design: about(), a quarter", r"---(`r about(0.25, to = 1/4)`, `r about(0.24, to = 1/4)` and `r about(0.26, to = 1/4)`)---",
       "a quarter, nearly a quarter and just over a quarter"),
  b_ok("phrases", "design: about(), a third", r"---(`r about(0.33, to = 1/3)`, `r about(0.32, to = 1/3)` and `r about(0.34, to = 1/3)`)---",
       "a third, nearly a third and just over a third"),
  b_ok("phrases", "design: about(), two-thirds", r"---(`r about(0.67, to = 2/3)`, `r about(0.66, to = 2/3)` and `r about(0.68, to = 2/3)`)---",
       "two-thirds, nearly two-thirds and just over two-thirds"),
  b_ok("phrases", "design: about(), three-quarters", r"---(`r about(0.75, to = 3/4)`, `r about(0.74, to = 3/4)` and `r about(0.76, to = 3/4)`)---",
       "three-quarters, nearly three-quarters and just over three-quarters"),
  b_ok("phrases", "3.5.3: about() takes a tolerance argument",
       r"---(`r about(0.56, tolerance = 0.1)`)---", "just over half"),
  b_ok("phrases", "3.5.1: ci()", r"---(`r ci(2.1, 1.3, 2.9)`)---", "2.1 (95% CI 1.3 to 2.9)"),
  b_ok("phrases", "3.5.1 + 1.4.13: ci() prints whole numbers as .num does", r"---(`r ci(2, 1, 3)`)---",
       "2 (95% CI 1 to 3)"),
  b_ok("phrases", "3.5.3: ci() takes a level argument", r"---(`r ci(2.1, 1.3, 2.9, level = 0.9)`)---",
       "2.1 (90% CI 1.3 to 2.9)"),
  b_ok("phrases", "design: ci() takes digits", r"---(`r ci(2.1, 1.3, 2.9, digits = 2)`)---",
       "2.10 (95% CI 1.30 to 2.90)"),
  b_ok("phrases", "9.1.5 + design: ci() with negative numbers uses the configured minus",
       r"---(`r ci(-0.5, -1.2, 0.3)`)---",
       paste0(B_MINUS, "0.5 (95% CI ", B_MINUS, "1.2 to 0.3)")),
  b_ok("phrases", "1.4.1: a text class after ci()", r"---(`r ci(2.1, 1.3, 2.9)`{.strong})---",
       "**2.1 (95% CI 1.3 to 2.9)**"),
  b_ok("phrases", "3.5.1: pm()", r"---(`r pm(2.1, 0.3)`)---", "2.1 ± 0.3"),
  b_ok("phrases", "design: pm() takes digits", r"---(`r pm(2.1, 0.3, digits = 2)`)---", "2.10 ± 0.30"),
  b_ok("phrases", "design: pm() prints whole numbers as .num does", r"---(`r pm(2, 0.5)`)---", "2 ± 0.5")
)

rows_literal <- list(
  b_ok("literal", "1.8.9 + 1.8.11: an inline literal, the why is removed and the class stays",
       r"---(filtered through [0.45 µm]{.weft-literal why="pore size, SOP 12"} membranes)---",
       "filtered through [0.45 µm]{.weft-literal} membranes"),
  b_ok("literal", "1.8.9 + 1.8.11: a literal div, the why is removed and the class stays",
       "::: {.weft-literal why=\"laboratory method, as specified in the SOP\"}\nSamples were filtered through 0.45 µm membranes and stored at 4 °C.\n:::",
       "::: {.weft-literal}\nSamples were filtered through 0.45 µm membranes and stored at 4 °C.\n:::"),
  b_ok("literal", "1.8.11 + 1.2.6: other classes and keys stay on a literal",
       r"---([0.45]{.weft-literal why="x" .smallcaps})---", "[0.45]{.weft-literal .smallcaps}"),
  b_ok("literal", "1.2.4: the why may come before the class",
       r"---([0.45]{why="x" .weft-literal})---", "[0.45]{.weft-literal}"),
  b_ok("literal", "1.1.6 + 1.5.15: a value inside a literal is still a value",
       r"---([`r k`{.num} µm]{.weft-literal why="w"})---", "[3 µm]{.weft-literal}")
)

B_ROWS_B <- c(rows_cap, rows_a, rows_lookup, rows_phrases, rows_literal)

# ---- batch C: .pairs, trunc, the list formatters ----------------------------------

rows_pairs <- list(
  b_ok("pairs", "1.4.3: .pairs", r"---(`r means`{.pairs})---", "A (1.2), B (3.4) and C (5.6)"),
  b_ok("pairs", "1.4.3: .pairs, two", r"---(`r means[1:2]`{.pairs})---", "A (1.2) and B (3.4)"),
  b_ok("pairs", "1.4.3: .pairs, one", r"---(`r means[1]`{.pairs})---", "A (1.2)"),
  b_ok("pairs", "1.3: .num .pairs, the number stage reaches the values",
       r"---(`r means`{.num .pairs})---", "A (1.2), B (3.4) and C (5.6)"),
  b_ok("pairs", "1.4.7: digits reaches every value", r"---(`r means`{.pairs digits="2"})---",
       "A (1.20), B (3.40) and C (5.60)"),
  b_ok("pairs", "1.4.1: .pct .pairs", r"---(`r pcts`{.pct .pairs})---", "A (12%) and B (50%)"),
  b_ok("pairs", "1.4.7: sep on .pairs", r"---(`r means`{.pairs sep="; "})---",
       "A (1.2); B (3.4) and C (5.6)"),
  b_ok("pairs", "1.4.1: a text class after .pairs", r"---(`r means`{.pairs .strong})---",
       "**A (1.2), B (3.4) and C (5.6)**")
)

rows_trunc <- list(
  b_ok("trunc", "1.4.7: trunc, more than k items", r"---(`r many`{.and trunc="3"})---", "a, b, c and 4 others"),
  b_ok("trunc", "design: trunc, one over is 'and 1 other'", r"---(`r letters[1:4]`{.and trunc="3"})---",
       "a, b, c and 1 other"),
  b_ok("trunc", "design: trunc, exactly k items is not truncated", r"---(`r sites`{.and trunc="3"})---", "A, B and C"),
  b_ok("trunc", "design: trunc 1", r"---(`r many`{.and trunc="1"})---", "a and 6 others"),
  b_ok("trunc", "design: trunc 2", r"---(`r many`{.and trunc="2"})---", "a, b and 5 others"),
  b_ok("trunc", "design: trunc implies .and when no collapse class is given",
       r"---(`r sites`{trunc="2"})---", "A, B and 1 other"),
  b_ok("trunc", "1.4.7: trunc with sep", r"---(`r many`{.and trunc="2" sep="; "})---", "a; b and 5 others"),
  b_ok("trunc", "design: trunc under .pairs", r"---(`r means`{.pairs trunc="2"})---",
       "A (1.2), B (3.4) and 1 other"),
  b_ok("trunc", "1.4.1: trunc, then a text class", r"---(`r many`{.and .strong trunc="3"})---",
       "**a, b, c and 4 others**"),
  b_ok("trunc", "1.4.1: trunc after the number stage", r"---(`r c(1.5, 2, 3, 4)`{.num .and trunc="2"})---",
       "1.5, 2 and 2 others")
)

rows_lists <- list(
  b_ok("lists", "1.4.3: .ul", r"---(`r sites`{.ul})---", "- A\n- B\n- C"),
  b_ok("lists", "1.4.3: .ol", r"---(`r sites`{.ol})---", "1. A\n2. B\n3. C"),
  b_ok("lists", "1.4.3: .dl from a named vector", r"---(`r c(a = 'x', b = 'y')`{.dl})---", "a\n:   x\n\nb\n:   y"),
  b_ok("lists", "design: .ul of one item", r"---(`r solo`{.ul})---", "- A"),
  b_ok("lists", "1.4.1: .num .ul", r"---(`r c(1.5, 2)`{.num .ul})---", "- 1.5\n- 2"),
  b_ok("lists", "1.4.1: .word .ul", r"---(`r c(1, 2)`{.word .ul})---", "- one\n- two"),
  b_ok("lists", "1.4.1: .num .dl", r"---(`r c(a = 1.5, b = 2)`{.num .dl})---", "a\n:   1.5\n\nb\n:   2"),
  b_ok("lists", "1.4.6: a list after a paragraph, alone in its own paragraph",
       "Sites sampled:\n\n`r sites`{.ul}\n\nThen the rest.", "Sites sampled:\n\n- A\n- B\n- C\n\nThen the rest.")
)

B_ROWS_C <- c(rows_pairs, rows_trunc, rows_lists)

B_BATCHES <- list(A = B_ROWS_A, B = B_ROWS_B, C = B_ROWS_C)

# ---- rendering a batch once and reading it from every file ----------------------

.b_cache <- new.env()

# the rendered batch (rmd runs in this process, so res$knit is last_knit())
b_batch <- function(batch, engine = c("rmd", "qmd")) {
  engine <- match.arg(engine)
  if (engine == "qmd") skip_if_no_quarto()
  key <- paste(batch, engine)
  if (!is.null(.b_cache[[key]])) return(.b_cache[[key]])
  rows <- B_BATCHES[[batch]]
  if (engine == "qmd") rows <- Filter(function(r) is.null(r$only) || "qmd" %in% r$only, rows)
  body <- batch_cases(vapply(rows, function(r) r$src, ""))
  res <- if (engine == "rmd") {
    render_rmd(body, code = PRE_B, in_process = TRUE)
  } else {
    render_qmd(body, code = PRE_B)
  }
  res$rows <- rows
  res$got <- if (res$failed) NULL else unlist(split_cases(res, length(rows)))
  .b_cache[[key]] <- res
  res
}

# the rows of the groups `grp` in the batch, compared with what rendered
b_expect_rows <- function(batch, grp, engine = c("rmd", "qmd")) {
  engine <- match.arg(engine)
  res <- b_batch(batch, engine)
  testthat::expect_false(res$failed,
                         label = paste(engine, "batch", batch, "render failed:", substr(res$message, 1, 300)))
  if (res$failed) return(invisible(NULL))
  idx <- which(vapply(res$rows, function(r) r$grp %in% grp, NA))
  testthat::expect_gt(length(idx), 0L)
  got <- res$got[idx]
  want <- vapply(res$rows[idx], function(r) r$out, "")
  got_c <- canon_md(ifelse(is.na(got), "<<missing>>", got))
  want_c <- canon_md(want)
  for (j in seq_along(idx)) {
    r <- res$rows[[idx[j]]]
    testthat::expect_equal(got_c[j], want_c[j],
                           label = sprintf("%s [%s] %s", engine, r$rule, gsub("\n", "\\\\n", r$src)))
  }
  invisible(res)
}

# ---- a document of rows, each on a line of its own, tagged ------------------------
#
# rows: list of list(tag, src, rule, want, rx); each src is one paragraph.
# `@L@` in want stands for the file line of the paragraph's first line.

b_body <- function(rows) {
  lines <- character(); at <- integer(length(rows))
  for (i in seq_along(rows)) {
    at[i] <- length(lines) + 1L
    lines <- c(lines, strsplit(rows[[i]]$src, "\n", fixed = TRUE)[[1]], "")
  }
  list(lines = lines, at = at)
}

b_row <- function(tag, src, rule, want = NULL, rx = NULL, collected = TRUE) {
  list(tag = tag, src = paste(tag, src), rule = rule, want = want, rx = rx,
       collected = collected)
}

# Each row's output line (found by its tag) against the expectation: `want`
# is the exact line, with the marker's line number as @L@; `rx` is a regexp
# the line must match (with @L@ the same). A line with no marker has `want`
# only.
b_check_lines <- function(res, b, rows, engine = "") {
  txt <- unesc(res$text)
  for (i in seq_along(rows)) {
    r <- rows[[i]]
    line <- res$offset + b$at[i]
    got <- grep(paste0("^", r$tag, " "), txt, value = TRUE)
    lab <- paste(engine, r$tag, r$rule)
    testthat::expect_length(got, 1L)
    if (length(got) != 1L) next
    if (!is.null(r$want)) {
      testthat::expect_equal(got, sub("@L@", as.character(line), r$want, fixed = TRUE), label = lab)
    }
    if (!is.null(r$rx)) {
      testthat::expect_match(got, sub("@L@", as.character(line), r$rx, fixed = TRUE), label = lab)
    }
  }
}

# ---- the configuration document: date_format, ci_level, about_tolerance, and
# the sentence-start list in its default (non-failing) state ------------------------
#
# One document, rendered once, shared by test-number-forms.R, test-phrases.R
# and test-text-classes.R.

CFG_FILES <- list("_weft.yml" = c(
  "date_format: \"%d/%m/%Y\"",
  "ci_level: 0.9",
  "about_tolerance: 0.2"
))

CFG_ROWS <- list(
  b_row("G01", "`r d1date`{.date}", "9.1 + design: date_format in _weft.yml", want = "G01 03/06/2024"),
  b_row("G02", "`r ci(2.1, 1.3, 2.9)`", "3.5.3: ci_level in _weft.yml is ci()'s default level",
        want = "G02 2.1 (90% CI 1.3 to 2.9)"),
  b_row("G03", "`r ci(2.1, 1.3, 2.9, level = 0.99)`", "3.5.3: the level argument beats the setting",
        want = "G03 2.1 (99% CI 1.3 to 2.9)"),
  b_row("G04", "`r about(0.6)`", "3.5.3: about_tolerance in _weft.yml (0.6 is 0.1 from half)",
        want = "G04 just over half")
)

# sentence starts (5.10.1): each paragraph begins with the construct under test
SENT_ROWS <- list(
  list(src = "`r k`{.num} sites failed.", listed = TRUE, text = "3", expr = "k",
       rule = "5.10.1: a value that opens a block with a digit"),
  list(src = "Done. `r k`{.num} sites failed.", listed = TRUE, text = "3", expr = "k",
       rule = "5.10.1: after '. '"),
  list(src = "Really? `r k`{.word} sites.", listed = TRUE, text = "three", expr = "k",
       rule = "5.10.1: after '? ' with a lower-case word"),
  list(src = "Wow! `r k`{.word} sites.", listed = TRUE, text = "three", expr = "k",
       rule = "5.10.1: after '! '"),
  list(src = "There were `r k`{.num} sites.", listed = FALSE,
       rule = "5.10.1: mid-sentence is not a sentence start"),
  list(src = "`r k`{.word .cap} sites.", listed = FALSE, rule = "5.10.1 + 1.4.3: .cap is the fix"),
  list(src = "[All]{if=\"flag\"} sites.", listed = FALSE, rule = "5.10.1: a span opening with a capital"),
  list(src = "[some | none]{if=\"flag\"} sites rose.", listed = TRUE, text = "some",
       rule = "5.10.1: a span opening with a lower-case word"),
  list(src = "`r k` sites.", listed = TRUE, text = "3", expr = "k",
       rule = "5.10.1: a bare value is listed too"),
  list(src = "Sites, `r k`{.num} of them.", listed = FALSE, rule = "5.10.1: after a comma"),
  list(src = "`r sites`{.and} were sampled.", listed = FALSE, rule = "5.10.1: a collapsed capital"),
  list(src = "`r tier_lab('hi')` rates.", listed = TRUE, text = "high", expr = "tier_lab('hi')",
       rule = "5.10.1: a lower-case phrase from lookup()")
)

b_cfg <- function() {
  if (!is.null(.b_cache$cfg)) return(.b_cache$cfg)
  rows <- c(CFG_ROWS, SENT_ROWS)
  b <- b_body(rows)
  res <- render_rmd(b$lines, code = PRE_B, in_process = TRUE, files = CFG_FILES)
  res$b <- b
  .b_cache$cfg <- res
  res
}
