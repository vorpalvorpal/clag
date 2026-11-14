# Package P5 of design 9 (dev/design-9.md, section T2, "Target in num.lua", D85, TL4, P5): the Lua number
# formatting under `config.target = "tex"`. Rule 1.4.22 of the design is read as 1.4.23. Needs `pandoc lua`
# (skip_if_no_lua_pandoc() of helper-lua.R, which runs Lua through Pandoc's own interpreter).
# ASCII only: non-ASCII is written as \u escapes.
#
# THE LUA INTERFACE THESE TESTS ASSUME (the design names the pieces, not the signatures; the implementer
# builds to this)
#   num.format(record, class, keys, config)      "num" or "pct"; keys.plus = true for `.plus` (as today);
#   num.format_sci(record, keys, config)         as today;
#   num.format_p(record, config, keys)           as today;
#     with config.target = "tex" (default "markdown": today's output, byte for byte) each returns the TeX text
#     of TX5. The configuration keys are those of today (decimal_mark, big_mark, minus, p_label, p_digits,
#     digits) and `target`. Other values of config.target are not tested.
#   words.collapse_range(text, number, raw, minus, exact_gt, plus, target)
#     READING: the design says only "words.lua (the collapse_range target)". The target is taken as a SEVENTH
#     positional parameter, after `plus`, "markdown" or "tex" or nil (nil = markdown). Under "tex" the caller
#     passes the already-formatted TeX texts of the two ends, and `minus` is "-"; the joiner is always
#     `\ \text{to}\ `, two equal ends give one end.
#   tex_text(s)                                   READING: the design says "the Lua tex_text" and lists it under
#     both num.lua and words.lua; these tests take `num.tex_text` and, when that is nil, `words.tex_text`.
#     It maps a string as R's weft:::tex_text() does (TX6).
# The Lua modules are read from system.file("quarto", "weftlib", ...), as lua_num_path() reads num.lua.

lt_words_path <- function() {
  p <- system.file("quarto", "weftlib", "words.lua", package = "weft")
  if (nzchar(p)) p else file.path(system.file(package = "weft"), "quarto", "weftlib", "words.lua")
}

LT_DRIVER <- '
local numpath, wordspath, rowsfile, outfile = arg[1], arg[2], arg[3], arg[4]
local num = dofile(numpath)
local words = dofile(wordspath)
local out = assert(io.open(outfile, "wb"))
local function oneline(s) return (tostring(s):gsub("[\\t\\r\\n]+", " ")) end
local function has(cls, t) for tok in cls:gmatch("%S+") do if tok == t then return true end end return false end
local function counts(k)
  local o = {}
  for a, b in pairs(k) do
    if a == "digits" or a == "sigfig" then o[a] = math.tointeger(tonumber(b)) else o[a] = b end
  end
  return o
end
local function one(rec, cls, keys, cfg)
  if has(cls, "sci") then return (num.format_sci(rec, keys, cfg)) end
  if has(cls, "p") then return (num.format_p(rec, cfg, keys)) end
  local k = {}
  for a, b in pairs(keys) do k[a] = b end
  if has(cls, "plus") then k.plus = true end
  return num.format(rec, has(cls, "pct") and "pct" or "num", k, cfg)
