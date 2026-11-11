## Test table. Each case: id (a-z0-9_), group, setup (R code run before the md),
## md (source markdown), expect (plain text after whitespace collapse) OR error
## (substring of the failure message), at (line of md the error must name),
## after (R code whose cat() output is appended, used for laziness checks),
## match ("exact"|"contains"), engines, solo (own document), html (substring the
## HTML must contain), expect_q / expect_r (per-engine override), pre (raw markdown
## appended after md), lang (document lang; own document). error/at may be vectors (every
## substring must appear; every line must be named). ASCII only (Windows-safe). `lg()` and LOG exist in every doc.
cases <- list()
add <- function(id, md, expect = NULL, setup = "", error = NULL, at = 1L, after = NULL, match = "exact",
                engines = c("quarto", "rmarkdown"), solo = FALSE, html = NULL, expect_q = NULL,
                expect_r = NULL, pre = NULL, group = "misc", lang = NULL) {
  stopifnot(grepl("^[a-z0-9_]+$", id), !any(vapply(cases, function(k) k$id == id, NA)))
  cases[[length(cases) + 1L]] <<- list(id = id, group = group, md = md, expect = expect, setup = setup,
    error = error, at = at, after = after, match = match, engines = engines,
    solo = solo || !is.null(error) || !is.null(lang), lang = lang, html = html, expect_q = expect_q, expect_r = expect_r, pre = pre)
}
Q <- '"'   # readability helper for n="n" below
N <- 'n="n"'

## MINUS = U+2212, ENDASH = U+2013 (written as escapes: this file is ASCII)
MINUS <- "−"; ENDASH <- "–"

## ---- values (items 1, 7) -------------------------------------------------------
g <- "values"
add("v_bare", "Value `r x` here.", "Value 42 here.", "x <- 42", group = g)
add("v_vec_default", "Sites `r sites` here.", "Sites A, B, C here.", 'sites <- c("A","B","C")', group = g)
add("v_claim_ok", 'Gaps: `r claim(n_gap, . > 10)` found.', "Gaps: 12 found.", "n_gap <- 12", group = g)
add("v_claim_multi_ok", '`r claim(x, . >= 10, . < 99)` ok', "50 ok", "x <- 50", group = g)
add("v_claim_returns_raw", '`r claim(x, . > 3)`{.num} end', "4 end", "x <- 3.7", group = g)
add("v_claim_dot_is_x", '`r claim(depth * 2, . > 1)`{.dec1} end', "2.4 end", "depth <- 1.2", group = g)
add("v_num", "`r x`{.num} end", "4 end", "x <- 3.7", group = g)
add("v_no_word0", "`r n`{.no .word} files", "no files", "n <- 0", group = g)
add("v_no_word2", "`r n`{.no .word} files", "two files", "n <- 2", group = g)
add("v_word1", "`r n`{.word} file", "one file", "n <- 1", group = g)
add("v_pct_strong", "Up `r p`{.pct .strong} today", "Up 46% today", "p <- 0.456", html = "<strong>46%</strong>", group = g)
add("v_em", "Up `r p`{.pct .em} today", "Up 46% today", "p <- 0.456", html = "<em>46%</em>", group = g)
add("v_strong_em_pos", "Up `r p`{.strong .pct} today", "Up 46% today", "p <- 0.456", html = "<strong>46%</strong>", group = g)
add("v_num_claim_raw", '`r claim(depth, . > 0.5)`{.num} m deep', "1 m deep", "depth <- 0.51", group = g)
add("v_or3", "Sites `r sites`{.or}.", "Sites A, B or C.", 'sites <- c("A","B","C")', group = g)
add("v_or2", "Sites `r sites`{.or}.", "Sites A or B.", 'sites <- c("A","B")', group = g)
add("v_or1", "Sites `r sites`{.or}.", "Sites A.", 'sites <- "A"', group = g)
add("v_and3", "Sites `r sites`{.and}.", "Sites A, B and C.", 'sites <- c("A","B","C")', group = g)
add("v_sep", 'Sites `r sites`{sep="; "}.', "Sites A; B; C.", 'sites <- c("A","B","C")', group = g)
add("v_sep_or", 'Sites `r sites`{.or sep="; "}.', "Sites A; B or C.", 'sites <- c("A","B","C")', group = g)
add("v_ul", "Sites:\n\n`r sites`{.ul}\n\nEnd.", "Sites: A B C End.", 'sites <- c("A","B","C")', html = "<li>B</li>", group = g)
add("v_ol", "Sites:\n\n`r sites`{.ol}\n\nEnd.", "Sites: A B C End.", 'sites <- c("A","B","C")', html = "<ol", group = g)
add("v_ord", "The `r k`{.ord} time, the `r j`{.ord} and the `r i`{.ord}.", "The 3rd time, the 11th and the 22nd.", "k <- 3; j <- 11; i <- 22", group = g)

