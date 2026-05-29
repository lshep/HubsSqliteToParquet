args <- commandArgs(trailingOnly = TRUE)

if(length(args) == 0) {
    stop("Usage: Rscript sqlite_to_parquet.R <annotationhub|experimenthub>")
}

hub <- args[1]

source("pipeline/hubs.R")

cfg <- get_hub_config(hub)


library(DBI)
library(duckdb)

dir.create(cfg$parquet_dir, recursive = TRUE, showWarnings = FALSE)

message("Connecting DuckDB...")
con <- dbConnect(duckdb::duckdb(), dbdir = ":memory:")

dbExecute(con, "INSTALL sqlite")
dbExecute(con, "LOAD sqlite")

message("Attaching SQLite: ", cfg$sqlite_file)
attach_name <- cfg$name
dbExecute(con, sprintf(
    "ATTACH '%s' AS %s (TYPE SQLITE)",
    cfg$sqlite_file,
    attach_name
))

message("Discovering tables...")
tables <- dbGetQuery(con, "SHOW ALL TABLES")
tables <- subset(
    tables,
    database == attach_name
)

if (nrow(tables) == 0) {
    stop("No tables found in attached SQLite database")
}

table_col <- "name"
if (!table_col %in% names(tables)) {
    stop(sprintf(
        "Unexpected SHOW ALL TABLES format: missing '%s' column",
        table_col
    ))
}


for(tbl in tables[[table_col]]) {

    out_file <- file.path(cfg$parquet_dir, paste0(tbl, ".parquet"))
    message("Exporting: ", tbl)
    sql <- sprintf(
        "COPY %s.%s TO '%s' (FORMAT PARQUET)",
        attach_name,
        tbl,
        out_file
    )
    dbExecute(con, sql)
}

dbDisconnect(con, shutdown = TRUE)
message("Parquet export complete for ", cfg$name)
