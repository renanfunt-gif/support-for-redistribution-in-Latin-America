source("scripts/00_utils.R")
check_dependencies(c("fs", "dplyr", "readr", "ggplot2"))

cfg <- get_config()
ensure_dirs(cfg)

required_files <- c(
  file.path(cfg$docs_dir, "local_file_inventory.csv"),
  file.path(cfg$docs_dir, "variable_inventory.csv"),
  file.path(cfg$docs_dir, "dictionary_inventory.csv"),
  file.path(cfg$docs_dir, "target_variable_candidates.csv"),
  file.path(cfg$docs_dir, "variable_mapping.csv"),
  file.path(cfg$docs_dir, "harmonization_report.md"),
  file.path(cfg$data_intermediate_dir, "latinobarometro_country_year_series.csv")
)
missing <- required_files[!fs::file_exists(required_files)]
if (length(missing) > 0) stop("Prerequisites missing before plotting: ", paste(missing, collapse = "; "))

series <- readr::read_csv(file.path(cfg$data_intermediate_dir, "latinobarometro_country_year_series.csv"), show_col_types = FALSE)
if (nrow(series) == 0) {
  message("No country-year rows available. Skipping plots.")
  quit(save = "no")
}

p1 <- ggplot2::ggplot(series, ggplot2::aes(x = year, y = mean_original_code, color = country, group = country)) +
  ggplot2::geom_line(alpha = 0.7) +
  ggplot2::facet_wrap(~standardized_name, scales = "free_y") +
  ggplot2::theme_minimal() +
  ggplot2::labs(title = "Série histórica (média do código original)", x = "Ano", y = "Média")

ggplot2::ggsave(file.path(cfg$figures_dir, "country_year_mean_series.png"), p1, width = 14, height = 8, dpi = 300)

p2 <- ggplot2::ggplot(series, ggplot2::aes(x = year, y = prop_non_missing, color = country, group = country)) +
  ggplot2::geom_line(alpha = 0.7) +
  ggplot2::facet_wrap(~standardized_name, scales = "free_y") +
  ggplot2::theme_minimal() +
  ggplot2::labs(title = "Cobertura de resposta (não missing)", x = "Ano", y = "Proporção não missing")

ggplot2::ggsave(file.path(cfg$figures_dir, "country_year_nonmissing_series.png"), p2, width = 14, height = 8, dpi = 300)

message("Saved exploratory figures to output/figures/")
