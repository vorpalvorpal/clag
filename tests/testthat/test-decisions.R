# Package 2c: the `decisions` setting and check_decisions(). Contract: dev/design-2c.md "The
# decision: resolver", rules 4.5.1-4.5.4, 9.1.4, 9.1.8, C26-C37. No test touches the network:
# every GitHub case passes a recording `fetch`; github_fetch() is tested with has_curl() mocked.
# Helpers: helper-2c.R.

COLS <- c("file", "line", "key", "decision", "resolved", "detail")
SETTING_MSG <- "The setting `decisions` must be `github`, `github:<owner>/<repo>`, a file pattern holding `{id}` (as decisions/{id}-*.md), or a function written pkg::fun; got `"

chk <- function(x, ...) weft:::check_decisions(x$dict, root = x$root, ...)

expect_row_types <- function(r) {
  expect_s3_class(r, "data.frame")
  expect_identical(names(r), COLS)
  expect_type(r$file, "character")
  expect_type(r$line, "integer")
  expect_type(r$key, "character")
  expect_type(r$decision, "character")
  expect_type(r$resolved, "logical")
  expect_type(r$detail, "character")
}

# ---- the setting -----------------------------------------------------------------------------

cfg_dir <- function(yml = NULL, env = parent.frame()) {
  c2_proj(if (is.null(yml)) list() else list(`_weft.yml` = yml), env)
}
cfg_of <- function(dir, front = list()) weft:::read_config(dir, front = front)

test_that("2c setting: decisions joins default_config() as github and does not warn as unknown (9.1.5, 9.1.8)", {
  withr::local_envvar(WEFT_DRAFT = NA)
  expect_true("decisions" %in% names(weft:::default_config()))
  expect_identical(weft:::default_config()$decisions, "github")
  expect_identical(cfg_of(cfg_dir())$decisions, "github")
})

test_that("2c setting: each of the four written forms is accepted by read_config() with no warning (9.1.8)", {
  withr::local_envvar(WEFT_DRAFT = NA)
  for (v in c("github", "github:example/proj", "github:Ex-1/pro.j_2", "decisions/{id}-*.md",
              "pkgname::fun", "fun", "my.fun_2")) {
    d <- cfg_dir(paste0("decisions: ", v))
    expect_no_warning(x <- cfg_of(d))
    expect_identical(x$decisions, v, label = v)
  }
})

test_that("2c setting: anything else is a weft_config_error naming the value and the four forms (9.1.8)", {
  withr::local_envvar(WEFT_DRAFT = NA)
  for (v in c("github:example", "'github:'", "github:a/b/c", "github:ex_ample/proj",
              "decisions/*.md", "1", "'a b'", "'github '", "''")) {
    e <- c2_err(cfg_of(cfg_dir(paste0("decisions: ", v))))
    c2_expect_cond(e, "weft_config_error")
    c2_expect_msg(e, SETTING_MSG, "(rule 9.1.8).")
  }
  e <- c2_err(cfg_of(cfg_dir("decisions: github:example")))
  c2_expect_msg(e, "got `github:example`")
})

test_that("2c setting: a list, or a number, is a weft_config_error (C26)", {
  withr::local_envvar(WEFT_DRAFT = NA)
  for (v in c("[github, github]", "{a: b}", "5", "true")) {
    e <- c2_err(cfg_of(cfg_dir(paste0("decisions: ", v))))
    c2_expect_cond(e, "weft_config_error")
    c2_expect_msg(e, "The setting `decisions` must be", "(rule 9.1.8)")
  }
})

test_that("2c setting: decisions in a document's front matter is a config error where _weft.yml exists, and accepted where it does not (9.1.4, C35)", {
  withr::local_envvar(WEFT_DRAFT = NA)
  d <- cfg_dir("digits: 1")
  e <- c2_err(cfg_of(d, front = list(decisions = "github")))
  c2_expect_cond(e, "weft_config_error")
  c2_expect_msg(e, "`decisions` is a project setting: set it in _weft.yml, not in a document's `weft:` front matter (rule 9.1.4).")
  d2 <- cfg_dir()
  expect_no_warning(x <- cfg_of(d2, front = list(decisions = "decisions/{id}-*.md")))
  expect_identical(x$decisions, "decisions/{id}-*.md")
})

