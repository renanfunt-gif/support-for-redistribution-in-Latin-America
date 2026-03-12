source("scripts/00_utils.R")
check_dependencies(c("fs", "dplyr", "purrr", "stringr", "readr", "tibble", "readxl", "janitor", "tidyr"))

cfg <- get_config()
ensure_dirs(cfg)

if (!fs::dir_exists(cfg$dictionary_dir)) {
  readr::write_csv(tibble::tibble(), file.path(cfg$docs_dir, "dictionary_inventory.csv"))
  message("Dictionary directory not found: ", cfg$dictionary_dir)
  quit(save = "no")
}

dict_files <- fs::dir_ls(cfg$dictionary_dir, recurse = TRUE, type = "file", regexp = "\\.(xlsx|xls)$")

if (length(dict_files) == 0) {
  readr::write_csv(tibble::tibble(), file.path(cfg$docs_dir, "dictionary_inventory.csv"))
  message("No Excel dictionaries found.")
  quit(save = "no")
}

pick_col <- function(nms, patterns) {
  nms2 <- stringr::str_to_lower(nms)
  for (p in patterns) {
    hit <- nms[which(stringr::str_detect(nms2, p))]
    if (length(hit) > 0) return(hit[1])
  }
  NA_character_
}


col_or_na <- function(dat, col_name) {
  if (is.na(col_name) || !(col_name %in% names(dat))) return(rep(NA_character_, nrow(dat)))
  as.character(dat[[col_name]])
}

parse_sheet <- function(file, sheet) {
  raw <- tryCatch(readxl::read_excel(file, sheet = sheet), error = function(e) NULL)
  if (is.null(raw) || nrow(raw) == 0 || ncol(raw) == 0) return(tibble::tibble())

  dat <- janitor::clean_names(raw)
  nms <- names(dat)

  col_var <- pick_col(nms, c("^var(_name)?$", "variable", "pregunta", "codigo"))
  col_lbl <- pick_col(nms, c("question", "label", "texto", "enunciado"))
  col_year <- pick_col(nms, c("^year$", "wave", "ano", "anio"))
  col_code <- pick_col(nms, c("code", "value", "response", "categoria", "escala"))
  col_obs <- pick_col(nms, c("obs", "note", "coment", "remark"))

  tibble::tibble(
    source_file = fs::path_file(file),
    source_sheet = sheet,
    row_id = dplyr::row_number(),
    year = suppressWarnings(as.integer(col_or_na(dat, col_year))),
    var_name = col_or_na(dat, col_var),
    var_label = col_or_na(dat, col_lbl),
    response_codes = col_or_na(dat, col_code),
    observations = col_or_na(dat, col_obs),
    col_var_detected = col_var %||% "",
    col_label_detected = col_lbl %||% "",
    col_year_detected = col_year %||% "",
    detection_note = dplyr::if_else(is.na(col_var) & is.na(col_lbl), "ambiguous_columns", "ok")
  )
}

inventory <- purrr::map_dfr(dict_files, function(f) {
  sheets <- readxl::excel_sheets(f)
  purrr::map_dfr(sheets, ~ parse_sheet(f, .x))
})

readr::write_csv(inventory, file.path(cfg$docs_dir, "dictionary_inventory.csv"))
message("Saved docs/dictionary_inventory.csv")
