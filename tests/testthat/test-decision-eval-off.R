# A decision pointer on a claim() in an R chunk that is statically not evaluated is not collected (owner's
# ruling; rules 1.8.12, 3.1.12, 4.5.5, 8 `decisions` part; code: decision_pointer_rows() in R/constructs.R,
# verify_decisions() in R/verify.R). "Statically not evaluated" is the claims rule's own test (rule G11/G35,
# N59; test-findings-s6.R F2): a literal `eval: false` / `eval = FALSE` / `F` in the header or a `#|` line.
# A non-literal `eval = flag` counts as evaluated, a `#|` line beats the header, document-level
# `execute: eval: false` is not read. Made-up content.

de_chunk <- function(hdr = character(), pipe = character(), code = "n <- claim(n, . > 0, decision = 12)",
                     engine = "r") {
  c(paste0("```{", engine, if (length(hdr)) paste0(" ", hdr), "}"), pipe, code, "```")
}
de_doc <- function(...) c("Intro.", "", de_chunk(...), "", "End.")
de_rows <- function(doc) weft:::decision_pointer_rows(read_src(doc))

# the same spellings as F2_SPELLINGS (test-findings-s6.R): n = pointers collected
DE_SPELLINGS <- list(
  list(pipe = "#| eval: false", n = 0L),
  list(pipe = "#| eval: FALSE", n = 0L),
  list(pipe = "#| eval: no", n = 0L),
  list(pipe = "#| eval: !expr FALSE", n = 0L),
  list(pipe = "#| eval: false # why", n = 0L),
  list(hdr = ",eval=FALSE", n = 0L),
  list(hdr = ",eval = FALSE", n = 0L),
  list(hdr = ",eval=F", n = 0L),
  list(hdr = ",eval = F", n = 0L),
  list(hdr = "eval=FALSE", n = 0L),
  list(hdr = ",eval=FALSE", pipe = "#| eval: true", n = 1L),
  list(pipe = "#| eval: true", n = 1L),
  list(pipe = "#| eval: !expr flag", n = 1L),
  list(hdr = ",eval=flag", n = 1L),
  list(hdr = ",eval=TRUE", n = 1L))

test_that("1.8.12, 3.1.12, 4.5.5: an evaluated chunk's literal decision is collected (control)", {
  d <- de_doc()
  rows <- de_rows(d)
  expect_identical(nrow(rows), 1L)
  expect_identical(rows$key, "claim()")
  expect_identical(rows$decision, "12")
  expect_identical(rows$line, dp_line(d, "decision = 12"))
  expect_identical(nrow(de_rows(de_doc(hdr = "label1"))), 1L)
})

test_that("1.8.12, 3.1.12, 4.5.5: a statically false eval, in every spelling the claims rule reads, drops the pointer; the rest keep it", {
  for (sp in DE_SPELLINGS) {
    rows <- de_rows(de_doc(hdr = sp$hdr %||% character(), pipe = sp$pipe %||% character()))
    expect_identical(nrow(rows), sp$n, info = paste(sp$hdr, sp$pipe))
  }
})

test_that("1.8.12, 4.5.5: a non-literal eval counts as evaluated, so the pointer is collected", {
  for (sp in list(list(hdr = ",eval=flag"), list(pipe = "#| eval: !expr flag"), list(hdr = ",eval=!is_draft"))) {
    rows <- de_rows(de_doc(hdr = sp$hdr %||% character(), pipe = sp$pipe %||% character()))
    expect_identical(rows$decision, "12", info = paste(sp$hdr, sp$pipe))
  }
})

test_that("1.8.12, 4.5.5: document-level execute: eval: false and opts_chunk$set(eval = FALSE) are not read, so the pointer stays", {
  front <- c("---", "execute:", "  eval: false", "---", "")
  setup <- c("```{r setup}", "knitr::opts_chunk$set(eval = FALSE)", "```", "")
  expect_identical(de_rows(c(front, de_chunk()))$decision, "12")
  expect_identical(de_rows(c("Intro.", "", setup, de_chunk()))$decision, "12")
})

test_that("1.8.12, 4.5.5: only the unevaluated chunk is dropped; an evaluated chunk and a #| eval: true chunk beside it keep their pointers", {
  d <- c("Intro.", "",
         de_chunk(pipe = "#| eval: false", code = "a <- claim(n, . > 0, decision = 31)"), "",
         de_chunk(code = "b <- claim(n, . > 0, decision = 12)"), "",
         de_chunk(hdr = ",eval=FALSE", pipe = "#| eval: true", code = "c <- claim(n, . > 0, decision = 7)"))
  rows <- de_rows(d)
  expect_identical(rows$decision, c("12", "7"))
  expect_identical(rows$line, c(dp_line(d, "decision = 12"), dp_line(d, "decision = 7")))
})

