# Package 6a: running weft's Lua modules from testthat (dev/design-6.md, section 5, "Lua from
# testthat"). Lua runs through Pandoc's own interpreter, `pandoc lua script.lua`, never a system Lua.
# ASCII only.
#
# HELPERS
#   lua_pandocs()            every distinct Pandoc found (Quarto's bundled one, the PATH one, the one
#                            rmarkdown finds), one per version, as list(label, cmd, pre, version).
#                            A Pandoc older than 3.1 stays in the list: test-lua-num.R fails on it.
#   lua_pandoc()             the first of them (Quarto's when Quarto is on the PATH).
#   skip_if_no_lua_pandoc()  skips ONLY when no Pandoc is found at all. (Named so that it does not
#                            replace skip_if_no_pandoc() of helper-quarto.R, which loads after this
#                            file.)
#   lua_run(script, args)    one `pandoc lua <script> <args>` process; returns stdout, stderr, status.
#   lua_num_path()           the shipped inst/quarto/weftlib/num.lua (a path; the file may be absent).
#   lua_num_table(rows, ...) the rows of a table through num.format(), ONE Pandoc process per call.
#
# THE LUA INTERFACE OF weftlib/num.lua THAT THESE TESTS FIX
# (dev/design-6.md N85 leaves it open; the implementer builds to this)
#   local num = dofile(".../weftlib/num.lua")      -- returns a table, no side effect on load (N80):
#                                                  -- nothing printed, no global set, no exit
#   text, info = num.format(record, class, keys, config)
#     record  a Lua table: the decoded JSON record of schema 1 (N22), e.g. {t = "float", v = "3.14"},
#             {t = "int", v = "12345678901234567890"}, {t = "decimal", v = "0.125"}. Decoded with
#             pandoc.json.decode(text, false), so `v` of int, float and decimal is a STRING.
#     class   a string, one class WITHOUT the dot: "num" or "pct". These are the only classes this
#             module implements (N82); .val is the filter's own, not the printer's.
#     keys    a Lua table (or nil) of the construct's keys: digits = <integer>, sigfig = <integer>
#             (Lua numbers). Any other key (unit = "m", say) is not implemented.
#     config  a Lua table (or nil) of the settings of N84, each optional: digits (default 1),
#             decimal_mark (default "."), big_mark (default ","), thousands_from (default 1000),
#             minus (default U+2212). The marks are plain UTF-8 strings of any length, a space
#             included. config.digits is the default of a number that is not whole; keys.digits and
#             keys.sigfig win over it.
#   returns text (a string; U+2212 minus by default; "%" at the end for "pct") and info, a table:
#     info.number    the number as printed, a Lua number (3.1 for 3.14159 at digits=1; the percentage
#                    for "pct"); not asserted beyond what the tests below name
#     info.decimals  true when the text shows a decimal mark and digits after it
#     info.relation  "="
#     info.zero      true when the number as printed is 0 ("0", "0.0", "0%"; never from the sign)
#     info.one       true when the number as printed is 1 ("1", "1.0")
#     info.two       true when the number as printed is 2
#   Anything this module does not implement FAILS LOUDLY: it calls error(), it never returns the
#   record's text or any other pass-through. That covers: a class other than num and pct ("sci",
#   "word", "uname", ...), a key other than digits and sigfig ("unit"), digits and sigfig together,
#   a record that is not int, float or decimal (bool, string, date, list, missing, error), a nil
#   record, and a malformed record. The error message is a string that names the offender (the
#   class, the key or the record kind) and, for an unimplemented class or key, contains the words
#   "not implemented".
#
# THE ROWS FILE (what lua_num_table() writes for its one process)
#   one line per row, three or four tab-separated fields: record (JSON text), classes, keys
#   ("k=v" pairs, space-separated, as in the conformance tables), config (JSON object text, may be
#   missing). The driver splits `keys` on spaces, turns digits and sigfig into Lua numbers, calls
#   num.format(record, classes, keys, config) inside pcall and writes one line per row:
#   "ok<TAB>text<TAB>info-as-JSON" or "err<TAB>message".

