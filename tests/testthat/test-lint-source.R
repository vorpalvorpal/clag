# Package 3a: the source reader, through weft:::read_source() (L9-L12; contract: dev/design-3.md).
# The design names read_source(path, root, cfg) and source_sentences(src) as internal functions
# with a contract, so they are tested directly. Helpers: helper-3.R (read_src(), expect_prose()).
# Every token like zzabc is unique so a fragment can be found in the text by its first occurrence.

# ---- L9: the shape of a weft_source ---------------------------------------------------

test_that("3a L9: read_source() returns the documented fields", {
  src <- read_src(c("---", "title: T", "lang: de", "---", "", "Some prose."))
  for (nm in c("text", "file", "lines", "line_start", "lang", "ext", "rows", "prose",
               "regions", "blocks", "chunks", "meta")) {
    expect_true(nm %in% names(src), label = paste("field", nm))
  }
  expect_false(is.null(src_front(src)))
  expect_type(src$text, "character")
  expect_identical(src$file, "doc.qmd")
  expect_identical(sub("^\\.", "", src$ext), "qmd")
  expect_s3_class(src$rows, "data.frame")
  expect_s3_class(src$regions, "data.frame")
  expect_s3_class(src$blocks, "data.frame")
  expect_s3_class(src$chunks, "data.frame")
})

test_that("3a L9: text drops a BOM and makes CR LF into LF; lines and line_start follow", {
  for (variant in list(list(), list(eol = "\r\n"), list(bom = TRUE), list(bom = TRUE, eol = "\r\n"))) {
    src <- do.call(read_src, c(list(c("Alpha", "Beta gamma", "", "Delta")), variant))
    expect_identical(substr(src$text, 1, 5), "Alpha")
    expect_false(grepl("\r", src$text, fixed = TRUE))
    expect_identical(src$text, "Alpha\nBeta gamma\n\nDelta\n")
    expect_identical(src$lines[1:4], c("Alpha", "Beta gamma", "", "Delta"))
    expect_identical(as.integer(src$line_start[1:4]), c(1L, 7L, 18L, 19L))
  }
})

test_that("3a L9: a file with no final newline keeps its last line", {
  src <- read_src(c("Alpha", "Beta"), final_newline = FALSE)
  expect_identical(src$text, "Alpha\nBeta")
  expect_identical(src$lines[2], "Beta")
})

test_that("3a L9: lang is the front matter's, else _quarto.yml's, else NA", {
  expect_identical(read_src(c("---", "lang: de", "---", "", "x"))$lang, "de")
  expect_identical(read_src("x")$lang, NA_character_)
  s <- read_src("x", files = list("_quarto.yml" = c("project:", "  type: default", "lang: fr-CA")))
  expect_identical(s$lang, "fr-CA")
  s <- read_src(c("---", "lang: en-AU", "---", "", "x"), files = list("_quarto.yml" = "lang: fr"))
  expect_identical(s$lang, "en-AU")
})

test_that("3a L9: ext is the document's extension", {
  expect_identical(sub("^\\.", "", read_src("x", ext = "Rmd")$ext), "Rmd")
  expect_identical(sub("^\\.", "", read_src("x", ext = "rmd")$ext), "rmd")
})

test_that("3a L9: prose is as long as text and keeps every line break, with BOM and CRLF too", {
  doc <- c("---", "title: T", "---", "", "Some `code` and [1]{.weft-literal} here.", "",
           "```{r}", "x <- 1", "```", "", "End.")
  for (variant in list(list(), list(eol = "\r\n"), list(bom = TRUE))) {
    src <- do.call(read_src, c(list(doc), variant))
    expect_identical(nchar(src$prose), nchar(src$text))
    expect_identical(gregexpr("\n", src$prose, fixed = TRUE)[[1]], gregexpr("\n", src$text, fixed = TRUE)[[1]])
    expect_false(grepl("[^ \n]", substr(src$prose, 1, 3)))
  }
})

test_that("3a L9: non-ASCII text is read in characters, so offsets are in characters", {
  src <- read_src(c("Caf\u00e9 `r zzv`{.num} \u00e9t\u00e9."))
  expect_identical(src$text, "Caf\u00e9 `r zzv`{.num} \u00e9t\u00e9.\n")
  expect_identical(nchar(src$prose), nchar(src$text))
  expect_identical(src$prose, paste0("Caf\u00e9", strrep(" ", 15), "\u00e9t\u00e9.\n"))
})

# ---- L11: what is prose in the body ---------------------------------------------------------

test_that("3a L11: metadata blocks are not prose, except the fields of L10", {
  expect_prose(
    c("---", "title: Kept title words", "author: Zed Blankauthor", "keywords: [zzkey1, zzkey2]",
      "date: 2020-01-03", "---", "", "Body words."),
    blank = c("author: Zed Blankauthor", "keywords: [zzkey1, zzkey2]", "date: 2020-01-03"),
    kept = c("Kept title words", "Body words.")
  )
  expect_prose_lines(c("---", "title: Kept title words", "---", "", "Body."),
                     c("1" = "", "2" = "       Kept title words", "3" = "", "5" = "Body."))
})

test_that("3a L10: title, subtitle, abstract, description are prose in place, scalar or block scalar", {
  expect_prose(
    c("---", "title: \"Quoted zztitle words\"", "subtitle: 'Single zzsub words'",
      "description: Plain zzdesc words", "abstract: |", "  Block zzabs one.", "  Block zzabs two.",
      "other: zznotread", "---", "", "Body."),
    kept = c("Quoted zztitle words", "Single zzsub words", "Plain zzdesc words",
             "Block zzabs one.", "Block zzabs two."),
    blank = c("zznotread", "abstract: |")
  )
  expect_prose(
    c("---", "description: >", "  Folded zzfold one", "  folded zzfold two", "abstract: |-", "  Strip zzstrip", "---", "", "B."),
    kept = c("Folded zzfold one", "folded zzfold two", "Strip zzstrip")
  )
})

