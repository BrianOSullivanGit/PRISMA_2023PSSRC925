# PRISMA_2023PSSRC925

## Reproducible Analysis Workflow
The R Markdown (Rmd) source files and associated R script in this GitHub directory provide a reproducible workflow for the analyses presented in the publication "Integrating GIS and Machine Learning to Map Environmental Antimicrobial Resistance Risk and Exposure Pathways in Irish Waters".

The analysis is performed in two steps:

**1)** Open `SomBathingWaterQualityAnalysis.Rmd` in RStudio and knit the document. This will execute `primaryAmrDriverDataDownload.R`, which loads the required R packages and geospatial datasets used in the study of environmental antimicrobial resistance (AMR) in the Republic of Ireland. The datasets are sourced from government agencies, including the EPA, DAFM (via the Marine Institute/Foras na Mara), and the CSO. Using these data, the R Markdown workflow generates SOM-derived pathogen level classifications from Irish bathing water quality data.

**2)** Open `CoastalAndSelecedInlandWatersRiskMaps.Rmd` in RStudio and knit the document. This analysis uses the pathogen level classifications generated in Step 1 to perform an AMR risk assessment of inland and coastal waters using source attribution and source-specific AMR risk weighting of routine bathing water microbiological monitoring data.

If you wish to download and stage the required datasets without running the full analysis, refer to the example script `loadDataExample.R`. The script downloads and stages the datasets required for the analysis for the date range 2020–2025 (the period examined in the publication), storing the output in the DATA directory. You may modify the date range specified in these files as required.

Run the script from the command line using:

```bash
Rscript ./loadDataExample.R
```
