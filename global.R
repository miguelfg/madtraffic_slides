require(RJSONIO)
require(rCharts)
require(RColorBrewer)
require(httr)
library(ggplot2)
library(ggmap)
require(downloader)
library(RCurl)

# publish(user='miguelfg', repo='madtraffic_slides')


## @knitr getData
getTrafficPoints <- function(limit = 0) {
  num_decimals <- 3
  # load traffic measure  points
  input_file <- paste(getwd(), '/data/PUNTOS_MEDIDA_TRAFICO_2014_01_23_FIXED.csv', sep='')
  l_traffic_measure_points <- read.csv2(input_file)
  df_traffic_measure_points <- as.data.frame(l_traffic_measure_points)
  df_traffic_measure_points$Long <- as.numeric(as.character(df_traffic_measure_points$Long))
  df_traffic_measure_points$Lat <- as.numeric(as.character(df_traffic_measure_points$Lat))
  df_traffic_measure_points$Long <- round(df_traffic_measure_points$Long, digits = num_decimals)
  df_traffic_measure_points$Lat <- round(df_traffic_measure_points$Lat, digits = num_decimals)
  
  if (limit == 0)
    return (df_traffic_measure_points)
  else
    return (df_traffic_measure_points[1:limit,])
}

## @knitr getData
getAirQualityPoints <- function() {
  num_decimals <- 3
  # load air quality measure points
  l_airq_measure_points <- read.csv2('data/est_airq_madrid.csv')
  df_airq_measure_points <- as.data.frame(l_airq_measure_points)
  df_airq_measure_points$Long2 <- as.numeric(as.character(df_airq_measure_points$Long2))
  df_airq_measure_points$Lat2 <- as.numeric(as.character(df_airq_measure_points$Lat2))
  df_airq_measure_points$Long2 <- round(df_airq_measure_points$Long2, digits = num_decimals)
  df_airq_measure_points$Lat2 <- round(df_airq_measure_points$Lat2, digits = num_decimals)
  return (df_airq_measure_points)
}

addColVis <- function(data) {
  nrows <- nrow(data)
  data$fillColor <- rgb(runif(nrows),runif(nrows),runif(nrows))  
  return (data)
}

getCenter <- function(nm, networks){
  net_ = networks[[nm]]
  lat = as.numeric(net_$lat)/10^6;
  lng = as.numeric(net_$lng)/10^6;
  return(list(lat = lat, lng = lng))
}

## @knitr plotMap
plotMap <- function(num_measure_points = nrow(df_traffic_measure_points), 
                    width = 1600, 
                    height = 800){
  
  map <- Leaflet$new()
  map$tileLayer(provide='Stamen.TonerLite')
  
  #   init map
  map$setView(c(40.41, -3.70), zoom = 12, size = c(20, 20))
  
  #   get data points
  df_traffic_measure_points <- getTrafficPoints(num_measure_points)
  df_airq_measure_points <- getAirQualityPoints()

  data_ <- df_traffic_measure_points[,c("Lat", "Long")]
  data_ <- addColVis(data_)
  colnames(data_) <- c('latitude', 'longitude', 'fillColor')
  
  output_geofile <- paste(getwd(), '/data/', sep='')

  map$geoJson(
        leafletR::toGeoJSON(data_, 
#                             lat.lon = c('Lat', 'Long'),
                            dest=output_geofile)
  )

  # append markers and popup texts
  for(i in 1:num_measure_points) {
    html_text <- paste("<h6> Punto de medida del tráfico </h6>")
    html_text <- paste(html_text, "<p>",  df_traffic_measure_points$NOMBRE.C.254[i]," </p>")
    map$marker(c(df_traffic_measure_points$Lat[i], 
                  df_traffic_measure_points$Long[i]), 
                bindPopup = html_text)
  }

  # append markers and popup texts
  for(i in 1:nrow(df_airq_measure_points)) {
    html_text <- paste("<h6> Estación de calidad del Aire </h6>")
    html_text <- paste(html_text, "<p>",  df_airq_measure_points$Estacion[i]," </p>")
    map$marker(c(df_airq_measure_points$Lat2[i], 
                  df_airq_measure_points$Long2[i]),
                bindPopup = html_text)
#     map$circle(c(df_airq_measure_points$Lat2[i], 
#                  df_airq_measure_points$Long2[i]))
  }


  map$enablePopover(TRUE)
  map$fullScreen(TRUE)
  return(map)
}