## _gate/edits.R -- the 72 scripted edits of dev/spikes/spike-gate/edits.R, with new hand answers.
## Sourced into the environment that already holds the generator (manuscript.R). Synthetic text only.
##
## ed(id, desc, f, width, hash_safe, sem): f(doc) -> doc, applied to the base manuscript D0; the before text is
## render_doc(D0, 72), the after text render_doc(f(D0), width, hash_safe).
##
## The expected answers are in the table EXPECT at the foot, written by hand (never computed with the package):
## per kind, the constructs the edit removes and adds ("vs" = values and spans, "claim" = claim() calls; a
## `r claim(x, ...)`{.num} is one value and one claim; an edited construct is one removed and one added; a
## construct moved is neither), and N under the ruling of dev/review-4.md (design question 1):
##   N = max(0, claims removed - claims added) + max(0, vs removed - vs added).
## Under this rule no answer of the 72 differs from the spike's net one: every edit that touches a claim
## edits it (one removed, one added), so claims never net against values. X01 is an extra, not in the
## spike, where they do.
## E16b has no table row: its answer is the scanner's count (see test-gate-edits.R).
D0 <- base_doc()
nm <- function(...) unname(c(...))

EDITS <- list()
ed <- function(id, desc, f, width = 72, sem = NA_character_, hash_safe = TRUE)
  EDITS[[id]] <<- list(id = id, desc = desc, f = f, width = width, sem = sem, hash_safe = hash_safe)

ed("E01", "loosen one check's bound (. > 10 -> . > 5)", function(d) subt(d, "M1", ". > 10", ". > 5"))
ed("E02", "mean(depth) -> median(depth)", function(d) subt(d, "I2", "mean(depth)", "median(depth)"))
ed("E03", "computed value -> literal construct `r 812`{.num}", function(d) subt(d, "I3", "`r mean(rain)`", "`r 812`"))
ed("E04", "computed value -> plain-prose number (construct gone)", function(d) subt(d, "I3", "`r mean(rain)`{.num}", "812"))
ed("E05", "delete a construct, reword the sentence around it", function(d) settext(d, "I1", 'We monitored `r n_sites`{.num} [a site | # sites]{n="n_sites"} in the years to `r end_year`{.num}, and the programme [has | have]{n="n_programmes"} continued since.'))
ed("E06", "delete a whole paragraph (2 constructs)", function(d) delb(d, "I4"))
ed("E07", "delete a whole section (sec-limits)", function(d) delsec(d, "sec-limits"))
ed("E08", "insert a paragraph above the first paragraph of a section",
   function(d) insb(d, "sec-intro", P("N1", 'This study asks whether `r n_new_q`{.num} questions can be answered.')))
ed("E09", "insert a paragraph between two edited ones (M1 bound, M2 mean->median)", function(d) {
   d <- subt(d, "M1", ". > 10", ". > 5"); d <- subt(d, "M2", "mean(level)", "median(level)")
   insb(d, "M1", P("N2", 'Loggers were checked by `r n_checkers`{.num} staff.')) })
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
ed("E16b", "reflow (55) with plain strwrap: wraps can land '# ' / '> ' at a line start and break right after `r", function(d) d, width = 55, hash_safe = FALSE,
   sem = "a line starting '# ' is a heading to Pandoc, '> ' a block quote, and knitr needs '`r ' + space: such a reflow really changes the render")
ed("E17", "change only arm text", function(d) subt(d, "I1", "[a site | # sites]", "[one site | # sites]"))
ed("E18", "reorder attributes, add spaces in braces", function(d) {
   d <- subt(d, "R3", "{#dmax .num}", "{.num #dmax}")
   subt(d, "R5", "`{.num}", "`{ .num }") },
   sem = "the spike also single-quoted n='n_sites'; a single-quoted value is a construct error (rule 1.2.3), so it is left out")
