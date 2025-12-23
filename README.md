# GDSCpredictor: Drug Sensitivity Prediction for Cancer Cell Lines

[![Shiny App](https://img.shields.io/badge/Shiny-Online%20Predictor-blue?logo=r)](https://bio215.shinyapps.io/gdsc_database_and_predictor_215/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Overview

**GDSCpredictor** is an R package for predicting cancer drug sensitivity (IC50) using machine learning. It provides a simple interface to pre-trained models (XGBoost, Ridge Regression) derived from the Genomics of Drug Sensitivity in Cancer (GDSC) dataset.

This package encapsulates the predictive logic of our [Analysis Pipeline](https://github.com/betheye/GDSCpipeline) and powers the [Shiny Web Application](https://bio215.shinyapps.io/gdsc_database_and_predictor_215/).

## Key Features

*   **⚡️ High Efficiency**: Default **XGBoost** model provides fast, accurate predictions.
*   **🔄 Robust Generalization**: **Ridge Regression** option for predicting novel drugs.
*   **🧬 Auto-Encoding**: Automatically handles categorical features (One-Hot, Frequency, Target Encoding).
*   **📦 Batch Processing**: Optimized for processing large datasets.

## Installation

Install directly from GitHub:

```r
# install.packages("devtools")
devtools::install_github("XinmiaoWu-xjtlu/GDSCpredictor")
```

## Quick Start

### 1. Load Package
```r
library(GDSCpredictor)
```

### 2. Predict Single Case
```r
# Define a cell line - drug pair
input_case <- data.frame(
    Tissue = "breast",
    Sub_Tissue = "breast",
    Cancer_Type = "BRCA",
    MSI_Status = "MSS/MSI-L",
    Drug_Target = "TOP1",
    Target_Pathway = "DNA replication",
    stringsAsFactors = FALSE
)

# Predict using XGBoost (Default)
result <- predict_single_sensitivity(input_case)
print(result[, c("Predicted_IC50", "Sensitivity_Status")])
```

### 3. Generalization to Novel Drugs
```r
# Use Ridge Regression for robust prediction of novel compounds
result_ridge <- predict_single_sensitivity(input_case, model = "ridge")
```

### 4. Batch Prediction
```r
# Predict for a dataframe of multiple samples
results <- predict_batch_sensitivity(large_dataframe, model = "xgboost")
head(results)
```

## 🧠 Model Portfolio

We provide two distinct models optimized for different research scenarios.

| Model | Encoding | RMSE | Best Use Case | Logic |
|-------|----------|------|---------------|-------|
| **XGBoost** (Default) | **Mixed** (Target+Freq+OneHot) | **1.11** | **Efficiency & Balance** | "Efficiency Specialist". Achieves high accuracy (R² = 0.838) but trains/predicts extremely fast. Perfect for web applications and large-scale screening. |
| **Ridge Regression** | **One-Hot Only** | **1.18** | **Generalization (Novel Drugs)** | "Mechanism Specialist". Relies *only* on biological features (no historical target encoding). **Outperforms complex models** on novel drugs (LODO RMSE 1.18 vs RF 1.76), making it the robust choice for new compounds. |

### Why these 2 models?

Our benchmark revealed a clear trade-off:

1.  **For Known Drugs**: **XGBoost** with Target Encoding provides excellent accuracy (RMSE ~1.11) and speed, making it the ideal default.
2.  **For Novel Drugs**: When historical data is unavailable, complex models overfit. **Ridge Regression with One-Hot encoding** proves most robust (RMSE 1.18), successfully capturing linear biological relationships without relying on leakage-prone artifacts.

> **Recommendation**: Use **XGBoost** for best performance on standard tasks. Switch to **Ridge (One-Hot)** if predicting for completely new drug compounds not in the GDSC database.

## Requirements

- R >= 4.0.0
- Packages: `xgboost`, `glmnet`, `dplyr`, `jsonlite`

## Citation

If you use this package, please cite our project repository:
[https://github.com/betheye/GDSCpipeline](https://github.com/betheye/GDSCpipeline)

## License

MIT License
