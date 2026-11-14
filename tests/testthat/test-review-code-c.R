# Regression tests for dev/review-code-c.md (the static lints and the enforcement tools), items 1 to 7, 10, 11, 12
# and 15, with the rulings at the end of that file. Each test is titled `review-code-c #<n>: ...`. A test that
# passes before the fix is a neighbour guard (a careless fix would break it) and says so in its comment.
# Helpers: helper-3.R, helper-3b.R, helper-4a.R, helper-4b.R, helper-4c.R, helper-4d.R. ASCII only (\u escapes).
# Everything runs in temporary folders and temporary git repositories.

# ---- shared pieces ----------------------------------------------------------------------------------------

rcc_ge <- new.env(parent = globalenv())
sys.source(test_path("_gate", "manuscript.R"), envir = rcc_ge)
sys.source(test_path("_gate", "edits.R"), envir = rcc_ge)

# a document that holds one `numeral` finding when `Site` is not a label word, and none when it is
RCC_SITE_DOC <- c("Intro words.", "", "Site 3 was wet.", G_ENGINE)
RCC_SITE2_DOC <- c("Intro words.", "", "Site 3 was wet.", "", "Site 4 was dry.", G_ENGINE)
RCC_QUIET_DOC <- c("Intro words.", "", "Nothing numeric here.", G_ENGINE)

rcc_numeral <- function(root, ...) lints(root, rules = "numeral", tier = 1:2, ...)

# ---- #1: verify() counts removals as the gate does ----------------------------------------------------------

test_that("review-code-c #1: a deleted claim() with an added value is a removal in verify(), as the gate says", {
  v4_env()
  before <- c("```{r chk}", "claim(x, . > 0)", "```", "", "Some words here.", G_ENGINE)
  after <- c("```{r chk}", "x <- 1", "```", "", "Some words `r x`{.num} here.", G_ENGINE)
  dir <- g_scenario(list("a.qmd" = before), list("a.qmd" = after))
  base <- g_head(dir)
  gate_res <- g_gate(dir)
  # neighbour guard (passes today): the gate demands a trailer, claims counted apart from values
  expect_false(gate_res$ok)
  expect_identical(gate_res$n_removed, 1L)
  g_commit(dir, "second")
  r <- v4_verify(dir, static = TRUE, since = base)
  x <- r$res$removed
  expect_identical(nrow(x), 1L)
  expect_identical(x$file, "a.qmd")
  expect_identical(x$kind, "claim")
  expect_match(x$text, "claim(x", fixed = TRUE)
})

test_that("review-code-c #1: a claim edited in place is not a removal, in the gate or in verify()", {
  # neighbour: the edit that a net count and the claims-apart count agree on
  v4_env()
  before <- c("```{r chk}", "claim(x, . > 0)", "```", "", "Some words here.", G_ENGINE)
  after <- c("```{r chk}", "claim(x, . > 1)", "```", "", "Some words here.", G_ENGINE)
  dir <- g_scenario(list("a.qmd" = before), list("a.qmd" = after))
  base <- g_head(dir)
  expect_identical(g_gate(dir)$n_removed, 0L)
  g_commit(dir, "second")
  r <- v4_verify(dir, static = TRUE, since = base)
  expect_identical(nrow(r$res$removed), 0L)
})

# the gate's n_removed and verify()'s removed rows agree, edit by edit (the edits of tests/testthat/_gate)
rcc_agree_ids <- c("E01", "E04", "E05", "E06", "E30", "E34", "E59", "E63", "X01")
for (id in rcc_agree_ids) local({
  id <- id
  e <- rcc_ge$EDITS[[id]]
  test_that(paste0("review-code-c #1: gate n_removed equals verify() removed for edit ", id), {
    v4_env()
    before <- c(rcc_ge$render_doc(rcc_ge$D0, 72), G_ENGINE)
    after <- c(rcc_ge$render_doc(e$f(rcc_ge$D0), e$width, e$hash_safe), G_ENGINE)
    dir <- g_scenario(list("ch1.qmd" = before), list("ch1.qmd" = after))
    base <- g_head(dir)
    n <- g_gate(dir)$n_removed
    expect_identical(n, rcc_ge$EXPECT[[id]]$n)         # the gate agrees with the hand answer
    g_commit(dir, "edit")
    r <- v4_verify(dir, static = TRUE, since = base)
    expect_identical(nrow(r$res$removed), n)
  })
})

