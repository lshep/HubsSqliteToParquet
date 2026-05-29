args <- commandArgs(trailingOnly = TRUE)

if(length(args) == 0) {
    stop("Usage: Rscript sqlite_to_parquet.R <annotationhub|experimenthub>")
}

hub <- args[1]

source("pipeline/hubs.R")
source("pipeline/utils.R")


cfg <- get_hub_config(hub)


library(DBI)
library(duckdb)

dir.create(cfg$parquet_dir, recursive = TRUE, showWarnings = FALSE)

message("Connecting DuckDB...")
con <- dbConnect(duckdb::duckdb(), dbdir = ":memory:")
on.exit(
    try(dbDisconnect(con, shutdown = TRUE), silent = TRUE),
    add = TRUE
)

dbExecute(con, "INSTALL sqlite")
dbExecute(con, "LOAD sqlite")

assert_file_exists(cfg$sqlite_file)

message("Attaching SQLite: ", cfg$sqlite_file)

attach_name <- cfg$name
fail_if(grepl("[^a-zA-Z0-9_]", attach_name), "Unsafe attach_name detected")

dbExecute(con, sprintf(
    "ATTACH '%s' AS %s (TYPE SQLITE)",
    cfg$sqlite_file,
    attach_name
))

dbs <- dbGetQuery(con, "SHOW DATABASES")$database

fail_if(
  !attach_name %in% dbs,
  "SQLite attach failed — database not found after ATTACH"
)

message("Discovering tables...")
tables <- dbGetQuery(con, "SHOW ALL TABLES")

table_col <- "name"
fail_if(!table_col %in% names(tables),
        sprintf("Unexpected SHOW ALL TABLES format: missing '%s' column",table_col))

tables <- subset(
    tables,
    database == attach_name
)

assert_non_empty(tables, "SQLite table listing")

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
    fail_if(!file.exists(out_file), paste("Failed to create parquet:", out_file))
    size <- file.info(out_file)$size
    fail_if(is.na(size) || size == 0, paste("Invalid parquet output:", out_file))
}
expected_files <- paste0(tables[[table_col]], ".parquet")
missing_files <- expected_files[
    !file.exists(file.path(cfg$parquet_dir, expected_files))
]
fail_if(length(missing_files) > 0,
    paste("Missing parquet outputs:", paste(missing_files, collapse = ", "))
)
message("Parquet export complete for ", cfg$name)
quit(status = 0)
