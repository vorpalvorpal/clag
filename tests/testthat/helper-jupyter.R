# Package 6e: real Jupyter for the Python package's tests (dev/design-6.md, section 5, "Real Jupyter and
# Julia"). ASCII only.
#
# skip_if_no_jupyter() skips ONLY when `quarto` is absent or no Python with jupyter_client and ipykernel
# is found: QUARTO_PYTHON first, then python3 on the PATH, each probed with
#   <python> -I -c "import jupyter_client, ipykernel"
# The tests put inst/python on PYTHONPATH for the kernel, so the package under test is used and never an
# installed one. Nothing here installs a Python package. Everything is written under temporary folders;
# the kernel runs with its own JUPYTER_DATA_DIR, JUPYTER_RUNTIME_DIR and IPYTHONDIR.
#
# HELPERS
#   jupyter_python()          the Python found (a path), or NA.
#   skip_if_no_jupyter()      the skip above.
#   py_lib_6e()               the folder that holds the package `weft` (inst/python of the tree under test).
#   jup_session(cells, ...)   starts ONE kernel with jupyter_client (through a driver script run with
#                             system2()), runs the cells in order, and returns one result per cell:
#                             status ("ok" or "error"), ename, evalue, traceback, stdout, display (the
#                             text/markdown of each display_data and execute_result, in order), result (the
#                             text/plain of an execute_result, or NA), kinds (the output types in order),
#                             blocks (the parsed weft-values blocks), block_text (their raw JSON text).
#   py_plain(code, ...)       runs `python -c code` (no kernel) with inst/python on PYTHONPATH.
#   blocks_of(res)            all the parsed blocks of a session, in order.
#   e_msg                     message texts of section 7 used by 6e (E41, E42, E55, E59, E60, E61).
#   qm_project(files, ...)    a temporary Quarto project set up by weft::use_quarto(), with the files written.
#   qm_render(dir, ...)       `quarto render` in it with the Python and the package found.

.jup <- new.env()

jupyter_python <- function() {
  if (!is.null(.jup$python)) return(.jup$python)
  cands <- c(Sys.getenv("QUARTO_PYTHON"), unname(Sys.which("python3")))
  cands <- unique(cands[nzchar(cands)])
  found <- NA_character_
  for (p in cands) {
    st <- suppressWarnings(system2(p, c("-I", "-c", shQuote("import jupyter_client, ipykernel")),
                                   stdout = FALSE, stderr = FALSE))
    if (identical(as.integer(st), 0L)) { found <- p; break }
  }
  .jup$python <- found
  found
}

skip_if_no_jupyter <- function() {
  testthat::skip_if(!nzchar(Sys.which("quarto")), "quarto is not available")
  testthat::skip_if(is.na(jupyter_python()), "no Python with jupyter_client and ipykernel was found")
}

# ---- the driver --------------------------------------------------------------------------------------

jup_driver_source <- c(
  "import json, os, sys",
  "from queue import Empty",
  "from jupyter_client.manager import KernelManager",
  "spec = json.load(open(sys.argv[1], encoding='utf-8'))",
  "env = dict(os.environ)",
  "for k, v in spec['env'].items():",
  "    if v is None:",
  "        env.pop(k, None)",
  "    else:",
  "        env[k] = v",
  "km = KernelManager(kernel_name='python3')",
  "km.start_kernel(env=env, cwd=spec['cwd'])",
  "kc = km.client()",
  "kc.start_channels()",
  "kc.wait_for_ready(timeout=90)",
  "results = []",
  "try:",
  "    for cell in spec['cells']:",
  "        for op in cell.get('before', []):",
  "            p = op['path']",
  "            if op['op'] == 'write':",
  "                os.makedirs(os.path.dirname(p), exist_ok=True)",
  "                open(p, 'w', encoding='utf-8').write(op['text'])",
  "            elif op['op'] == 'remove':",
  "                os.remove(p)",
  "        mid = kc.execute(cell['code'], store_history=True)",
  "        res = {'status': None, 'ename': None, 'evalue': None, 'traceback': [], 'stdout': '', 'outputs': []}",
  "        while True:",
  "            try:",
  "                m = kc.get_iopub_msg(timeout=90)",
  "            except Empty:",
  "                res['status'] = 'timeout'",
  "                break",
  "            if m['parent_header'].get('msg_id') != mid:",
  "                continue",
  "            t, c = m['msg_type'], m['content']",
  "            if t == 'status' and c['execution_state'] == 'idle':",
  "                break",
  "            if t == 'stream' and c['name'] == 'stdout':",
  "                res['stdout'] += c['text']",
  "            elif t in ('display_data', 'execute_result'):",
  "                res['outputs'].append({'type': t, 'data': c['data']})",
  "            elif t == 'error':",
  "                res['outputs'].append({'type': 'error', 'data': {}})",
  "                res['ename'], res['evalue'], res['traceback'] = c['ename'], c['evalue'], c['traceback']",
  "        try:",
  "            rep = kc.get_shell_msg(timeout=90)",
  "            if res['status'] is None:",
  "                res['status'] = rep['content']['status']",
  "        except Empty:",
  "            res['status'] = res['status'] or 'timeout'",
  "        results.append(res)",
  "finally:",
  "    kc.stop_channels()",
  "    km.shutdown_kernel(now=True)",
  "json.dump(results, open(spec['out'], 'w', encoding='utf-8'))"
)

