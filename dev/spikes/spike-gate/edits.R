## spike-gate/edits.R -- scripted edits with hand-written correct classifications.
## Each: id, desc, f(doc)->doc, exp (character vector of expected non-trivial events), width, sem (rule-level blind spot note).
D0 <- base_doc()
V  <- function(e, cls = "num") paste0("v:", canon(e), "|", paste(sort(cls), collapse = " "))
G  <- function(key, val) paste0("g:", key, "=", canon(val))
ID <- function(x) paste0("id:", x)
R_ <- function(...) vapply(c(...), function(i) evkey("removed", i), "")
A_ <- function(...) vapply(c(...), function(i) evkey("added", i), "")
E_ <- function(b, a) evkey("edited", b, a)
btxt <- function(b) if (b$type == "p") b$text else paste(b$lines, collapse = " ")
ids_blk <- function(...) unlist(lapply(c(...), function(nm) scan_ids(btxt(getb(D0, nm)))))
ids_sec <- function(anchor) { s <- D0$secs[[sloc(D0, anchor)]]; c(scan_ids(s$title), unlist(lapply(s$blocks, function(b) scan_ids(btxt(b))))) }
nm <- function(...) unname(c(...))

EDITS <- list()
ed <- function(id, desc, f, exp = character(), width = 72, sem = NA_character_, hash_safe = TRUE)
  EDITS[[id]] <<- list(id = id, desc = desc, f = f, exp = if (is.function(exp)) exp else unname(exp), width = width, sem = sem, hash_safe = hash_safe)

ed("E01", "loosen one check's bound (. > 10 -> . > 5)", function(d) subt(d, "M1", ". > 10", ". > 5"),
   E_(V("claim(n_sites, . > 10)"), V("claim(n_sites, . > 5)")))
ed("E02", "mean(depth) -> median(depth)", function(d) subt(d, "I2", "mean(depth)", "median(depth)"),
   E_(V("mean(depth)"), V("median(depth)")))
ed("E03", "computed value -> literal construct `r 812`{.num}", function(d) subt(d, "I3", "`r mean(rain)`", "`r 812`"),
   E_(V("mean(rain)"), V("812")))
ed("E04", "computed value -> plain-prose number (construct gone)", function(d) subt(d, "I3", "`r mean(rain)`{.num}", "812"),
   R_(V("mean(rain)")))
ed("E05", "delete a construct, reword the sentence around it", function(d) settext(d, "I1", 'We monitored `r n_sites`{.num} [a site | # sites]{n="n_sites"} in the years to `r end_year`{.num}, and the programme [has | have]{n="n_programmes"} continued since.'),
   R_(V("start_year")))
ed("E06", "delete a whole paragraph (2 constructs)", function(d) delb(d, "I4"), R_(V("n_old_surveys"), V("old_mean")))
ed("E07", "delete a whole section (sec-limits)", function(d) delsec(d, "sec-limits"), R_(ids_sec("sec-limits")))
ed("E08", "insert a paragraph above the first paragraph of a section",
   function(d) insb(d, "sec-intro", P("N1", 'This study asks whether `r n_new_q`{.num} questions can be answered.')), A_(V("n_new_q")))
ed("E09", "insert a paragraph between two edited ones (M1 bound, M2 mean->median)", function(d) {
   d <- subt(d, "M1", ". > 10", ". > 5"); d <- subt(d, "M2", "mean(level)", "median(level)")
   insb(d, "M1", P("N2", 'Loggers were checked by `r n_checkers`{.num} staff.')) },
   c(E_(V("claim(n_sites, . > 10)"), V("claim(n_sites, . > 5)")), E_(V("mean(level)"), V("median(level)")), A_(V("n_checkers"))))
ed("E10", "split a paragraph in two (no construct lost)", function(d) {
   d <- settext(d, "M2", 'Water levels were summarised by their `r mean(level)`{.num} and `r sd(level)`{.num}.')
   insb(d, "M2", P("M2b", 'We used `r n_loggers`{.num} loggers.')) })
