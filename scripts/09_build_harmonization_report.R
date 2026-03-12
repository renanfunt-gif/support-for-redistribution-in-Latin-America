source("scripts/00_utils.R")
check_dependencies(c("fs", "dplyr", "readr", "stringr", "tibble"))

cfg <- get_config()
ensure_dirs(cfg)

inv <- if (fs::file_exists(file.path(cfg$docs_dir, "local_file_inventory.csv"))) readr::read_csv(file.path(cfg$docs_dir, "local_file_inventory.csv"), show_col_types = FALSE) else tibble::tibble()
dict_inv <- if (fs::file_exists(file.path(cfg$docs_dir, "dictionary_inventory.csv"))) readr::read_csv(file.path(cfg$docs_dir, "dictionary_inventory.csv"), show_col_types = FALSE) else tibble::tibble()
cands <- if (fs::file_exists(file.path(cfg$docs_dir, "target_variable_candidates.csv"))) readr::read_csv(file.path(cfg$docs_dir, "target_variable_candidates.csv"), show_col_types = FALSE) else tibble::tibble()
map <- if (fs::file_exists(file.path(cfg$docs_dir, "variable_mapping.csv"))) readr::read_csv(file.path(cfg$docs_dir, "variable_mapping.csv"), show_col_types = FALSE) else tibble::tibble()

n_files <- nrow(inv)
readable_years <- inv |> dplyr::filter(extension == "dta", read_status == "dta_readable", !is.na(year)) |> dplyr::distinct(year) |> dplyr::arrange(year) |> dplyr::pull(year)

exact_check <- cands |>
  dplyr::mutate(vu = normalize_var(var_name)) |>
  dplyr::filter(vu %in% c("P17ST", "P61ST", "P41ST.E")) |>
  dplyr::count(vu, name = "n_hits")

found_by_year <- cands |>
  dplyr::filter(!is.na(year), !is.na(target_concept)) |>
  dplyr::group_by(year, target_concept) |>
  dplyr::summarise(vars = paste(unique(var_name), collapse = ", "), .groups = "drop")

manual_years <- map |>
  dplyr::filter(needs_manual_review %in% TRUE, !is.na(year)) |>
  dplyr::distinct(year) |> dplyr::arrange(year) |> dplyr::pull(year)

dict_status <- if (nrow(dict_inv) > 0) "suficiente/parcial (importado); revisar cobertura" else "não disponível ou vazio"

lines <- c(
  "# Harmonization Report",
  "",
  "## Resumo de arquivos locais",
  paste0("- Total de arquivos encontrados: ", n_files),
  paste0("- Anos com .dta legíveis: ", ifelse(length(readable_years) > 0, paste(readable_years, collapse = ", "), "nenhum")),
  "",
  "## Variáveis-alvo encontradas por ano",
  if (nrow(found_by_year) == 0) "- Nenhuma correspondência encontrada automaticamente." else apply(found_by_year, 1, function(r) paste0("- ", r[[1]], " | ", r[[2]], " -> ", r[[3]])),
  "",
  "## P17ST / P61ST / P41ST.E (nome exato)",
  if (nrow(exact_check) > 0) paste0("- ", exact_check$vu, ": ", exact_check$n_hits, " hit(s)") else "- Não houve hit exato automático.",
  "",
  "## Revisão manual",
  paste0("- Anos com needs_manual_review=TRUE: ", ifelse(length(manual_years) > 0, paste(manual_years, collapse = ", "), "nenhum")),
  "",
  "## Dicionário Excel",
  paste0("- Status: ", dict_status),
  "",
  "## Outputs principais",
  "- docs/local_file_inventory.csv",
  "- docs/variable_inventory.csv",
  "- docs/read_errors.csv",
  "- docs/dictionary_inventory.csv",
  "- docs/target_variable_candidates.csv",
  "- docs/variable_mapping.csv",
  "- docs/english_question_texts.csv",
  "- docs/harmonization_report.md",
  "- data_intermediate/latinobarometro_harmonized.csv",
  "- data_intermediate/latinobarometro_harmonized.rds",
  "- data_intermediate/latinobarometro_country_year_series.csv",
  "- output/figures/"
)

writeLines(unlist(lines), file.path(cfg$docs_dir, "harmonization_report.md"))
message("Saved docs/harmonization_report.md")