ed("E19", "add an #id to an existing construct", function(d) subt(d, "I2", "`r mean(depth)`{.num}", "`r mean(depth)`{#dmean .num}"))
ed("E20", "remove an #id from a construct", function(d) subt(d, "R3", "{#dmax .num}", "{.num}"))
ed("E21", "two adjacent paragraphs both edited (I2, I3)", function(d) { d <- subt(d, "I2", "mean(depth)", "median(depth)"); subt(d, "I3", "mean(rain)", "median(rain)") })
ed("E22", "edit in a paragraph that also gets a sentence added", function(d) {
   d <- subt(d, "I3", "mean(rain)", "median(rain)"); settext(d, "I3", paste(getb(d, "I3")$text, 'We also logged `r n_gauges`{.num} gauges.')) })
ed("E23", "swap two constructs between non-adjacent paragraphs (I1 start_year <-> I4 old_mean)", function(d) {
   d <- subt(d, "I1", "`r start_year`", "`r old_mean`"); subt(d, "I4", "`r old_mean`", "`r start_year`") })
ed("E24", "same identity removed from one paragraph, added in another (same section)", function(d) {
   d <- settext(d, "I1", 'We monitored `r n_sites`{.num} [a site | # sites]{n="n_sites"} to `r end_year`{.num}, and the programme [has | have]{n="n_programmes"} continued since.')
   settext(d, "I4", 'Earlier surveys since `r start_year`{.num} used `r n_old_surveys`{.num} stations and reported `r old_mean`{.num} m.') }, sem = "moved by count rule; semantically start_year was dropped from I1 (and re-added in I4)")
ed("E25", "COMBINED: bound loosened + delete paragraph + insert above + move section + reflow", function(d) {
   d <- subt(d, "M1", ". > 10", ". > 5"); d <- delb(d, "I4"); d <- insb(d, "sec-intro", P("N1", 'This study asks whether `r n_new_q`{.num} questions can be answered.'))
   movesec(d, "sec-app-b", "sec-concl") }, width = 66)
ed("E26", "COMBINED: split M2 + loosen M1 (adjacent) + rename sec-data anchor", function(d) {
   d <- subt(d, "M1", ". > 10", ". > 5")
   d <- settext(d, "M2", 'Water levels were summarised by their `r mean(level)`{.num} and `r sd(level)`{.num}.'); d <- insb(d, "M2", P("M2b", 'We used `r n_loggers`{.num} loggers.'))
   rename_anchor(d, "sec-data", "sec-datasets") })
ed("E27", "COMBINED: add id (I2) + adjacent edits R1,R2 + delete sec-app-c + move M3 elsewhere", function(d) {
   d <- subt(d, "I2", "`r mean(depth)`{.num}", "`r mean(depth)`{#dmean .num}")
   d <- subt(d, "R1", "pct_pass", "pct_ok"); d <- subt(d, "R2", "`r n_events`{.num}", "`r n_valid_events`{.num}")
   d <- delsec(d, "sec-app-c"); moveb(d, "M3", "D1") })