# ---- #2: the innermost project's settings, in lints() and verify() -----------------------------------------

test_that("review-code-c #2: lints() of the parent reads a nested project's document with the nested settings", {
  root <- lint_proj(list("sub/_weft.yml" = "draft: false", "sub/x.qmd" = RCC_SITE_DOC, "top.qmd" = RCC_SITE_DOC),
                    weft_yml = "label_words: [Site]")
  # control (passes today): lints() at the nested project sees the numeral
  inner <- rcc_numeral(file.path(root, "sub"))
  expect_identical(nrow(inner), 1L)
  x <- rcc_numeral(root)
  # the nested document is judged by the nested _weft.yml (no label words): one finding, not doubled
  expect_identical(x$file, "sub/x.qmd")
  expect_identical(nrow(x), 1L)
  # the parent's own document is judged by the parent's settings (Site is a label word: none)
  expect_false("top.qmd" %in% x$file)
})

test_that("review-code-c #2: a label word of the nested project is not a finding when the parent is linted", {
  root <- lint_proj(list("sub/_weft.yml" = "label_words: [Site]", "sub/x.qmd" = RCC_SITE_DOC,
                         "top.qmd" = RCC_SITE_DOC),
                    weft_yml = "draft: false")
  x <- rcc_numeral(root)
  expect_identical(x$file, "top.qmd")
  expect_identical(nrow(x), 1L)
})

test_that("review-code-c #2: a setting that differs (numeral_years) decides by the inner _weft.yml", {
  yr <- c("Intro words.", "", "Rain fell in 2019.", G_ENGINE)
  root <- lint_proj(list("sub/_weft.yml" = "numeral_years: false", "sub/x.qmd" = yr, "top.qmd" = yr),
                    weft_yml = "numeral_years: true")
  x <- rcc_numeral(root)
  inner <- rcc_numeral(file.path(root, "sub"))
  # the nested project does not accept a year in prose (one finding); the parent does (none)
  expect_identical(nrow(inner), 1L)
  expect_identical(sum(x$file == "sub/x.qmd"), 1L)
  expect_identical(sum(x$file == "top.qmd"), 0L)
})

test_that("review-code-c #2: verify() of the parent judges a nested project's added line by the nested settings, as the gate does", {
  v4_env()
  before <- list("_weft.yml" = "label_words: [Site]", "sub/_weft.yml" = "draft: false", "sub/x.qmd" = RCC_QUIET_DOC)
  after <- list("sub/x.qmd" = RCC_SITE_DOC)
  dir <- g_scenario(before, after)
  base <- g_head(dir)
  g <- g_gate(dir)
  # neighbour guard (passes today): the gate refuses, one finding added
  expect_false(g$ok)
  expect_identical(nrow(g$added), 1L)
  g_commit(dir, "second")
  r <- v4_verify(dir, static = TRUE, since = base)
  expect_false(r$res$ok)
  expect_identical(nrow(r$res$added), 1L)
  expect_identical(r$res$added$file, "sub/x.qmd")
  expect_identical(r$res$added$rule, "numeral")
})

# ---- #3: changes() and git-quoted names ---------------------------------------------------------------------

