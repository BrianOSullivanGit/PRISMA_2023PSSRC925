# This R script downloads publicly available geospatial data relevant to the study of
# environmental antimicrobial resistance in the Republic of Ireland from government agencies
# including the EPA, DAFM (via the Marine Institute / Foras na Mara), and the CSO.
# It also installs and loads the R packages required to access and process these datasets.

# In addition this script also defines some utility functions to process and render this data
# and downloads open data to create a base layer that provides geographic context for the
# environmental maps presented.

# This script has been tested on Ubuntu 24.04 with R version 4.3.3 (2024-02-29).

# The following packages will need to be installed on ubuntu.
# If they are not there you may want to install them with,
# sudo apt-get install build-essential -y
# sudo apt install cmake
# sudo apt install libgdal-dev -y
# sudo apt install libudunits2-dev -y 

# FYI, to clear memory...
# to clear rm(list = ls())
# gc()

# Required R packages to download and process the data.
# This section will install any required packages that are missing.
if (!requireNamespace("rjson", quietly = TRUE))
  install.packages("rjson")
if (!requireNamespace("dplyr", quietly = TRUE))
  install.packages("dplyr")
if (!requireNamespace("lubridate", quietly = TRUE))
  install.packages("lubridate")
if (!requireNamespace("sf", quietly = TRUE))
  install.packages("sf")
if (!requireNamespace("geojsonsf", quietly = TRUE))
  install.packages("geojsonsf")
if (!requireNamespace("tmap", quietly = TRUE))
  install.packages("tmap")
if (!requireNamespace("kohonen", quietly = TRUE))
  install.packages("kohonen")
if (!requireNamespace("ggplot2", quietly = TRUE))
  install.packages("ggplot2")
if (!requireNamespace("pracma", quietly = TRUE))
  install.packages("pracma")
if (!requireNamespace("stars", quietly = TRUE))
  install.packages("stars")
if (!requireNamespace("osmdata", quietly = TRUE))
  install.packages("osmdata")


library(osmdata)
library(sf)

library(ggplot2)
library(pracma)
library(stars)
library(rjson)
library(dplyr)
library(lubridate)

# Map libs
library(sf)
library(tmap)

# SOM
library(kohonen)

# Make sure the required data files are there.
# remember these are live files that may be frequently updated.
# Delete the previous file version if you want to get an upto date picture.


# A Web Feature Service (WFS) is a web service that allows users to retrieve, manipulate, and manage geographic features over the internet.
# It's a standard defined by the Open Geospatial Consortium (OGC) for accessing and interacting with vector data in a standardized way.
# It is defined in the OGC Web Services Context Document (OWS).
#
# This API provides a standard way to access and interact with geospatial data stored on environment/climate servers.

# Locations of icons used in visuals

# Bathing waterquality level icons
bathingLevelsIcons = tmap_icons(c(
  "ICONS/blueBpin.png",
  "ICONS/greenBpin.png",
  "ICONS/orangeBpin.png",
  "ICONS/redBpin.png",
  "ICONS/purpleBpin.png"))

# Wastewater emission point severity icons
wwepsLevelsIcons = tmap_icons(c(
  "ICONS/redAlertIcon.png",
  "ICONS/yellowAlertIcon.png",
  "ICONS/purpleAlertIcon.png"
))

########################## CSO animal census data from 2020 #############################

# Animal census data collected every ten years in accordance with (EU) 2018/1091
# is geolocated at the Electoral Division level.
# We also download geospatial data defining the boundaries of each electoral division,
# along with data on the types and numbers of livestock within each division.

message(paste0("\033[0;32m########################## CSO animal census data from 2020 #############################\n\nAnimal census data collected every ten years in accordance with (EU) 2018/1091\nis geolocated at the Electoral Division level.\nWe also download geospatial data defining the boundaries of each electoral division,\nalong with data on the types and numbers of livestock within each division.\n"))


# CSO: Get the Electoral Divisions geojson file associated with the 2020 animal census.
# The geospatial data is 20m generalised.
if (!file.exists("DATA/csoEdAVA42.geojson")) {
  # Then download it
  system("wget -O DATA/csoEdAVA42.geojson 'https://ws.cso.ie/public/api.static/PxStat.Data.GeoMap_API.Read/8618bd9a9b8b23c966fdd8a37a1b3204'")
}
csoEdAVA42 = st_read("DATA/csoEdAVA42.geojson")

# CSO: Get the Electoral Divisions geojson file containing livestock data from the 2020 CSO animal census.
# Geospatial data is 20m generalised.

# Data use: https://data.gov.ie/dataset/ava42-farms-with-livestock/resource/b0874c44-5c8b-42a4-9920-c00678cf6920

if (!file.exists("DATA/csoDataAVA42.csv")) {
  # Then download it
  system("wget -O DATA/csoDataAVA42.csv 'https://ws.cso.ie/public/api.restful/PxStat.Data.Cube_API.ReadDataset/AVA42/CSV/1.0/en'")
}
csoDataAVA42 = read.csv("DATA/csoDataAVA42.csv", header = TRUE)

# Convert to wide format and just look at the most recent census, 2020.
csoDataAVA42_2020=reshape(csoDataAVA42[csoDataAVA42$Census.Year=="2020",], idvar = c("C03904V04656"), timevar = "Type.of.Livestock", direction = "wide")[,c(1,5:6,9,17,25,33,41)]

# Match these entries up with their corresponding geometries.
csoDataAVA42_2020=cbind(csoDataAVA42_2020[match(csoEdAVA42$code,csoDataAVA42_2020$C03904V04656),],csoEdAVA42[,2:3])

# Use this to create an sf object
edSfAVA42 = st_as_sf(csoDataAVA42_2020,
                     crs = 4326)

# Unfortunately some of the geometries provided by the CSO are malformed (ie., polygons with crossed edges or duplicate vertices).
# We therefore need to fix them before applying methods to get their area etc.
# See. https://github.com/r-spatial/s2/issues/265

sf_use_s2(FALSE)
edSfAVA42 = st_make_valid(edSfAVA42)

# Add polygon areas to the CSO animal census data.
edSfAVA42$areas = st_area(edSfAVA42)
sf_use_s2(TRUE)

# Give the columns easier to remember names.
colnames(edSfAVA42) <- c("csoId", "year", "edName", "totalCattle", "dairyCows", "otherCows", "totalSheep", "livestockUnits", "altEdName", "geometry", "area")

