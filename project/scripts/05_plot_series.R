#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(fs)
  library(ggplot2)
  library(readr)
})

root_dir <- fs::path_abs("project")
final_dir <- fs::path(root_dir, "data_final")
fig_dir <- fs::path(root_dir, "figs")

fs::dir_create(fig_dir, recurse = TRUE)

series <- readr::read_csv(fs::path(final_dir, "latinobarometro_country_year_redistribution.csv"), show_col_types = FALSE)

plot_question <- function(df, q_name) {
  data_q <- df |> filter(question == q_name)
  if (nrow(data_q) == 0) return(invisible(NULL))

  p_mean_all <- ggplot(data_q, aes(x = year, y = mean_ordinal_std, color = country, group = country)) +
    geom_line(alpha = 0.8) +
    labs(
      x = "Ano",
      y = "Média ordinal padronizada",
      color = "País",
      title = paste("Série histórica -", q_name, "(média padronizada)")
    ) +
    theme_minimal(base_size = 12)

  ggsave(fs::path(fig_dir, paste0("series_mean_all_countries_", q_name, ".png")), p_mean_all, width = 12, height = 7, dpi = 300)

  p_mean_facet <- p_mean_all + facet_wrap(~country)
  ggsave(fs::path(fig_dir, paste0("series_mean_faceted_", q_name, ".png")), p_mean_facet, width = 14, height = 10, dpi = 300)

  p_crit_all <- ggplot(data_q, aes(x = year, y = prop_critical, color = country, group = country)) +
    geom_line(alpha = 0.8) +
    labs(
      x = "Ano",
      y = "Proporção crítica",
      color = "País",
      title = paste("Série histórica -", q_name, "(proporção crítica)")
    ) +
    theme_minimal(base_size = 12)

  ggsave(fs::path(fig_dir, paste0("series_critical_all_countries_", q_name, ".png")), p_crit_all, width = 12, height = 7, dpi = 300)

  p_crit_facet <- p_crit_all + facet_wrap(~country)
  ggsave(fs::path(fig_dir, paste0("series_critical_faceted_", q_name, ".png")), p_crit_facet, width = 14, height = 10, dpi = 300)

  key_countries <- c("Brazil", "Argentina", "Chile", "Mexico", "Colombia", "Brasil", "México", "Colômbia")
  key <- data_q |> filter(country %in% key_countries)
  regional <- data_q |> group_by(year) |> summarise(country = "Média regional", mean_ordinal_std = mean(mean_ordinal_std, na.rm = TRUE), prop_critical = mean(prop_critical, na.rm = TRUE), .groups = "drop")

  highlight_data <- bind_rows(
    key |> select(year, country, mean_ordinal_std, prop_critical),
    regional
  )

  if (nrow(highlight_data) > 0) {
    p_high <- ggplot(highlight_data, aes(x = year, y = prop_critical, color = country, group = country)) +
      geom_line(linewidth = 1) +
      labs(
        x = "Ano",
        y = "Proporção crítica",
        color = "País",
        title = paste("Destaque regional -", q_name)
      ) +
      theme_minimal(base_size = 12)

    ggsave(fs::path(fig_dir, paste0("series_critical_highlight_", q_name, ".png")), p_high, width = 12, height = 7, dpi = 300)
  }
}

unique(series$question) |> lapply(function(q) plot_question(series, q))

message("Figures saved to figs/")
