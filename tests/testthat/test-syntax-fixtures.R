# Package B: the syntax fixtures table (spec section 21, first bullet).
#
# One row = source, the setup (the shared PRE chunk), and the expected text or
# the expected error with its line. Rows that render are batched: one document
# per engine, one case per paragraph group, split on marker lines. Rows that
# expect a construct error get a render of their own (every one under
# rmarkdown, a representative dozen under Quarto), and all of them run once
# more in draft mode in a single document, where the marker names the line.
#
# Expected text is markdown; both it and the rendered text go through Pandoc's
# own markdown writer (canon_md) before they are compared, so a row does not
# depend on how Pandoc re-spells a table or an escape.
#
# A stock render prints the attribute block as text (`1.2{.num}`), so no row
# below passes with the hooks absent except the rows marked "left alone",
# which say what weft must NOT change (1.9).

# ---- the setup every row shares ---------------------------------------------

PRE <- c(
  "x <- 1.2; k <- 3; z <- 0; o <- 1; tw <- 2",
  "big <- 12345.678; neg <- -4; pr <- 0.12; frac <- 0.125",
  "flag <- TRUE; noflag <- FALSE",
  "sites <- c('A', 'B', 'C'); pair <- c('A', 'B'); solo <- 'A'",
  "nums <- c(1.2, 3, 4.5)",
  "d_md <- c('*a*', 'b')",
  "d_code <- '`r 99`{.num}'",
  "hits <- new.env()",
  "touch <- function(tag) { assign(tag, TRUE, envir = hits); tag }"
)

MINUS <- "−"

ok <- function(rule, src, out, only = NULL) {
  list(rule = rule, src = src, out = out, only = only)
}

bad <- function(rule, src, line, rx = NULL, quarto = FALSE, code = NULL,
                files = NULL, front = NULL) {
  list(rule = rule, src = src, line = line, rx = rx, quarto = quarto,
       code = code, files = files, front = front)
}

# every ordering of the elements of v
perms <- function(v) {
  if (length(v) <= 1L) return(list(v))
  out <- list()
  for (i in seq_along(v)) for (p in perms(v[-i])) out[[length(out) + 1L]] <- c(v[i], p)
  out
}

# rows for every ordering of the attribute items
perm_rows <- function(rule, template, items, out) {
  lapply(perms(items), function(p) {
    ok(rule, sprintf(template, paste(p, collapse = " ")), out)
  })
}

# ---- the rows that render ----------------------------------------------------

values <- list(
  ok("1.3 / 1.4.13", r"---(Mean `r x`{.num} m.)---", "Mean 1.2 m."),
  ok("1.4.13: a whole number has no decimals", r"---(Count `r k`{.num} sites.)---", "Count 3 sites."),
  ok("9.1.5: thousands mark from 10,000", r"---(`r big`{.num})---", "12,345.7"),
  ok("9.1.5 + entry 34: thousands mark from 1000", r"---(`r 1234.5`{.num})---", "1,234.5"),
  ok("entry 34: no thousands mark below 1000", r"---(`r 999.5`{.num})---", "999.5"),
  ok("9.1.5: 10,000 takes the mark", r"---(`r 10000`{.num})---", "10,000"),
  ok("9.1.5: the minus sign printed is U+2212", r"---(`r neg`{.num})---", paste0(MINUS, "4")),
  ok("1.4.7: digits", r"---(`r x`{.num digits="2"})---", "1.20"),
  ok("1.4.7 + 1.4.13: digits on a whole number shows decimals", r"---(`r k`{.num digits="1"})---", "3.0"),
  ok("1.4.7: digits 0", r"---(`r 2.6`{.num digits="0"})---", "3"),
  ok("1.4.7: sigfig 2", r"---(`r 0.012345`{.num sigfig="2"})---", "0.012"),
  ok("1.4.7: sigfig 3", r"---(`r 1.2345`{.num sigfig="3"})---", "1.23"),
  ok("1.4.7: digits alone implies .num", r"---(`r x`{digits="2"})---", "1.20"),
  ok("1.4.7: sigfig alone implies .num", r"---(`r 1.2345`{sigfig="2"})---", "1.2"),
  ok("1.4.3: .pct reads a proportion", r"---(`r pr`{.pct})---", "12%"),
  ok("1.4.13 on .pct: default digits when not whole", r"---(`r frac`{.pct})---", "12.5%"),
  ok("1.4.3: .pct of 0.5", r"---(`r 0.5`{.pct})---", "50%"),
  ok("1.4.7 on .pct", r"---(`r pr`{.pct digits="2"})---", "12.00%"),
  ok("1.4.3: .sci", r"---(`r 1234`{.sci})---", "1.2 × 10^3^"),
  ok("1.4.3: .sci, negative exponent uses the minus", r"---(`r 0.00123`{.sci})---", paste0("1.2 × 10^", MINUS, "3^")),
  ok("1.4.7 on .sci", r"---(`r 1234`{.sci digits="2"})---", "1.23 × 10^3^"),
  ok("1.4.3: .word", r"---(There were `r k`{.word} sites.)---", "There were three sites."),
  ok("1.4.3 + design: .word hyphenates, no 'and'", r"---(`r 21`{.word} and `r 99`{.word})---", "twenty-one and ninety-nine"),
  ok("1.4.3: .word of 0 and 12", r"---(`r z`{.word} `r 12`{.word})---", "zero twelve"),
  ok("1.4.12: .word prints digits from the limit (100)", r"---(`r 100`{.word})---", "100"),
  ok("1.4.12: .word judges the number as printed", r"---(`r 2.6`{.num digits="0" .word})---", "three"),
  ok("1.4.3: .count below the threshold is a word", r"---(`r 3`{.count} `r 9`{.count})---", "three nine"),
  ok("1.4.3: .count from the threshold up is digits", r"---(`r 10`{.count} `r 12`{.count})---", "10 12"),
  ok("1.4.3: .ord", r"---(`r 1`{.ord} `r 2`{.ord} `r 3`{.ord} `r 4`{.ord})---", "1st 2nd 3rd 4th"),
  ok("1.4.3: .ord, teens", r"---(`r 11`{.ord} `r 12`{.ord} `r 13`{.ord})---", "11th 12th 13th"),
  ok("1.4.3: .ord, 21, 22, 101, 111, 112", r"---(`r 21`{.ord} `r 22`{.ord} `r 101`{.ord} `r 111`{.ord} `r 112`{.ord})---", "21st 22nd 101st 111th 112th"),
  ok("1.4.3: .no is 'no' for a printed zero", r"---(`r z`{.no} files)---", "no files"),
  ok("1.4.3: .no leaves a non-zero alone", r"---(`r k`{.no} files)---", "3 files"),
  ok("design: .no does not act on a printed 0.0", r"---(`r z`{.num digits="1" .no})---", "0.0"),
  ok("1.4.1: .no then .word", r"---(`r z`{.no .word}, `r o`{.no .word}, `r tw`{.no .word})---", "no, one, two"),
  ok("1.4.1: .no then .count", r"---(`r z`{.no .count}, `r tw`{.no .count}, `r 12`{.no .count})---", "no, two, 12"),
  ok("1.3.2: claim() returns the raw value, the formatter applies after", r"---(`r claim(x, . > 1)`{.num})---", "1.2"),
  ok("1.3.2 + 3.1.3: several checks", r"---(`r claim(k, . > 0, . < 10)`{.word})---", "three"),
  ok("3.1.1: a claim nested in a larger expression", r"---(`r sqrt(claim(k, . > 0))`{.num})---", "1.7"),
  ok("1.3.1 + 1.1.8: a bare value with a passing claim prints as stock", r"---(`r claim(k, . > 0)` sites)---", "3 sites"),
  ok("1.4.10: data text is markdown, not escaped", r"---(`r d_md`{.and})---", "*a* and b"),
  ok("2.2.4: a data value that looks like a construct is printed, never evaluated", r"---(`r d_code`{.and})---", "`r 99`{.num}")
)