test_that("2c setting: decisions_route() gives a list with a kind for each form and the config error for the rest (9.1.8)", {
  r <- lapply(c("github", "github:example/proj", "decisions/{id}-*.md", "pkgname::fun", "fun"),
              weft:::decisions_route)
  for (x in r) {
    expect_type(x, "list")
    expect_true(is.character(x$kind) && length(x$kind) == 1L && nzchar(x$kind))
  }
  kinds <- vapply(r, function(x) x$kind, "")
  expect_false(kinds[1] == kinds[3])
  expect_false(kinds[1] == kinds[4])
  expect_false(kinds[3] == kinds[4])
  for (v in list("github:example", "decisions/*.md", "1", c("github", "github"), NA_character_, 5, list("a"))) {
    e <- c2_err(weft:::decisions_route(v))
    c2_expect_cond(e, "weft_config_error")
    c2_expect_msg(e, "The setting `decisions` must be", "(rule 9.1.8)")
  }
})

test_that("2c setting: check_decisions() raises the same config error for a bad resolver (9.1.8)", {
  x <- c2_decision_dict(12)
  e <- c2_err(chk(x, resolver = "github:example", fetch = c2_no_fetch()))
  c2_expect_cond(e, "weft_config_error")
  c2_expect_msg(e, SETTING_MSG, "github:example")
})

# ---- no pointers -----------------------------------------------------------------------------

test_that("2c decisions: with no pointers there are zero typed rows and no call to fetch (4.5)", {
  c2_no_token()
  x <- c2_decision_dict(c(NA, NA))
  r <- chk(x, resolver = "github:example/proj", fetch = c2_no_fetch())
  expect_row_types(r)
  expect_identical(nrow(r), 0L)
  r2 <- chk(x, resolver = "decisions/{id}-*.md")
  expect_row_types(r2)
  expect_identical(nrow(r2), 0L)
  c2_expect_na_iff_detail(r)
})

# ---- GitHub with a recording fake fetch ------------------------------------------------------

REPO <- "example/proj"

test_that("2c github: pointers 12, 31, 12 and 'zones-2023' resolve as the contract says, with exactly the stated calls (4.5.3, C29, C30, C32)", {
  c2_no_token()
  x <- c2_decision_dict(list(12, 31, 12, "zones-2023"))
  f <- c2_fetch(setNames(list(200, 200, 200), c(REPO, paste0(REPO, "/issues/12"), paste0(REPO, "/issues/31"))))
  r <- chk(x, resolver = "github:example/proj", fetch = f$fetch)
  expect_row_types(r)
  expect_identical(r$key, c("a", "b", "c", "d"))
  expect_identical(r$decision, c("12", "31", "12", "zones-2023"))
  expect_identical(r$line, 1:4)
  expect_identical(r$file, rep(attr(x$dict, "file"), 4))
  expect_identical(r$resolved, c(TRUE, TRUE, TRUE, FALSE))
  expect_identical(r$detail, c("example/proj#12 exists", "example/proj#31 exists", "example/proj#12 exists",
                               "`zones-2023` is not an issue number; the github resolver takes whole numbers (rule 4.5.3)"))
  expect_identical(f$urls(), c("example/proj", "example/proj/issues/12", "example/proj/issues/31"))
  expect_identical(f$calls()[1], "https://api.github.com/repos/example/proj")
  expect_true(all(vapply(f$tokens(), is.null, TRUE)))
  c2_expect_na_iff_detail(r)
})

test_that("2c github: a pointer that is not a whole number is FALSE with no request, and with no number nothing else happens (C31)", {
  c2_no_token()
  x <- c2_decision_dict(list("zones-2023", "0", "012", "1.5", " 7", "-3"))
  r <- chk(x, resolver = "github:example/proj", fetch = c2_no_fetch())
  expect_identical(r$resolved, rep(FALSE, 6))
  expect_identical(r$detail, sprintf("`%s` is not an issue number; the github resolver takes whole numbers (rule 4.5.3)",
                                     c("zones-2023", "0", "012", "1.5", " 7", "-3")))
})

test_that("2c github: an issue that answers 404 is FALSE with its detail, one that answers 410 is NA (could not check, ruling D); a pull request or closed issue is just 200 (C30)", {
  c2_no_token()
  x <- c2_decision_dict(list(12, 99, 98))
  f <- c2_fetch(setNames(list(200, 200, 404, 410),
                         c(REPO, paste0(REPO, "/issues/12"), paste0(REPO, "/issues/99"), paste0(REPO, "/issues/98"))))
  r <- chk(x, resolver = "github:example/proj", fetch = f$fetch)
  expect_identical(r$resolved, c(TRUE, FALSE, NA))
  expect_identical(r$detail[1:2], c("example/proj#12 exists",
                                    "example/proj has no issue or pull request #99"))
  expect_true(startsWith(r$detail[3], "could not check: "))
  expect_identical(length(f$calls()), 4L)
  c2_expect_na_iff_detail(r)
})