# cells: a list; each element is a string (the code) or list(code =, before = list(list(op = "write" |
# "remove", path =, text =), ...)). env: named list of environment variables for the kernel. Returns the
# per-cell results (see the header). The kernel's working folder is `cwd` (default: a fresh folder).
jup_session <- function(cells, env = list(), cwd = NULL, dir = NULL) {
  skip_if_no_jupyter()
  if (is.null(dir)) {
    dir <- tempfile("jup-")
    dir.create(dir)
    withr::defer(unlink(dir, recursive = TRUE), envir = parent.frame())
  }
  dir <- normalizePath(dir, winslash = "/")
  work <- file.path(dir, "kernel-work")
  dir.create(work, showWarnings = FALSE)
  if (is.null(cwd)) cwd <- work
  for (d in c("data", "runtime", "ipython")) dir.create(file.path(dir, d), showWarnings = FALSE)
  base_env <- list(
    PYTHONPATH = py_lib_6e(),
    JUPYTER_DATA_DIR = file.path(dir, "data"),
    JUPYTER_RUNTIME_DIR = file.path(dir, "runtime"),
    IPYTHONDIR = file.path(dir, "ipython"),
    PYTHONDONTWRITEBYTECODE = "1",
    WEFT_RUN = NA_character_, QUARTO_DOCUMENT_PATH = NA_character_, QUARTO_DOCUMENT_FILE = NA_character_,
    WEFT_DRAFT = NA_character_, WEFT_COLLECT = NA_character_
  )
  for (n in names(env)) base_env[[n]] <- env[[n]]
  cell_names <- names(cells)
  cells <- lapply(cells, function(x) if (is.character(x)) list(code = paste(x, collapse = "\n")) else x)
  names(cells) <- NULL
  out <- file.path(dir, "out.json")
  spec <- list(env = base_env, cwd = cwd, out = out, cells = cells)
  spec_path <- file.path(dir, "spec.json")
  writeLines(jsonlite::toJSON(spec, auto_unbox = TRUE, null = "null", na = "null"), spec_path, useBytes = TRUE)
  drv <- file.path(dir, "driver.py")
  writeLines(jup_driver_source, drv)
  log <- suppressWarnings(system2(jupyter_python(), c(shQuote(drv), shQuote(spec_path)), stdout = TRUE, stderr = TRUE))
  ok <- file.exists(out)
  testthat::expect(ok, paste("the kernel driver ran:", paste(utils::tail(log, 8), collapse = " / ")))
  if (!ok) return(rep(list(list(status = "driver failed", ename = NA_character_, evalue = NA_character_,
                                traceback = character(), stdout = "", display = character(), result = NA_character_,
                                kinds = character(), blocks = list(), block_text = character())), length(cells)))
  raw <- jsonlite::fromJSON(out, simplifyVector = FALSE)
  res <- lapply(raw, jup_result)
  if (!is.null(cell_names)) names(res) <- cell_names
  res
}

block_re <- "^\\s*````\\{\\.weft-values\\}\\n(.*)\\n````\\s*$"