collapse_rows <- list(
  ok("1.4.3: .and, three", r"---(`r sites`{.and})---", "A, B and C"),
  ok("1.4.3: .and, two", r"---(`r pair`{.and})---", "A and B"),
  ok("1.4.3: .and, one", r"---(`r solo`{.and})---", "A"),
  ok("1.4.3: .or", r"---(`r sites`{.or})---", "A, B or C"),
  ok("1.4.7: sep", r"---(`r sites`{.and sep="; "})---", "A; B and C"),
  ok("1.4.7: last", r"---(`r sites`{.and last=" plus "})---", "A, B plus C"),
  ok("1.4.7: sep and last", r"---(`r sites`{.or sep=" / " last=" / "})---", "A / B / C"),
  ok("1.4.1: stage i then iii", r"---(`r nums`{.num .and})---", "1.2, 3 and 4.5"),
  ok("1.4.1 + 1.4.7: digits reaches every element", r"---(`r nums`{.num digits="2" .and})---", "1.20, 3.00 and 4.50"),
  ok("1.4.1: stage ii then iii", r"---(`r c(1, 2, 3)`{.word .and})---", "one, two and three"),
  ok("1.4.1: stage iv acts on the collapsed text", r"---(`r sites`{.and .strong})---", "**A, B and C**")
)

stage_rows <- c(
  perm_rows("1.4.1: .no .word .strong in every order", r"---(`r z`{%s})---", c(".no", ".word", ".strong"), "**no**"),
  perm_rows("1.4.1: .num .word .em in every order", r"---(`r k`{%s})---", c(".num", ".word", ".em"), "*three*"),
  perm_rows("1.4.1: four classes in every order", r"---(`r c(0, 1, 2)`{%s})---", c(".no", ".word", ".and", ".strong"), "**no, one and two**"),
  perm_rows("1.4.1: .num .and .em in every order", r"---(`r nums`{%s})---", c(".num", ".and", ".em"), "*1.2, 3 and 4.5*"),
  perm_rows("1.4.1: .pct .and in every order", r"---(`r c(0.12, 0.5)`{%s})---", c(".pct", ".and"), "12% and 50%"),
  perm_rows("1.2.4: a renderer key anywhere in the block", r"---(`r x`{%s})---", c(".num", 'digits="2"', ".strong"), "**1.20**"),
  perm_rows("1.2.4 + 1.5.7: formatter, governor key, text class", r"---([# site | # sites]{%s})---", c(".word", 'n="k"', ".strong"), "**three sites**"),
  perm_rows("1.2.4: .and with sep and last", r"---(`r sites`{%s})---", c(".and", 'sep="; "', 'last=" or "'), "A; B or C")
)

