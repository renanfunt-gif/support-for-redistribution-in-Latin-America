source("scripts/00_utils.R")
check_dependencies(c("fs", "dplyr", "stringr", "readr", "tibble"))

cfg <- get_config()
ensure_dirs(cfg)

if (!fs::dir_exists(cfg$raw_data_dir)) {
  inv <- tibble::tibble(
    year = integer(), file_name = character(), full_path = character(), extension = character(),
    size_bytes = numeric(), read_status = character(), note = character()
  )
  readr::write_csv(inv, file.path(cfg$docs_dir, "local_file_inventory.csv"))
  stop("raw_data_dir not found: ", cfg$raw_data_dir)
}

all_files <- fs::dir_ls(cfg$raw_data_dir, recurse = TRUE, type = "file")

inv <- tibble::tibble(
  year = extract_year_from_path(all_files),
  file_name = fs::path_file(all_files),
  full_path = as.character(all_files),
  extension = stringr::str_to_lower(fs::path_ext(all_files)),
  size_bytes = as.numeric(fs::file_info(all_files)$size)
) |>
  dplyr::mutate(
    read_status = dplyr::case_when(
      extension == "dta" ~ "pending_read_test",
      extension %in% c("xlsx", "xls", "csv", "sav") ~ "non_dta_data_or_meta",
      TRUE ~ "other_file"
    ),
    note = dplyr::case_when(
      is.na(year) ~ "year_not_inferred_from_path",
      TRUE ~ ""
    )
  )

# quick readability test only for .dta
if (any(inv$extension == "dta")) {
  dta_paths <- inv |> dplyr::filter(extension == "dta") |> dplyr::pull(full_path)
  read_ok <- vapply(dta_paths, function(p) !inherits(safe_read_dta(p), "lb_read_error"), logical(1))
  inv$read_status[match(dta_paths, inv$full_path)] <- ifelse(read_ok, "dta_readable", "dta_read_error")
}

readr::write_csv(inv, file.path(cfg$docs_dir, "local_file_inventory.csv"))
message("Saved docs/local_file_inventory.csv")