## ---- item 2: n (arms, printed-number selection) ----------------------------------------
g <- "spans"
add("s_2_one", '[a person | # people]{n="n"} came', "a person came", "n <- 1", group = g)
add("s_2_many", '[a person | # people]{n="n"} came', "5 people came", "n <- 5", group = g)
add("s_2_zero", '[a person | # people]{n="n"} came', "0 people came", "n <- 0", group = g)
add("s_3_zero", '[no people | a person | # people]{n="n"} came', "no people came", "n <- 0", group = g)
add("s_3_one", '[no people | a person | # people]{n="n"} came', "a person came", "n <- 1", group = g)
add("s_3_many", '[no people | a person | # people]{n="n"} came', "3 people came", "n <- 3", group = g)
add("s_4_zero", '[no files | one file | two files | # files]{n="n"}', "no files", "n <- 0", group = g)
add("s_4_one", '[no files | one file | two files | # files]{n="n"}', "one file", "n <- 1", group = g)
add("s_4_two", '[no files | one file | two files | # files]{n="n"}', "two files", "n <- 2", group = g)
add("s_4_other", '[no files | one file | two files | # files]{n="n"}', "3 files", "n <- 3", group = g)
add("s_4_other_neg", '[no files | one file | two files | # files]{n="n"}', "-1 files", "n <- -1", group = g)
add("s_1arm", 'Found [# sites]{n="n"}.', "Found 4 sites.", "n <- 4", group = g)
add("s_empty_first_1", 'one file[ | s]{n="n"} here', "one file here", "n <- 1", group = g)
add("s_empty_first_2", 'two file[ | s]{n="n"} here', "two files here", "n <- 2", group = g)
add("s_no_0", '[# file | # files]{.no n="n"}', "no files", "n <- 0", group = g)
add("s_no_1", '[# file | # files]{.no n="n"}', "1 file", "n <- 1", group = g)
add("s_no_4", '[# file | # files]{.no n="n"}', "4 files", "n <- 4", group = g)
add("s_num_claim", 'Depth [# metre | # metres]{.num n="claim(depth, . > 0.5)"}.', "Depth 1 metre.", "depth <- 1.2", group = g)
add("s_dec1_plural", '[# unit | # units]{.dec1 n="x"}', "1.0 units", "x <- 1", group = g)
add("s_dec1_zero3", '[none | one | # many]{.dec1 n="x"}', "0.0 many", "x <- 0", group = g)
add("s_dec1_one3", '[none | one | # many]{.dec1 n="x"}', "1.0 many", "x <- 1", group = g)
add("s_num_rounds_to_one", '[none | one | # many]{.num n="x"}', "one", "x <- 1.2", group = g)
add("s_num_rounds_to_zero", '[none | one | # many]{.num n="x"}', "none", "x <- 0.2", group = g)
add("s_num_rounds_to_two", '[none | one | two | # many]{.num n="x"}', "two", "x <- 1.7", group = g)
add("s_two_plain_decimals", '[none | one | two | # many]{n="x"}', "1.5 many", "x <- 1.5", group = g)
add("s_word_1", '[# cat | # cats]{.word n="n"}', "one cat", "n <- 1", group = g)
add("s_word_3", '[# cat | # cats]{.word n="n"}', "three cats", "n <- 3", group = g)
add("s_two_in_sentence", '[a | b]{n="n"} and [c | d]{n="m"}', "a and d", "n <- 1; m <- 2", group = g)

## ---- item 2: if ----------------------------------------------------------------------------
add("s_if_t", 'It [rose | fell]{if="slope > 0"}.', "It rose.", "slope <- 1", group = g)
add("s_if_f", 'It [rose | fell]{if="slope > 0"}.', "It fell.", "slope <- -1", group = g)
add("s_if_multi_t", 'It [rose | fell]{if="n_gap > 10, n_sites >= 3"}.', "It rose.", "n_gap <- 12; n_sites <- 3", group = g)
add("s_if_multi_f", 'It [rose | fell]{if="n_gap > 10, n_sites >= 3"}.', "It fell.", "n_gap <- 12; n_sites <- 2", group = g)
add("s_if_paren_comma", 'It [yes | no]{if="all(c(a, b)), identical(c(1, 2), c(1, 2))"}.', "It yes.", "a <- TRUE; b <- TRUE", group = g)
add("s_if_empty_f", 'Done. [add more sites | ]{if="n_gap > 10"} End.', "Done. End.", "n_gap <- 5", group = g)
add("s_if_empty_t", 'Done. [add more sites | ]{if="n_gap > 10"} End.', "Done. add more sites End.", "n_gap <- 50", group = g)
add("s_if_empty_true_arm", 'Done. [ | not enough sites]{if="n_gap > 10"} End.', "Done. not enough sites End.", "n_gap <- 5", group = g)
add("s_guard_ok", 'Please [add more sites]{if="n_gap > 10"} now.', "Please add more sites now.", "n_gap <- 12", group = g)
add("s_guard_multi_ok", 'Please [add more sites]{if="n_gap > 10, n_sites >= 3"} now.', "Please add more sites now.", "n_gap <- 12; n_sites <- 3", group = g)
add("s_nested_value", '[All `r k` models rise]{if="all(up)"}.', "All 4 models rise.", "k <- 4; up <- c(TRUE, TRUE)", group = g)