attribute_rows <- list(
  ok("1.2.10: N is n", r"---([# site | # sites]{N="k"})---", "3 sites"),
  ok("1.2.10: If is if", r"---([a | b]{If="flag"})---", "a"),
  ok("1.2.10 + 21: Digits is digits", r"---(`r x`{.num Digits="2"})---", "1.20"),
  ok("1.2.10 + 21: Sep and Last", r"---(`r sites`{.and Sep="; " Last=" plus "})---", "A; B plus C"),
  ok("1.2.2: unquoted n", r"---([# site | # sites]{n=k .word})---", "three sites"),
  ok("1.2.2: unquoted digits", r"---(`r x`{.num digits=2})---", "1.20"),
  ok("1.2.2: unquoted if", r"---([a | b]{if=flag})---", "a"),
  ok("1.2.2 + 1.5.4: unquoted condition list", r"---([yes | no]{if=x>1,k>=3})---", "yes")
)

governor_rows <- list(
  ok("1.5.18: default class, 3 prints 3", r"---([# site | # sites]{n="k"})---", "3 sites"),
  ok("1.5.9: one takes the one arm", r"---([# site | # sites]{n="o"})---", "1 site"),
  ok("1.5.1: three arms, zero", r"---([no sites | a site | # sites]{n="z"})---", "no sites"),
  ok("1.5.1: three arms, one", r"---([no sites | a site | # sites]{n="o"})---", "a site"),
  ok("1.5.1: three arms, two falls to other", r"---([no sites | a site | # sites]{n="tw"})---", "2 sites"),
  ok("1.5.1: three arms, three", r"---([no sites | a site | # sites]{n="k"})---", "3 sites"),
  ok("1.5.1: four arms, zero", r"---([never | once | twice | # times]{n="z"})---", "never"),
  ok("1.5.1: four arms, one", r"---([never | once | twice | # times]{n="o"})---", "once"),
  ok("1.5.1: four arms, two", r"---([never | once | twice | # times]{n="tw"})---", "twice"),
  ok("1.5.1: four arms, three", r"---([never | once | twice | # times]{n="k"})---", "3 times"),
  ok("1.5.1: one arm is a template for #", r"---([# day trip]{n="k"})---", "3 day trip"),
  ok("1.5.9 + 1.4.13: a value that is not whole prints to the default digits and takes other", r"---([# site | # sites]{n="x"})---", "1.2 sites"),
  ok("1.5.9: 1 printed as 1.0 takes the other arm", r"---([# site | # sites]{n="o" digits="1"})---", "1.0 sites"),
  ok("1.5.7: a formatter class on the governor", r"---([# site | # sites]{.word n="k"})---", "three sites"),
  ok("1.5.7: .ord on the governor", r"---([# place | # places]{.ord n="o"})---", "1st place"),
  ok("1.5.7: .pct on the governor", r"---([# of them]{.pct n="pr"})---", "12% of them"),
  ok("1.5.7: digits on the governor", r"---([# site | # sites]{n="x" digits="2"})---", "1.20 sites"),
  ok("1.5.7 + 9.1.5: thousands mark inside #", r"---([# site | # sites]{n="big"})---", "12,345.7 sites"),
  ok("1.5.6: a check in the governor's expression", r"---([# site | # sites]{n="claim(k, . > 0)"})---", "3 sites"),
  ok("1.5.11 + 1.7.3: n is length(x), never inferred", r"---([# site | # sites]{n="length(sites)"})---", "3 sites"),
  ok("1.5.1: n may be a literal", r"---([# site | # sites]{n="2"})---", "2 sites"),
  ok("1.5.12: an empty arm: file/files, many", r"---(file[ | s]{n="k"})---", "files"),
  ok("1.5.12: an empty arm: file/files, one", r"---(file[ | s]{n="o"})---", "file"),
  ok("1.5.12: an empty 'one' arm, other", r"---(site[s | | s]{n="k"})---", "sites"),
  ok("1.5.12: an empty 'one' arm, one", r"---(site[s | | s]{n="o"})---", "site"),
  ok("1.5.12: an empty 'one' arm, zero", r"---(site[s | | s]{n="z"})---", "sites"),
  ok("1.5.12: non-ASCII arms", r"---([café | cafés]{n="k"})---", "cafés")
)

if_rows <- list(
  ok("1.5.1: true arm", r"---(The target was [met | not met]{if="x > 1"}.)---", "The target was met."),
  ok("1.5.1: false arm", r"---(The target was [met | not met]{if="x > 5"}.)---", "The target was not met."),
  ok("1.5.4: a condition list, all true", r"---([both | not both]{if="flag, x > 1"})---", "both"),
  ok("1.5.4: a condition list, one false", r"---([both | not both]{if="flag, x > 5"})---", "not both"),
  ok("1.5.4: && || and brackets inside a condition", r"---([yes | no]{if="(x > 1 && k == 3) || z > 5"})---", "yes"),
  ok("1.5.5: a guard prints its phrase when true", r"---([All]{if="flag"} models rise.)---", "All models rise."),
  ok("1.5.5 + 1.5.4: a guard with a condition list", r"---([All]{if="flag, x > 1, k >= 3"} sites.)---", "All sites."),
  ok("1.5.5: optional text, empty second arm, false", r"---(Sampling was complete[, apart from the estuary sites | ]{if="noflag"}.)---", "Sampling was complete."),
  ok("1.5.5: optional text, empty second arm, true", r"---(Sampling was complete[, apart from the estuary sites | ]{if="flag"}.)---", "Sampling was complete, apart from the estuary sites."),
  ok("1.5.3: either arm of a two-arm if may be empty (first)", r"---(A[ | b]{if="flag"}C)---", "AC"),
  ok("1.5.3: either arm of a two-arm if may be empty (second)", r"---(A[b | ]{if="noflag"}C)---", "AC")
)

