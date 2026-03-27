
library(shiny)
library(bslib)
library(jsonlite)
library(dplyr)
library(stringr)
`%||%` <- function(a,b) if(!is.null(a)&&!is.na(a)&&nchar(a)>0) a else b
ui <- page_fillable(
  theme=bs_theme(bootswatch="flatly"),
  tags$head(
    tags$title("R言語 × 日本語記事のキュレーション | R Language × Japanese-language Article Curation"),
    tags$script(HTML("document.addEventListener('DOMContentLoaded',()=>{document.title='R言語 × 日本語記事のキュレーション | R Language × Japanese-language Article Curation'});")),
    includeCSS("www/styles.css")
  ),
  layout_sidebar(
    sidebar=sidebar(
      textInput("q","検索",placeholder="例: ggplot2"),
      uiOutput("domain_ui"), uiOutput("source_ui")
    ),
    div(id="list", uiOutput("cards"))
  )
)
server <- function(input, output, session){
 dat <- reactiveVal(list(items=tibble::tibble()))
 observe({
  j <- try(read_json("data/articles.json", simplifyVector=TRUE), silent=TRUE)
  if(inherits(j,'try-error')||is.null(j$items)) return(NULL)
  items <- as_tibble(j$items)
  chr <- intersect(names(items), c('title','summary','domain','hit_keywords','thumb','link'))
  if(nrow(items)) items <- mutate(items, across(all_of(chr), ~as.character(tidyr::replace_na(. ,""))))
  dat(list(items=items))
 })
 output$domain_ui <- renderUI({x<-dat()$items;if(!nrow(x))return(NULL);selectizeInput('domain','domain',choices=sort(unique(x$domain)),multiple=TRUE)})
 output$source_ui <- renderUI({x<-dat()$items;if(!nrow(x))return(NULL);checkboxGroupInput('source','source',choices=sort(unique(x$source)),selected=sort(unique(x$source)))})
 filtered <- reactive({x<-dat()$items;if(!nrow(x))return(x)
  if(length(input$source)) x<-filter(x, source %in% input$source)
  if(length(input$domain)) x<-filter(x, domain %in% input$domain)
  q<-tolower(input$q%||%"")
  if(nchar(q)) x<-filter(x, grepl(q,tolower(title),fixed=TRUE)|grepl(q,tolower(summary),fixed=TRUE))
  x
 })
 output$cards <- renderUI({x<-filtered(); if(!nrow(x)) return(div("no data"))
  lapply(seq_len(nrow(x)), function(i){it<-x[i,]; tags$a(href=it$link,target="_blank",div(class="card-item",it$title))})
 })
}
shinyApp(ui,server)
