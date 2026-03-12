#!/usr/bin/env Rscript

scripts <- c(
  "01_download_data.R",
  "02_build_crosswalk.R",
  "03_harmonize_variables.R",
  "04_build_country_year_series.R",
  "05_plot_series.R"
)

base <- file.path("project", "scripts")

for (s in scripts) {
  cat("\n=== Running", s, "===\n")
  source(file.path(base, s), local = new.env(parent = globalenv()))
}

cat("\nPipeline finished.\n")