## ---- item 2: sign ------------------------------------------------------------------------------
add("sg_2_pos", 'It [rose | fell]{sign="d"} by `r abs(d)`{.pct}.', "It rose by 5%.", "d <- 0.05", group = g)
add("sg_2_neg", 'It [rose | fell]{sign="d"} by `r abs(d)`{.pct}.', "It fell by 5%.", "d <- -0.05", group = g)
add("sg_3_zero", 'It [rose | fell | did not change]{sign="d"}.', "It did not change.", "d <- 0", group = g)
add("sg_3_pos", 'It [rose | fell | did not change]{sign="d"}.', "It rose.", "d <- 0.1", group = g)
add("sg_zero_as_printed", 'It [rose | fell | did not change]{.pct sign="d"}.', "It did not change.", "d <- 0.004", group = g)
add("sg_zero_as_printed_neg", 'It [rose | fell | did not change]{.pct sign="d"}.', "It did not change.", "d <- -0.004", group = g)
add("sg_not_zero_when_printed", 'It [rose | fell | did not change]{.pct sign="d"}.', "It fell.", "d <- -0.04", group = g)
add("sg_magnitude_hash", 'Cover [up # | down # | flat]{.pct sign="d"}.', "Cover down 30%.", "d <- -0.3", group = g)
add("sg_magnitude_hash_pos", 'Cover [up # | down # | flat]{.pct sign="d"}.', "Cover up 30%.", "d <- 0.3", group = g)
add("sg_magnitude_dec1", 'Shift [up # | down #]{.dec1 sign="d"}.', "Shift down 2.5.", "d <- -2.5", group = g)

## ---- item 4: classes, pass-through, text classes ---------------------------------------------------
g <- "classes"
add("c_pass_style", 'Value `r x`{.dec1 .smallcaps custom-style="Key figure"} end', "Value 1.2 end", "x <- 1.2",
    html = 'custom-style="Key figure"', group = g)
add("c_pass_class_html", 'Value `r x`{.dec1 .smallcaps custom-style="Key figure"} end', "Value 1.2 end", "x <- 1.2",
    html = 'class="smallcaps"', group = g)
add("c_pass_pos_indep", 'Value `r x`{.smallcaps custom-style="Key figure" .dec1} end', "Value 1.2 end", "x <- 1.2",
    html = 'class="smallcaps"', group = g)
add("c_pass_plain_when_empty", "Value `r x`{.dec1} end", "Value 1.2 end", "x <- 1.2", group = g)
add("c_pass_id", "Value `r x`{.dec1 #pid1} end", "Value 1.2 end", "x <- 1.2", html = 'id="pid1"', group = g)
add("c_pass_unknown_class", "Value `r x`{.bogus} end", "Value 1 end", "x <- 1", html = 'class="bogus"', group = g)
add("c_pass_unknown_class_span", '[a | b]{.bogus n="n"} end', "a end", "n <- 1", html = 'class="bogus"', group = g)
add("c_pass_span_style", '[a | b]{.smallcaps n="n"} end', "b end", "n <- 2", html = 'class="smallcaps"', group = g)
add("c_pass_if_span", '[a | b]{.mark if="TRUE"} end', "a end", html = "<mark>a</mark>", group = g)
add("c_pass_unknown_key", "Value `r x`{.dec1 foo=\"bar\"} end", "Value 1.2 end", "x <- 1.2", html = 'foo="bar"', group = g)
add("c_text_cap_after_count", "`r k`{.count .cap} sites", "Seven sites", "k <- 7", group = g)
add("c_text_cap_before_count", "`r k`{.cap .count} sites", "Seven sites", "k <- 7", group = g)
add("c_text_cap_count_12", "`r k`{.count .cap} sites", "12 sites", "k <- 12", group = g)
add("c_text_a", "X `r 8`{.a}, `r 11`{.a}, `r 18`{.a}, `r 85`{.a}, `r 80`{.a}, `r 12`{.a}, `r 7`{.a}, `r 90`{.a}, `r 110`{.a} Y",
    "X an 8, an 11, an 18, an 85, an 80, a 12, a 7, a 90, a 110 Y", group = g)
add("c_text_a_words", 'Is `r w1`{.a}, `r w2`{.a}, `r w3`{.a}, `r w4`{.a}?', "Is an apple, a unicorn, an hour, a dog?",
    'w1 <- "apple"; w2 <- "unicorn"; w3 <- "hour"; w4 <- "dog"', group = g)
add("c_text_a_cap", "`r 11`{.a .cap}-year record", "An 11-year record", group = g)
add("c_text_a_span", '[# year]{.a n="n"} record', "an 11 year record", "n <- 11", group = g)
add("c_text_cap_span", '[a person | # people]{.cap n="n"} came', "A person came", "n <- 1", group = g)
add("c_text_strong_span", '[a | b]{.strong n="n"} end', "a end", "n <- 1", html = "<strong>a</strong>", group = g)
add("c_text_em_span", '[a | b]{n="n" .em} end', "a end", "n <- 1", html = "<em>a</em>", group = g)
add("c_pos_indep_span", '[# cat | # cats]{#cs1 n="n" .word .cap .smallcaps}', "Three cats", "n <- 3", html = 'id="cs1"', group = g)
add("c_empty_arm_no_span", 'A[ | b]{.smallcaps n="n"} end', "A end", "n <- 1", group = g)