escape_rows <- list(
  ok("1.5.12: || is a literal |", r"---([a||b | c]{if="flag"})---", "a|b"),
  ok("1.5.12: || other arm", r"---([a||b | c]{if="noflag"})---", "c"),
  ok("1.5.12: the Pandoc writer's form a\\|\\|b \\| c", r"---([a\|\|b \| c]{if="flag"})---", "a|b"),
  ok("1.5.12: the Pandoc writer's form, other arm", r"---([a\|\|b \| c]{if="noflag"})---", "c"),
  ok("1.5.12: three in a row, a literal then a separator", r"---([a||| c]{if="flag"})---", "a|"),
  ok("1.5.12: ### is a literal # then the placeholder", r"---([x | No. ###]{n="k"})---", "No. #3"),
  ok("1.5.12: \\## is a literal #", r"---(Item [x | \## #]{n="k"})---", "Item # 3"),
  ok("1.5.14: | inside a code span is not a separator", r"---([`a|b` | c]{if="flag"})---", "`a|b`"),
  ok("1.5.14: | inside math is not a separator", r"---([$a|b$ | c]{if="flag"})---", "$a|b$"),
  ok("1.5.14: | inside a link target is not a separator", r"---([[l](http://x.org/a|b) | c]{if="flag"})---", "[l](http://x.org/a|b)")
)

nesting_rows <- list(
  ok("1.5.15: a value inside an arm", r"---([none | `r k`{.word} sites]{if="noflag"})---", "three sites"),
  ok("1.5.15: a bare value inside an arm", r"---([a | `r k` b]{n="k"})---", "3 b"),
  ok("1.5.15: markdown inside an arm", r"---([a | **bold** b]{if="noflag"})---", "**bold** b"),
  ok("2.2.2: a span inside an arm", r"---([It was [one | two]{if="noflag"} | no]{if="flag"})---", "It was two"),
  ok("2.2.2: # and a value in the same arm", r"---([# site, `r k`{.word} visits | # sites, `r k`{.word} visits]{n="k"})---", "3 sites, three visits"),
  ok("1.7.2: n=\".\" inherits the governor (plural)", r"---([# sample[ | s]{n="."} [was | were]{n="."} taken]{n="k"})---", "3 samples were taken"),
  ok("1.7.2: n=\".\" inherits the governor (singular)", r"---([# sample[ | s]{n="."} [was | were]{n="."} taken]{n="o"})---", "1 sample was taken"),
  ok("1.7.3: a list and its verb", r"---(`r sites`{.and} [was | were]{n="length(sites)"} sampled.)---", "A, B and C were sampled."),
  ok("1.5.16: only the chosen arm is evaluated (error in the other)", r"---([A `r k`{.num} | B `r stop('never')`{.num}]{if="flag"})---", "A 3"),
  ok("1.5.16: a value that would fail to evaluate, in the other arm", r"---([ok | `r nope_var`{.num}]{if="flag"})---", "ok"),
  ok("1.5.16: a check in the arm that is not chosen does not run", r"---([A | B `r claim(k, . > 100)`]{if="flag"})---", "A"),
  ok("1.5.16 + 2.2.2: side effects, if", "[`r touch('t1')` | `r touch('t2')`]{if=\"flag\"}\n\nTouched: `r exists('t1', hits)` `r exists('t2', hits)`.", "t1\n\nTouched: TRUE FALSE."),
  ok("1.5.16 + 2.2.2: side effects, n", "[`r touch('n1')` | `r touch('n2')`]{n=\"o\"}\n\nNow: `r exists('n1', hits)` `r exists('n2', hits)`.", "n1\n\nNow: TRUE FALSE."),
  ok("2.2.3: a block sees what the chunks above it made", "```{r}\nlater <- 7\n```\n\nLater `r later`{.word}.", "Later seven.")
)

passthrough_rows <- list(
  ok("1.2.6: a class weft does not own is put on a span", r"---(`r x`{.num .smallcaps})---", "[1.2]{.smallcaps}"),
  ok("1.2.6: a key weft does not own", r"---(`r x`{.num custom-style="Key figure"})---", "[1.2]{custom-style=\"Key figure\"}"),
  ok("1.2.6: both together", r"---(`r x`{.num .smallcaps custom-style="K"})---", "[1.2]{.smallcaps custom-style=\"K\"}"),
  ok("1.2.7: an unknown class is not an error", r"---(`r k`{.num .nmu})---", "[3]{.nmu}"),
  ok("1.2.7: an unknown key is not an error", r"---(`r k`{.num trunk="3"})---", "[3]{trunk=\"3\"}"),
  ok("1.2.6: pass-through on a governed span", r"---([a | b]{if="noflag" .smallcaps})---", "[b]{.smallcaps}"),
  ok("1.2.6: an empty output emits nothing, with pass-through", r"---(A[ | b]{if="flag" .smallcaps}C)---", "AC"),
  ok("1.2.6: an empty arm emits nothing without it", r"---(A[ | b]{if="flag"}C)---", "AC")
)

