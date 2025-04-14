library(mongolite)
library(shiny)
library(ggplot2)
library(dplyr)
library(scales)

# --- MongoDB Connections ---

# Sentiment data
sentiment_conn <- mongo(
  collection = "Stock_Sentiment_Refined",
  db = "NVIDIA",
  url = "mongodb+srv://SamFTW0128:abc@tutorial3.9rilbcs.mongodb.net/?retryWrites=true&w=majority&appName=TUTORIAL3"
)
sentiment_data <- sentiment_conn$find()

# Market (Yahoo Finance) data
market_conn <- mongo(
  collection = "nvda_trend",
  db = "stock_data",
  url = "mongodb+srv://SamFTW0128:abc@tutorial3.9rilbcs.mongodb.net/?retryWrites=true&w=majority&appName=TUTORIAL3"
)
market_data <- market_conn$find()

# --- Data Processing ---

# Convert to Date/Time
sentiment_data$date <- as.Date(sentiment_data$date)
market_data$date <- as.POSIXct(market_data$Date)
market_data$date_only <- as.Date(market_data$date)

# Aggregate daily sentiment and add direction arrows
daily_sentiment <- sentiment_data %>%
  filter(sentiment_label %in% c("Positive", "Negative")) %>%
  group_by(date, sentiment_label) %>%
  summarise(count = n(), .groups = "drop") %>%
  group_by(date) %>%
  mutate(percentage = count / sum(count) * 100) %>%
  arrange(desc(percentage), sentiment_label) %>%
  slice(1) %>%
  mutate(
    arrow = case_when(
      sentiment_label == "Positive" ~ "🔼",
      sentiment_label == "Negative" ~ "🔽",
      TRUE ~ ""
    )
  )


# Merge daily sentiment to market data
merged_data <- left_join(market_data, daily_sentiment, by = c("date_only" = "date"))

# Pick one row per day for arrow placement (first timestamp of each day)
arrow_data <- merged_data %>%
  group_by(date_only) %>%
  slice(1) %>%
  ungroup() %>%
  filter(!is.na(arrow) & arrow != "")

# --- UI ---

ui <- fluidPage(
  titlePanel("Stock Sentiment & Market Dashboard"),
  
  sidebarLayout(
    sidebarPanel(
      dateRangeInput("date_range", "Select Date Range:",
                     start = min(sentiment_data$date),
                     end = max(sentiment_data$date)),
      selectInput("label_filter", "Sentiment Type:",
                  choices = unique(sentiment_data$sentiment_label),
                  selected = unique(sentiment_data$sentiment_label),
                  multiple = TRUE)
    ),
    
    mainPanel(
      tabsetPanel(
        tabPanel("Price vs Sentiment", 
                 plotOutput("price_sentiment_plot")),
        tabPanel("Sentiment Ratio", 
                 plotOutput("sentiment_ratio_plot"))
        
      )
    )
  )
)

# --- SERVER ---

server <- function(input, output, session) {
  
  # Filter sentiment data
  filtered_sentiment <- reactive({
    sentiment_data %>%
      filter(
        date >= input$date_range[1],
        date <= input$date_range[2],
        sentiment_label %in% input$label_filter
      )
  })
  
  # Filter merged data
  filtered_merged <- reactive({
    merged_data %>%
      filter(date_only >= input$date_range[1],
             date_only <= input$date_range[2])
  })
  
  # Filtered arrows
  filtered_arrows <- reactive({
    arrow_data %>%
      filter(date_only >= input$date_range[1],
             date_only <= input$date_range[2])
  })
  # Summary table
  output$summary_table <- renderTable({
    filtered_sentiment() %>%
      group_by(sentiment_label) %>%
      summarise(
        avg_score = round(mean(sentiment_score, na.rm = TRUE), 3),
        count = n(),
        .groups = "drop"
      )
  })
  
  # Price vs sentiment plot (with one arrow per day)
  output$price_sentiment_plot <- renderPlot({
    df <- filtered_merged()
    arrows <- filtered_arrows()
    
    ggplot(df, aes(x = date)) +
      geom_line(aes(y = Close), color = "blue", size = 1.2) +
      geom_point(aes(y = Close), color = "blue", size = 1) +
      geom_text(data = arrows, aes(x = date, y = Close, label = arrow), 
                vjust = -1.5, size = 6, inherit.aes = FALSE) +
      scale_y_continuous(name = "Closing Price") +
      labs(title = "Stock Price with Sentiment Arrows",
           x = "Timestamp",
           caption = "🔼 Positive | 🔽 Negative") +
      theme_minimal()
  })
  output$sentiment_ratio_plot <- renderPlot({
    sentiment_ratio_daily <- filtered_sentiment() %>%
      filter(sentiment_label %in% c("Positive", "Negative")) %>%
      group_by(date, sentiment_label) %>%
      summarise(count = n(), .groups = "drop") %>%
      group_by(date) %>%
      mutate(
        percentage = count / sum(count) * 100
      )
    
    ggplot(sentiment_ratio_daily, aes(x = date, y = percentage, fill = sentiment_label)) +
      geom_bar(stat = "identity", position = "dodge", width = 0.7) +
      geom_text(aes(label = paste0(round(percentage, 1), "%")),
                position = position_dodge(width = 0.7),
                vjust = -0.3, size = 4) +
      scale_fill_manual(values = c("Positive" = "#4CAF50", "Negative" = "#F44336")) +
      scale_x_date(date_labels = "%b %d") +
      labs(
        title = "Daily Sentiment Ratio: Positive vs Negative",
        x = "Date", y = "Percentage"
      ) +
      theme_minimal()
  })
  
  
}

# Run the app
shinyApp(ui, server)

