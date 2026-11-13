# Package 6e: put() of the Python package, in a Jupyter kernel and with no back end (N20 to N22, N29, N48,
# N54, N70, N73, N6; messages E41 and E42 of dev/design-6.md section 7). Written before the code.
# Made-up values only. Helper: helper-jupyter.R. Skipped when quarto or a Python with jupyter_client and
# ipykernel is absent. One kernel session serves the kernel tests of this file.
#
# READINGS of the note (see the report, "Spec gaps"):
#  - the knitr half of put() (records handed to R's waiting names) is not tested: the note gives no
#    interface for it;
#  - the text of a `missing` record's `why` is not pinned (the classifier of stage 5 owns it);
#  - a keyword name that is not a NAME (only possible through **{...}) is not tested.

DOC_6E <- "doc.qmd"
RUN_RE <- function(run, values) {
  sprintf('^\\{"weft":1,"lang":"python","run":%s,"at":[0-9]+,"values":%s\\}$',
          if (is.null(run)) "null" else sprintf('"%s"', run), values)
}

put_session <- function() {
  if (!is.null(.jup$put_session)) return(.jup$put_session)
  .jup$put_session <- put_session_run()
}

put_session_run <- function() {
  root <- withr::local_tempdir(.local_envir = parent.frame())
  root <- normalizePath(root, winslash = "/")
  docdir <- file.path(root, "sub", "deeper")
  dir.create(docdir, recursive = TRUE)
  runfile <- file.path(root, ".weft", "run")
  w <- function(text) list(list(op = "write", path = runfile, text = text))
  rm <- list(list(op = "remove", path = runfile))
  cells <- list(
    # 1
    "import datetime, decimal\nfrom weft import put, WeftError, PublishError",
    # 2: the exact block of one value, and the return value
    "print(put(depth=3.14159))",
    # 3: every kind
    paste("put(i=42, neg=-7, f=0.1, b=True, s='Alpha', d=datetime.date(2026, 11, 13), big=2**70,",
          "dec=decimal.Decimal('1.50'), xs=[1, 2, 3], nothing_here=None, nan=float('nan'))"),
    # 4: a mapping and keywords in one call
    "put({'alpha': 1, 'beta': 'x'}, gamma=2)",
    # 5: a dot is an ordinary character in a name
    "put({'n.sites': 4})",
    # 6 to 9: a mapping that holds a bad key publishes nothing
    "put({'bad name': 1})",
    "put({'ok_name': 1, '1bad': 2})",
    "put({'missing': 1})",
    "put({'a' * 65: 1})",
    # 10: two calls, two blocks
    "put(one=1)\nput(two=2)",
    # 11: a value the classifier refuses is published as its error record
    "put(s={1, 2})",
    # 12, 13: the size of a list
    "try:\n    put(col=list(range(10001)))\nexcept PublishError as e:\n    print(type(e).__name__, isinstance(e, WeftError), isinstance(e, TypeError), str(e))",
    "put(col=list(range(100)))",
    # 14: exceptions are as N3 says
    "print(issubclass(PublishError, WeftError), issubclass(PublishError, TypeError), issubclass(WeftError, Exception))",
    # 15 to 22: the run id, read at each publish (N48)
    "put(r=1)",
    list(code = "put(r=1)", before = w("run-file-1\nsecond line is ignored\n")),
    list(code = "put(r=1)", before = w("run-file-2\n")),
    list(code = "put(r=1)", before = rm),
    "import os\nos.environ.pop('WEFT_RUN')\nput(r=1)",
    "os.environ['WEFT_RUN'] = 'run-env-2'\nput(r=1)",
    "os.environ['WEFT_RUN'] = ''\nput(r=1)",
    "put(r=1)"
  )
  t0 <- floor(as.numeric(Sys.time()))
  res <- jup_session(cells, env = list(WEFT_RUN = "run-env-1", QUARTO_DOCUMENT_PATH = docdir,
                                       QUARTO_DOCUMENT_FILE = DOC_6E))
  list(res = res, t0 = t0, t1 = ceiling(as.numeric(Sys.time())))
}