ed("E11", "merge two paragraphs (no construct lost)", function(d) {
   d <- settext(d, "D1", paste(getb(D0, "D1")$text, getb(D0, "D2")$text)); delb(d, "D2") })
ed("E12", "move a paragraph within its section", function(d) moveb(d, "I3", "I4"))
ed("E13", "move a paragraph to another section (unchanged)", function(d) moveb(d, "M3", "D1"))
ed("E14", "move a section (sec-limits after sec-concl)", function(d) movesec(d, "sec-limits", "sec-concl"))
ed("E15", "rename a section's anchor, nothing else", function(d) rename_anchor(d, "sec-limits", "sec-limitations"))
ed("E16", "reflow line wraps only (72 -> 55)", function(d) d, width = 55)
TRUTH_BY_COUNT <- function(lb, la) R_(baseline_removals(lb, la))   # for reflow hazards: whatever the scanner no longer sees IS removed
ed("E16b", "reflow (55) with plain strwrap: wraps can land '# ' / '> ' at a line start and break right after `r", function(d) d, exp = TRUTH_BY_COUNT, width = 55, hash_safe = FALSE,
   sem = "a line starting '# ' is a heading to Pandoc, '> ' a block quote, and knitr needs '`r ' + space: such a reflow really changes the render")
ed("E17", "change only arm text", function(d) subt(d, "I1", "[a site | # sites]", "[one site | # sites]"))
ed("E18", "reorder attributes, change quoting, add spaces in braces", function(d) {
   d <- subt(d, "R3", "{#dmax .num}", "{.num #dmax}"); d <- subt(d, "I1", 'n="n_sites"', "n='n_sites'")
   subt(d, "R5", "`{.num}", "`{ .num }") })
ed("E19", "add an #id to an existing construct", function(d) subt(d, "I2", "`r mean(depth)`{.num}", "`r mean(depth)`{#dmean .num}"),
   E_(V("mean(depth)"), ID("dmean")))
ed("E20", "remove an #id from a construct", function(d) subt(d, "R3", "{#dmax .num}", "{.num}"), E_(ID("dmax"), V("depth_max")))
ed("E21", "two adjacent paragraphs both edited (I2, I3)", function(d) { d <- subt(d, "I2", "mean(depth)", "median(depth)"); subt(d, "I3", "mean(rain)", "median(rain)") },
   c(E_(V("mean(depth)"), V("median(depth)")), E_(V("mean(rain)"), V("median(rain)"))))
ed("E22", "edit in a paragraph that also gets a sentence added", function(d) {
   d <- subt(d, "I3", "mean(rain)", "median(rain)"); settext(d, "I3", paste(getb(d, "I3")$text, 'We also logged `r n_gauges`{.num} gauges.')) },
   c(E_(V("mean(rain)"), V("median(rain)")), A_(V("n_gauges"))))
ed("E23", "swap two constructs between non-adjacent paragraphs (I1 start_year <-> I4 old_mean)", function(d) {
   d <- subt(d, "I1", "`r start_year`", "`r old_mean`"); subt(d, "I4", "`r old_mean`", "`r start_year`") },
   c(E_(V("start_year"), V("old_mean")), E_(V("old_mean"), V("start_year"))))
ed("E24", "same identity removed from one paragraph, added in another (same section)", function(d) {
   d <- settext(d, "I1", 'We monitored `r n_sites`{.num} [a site | # sites]{n="n_sites"} to `r end_year`{.num}, and the programme [has | have]{n="n_programmes"} continued since.')
   settext(d, "I4", 'Earlier surveys since `r start_year`{.num} used `r n_old_surveys`{.num} stations and reported `r old_mean`{.num} m.') },
   character(), sem = "moved by count rule; semantically start_year was dropped from I1 (and re-added in I4)")
