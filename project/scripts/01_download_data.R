#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(fs)
  library(httr2)
  library(purrr)
  library(readr)
  library(stringr)
  library(tidyr)
})

root_dir <- fs::path_abs(fs::path("project"))
raw_dir <- fs::path(root_dir, "data_raw")
waves_dir <- fs::path(raw_dir, "waves")
time_series_dir <- fs::path(raw_dir, "time_series")
log_dir <- fs::path(root_dir, "docs")

fs::dir_create(waves_dir, recurse = TRUE)
fs::dir_create(time_series_dir, recurse = TRUE)
fs::dir_create(log_dir, recurse = TRUE)

start_year <- 2000
end_year <- 2024
years <- start_year:end_year

source_pages <- tibble::tribble(
  ~type, ~url,
  "wave_level", "https://www.latinobarometro.org/latOnline.jsp?Idioma=I",
  "wave_level", "https://www.latinobarometro.org/latNewsShow.jsp?ID=193",
  "time_series", "https://www.latinobarometro.org/latContents.jsp?CMSID=databases",
  "time_series", "https://www.latinobarometro.org/latContents.jsp?CMSID=questionnaires"
)

safe_get_text <- function(url) {
  tryCatch({
    request(url) |>
      req_user_agent("latinobarometro-harmonization/1.0") |>
      req_timeout(60) |>
      req_perform() |>
      resp_body_string()
  }, error = function(e) NA_character_)
}

extract_candidate_links <- function(html, base_url) {
  if (is.na(html)) return(character())
  links <- stringr::str_match_all(html, "(?i)href=[\"']([^\"']+)[\"']")[[1]][, 2]
  links <- links[!is.na(links)]
  links <- links[stringr::str_detect(links, "(?i)\\.(zip|sav|dta|csv|xlsx?|pdf)$")]
  full_links <- purrr::map_chr(links, function(x) {
    if (stringr::str_detect(x, "^https?://")) x else url_absolute(x, base_url)
  })
  unique(full_links)
}

page_links <- source_pages |>
  mutate(html = map_chr(url, safe_get_text),
         links = map2(html, url, extract_candidate_links)) |>
  tidyr::unnest_longer(links, keep_empty = TRUE) |>
  rename(file_url = links)

year_regex <- paste0("(", paste(years, collapse = "|"), ")")
wave_candidates <- page_links |>
  filter(type == "wave_level", !is.na(file_url)) |>
  mutate(year = suppressWarnings(as.integer(str_extract(file_url, year_regex)))) |>
  filter(!is.na(year)) |>
  distinct(year, file_url)

time_series_candidates <- page_links |>
  filter(type == "time_series", !is.na(file_url)) |>
  filter(str_detect(file_url, regex("time|series|dic|integr|1981|2024", ignore_case = TRUE))) |>
  distinct(file_url)

manual_fallback <- tibble::tribble(
  ~year, ~file_url,
  2024L, "https://www.latinobarometro.org/latContents.jsp?CMSID=databases",
  2023L, "https://www.latinobarometro.org/latContents.jsp?CMSID=databases",
  2020L, "https://www.latinobarometro.org/latContents.jsp?CMSID=databases"
)

wave_download_plan <- tibble(year = years) |>
  left_join(wave_candidates, by = "year") |>
  rows_update(manual_fallback, by = "year", unmatched = "ignore")

safe_download <- function(url, dest_path) {
  if (is.na(url)) {
    return(list(status = "missing_link", message = "No URL identified automatically"))
  }
  tryCatch({
    request(url) |>
      req_user_agent("latinobarometro-harmonization/1.0") |>
      req_timeout(120) |>
      req_perform(path = dest_path)
    list(status = "ok", message = "downloaded")
  }, error = function(e) {
    list(status = "error", message = conditionMessage(e))
  })
}

wave_log <- pmap_dfr(wave_download_plan, function(year, file_url) {
  file_url_safe <- ifelse(is.na(file_url), "", file_url)
  ext <- str_extract(file_url_safe, "(?i)(zip|sav|dta|csv|xlsx?)$") %>% tolower()
  if (is.na(ext)) ext <- "html"
  dest <- fs::path(waves_dir, sprintf("latinobarometro_%s.%s", year, ext))
  res <- safe_download(file_url, dest)
  tibble(
    asset_type = "wave",
    year = year,
    source_url = file_url,
    dest_file = as.character(dest),
    status = res$status,
    message = res$message
  )
})

if (nrow(time_series_candidates) == 0) {
  time_series_candidates <- tibble(file_url = "https://www.latinobarometro.org/latContents.jsp?CMSID=databases")
}

ts_log <- map_dfr(time_series_candidates$file_url, function(u) {
  ext <- str_extract(u, "(?i)(zip|sav|dta|csv|xlsx?|pdf)$") %>% tolower()
  if (is.na(ext)) ext <- "html"
  dest <- fs::path(time_series_dir, paste0("latinobarometro_time_series_1981_2024.", ext))
  res <- safe_download(u, dest)
  tibble(
    asset_type = "time_series",
    year = NA_integer_,
    source_url = u,
    dest_file = as.character(dest),
    status = res$status,
    message = res$message
  )
})

log_tbl <- bind_rows(wave_log, ts_log) |>
  mutate(timestamp = as.character(Sys.time()))

readr::write_csv(log_tbl, fs::path(log_dir, "download_log.csv"))

summary_tbl <- log_tbl |>
  count(asset_type, status, name = "n")

readr::write_csv(summary_tbl, fs::path(log_dir, "download_summary.csv"))

message("Download stage finished. See docs/download_log.csv for details.")
