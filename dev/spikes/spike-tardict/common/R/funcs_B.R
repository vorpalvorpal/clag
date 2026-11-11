scale_sal <- function(x) x / dict$salinity_res
era_label <- function(y) ifelse(y < dict$era_split, "early", "late")
