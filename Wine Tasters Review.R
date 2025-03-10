# Installing Necessary Libraries
install.packages(c("tidyverse", "tm", "wordcloud", "syuzhet", 
                   "topicmodels", "ggplot2", "SnowballC", "tidytext", "reshape2"))
library(tidytext)
library(tm)
library(tidyr)
library(dplyr)
library(stringr)
library(topicmodels)
library(reshape2)
library(e1071)
library(ggplot2)
library(wordcloud)


setwd("C:/Users/Omobolanle/OneDrive/Documents/")

# Loading the dataset

reviews <- read.csv("MS4S09_CW_Reviews.csv", stringsAsFactors = FALSE)
names(reviews)

# Data Preprocessing/Text Mining:

reviews$text <- tolower(reviews$description)  # to convert to lowercase

reviews$text <- gsub("[[:punct:]]", "", reviews$description)
reviews$text <- gsub("[[:digit:]]", "", reviews$description)  
               # to get rid of punctuation and numbers

#Create a corpus from the 'description' column
corpus <- Corpus(VectorSource(reviews$description))

# Remove stopwords
corpus <- tm_map(corpus, removeWords, stopwords("english"))


# Filter out empty documents after stopwords removal
corpus <- corpus[sapply(corpus, function(x) nchar(unlist(x)))> 0]

# Apply stemming
corpus <- tm_map(corpus, stemDocument)

# Inspect the cleaned corpus
inspect(corpus)


# Tokenize and clean the text
cleaned_data <- reviews %>% select(description) %>%
unnest_tokens(word, description) %>% anti_join(stop_words) %>%
mutate(word = str_remove_all(word, "[^a-zA-Z]")) %>% filter(word !=
"")

# Count word frequency
word_count <- cleaned_data %>% count(word, sort = TRUE)


# Visualize word frequency
word_count %>%
  top_n(20) %>%
  ggplot(aes(x = reorder(word, n), y = n)) +
  geom_bar(stat = "identity") +
  coord_flip() +
  labs(title = "Top 20 Words in Reviews", x = "Words", y = "Frequency")

# Word cloud visualization
wordcloud(words = word_count$word, 
          freq = word_count$n, 
          min.freq = 1, 
          max.words = 100, 
          random.order = FALSE, 
          colors = brewer.pal(8, "Dark2"))


## Sentiment Analysis 
sentiment_data <- reviews %>%
  unnest_tokens(word, description) %>%
  inner_join(get_sentiments("bing")) %>%
  count(sentiment, sort = TRUE)

head(sentiment_data)

# Visualizing sentiment distribution
sentiment_data %>%
  group_by(sentiment) %>%                       # Group by sentiment
  summarise(n = sum(n)) %>%                     # Summarize the count
  ggplot(aes(x = sentiment, y = n, fill = sentiment)) +
  geom_bar(stat = "identity") +
  labs(title = "Sentiment Distribution", x = "Sentiment", y = "Frequency")

#filtering positive and negative review 
positive_reviews <-sentiment_data %>% filter(sentiment == "positive") 
negative_reviews <-sentiment_data %>% filter(sentiment == "negative")

# Positive reviews word cloud
positive_reviews <- reviews %>%
  unnest_tokens(word, description) %>%        
  inner_join(get_sentiments("bing")) %>%       
  filter(sentiment == "positive") %>%         
  count(word, sort = TRUE)                   
head(positive_reviews)

#visualizing the word cloud
wordcloud(
  words = positive_reviews$word,
  freq = positive_reviews$n,
  min.freq = 2, 
  max.words = 200, 
  random.order = FALSE, 
  colors = brewer.pal(8, "Dark2")
)

# Visualizing the most frequent(top 20) positive words
positive_reviews %>% arrange(desc(n)) %>% top_n(20, n) %>%
ggplot(aes(x = reorder(word, n), y = n)) + geom_col(fill = "green") +
coord_flip() + labs( title = "Top 20 Positive Words", x = "Word", y =
"Frequency" )

# Negative reviews word cloud
negative_reviews <- reviews %>%
  unnest_tokens(word, description) %>%        
  inner_join(get_sentiments("bing")) %>%       
  filter(sentiment == "negative") %>%         
  count(word, sort = TRUE)                     
head(positive_reviews)