test_that("2c github C28: a repository that answers 404 with no token makes every number row NA with the 'not visible' detail and one call (C28, C29)", {
  c2_no_token()
  x <- c2_decision_dict(list(12, "zones-2023", 31))
  f <- c2_fetch(setNames(list(404), REPO))
  r <- chk(x, resolver = "github:example/proj", fetch = f$fetch)
  detail <- "could not check: example/proj is not visible (private without a token, or misnamed); set GITHUB_PAT"
  expect_identical(r$resolved, c(NA, FALSE, NA))
  expect_identical(r$detail[c(1, 3)], c(detail, detail))
  expect_match(r$detail[2], "is not an issue number", fixed = TRUE)
  expect_identical(f$urls(), REPO)
  expect_null(f$tokens()[[1]])
  c2_expect_na_iff_detail(r)
})

test_that("2c github: with GITHUB_PAT set the token reaches fetch, the detail names the variable, and the token is never printed (4.5.3 step 2)", {
  withr::local_envvar(GITHUB_PAT = "tok-abc123-secret", GITHUB_TOKEN = NA)
  x <- c2_decision_dict(list(12))
  f <- c2_fetch(setNames(list(404), REPO))
  r <- chk(x, resolver = "github:example/proj", fetch = f$fetch)
  expect_identical(r$resolved, NA)
  expect_identical(r$detail, "could not check: example/proj is not visible with the token in GITHUB_PAT")
  expect_identical(f$tokens()[[1]], "tok-abc123-secret")
  expect_false(grepl("tok-abc123-secret", paste(r$detail, collapse = " "), fixed = TRUE))
  # the token goes with every call
  f2 <- c2_fetch(setNames(list(200, 200), c(REPO, paste0(REPO, "/issues/12"))))
  chk(x, resolver = "github:example/proj", fetch = f2$fetch)
  expect_identical(unlist(f2$tokens()), rep("tok-abc123-secret", 2))
})

test_that("2c github: an empty GITHUB_PAT with GITHUB_TOKEN set uses GITHUB_TOKEN and names it (4.5.3 step 2)", {
  withr::local_envvar(GITHUB_PAT = "", GITHUB_TOKEN = "tok-xyz789-secret")
  x <- c2_decision_dict(list(12))
  f <- c2_fetch(setNames(list(404), REPO))
  r <- chk(x, resolver = "github:example/proj", fetch = f$fetch)
  expect_identical(r$detail, "could not check: example/proj is not visible with the token in GITHUB_TOKEN")
  expect_identical(f$tokens()[[1]], "tok-xyz789-secret")
  expect_false(grepl("tok-xyz789-secret", r$detail, fixed = TRUE))
})

test_that("2c github: GITHUB_PAT is used before GITHUB_TOKEN when both are set (4.5.3 step 2)", {
  withr::local_envvar(GITHUB_PAT = "pat-one", GITHUB_TOKEN = "tok-two")
  x <- c2_decision_dict(list(12))
  f <- c2_fetch(setNames(list(401), REPO))
  r <- chk(x, resolver = "github:example/proj", fetch = f$fetch)
  expect_identical(f$tokens()[[1]], "pat-one")
  expect_identical(r$detail, "could not check: GitHub refused the token in GITHUB_PAT (401)")
})

test_that("2c github: 401 with GITHUB_TOKEN names that variable (4.5.3 results table)", {
  withr::local_envvar(GITHUB_PAT = NA, GITHUB_TOKEN = "tok-two")
  x <- c2_decision_dict(list(12))
  r <- chk(x, resolver = "github:example/proj", fetch = c2_fetch(setNames(list(401), REPO))$fetch)
  expect_identical(r$resolved, NA)
  expect_identical(r$detail, "could not check: GitHub refused the token in GITHUB_TOKEN (401)")
})

