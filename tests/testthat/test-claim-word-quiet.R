# The quieter `claim-word` lint: rules CW1 to CW10 of dev/design-claim-word.md.
# claim-word is tier 2, so lint_one() is asked for its default tier 1:2.
# ASCII only: write non-ASCII as \uXXXX.

cwq <- function(lines, weft_yml = NULL, ext = "qmd", env = parent.frame()) {
  lint_one(lines, rules = "claim-word", ext = ext, weft_yml = weft_yml, env = env)
}

# the setting claim_quantifiers, as _weft.yml lines
qs <- function(v) paste0("claim_quantifiers: ", v)

# the condition lints() raises over a project with these _weft.yml lines
cwq_err_yml <- function(yml) {
  root <- lint_proj(list("a.qmd" = "Plain."), weft_yml = yml)
  f2_cond(lints(root))
}
# ... and over a document with these lines under `weft:` in its front matter
cwq_err_front <- function(lines) {
  doc <- c("---", "title: T", "weft:", paste0("  ", lines), "---", "", "Plain.")
  f2_cond(lint_one(doc, rules = "claim-word"))
}

CWQ_IDIOMS <- c("at least", "at the very least", "at most", "most likely", "as a whole", "on the whole",
                "no longer", "no doubt", "no matter", "not only", "if only", "nothing else", "nothing more",
                "best read", "best understood", "best seen", "best practice", "lower bound", "lower bounds",
                "lower limit", "maximum likelihood", "minimum detectable", "significant figures",
                "significant digits", "fall short", "either way")

# ---- CW1: four quantifiers leave the shipped lexicon ---------------------------------------------

test_that("CW1: the shipped lexicon holds 65 words and has lost each, both, either and whole", {
  w <- weft:::claim_lexicon(weft:::default_config(), "en")
  expect_length(w, 65L)
  expect_false(any(c("each", "both", "either", "whole") %in% w))
  expect_true(all(c("all", "every", "none", "only", "most", "neither", "entire", "sole") %in% w))
  y <- yaml::read_yaml(system.file("weft-claim-words.yml", package = "weft"))
  expect_false(any(c("each", "both", "either", "whole") %in% unlist(y[c("quantifier", "extremum", "direction")])))
  expect_length(unlist(y[c("quantifier", "extremum", "direction")], use.names = FALSE), 65L)
})

test_that("CW1: each, both, either and whole are no hit, even with a number and with claim_quantifiers any", {
  rows <- c("Each of the 3 sites was wet.", "Both of the 3 sites were wet.", "Either of the 3 sites was wet.",
            "The whole of the 3 sites was wet.")
  for (r in rows) {
    expect_identical(nrow(cwq(r)), 0L, info = r)
    expect_identical(nrow(cwq(r, weft_yml = qs("any"))), 0L, info = r)
  }
  expect_identical(cwq("Each of the 3 sites fell.")$text, "fell")
})

test_that("CW1: a project can put a dropped word back with claim_words add, and it is a hit in any sentence", {
  for (w in c("each", "both", "either", "whole")) {
    x <- cwq(sprintf("The %s site was wet.", w), weft_yml = c("claim_words:", sprintf("  add: [%s]", w)))
    expect_identical(x$text, w, info = w)
  }
})

# ---- CW2: the shipped idiom list --------------------------------------------------------------------

test_that("CW2: the shipped lexicon file has a top-level list idioms, lower case, with the 26 phrases", {
  y <- yaml::read_yaml(system.file("weft-claim-words.yml", package = "weft"))
  expect_true("idioms" %in% names(y))
  expect_setequal(unlist(y$idioms), CWQ_IDIOMS)
  expect_length(unlist(y$idioms), 26L)
  expect_identical(unlist(y$idioms), tolower(unlist(y$idioms)))
  # the idioms are not claim words
  expect_length(weft:::claim_lexicon(weft:::default_config(), "en"), 65L)
})