# Add some animal densities. List them in terms of animals per square KM.
edSfAVA42$totalCattlePerKm = 10^6*(edSfAVA42$totalCattle/edSfAVA42$area)
edSfAVA42$dairyCowsPerKm = 10^6*(edSfAVA42$dairyCows/edSfAVA42$area)
edSfAVA42$otherCowsPerKm = 10^6*(edSfAVA42$otherCows/edSfAVA42$area)
edSfAVA42$totalSheepPerKm = 10^6*(edSfAVA42$totalSheep/edSfAVA42$area)
edSfAVA42$livestockUnitsPerKm = 10^6*(edSfAVA42$livestockUnits/edSfAVA42$area)

# Clear the units here, they only make potential problems down the line.
# The standard unit of distance is the metre.
# Unless it is explicitly stated in the variable name (ie., "totalCattlePerKm")
# assume the standard unit.
# don't go down the route of something like,
# The previous calculation was in m^2, change to units of km^2
#  tUnit=units(edSfAVA42$totalCattlePerKm)
#  tUnit$denominator=c("km","km")
#  units(edSfAVA42$totalCattlePerKm) <- tUnit

units(edSfAVA42$totalCattlePerKm) <- c()
units(edSfAVA42$dairyCowsPerKm) <- c()
units(edSfAVA42$otherCowsPerKm) <- c()
units(edSfAVA42$totalSheepPerKm) <- c()




######## CSO septic tank data data from Permanent private households 2022 census ########

# As with the livestock data, we also download geospatial data defining the boundaries
# of each electoral division, together with information on the types and numbers of
# household wastewater treatment systems within each division.

# Data use: https://data.gov.ie/dataset/sap2022t6t7ed-permanent-private-households

message(paste0("\033[0;32m######## CSO septic tank data data from Permanent private households 2022 census ########\n\nAs with the livestock data, we also download geospatial data defining the boundaries\nof each electoral division, together with information on the types and numbers of\nhousehold wastewater treatment systems within each division.\n"))

# CSO: Get the Electoral Divisions geojson file associated with the Permanent private households 2022 census.
# The geospatial data is 20m generalised.
if (!file.exists("DATA/csoEdSAP2022T6T7ED.geojson")) {
  # Then download it
  system("wget -O DATA/csoEdSAP2022T6T7ED.geojson 'https://ws.cso.ie/public/api.static/PxStat.Data.GeoMap_API.Read/c5b950f2f3ab85cc657c4c0082b9fd05'")
}
csoEdSAP2022T6T7ED = st_read("DATA/csoEdSAP2022T6T7ED.geojson")

# CSO: Get the Electoral Divisions geojson file associated with the CSO Permanent private households 2022 census.
# Geospatial data is 20m generalised.
if (!file.exists("DATA/csoDataSAP2022T6T7ED.csv")) {
  # Then download it
  system("wget -O DATA/csoDataSAP2022T6T7ED.csv 'https://ws.cso.ie/public/api.restful/PxStat.Data.Cube_API.ReadDataset/SAP2022T6T7ED/CSV/1.0/en'")
}
csoDataSAP2022T6T7ED = read.csv("DATA/csoDataSAP2022T6T7ED.csv", header = TRUE)

# Convert to wide format and just look at the most recent census, 2020.
csoDataSAP2022T6T7ED_2022=reshape(csoDataSAP2022T6T7ED, idvar = c("C04167V04938"), timevar = "Type.of.Sewerage", direction = "wide")[,c(1,5,9,17,25,33,41,49,57)]


# Match these entries up with their corresponding geometries.
csoDataSAP2022T6T7ED_2022=cbind(csoDataSAP2022T6T7ED_2022[match(csoEdSAP2022T6T7ED$code,csoDataSAP2022T6T7ED_2022$C04167V04938),],csoEdSAP2022T6T7ED[,2:4])

# Use this to create an sf object
edSfSAP2022T6T7ED_2022 = st_as_sf(csoDataSAP2022T6T7ED_2022,
                                  crs = 4326)

# Unfortunately some of the geometries provided by the CSO are malformed (ie., polygons with crossed edges or duplicate vertices).
# We therefore need to fix them before applying methods from the R Simple Features library to get their area etc.
# See. https://github.com/r-spatial/s2/issues/265

sf_use_s2(FALSE)
edSfSAP2022T6T7ED_2022 = st_make_valid(edSfSAP2022T6T7ED_2022)

# Add polygon areas to the CSO Permanent private households 2022 census.
edSfSAP2022T6T7ED_2022$area = st_area(edSfSAP2022T6T7ED_2022)
sf_use_s2(TRUE)

# Give the columns easier to remember names.
colnames(edSfSAP2022T6T7ED_2022) <- c("csoId", "year", "publicScheme", "individualSepticTank", "otherIndividualTreatment", "other", "noSewerageFacility", "notStated", "total",  "edNameEng", "edNameGa", "geometry", "area")

colnames(edSfSAP2022T6T7ED_2022)

# Add densities per square KM.
edSfSAP2022T6T7ED_2022$publicSchemePerKm = 10^6*(edSfSAP2022T6T7ED_2022$publicScheme/edSfSAP2022T6T7ED_2022$area)
edSfSAP2022T6T7ED_2022$individualSepticTankPerKm = 10^6*(edSfSAP2022T6T7ED_2022$individualSepticTank/edSfSAP2022T6T7ED_2022$area)
edSfSAP2022T6T7ED_2022$otherIndividualTreatmentPerKm = 10^6*(edSfSAP2022T6T7ED_2022$otherIndividualTreatment/edSfSAP2022T6T7ED_2022$area)
edSfSAP2022T6T7ED_2022$otherPerKm = 10^6*(edSfSAP2022T6T7ED_2022$other/edSfSAP2022T6T7ED_2022$area)
edSfSAP2022T6T7ED_2022$noSewerageFacilityPerKm = 10^6*(edSfSAP2022T6T7ED_2022$noSewerageFacility/edSfSAP2022T6T7ED_2022$area)

# Clear the units here, they only make potential problems down the line.
# The standard unit of distance is the metre.
# Unless it is explicitly stated in the variable name (ie., "individualSepticTankPerKm")
# assume the standard unit.
units(edSfSAP2022T6T7ED_2022$publicSchemePerKm) <- c()
units(edSfSAP2022T6T7ED_2022$individualSepticTankPerKm) <- c()
units(edSfSAP2022T6T7ED_2022$otherIndividualTreatmentPerKm) <- c()
units(edSfSAP2022T6T7ED_2022$otherPerKm) <- c()
units(edSfSAP2022T6T7ED_2022$noSewerageFacilityPerKm) <- c()


######### Wastewater treatment plants and discharge locations (emission points) #########