ed("E25", "COMBINED: bound loosened + delete paragraph + insert above + move section + reflow", function(d) {
   d <- subt(d, "M1", ". > 10", ". > 5"); d <- delb(d, "I4"); d <- insb(d, "sec-intro", P("N1", 'This study asks whether `r n_new_q`{.num} questions can be answered.'))
   movesec(d, "sec-app-b", "sec-concl") }, width = 66,
   c(E_(V("claim(n_sites, . > 10)"), V("claim(n_sites, . > 5)")), R_(V("n_old_surveys"), V("old_mean")), A_(V("n_new_q"))))
ed("E26", "COMBINED: split M2 + loosen M1 (adjacent) + rename sec-data anchor", function(d) {
   d <- subt(d, "M1", ". > 10", ". > 5")
   d <- settext(d, "M2", 'Water levels were summarised by their `r mean(level)`{.num} and `r sd(level)`{.num}.'); d <- insb(d, "M2", P("M2b", 'We used `r n_loggers`{.num} loggers.'))
   rename_anchor(d, "sec-data", "sec-datasets") },
   E_(V("claim(n_sites, . > 10)"), V("claim(n_sites, . > 5)")))
ed("E27", "COMBINED: add id (I2) + adjacent edits R1,R2 + delete sec-app-c + move M3 elsewhere", function(d) {
   d <- subt(d, "I2", "`r mean(depth)`{.num}", "`r mean(depth)`{#dmean .num}")
   d <- subt(d, "R1", "pct_pass", "pct_ok"); d <- subt(d, "R2", "`r n_events`{.num}", "`r n_valid_events`{.num}")
   d <- delsec(d, "sec-app-c"); moveb(d, "M3", "D1") },
   c(E_(V("mean(depth)"), ID("dmean")), E_(V("pct_pass", "pct"), V("pct_ok", "pct")), E_(V("n_events"), V("n_valid_events")), R_(ids_sec("sec-app-c"))))
ed("E28", "change a span's key value (n_sites -> n_valid_sites)", function(d) subt(d, "I1", 'n="n_sites"', 'n="n_valid_sites"'),
   E_(G("n", "n_sites"), G("n", "n_valid_sites")))
ed("E29", "change a span's `if` condition", function(d) subt(d, "R4", 'if="drift_found"', 'if="drift_found & n_drift > 2"'),
   E_(G("if", "drift_found"), G("if", "drift_found & n_drift > 2")))
ed("E30", "delete a governed span (leave plain 'has')", function(d) subt(d, "I1", '[has | have]{n="n_programmes"}', "has"), R_(G("n", "n_programmes")))
ed("E31", "delete a construct from a heading", function(d) settitle(d, "sec-methods", "Methods"), R_(V("n_sites")))
ed("E32", "edit a construct in a heading", function(d) settitle(d, "sec-methods", 'Methods for `r n_valid`{.num} sites'), E_(V("n_sites"), V("n_valid")))
ed("E33", "edit a construct in a list item", function(d) subt(d, "L1", "`r n_loggers`", "`r n_loggers_active`"), E_(V("n_loggers"), V("n_loggers_active")))
ed("E34", "delete a list item", function(d) setlines(d, "L1", getb(D0, "L1")$lines[1:2]), R_(V("duration_days")))
ed("E35", "edit a construct in a table cell", function(d) subt(d, "TB1", "`r depth_a`", "`r depth_a_adj`"), E_(V("depth_a"), V("depth_a_adj")))
ed("E36", "delete a table row", function(d) setlines(d, "TB1", getb(D0, "TB1")$lines[1:3]), R_(V("depth_b"), V("n_b")))
ed("E37", "edit a footnote definition", function(d) subt(d, "FNDEF", "tide_range", "tide_range_m"), E_(V("tide_range"), V("tide_range_m")))
ed("E38", "delete a footnote definition", function(d) delb(d, "FNDEF"), R_(V("tide_range")))
ed("E39", "edit a chunk-option caption construct", function(d) subt(d, "CH1", "n_regions", "n_zones"), E_(V("n_regions"), V("n_zones")))
ed("E40", "remove a construct from a chunk-option caption", function(d) subt(d, "CH1", " in `r n_regions`{.num} regions", ""), R_(V("n_regions")))
ed("E41", "delete a whole chunk with a caption", function(d) delb(d, "CH2"), R_(V("n_hydro")))
ed("E42", "edit a construct in a block quote", function(d) subt(d, "BQ1", "n_quoted", "n_quoted_total"), E_(V("n_quoted"), V("n_quoted_total")))
ed("E43", "edit a construct inside a div", function(d) subt(d, "DIV1", "n_flagged", "n_flagged_total"), E_(V("n_flagged"), V("n_flagged_total")))
ed("E44", "change a formatter class (.pct -> .num)", function(d) subt(d, "R1", "`{.pct}", "`{.num}"), E_(V("pct_pass", "pct"), V("pct_pass", "num")))
ed("E45", "add a formatter class (.pct -> .pct .dec1)", function(d) subt(d, "A2", "{.pct}", "{.pct .dec1}"), E_(V("n_missing", "pct"), V("n_missing", c("pct", "dec1"))))
ed("E46", "edit a construct in an inline footnote", function(d) subt(d, "FN1", "mean(drift)", "median(drift)"), E_(V("mean(drift)"), V("median(drift)")))
ed("E47", "ADVERSARIAL: delete a paragraph, insert an unrelated one in its place", function(d) settext(d, "A1", 'Metadata were stored by `r n_archive`{.num} archives.'),
   c(R_(V("n_raw")), A_(V("n_archive"))))
