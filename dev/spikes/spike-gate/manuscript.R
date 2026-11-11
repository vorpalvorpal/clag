## spike-gate/manuscript.R -- structured test manuscript + render + edit helpers (throwaway)
P   <- function(name, text) list(name = name, type = "p", text = text)
RAW <- function(name, ...) list(name = name, type = "raw", lines = c(...))
SEC <- function(anchor, title, ...) list(anchor = anchor, title = title, blocks = list(...))

topics <- c("alluvial","bedrock","colluvial","deltaic","estuarine","fluvial","glacial","hyporheic","igneous","joint",
 "karst","limestone","marine","nodular","orogenic","perched","quartzite","riparian","shale","tidal","upland",
 "volcanic","weathered","xeric","yielding","zonal","aquitard","basalt","clay","dolerite","evaporite","fault",
 "gneiss","humic","inland","jointed","kaolin","loam","marl","neritic","oolitic","peat","quartz","regolith",
 "silt","till","umber","varved","wetland","xenolith")
filler <- function(s, k) {
  t <- topics[(s - 1L) * 5L + k]; tmpl <- (s + k) %% 5L
  txt <- switch(as.character(tmpl),
   "0" = sprintf('Readings from the %s bores averaged `r avg_%s`{.num} m, ranging up to `r max_%s`{.num} m, and the %s record was otherwise unremarkable.', t, t, t, t),
   "1" = sprintf('Of the %s records, `r share_%s`{.pct} were complete across `r n_sites`{.num} sites, so the %s subset was retained.', t, t, t),
   "2" = sprintf('We excluded `r drop_%s`{.num} [%s reading | # %s readings]{n="drop_%s"} from the %s series because of obvious faults.', t, t, t, t, t),
   "3" = sprintf('The %s trend was [upward | downward]{sign="trend_%s"} at `r slope_%s`{.num} m per year, a modest signal against the %s background.', t, t, t, t),
   "4" = sprintf('Across `r n_events`{.num} [event | # events]{n="n_events"}, the %s response lagged by `r lag_%s`{.num} days in the %s zone.', t, t, t))
  P(sprintf("f%d.%d", s, k), txt)
}
fills <- function(s, ks = 1:4) lapply(ks, function(k) filler(s, k))

