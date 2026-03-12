# Shared utilities (local files only; no scraping/downloading)

source("scripts/config.R")

required_pkgs <- c(
  "here", "fs", "dplyr", "purrr", "stringr", "readr", "tibble", "tidyr",
  "haven", "labelled", "readxl", "janitor", "ggplot2"
)

check_dependencies <- function(pkgs = required_pkgs) {
  missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0) {
    stop("Missing packages: ", paste(missing, collapse = ", "), "\nInstall before running.")
  }
  invisible(TRUE)
}

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || all(is.na(x))) y else x

ensure_dirs <- function(cfg) {
  fs::dir_create(cfg$docs_dir, recurse = TRUE)
  fs::dir_create(cfg$data_intermediate_dir, recurse = TRUE)
  fs::dir_create(cfg$output_dir, recurse = TRUE)
  fs::dir_create(cfg$figures_dir, recurse = TRUE)
}

extract_year_from_path <- function(path_chr) {
  as.integer(stringr::str_extract(path_chr, "(200[0-9]|201[0-9]|202[0-4])"))
}

safe_read_dta <- function(path) {
  tryCatch(
    haven::read_dta(path),
    error = function(e) structure(list(.error = conditionMessage(e)), class = "lb_read_error")
  )
}

collect_value_labels <- function(x) {
  vl <- labelled::val_labels(x)
  if (length(vl) == 0) return("")
  paste(paste0(names(vl), "=", unname(vl)), collapse = " | ")
}

find_col_by_pattern <- function(df, patterns) {
  nm <- names(df)
  for (p in patterns) {
    hit <- nm[stringr::str_detect(stringr::str_to_lower(nm), p)]
    if (length(hit) > 0) return(hit[1])
  }
  NA_character_
}

normalize_var <- function(x) {
  stringr::str_to_upper(stringr::str_replace_all(x %||% "", "\\s+", ""))
}

known_target_codes <- function() {
  # Códigos fornecidos pelo usuário (ordem temporal ainda pode exigir revisão manual)
  list(
    fair_income_distribution = c("P16ST", "P17ST", "P14ST", "P12ST", "P27ST", "P18ST", "P21ST", "P20ST", "P23ST", "P19ST.A"),
    inequality_acceptable = c("P72NPN", "P61ST"),
    justice_wealth_distribution = c("P18NE", "P26ST.E", "P15ST.E", "P41ST.E", "P50ST.E", "P47ST.E")
  )
}