test_that("N70, N20, N21, N48: put() in a kernel displays one block, whose JSON is exact, and returns None", {
  s <- put_session()
  r <- s$res
  expect_identical(r[[1]]$status, "ok")
  expect_identical(r[[2]]$status, "ok")
  expect_identical(r[[2]]$stdout, "None\n")
  # one block, displayed as markdown, four backticks, class weft-values
  expect_length(r[[2]]$block_text, 1L)
  expect_match(r[[2]]$block_text, RUN_RE("run-env-1", '\\{"depth":\\{"t":"float","v":"3.14159"\\}\\}'))
  expect_identical(r[[2]]$kinds, "block")
  at <- as.numeric(sub('.*"at":([0-9]+),.*', "\\1", r[[2]]$block_text))
  expect_true(at >= s$t0 - 1 && at <= s$t1 + 1, label = "`at` is the time of the publish in whole seconds")
  b <- r[[2]]$blocks[[1]]
  expect_identical(as.integer(b$weft), 1L)
  expect_identical(b$lang, "python")
})

test_that("N70, N22: every kind of value becomes its record", {
  r <- put_session()$res
  expect_identical(r[[3]]$status, "ok")
  expect_length(r[[3]]$blocks, 1L)
  v <- r[[3]]$blocks[[1]]$values
  sc <- function(x) list(t = x$t, v = x$v)
  expect_identical(sc(v$i), list(t = "int", v = "42"))
  expect_identical(sc(v$neg), list(t = "int", v = "-7"))
  expect_identical(sc(v$f), list(t = "float", v = "0.1"))
  expect_identical(sc(v$b), list(t = "bool", v = TRUE))
  expect_identical(sc(v$s), list(t = "string", v = "Alpha"))
  expect_identical(sc(v$d), list(t = "date", v = "2026-11-13"))
  expect_identical(sc(v$dec), list(t = "decimal", v = "1.50"))
  # an int of any size is an int record: no refusal for size
  expect_identical(sc(v$big), list(t = "int", v = "1180591620717411303424"))
  expect_identical(v$xs$t, "list")
  expect_identical(v$xs$of, "int")
  expect_null(v$xs$keys)
  expect_identical(vapply(v$xs$v, function(e) paste(e$t, e$v), ""), c("int 1", "int 2", "int 3"))
  expect_identical(v$nothing_here$t, "missing")
  expect_identical(v$nan$t, "missing")
  expect_setequal(names(v), c("i", "neg", "f", "b", "s", "d", "big", "dec", "xs", "nothing_here", "nan"))
})

test_that("N70: a mapping given positionally and keywords publish together, in one block", {
  r <- put_session()$res
  expect_length(r[[4]]$blocks, 1L)
  v <- r[[4]]$blocks[[1]]$values
  expect_setequal(names(v), c("alpha", "beta", "gamma"))
  expect_identical(list(v$alpha$t, v$alpha$v), list("int", "1"))
  expect_identical(list(v$beta$t, v$beta$v), list("string", "x"))
  expect_identical(list(v$gamma$t, v$gamma$v), list("int", "2"))
  expect_match(r[[5]]$block_text, RUN_RE("run-env-1", '\\{"n\\.sites":\\{"t":"int","v":"4"\\}\\}'))
})

test_that("N70, E41: a mapping with a key that is not a NAME raises PublishError and publishes nothing", {
  r <- put_session()$res
  bad <- list(`6` = "bad name", `7` = "1bad", `8` = "missing", `9` = strrep("a", 65))
  for (k in names(bad)) {
    x <- r[[as.integer(k)]]
    expect_identical(x$status, "error", label = bad[[k]])
    expect_identical(x$ename, "PublishError", label = bad[[k]])
    expect_identical(x$evalue, e_msg$E41(bad[[k]]), label = bad[[k]])
    expect_length(x$blocks, 0L)
  }
})