# Datasets detailing Sewage Industrial Interface Facilities (SIIF) and
# Urban Wastewater (UWW) discharge points in Ireland, including geolocated wastewater treatment
# plants and discharge locations, are available through GIS services such as GeoServer
# (an open-source, Java-based geospatial data server supporting WFS) provided by the
# Environmental Protection Agency (EPA) of Ireland.

# Data use: https://gis.epa.ie/geonetwork/srv/api/records/8034f005-acf6-45b4-9c55-33c23fb74c78


message(paste0("\033[0;32m######### Wastewater treatment plants and discharge locations (emission points) #########\n\nDatasets detailing Sewage Industrial Interface Facilities (SIIF) and\nUrban Wastewater (UWW) discharge points in Ireland, including geolocated wastewater treatment\nplants and discharge locations, are available through GIS services such as GeoServer\n(an open-source, Java-based geospatial data server supporting WFS) provided by the\nEnvironmental Protection Agency (EPA) of Ireland.\n\033[0m\n"))

if (!file.exists("DATA/wwtpEmissionPoints.geojson")) {
  # Then download it
  system("wget -O DATA/wwtpEmissionPoints.geojson 'https://gis.epa.ie/geoserver/EPA/ows?service=WFS&version=1.0.0&request=GetFeature&typeName=EPA:SIIF_UWWEmissionPoints&outputFormat=application%2Fjson&srsName=EPSG:4326'")
}
wwEp = st_read("DATA/wwtpEmissionPoints.geojson")

# UWWTPs

# Data use: https://gis.epa.ie/geonetwork/srv/api/records/8034f005-acf6-45b4-9c55-33c23fb74c78

if (!file.exists("DATA/wwtpFacilities.geojson")) {
  # Then download it
  system("wget -O DATA/wwtpFacilities.geojson 'https://gis.epa.ie/geoserver/EPA/ows?service=WFS&version=1.0.0&request=GetFeature&typeName=EPA:LEMA_Facilities_UWW&outputFormat=application%2Fjson&srsName=EPSG:4326'")
}
wwtpFacilities=st_read("DATA/wwtpFacilities.geojson")

# Also down plant outline from OSM for WWTPs of interest.
# Cache these locally

if (!file.exists("DATA/castleblayneyWwtp.geojson")) {
  # Then download it
  q = add_osm_feature(opq=opq("Castleblayney, Ireland"), key = "name", value = "Castleblaney Wastewater Treatment Plant")
  castleblayneyWwtpSf = osmdata_sf(q)$osm_polygons
  st_write(castleblayneyWwtpSf, dsn = "DATA/castleblayneyWwtp.geojson", layer = "castleblayneyWwtp.geojson")
} else {
  castleblayneyWwtpSf = st_read("DATA/castleblayneyWwtp.geojson")
}

if (!file.exists("DATA/ringsendWwtp.geojson")) {
  # Then download it
  q = add_osm_feature(opq=opq("Dublin, Ireland"), key = "name", value = "Ringsend Wastewater Treatment Works")
  ringsendWwtpSf = osmdata_sf(q)$osm_polygons
  st_write(ringsendWwtpSf, dsn = "DATA/ringsendWwtp.geojson", layer = "ringsendWwtp.geojson")
} else {
  ringsendWwtpSf = st_read("DATA/ringsendWwtp.geojson")
}

# UWWTP agglomerations (catchment areas)

# Data use: https://gis.epa.ie/geonetwork/srv/api/records/aa16d584-7208-4f93-9c6a-daae906fb120

if (!file.exists("DATA/wwtpAgglomerations.geojson")) {
  # Then download it
  system("wget -O DATA/wwtpAgglomerations.geojson 'https://gis.epa.ie/geoserver/EPA/ows?service=WFS&version=1.0.0&request=GetFeature&typeName=EPA:UWW_AgglomerationBoundaries&outputFormat=application%2Fjson&srsName=EPSG:4326'")
}
wwtpAgglomerations=st_read("DATA/wwtpAgglomerations.geojson")

##################### Industrial emissions licensed facilities ##########################

# The Environmental Protection Agency (EPA) grants and enforces Industrial Emissions
# licences (IEL) for specified industrial and large-scale agricultural activities, such
# as pig and poultry farming.
# Details on the type and scale of each licensed activity are available through GIS
# services, including GeoServer (an open-source, Java-based geospatial data server
# supporting WFS), provided by the EPA of Ireland.

message(paste0("\033[0;32m##################### Industrial emissions licensed facilities ##########################\n\nThe Environmental Protection Agency (EPA) grants and enforces Industrial Emissions\nlicences (IEL) for specified industrial and large-scale agricultural activities, such\nas pig and poultry farming.\nDetails on the type and scale of each licensed activity are available through GIS\nservices, including GeoServer (an open-source, Java-based geospatial data server\nsupporting WFS), provided by the EPA of Ireland.\n\033[0m\n"))

# Data use: https://gis.epa.ie/geonetwork/srv/api/records/7905844c-a43d-4dd4-b262-c95c7aa0e9c7

if (!file.exists("DATA/LEMA_Facilities_IEL.geojson")) {
  # Then download it
  system("wget -O DATA/LEMA_Facilities_IEL.geojson 'https://gis.epa.ie/geoserver/EPA/ows?service=WFS&version=1.0.0&request=GetFeature&typeName=EPA:LEMA_Facilities_IEL&outputFormat=application%2Fjson&srsName=EPSG:4326'")
}
ielFacilities=st_read("DATA/LEMA_Facilities_IEL.geojson")

#################################### Aquaculture ########################################

# In the Republic of Ireland, geolocated aquaculture data are collected by the 
# Department of Agriculture, Food and the Marine and made available by the Marine 
# Institute to support reporting under the Marine Strategy Framework Directive 
# (2008/56/EC). The data are accessible via the Marine Institute’s GIS 
# services, including its ArcGIS REST API, subject to the terms and conditions of 
# the Marine Atlas (https://atlas.marine.ie).

message(paste0("\033[0;32m#################################### Aquaculture ########################################\n\nIn the Republic of Ireland, geolocated aquaculture data are collected by the \nDepartment of Agriculture, Food and the Marine and made available by the Marine \nInstitute to support reporting under the Marine Strategy Framework Directive \n(2008/56/EC). The data are accessible via the Marine Institute’s GIS \nservices, including its ArcGIS REST API, subject to the terms and conditions of \nthe Marine Atlas (https://atlas.marine.ie).\n\033[0m\n"))

# Data usage: https://www.marine.ie/site-area/online-policies/re-use-public-sector-information

