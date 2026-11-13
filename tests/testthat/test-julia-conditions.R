# Stage 5J-b: Julia conditions in the condition log and the severity list (J3,
# J17 to J20, 2.12.18, 7.4). Julia's @warn and @error reach weft through the
# logger it registers (J16); @info, @debug and standard error do not. Documents
# are knitted in this process in a set-up project (`_weft.yml`), so the
# condition log is a file. The helpers of helper-2d.R (d2_path(), d2_lines(),
# d2_conds(), d2_pick()) read it. Messages carry no digits, so that
# normalising (7.4.5) leaves them as written. Julia is shared by the file.

WY <- "draft: false"

cond_path <- function(dir) d2_path(dir, conditions = TRUE)

cond_main <- function() {
  if (is.null(.w5j$cond)) {
    lines <- c(
      "```{julia j3}",
      "@warn \"fit did not converge\"",
      "```", "",
      "```{julia jerr}",
      "@error \"bad thing\"",
      "```", "",
      "```{julia jkv}",
      "@warn \"with pairs\" depth = 3 note = \"z\"",
      "```", "",
      "```{julia jloop}",
      "for i in 1:3",
      "    @warn \"loop once\" maxlog = 1",
      "end",
      "```", "",
      "```{julia jinfo}",
      "using Logging",
      "@info \"info text\"",
      "@debug \"debug text\"",
      "println(stderr, \"stderr text\")",
      "with_logger(NullLogger()) do",
      "    @warn \"hidden warning\"",
      "end",
      "```", "",
      "```{julia jinc}",
      "include(\"warner.jl\")",
      "```", "",
      "```{r rw}",
      "JuliaCall::julia_command(\"@warn \\\"from r chunk\\\"\")",
      "```", "",
      "Prose `r JuliaCall::julia_eval(\"begin; @warn \\\"from prose\\\"; 3; end\")` here.", "")
    .w5j$cond <- k5j(lines, weft_yml = WY,
                     files = list("warner.jl" = c("@warn \"from included file\"", "t_j5c_inc = 1")))
  }
  .w5j$cond
}

cond_texts <- function(res) vapply(d2_conds(res), `[[`, "", "text")

test_that("the condition document knits to its end", {
  res <- cond_main()
  expect_false(res$failed, label = res$message)
})

test_that("J3: @warn in chunk j3 is one line with from, source, class, normalised and text, exactly", {
  res <- cond_main()
  ln <- d2_lines(cond_path(res$dir))
  expect_true(paste0("{\"from\":\"chunk\",\"source\":\"j3\",\"class\":\"warning\",",
                     "\"normalised\":\"fit did not converge\",\"text\":\"fit did not converge\"}") %in% ln)
})

test_that("J3: last_knit() holds the row too", {
  res <- cond_main()
  cd <- res$conditions
  hit <- cd[cd$source == "j3" & cd$class == "warning", , drop = FALSE]
  expect_equal(nrow(hit), 1L)
  expect_identical(hit$text, "fit did not converge")
  cl <- res$cond
  hit <- cl[cl$from == "chunk" & cl$source == "j3" & cl$class == "warning", , drop = FALSE]
  expect_equal(nrow(hit), 1L)
  expect_identical(hit$normalised, "fit did not converge")
})

test_that("J3: an @error line is of class error, and the knit goes on", {
  res <- cond_main()
  c <- d2_conds(res)
  expect_length(d2_pick(c, from = "chunk", source = "jerr", class = "error", text = "bad thing"), 1L)
  expect_false(res$failed)
})

test_that("J3: the key and value pairs after the message are not part of its text", {
  res <- cond_main()
  c <- d2_conds(res)
  expect_length(d2_pick(c, from = "chunk", source = "jkv", class = "warning", text = "with pairs"), 1L)
  expect_false(any(grepl("depth", cond_texts(res), fixed = TRUE)))
})

test_that("J3: a warning raised inside an included file is logged on the including chunk", {
  res <- cond_main()
  c <- d2_conds(res)
  expect_length(d2_pick(c, from = "chunk", source = "jinc", class = "warning", text = "from included file"), 1L)
})