rcc_quoted_names <- list(quote = "say \"hi\".qmd", tab = "tab\there.qmd", nonascii = "caf\u00e9.qmd")
for (nm in names(rcc_quoted_names)) local({
  nm <- nm
  fname <- rcc_quoted_names[[nm]]
  test_that(paste0("review-code-c #3: changes() lists a document whose name git quotes (", nm, ")"), {
    skip_on_os("windows")
    skip_if_no_git()
    skip_if_not(l10n_info()[["UTF-8"]], "needs a UTF-8 locale")
    v4_env()
    git_env()
    tmp <- withr::local_tempdir()
    ok <- tryCatch(file.create(file.path(tmp, enc2utf8(fname))), warning = function(w) FALSE, error = function(e) FALSE)
    skip_if(!isTRUE(ok) || !file.exists(file.path(tmp, enc2utf8(fname))), "the file system refuses this name")
    base <- c("# A {#sec-a}", "", "Opening text here.", "")
    sentence <- "Rain was highest again."
    before <- stats::setNames(list(base, base), c("plain.qmd", fname))
    after <- stats::setNames(list(c(base, sentence), c(base, sentence)), c("plain.qmd", fname))
    dir <- f3d_scenario(before, after)
    f <- changes(path = dir)$findings
    expect_true("plain.qmd" %in% f$file)             # control: the plain name is listed
    expect_true(fname %in% f$file, label = paste0("the name is listed (listed: ", paste(f$file, collapse = " | "), ")"))
    expect_true("claim-word" %in% f$rule[f$file == fname])
  })
})

# ---- #4: !expr in _weft.yml is never evaluated --------------------------------------------------------------

rcc_evil_yml <- function(marker) {
  sprintf("guard_words: !expr \"file.create('%s'); 12L\"", gsub("\\", "/", marker, fixed = TRUE))
}

test_that("review-code-c #4: lints() does not evaluate !expr in _weft.yml, even with yaml.eval.expr on", {
  marker <- file.path(withr::local_tempdir(), "lints-ran.txt")
  root <- lint_proj(list("a.qmd" = "Plain."), weft_yml = rcc_evil_yml(marker))
  withr::local_options(yaml.eval.expr = TRUE)
  try(suppressWarnings(suppressMessages(lints(root, tier = 1:2))), silent = TRUE)
  expect_false(file.exists(marker))
})

test_that("review-code-c #4: status() does not evaluate !expr in _weft.yml, even with yaml.eval.expr on", {
  marker <- file.path(withr::local_tempdir(), "status-ran.txt")
  dir <- u4_dir(list(`_weft.yml` = rcc_evil_yml(marker), `a.qmd` = u4_qmd()))
  withr::local_options(yaml.eval.expr = TRUE)
  try(h4_status(dir), silent = TRUE)
  expect_false(file.exists(marker))
})

test_that("review-code-c #4: with the default option nothing is evaluated either (neighbour guard)", {
  marker <- file.path(withr::local_tempdir(), "default-ran.txt")
  root <- lint_proj(list("a.qmd" = "Plain."), weft_yml = rcc_evil_yml(marker))
  withr::local_options(yaml.eval.expr = NULL)
  try(suppressWarnings(suppressMessages(lints(root, tier = 1:2))), silent = TRUE)
  expect_false(file.exists(marker))
})

# ---- #5: config-place flags every project-only setting -------------------------------------------------------

rcc_cp <- function(key, value = "true", weft_yml = "draft: false") {
  doc <- c("---", "title: T", "weft:", paste0("  ", key, ": ", value), "---", "", "Words.", G_ENGINE)
  lint_fixture(list("a.qmd" = doc), rules = "config-place", weft_yml = weft_yml)
}

test_that("review-code-c #5: verify_skip in a document's weft: is a config-place finding", {
  x <- rcc_cp("verify_skip", "[render]")
  expect_identical(nrow(x), 1L)
  expect_identical(x$text, "verify_skip")
  expect_identical(x$rule, "config-place")
})

