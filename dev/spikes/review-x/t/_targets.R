library(targets)
list(
  tar_target(msg_only, { message("boundary (singular) fit: see help('isSingular')"); 1 }),
  tar_target(warn_two, { warning("first warning 5 rows"); warning("second warning"); 2 }),
  tar_target(down, msg_only + warn_two)
)
