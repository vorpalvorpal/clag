library(targets)
source("tar_dict.R"); source("R/funcs.R")
tar_option_set(packages = "yaml")
val <- function(x) if (is.list(x) && "value" %in% names(x)) x$value else x
c(tar_dict("dict.yml", whole_entry = Sys.getenv("WHOLE") == "1", whole_target = Sys.getenv("WT") == "1"), list(
  tar_target(t_era,  val(dict_era_split) + 1),
  tar_target(t_sal,  val(dict_salinity_res) * 10),
  tar_target(t_both, val(dict_era_split) + val(dict_salinity_res)),
  tar_target(t_none, 1 + 1),
  tar_target(t_fn_sal, scale_sal(5, val(dict_salinity_res))),   # key passed as argument
  tar_target(t_fn_era, era_label(2010, val(dict_era_split)))
))
