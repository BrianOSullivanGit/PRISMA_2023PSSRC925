# Source this file before starting your analysis to load primary AMR driver datasets.

# Specify the time frame for bathing water quality assessment.
# The period includes data from the start year up to and including the end year.
# Modify this range and re-run as required.
yearStart=2020
yearEnd=2025

source("primaryAmrDriverDataDownload.R")

# Comment out as required if you need to store any of these datasets as WKT/CVS
# (to export to another geospatial database etc.)

# st_write(csoEdAVA42,"csoEdAVA42.csv", layer_options = "GEOMETRY=AS_WKT");
# st_write(csoEdSAP2022T6T7ED,"csoEdSAP2022T6T7ED.csv", layer_options = "GEOMETRY=AS_WKT");
# st_write(wwEp,"wwEp.csv", layer_options = "GEOMETRY=AS_WKT");
# st_write(castleblayneyWwtpSf,"castleblayneyWwtpSf.csv", layer_options = "GEOMETRY=AS_WKT");
# st_write(ringsendWwtpSf,"ringsendWwtpSf.csv", layer_options = "GEOMETRY=AS_WKT");
# st_write(repIrl,"repIrl.csv", layer_options = "GEOMETRY=AS_WKT");
# st_write(NorthernIrl,"NorthernIrl.csv", layer_options = "GEOMETRY=AS_WKT");
# st_write(castleblayneyUrbanEd,"castleblayneyUrbanEd.csv", layer_options = "GEOMETRY=AS_WKT");
# st_write(carlow,"carlow.csv", layer_options = "GEOMETRY=AS_WKT");
# st_write(graigue,"graigue.csv", layer_options = "GEOMETRY=AS_WKT");
# st_write(graigueUrbanED,"graigueUrbanED.csv", layer_options = "GEOMETRY=AS_WKT");
# st_write(leighlinbridge,"leighlinbridge.csv", layer_options = "GEOMETRY=AS_WKT");
# st_write(bagenalstown,"bagenalstown.csv", layer_options = "GEOMETRY=AS_WKT");
# st_write(buncranaBoundary,"buncranaBoundary.csv", layer_options = "GEOMETRY=AS_WKT");