test_that("2c github: 403 and 429, with and without a token, give their details (4.5.3 results table)", {
  x <- c2_decision_dict(list(12))
  c2_no_token()
  for (st in c(403L, 429L)) {
    r <- chk(x, resolver = "github:example/proj", fetch = c2_fetch(setNames(list(st), REPO))$fetch)
    expect_identical(r$resolved, NA)
    expect_identical(r$detail, sprintf("could not check: GitHub refused the request (%d), usually its limit of 60 requests an hour without a token; set GITHUB_PAT", st))
  }
  withr::local_envvar(GITHUB_PAT = "tok-abc", GITHUB_TOKEN = NA)
  for (st in c(403L, 429L)) {
    r <- chk(x, resolver = "github:example/proj", fetch = c2_fetch(setNames(list(st), REPO))$fetch)
    expect_identical(r$detail, sprintf("could not check: GitHub refused the request (%d) with the token in GITHUB_PAT", st))
  }
})

test_that("2c github: a status NA with an error, and any other status, give their details (4.5.3 results table)", {
  c2_no_token()
  x <- c2_decision_dict(list(12))
  r <- chk(x, resolver = "github:example/proj",
           fetch = c2_fetch(setNames(list(list(status = NA, error = "Timeout was reached")), REPO))$fetch)
  expect_identical(r$resolved, NA)
  expect_identical(r$detail, "could not check: GitHub could not be reached (Timeout was reached)")
  r2 <- chk(x, resolver = "github:example/proj", fetch = c2_fetch(setNames(list(500), REPO))$fetch)
  expect_identical(r2$resolved, NA)
  expect_identical(r2$detail, "could not check: GitHub answered 500")
  r3 <- chk(x, resolver = "github:example/proj", fetch = c2_fetch(setNames(list(302), REPO))$fetch)
  expect_identical(r3$detail, "could not check: GitHub answered 302")
})

test_that("2c github C29: after a refusal at an issue, that row and every later number row are NA and no further call is made", {
  c2_no_token()
  x <- c2_decision_dict(list(12, 31, "words", 40, 41))
  f <- c2_fetch(setNames(list(200, 200, 403), c(REPO, paste0(REPO, "/issues/12"), paste0(REPO, "/issues/31"))))
  r <- chk(x, resolver = "github:example/proj", fetch = f$fetch)
  detail <- "could not check: GitHub refused the request (403), usually its limit of 60 requests an hour without a token; set GITHUB_PAT"
  expect_identical(r$resolved, c(TRUE, NA, FALSE, NA, NA))
  expect_identical(r$detail[c(2, 4, 5)], rep(detail, 3))
  expect_identical(f$urls(), c(REPO, paste0(REPO, "/issues/12"), paste0(REPO, "/issues/31")))
  c2_expect_na_iff_detail(r)
})

test_that("2c github C29: after an unreachable GitHub at an issue, the later numbers are NA with its detail and no more calls", {
  c2_no_token()
  x <- c2_decision_dict(list(12, 31))
  f <- c2_fetch(setNames(list(200, list(status = NA, error = "offline")), c(REPO, paste0(REPO, "/issues/12"))))
  r <- chk(x, resolver = "github:example/proj", fetch = f$fetch)
  expect_identical(r$resolved, c(NA, NA))
  expect_identical(r$detail, rep("could not check: GitHub could not be reached (offline)", 2))
  expect_length(f$calls(), 2L)
})

test_that("2c github: each distinct pointer is checked once per call and nothing is cached between calls (C32)", {
  c2_no_token()
  x <- c2_decision_dict(list(12, 12, 12))
  f <- c2_fetch(setNames(list(200, 200), c(REPO, paste0(REPO, "/issues/12"))))
  r <- chk(x, resolver = "github:example/proj", fetch = f$fetch)
  expect_identical(r$resolved, rep(TRUE, 3))
  expect_length(f$calls(), 2L)
  chk(x, resolver = "github:example/proj", fetch = f$fetch)
  expect_length(f$calls(), 4L)
})

test_that("2c github: resolved is NA exactly when the detail begins 'could not check: ', over every kind of row (4.5.4)", {
  c2_no_token()
  x <- c2_decision_dict(list(12, "zones-2023", 31))
  answers <- list(
    list(setNames(list(200, 200, 200), c(REPO, paste0(REPO, "/issues/12"), paste0(REPO, "/issues/31")))),
    list(setNames(list(200, 404, 410), c(REPO, paste0(REPO, "/issues/12"), paste0(REPO, "/issues/31")))),
    list(setNames(list(404), REPO)), list(setNames(list(401), REPO)),
    list(setNames(list(403), REPO)), list(setNames(list(429), REPO)),
    list(setNames(list(list(status = NA, error = "x")), REPO)), list(setNames(list(500), REPO)))
  for (a in answers) c2_expect_na_iff_detail(chk(x, resolver = "github:example/proj", fetch = c2_fetch(a[[1]])$fetch))
})