add("c_claim_attr_passthrough_value", 'Value `r x`{.dec1 claim=". > 1"} end', "Value 1.2 end", "x <- 1.2", html = 'claim="', group = "classes")
add("c_claim_attr_passthrough_span", '[a | b]{n="n" claim="TRUE"} end', "a end", "n <- 1", html = 'claim="TRUE"', group = "classes")
add("c_claim_attr_passthrough_bare_span", '[a]{claim="TRUE"} end', "a end", html = 'claim="TRUE"', group = "classes")

## ---- item 5: attribute forms --------------------------------------------------------------------------
g <- "attrforms"
add("a_unquoted", '[a | b]{n=k} end', "b end", "k <- 2", group = g)
add("a_single_quoted_mixed", "[# thing | # things]{n='k' .num #z5} end", "2 things end", "k <- 2.2", html = 'id="z5"', group = g)
add("a_id_first", '[# thing | # things]{#z6 .num n="k"} end', "2 things end", "k <- 2.2", html = 'id="z6"', group = g)
add("a_key_first", '[# thing | # things]{n="k" #z7 .num} end', "2 things end", "k <- 2.2", html = 'id="z7"', group = g)
add("a_unquoted_value_attr", 'Sites `r sites`{.or last=" & "} end', "Sites A, B & C end", 'sites <- c("A","B","C")', group = g)
add("a_single_quoted_if", "[rose | fell]{if='slope > 0'} end", "rose end", "slope <- 1", group = g)
add("a_if_sq_inner", "[sev | other]{if=\"tier == 'sev'\"} end", "sev end", "tier <- 'sev'", group = g)
add("a_value_id_single", "Value `r x`{.dec1 #z8 .smallcaps} end", "Value 1.2 end", "x <- 1.2", html = 'id="z8"', group = g)

## ---- item 3: back-references ----------------------------------------------------------------------------
g <- "backrefs"
add("r_formatter_travels_dec", 'Depth `r depth`{.dec1 #d1} [metre | metres]{n="#d1"}.', "Depth 1.0 metres.", "depth <- 1", group = g)
add("r_formatter_travels_num", 'Depth `r depth`{.num #d2} [metre | metres]{n="#d2"}.', "Depth 1 metre.", "depth <- 1.2", group = g)
add("r_print_again", 'There were `r k`{.word #d3} samples; in total [#]{n="#d3"}.', "There were three samples; in total three.", "k <- 3", group = g)
add("r_fresh_with_classes", 'Got `r x`{.num #d5} items, i.e. [# item | # items]{.dec1 n="#d5"}.', "Got 4 items, i.e. 3.7 items.", "x <- 3.7", group = g)
add("r_fresh_with_classes_one", 'Got `r x`{.dec1 #d5b}, i.e. [# item | # items]{.num n="#d5b"}.', "Got 1.0, i.e. 1 item.", "x <- 1", group = g)
add("r_span_defines", '[# a | # b]{n="n" #g1} and [x | y]{n="#g1"}', "2 b and y", "n <- 2", group = g)
add("r_sign_ref", 'Change `r d`{.pct #d6} [up | down]{sign="#d6"}.', "Change -5% down.", "d <- -0.05", group = g)
add("r_sign_ref_magnitude", 'Change `r d`{.pct #d6b} [up # | down #]{sign="#d6b"}.', "Change -5% down 5%.", "d <- -0.05", group = g)
add("r_across_blocks", 'Value `r depth`{.dec1 #d7}.\n\n```{r}\n#| include: false\nz <- 1\n```\n\nLater [# metre | # metres]{n="#d7"}.',
    "Value 1.0. Later 1.0 metres.", "depth <- 1", group = g)
add("r_in_arm", '[no sites | one site | # sites]{n="n" #d8}; again [# | #]{n="#d8"}.', "3 sites; again 3.", "n <- 3", group = g)
add("r_id_in_html", 'Value `r x`{#d9} end', "Value 4 end", "x <- 4", html = 'id="d9"', group = g)
add("r_inherit_dot_plain", '[# sample[ | s]{n="."} [was | were]{n="."} taken]{n="n"}', "1 sample was taken", "n <- 1", group = g)

## ---- escapes -------------------------------------------------------------------------------------------------
g <- "escapes"
add("esc_bar", '[a person \\| # people]{n="n"}', "2 people", "n <- 2", group = g)
add("esc_hash", '[\\# person | \\# people]{n="n"}', "2 people", "n <- 2", group = g)
add("esc_litbar", '[a || b | c]{n="n"}', "a | b", "n <- 1", group = g)
add("esc_litbar_bs", '[a \\|\\| b | c]{n="n"}', "a | b", "n <- 1", group = g)
add("esc_lithash_1", 'Item [## | # items]{n="n"} end', "Item # end", "n <- 1", group = g)
add("esc_lithash_alone", '[## | # items]{n="n"}', "", "n <- 1", group = g)   # documents the Pandoc behaviour
add("esc_lithash_3", '[## | # items]{n="n"}', "3 items", "n <- 3", group = g)
add("esc_lithash_bs", 'Item [\\#\\# | # items]{n="n"} end', "Item # end", "n <- 1", group = g)

