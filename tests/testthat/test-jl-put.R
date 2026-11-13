# Package 6h: put() and @put of Weft.jl (N20 to N22, N29, N48, N6, N70 mirrored for Julia, the "Julia put"
# paragraph of section 4 of dev/design-6.md; messages E41 and E42 of section 7). Written before the code.
# Made-up values only. Helper: helper-julia-engine.R. Skipped when quarto or julia is absent.
#
# Two kinds of test. The no-back-end ones run in ONE plain `julia` process (jle_cases(): no Quarto, fast):
# with no back end the block is printed to stdout. The engine ones render ONE bare project (no filter, so
# the carrier blocks stay in the HTML) on the julia engine and read what `put` displayed.
#
# READINGS of the note (see the report, "Spec gaps"):
#  - the members of a record after `t` and `v` (`why`, `of`, `keys`, `type`) are not pinned in the block's
#    text, only parsed; the order of the envelope members follows the example of N20;
#  - `Weft.put(pairs...)` is read as pairs `:name => value` (a Symbol key); a String key, a mix of pairs and
#    keywords in one call, a repeated name, and `@put` of something that is not a variable are not tested;
#  - run: read from `.weft/run` found upward from QUARTO_DOCUMENT_PATH (the document's folder), else
#    WEFT_RUN, as N48 says; the tests give the folder through QUARTO_DOCUMENT_PATH, as 6e's tests do;
#  - the engine back end is not switched on by name here: it is whatever a notebook of the julia engine
#    gets, so those tests are renders;
#  - the text of a PublishError is read as E41 and E42 (showerror), looked for inside the message.

jle_kill_at_file_end()

`%||%` <- function(a, b) if (is.null(a)) b else a

# the envelope of N20 up to the start of `values`: members in the order of the example
JSON_ENV <- function(values_start, run = "null") {
  sprintf('^\\{"weft":1,"lang":"julia","run":%s,"at":[0-9]+,"values":%s', run, values_start)
}
PUT_BLOCK <- function(values_start) paste0("^````\\{\\.weft-values\\}\n", sub("^\\^", "", JSON_ENV(values_start)))

put_run <- function() {
  if (!is.null(.jle$put_run)) return(.jle$put_run)
  codes <- c(
    # 1: the exact block of one value, and the return value
    'using Weft\nr = Weft.put(depth=3.14159)\nprintln("RET=", repr(r))',
    # 2: every kind
    paste('using Weft, Dates',
          'Weft.put(i=42, neg=-7, f=0.1, b=true, s="Alpha", d=Date(2026, 11, 13), big=BigInt(2)^70,',
          '         i64=2^62, xs=[1, 2, 3], mx=[1, 2.5], nt=(a=1, b=2), gone=missing, none=nothing, nan=NaN)',
          sep = "\n"),
    # 3: pairs
    'using Weft\nr = Weft.put(:alpha => 1, :beta => "x")\nprintln("RET=", repr(r))',
    # 4: a dot is an ordinary character in a name
    'using Weft\nWeft.put(Symbol("n.sites") => 4)',
    # 5 to 9: a name that is not a NAME raises PublishError and publishes nothing
    'using Weft\nWeft.put(Symbol("bad name") => 1)',
    'using Weft\nWeft.put(:ok_name => 1, Symbol("1bad") => 2)',
    'using Weft\nWeft.put(Symbol("missing") => 1)',
    'using Weft\nWeft.put(Symbol("a"^65) => 1)',
    'using Weft\nWeft.put(; Dict(Symbol("bad name") => 1)...)',
    # 10: two calls, two blocks
    'using Weft\nWeft.put(one=1)\nWeft.put(two=2)',
    # 11: a value the classifier refuses is published as its error record
    'using Weft\nWeft.put(s=Set([1, 2]))',
    # 12, 13: the size of a list
    'using Weft\nWeft.put(col=collect(1:10001))',
    'using Weft\nWeft.put(col=collect(1:100))',
    # 14: the exceptions of N3
    'using Weft\nprintln(Weft.PublishError <: Exception, " ", Weft.ClaimFailed <: Exception)',
    # 15: @put
    'using Weft\na = 3\nb = "x"\nr = @put a b\nprintln("RET=", repr(r))',
    # 16: @put of one variable, its own name
    'using Weft\nn_sites = 4\n@put n_sites',
    # 17: @put of a name that is not ASCII
    'using Weft\ncaf\u00e9 = 1\n@put caf\u00e9',
    # 18: the run id, read at each publish (N48); last: it changes the environment of the process
    paste('using Weft',
          'root = mktempdir()',
          'doc = joinpath(root, "sub", "deeper"); mkpath(doc)',
          'ENV["QUARTO_DOCUMENT_PATH"] = doc',
          'ENV["QUARTO_DOCUMENT_FILE"] = "doc.qmd"',
          'rf = joinpath(root, ".weft", "run"); mkpath(dirname(rf))',
          'ENV["WEFT_RUN"] = "run-env-1"',
          'Weft.put(r=1)',
          'write(rf, "run-file-1\\nsecond line is ignored\\n"); Weft.put(r=1)',
          'write(rf, "run-file-2\\n"); Weft.put(r=1)',
          'rm(rf); Weft.put(r=1)',
          'delete!(ENV, "WEFT_RUN"); Weft.put(r=1)',
          'ENV["WEFT_RUN"] = "run-env-2"; Weft.put(r=1)',
          'ENV["WEFT_RUN"] = ""; Weft.put(r=1)',
          'delete!(ENV, "WEFT_RUN"); Weft.put(r=1)',
          sep = "\n")
  )
  t0 <- floor(as.numeric(Sys.time()))
  res <- jle_cases(codes)
  .jle$put_run <- list(res = res, t0 = t0, t1 = ceiling(as.numeric(Sys.time())))
}