ed("E28", "change a span's key value (n_sites -> n_valid_sites)", function(d) subt(d, "I1", 'n="n_sites"', 'n="n_valid_sites"'))
ed("E29", "change a span's `if` condition", function(d) subt(d, "R4", 'if="drift_found"', 'if="drift_found & n_drift > 2"'))
ed("E30", "delete a governed span (leave plain 'has')", function(d) subt(d, "I1", '[has | have]{n="n_programmes"}', "has"))
ed("E31", "delete a construct from a heading", function(d) settitle(d, "sec-methods", "Methods"))
ed("E32", "edit a construct in a heading", function(d) settitle(d, "sec-methods", 'Methods for `r n_valid`{.num} sites'))
ed("E33", "edit a construct in a list item", function(d) subt(d, "L1", "`r n_loggers`", "`r n_loggers_active`"))
ed("E34", "delete a list item", function(d) setlines(d, "L1", getb(D0, "L1")$lines[1:2]))
ed("E35", "edit a construct in a table cell", function(d) subt(d, "TB1", "`r depth_a`", "`r depth_a_adj`"))
ed("E36", "delete a table row", function(d) setlines(d, "TB1", getb(D0, "TB1")$lines[1:3]))
ed("E37", "edit a footnote definition", function(d) subt(d, "FNDEF", "tide_range", "tide_range_m"))
ed("E38", "delete a footnote definition", function(d) delb(d, "FNDEF"))
ed("E39", "edit a chunk-option caption construct", function(d) subt(d, "CH1", "n_regions", "n_zones"))
ed("E40", "remove a construct from a chunk-option caption", function(d) subt(d, "CH1", " in `r n_regions`{.num} regions", ""))
ed("E41", "delete a whole chunk with a caption", function(d) delb(d, "CH2"))
ed("E42", "edit a construct in a block quote", function(d) subt(d, "BQ1", "n_quoted", "n_quoted_total"))
ed("E43", "edit a construct inside a div", function(d) subt(d, "DIV1", "n_flagged", "n_flagged_total"))
ed("E44", "change a formatter class (.pct -> .num)", function(d) subt(d, "R1", "`{.pct}", "`{.num}"))
ed("E45", "add a formatter class (.pct -> .pct .dec1)", function(d) subt(d, "A2", "{.pct}", "{.pct .dec1}"))
ed("E46", "edit a construct in an inline footnote", function(d) subt(d, "FN1", "mean(drift)", "median(drift)"))
ed("E47", "ADVERSARIAL: delete a paragraph, insert an unrelated one in its place", function(d) settext(d, "A1", 'Metadata were stored by `r n_archive`{.num} archives.'))
ed("E48", "edit a paragraph whose neighbour is deleted (R1 edited, R2 deleted)", function(d) { d <- subt(d, "R1", "pct_pass", "pct_ok"); delb(d, "R2") })
ed("E49", "insert a paragraph directly above an edited one (D1)", function(d) {
   d <- subt(d, "D1", "n_sources", "n_sources_all"); insb(d, "sec-data", P("N3", 'We begin with `r n_prelim`{.num} preliminary checks.')) })
ed("E50", "edit a heading's words, anchor and constructs unchanged", function(d) settitle(d, "sec-data", "Data sources"))
ed("E51", "rename a section's anchor AND loosen a bound in it", function(d) rename_anchor(subt(d, "M1", ". > 10", ". > 5"), "sec-methods", "sec-methods2"))
ed("E52", "move a paragraph to another section AND edit it", function(d) moveb(subt(d, "M3", "n_cal", "n_cal_pts"), "M3", "D1"))
ed("E53", "delete one of two identical adjacent paragraphs", function(d) delb(d, "DupB"))
ed("E54", "edit the second of two identical adjacent paragraphs", function(d) subt(d, "DupB", "`r digits`", "`r digits_out`"))
ed("E55", "edit the first of two identical adjacent paragraphs", function(d) subt(d, "DupA", "`r digits`", "`r digits_out`"))
ed("E56", "remove one #id'd construct and reword", function(d) settext(d, "R3", 'The deepest bore reached `r depth_max`{#dmax .num} m.'))
ed("E57", "change the EXPRESSION of a construct that has an #id", function(d) subt(d, "R3", "`r depth_max`{#dmax", "`r depth_max * 0.5`{#dmax"), sem = "identity = #id, so a changed expression under an id is invisible to the gate")
ed("E58", "rename an #id (dmax -> dmaxx)", function(d) subt(d, "R3", "#dmax ", "#dmaxx "))
ed("E59", "drop one of many occurrences of a repeated identity (n_sites in Li1)", function(d) settext(d, "Li1", 'The main limitation is the small number of sites gauged.'))
ed("E60", "reword a paragraph wholesale, keep its constructs", function(d) settext(d, "Di1", 'Published work from `r n_published`{.num} studies is consistent with the findings at `r n_sites`{.num} sites here.'))
ed("E61", "delete one construct and add an unrelated one in the same paragraph", function(d) settext(d, "Di1", 'These results from `r n_sites`{.num} sites agree with the budget of `r n_budget`{.num}.'), sem = "rule 6.2.2 makes this an edit (a different check swapped in); a deleted check is shown only as a pairing")
ed("E62", "delete one construct and edit another in the same paragraph (M2)", function(d) settext(d, "M2", 'Water levels were summarised by their `r median(level)`{.num}, using `r n_loggers`{.num} loggers.'))
ed("E63", "no change at all", function(d) d)
ed("E64", "front matter only", function(d) { d$front <- c("---", 'title: "Groundwater trends, revised"', "format: pdf", "---"); d })
ed("E65", "swap two adjacent paragraphs", function(d) { b <- getb(d, "R4"); d <- delb(d, "R4"); insb(d, "R5", b) })
ed("E66", "add a sentence without touching constructs", function(d) settext(d, "I4", paste(getb(D0, "I4")$text, 'These were widely spaced.')))
ed("E67", "COMBINED: edit + delete section + add id, non-adjacent", function(d) {
   d <- subt(d, "M1", ". > 10", ". > 5"); d <- subt(d, "Di2", "`r mean(depth)`{.num}", "`r mean(depth)`{#dm2 .num}"); delsec(d, "sec-app-a") })