## ---- laziness / data / nesting ------------------------------------------------------------------------------------
g <- "lazy"
lz <- 'LOG <- character()'
add("lazy_inline", '[`r lg("A", 0)` none | one | `r lg("C", 3)` many]{n="n"} here `r lg("PLAIN", 7)`.',
    "one here 7. LOG=PLAIN", paste(lz, "; n <- 1"), after = 'cat("LOG=", paste(LOG, collapse = ","), sep = "")', group = g)
add("lazy_inline_ctrl", '[`r lg("A", 0)` none | one | `r lg("C", 3)` many]{n="n"}.',
    "3 many. LOG=C", paste(lz, "; n <- 5"), after = 'cat("LOG=", paste(LOG, collapse = ","), sep = "")', group = g)
add("lazy_span", "[none | one | [p | q]{n=\"lg('NESTED', 1)\"}]{n=\"n\"} here.",
    "none here. LOG=", paste(lz, "; n <- 0"), after = 'cat("LOG=", paste(LOG, collapse = ","), sep = "")', group = g)
add("lazy_span_ctrl", "[none | one | [p | q]{n=\"lg('NESTED', 1)\"}]{n=\"n\"} here.",
    "p here. LOG=NESTED", paste(lz, "; n <- 5"), after = 'cat("LOG=", paste(LOG, collapse = ","), sep = "")', group = g)
add("lazy_if", "[ok | [p | q]{n=\"lg('IFARM', 1)\"}]{if=\"TRUE\"} here.",
    "ok here. LOG=", lz, after = 'cat("LOG=", paste(LOG, collapse = ","), sep = "")', group = g)
add("lazy_claim_unchosen", '[`r claim(lg("CL1", 1), . > 99)` x | y]{if="FALSE"} here.',
    "y here. LOG=", lz, after = 'cat("LOG=", paste(LOG, collapse = ","), sep = "")', group = g)
add("lazy_if_multi_conds", '[a | b]{if="FALSE, lg(\'COND2\', TRUE)"} here.',
    "b here. LOG=COND2", lz, after = 'cat("LOG=", paste(LOG, collapse = ","), sep = "")', group = g)
add("data_span_text", "Data: `r evil` end.", "Data: x | y end. LOG=",
    paste(lz, "; evil <- '[x | y]{n=\"lg(\\'INJECTED\\', 1)\"}'"), after = 'cat("LOG=", paste(LOG, collapse = ","), sep = "")', group = g)
add("data_inline_code", "Data: `r evil2` end.", 'Data: a r lg("INJ2") b end. LOG=',
    paste(lz, "; evil2 <- 'a `r lg(\"INJ2\")` b'"), after = 'cat("LOG=", paste(LOG, collapse = ","), sep = "")', group = g)

## ---- item 6: leave alone (non-executed fences change nothing) ------------------------------------------------------
g <- "leave"
add("la_fence", '```markdown\n[a | b]{n="n"}\n```', '[a | b]{n="n"}', "n <- 1", group = g)
add("la_fence_tilde", '~~~\n[a | b]{n="n"}\n~~~', '[a | b]{n="n"}', "n <- 1", group = g)
add("la_fence_inline_r", 'Before.\n\n```markdown\nx is `r 1+1`\n```', 'Before. x is 2', group = g)
add("la_fence_inline_r_attr", 'Before.\n\n```markdown\nx is `r 1+1`{.num} and `r 7`{.dec1 #fid}\n```', 'Before. x is 2{.num} and 7{.dec1 #fid}', group = g)
add("la_fence_inline_r_tilde", '~~~\nx is `r y`\n~~~', 'x is 5', "y <- 5", group = g)
add("la_fence_inline_r_span_text", '```markdown\n[`r y` | b]{n="n"}\n```', '[5 | b]{n="n"}', "y <- 5; n <- 1", group = g)
add("la_fence_inline_claim_bare", '```markdown\nclaim: `r claim(y, . > 1)`\n```', 'claim: 5', "y <- 5", group = g)
add("la_code", 'Write `[a | b]{n="n"}` as is.', 'Write [a | b]{n="n"} as is.', "n <- 1", group = g)
add("la_math", 'Math $a | b$ and [x | y]{n="n"} and $$c | d$$ end.', "\\(a | b\\) and x and", "n <- 1", match = "contains", group = g)
add("la_link", "See [the docs](https://example.org/a|b) now.", "See the docs now.", group = g)
add("la_cite", "As shown [@smith2020] here.", "smith2020", match = "contains", group = g)
add("la_plain_span", "[text]{.smallcaps} and [other]{#idx .cls} end.", "text and other end.", html = 'class="smallcaps"', group = g)
add("la_brackets", "[just brackets] and [ ] end.", "[just brackets] and [ ] end.", group = g)
add("la_bars_hash", "a | b and # not heading and [x | y] z", "a | b and # not heading and [x | y] z", group = g)
add("la_escaped_brackets", '\\[a | b\\]{n="n"} end', '[a | b]{n=“n”} end', "n <- 1",
    expect_r = '\\[a | b\\]{n=“n”} end', group = g)