test_that("CW2: a lexicon word inside a shipped idiom is not a hit", {
  # a digit is in the sentence, so a quantifier of an idiom would be a hit under the default setting
  for (p in CWQ_IDIOMS) {
    x <- cwq(sprintf("The 3 sites, %s, were wet.", p))
    expect_identical(nrow(x), 0L, info = p)
  }
  expect_identical(nrow(cwq("At least 3 sites were wet.")), 0L)
  expect_identical(nrow(cwq("At most 3 sites were wet.")), 0L)
  expect_identical(nrow(cwq("The 3 sites were not only wet.")), 0L)
})

test_that("CW2: a word outside an idiom is still a hit (the near miss)", {
  expect_identical(cwq("The 3 sites were most wet.")$text, "most")
  expect_identical(cwq("The 3 sites had the least rain.")$text, "least")
  expect_identical(cwq("The 3 sites were at most wet and the lowest.")$text, "lowest")
  expect_identical(cwq("The lower value rose at the 3 sites.")$text, "lower, rose")
  expect_identical(cwq("The 3 sites had the best fit.")$text, "best")
  expect_identical(cwq("The 3 sites had no rain.")$text, "no")
  expect_identical(cwq("The 3 sites were significant.")$text, "significant")
})

test_that("CW2: an idiom does not hide another hit in the same sentence", {
  x <- cwq("The largest of the 3 sites was at least wet.")
  expect_identical(x$text, "largest")
  x <- cwq("The 3 sites rose, and most likely fell.")
  expect_identical(x$text, "rose, fell")
})

test_that("CW2: matching ignores case", {
  expect_identical(nrow(cwq("Most likely the 3 sites were wet.")), 0L)
  expect_identical(nrow(cwq("MOST LIKELY the 3 sites were wet.")), 0L)
  expect_identical(nrow(cwq("No longer were the 3 sites wet.")), 0L)
  expect_identical(nrow(cwq("NO LONGER were the 3 sites wet.")), 0L)
  expect_identical(nrow(cwq("The 3 sites were wet, at Least in part.")), 0L)
})

test_that("CW2: any run of white space, a line break included, is one space", {
  expect_identical(nrow(cwq(c("The 3 sites were wet, at", "least in part."))), 0L)
  expect_identical(nrow(cwq(c("Most", "likely 3 sites were wet."))), 0L)
  expect_identical(nrow(cwq("The 3 sites were wet, at   least in part.")), 0L)
  expect_identical(nrow(cwq("The 3 sites were wet, at\tleast in part.")), 0L)
  expect_identical(nrow(cwq(c("The 3 sites were wet, at the", "very least."))), 0L)
})

test_that("CW2: an idiom must start and end at word boundaries", {
  # "at least" starts inside "cat", so "least" is a hit
  expect_identical(cwq("The 3 sites were wet, cat least in part.")$text, "least")
  # "most likely" ends inside "likelyhood", so "most" is a hit
  expect_identical(cwq("The 3 sites were most likelyhood wet.")$text, "most")
})

# ---- CW3: project idioms -----------------------------------------------------------------------------

test_that("CW3: default_config() shows claim_words idioms, empty", {
  d <- weft:::default_config()
  expect_true("idioms" %in% names(d$claim_words))
  expect_length(d$claim_words$idioms, 0L)
  expect_length(d$claim_words$add, 0L)
  expect_length(d$claim_words$drop, 0L)
})

test_that("CW3: a project idiom from _weft.yml silences a lexicon word inside it; matching ignores case", {
  yml <- c("claim_words:", "  idioms: [\"highest point\"]")
  expect_identical(cwq("The highest point was wet.")$text, "highest")
  expect_identical(nrow(cwq("The highest point was wet.", weft_yml = yml)), 0L)
  expect_identical(nrow(cwq("Highest point was wet.", weft_yml = yml)), 0L)
  expect_identical(nrow(cwq(c("The highest", "point was wet."), weft_yml = yml)), 0L)
  yml2 <- c("claim_words:", "  idioms: [\"HIGHEST Point\"]")
  expect_identical(nrow(cwq("The highest point was wet.", weft_yml = yml2)), 0L)
  # the near miss: the word alone is still a hit
  expect_identical(cwq("The highest site was wet.", weft_yml = yml)$text, "highest")
})