ed("E48", "edit a paragraph whose neighbour is deleted (R1 edited, R2 deleted)", function(d) { d <- subt(d, "R1", "pct_pass", "pct_ok"); delb(d, "R2") },
   c(E_(V("pct_pass", "pct"), V("pct_ok", "pct")), R_(V("mean(depth)"), V("n_events"), G("n", "n_events"))))
ed("E49", "insert a paragraph directly above an edited one (D1)", function(d) {
   d <- subt(d, "D1", "n_sources", "n_sources_all"); insb(d, "sec-data", P("N3", 'We begin with `r n_prelim`{.num} preliminary checks.')) },
   c(E_(V("n_sources"), V("n_sources_all")), A_(V("n_prelim"))))
ed("E50", "edit a heading's words, anchor and constructs unchanged", function(d) settitle(d, "sec-data", "Data sources"))
ed("E51", "rename a section's anchor AND loosen a bound in it", function(d) rename_anchor(subt(d, "M1", ". > 10", ". > 5"), "sec-methods", "sec-methods2"),
   E_(V("claim(n_sites, . > 10)"), V("claim(n_sites, . > 5)")))
ed("E52", "move a paragraph to another section AND edit it", function(d) moveb(subt(d, "M3", "n_cal", "n_cal_pts"), "M3", "D1"),
   E_(V("n_cal"), V("n_cal_pts")))
ed("E53", "delete one of two identical adjacent paragraphs", function(d) delb(d, "DupB"), R_(V("digits")))
ed("E54", "edit the second of two identical adjacent paragraphs", function(d) subt(d, "DupB", "`r digits`", "`r digits_out`"), E_(V("digits"), V("digits_out")))
ed("E55", "edit the first of two identical adjacent paragraphs", function(d) subt(d, "DupA", "`r digits`", "`r digits_out`"), E_(V("digits"), V("digits_out")))
ed("E56", "remove one #id'd construct and reword", function(d) settext(d, "R3", 'The deepest bore reached `r depth_max`{#dmax .num} m.'), R_(ID("dprev")))
ed("E57", "change the EXPRESSION of a construct that has an #id", function(d) subt(d, "R3", "`r depth_max`{#dmax", "`r depth_max * 0.5`{#dmax"),
   character(), sem = "identity = #id, so a changed expression under an id is invisible to the gate")