ed("E68", "COMBINED: bound edit, delete one repeated n_sites paragraph elsewhere, move another paragraph across sections", function(d) {
   d <- subt(d, "M1", ". > 10", ". > 5"); d <- delb(d, "Z1"); moveb(d, "I3", "D2") })
ed("E69", "ADVERSARIAL: replace 3 adjacent paragraphs (I2,I3,I4) by 3 new unrelated ones in the same place", function(d) {
   d <- settext(d, "I2", 'The sampling frame covered `r n_strata`{.num} strata.'); d <- settext(d, "I3", 'Costs were `r cost_total`{.num} dollars.')
   settext(d, "I4", 'Staff numbered `r n_staff`{.num} people.') })
ed("E70", "ADVERSARIAL (templated prose): replace a generated results sentence by the same template with another topic and its own constructs", function(d)
   settext(d, "f1.1", 'We excluded `r drop_zeolite`{.num} [zeolite reading | # zeolite readings]{n="drop_zeolite"} from the zeolite series because of obvious faults.'))
ed("E71", "two constructs in one paragraph both edited", function(d)
   settext(d, "I4", 'Earlier surveys used `r n_old_surveys_v2`{.num} stations and reported `r old_median`{.num} m.'))
## The findings an edit ADDS that are the edit's own doing (rule ids); every other edit adds none.
EDITS$E03$finding <- "literal-value"   # `r 812` is made only of constants (5.6.1)
EDITS$E04$finding <- "numeral"         # 812 typed in prose (5.2.1)

ed("X01", "EXTRA: delete a claim paragraph, add a paragraph of two values elsewhere (claims counted apart)",
   function(d) insb(delb(d, "R5"), "sec-intro", P("N4", 'Of `r n_new_q`{.num} questions, `r n_answered`{.num} were answered.')))


