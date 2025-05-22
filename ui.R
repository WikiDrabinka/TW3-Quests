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
  
  navset_pill(nav_panel(
    "Quest Overview",
    fluidRow(
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
      column(9, align = "center", fluidRow(
        column(
          4,
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
        column(
          4,
          h4("Player"),
          div("Completed quests: ", textOutput("completedQuests")),
          div("Failed quests: ", textOutput("failedQuests")),
          h4("Estimated level"),
          span(textOutput("estimatedLevel"), style = "font-size:30px"),
          br(),
          plotOutput("progressBar", height = "30px")
          ),
          column(4, h4("% of completed quests"), plotOutput("typeChart"))
        ),
        fluidRow(column(12, DTOutput("questTable")))
      ))
    ),
    nav_panel("Story Progression", fluidRow(column(
      12, tags$table(
        height = "69px",
        width = "80%",
        tags$tr(
          align = "center",
          tags$td(width = "3%", actionButton(
            "filtersVisible",
            label = "",
            icon = icon(name = "filter", class = "fa-solid fa-filter")
          )),
          tags$td(width = "4.5%", hidden(div("Regions", id = "regionsText"))),
          tags$td(width = "23%", hidden(
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
              multiple = T,
              width = "100%"
            )
          )),
          tags$td(width = "6%", hidden(div("Characters", id = "charactersText"))),
          tags$td(
            width = "23%",
            hidden(
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
                multiple = T,
                width = "100%"
              )
            ),
            tags$td(width = "5.5%", hidden(div("Mechanics", id = "mechanicsText"))),
            tags$td(width = "23%", hidden(
              selectInput(
                "mechanicsSelected",
                label = "",
                choices = c("Gwent", "Fistfight", "Race", "Diagram"),
                multiple = T,
                width = "100%"
              )
            )),
            tags$td(width = "12%", hidden(
              checkboxInput("highlightDone", "Highlight Done", width = "100%")
            ))
          )
        )
      )
    )), fluidRow(column(
      12, plotlyOutput("progressPlot")
    )))
  ))
  