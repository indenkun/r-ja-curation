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

# R関連キーワード & 除外ワード（誤検出抑制）
r_keywords <- c("R言語","tidyverse","ggplot2","dplyr","tidyr","readr","purrr","stringr",
                "lubridate","data\\.table","Shiny","shinylive","Quarto","R Markdown","R ")
exclude_keywords <- c("React","React\\.js","RPG","RISC","RHEL","ruby on rails")

is_r_related <- function(title, summary = "") {
  title   <- ifelse(is.na(title),   "", title)
  summary <- ifelse(is.na(summary), "", summary)
  txt <- paste(title, summary)
  pos <- str_detect(txt, paste0("(?i)(", paste(r_keywords, collapse="|"), ")"))
  neg <- str_detect(txt, paste0("(?i)(", paste(exclude_keywords, collapse="|"), ")"))
  pos & !neg
}

# はてなブックマーク数
get_hatena_count <- function(url) {
  req <- request(paste0("https://api.b.st-hatena.com/entry.count?url=", URLencode(url)))
  resp <- tryCatch(req_perform(req), error = function(e) NULL)
  if (is.null(resp)) return(NA_integer_)
  txt <- tryCatch(resp_body_string(resp), error = function(e) "0")
  as.integer(txt %||% "0")
}

# OGP画像
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

# 最初に存在する列を選ぶ
pick_first <- function(dat, candidates, default = "") {
  for (nm in candidates) if (nm %in% names(dat)) return(dat[[nm]])
  rep(default, nrow(dat))
}

# 安全な取得
fetch_one <- function(src, feed_url) {
  df <- tryCatch(tidyRSS::tidyfeed(feed_url), error = function(e) tibble())
  if (!nrow(df)) return(tibble())
  out <- tibble(
    source    = src,
    title     = pick_first(df, c("item_title","title"), ""),
    link      = pick_first(df, c("item_link","link"), ""),
    summary   = pick_first(df, c("item_description","description","item_content"), ""),
    published = pick_first(df, c("item_pub_date","pub_date"), as.character(Sys.time()))
  ) |>
    mutate(
      published = suppressWarnings(lubridate::as_datetime(published)),
      published = if_else(is.na(published), Sys.time(), published)
    ) |>
    filter(nzchar(link)) |>
    distinct(link, .keep_all = TRUE)
  out
}

# ------------------ フィード定義 ------------------
# Qiita タグRSS（/tags/r/feed.atom）
qiita_feed <- tibble(
  source = "Qiita",
  url    = "https://qiita.com/tags/r/feed.atom"
)
# Zenn R トピック
zenn_feed <- tibble(
  source = "Zenn",
  url    = "https://zenn.dev/topics/r/feed"
)
# はてなキーワードRSS（R関連キーワード）
hatena_keywords <- c("R言語","R","tidyverse","ggplot2","dplyr","Shiny")
hatena_feeds <- tibble(
  source = "HatenaKeyword",
  url    = paste0("https://b.hatena.ne.jp/q/", URLencode(hatena_keywords), "?mode=rss")
)

feeds <- dplyr::bind_rows(qiita_feed, zenn_feed, hatena_feeds)

# ------------------ 収集 ------------------
articles <- pmap_dfr(feeds, ~ fetch_one(..1, ..2))

if (!nrow(articles)) {
  message("No articles fetched. Exiting with empty JSON.")
  dir.create("app/data", recursive = TRUE, showWarnings = FALSE)
  write_json(list(items = list(), updated_at = as.character(Sys.time())), "app/data/articles.json",
             auto_unbox = TRUE, pretty = TRUE)
  quit(save = "no")
}

# 日本語/R関連フィルタ + 追加情報
articles <- articles |>
  filter(is_japanese(title) | is_japanese(summary) | is_r_related(title, summary)) |>
  mutate(
    hb_count = map_int(link, ~ { Sys.sleep(0.3); get_hatena_count(.x) }),
    thumb    = map_chr(link, ~ { Sys.sleep(0.1); get_og_image(.x) }),
    domain   = domain(link)
  ) |>
  arrange(desc(hb_count), desc(published))

articles <- articles |> slice_head(n = 500)

# JSON 出力
dir.create("app/data", recursive = TRUE, showWarnings = FALSE)
payload <- list(
  updated_at = as.character(with_tz(Sys.time(), "Asia/Tokyo")),
  items = articles |> mutate(published = as.character(with_tz(published, "Asia/Tokyo")))
)
write_json(payload, "app/data/articles.json", auto_unbox = TRUE, pretty = TRUE)

message("Done: app/data/articles.json")