if (!file.exists("DATA/aquaculture_irl.json")) {
  # Then download it
  system("wget -O DATA/aquaculture_irl.json 'https://atlas.marine.ie/arcgis/rest/services/05_Aquaculture_Sites/MapServer/0/query?where=OBJECTID>0&geometryType=esriGeometryEnvelope&spatialRel=esriSpatialRelIntersects&outFields=OBJECTID,Shape,site_id,bay,harbour,county,site_status,licence_type,licensee_name,aquaculture_type,species_name_1,species_name_2,species_name_3,species_name_4,species_name_5,species_name_6,species_name_7,species_name_8,species_name_9,species_name_10,species_concat,Shape_Length,Shape_Area&returnGeometry=true&returnTrueCurves=false&returnIdsOnly=false&returnCountOnly=false&returnZ=false&returnM=false&returnDistinctValues=false&f=pjson'")
}
ielAquaculture=st_read("DATA/aquaculture_irl.json")


########################## Water Framework Directive lakes ##############################

# Geospatial Dataset of EPA-Managed Lakes in Ireland under the Water Framework Directive

message(paste0("\033[0;32m######################### Water Framework Directive lakes ##############################\n\nGeospatial Dataset of EPA-Managed Lakes in Ireland under the Water Framework Directive\n\033[0m\n"))


# EPA:WFD_RIVERWATERBODIES_CYCLE3
if (!file.exists("DATA/WFD_RiverWaterBodies.geojson")) {
  # Then download it
  system("wget -O DATA/WFD_RiverWaterBodies.geojson 'https://gis.epa.ie/geoserver/EPA/ows?service=WFS&version=1.0.0&request=GetFeature&typeName=EPA:WFD_RIVERWATERBODIES_CYCLE3&outputFormat=application%2Fjson&srsName=EPSG:4326'")
}
wfdRiverWaterBodies=st_read("DATA/WFD_RiverWaterBodies.geojson")

######
# EPA:WATER_RIVNETROUTES
if (!file.exists("DATA/WATER_RiverNetRoutes.geojson")) {
  # Then download it
  system("wget -O DATA/WATER_RiverNetRoutes.geojson 'https://gis.epa.ie/geoserver/EPA/ows?service=WFS&version=1.0.0&request=GetFeature&typeName=EPA:WATER_RIVNETROUTES&outputFormat=application%2Fjson&srsName=EPSG:4326'")
}
wfdRiverWaterBodies=st_read("DATA/WATER_RiverNetRoutes.geojson")


######

# EPA:WFD Lake Water Bodies
# Data use: https://gis.epa.ie/geonetwork/srv/api/records/b0f258c3-4ce8-4a4d-9549-316490a59b28

if (!file.exists("DATA/WFD_LakeWaterBodiesActive.geojson")) {
  # Then download it
  system("wget -O DATA/WFD_LakeWaterBodiesActive.geojson 'https://gis.epa.ie/geoserver/EPA/ows?service=WFS&version=1.0.0&request=GetFeature&typeName=EPA:WFD_LakeWaterBodiesActive&outputFormat=application%2Fjson&srsName=EPSG:4326'")
}
wfdLakeWaterBodies=st_read("DATA/WFD_LakeWaterBodiesActive.geojson")

# WFD_RPA_BATHINGWATERAREAS

# Data use: https://gis.epa.ie/geonetwork/srv/api/records/6e301f33-88a2-4a6a-a068-2da8f0b3aa75

if (!file.exists("DATA/WFD_RPA_BATHINGWATERAREAS.geojson")) {
  # Then download it
  system("wget -O DATA/WFD_RPA_BATHINGWATERAREAS.geojson 'https://gis.epa.ie/geoserver/EPA/ows?service=WFS&version=1.0.0&request=GetFeature&typeName=EPA:WFD_RPA_BATHINGWATERAREAS&outputFormat=application%2Fjson&srsName=EPSG:4326'")
}
wfdRpaBathingWaterAreas=st_read("DATA/WFD_RPA_BATHINGWATERAREAS.geojson")

################################ Bathingwater quality ###################################

# This dataset is provided as part of EPA Ireland's Open Data REST APIs for accessing real-time
# water quality data provided by local authorities on Ireland's beaches and lakes,
# including Locations, Measurements, and Alerts.
# See https://beaches.ie and https://data.epa.ie for more information.

# Data use: https://data.epa.ie/api-list/bathing-water-open-data

message(paste0("\033[0;32m################################ Bathingwater quality ###################################\n\nThis dataset is provided as part of EPA Ireland's Open Data REST APIs for accessing real-time\nwater quality data provided by local authorities on Ireland's beaches and lakes,\nincluding Locations, Measurements, and Alerts.\nSee https://beaches.ie and https://data.epa.ie for more information.\n\033[0m\n"))

# EPA bathing locations test points
if (!file.exists("DATA/epaBathingLocations.json")) {
  # Then download it
  system("wget -O DATA/epaBathingLocations.json https://api.beaches.ie/odata/beaches")
}

# Unnest the bathing mess
epaBathingLocations=fromJSON(file="DATA/epaBathingLocations.json")
epaBathingLocations=epaBathingLocations[2]$value
epaBathingLocations <- as.data.frame(do.call(rbind, epaBathingLocations))
epaBathingLocations = data.frame(lapply(epaBathingLocations, as.character), stringsAsFactors=FALSE)
epaBathingLocations$EtrsX = as.numeric(epaBathingLocations$EtrsX)
epaBathingLocations$EtrsY = as.numeric(epaBathingLocations$EtrsY)
epaBathingLocations$Easting = as.numeric(epaBathingLocations$Easting)
epaBathingLocations$Northing = as.numeric(epaBathingLocations$Northing)


# List of inland bathing waters (rivers, lakes etc.)
# It would have been nice if they used a consistent naming convention for the Eden code to distinguish them here,
# but they did not, so here's the list...
inlandBathingWaters = c("IEWEBWL29_194_0100","IEEABWL07_274_0100","IESHBWL27_72_0100","IESHBWL26_624_0100","IESHBWL25_188_0100","IESHBWL25_191a_0200","IESHBWL26_703_0100","BPNBF010000010001","BPNBF010000020001","BPNBF240000030001","BPNBF240000100001","BPNBF240000020001","BPNBF240000040001","BPNBF240000050001","BPNBF240000060001","BPNBF240000070001","BPNBF240000080001","BPNBF240000090001","BPNBF240000110001","IESHBWL25_191a_0300","IESHBWL25_191a_0100","BPNBF120000200001","IESHBWL25_191a_0190")