sc <- function(x) list(t = x$t, v = x$v)

test_that("N70, N20, N21: Weft.put(; kw...) with no back end prints one block, whose envelope is exact, and returns nothing", {
  s <- put_run()
  x <- s$res[[1]]
  expect_true(is.na(x$etype) || identical(x$etype, ""), label = paste("no exception:", x$etype, x$emsg))
  expect_match(x$out, paste0(PUT_BLOCK('\\{"depth":\\{"t":"float","v":"3.14159"'), '[^\n]*\\}\\}\\}\n````\nRET=nothing\n$'))
  expect_length(x$blocks, 1L)
  b <- blk(x, 1)
  expect_identical(as.integer(b$weft), 1L)
  expect_identical(b$lang, "julia")
  expect_null(b$run)
  at <- as.numeric(sub('.*"at":([0-9]+),.*', "\\1", x$block_text))
  expect_true(at >= s$t0 - 1 && at <= s$t1 + 1, label = "`at` is the time of the publish in whole seconds")
})

test_that("N70, N22: every kind of value becomes its record", {
  x <- put_run()$res[[2]]
  expect_true(is.na(x$etype) || identical(x$etype, ""), label = paste("no exception:", x$etype, x$emsg))
  expect_length(x$blocks, 1L)
  v <- blk(x, 1)$values
  expect_identical(sc(v$i), list(t = "int", v = "42"))
  expect_identical(sc(v$neg), list(t = "int", v = "-7"))
  expect_identical(sc(v$f), list(t = "float", v = "0.1"))
  expect_identical(sc(v$b), list(t = "bool", v = TRUE))
  expect_identical(sc(v$s), list(t = "string", v = "Alpha"))
  expect_identical(sc(v$d), list(t = "date", v = "2026-11-13"))
  # an integer of any size is an int record: no refusal for size
  expect_identical(sc(v$big), list(t = "int", v = "1180591620717411303424"))
  expect_identical(sc(v$i64), list(t = "int", v = "4611686018427387904"))
  expect_identical(v$xs$t, "list")
  expect_identical(v$xs$of, "int")
  expect_null(v$xs$keys)
  expect_identical(vapply(v$xs$v, function(e) paste(e$t, e$v), ""), c("int 1", "int 2", "int 3"))
  expect_identical(v$mx$t, "list")
  expect_identical(v$mx$of, "float")
  expect_identical(v$nt$t, "list")
  expect_identical(unlist(v$nt$keys), c("a", "b"))
  expect_identical(v$gone$t, "missing")
  expect_identical(v$none$t, "missing")
  expect_identical(v$nan$t, "missing")
  expect_setequal(nms(v), c("i", "neg", "f", "b", "s", "d", "big", "i64", "xs", "mx", "nt", "gone", "none", "nan"))
})

