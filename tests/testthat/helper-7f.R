# Helpers for stage 7f (dev/design-7.md, 2 F: forward references for named values):
# test-filter-forward.R and test-forward-knit.R. Nothing here edits another helper. Made-up content only.

# the messages of section 7, % filled
f7_msg <- list(
  E40 = function(name, n) sprintf(paste0("`%s` is used above its first publication, and the document publishes %d ",
                                         "different values for it below; a use above every publication needs a name ",
                                         "that takes one value (rule 1.12.7)."), name, n),
  E41 = "Move the sentence below the value it means, or publish that value under a name of its own.",
  E42 = function(name) sprintf("no value is published under the name `%s` in this document (rule 1.12.7).", name),
  E43 = function(name) sprintf(paste0("If `%s` is computed further down, write it as a named value, `%s`{.num}, ",
                                      "which takes its value from below (rule 1.12.7)."), name, name)
)

# the output paragraphs of a plain-text run, trimmed
f7_paras <- function(res) {
  if (!nzchar(trimws(res$output))) return(character())
  trimws(strsplit(trimws(res$output), "\n\n", fixed = TRUE)[[1]])
}

# a values-file block (four backticks, class weft-values, file attribute, empty body)
f7_file_block <- function(path) c(sprintf("````{.weft-values file=\"%s\"}", path), "````")

F7_DRAFT <- c(WEFT_DRAFT = "1")
