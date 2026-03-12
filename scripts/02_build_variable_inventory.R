source("scripts/00_utils.R")
check_dependencies(c("fs", "dplyr", "purrr", "stringr", "readr", "tibble", "haven", "labelled"))

cfg <- get_config()
ensure_dirs(cfg)

inv_file <- file.path(cfg$docs_dir, "local_file_inventory.csv")
if (!fs::file_exists(inv_file)) {
  stop("Missing docs/local_file_inventory.csv. Run scripts/01_inventory_local_files.R first.")
}

files <- readr::read_csv(inv_file, show_col_types = FALSE) |>
  dplyr::filter(extension == "dta")

if (nrow(files) == 0) {
  empty_var <- tibble::tibble(
    year = integer(), source_file = character(), full_path = character(), var_name = character(),
    var_label = character(), var_class = character(), value_labels = character(), n_rows = integer(), n_cols = integer()
  )
  readr::write_csv(empty_var, file.path(cfg$docs_dir, "variable_inventory.csv"))
  readr::write_csv(tibble::tibble(), file.path(cfg$docs_dir, "read_errors.csv"))
  quit(save = "no")
}

read_one <- function(path, year, file_name) {
  dat <- safe_read_dta(path)
  if (inherits(dat, "lb_read_error")) {
    return(list(
      vars = NULL,
      err = tibble::tibble(year = year, source_file = file_name, full_path = path, error_message = dat$.error)
    ))
  }

  vnames <- names(dat)
  out <- tibble::tibble(
    year = year,
    source_file = file_name,
    full_path = path,
    var_name = vnames,
    var_label = purrr::map_chr(vnames, ~ as.character(attr(dat[[.x]], "label") %||% "")),
    var_class = purrr::map_chr(vnames, ~ paste(class(dat[[.x]]), collapse = ";")),
    value_labels = purrr::map_chr(vnames, ~ collect_value_labels(dat[[.x]])),
    n_rows = nrow(dat),
    n_cols = ncol(dat)
  )

  list(vars = out, err = NULL)
}

results <- purrr::pmap(files |> dplyr::select(full_path, year, file_name), read_one)

var_inventory <- dplyr::bind_rows(purrr::map(results, "vars"))
errors <- dplyr::bind_rows(purrr::map(results, "err"))

readr::write_csv(var_inventory, file.path(cfg$docs_dir, "variable_inventory.csv"))
readr::write_csv(errors, file.path(cfg$docs_dir, "read_errors.csv"))

message("Saved docs/variable_inventory.csv and docs/read_errors.csv")
