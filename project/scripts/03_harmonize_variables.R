#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(fs)
  library(haven)
  library(labelled)
  library(purrr)
  library(readr)
  library(stringr)
  library(tidyr)
})

root_dir <- fs::path_abs("project")
wave_dir <- fs::path(root_dir, "data_raw", "waves")
docs_dir <- fs::path(root_dir, "docs")
intermediate_dir <- fs::path(root_dir, "data_intermediate")

fs::dir_create(intermediate_dir, recurse = TRUE)

crosswalk <- readr::read_csv(fs::path(docs_dir, "variable_crosswalk.csv"), show_col_types = FALSE)

wave_files <- fs::dir_ls(wave_dir, recurse = TRUE, type = "file", regexp = "\\.(sav|dta|csv)$")

read_wave <- function(path) {
  ext <- fs::path_ext(path)
  switch(ext,
         sav = haven::read_sav(path),
         dta = haven::read_dta(path),
         csv = readr::read_csv(path, show_col_types = FALSE),
         stop("Formato não suportado: ", ext)
  )
}

pick_first <- function(df, candidates) {
  cands <- intersect(names(df), candidates)
  if (length(cands) == 0) return(NA_character_)
  cands[1]
}

parse_year <- function(path) {
  y <- stringr::str_extract(fs::path_file(path), "(200[0-9]|201[0-9]|202[0-4])")
  as.integer(y)
}

recode_special_missing <- function(x) {
  if (inherits(x, "haven_labelled")) {
    x <- labelled::zap_missing(x)
  }
  x_num <- suppressWarnings(as.numeric(x))
  if (!all(is.na(x_num))) {
    x_num[x_num %in% c(8, 9, 88, 89, 98, 99, 888, 999)] <- NA_real_
    return(x_num)
  }
  x
}

label_to_ordinal <- function(x) {
  vals <- as.character(x)
  lv <- tolower(vals)
  case_when(
    str_detect(lv, "very fair|muy justa|muito justa") ~ 1,
    str_detect(lv, "fair|justa") ~ 2,
    str_detect(lv, "unfair|injusta") ~ 3,
    str_detect(lv, "very unfair|muy injusta|muito injusta") ~ 4,
    str_detect(lv, "acceptable|aceptable|aceitável") ~ 1,
    str_detect(lv, "not acceptable|inaceptable|inaceitável") ~ 4,
    TRUE ~ suppressWarnings(as.numeric(x))
  )
}

make_binary_critical <- function(label_chr, ordinal) {
  lv <- tolower(label_chr)
  ifelse(
    str_detect(lv, "unfair|injusta|not acceptable|inaceptable|inaceitável|too high|demasiad"), 1,
    ifelse(!is.na(ordinal), ifelse(ordinal >= 3, 1, 0), NA_real_)
  )
}

harmonized <- map_dfr(wave_files, function(f) {
  year <- parse_year(f)
  if (is.na(year)) return(tibble())

  cw <- crosswalk |> filter(year == !!year)
  if (nrow(cw) == 0) return(tibble())

  df <- tryCatch(read_wave(f), error = function(e) NULL)
  if (is.null(df)) return(tibble())

  nm <- names(df)
  country_var <- pick_first(df, c("country", "pais", "pa_s", "id_country", "n_pais", "pais_r"))
  id_var <- pick_first(df, c("id", "folio", "caseid", "idencuesta", "nroentrevista"))
  weight_var <- pick_first(df, c("wt", "weight", "pondera", "factor", "wgt", "peso", "fexp"))

  fair_var <- cw$var_income_fairness[[1]]
  ineq_var <- cw$var_inequality_acceptability[[1]]

  fair_exists <- !is.na(fair_var) && fair_var %in% nm
  ineq_exists <- !is.na(ineq_var) && ineq_var %in% nm

  out <- tibble(
    year = year,
    source_file = fs::path_file(f),
    country = if (!is.na(country_var)) as.character(df[[country_var]]) else NA_character_,
    obs_id = if (!is.na(id_var)) as.character(df[[id_var]]) else NA_character_,
    sample_weight = if (!is.na(weight_var)) suppressWarnings(as.numeric(df[[weight_var]])) else NA_real_,
    var_income_fairness_name = fair_var,
    var_ineq_accept_name = ineq_var,
    income_fairness_original = if (fair_exists) as.character(df[[fair_var]]) else NA_character_,
    ineq_accept_original = if (ineq_exists) as.character(df[[ineq_var]]) else NA_character_
  )

  out <- out |>
    mutate(
      income_fairness_num = if (fair_exists) recode_special_missing(df[[fair_var]]) else NA_real_,
      ineq_accept_num = if (ineq_exists) recode_special_missing(df[[ineq_var]]) else NA_real_,
      income_fairness_label = income_fairness_original,
      ineq_accept_label = ineq_accept_original,
      income_fairness_ordinal_std = label_to_ordinal(income_fairness_label),
      ineq_accept_ordinal_std = label_to_ordinal(ineq_accept_label),
      income_fairness_binary_critical = make_binary_critical(income_fairness_label, income_fairness_ordinal_std),
      ineq_accept_binary_critical = make_binary_critical(ineq_accept_label, ineq_accept_ordinal_std),
      weight_found = !all(is.na(sample_weight))
    )

  out
})

readr::write_csv(harmonized, fs::path(intermediate_dir, "latinobarometro_harmonized_microdata.csv"))

coverage <- harmonized |>
  group_by(year) |>
  summarise(
    n_obs = n(),
    countries = n_distinct(country, na.rm = TRUE),
    has_income_fairness = any(!is.na(income_fairness_original)),
    has_ineq_accept = any(!is.na(ineq_accept_original)),
    use_weight = any(weight_found),
    .groups = "drop"
  )

readr::write_csv(coverage, fs::path(docs_dir, "harmonization_coverage.csv"))
message("Harmonized microdata saved.")