add("la_fnmark", "Claim[^fn1] here.\n\n[^fn1]: The note.", "The note.", match = "contains", solo = TRUE, group = g)

## ---- structure --------------------------------------------------------------------------------------------------------------
g <- "structure"
add("st_heading", '## Heading with [# site | # sites]{n="n"}', "Heading with 1 site", "n <- 1", group = g)
add("st_bullet", '- first [a | b]{n="n"}\n- second `r x`{.num}', "first a second 7", "n <- 1; x <- 7", group = g)
add("st_quote", '> quote [a | b]{n="n"} here', "quote a here", "n <- 1", group = g)
add("st_table", '| col | val |\n|-----|-----|\n| x | [a \\| b]{n="n"} |', "col val x b", "n <- 2", group = g)
add("st_fn_inline", 'Text^[note: [# site | # sites]{n="n"} found] end.', "2 sites found", "n <- 2", match = "contains", solo = TRUE, group = g)
add("st_div", '::: {.box}\nCallout [a | b]{n="n"} text `r x`.\n:::', "Callout a text 7.", "n <- 1; x <- 7", group = g)
add("st_callout_q", '::: {.callout-note}\nCallout [a | b]{n="n"} text.\n:::', "Callout a text.", "n <- 1", match = "contains", engines = "quarto", group = g)
add("st_wrap_bar", 'A [a person\n| # people]{n="n"} came\nhere.', "A a person came here.", "n <- 1", group = g)
add("st_wrap_inside", 'A [a\nperson | # \npeople]{n="n"} came.', "A a person came.", "n <- 1", group = g)
add("st_wrap_many", 'A [a person\n| # \npeople]{n="n"} came.', "A 3 people came.", "n <- 3", group = g)

## ---- arm contents ----------------------------------------------------------------------------------------------------------------
g <- "arms"
add("ar_emph_1", '[**bold** one | *em* two]{n="n"}', "bold one", "n <- 1", group = g)
add("ar_emph_2", '[**bold** one | *emph* two]{n="n"}', "emph two", "n <- 2", html = "<em>emph</em>", group = g)
add("ar_link", '[see [docs](https://example.org/x) | none]{n="n"}', "see docs", "n <- 1", html = 'href="https://example.org/x"', group = g)
add("ar_link_bar", '[see [a | b](https://example.org/y) | none]{n="n"}', "see a | b", "n <- 1", group = g)
add("ar_link_hash", '[see [docs](#anchor) | none]{n="n"}', "see docs", "n <- 1", html = 'href="#anchor"', group = g)
add("ar_math", '[$a | b$ rule | other]{n="n"}', "\\(a | b\\) rule", "n <- 1", group = g)
add("ar_code", '[`a | b` code | other]{n="n"}', "a | b code", "n <- 1", group = g)
add("ar_xref_q", '[see @fig-x | none]{n="n"}', "see Figure 1", "n <- 1", match = "contains", engines = "quarto",
    pre = '\n::: {#fig-x}\n```{r}\n#| echo: false\nplot(1)\n```\n\nThe plot.\n:::', group = g)

