
# app/app.R
library(shiny)
library(bslib)
library(jsonlite)
library(dplyr)
library(stringr)
library(glue)

`%||%` <- function(a, b) if (!is.null(a) && !is.na(a) && nchar(a) > 0) a else b

# サイト名
SITE_TITLE_JA <- "R言語 × 日本語記事のキュレーション"
SITE_TITLE_EN <- "R Language × Japanese-language Article Curation"

ui <- page_fillable(
  theme = bs_theme(bootswatch = "flatly"),
  tags$head(
    tags$title(paste(SITE_TITLE_JA, "|", SITE_TITLE_EN)),
    includeCSS("www/styles.css"),
    tags$meta(name = "viewport", content = "width=device-width, initial-scale=1")
  ),
  layout_sidebar(
    sidebar = sidebar(
      textInput("q", "キーワード検索", placeholder = "例: ggplot2 / tidyverse / 可視化"),
      selectInput("sort", "表示順", choices = c("ブックマークが多い順" = "hb", "新着順" = "new")),
      uiOutput("domain_ui"),
      uiOutput("source_ui"),
      div(class = "muted", textOutput("updated")),
      hr(),
      div(class = "small muted",
          HTML("データは RSS + はてなブックマーク数で日次更新。<br>(<code>GitHub Actions</code> + <code>Shinylive</code>)")
      )
    ),
    card(
      card_header(
        div(class = "site-header",
            h4(SITE_TITLE_JA),
            div(class = "site-sub", SITE_TITLE_EN)
        )
      ),
      div(id = "list", uiOutput("cards"))
    )
  )
)

server <- function(input, output, session) {
  dat <- reactiveVal(NULL)

  observe({
    pth <- "data/articles.json"
    j <- tryCatch(jsonlite::read_json(pth, simplifyVector = TRUE), error = function(e) NULL)

    if (is.null(j) || is.null(j$items)) {
      dat(list(updated_at = NA_character_, items = tibble::tibble()))
      showNotification("データを読み込めませんでした（articles.json が見つからない/壊れている可能性）。", type = "error")
      return()
    }

    items <- tibble::as_tibble(j$items)
    if (nrow(items)) {
      items <- items |>
        mutate(
          published = as.POSIXct(published, tz = "Asia/Tokyo"),
          date = format(published, "%Y-%m-%d %H:%M")
        )
    }
    dat(list(updated_at = j$updated_at, items = items))
  })

  output$updated <- renderText({
    d <- dat()
    if (is.null(d) || is.null(d$updated_at) || is.na(d$updated_at)) return("")
    paste0("更新: ", d$updated_at, " JST")
  })

  output$domain_ui <- renderUI({
    d <- dat(); if (is.null(d)) return(NULL)
    items <- d$items; if (!nrow(items)) return(NULL)
    doms <- sort(unique(items$domain))
    selectizeInput("domain", "ドメイン絞り込み", choices = doms, multiple = TRUE)
  })

  output$source_ui <- renderUI({
    d <- dat(); if (is.null(d)) return(NULL)
    items <- d$items; if (!nrow(items)) return(NULL)
    srcs <- sort(unique(items$source))
    checkboxGroupInput("source", "ソース", choices = srcs, selected = srcs, inline = FALSE)
  })

  filtered <- reactive({
    d <- dat(); if (is.null(d)) return(tibble::tibble())
    items <- d$items; if (!nrow(items)) return(items)

    out <- items

    if (!is.null(input$source) && length(input$source)) {
      out <- dplyr::filter(out, source %in% input$source)
    }
    if (!is.null(input$domain) && length(input$domain)) {
      out <- dplyr::filter(out, domain %in% input$domain)
    }

    q <- stringr::str_trim(input$q %||% "")
    if (nzchar(q)) {
      qm <- stringr::str_to_lower(q)
      out <- dplyr::filter(
        out,
        stringr::str_detect(stringr::str_to_lower(title %||% ""), stringr::fixed(qm)) |
        stringr::str_detect(stringr::str_to_lower(summary %||% ""), stringr::fixed(qm)) |
        stringr::str_detect(stringr::str_to_lower(domain %||% ""), stringr::fixed(qm)) |
        stringr::str_detect(stringr::str_to_lower(hit_keywords %||% ""), stringr::fixed(qm))
      )
    }

    if (identical(input$sort, "hb")) {
      out <- dplyr::arrange(out, dplyr::desc(hb_count), dplyr::desc(published))
    } else {
      out <- dplyr::arrange(out, dplyr::desc(published), dplyr::desc(hb_count))
    }

    out
  })

  output$cards <- renderUI({
    items <- filtered()
    if (!nrow(items)) {
      return(div(class = "empty", "該当する記事がありません。"))
    }

    lapply(seq_len(nrow(items)), function(i) {
      it <- items[i, ]

      tags_vec <- character(0)
      if (!is.null(it$hit_keywords) && !is.na(it$hit_keywords) && nchar(it$hit_keywords) > 0) {
        parts <- strsplit(it$hit_keywords, ",")[[1]]
        parts <- trimws(parts)
        parts <- parts[nzchar(parts)]
        tags_vec <- parts
      }

      tags$a(
        class = "card-link",
        href = it$link, target = "_blank", rel = "noopener",
        div(class = "card-item",
          div(class = "thumb",
              tags$img(src = it$thumb %||% "", alt = "thumb")),
          div(class = "meta",
            div(class = "title", it$title),
            div(class = "sub",
              span(class = "badge", paste0("★ ", it$hb_count)),
              span(" / "),
              span(it$domain %||% it$source %||% ""),
              span(" / "),
              span(it$date)
            ),
            div(class = "desc",
                HTML(htmltools::htmlEscape(stringr::str_trunc(it$summary %||% "", width = 140)))),
            if (length(tags_vec)) {
              div(class = "tags", lapply(tags_vec, function(t) span(class = "tag", t)))
            }
          )
        )
      )
    })
  })
}

shinyApp(ui, server)