jup_result <- function(r) {
  disp <- character()
  result <- NA_character_
  kinds <- character()
  for (o in r$outputs) {
    md <- o$data[["text/markdown"]]
    md <- if (is.null(md)) NA_character_ else paste(unlist(md), collapse = "")
    if (!is.na(md)) disp <- c(disp, md)
    if (identical(o$type, "execute_result")) result <- paste(unlist(o$data[["text/plain"]]), collapse = "")
    kinds <- c(kinds, if (!is.na(md) && grepl(block_re, md)) "block" else o$type)
  }
  texts <- sub(block_re, "\\1", disp[grepl(block_re, disp)])
  list(status = r$status, ename = if (is.null(r$ename)) NA_character_ else r$ename,
       evalue = if (is.null(r$evalue)) NA_character_ else r$evalue,
       traceback = unlist(r$traceback), stdout = r$stdout, display = disp, result = result,
       kinds = kinds, block_text = texts,
       blocks = lapply(texts, function(t) jsonlite::fromJSON(t, simplifyVector = FALSE)))
}

blocks_of <- function(res) unlist(lapply(res, function(r) r$blocks), recursive = FALSE)

# ---- plain Python (no kernel) ------------------------------------------------------------------------

py_plain <- function(code, env = character()) {
  skip_if_no_jupyter()
  vars <- c(PYTHONPATH = py_lib_6e(), PYTHONDONTWRITEBYTECODE = "1", WEFT_RUN = NA, IPYTHONDIR = withr::local_tempdir())
  for (n in names(env)) vars[[n]] <- env[[n]]
  withr::local_envvar(vars)
  errf <- tempfile("py-err-")
  on.exit(unlink(errf), add = TRUE)
  out <- suppressWarnings(system2(jupyter_python(), c("-c", shQuote(code)), stdout = TRUE, stderr = errf))
  st <- attr(out, "status")
  list(stdout = paste(out, collapse = "\n"), stderr = paste(readLines(errf, warn = FALSE), collapse = "\n"),
       status = if (is.null(st)) 0L else as.integer(st))
}

# ---- messages of section 7 ---------------------------------------------------------------------------

e_msg <- list(
  E41 = function(name) sprintf("`%s` is not a name weft can publish: ASCII letters, digits, _ and ., starting with a letter or _ (rule 1.12.1).", name),
  E42 = function(name, n) sprintf("`%s` is a list of %d elements; weft publishes at most 10000 (rule 2.13.1).", name, n),
  E59 = "auto() works in a Jupyter kernel or a weft knit.",
  E60 = function(path) sprintf("auto() cannot read the document %s; give it: auto(\"doc.qmd\").", path),
  E61 = "Install the Python package in the Python Quarto uses: pip install \"git+https://github.com/vorpalvorpal/weft#subdirectory=inst/python\"",
  E62 = "Install the Julia package: using Pkg; Pkg.add(url = \"https://github.com/vorpalvorpal/weft\", subdir = \"inst/julia/Weft\")"
)

# ---- Quarto projects on the jupyter engine -----------------------------------------------------------

# files: a named list of lines. The project is set up by use_quarto() (its messages dropped); `project_yml`
# is the text of _quarto.yml.
qm_project <- function(files, project_yml = c("project:", "  type: default", "format: html")) {
  dir <- withr::local_tempdir(.local_envir = parent.frame())
  dir <- normalizePath(dir, winslash = "/")
  writeLines(project_yml, file.path(dir, "_quarto.yml"))
  put_files(dir, files)
  suppressMessages(utils::capture.output(weft::use_quarto(dir)))
  dir
}

# `quarto render <args>` in dir, with the Python found, the package under test and private Jupyter folders.
# The run id is unset unless `env` gives WEFT_RUN. Returns list(status, log, stderr, stdout).
qm_render <- function(dir, args = character(), env = character()) {
  skip_if_no_jupyter()
  scratch <- withr::local_tempdir()
  for (d in c("data", "runtime", "ipython")) dir.create(file.path(scratch, d))
  vars <- c(NO_COLOR = "1", WEFT_DRAFT = NA, WEFT_COLLECT = NA, WEFT_RUN = NA,
            QUARTO_PYTHON = jupyter_python(), PYTHONPATH = py_lib_6e(), PYTHONDONTWRITEBYTECODE = "1",
            JUPYTER_DATA_DIR = file.path(scratch, "data"), JUPYTER_RUNTIME_DIR = file.path(scratch, "runtime"),
            IPYTHONDIR = file.path(scratch, "ipython"))
  quarto_render_env(dir, args, vars, env)
}