## ---- second tier (items 8, 9) -------------------------------------------------------------------------------------------------------------
g <- "tier2"
add("t_range", 'Depth `r c(3, 5)`{.range} m.', paste0("Depth 3", ENDASH, "5 m."), group = g)
add("t_range_collapse", 'Depth `r c(2, 2)`{.range} m.', "Depth 2 m.", group = g)
add("t_range_neg", 'Temp `r c(-5, -3)`{.range}.', paste0("Temp ", MINUS, "5 to ", MINUS, "3."), group = g)
add("t_range_mixed", 'Temp `r c(-1, 4)`{.range}.', paste0("Temp ", MINUS, "1 to 4."), group = g)
add("t_range_collapse_printed", 'Depth `r c(3.2, 3.4)`{.num .range} m.', "Depth 3 m.", group = g)
add("t_range_n_plural", '[# site | # sites]{.range n="c(lo, hi)"}', paste0("3", ENDASH, "5 sites"), "lo <- 3; hi <- 5", group = g)
add("t_range_n_collapse_one", '[# site | # sites]{.range n="c(lo, hi)"}', "1 site", "lo <- 1; hi <- 1", group = g)
add("t_range_n_collapse_two", '[# site | # sites]{.range n="c(lo, hi)"}', "2 sites", "lo <- 2; hi <- 2", group = g)
add("t_range_n_one_to_two", '[# site | # sites]{.range n="c(lo, hi)"}', paste0("1", ENDASH, "2 sites"), "lo <- 1; hi <- 2", group = g)
add("t_range_n_printed_collapse", '[# site | # sites]{.num .range n="c(lo, hi)"}', "1 site", "lo <- 0.8; hi <- 1.2", group = g)
add("t_p_small", 'Result: `r pv`{.p}.', "Result: p < 0.001.", "pv <- 0.0004", group = g)
add("t_p_eq", 'Result: `r pv`{.p}.', "Result: p = 0.032.", "pv <- 0.0321", group = g)
add("t_p_bound_other", '[# test | # tests]{.p n="pv"}', "p < 0.001 tests", "pv <- 0.0004", group = g)
add("t_bound_one_takes_other", '[# unit | # units]{.lt1 n="x"}', "< 1 units", 'x <- 1; clag_register("lt1", function(x) list(text = "< 1", num = 1, dec = FALSE, rel = "<"))', group = g)
add("t_count_word", '`r k`{.count} sites', "seven sites", "k <- 7", group = g)
add("t_count_digits", '`r k`{.count} sites', "12 sites", "k <- 12", group = g)
add("t_count_span_one", '[# site | # sites]{.count n="n"}', "one site", "n <- 1", group = g)
add("t_count_span_many", '[# site | # sites]{.count n="n"}', "three sites", "n <- 3", group = g)
add("t_count_span_digits", '[# site | # sites]{.count n="n"}', "12 sites", "n <- 12", group = g)
add("t_pairs", 'Means: `r means`{.dec1 .pairs}.', "Means: A (1.2), B (3.4) and C (5.6).", 'means <- c(A = 1.2, B = 3.4, C = 5.6)', group = g)
add("t_pairs_num", 'Means: `r means`{.num .pairs}.', "Means: A (1), B (3) and C (6).", 'means <- c(A = 1.2, B = 3.4, C = 5.6)', group = g)
add("t_trunc_and", 'Sites `r sites`{.and trunc="3"}.', "Sites a, b, c and 4 others.", "sites <- letters[1:7]", group = g)
add("t_trunc_or", 'Sites `r sites`{.or trunc="3"}.', "Sites a, b, c or 4 others.", "sites <- letters[1:7]", group = g)
add("t_trunc_one_other", 'Sites `r sites`{.and trunc="3"}.', "Sites a, b, c and 1 other.", "sites <- letters[1:4]", group = g)
add("t_trunc_not_needed", 'Sites `r sites`{.and trunc="3"}.', "Sites a, b and c.", "sites <- letters[1:3]", group = g)
add("t_lang_en_ok", '[a | b]{n="n"} end', "b end", "n <- 2", lang = "en-AU")
add("t_lang_fr_1arm_ok", 'Found [# sites]{n="n"}.', "Found 2 sites.", "n <- 2", lang = "fr")
add("t_lang_fr_if_ok", '[a | b]{if="TRUE"} end', "a end", lang = "fr")
add("e_lang_fr_2arm", '[a | b]{n="n"}', error = "not shipped", setup = "n <- 1", lang = "fr")
add("e_lang_de_3arm", '[a | b | c]{n="n"}', error = "'de'", setup = "n <- 1", lang = "de")

## ---- errors (grammar errors stop at once; failed checks are collected and reported once at the end) ----------------------
add("e_claim_fail", '`r claim(n_gap, . > 10)`', error = c("1 claim failed", ". > 10 was FALSE (value 5)"), setup = "n_gap <- 5")
add("e_claim_multi_fail", '`r claim(x, . >= 10, . < 99)`', error = ". < 99 was FALSE (value 100)", setup = "x <- 100")
add("e_claim_report_all", 'Line one `r claim(a, . > 10)` x.\n\nMiddle.\n\nLine five [# m | # ms]{.num n="claim(b, . > 10)"}.\n\nEnd `r claim(c, . > 10)`',
    error = c("3 claims failed", "claim(a, . > 10)", "[# m | # ms]", "claim(c, . > 10)"), at = c(1L, 5L, 7L), setup = "a <- 1; b <- 2; c <- 3")
add("e_claim_across_blocks", 'First `r claim(a, . > 10)`.\n\n```{r}\n#| include: false\nz <- 1\n```\n\nSecond `r claim(a, . > 10)`.',
    error = "2 claims failed", at = c(1L, 8L), setup = "a <- 1")
add("e_claim_nonlogical", '`r claim(x, c(TRUE, TRUE))`', error = "did not give a single TRUE", setup = "x <- 1")
add("e_claim_na", '`r claim(x, . > 1)`', error = "did not give a single TRUE", setup = "x <- NA_real_")
add("e_claim_in_n", '[# m | # ms]{.num n="claim(depth, . > 0.5)"}', error = ". > 0.5 was FALSE (value 0.2)", setup = "depth <- 0.2")
add("e_claim_in_sign", '[up | down]{sign="claim(d, . > 0)"}', error = ". > 0 was FALSE", setup = "d <- -1")
add("e_claim_in_if", '[a | b]{if="claim(d, . > 0) > 0"}', error = ". > 0 was FALSE", setup = "d <- -1")
add("e_claim_check_errors", '`r claim(x, nosuch_zz > 1)`', error = "nosuch_zz", setup = "x <- 1")
add("e_guard_fail", '[add more sites]{if="n_gap > 10"}', error = c("add more sites", "n_gap > 10 was FALSE"), setup = "n_gap <- 5")
add("e_guard_each_condition", 'Please [add more sites]{if="n_gap > 10, n_sites >= 3, ok"} now.',
    error = c("2 claims failed", "n_gap > 10 was FALSE", "n_sites >= 3 was FALSE"), at = c(1L, 1L), setup = "n_gap <- 5; n_sites <- 1; ok <- TRUE")