#write.table(epaBathingLocations, file='DATA/epaBathingLocations.csv', quote=TRUE, sep=',', row.names = TRUE);

# EPA bathing water quality results
# Download all historical test result data on all bathing locations unless you have done so already.
if (!file.exists("DATA/bathingWaterQuality.tsv")) {
  # Then download all EPA bathing water quality results.
  
  # Now, unless you have done so already, download the complete set of bathing water quality testing results to date for Ireland.
  bqDataComplete = c();
  
  # For each bathing location, get historical water quality test data.
  for(i in epaBathingLocations$Code)
  {
    sysCmd = paste0("wget -O- https://api.beaches.ie/api/beach/", i, "/monitoringdata");
    jStr = system(sysCmd, intern = TRUE);
    
    bqData = fromJSON(json_str = jStr);
    bqData = bqData$Results;
    bqData = as.data.frame(do.call(rbind, bqData));
    bqDataComplete = rbind(bqDataComplete, bqData);
  }
  
  bqDataComplete = data.frame(lapply(bqDataComplete, as.character), stringsAsFactors=FALSE)
  
  # Store the data so we don't need to redownload each time.
  write.table(bqDataComplete, file='DATA/bathingWaterQuality.tsv', quote=FALSE, sep='\t', row.names = FALSE);
}

bqDataComplete=read.table(file = 'DATA/bathingWaterQuality.tsv', sep = '\t', header = TRUE)

# Estimate reading that have been capped at less than some value.
# Set value to half the max.
bqDataComplete$EcoliResult = sub("^<","0.5*",bqDataComplete$EcoliResult)
bqDataComplete$EnterococciResult = sub("^<","0.5*",bqDataComplete$EnterococciResult)

# Estimate readings listed as greater than some number.
# Set value to the min value (ie. remove the ">").
bqDataComplete$EcoliResult = sub("^>","",bqDataComplete$EcoliResult)
bqDataComplete$EnterococciResult = sub("^>","",bqDataComplete$EnterococciResult)

# Now evaluate the changes to update the values.
bqDataComplete$EcoliResult = unname(sapply(bqDataComplete$EcoliResult, function(x) eval(parse(text=x))))
bqDataComplete$EnterococciResult = unname(sapply(bqDataComplete$EnterococciResult, function(x) eval(parse(text=x))))

# Add a field indicating the year the test was carried out
bqDataComplete$ResultYear = as.numeric(sub("-.*","",bqDataComplete$ResultDate))

# Add a column recording the number of hours since the start of that year’s bathing season monitoring.
# Convert date format first
bqDataComplete$posixDateTime=as.POSIXct(bqDataComplete$ResultDate, format = "%Y-%m-%dT%H:%M:%S")
bqDataComplete = bqDataComplete %>%
  arrange(LocationId, posixDateTime) %>%
  mutate(year = year(posixDateTime)) %>%
  group_by(LocationId, year) %>%
  mutate(hoursSinceSeasonMonitoringStart = as.numeric(posixDateTime - first(posixDateTime), units = "hours")) %>%
  ungroup()


# Get summary of last number of years bathing water quality.
# Use the median value of pooled microbial data for each monitoring site from the years of interest
bqSummary = bqDataComplete[bqDataComplete$ResultYear>=yearStart & bqDataComplete$ResultYear<=yearEnd,] %>%
  group_by(LocationId)%>% 
  summarise(EcoliResult=median(EcoliResult), EnterococciResult=median(EnterococciResult))

# Get another summary of last number of years bathing water quality.
# This time use mean of the time-weighted seasonal means for each monitoring station from the years of interest.

# Use the trapezoidal rule with linear interpolation to get a time-weighted seasonal mean
trapMean  <- function(time, value) {
  trapz(time, value)/(max(time)-min(time))
}

seasonalMeans <- bqDataComplete[bqDataComplete$ResultYear>=yearStart & bqDataComplete$ResultYear<=yearEnd,] %>%
  group_by(LocationId, year) %>%
  summarise(        
    # Add mean of time-weighted seasonal means to compare 
    EcoliTwsmmResult = trapMean(hoursSinceSeasonMonitoringStart, EcoliResult),
    EnterococciTwsmmResult = trapMean(hoursSinceSeasonMonitoringStart, EnterococciResult)
  )
# Now get the mean of the seasonal means.
seasonalMeans = seasonalMeans %>%
  group_by(LocationId)%>% 
  summarise(EcoliTwsmmResult=mean(EcoliTwsmmResult), EnterococciTwsmmResult=mean(EnterococciTwsmmResult))

# Now add these to the BWQ summary

# df[order(as.Date(df$date, format="%m/%d/%Y")),]

# Complete bathing water quality dataframe.
epaBqXyrsMedians=cbind(epaBathingLocations[match(bqSummary$LocationId,epaBathingLocations$LocationId),c(1:3,5:10)],bqSummary[,2:3],seasonalMeans[,c(2,3)])


################################### Base map detail #####################################

# OSRM (Open Source Routing Machine) is an open-source routing engine that supports interactive
# route planning, navigation, and network analysis. In this publication, routes devised by the  OSRM server
# are used in conjunction with coastal maps of the Republic of Ireland and Northern Ireland obtained from
# Tailte Éireann and the Ordnance Survey of Northern Ireland open data portals to create a base
# layer that provides geographic context for the environmental maps presented.

message(paste0("\033[0;32m######## Base map detail ########\nOSRM (Open Source Routing Machine) is an open-source routing engine that supports interactive\nroute planning, navigation, and network analysis. In this publication, routes devised by the  OSRM server\nare used in conjunction with coastal maps of the Republic of Ireland and Northern Ireland obtained from\nTailte Éireann and the Ordnance Survey of Northern Ireland open data portals to create a base\nlayer that provides geographic context for the environmental maps presented.\n\033[0m\n"))

# Utility functions....
# Plot E.coli median levels for all years on record at a given location
ecoliWQoverview <- function(locationList, bData, location, note = "") {
  tmpIds=locationList[grep(location, locationList$Name),]$LocationId[1]
  name=epaBathingLocations[grep(location, epaBathingLocations$Name),]$Name[1]
  
  tmpSummary = bData %>%
    group_by(LocationId, ResultYear)%>% 
    summarise(EcoliResult=median(EcoliResult))
  
  tmpSummary = tmpSummary[tmpSummary$LocationId==tmpIds,]
  sum(tmpSummary$LocationId==tmpIds)
  ggplot(tmpSummary[tmpSummary$LocationId==tmpIds,], aes(ResultYear, EcoliResult, color = "blue")) +
    geom_point() +
    geom_line() +
    ggtitle(paste0(name, note,": Annual median Escherichia coli levels")) +
    xlab("Year") + ylab("E.coli MPN") +
    scale_x_continuous(n.breaks = max(tmpSummary$ResultYear) - min(tmpSummary$ResultYear)) +
    theme_classic() +
    theme(legend.position = "none")
}

