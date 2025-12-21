#' Internal helper to load package data
#' @noRd
.load_resource <- function(filename) {
    path <- system.file("extdata", filename, package = "GDSCpredictor")
    if (path == "") stop("Resource not found: ", filename)
    return(path)
}

#' Encode Features for Prediction
#'
#' Applies specific encoding strategies (One-Hot, Frequency, Target) to raw input data
#' to prepare it for the XGBoost model.
#'
#' @param input_data A data frame containing the raw categorical features:
#'   \itemize{
#'     \item Tissue
#'     \item Sub_Tissue
#'     \item Cancer_Type
#'     \item MSI_Status
#'     \item Drug_Target
#'     \item Target_Pathway
#'   }
#' @return A numeric matrix with encoded features, ready for `xgb.predict`.
#' @examples
#' \dontrun{
#' sample_data <- data.frame(
#'     Tissue = "breast",
#'     Sub_Tissue = "breast",
#'     Encode_Test = "TRUE" # Dummy example
#' )
#' encoded <- encode_features(sample_data)
#' }
#' @export
encode_features <- function(input_data) {
    # Load encoding maps used during training
    onehot_mapping <- readRDS(.load_resource("onehot_mapping_robust.rds"))
    freq_maps <- readRDS(.load_resource("frequency_encoding_maps_robust.rds"))
    target_maps <- readRDS(.load_resource("target_encoding_maps_robust.rds"))
    feature_meta <- jsonlite::fromJSON(.load_resource("xgb_onehot_freq_target_meta.json"))

    encoded <- data.frame(row.names = 1:nrow(input_data))

    # 1. One-Hot Encoding
    for (col in names(onehot_mapping)) {
        if (col %in% colnames(input_data)) {
            categories <- onehot_mapping[[col]]
            # Skip reference category (last one usually) to avoid dummy trap if handled that way,
            # but here we follow exact logic from training: 1 to length-1
            for (i in 1:(length(categories) - 1)) {
                new_col_name <- paste0(col, "_", make.names(categories[i]))
                # Use as.integer for 0/1, handle NA
                val <- input_data[[col]] == categories[i]
                encoded[[new_col_name]] <- as.integer(ifelse(is.na(val), FALSE, val))
            }
        }
    }

    # 2. Frequency Encoding
    for (col in names(freq_maps)) {
        if (col %in% colnames(input_data)) {
            freq_map <- freq_maps[[col]]
            new_col_name <- paste0(col, "_FreqEnc")
            matched_idx <- match(input_data[[col]], freq_map[[col]])
            encoded[[new_col_name]] <- ifelse(is.na(matched_idx), 0, freq_map$frequency[matched_idx])
        }
    }

    # 3. Target Encoding
    for (col in names(target_maps)) {
        if (col %in% colnames(input_data)) {
            target_map <- target_maps[[col]]
            global_mean <- attr(target_map, "global_mean")
            new_col_name <- paste0(col, "_TargetEnc")
            matched_idx <- match(input_data[[col]], target_map[[col]])
            encoded[[new_col_name]] <- ifelse(is.na(matched_idx), global_mean, target_map$smoothed_mean[matched_idx])
        }
    }

    # 4. Fill Missing Model Features with 0
    expected_features <- feature_meta$feature_names
    for (f in expected_features) {
        if (!(f %in% colnames(encoded))) {
            encoded[[f]] <- 0
        }
    }

    # 5. Reorder to match model
    encoded <- encoded[, expected_features, drop = FALSE]

    return(as.matrix(encoded))
}