test_that("CW3: project idioms are added to the shipped ones, not instead of them", {
  yml <- c("claim_words: {add: [], drop: [], idioms: [\"highest point\"]}")
  expect_identical(nrow(cwq("At least 3 sites were wet.", weft_yml = yml)), 0L)
  expect_identical(nrow(cwq("The highest point was wet.", weft_yml = yml)), 0L)
})

test_that("CW3: idioms in the front matter weft: block are honoured", {
  doc <- c("---", "title: T", "weft:", "  claim_words:", "    idioms: [\"highest point\"]", "---", "",
           "The highest point was wet.")
  for (e in c("qmd", "Rmd")) expect_identical(nrow(cwq(doc, ext = e)), 0L)
})

test_that("CW3: idioms that are not a list of strings is the 5.5.4 config error, from _weft.yml and front matter", {
  for (y in c("claim_words: {add: [], drop: [], idioms: 5}", "claim_words: {idioms: {a: b}}",
              "claim_words: {idioms: [[a, b]]}", "claim_words: {idioms: [5]}")) {
    e <- cwq_err_yml(y)
    expect_true(inherits(e, "weft_config_error"), label = y)
    expect_true(grepl("claim_words", f2_msg(e), fixed = TRUE), label = y)
    expect_true(grepl("(rule 5.5.4)", f2_msg(e), fixed = TRUE), label = y)
  }
  e <- cwq_err_front("claim_words: {idioms: 5}")
  expect_true(inherits(e, "weft_config_error"))
  expect_true(grepl("(rule 5.5.4)", f2_msg(e), fixed = TRUE))
})

test_that("CW3: valid idioms values are accepted", {
  for (y in c("claim_words: {add: [], drop: [], idioms: []}", "claim_words: {idioms: [\"a b\", c]}",
              "claim_words: {add: [x], idioms: [\"highest point\"]}")) {
    root <- lint_proj(list("a.qmd" = "Plain."), weft_yml = y)
    expect_no_error(lints(root))
  }
})

# ---- CW4: a hyphen next to the word ---------------------------------------------------------------

test_that("CW4: a hyphen directly after or before the word is no hit, whatever the class", {
  expect_identical(nrow(cwq("The best-supported site was wet.")), 0L)
  expect_identical(nrow(cwq("The sub-largest site was wet.")), 0L)
  expect_identical(nrow(cwq("The all-time site was wet.", weft_yml = qs("any"))), 0L)
  expect_identical(nrow(cwq("The 3 sites were all-weather.")), 0L)
  expect_identical(nrow(cwq("The rose-coloured site was wet.")), 0L)
  expect_identical(nrow(cwq("The 3 sites had whole-record data and a most-used road.")), 0L)
})

test_that("CW4: U+2010 and U+2011 are hyphens too", {
  for (h in c("‐", "‑")) {
    expect_identical(nrow(cwq(paste0("The best", h, "supported site was wet."))), 0L, info = h)
    expect_identical(nrow(cwq(paste0("The sub", h, "largest site was wet."))), 0L, info = h)
    expect_identical(nrow(cwq(paste0("The rose", h, "coloured site was wet."))), 0L, info = h)
  }
})

test_that("CW4: only a hyphen directly beside the word counts (the near miss)", {
  expect_identical(cwq("The best - and the worst - sites were wet.")$text, "best, worst")
  expect_identical(cwq("The best–supported site was wet.")$text, "best")
  expect_identical(cwq("The best—supported site was wet.")$text, "best")
  expect_identical(cwq("The best, supported site was wet.")$text, "best")
  # another word of the sentence is judged by its own neighbours
  expect_identical(cwq("The best-supported and largest site was wet.")$text, "largest")
})

# ---- CW5: a capital that is not the first word -------------------------------------------------------

test_that("CW5: a hit with a capital that is not the first word of its sentence is no hit", {
  expect_identical(nrow(cwq("The track at Wentworth Falls was wet.")), 0L)
  expect_identical(nrow(cwq("The site was Largest.")), 0L)
  expect_identical(nrow(cwq("The sites had FALLS recorded.")), 0L)
  expect_identical(nrow(cwq("The 3 sites were wet at LOWEST.")), 0L)
  expect_identical(nrow(cwq("The 3 sites were wet, said Every Man.")), 0L)
})

