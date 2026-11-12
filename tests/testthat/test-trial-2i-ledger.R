# 2i In: I10 (dev/design-2i.md): `ledger: false` in _weft.yml or in a document's `weft:` front matter turns
# the ledger and the condition log off. Non-ASCII is written as \uXXXX. Made-up values only.
if (!exists("i2_run")) source(Filter(file.exists, c(testthat::test_path("helper-2i.R"), testthat::test_path("..", "helper-2i.R")))[[1]])

I2_DOC <- c("Of the `r n_sites` sites, `r len`{.num} was the reach.")
I2_CODE <- c("n_sites <- 14", "len <- u(1500, m)")

# a knit of I2_DOC in a project whose _weft.yml holds `yml` (and whose front matter holds `front`)
i2_knit <- function(yml, front = NULL, extra = NULL) {
  files <- list("_weft.yml" = yml)
  d2_run(I2_DOC, set_up = FALSE, files = files, code = I2_CODE, front = front, env = c(WEFT_DRAFT = NA))
}

test_that("2i I10: control - a set-up project writes the ledger and the condition log, by default and with `ledger: true`", {
  for (yml in list("draft: false", c("draft: false", "ledger: true"))) {
    res <- i2_knit(yml)
    expect_false(res$failed)
    expect_true(file.exists(d2_path(res$dir)), label = paste(yml, collapse = " "))
    expect_true(file.exists(d2_path(res$dir, conditions = TRUE)))
    expect_identical(unname(res$knit$written), c("_weft/ledger/doc.Rmd/doc.jsonl", "_weft/ledger/doc.Rmd/doc.conditions.jsonl"))
  }
})

test_that("2i I10: `ledger: false` in _weft.yml writes no _weft/ledger folder, and last_knit()$written is NA twice", {
  res <- i2_knit(c("draft: false", "ledger: false"))
  expect_false(res$failed)
  expect_false(dir.exists(file.path(res$dir, "_weft", "ledger")))
  expect_false(dir.exists(file.path(res$dir, "_weft")))
  expect_identical(res$knit$written, c(ledger = NA_character_, conditions = NA_character_))
})

test_that("2i I10: `units:` rows in the same _weft.yml still work with the ledger off", {
  res2 <- d2_run("`r u(3, zzsite)`{.num} were seen.", set_up = FALSE,
                 files = list("_weft.yml" = c("draft: false", "ledger: false", "units:", "  zzsite:", "    name: site", "    symbol: false")),
                 env = c(WEFT_DRAFT = NA))
  expect_false(res2$failed)
  expect_false(dir.exists(file.path(res2$dir, "_weft", "ledger")))
  expect_identical(res2$knit$written, c(ledger = NA_character_, conditions = NA_character_))
  expect_true(any(grepl("3[ \u00a0]sites", readLines(file.path(res2$dir, "doc.md"), encoding = "UTF-8"))))
})

test_that("2i I10: `ledger: false` in the document's `weft:` front matter turns it off in a set-up project", {
  res <- i2_knit("draft: false", front = c("weft:", "  ledger: false"))
  expect_false(res$failed)
  expect_false(dir.exists(file.path(res$dir, "_weft", "ledger")))
  expect_identical(res$knit$written, c(ledger = NA_character_, conditions = NA_character_))
})

test_that("2i I10: a value that is not a logical is a weft_config_error, in _weft.yml and in front matter", {
  for (v in c("maybe", "1", "\"false\"", "[true]", "auto")) {
    e <- g2_cfg_err(paste0("ledger: ", v))
    f2_has_class(e, "weft_config_error")
    f2_msg_has(e, "ledger")
  }
  for (v in list("maybe", 1, "false", c(TRUE, FALSE))) {
    e <- g2_cfg_err(NULL, front = list(ledger = v))
    f2_has_class(e, "weft_config_error")
    f2_msg_has(e, "ledger")
  }
})

test_that("2i I10: control - a logical value is no error in either place", {
  expect_null(g2_cfg_err("ledger: false"))
  expect_null(g2_cfg_err("ledger: true"))
  expect_null(g2_cfg_err(NULL, front = list(ledger = FALSE)))
})