test_that("3a L10: the pieces are read in every metadata block, not only the first", {
  expect_prose(
    c("---", "title: First zzfirst", "---", "", "Body zzbody.", "", "---", "abstract: |",
      "  Late zzlate abstract.", "other: zzlateother", "---", "", "End."),
    kept = c("First zzfirst", "Late zzlate abstract.", "Body zzbody."),
    blank = c("zzlateother")
  )
})

test_that("3a L10: a front-matter piece sits at its file position (the late abstract is at its own line)", {
  doc <- c("---", "title: T", "---", rep(c("", "Filler words."), 40), "", "---", "abstract: |", "  Late 4 sites.", "---")
  src <- read_src(doc)
  p <- src_frag(src, "Late 4 sites.")
  ln <- length(gregexpr("\n", substr(src$text, 1, p$start), fixed = TRUE)[[1]]) + 1L
  expect_identical(ln, length(doc) - 1L)
  expect_identical(p$prose, "Late 4 sites.")
})

test_that("3a L11: fenced blocks are not prose, whatever their kind", {
  expect_prose(
    c("Lead words.", "", "```", "zzfence code", "```", "", "~~~", "zztilde code", "~~~", "",
      "```{=html}", "<div>zzraw</div>", "```", "", "```{r}", "zzchunk <- 1", "```", "",
      "```{r}", "#| eval: false", "zzoff <- 1", "```", "", "```r", "zzplain <- 1", "```", "", "Tail words."),
    blank = c("```\nzzfence code\n```", "~~~\nzztilde code\n~~~", "```{=html}\n<div>zzraw</div>\n```",
              "```{r}\nzzchunk <- 1\n```", "zzoff <- 1", "zzplain <- 1"),
    kept = c("Lead words.", "Tail words.")
  )
})

test_that("3a L11: indented code (4+ spaces after a blank line, not in a list item) is not prose; a list item's continuation is", {
  expect_prose(
    c("Lead words.", "", "    zzindented code", "", "- item words", "", "    zzcontinued para", "",
      "Tail words."),
    blank = c("zzindented code"),
    kept = c("zzcontinued para", "item words", "Tail words.")
  )
  # a list item lasts until a non-blank line at indentation 0 that follows a blank line
  expect_prose(
    c("- item words", "", "    zzcontinued one", "", "Dedented zzpara.", "", "    zzcode after"),
    kept = c("zzcontinued one", "Dedented zzpara."),
    blank = c("zzcode after")
  )
})

test_that("3a L11: HTML comments, script and style elements and HTML tags are not prose; the text between tags is", {
  expect_prose(
    c("Lead words <!-- zzcomment --> mid words.", "", "<!--", "zzmulti comment", "-->", "",
      "<script>zzscript()</script>", "", "<style>", ".zzstyle { color: red }", "</style>", "",
      "<span class=\"zzcls\">kept span text</span> and <br/> more words.", "", "<div>", "Div body words.", "</div>"),
    blank = c("<!-- zzcomment -->", "<!--\nzzmulti comment\n-->", "<script>zzscript()</script>",
              ".zzstyle { color: red }", "<span class=\"zzcls\">", "</span>", "<br/>", "<div>", "</div>"),
    kept = c("Lead words", "mid words.", "kept span text", "more words.", "Div body words.")
  )
})

test_that("3a L11: math is not prose in every delimiter form", {
  expect_prose(
    c("Inline $zzm1 + 1$ then $$ zzm2 $$ and \\(zzm3\\) and \\[zzm4\\] end words.", "",
      "$$", "zzdisplay + 2", "$$", "", "After words."),
    blank = c("$zzm1 + 1$", "$$ zzm2 $$", "\\(zzm3\\)", "\\[zzm4\\]", "$$\nzzdisplay + 2\n$$"),
    kept = c("Inline", "end words.", "After words.")
  )
})

test_that("3a L11: code spans, including inline R, are not prose", {
  expect_prose(
    c("Use `zzcode` and `r zzexpr` and ``zz`tick`` then `r zzv`{.num} end words."),
    blank = c("`zzcode`", "`r zzexpr`", "``zz`tick``", "`r zzv`{.num}"),
    kept = c("Use", "end words.")
  )
})

test_that("3a L11: every attribute block is not prose, after ], a code span, a link, an image, $$ and a heading", {
  expect_prose(
    c("## Head zzh {#sec-zzhead}", "", "A [kept bracket]{.zzcls1} and `x`{.zzcls2} and [kept link text](zzurl.html){.zzcls3}",
      "and ![kept alt text](zzimg.png){.zzcls4} end.", "", "$$ x $$ {#eq-zzeq}", "",
      "::: {.zzdivclass}", "Div body words.", ":::"),
    blank = c("{#sec-zzhead}", "{.zzcls1}", "{.zzcls2}", "{.zzcls3}", "{.zzcls4}", "{#eq-zzeq}",
              "{.zzdivclass}"),
    kept = c("Head zzh", "kept bracket", "kept link text", "kept alt text", "Div body words.")
  )
  # div fence lines are blank as lines
  expect_prose_lines(c("::: {.zzdivclass}", "Div body words.", ":::"),
                     c("1" = "", "2" = "Div body words.", "3" = ""))
})

