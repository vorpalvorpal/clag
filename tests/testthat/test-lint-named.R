# Package 6d: the lints for named values and for spans the filter resolves (rules N7 to N13, N17, N141 to N145 of
# dev/design-6.md; messages E1 to E6, E9, E70 to E72 of section 7). Static: no Pandoc, Python or Julia is needed.
# Helpers: helper-6d.R, helper-3.R (lint_one, lint_fixture, lf_by_rule), helper-3d.R (expect_none).
#
# READINGS of the note (see the report):
#  - construct errors come out of the `construct` lint as the scanner's message verbatim, with the spec
#    of the first "rule x.y.z" in it and the construct as written for `text` (L17 of design-3);
#  - a document on the jupyter engine is written `engine: jupyter` in its front matter (the julia engine
#    `engine: julia`); under it every construct is the filter's (N14);
#  - for `named-unpublished` only the line of the finding is pinned (the construct's line), not its column
#    or `text`; the tests use each name once, so the note's silence on one finding or many does not matter.

con6d <- function(body, name = "a.qmd", front = "engine: jupyter") {
  lines <- if (is.null(front)) c("Intro.", "", body) else w6d_doc(c("Intro.", "", body), front = front)
  w6d_find(lines, "construct", name = name)
}
# the same sentence as a knitr document (an .Rmd) and as a jupyter one
con6d_both <- function(src) list(jupyter = con6d(src), Rmd = con6d(src, name = "a.Rmd", front = NULL))

expect_one_construct <- function(x, message, spec, text = NULL, label = NULL) {
  expect_identical(nrow(x), 1L, label = label)
  if (nrow(x) != 1L) return(invisible())
  expect_identical(x$rule, "construct", label = label)
  expect_identical(x$tier, 1L, label = label)
  expect_identical(x$message, message, label = label)
  expect_identical(x$spec, spec, label = label)
  if (!is.null(text)) expect_identical(x$text, text, label = label)
}

# ---- the registry --------------------------------------------------------------------------------------------

test_that("N144, N145: lint_rules() lists named-unpublished (5.12.1, tier 2) and publish-hidden (5.12.2, tier 1), both per file", {
  lr <- lint_rules()
  want <- list(`named-unpublished` = c("5.12.1", 2L), `publish-hidden` = c("5.12.2", 1L))
  for (id in names(want)) {
    expect_identical(sum(lr$id == id), 1L, label = id)
    expect_identical(lr$spec[lr$id == id], want[[id]][[1]], label = paste("spec of", id))
    expect_identical(lr$tier[lr$id == id], as.integer(want[[id]][[2]]), label = paste("tier of", id))
    expect_identical(lr$scope[lr$id == id], "file", label = paste("scope of", id))
  }
  # control: an existing rule is still listed
  expect_identical(sum(lr$id == "construct"), 1L)
})

# ---- N7, E1: a weft class on a code span whose text is not a NAME -------------------------------------------

E1_TEXTS <- c("x + 1", "cfg.depth[1]", "{python} x", "TRUE", "FALSE", "True", "False", "true", "false", "NA",
              "NULL", "None", "nothing", "missing", "Inf", "NaN", "1a", "x.", "a-b", "dépth",
              paste0("a", strrep("b", 64)))

test_that("N7, E1: a text that is not a NAME, with a weft class, is a construct error quoting it, in both kinds of document", {
  for (tx in E1_TEXTS) {
    src <- sprintf("Words `%s`{.num} more.", tx)
    cs <- con6d_both(src)
    for (kind in names(cs)) {
      expect_one_construct(cs[[kind]], W6D_E1(tx), "1.12.3", text = sprintf("`%s`{.num}", tx),
                           label = paste(kind, tx))
    }
  }
})

test_that("N7, E1: a renderer key or another class makes the span a construct as well; a class that is not weft's does not", {
  expect_one_construct(con6d("Words `x + 1`{digits=\"2\"} more."), W6D_E1("x + 1"), "1.12.3")
  expect_one_construct(con6d("Words `x + 1`{.val} more."), W6D_E1("x + 1"), "1.12.3")
  expect_one_construct(con6d("Words `x + 1`{.and} more."), W6D_E1("x + 1"), "1.12.3")
  expect_identical(nrow(con6d("Words `x + 1`{.python} more.")), 0L)
  expect_identical(nrow(con6d("Words `x + 1`{#d} more.")), 0L)
  expect_identical(nrow(con6d("Words `x + 1` more.")), 0L)
})