text_rows <- list(
  ok("1.1.9: .strong text span", r"---([results]{.strong})---", "**results**"),
  ok("1.1.9: .em text span", r"---([results]{.em})---", "*results*"),
  ok("1.1.9: a text span has no arms: | and # are ordinary", r"---([a|b #c]{.strong})---", "**a|b #c**"),
  ok("1.5.15 + 1.1.9: a text span's bracket is prose", r"---([total `r k`]{.strong})---", "**total 3**"),
  ok("1.5.15 + 1.1.9: a value with a formatter inside a text span", r"---([total `r k`{.word}]{.em})---", "*total three*"),
  ok("1.5.7: a text class acts on the chosen arm", r"---([a | b]{.strong if="flag"})---", "**a**"),
  ok("1.5.7: a text class on an n span acts on the final text", r"---([# site | # sites]{.em n="k"})---", "*3 sites*"),
  ok("1.2.6 + 1.5.7: an empty chosen arm stays empty with a text class", r"---(x[ | y]{.strong if="flag"}z)---", "xz"),
  ok("1.4.1: a text class on a value", r"---(`r k`{.word .strong})---", "**three**"),
  ok("1.1.9: .em on a value", r"---(`r x`{.num .em})---", "*1.2*")
)

left_alone_rows <- list(
  ok("1.1.9 + 1.9.1: [1234]{.num} is not a construct (left alone)", r"---([1234]{.num})---", "[1234]{.num}"),
  ok("1.9.1: an ordinary Pandoc span (left alone)", r"---([abc]{.smallcaps})---", "[abc]{.smallcaps}"),
  ok("1.9.1: a bracket with no attribute block (left alone)", r"---(See [a | b] and [c](http://x.org).)---", "See [a \\| b] and [c](http://x.org)."),
  ok("1.9.1: a citation bracket (left alone)", r"---(As shown [@smith2020].)---", "As shown [@smith2020]."),
  ok("1.1.10: inline R in a fence that is not a chunk is read and formatted; a bracketed span there is text", "```text\nfence `r k`{.num} and [a | b]{if=\"flag\"}\n```", "``` text\nfence 3 and [a | b]{if=\"flag\"}\n```"),
  ok("1.1.10: inline R in an HTML comment is read and formatted, with no braces left", r"---(<!-- comment `r k`{.num} -->)---", "<!-- comment 3 -->"),
  ok("1.1.8: bare inline R prints as stock", r"---(Mean `r x` m and `r k` sites.)---", "Mean 1.2 m and 3 sites."),
  ok("1.3.4: a bare NA prints as stock knitr prints it", r"---(Mean depth was `r NA_real_` m.)---", "Mean depth was NA m.")
)

context_rows <- list(
  ok("1.5.15: a heading", "## Result [no | `r k`{.word} items]{n=\"k\"}", "## Result three items"),
  ok("1.5.15: a list", "- first [a | b]{if=\"flag\"}\n- second `r k`{.word}", "- first a\n- second three"),
  ok("1.5.15: a block quote", "> quoted [a | b]{if=\"noflag\"} text", "> quoted b text"),
  ok("1.5.13: a table cell, arms separated by \\|",
     "| name | value |\n|------|-------|\n| [x \\| y]{if=\"flag\"} | `r k`{.word} |\n| [x \\| y]{if=\"noflag\"} | `r x`{.num} |",
     "| name | value |\n|------|-------|\n| x | three |\n| y | 1.2 |"),
  ok("1.5.15: a div", "::: {.mydiv}\nInside [a | b]{if=\"flag\"} and `r k`{.word}.\n:::", "::: {.mydiv}\nInside a and three.\n:::"),
  ok("1.5.15: inside emphasis", r"---(*[a | b]{if="flag"}* and **`r k`{.word}**)---", "*a* and **three**"),
  ok("1.5.15: inside link text", r"---([see [a | b]{if="flag"}](http://x.org))---", "[see a](http://x.org)"),
  ok("1.5.15: inside inline HTML", r"---(<span title="x">`r k`{.word}</span>)---", "<span title=\"x\">three</span>"),
  ok("2.2.2: constructs resolved in textual order on one line", r"---(`r k`{.word}, [a | b]{if="flag"}, `r x`{.num}, [# site | # sites]{n="tw"}.)---", "three, a, 1.2, 2 sites."),
  ok("2.2.2: a paragraph that begins with a construct", r"---([All]{if="flag"} `r k`{.word} models rise.)---", "All three models rise.")
)

quarto_only_rows <- list(
  ok("1.1.4: Quarto's {r} form with a formatter", r"---(`{r} k`{.word} sites.)---", "three sites.", only = "qmd"),
  ok("1.1.4: Quarto's {r} form, .num", r"---(`{r} x`{.num} m.)---", "1.2 m.", only = "qmd"),
  ok("1.1.4: Quarto's {r} form, .and", r"---(`{r} sites`{.and}.)---", "A, B and C.", only = "qmd"),
  ok("1.1.4: Quarto's {r} form on a governor", r"---([# site | # sites]{n="k"} and `{r} k`{.word})---", "3 sites and three", only = "qmd"),
  ok("1.3.1: Quarto's bare {r} form prints as stock Quarto", r"---(Bare `{r} k` and `{r} NA_real_`.)---", "Bare 3 and NA.", only = "qmd")
)

