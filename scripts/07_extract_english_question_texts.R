source("scripts/00_utils.R")
check_dependencies(c("fs", "dplyr", "stringr", "readr", "tibble"))

cfg <- get_config()
ensure_dirs(cfg)

dict_file <- file.path(cfg$docs_dir, "dictionary_inventory.csv")
cand_file <- file.path(cfg$docs_dir, "target_variable_candidates.csv")

dict_inv <- if (fs::file_exists(dict_file)) readr::read_csv(dict_file, show_col_types = FALSE) else tibble::tibble()
cands <- if (fs::file_exists(cand_file)) readr::read_csv(cand_file, show_col_types = FALSE) else tibble::tibble()

from_dict <- dict_inv |>
  dplyr::filter(!is.na(var_label), stringr::str_detect(var_label, stringr::regex("(how fair|inequality|acceptable|wealth distribution|distribution of income)", ignore_case = TRUE))) |>
  dplyr::transmute(
    year = suppressWarnings(as.integer(year)),
    var_name,
    question_text_english = var_label,
    source = paste0("dictionary_excel:", source_file),
    needs_manual_review = FALSE
  )

from_cands <- cands |>
  dplyr::filter(
    stringr::str_detect(matched_term, stringr::regex("(how fair|inequality|acceptable|wealth distribution|distribution of income)", ignore_case = TRUE))
  ) |>
  dplyr::transmute(
    year = suppressWarnings(as.integer(year)),
    var_name,
    question_text_english = var_label,
    source = paste0(source_type, ":", source_file),
    needs_manual_review = TRUE
  )

out <- dplyr::bind_rows(from_dict, from_cands) |>
  dplyr::distinct() |>
  dplyr::arrange(year, var_name)

readr::write_csv(out, file.path(cfg$docs_dir, "english_question_texts.csv"))
message("Saved docs/english_question_texts.csv")