test_that("N70: pairs `:name => value` publish together, in one block, and return nothing; a dot is part of a name", {
  r <- put_run()$res
  x <- r[[3]]
  expect_true(is.na(x$etype) || identical(x$etype, ""), label = paste("no exception:", x$etype, x$emsg))
  expect_length(x$blocks, 1L)
  v <- blk(x, 1)$values
  expect_setequal(nms(v), c("alpha", "beta"))
  expect_identical(sc(v$alpha), list(t = "int", v = "1"))
  expect_identical(sc(v$beta), list(t = "string", v = "x"))
  expect_match(x$out, "RET=nothing\n$")
  expect_match(r[[4]]$out, PUT_BLOCK('\\{"n\\.sites":\\{"t":"int","v":"4"'))
})

test_that("N70, E41, N6: a name that is not a NAME raises PublishError and publishes nothing", {
  r <- put_run()$res
  bad <- list(`5` = "bad name", `6` = "1bad", `7` = "missing", `8` = strrep("a", 65), `9` = "bad name")
  for (k in names(bad)) {
    x <- r[[as.integer(k)]]
    expect_identical(x$etype, "PublishError", label = paste("case", k))
    expect_true(grepl(jle_msg$E41(bad[[k]]), x$emsg, fixed = TRUE), label = paste("E41 for", bad[[k]], "in:", x$emsg))
    expect_false(grepl("weft-values", x$out, fixed = TRUE), label = paste("nothing published, case", k))
  }
})

test_that("N70: each call prints its own block", {
  x <- put_run()$res[[10]]
  expect_length(x$blocks, 2L)
  expect_identical(nms(blk(x, 1)$values), "one")
  expect_identical(nms(blk(x, 2)$values), "two")
})

test_that("N70, N43's reason: a value the classifier refuses is published as an error record", {
  x <- put_run()$res[[11]]
  expect_true(is.na(x$etype) || identical(x$etype, ""), label = paste("no exception:", x$etype, x$emsg))
  expect_length(x$blocks, 1L)
  rec <- blk(x, 1)$values$s
  expect_identical(rec$t, "error")
  expect_true(is.character(rec$why) && nzchar(rec$why))
})

test_that("N29, E42, E52, N3: a list of more than 10000 elements is refused with PublishError; a shorter one goes", {
  r <- put_run()$res
  expect_identical(r[[12]]$etype, "PublishError")
  expect_true(grepl(jle_msg$E42("col", 10001L), r[[12]]$emsg, fixed = TRUE), label = r[[12]]$emsg)
  expect_false(grepl("weft-values", r[[12]]$out, fixed = TRUE))
  expect_length(r[[13]]$blocks, 1L)
  expect_identical(blk(r[[13]], 1)$values$col$of, "int")
  expect_length(blk(r[[13]], 1)$values$col$v, 100L)
  expect_identical(r[[14]]$out, "true true\n")
})

test_that("N40's Julia form: @put a b publishes each variable under its own name, in one block, and returns nothing", {
  r <- put_run()$res
  x <- r[[15]]
  expect_true(is.na(x$etype) || identical(x$etype, ""), label = paste("no exception:", x$etype, x$emsg))
  expect_length(x$blocks, 1L)
  v <- blk(x, 1)$values
  expect_setequal(nms(v), c("a", "b"))
  expect_identical(sc(v$a), list(t = "int", v = "3"))
  expect_identical(sc(v$b), list(t = "string", v = "x"))
  expect_identical(blk(x, 1)$lang, "julia")
  expect_match(x$out, "RET=nothing\n$")
  y <- r[[16]]
  expect_length(y$blocks, 1L)
  expect_match(y$block_text, PUT_BLOCK('\\{"n_sites":\\{"t":"int","v":"4"'))
})

