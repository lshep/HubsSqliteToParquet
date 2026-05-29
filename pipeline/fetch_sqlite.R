args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
    stop("Usage: Rscript fetch_sqlite.R <annotationhub|experimenthub>")
}

hub <- args[1]

source("pipeline/hubs.R")
cfg <- get_hub_config(hub)

dir.create(dirname(cfg$sqlite_file), recursive = TRUE, showWarnings = FALSE)

message("Downloading: ", cfg$name)
message("From URL: ", cfg$url)
message("To file: ", cfg$sqlite_file)

download.file(
    url = cfg$url,
    destfile = cfg$sqlite_file,
    mode = "wb"
)

message("Download complete for ", cfg$name)
