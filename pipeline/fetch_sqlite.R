args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
    stop("Usage: Rscript fetch_sqlite.R <annotationhub|experimenthub>")
}

hub <- args[1]

source("pipeline/utils.R")
source("pipeline/hubs.R")

cfg <- get_hub_config(hub)

dir.create(dirname(cfg$sqlite_file), recursive = TRUE, showWarnings = FALSE)

message("Downloading: ", cfg$name)
message("From URL: ", cfg$url)
message("To file: ", cfg$sqlite_file)

ok <- tryCatch({
    download.file(url=cfg$url,
                  destfile=cfg$sqlite_file,
                  mode = "wb",
                  quiet = TRUE)
  TRUE
}, error = function(e) {
  message("Download error: ", e$message)
  FALSE
})

fail_if(!ok, "SQLite download failed")
assert_file_exists(cfg$sqlite_file)

library(DBI)
library(RSQLite)

db <- DBI::dbConnect(RSQLite::SQLite(), cfg$sqlite_file)
on.exit(DBI::dbDisconnect(db), add = TRUE)

fail_if(!DBI::dbIsValid(db), "SQLite connection is invalid")

tables <- DBI::dbListTables(db)

fail_if(length(tables) == 0,
        "SQLite file has no tables — download likely failed")
key_tables <- c("biocversions", "input_sources", "location_prefixes",
                "rdatapaths", "recipes", "resources", "statuses", "tags")
fail_if(!all(key_tables %in% tables), "SQLite file likely missing tables — corrupt download")

message("Download complete for ", cfg$name)
quit(status = 0)