test_that("3a L11: link and image targets, labels, reference definitions, autolinks, URLs, DOIs and e-mails are not prose", {
  expect_prose(
    c("A [link text](https://zztarget.example/a?b=1) and [text two][zzlabel] and ![alt words](zzimg.png \"zzttl\").", "",
      "[zzlabel]: https://zzdef.example/x", "",
      "Auto <https://zzauto.example/y> and bare https://zzbare.example/path and www.zzwww.example and ftp://zzftp.example/f.",
      "", "A doi 10.1000/zzdoi here and mail zzperson@zzmail.example now."),
    blank = c("https://zztarget.example/a?b=1", "zzlabel", "zzttl", "[zzlabel]: https://zzdef.example/x", "<https://zzauto.example/y>",
              "https://zzbare.example/path", "www.zzwww.example", "ftp://zzftp.example/f", "10.1000/zzdoi",
              "zzperson@zzmail.example", "zzimg.png"),
    kept = c("link text", "text two", "alt words", "A doi", "here and mail", "now.")
  )
})

test_that("3a L11: shortcodes and HTML entities are not prose", {
  expect_prose(
    c("Before {{< include zzfile.qmd >}} after and &amp; and &#8212; and &zzent; end words."),
    blank = c("{{< include zzfile.qmd >}}", "&amp;", "&#8212;", "&zzent;"),
    kept = c("Before", "after and", "end words.")
  )
})

test_that("3a L11: citations and cross-references are not prose (the key and its locator)", {
  expect_prose(
    c("Kept one [see @zzc1; @zzc2, p. 3] and in-text @zzc3 [p. 4] and -@zzc4 and @{zzc5} words.", "",
      "Refer to @fig-zzx and @tbl-zzy words, \\@ref(fig:zzr) and (\\#fig:zzanch) end."),
    blank = c("@zzc1", "@zzc2", "@zzc3", "[p. 4]", "-@zzc4", "@{zzc5}", "@fig-zzx", "@tbl-zzy",
              "\\@ref(fig:zzr)", "(\\#fig:zzanch)"),
    kept = c("Kept one", "words.", "Refer to", "words,", "end.")
  )
})

test_that("3a L11: footnote markers and definition labels are not prose, the note's text is", {
  expect_prose(
    c("Text[^zzn1] more^[Inline zznote words] after.", "", "[^zzn1]: Definition zzdef words."),
    blank = c("[^zzn1]", "[^zzn1]:", "^["),
    kept = c("Text", "more", "Inline zznote words", "Definition zzdef words.")
  )
  src <- read_src(c("Text[^zzn1] more^[Inline zznote words] after."))
  # the closing ] of the inline note is blank
  expect_identical(src_frag(src, "words]")$prose, "words ")
})

test_that("3a L11: line-start markers are blanked in place", {
  expect_prose_lines(
    c("> quote words", "> > nested words", "", "## Heading words ##", "", "- bullet words", "* star words",
      "+ plus words", "- [ ] task words", "- [x] done words", "", "1. first words", "2) second words", "",
      "Term words", ":   Definition words", "", "(@) example words"),
    c("1" = "  quote words", "2" = "    nested words", "4" = "   Heading words", "6" = "  bullet words",
      "7" = "  star words", "8" = "  plus words", "9" = "      task words", "10" = "      done words",
      "12" = "   first words", "13" = "   second words", "15" = "Term words", "16" = "    Definition words",
      "18" = "    example words")
  )
})

test_that("3a L11: setext underlines and horizontal rules are blank", {
  expect_prose_lines(c("Setext words", "============", "", "Second words", "------------", "", "Para.", "", "* * *", "", "---", "", "After."),
                     c("1" = "Setext words", "2" = "", "4" = "Second words", "5" = "", "9" = "", "11" = "", "13" = "After."))
})

test_that("3a L11: a numeric list marker is blanked only where it starts a block, so 2020. inside a paragraph stays prose", {
  expect_prose_lines(
    c("A paragraph that goes on and in", "2020. The year words.", "", "1. Item words", "2. Item two words"),
    c("1" = "A paragraph that goes on and in", "2" = "2020. The year words.", "4" = "   Item words",
      "5" = "   Item two words")
  )
  expect_prose_lines(c("Intro.", "", "(3) Parenthesised words"), c("3" = "    Parenthesised words"))
})

test_that("3a L11: pipe-table delimiter rows are blank; cells are prose", {
  src <- read_src(c("Lead.", "", "| zzhead A | zzhead B |", "|---|---:|", "| zzcell one | 3.4 |", "", ": Table zzcap words {#tbl-zz}"))
  expect_true(src_is_blank(src, "|---|---:|"))
  expect_true(src_is_kept(src, "zzhead A"))
  expect_true(src_is_kept(src, "zzcell one"))
  expect_true(src_is_kept(src, "3.4"))
  expect_true(src_is_kept(src, "Table zzcap words"))
  expect_true(src_is_blank(src, "{#tbl-zz}"))
})

test_that("3a L11: grid-table borders are blank; cells are prose", {
  src <- read_src(c("Lead.", "", "+--------+--------+", "| zzgrid | other  |", "+========+========+", "| zzcell | 4.5    |", "+--------+--------+"))
  expect_true(src_is_blank(src, "+--------+--------+"))
  expect_true(src_is_kept(src, "zzgrid"))
  expect_true(src_is_kept(src, "4.5"))
})

