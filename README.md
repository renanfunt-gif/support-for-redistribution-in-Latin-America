# Projeto: Apoio à redistribuição e percepções de desigualdade na América Latina (Latinobarómetro)

Este repositório implementa um pipeline reproduzível em **R** para construir uma série histórica comparável (2000–2024) sobre:

1. Avaliação da justiça da distribuição de renda.
2. Aceitabilidade da desigualdade.

> **Princípio central:** não assumir que os códigos de variáveis são estáveis ao longo das ondas. A harmonização é feita via crosswalk (`project/docs/variable_crosswalk.csv`) alimentado pelo dicionário integrado de séries temporais 1981–2024 e validação por questionários oficiais.

## Estrutura

```text
project/
  data_raw/
  data_intermediate/
  data_final/
  docs/
  figs/
  scripts/
```

## Scripts

1. `project/scripts/01_download_data.R`
   - tenta baixar bases por onda (2000–2024) e dicionário de séries temporais;
   - registra falhas sem derrubar o pipeline (`project/docs/download_log.csv`).

2. `project/scripts/02_build_crosswalk.R`
   - constrói/atualiza o crosswalk de harmonização por ano;
   - salva `project/docs/variable_crosswalk.csv`.

3. `project/scripts/03_harmonize_variables.R`
   - lê microdados por onda;
   - extrai país, ano, id, peso e as duas perguntas harmonizadas;
   - padroniza missing e cria variáveis ordinal/binária.

4. `project/scripts/04_build_country_year_series.R`
   - agrega para país-ano;
   - calcula média ordinal, proporção crítica, N total, N válido e indicador de ponderação;
   - gera `project/data_final/latinobarometro_country_year_redistribution.csv`.

5. `project/scripts/05_plot_series.R`
   - gera gráficos de séries históricas em `project/figs/`.

6. `project/scripts/99_run_all.R`
   - executa todo o pipeline em sequência.

## Como rodar

No R:

```r
source("project/scripts/99_run_all.R")
```

## Dependências R

Pacotes usados: `haven`, `labelled`, `dplyr`, `tidyr`, `purrr`, `stringr`, `janitor`, `ggplot2`, `readr`, `fs`, `httr2`, `writexl`, `readxl`.

## Plano técnico resumido

1. Descobrir e baixar ativos oficiais do Latinobarómetro (ondas + dicionário integrado).
2. Construir crosswalk por ano (2000–2024), validando ambiguidades com questionário da onda.
3. Harmonizar microdados e padronizar codificações.
4. Agregar para país-ano com e sem pesos conforme disponibilidade.
5. Produzir gráficos comparativos e artefatos de checagem.

## Principais riscos de comparabilidade

- Mudança de código da variável entre ondas.
- Mudança de wording, categorias e direção de escala.
- Diferenças de universo/filtros amostrais.
- Pesos com nome/definição distintos entre ondas.
- Anos sem dados ou sem uma das perguntas.

Detalhes metodológicos: `project/docs/methodological_notes.md`.
