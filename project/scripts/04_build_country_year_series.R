#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(fs)
  library(purrr)
  library(readr)
  library(stringr)
  library(tidyr)
})

root_dir <- fs::path_abs("project")
intermediate_dir <- fs::path(root_dir, "data_intermediate")
final_dir <- fs::path(root_dir, "data_final")
docs_dir <- fs::path(root_dir, "docs")

fs::dir_create(final_dir, recurse = TRUE)

micro <- readr::read_csv(fs::path(intermediate_dir, "latinobarometro_harmonized_microdata.csv"), show_col_types = FALSE)

weighted_mean_safe <- function(x, w = NULL) {
  ok <- !is.na(x)
  if (is.null(w) || all(is.na(w))) return(mean(x[ok], na.rm = TRUE))
  w2 <- w[ok]
  x2 <- x[ok]
  if (length(x2) == 0 || sum(w2, na.rm = TRUE) <= 0) return(NA_real_)
  weighted.mean(x2, w2, na.rm = TRUE)
}

weighted_prop <- function(cond, w = NULL) {
  ok <- !is.na(cond)
  if (is.null(w) || all(is.na(w))) return(mean(cond[ok], na.rm = TRUE))
  c2 <- cond[ok]
  w2 <- w[ok]
  if (length(c2) == 0 || sum(w2, na.rm = TRUE) <= 0) return(NA_real_)
  sum((c2 == 1) * w2, na.rm = TRUE) / sum(w2, na.rm = TRUE)
}

summarise_question <- function(df, q_prefix, question_label) {
  ordinal_col <- paste0(q_prefix, "_ordinal_std")
  binary_col <- paste0(q_prefix, "_binary_critical")
  label_col <- paste0(q_prefix, "_label")

  df |>
    group_by(country, year) |>
    summarise(
      question = question_label,
      n_total = n(),
      n_valid = sum(!is.na(.data[[ordinal_col]])),
      weighted = any(!is.na(sample_weight)),
      mean_ordinal_std = weighted_mean_safe(.data[[ordinal_col]], sample_weight),
      prop_critical = weighted_prop(.data[[binary_col]], sample_weight),
      .groups = "drop"
    )
}

category_props <- function(df, q_prefix, question_label) {
  label_col <- paste0(q_prefix, "_label")

  df |>
    filter(!is.na(.data[[label_col]])) |>
    mutate(category = .data[[label_col]]) |>
    group_by(country, year, question = question_label, category) |>
    summarise(
      prop = weighted_prop(rep(1, n()), sample_weight),
      n = n(),
      .groups = "drop"
    )
}

summary_tbl <- bind_rows(
  summarise_question(micro, "income_fairness", "income_distribution_fairness"),
  summarise_question(micro, "ineq_accept", "inequality_acceptability")
)

cat_tbl <- bind_rows(
  category_props(micro, "income_fairness", "income_distribution_fairness"),
  category_props(micro, "ineq_accept", "inequality_acceptability")
)

readr::write_csv(summary_tbl, fs::path(final_dir, "latinobarometro_country_year_redistribution.csv"))
readr::write_csv(cat_tbl, fs::path(final_dir, "latinobarometro_country_year_category_props.csv"))

checks <- summary_tbl |>
  group_by(question) |>
  summarise(
    min_year = min(year, na.rm = TRUE),
    max_year = max(year, na.rm = TRUE),
    n_country_year = n(),
    .groups = "drop"
  )

readr::write_csv(checks, fs::path(docs_dir, "country_year_checks.csv"))
message("Country-year dataset created.")