test_that("3a L11: raw TeX is not prose; the backslash of an escape is, and the escaped character is", {
  expect_prose(
    c("Words \\vspace{2em} more \\newcommand{\\zzcmd}[1]{x} and \\textbf{zzbold} end words."),
    blank = c("\\vspace{2em}", "\\newcommand{\\zzcmd}[1]{x}", "\\textbf{zzbold}"),
    kept = c("Words", "more", "end words.")
  )
  expect_prose_lines(c("Costs \\$5 and \\#zzhash total."), c("1" = "Costs  $5 and  #zzhash total."))
})

test_that("3a L11: a construct's code and attribute block are blanked, the span's bracket text is prose", {
  doc <- c("Mean was `r zzx`{.num} m, [a site | # sites]{n=\"zzk\"} here, [All]{if=\"zzok\"} words and `r zzy` too.")
  expect_prose(doc,
    blank = c("`r zzx`{.num}", "{n=\"zzk\"}", "{if=\"zzok\"}", "`r zzy`"),
    kept = c("Mean was", "a site | # sites", "All", "here,", "words and", "too.")
  )
  src <- read_src(doc)
  # [, ], | and # stay as characters in the bracket text
  expect_true(src_is_kept(src, "a site | # sites"))
})

test_that("3a L11: a link with text keeps the text and blanks the target, in Rmd and qmd", {
  expect_prose(c("See [the Zz report](https://zz.example/r) now."),
               blank = "https://zz.example/r", kept = c("the Zz report", "now."))
})

test_that("3a L11: the same document reads the same under .qmd and .Rmd", {
  doc <- c("---", "title: T zz", "---", "", "Body `c` [x]{n=\"k\"} <!-- c --> $m$ end.")
  a <- read_src(doc, ext = "qmd")
  b <- read_src(doc, ext = "Rmd")
  expect_identical(a$prose, b$prose)
})

# ---- L10: pieces beside the body --------------------------------------------------------------

test_that("3a L10: chunk-option captions and alt text are prose on #| lines, scalar and block forms", {
  expect_prose(
    c("Lead.", "", "```{r}", "#| fig-cap: \"Quoted zzcap1\"", "#| fig.cap: Plain zzcap2",
      "#| fig-alt: |", "#|   Block zzalt1", "#|   second zzalt2", "#| fig-subcap:", "#|   - Item zzsub1",
      "#|   - Item zzsub2", "#| fig.subcap: Dot zzsub3", "#| tbl-cap: Table zzcap3", "#| fig-scap: Short zzscap",
      "#| fig.scap: Short zzscap2", "#| fig.alt: Dot zzalt3", "#| other-opt: zzother", "x <- 1", "```"),
    kept = c("Quoted zzcap1", "Plain zzcap2", "Block zzalt1", "second zzalt2", "Item zzsub1", "Item zzsub2",
             "Dot zzsub3", "Table zzcap3", "Short zzscap", "Short zzscap2", "Dot zzalt3"),
    blank = c("zzother", "x <- 1", "#| fig-alt: |")
  )
})

test_that("3a L10: header-option captions: a literal string's contents are prose, a non-literal is not", {
  expect_prose(
    c("Lead.", "", "```{r, fig.cap=\"Header zzhead cap\", fig.alt = zzvar, fig.subcap = paste(\"zzpaste\"), other=\"zzhother\"}",
      "x <- 1", "```"),
    kept = "Header zzhead cap",
    blank = c("zzvar", "zzpaste", "zzhother")
  )
})

test_that("3a L10: an !expr or a non-literal caption is never prose", {
  expect_prose(
    c("Lead.", "", "```{r}", "#| fig-cap: !expr paste(\"zzexpr\", \"cap\")", "x <- 1", "```"),
    blank = c("zzexpr")
  )
})

test_that("3a L10: captions are read in chunks with eval: false, but not in other engines or in plain fences", {
  expect_prose(
    c("Lead.", "", "```{r}", "#| eval: false", "#| fig-cap: Off zzoffcap", "```", "",
      "```{python}", "#| fig-cap: Python zzpycap", "```", "",
      "```r", "#| fig-cap: Plain zzplaincap", "```"),
    kept = "Off zzoffcap",
    blank = c("Python zzpycap", "Plain zzplaincap")
  )
})

test_that("3a L10: literal strings given to weft_str() are prose; other strings are not", {
  expect_prose(
    c("Lead.", "", "```{r}", "x <- weft_str(\"Literal zzws1 string\")", "y <- weft::weft_str('Single zzws2')",
      "z <- \"zzother string\"", "plot(1, main = \"zzmain\")", "```"),
    kept = c("Literal zzws1 string", "Single zzws2"),
    blank = c("zzother string", "zzmain")
  )
})

test_that("3a L10: weft_str() strings are not prose in a chunk with eval: false", {
  expect_prose(
    c("Lead.", "", "```{r}", "#| eval: false", "x <- weft_str(\"Off zzwsoff string\")", "```"),
    blank = "Off zzwsoff string"
  )
})

test_that("3a L10: string constants inside lookup() and brk() are prose, but names are not", {
  expect_prose(
    c("Lead.", "", "```{r}",
      "a <- lookup(x, c(hi = \"high zzlk1\", lo = \"low zzlk2\"))",
      "b <- brk(v, c(2, 5), c(\"few zzbk1\", \"some zzbk2\", \"many zzbk3\"))",
      "d <- c(hi = \"zznolookup\")", "```"),
    kept = c("high zzlk1", "low zzlk2", "few zzbk1", "some zzbk2", "many zzbk3"),
    blank = c("zznolookup")
  )
  src <- read_src(c("```{r}", "a <- lookup(x, c(hi = \"high zzlk1\"))", "```"))
  # the name hi is not prose: the first "hi" of `hi =` is blank though "high" is not
  p <- src_frag(src, "hi =")
  expect_false(grepl("[^ ]", p$prose))
})

