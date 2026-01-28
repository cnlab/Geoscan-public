library(dplyr)
library(readr)

# Set working directory
setwd("/Users/Farah/Desktop")

# Read data
PIL <- read.csv("PIL.csv", header = TRUE, stringsAsFactors = FALSE)
CESD <- read.csv("cesd.csv", header = TRUE, stringsAsFactors = FALSE)


#SUBSET PIL TO MEAN SCORES
# Check column names
names(PIL)

# Subset to rows where method contains "mean"
mean_PIL <- PIL %>%
  filter(grepl("mean", method, ignore.case = TRUE))

# Preview the filtered data
head(mean_PIL)
nrow(mean_PIL)

# Save the filtered data
write_csv(mean_PIL, "/Users/Farah/Desktop/mean_PIL.csv")



#SUBSET CESD TO MEAN SCORES
# Check column names
names(CESD)

# Subset to rows where method contains "mean"
mean_CESD <- CESD %>%
  filter(grepl("mean", method, ignore.case = TRUE))

# Preview the filtered data
head(mean_CESD)
nrow(mean_CESD)

# Save the filtered data
write_csv(mean_CESD, "/Users/Farah/Desktop/mean_CESD.csv")


#MERGE THE MEANS SCORES
# Rename score columns to be unique
mean_PIL <- mean_PIL %>%
  rename(PIL_score = score)

mean_CESD <- mean_CESD %>%
  rename(CESD_score = score)

# Filter to session 1
mean_PIL <- mean_PIL %>%
  filter(sm_session == 1)

mean_CESD <- mean_CESD %>%
  filter(sm_session == 1)

# Merge by participant ID
merged_data <- inner_join(mean_PIL, mean_CESD, by = "pid")


#CORRELATION BETWEN PIL AND CESD MEAN SCORES
cor(merged_data$PIL_score, merged_data$CESD_score, use = "complete.obs")

#with p value
cor.test(merged_data$PIL_score, merged_data$CESD_score)

#plot
plot(merged_data$PIL_score, merged_data$CESD_score,
     xlab = "PIL Score",
     ylab = "CESD Score",
     main = "Correlation between PIL and CESD scores")
abline(lm(CESD_score ~ PIL_score, data = merged_data), col = "red")  # regression line