test_that("CW5: the first word of a sentence is still a hit when capitalised, or in all capitals", {
  expect_identical(cwq("Falls were wet.")$text, "falls")
  expect_identical(cwq("FALLS were wet.")$text, "falls")
  expect_identical(cwq("Sites were counted. Falls were measured.")$text, "falls")
  expect_identical(cwq("Largest 3 sites were wet.")$text, "largest")
  expect_identical(cwq("Every 3 sites were wet.")$text, "every")
})

test_that("CW5: the first word is the first run of letters, so a quote, bracket or digit before it does not move it", {
  expect_identical(cwq("\"Falls were wet,\" he said.")$text, "falls")
  expect_identical(cwq("(Falls were wet.)")$text, "falls")
  expect_identical(cwq("3 Falls were wet.")$text, "falls")
  expect_identical(nrow(cwq("\"The Falls were wet,\" he said.")), 0L)
})

test_that("CW5: a lower-case hit mid-sentence is still a hit", {
  expect_identical(cwq("The track at the falls was wet.")$text, "falls")
  expect_identical(cwq("The Wentworth site rose.")$text, "rose")
})

# ---- CW6: claim_quantifiers --------------------------------------------------------------------------

test_that("CW6: the default is number: a quantifier with no value and no digit in its sentence is no hit", {
  expect_identical(nrow(cwq("All sites were wet.")), 0L)
  expect_identical(nrow(cwq("Every site was wet. Nothing was dry.")), 0L)
  expect_identical(nrow(cwq("All sites were wet.", weft_yml = qs("number"))), 0L)
  expect_identical(nrow(cwq("Rain was always heavy and never light.")), 0L)
})

test_that("CW6: number: a weft value, bare value, named value, n, sign or list in the sentence lets a quantifier count", {
  rows <- c("All `r n` sites were wet.", "All `r n`{.num} sites were wet.", "All `n`{.num} sites were wet.",
            "All [site | sites]{n=\"k\"} were wet.", "All [x | y]{list=\"ks\"} were wet.",
            "All sites [rose | fell]{sign=\"d\"} again.")
  for (r in rows) {
    x <- cwq(r)
    expect_identical(nrow(x), 1L, info = r)
    expect_identical(x$text, "all", info = r)
  }
})

test_that("CW6: number: a typed digit in the sentence lets a quantifier count", {
  expect_identical(cwq("All 3 sites were wet.")$text, "all")
  expect_identical(cwq("All sites were wet in 2020.")$text, "all")
  expect_identical(cwq("Every site was wet at stn 7, never dry.")$text, "every, never")
  expect_identical(cwq("All sites were wet [part 2](x.html).")$text, "all")
})

test_that("CW6: number: a digit only inside a code span, a link target or a citation key does not count", {
  rows <- c("All sites in `x3` were wet.", "All sites were wet, see [here](page2.html).",
            "All sites were wet [@smith2020].", "All sites were wet, see https://example.org/a1.")
  for (r in rows) expect_identical(nrow(cwq(r)), 0L, info = r)
})

test_that("CW6: number: a value or digit in another sentence does not count", {
  expect_identical(nrow(cwq("There were 3 sites. All were wet.")), 0L)
  expect_identical(nrow(cwq("`r n` sites were visited. All were wet.")), 0L)
  x <- cwq("There were 3 sites. All 3 were wet.")
  expect_identical(x$text, "all")
  expect_identical(x$sentence, "All 3 were wet.")
})

test_that("CW6: extremum and direction words are hits in any sentence under number, any and none", {
  for (v in c("number", "any", "none")) {
    expect_identical(cwq("The largest site was wet.", weft_yml = qs(v))$text, "largest", info = v)
    expect_identical(cwq("The sites rose.", weft_yml = qs(v))$text, "rose", info = v)
    expect_identical(cwq("The largest 3 sites rose.", weft_yml = qs(v))$text, "largest, rose", info = v)
  }
})

