# PRISMA_2023PSSRC925

## Data download and setup.
This directory contains the scripts required to download and process the primary geospatial datasets used in the study of environmental antimicrobial resistance (AMR) in the Republic of Ireland. Data are sourced from government agencies including the EPA, DAFM (via the Marine Institute / Foras na Mara), and the CSO.

The scripts will also install and load the R packages required to access and process these datasets.

To begin, run the following R script:

```
# Open and run in R studio or alternatively, from the command line with the directory downloaded from github

Rscript ./loadDataExample.R
```

Data is stored in the 'DATA' directory. See the script `primaryAmrDriverDataDownload.R` for more details.