LUA_DRIVER <- '
local numpath, rowsfile, outfile = arg[1], arg[2], arg[3]
local num = dofile(numpath)
local out = assert(io.open(outfile, "wb"))
local function oneline(s) return (tostring(s):gsub("[\\t\\r\\n]+", " ")) end
for line in io.lines(rowsfile) do
  local f = {}
  for field in (line .. "\\t"):gmatch("(.-)\\t") do f[#f + 1] = field end
  local ok, text, info = pcall(function()
    local rec = pandoc.json.decode(f[1], false)
    local keys = {}
    for tok in (f[3] or ""):gmatch("%S+") do
      local k, v = tok:match("^([^=]*)=(.*)$")
      if k == "digits" or k == "sigfig" then keys[k] = tonumber(v) else keys[k] = v end
    end
    local cfg = nil
    if f[4] and f[4] ~= "" then cfg = pandoc.json.decode(f[4], false) end
    return num.format(rec, f[2], keys, cfg)
  end)
  if ok then
    out:write("ok\\t", oneline(text), "\\t", pandoc.json.encode(info or {}), "\\n")
  else
    out:write("err\\t", oneline(text), "\\n")
  end
end
out:close()
'

.lua_env <- new.env(parent = emptyenv())

lua_pandocs <- function() {
  if (!is.null(.lua_env$pandocs)) return(.lua_env$pandocs)
  cands <- list()
  q <- unname(Sys.which("quarto"))
  if (nzchar(q)) cands[[length(cands) + 1L]] <- list(label = "quarto", cmd = q, pre = "pandoc")
  p <- unname(Sys.which("pandoc"))
  if (nzchar(p)) cands[[length(cands) + 1L]] <- list(label = "path", cmd = p, pre = character())
  if (requireNamespace("rmarkdown", quietly = TRUE)) {
    r <- tryCatch(rmarkdown::pandoc_exec(), error = function(e) "")
    if (length(r) == 1L && !is.na(r) && nzchar(r) && file.exists(r)) {
      cands[[length(cands) + 1L]] <- list(label = "rmarkdown", cmd = r, pre = character())
    }
  }
  found <- list(); seen <- character()
  for (cd in cands) {
    v <- suppressWarnings(tryCatch(
      system2(cd$cmd, c(cd$pre, "--version"), stdout = TRUE, stderr = FALSE),
      error = function(e) character()))
    if (!length(v)) next
    ver <- sub("^pandoc(\\.exe)? ", "", v[[1]])
    if (!grepl("^[0-9]+\\.[0-9]+", ver)) next
    ver <- sub("^([0-9.]+).*$", "\\1", ver)
    if (ver %in% seen) next
    seen <- c(seen, ver)
    cd$version <- ver
    found[[length(found) + 1L]] <- cd
  }
  .lua_env$pandocs <- found
  found
}

lua_pandoc <- function() lua_pandocs()[[1]]

lua_version_ok <- function(p) numeric_version(p$version) >= numeric_version("3.1")

skip_if_no_lua_pandoc <- function() {
  testthat::skip_if(length(lua_pandocs()) == 0L, "no Pandoc found")
}

lua_run <- function(script, args = character(), pandoc = lua_pandoc(), dir = NULL) {
  out <- tempfile("lua-out-"); err <- tempfile("lua-err-")
  on.exit(unlink(c(out, err)), add = TRUE)
  if (!is.null(dir)) {
    old <- setwd(dir); on.exit(setwd(old), add = TRUE)
  }
  status <- suppressWarnings(system2(
    pandoc$cmd, c(pandoc$pre, "lua", shQuote(script), vapply(args, shQuote, character(1))),
    stdout = out, stderr = err))
  rd <- function(f) {
    if (!file.exists(f)) return("")
    paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  }
  list(stdout = rd(out), stderr = rd(err), status = as.integer(status))
}

lua_num_path <- function() {
  p <- system.file("quarto", "weftlib", "num.lua", package = "weft")
  if (nzchar(p)) p else file.path(system.file(package = "weft"), "quarto", "weftlib", "num.lua")
}

# rows: a data frame with character columns record, classes, keys (keys may be ""). `config`: NULL, one
# named list of settings used for every row, or a character vector of JSON objects (one per row, "" for
# none). Returns the data frame plus ok (logical), text, err (character, "" when ok) and info (a list of
# lists). One Pandoc process.
lua_num_table <- function(rows, config = NULL, pandoc = lua_pandoc()) {
  n <- nrow(rows)
  dir <- tempfile("lua-num-"); dir.create(dir)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)
  cfg <- if (is.null(config)) rep("", n)
         else if (is.list(config)) rep(as.character(jsonlite::toJSON(config, auto_unbox = TRUE)), n)
         else rep_len(as.character(config), n)
  stopifnot(!any(grepl("[\t\r\n]", c(rows$record, rows$classes, rows$keys, cfg))))
  con <- file(file.path(dir, "rows.tsv"), "wb")
  writeBin(charToRaw(enc2utf8(paste0(
    paste(rows$record, rows$classes, rows$keys, cfg, sep = "\t"), "\n", collapse = ""))), con)
  close(con)
  writeLines(LUA_DRIVER, file.path(dir, "driver.lua"), useBytes = TRUE)
  res <- lua_run(file.path(dir, "driver.lua"),
                 c(lua_num_path(), file.path(dir, "rows.tsv"), file.path(dir, "out.tsv")),
                 pandoc = pandoc)
  outf <- file.path(dir, "out.tsv")
  lines <- if (file.exists(outf)) readLines(outf, warn = FALSE, encoding = "UTF-8") else character()
  if (length(lines) != n) {
    stop("the Lua driver wrote ", length(lines), " lines for ", n, " rows (status ", res$status,
         "). stderr: ", substr(res$stderr, 1, 600), call. = FALSE)
  }
  parts <- strsplit(paste0(lines, "\t\t"), "\t", fixed = TRUE)
  rows$ok <- vapply(parts, function(p) identical(p[1], "ok"), logical(1))
  rows$text <- ifelse(rows$ok, vapply(parts, `[`, "", 2L), "")
  rows$err <- ifelse(rows$ok, "", vapply(parts, `[`, "", 2L))
  rows$info <- lapply(seq_len(n), function(i) {
    if (!rows$ok[i] || !nzchar(parts[[i]][3])) return(list())
    jsonlite::fromJSON(parts[[i]][3], simplifyVector = FALSE)
  })
  rows
}