test_that("N7: a code span that starts r , R  or {r} is an R value, not E1; a name is no finding", {
  expect_identical(nrow(con6d("Words `r x`{.num} more.", name = "a.Rmd", front = NULL)), 0L)
  expect_identical(nrow(con6d("Words `R x`{.num} more.", name = "a.Rmd", front = NULL)), 0L)
  expect_identical(nrow(con6d("Words `{r} x`{.num} more.", name = "a.Rmd", front = NULL)), 0L)
  for (nm in c("depth", "n.sites", "_x", "a1")) {
    cs <- con6d_both(sprintf("Words `%s`{.num} more.", nm))
    for (kind in names(cs)) expect_identical(nrow(cs[[kind]]), 0L, label = paste(kind, nm))
  }
})

test_that("N7: a name of 64 characters is fine, and a reserved word is not a name even in the middle of a longer word", {
  expect_identical(nrow(con6d(paste0("Words `a", strrep("b", 63), "`{.num} more."))), 0L)
  expect_identical(nrow(con6d("Words `TRUE_n`{.num} more.")), 0L)
  expect_identical(nrow(con6d("Words `NAs`{.num} more.")), 0L)
})

# ---- N8, E2: .val and a wording class ------------------------------------------------------------------------

test_that("N8, E2: .val with a wording class is a construct error naming the class; .val alone and with a collapse class is not", {
  for (cls in c("word", "count", "ord")) {
    src <- sprintf("Words `depth`{.val .%s} more.", cls)
    cs <- con6d_both(src)
    for (kind in names(cs)) {
      expect_one_construct(cs[[kind]], W6D_E2(cls), "1.12.2", text = sprintf("`depth`{.val .%s}", cls),
                           label = paste(kind, cls))
    }
  }
  expect_identical(nrow(con6d("Words `depth`{.val} more.")), 0L)
  expect_identical(nrow(con6d("Words `sites`{.val .and} more.")), 0L)
  expect_identical(nrow(con6d("Words `sites`{.val .or} more.")), 0L)
})

test_that("N8: .val with a number class is the 1.4.2 error (one class per group)", {
  x <- con6d("Words `depth`{.val .num} more.")
  expect_gte(nrow(x), 1L)
  expect_true("1.4.2" %in% x$spec)
})

# ---- N17, E9: the other syntax rules, unchanged ---------------------------------------------------------------

test_that("N17, E9: a governor key on a named value is a construct error naming the key", {
  for (key in c("if", "n", "sign", "list")) {
    src <- sprintf("Words `depth`{.num %s=\"k\"} more.", key)
    cs <- con6d_both(src)
    for (kind in names(cs)) {
      expect_one_construct(cs[[kind]], W6D_E9(key), "1.3.3", text = sprintf("`depth`{.num %s=\"k\"}", key),
                           label = paste(kind, key))
    }
  }
})

test_that("N17: digits with sigfig, two classes of one group and a key written twice are the errors the R values give", {
  cases <- list(
    list("`depth`{.num digits=\"2\" sigfig=\"3\"}", "`digits` with `sigfig` is an error (rule 1.4.7).", "1.4.7"),
    list("`depth`{.num .pct}", "Two classes from one group in one block: .num .pct (rule 1.4.2).", "1.4.2"),
    list("`depth`{.num foo=\"a\" foo=\"b\"}", "The key `foo` is written twice in one block (rule 1.2.10).", "1.2.10")
  )
  for (cs in cases) {
    r <- con6d_both(paste("Words", cs[[1]], "more."))
    for (kind in names(r)) expect_one_construct(r[[kind]], cs[[2]], cs[[3]], text = cs[[1]], label = paste(kind, cs[[1]]))
  }
})