test_that("review-code-c #5: draft and decisions are still flagged, and each of the three is its own finding", {
  # neighbour guard for draft and decisions (pass today)
  expect_identical(rcc_cp("draft")$text, "draft")
  expect_identical(rcc_cp("decisions")$text, "decisions")
  doc <- c("---", "title: T", "weft:", "  verify_skip: [render]", "  draft: true", "  decisions: true", "---", "",
           "Words.", G_ENGINE)
  x <- lint_fixture(list("a.qmd" = doc), rules = "config-place", weft_yml = "draft: false")
  expect_setequal(x$text, c("verify_skip", "draft", "decisions"))
  expect_identical(nrow(x), 3L)
})

test_that("review-code-c #5: a setting that belongs in a document's weft: is not flagged", {
  # neighbour guard (passes today): a fix must not flag every key
  expect_identical(nrow(rcc_cp("numeral_years")), 0L)
  expect_identical(nrow(rcc_cp("label_words", "[Site]")), 0L)
})

# ---- #6: block-start with list markers in a chunk -----------------------------------------------------------

rcc_bs <- function(lines, ext = "qmd") lint_one(lines, rules = "block-start", ext = ext)
RCC_INDENTED <- "    [3 sites]{n=\"k\"} here"

test_that("review-code-c #6: a list marker inside a chunk does not hide an indented construct after the chunk", {
  doc <- c("Intro words.", "", "```{r}", "- 1", "```", "", RCC_INDENTED)
  for (e in c("qmd", "Rmd")) {
    x <- rcc_bs(doc, e)
    expect_identical(nrow(x), 1L, info = e)
    expect_identical(x$line, 7L, info = e)
    expect_identical(x$rule, "block-start", info = e)
  }
})

test_that("review-code-c #6: a marker and a blank line inside the chunk, the construct later (neighbour guard, passes today)", {
  doc <- c("Intro words.", "", "```{r}", "x <- 1", "- 1", "", "```", "", "`r x` sheep", "", "    `r x` sheep")
  x <- rcc_bs(doc)
  expect_true(11L %in% x$line)
})

test_that("review-code-c #6: the same chunk without the marker line gives the finding (neighbour guard)", {
  doc <- c("Intro words.", "", "```{r}", "x <- 1", "```", "", RCC_INDENTED)
  x <- rcc_bs(doc)
  expect_identical(nrow(x), 1L)
  expect_identical(x$line, 7L)
})

test_that("review-code-c #6: a list really open in the prose still hides it (neighbour guard)", {
  doc <- c("Intro words.", "", "```{r}", "- 1", "```", "", "- item", "", RCC_INDENTED)
  expect_identical(nrow(rcc_bs(doc)), 0L)
  expect_identical(nrow(rcc_bs(c("- item", "", RCC_INDENTED))), 0L)
})

# ---- #7: tar-cache honours _quarto.yaml ---------------------------------------------------------------------

RCC_TAR_DOC <- c("Intro.", "", "```{r}", "x <- tar_read(fit)", "```")

test_that("review-code-c #7: execute: cache: true in _quarto.yaml makes a tar_read() a finding, as _quarto.yml does", {
  yml <- c("project:", "  type: default", "execute:", "  cache: true")
  # neighbour guard (passes today): the .yml spelling
  x <- lint_fixture(list("a.qmd" = RCC_TAR_DOC, "_quarto.yml" = yml), rules = "tar-cache")
  expect_identical(x$text, "fit")
  y <- lint_fixture(list("a.qmd" = RCC_TAR_DOC, "_quarto.yaml" = yml), rules = "tar-cache")
  expect_identical(y$text, "fit")
  expect_identical(y$rule, "tar-cache")
})

test_that("review-code-c #7: _quarto.yaml with no cache, or cache: false, gives none (neighbour guard)", {
  for (yml in list(c("project:", "  type: default"), c("execute:", "  cache: false"))) {
    x <- lint_fixture(list("a.qmd" = RCC_TAR_DOC, "_quarto.yaml" = yml), rules = "tar-cache")
    expect_identical(nrow(x), 0L)
  }
})