## id, removed (vs, claim), added (vs, claim), N
EXPECT_ROWS <- list(
  list("E01", 1, 1, 1, 1, 0), list("E02", 1, 0, 1, 0, 0), list("E03", 1, 0, 1, 0, 0),
  list("E04", 1, 0, 0, 0, 1), list("E05", 1, 0, 0, 0, 1), list("E06", 2, 0, 0, 0, 2),
  list("E07", 12, 0, 0, 0, 12),       # Li1 1, Li2 2, four filler paragraphs 2+2+3+2
  list("E08", 0, 0, 1, 0, 0), list("E09", 2, 1, 3, 1, 0), list("E10", 0, 0, 0, 0, 0),
  list("E11", 0, 0, 0, 0, 0), list("E12", 0, 0, 0, 0, 0), list("E13", 0, 0, 0, 0, 0),
  list("E14", 0, 0, 0, 0, 0), list("E15", 0, 0, 0, 0, 0), list("E16", 0, 0, 0, 0, 0),
  list("E17", 0, 0, 0, 0, 0), list("E18", 0, 0, 0, 0, 0), list("E19", 1, 0, 1, 0, 0),
  list("E20", 1, 0, 1, 0, 0), list("E21", 2, 0, 2, 0, 0), list("E22", 1, 0, 2, 0, 0),
  list("E23", 2, 0, 2, 0, 0), list("E24", 1, 0, 1, 0, 0), list("E25", 3, 1, 2, 1, 1),
  list("E26", 1, 1, 1, 1, 0),
  list("E27", 15, 0, 3, 0, 12),       # sec-app-c holds 12; three edited constructs
  list("E28", 1, 0, 1, 0, 0), list("E29", 1, 0, 1, 0, 0), list("E30", 1, 0, 0, 0, 1),
  list("E31", 1, 0, 0, 0, 1), list("E32", 1, 0, 1, 0, 0), list("E33", 1, 0, 1, 0, 0),
  list("E34", 1, 0, 0, 0, 1), list("E35", 1, 0, 1, 0, 0), list("E36", 2, 0, 0, 0, 2),
  list("E37", 1, 0, 1, 0, 0), list("E38", 1, 0, 0, 0, 1), list("E39", 1, 0, 1, 0, 0),
  list("E40", 1, 0, 0, 0, 1), list("E41", 1, 0, 0, 0, 1), list("E42", 1, 0, 1, 0, 0),
  list("E43", 1, 0, 1, 0, 0), list("E44", 1, 0, 1, 0, 0), list("E45", 1, 0, 1, 0, 0),
  list("E46", 1, 0, 1, 0, 0), list("E47", 1, 0, 1, 0, 0), list("E48", 4, 0, 1, 0, 3),
  list("E49", 1, 0, 2, 0, 0), list("E50", 0, 0, 0, 0, 0), list("E51", 1, 1, 1, 1, 0),
  list("E52", 1, 0, 1, 0, 0), list("E53", 1, 0, 0, 0, 1), list("E54", 1, 0, 1, 0, 0),
  list("E55", 1, 0, 1, 0, 0), list("E56", 1, 0, 0, 0, 1),
  list("E57", 0, 0, 0, 0, 0),         # an expression changed under an #id: the count cannot see it
  list("E58", 1, 0, 1, 0, 0), list("E59", 1, 0, 0, 0, 1), list("E60", 0, 0, 0, 0, 0),
  list("E61", 1, 0, 1, 0, 0), list("E62", 2, 0, 1, 0, 1), list("E63", 0, 0, 0, 0, 0),
  list("E64", 0, 0, 0, 0, 0), list("E65", 0, 0, 0, 0, 0), list("E66", 0, 0, 0, 0, 0),
  list("E67", 13, 1, 2, 1, 11),       # sec-app-a holds 11
  list("E68", 2, 1, 1, 1, 1), list("E69", 6, 0, 3, 0, 3), list("E70", 2, 0, 2, 0, 0),
  list("E71", 2, 0, 2, 0, 0),
  # not in the spike. Net answer 0 (2 removed, 2 added); apart, 1 claim removed and 0 added: N = 1.
  list("X01", 1, 1, 2, 0, 1))
EXPECT <- lapply(EXPECT_ROWS, function(r) list(
  id = r[[1]], rm = c(vs = r[[2]], claim = r[[3]]), add = c(vs = r[[4]], claim = r[[5]]), n = as.integer(r[[6]])))
names(EXPECT) <- vapply(EXPECT_ROWS, `[[`, "", 1L)