base_doc <- function() {
  S <- list(
  SEC("sec-intro", "Introduction",
    P("I1", 'We monitored `r n_sites`{.num} [a site | # sites]{n="n_sites"} between `r start_year`{.num} and `r end_year`{.num}, and the programme [has | have]{n="n_programmes"} continued since.'),
    P("I2", 'The mean depth to water was `r mean(depth)`{.num} m, which [rose | fell]{sign="delta_depth"} over the period.'),
    P("I3", 'Rainfall averaged `r mean(rain)`{.num} mm per year across `r n_sites`{.num} sites.'),
    P("I4", 'Earlier surveys used `r n_old_surveys`{.num} stations and reported `r old_mean`{.num} m.'),
    fills(1)),
  SEC("sec-methods", 'Methods for `r n_sites`{.num} sites',
    P("M1", 'A site was retained only when it had at least `r claim(n_sites, . > 10)`{.num} readings[ (relaxed rule) | ]{if="relaxed"}.'),
    P("M2", 'Water levels were summarised by their `r mean(level)`{.num} and `r sd(level)`{.num}, using `r n_loggers`{.num} loggers.'),
    P("M3", 'Calibration used `r n_cal`{.num} reference points.'),
    RAW("L1", '- Loggers: `r n_loggers`{.num} deployed', '- Interval: `r interval_min`{.num} minutes', '- Duration: `r duration_days`{.num} days'),
    P("FN1", 'Drift was small.^[The drift averaged `r mean(drift)`{.num} mm per year.]'),
    P("FN2", 'Tides matter.[^tide]'),
    RAW("FNDEF", '[^tide]: Tidal range was `r tide_range`{.num} m.'),
    fills(2)),
  SEC("sec-data", "Data",
    P("D1", 'Data come from `r n_sources`{.num} sources.'),
    P("D2", 'Each source reported at `r interval_min`{.num} minute intervals.'),
    RAW("TB1", '| Site | Depth (m) | Readings |', '|------|-----------|----------|',
        '| A    | `r depth_a`{.num} | `r n_a`{.num} |', '| B    | `r depth_b`{.num} | `r n_b`{.num} |'),
    RAW("TBC", ': Depths at `r n_sites`{.num} sites {#tbl-depth}'),
    RAW("CH1", '```{r}', '#| label: fig-map', '#| fig-cap: "Map of `r n_sites`{.num} sites in `r n_regions`{.num} regions"', 'plot(x)', '```'),
    RAW("CH2", '```{r}', '#| label: fig-hydro', '#| fig-cap: "Hydrograph for `r n_hydro`{.num} bores"', 'plot(y)', '```'),
    fills(3)),
  SEC("sec-results", "Results",
    P("R1", 'At `r n_sites`{.num} sites the median was `r median(depth)`{.num} m (`r pct_pass`{.pct} passing).'),
    P("R2", 'Of these, `r mean(depth)`{.num} m was the overall mean depth and `r n_events`{.num} [event | # events]{n="n_events"} exceeded it.'),
    RAW("BQ1", '> As one reviewer put it, `r n_quoted`{.num} events is too many.'),
    RAW("DIV1", '::: {.callout-note}', 'Note that `r n_flagged`{.num} readings were flagged.', ':::'),
    P("R3", 'The deepest bore reached `r depth_max`{#dmax .num} m, deeper than `r depth_prev`{#dprev .num} m before.'),
    P("R4", 'Drift was detected[ at `r n_drift`{.num} sites | ]{if="drift_found"}.'),
    P("R5", 'Sites with a depth of `r claim(depth_ok, . < 3)`{.num} m counted as shallow.'),
    fills(4)),
  SEC("sec-discussion", "Discussion",
    P("Di1", 'These results from `r n_sites`{.num} sites agree with `r n_published`{.num} published studies.'),
    P("Di2", 'A reading of `r mean(depth)`{.num} m is typical of the region.'),
    P("Di3", 'The `r n_events`{.num} [event | # events]{n="n_events"} are discussed further in the appendix.'),
    P("DupA", 'All figures are reported to `r digits`{.num} decimal places.'),
    P("DupB", 'All figures are reported to `r digits`{.num} decimal places.'),
    fills(5)),
  SEC("sec-limits", "Limitations",
    P("Li1", 'The main limitation is that only `r n_sites`{.num} sites were gauged.'),
    P("Li2", 'Logger error was `r logger_err`{.num} mm[, a small | , a large]{if="err_large"} effect.'),
    fills(6)),
  SEC("sec-concl", "Conclusion",
    P("C1", 'In summary, `r n_sites`{.num} sites showed a [rise | fall]{sign="delta_depth"} of `r delta_depth`{.num} m.'),
    P("C2", 'We recommend `r n_new_sites`{.num} new [site | # sites]{n="n_new_sites"}.'),
    fills(7)),
  SEC("sec-app-a", "Appendix A",
    P("A1", 'Raw counts were `r n_raw`{.num} per site.'),
    P("A2", 'Missing values: `r n_missing`{.pct}.'),
    fills(8)),
  SEC("sec-app-b", "Appendix B",
    P("B1", 'Instrument serials are listed for `r n_loggers`{.num} loggers.'),
    P("B2", 'Reference elevations were surveyed to `r elev_tol`{.num} mm.'),
    fills(9)),
  SEC("sec-app-c", "Appendix C",
    P("Z1", 'Code is available for all `r n_sites`{.num} sites.'),
    P("Z2", 'Cleaning removed `r n_removed`{.num} [row | # rows]{n="n_removed"}.'),
    fills(10)))
  ## flatten nested filler lists
  for (i in seq_along(S)) { b <- list(); for (x in S[[i]]$blocks) if (!is.null(x$name)) b[[length(b) + 1L]] <- x else for (y in x) b[[length(b) + 1L]] <- y; S[[i]]$blocks <- b }
  list(front = c("---", 'title: "Groundwater trends"', "format: html", "---"), secs = S)
}

