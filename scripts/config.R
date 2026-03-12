# Central configuration for local-first Latinobarómetro pipeline

get_default_raw_data_dir <- function() {
  # Windows default provided by user; editable by user/environment
  "C:/Users/renan/Downloads/Latinobarometro compactado"
}

get_config <- function() {
  root <- if (requireNamespace("here", quietly = TRUE)) here::here() else normalizePath(".", winslash = "/", mustWork = TRUE)

  raw_data_dir <- Sys.getenv("LB_RAW_DATA_DIR", unset = get_default_raw_data_dir())
  dictionary_dir <- Sys.getenv("LB_DICTIONARY_DIR", unset = file.path(raw_data_dir, "dictionaries"))

  list(
    project_root = root,
    raw_data_dir = raw_data_dir,
    dictionary_dir = dictionary_dir,
    data_intermediate_dir = file.path(root, "data_intermediate"),
    docs_dir = file.path(root, "docs"),
    output_dir = file.path(root, "output"),
    figures_dir = file.path(root, "output", "figures")
  )
}