test_that("J3: Julia code an R chunk calls through JuliaCall::julia_command() is logged on that R chunk", {
  res <- cond_main()
  c <- d2_conds(res)
  expect_length(d2_pick(c, from = "chunk", source = "rw", class = "warning", text = "from r chunk"), 1L)
})

test_that("J3: Julia code a prose expression calls is logged as from prose", {
  res <- cond_main()
  c <- d2_conds(res)
  hit <- d2_pick(c, from = "prose", class = "warning", text = "from prose")
  expect_length(hit, 1L)
  expect_match(hit[[1]]$source, "^doc\\.Rmd")
})

test_that("J3: maxlog = 1 in a loop of three gives one line", {
  res <- cond_main()
  c <- d2_conds(res)
  expect_length(d2_pick(c, source = "jloop", text = "loop once"), 1L)
  expect_equal(sum(res$conditions$text == "loop once"), 1L)
})

test_that("J20: @info, @debug, standard error and a with_logger() block's record add no line", {
  res <- cond_main()
  txt <- cond_texts(res)
  expect_false(any(grepl("info text", txt, fixed = TRUE)))
  expect_false(any(grepl("debug text", txt, fixed = TRUE)))
  expect_false(any(grepl("stderr text", txt, fixed = TRUE)))
  expect_false(any(grepl("hidden warning", txt, fixed = TRUE)))
  expect_false(any(res$conditions$source == "jinfo"))
})

test_that("J3 + 2.8.1: the warning never reaches the document", {
  res <- cond_main()
  # the chunks' source is echoed; what Julia prints to standard error is not
  expect_false(any(grepl("Warning:", res$text, fixed = TRUE)))
  expect_false(any(grepl("Error:", res$text, fixed = TRUE)))
  expect_false(any(trimws(res$text) %in% c("from included file", "## from included file",
                                           "stderr text", "## stderr text")))
})

test_that("J3: the condition log is sorted and has no duplicate lines, as for R chunks", {
  res <- cond_main()
  c <- d2_conds(res)
  df <- data.frame(from = vapply(c, `[[`, "", "from"), source = vapply(c, `[[`, "", "source"),
                   class = vapply(c, `[[`, "", "class"), normalised = vapply(c, `[[`, "", "normalised"),
                   stringsAsFactors = FALSE)
  expect_gte(nrow(df), 7L)
  expect_identical(order(df$from, df$source, df$class, df$normalised, method = "radix"), seq_len(nrow(df)))
  expect_false(anyDuplicated(df) > 0)
})

# ---- J3 + 2.8.1: the document is the same without weft ---------------------------------------

test_that("J3 + 2.8.1: the rendered document is identical to the same knit without weft", {
  lines <- c(
    "```{julia jsame}",
    "@warn \"same warning\"",
    "t_j5c_same = 1 + 1",
    "```", "",
    "Value 2 and some prose.", "")
  with_weft <- k5j(lines, weft_yml = WY)
  without <- k5j(lines, setup = FALSE)
  expect_false(with_weft$failed, label = with_weft$message)
  expect_false(without$failed, label = without$message)
  expect_true(any(grepl("## 2", with_weft$text, fixed = TRUE)))
  expect_identical(with_weft$text, without$text)
})

# ---- J16: no double wrapping ------------------------------------------------------------------

test_that("J16: after two earlier knits in the process, one @warn gives one row", {
  lines <- c("```{julia jonce}", "@warn \"once only\"", "```", "")
  for (i in 1:3) {
    res <- k5j(lines, weft_yml = WY)
    expect_false(res$failed, label = res$message)
    expect_equal(sum(res$conditions$text == "once only"), 1L, label = paste("knit", i))
    expect_length(d2_pick(d2_conds(res), source = "jonce", text = "once only"), 1L)
  }
})

# ---- J17: severity -------------------------------------------------------------------------------