# Boxplot of E.coli  levels for all years on record at a given location
ecoliBoxPlotWQoverview <- function(locationList, bData, location, note = "") {
  
  tmpIds=locationList[grep(location, locationList$Name),]$LocationId[1]
  name=epaBathingLocations[grep(location, epaBathingLocations$Name),]$Name[1]
  
  
  tmpSummary = bData %>%
    group_by(LocationId, ResultYear)%>% 
    summarise(EcoliResult=median(EcoliResult))
  
  tmpSummary = tmpSummary[tmpSummary$LocationId==tmpIds,]
  
  bData = bData[bData$LocationId==tmpIds,]
  
  ggplot(bData[bData$LocationId==tmpIds,], aes(factor(ResultYear), EcoliResult)) +
    ggtitle(paste0(name, note,": Annual median Escherichia coli levels")) +
    geom_boxplot(outlier.shape = NA, fill = "lightblue") +
    geom_jitter(width = 0.05, colour = "red", alpha = 0.8) +
    xlab("Year") + ylab(expression(paste(italic("Escherichia coli"), " MPN"))) +
    theme_classic() +
    theme(legend.position = "none")
}

# Plot E.coli  levels for all years on record at a given location
ecoliDualPlotWQoverview <- function(locationList, bData, location, note = "") {
  tmpIds=locationList[grep(location, locationList$Name),]$LocationId[1]
  name=epaBathingLocations[grep(location, epaBathingLocations$Name),]$Name[1]
  
  
  tmpSummary = bData %>%
    group_by(LocationId, ResultYear)%>% 
    summarise(EcoliResult=median(EcoliResult))
  
  tmpSummary = tmpSummary[tmpSummary$LocationId==tmpIds,]
  
  bData = bData[bData$LocationId==tmpIds,]
  
  #  sum(tmpSummary$LocationId==tmpIds)
  #  ggplot(bData[bData$LocationId==tmpIds,], aes(ResultYear, EcoliResult, color = "blue")) +
  ggplot() +
    #  geom_point() +
    geom_line(data=tmpSummary[tmpSummary$LocationId==tmpIds,], aes(ResultYear, EcoliResult), color = "blue") +
    geom_point(data=bData[bData$LocationId==tmpIds,], aes(ResultYear, EcoliResult), color = "red") +
    ggtitle(paste0(name, note,": Annual median Escherichia coli levels")) +
    xlab("Year") + ylab("E.coli MPN") +
    scale_x_continuous(n.breaks = max(tmpSummary$ResultYear) - min(tmpSummary$ResultYear)) +
    theme_classic() +
    theme(legend.position = "none")
}

# Plot Enterococci median levels for all years on record at a given location
enterococciWQoverview <- function(locationList, bData, location, note = "") {
  tmpIds=locationList[grep(location, locationList$Name),]$LocationId[1]
  name=epaBathingLocations[grep(location, epaBathingLocations$Name),]$Name[1]
  
  tmpSummary = bData %>%
    group_by(LocationId, ResultYear)%>% 
    summarise(EnterococciResult=median(EnterococciResult))
  
  tmpSummary = tmpSummary[tmpSummary$LocationId==tmpIds,]
  sum(tmpSummary$LocationId==tmpIds)
  ggplot(tmpSummary[tmpSummary$LocationId==tmpIds,], aes(ResultYear, EnterococciResult, color = "blue")) +
    geom_point() +
    geom_line() +
    ggtitle(paste0(name, note,": Yearly Enterococci median levels")) +
    xlab("Year") + ylab("Enterococci MPN") +
    scale_x_continuous(n.breaks = max(tmpSummary$ResultYear) - min(tmpSummary$ResultYear)) +
    theme_classic() +
    theme(legend.position = "none")
}

# Plot E.coli time-weighted seasonal means overview  
ecoliWqTwsmOverview <- function(locationList, bData, location, note = "") {
  tmpIds=locationList[grep(location, locationList$Name),]$LocationId[1]
  name=epaBathingLocations[grep(location, epaBathingLocations$Name),]$Name[1]
  
  tmpSummary = bData %>%
    group_by(LocationId, ResultYear)%>% 
    summarise(EcoliResult=trapMean(hoursSinceSeasonMonitoringStart, EcoliResult))
  
  tmpSummary = tmpSummary[tmpSummary$LocationId==tmpIds,]
  sum(tmpSummary$LocationId==tmpIds)
  ggplot(tmpSummary[tmpSummary$LocationId==tmpIds,], aes(ResultYear, EcoliResult, color = "blue")) +
    geom_point() +
    geom_line() +
    ggtitle(paste0(name, note,": Time-weighted seasonal E.coli mean levels")) +
    xlab("Year") + ylab("E.coli MPN") +
    scale_x_continuous(n.breaks = max(tmpSummary$ResultYear) - min(tmpSummary$ResultYear)) +
    theme_classic() +
    theme(legend.position = "none")
}

# Plot Enterococci time-weighted seasonal means overview
enterococciWqTwsmOverview <- function(locationList, bData, location, note = "") {
  tmpIds=locationList[grep(location, locationList$Name),]$LocationId[1]
  name=epaBathingLocations[grep(location, epaBathingLocations$Name),]$Name[1]
  
  tmpSummary = bData %>%
    group_by(LocationId, ResultYear)%>% 
    summarise(EnterococciResult= trapMean(hoursSinceSeasonMonitoringStart, EnterococciResult))
  
  tmpSummary = tmpSummary[tmpSummary$LocationId==tmpIds,]
  sum(tmpSummary$LocationId==tmpIds)
  ggplot(tmpSummary[tmpSummary$LocationId==tmpIds,], aes(ResultYear, EnterococciResult, color = "blue")) +
    geom_point() +
    geom_line() +
    ggtitle(paste0(name, note,": Yearly Enterococci median levels")) +
    xlab("Year") + ylab("Enterococci MPN") +
    scale_x_continuous(n.breaks = max(tmpSummary$ResultYear) - min(tmpSummary$ResultYear)) +
    theme_classic() +
    theme(legend.position = "none")
}