# ---- #10: status() and use_setup() agree about `engine: knitr` ----------------------------------------------

rcc_engine_dir <- function(front_line, env = parent.frame()) {
  doc <- c("---", "title: t", front_line, "---", "", "Some words.")
  h4_repo(list(`_quarto.yml` = U4_QUARTO_YML, `.Rprofile` = U4_RPROFILE, `a.qmd` = doc), weft = character(),
          origin = NULL, env = env)
}
rcc_engine_flagged <- function(st) grepl("engine", h4_detail(st, "activation"), fixed = TRUE)

for (front in c("engine: knitr", "\"engine\": knitr", "'engine': knitr", "engine: jupyter", "title2: x")) local({
  front <- front
  test_that(paste0("review-code-c #10: status() flags a.qmd for the engine exactly when use_setup() would write it (",
                   front, ")"), {
    dir <- rcc_engine_dir(front)
    before <- unname(tools::md5sum(file.path(dir, "a.qmd")))
    flagged_before <- rcc_engine_flagged(h4_status(dir))
    suppressMessages(utils::capture.output(weft::use_setup(dir)))
    changed <- !identical(unname(tools::md5sum(file.path(dir, "a.qmd"))), before)
    expect_identical(flagged_before, changed)
    # and once use_setup() has run, the engine is no longer a next step
    st <- h4_status(dir)
    expect_false(rcc_engine_flagged(st))
    expect_identical(h4_state(st, "activation"), "ok")
  })
})

# ---- #11: lints() and a formatters setting the render rejects -------------------------------------------------

test_that("review-code-c #11: a malformed formatters setting is refused by lints() as a weft_config_error, or noted", {
  root <- lint_proj(list("a.qmd" = "Plain."), weft_yml = "formatters: {mm: 5}")
  # the render refuses it (neighbour guard, passes today)
  e0 <- f2_cond(weft:::read_config(root))
  expect_false(is.null(e0))
  msgs <- character()
  err <- NULL
  res <- withCallingHandlers(
    tryCatch(lints(root, tier = 1:2), error = function(e) {
      err <<- e
      NULL
    }),
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    },
    warning = function(w) {
      msgs <<- c(msgs, conditionMessage(w))
      invokeRestart("muffleWarning")
    })
  noted <- length(msgs) > 0L || (!is.null(res) && length(attr(res, "notes")) > 0L)
  if (!is.null(err)) {
    f2_has_class(err, "weft_config_error")
    expect_match(conditionMessage(err), "mm", fixed = TRUE)
  } else {
    expect_true(noted, label = "lints() neither raised weft_config_error nor noted the setting")
  }
})

test_that("review-code-c #11: a well-formed formatters setting passes lints() unchanged (neighbour guard)", {
  yml <- c("formatters:", "  .compact:", "    function: base::toupper", "    stage: text")
  root <- lint_proj(list("a.qmd" = "Plain."), weft_yml = yml)
  expect_no_error(x <- lints(root, tier = 1:2))
  expect_identical(nrow(x), 0L)
})

test_that("review-code-c #11: the gate reads a malformed formatters as 'did not read', as for any other bad setting", {
  v4_env()
  dir <- g_scenario(list("a.qmd" = G_PROSE, "_weft.yml" = "draft: false"),
                    list("_weft.yml" = "formatters: {mm: 5}", "a.qmd" = c(G_PROSE, "", "More words.")))
  res <- tryCatch(g_gate(dir), error = function(e) e)
  # the gate must not pass the commit silently: it refuses, or it raises the same condition class
  if (inherits(res, "error")) {
    expect_s3_class(res, "weft_error")
  } else {
    expect_false(res$ok)
  }
})

# ---- #12: label_seed(paths) takes the project of the paths ---------------------------------------------------