test_that("3a L10: lookup() and brk() strings are not read in a chunk with eval: false or a non-R chunk", {
  expect_prose(
    c("Lead.", "", "```{r}", "#| eval: false", "a <- lookup(x, c(hi = \"high zzlkoff\"))", "```", "",
      "```{python}", "a <- lookup(x, c(hi = \"high zzlkpy\"))", "```"),
    blank = c("high zzlkoff", "high zzlkpy")
  )
})

# ---- L9: rows and offsets -------------------------------------------------------------------------

# a document with constructs in every context, and the construct strings as written
ROW_DOC <- c(
  "---", "title: T", "abstract: |", "  Abs with `r zzabs`{.num} and more.", "---", "",
  "Body `r zzx1`{.num} and [a site | # sites]{n=\"zzk\"} and `r zzx2`.", "",
  "```{r}", "#| fig-cap: |", "#|   Cap [many | one]{if=\"zzcond\"} sites.",
  "x <- weft_str(\"val `r zzx3`{.num} ok\")", "y <- lookup(x, c(a = \"the `r zzx4`{.num} bit\"))", "```"
)
ROW_CONSTRUCTS <- c("`r zzabs`{.num}", "`r zzx1`{.num}", "[a site | # sites]{n=\"zzk\"}", "`r zzx2`",
                    "[many | one]{if=\"zzcond\"}", "`r zzx3`{.num}", "`r zzx4`{.num}")

test_that("3a L9: rows carry fstart, fend and fblock, and substr(text, fstart, fend) is the construct as written in every context", {
  for (e in c("qmd", "Rmd")) {
    src <- read_src(ROW_DOC, ext = e)
    r <- src$rows
    expect_true(all(c("fstart", "fend", "fblock") %in% names(r)))
    expect_true(all(c("kind", "line", "start", "end", "expr", "error") %in% names(r)))
    got <- substring(src$text, r$fstart, r$fend)
    expect_setequal(got, ROW_CONSTRUCTS)
    expect_equal(nrow(r), length(ROW_CONSTRUCTS))
    expect_false(anyNA(r$fstart))
    expect_false(anyNA(r$fend))
  }
})

test_that("3a L9: fblock is the offset of the attribute block (assumed: its opening brace)", {
  src <- read_src(ROW_DOC)
  r <- src$rows
  with_attr <- grepl("\\}$", substring(src$text, r$fstart, r$fend))
  expect_true(any(with_attr))
  expect_true(all(substring(src$text, r$fblock[with_attr], r$fblock[with_attr]) == "{"))
  # a bare value has no attribute block
  bare <- !with_attr
  expect_true(all(is.na(r$fblock[bare])))
})

test_that("3a L9: rows still hold the scanner's columns (kind, expr, classes, keys, error) for the same text", {
  src <- read_src(ROW_DOC)
  expect_true(all(c("classes", "keys", "id", "arms", "parent", "arm") %in% names(src$rows)))
  k <- src$rows$kind[substring(src$text, src$rows$fstart, src$rows$fend) == "[many | one]{if=\"zzcond\"}"]
  expect_identical(k, "if")
})

test_that("3a L9: fstart and fend survive CRLF, BOM, and non-ASCII before the construct", {
  doc <- c("\u00e9\u00e9 `r zzx1`{.num}", "", "Line \u2014 [a | b]{n=\"zzk\"}")
  for (variant in list(list(), list(eol = "\r\n", bom = TRUE))) {
    src <- do.call(read_src, c(list(doc), variant))
    expect_setequal(substring(src$text, src$rows$fstart, src$rows$fend), c("`r zzx1`{.num}", "[a | b]{n=\"zzk\"}"))
  }
})

# ---- L9: regions ----------------------------------------------------------------------------------

REG_DOC <- c(
  "---", "title: Reg title", "---", "",
  "## Zz Heading {#sec-zzh}", "",
  "A $zzmath$ and `r zzbare` and `r zzval`{.num} and [1]{.weft-literal why=\"zzwhy\"} and [a | b]{if=\"zzif\"}.", "",
  "Then [a | b]{n=\"zzn\"} and [x]{sign=\"zzsign\"} and [a]{list=\"zzlist\"} and [10 m]{cite=\"zzcite\"} and [t]{.num}.", "",
  "A [@zzcit1] and @fig-zzx and [zzlinktext](zzlink.org) and ![zzalt](zzimg.png) and a note[^zzfn].", "",
  "[^zzfn]: Note words.", "", "[zzref]: https://zzref.example", "",
  "| zzcell | b |", "|---|---|", "| 1 | 2 |", "",
  "::: {.zzdivclass}", "Inside.", ":::", "",
  "```{r}", "#| fig-cap: Cap words", "zzchunkcode <- weft_str(\"zzstr\")", "q <- lookup(c(a = \"zzphrase\"))", "```"
)

test_that("3a L9: regions has the documented columns", {
  src <- read_src(REG_DOC)
  r <- src$regions
  for (nm in c("type", "start", "end", "row", "name", "inner_start", "inner_end", "attr_start", "attr_end",
               "classes", "keys", "id")) {
    expect_true(nm %in% names(r), label = paste("regions column", nm))
  }
  expect_type(r$classes, "list")
  expect_type(r$keys, "list")
  expect_type(r$id, "list")
})

