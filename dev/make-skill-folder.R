# Regenerates the repository's skills/weft/ folder (the Agent Skills layout, which the Claude Code
# plugin in .claude-plugin/ also serves) from inst/agent/, and sets the version in both manifests to
# the version in DESCRIPTION. Run it at each release, after bumping the version, from the repository
# root:  Rscript dev/make-skill-folder.R   Then commit skills/ and .claude-plugin/.
# A test fails when the committed copies differ from what this writes.
pkgload::load_all(".", quiet = TRUE)
agent_repo_skill(".")
v <- as.character(read.dcf("DESCRIPTION", fields = "Version")[1L, 1L])
for (f in c(".claude-plugin/plugin.json", ".claude-plugin/marketplace.json")) {
  x <- readLines(f, warn = FALSE)
  x <- sub('("version": ")[^"]*(")', paste0("\\1", v, "\\2"), x)
  writeLines(x, f)
}
cat("skills/weft written; manifests at version", v, "\n")
