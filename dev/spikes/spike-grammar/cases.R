## Test table. Each case: id (a-z0-9_), group, setup (R code run before the md),
## md (source markdown), expect (plain text after whitespace collapse) OR error
## (substring of the failure message), at (line of md the error must name),
## after (R code whose cat() output is appended, used for laziness checks),
## match ("exact"|"contains"), engines, solo (own document), html (substring the
## HTML must contain), expect_q / expect_r (per-engine override), pre (raw markdown
## appended after md). ASCII only (Windows-safe). `lg()` and LOG exist in every doc.
cases <- list()
add <- function(id, md, expect = NULL, setup = "", error = NULL, at = 1L, after = NULL, match = "exact",
                engines = c("quarto", "rmarkdown"), solo = FALSE, html = NULL, expect_q = NULL,
                expect_r = NULL, pre = NULL, group = "misc") {
  stopifnot(grepl("^[a-z0-9_]+$", id), !any(vapply(cases, function(k) k$id == id, NA)))
  cases[[length(cases) + 1L]] <<- list(id = id, group = group, md = md, expect = expect, setup = setup,
    error = error, at = at, after = after, match = match, engines = engines,
    solo = solo || !is.null(error), html = html, expect_q = expect_q, expect_r = expect_r, pre = pre)
}
Q <- '"'   # readability helper for n="n" below
N <- 'n="n"'

## ---- values -------------------------------------------------------------------
g <- "values"
add("v_bare", "Value `r x` here.", "Value 42 here.", "x <- 42", group = g)
add("v_vec_default", "Sites `r sites` here.", "Sites A, B, C here.", 'sites <- c("A","B","C")', group = g)
add("v_claim_ok", 'Gaps: `r n_gap`{claim=". > 10"} found.', "Gaps: 12 found.", "n_gap <- 12", group = g)
add("v_claim_multi_ok", '`r x`{claim=". >= 10, . < 99"} ok', "50 ok", "x <- 50", group = g)
add("v_num", "`r x`{.num} end", "4 end", "x <- 3.7", group = g)
add("v_no_word0", "`r n`{.no .word} files", "no files", "n <- 0", group = g)
add("v_no_word2", "`r n`{.no .word} files", "two files", "n <- 2", group = g)
add("v_word1", "`r n`{.word} file", "one file", "n <- 1", group = g)
add("v_pct_strong", "Up `r p`{.pct .strong} today", "Up 46% today", "p <- 0.456", html = '>46%</span>', group = g)
add("v_em", "Up `r p`{.pct .em} today", "Up 46% today", "p <- 0.456", html = 'class="em"', group = g)
add("v_num_claim_raw", '`r depth`{.num claim=". > 0.5"} m deep', "1 m deep", "depth <- 0.51", group = g)
add("v_or3", "Sites `r sites`{.or}.", "Sites A, B or C.", 'sites <- c("A","B","C")', group = g)
add("v_or2", "Sites `r sites`{.or}.", "Sites A or B.", 'sites <- c("A","B")', group = g)
add("v_or1", "Sites `r sites`{.or}.", "Sites A.", 'sites <- "A"', group = g)
add("v_sep", 'Sites `r sites`{sep="; "}.', "Sites A; B; C.", 'sites <- c("A","B","C")', group = g)
add("v_sep_or", 'Sites `r sites`{.or sep="; "}.', "Sites A; B or C.", 'sites <- c("A","B","C")', group = g)
add("v_ul", "Sites:\n\n`r sites`{.ul}\n\nEnd.", "Sites: A B C End.", 'sites <- c("A","B","C")', html = "<li>B</li>", group = g)