test_that("N17: a named value may carry other classes and keys (pass-through); the controls give no construct finding", {
  expect_identical(nrow(con6d("Words `depth`{.num .smallcaps} more.")), 0L)
  expect_identical(nrow(con6d("Words `depth`{.num digits=\"2\"} more.")), 0L)
  expect_identical(nrow(con6d("Words `depth`{.num DIGITS=\"2\"} more.")), 0L)
})

# ---- N11, N12, E3 to E5: a span governor in a document the filter resolves --------------------------------------

E3_BAD <- c("a && b", "a || b", "a & b", "a | b", "a and b", "a or b", "not a", "(a)", "a + 1 > b",
            "len(x) > 2", "x[1] > 2", "0 < x < 1", "a = b", "a <> b", "x > NA", "x == NULL", "x == TRUE", "TRUE",
            "3", "x > +1", "x > .5", "x > 1_000", "x > 0x10", "x > 10L", "x > 1e")

test_that("N11, E3: a condition that is not a name or one comparison is a construct error quoting the part (jupyter document)", {
  for (cond in E3_BAD) {
    src <- sprintf("The level [rose | fell]{if=\"%s\"} again.", cond)
    expect_one_construct(con6d(src), W6D_E3(cond), "1.12.4", text = sprintf("[rose | fell]{if=\"%s\"}", cond),
                         label = cond)
  }
})

test_that("N10, N11, E3: with commas only the part that is wrong is quoted; a comma inside a string literal splits nothing", {
  expect_one_construct(con6d(r"{The level [rose | fell]{if="n > 10, a && b"} again.}"), W6D_E3("a && b"), "1.12.4")
  expect_one_construct(con6d(r"{The level [rose | fell]{if="a && b, n > 10"} again.}"), W6D_E3("a && b"), "1.12.4")
  expect_identical(nrow(con6d(r"{The level [rose | fell]{if="s == 'a,b', n > 1"} again.}")), 0L)
})

test_that("N10, E3: an empty part is a construct error (a,,b and a,)", {
  for (cond in c("a,,b", "a,")) {
    x <- con6d(sprintf("The level [rose | fell]{if=\"%s\"} again.", cond))
    expect_identical(nrow(x), 1L, label = cond)
    expect_true(endsWith(x$message, W6D_E3_TAIL), label = cond)
    expect_identical(x$spec, "1.12.4", label = cond)
  }
})

E4_BAD <- c("3 > 2", "'a' == 'a'", "1 == 1", "3>2", "'a' != 'b'")

test_that("N11, E4: a comparison of two literals is a construct error of its own", {
  for (cond in E4_BAD) {
    expect_one_construct(con6d(sprintf("The level [rose | fell]{if=\"%s\"} again.", cond)), W6D_E4(cond), "1.12.4",
                         label = cond)
  }
})

E3_GOOD <- c("ok", "n > 10", "n>10", "x <= -1.5e3", "s == 'north'", "'north' == s", "a != b", "n_gap > 10, n_sites >= 3",
             "s == 'a,b'", "0.5 < x", "n.sites >= 3", "a == b", "ok  ", "x >= 0", "!x", "!ok, n > 10")

test_that("N9: a name, or one comparison with a name in it, with optional spaces and commas between, is no finding", {
  for (cond in E3_GOOD) {
    x <- con6d(sprintf("The level [rose | fell]{if=\"%s\"} again.", cond))
    expect_identical(nrow(x), 0L, label = cond)
  }
})

test_that("N11 control: a knitr document's span takes an R expression, so the same condition is not a finding there", {
  for (cond in c("a && b", "len(x) > 2", "x[1] > 2")) {
    x <- con6d(sprintf("The level [rose | fell]{if=\"%s\"} again.", cond), name = "a.Rmd", front = NULL)
    expect_identical(nrow(x), 0L, label = cond)
  }
})

test_that("N12, E5: n takes a name, . or #id; anything else is a construct error quoting the value and the key", {
  for (v in c("3", "x + 1", "n()")) {
    src <- sprintf("We saw [a site | # sites]{n=\"%s\"} today.", v)
    expect_one_construct(con6d(src), W6D_E5(v, "n"), "1.12.6", label = v)
  }
  expect_identical(nrow(con6d(r"{We saw [a site | # sites]{n="k"} today.}")), 0L)
  expect_identical(nrow(con6d(r"{We saw [a site | # sites]{n="."} today.}")), 0L)
})

