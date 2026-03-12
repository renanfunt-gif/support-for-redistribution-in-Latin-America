#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(fs)
  library(janitor)
  library(purrr)
  library(readr)
  library(readxl)
  library(stringr)
  library(tidyr)
  library(writexl)
})

root_dir <- fs::path_abs("project")
ts_dir <- fs::path(root_dir, "data_raw", "time_series")
wave_dir <- fs::path(root_dir, "data_raw", "waves")
docs_dir <- fs::path(root_dir, "docs")

fs::dir_create(docs_dir, recurse = TRUE)

years <- 2000:2024

extract_from_dictionary <- function(file_path) {
  ext <- fs::path_ext(file_path)
  if (!(ext %in% c("xlsx", "xls", "csv"))) return(tibble())

  if (ext == "csv") {
    raw <- suppressMessages(readr::read_csv(file_path, show_col_types = FALSE))
    sheets <- list(main = raw)
  } else {
    sheet_names <- readxl::excel_sheets(file_path)
    sheets <- purrr::set_names(sheet_names) |>
      purrr::map(~ readxl::read_excel(file_path, sheet = .x))
  }

  purrr::imap_dfr(sheets, function(df, sheet_name) {
    df <- janitor::clean_names(df)
    if (ncol(df) < 2) return(tibble())

    long <- df |>
      mutate(row_id = row_number()) |>
      pivot_longer(-row_id, names_to = "col", values_to = "value") |>
      mutate(value_chr = as.character(value))

    cues <- long |>
      filter(str_detect(value_chr, regex("how fair|distribution of income|justa.*distribuci|acceptable.*inequality|desigualdad.*aceptable|p17st|p61st|q19st", ignore_case = TRUE))) |>
      select(row_id) |>
      distinct()

    if (nrow(cues) == 0) return(tibble())

    df |>
      mutate(row_id = row_number(), sheet = sheet_name) |>
      semi_join(cues, by = "row_id")
  })
}

candidate_dict_files <- fs::dir_ls(ts_dir, regexp = "\\.(xlsx?|csv)$", recurse = TRUE, type = "file")

dict_hits <- map_dfr(candidate_dict_files, extract_from_dictionary, .id = "dictionary_file")

manual_template <- tibble(
  year = years,
  var_income_fairness = NA_character_,
  var_inequality_acceptability = NA_character_,
  source_type = "manual_template",
  notes = "Preencher a partir do dicionário integrado 1981-2024 e questionário da onda"
) |>
  mutate(
    var_income_fairness = case_when(
      year %in% c(2023, 2024) ~ "P17ST",
      year == 2020 ~ "Q19ST.A",
      TRUE ~ var_income_fairness
    ),
    var_inequality_acceptability = case_when(
      year %in% c(2023, 2024) ~ "P61ST",
      TRUE ~ var_inequality_acceptability
    ),
    notes = case_when(
      year %in% c(2023, 2024) ~ "Código confirmado por instrução do usuário; validar wording e escala no questionário.",
      year == 2020 ~ "Exemplo indicado na instrução: Q19ST.A para justiça distributiva; confirmar no questionário oficial.",
      TRUE ~ notes
    )
  )

if (nrow(dict_hits) > 0) {
  readr::write_csv(dict_hits, fs::path(docs_dir, "dictionary_hits_raw.csv"))
}

readr::write_csv(manual_template, fs::path(docs_dir, "variable_crosswalk.csv"))
writexl::write_xlsx(manual_template, fs::path(docs_dir, "variable_crosswalk.xlsx"))

message("Crosswalk template updated at docs/variable_crosswalk.csv")