## ---- governed spans ------------------------------------------------------------
g <- "spans"
add("s_2_one", '[a person | # people]{n="n"} came', "a person came", "n <- 1", group = g)
add("s_2_many", '[a person | # people]{n="n"} came', "5 people came", "n <- 5", group = g)
add("s_2_zero", '[a person | # people]{n="n"} came', "0 people came", "n <- 0", group = g)
add("s_3_zero", '[no people | a person | # people]{n="n"} came', "no people came", "n <- 0", group = g)
add("s_3_one", '[no people | a person | # people]{n="n"} came', "a person came", "n <- 1", group = g)
add("s_3_many", '[no people | a person | # people]{n="n"} came', "3 people came", "n <- 3", group = g)
add("s_1arm", 'Found [# sites]{n="n"}.', "Found 4 sites.", "n <- 4", group = g)
add("s_empty_first_1", 'one file[ | s]{n="n"} here', "one file here", "n <- 1", group = g)
add("s_empty_first_2", 'two file[ | s]{n="n"} here', "two files here", "n <- 2", group = g)
add("s_no_0", '[# file | # files]{.no n="n"}', "no files", "n <- 0", group = g)
add("s_no_1", '[# file | # files]{.no n="n"}', "1 file", "n <- 1", group = g)
add("s_no_4", '[# file | # files]{.no n="n"}', "4 files", "n <- 4", group = g)
add("s_num_claim", 'Depth [# metre | # metres]{.num n="depth" claim=". > 0.5"}.', "Depth 1 metre.", "depth <- 1.2", group = g)
add("s_dec1_plural", '[# unit | # units]{.dec1 n="x"}', "1.0 units", "x <- 1", group = g)
add("s_word_1", '[# cat | # cats]{.word n="n"}', "one cat", "n <- 1", group = g)
add("s_word_3", '[# cat | # cats]{.word n="n"}', "three cats", "n <- 3", group = g)
add("s_if_t", 'It [rose | fell]{if="slope > 0"}.', "It rose.", "slope <- 1", group = g)
add("s_if_f", 'It [rose | fell]{if="slope > 0"}.', "It fell.", "slope <- -1", group = g)
add("s_if_empty_f", 'Done. [add more sites | ]{if="n_gap > 10"} End.', "Done. End.", "n_gap <- 5", group = g)
add("s_if_empty_t", 'Done. [add more sites | ]{if="n_gap > 10"} End.', "Done. add more sites End.", "n_gap <- 50", group = g)
add("s_guard_ok", 'Please [add more sites]{claim="n_gap > 10"} now.', "Please add more sites now.", "n_gap <- 12", group = g)
add("s_nested_value", '[All `r k` models rise]{claim="all(up)"}.', "All 4 models rise.", "k <- 4; up <- c(TRUE, TRUE)", group = g)
add("s_inherit_1", '[# sample[ | s]{n="."} [was | were]{n="."} taken]{n="n"}', "1 sample was taken", "n <- 1", group = g)
add("s_inherit_3", '[# sample[ | s]{n="."} [was | were]{n="."} taken]{n="n"}', "3 samples were taken", "n <- 3", group = g)
add("s_two_in_sentence", '[a | b]{n="n"} and [c | d]{n="m"}', "a and d", "n <- 1; m <- 2", group = g)

## ---- escapes ---------------------------------------------------------------------
g <- "escapes"
add("esc_bar", '[a person \\| # people]{n="n"}', "2 people", "n <- 2", group = g)
add("esc_hash", '[\\# person | \\# people]{n="n"}', "2 people", "n <- 2", group = g)
add("esc_litbar", '[a || b | c]{n="n"}', "a | b", "n <- 1", group = g)
add("esc_litbar_bs", '[a \\|\\| b | c]{n="n"}', "a | b", "n <- 1", group = g)
add("esc_lithash_1", 'Item [## | # items]{n="n"} end', "Item # end", "n <- 1", group = g)
## NB: a paragraph that is only "#" would be an empty ATX heading to Pandoc, hence the sentence.
add("esc_lithash_alone", '[## | # items]{n="n"}', "", "n <- 1", group = g)   # documents the Pandoc behaviour
add("esc_lithash_3", '[## | # items]{n="n"}', "3 items", "n <- 3", group = g)
add("esc_lithash_bs", 'Item [\\#\\# | # items]{n="n"} end', "Item # end", "n <- 1", group = g)

## ---- laziness / data -----------------------------------------------------------------
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
add("data_span_text", "Data: `r evil` end.", "Data: x | y end. LOG=",
    paste(lz, "; evil <- '[x | y]{n=\"lg(\\'INJECTED\\', 1)\"}'"), after = 'cat("LOG=", paste(LOG, collapse = ","), sep = "")', group = g)
add("data_inline_code", "Data: `r evil2` end.", 'Data: a r lg("INJ2") b end. LOG=',
    paste(lz, "; evil2 <- 'a `r lg(\"INJ2\")` b'"), after = 'cat("LOG=", paste(LOG, collapse = ","), sep = "")', group = g)