test_that("N12, E5: sign takes a name or #id, and list a name", {
  for (v in c("3", ".", "x + 1")) {
    expect_one_construct(con6d(sprintf("The level [rose | fell]{sign=\"%s\"} again.", v)), W6D_E5(v, "sign"),
                         "1.12.6", label = paste("sign", v))
  }
  for (v in c("3", ".", "#d", "x + 1")) {
    expect_one_construct(con6d(sprintf("[No sites were | # was | # were]{list=\"%s\"} flagged.", v)),
                         W6D_E5(v, "list"), "1.12.6", label = paste("list", v))
  }
  expect_identical(nrow(con6d(r"{The level [rose | fell]{sign="d"} again.}")), 0L)
  expect_identical(nrow(con6d(r"{[No sites were | # was | # were]{list="flagged"} flagged.}")), 0L)
})

test_that("N12 control: in a knitr document n=\"3\" is an R expression, not E5", {
  expect_identical(nrow(con6d(r"{We saw [a site | # sites]{n="3"} today.}", name = "a.Rmd", front = NULL)), 0L)
})

# ---- N13, E6: ids ---------------------------------------------------------------------------------------------

test_that("N13: an id on a named value is defined for the filter's spans of a jupyter document: no construct finding", {
  x <- con6d(c("The depth `depth`{#d .num} was measured.", "", r"{The level [rose | fell]{sign="#d"} again.}"))
  expect_identical(nrow(x), 0L)
  y <- con6d(c("The depth `depth`{#d .num} was measured.", "", r"{We saw [a site | # sites]{n="#d"} today.}"))
  expect_identical(nrow(y), 0L)
})

test_that("N13, E6: in a knitr document a span the hooks resolve cannot refer to an id on a named value", {
  x <- con6d(c("The depth `depth`{#d .num} was measured.", "", r"{The level [rose | fell]{sign="#d"} again.}"),
             name = "a.Rmd", front = NULL)
  expect_one_construct(x, W6D_E6("d"), "1.12.10")
})

# ---- N141: R's parser is not applied to names or to filter spans --------------------------------------------

test_that("N141: a NAME that is a word of R's grammar is a name; no R parse error is reported for a named value", {
  for (nm in c("if", "for", "function", "next", "repeat", "in", "while")) {
    cs <- con6d_both(sprintf("Words `%s`{.num} more.", nm))
    for (kind in names(cs)) expect_identical(nrow(cs[[kind]]), 0L, label = paste(kind, nm))
  }
})

test_that("N141: a governor of a filter span is judged by N9 and N12, not by R's parser", {
  expect_identical(nrow(con6d(r"{The level [rose | fell]{if="in"} again.}")), 0L)
  expect_identical(nrow(con6d(r"{The level [rose | fell]{if="n_a > 'x y'"} again.}")), 0L)
})

# ---- N142: the lints that apply unchanged --------------------------------------------------------------------

test_that("N142: claim-word treats a named value as a value", {
  x <- w6d_find(w6d_doc(c("Intro words.", "", "All `n`{.num} sites were wet.")), "claim-word")
  expect_identical(nrow(x), 1L)
  expect_identical(x$tier, 2L)
  expect_identical(x$text, "all")
  expect_identical(x$message,
                   paste0("Claim word \"all\" in a sentence with a value; check that the value still bears it out, ",
                          "or guard the word with an `if` span (rule 5.5.1)."))
})

test_that("N142: the name lint lists an unknown key on a named value, and knows .val", {
  x <- w6d_find(w6d_doc(c("Intro.", "", "Words `depth`{.num foo=\"a\"} more.")), "name")
  expect_identical(nrow(x), 1L)
  expect_identical(x$text, "foo")
  expect_identical(nrow(w6d_find(w6d_doc(c("Intro.", "", "Words `depth`{.val} and `sites`{.val .and}.")), "name")), 0L)
})

test_that("N142: if-zero reads the condition text of a span in a filter document", {
  x <- w6d_find(w6d_doc(c("Intro.", "", r"{The level [up | down]{if="d > 0"} again.}")), "if-zero")
  expect_identical(nrow(x), 1L)
  expect_identical(x$text, "d > 0")
  expect_identical(nrow(w6d_find(w6d_doc(c("Intro.", "", r"{The level [up | down]{if="d > 10"} again.}")), "if-zero")), 0L)
})

test_that("N142: a typed numeral beside a named value is still a numeral finding, and the value is not", {
  x <- w6d_find(w6d_doc(c("Intro.", "", "The `depth`{.num} metres was 12 at most.")), "numeral")
  expect_identical(x$text, "12")
})

# ---- N143: the lints that cannot occur ------------------------------------------------------------------------

test_that("N143: a name is not a literal, and a condition of two literals is E4, not an inert check", {
  doc <- w6d_doc(c("Intro.", "", "The `depth`{.num} and `sites`{.val} and [a | b]{if=\"3 > 2\"} here."))
  all <- lint_fixture(list("a.qmd" = doc), rules = NULL, tier = 1:2)
  expect_true(W6D_E4("3 > 2") %in% w6d_msgs(lf_by_rule(all, "construct")))
  for (rule in c("literal-value", "inert-check", "value-constant", "value-format")) {
    expect_identical(nrow(lf_by_rule(all, rule)), 0L, label = rule)
  }
})

# ---- N144: named-unpublished ------------------------------------------------------------------------------------

NU_BODY <- "The depth is `depth`{.num} metres."

nu <- function(body = NU_BODY, chunks = character(), front = "engine: jupyter", files = list(), name = "a.qmd",
               tier = 1:2, env = parent.frame()) {
  w6d_find(w6d_doc(body, chunks, front), "named-unpublished", name = name, files = files, tier = tier, env = env)
}

test_that("N144: a name used by a named value that no chunk mentions is one tier-2 finding with E70, at the value's line", {
  x <- nu()
  expect_identical(nrow(x), 1L)
  expect_identical(x$rule, "named-unpublished")
  expect_identical(x$tier, 2L)
  expect_identical(x$spec, "5.12.1")
  expect_identical(x$file, "a.qmd")
  expect_identical(x$line, 5L)
  expect_identical(x$message, W6D_E70("depth"))
})

test_that("N144: it is a tier-2 rule: tier 1 alone does not list it", {
  expect_identical(nrow(nu(tier = 1L)), 0L)
})

test_that("N144: a chunk of any language that mentions the name, as a whole-word token, silences it", {
  for (chunks in list(w6d_py("depth = 12"), w6d_jl("depth = 12"), w6d_r("weft_put(depth = 12)"),
                      w6d_py("put(depth=12)"), w6d_py("print(\"depth\")"), w6d_py("depth.x = 1"),
                      w6d_py(c("x = 1", "depth = 12")))) {
    expect_identical(nrow(nu(chunks = chunks)), 0L, label = paste(chunks, collapse = " | "))
  }
})

test_that("N144: a token that only contains the name does not count", {
  for (code in c("depth2 = 1", "my_depth = 1", "depth_x = 1", "xdepth = 1", "my.depth = 1", "d = 1")) {
    x <- nu(chunks = w6d_py(code))
    expect_identical(nrow(x), 1L, label = code)
    expect_identical(x$message, W6D_E70("depth"), label = code)
  }
})

test_that("N144: only executed chunks count: a mention in eval: false code, or in prose, does not", {
  expect_identical(nrow(nu(chunks = w6d_py("depth = 12", "eval: false"))), 1L)
  expect_identical(nrow(nu(body = c(NU_BODY, "", "We called the variable depth in the code."))), 1L)
})

test_that("N144: a key of a hand-written weft-values block of the document is a publication", {
  blk <- c("````{.weft-values}", "{\"weft\":1,\"values\":{\"depth\":{\"t\":\"float\",\"v\":\"3.14159\"}}}", "````")
  expect_identical(nrow(nu(body = c(NU_BODY, "", blk))), 0L)
  other <- c("````{.weft-values}", "{\"weft\":1,\"values\":{\"width\":{\"t\":\"float\",\"v\":\"3.14159\"}}}", "````")
  x <- nu(body = c(NU_BODY, "", other))
  expect_identical(nrow(x), 1L)
  expect_identical(x$message, W6D_E70("depth"))
})

test_that("N144: a key of a values file the document reads is a publication", {
  blk <- c("````{.weft-values file=\"vals.json\"}", "````")
  has <- list("vals.json" = "{\"weft\":1,\"values\":{\"depth\":{\"t\":\"float\",\"v\":\"1.5\"}}}")
  lacks <- list("vals.json" = "{\"weft\":1,\"values\":{\"width\":{\"t\":\"float\",\"v\":\"1.5\"}}}")
  expect_identical(nrow(nu(body = c(NU_BODY, "", blk), files = has)), 0L)
  expect_identical(nrow(nu(body = c(NU_BODY, "", blk), files = lacks)), 1L)
})

test_that("N144: a chunk of an included file counts", {
  inc <- list("_part.qmd" = w6d_py("depth = 12"))
  expect_identical(nrow(nu(body = c(NU_BODY, "", "{{< include _part.qmd >}}"), files = inc)), 0L)
  expect_identical(nrow(nu(body = c(NU_BODY, "", "{{< include _part.qmd >}}"),
                           files = list("_part.qmd" = w6d_py("width = 12")))), 1L)
})

test_that("N144: the names a filter span governs are names used, and string literals are not", {
  body <- c(NU_BODY, "", r"{The level [rose | fell]{if="ok, n_gap > 10, s == 'north'"} again.}")
  x <- nu(body = body, chunks = w6d_py("depth = 12"))
  expect_identical(sort(w6d_msgs(x)), sort(c(W6D_E70("ok"), W6D_E70("n_gap"), W6D_E70("s"))))
  y <- nu(body = body, chunks = w6d_py(c("depth = 12", "ok = True", "n_gap = 12", "s = 'x'")))
  expect_identical(nrow(y), 0L)
  z <- nu(body = c(NU_BODY, "", r"{We saw [a site | # sites]{n="k"} and [a | b | c]{sign="d"}.}"),
          chunks = w6d_py(c("depth = 12", "k = 3")))
  expect_identical(w6d_msgs(z), W6D_E70("d"))
})

test_that("N144: each unpublished name is a finding, at its own line", {
  x <- nu(body = c("The `depth`{.num} and `width`{.num}.", "", "Then `height`{.val}."),
          chunks = w6d_py("width = 1"))
  expect_identical(sort(w6d_msgs(x)), sort(c(W6D_E70("depth"), W6D_E70("height"))))
  expect_identical(x$line[match(W6D_E70("depth"), x$message)], 5L)
  expect_identical(x$line[match(W6D_E70("height"), x$message)], 7L)
})

test_that("N144: in a knitr document only named values are the filter's: a hooks span's names are not checked", {
  rmd <- function(body, chunks = character()) w6d_find(c(body, if (length(chunks)) c("", chunks)),
                                                       "named-unpublished", name = "a.Rmd")
  x <- rmd(NU_BODY)
  expect_identical(w6d_msgs(x), W6D_E70("depth"))
  expect_identical(nrow(rmd(NU_BODY, w6d_r("weft_put(depth = 12)"))), 0L)
  # control: a hooks span's governor name is not a name used by the filter
  y <- rmd(c(NU_BODY, "", r"{The level [rose | fell]{if="ok"} again.}"), w6d_r("weft_put(depth = 12)"))
  expect_identical(nrow(y), 0L)
})

test_that("N144 control: a document with no named value and no filter span has nothing to publish", {
  expect_identical(nrow(nu(body = "Plain words only.")), 0L)
})

# ---- N145: publish-hidden ----------------------------------------------------------------------------------------

ph <- function(code, opts, engine = "python", front = "engine: jupyter", body = "Words.") {
  chunk <- w6d_chunk(engine, code, c("label: setup", opts))
  w6d_find(w6d_doc(body, chunk, front), "publish-hidden")
}
ph_auto <- function(code, opts, engine = "python", front = "engine: jupyter") {
  w6d_find(w6d_doc("Words.", w6d_chunk(engine, code, c("label: setup", opts)), front), "publish-hidden-auto")
}

test_that("N145: a python chunk with include: false that calls put( is one tier-1 finding with E71", {
  x <- ph("put(n = 1)", "include: false")
  expect_identical(nrow(x), 1L)
  expect_identical(x$rule, "publish-hidden")
  expect_identical(x$tier, 1L)
  expect_identical(x$spec, "5.12.2")
  expect_identical(x$file, "a.qmd")
  expect_true(x$message %in% W6D_E71("setup", "include: false"))
})

test_that("N145: output: false is the other option, and is named in the message", {
  x <- ph("put(n = 1)", "output: false")
  expect_identical(nrow(x), 1L)
  expect_true(x$message %in% W6D_E71("setup", "output: false"))
})

test_that("N145: put(, weft.put( in Python and @put, Weft.put( in Julia are the calls", {
  for (code in c("put(n = 1)", "weft.put(n = 1)", "x = 1; put(n = x)", "    put(n=1)", "import weft\nweft.put(n=1)")) {
    expect_identical(nrow(ph(strsplit(code, "\n")[[1]], "include: false")), 1L, label = code)
  }
  for (code in c("@put n", "Weft.put(n = 1)", "    @put a b", "Weft.@put n")) {
    x <- ph(code, "include: false", engine = "julia", front = "engine: julia")
    expect_identical(nrow(x), 1L, label = code)
  }
})

test_that("N145: a comment line, a longer name, an attribute call and a name that merely ends in put do not count", {
  for (code in c("# put(n = 1)", "    # put(n = 1)", "my_put(n)", "q.put(1)", "output(1)", "input(1)", "puts(n)")) {
    expect_identical(nrow(ph(code, "include: false")), 0L, label = code)
  }
  for (code in c("# @put n", "@puts n", "my_put(n)")) {
    expect_identical(nrow(ph(code, "include: false", engine = "julia", front = "engine: julia")), 0L, label = code)
  }
})

test_that("N145: a chunk that shows its output, or is not executed, or only hides its code, is no finding", {
  expect_identical(nrow(ph("put(n = 1)", character())), 0L)
  expect_identical(nrow(ph("put(n = 1)", "echo: false")), 0L)
  expect_identical(nrow(ph("put(n = 1)", c("include: false", "eval: false"))), 0L)
  expect_identical(nrow(ph("put(n = 1)", "include: true")), 0L)
  expect_identical(nrow(ph("n = 1", "include: false")), 0L)
})

test_that("N145: a hidden chunk in a knitr document is harmless (D9): no finding", {
  expect_identical(nrow(ph("weft_put(n = 1)", "include: false", engine = "r", front = "engine: knitr")), 0L)
  expect_identical(nrow(ph("put(n = 1)", "include: false", engine = "python", front = "engine: knitr")), 0L)
})

test_that("N145: two hidden chunks are findings of their own labels", {
  chunks <- c(w6d_chunk("python", "put(a = 1)", c("label: one", "include: false")), "",
              w6d_chunk("python", "put(b = 1)", c("label: two", "output: false")))
  x <- w6d_find(w6d_doc("Words.", chunks), "publish-hidden")
  expect_identical(nrow(x), 2L)
  expect_true(any(x$message %in% W6D_E71("one", "include: false")))
  expect_true(any(x$message %in% W6D_E71("two", "output: false")))
})

test_that("N145: a hidden chunk that calls auto( is the tier-2 finding publish-hidden-auto with E72, not publish-hidden", {
  x <- ph_auto("auto()", "include: false")
  expect_identical(nrow(x), 1L)
  expect_identical(x$rule, "publish-hidden-auto")
  expect_identical(x$tier, 2L)
  expect_identical(x$spec, "5.12.2")
  expect_true(x$message %in% W6D_E72("setup", "include: false"))
  expect_identical(nrow(ph("auto()", "include: false")), 0L)
  y <- ph_auto("auto()", "output: false")
  expect_true(y$message %in% W6D_E72("setup", "output: false"))
  expect_identical(nrow(ph_auto("auto()", character())), 0L)
  expect_identical(nrow(w6d_find(w6d_doc("Words.", w6d_chunk("python", "auto()", c("label: setup", "include: false"))),
                                 "publish-hidden-auto", tier = 1L)), 0L)
})
