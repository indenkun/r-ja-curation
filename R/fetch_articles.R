# R/fetch_articles.R
# ------------------
# ライブラリ（Actions側で setup-r-dependencies により事前インストール）
library(tidyRSS)
library(dplyr)
library(purrr)
library(stringr)
library(lubridate)
library(httr2)
library(jsonlite)
library(rvest)
library(urltools)
library(tibble)

`%||%` <- function(a, b) {
  # a が長さベクトルの場合も扱えるように
  if (length(a) == 0) return(b)
  a <- ifelse(is.na(a) | a == "", b, a)
  a
}

# 日本語検知（ベクトル対応）
is_japanese <- function(x) {
  x <- ifelse(is.na(x), "", x)
  str_detect(x, "[\\p{Hiragana}\\p{Katakana}\\p{Han}]")
}

# R関連キーワード
r_keywords <- c(
  "R", "R言語", "tidyverse", "ggplot2", "dplyr", "tidyr", "readr", "purrr",
  "stringr", "lubridate", "data.table", "Shiny", "shinylive", "Quarto", "R Markdown"
)

# R関連判定（ベクトル対応）
is_r_related <- function(title, summary = "") {
  title   <- ifelse(is.na(title),   "", title)
  summary <- ifelse(is.na(summary), "", summary)
  text <- paste(title, summary)
  kw_regex <- paste0("(?i)\\b(", paste(r_keywords, collapse = "|"), ")\\b")
  str_detect(text, kw_regex)
}

# はてなブックマーク数取得
get_hatena_count <- function(url) {
  safe_req <- function(u) {
    req <- request(paste0("https://api.b.st-hatena.com/entry.count?url=", URLencode(u)))
    resp <- tryCatch(req_perform(req), error = function(e) NULL)
    if (is.null(resp)) return(NA_integer_)
    txt <- tryCatch(resp_body_string(resp), error = function(e) "0")
    as.integer(txt %||% "0")
  }
  safe_req(url)
}

# OGP画像取得
get_og_image <- function(url) {
  pg <- tryCatch(read_html(url, options = "HUGE"), error = function(e) NULL)
  if (is.null(pg)) return(NA_character_)
  og <- html_attr(html_element(pg, "meta[property='og:image']"), "content")
  if (!is.na(og) && nzchar(og)) return(og)
  tw <- html_attr(html_element(pg, "meta[name='twitter:image']"), "content")
  if (!is.na(tw) && nzchar(tw)) return(tw)
  dom <- domain(url)
  if (!is.na(dom)) return(paste0("https://www.google.com/s2/favicons?sz=64&domain_url=https://", dom))
  NA_character_
}

# 存在する列を安全に選ぶヘルパー
a_pick_first <- function(dat, candidates, default = "") {
  for (nm in candidates) {
    if (nm %in% names(dat)) return(dat[[nm]])
  }
  rep(default, nrow(dat))
}

# 安全な fetch_one（tidyRSS 継続）
fetch_one <- function(src, feed_url) {
  df <- tryCatch(tidyfeed(feed_url), error = function(e) tibble())
  if (!nrow(df)) return(tibble())

  out <- tibble(
    source    = src,
    title     = a_pick_first(df, c("item_title", "title"), ""),
    link      = a_pick_first(df, c("item_link", "link"), ""),
    summary   = a_pick_first(df, c("item_description", "description", "item_content"), ""),
    published = a_pick_first(df, c("item_pub_date", "pub_date"), as.character(Sys.time()))
  ) |>
    mutate(
      published = suppressWarnings(lubridate::as_datetime(published)),
      published = if_else(is.na(published), Sys.time(), published)
    ) |>
    filter(nzchar(link)) |>
    distinct(link, .keep_all = TRUE)

  out
}

# ------------------
# フィード一覧
feeds <- tribble(
  ~source,   ~url,
  "Qiita",   "https://qiita.com/tags/r/feed",
  "Zenn",    "https://zenn.dev/topics/r/feed",
  "HatenaIT","https://b.hatena.ne.jp/hotentry/it.rss"
)

# 収集
articles <- pmap_dfr(feeds, ~ fetch_one(..1, ..2))

if (!nrow(articles)) {
  message("No articles fetched. Exiting with empty JSON.")
  dir.create("app/data", recursive = TRUE, showWarnings = FALSE)
  write_json(list(items = list(), updated_at = as.character(Sys.time())), "app/data/articles.json",
             auto_unbox = TRUE, pretty = TRUE)
  quit(save = "no")
}

# 日本語/R関連フィルタ + 追加情報付与
articles <- articles |>
  filter(is_japanese(title) | is_japanese(summary) | is_r_related(title, summary)) |>
  mutate(
    hb_count = map_int(link, ~ { Sys.sleep(0.3); get_hatena_count(.x) }),
    thumb    = map_chr(link, ~ { Sys.sleep(0.1); get_og_image(.x) }),
    domain   = domain(link)
  ) |>
  arrange(desc(hb_count), desc(published))

# 上限（最新500件）
articles <- articles |> slice_head(n = 500)

# JSON 書き出し
dir.create("app/data", recursive = TRUE, showWarnings = FALSE)
payload <- list(
  updated_at = as.character(with_tz(Sys.time(), "Asia/Tokyo")),
  items = articles |> mutate(published = as.character(with_tz(published, "Asia/Tokyo")))
)
write_json(payload, "app/data/articles.json", auto_unbox = TRUE, pretty = TRUE)

message("Done: app/data/articles.json")