OK_ROWS <- c(values, collapse_rows, stage_rows, attribute_rows, governor_rows,
             if_rows, escape_rows, nesting_rows, passthrough_rows, text_rows,
             left_alone_rows, context_rows)

# ---- the rows that are construct errors --------------------------------------

BAD_ROWS <- list(
  bad("1.2.3: a single-quoted value", "Intro.\n\nSee [a | b]{n='k'} here.\n\nOutro.", 3, "chunk", quarto = TRUE),
  bad("1.2.3: a double quote inside a value", "Intro.\n\nSee [a | b]{if=\"x == \\\"a\\\"\"} here.\n\nOutro.", 3, "chunk"),
  bad("1.2.9: a double quote ends the value early", "Intro.\n\nSee [a | b]{if=\"tier == \"sev\"\"} here.\n\nOutro.", 3, quarto = TRUE),
  bad("1.2.3: single-quoted value on inline code", "Intro.\n\nValue `r x`{.num digits='2'} here.\n\nOutro.", 3, "chunk"),
  bad("1.1.5: two governor keys", "Intro.\n\nSee [a | b]{n=\"k\" if=\"flag\"} here.\n\nOutro.", 3, quarto = TRUE),
  bad("1.2.10: a key written twice in different letter case", "Intro.\n\nSee [a | b]{n=\"k\" N=\"k\"} here.\n\nOutro.", 3),
  bad("1.2.10: a key written twice", "Intro.\n\nSee [a | b]{if=\"flag\" if=\"flag\"} here.\n\nOutro.", 3),
  bad("1.4.2: two number-stage classes", "Intro.\n\nValue `r x`{.num .pct} here.\n\nOutro.", 3, quarto = TRUE),
  bad("1.4.2: two wording-stage classes", "Intro.\n\nValue `r k`{.word .count} here.\n\nOutro.", 3),
  bad("1.4.2: two collapse-stage classes", "Intro.\n\nValue `r sites`{.and .or} here.\n\nOutro.", 3),
  bad("1.4.7: digits and sigfig together", "Intro.\n\nValue `r x`{.num digits=\"1\" sigfig=\"2\"} here.\n\nOutro.", 3, quarto = TRUE),
  bad("1.3.3: a governor key on a value", "Intro.\n\nValue `r k`{n=\"k\"} here.\n\nOutro.", 3, quarto = TRUE),
  bad("1.3.3: an if key on a value", "Intro.\n\nValue `r k`{if=\"flag\"} here.\n\nOutro.", 3),
  bad("1.5.7: a formatter class on an if span", "Intro.\n\nSee [a | b]{.num if=\"flag\"} here.\n\nOutro.", 3, quarto = TRUE),
  bad("1.5.2: an n span with five arms", "Intro.\n\nSee [a | b | c | d | e]{n=\"k\"} here.\n\nOutro.", 3, quarto = TRUE),
  bad("1.5.2: an if span with three arms", "Intro.\n\nSee [a | b | c]{if=\"flag\"} here.\n\nOutro.", 3),
  bad("1.5.13: an unescaped separator in a pipe-table cell", "Intro.\n\n| a | b |\n|---|---|\n| [x | y]{if=\"flag\"} | z |\n\nOutro.", 5, quarto = TRUE),
  bad("5.3.5 + 1.1.8: an expression that does not parse (value)", "Intro.\n\nValue `r 1 +* 2`{.num} here.\n\nOutro.", 3, quarto = TRUE),
  bad("5.3.5 + 1.1.8: an expression that does not parse (bare)", "Intro.\n\nValue `r 1 +* 2` here.\n\nOutro.", 3),
  bad("5.3.5: an expression that does not parse (attribute value)", "Intro.\n\nSee [a | b]{if=\"flag &&\"} here.\n\nOutro.", 3),
  bad("3.1.10: claim() with no check, in a value", "Intro.\n\nValue `r claim(x)`{.num} here.\n\nOutro.", 3, quarto = TRUE),
  bad("3.1.10 + 1.1.8: claim() with no check, bare", "Intro.\n\nValue `r claim(x)` here.\n\nOutro.", 3),
  bad("3.1.10: claim() with no check, in an attribute value", "Intro.\n\nSee [a | b]{if=\"claim(flag)\"} here.\n\nOutro.", 3),
  bad("1.7.2: n=\".\" outside an n or sign span", "Intro.\n\nSee [a | b]{n=\".\"} here.\n\nOutro.", 3),
  bad("1.7.2: n=\".\" inside an if span", "Intro.\n\nSee [x [a | b]{n=\".\"} | y]{if=\"flag\"} here.\n\nOutro.", 3),
  bad("1.4.8: two classes of one stage, one a project formatter",
      "Intro.\n\nValue `r sites`{.and .tostr} here.\n\nOutro.", 3,
      files = list("_weft.yml" = c("formatters:", "  .tostr:", "    function: base::toString", "    stage: collapse"))),
  bad("1.2.3: error on the line of the construct, not the paragraph (second line)",
      "Intro.\n\nFirst line of a paragraph\nthen `r x`{.num .pct} on its second line\n\nOutro.", 4)
)