test_that("N6, E41: @put of a variable whose name is not ASCII raises PublishError", {
  x <- put_run()$res[[17]]
  expect_identical(x$etype, "PublishError")
  expect_true(grepl(jle_msg$E41("caf\u00e9"), x$emsg, fixed = TRUE), label = x$emsg)
  expect_false(grepl("weft-values", x$out, fixed = TRUE))
})

test_that("N48: run is the first line of .weft/run found upward, else WEFT_RUN when not empty, else null; read at each publish", {
  x <- put_run()$res[[18]]
  expect_true(is.na(x$etype) || identical(x$etype, ""), label = paste("no exception:", x$etype, x$emsg))
  expect_length(x$blocks, 8L)
  run <- vapply(x$blocks, function(b) if (is.null(b$run)) NA_character_ else b$run, "")
  expect_identical(run, c("run-env-1", "run-file-1", "run-file-2", "run-env-1", NA, "run-env-2", NA, NA))
  expect_length(gregexpr('"run":null', x$out, fixed = TRUE)[[1]], 3L)
})

# ---- on the julia engine: put displays a Weft.Values --------------------------------------------------

PUT_QMD <- c(
  "---",
  "title: Put",
  "execute:",
  "  error: true",
  "---",
  "",
  "```{julia}",
  "#| include: false",
  "using Weft",
  "```",
  "",
  "```{julia}",
  "#| label: p1",
  "#| echo: false",
  "Weft.put(depth=3.14159)",
  "```",
  "",
  "```{julia}",
  "#| label: p2",
  "#| echo: false",
  "a = 3",
  "b = \"x\"",
  "@put a b",
  "```",
  "",
  "```{julia}",
  "#| label: p3",
  "#| echo: false",
  "Weft.put(one=1)",
  "Weft.put(two=2)",
  "```",
  "",
  "```{julia}",
  "#| label: p4",
  "#| echo: false",
  "Weft.put(:alpha => 1, :beta => \"x\")",
  "```",
  "",
  "```{julia}",
  "#| label: p5",
  "#| echo: false",
  "Weft.put(Symbol(\"bad name\") => 1)",
  "```",
  "",
  "```{julia}",
  "#| label: p6",
  "#| echo: false",
  "Weft.put(col=collect(1:10001))",
  "```",
  "",
  "```{julia}",
  "#| label: p7",
  "#| echo: false",
  "struct Cap <: AbstractDisplay",
  "    items::Vector{Any}",
  "end",
  "Base.display(d::Cap, x) = (push!(d.items, x); nothing)",
  "Base.display(d::Cap, m::MIME, x) = (push!(d.items, x); nothing)",
  "cap = Cap(Any[])",
  "pushdisplay(cap)",
  "Weft.put(depth=2.5)",
  "popdisplay()",
  "println(length(cap.items))",
  "println(isempty(cap.items) ? \"none\" : string(typeof(cap.items[1])))",
  "println(isempty(cap.items) ? \"none\" : repr(\"text/markdown\", cap.items[1]))",
  "```",
  "",
  "The end."
)

put_render <- function() {
  if (!is.null(.jle$put_render)) return(.jle$put_render)
  dir <- jle_project(list(`put.qmd` = PUT_QMD, `.weft/run` = "run-file-1"), filter = FALSE)
  t0 <- floor(as.numeric(Sys.time()))
  res <- jle_render(dir, "put.qmd")
  html <- jle_read(dir, "put.html")
  .jle$put_render <- list(res = res, html = html, cells = jle_cells(html), t0 = t0,
                         t1 = ceiling(as.numeric(Sys.time())))
}

cell_blocks <- function(label) {
  s <- put_render()
  jle_html_blocks(if (is.null(s$cells[[label]])) "" else s$cells[[label]])
}

n_outputs <- function(label) {
  m <- gregexpr("<div class=\"cell-output", put_render()$cells[[label]] %||% "", fixed = TRUE)[[1]]
  sum(m > 0)
}

test_that("control: the project renders on the julia engine and the cells ran", {
  s <- put_render()
  expect_identical(s$res$status, 0L, label = s$res$log)
  expect_true(all(c("p1", "p2", "p3", "p4", "p5", "p6", "p7") %in% names(s$cells)), label = paste(names(s$cells), collapse = " "))
})

