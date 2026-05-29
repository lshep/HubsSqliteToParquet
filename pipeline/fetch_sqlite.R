url <- "https://annotationhub.bioconductor.org/metadata/annotationhub.sqlite3"
dest <- "data/annotationhub.sqlite3"
download.file(
    url,
    destfile = dest,
    mode = "wb"
)