# ---- helpers for the tests ----------------------------------------------------

label_row <- function(r) sprintf("[%s] %s", r$rule, gsub("\n", "\\\\n", r$src))

compare_rows <- function(rows, res, engine) {
  expect_false(res$failed, label = paste(engine, "batch render failed:", res$message))
  got <- split_cases(res, length(rows))
  want <- vapply(rows, function(r) r$out, "")
  got_c <- canon_md(ifelse(is.na(got), "<<missing>>", unlist(got)))
  want_c <- canon_md(want)
  for (i in seq_along(rows)) {
    expect_equal(got_c[i], want_c[i], label = paste(engine, label_row(rows[[i]])))
  }
}

# ---- tests -------------------------------------------------------------------

test_that("rows: values, constructs and contexts render as the rules say (rmarkdown)", {
  body <- batch_cases(vapply(OK_ROWS, function(r) r$src, ""))
  res <- render_rmd(body, code = PRE)
  compare_rows(OK_ROWS, res, "rmarkdown")
})

test_that("rows: the same table renders the same under Quarto, with the {r} form", {
  skip_if_no_quarto()
  rows <- c(OK_ROWS, quarto_only_rows)
  body <- batch_cases(vapply(rows, function(r) r$src, ""))
  res <- render_qmd(body, code = PRE)
  compare_rows(rows, res, "quarto")
})

test_that("1.5.15: a span inside a footnote (a footnote moves to the end of the document, so its own render)", {
  src <- "A claim.[^n1] More.\n\n[^n1]: Counted [# site | # sites]{n=\"k\"}."
  want <- "A claim.[^n1] More.\n\n[^n1]: Counted 3 sites."
  both(src, want, code = PRE)
})

test_that("1.2.10: letter case of the keys, and the two text classes in either order, make one output", {
  cases <- c(
    r"---([a | b]{.strong .em if="flag"})---",
    r"---([a | b]{.em if="flag" .strong})---",
    r"---([a | b]{if="flag" .strong .em})---"
  )
  res <- render_rmd(batch_cases(cases), code = PRE)
  expect_false(res$failed)
  got <- split_cases(res, 3)
  expect_equal(got[[2]], got[[1]])
  expect_equal(got[[3]], got[[1]])
  expect_true(grepl("a", got[[1]], fixed = TRUE))
  expect_false(grepl("[{}]", got[[1]]))
  expect_false(grepl("if=", got[[1]], fixed = TRUE))
})

# ---- errors ------------------------------------------------------------------

check_construct_error <- function(res, row, file_rx = NULL) {
  label <- label_row(row)
  expect_true(res$failed, label = paste("render stops:", label))
  expect_match(res$message, at_line(res, row$line), label = paste("names file:line,", label))
  expect_match(res$message, "weft", fixed = TRUE, label = paste("is weft's message,", label))
  if (!is.null(row$rx)) {
    expect_match(res$message, row$rx, ignore.case = TRUE, label = paste("says", row$rx, "-", label))
  }
}

test_that("construct errors stop the render with weft: file:line: (rmarkdown), 5.3.1 / 2.6.5", {
  for (row in BAD_ROWS) {
    res <- render_rmd(row$src, code = c(PRE, row$code), files = row$files)
    check_construct_error(res, row)
    expect_true("weft_construct_error" %in% res$error$class, label = paste("class,", label_row(row)))
    expect_match(res$message, "weft: ", fixed = TRUE)
  }
})

test_that("construct errors stop the render under Quarto, naming file:line", {
  skip_if_no_quarto()
  for (row in Filter(function(r) isTRUE(r$quarto), BAD_ROWS)) {
    res <- render_qmd(row$src, code = c(PRE, row$code), files = row$files)
    expect_true(res$failed, label = label_row(row))
    expect_match(res$message, at_line(res, row$line), label = label_row(row))
    expect_match(res$message, "weft", fixed = TRUE)
    if (!is.null(row$rx)) expect_match(res$message, row$rx, ignore.case = TRUE)
  }
})

test_that("2.6.5 + 2.6.8 + 9.4.3: in draft mode every construct error is a marker on its line (both engines)", {
  # knitr parses inline code before any hook runs (5.3.5), so code that does
  # not parse stops a knit in draft mode too (9.4.3)
  rows <- Filter(function(r) !grepl("5\\.3\\.5.*\\((value|bare)\\)", r$rule) && is.null(r$files) && is.null(r$front) &&
                   !grepl("bare", r$rule), BAD_ROWS)
  body <- batch_cases(vapply(rows, function(r) r$src, ""))
  starts <- attr(body, "starts")
  check <- function(res, engine) {
    expect_false(res$failed, label = paste(engine, "draft render fails:", res$message))
    txt <- unesc(res$md)
    for (i in seq_along(rows)) {
      line <- res$offset + starts[i] + rows[[i]]$line - 1L
      expect_match(txt, sprintf("<<weft: construct error, line %d>>", line), fixed = TRUE,
                   label = paste(engine, label_row(rows[[i]])))
    }
    expect_equal(lengths(regmatches(txt, gregexpr("<<weft: construct error", txt, fixed = TRUE)))[[1]],
                 length(rows))
  }
  check(render_rmd(body, code = PRE, env = c(WEFT_DRAFT = "1"), format = "knit"), "rmarkdown")
  skip_if_no_quarto()
  check(render_qmd(body, code = PRE, env = c(WEFT_DRAFT = "1")), "quarto")
})

