get_hub_config <- function(hub) {

    base_dir <- Sys.getenv("BASE_DIR", unset = NA)
    sqlite_dir <- Sys.getenv("SQLITE_DIR", unset = NA)
    
    if (is.na(base_dir) || base_dir == "") {
        base_dir <- file.path("parquet", hub)
    }
    
    if (is.na(sqlite_dir) || sqlite_dir == "") {
        sqlite_dir <- file.path("data", hub)
    }
    
    sqlite_file <- file.path(sqlite_dir, paste0(hub, ".sqlite3"))

    if (hub == "annotationhub") {

        list(
            name = "annotationhub",
            url = "https://annotationhub.bioconductor.org/metadata/annotationhub.sqlite3",
            sqlite_file = sqlite_file,
            parquet_dir = base_dir,
            osn_path = "bir190004-bucket01/AnnotationHub/AnnotationHub/parquet"
        )

    } else if (hub == "experimenthub") {

        list(
            name = "experimenthub",
            url = "https://experimenthub.bioconductor.org/metadata/experimenthub.sqlite3",
            sqlite_file = sqlite_file,
            parquet_dir = base_dir,
            osn_path = "bir190004-bucket01/ExperimentHub/ExperimentHub/parquet"
        )
    } else {
        stop("Unknown hub: ", hub)
    }
}