# (type, a token that its text must contain)
REG_EXPECT <- list(
  c("math", "zzmath"), c("bare", "zzbare"), c("value", "zzval"), c("literal", "zzwhy"), c("if", "zzif"),
  c("n", "zzn"), c("sign", "zzsign"), c("list", "zzlist"), c("cite_span", "zzcite"), c("text_span", ".num"),
  c("span", "zzif"), c("citation", "zzcit1"), c("crossref", "fig-zzx"), c("link", "zzlink.org"),
  c("image", "zzimg.png"), c("heading", "Zz Heading"), c("footnote", "zzfn"), c("div", "zzdivclass"),
  c("chunk", "zzchunkcode"), c("caption", "Cap words"), c("weft_str", "zzstr"), c("phrase", "zzphrase"),
  c("refdef", "zzref"), c("table", "zzcell"), c("yaml_field", "Reg title")
)

test_that("3a L9: each region type is found, and its offsets cover its text", {
  for (e in c("qmd", "Rmd")) {
    src <- read_src(REG_DOC, ext = e)
    for (ex in REG_EXPECT) {
      rr <- src_regions(src, ex[[1]])
      expect_gte(nrow(rr), 1L)
      txt <- substring(src$text, rr$start, rr$end)
      expect_true(any(grepl(ex[[2]], txt, fixed = TRUE)),
                  label = sprintf("[%s] region %s covers text with %s (got: %s)", e, ex[[1]], ex[[2]],
                                  substr(paste(txt, collapse = " | "), 1, 80)))
    }
  }
})

test_that("3a L9: a span region has inner and attribute offsets and parsed classes, keys and id", {
  src <- read_src(c("Text [a site | # sites]{n=\"zzk\" .zzcls #zzid} and [t]{.smallcaps}."))
  sp <- src_regions(src, "span")
  expect_equal(nrow(sp), 2L)
  strip <- function(x) sub("\\]$", "", sub("^\\[", "", x))
  inner <- strip(substring(src$text, sp$inner_start, sp$inner_end))
  expect_setequal(inner, c("a site | # sites", "t"))
  a <- sp[inner == "a site | # sites", ]
  attr_txt <- substring(src$text, a$attr_start, a$attr_end)
  expect_true(grepl("zzk", attr_txt, fixed = TRUE))
  expect_identical(sub("^\\.", "", unlist(a$classes[[1]])), "zzcls")
  expect_identical(unlist(a$keys[[1]]), "n")
  expect_identical(sub("^#", "", unlist(a$id[[1]])), "zzid")
  b <- sp[inner == "t", ]
  expect_identical(sub("^\\.", "", unlist(b$classes[[1]])), "smallcaps")
})

test_that("3a L9: regions of a span that is not a weft construct are found too (any [...]{...})", {
  src <- read_src("A [plain]{.zzcls} span.")
  expect_equal(nrow(src_regions(src, "span")), 1L)
  expect_equal(nrow(src_regions(src, "n")) + nrow(src_regions(src, "if")), 0L)
})

test_that("3a L9: code_attr is inline code with an attribute block; yaml_field names the field; caption names the option", {
  src <- read_src(c("---", "title: T", "---", "", "A `x`{.zzr} and `y`.", "", "```{r}", "#| fig-cap: Cap zz", "```"))
  expect_equal(nrow(src_regions(src, "code_attr")), 1L)
  expect_true("title" %in% src_regions(src, "yaml_field")$name)
  expect_true("fig-cap" %in% src_regions(src, "caption")$name)
})

test_that("3a L9: code spans and chunks give 'code' and 'chunk' regions", {
  src <- read_src(c("A `zzspan` here.", "", "```{r}", "zzchunk <- 1", "```"))
  expect_true(any(grepl("zzspan", substring(src$text, src_regions(src, "code")$start, src_regions(src, "code")$end), fixed = TRUE)))
  expect_equal(nrow(src_regions(src, "chunk")), 1L)
})

# ---- L9: blocks -----------------------------------------------------------------------------------

BLOCK_DOC <- c(
  "---", "title: Block title", "---", "",                                  # 1-4
  "# Zz Heading {#sec-z}", "",                                           # 5-6
  "Para line one", "para line two.", "",                                 # 7-9
  "- item one", "- item two", "",                                        # 10-12
  "| a | b |", "|---|---|", "| cell1 | cell2 |", "",                     # 13-16
  ": Table caption {#tbl-z}", "",                                        # 17-18
  "Text with note[^n1] and ^[inline note].", "",                         # 19-20
  "[^n1]: Definition paragraph.", "",                                    # 21-22
  "```{r}", "#| fig-cap: Chunk caption words",                           # 23-24
  "x <- weft_str(\"string words\")", "y <- lookup(c(a = \"phrase words\"))", "```", "",   # 25-28
  "::: {#fig-d}", "![Alt](d.png)", "", "Div caption last paragraph.", ":::"                # 29-33
)

test_that("3a L9: blocks has type, start, end, line, end_line", {
  src <- read_src(BLOCK_DOC)
  b <- src$blocks
  expect_s3_class(b, "data.frame")
  for (nm in c("type", "start", "end", "line", "end_line")) expect_true(nm %in% names(b), label = nm)
  expect_true(all(b$type %in% c("para", "heading", "item", "cell", "footnote", "caption",
                                "front-matter", "weft_str", "phrase")))
  expect_true(all(b$end >= b$start))
  expect_true(all(b$end_line >= b$line))
})

# (type, line) pairs that must be present
BLOCK_EXPECT <- list(
  c("front-matter", 2), c("heading", 5), c("para", 7), c("item", 10), c("item", 11),
  c("cell", 13), c("cell", 15), c("caption", 17), c("para", 19), c("footnote", 19),
  c("footnote", 21), c("caption", 24), c("weft_str", 25), c("phrase", 26), c("caption", 32)
)