ed("E58", "rename an #id (dmax -> dmaxx)", function(d) subt(d, "R3", "#dmax ", "#dmaxx "), E_(ID("dmax"), ID("dmaxx")))
ed("E59", "drop one of many occurrences of a repeated identity (n_sites in Li1)", function(d) settext(d, "Li1", 'The main limitation is the small number of sites gauged.'), R_(V("n_sites")))
ed("E60", "reword a paragraph wholesale, keep its constructs", function(d) settext(d, "Di1", 'Published work from `r n_published`{.num} studies is consistent with the findings at `r n_sites`{.num} sites here.'))
ed("E61", "delete one construct and add an unrelated one in the same paragraph", function(d) settext(d, "Di1", 'These results from `r n_sites`{.num} sites agree with the budget of `r n_budget`{.num}.'),
   E_(V("n_published"), V("n_budget")), sem = "rule 6.2.2 makes this an edit (a different check swapped in); a deleted check is shown only as a pairing")
ed("E62", "delete one construct and edit another in the same paragraph (M2)", function(d) settext(d, "M2", 'Water levels were summarised by their `r median(level)`{.num}, using `r n_loggers`{.num} loggers.'),
   c(E_(V("mean(level)"), V("median(level)")), R_(V("sd(level)"))))
ed("E63", "no change at all", function(d) d)
ed("E64", "front matter only", function(d) { d$front <- c("---", 'title: "Groundwater trends, revised"', "format: pdf", "---"); d })
ed("E65", "swap two adjacent paragraphs", function(d) { b <- getb(d, "R4"); d <- delb(d, "R4"); insb(d, "R5", b) })
ed("E66", "add a sentence without touching constructs", function(d) settext(d, "I4", paste(getb(D0, "I4")$text, 'These were widely spaced.')))
ed("E67", "COMBINED: edit + delete section + add id, non-adjacent", function(d) {
   d <- subt(d, "M1", ". > 10", ". > 5"); d <- subt(d, "Di2", "`r mean(depth)`{.num}", "`r mean(depth)`{#dm2 .num}"); delsec(d, "sec-app-a") },
   c(E_(V("claim(n_sites, . > 10)"), V("claim(n_sites, . > 5)")), E_(V("mean(depth)"), ID("dm2")), R_(ids_sec("sec-app-a"))))
ed("E68", "COMBINED: bound edit, delete one repeated n_sites paragraph elsewhere, move another paragraph across sections", function(d) {
   d <- subt(d, "M1", ". > 10", ". > 5"); d <- delb(d, "Z1"); moveb(d, "I3", "D2") },
   c(E_(V("claim(n_sites, . > 10)"), V("claim(n_sites, . > 5)")), R_(V("n_sites"))))
ed("E69", "ADVERSARIAL: replace 3 adjacent paragraphs (I2,I3,I4) by 3 new unrelated ones in the same place", function(d) {
   d <- settext(d, "I2", 'The sampling frame covered `r n_strata`{.num} strata.'); d <- settext(d, "I3", 'Costs were `r cost_total`{.num} dollars.')
   settext(d, "I4", 'Staff numbered `r n_staff`{.num} people.') },
   c(R_(V("mean(depth)"), G("sign", "delta_depth"), V("mean(rain)"), V("n_sites"), V("n_old_surveys"), V("old_mean")), A_(V("n_strata"), V("cost_total"), V("n_staff"))))
ed("E70", "ADVERSARIAL (templated prose): replace a generated results sentence by the same template with another topic and its own constructs", function(d)
   settext(d, "f1.1", 'We excluded `r drop_zeolite`{.num} [zeolite reading | # zeolite readings]{n="drop_zeolite"} from the zeolite series because of obvious faults.'),
   c(R_(V("drop_alluvial"), G("n", "drop_alluvial")), A_(V("drop_zeolite"), G("n", "drop_zeolite"))))
ed("E71", "two constructs in one paragraph both edited", function(d)
   settext(d, "I4", 'Earlier surveys used `r n_old_surveys_v2`{.num} stations and reported `r old_median`{.num} m.'),
   c(E_(V("n_old_surveys"), V("n_old_surveys_v2")), E_(V("old_mean"), V("old_median"))))
