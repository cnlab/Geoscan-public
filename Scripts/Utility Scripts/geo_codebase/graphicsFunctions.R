# Quantile Graphic Functions
# q5 and qBr Functions by Ken Steif
# Source: https://www.amazon.com/Public-Policy-Analytics-Context-Government/dp/036751625X

# Raw functions:

q5 <- function(variable) {as.factor(ntile(variable, 5))}

qBr <- function(df, variable, rnd) {
  if (missing(rnd)) {
    as.character(quantile(round(df[[variable]],0),
                          c(.01,.2,.4,.6,.8), na.rm=T))
  } else if (rnd == FALSE | rnd == F) {
    as.character(formatC(quantile(df[[variable]]), digits = 3),
                 c(.01,.2,.4,.6,.8), na.rm=T)
  }
}

# Vignette

#ggplot() +
#  geom_sf(data = myData, aes(fill = q5(myVariable))) +
#  scale_fill_manual(values = palette5,
#                    labels = qBr(myVariable, "myVariable"),
#                    name = "My Variable\n(Quintile Breaks)") +
#  labs(title = "My Title", subtitle = "My Subtitle")

# Plotting and Mapping Themes

plotTheme <- theme(
  plot.title =element_text(size=12),
  plot.subtitle = element_text(size=8),
  plot.caption = element_text(size = 6),
  axis.text.x = element_text(size = 10, angle = 45, hjust = 1),
  axis.text.y = element_text(size = 10),
  axis.title.y = element_text(size = 10),
  # Set the entire chart region to blank
  panel.background=element_blank(),
  plot.background=element_blank(),
  # Format the grid
  panel.grid.major=element_line(colour="#D0D0D0",size=.75),
  axis.ticks=element_blank())

mapTheme <- theme(plot.title =element_text(size=12),
                  plot.subtitle = element_text(size=8),
                  plot.caption = element_text(size = 6),
                  axis.line=element_blank(),
                  axis.text.x=element_blank(),
                  axis.text.y=element_blank(),
                  axis.ticks=element_blank(),
                  axis.title.x=element_blank(),
                  axis.title.y=element_blank(),
                  panel.background=element_blank(),
                  panel.border=element_blank(),
                  panel.grid.major=element_line(colour = 'transparent'),
                  panel.grid.minor=element_blank(),
                  legend.direction = "vertical", 
                  legend.position = "right",
                  plot.margin = margin(1, 1, 1, 1, 'cm'),
                  legend.key.height = unit(1, "cm"), legend.key.width = unit(0.2, "cm"))

palette <- c("#10142A", "#47E9B9", "#F55D60", "#71EA48", "#C148EA", "EAC148" )