test_that("J17: a Julia @warn matching the project's severity list fails the render at the end", {
  lines <- c(
    "```{julia jsev}",
    "@warn \"fit did not converge\"",
    "```", "",
    "Text after the chunk.", "")
  res <- k5j(lines, weft_yml = c("severity:", "  - \"did not converge\""))
  expect_true(res$failed)
  expect_true("weft_failures" %in% res$class)
  f <- res$failures
  expect_equal(nrow(f), 1L)
  expect_identical(f$kind, "condition")
  expect_identical(f$chunk, "jsev")
  expect_identical(msg5(f$detail), "warning: fit did not converge")
  expect_identical(msg5(f$hint), "matched the severity pattern did not converge")
  # the same document without the setting passes
  res0 <- k5j(lines, weft_yml = WY)
  expect_false(res0$failed, label = res0$message)
})

# ---- J18: Julia errors ------------------------------------------------------------------------------

test_that("J18: a Julia error stops the knit with error = TRUE, its message holds Julia's, and the log gains no line", {
  lines <- c("```{julia jboom, error=TRUE}", "error(\"boom\")", "```", "", "After the chunk.", "")
  res <- k5j(lines, weft_yml = WY)
  expect_true(res$failed)
  expect_true(grepl("boom", res$message, fixed = TRUE))
  expect_false(any(grepl("After the chunk", res$text, fixed = TRUE)))
  expect_false(!is.null(res$cond) && any(grepl("boom", res$cond$text, fixed = TRUE)))
  expect_false(!is.null(res$cond) && any(res$cond$class == "error"))
})

test_that("J18: a Julia error stops the knit without error = TRUE too", {
  lines <- c("```{julia jboom2}", "error(\"boom\")", "```", "")
  res <- k5j(lines, weft_yml = WY)
  expect_true(res$failed)
  expect_true(grepl("boom", res$message, fixed = TRUE))
})

test_that("J18: a chunk whose last line's value is a scalar `missing` stops the knit with JuliaCall's TypeError, also under error = TRUE", {
  msg <- "TypeError: non-boolean (Missing) used in boolean context"
  res <- k5j(c("```{julia jmiss}", "t_j5c_zz = missing", "```", ""), weft_yml = WY)
  expect_true(res$failed)
  expect_true(grepl(msg, res$message, fixed = TRUE))
  res <- k5j(c("```{julia jmiss2, error=TRUE}", "t_j5c_zz2 = missing", "```", ""), weft_yml = WY)
  expect_true(res$failed)
  expect_true(grepl(msg, res$message, fixed = TRUE))
})

test_that("J18: with a trailing `;` the same chunk runs", {
  res <- k5j(c("```{julia jmiss3}", "t_j5c_zz3 = missing;", "```", "", "After the chunk.", ""), weft_yml = WY)
  expect_false(res$failed, label = res$message)
  expect_true("After the chunk." %in% res$text)
})

# ---- J19: cache -------------------------------------------------------------------------------------

test_that("J19: a Julia chunk with cache = TRUE served from knitr's cache replays its conditions", {
  dir <- tempfile("weft-5j-cache-")
  dir.create(dir)
  lines <- c("```{julia jcache, cache=TRUE}", "@warn \"cached warning\"", "t_j5c_cache = 1;", "```", "",
             "Done.", "")
  res1 <- k5j(lines, weft_yml = WY, dir = dir)
  expect_false(res1$failed, label = res1$message)
  log1 <- d2_lines(cond_path(dir))
  expect_true(any(grepl("\"source\":\"jcache\"", log1, fixed = TRUE)))
  expect_true(any(grepl("\"text\":\"cached warning\"", log1, fixed = TRUE)))
  res2 <- k5j(lines, weft_yml = WY, dir = dir)
  expect_false(res2$failed, label = res2$message)
  expect_gte(length(list.files(dir, pattern = "\\.rdb$", recursive = TRUE)), 1L)
  log2 <- d2_lines(cond_path(dir))
  expect_identical(log2, log1)
  expect_identical(res2$cond, res1$cond)
})
