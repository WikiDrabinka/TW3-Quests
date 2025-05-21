library(shiny)
library(shinyjs)
library(DT)
library(reactable)
library(bslib)
library(plotly)

fluidPage(
  tags$head(tags$script(src = "my.js")),
  tags$head(tags$style(HTML(
    '* {font-family: "Tahoma"};'
  ))),
  
  useShinyjs(),
  
  navset_pill(
    nav_panel("Quest Overview", fluidRow(
      column(
        3,
        align = "center",
        h3(
          strong(textOutput("questTitle")),
          imageOutput("regionIcon", height = "17px")
        ),
        reactableOutput("questSummary"),
        
        selectInput(
          "questStatus",
          "Completed Quest?",
          c("Unfinished", "Done", "Failed"),
          selected = "Unfinished"
        ),
        
        actionButton("statusReset", "Reset"),
        downloadButton("statusDownload", "Save"),
        div(style = "margin-top: -2%"),
        fileInput(
          "statusLoad",
          "",
          buttonLabel = "Load",
          placeholder = "status.csv",
          width = "50%",
          accept = ".csv"
        ),
        
        reactableOutput("questConnections"),
        hidden(
          numericInput(
            "questID",
            "Enter Quest ID",
            value = 0,
            min = 1,
            max = 415
          )
        )
      ),
      column(
        9,
        align = "center",
        DTOutput("questTable"),
        column(
          3,
          h4("Recommended Quests"),
          numericInput(
            "playerLevel",
            "Player Level",
            value = 1,
            min = 1,
            max = 50
          ),
          DTOutput("recommendedTable")
        ),
        column(5, plotOutput("typeChart"))
      )
    )),
    nav_panel("Story Progression", fluidRow(column(
      12, tags$table(
        height = "69px",
        tags$tr(
          width = "100%",
          tags$td(width = "7.5%", actionButton(
            "filtersVisible",
            label = "",
            icon = icon(name = "filter", class = "fa-solid fa-filter")
          )),
          tags$td(width = "7.5%", hidden(div("Regions", id = "regionsText"))),
          tags$td(width = "30%", hidden(
            selectInput(
              "regionsSelected",
              label = "",
              choices = c(
                "White Orchard",
                "Velen",
                "Novigrad",
                "Skellige",
                "Kaer Morhen",
                "Toussaint",
                "Vizima"
              ),
              multiple = T
            )
          )),
          tags$td(width = "12%", hidden(div("Characters", id = "charactersText"))),
          tags$td(width = "30%", hidden(
            selectInput(
              "charactersSelected",
              label = "",
              choices = c(
                "Ciri",
                "Yennefer",
                "Triss",
                "Dandelion",
                "Dijkstra",
                "Baron",
                "Keira",
                "Crach",
                "Mousesack",
                "Eredin",
                "Regis"
              ),
              multiple = T
            )
          ), tags$td(width = "10%", hidden(
            checkboxInput("highlightDone", "Highlight Done")
          )))
        )
      )
    )), fluidRow(column(
      12, plotlyOutput("progressPlot")
    )))
  )
)
