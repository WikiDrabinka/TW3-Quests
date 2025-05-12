#
# This is the user-interface definition of a Shiny web application. You can
# run the application by clicking 'Run App' above.
#
# Find out more about building applications with Shiny here:
#
#    https://shiny.posit.co/
#

library(shiny)
library(shinyjs)
library(DT)
library(reactable)

# Define UI for application that draws a histogram
fluidPage(
    useShinyjs(),
  
    titlePanel("Quest Overview"),

    # Sidebar with a slider input for number of bins
    fluidRow(
      column(4, align="center",
             h3(strong(textOutput("questTitle")),imageOutput("regionIcon",height="17px")),
             reactableOutput("questSummary"),
             
             selectInput("questStatus","Completed Quest?",c("Unfinished","Done","Failed"),selected="Unfinished"),
             
             actionButton("statusReset","Reset"),
             downloadButton("statusDownload","Save"),
             div(style = "margin-top: -2%"),
             fileInput("statusLoad","",buttonLabel = "Load", placeholder = "status.csv", width="50%", accept = ".csv"),
             
             reactableOutput("questConnections"),
             hidden(numericInput("questID","Enter Quest ID",value=0,min=1,max=415)),
             ),
      column(8,align="center",
             h4("Quests"),
             DTOutput("questTable"),
             column(6,
                    h4("Recommended Quests"),
                    numericInput("playerLevel","Player Level",value=1,min=1,max=50),
                    DTOutput("recommendedTable")
                    )
             )
    )

)