#visualizing the word cloud
wordcloud( words = negative_reviews$word,
  freq = negative_reviews$n, min.freq = 2, max.words = 200, random.order
= FALSE, colors = brewer.pal(8, "Reds") )

# Top 20 negative words
negative_reviews %>% arrange(desc(n)) %>% top_n(20, n) %>%
ggplot(aes(x = reorder(word, n), y = n)) + geom_col(fill = "red") +
coord_flip() + labs( title = "Top 20 Negative Words", x = "Word", y =
"Frequency" )


## Topic Modelling


# Tokenizing the 'description' column into words
reviews_tidy <- reviews %>% mutate(description_id = row_number()) %>%
unnest_tokens(word, description)

# Creating the Document-Term Matrix (DTM)
dtm <- reviews_tidy %>% count(word, description_id) %>%
cast_dtm(description_id, word, n)

#applying a topic modeling algorithm (Latent Dirichlet Allocation (LDA))
# Fit the LDA model 
lda_model <- LDA(dtm, k = 5)

# Get the top terms for each topic
terms(lda_model, 10)
top_terms <- tidy(lda_model, matrix = "beta") %>% arrange(topic,
desc(beta)) %>% group_by(topic) %>% slice_head(n = 10)
head(top_terms)

# Now visualizing
top_terms %>%
  ungroup() %>%  # Remove grouping
  ggplot(aes(x = reorder(term, beta), y = beta, fill = factor(topic))) +
  geom_bar(stat = "identity", show.legend = FALSE) +
  facet_wrap(~ topic, scales = "free") +
  coord_flip() +
  labs(title = "Top Terms in Each Topic", x = "Terms", y = "Beta")


# Further Explorations:

# 1.TF-IDF (Term Frequency-Inverse Document Frequency)

# Compute TF-IDF
tfidf_data <- reviews_tidy %>% 
  count(word, description_id) %>% 
  bind_tf_idf(word, description_id, n)

# View top 20 words with highest TF-IDF
tfidf_data %>% 
  arrange(desc(tf_idf)) %>%
  top_n(20) %>%
  ggplot(aes(x = reorder(word, tf_idf), y = tf_idf)) +
  geom_col(fill = "blue") +
  coord_flip() +
  labs(title = "Top 20 Words by TF-IDF Score", x = "Word", y = "TF-IDF Score")

# 2.Bigram Analysis

# Tokenize into bigrams
bigrams <- reviews %>%
  unnest_tokens(bigram, description, token = "ngrams", n = 2)

# Count the most common bigrams
bigram_counts <- bigrams %>%
  count(bigram, sort = TRUE)

# Visualizing top 20 bigrams
bigram_counts %>%
  top_n(20) %>%
  ggplot(aes(x = reorder(bigram, n), y = n)) +
  geom_col(fill = "purple") +
  coord_flip() +
  labs(title = "Top 20 Bigrams in Reviews", x = "Bigram", y = "Frequency")

# 3. Sentiments by Points

# Convert points to numeric
reviews$points <- as.numeric(reviews$points)

# Get sentiment scores for each review
sentiment_by_points <- reviews %>%
  unnest_tokens(word, description) %>%
  inner_join(get_sentiments("bing")) %>%
  group_by(points, sentiment) %>%
  summarise(n = n(), .groups = "drop")

# Visualizing sentiment distribution across points
sentiment_by_points %>%
  ggplot(aes(x = points, y = n, color = sentiment)) +
  geom_line(size = 1) +
  labs(title = "Sentiment Distribution by Wine Points",
       x = "Wine Rating (Points)", y = "Number of Words") +
  theme_minimal()

# 4. Sentiments by country

# Calculate sentiment counts per country
sentiment_by_country <- reviews %>%
  unnest_tokens(word, description) %>%
  inner_join(get_sentiments("bing")) %>%
  count(country, sentiment) %>%
  spread(sentiment, n, fill = 0) %>%
  mutate(sentiment_score = positive - negative) 

# Visualize top 10 countries with highest sentiment scores
sentiment_by_country %>%
  top_n(10, sentiment_score) %>%
  ggplot(aes(x = reorder(country, sentiment_score), y = sentiment_score, fill = sentiment_score > 0)) +
  geom_col(show.legend = FALSE) +
  coord_flip() +
  labs(title = "Top 10 Countries by Net Sentiment",
       x = "Country", y = "Net Sentiment Score") +
  theme_minimal()

