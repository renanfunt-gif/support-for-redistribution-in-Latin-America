source("scripts/00_utils.R")
check_dependencies(c("fs", "dplyr", "purrr", "stringr", "readr", "tibble", "tidyr"))

cfg <- get_config()
ensure_dirs(cfg)

var_inv_file <- file.path(cfg$docs_dir, "variable_inventory.csv")
dict_inv_file <- file.path(cfg$docs_dir, "dictionary_inventory.csv")

var_inv <- if (fs::file_exists(var_inv_file)) readr::read_csv(var_inv_file, show_col_types = FALSE) else tibble::tibble()
dict_inv <- if (fs::file_exists(dict_inv_file)) readr::read_csv(dict_inv_file, show_col_types = FALSE) else tibble::tibble()

codes <- known_target_codes()

terms <- c(
  "How fair do you think is the distribution of income",
  "distribution of income",
  "Would you say that the level of inequality in your country is acceptable",
  "inequality acceptable",
  "justice in the distribution of wealth",
  "wealth distribution",
  "justiça da distribuição de renda",
  "aceitabilidade da desigualdade",
  "justiça na distribuição da riqueza"
)

concept_from_code <- function(vn) {
  v <- normalize_var(vn)
  dplyr::case_when(
    v %in% normalize_var(codes$fair_income_distribution) ~ "fair_income_distribution",
    v %in% normalize_var(codes$inequality_acceptable) ~ "inequality_acceptable",
    v %in% normalize_var(codes$justice_wealth_distribution) ~ "justice_wealth_distribution",
    TRUE ~ NA_character_
  )
}

find_code_hits <- function(df, source_type, file_col = "source_file") {
  if (nrow(df) == 0) return(tibble::tibble())
  df |>
    dplyr::mutate(
      var_name_norm = normalize_var(var_name),
      target_concept = concept_from_code(var_name)
    ) |>
    dplyr::filter(!is.na(target_concept)) |>
    dplyr::transmute(
      year = suppressWarnings(as.integer(year)),
      source_file = .data[[file_col]],
      source_type,
      var_name,
      var_label,
      matched_term = var_name,
      match_method = "exact_code_from_user_list",
      confidence = "high",
      needs_manual_review = FALSE,
      target_concept
    )
}

find_text_hits <- function(df, source_type, file_col = "source_file") {
  if (nrow(df) == 0) return(tibble::tibble())
  purrr::map_dfr(terms, function(t) {
    rx <- stringr::regex(stringr::str_to_lower(t), ignore_case = TRUE)
    df |>
      dplyr::filter(stringr::str_detect(stringr::str_to_lower(var_label %||% ""), rx)) |>
      dplyr::mutate(
        target_concept = dplyr::case_when(
          stringr::str_detect(stringr::str_to_lower(t), "income|renda") ~ "fair_income_distribution",
          stringr::str_detect(stringr::str_to_lower(t), "inequality|desigualdade") ~ "inequality_acceptable",
          stringr::str_detect(stringr::str_to_lower(t), "wealth|riqueza") ~ "justice_wealth_distribution",
          TRUE ~ NA_character_
        )
      ) |>
      dplyr::transmute(
        year = suppressWarnings(as.integer(year)),
        source_file = .data[[file_col]],
        source_type,
        var_name,
        var_label,
        matched_term = t,
        match_method = "label_text_match",
        confidence = "medium",
        needs_manual_review = TRUE,
        target_concept
      )
  })
}

c_data <- dplyr::bind_rows(
  find_code_hits(var_inv, "data_file", "source_file"),
  find_text_hits(var_inv, "data_file", "source_file")
)

c_dict <- dplyr::bind_rows(
  find_code_hits(dict_inv, "dictionary_excel", "source_file"),
  find_text_hits(dict_inv, "dictionary_excel", "source_file")
)

candidates <- dplyr::bind_rows(c_data, c_dict) |>
  dplyr::filter(!is.na(target_concept)) |>
  dplyr::distinct() |>
  dplyr::arrange(year, target_concept, source_type, source_file, var_name)

readr::write_csv(candidates, file.path(cfg$docs_dir, "target_variable_candidates.csv"))
message("Saved docs/target_variable_candidates.csv")