# one record, as a data frame row for lua_num_table()
lua_row <- function(record, classes = "num", keys = "") {
  data.frame(record = record, classes = classes, keys = keys, stringsAsFactors = FALSE)
}

# The records of N22 for scalars, written as compact JSON the way a writer would.
rec_int <- fr_int
rec_float <- fr_float
rec_dec <- fr_dec

# ---- an independent exact oracle (string arithmetic, no double) -------------------------------------
# exact_oracle(v, class, digits, sigfig, config) prints the decimal text `v` (the JSON `v` of an int or a
# decimal) as rule N85 says: half away from zero on the value as written, whole when every fraction digit
# is 0, `digits` places, `sigfig` significant digits, the thousands mark from thousands_from, no minus on
# a result that rounds to zero, "pct" by moving the point two places. Returns NA_character_ for a case the
# rule leaves open (a sigfig rounding that carries into a new digit). It checks the hand-curated
# exact.tsv independently of the Lua code, and is itself checked against the committed numbers.tsv for the
# rows that a decimal of at most 15 digits describes.
.str_incr <- function(s) {
  d <- rev(as.integer(strsplit(s, "")[[1]])); i <- 1L
  repeat {
    if (i > length(d)) { d <- c(d, 1L); break }
    if (d[i] == 9L) { d[i] <- 0L; i <- i + 1L } else { d[i] <- d[i] + 1L; break }
  }
  paste(rev(d), collapse = "")
}

