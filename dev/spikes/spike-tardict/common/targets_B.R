library(targets)
source("tar_dict.R"); source("R/funcs.R")
tar_option_set(packages = "yaml")
dict <- spike_dict_obj("dict.yml")      # plain global, definition-time; prose reads the same
c(tar_dict("dict.yml"), tar_dict_deps(list(
  tar_target(t_era,  dict$era_split + 1),
  tar_target(t_sal,  dict$salinity_res * 10),
  tar_target(t_both, dict$era_split + dict$salinity_res),
  tar_target(t_none, 1 + 1),
  tar_target(t_fn_sal, scale_sal(5)),   # key read inside function
  tar_target(t_fn_era, era_label(2010))
), "dict.yml", fn_mode = Sys.getenv("FNS", "exact")))