## ---- leave alone ------------------------------------------------------------------------
g <- "leave"
add("la_fence", '```markdown\n[a | b]{n="n"}\n```', '[a | b]{n="n"}', "n <- 1", group = g)
add("la_fence_tilde", '~~~\n[a | b]{n="n"}\n~~~', '[a | b]{n="n"}', "n <- 1", group = g)
add("la_fence_inline_r", 'Before.\n\n```markdown\nx is `r 1+1`\n```', 'Before. x is `r 1+1`', group = g)
add("la_code", 'Write `[a | b]{n="n"}` as is.', 'Write [a | b]{n="n"} as is.', "n <- 1", group = g)
add("la_math", 'Math $a | b$ and [x | y]{n="n"} and $$c | d$$ end.', "\\(a | b\\) and x and", "n <- 1", match = "contains", group = g)
add("la_link", "See [the docs](https://example.org/a|b) now.", "See the docs now.", group = g)
add("la_cite", "As shown [@smith2020] here.", "smith2020", match = "contains", group = g)
add("la_plain_span", "[text]{.smallcaps} and [other]{#idx .cls} end.", "text and other end.", html = 'class="smallcaps"', group = g)
add("la_brackets", "[just brackets] and [ ] end.", "[just brackets] and [ ] end.", group = g)
add("la_bars_hash", "a | b and # not heading and [x | y] z", "a | b and # not heading and [x | y] z", group = g)
## Pandoc smart quotes curl the n="n"; R Markdown html_document reads \[ \] as display math (tex_math_single_backslash).
add("la_escaped_brackets", '\\[a | b\\]{n="n"} end', '[a | b]{n=\u201cn\u201d} end', "n <- 1",
    expect_r = '\\[a | b\\]{n=\u201cn\u201d} end', group = g)
add("la_fnmark", "Claim[^fn1] here.\n\n[^fn1]: The note.", "The note.", match = "contains", solo = TRUE, group = g)

## ---- structure ---------------------------------------------------------------------------------
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

## ---- arm contents ---------------------------------------------------------------------------------
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

## ---- errors ----------------------------------------------------------------------------------------------
add("e_claim_fail", '`r n_gap`{claim=". > 10"}', error = ". > 10", setup = "n_gap <- 5")
add("e_claim_multi_fail", '`r x`{claim=". >= 10, . < 99"}', error = ". < 99", setup = "x <- 100")
add("e_unknown_class_val", "`r x`{.bogus}", error = ".bogus", setup = "x <- 1")
add("e_unknown_class_span", '[a | b]{.bogus n="n"}', error = ".bogus", setup = "n <- 1")
add("e_n_vector", '[a | b]{n="n"}', error = "length(n)", setup = "n <- c(1, 2)")
add("e_n_string", '[a | b]{n="n"}', error = "single number", setup = 'n <- "a"')
add("e_n_4arms", '[a | b | c | d]{n="n"}', error = "at most 3 arms", setup = "n <- 1")
add("e_if_3arms", '[a | b | c]{if="TRUE"}', error = "exactly 2 arms")
add("e_if_1arm", '[a]{if="TRUE"}', error = "exactly 2 arms")
add("e_claim_2arms", '[a | b]{claim="TRUE"}', error = "claim alone takes 1 arm")
add("e_n_and_if", '[a | b]{n="n" if="TRUE"}', error = "only one of n and if", setup = "n <- 1")
add("e_if_nonlogical", '[a | b]{if="1"}', error = "single TRUE or FALSE")
add("e_dot_no_governor", '[a | b]{n="."}', error = "enclosing span")
add("e_r_error", '`r stop("boom")`', error = "boom")
add("e_missing_var", "`r nosuch_var_zz`", error = "nosuch_var_zz")
add("e_guard_fail", '[add more sites]{claim="n_gap > 10"}', error = "add more sites", setup = "n_gap <- 5")
add("e_num_claim_fail", '[# m | # ms]{.num n="depth" claim=". > 0.5"}', error = ". > 0.5", setup = "depth <- 0.2")
add("e_line_span", 'Line one.\nLine two.\nLine three.\nLine four has [a | b]{n="zzz_missing"} here.\nLine five.', error = "zzz_missing", at = 4L)
add("e_line_value", 'Line one.\nLine two.\n\nLine four `r nosuch_val` x.\nLine five.', error = "nosuch_val", at = 4L)
add("e_line_nested", '[no |\none |\n[p | q]{n="nosuch_nested"}]{n="n"}', error = "nosuch_nested", at = 3L, setup = "n <- 5")
add("e_line_multi_on_line", 'Intro text here.\n\n- item with [a | b]{n="n"} fine\n- item with `r x`{claim=". > 99"} bad', error = ". > 99", at = 4L, setup = "n <- 1; x <- 1")
