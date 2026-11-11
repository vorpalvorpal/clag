## Matrix runner: Rscript run.R   (add --skip-extras to run only the case matrix)
source(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), "lib.R"))
source(file.path(ROOT, "cases.R"))
unlink(list.files(OUT, pattern = "^(g_|c_)", full.names = TRUE), recursive = TRUE)
engines <- c("quarto", "rmarkdown")
res <- list()      # res[[id]][[engine]] = list(pass, detail)

judge <- function(cs, engine, actual) {
  want <- cs[[if (engine == "quarto") "expect_q" else "expect_r"]] %||% cs$expect
  want_n <- norm(want)
  ok <- if (cs$match == "contains") grepl(want_n, actual, fixed = TRUE) else identical(actual, want_n)
  list(pass = ok, detail = if (!ok) sprintf("expected %s'%s' got '%s'", if (cs$match == "contains") "(contains) " else "", want_n, actual))
}
check_html <- function(cs, htmlpath) {
  if (is.null(cs$html)) return(NULL)
  h <- paste(readLines(htmlpath, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  if (!grepl(cs$html, h, fixed = TRUE)) sprintf("html lacks %s", cs$html)
}

for (engine in engines) {
  active <- Filter(function(cs) engine %in% cs$engines, cases)
  group_cs <- Filter(function(cs) !cs$solo, active)
  solo_cs <- Filter(function(cs) cs$solo, active)
  record <- function(id, r) res[[id]][[engine]] <<- r
  run_solo <- function(cs) {
    b <- build_doc(paste0("c_", cs$id), list(cs), engine); r <- render_doc(b$path, engine)
    if (!is.null(cs$error)) {
      line <- b$starts[[cs$id]] + cs$at - 1L; where <- paste0(b$name, ":", line)
      ok <- !r$ok && grepl(cs$error, r$log, fixed = TRUE) && grepl(where, r$log, fixed = TRUE)
      detail <- if (!ok) paste0("wanted error containing '", cs$error, "' at ", where, "; ",
                                if (r$ok) "render SUCCEEDED" else paste("log:", substr(gsub("\\s+", " ", regmatches(r$log, regexpr("clag:[^\n]*", r$log))), 1, 200)))
      record(cs$id, list(pass = ok, detail = detail))
    } else if (!r$ok) record(cs$id, list(pass = FALSE, detail = paste("render failed:", substr(gsub("\\s+", " ", r$log), 1, 300))))
    else {
      seg <- segments(html_text(r$out))[[cs$id]] %||% "<marker missing>"
      j <- judge(cs, engine, seg); h <- check_html(cs, r$out)
      if (!is.null(h)) { j$pass <- FALSE; j$detail <- paste(j$detail, h) }
      record(cs$id, j)
    }
  }
  b <- build_doc("g_main", group_cs, engine); r <- render_doc(b$path, engine)
  cat(sprintf("[%s] group doc: %s (%.1fs)\n", engine, if (r$ok) "rendered" else "FAILED", r$secs))
  if (r$ok) {
    segs <- segments(html_text(r$out)); hh <- paste(readLines(r$out, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    for (cs in group_cs) {
      j <- judge(cs, engine, segs[[cs$id]] %||% "<marker missing>")
      if (!is.null(cs$html) && !grepl(cs$html, hh, fixed = TRUE)) { j$pass <- FALSE; j$detail <- paste(j$detail, "html lacks", cs$html) }
      record(cs$id, j)
    }
  } else { cat("  falling back to one document per case; group log tail:\n", substr(r$log, max(1, nchar(r$log) - 400), nchar(r$log)), "\n"); for (cs in group_cs) run_solo(cs) }
  for (cs in solo_cs) { cat(sprintf("[%s] %s\n", engine, cs$id)); run_solo(cs) }
}

## ---- matrix ----------------------------------------------------------------
cell <- function(id, e) { r <- res[[id]][[e]]; if (is.null(r)) "  -  " else if (r$pass) "PASS" else "FAIL" }
mat <- data.frame(id = vapply(cases, `[[`, "", "id"), group = vapply(cases, `[[`, "", "group"), stringsAsFactors = FALSE)
mat$quarto <- vapply(mat$id, cell, "", "quarto"); mat$rmarkdown <- vapply(mat$id, cell, "", "rmarkdown")
cat("\n"); print(mat, row.names = FALSE)
npass <- function(e) sum(mat[[e]] == "PASS"); nfail <- function(e) sum(mat[[e]] == "FAIL")
cat(sprintf("\nquarto: %d PASS, %d FAIL | rmarkdown: %d PASS, %d FAIL ('-' = not run for that engine)\n", npass("quarto"), nfail("quarto"), npass("rmarkdown"), nfail("rmarkdown")))
for (id in mat$id) for (e in engines) { r <- res[[id]][[e]]; if (!is.null(r) && !r$pass) cat(sprintf("FAIL %s [%s]: %s\n", id, e, r$detail)) }
saveRDS(res, file.path(OUT, "matrix.rds"))
if (!"--skip-extras" %in% commandArgs(TRUE) && file.exists(file.path(ROOT, "extras.R"))) source(file.path(ROOT, "extras.R"))