# ---- the repository from git -----------------------------------------------------------------

test_that("2c github: with resolver github the repository is read from `git remote get-url origin` (4.5.3 step 1)", {
  skip_if(Sys.which("git") == "")
  c2_no_token()
  for (remote in c("git@github.com:example/proj.git", "https://github.com/example/proj",
                   "https://user:pw@github.com/example/proj.git")) {
    root <- c2_git_repo(remote)
    writeLines("a: {value: 1, type: number, definition: x, decision: 12}", file.path(root, "dict.yml"))
    f <- c2_fetch(setNames(list(200, 200), c(REPO, paste0(REPO, "/issues/12"))))
    r <- weft:::check_decisions(read_dict(file.path(root, "dict.yml")), resolver = "github", root = root,
                                fetch = f$fetch)
    expect_identical(r$resolved, TRUE, label = remote)
    expect_identical(f$urls(), c(REPO, paste0(REPO, "/issues/12")), label = remote)
  }
})

test_that("2c github: with resolver NULL and no _weft.yml the route is github (9.1.5)", {
  skip_if(Sys.which("git") == "")
  c2_no_token()
  root <- c2_git_repo("git@github.com:example/proj.git")
  writeLines("a: {value: 1, type: number, definition: x, decision: 12}", file.path(root, "dict.yml"))
  f <- c2_fetch(setNames(list(200, 200), c(REPO, paste0(REPO, "/issues/12"))))
  r <- weft:::check_decisions(read_dict(file.path(root, "dict.yml")), root = root, fetch = f$fetch)
  expect_identical(r$resolved, TRUE)
})

test_that("2c github: no origin gives NA, 'no git remote `origin`', and no call (4.5.3 step 1)", {
  skip_if(Sys.which("git") == "")
  c2_no_token()
  root <- c2_git_repo(NULL)
  writeLines("a: {value: 1, type: number, definition: x, decision: 12}", file.path(root, "dict.yml"))
  r <- weft:::check_decisions(read_dict(file.path(root, "dict.yml")), resolver = "github", root = root,
                              fetch = c2_no_fetch())
  expect_identical(r$resolved, NA)
  expect_identical(r$detail, "could not check: no GitHub repository (no git remote `origin`); set decisions: github:<owner>/<repo> in _weft.yml")
})

test_that("2c github: an origin on another host gives NA and never prints the remote URL (4.5.3 step 1)", {
  skip_if(Sys.which("git") == "")
  c2_no_token()
  root <- c2_git_repo("https://sekrit-token-77@gitlab.example.org/example/proj.git")
  writeLines("a: {value: 1, type: number, definition: x, decision: 12}", file.path(root, "dict.yml"))
  r <- weft:::check_decisions(read_dict(file.path(root, "dict.yml")), resolver = "github", root = root,
                              fetch = c2_no_fetch())
  expect_identical(r$resolved, NA)
  expect_identical(r$detail, "could not check: no GitHub repository (the remote `origin` is not on github.com); set decisions: github:<owner>/<repo> in _weft.yml")
  expect_false(grepl("sekrit", paste(r$detail, collapse = " "), fixed = TRUE))
})

test_that("2c github: with git not installed (no git on PATH) every number row is NA with the 'git is not installed' detail (4.5.3 step 1)", {
  c2_no_token()
  x <- c2_decision_dict(list(12, "words"))
  withr::local_envvar(PATH = c2_proj())
  skip_if(nzchar(Sys.which("git")), "git is still found with an empty PATH")
  r <- chk(x, resolver = "github", fetch = c2_no_fetch())
  expect_identical(r$resolved, c(NA, FALSE))
  expect_identical(r$detail[1], "could not check: no GitHub repository (git is not installed); set decisions: github:<owner>/<repo> in _weft.yml")
})

# ---- parse_github_remote() -------------------------------------------------------------------