test_that("CW6: any: a quantifier is a hit in any sentence", {
  x <- cwq("All sites were wet.", weft_yml = qs("any"))
  expect_identical(x$text, "all")
  expect_match(x$message, "with no value", fixed = TRUE)
  expect_identical(cwq("Rain was always heavy.", weft_yml = qs("any"))$text, "always")
  expect_identical(cwq("All sites rose.", weft_yml = qs("any"))$text, "all, rose")
  expect_identical(cwq("All 3 sites were wet.", weft_yml = qs("any"))$text, "all")
})

test_that("CW6: any still applies CW1, CW2, CW4 and CW5", {
  expect_identical(nrow(cwq("Each site was wet.", weft_yml = qs("any"))), 0L)
  expect_identical(nrow(cwq("The site was no longer wet.", weft_yml = qs("any"))), 0L)
  expect_identical(nrow(cwq("The all-weather site was wet.", weft_yml = qs("any"))), 0L)
  expect_identical(nrow(cwq("The site at Every Point was wet.", weft_yml = qs("any"))), 0L)
})

test_that("CW6: none: a quantifier is never a hit, with or without a number", {
  expect_identical(nrow(cwq("All sites were wet.", weft_yml = qs("none"))), 0L)
  expect_identical(nrow(cwq("All 3 sites were wet.", weft_yml = qs("none"))), 0L)
  expect_identical(nrow(cwq("All `r n` sites were wet.", weft_yml = qs("none"))), 0L)
  expect_identical(cwq("All `r n` sites rose.", weft_yml = qs("none"))$text, "rose")
})

test_that("CW6: a word added by claim_words add is a hit in any sentence, whatever list it sat in", {
  yml <- c("claim_words:", "  add: [all, ratio]")
  expect_identical(cwq("All sites were wet.", weft_yml = yml)$text, "all")
  expect_identical(cwq("The ratio was clear.", weft_yml = yml)$text, "ratio")
  yml2 <- c(yml, qs("none"))
  expect_identical(cwq("All sites were wet.", weft_yml = yml2)$text, "all")
  # without the add, the sentence is quiet
  expect_identical(nrow(cwq("All sites were wet.")), 0L)
})

test_that("CW6: claim_quantifiers can be set in the front matter weft: block", {
  doc <- c("---", "title: T", "weft:", "  claim_quantifiers: any", "---", "", "All sites were wet.")
  for (e in c("qmd", "Rmd")) expect_identical(cwq(doc, ext = e)$text, "all")
})

test_that("CW6: default_config() has claim_quantifiers number", {
  expect_identical(weft:::default_config()$claim_quantifiers, "number")
})

test_that("CW6: another value of claim_quantifiers is a config error naming number, any, none and rule 5.5.5", {
  for (y in c("claim_quantifiers: sometimes", "claim_quantifiers: true", "claim_quantifiers: [any]",
              "claim_quantifiers: 3")) {
    e <- cwq_err_yml(y)
    expect_true(inherits(e, "weft_config_error"), label = y)
    m <- f2_msg(e)
    expect_true(grepl("claim_quantifiers", m, fixed = TRUE), label = y)
    for (w in c("number", "any", "none", "5.5.5")) expect_true(grepl(w, m, fixed = TRUE), label = paste(y, w))
  }
  e <- cwq_err_front("claim_quantifiers: sometimes")
  expect_true(inherits(e, "weft_config_error"))
  expect_true(grepl("5.5.5", f2_msg(e), fixed = TRUE))
})

test_that("CW6: the three valid values are accepted", {
  for (v in c("number", "any", "none")) {
    root <- lint_proj(list("a.qmd" = "Plain."), weft_yml = qs(v))
    expect_no_error(lints(root))
  }
})

# ---- CW7: order of the tests, one finding listing the remaining words -------------------------------

