library(shiny)
library(bslib)
library(jsonlite)
library(dplyr)
library(stringr)
library(tidyr)

`%||%` <- function(a,b) if(!is.null(a)&&!is.na(a)&&nchar(a)>0) a else b

SITE_TITLE_JA <- "R言語 × 日本語記事のキュレーション"
SITE_TITLE_EN <- "R Language × Japanese-language Article Curation"

ui <- page_fillable(
  theme = bs_theme(bootswatch = "flatly"),
  tags$head(
    tags$title(paste(SITE_TITLE_JA, "|", SITE_TITLE_EN)),
    tags$script(HTML(sprintf(
      "document.title='%s | %s'",
      SITE_TITLE_JA, SITE_TITLE_EN
    ))),
    includeCSS("www/styles.css")
  ),
  
  # ★ 画面右上に GitHub リンク
  tags$div(
    style = "
      position: fixed; top: 12px; right: 20px; z-index: 9999;
      background: white; padding: 6px 12px; border-radius: 8px;
      border: 1px solid #ccc; font-size: 14px;
    ",
    tags$a(
      href = "https://github.com/indenkun/r-ja-curation",
      target = "_blank",
      "GitHub: r-ja-curation"
    )
  ),
  
  layout_sidebar(
    sidebar = sidebar(
      textInput("q", "検索", placeholder = "例: ggplot2"),
      selectInput("sort", "表示順", c("ブックマーク順" = "hb", "新着順" = "new")),
      uiOutput("domain_ui"),
      uiOutput("source_ui")
    ),
    div(id = "list", uiOutput("cards"))
  )
)

server <- function(input, output, session){
  
  dat <- reactiveVal(list(updated_at = NA, items = tibble()))
  
  observe({
    j <- try(read_json("data/articles.json", simplifyVector = TRUE), silent = TRUE)
    if (inherits(j, "try-error") || is.null(j$items)) return(NULL)
    
    items <- as_tibble(j$items)
    
    chr <- intersect(names(items),
                     c("title","summary","domain","hit_keywords","thumb","link"))
    if (nrow(items)) {
      items <- items |> mutate(across(all_of(chr), ~ as.character(tidyr::replace_na(.,""))))
    }
    
    dat(list(updated_at = j$updated_at %||% "", items = items))
  })
  
  output$domain_ui <- renderUI({
    x <- dat()$items
    if (!nrow(x)) return(NULL)
    selectizeInput("domain", "domain", choices = sort(unique(x$domain)), multiple = TRUE)
  })
  
  output$source_ui <- renderUI({
    x <- dat()$items
    if (!nrow(x)) return(NULL)
    checkboxGroupInput("source", "source",
                       choices = sort(unique(x$source)),
                       selected = sort(unique(x$source)))
  })
  
  # フィルター
  filtered <- reactive({
    x <- dat()$items
    if (!nrow(x)) return(x)
    
    if (length(input$source)) x <- filter(x, source %in% input$source)
    if (length(input$domain)) x <- filter(x, domain %in% input$domain)
    
    q <- tolower(input$q %||% "")
    if (nchar(q)) {
      x <- filter(x,
                  grepl(q, tolower(title), fixed = TRUE) |
                    grepl(q, tolower(summary), fixed = TRUE))
    }
    
    if (input$sort == "hb") {
      arrange(x, desc(hb_count), desc(published))
    } else {
      arrange(x, desc(published))
    }
  })
  
  # カード描画（はてな風）
  output$cards <- renderUI({
    x <- filtered()
    if (!nrow(x)) return(div("該当なし"))
    
    lapply(seq_len(nrow(x)), function(i){
      it <- x[i,]
      
      tags$a(
        href = it$link,
        target = "_blank",
        div(
          class = "card-item",
          style = "display:flex; gap:12px;",
          
          # ★ サムネイル
          tags$img(
            src = it$thumb %||% "",
            style = "width:96px;height:96px;object-fit:cover;border-radius:6px;"
          ),
          
          # ★ タイトル＋概要＋タグ
          div(
            style = "flex:1;",
            
            # タイトル
            tags$div(
              style = "font-weight:bold; font-size:16px; margin-bottom:4px;",
              it$title
            ),
            
            # ★ 概要（summary の先頭120文字）
            tags$div(
              style = "color:#444; font-size:13px; margin-bottom:6px;",
              paste0(substr(it$summary, 1, 120), "...")
            ),
            
            # ★ はてなスター（hb_count）
            tags$div(
              style = "font-size:13px; color:#e08524; margin-bottom:6px;",
              paste0("★ ", it$hb_count %||% 0)
            ),
            
            # ★ ヒットキーワード（タグ風）
            tags$div(
              style = "display:flex; flex-wrap:wrap; gap:4px;",
              lapply(strsplit(it$hit_keywords, ",")[[1]], function(k){
                if (!nzchar(k)) return(NULL)
                tags$span(
                  style = "
                    background:#eef;
                    padding:2px 6px;
                    border-radius:4px;
                    font-size:12px;
                    color:#336;
                  ",
                  k
                )
              })
            )
          )
        )
      )
    })
  })
}

shinyApp(ui, server)