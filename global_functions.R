
#######################
# GLOBAL FUNCS
#######################


# load air quality measure points
fixStationCodes <- function(code) {
    #   code <- as.character(code)
    if (code<10) {
        station_code <- paste('2807900',
                              code, sep='')
    }
    else {
        station_code <- paste('280790',
                              code, sep='')
    }
    station_code
}

# BOA
getBOAData <- function(url){
    temp <- getURL(URLencode(url), ssl.verifypeer = FALSE)
    data <- fromJSON(temp, simplifyVector=FALSE)  
}

# IMPALA
connectImpala <- function(){
    rimpala.init(libs ="lib/impala/impala-jdbc-0.5-2/")
    
    # connect
    rimpala.connect("54.171.4.239", port = "21050", principal = "user=guest;password=maddata")
    rimpala.usedatabase("bod_pro")
}

disconnectImpala <- function(){
    rimpala.close()  
}

# identif <- 'PM20742'
# "SELECT * FROM md_trafico_madrid WHERE identif = \"PM20742\" AND fecha > \"2014-09-15\" LIMIT 100 LIMIT 100 LIMIT 100"
getImpalaQuery <- function(identif = 0, date_start = 0, date_end = 0){
    
    limit <- 100
    
    query <- "SELECT * FROM md_trafico_madrid "  
    
    if (identif != 0) {
        query <- paste(query, "WHERE identif = ", 
                       "\"",
                       identif,
                       "\"",         
                       sep = '')
    }
    if (date_start != 0) {
        query <- paste(query, 
                       " AND fecha > ",
                       "\"",
                       date_start,
                       "\"",
                       sep = '')
    }
    if (date_end != 0) {   
        query <- paste(query, 
                       " AND fecha < ",
                       "\"",
                       date_end,
                       "\"",
                       sep = '')
    }
    
    query <- paste(query, " ORDER BY fecha", sep = '')
    
    if (limit != 0) {   
        query <- paste(query, " LIMIT ", as.character(limit) ,sep = '')
    }
    
    query
}

getImpalaData <- function(query){
    data <- rimpala.query(query)
    data
}

getSUMsDataTable <- function(date) {
    
    month_start <- as.Date(date)
    day(month_start) <- 1
    
    month_end <- as.Date(date)
    day(month_end) <- 1
    month(month_end) <- month(month_end) + 1
    
    #   month_name <- strptime(date, format = "%M")
    #   print(month_name)
    
    #   sums_data <- rimpala.query("SELECT identif, sum(vmed) as vmed, sum(intensidad) as intensidad FROM md_trafico_madrid WHERE fecha >= \"2014-06-20\" and fecha < \"2014-06-23\" group by identif order by intensidad desc")
    query <- paste("SELECT identif, avg(vmed) as velocidad_media, avg(carga) as carga_media, sum(intensidad) as intensidad_total FROM md_trafico_madrid WHERE fecha >= \"",
                   month_start,
                   "\" and fecha < \"",
                   month_end,
                   "\" group by identif order by carga_media desc",
                   sep = '')
    sums_data <- rimpala.query(query)
    sums_data
}

getTrafficPointsChoicesImpala <- function(limit = 0) {
    choices <- rimpala.query("SELECT DISTINCT identif FROM md_trafico_madrid")
    choices
}

getIDTrafPoint <- function(name){
    code <- df_traffic_measure_points[df_traffic_measure_points$name == name, 3]
    code
}

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

getKMLData <- function () {
    
    kml_url = 'http://datos.madrid.es/egob/catalogo/202088-0-trafico-camaras.kml'
    kml_file = 'data/202088-0-trafico-camaras.kml'
    if (file.exists(kml_file)) {
        download(url=kml_url, destfile = kml_file)
    }
    #   print(toGeoJSON(kml_file))
    #   toGeoJSON(data=quakes, name="quakes", dest=tempdir(), lat.lon=c(1,2))
    #   return (toGeoJSON(kml_file))
    return (kml_file)
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



plotMap <- function(num_measure_points = nrow(df_traffic_measure_points), 
                    width = 1600, 
                    height = 800){
    
    map <- Leaflet$new()
    map$tileLayer(provide='Stamen.TonerLite')
    
    #   init map
    map$setView(c(40.41, -3.70), zoom = 12, size = c(20, 20))

    #   filter data points
    sub_traffic_measure_points <- df_traffic_measure_points[1:num_measure_points,]
    #   df_airq_measure_points <- getAirQualityPoints()
    
    data_ <- sub_traffic_measure_points[,c("lat", "long")]
    data_ <- addColVis(data_)
    colnames(data_) <- c('lat', 'lng', 'fillColor')
    
    output_geofile <- paste(getwd(), '/data/', sep='')
    

    map$geoJson(
        leafletR::toGeoJSON(data_, 
                            lat.lon = c('lat', 'lng'),
                            dest=output_geofile),
        pointToLayer =  "#! function(feature, latlng){
                            return L.circleMarker(latlng, {
                            radius: 6,
                            fillColor: 'green',
                            color: '#333',
                            weight: 1,
                            fillOpacity: 0.8
                            })
                         } !#"
        )
    
    # append markers and popup texts
    for(i in 1:num_measure_points) {
        html_text <- paste("<h6> Punto de medida del tráfico </h6>")
        html_text <- paste(html_text, "<p>",  sub_traffic_measure_points$name[i]," </p>")
        map$marker(c(sub_traffic_measure_points$lat[i], 
                     sub_traffic_measure_points$long[i]),
                   bindPopup = html_text)
    }
    
    # append markers and popup texts
    for(i in 1:nrow(df_airq_measure_points)) {
        html_text <- paste("<h6> Estación de calidad del Aire </h6>")
        html_text <- paste(html_text, "<p>",  df_airq_measure_points$Estacion[i]," </p>")
        map$marker(c(df_airq_measure_points$Lat2[i], 
                     df_airq_measure_points$Long2[i]),
                   bindPopup = html_text)
    }
    
    map$enablePopover(TRUE)
    map$fullScreen(TRUE)
    return(map)
    }


# SERIES CHART FOR ONE TRAFFIC MEASURE POINT
getTrafficSeriesChart <- function (traf_point = 'PM20742', date_start, date_end) { 
    #   print(traf_point)
    #   print(date_start)
    #   print(date_end)
    #   print("===========")
    
    query <- getImpalaQuery(traf_point, date_start, date_end)  
    
    # get data from impala
    data <- getImpalaData(query)  
    data
}