
# R/fetch_articles.R（pmapの引数ずれ修正版：feeds列順を source,url,query に統一）
# ---------------------------------------------------------------------------------
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
library(xml2)

`%||%` <- function(a, b) { if (length(a) == 0) return(b); ifelse(is.na(a) | a == "", b, a) }

# ----------------- 共通ユーティリティ -----------------
is_japanese <- function(x) { x <- ifelse(is.na(x), "", x); str_detect(x, "[\\p{Hiragana}\\p{Katakana}\\p{Han}]") }

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

get_hatena_count <- function(url) {
  req <- request(paste0("https://api.b.st-hatena.com/entry.count?url=", URLencode(url)))
  resp <- tryCatch(req_perform(req), error = function(e) NULL)
  if (is.null(resp)) return(NA_integer_)
  txt <- tryCatch(resp_body_string(resp), error = function(e) "0")
  as.integer(txt %||% "0")
}

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

pick_first <- function(dat, candidates, default = "") {
  for (nm in candidates) if (nm %in% names(dat)) return(dat[[nm]])
  rep(default, ifelse(is.null(nrow(dat)), length(dat[[1]]), nrow(dat)))
}

parse_atom_with_xml2 <- function(feed_url, src, q) {
  if (!grepl("^https?://", feed_url)) return(tibble())  # 相対パス等を即時除外
  doc <- tryCatch(xml2::read_xml(feed_url), error = function(e) NULL)
  if (is.null(doc)) return(tibble())
  ns <- c(d1 = "http://www.w3.org/2005/Atom")
  entries <- xml2::xml_find_all(doc, ".//d1:entry|.//entry", ns = ns)
  if (!length(entries)) return(tibble())

  purrr::map_dfr(entries, function(n) {
    ttl <- xml2::xml_text(xml2::xml_find_first(n, ".//d1:title|.//title", ns = ns))
    lnk <- xml2::xml_attr(xml2::xml_find_first(n, ".//d1:link[@rel='alternate']", ns = ns), "href")
    if (is.na(lnk) || !nzchar(lnk)) lnk <- xml2::xml_text(xml2::xml_find_first(n, ".//d1:url|.//url", ns = ns))
    if (is.na(lnk) || !nzchar(lnk)) lnk <- xml2::xml_attr(xml2::xml_find_first(n, ".//d1:link|.//link", ns = ns), "href")
    cnt <- xml2::xml_text(xml2::xml_find_first(n, ".//d1:content|.//content", ns = ns))
    if (is.na(cnt) || !nzchar(cnt)) cnt <- xml2::xml_text(xml2::xml_find_first(n, ".//d1:summary|.//summary", ns = ns))
    pub <- xml2::xml_text(xml2::xml_find_first(n, ".//d1:published|.//published|.//d1:updated|.//updated", ns = ns))

    tibble(
      source = src,
      title = ttl %||% "",
      link = lnk %||% "",
      summary = cnt %||% "",
      published = pub %||% as.character(Sys.time()),
      hit_keywords = q
    )
  }) |>
    mutate(
      published = suppressWarnings(lubridate::as_datetime(published)),
      published = if_else(is.na(published), Sys.time(), published)
    ) |>
    filter(nzchar(link)) |>
    distinct(link, .keep_all = TRUE)
}

fetch_one <- function(src, feed_url, q) {
  # フィードURLの妥当性チェック
  if (!grepl("^https?://", feed_url)) {
    return(tibble())
  }
  df <- tryCatch(tidyRSS::tidyfeed(feed_url), error = function(e) tibble())
  out <- tibble()
  if (nrow(df)) {
    out <- tibble(
      source    = src,
      title     = pick_first(df, c("item_title","title","entry_title"), ""),
      link      = pick_first(df, c("item_link","link","entry_link"), ""),
      summary   = pick_first(df, c("item_description","description","item_content","entry_content"), ""),
      published = pick_first(df, c("item_pub_date","pub_date","entry_published","entry_updated"), as.character(Sys.time())),
      hit_keywords = q
    ) |>
      mutate(
        published = suppressWarnings(lubridate::as_datetime(published)),
        published = if_else(is.na(published), Sys.time(), published)
      ) |>
      filter(nzchar(link)) |>
      distinct(link, .keep_all = TRUE)
  }
  if (!nrow(out) || all(!nzchar(out$link))) {
    out <- parse_atom_with_xml2(feed_url, src, q)
  }
  out
}

