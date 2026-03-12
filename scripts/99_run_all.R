# Run full local-first pipeline (no scraping)

steps <- c(
  "scripts/01_inventory_local_files.R",
  "scripts/02_build_variable_inventory.R",
  "scripts/03_import_dictionary_excel.R",
  "scripts/04_find_target_variables.R",
  "scripts/05_build_variable_mapping.R",
  "scripts/06_harmonize_latinobarometro.R",
  "scripts/07_extract_english_question_texts.R",
  "scripts/10_build_country_year_series.R",
  "scripts/09_build_harmonization_report.R",
  "scripts/08_exploratory_plots.R"
)

for (s in steps) {
  cat("\n=== Running:", s, "===\n")
  source(s, local = new.env(parent = globalenv()))
}

cat("\nPipeline completed.\n")
