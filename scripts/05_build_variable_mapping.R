source("scripts/00_utils.R")
check_dependencies(c("fs", "dplyr", "stringr", "readr", "tibble", "purrr", "tidyr"))

cfg <- get_config()
ensure_dirs(cfg)

cands <- if (fs::file_exists(file.path(cfg$docs_dir, "target_variable_candidates.csv"))) readr::read_csv(file.path(cfg$docs_dir, "target_variable_candidates.csv"), show_col_types = FALSE) else tibble::tibble()

if (nrow(cands) == 0) {
  mapping_final <- tibble::tibble(year = 2000:2024) |>
    dplyr::mutate(
      source_file = NA_character_,
      standardized_name = NA_character_,
      original_var_name = NA_character_,
      original_var_label = NA_character_,
      matched_from_dictionary = FALSE,
      response_scale_note = "No confident mapping found automatically.",
      needs_manual_review = TRUE
    )
  readr::write_csv(mapping_final, file.path(cfg$docs_dir, "variable_mapping.csv"))
  quit(save = "no")
}

mapping_ranked <- cands |>
  dplyr::mutate(
    standardized_name = target_concept,
    matched_from_dictionary = source_type == "dictionary_excel",
    score = dplyr::case_when(
      match_method == "exact_code_from_user_list" & source_type == "data_file" ~ 1L,
      match_method == "exact_code_from_user_list" & source_type == "dictionary_excel" ~ 2L,
      match_method == "label_text_match" & source_type == "data_file" ~ 3L,
      TRUE ~ 4L
    ),
    response_scale_note = dplyr::case_when(
      standardized_name == "fair_income_distribution" ~ "Interpretar direção da escala via labels (justa/injusta).",
      standardized_name == "inequality_acceptable" ~ "Confirmar coding de aceitável/inaceitável em cada onda.",
      standardized_name == "justice_wealth_distribution" ~ "Pergunta tipo garantia; confirmar comparabilidade temporal.",
      TRUE ~ "Review needed"
    )
  ) |>
  dplyr::group_by(year, standardized_name) |>
  dplyr::arrange(score, .by_group = TRUE) |>
  dplyr::slice(1) |>
  dplyr::ungroup() |>
  dplyr::transmute(
    year = suppressWarnings(as.integer(year)),
    source_file,
    standardized_name,
    original_var_name = var_name,
    original_var_label = var_label,
    matched_from_dictionary,
    response_scale_note,
    needs_manual_review = needs_manual_review | match_method != "exact_code_from_user_list"
  )

# Add missing year x concept placeholders
all_grid <- tidyr::expand_grid(
  year = 2000:2024,
  standardized_name = c("fair_income_distribution", "inequality_acceptable", "justice_wealth_distribution")
)

mapping_final <- all_grid |>
  dplyr::left_join(mapping_ranked, by = c("year", "standardized_name")) |>
  dplyr::mutate(
    needs_manual_review = dplyr::coalesce(needs_manual_review, TRUE),
    response_scale_note = dplyr::coalesce(response_scale_note, "No candidate selected for this year/concept.")
  ) |>
  dplyr::arrange(year, standardized_name)

readr::write_csv(mapping_final, file.path(cfg$docs_dir, "variable_mapping.csv"))
message("Saved docs/variable_mapping.csv")