# ------------------ フィード定義（例） ------------------
qiita_feeds <- tibble(
  source = "Qiita",
  query  = "r",
  url    = c("https://qiita.com/tags/r/feed.atom", "https://qiita.com/tags/r/feed")
)

zenn_feeds <- tibble(source = "Zenn", query = "r", url = "https://zenn.dev/topics/r/feed")

hatena_keywords <- c("R言語","tidyverse","ggplot2","dplyr","Shiny")

hatena_q <- tibble(
  source = "HatenaKeyword",
  query  = hatena_keywords,
  url    = paste0(
    "https://b.hatena.ne.jp/q/",
    URLencode(hatena_keywords),
    "?mode=rss&target=all&sort=recent&users=1&date_range=y&safe=on"
  )
)

jst_today  <- with_tz(Sys.time(), "Asia/Tokyo")
start_date <- format(as.Date(jst_today) - 365, "%Y-%m-%d")
end_date   <- format(as.Date(jst_today),       "%Y-%m-%d")

hatena_search <- tibble(
  source = "HatenaKeyword",
  query  = hatena_keywords,
  url    = paste0(
    "https://b.hatena.ne.jp/search/text?q=",
    URLencode(hatena_keywords),
    "&mode=rss&date_begin=", start_date,
    "&date_end=", end_date,
    "&threshold=1&sort=recent"
  )
)

try_q <- tryCatch(tidyRSS::tidyfeed(hatena_q$url[[1]]), error = function(e) tibble())
hatena_feeds <- if (nrow(try_q)) hatena_q else hatena_search

bing_queries <- c("R 言語","R tidyverse","ggplot2","R Shiny")
bing_feeds <- tibble(
  source = "BingNews",
  query  = bing_queries,
  url    = paste0("https://www.bing.com/news/search?q=", URLencode(bing_queries), "&format=rss")
)

feeds <- dplyr::bind_rows(qiita_feeds, zenn_feeds, hatena_feeds, bing_feeds)

# ★ 列順を source, url, query に固定（pmap の引数順を保証）
feeds <- feeds |>
  dplyr::select(source, url, query)

# ------------------ 収集 ------------------
articles <- pmap_dfr(feeds, ~ fetch_one(..1, ..2, ..3))

if (!nrow(articles)) {
  message("No articles fetched. Exiting with empty JSON.")
  dir.create("app/data", recursive = TRUE, showWarnings = FALSE)
  write_json(list(items = list(), updated_at = as.character(Sys.time())), "app/data/articles.json",
             auto_unbox = TRUE, pretty = TRUE)
  quit(save = "no")
}

articles <- articles |>
  mutate(published = suppressWarnings(lubridate::as_datetime(published))) |>
  mutate(published = if_else(is.na(published), Sys.time(), published)) |>
  filter(published >= (Sys.time() - lubridate::days(365))) |>
  filter(is_japanese(title) | is_japanese(summary) | is_r_related(title, summary)) |>
  mutate(
    hb_count = map_int(link, ~ { Sys.sleep(0.2); get_hatena_count(.x) }),
    thumb    = map_chr(link, ~ { Sys.sleep(0.1); get_og_image(.x) }),
    domain   = domain(link)
  ) |>
  arrange(desc(published)) |>
  group_by(link) |>
  summarise(
    title   = dplyr::first(title),
    summary = dplyr::first(summary),
    published = dplyr::first(published),
    source  = dplyr::first(source),
    domain  = dplyr::first(domain),
    hb_count = suppressWarnings(max(hb_count, na.rm = TRUE)),
    thumb   = dplyr::first(thumb),
    hit_keywords = paste(unique(na.omit(hit_keywords)), collapse = ", "),
    .groups = "drop"
  ) |>
  arrange(desc(hb_count), desc(published)) |>
  slice_head(n = 500)

# JSON 出力
dir.create("app/data", recursive = TRUE, showWarnings = FALSE)
payload <- list(
  updated_at = as.character(with_tz(Sys.time(), "Asia/Tokyo")),
  items = articles |> mutate(published = as.character(with_tz(published, "Asia/Tokyo")))
)
write_json(payload, "app/data/articles.json", auto_unbox = TRUE, pretty = TRUE)

message("Done: app/data/articles.json")