end
for line in io.lines(rowsfile) do
  local f = {}
  for field in (line .. "\\t"):gmatch("(.-)\\t") do f[#f + 1] = field end
  local ok, text = pcall(function()
    local cls = f[2]
    local keys = counts(pandoc.json.decode(f[3], false))
    local cfg = pandoc.json.decode(f[4], false)
    if cls == "tex_text" then
      local fn = num.tex_text or words.tex_text
      assert(fn, "neither num.tex_text nor words.tex_text exists")
      return fn(keys.s)
    elseif cls == "collapse" then
      local a = pandoc.json.decode(f[1], false)
      local r, msg = words.collapse_range(a.t, a.n, nil, a.minus, nil, a.plus, a.target)
      assert(r, msg)
      return r
    end
    local rec = pandoc.json.decode(f[1], false)
    if has(cls, "range") then
      local t, n = {}, {}
      -- as the filter does (weft.lua, stage i): with no digits or sigfig, and an end that is not whole,
      -- both ends print with the setting `digits`
      if keys.digits == nil and keys.sigfig == nil then
        local whole = true
        for _, r in ipairs(rec.v) do
          local v = tonumber(r.v)
          if r.t ~= "int" and v and math.abs(v - math.floor(v + 0.5)) >= 1e-9 then whole = false end
        end
        if not whole then
          keys = counts(keys)
          keys.digits = math.tointeger(tonumber(cfg.digits or 1))
        end
      end
      for i, r in ipairs(rec.v) do
        local txt, info = one(r, has(cls, "plus") and "num plus" or "num", keys, cfg)
        t[i], n[i] = txt, info.number
      end
      local minus = (cfg.target == "tex") and "-" or (cfg.minus or "\\u{2212}")
      local r, msg = words.collapse_range(t, n, nil, minus, nil, has(cls, "plus"), cfg.target)
      assert(r, msg)
      return r
    end
    return (one(rec, cls, keys, cfg))
  end)
  if ok then out:write("ok\\t", oneline(text), "\\n") else out:write("err\\t", oneline(text), "\\n") end
end
out:close()
'

lt_json <- function(x) if (!length(x)) "{}" else as.character(jsonlite::toJSON(x, auto_unbox = TRUE))

# rows: a list of list(record =, classes =, keys = list(), cfg = list()); `record` is JSON text (or, for the
# class "collapse", the JSON of the call). Returns list(ok, text) in the order of the rows. One Pandoc process.
lt_run <- function(rows, pandoc = lua_pandoc()) {
  n <- length(rows)
  dir <- tempfile("lua-tex-"); dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  lines <- vapply(rows, function(r) {
    paste(r$record, r$classes, lt_json(r$keys), lt_json(r$cfg), sep = "\t")
  }, "")
  stopifnot(!any(grepl("[\r\n]", lines)))
  con <- file(file.path(dir, "rows.tsv"), "wb")
  writeBin(charToRaw(enc2utf8(paste0(lines, "\n", collapse = ""))), con)
  close(con)
  writeLines(LT_DRIVER, file.path(dir, "driver.lua"), useBytes = TRUE)
  res <- lua_run(file.path(dir, "driver.lua"),
                 c(lua_num_path(), lt_words_path(), file.path(dir, "rows.tsv"), file.path(dir, "out.tsv")),
                 pandoc = pandoc)
  outf <- file.path(dir, "out.tsv")
  got <- if (file.exists(outf)) readLines(outf, warn = FALSE, encoding = "UTF-8") else character()
  if (length(got) != n) {
    stop("the Lua driver wrote ", length(got), " lines for ", n, " rows (status ", res$status, "). stderr: ",
         substr(res$stderr, 1, 600), call. = FALSE)
  }
  parts <- strsplit(paste0(got, "\t"), "\t", fixed = TRUE)
  list(ok = vapply(parts, function(p) identical(p[1], "ok"), logical(1)),
       text = vapply(parts, function(p) paste(p[-1], collapse = " "), ""))
}

lt_unesc <- function(x) gsub("%25", "%", gsub("%20", " ", x, fixed = TRUE), fixed = TRUE)

# a `keys` cell of a conformance row as Lua keys and configuration (an independent reading of the format:
# `cfg.NAME=VALUE` is a setting, `target=tex` is config.target, anything else is a key)
lt_split <- function(keys) {
  out <- list(keys = list(), cfg = list())
  if (!nzchar(keys)) return(out)
  for (p in strsplit(keys, " ", fixed = TRUE)[[1]]) {
    k <- sub("=.*$", "", p)
    v <- lt_unesc(sub("^[^=]*=", "", p))
    if (k == "target") out$cfg$target <- v
    else if (startsWith(k, "cfg.")) out$cfg[[substring(k, 5L)]] <- v
    else out$keys[[k]] <- v
  }
  out
}

# the rows of a conformance table as Lua rows
lt_table_rows <- function(d, drop_target = FALSE, target = NULL) {
  lapply(seq_len(nrow(d)), function(i) {
    s <- lt_split(d$keys[i])
    if (drop_target) s$cfg$target <- NULL
    if (!is.null(target)) s$cfg$target <- target
    list(record = d$record[i], classes = d$classes[i], keys = s$keys, cfg = s$cfg)
  })
}

lt_read <- function(set) {
  p <- test_path("_conformance", paste0(set, ".tsv"))
  expect_true(file.exists(p), label = paste0(set, ".tsv exists"))
  if (!file.exists(p)) return(NULL)
  utils::read.delim(p, header = TRUE, sep = "\t", quote = "", comment.char = "", colClasses = "character",
                    na.strings = character(), check.names = FALSE, stringsAsFactors = FALSE,
                    encoding = "UTF-8", fileEncoding = "UTF-8", blank.lines.skip = FALSE)
}

rf <- function(v) sprintf('{"t":"float","v":"%s"}', v)
ri <- function(v) sprintf('{"t":"int","v":"%s"}', v)
rl <- function(...) {
  v <- c(...)
  sprintf('{"t":"list","v":[%s],"of":"float","keys":null}', paste(vapply(v, rf, ""), collapse = ","))
}

# a hand case: record JSON, classes, keys (list), cfg (list, `target` added), expected text
HC <- function(record, classes, keys = list(), cfg = list(), want, target = "tex") {
  if (!is.null(target)) cfg$target <- target
  list(rows = list(record = record, classes = classes, keys = keys, cfg = cfg), want = want)
}
lt_check <- function(cases, label) {
  skip_if_no_lua_pandoc()
  res <- lt_run(lapply(cases, `[[`, "rows"))
  for (i in seq_along(cases)) {
    r <- cases[[i]]$rows
    info <- sprintf("%s: %s | %s | keys %s | cfg %s", label, r$record, r$classes, lt_json(r$keys), lt_json(r$cfg))
    expect_true(res$ok[i], info = paste(info, "->", res$text[i]))
    expect_identical(res$text[i], cases[[i]]$want, info = info)
  }
}

# ---- every row of tex.tsv --------------------------------------------------------------------------------------

LT_CLASSES <- c("num", "pct", "plus", "sci", "p", "range")

test_that("D85, TX5: every Lua-reproducible row of tex.tsv prints from Lua what R printed", {
  skip_if_no_lua_pandoc()
  d <- lt_read("tex")
  if (is.null(d)) return(invisible())
  toks <- strsplit(d$classes, " ", fixed = TRUE)
  is_range <- vapply(toks, function(t) "range" %in% t, logical(1))
  supported <- vapply(toks, function(t) all(t %in% LT_CLASSES), logical(1)) &
    (is_range | !startsWith(d$value, "c(")) & (!is_range | startsWith(d$value, "c("))
  # READING: the design's corpus is num, pct, plus, sci, p and range; a vector joined with ", " is R's alone
  expect_gte(sum(supported), 60L)
  expect_gte(sum(supported), 0.8 * nrow(d))
  x <- d[supported, , drop = FALSE]
  res <- lt_run(lt_table_rows(x))
  got <- ifelse(res$ok, res$text, paste0("<<error: ", res$text, ">>"))
  bad <- which(got != x$text)
  expect(length(bad) == 0L,
         paste0(length(bad), " of ", nrow(x), " rows differ; first differences:\n",
                paste(vapply(utils::head(bad, 8), function(i) {
                  sprintf("  %s | %s | %s\n    Lua: %s\n    R:   %s", x$value[i], x$classes[i], x$keys[i],
                          got[i], x$text[i])
                }, ""), collapse = "\n")))
})

# ---- config.target, direct cases: the forms of TX5 --------------------------------------------------------------

test_that("TX5, D85: .num and .pct under config.target = tex", {
  lt_check(list(
    HC(rf("-1234567.89"), "num", want = r"(-1{,}234{,}567.9)"),
    HC(rf("999.95"), "num", want = r"(1{,}000.0)"),
    HC(rf("3"), "num", want = "3"),
    HC(rf("0.5"), "num", list(digits = "2"), want = "0.50"),
    HC(rf("0.04"), "num", want = "0.0"),
    HC(rf("3"), "num plus", want = "+3"),
    HC(rf("-3"), "num plus", want = "-3"),
    HC(rf("0"), "num plus", want = "0"),
    HC(ri("1234567"), "num", want = r"(1{,}234{,}567)"),
    HC(rf("0.123"), "pct", want = r"(12.3\%)"),
    HC(rf("0.05"), "pct plus", want = r"(+5\%)"),
    HC(rf("0.0004"), "pct", want = r"(0.0\%)"),
    HC(rf("-3.456"), "pct", want = r"(-345.6\%)"),
    HC(rf("1234.5"), "pct", want = r"(123{,}450\%)"),
    HC(rf("0.5"), "pct", list(digits = "0"), want = r"(50\%)")
  ), "num and pct")
})

test_that("TX4, D67: the minus is - whatever cfg.minus is", {
  lt_check(list(
    HC(rf("-2.5"), "num", cfg = list(minus = "\u2212"), want = "-2.5"),
    HC(rf("-2.5"), "num", cfg = list(minus = "-"), want = "-2.5"),
    HC(rf("-2.5"), "num", cfg = list(minus = "--"), want = "-2.5"),
    HC(rf("-2.5"), "num", cfg = list(minus = "\u2013"), want = "-2.5"),
    HC(rf("-0.12"), "pct", cfg = list(minus = "\u2212"), want = r"(-12\%)"),
    HC(rf("-1.25"), "num plus", cfg = list(minus = "\u2212"), want = "-1.3")
  ), "minus")
})

test_that("TX4: the big mark under each mark of the table", {
  big <- function(mark, want) HC(ri("1234567"), "num", cfg = list(big_mark = mark), want = want)
  lt_check(list(
    big("", "1234567"),
    big(",", r"(1{,}234{,}567)"),
    big(".", "1.234.567"),
    big(" ", r"(1\,234\,567)"),
    big("\u00a0", r"(1\,234\,567)"),
    big("\u2009", r"(1\,234\,567)"),
    big("\u202f", r"(1\,234\,567)"),
    big("'", r"(1\text{'}234\text{'}567)"),
    big("\u2019", r"(1\text{'}234\text{'}567)"),
    big("\u00b7", r"(1{\cdot}234{\cdot}567)"),
    big("_", r"(1\_234\_567)"),
    big("%", r"(1\%234\%567)"),
    big("x", r"(1\text{x}234\text{x}567)"),
    big("ab", r"(1\text{ab}234\text{ab}567)")
  ), "big_mark")
})

test_that("TX4: the decimal mark under each mark of the table (the big mark empty, so no collision)", {
  dec <- function(mark, want) HC(rf("1.5"), "num", cfg = list(decimal_mark = mark, big_mark = ""), want = want)
  lt_check(list(
    dec("", "15"),
    dec(",", r"(1{,}5)"),
    dec(".", "1.5"),
    dec(" ", r"(1\,5)"),
    dec("\u00a0", r"(1\,5)"),
    dec("'", r"(1\text{'}5)"),
    dec("\u2019", r"(1\text{'}5)"),
    dec("\u00b7", r"(1{\cdot}5)"),
    dec("x", r"(1\text{x}5)")
  ), "decimal_mark")
})

test_that("TX4, TX5: the configurations of the design, and equal marks", {
  lt_check(list(
    HC(rf("1234567.89"), "num", cfg = list(decimal_mark = ",", big_mark = "."), want = r"(1.234.567{,}9)"),
    HC(rf("1234567.89"), "num", cfg = list(big_mark = " "), want = r"(1\,234\,567.9)"),
    HC(rf("1234567.89"), "num", cfg = list(big_mark = "'"), want = r"(1\text{'}234\text{'}567.9)"),
    HC(rf("1234567.89"), "num", cfg = list(big_mark = ""), want = "1234567.9"),
    # both marks map to the same TeX: the decimal mark is \text{<mark>}
    HC(rf("1234567.89"), "num", cfg = list(decimal_mark = ","), want = r"(1{,}234{,}567\text{,}9)"),
    HC(rf("1234.5"), "num", cfg = list(decimal_mark = ",", big_mark = ","), want = r"(1{,}234\text{,}5)")
  ), "configurations")
})

test_that("TX5: .sci writes \\times 10^{e}", {
  lt_check(list(
    HC(rf("1234567"), "sci", want = r"(1.2 \times 10^{6})"),
    HC(rf("-0.000123"), "sci", want = r"(-1.2 \times 10^{-4})"),
    HC(rf("0"), "sci", want = "0"),
    HC(rf("1"), "sci", want = r"(1 \times 10^{0})"),
    HC(rf("9.96"), "sci", want = r"(1 \times 10^{1})"),
    HC(rf("12345"), "sci", list(digits = "2"), want = r"(1.23 \times 10^{4})"),
    HC(rf("-2500"), "sci", list(digits = "2"), want = r"(-2.50 \times 10^{3})"),
    HC(rf("12345"), "sci", list(sigfig = "2"), want = r"(1.2 \times 10^{4})")
  ), "sci")
})

test_that("TX4, D67: .sci under TeX uses - in the exponent and the mantissa, whatever cfg.minus is, and the marks", {
  lt_check(list(
    HC(rf("-0.000123"), "sci", cfg = list(minus = "\u2212"), want = r"(-1.2 \times 10^{-4})"),
    HC(rf("-0.000123"), "sci", cfg = list(minus = "-"), want = r"(-1.2 \times 10^{-4})"),
    HC(rf("1234567"), "sci", cfg = list(decimal_mark = ",", big_mark = "."), want = r"(1{,}2 \times 10^{6})"),
    HC(rf("1234567"), "sci", cfg = list(decimal_mark = "\u00b7", big_mark = ","), want = r"(1{\cdot}2 \times 10^{6})")
  ), "sci config")
})

test_that("TX5: .p, with the label key verbatim", {
  lt_check(list(
    HC(rf("0.0001"), "p", want = "p < 0.001"),
    HC(rf("0.03"), "p", want = "p = 0.030"),
    HC(rf("0.5"), "p", want = "p = 0.50"),
    HC(rf("0.995"), "p", want = "p > 0.99"),
    HC(rf("0.5"), "p", list(label = ""), want = "0.50"),
    HC(rf("0.995"), "p", list(label = ""), want = "> 0.99"),
    HC(rf("0.0001"), "p", list(label = ""), want = "< 0.001"),
    HC(rf("0.046"), "p", list(label = r"(\tilde{p})"), want = r"(\tilde{p} = 0.046)"),
    HC(rf("0.046"), "p", list(label = "q"), want = "q = 0.046"),
    HC(rf("0.046"), "p", list(label = "adj. p"), want = "adj. p = 0.046"),
    HC(rf("0.0004"), "p", list(digits = "3"), want = "p < 0.001"),
    HC(rf("0.12"), "p", cfg = list(p_digits = "3"), want = "p = 0.120")
  ), "p")
})

test_that("D72: the setting p_label is converted to TeX; a label key wins and is verbatim", {
  lab <- function(setting, want, keys = list()) {
    HC(rf("0.046"), "p", keys, cfg = list(p_label = setting), want = want)
  }
  lt_check(list(
    lab("p", "p = 0.046"),
    lab("*p*", "p = 0.046"),
    lab("_p_", "p = 0.046"),
    lab("q", "q = 0.046"),
    lab("", "0.046"),
    lab("adj. p", r"(\text{adj. p} = 0.046)"),
    lab("p_adj", r"(\text{p}\_\text{adj} = 0.046)"),
    lab("adj. p", "q = 0.046", list(label = "q")),
    lab("adj. p", r"(\tilde{p} = 0.046)", list(label = r"(\tilde{p})")),
    lab("q", "0.046", list(label = ""))
  ), "p_label")
  # the same settings print as they did before under the default target
  lt_check(list(
    HC(rf("0.046"), "p", cfg = list(p_label = "*p*"), want = "*p* = 0.046", target = NULL),
    HC(rf("0.046"), "p", cfg = list(p_label = "adj. p"), want = "adj. p = 0.046", target = NULL)
  ), "p_label, no target")
})

test_that("TX4: .p under a decimal mark", {
  lt_check(list(
    HC(rf("0.0001"), "p", cfg = list(decimal_mark = ",", big_mark = "."), want = "p < 0{,}001"),
    HC(rf("0.03"), "p", cfg = list(decimal_mark = ",", big_mark = "."), want = "p = 0{,}030"),
    HC(rf("0.03"), "p", cfg = list(decimal_mark = "\u00b7"), want = r"(p = 0{\cdot}030)")
  ), "p decimal")
})

test_that("TX5, D69: .range under TeX always says to", {
  lt_check(list(
    HC(rl("1.23", "3.45"), "range", want = r"(1.2\ \text{to}\ 3.5)"),
    HC(rl("-1", "3"), "range", want = r"(-1\ \text{to}\ 3)"),
    HC(rl("2", "2"), "range", want = "2"),
    HC(rl("1", "3"), "range plus", want = r"(+1\ \text{to}\ +3)"),
    HC(rl("3", "5"), "range", want = r"(3\ \text{to}\ 5)"),
    HC(rl("-3", "-1"), "range", want = r"(-3\ \text{to}\ -1)"),
    HC(rl("1000", "2500"), "range", want = r"(1{,}000\ \text{to}\ 2{,}500)"),
    HC(rl("1.25", "3.5"), "range", list(digits = "2"), want = r"(1.25\ \text{to}\ 3.50)"),
    HC(rl("1.25", "3.5"), "range", list(sigfig = "1"), want = r"(1\ \text{to}\ 4)"),
    HC(rl("0.12", "0.5"), "range", cfg = list(decimal_mark = ",", big_mark = "."), want = r"(0{,}1\ \text{to}\ 0{,}5)")
  ), "range")
})

test_that("D69: words.collapse_range under a target: the joiner, equal ends, the order check", {
  col <- function(t, n, want, target = "tex", plus = FALSE, minus = "-") {
    j <- list(t = as.list(t), n = as.list(n), minus = minus, plus = plus)
    if (!is.null(target)) j$target <- target
    list(rows = list(record = lt_json(j), classes = "collapse", keys = list(), cfg = list()), want = want)
  }
  lt_check(list(
    col(c("1.2", "3.5"), c(1.2, 3.5), r"(1.2\ \text{to}\ 3.5)"),
    col(c("-1", "3"), c(-1, 3), r"(-1\ \text{to}\ 3)"),
    col(c("2", "2"), c(2, 2), "2"),
    col(c("+1", "+3"), c(1, 3), r"(+1\ \text{to}\ +3)", plus = TRUE),
    col(c("1{,}000", "2{,}500"), c(1000, 2500), r"(1{,}000\ \text{to}\ 2{,}500)"),
    # no target, and the explicit default: today's text
    col(c("3", "5"), c(3, 5), "3\u20135", target = NULL, minus = "\u2212"),
    col(c("3", "5"), c(3, 5), "3\u20135", target = "markdown", minus = "\u2212"),
    col(c("\u22121", "3"), c(-1, 3), "\u22121 to 3", target = NULL, minus = "\u2212"),
    col(c("\u22121", "3"), c(-1, 3), "\u22121 to 3", target = "markdown", minus = "\u2212")
  ), "collapse_range")
  skip_if_no_lua_pandoc()
  res <- lt_run(list(col(c("5", "3"), c(5, 3), "")$rows))
  expect_false(res$ok, label = "a range whose first end is above its second is still refused under tex")
})

# ---- tex_text ----------------------------------------------------------------------------------------------------

LT_STRINGS <- c("", "abc", "a b", "adj. p", "p_adj", "5%", "{a}", "}{", "a\\b", "a^b~c", "<>|", "$#&",
                "~", "^", "_", "a|b", "<", "a%b", "100%", "x_1", "\\alpha", "a  b", " lead", "trail ",
                "\u00b0C", "\u00b5m", "\u03a9", "mg/L", "m^2", "A&B", "50 % off", "caf\u00e9 au lait",
                "\u2019", "a\u00a0b", "\u00a0", "p < 0.05", "{\\cdot}", "$5", "#1 & #2")

test_that("TX6: the Lua tex_text maps its strings as R's tex_text does", {
  skip_if_no_lua_pandoc()
  expect_gte(length(LT_STRINGS), 30L)
  rows <- lapply(LT_STRINGS, function(s) list(record = "{}", classes = "tex_text", keys = list(s = s), cfg = list()))
  res <- lt_run(rows)
  want <- vapply(LT_STRINGS, weft:::tex_text, "", USE.NAMES = FALSE)
  for (i in seq_along(LT_STRINGS)) {
    expect_true(res$ok[i], info = paste("string", i, res$text[i]))
    expect_identical(res$text[i], want[i], info = paste("string", encodeString(LT_STRINGS[i])))
  }
})

test_that("TX6: the Lua tex_text, hand-written cases", {
  hand <- list(
    c("adj. p", r"(\text{adj. p})"), c("abc", r"(\text{abc})"), c("p_adj", r"(\text{p}\_\text{adj})"),
    c("\\", r"(\backslash)"), c("{", r"(\{)"), c("}", r"(\})"), c("$", r"(\$)"), c("%", r"(\%)"),
    c("&", r"(\&)"), c("#", r"(\#)"), c("_", r"(\_)"), c("^", r"(\hat{})"), c("~", r"(\sim)"),
    c("<", "<"), c(">", ">"), c("|", "|"), c("\u00a0", r"(\,)"), c("a%b", r"(\text{a}\%\text{b})"),
    c("a^b~c", r"(\text{a}\hat{}\text{b}\sim\text{c})"), c("\u00b0C", "\\text{\u00b0C}"),
    c("{a}", r"(\{\text{a}\})"), c("5%", r"(\text{5}\%)"))
  lt_check(lapply(hand, function(h) {
    list(rows = list(record = "{}", classes = "tex_text", keys = list(s = h[1]), cfg = list()), want = h[2])
  }), "tex_text")
})

# ---- with no target, today's output ------------------------------------------------------------------------------

lt_identity <- function(set, classes, label) {
  skip_if_no_lua_pandoc()
  d <- lt_read(set)
  if (is.null(d)) return(invisible())
  d <- d[d$classes %in% classes, , drop = FALSE]
  expect_gt(nrow(d), 0L)
  for (target in list(NULL, "markdown")) {
    res <- lt_run(lt_table_rows(d, target = target))
    got <- ifelse(res$ok, res$text, paste0("<<error: ", res$text, ">>"))
    bad <- which(got != d$text)
    expect(length(bad) == 0L,
           paste0(label, " (target ", if (is.null(target)) "absent" else target, "): ", length(bad), " of ",
                  nrow(d), " rows differ; first: ",
                  paste(vapply(utils::head(bad, 3), function(i) {
                    sprintf("%s | %s | %s -> %s (committed %s)", d$value[i], d$classes[i], d$keys[i], got[i],
                            d$text[i])
                  }, ""), collapse = "; ")))
  }
}

test_that("D85: with no target (or markdown), the number printer is byte-identical to the committed numbers.tsv", {
  lt_identity("numbers", c("num", "pct", "num plus", "pct plus"), "numbers.tsv")
})

test_that("D85: with no target (or markdown), .sci is byte-identical to the committed sci.tsv", {
  lt_identity("sci", "sci", "sci.tsv")
})

test_that("D85: with no target (or markdown), .p is byte-identical to the committed p.tsv", {
  lt_identity("p", "p", "p.tsv")
})

test_that("D85, D69: with no target (or markdown), the range is byte-identical to the committed collapse.tsv", {
  lt_identity("collapse", c("range", "range plus"), "collapse.tsv")
})
