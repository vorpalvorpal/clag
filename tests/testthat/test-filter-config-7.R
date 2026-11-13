# Package 7s: the new settings in the filter's reader (dev/design-7.md N25, N28, N51; E33 of design-6).
# weftlib/config.lua is driven directly, in ONE `pandoc lua` process for every case: config.load(path,
# text, cwd) returns the settings and the problems (E33 is composed from a problem by weft.lua).
# ASCII only.

C7_DRIVER <- '
local lib = arg[1]
local config = dofile(lib .. "/config.lua")
for i = 2, #arg do
  local dir = arg[i]
  local f = io.open(dir .. "/doc.md", "rb")
  local text = f and f:read("a") or nil
  if f then f:close() end
  local cfg, problems = config.load("doc.md", text, dir)
  local ps = {}
  for _, p in ipairs(problems) do
    ps[#ps + 1] = { file = p.file, key = p.key, value = p.value, what = p.what }
  end
  local out = { p_digits = cfg.p_digits, p_label = cfg.p_label, output_refs = cfg.output_refs,
                output_missing = cfg.output_missing, output_markup = cfg.output_markup,
                digits = cfg.digits, nproblems = #ps, problems = ps }
  io.write(pandoc.json.encode(out), "\\n")
end
'

# name -> list(yml = lines, doc = lines)
c7f_cases <- list(
  default      = list(yml = "# nothing"),
  p3           = list(yml = "p_digits: 3"),
  pnull        = list(yml = "p_digits: null"),
  p6           = list(yml = "p_digits: 6"),
  label_empty  = list(yml = "p_label: \"\""),
  label_q      = list(yml = "p_label: \"q\""),
  miss_off     = list(yml = "output_missing: off"),
  all_three    = list(yml = c("output_refs: warn", "output_missing: fail", "output_markup: off")),
  doc_wins     = list(yml = c("p_digits: 3", "p_label: q", "output_missing: off"),
                      doc = c("---", "weft:", "  p_digits: 2", "  p_label: \"\"", "  output_missing: fail",
                              "---", "", "Text.")),
  doc_flow     = list(yml = "p_digits: 3", doc = c("---", "weft: {p_digits: 5, p_label: r}", "---", "", "Text.")),
  bad_p0       = list(yml = "p_digits: 0"),
  bad_p7       = list(yml = "p_digits: 7"),
  bad_p15      = list(yml = "p_digits: 1.5"),
  bad_pword    = list(yml = "p_digits: three"),
  bad_miss     = list(yml = "output_missing: maybe"),
  bad_refs     = list(yml = "output_refs: true"),
  bad_markup   = list(yml = "output_markup: loud"),
  bad_doc      = list(yml = "output_markup: off", doc = c("---", "weft:", "  output_markup: sometimes", "---", "", "Text.")),
  ctl_digits   = list(yml = "digits: 2")
)

c7f_run <- local({
  cache <- NULL
  function() {
    if (!is.null(cache)) return(cache)
    root <- tempfile("c7f-"); dir.create(root)
    dirs <- vapply(names(c7f_cases), function(nm) {
      d <- file.path(root, nm); dir.create(d)
      writeLines(c7f_cases[[nm]]$yml, file.path(d, "_weft.yml"))
      if (!is.null(c7f_cases[[nm]]$doc)) writeLines(c7f_cases[[nm]]$doc, file.path(d, "doc.md"))
      d
    }, "")
    script <- file.path(root, "driver.lua")
    writeLines(C7_DRIVER, script)
    lib <- dirname(lua_num_path())
    res <- lua_run(script, c(lib, dirs))
    lines <- strsplit(res$stdout, "\n", fixed = TRUE)[[1]]
    out <- if (length(lines) == length(dirs) && res$status == 0L) {
      stats::setNames(lapply(lines, jsonlite::fromJSON, simplifyVector = FALSE), names(c7f_cases))
    } else NULL
    attr(out, "raw") <- res
    unlink(root, recursive = TRUE)
    cache <<- out
    out
  }
})

c7f <- function(nm) {
  skip_if_no_lua_pandoc()
  all <- c7f_run()
  if (is.null(all)) {
    res <- attr(all, "raw")
    fail(paste("the config driver failed:", res$stderr))
    return(NULL)
  }
  all[[nm]]
}

test_that("control: the driver runs and reads an existing setting (digits: 2), with no problems", {
  # passes today
  r <- c7f("ctl_digits")
  expect_equal(r$digits, 2)
  expect_identical(r$nproblems, 0L)
})

test_that("N25, N28, N51: the defaults are p_digits nil, p_label p, output_refs fail, output_missing warn, output_markup fail", {
  r <- c7f("default")
  expect_null(r$p_digits)
  expect_identical(r$p_label, "p")
  expect_identical(r$output_refs, "fail")
  expect_identical(r$output_missing, "warn")
  expect_identical(r$output_markup, "fail")
  expect_identical(r$nproblems, 0L)
})

test_that("N28: p_digits: 3 is read as the whole number 3, and 6 is allowed", {
  r <- c7f("p3")
  expect_identical(r$p_digits, 3L)
  expect_identical(r$nproblems, 0L)
  expect_identical(c7f("p6")$p_digits, 6L)
})

test_that("N25: p_digits: null is the default and not a problem", {
  r <- c7f("pnull")
  expect_null(r$p_digits)
  expect_identical(r$nproblems, 0L)
})

test_that("N28: p_label: \"\" is read as the empty string, not the default; p_label: \"q\" as q", {
  e <- c7f("label_empty")
  expect_identical(e$p_label, "")
  expect_identical(e$nproblems, 0L)
  expect_identical(c7f("label_q")$p_label, "q")
})

test_that("N51: output_missing: off, and the three output_* settings, are read", {
  expect_identical(c7f("miss_off")$output_missing, "off")
  expect_identical(c7f("miss_off")$output_refs, "fail")
  r <- c7f("all_three")
  expect_identical(r$output_refs, "warn")
  expect_identical(r$output_missing, "fail")
  expect_identical(r$output_markup, "off")
  expect_identical(r$nproblems, 0L)
})

test_that("N25, N51: a document's weft: block wins over _weft.yml, in block and in flow style", {
  r <- c7f("doc_wins")
  expect_identical(r$p_digits, 2L)
  expect_identical(r$p_label, "")
  expect_identical(r$output_missing, "fail")
  f <- c7f("doc_flow")
  expect_identical(f$p_digits, 5L)
  expect_identical(f$p_label, "r")
})

test_that("E33: a p_digits outside 1 to 6 or not whole is one problem naming the key and value, and the default is used", {
  for (c in list(list("bad_p0", "0"), list("bad_p7", "7"), list("bad_p15", "1.5"), list("bad_pword", "three"))) {
    r <- c7f(c[[1]])
    expect_identical(r$nproblems, 1L, label = c[[1]])
    p <- r$problems[[1]]
    expect_identical(p$file, "_weft.yml", label = c[[1]])
    expect_identical(p$key, "p_digits", label = c[[1]])
    expect_identical(p$value, c[[2]], label = c[[1]])
    expect_true(is.character(p$what) && nzchar(p$what), label = c[[1]])
    expect_null(r$p_digits, label = c[[1]])
  }
})

test_that("E33: a wrong output_* value is one problem, and the default is used", {
  m <- c7f("bad_miss")
  expect_identical(m$nproblems, 1L)
  expect_identical(m$problems[[1]]$key, "output_missing")
  expect_identical(m$problems[[1]]$value, "maybe")
  expect_identical(m$output_missing, "warn")
  r <- c7f("bad_refs")
  expect_identical(r$nproblems, 1L)
  expect_identical(r$problems[[1]]$key, "output_refs")
  expect_identical(r$problems[[1]]$value, "true")
  expect_identical(r$output_refs, "fail")
  k <- c7f("bad_markup")
  expect_identical(k$nproblems, 1L)
  expect_identical(k$problems[[1]]$key, "output_markup")
  expect_identical(k$output_markup, "fail")
})

test_that("E33: a wrong value in the document's weft: block names the document, and the default is used", {
  r <- c7f("bad_doc")
  expect_identical(r$nproblems, 1L)
  expect_identical(r$problems[[1]]$file, "doc.md")
  expect_identical(r$problems[[1]]$key, "output_markup")
  expect_identical(r$problems[[1]]$value, "sometimes")
  # the default, not the project's "off"
  expect_identical(r$output_markup, "fail")
})