# value = 0.D * 10^p ; D == "" means zero
.dec_parse <- function(v) {
  neg <- startsWith(v, "-"); v <- sub("^-", "", v)
  ex <- 0L
  if (grepl("[eE]", v)) {
    ex <- as.integer(sub("^.*[eE]\\+?", "", v)); v <- sub("[eE].*$", "", v)
  }
  ip <- sub("\\..*$", "", v)
  fp <- if (grepl("\\.", v)) sub("^[^.]*\\.", "", v) else ""
  D <- paste0(ip, fp); p <- nchar(ip) + ex
  lead <- nchar(sub("^(0*).*$", "\\1", D))
  D <- substr(D, lead + 1L, nchar(D)); p <- p - lead
  list(neg = neg, D = sub("0+$", "", D), p = p)
}

# round_half_away(value * 10^k) as a digit string
.dec_round <- function(D, p, k) {
  keep <- p + k
  if (!nzchar(D) || keep < 0L) return("0")
  if (keep == 0L) return(if (as.integer(substr(D, 1, 1)) >= 5L) "1" else "0")
  if (keep >= nchar(D)) return(paste0(D, strrep("0", keep - nchar(D))))
  N <- substr(D, 1, keep)
  if (as.integer(substr(D, keep + 1L, keep + 1L)) >= 5L) N <- .str_incr(N)
  N
}

exact_oracle <- function(v, class = "num", digits = NULL, sigfig = NULL, config = list()) {
  cfg <- utils::modifyList(list(digits = 1L, decimal_mark = ".", big_mark = ",",
                                thousands_from = 1000L, minus = "−"), config)
  x <- .dec_parse(v)
  if (class == "pct") x$p <- x$p + 2L
  D <- x$D; p <- x$p
  zero <- !nzchar(D)
  whole <- zero || nchar(D) <= p
  if (!is.null(sigfig)) {
    if (zero) {
      dec <- sigfig - 1L; N <- "0"
    } else {
      k <- sigfig - 1L - (p - 1L)
      if (k >= 0L) {
        N <- .dec_round(D, p, k); dec <- k
        core <- N
      } else {
        core <- .dec_round(D, p + k, 0L); N <- paste0(core, strrep("0", -k)); dec <- 0L
      }
      if (nchar(sub("^0+", "", core)) > sigfig) return(NA_character_)
    }
  } else if (!is.null(digits)) {
    dec <- as.integer(digits); N <- .dec_round(D, p, dec)
  } else if (whole) {
    dec <- 0L; N <- .dec_round(D, p, 0L)
  } else {
    dec <- as.integer(cfg$digits); N <- .dec_round(D, p, dec)
  }
  if (nchar(N) < dec + 1L) N <- paste0(strrep("0", dec + 1L - nchar(N)), N)
  ipart <- substr(N, 1, nchar(N) - dec)
  fpart <- if (dec > 0L) substr(N, nchar(N) - dec + 1L, nchar(N)) else ""
  ipart <- sub("^0+(?=.)", "", ipart, perl = TRUE)
  big <- nchar(ipart) > 15L || as.numeric(ipart) >= cfg$thousands_from
  if (big) ipart <- gsub("(?<=\\d)(?=(\\d{3})+$)", cfg$big_mark, ipart, perl = TRUE)
  txt <- if (dec > 0L) paste0(ipart, cfg$decimal_mark, fpart) else ipart
  if (x$neg && grepl("[1-9]", N)) txt <- paste0(cfg$minus, txt)
  if (class == "pct") txt <- paste0(txt, "%")
  txt
}
