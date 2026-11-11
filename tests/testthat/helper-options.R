# claim() quotes a check as written from R's kept source (rule 3.1.4);
# Rscript -e runs with keep.source = FALSE, which would hide that.
options(keep.source = TRUE)

# R CMD check sets R_TESTS to a startup file with a relative path; a child R
# (rmarkdown, Quarto) started in another directory then skips its .Rprofile.
Sys.setenv(R_TESTS = "")

# devtools::check() runs R CMD check through callr, which points
# R_PROFILE_USER at a file of its own; a child R then ignores the .Rprofile
# of its working directory, which some fixtures rely on.
Sys.unsetenv("R_PROFILE_USER")