test_that("2c parse_github_remote: the accepted forms give owner and repo (4.5.3)", {
  want <- c(owner = "example", repo = "proj")
  for (u in c("https://github.com/example/proj", "https://github.com/example/proj.git",
              "https://github.com/example/proj/", "https://github.com/example/proj.git/",
              "http://github.com/example/proj", "https://www.github.com/example/proj",
              "http://www.github.com/example/proj.git",
              "https://user:pw@github.com/example/proj.git", "https://tok@github.com/example/proj",
              "git@github.com:example/proj", "git@github.com:example/proj.git",
              "ssh://git@github.com/example/proj.git", "ssh://git@github.com:22/example/proj.git",
              "ssh://git@github.com:2222/example/proj")) {
    expect_identical(weft:::parse_github_remote(u), want, label = u)
  }
})

test_that("2c parse_github_remote: another host, or a path that is not two parts, is NULL (4.5.3)", {
  for (u in c("https://gitlab.com/example/proj", "https://github.com/example", "https://github.com/",
              "https://github.com/example/proj/extra", "git@gitlab.com:example/proj.git",
              "https://notgithub.com/example/proj", "https://github.com.evil.example/example/proj",
              "", "not a url", "/local/path/to/repo")) {
    expect_null(weft:::parse_github_remote(u), label = u)
  }
})

# ---- github_fetch() with curl mocked absent --------------------------------------------------

test_that("2c github_fetch: with has_curl() FALSE it returns status NA and the install message with no request (C27)", {
  testthat::local_mocked_bindings(has_curl = function() FALSE, .package = "weft")
  r <- weft:::github_fetch("https://api.github.com/repos/example/proj", NULL)
  expect_identical(r$status, NA_integer_)
  expect_identical(r$error, "the curl package is not installed; install.packages(\"curl\")")
})

test_that("2c github_fetch: has_curl() is a single logical", {
  v <- weft:::has_curl()
  expect_type(v, "logical")
  expect_length(v, 1L)
})

test_that("2c github: with the default fetch and curl absent the row detail quotes the install message (C27)", {
  testthat::local_mocked_bindings(has_curl = function() FALSE, .package = "weft")
  c2_no_token()
  x <- c2_decision_dict(list(12))
  r <- chk(x, resolver = "github:example/proj")
  expect_identical(r$resolved, NA)
  expect_identical(r$detail, "could not check: GitHub could not be reached (the curl package is not installed; install.packages(\"curl\"))")
})

# ---- glob ------------------------------------------------------------------------------------

glob_project <- function(env = parent.frame()) {
  root <- c2_proj(list(`decisions/12-core.md` = "x", `decisions/121-other.md` = "x",
                       `decisions/dec-method-a.md` = "x", `decisions/dec-method-b.md` = "x",
                       `decisions/7-dir/keep.txt` = "x", `decisions/12/12.md` = "x"), env)
  root
}

glob_dict <- function(root, pointers) {
  lines <- vapply(seq_along(pointers), function(i) {
    sprintf("%s: {value: 1, type: number, definition: x, decision: \"%s\"}", letters[i],
            gsub("\\", "\\\\", pointers[i], fixed = TRUE))
  }, "")
  writeLines(lines, file.path(root, "dict.yml"))
  read_dict(file.path(root, "dict.yml"))
}

test_that("2c glob: pattern decisions/{id}-*.md resolves by file, a folder does not count, and the details are as stated (4.5.3, C33)", {
  root <- glob_project()
  d <- glob_dict(root, c("12", "121", "dec-method", "7", "99"))
  r <- weft:::check_decisions(d, resolver = "decisions/{id}-*.md", root = root, fetch = c2_no_fetch())
  expect_row_types(r)
  expect_identical(r$resolved, c(TRUE, TRUE, TRUE, FALSE, FALSE))
  expect_identical(r$detail, c("decisions/12-core.md", "decisions/121-other.md",
                               "decisions/dec-method-a.md and 1 more",
                               "no file matches decisions/7-*.md", "no file matches decisions/99-*.md"))
  c2_expect_na_iff_detail(r)
})

test_that("2c glob: a pointer holding * ? [ ] / or \\ is FALSE with the stated detail and matches nothing (4.5.3)", {
  root <- glob_project()
  ptrs <- c("a*b", "a?b", "a[b", "a]b", "../x", "a/b", "a\\b")
  d <- glob_dict(root, ptrs)
  r <- weft:::check_decisions(d, resolver = "decisions/{id}-*.md", root = root)
  expect_identical(r$resolved, rep(FALSE, length(ptrs)))
  expect_identical(r$detail, sprintf("`%s` holds a character a file pattern cannot match literally (* ? [ ] / \\)", ptrs))
})

