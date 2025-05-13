library(shiny)
library(shinyjs)
library(ggplot2)
library(tidyr)
library(dplyr)
library(DT)
library(reactable)
library(shinydashboard)
library(tools)
library(paletteer)

function(input, output, session) {
  values <- reactiveValues()
  hideElement("questID")
  
  values$quests <- data.frame(read.csv("www/quests.csv")) %>% mutate(
    Status = "Unfinished",
    Type = factor(
      Type,
      levels = c(
        "Main quest",
        "Secondary quest",
        "Contract quest",
        "Treasure hunt",
        "Unmarked quest"
      )
    ),
    Status = factor(Status, levels = c("Unfinished", "Done", "Failed"))
  )
  
  values$connections <- data.frame(read.csv("www/connections.csv"))
  
  select_quest_on_click <- JS("select_quest_on_click(table)")
  
  summarise_quest <- function(ID) {
    quests_table <- (
      values$quests[ID + 1, ] %>%
        gather("Region", "Appeared", White.Orchard:Toussaint) %>% filter(Appeared == 1) %>% select(-(Ciri:Eredin)) %>%
        group_by(ID) %>% mutate(Regions = paste(Region, collapse = ", ")) %>%
        ungroup() %>% select(-(Region:Appeared), -Status)
    ) [1, ]
    
    quests_table$Regions <- gsub("[.]", " ", quests_table$Regions)
    
    quests_table <- cbind(names(quests_table), t(quests_table[1, ]))
    
    quests_table[, 1] <- gsub("[.]", " ", quests_table[, 1])
    
    
    return (quests_table)
  }
  
  
  output$questSummary <- renderReactable({
    reactable(
      summarise_quest(input$questID),
      rownames = F,
      striped = T,
      sortable = F,
      columns = list("V1" = colDef(name = ""), "V2" = colDef(name =
                                                               ""))
    )
  })
  
  output$questConnections <- renderReactable({
    ID = input$questID
    
    quests_table <- values$quests[ID + 1, ] %>% select(ID)
    previous_quests <- values$connections %>% filter(Successor == ID) %>% rename("ID" =
                                                                                   "Successor")
    
    quests_table <- (
      quests_table %>% left_join(previous_quests, by = join_by(ID)) %>% group_by(ID) %>%
        mutate(Previous = paste(Predecessor, collapse = ", "))
    )[1, ]
    
    next_quests <- values$connections %>% filter(Predecessor == ID) %>% rename("ID" =
                                                                                 "Predecessor")
    
    quests_table <- quests_table %>% left_join(next_quests, by = join_by(ID)) %>% group_by(ID) %>%
      mutate(Next = paste(Successor, collapse = ", ")) %>% ungroup() %>% select(-Predecessor, -Successor, -ID)
    
    split = strsplit(quests_table[1, ]$Next, split = ", ")
    
    for (i in 1:length(split[[1]])) {
      quests_table[paste("Next", i, sep = "")] = split[[1]][i]
    }
    split = strsplit(quests_table[1, ]$Previous, split = ", ")
    for (i in 1:length(split[[1]])) {
      quests_table[paste("Previous", i, sep = "")] = split[[1]][i]
    }
    
    quests_table <- quests_table %>% select(-Previous, -Next)
    
    quests_table <- data.frame(cbind(names(quests_table), t(quests_table[1, ])))
    
    quests_table[, 1] <- gsub("Next.+", "Next", quests_table[, 1])
    quests_table[, 1] <- gsub("Previous.+", "Previous", quests_table[, 1])
    
    quests_table <- quests_table %>% filter(X2 != "NA") %>% rename("ID" =
                                                                     "X2") %>% rename("col" = "X1") %>%
      mutate (ID = as.integer(ID)) %>% left_join(values$quests[1:3], by =
                                                   join_by(ID))
    
    if (nrow(quests_table) > 0) {
      reactable(
        quests_table %>% select(col, Name, ID),
        rownames = F,
        striped = T,
        sortable = F,
        columns = list(
          "col" = colDef(name = ""),
          "Name" = colDef(name = ""),
          "ID" = colDef(show = F)
        ),
        groupBy = "col",
        onClick = JS("select_next")
      )
      
    }
  })
  
  output$questTitle <- renderText(values$quests[input$questID + 1, ]$Name)
  
  output$regionIcon <- renderImage(deleteFile = F, {
    ID = input$questID
    path = "./www/"
    regions = values$quests[ID + 1, 16:22]
    if (sum(regions) > 1) {
      path = paste(path, "Multiple.png", sep = "")
    } else {
      path = paste(path, gsub("[.]", " ", colnames(regions)[regions == 1]), ".png", sep =
                     "")
    }
    list(
      src = path,
      width = "auto",
      height = "auto",
      alt = "Region"
    )
  })
  
  output$questTable <- renderDT({
    regions <- values$quests %>%
      gather("Region", "Appeared", White.Orchard:Toussaint) %>% filter(Appeared == 1) %>%
      group_by(ID) %>% mutate(Regions = gsub("[.]", " ", paste(Region, collapse = ", "))) %>%
      ungroup() %>% select(-(Region:Appeared)) %>% distinct()
    quests_table <- regions %>%
      gather("Character", "Appeared", Ciri:Eredin) %>% filter(Appeared >= 1) %>%
      rbind(regions %>% select(-(Ciri:Eredin)) %>% mutate(Character =
                                                            "", Appeared = 0)) %>%
      group_by(ID) %>% mutate(Characters = gsub(", $", "", paste(Character, collapse = ", "))) %>%
      ungroup() %>% select(-(Character:Appeared)) %>% distinct()
    datatable(
      quests_table,
      rownames = F,
      colnames = c("Suggested Level" = "Suggested.Level"),
      callback = select_quest_on_click,
      selection = 'single',
      options = list(
        lengthMenu = list(c(3, 5, 10), c('3', '5', '10')),
        order = list(list(0, 'asc')),
        pageLength = 5
      )
    ) %>% formatStyle('Status', target = 'row', color = styleEqual(c("Done", "Failed"), c("#308810", "#883010")))
  })
  
  output$recommendedTable <- renderDT({
    requirementsMet <- function(IDs) {
      reqs = c()
      for (idx in 1:length(IDs)) {
        ID = IDs[idx]
        previous = values$connections %>% filter(Successor == ID)
        if (nrow(previous) == 0) {
          reqs[idx] = TRUE
        } else {
          previous = previous %>% rename("ID" = "Predecessor") %>% left_join(values$quests, by =
                                                                               join_by(ID))
          reqs[idx] = all(previous$Status == "Done")
        }
      }
      return (reqs)
    }
    
    datatable(
      rownames = F,
      colnames = c("", ""),
      selection = 'single',
      options = list(
        pageLength = 5,
        dom = 't',
        ordering = F
      ),
      values$quests %>% filter(
        Suggested.Level > input$playerLevel - 10,
        Suggested.Level < input$playerLevel +
          6,
        Status == "Unfinished",
        requirementsMet(ID)
      ) %>% arrange(Type, desc(Exp), Suggested.Level) %>% select(ID, Name),
      callback = select_quest_on_click
    ) %>%
      formatStyle(columns = c(T, F), fontSize = '0%')
  })
  
  output$questsCompleted <- renderPlot({
    values$quests %>% filter(Status == "Done") %>% group_by(Type) %>% summarise(Count =
                                                                                  n_distinct(ID)) %>%
      ggplot(aes(x = Type, y = Count)) + geom_bar(stat = "identity")
  })
  
  output$statusDownload <- downloadHandler(
    filename = "status.csv",
    content = function(file) {
      write.csv(values$quests %>% filter(Status != "Unfinished") %>% select(ID, Status),
                file)
    }
  )
  
  output$typeChart <- renderPlot({
    values$quests %>% group_by(Type, Status) %>% summarise(Count = n_distinct(ID)) %>%
      ggplot(aes(x = Type, y = Count, fill = Status)) + geom_bar(stat =
                                                                   "identity", position = position_fill(reverse = TRUE)) +
      theme_minimal() + labs(x = "", y = "") +
      scale_fill_manual(
        breaks = c("Done", "Failed", "Unfinished"),
        values = c("#90E8A0", "#E890A0", "#00000000")
      ) + coord_polar(theta = "x",
                      direction = 1,
                      clip = "off")
  })
  
  observeEvent(input$statusLoad, {
    updates = read.csv(input$statusLoad$datapath)
    if ("ID" %in% colnames(updates) &&
        "Status" %in% colnames(updates)) {
      values$quests <- values$quests %>% select(-Status) %>% left_join(updates %>% select(ID, Status), by =
                                                                         join_by(ID))
      values$quests[is.na(values$quests)] <- "Unfinished"
    }
  })
  
  observeEvent(input$statusReset, {
    values$quests$Status = "Unfinished"
  })
  
  observeEvent(input$questStatus, {
    values$quests$Status[values$quests$ID == input$questID] = input$questStatus
  })
  
  observeEvent(input$questID, {
    updateSelectInput(session, "questStatus", selected = values$quests$Status[values$quests$ID == input$questID])
  })
  
  
}