add("e_sign_zero_2arm", 'Line one.\n\nIt [rose | fell]{sign="d"} here.', error = c("no zero arm", "1 claim failed"), at = 3L, setup = "d <- 0")
add("e_sign_zero_printed_2arm", 'It [rose | fell]{.pct sign="d"} here.', error = "no zero arm", setup = "d <- 0.004")
add("e_sign_string", '[a | b]{sign="d"}', error = "single number", setup = 'd <- "a"')
add("e_sign_1arm", '[a]{sign="d"}', error = "sign takes 2 arms", setup = "d <- 1")
add("e_sign_4arm", '[a | b | c | d]{sign="d"}', error = "sign takes 2 arms", setup = "d <- 1")
add("e_n_vector", '[a | b]{n="n"}', error = "length(n)", setup = "n <- c(1, 2)")
add("e_n_string", '[a | b]{n="n"}', error = "single number", setup = 'n <- "a"')
add("e_n_na", '[a | b]{n="n"}', error = "single number", setup = "n <- NA_real_")
add("e_n_5arms", '[a | b | c | d | e]{n="n"}', error = "at most 4 arms", setup = "n <- 1")
add("e_n_range_len3", '[a | b]{.range n="c(1,2,3)"}', error = "single number")
add("e_n_len2_no_range", '[a | b]{n="c(1, 2)"}', error = "length(c(1, 2))")
add("e_if_3arms", '[a | b | c]{if="TRUE"}', error = "if takes 1 arm")
add("e_if_nonlogical", '[a | b]{if="1"}', error = "single TRUE or FALSE")
add("e_if_second_nonlogical", '[a | b]{if="TRUE, 1"}', error = "single TRUE or FALSE")
add("e_if_formatter", '[a | b]{.num if="TRUE"}', error = "formatter")
add("e_two_governors_n_if", '[a | b]{n="n" if="TRUE"}', error = "exactly one of n, if and sign", setup = "n <- 1")
add("e_two_governors_n_sign", '[a | b]{n="n" sign="n"}', error = "exactly one of n, if and sign", setup = "n <- 1")
add("e_two_governors_if_sign", '[a | b]{if="TRUE" sign="1"}', error = "exactly one of n, if and sign")
add("e_key_on_value", '`r x`{n="x"}', error = "does not go on a value", setup = "x <- 1")
add("e_dot_no_governor", '[a | b]{n="."}', error = "enclosing n span")
add("e_dot_in_sign", '[up [a | b]{n="."} | down]{sign="d"}', error = "enclosing n span", setup = "d <- 1")
add("e_ref_unknown", 'Line one.\n\n[a | b]{n="#nope"}', error = "#nope", at = 3L)
add("e_ref_defined_later", '[a | b]{n="#late1"} then `r x`{#late1 .num}', error = c("#late1", "later"), setup = "x <- 1")
add("e_ref_later_block", 'First [a | b]{sign="#late2"}.\n\n```{r}\n#| include: false\nz <- 1\n```\n\nThen `r x`{#late2}.', error = "#late2", setup = "x <- 1")
add("e_ref_to_string", 'Is `r s`{#sid1} [a | b]{n="#sid1"}', error = "single number", setup = 's <- "txt"')
add("e_ref_not_whole_value", '`r x`{#rid9} [a | b]{n="#rid9 + 1"}', error = "single number", setup = "x <- 1")
add("e_ref_duplicate_id", '`r x`{#dup1} and `r x`{#dup1}', error = "already defined", setup = "x <- 1")
add("e_typo_class_val", "`r x`{.nmu}", error = "one edit from .num", setup = "x <- 1")
add("e_typo_class_span", '[a | b]{.nmu n="n"}', error = ".nmu", setup = "n <- 1")
add("e_typo_class_swap_text", "`r x`{.cpa}", error = "one edit from .cap", setup = "x <- 1")
add("e_typo_class_extra_letter", "`r x`{.words}", error = "one edit from .word", setup = "x <- 1")
add("e_r_error", '`r stop("boom")`', error = "boom")
add("e_r_error_attr", '`r stop("boom")`{.num}', error = "boom")
add("e_missing_var", "`r nosuch_var_zz`", error = "nosuch_var_zz")
add("e_line_span", 'Line one.\nLine two.\nLine three.\nLine four has [a | b]{n="zzz_missing"} here.\nLine five.', error = "zzz_missing", at = 4L)
add("e_line_value", 'Line one.\nLine two.\n\nLine four `r nosuch_val` x.\nLine five.', error = "nosuch_val", at = 4L)
add("e_line_nested", '[no |\none |\n[p | q]{n="nosuch_nested"}]{n="n"}', error = "nosuch_nested", at = 3L, setup = "n <- 5")
add("e_line_grammar", 'Line one.\nLine two.\n\nLine four [a | b | c | d | e]{n="n"} x.\nEnd.', error = "at most 4 arms", at = 4L, setup = "n <- 1")
add("e_line_multi_on_line", 'Intro text here.\n\n- item with [a | b]{n="n"} fine\n- item with `r claim(x, . > 99)` bad', error = ". > 99", at = 4L, setup = "n <- 1; x <- 1")
add("e_line_fence_value", 'Intro.\n\n```markdown\nok\nbad `r nosuch_fence_zz` here\n```', error = "nosuch_fence_zz", at = 5L)