test_that("2c glob C33: decisions/{id}*.md is a glob and nothing more, so 12 also matches 121-other.md (documented behaviour)", {
  root <- glob_project()
  d <- glob_dict(root, "12")
  r <- weft:::check_decisions(d, resolver = "decisions/{id}*.md", root = root)
  expect_identical(r$resolved, TRUE)
  expect_identical(r$detail, "decisions/12-core.md and 1 more")
  d2 <- glob_dict(root, "3")
  writeLines("", file.path(root, "decisions", "31-x.md"))
  r2 <- weft:::check_decisions(d2, resolver = "decisions/{id}*.md", root = root)
  expect_identical(r2$resolved, TRUE)
  expect_identical(r2$detail, "decisions/31-x.md")
  r3 <- weft:::check_decisions(d2, resolver = "decisions/{id}-*.md", root = root)
  expect_identical(r3$resolved, FALSE)
})

test_that("2c glob: every {id} is replaced, and an absolute pattern is used as it stands (4.5.3)", {
  root <- glob_project()
  d <- glob_dict(root, "12")
  r <- weft:::check_decisions(d, resolver = "decisions/{id}/{id}.md", root = root)
  expect_identical(r$resolved, TRUE)
  expect_identical(r$detail, "decisions/12/12.md")
  r2 <- weft:::check_decisions(d, resolver = file.path(root, "decisions", "{id}-*.md"), root = root)
  expect_identical(r2$resolved, TRUE)
})

test_that("2c glob: the glob needs no fetch, no git and writes nothing (4.5.3)", {
  root <- glob_project()
  d <- glob_dict(root, "12")
  before <- c2_tree(root)
  weft:::check_decisions(d, resolver = "decisions/{id}-*.md", root = root, fetch = c2_no_fetch())
  expect_identical(c2_tree(root), before)
})

# ---- function --------------------------------------------------------------------------------

global_fn <- function(name, fn, env = parent.frame()) {
  assign(name, fn, envir = globalenv())
  withr::defer(rm(list = name, envir = globalenv()), envir = env)
}

test_that("2c function: a global function of the id gives TRUE and FALSE with the stated details, called once per distinct pointer (4.5.3, C32)", {
  seen <- character()
  global_fn("c2_res_fn", function(id) { seen <<- c(seen, id); identical(id, "12") })
  x <- c2_decision_dict(list(12, 31, 12))
  r <- chk(x, resolver = "c2_res_fn", fetch = c2_no_fetch())
  expect_row_types(r)
  expect_identical(r$resolved, c(TRUE, FALSE, TRUE))
  expect_identical(r$detail, c("c2_res_fn returned TRUE", "c2_res_fn returned FALSE", "c2_res_fn returned TRUE"))
  expect_identical(seen, c("12", "31"))
})

test_that("2c function: NA is 'could not check', an error is 'failed' with the first line of its message (4.5.3)", {
  global_fn("c2_na_fn", function(id) NA)
  global_fn("c2_stop_fn", function(id) stop("boom\nsecond line"))
  x <- c2_decision_dict(list(12))
  r <- chk(x, resolver = "c2_na_fn")
  expect_identical(r$resolved, NA)
  expect_identical(r$detail, "could not check: c2_na_fn returned NA")
  r2 <- chk(x, resolver = "c2_stop_fn")
  expect_identical(r2$resolved, NA)
  expect_identical(r2$detail, "could not check: c2_stop_fn failed: boom")
  c2_expect_na_iff_detail(r)
  c2_expect_na_iff_detail(r2)
})

test_that("2c function: anything else is 'could not check' with a description of its class and length (4.5.3)", {
  global_fn("c2_chr_fn", function(id) "yes")
  global_fn("c2_num_fn", function(id) 1)
  global_fn("c2_vec_fn", function(id) c(TRUE, FALSE))
  x <- c2_decision_dict(list(12))
  r1 <- chk(x, resolver = "c2_chr_fn")
  expect_identical(r1$resolved, NA)
  expect_identical(r1$detail, "could not check: c2_chr_fn returned a character of length 1, not TRUE, FALSE or NA")
  expect_identical(chk(x, resolver = "c2_num_fn")$detail,
                   "could not check: c2_num_fn returned a numeric of length 1, not TRUE, FALSE or NA")
  expect_identical(chk(x, resolver = "c2_vec_fn")$detail,
                   "could not check: c2_vec_fn returned a logical of length 2, not TRUE, FALSE or NA")
})