test_that("3a L9: every block type is found at its line, in qmd and Rmd", {
  for (e in c("qmd", "Rmd")) {
    b <- read_src(BLOCK_DOC, ext = e)$blocks
    for (ex in BLOCK_EXPECT) {
      expect_true(any(b$type == ex[[1]] & b$line == as.integer(ex[[2]])),
                  label = sprintf("[%s] block %s at line %s", e, ex[[1]], ex[[2]]))
    }
  }
})

test_that("3a L9: a paragraph spans its lines (end_line), a code line is in no block", {
  b <- read_src(BLOCK_DOC)$blocks
  p <- b[b$type == "para" & b$line == 7L, ]
  expect_equal(p$end_line, 8L)
  # a line of code (line 25's R code is not a para): no para starts at 27 or 28
  expect_false(any(b$type == "para" & b$line %in% c(23L, 27L, 28L)))
})

test_that("3a L9: a paragraph ends at a blank line, a fence, a div line, a heading or a list marker that starts a block", {
  b <- read_src(c("Para one", "```", "code", "```", "Para two", "::: {.d}", "In div", ":::", "Para three", "## Head", "Para four", "", "Para five"))$blocks
  p <- b[b$type == "para", ]
  expect_equal(p$line, c(1L, 5L, 7L, 9L, 11L, 13L))
  expect_true(any(b$type == "heading" & b$line == 10L))
  expect_equal(p$end_line, p$line)
})

test_that("3a L9: the last paragraph of a #fig- or #tbl- div is its caption", {
  b <- read_src(c("::: {#tbl-x}", "| a |", "|---|", "| 1 |", "", "Table caption words.", ":::"))$blocks
  expect_true(any(b$type == "caption" & b$line == 6L))
})

test_that("3a L9: a block equal to a line of the chunk above does not confuse positions", {
  doc <- c("```{r}", "x <- 1", "Same words here.", "```", "", "Same words here.", "", "Same words here.")
  b <- read_src(doc)$blocks
  p <- b[b$type == "para", ]
  expect_equal(p$line, c(6L, 8L))
})

# ---- L9: chunks -----------------------------------------------------------------------------------

CHUNK_DOC <- c(
  "```{r setup}", "x <- 1", "```", "",                                              # 1-4
  "```{r}", "#| label: fig-a", "#| eval: false", "#| cache: true", "y <- 2", "z <- 3", "```", "",   # 5-12
  "```{python}", "print(1)", "```", "",                                              # 13-16
  "```r", "not executed", "```"                                                     # 17-19
)

test_that("3a L9: chunks lists executed chunks only, with their columns", {
  src <- read_src(CHUNK_DOC)
  ch <- src$chunks
  expect_s3_class(ch, "data.frame")
  for (nm in c("open", "close", "engine", "label", "explicit", "eval", "cache", "options", "code", "code_first")) {
    expect_true(nm %in% names(ch), label = paste("chunks column", nm))
  }
  expect_equal(nrow(ch), 3L)
  expect_identical(ch$engine, c("r", "r", "python"))
  expect_type(ch$explicit, "logical")
  expect_type(ch$eval, "logical")
  expect_type(ch$options, "list")
  expect_type(ch$code, "list")
})

test_that("3a L9: a chunk's label, explicitness, eval, cache and code", {
  ch <- read_src(CHUNK_DOC)$chunks
  expect_identical(ch$label[[1]], "setup")
  expect_true(ch$explicit[[1]])
  expect_identical(ch$label[[2]], "fig-a")
  expect_true(ch$explicit[[2]])
  expect_false(ch$explicit[[3]])
  # eval is FALSE only when written literally false
  expect_false(isFALSE(ch$eval[[1]]))
  expect_true(isFALSE(ch$eval[[2]]))
  expect_false(isFALSE(ch$eval[[3]]))
  # cache as written: TRUE, FALSE or NA
  expect_true(is.na(ch$cache[[1]]))
  expect_true(isTRUE(ch$cache[[2]]))
  expect_true(is.na(ch$cache[[3]]))
  expect_identical(ch$code_first[[1]], "x <- 1")
  expect_identical(ch$code_first[[2]], "y <- 2")
  expect_true(all(c("y <- 2", "z <- 3") %in% ch$code[[2]]))
  expect_identical(ch$code_first[[3]], "print(1)")
})

test_that("3a L9: open and close are the chunk's fence lines (as line numbers or offsets)", {
  src <- read_src(CHUNK_DOC)
  ch <- src$chunks
  expect_true(ch$open[[2]] %in% c(5L, src$line_start[[5]]))
  expect_true(ch$close[[2]] %in% c(11L, src$line_start[[11]]))
})

test_that("3a L9: header option forms: label, eval and cache as written", {
  doc <- c("```{r lbl1, eval=FALSE, cache=TRUE}", "a", "```", "", "```{r, label=\"lbl2\", eval=isTRUE(zz), cache=FALSE}", "b", "```", "",
           "```{r lbl3, cache=zz}", "c", "```", "", "```{r}", "#| eval: !expr zz", "#| label: lbl4", "d", "```")
  ch <- read_src(doc, ext = "Rmd")$chunks
  expect_equal(nrow(ch), 4L)
  expect_identical(ch$label[c(1, 2, 3, 4)], c("lbl1", "lbl2", "lbl3", "lbl4"))
  expect_true(all(ch$explicit))
  expect_identical(isFALSE(ch$eval[[1]]), TRUE)
  expect_false(isFALSE(ch$eval[[2]]))
  expect_false(isFALSE(ch$eval[[4]]))
  expect_true(isTRUE(ch$cache[[1]]))
  expect_true(isFALSE(ch$cache[[2]]))
  expect_true(is.na(ch$cache[[3]]))
})

