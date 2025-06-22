library(devtools)
library(shiny)
library(shinyjs)
library(DT)
library(reactable)
library(bslib)
library(plotly)
library(chorddiag)

fluidPage(
  tags$head(tags$script(src = "my.js"), tags$link(rel = "stylesheet", type = "text/css", href = "theme.css")),
  
  useShinyjs(),
  
  navset_pill(
    nav_item(img(width = "40px", src = "https://purepng.com/public/uploads/large/purepng.com-the-witcher-logowitcherthe-witcherandrzej-sapkowskiwriterfantasy-serieswitcher-geralt-of-riviawitchersbooksmonster-hunterssupernaturaldeadly-beastsseriesvideo-gamesxbox-1701528661197tz2s1.png")),
    nav_panel("Quest Overview", br(), fluidRow(
      column(
        3,
        align = "center",
        div(
          style = "background-color: #ffffff; padding: 10px; margin-top: -10px",
          h2(
            strong(textOutput("questTitle")),
            imageOutput("regionIcon", height = "22px"),
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
        )
      ),
      column(
        9,
        align = "center",
        fluidRow(column(
          4,
          div(
            style = "background-color: #ffffff; padding: 5px; height: 40vh; margin-bottom: 20px; margin-top: -10px",
            h4("Recommended Quests"),
            numericInput(
              "playerLevel",
              "Player Level",
              value = 1,
              min = 1,
              max = 50
            ),
            DTOutput("recommendedTable")
          )
        ), column(
          4,
          div(
            style = "background-color: #ffffff; padding: 5px; height: 40vh; margin-bottom: 20px; margin-top: -10px",
            h4("Player"),
            div("Completed quests: ", textOutput("completedQuests")),
            div("Failed quests: ", textOutput("failedQuests")),
            h4("Estimated level"),
            span(textOutput("estimatedLevel"), style = "font-size:30px"),
            br(),
            plotOutput("progressBar", height = "30px")
          )
        ), column(
          4,
          div(style = "background-color: #ffffff; padding: 5px; height: 40vh; margin-bottom: 20px; margin-top: -10px", h4("% of completed quests"),
              plotOutput("typeChart", height = "35vh"))
        )),
        fluidRow(column(
          12,
          div(style = "background-color: #ffffff; padding: 10px;", DTOutput("questTable"))
        ))
      )
    )),
    nav_panel(
      "Story Progression",
      fluidRow(column(
        12, align = "left", br(), column(1, div(
          style = "height:49px; margin-top: -10px;",
          actionButton(
            "filtersVisible",
            label = NULL,
            icon = icon(name = "filter", class = "fa-solid fa-filter")
          )
        )), column(11, hidden(
          div(
            id = "filters",
            style = "margin-top: -10px; background-color: #ffffff;",
            column(
              3,
              selectizeInput(
                "regionsSelected",
                label = NULL,
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
                width = "100%",
                options = list(placeholder = '(All regions)')
              )
            ),
            column(
              3,
              selectizeInput(
                "charactersSelected",
                label = NULL,
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
                  "Olgierd",
                  "Regis"
                ),
                multiple = T,
                width = "100%",
                options = list(placeholder = '(All characters)')
              )
            ),
            column(
              3,
              selectizeInput(
                "mechanicsSelected",
                label = NULL,
                choices = c("Gwent", "Fistfight", "Race", "Diagram"),
                multiple = T,
                width = "100%",
                options = list(placeholder = '(All mechanics)')
              )
            ),
            column(
              3,
              checkboxInput("highlightDone", "Highlight Done", width = "100%")
            ),
          )
        ))
        
      )),
      fluidRow(column(
        12, div(style = "margin-top:-10px; margin-bottom: 20px; background-color: #ffffff;", plotlyOutput("progressPlot", height = "35vh"))
      )),
      fluidRow(column(
        7,
        div(
          style = "background-color: #ffffff; padding: 5px; height: 50vh",
          h4("Completion rates"),
          p("Based on Steam achievements"),
          fluidRow(column(
            4, selectInput(
              "curveType",
              label = "Curve",
              choices = c("None", "All", "Main quest", "Secondary quest", "Contract quest")
            )
          ), column(
            8, br(), checkboxInput("ignoreZeros", "Ignore Zeros")
          )),
          plotlyOutput("questCompletion", height = "32vh")
        )
      ), column(
        5, align = "center",
        div(
          style = "background-color: #ffffff; padding: 5px; height: 50vh",
          h4("Changes of regions in consecutive quests"),
          chorddiagOutput("chordDiagram", height = "95%")
        )
      ))
    ),
    nav_item(actionButton("help", label=NULL, style='background-color:transparent; border-color:transparent; font-size:20px', icon = icon(name = "info", class = "fa-solid fa-circle-info")))
  )
)
