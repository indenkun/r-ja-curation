# R/fetch_articles.R
# ------------------
# 必要パッケージの読み込み（存在しなければインストール）
pkgs <- c(
  "tidyRSS", "dplyr", "purrr", "stringr", "lubridate",
  "httr2", "jsonlite", "rvest", "urltools", "tibble"
)
to_install <- setdiff(pkgs, rownames(installed.packages()))
if (length(to_install)) install.packages(to_install, repos = "https://cloud.r-project.org")

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

# ------------------
# 設定
# ------------------

# 収集対象RSS（必要に応じて追加してください）
feeds <- tribble(
  ~source,   ~url,
  "Qiita",   "https://qiita.com/tags/r/feed",
  "Zenn",    "https://zenn.dev/topics/r/feed",
  "HatenaIT","https://b.hatena.ne.jp/hotentry/it.rss"
)

# 日本語検知（ひらがな・カタカナ・漢字のいずれかが含まれる）
is_japanese <- function(text) {
  if (is.na(text) || !nzchar(text)) return(FALSE)
  str_detect(text, "[\\p{Hiragana}\\p{Katakana}\\p{Han}]")
}

# R関連のキーワード（最低限の例。お好みで増やしてください）
r_keywords <- c(
  "R", "R言語", "tidyverse", "ggplot2", "dplyr", "tidyr", "readr", "purrr",
  "stringr", "lubridate", "data.table", "Shiny", "shinylive", "Quarto", "R Markdown"
)

is_r_related <- function(title, summary = "") {
  text <- paste(title %||% "", summary %||% "")
  # 「R」単体は誤検知を避けるため単語境界も考慮
  kw_regex <- paste0("(?i)\\b(", paste(r_keywords, collapse = "|"), ")\\b")
  str_detect(text, kw_regex)
}

# はてなブックマーク数を取得
get_hatena_count <- function(url) {
  # 参考: entry.count はプレーンテキストで数値を返します（0の場合は "0"）
  # https://api.b.st-hatena.com/entry.count?url={encoded_url}
  safe_req <- function(u) {
    req <- request(paste0("https://api.b.st-hatena.com/entry.count?url=", URLencode(u)))
    resp <- tryCatch(req_perform(req), error = function(e) NULL)
    if (is.null(resp)) return(NA_integer_)
    txt <- tryCatch(resp_body_string(resp), error = function(e) "0")
    as.integer(txt %||% "0")
  }
  safe_req(url)
}

# OGP画像（サムネイル）を推定
get_og_image <- function(url) {
  pg <- tryCatch(read_html(url, options = "HUGE"), error = function(e) NULL)
  if (is.null(pg)) return(NA_character_)
  # og:image 優先
  og <- html_attr(html_element(pg, "meta[property='og:image']"), "content")
  if (!is.na(og) && nzchar(og)) return(og)

  # twitter:image
  tw <- html_attr(html_element(pg, "meta[name='twitter:image']"), "content")
  if (!is.na(tw) && nzchar(tw)) return(tw)

  # fallback: ファビコン（GoogleのFavicon API）
  dom <- domain(url)
  if (!is.na(dom)) {
    return(paste0("https://www.google.com/s2/favicons?sz=64&domain_url=https://", dom))
  }

  NA_character_
}

# RSSを1件取得して整形
fetch_one <- function(src, feed_url) {
  df <- tryCatch(tidyfeed(feed_url), error = function(e) tibble())
  if (!nrow(df)) return(tibble())
  # tidyRSS の列名に合わせて取り出し
  out <- df |>
    transmute(
      source = src,
      title  = coalesce(item_title, title, ""),
      link   = coalesce(item_link, link, ""),
      summary= coalesce(item_description, description, item_content, ""),
      published = coalesce(item_pub_date, pub_date, as.character(Sys.time()))
    ) |>
    mutate(
      published = suppressWarnings(lubridate::as_datetime(published)),
      published = if_else(is.na(published), Sys.time(), published)
    ) |>
    filter(nzchar(link))
  distinct(out, link, .keep_all = TRUE)
}

# 収集・フィルタ・スコアリング
articles <- pmap_dfr(feeds, ~ fetch_one(..1, ..2))

if (!nrow(articles)) {
  message("No articles fetched. Exiting with empty JSON.")
  dir.create("app/data", recursive = TRUE, showWarnings = FALSE)
  write_json(list(items = list(), updated_at = as.character(Sys.time())), "app/data/articles.json",
             auto_unbox = TRUE, pretty = TRUE)
  quit(save = "no")
}

# フィルタ：日本語かつ/または R関連キーワード
articles <- articles |>
  filter(is_japanese(title) | is_japanese(summary) | is_r_related(title, summary)) |>
  mutate(
    # はてなブックマーク数（礼儀として短いスリープ）
    hb_count = map_int(link, ~ { Sys.sleep(0.2); get_hatena_count(.x) }),
    thumb    = map_chr(link, ~ { Sys.sleep(0.1); get_og_image(.x) }),
    domain   = domain(link)
  ) |>
  arrange(desc(hb_count), desc(published))

# 上限件数（例：最新500件まで）
articles <- articles |> slice_head(n = 500)

# JSONに保存（Shiny が読む）
dir.create("app/data", recursive = TRUE, showWarnings = FALSE)
payload <- list(
  updated_at = as.character(with_tz(Sys.time(), "Asia/Tokyo")),
  items = articles |> mutate(published = as.character(with_tz(published, "Asia/Tokyo")))
)
write_json(payload, "app/data/articles.json", auto_unbox = TRUE, pretty = TRUE)

message("Done: app/data/articles.json")
