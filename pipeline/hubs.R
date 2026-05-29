get_hub_config <- function(hub = c("annotationhub", "experimenthub")) {

    hub <- match.arg(hub)

    if (hub == "annotationhub") {

        list(
            name = "annotationhub",
            url = "https://annotationhub.bioconductor.org/metadata/annotationhub.sqlite3",
            sqlite_file = "data/annotationhub/annotationhub.sqlite3",
            parquet_dir = "parquet/annotationhub",
            osn_path = "bir190004-bucket01/AnnotationHub/AnnotationHub/parquet"
        )

    } else {

        list(
            name = "experimenthub",
            url = "https://experimenthub.bioconductor.org/metadata/experimenthub.sqlite3",
            sqlite_file = "data/experimenthub/experimenthub.sqlite3",
            parquet_dir = "parquet/experimenthub",
            osn_path = "bir190004-bucket01/ExperimentHub/ExperimentHub/parquet"
        )
    }
}