test_that("1.8.12, 4.5.5: inline claim() is unaffected by a chunk's eval option, and so is a prose pointer beside an unevaluated chunk", {
  prose <- c("Filtered through [0.45]{.weft-literal why=\"method\" decision=\"12\"} membranes and",
             "[10 m]{cite=\"@smith2020\" decision=\"31\"} deep, with `r claim(n, . > 0, decision = \"7\")` here.")
  for (pipe in list(character(), "#| eval: false")) {
    d <- c(prose, "", de_chunk(pipe = pipe, code = "x <- claim(n, . > 0, decision = 99)"))
    rows <- de_rows(d)
    expected <- c("12", "31", "7", if (!length(pipe)) "99")
    expect_setequal(rows$decision, expected)
    expect_true(all(c(".weft-literal", "cite=\"@smith2020\"") %in% rows$key), info = paste(pipe, collapse = " "))
  }
})

test_that("1.8.12, 4.5.5: a guest chunk's claim carries no decision pointer either way (as for the claims rule's R/guest split)", {
  # READING: claim_decisions() reads R code only (the engine test in decision_pointer_rows()), so a Python
  # chunk gives no row evaluated or not; the ruling leaves that as it is.
  for (pipe in list(character(), "#| eval: false")) {
    d <- de_doc(engine = "python", pipe = pipe, code = "claim(n, \"> 0\", decision=12)")
    expect_identical(nrow(de_rows(d)), 0L, info = paste(pipe, collapse = " "))
  }
})

# ---- verify(): the pointer is checked against the record only when collected ----------------------------------

de_verify <- function(doc, extra = list()) {
  v4_env()
  p <- v4_proj(c(list("a.qmd" = doc), extra, DP_FILES), git = TRUE, weft_yml = DP_YML)
  v4_verify(p$root, static = TRUE)
}

test_that("4.5.4, 4.5.5, 8: a pointer to a missing decision fails verify() when its chunk is evaluated, and is no finding when it is not", {
  hdrs <- list(list(pipe = "#| eval: false"), list(hdr = ",eval=FALSE"), list(hdr = ",eval=F"))
  on <- de_verify(de_doc(code = "n <- claim(n, . > 0, decision = 99)"))
  dp_expect_failed(on)
  expect_identical(v4_status(on$res, "decisions"), "failed")
  expect_identical(dp_rows(on$res)$decision, "99")
  expect_identical(dp_rows(on$res)$resolved, FALSE)
  for (sp in hdrs) {
    off <- de_verify(de_doc(hdr = sp$hdr %||% character(), pipe = sp$pipe %||% character(),
                            code = "n <- claim(n, . > 0, decision = 99)"))
    dp_expect_passed(off)
    expect_false(any(dp_rows(off$value)$decision == "99"), info = paste(sp$hdr, sp$pipe))
  }
})

test_that("4.5.5, 8: with the only pointer in an unevaluated chunk the decisions part is skipped, with its own reason", {
  on <- de_verify(de_doc())
  dp_expect_passed(on)
  expect_identical(v4_status(on$value, "decisions"), "ran")
  expect_identical(nrow(dp_rows(on$value)), 1L)
  off <- de_verify(de_doc(pipe = "#| eval: false"))
  dp_expect_passed(off)
  expect_identical(v4_status(off$value, "decisions"), "skipped")
  expect_identical(v4_detail(off$value, "decisions"), "skipped: no decision pointers")
})

test_that("4.5.5, 8: a decision referenced only from an unevaluated chunk is not among the document pointers; a prose pointer to it still is", {
  # READING: the specification has no report of unreferenced decisions and R/ has none: the nearest
  # observable is the `decisions` table of verify() (which pointers there are). "Referenced only from an
  # unevaluated chunk" therefore means no row for that decision in that table.
  chunk31 <- de_chunk(pipe = "#| eval: false", code = "a <- claim(n, . > 0, decision = 31)")
  base <- c("Prose [0.45]{.weft-literal why=\"method\" decision=\"12\"} here.", "")
  off <- de_verify(c(base, chunk31))
  dp_expect_passed(off)
  expect_identical(dp_rows(off$value)$decision, "12")
  prose31 <- c(base, "Also [10 m]{.weft-literal why=\"rule\" decision=\"31\"} here.", "", chunk31)
  both <- de_verify(prose31)
  dp_expect_passed(both)
  expect_identical(sort(dp_rows(both$value)$decision), c("12", "31"))
  on31 <- de_verify(c(base, de_chunk(code = "a <- claim(n, . > 0, decision = 31)")))
  expect_identical(sort(dp_rows(on31$value)$decision), c("12", "31"))
})