test_that("2c function: pkg::fun is found in the package's namespace, and an unknown one is a weft_config_error (4.5.3, C34)", {
  x <- c2_decision_dict(list(12))
  r <- chk(x, resolver = "base::is.character", fetch = c2_no_fetch())
  expect_identical(r$resolved, TRUE)
  expect_identical(r$detail, "base::is.character returned TRUE")
  e <- c2_err(chk(x, resolver = "nopkg::f", fetch = c2_no_fetch()))
  c2_expect_cond(e, "weft_config_error")
  c2_expect_msg(e, "Cannot find the decisions function `nopkg::f` (rule 9.1.8).")
  e2 <- c2_err(chk(x, resolver = "base::no_such_function_here"))
  c2_expect_cond(e2, "weft_config_error")
  c2_expect_msg(e2, "Cannot find the decisions function `base::no_such_function_here` (rule 9.1.8).")
  e3 <- c2_err(chk(x, resolver = "c2_not_defined_anywhere"))
  c2_expect_cond(e3, "weft_config_error")
  c2_expect_msg(e3, "Cannot find the decisions function `c2_not_defined_anywhere` (rule 9.1.8).")
})

test_that("2c function: a name that looks like a typo of github is a function name, so it is a missing function (9.1.8)", {
  x <- c2_decision_dict(list(12))
  e <- c2_err(chk(x, resolver = "githb", fetch = c2_no_fetch()))
  c2_expect_cond(e, "weft_config_error")
  c2_expect_msg(e, "Cannot find the decisions function `githb` (rule 9.1.8).")
})

# ---- resolver = NULL -------------------------------------------------------------------------

test_that("2c resolver: NULL reads decisions from _weft.yml at the root (4.5, C36)", {
  root <- glob_project()
  writeLines("decisions: decisions/{id}-*.md", file.path(root, "_weft.yml"))
  d <- glob_dict(root, c("12", "7"))
  r <- weft:::check_decisions(d, root = root, fetch = c2_no_fetch())
  expect_identical(r$resolved, c(TRUE, FALSE))
  expect_identical(r$detail[1], "decisions/12-core.md")
})

test_that("2c resolver: with root NULL the root is the project root of the dictionary's file (4.5)", {
  root <- glob_project()
  writeLines("decisions: decisions/{id}-*.md", file.path(root, "_weft.yml"))
  dir.create(file.path(root, "sub"))
  writeLines("a: {value: 1, type: number, definition: x, decision: 12}", file.path(root, "sub", "dict.yml"))
  r <- weft:::check_decisions(read_dict(file.path(root, "sub", "dict.yml")), fetch = c2_no_fetch())
  expect_identical(r$resolved, TRUE)
  expect_identical(r$detail, "decisions/12-core.md")
})

test_that("2c resolver: an _weft.yml with a bad decisions is the config error, and an unreadable one is a weft_config_error (4.5)", {
  root <- c2_proj(list(`_weft.yml` = "decisions: github:example"))
  d <- glob_dict(root, "12")
  c2_expect_cond(c2_err(weft:::check_decisions(d, root = root, fetch = c2_no_fetch())), "weft_config_error")
  root2 <- c2_proj(list(`_weft.yml` = "decisions: [unclosed"))
  d2 <- glob_dict(root2, "12")
  c2_expect_cond(c2_err(weft:::check_decisions(d2, root = root2, fetch = c2_no_fetch())), "weft_config_error")
})

test_that("2c resolver: with no _weft.yml and no resolver the route is github (9.1.5)", {
  skip_if(Sys.which("git") == "")
  c2_no_token()
  root <- c2_proj()                                       # not a git repository
  d <- glob_dict(root, "12")
  r <- weft:::check_decisions(d, root = root, fetch = c2_no_fetch())
  expect_identical(r$resolved, NA)
  expect_match(r$detail, "^could not check: no GitHub repository \\(")
})

test_that("2c decisions: check_decisions() reads the fixture dictionary and its own pointers by glob (4.5, rule 4.5.1)", {
  root <- glob_project()
  file.copy(c2_fixture(), file.path(root, "dict.yml"))
  d <- read_dict(file.path(root, "dict.yml"))
  r <- weft:::check_decisions(d, resolver = "decisions/{id}-*.md", root = root)
  expect_identical(r$key, c("core_len", "method_change"))
  expect_identical(r$decision, c("12", "dec-method"))
  expect_identical(r$resolved, c(TRUE, TRUE))
  expect_identical(r$line, c(8L, 21L))
})