test_that("N70, N57's mirror, measured 2: put() on the julia engine displays one block, which reaches the document, with the run id from .weft/run", {
  s <- put_render()
  b <- cell_blocks("p1")
  expect_length(b$blocks, 1L)
  expect_match(b$texts, JSON_ENV('\\{"depth":\\{"t":"float","v":"3.14159"', run = '"run-file-1"'))
  x <- blk(b, 1)
  expect_identical(as.integer(x$weft), 1L)
  expect_identical(x$lang, "julia")
  expect_identical(x$run, "run-file-1")
  expect_identical(x$values$depth$t, "float")
  expect_identical(x$values$depth$v, "3.14159")
  at <- as.numeric(sub('.*"at":([0-9]+),.*', "\\1", b$texts))
  expect_true(at >= s$t0 - 1 && at <= s$t1 + 1, label = "`at` is the time of the publish")
  # put returns nothing: the block is the cell's only output
  expect_identical(n_outputs("p1"), 1L)
})

test_that("N70: @put a b on the engine displays one block with both names; two calls give two blocks; pairs work", {
  b2 <- cell_blocks("p2")
  expect_length(b2$blocks, 1L)
  expect_setequal(nms(blk(b2, 1)$values), c("a", "b"))
  expect_identical(sc(blk(b2, 1)$values$a), list(t = "int", v = "3"))
  expect_identical(sc(blk(b2, 1)$values$b), list(t = "string", v = "x"))
  expect_identical(n_outputs("p2"), 1L)
  b3 <- cell_blocks("p3")
  expect_length(b3$blocks, 2L)
  expect_identical(nms(blk(b3, 1)$values), "one")
  expect_identical(nms(blk(b3, 2)$values), "two")
  b4 <- cell_blocks("p4")
  expect_length(b4$blocks, 1L)
  expect_setequal(nms(blk(b4, 1)$values), c("alpha", "beta"))
})

test_that("E41, E42 on the engine: PublishError reaches the cell's error output and no block is displayed", {
  s <- put_render()
  expect_length(cell_blocks("p5")$blocks, 0L)
  expect_true(grepl(jle_msg$E41("bad name"), jle_unesc(s$cells[["p5"]] %||% ""), fixed = TRUE))
  expect_length(cell_blocks("p6")$blocks, 0L)
  expect_true(grepl(jle_msg$E42("col", 10001L), jle_unesc(s$cells[["p6"]] %||% ""), fixed = TRUE))
})

test_that("measured 2, N57: what put() displays on the engine is a Weft.Values whose text/markdown is the block, four backticks", {
  s <- put_render()
  out <- jle_stdout_of(s$cells[["p7"]] %||% "")
  expect_length(out, 1L)
  lines <- if (length(out)) strsplit(out[1], "\n", fixed = TRUE)[[1]] else character()
  expect_identical(lines[1], "1")
  expect_identical(lines[2], "Weft.Values")
  md <- paste(lines[-(1:2)], collapse = "\n")
  expect_match(md, "^\\s*````\\{\\.weft-values\\}\n\\{\"weft\":1,\"lang\":\"julia\",\"run\":\"run-file-1\",\"at\":[0-9]+,\"values\":\\{\"depth\":\\{\"t\":\"float\",\"v\":\"2.5\"[^\n]*\\}\\}\\}\n````\\s*$")
})

# ---- controls: true of the package today ------------------------------------------------------------

test_that("control (N3, N60): the exceptions load from the package under test, and a passing @claim returns its value", {
  r <- jle_cases(c(
    paste('using Weft',
          'println(Weft.PublishError <: Exception, " ", Weft.ClaimFailed <: Exception)',
          'println(pathof(Weft))',
          sep = "\n"),
    'using Weft\nn = 7\nprintln(@claim n > 1)'
  ))
  lines <- strsplit(r[[1]]$out, "\n")[[1]]
  expect_identical(lines[1], "true true")
  expect_true(startsWith(normalizePath(lines[2]), jle_lib()))
  expect_identical(r[[2]]$out, "7\n")
})
