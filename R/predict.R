#' Internal prediction logic
#' @importFrom dplyr case_when
#' @importFrom stats predict
#' @importFrom utils read.csv
#' @noRd
.predict_internal <- function(input_data) {
    # Encode features
    encoded_matrix <- encode_features(input_data)

    # Load model
    model_path <- .load_resource("xgb_onehot_freq_target.json")
    model <- xgboost::xgb.load(model_path)

    # Predict
    preds_ln_ic50 <- predict(model, encoded_matrix)

    # Output results
    results <- input_data
    results$Predicted_LN_IC50 <- round(preds_ln_ic50, 4)
    results$Predicted_IC50 <- round(exp(preds_ln_ic50), 4)

    results$Sensitivity_Status <- dplyr::case_when(
        results$Predicted_LN_IC50 < -2.3 ~ "High Sensitivity",
        results$Predicted_LN_IC50 > 2.3 ~ "Resistant",
        TRUE ~ "Moderate"
    )

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
#' @return A data frame with prediction results.
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
#' }
#' @export
predict_single_sensitivity <- function(input_data) {
    if (nrow(input_data) != 1) {
        stop("predict_single_sensitivity expects exactly 1 row of data. Use predict_batch_sensitivity for multiple rows.")
    }
    return(.predict_internal(input_data))
}

#' Batch Prediction
#'
#' Predicts IC50 for multiple cell line - drug pairs using optimized batch processing.
#'
#' @param input_data A data frame containing multiple rows of features.
#'   See \code{\link{predict_single_sensitivity}} for the list of required columns.
#' @return A data frame with prediction results appended.
#' @examples
#' \dontrun{
#' # Load the example dataset bundled with the package
#' example_path <- system.file("extdata", "batch_input_example.csv", package = "GDSCpredictor")
#' batch_data <- read.csv(example_path)
#'
#' # Run batch prediction
#' res <- predict_batch_sensitivity(batch_data)
#' head(res)
#' }
#' @export
predict_batch_sensitivity <- function(input_data) {
    if (nrow(input_data) < 1) {
        stop("Input data is empty.")
    }
    return(.predict_internal(input_data))
}
