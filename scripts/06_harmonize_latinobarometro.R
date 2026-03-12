source("scripts/00_utils.R")
check_dependencies(c("fs", "dplyr", "purrr", "stringr", "readr", "tibble", "haven", "labelled"))

cfg <- get_config()
ensure_dirs(cfg)

map_file <- file.path(cfg$docs_dir, "variable_mapping.csv")
if (!fs::file_exists(map_file)) stop("Missing docs/variable_mapping.csv")

mapping <- readr::read_csv(map_file, show_col_types = FALSE) |>
  dplyr::filter(!is.na(source_file), !is.na(original_var_name), !is.na(standardized_name))

if (nrow(mapping) == 0) {
  out <- tibble::tibble(
    year = integer(), country = character(), source_file = character(), standardized_name = character(),
    original_var_name = character(), original_var_label = character(), original_value = character(),
    original_value_label = character(), mapping_note = character(), needs_manual_review = logical()
  )
  readr::write_csv(out, file.path(cfg$data_intermediate_dir, "latinobarometro_harmonized.csv"))
  saveRDS(out, file.path(cfg$data_intermediate_dir, "latinobarometro_harmonized.rds"))
  quit(save = "no")
}

all_local_dta <- fs::dir_ls(cfg$raw_data_dir, recurse = TRUE, type = "file", regexp = "\\.dta$")

harmonize_row <- function(year, source_file, standardized_name, original_var_name, original_var_label, matched_from_dictionary, response_scale_note, needs_manual_review) {
  path <- all_local_dta[fs::path_file(all_local_dta) == source_file]

  if (length(path) == 0) {
    return(tibble::tibble(
      year = as.integer(year), country = NA_character_, source_file = source_file,
      standardized_name = standardized_name, original_var_name = original_var_name,
      original_var_label = original_var_label, original_value = NA_character_,
      original_value_label = NA_character_, mapping_note = "source_file_not_found_locally", needs_manual_review = TRUE
    ))
  }

  dat <- safe_read_dta(path[1])
  if (inherits(dat, "lb_read_error") || !(original_var_name %in% names(dat))) {
    return(tibble::tibble(
      year = as.integer(year), country = NA_character_, source_file = source_file,
      standardized_name = standardized_name, original_var_name = original_var_name,
      original_var_label = original_var_label, original_value = NA_character_,
      original_value_label = NA_character_, mapping_note = "file_read_error_or_var_missing", needs_manual_review = TRUE
    ))
  }

  country_col <- find_col_by_pattern(dat, c("^country$", "pais", "id_country", "n_pais", "pa_s"))
  country <- if (!is.na(country_col)) as.character(dat[[country_col]]) else NA_character_

  vv <- dat[[original_var_name]]
  value_labels <- labelled::val_labels(vv)

  vv_lbl <- if (length(value_labels) == 0) {
    rep(NA_character_, length(vv))
  } else {
    vapply(vv, function(x) {
      nm <- names(value_labels)[which(value_labels == x)][1]
      ifelse(length(nm) == 0 || is.na(nm), NA_character_, nm)
    }, character(1))
  }

  tibble::tibble(
    year = as.integer(year),
    country = country,
    source_file = source_file,
    standardized_name = standardized_name,
    original_var_name = original_var_name,
    original_var_label = original_var_label,
    original_value = as.character(vv),
    original_value_label = vv_lbl,
    mapping_note = response_scale_note,
    needs_manual_review = needs_manual_review
  )
}

harmonized <- purrr::pmap_dfr(mapping, harmonize_row)

readr::write_csv(harmonized, file.path(cfg$data_intermediate_dir, "latinobarometro_harmonized.csv"))
saveRDS(harmonized, file.path(cfg$data_intermediate_dir, "latinobarometro_harmonized.rds"))

message("Saved harmonized dataset to data_intermediate/")