# Estimate driver densities within a given impact zone around a waterbody.
driverDensitiesAroundLake <- function(loughPolySf, buffSizeMtrs, totalUnitsName, dataset)
{
  ###
  #loughPolySf=loughMuckno
  #totalUnits="totalCattle"
  #buffSizeMtrs=800000
  #dataset=edSfAVA42
  ###
  ###
  #  loughPolySf=loughMuckno
  #  totalUnits="individualSepticTank"
  #  buffSizeMtrs=40000
  #  dataset=edSfSAP2022T6T7ED_2022
  ###
  totalUnitsPerSqKm = paste0(totalUnitsName,"PerKm")
  
  tmpDrDs = dataset
  
  # Get the subset of ED's that intersect the lake.
  # Update their geometries to remove the lake from the ED
  # (as we assume there will be no units - for example cattle -
  # located in the lake itself)
  edSubset=unique(unlist(st_intersects(loughPolySf,tmpDrDs)))
  
  edSubsetMinusLakeArea = st_difference(tmpDrDs[edSubset,],loughPolySf)
  tmpDrDs[edSubset,]$geometry = edSubsetMinusLakeArea$geometry
  
  # Eyeball to make sure all as expected.
  # print(tm_shape(edSfAVA42[edSubset,]) + tm_borders(col="red", lwd = 2) +
  #    tm_shape(loughPolySf) + tm_borders(fill="#0000FF33", lwd = 2))
  
  # print(tm_shape(tmpDrDs[edSubset,]) + tm_borders(col="green", lwd = 2) +
  #    tm_shape(loughPolySf) + tm_borders(fill="#0000FF33", lwd = 2))
  
  # Recalculate the unit (ie.,cattle) densities without including the lake area.  
  # Recalculate ED areas
  tmpDrDs[edSubset,]$area = st_area(tmpDrDs[edSubset,])
  units(tmpDrDs$area) <- c() # remove units
  
  # OK, for Lough Muckno the changes ended up being small,
  # but we needed to do the calculation to be sure.
  
  # Draw a buffer of X metres from the lake edge around the lake and find the
  # unit (ie.,cattle) density within it.
  xMtrBuffer = st_difference(st_buffer(loughPolySf,buffSizeMtrs),loughPolySf)
  xMtrBuffer = st_intersection(tmpDrDs,xMtrBuffer)
  
  # Recalculate fraction of total unit (ie.,cattle) numbers in each ED subset within that buffer
  xMtrBuffer$areaFraction = st_area(xMtrBuffer)/xMtrBuffer$area
  units(xMtrBuffer$areaFraction) <- c() # remove units
  
  totalBufferArea = sum(st_area(xMtrBuffer))
  units(totalBufferArea) <- c() # remove units
  
  # Get the overall unit (ie.,cattle) density within that X metre (from the lake edge) buffer
  overallxMtrBufferDensity =  10^6 * sum(xMtrBuffer$areaFraction * data.frame(xMtrBuffer)[,c(totalUnitsName)] ,na.rm=TRUE)/totalBufferArea
  return(overallxMtrBufferDensity)
  
}

# This function contacts the OSRM server to get a route line by car, from a to b.
# crs 4326
# Use responsibly. Store result & reuse as required. Only call when needed.
getOsrmRouteAtoB <- function(ax,ay,bx,by)
{
  sysCmd = paste0("wget -O- \"https://router.project-osrm.org/route/v1/driving/",ax,",",ay,";",bx,",",by,"?geometries=geojson&alternatives=false&steps=true&generate_hints=false\"");
  jStr = system(sysCmd, intern = TRUE);
  
  coords=as.numeric(unlist(fromJSON(json_str = jStr)$routes[[1]]$geometry$coordinates))
  routePoints=data.frame(x=coords[seq(from = 1, to = length(coords), by = 2)],
                         y=coords[seq(from = 2, to = length(coords), by = 2)])
  
  routePoints=st_as_sf(routePoints,
                       coords = c("x","y"),
                       crs = 4326)
  
  routeLine <- st_sfc(st_linestring(st_coordinates(routePoints)))
  st_crs(routeLine) = 4326
  
  return(routeLine)
  
}

irlTowns = st_as_sf(read.csv("DATA/ie.csv", header = TRUE),
                    coords = c("lng","lat"),
                    crs = 4326)

irlTowns=irlTowns[grepl("^Dublin|Athlone|Galway|Tuam| Ballinasloe|Limerick|Ennis|Tralee|Waterford|Castlebar|Westport|Sligo|Cavan|Monaghan|Athlone|Newbridge|Naas|Cork|Cobh|Youghal|Tipperary|Killarney|Clonmel|Letterkenny|Wexford|Waterford|Wicklow|Kilkenny|Carlow", irlTowns$city),]

# If a routes map does not exist for the background base layer then create it.

if (!file.exists("DATA/routeCollection.geojson")) {
  
  mainTownsIdx=grepl("^Dublin|Galway|Limerick|Cork|Castlebar|Cavan|Monaghan|Tralee|Letterkenny", irlTowns$city)
  secodnTownsIdx=!mainTownsIdx
  
  routesFromAtoListOfBs = function(mainTown,towns)
  {
    otherTownsIdx=!grepl(mainTown, towns$city)
    print(otherTownsIdx)
    return
    ax=unname(st_coordinates(towns[!otherTownsIdx,]$geometry)[,"X"])
    ay=unname(st_coordinates(towns[!otherTownsIdx,]$geometry)[,"Y"])
    ax;ay
    
    routeCollection=c()
    for(i in which(otherTownsIdx))
    {
      print(paste0("Processing ",towns[i,]$city))
      
      bx=unname(st_coordinates(towns[i,]$geometry)[,"X"])
      by=unname(st_coordinates(towns[i,]$geometry)[,"Y"])
      
      route=getOsrmRouteAtoB(ax,ay,bx,by)
      routeCollection = rbind(routeCollection,route)
    }
    routeCollection
  }
  
  
  # Put routes of the base map together.
  routeCollection=c()
  
  routeCollection = routesFromAtoListOfBs("Dublin",irlTowns)
  
  routeCollection2 = routesFromAtoListOfBs("Galway",irlTowns[(!grepl("Dublin", irlTowns$city)),])
  routeCollection = rbind(routeCollection,routeCollection2)
  
  routeCollection2 = routesFromAtoListOfBs("Cork",irlTowns[(!grepl("Dublin|Galway", irlTowns$city)),])
  routeCollection = rbind(routeCollection,routeCollection2)
  
  # Use this to create an sf object
  routeCollection = st_as_sf(data.frame(routeCollection),
                             crs = 4326)
  
  st_write(st_transform(routeCollection, crs=4326), "DATA/routeCollection.geojson")
  
}
routeCollection=st_read("DATA/routeCollection.geojson")