test_that("3a L9: a chunk with no code has code_first NA or empty, not an error", {
  expect_no_error(read_src(c("```{r}", "#| label: a", "```")))
  ch <- read_src(c("```{r}", "#| label: a", "```"))$chunks
  expect_equal(nrow(ch), 1L)
})

test_that("3a L9: no chunks gives a zero-row chunks table with the columns", {
  ch <- read_src("Just prose.")$chunks
  expect_equal(nrow(ch), 0L)
  expect_true(all(c("open", "close", "engine", "label", "explicit", "eval", "cache", "options", "code", "code_first") %in% names(ch)))
})

# ---- L9: meta and front ---------------------------------------------------------------------------

test_that("3a L9: meta holds each metadata block; front merges them with the later winning", {
  src <- read_src(c("---", "title: First", "lang: en", "---", "", "Body.", "", "---", "title: Second", "extra: kept", "---", "", "End."))
  expect_length(src$meta, 2L)
  f <- src_front(src)
  expect_identical(f$title, "Second")
  expect_identical(f$lang, "en")
  expect_identical(f$extra, "kept")
})

test_that("3a L9: !expr in front matter is kept as text", {
  src <- read_src(c("---", "title: T", "date: !expr Sys.Date()", "---", "", "Body."))
  d <- src_front(src)$date
  expect_type(d, "character")
  expect_true(grepl("Sys.Date()", paste(d, collapse = " "), fixed = TRUE))
})

test_that("3a L9: a document with no front matter has an empty meta", {
  src <- read_src("Just prose.")
  expect_length(src$meta, 0L)
})

# ---- L12: words and sentences ------------------------------------------------------------------------

sents <- function(lines, ...) {
  src <- read_src(lines, ...)
  list(src = src, s = weft:::source_sentences(src))
}

test_that("3a L12: source_sentences() returns start, end, line, end_line and block per sentence", {
  r <- sents(c("First sentence here. Second sentence here.", "", "Third one."))
  expect_s3_class(r$s, "data.frame")
  for (nm in c("start", "end", "line", "end_line", "block")) expect_true(nm %in% names(r$s), label = nm)
  expect_equal(nrow(r$s), 3L)
  expect_identical(as.integer(r$s$line), c(1L, 1L, 3L))
  expect_identical(r$s$block[[1]], r$s$block[[2]])
  expect_false(r$s$block[[2]] == r$s$block[[3]])
})

test_that("3a L12: a sentence that crosses lines has end_line, the next starts on the line it ends on", {
  r <- sents(c("First sentence", "continues here. Second sentence."))
  expect_equal(nrow(r$s), 2L)
  expect_identical(as.integer(r$s$line), c(1L, 2L))
  expect_identical(as.integer(r$s$end_line), c(2L, 2L))
})

test_that("3a L12: sentence offsets are in the source text", {
  r <- sents(c("First sentence here. Second sentence here."))
  expect_match(substr(r$src$text, r$s$start[[1]], r$s$end[[1]]), "^First sentence here\\.?\\s*$")
  expect_match(substr(r$src$text, r$s$start[[2]], r$s$end[[2]]), "^\\s*Second sentence here\\.?\\s*$")
})

test_that("3a L12: a full stop inside a code span, a construct or a citation does not end a sentence", {
  r <- sents(c("Call `a. B` here. Next sentence."))
  expect_equal(nrow(r$s), 2L)
  r <- sents(c("It was `r zzv`{.num} m. in all. Next sentence."))
  expect_gte(nrow(r$s), 2L)
  r <- sents(c("As shown [@smith2020, p. 4]. Next sentence."))
  expect_equal(nrow(r$s), 2L)
})

test_that("3a L12: sentences are cut per block (a heading, each list item and each cell is its own)", {
  r <- sents(c("## Heading words", "", "- Item one. Item one again.", "- Item two.", "", "| a | b |", "|---|---|", "| cell one | cell two |"))
  s <- r$s
  # heading (1) + item one (2 sentences) + item two (1) + 2 header cells + 2 body cells
  expect_gte(nrow(s), 5L)
  expect_gte(length(unique(s$block)), 4L)
  expect_true(any(s$line == 1L))
  expect_equal(sum(s$line == 3L), 2L)
  expect_equal(sum(s$line == 4L), 1L)
})

test_that("3a L12: a sentence in a caption, a front-matter piece and a weft_str string is read in its place", {
  doc <- c("---", "title: Title words. Second title sentence.", "---", "", "```{r}", "#| fig-cap: Caption one. Caption two.",
           "x <- weft_str(\"String one. String two.\")", "```")
  s <- sents(doc)$s
  expect_equal(sum(s$line == 2L), 2L)
  expect_equal(sum(s$line == 6L), 2L)
  expect_equal(sum(s$line == 7L), 2L)
})

test_that("3a L12: a document with no prose has no sentences", {
  s <- sents(c("```{r}", "x <- 1", "```"))$s
  expect_equal(nrow(s), 0L)
  expect_true(all(c("start", "end", "line", "end_line", "block") %in% names(s)))
})

test_that("3a L12: sentences follow the document's lang (a Latin-script de document is cut like any other here)", {
  s <- sents(c("---", "lang: de", "---", "", "Das erste. Das zweite."))$s
  expect_gte(nrow(s), 1L)
})
