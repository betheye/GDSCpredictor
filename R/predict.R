#' Internal prediction logic for XGBoost
#' @importFrom dplyr case_when
#' @importFrom stats predict
#' @importFrom utils read.csv
#' @noRd
.predict_xgboost <- function(input_data) {
    # Encode features (onehot_freq_target)
    encoded_matrix <- encode_features(input_data, strategy = "onehot_freq_target")

    # Load model
    model_path <- .load_resource("xgb_onehot_freq_target.json")
    model <- xgboost::xgb.load(model_path)

    # Predict
    preds_ln_ic50 <- predict(model, encoded_matrix)

    return(preds_ln_ic50)
}

#' Internal prediction logic for Ridge regression
#' @importFrom glmnet glmnet
#' @noRd
.predict_ridge <- function(input_data) {
    # Encode features (onehot_only for generalization)
    encoded_matrix <- encode_features(input_data, strategy = "onehot_only")

    # Load Ridge model
    model_path <- .load_resource("ridge_onehot_only.RData")
    load(model_path) # loads the glmnet model

    # Get model object
    model_vars <- ls()
    model_var <- setdiff(model_vars, c("model_path", "input_data", "encoded_matrix"))
    ridge_model <- get(model_var[1])

    # Predict using glmnet
    preds_ln_ic50 <- as.vector(predict(ridge_model, as.matrix(encoded_matrix)))

    return(preds_ln_ic50)
}

#' Internal prediction logic with model selection
#' @noRd
.predict_internal <- function(input_data, model = c("xgboost", "ridge")) {
    model <- match.arg(model)

    # Dispatch to appropriate model
    preds_ln_ic50 <- switch(model,
        "xgboost" = .predict_xgboost(input_data),
        "ridge" = .predict_ridge(input_data)
    )

    # Output results
    results <- input_data
    results$Predicted_LN_IC50 <- round(preds_ln_ic50, 4)
    results$Predicted_IC50 <- round(exp(preds_ln_ic50), 4)

    results$Sensitivity_Status <- dplyr::case_when(
        results$Predicted_LN_IC50 < -2.3 ~ "High Sensitivity",
        results$Predicted_LN_IC50 > 2.3 ~ "Resistant",
        TRUE ~ "Moderate"
    )

    results$Model_Used <- model

    return(results)
}

#' Single Data Point Prediction
#'
#' Predicts IC50 for a single cell line - drug pair.
#'
#' @param input_data A data frame valid for encoding, must contain exactly 1 row.
#'   \strong{Required Columns:}
#'   \itemize{
#'     \item \code{Tissue}: Primary tissue of origin (e.g., "breast", "lung").
#'     \item \code{Sub_Tissue}: More specific tissue descriptor (e.g., "lung_NSCLC").
#'     \item \code{Cancer_Type}: TCGA cancer classification code (e.g., "BRCA", "LUAD").
#'     \item \code{MSI_Status}: Microsatellite Instability status ("MSS/MSI-L" or "MSI-H").
#'     \item \code{Drug_Target}: The molecular target of the drug (e.g., "TOP1", "EGFR").
#'     \item \code{Target_Pathway}: The biological pathway targeted (e.g., "DNA replication").
#'   }
#' @param model Character string specifying the model to use. Options:
#'   \itemize{
#'     \item \code{"xgboost"} (default): Efficiency Specialist (Mixed Encoding). Balanced speed/accuracy.
#'     \item \code{"ridge"}: Generalization Specialist (One-Hot). Best for novel drugs (LODO RMSE ~1.18).
#'   }
#' @return A data frame with prediction results including Predicted_IC50, Sensitivity_Status, and Model_Used.
#' @examples
#' \dontrun{
#' single_case <- data.frame(
#'     Tissue = "breast", Sub_Tissue = "breast",
#'     Cancer_Type = "BRCA", MSI_Status = "MSS/MSI-L",
#'     Drug_Target = "TOP1", Target_Pathway = "DNA replication",
#'     stringsAsFactors = FALSE
#' )
#' res <- predict_single_sensitivity(single_case)
#' print(res)
#'
#' # Use Ridge for better generalization to novel drugs
#' res_ridge <- predict_single_sensitivity(single_case, model = "ridge")
#' }
#' @export
predict_single_sensitivity <- function(input_data, model = c("xgboost", "ridge")) {
    model <- match.arg(model)
    if (nrow(input_data) != 1) {
        stop("predict_single_sensitivity expects exactly 1 row of data. Use predict_batch_sensitivity for multiple rows.")
    }
    return(.predict_internal(input_data, model = model))
}

#' Batch Prediction
#'
#' Predicts IC50 for multiple cell line - drug pairs using optimized batch processing.
#'
#' @param input_data A data frame containing multiple rows of features.
#'   See \code{\link{predict_single_sensitivity}} for the list of required columns.
#' @param model Character string specifying the model to use. Options:
#'   \itemize{
#'     \item \code{"xgboost"} (default): Best speed-accuracy trade-off
#'     \item \code{"ridge"}: Ridge regression, best generalization
#'   }
#' @return A data frame with prediction results appended.
#' @examples
#' \dontrun{
#' # Load the example dataset bundled with the package
#' example_path <- system.file("extdata", "batch_input_example.csv", package = "GDSCpredictor")
#' batch_data <- read.csv(example_path)
#'
#' # Run batch prediction with default XGBoost
#' res <- predict_batch_sensitivity(batch_data)
#' head(res)
#'
#' # Compare with Ridge predictions
#' res_ridge <- predict_batch_sensitivity(batch_data, model = "ridge")
#' }
#' @export
predict_batch_sensitivity <- function(input_data, model = c("xgboost", "ridge")) {
    model <- match.arg(model)
    if (nrow(input_data) < 1) {
        stop("Input data is empty.")
    }
    return(.predict_internal(input_data, model = model))
}