# Base map of Rep. Ireland coastline
if (!file.exists("DATA/Coast___OSi_National_250k_Map_Of_Ireland.geojson")) {
  # Then download it
  system("wget -O DATA/Coast___OSi_National_250k_Map_Of_Ireland.geojson 'https://services-eu1.arcgis.com/FH5XCsx8rYXqnjF5/arcgis/rest/services/Coast___OSi_National_250k_Map_Of_Ireland/FeatureServer/0/query?where=&geometry=%7B-10.66%2C51.39%2C-5.43%2C+55.43%7D&geometryType=esriGeometryEnvelope&inSR=4326&spatialRel=esriSpatialRelContains&resultType=none&distance=0.0&units=esriSRUnit_Meter&returnGeodetic=false&outFields=Shape__Length&returnGeometry=true&returnEnvelope=false&featureEncoding=esriDefault&multipatchOption=xyFootprint&applyVCSProjection=false&returnIdsOnly=false&returnUniqueIdsOnly=false&returnCountOnly=false&returnExtentOnly=false&returnQueryGeometry=false&returnDistinctValues=false&cacheHint=false&returnAggIds=false&returnZ=false&returnM=false&returnTrueCurves=false&returnExceededLimitFeatures=true&sqlFormat=none&f=pgeojson'")
}
repIrl = st_read("DATA/Coast___OSi_National_250k_Map_Of_Ireland.geojson")

# Base map of Northern Ireland polygon
if (!file.exists("DATA/OSNI_Open_Data_-_Largescale_Boundaries_-_NI_Outline.geojson")) {
  # Then download it
  system("wget -O DATA/OSNI_Open_Data_-_Largescale_Boundaries_-_NI_Outline.geojson 'https://admin.opendatani.gov.uk/dataset/1f472693-2c20-483c-b367-b42382b83886/resource/ec752797-02df-43eb-bdeb-f74838771df3/download/osni_open_data_largescale_boundaries_ni_outline.geojson'")
}
NorthernIrl = st_read("DATA/OSNI_Open_Data_-_Largescale_Boundaries_-_NI_Outline.geojson")

# Also download some urban ED boundaries of interest later in our analysis

# Get Castleblayney town boundary
if (!file.exists("DATA/castleblayneyUrbanEd.geojson")) {
  # Then download it
  q = add_osm_feature(opq=opq("Castleblayney, Ireland"), key = "boundary", value = "administrative")
  castleblayneyUrbanEd=osmdata_sf(q)
  castleblayneyUrbanEd = castleblayneyUrbanEd$osm_multipolygons[
    castleblayneyUrbanEd$osm_multipolygons$name=="Castleblaney Urban ED",
  ]
  st_write(castleblayneyUrbanEd, dsn = "DATA/castleblayneyUrbanEd.geojson", layer = "castleblayneyUrbanEd.geojson")
} else {
  castleblayneyUrbanEd = st_read("DATA/castleblayneyUrbanEd.geojson")
}  

# Add context, Carlow
if (!file.exists("DATA/carlow.geojson")) {
  # Then download it
  #q = add_osm_feature(opq=opq("Carlow, Ireland"),key = "name", value = "Carlow")
  q = add_osm_feature(opq=opq("Carlow, Ireland"), key = "logainm:ref", value = "3195")
  carlow=osmdata_sf(q)
  carlow = carlow$osm_multipolygons[
    carlow$osm_multipolygons$name=="Carlow",
  ]
  st_write(carlow, dsn = "DATA/carlow.geojson", layer = "carlow.geojson")
} else {
  carlow = st_read("DATA/carlow.geojson")
}

# Graigue
if (!file.exists("DATA/graigue.geojson")) {
  # Then download it
  q = add_osm_feature(opq=opq("Ireland"), key = "logainm:ref", value = "28856")
  graigue=osmdata_sf(q)
  graigue = graigue$osm_multipolygons[
    graigue$osm_multipolygons$name=="Graigue",
  ]
  st_write(graigue, dsn = "DATA/graigue.geojson", layer = "graigue.geojson")
} else {
  graigue = st_read("DATA/graigue.geojson")
}

# Graigue Urban ED
# Add context, GraigueUrbanED
if (!file.exists("DATA/graigueUrbanED.geojson")) {
  # Then download it
  q = add_osm_feature(opq=opq("Ireland"), key = "ref", value = "1002")
  graigueUrbanED=osmdata_sf(q)
  graigueUrbanED = graigueUrbanED$osm_multipolygons[
    graigueUrbanED$osm_multipolygons$name=="Graigue Urban ED",
  ]
  st_write(graigueUrbanED, dsn = "DATA/graigueUrbanED.geojson", layer = "graigueUrbanED.geojson")
} else {
  graigueUrbanED = st_read("DATA/graigueUrbanED.geojson")
}


# Add context, Leighlinbridge
if (!file.exists("DATA/leighlinbridge.geojson")) {
  # Then download it
  q = add_osm_feature(opq=opq("Leighlinbridge, Ireland"), key = "ref:name", value = "Leighlinbridge")
  leighlinbridge=osmdata_sf(q)
  leighlinbridge = leighlinbridge$osm_multipolygons
  st_write(leighlinbridge, dsn = "DATA/leighlinbridge.geojson", layer = "leighlinbridge.geojson")
} else {
  leighlinbridge = st_read("DATA/leighlinbridge.geojson")
}

# Add context, Bagenalstown
if (!file.exists("DATA/bagenalstown.geojson")) {
  # Then download it
  q = add_osm_feature(opq=opq("Ireland"), key = "name", value = "Muinebeag Urban ED")
  bagenalstown=osmdata_sf(q)
  bagenalstown = bagenalstown$osm_multipolygons
  st_write(bagenalstown, dsn = "DATA/bagenalstown.geojson", layer = "bagenalstown.geojson")
} else {
  bagenalstown = st_read("DATA/bagenalstown.geojson")
}

# Get Buncrana boundary for context
if (!file.exists("DATA/buncranaBoundary.geojson")) {
  # Then download it
  q = add_osm_feature(opq=opq("Buncrana, Ireland"), key = "boundary", value = "census")
  buncranaBoundary=osmdata_sf(q)
  buncranaBoundary = buncranaBoundary$osm_multipolygons 
  st_write(buncranaBoundary, dsn = "DATA/buncranaBoundary.geojson", layer = "buncranaBoundary.geojson")
} else {
  buncranaBoundary = st_read("DATA/buncranaBoundary.geojson")
}  




