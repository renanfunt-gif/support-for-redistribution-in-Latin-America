# Pipeline local-first para harmonização do Latinobarómetro (2000–2024)

Este projeto usa **apenas arquivos locais** (sem scraping/download automático).

## Configuração de caminho

Edite `scripts/config.R` (ou variáveis de ambiente):

- `raw_data_dir` (default): `C:/Users/renan/Downloads/Latinobarometro compactado`
- `dictionary_dir` (default: subpasta `dictionaries` dentro de `raw_data_dir`)
- saídas em `docs/`, `data_intermediate/` e `output/figures/`

Sobrescritas opcionais por ambiente:

- `LB_RAW_DATA_DIR`
- `LB_DICTIONARY_DIR`

## Códigos-alvo incorporados (fornecidos pelo usuário)

- `fair_income_distribution`: `P16ST`, `P17ST`, `P14ST`, `P12ST`, `P27ST`, `P18ST`, `P21ST`, `P20ST`, `P23ST`, `P19ST.A`
- `inequality_acceptable`: `P72NPN`, `P61ST`
- `justice_wealth_distribution`: `P18NE`, `P26ST.E`, `P15ST.E`, `P41ST.E`, `P50ST.E`, `P47ST.E`

> Observação: a ordem cronológica desses códigos ainda pode exigir revisão manual por onda.

## Etapas do pipeline

1. `scripts/01_inventory_local_files.R`
2. `scripts/02_build_variable_inventory.R`
3. `scripts/03_import_dictionary_excel.R`
4. `scripts/04_find_target_variables.R`
5. `scripts/05_build_variable_mapping.R`
6. `scripts/06_harmonize_latinobarometro.R`
7. `scripts/07_extract_english_question_texts.R`
8. `scripts/10_build_country_year_series.R`
9. `scripts/09_build_harmonization_report.R`
10. `scripts/08_exploratory_plots.R`

Runner único:

```r
source("scripts/99_run_all.R")
```

## Artefatos esperados

- `docs/local_file_inventory.csv`
- `docs/variable_inventory.csv`
- `docs/read_errors.csv`
- `docs/dictionary_inventory.csv`
- `docs/target_variable_candidates.csv`
- `docs/variable_mapping.csv`
- `docs/english_question_texts.csv`
- `docs/harmonization_report.md`
- `data_intermediate/latinobarometro_harmonized.csv`
- `data_intermediate/latinobarometro_harmonized.rds`
- `data_intermediate/latinobarometro_country_year_series.csv`
- `output/figures/`

## Regra metodológica central

Priorizar auditabilidade e revisão manual explícita, evitando inferências frágeis de equivalência entre ondas.
