source("scripts/00_utils.R")
check_dependencies(c("fs", "dplyr", "readr", "tibble", "stringr", "tidyr"))

cfg <- get_config()
ensure_dirs(cfg)

harm_file <- file.path(cfg$data_intermediate_dir, "latinobarometro_harmonized.csv")
if (!fs::file_exists(harm_file)) stop("Missing harmonized data file")

dat <- readr::read_csv(harm_file, show_col_types = FALSE)

if (nrow(dat) == 0) {
  out <- tibble::tibble(
    year = integer(), country = character(), standardized_name = character(),
    n_total = integer(), n_valid = integer(), mean_original_code = numeric(),
    prop_non_missing = numeric()
  )
  readr::write_csv(out, file.path(cfg$data_intermediate_dir, "latinobarometro_country_year_series.csv"))
  quit(save = "no")
}

dat2 <- dat |>
  dplyr::mutate(
    original_value_num = suppressWarnings(as.numeric(original_value)),
    country = dplyr::coalesce(country, "UNKNOWN_COUNTRY")
  )

series <- dat2 |>
  dplyr::group_by(year, country, standardized_name) |>
  dplyr::summarise(
    n_total = dplyr::n(),
    n_valid = sum(!is.na(original_value_num)),
    mean_original_code = ifelse(n_valid > 0, mean(original_value_num, na.rm = TRUE), NA_real_),
    prop_non_missing = n_valid / n_total,
    .groups = "drop"
  ) |>
  dplyr::arrange(standardized_name, country, year)

readr::write_csv(series, file.path(cfg$data_intermediate_dir, "latinobarometro_country_year_series.csv"))
message("Saved data_intermediate/latinobarometro_country_year_series.csv")