# ---- the table's other documents ----------------------------------------------

test_that("1.5.18 + 9.1.2: the default governor class setting changes the class", {
  res <- render_rmd(c("[# site | # sites]{n=\"k\"}"),
                    code = PRE, files = list("_weft.yml" = "governor_class: .word"))
  expect_false(res$failed)
  expect_match(res$md, "three sites", fixed = TRUE)
  res <- render_rmd(c("[# of them]{n=\"pr\"}"), code = PRE,
                    files = list("_weft.yml" = "governor_class: .pct"))
  expect_equal(canon_md(res$md), "12% of them")
})

test_that("1.5.9 + 21 Governors: 0, 1, 2 and 3 print as themselves and take their arm", {
  cases <- vapply(c(0, 1, 2, 3), function(v) {
    sprintf("[no sites (%s) | one site (%s) | two sites (%s) | # sites (%s)]{n=\"%s\"}", "#", "#", "#", "#", v)
  }, "")
  # the arms print their own number: 0 -> "no sites (0)" etc.
  res <- render_rmd(batch_cases(cases), code = PRE)
  expect_false(res$failed)
  got <- unlist(split_cases(res, 4))
  expect_equal(got, c("no sites (0)", "one site (1)", "two sites (2)", "3 sites (3)"))
})

test_that("1.6.7 + 1.6.5 + 1.6.8: lang is matched on its primary subtag; other languages are errors", {
  # NOTE: depends on stage 1a reading `lang` (it may be built later).
  res <- render_rmd("See [# site | # sites]{n=\"k\"}.", code = PRE, front = "lang: en-AU")
  expect_false(res$failed)
  expect_equal(canon_md(res$md), "See 3 sites.")
  res <- render_rmd("See [# site | # sites]{n=\"k\"}.", code = PRE, front = "lang: en_GB")
  expect_equal(canon_md(res$md), "See 3 sites.")
  res <- render_rmd("See [# Stelle | # Stellen]{n=\"k\"}.", code = PRE, front = "lang: de")
  expect_true(res$failed)
  expect_match(res$message, at_line(res, 1))
  res <- render_rmd("See `r k`{.word}.", code = PRE, front = "lang: de")
  expect_true(res$failed)
  expect_match(res$message, at_line(res, 1))
})

test_that("1.4.8 + 9.1.2: a project-registered formatter, at its stage", {
  cfg <- list("_weft.yml" = c(
    "formatters:",
    "  .tostr:",
    "    function: base::toString",
    "    stage: collapse",
    "  .shout:",
    "    function: base::toupper",
    "    stage: text"
  ))
  cases <- c(
    r"---(`r sites`{.tostr})---",
    r"---(`r sites`{.and .shout})---",
    r"---(`r sites`{.shout .and})---",
    r"---(`r solo`{.shout})---"
  )
  res <- render_rmd(batch_cases(cases), code = PRE, files = cfg)
  expect_false(res$failed, label = res$message)
  got <- unlist(split_cases(res, 4))
  expect_equal(got, c("A, B, C", "A, B AND C", "A, B AND C", "A"))
})

test_that("9.1.2 + 9.1.5: _weft.yml settings take effect in a render", {
  cfg <- list("_weft.yml" = c(
    "digits: 2",
    "decimal_mark: \",\"",
    "big_mark: \".\"",
    "minus: \"-\"",
    "pct_proportion: false",
    "count_threshold: 5",
    "word_limit: 50"
  ))
  cases <- c(
    r"---(`r x`{.num})---",                        # 1,20
    r"---(`r k`{.num})---",                        # whole stays whole
    r"---(`r neg`{.num})---",                      # ASCII minus
    r"---(`r 30`{.pct})---",                       # not a proportion
    r"---(`r 4`{.count} `r 7`{.count})---",        # threshold 5
    r"---(`r 49`{.word} `r 60`{.word})---",        # limit 50
    r"---(`r x`{.num digits="1"})---"              # the construct wins
  )
  res <- render_rmd(batch_cases(cases), code = PRE, files = cfg)
  expect_false(res$failed, label = res$message)
  got <- unlist(split_cases(res, length(cases)))
  expect_equal(got, c("1,20", "3", "-4", "30%", "four 7", "forty-nine 60", "1,2"))
})

test_that("9.1.1: a document's weft: key overrides the project setting by setting", {
  cfg <- list("_weft.yml" = c("digits: 2", "minus: \"-\""))
  res <- render_rmd(batch_cases(c(r"---(`r x`{.num})---", r"---(`r neg`{.num})---")),
                    code = PRE, files = cfg, front = c("weft:", "  digits: 3"))
  expect_false(res$failed, label = res$message)
  got <- unlist(split_cases(res, 2))
  expect_equal(got, c("1.200", "-4"))
})

test_that("9.1.3 + last_knit()$config: the merged configuration is what the render used", {
  res <- render_rmd(r"---(`r x`{.num})---", code = PRE, in_process = TRUE,
                    files = list("_weft.yml" = "digits: 4"))
  expect_false(res$failed)
  expect_equal(canon_md(res$md), "1.2000")
  expect_equal(res$knit$config$digits, 4)
})
