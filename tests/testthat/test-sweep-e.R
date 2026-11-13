# Sweep package E1 (dev/refactor-sweep.md): the drains of the Python and Julia guests no longer swallow a reply
# that is not JSON. No interpreter is started: the guest is mocked.

test_that("E1: guest_drain_json() returns the parsed value of a good reply", {
  guest_probe_drain <- function() "[[\"warning\", \"text\"], [\"error\", \"more\"]]"
  got <- weft:::guest_drain_json(guest_probe_drain())
  expect_identical(got, list(list("warning", "text"), list("error", "more")))
})

test_that("E1: guest_drain_json() returns an empty result when the guest is not running", {
  # a call that finds no guest to ask: it fails, or it answers nothing
  expect_length(weft:::guest_drain_json(stop("the guest is not running")), 0L)
  expect_length(weft:::guest_drain_json(NULL), 0L)
})

test_that("E1: guest_drain_json() raises a weft_guest_error naming the drain when the reply is not JSON", {
  guest_probe_drain <- function() "{this is not json"
  err <- tryCatch(weft:::guest_drain_json(guest_probe_drain()), error = function(e) e)
  expect_s3_class(err, "weft_guest_error")
  expect_match(conditionMessage(err), "drain", ignore.case = TRUE)
})

# ---- the drains, with the guest mocked -----------------------------------------------------------------------

# Python: weft_env$guest_mod holds a stand-in whose drain returns `txt`, and reticulate's conversion is the
# identity, so no interpreter starts.
e1_mock_python <- function(txt, env = parent.frame()) {
  we <- weft:::weft_env
  old <- we$guest_mod
  we$guest_mod <- list(drain_warnings = function() txt, project_modules = function(root) txt)
  withr::defer(we$guest_mod <- old, envir = env)
  testthat::local_mocked_bindings(guest_running = function() TRUE, .env = env, .package = "weft")
  testthat::local_mocked_bindings(py_to_r = function(x) x, .env = env, .package = "reticulate")
}

# Julia: julia_running() says yes and JuliaCall::julia_call() returns `txt`.
e1_mock_julia <- function(txt, env = parent.frame()) {
  testthat::skip_if_not_installed("JuliaCall")
  testthat::local_mocked_bindings(julia_running = function() TRUE, .env = env, .package = "weft")
  testthat::local_mocked_bindings(julia_call = function(...) txt, .env = env, .package = "JuliaCall")
}

test_that("E1: the Python warnings drain still returns a good reply", {
  e1_mock_python("[\"UserWarning: a\", \"UserWarning: b\"]")
  expect_identical(weft:::guest_drain_warnings(), c("UserWarning: a", "UserWarning: b"))
})

test_that("E1: the Python warnings drain raises a weft_guest_error for a reply that is not JSON", {
  e1_mock_python("not json at all")
  expect_error(weft:::guest_drain_warnings(), class = "weft_guest_error")
})

test_that("E1: the Python project-modules drain raises a weft_guest_error for a reply that is not JSON", {
  e1_mock_python("[\"a.py\"")
  expect_error(weft:::guest_project_modules("/tmp"), class = "weft_guest_error")
})

test_that("E1: the Julia log drain still returns a good reply", {
  e1_mock_julia("[[\"warning\", \"w\"]]")
  expect_identical(weft:::julia_drain(), list(list(class = "warning", text = "w")))
})

test_that("E1: the Julia log drain raises a weft_guest_error for a reply that is not JSON", {
  e1_mock_julia("<<not json>>")
  expect_error(weft:::julia_drain(), class = "weft_guest_error")
})

test_that("E1: the Julia included-files drain raises a weft_guest_error for a reply that is not JSON", {
  e1_mock_julia("[\"a.jl\"")
  expect_error(weft:::julia_project_files("/tmp"), class = "weft_guest_error")
})

test_that("E1: the Julia puts drain raises a weft_guest_error for a reply that is not JSON", {
  e1_mock_julia("{{")
  expect_error(weft:::julia_take_puts(new.env()), class = "weft_guest_error")
})
