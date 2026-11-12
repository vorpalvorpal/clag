# For the whole test run, the user cache folder is a temporary one, so that no test writes to the
# user's real cache directory (the units tables are kept there). ASCII only.
withr::local_envvar(R_USER_CACHE_DIR = withr::local_tempdir(.local_envir = testthat::teardown_env()),
                    .local_envir = testthat::teardown_env())
