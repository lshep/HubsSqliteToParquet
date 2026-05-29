library(DBI)
library(duckdb)

con <- dbConnect(duckdb())

dbExecute(con, "INSTALL sqlite")
dbExecute(con, "LOAD sqlite")

dbExecute(con,
    "
    ATTACH 'data/annotationhub.sqlite3'
    AS ahdb (TYPE SQLITE)
    "
)

dir.create("parquet", recursive=TRUE, showWarnings = FALSE)

tables <- dbGetQuery(con, "SHOW ALL TABLES")
tables <- subset(
    tables,
    database == "ahdb"
)

for (tbl in tables$name) {

    outfile <- sprintf("parquet/%s.parquet", tbl)

    sql <- sprintf("
        COPY ahdb.%s
        TO '%s'
        (FORMAT PARQUET)
        ", tbl, outfile)

    message(sql)

    dbExecute(con, sql)
}

dbDisconnect(con, shutdown = TRUE)
