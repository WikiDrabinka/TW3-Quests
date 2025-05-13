library(shiny)
library(shinyjs)
library(DT)
library(reactable)

fluidPage(
  tags$head(tags$script(src = "my.js")),
  
  useShinyjs(),
  
  titlePanel("Quest Overview"),
  
  fluidRow(
    column(
      4,
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
      ),
    ),
    column(
      8,
      align = "center",
      DTOutput("questTable"),
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
      column(4, plotOutput("typeChart"))
    )
  )
)
