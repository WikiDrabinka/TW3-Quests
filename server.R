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
library(reticulate)
library(here)
library(plotly)
library(shinycssloaders)
library(devtools)
library(chorddiag)
py_require(c("pandas", "plotly"))

function(input, output, session) {
  values <- reactiveValues()
  hideElement("questID")
  showPageSpinner(color = "black", type = 1)
  
  source_python("www/graph.py")
  
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
  
  values$nodes <- main_graph(here())
  
  values$connections <- data.frame(read.csv("www/connections.csv"))
  
  select_quest_on_click <- JS("select_quest_on_click(table)")
  
  region_unlocks = list(
    Kaer.Morhen = 34,
    White.Orchard = 1,
    Velen = 5,
    Vizima = 4,
    Skellige = 27,
    Novigrad = 17,
    Toussaint = 332
  )
  
  hidePageSpinner()
  
  summarise_quest <- function(ID) {
    quests_table <- (
      values$quests[ID + 1, ] %>%
        gather("Region", "Appeared", White.Orchard:Toussaint) %>% filter(Appeared == 1) %>% select(-(Ciri:Diagram)) %>%
        group_by(ID) %>% mutate(Regions = paste(Region, collapse = ", ")) %>%
        ungroup() %>% select(-(Region:Appeared), -Status, -Completion.Rate)
    ) [1, ]
    
    quests_table$Regions <- gsub("[.]", " ", quests_table$Regions)
    
    quests_table <- cbind(names(quests_table), t(quests_table[1, ]))
    
    quests_table[, 1] <- gsub("[.]", " ", quests_table[, 1])
    
    
    return (quests_table)
  }
  
  requirements_met <- function(IDs) {
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
      regions_unlocked = T
      if (ID != 0) {
        for (region in colnames(values$quests %>% select(White.Orchard:Toussaint))) {
          if (values$quests[ID + 1, region] == 1) {
            requirement = region_unlocks[[region]]
            if (ID != requirement &&
                values$quests$Status[requirement + 1] != "Done") {
              regions_unlocked = F
              break
            }
          }
        }
      }
      reqs[idx] = reqs[idx] && regions_unlocked
    }
    return (reqs)
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
    regions = values$quests[ID + 1, ] %>% select(White.Orchard:Toussaint)
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
    characters <- regions %>%
      gather("Character", "Appeared", Ciri:Regis) %>% filter(Appeared >= 1) %>%
      rbind(regions %>% select(-(Ciri:Regis)) %>% mutate(Character =
                                                           "", Appeared = 0)) %>%
      group_by(ID) %>% mutate(Characters = gsub(", $", "", paste(Character, collapse = ", "))) %>%
      ungroup() %>% select(-(Character:Appeared)) %>% distinct()
    
    quests_table <- characters %>%
      gather("Mechanic", "Appeared", Gwent:Diagram) %>% filter(Appeared == "True") %>%
      rbind(characters %>% select(-(Gwent:Diagram)) %>% mutate(Mechanic =
                                                                 "", Appeared = "False")) %>%
      group_by(ID) %>% mutate(Mechanics = gsub(", $", "", paste(Mechanic, collapse = ", "))) %>%
      ungroup() %>% select(-(Mechanic:Appeared), -Completion.Rate) %>% distinct()
    datatable(
      quests_table,
      rownames = F,
      colnames = c("Suggested Level" = "Suggested.Level"),
      callback = select_quest_on_click,
      selection = 'single',
      options = list(
        lengthMenu = list(c(5, 10, 15), c('5', '10', '15')),
        order = list(list(0, 'asc')),
        pageLength = 10
      )
    ) %>% formatStyle('Status', target = 'row', color = styleEqual(c("Done", "Failed"), c("#308810", "#883010")))
  })
  
  output$recommendedTable <- renderDT({
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
        Suggested.Level == 0 | Suggested.Level > input$playerLevel - 10,
        Suggested.Level < input$playerLevel +
          6,
        Status == "Unfinished",
        requirements_met(ID)
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
  
  output$completedQuests <- renderText({
    nrow(values$quests %>% filter(Status == "Done"))
  })
  
  output$failedQuests <- renderText({
    nrow(values$quests %>% filter(Status == "Failed"))
  })
  
  output$estimatedLevel <- renderText({
    exp = sum(values$quests %>% filter(Status == "Done") %>% select(Exp))
    if (exp < 10500) {
      min(10, exp %/% 1000 + 1)
    } else if (exp < 26000) {
      min(20, (exp - 9000) %/% 1500 + 10)
    } else {
      (exp - 24000) %/% 2000 + 20
    }
  })
  
  output$progressBar <- renderPlot(height = 30, {
    total_exp = sum(values$quests %>% filter(Status == "Done") %>% select(Exp))
    if (total_exp < 9000) {
      exp = total_exp %% 1000
      max_exp = 1000
    } else if (total_exp < 24000) {
      exp = (total_exp - 9000) %% 1500
      max_exp = 1500
    } else {
      exp = (total_exp - 24000) %% 2000
      max_exp = 2000
    }
    
    val = data.frame(list(
      exp = c(exp, max_exp - exp),
      type = c("Gained", "Remaining"),
      idx = c(1, 1)
    )) %>% mutate(type = factor(type, c("Remaining", "Gained")))
    val %>% ggplot(aes(x = idx, fill = type, y = exp)) + geom_bar(stat =
                                                                    "identity", position = "fill") + coord_flip() + theme_void() +
      scale_fill_manual(
        breaks = c("Gained", "Remaining"),
        values = c("#888888", "#DDDDDD")
      ) + theme(legend.position = "none") +
      labs(caption = paste(exp, "/", max_exp)) + theme(plot.caption = element_text(family = "Trebushet MS", hjust = .95))
  })
  
  output$typeChart <- renderPlot({
    values$quests %>% group_by(Type, Status) %>% summarise(Count = n_distinct(ID), .groups = "keep") %>%
      ggplot(aes(x = Type, y = Count, fill = Status)) + geom_bar(stat =
                                                                   "identity", position = position_fill(reverse = TRUE)) +
      theme_minimal() + labs(x = "", y = "") +
      scale_fill_manual(
        breaks = c("Done", "Failed", "Unfinished"),
        values = c("#90E8A0", "#E890A0", "#00000000")
      ) + coord_polar(theta = "x",
                      direction = 1,
                      clip = "off") + theme(legend.position = "bottom")
  })
  
  output$progressPlot <- renderPlotly({
    nodes <- values$nodes %>% left_join(values$quests, by = join_by(ID))
    
    if (is.null(input$regionsSelected)) {
      regions <- nodes
    } else {
      regions <- nodes %>% filter(ID == -1)
      for (region in input$regionsSelected) {
        regions <- rbind(regions, nodes[nodes[gsub(" ", ".", region)] == 1, ])
      }
    }
    if (is.null(input$charactersSelected)) {
      characters <- regions
    } else {
      characters <- regions %>% filter(ID == -1)
      for (character in input$charactersSelected) {
        characters <- rbind(characters, regions[regions[character] > 0, ])
      }
    }
    if (is.null(input$mechanicsSelected)) {
      data <- characters
    } else {
      data <- characters %>% filter(ID == -1)
      for (mechanic in input$mechanicsSelected) {
        data <- rbind(data, characters[characters[mechanic] == "True", ])
      }
    }
    data <- data %>% distinct()
    
    arrows <- values$connections %>% rename("ID" = "Successor") %>% left_join(data, by =
                                                                                join_by(ID)) %>%
      rename("Successor" = "ID",
             "xend" = "x",
             "yend" = "y") %>% rename("ID" = "Predecessor") %>% left_join(data, by =
                                                                            join_by(ID)) %>%
      rename("Predecessor" = "ID") %>% na.omit()
    (
      ggplot() + geom_point(
        data = complete(data, Type),
        aes(
          x = x,
          y = y,
          color = Type,
          text = Name,
          alpha = Status
        ),
        size = 2.5,
        show.legend = T
      ) + scale_alpha_manual(
        values = `if`(input$highlightDone, c(1, 0.5, 0.5), c(1, 1, 1)),
        breaks = c("Done", "Unfinished", "Failed"),
      ) + guides(alpha = F) +
        theme_void() +
        scale_color_paletteer_d("PNWColors::Sailboat") +
        coord_cartesian(xlim = c(0, 30), ylim = c(-15, 15))
    ) %>%
      ggplotly(tooltip = c("Name")) %>% add_annotations(
        data = arrows,
        x = ~ xend,
        y = ~ yend,
        xref = "x",
        yref = "y",
        axref = "x",
        ayref = "y",
        text = "",
        showarrow = T,
        arrowhead = 2,
        arrowwidth = 1.25,
        ax = ~ x,
        ay = ~ y,
        opacity = .5
      ) %>% layout(
        xaxis = list(showgrid = F, showline = F),
        yaxis = list(showgrid = F, showline = F),
        plot_bgcolor  = "rgba(0, 0, 0, 0)",
        paper_bgcolor = "rgba(0, 0, 0, 0)",
        legend = list(orientation = "h", y = 1)
      )
  })
  
  output$questCompletion <- renderPlotly({
    plot <- values$quests %>% filter(Completion.Rate > 0) %>% ggplot(aes(x =
                                                                           Suggested.Level, y = Completion.Rate, color = Type)) + theme_minimal() +
      geom_point() + coord_cartesian(xlim = c(0, 37), ylim = c(0, 0.7)) +
      scale_color_paletteer_d("PNWColors::Sailboat") + labs(x = "Suggested Level", y = "Completion Rate") +
      geom_smooth(
        data = values$quests %>%
          filter(
            Completion.Rate > 0,
            Type == input$curveType,
            (
              !input$ignoreZeros |
                input$curveType == "Main quest" |
                Suggested.Level > 0
            )
          ),
        aes(x = Suggested.Level),
        alpha = .25,
        method = 'loess'
      )
    
    if (input$curveType == "All") {
      plot <- plot + geom_smooth(
        data = values$quests %>% filter(
          Completion.Rate > 0,
          (
            !input$ignoreZeros | Type == "Main quest" | Suggested.Level > 0
          )
        ),
        aes(x = Suggested.Level, y = Completion.Rate),
        alpha = .25,
        inherit.aes = F,
        method = 'loess'
      )
    }
    
    plot %>% ggplotly() %>% layout(showlegend = FALSE) %>% config(displayModeBar = FALSE)
  })
  
  output$chordDiagram <- renderChorddiag({
    quest_regions <- values$quests %>% gather("Region", "Appeared", White.Orchard:Toussaint) %>% filter(Appeared == 1) %>% select(ID, Region)
    data <- values$connections %>% rename("ID" = "Predecessor") %>%
      left_join(quest_regions, by = join_by(ID)) %>% rename("Predecessor" = "ID",
                                                            "PRegion" = "Region",
                                                            "ID" = "Successor") %>%
      left_join(quest_regions, by = join_by(ID)) %>% select(PRegion, Region) %>% group_by(PRegion, Region) %>% summarise(Count = n()) %>% ungroup() %>%
      spread(Region, Count)
    data[is.na(data)] <- 0
    data_matrix <- data.matrix(data %>% select(-PRegion))
    dimnames(data_matrix) <- list(PRegion = data$PRegion,
                                  Region = colnames(data %>% select(-PRegion)))
    chorddiag(
      data_matrix,
      groupNames = c(
        "Kaer Morhen",
        "Novigrad",
        "Skellige",
        "Toussaint",
        "Velen",
        "Vizima",
        "White Orchard"
      ),
      showTicks = F,
      groupnamePadding = 5,
      groupnameFontsize = 15
    )
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
  
  observeEvent(input$filtersVisible, {
    toggle("filters")
  })
  
  observeEvent(input$help, {
    showModal(
      modalDialog(
        h3("Help"),
        p(
          "This dashboard allows users to track their progress in The Witcher 3. Simply select a quest by clicking on its row in the table and start tracking!"
        ),
        p(
          "When done, progress can be saved to a csv file that you can easily load next time."
        ),
        p(
          "Alternatively, you may use buttons below to load one of the prepared presets."
        ),
        actionButton("presetPlot", "Plot only"),
        actionButton("presetAll", "All done"),
        actionButton("presetRandom", "Random"),
        br(),
        br(),
        p(
          "The Story Progression tab provides a handy graph showing dependencies between quests, filterable by multiple criteria and with the ability to highlight quests marked as done."
        )
      )
    )
  })
  
  observeEvent(input$presetPlot, {
    preset = read.csv("www/presetlot.csv")
    values$quests <- values$quests %>% select(-Status) %>% left_join(preset %>% select(ID, Status), by =
                                                                       join_by(ID))
    values$quests[is.na(values$quests)] <- "Unfinished"
  })
  
  observeEvent(input$presetAll, {
    values$quests$Status = "Done"
  })
  
  observeEvent(input$presetRandom, {
    values$quests$Status = "Unfinished"
    values$quests[values$quests$ID <= 5, "Status"] = "Done"
    values$quests[values$quests$ID == 17, "Status"] = "Done"
    values$quests[values$quests$ID == 27, "Status"] = "Done"
    for (i in 1:400) {
      ID = sample(6:414, 1)
      if (requirements_met(c(ID))[1]) {
        values$quests[values$quests$ID == ID, "Status"] = "Done"
      }
    }
    for (j in 1:50) {
      ID = sample(6:414, 1)
      if (values$quests[values$quests$ID == ID, "Status"] == "Unfinished" &
          values$quests[values$quests$ID == ID, "Type"] != "Main quest") {
        values$quests[values$quests$ID == ID, "Status"] = "Failed"
      }
    }
  })
  
}