test_that("CW7: a quantifier with no number plus a direction word is one finding listing only the direction word", {
  x <- cwq("All sites rose.")
  expect_identical(nrow(x), 1L)
  expect_identical(x$text, "rose")
  expect_identical(x$sentence, "All sites rose.")
  expect_identical(x$col, 11L)
  expect_false(grepl("\"all\"", x$message, fixed = TRUE))
  expect_match(x$message, "Claim word \"rose\" in a sentence with no value", fixed = TRUE)
})

test_that("CW7: a sentence whose only hits are removed gives nothing; its neighbour still gives its finding", {
  x <- cwq("All sites were wet. The largest site fell.")
  expect_identical(nrow(x), 1L)
  expect_identical(x$text, "largest, fell")
})

test_that("CW7: an idiom removes its word, and the others of the sentence remain as one finding", {
  x <- cwq("Not only did 3 sites rise, no longer were they wet.")
  expect_identical(nrow(x), 1L)
  expect_identical(x$text, "rise")
})

test_that("CW7: a guard still silences first, and the number test sees the rest of the sentence", {
  x <- cwq("[All]{if=\"all(up)\"} 3 sites rose.")
  expect_identical(x$text, "rose")
  x <- cwq("All sites [rose | fell]{sign=\"d\"} again.")
  expect_identical(x$text, "all")
})

# ---- CW8: messages and the rest unchanged ---------------------------------------------------------

test_that("CW8: the message, rule, spec, tier and level are unchanged", {
  x <- cwq("All `r n` sites were wet.")
  expect_identical(x$rule, "claim-word")
  expect_identical(x$spec, "5.5.1")
  expect_identical(x$tier, 2L)
  expect_identical(x$message,
    paste0("Claim word \"all\" in a sentence with a value; check that the value still bears it out, ",
           "or guard the word with an `if` span (rule 5.5.1)."))
  x <- cwq("The largest site rose.")
  expect_identical(x$message,
    paste0("Claim words \"largest\", \"rose\" in a sentence with no value: if it states a result, ",
           "compute it (rule 5.5.1)."))
  x <- cwq("All sites rose.")
  expect_identical(x$message,
    "Claim word \"rose\" in a sentence with no value: if it states a result, compute it (rule 5.5.1).")
})

test_that("CW8: claim_cap still limits changes(), not lints()", {
  doc <- c("All sites rose.", "", "All sites fell.", "", "All sites dropped.")
  expect_identical(nrow(cwq(doc, weft_yml = "claim_cap: 1")), 3L)
})

# ---- CW9: blockquote markers --------------------------------------------------------------------

test_that("CW9: the reported sentence of a finding in a blockquote has no > marker", {
  x <- cwq(c("Intro words.", "", "> The largest site rose."))
  expect_identical(x$sentence, "The largest site rose.")
  expect_identical(x$line, 3L)
  x <- cwq(c("Intro words.", "", ">The largest site rose."))
  expect_identical(x$sentence, "The largest site rose.")
})

test_that("CW9: a multi-line blockquote sentence has the markers of every line removed", {
  x <- cwq(c("Intro words.", "", "> The largest site", "> rose by a lot."))
  expect_identical(x$sentence, "The largest site rose by a lot.")
  expect_identical(x$line, 3L)
  expect_identical(x$end_line, 4L)
  x <- cwq(c("Intro words.", "", "> All `r n` sites", "> rose", "> again."))
  expect_identical(x$sentence, "All `r n` sites rose again.")
  expect_identical(x$end_line, 5L)
})

test_that("CW9: nested blockquote markers are all removed", {
  x <- cwq(c("Intro words.", "", "> > The largest site", "> > rose by a lot."))
  expect_identical(x$sentence, "The largest site rose by a lot.")
  x <- cwq(c("Intro words.", "", "> The largest site", "> > rose by a lot."))
  expect_identical(x$sentence, "The largest site rose by a lot.")
  x <- cwq(c("Intro words.", "", "> > > The largest site rose."))
  expect_identical(x$sentence, "The largest site rose.")
})

test_that("CW9: only a line's leading markers go; a > inside the text stays", {
  x <- cwq(c("Intro words.", "", "> The largest site rose, and a > b."))
  expect_identical(x$sentence, "The largest site rose, and a > b.")
})