wrap <- function(t, width, hash_safe = TRUE) {            # hash_safe: never break so that "# " lands at a line start
  if (!hash_safe) return(strwrap(t, width = width))
  t <- gsub("`r ", "`r\u0001", t, fixed = TRUE); t <- gsub(" # ", "\u0001#\u0001", t, fixed = TRUE); t <- gsub(" > ", "\u0001>\u0001", t, fixed = TRUE); gsub("\u0001", " ", strwrap(t, width = width), fixed = TRUE) }
render_doc <- function(doc, width = 72, hash_safe = TRUE) {
  out <- c(doc$front, "")
  for (s in doc$secs) {
    out <- c(out, sprintf("## %s {#%s}", s$title, s$anchor), "")
    for (b in s$blocks) out <- c(out, if (b$type == "p") wrap(b$text, width, hash_safe) else b$lines, "")
  }
  out
}

## ---- edit helpers ----
loc <- function(doc, name) { for (s in seq_along(doc$secs)) { i <- which(vapply(doc$secs[[s]]$blocks, function(b) identical(b$name, name), NA)); if (length(i)) return(c(s, i)) }; stop("no block ", name) }
sloc <- function(doc, anchor) { s <- which(vapply(doc$secs, function(x) x$anchor == anchor, NA)); if (!length(s)) stop("no section ", anchor); s }
subt <- function(doc, name, from, to) { l <- loc(doc, name); b <- doc$secs[[l[1]]]$blocks[[l[2]]]
  if (b$type == "p") { stopifnot(grepl(from, b$text, fixed = TRUE)); b$text <- sub(from, to, b$text, fixed = TRUE) }
  else { stopifnot(any(grepl(from, b$lines, fixed = TRUE))); b$lines <- sub(from, to, b$lines, fixed = TRUE) }
  doc$secs[[l[1]]]$blocks[[l[2]]] <- b; doc }
settext <- function(doc, name, text) { l <- loc(doc, name); doc$secs[[l[1]]]$blocks[[l[2]]]$text <- text; doc }
setlines <- function(doc, name, lines) { l <- loc(doc, name); doc$secs[[l[1]]]$blocks[[l[2]]]$lines <- lines; doc }
delb <- function(doc, name) { l <- loc(doc, name); doc$secs[[l[1]]]$blocks[[l[2]]] <- NULL; doc }
insb <- function(doc, after, blk) { if (after %in% vapply(doc$secs, function(s) s$anchor, "")) { s <- sloc(doc, after); doc$secs[[s]]$blocks <- c(list(blk), doc$secs[[s]]$blocks); return(doc) }
  l <- loc(doc, after); bl <- doc$secs[[l[1]]]$blocks; doc$secs[[l[1]]]$blocks <- append(bl, list(blk), after = l[2]); doc }
getb <- function(doc, name) { l <- loc(doc, name); doc$secs[[l[1]]]$blocks[[l[2]]] }
moveb <- function(doc, name, after) { b <- getb(doc, name); doc <- delb(doc, name); insb(doc, after, b) }
delsec <- function(doc, anchor) { doc$secs[[sloc(doc, anchor)]] <- NULL; doc }
movesec <- function(doc, anchor, after) { s <- doc$secs[[sloc(doc, anchor)]]; doc <- delsec(doc, anchor); k <- sloc(doc, after); doc$secs <- append(doc$secs, list(s), after = k); doc }
rename_anchor <- function(doc, from, to) { s <- sloc(doc, from); doc$secs[[s]]$anchor <- to; doc }
settitle <- function(doc, anchor, title) { doc$secs[[sloc(doc, anchor)]]$title <- title; doc }

if (sys.nframe() == 0L || identical(Sys.getenv("MS_MAIN"), "1")) {
  source("lib.R"); d <- base_doc(); L <- render_doc(d)
  writeLines(L, "out/manuscript.qmd")
  u <- extract_units(L)
  cat("sections:", length(d$secs), " units:", length(u), " plain-p blocks:", sum(vapply(d$secs, function(s) sum(vapply(s$blocks, function(b) b$type == "p", NA)), 0L)),
      " constructs:", length(unlist(lapply(u, `[[`, "ids"))), "\n")
  print(table(vapply(u, `[[`, "", "type")))
  ids <- unlist(lapply(u, `[[`, "ids")); cat("distinct identities:", length(unique(ids)), " repeated:", sum(table(ids) > 1), "\n")
  print(head(sort(table(ids), decreasing = TRUE), 8))
}