test_that("review-code-c #12: label_seed(paths) reads the settings of the paths' project, not the working folder's", {
  a <- lint_proj(list("a.qmd" = RCC_SITE2_DOC))                # no label words
  b <- lint_proj(list("a.qmd" = RCC_SITE2_DOC), weft_yml = "label_words: [Site]")
  # from inside A, the documents of B are read with B's settings: Site is already a label word
  withr::local_dir(a)
  rb <- suppressMessages(label_seed(file.path(b, "a.qmd")))
  expect_false("Site" %in% rb$word)
  # neighbour guard (passes today): from inside B, B's own documents are read with B's settings
  withr::local_dir(b)
  rb2 <- suppressMessages(label_seed(file.path(b, "a.qmd")))
  expect_false("Site" %in% rb2$word)
})

test_that("review-code-c #12: the documents of a project with no label words list Site, wherever the working folder is", {
  a <- lint_proj(list("a.qmd" = RCC_SITE2_DOC))
  b <- lint_proj(list("a.qmd" = RCC_SITE2_DOC), weft_yml = "label_words: [Site]")
  withr::local_dir(b)
  ra <- suppressMessages(label_seed(file.path(a, "a.qmd")))
  expect_true("Site" %in% ra$word)
  # neighbour guard (passes today): with no paths, the working folder's project is used
  expect_false("Site" %in% suppressMessages(label_seed())$word)
  withr::local_dir(a)
  expect_true("Site" %in% suppressMessages(label_seed())$word)
})

# ---- #15: the version warning when the project records a newer weft -----------------------------------------

rcc_version_warning <- function(rec, env = parent.frame()) {
  v4_env(env = env)
  p <- v4_proj(list("a.qmd" = V4_PLAIN_DOC), weft_yml = c("draft: false", paste0("weft_version: ", rec)), env = env)
  w <- Filter(function(w) inherits(w, "weft_version_warning"), v4_verify(p$root, static = TRUE)$warnings)
  expect_length(w, 1L)
  cli::ansi_strip(conditionMessage(w[[1]]))
}

test_that("review-code-c #15: a project that records a newer weft is told to update weft, not to run an installer that downgrades", {
  rec <- "99.0.0"
  msg <- rcc_version_warning(rec)
  # the warning stays (H28) and names both versions
  expect_match(msg, rec, fixed = TRUE)
  expect_match(msg, v4_version(), fixed = TRUE)
  expect_match(msg, "older than")
  expect_match(msg, "update weft", ignore.case = TRUE)
  expect_match(msg, "take the project back", fixed = TRUE)
  expect_false(grepl("to update the files weft installed", msg, fixed = TRUE))
})

test_that("review-code-c #15: a project that records an older weft is still told to run use_weft() to update", {
  rec <- "0.0.0.1"
  expect_lt(utils::compareVersion(rec, v4_version()), 0L)
  expect_identical(rcc_version_warning(rec), v4_version_msg(rec))
})

test_that("review-code-c #15: use_weft() says it is a downgrade when the record is newer, and not when it is older", {
  newer <- h4_repo(list(`index.qmd` = u4_qmd(), `_weft.yml` = c("draft: false", "weft_version: 99.0.0")),
                   weft = character(), origin = "https://github.com/example-org/example-repo.git")
  withr::local_libpaths(h4_lib(), action = "prefix")
  s <- h4_say(weft::use_weft(newer))
  expect_match(s$text, "downgrade", ignore.case = TRUE)
  older <- h4_repo(list(`index.qmd` = u4_qmd(), `_weft.yml` = c("draft: false", "weft_version: 0.0.0.1")),
                   weft = character(), origin = "https://github.com/example-org/example-repo.git")
  s2 <- h4_say(weft::use_weft(older))
  expect_false(grepl("downgrade", s2$text, ignore.case = TRUE))
})

test_that("review-code-c #15: the helper's 'older template' version really is older than the installed weft", {
  forged <- eval(formals(h4_forge)$version)
  expect_lt(utils::compareVersion(forged, u4_version()), 0L)
})