test_that("CW9: a sentence outside a blockquote is unchanged", {
  x <- cwq(c("Intro words.", "", "The largest site rose."))
  expect_identical(x$sentence, "The largest site rose.")
})

# ---- CW10: the last sentence of a list item ends at the item ---------------------------------------

test_that("CW10: an ordered list item whose last sentence wraps does not run into the next marker", {
  lines <- c("Intro words.", "", "1. First wet item", "2. The largest site", "   rose again", "3. Wet items here")
  x <- cwq(lines)
  expect_identical(nrow(x), 1L)
  expect_identical(x$sentence, "The largest site rose again")
  expect_identical(x$line, 4L)
  expect_identical(x$end_line, 5L)
})

test_that("CW10: an ordered list item with a single line, and ends in a full stop, is unchanged", {
  x <- cwq(c("Intro words.", "", "1. First wet item", "2. The largest site rose", "3. Wet items here"))
  expect_identical(x$sentence, "The largest site rose")
  expect_identical(x$end_line, 4L)
  x <- cwq(c("Intro words.", "", "1. First wet item.", "2. The largest site rose.", "3. Wet items here."))
  expect_identical(x$sentence, "The largest site rose.")
  expect_identical(x$end_line, 4L)
})

test_that("CW10: a wrapped item before a two-digit marker", {
  lines <- c("Intro words.", "", "9. The largest site", "   rose again", "10. Wet items here")
  x <- cwq(lines)
  expect_identical(x$sentence, "The largest site rose again")
  expect_identical(x$end_line, 4L)
})

test_that("CW10: bullet items, with each of - * +, end at the item", {
  for (m in c("-", "*", "+")) {
    lines <- c("Intro words.", "", paste(m, "First wet item"), paste(m, "The largest site"),
               "  rose again", paste(m, "Wet items here"))
    x <- cwq(lines)
    expect_identical(nrow(x), 1L, info = m)
    expect_identical(x$sentence, "The largest site rose again", info = m)
    expect_identical(x$end_line, 5L, info = m)
  }
})

test_that("CW10: a nested list item ends at the item, before the next nested or outer marker", {
  lines <- c("Intro words.", "", "- First wet item", "  - The largest site", "    rose again", "  - Wet nested",
             "- Wet outer")
  x <- cwq(lines)
  expect_identical(x$sentence, "The largest site rose again")
  expect_identical(x$end_line, 5L)
  lines <- c("Intro words.", "", "1. First wet item", "   - The largest site", "     rose again", "2. Wet outer")
  x <- cwq(lines)
  expect_identical(x$sentence, "The largest site rose again")
  expect_identical(x$end_line, 5L)
  # an outer item, last before a nested marker
  lines <- c("Intro words.", "", "- The largest site", "  rose again", "  - Wet nested")
  x <- cwq(lines)
  expect_identical(x$sentence, "The largest site rose again")
  expect_identical(x$end_line, 4L)
})

test_that("CW10: a lettered item (a) does not hold the next marker, single line or wrapped", {
  x <- cwq(c("Intro words.", "", "(a) The largest site rose", "(b) Wet items here"))
  expect_identical(x$sentence, "The largest site rose")
  expect_identical(x$end_line, 3L)
  x <- cwq(c("Intro words.", "", "(a) The largest site", "    rose again", "(b) Wet items here"))
  expect_identical(x$sentence, "The largest site rose again")
  expect_identical(x$end_line, 4L)
})

test_that("CW10: an item with two sentences, the last one ends at the item", {
  lines <- c("Intro words.", "", "1. Wet. The largest site", "   rose again", "2. Wet items here")
  x <- cwq(lines)
  expect_identical(x$sentence, "The largest site rose again")
  expect_identical(x$end_line, 4L)
})

test_that("CW10: the last item of a list, followed by a paragraph, ends at the item", {
  lines <- c("Intro words.", "", "1. First wet item", "2. The largest site", "   rose again", "", "Wet words.")
  x <- cwq(lines)
  expect_identical(x$sentence, "The largest site rose again")
  expect_identical(x$end_line, 5L)
})