test_that("N70: each call displays its own block", {
  r <- put_session()$res
  expect_length(r[[10]]$blocks, 2L)
  expect_identical(names(r[[10]]$blocks[[1]]$values), "one")
  expect_identical(names(r[[10]]$blocks[[2]]$values), "two")
})

test_that("N70, N43's reason: a value the classifier refuses is published as an error record", {
  r <- put_session()$res
  expect_identical(r[[11]]$status, "ok")
  expect_length(r[[11]]$blocks, 1L)
  rec <- r[[11]]$blocks[[1]]$values$s
  expect_identical(rec$t, "error")
  expect_true(is.character(rec$why) && nzchar(rec$why))
})

test_that("N29, E42, N3: a list of more than 10000 elements is refused with PublishError; a shorter one goes", {
  r <- put_session()$res
  expect_identical(r[[12]]$stdout, paste0("PublishError True True ", e_msg$E42("col", 10001L), "\n"))
  expect_length(r[[12]]$blocks, 0L)
  expect_length(r[[13]]$blocks, 1L)
  expect_identical(r[[13]]$blocks[[1]]$values$col$of, "int")
  expect_length(r[[13]]$blocks[[1]]$values$col$v, 100L)
  expect_identical(r[[14]]$stdout, "True True True\n")
})

test_that("N48: run is the first line of .weft/run found upward, else WEFT_RUN when not empty, else null; read at each publish", {
  r <- put_session()$res
  run <- function(i) {
    expect_length(r[[i]]$blocks, 1L)
    x <- r[[i]]$blocks[[1]]
    x$run
  }
  expect_identical(run(15), "run-env-1")
  expect_identical(run(16), "run-file-1")
  expect_identical(run(17), "run-file-2")
  expect_identical(run(18), "run-env-1")
  expect_null(run(19))
  expect_identical(run(20), "run-env-2")
  expect_null(run(21))
  expect_null(run(22))
  expect_match(r[[19]]$block_text, '"run":null', fixed = TRUE)
})

test_that("N70, N54, N73: with no back end (plain Python) the block's text is printed to stdout", {
  x <- py_plain(paste("from weft import put",
                      "r = put(depth=3.14159)",
                      "assert r is None",
                      sep = "\n"))
  expect_identical(x$status, 0L, label = x$stderr)
  expect_match(x$stdout, paste0("^````\\{\\.weft-values\\}\n",
                                '\\{"weft":1,"lang":"python","run":null,"at":[0-9]+,',
                                '"values":\\{"depth":\\{"t":"float","v":"3.14159"\\}\\}\\}\n````\\s*$'))
})

test_that("N73: an IPython shell with no kernel is no back end: put() prints the block's text", {
  x <- py_plain(paste("from IPython.core.interactiveshell import InteractiveShell",
                      "ip = InteractiveShell.instance()",
                      "ip.run_cell('from weft import put\\nput(depth=3.14159)')",
                      sep = "\n"))
  expect_identical(x$status, 0L, label = x$stderr)
  expect_match(x$stdout, "````{.weft-values}\n{\"weft\":1,\"lang\":\"python\",\"run\":null,", fixed = TRUE)
  expect_match(x$stdout, "\"values\":{\"depth\":{\"t\":\"float\",\"v\":\"3.14159\"}}}\n````", fixed = TRUE)
})

# ---- controls: true of the package today ------------------------------------------------------------

test_that("control (N3, N60): the exceptions and put are importable, and the package is the one under test", {
  x <- py_plain(paste("import weft",
                      "from weft import put, auto, claim, WeftError, ClaimFailed, PublishError",
                      "print(weft.__weft_package__, issubclass(PublishError, TypeError), issubclass(ClaimFailed, AssertionError))",
                      "print(weft.__file__)",
                      sep = "\n"))
  expect_identical(x$status, 0L, label = x$stderr)
  lines <- strsplit(x$stdout, "\n")[[1]]
  expect_identical(lines[1], "True True True")
  expect_true(startsWith(normalizePath(lines[2]), py_lib_6e()))
})
