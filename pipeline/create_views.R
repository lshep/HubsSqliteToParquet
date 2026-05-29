args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
    stop("Usage: Rscript build_views.R <annotationhub|experimenthub>")
}

hub <- args[1]

source("pipeline/hubs.R")
source("pipeline/utils.R")

cfg <- get_hub_config(hub)


library(DBI)
library(duckdb)

required_files <- c(
    "resources.parquet",
    "statuses.parquet",
    "rdatapaths.parquet",
    "location_prefixes.parquet"
)

parquet_base <- cfg$parquet_dir
message("Using parquet base: ", parquet_base)

required_paths <- file.path(parquet_base, required_files)
missing <- required_paths[!file.exists(required_paths)]
fail_if(length(missing) > 0,
        paste("Missing required parquet files:", paste(basename(missing), collapse = ", "))
        )

message("Building views for: ", cfg$name)

con <- dbConnect(duckdb::duckdb(), dbdir = ":memory:")
on.exit(
    try(dbDisconnect(con, shutdown = TRUE), silent = TRUE),
    add = TRUE
)

dbExecute(con, "INSTALL httpfs")
dbExecute(con, "LOAD httpfs")

message("Creating resource_metadata view")

## -- IMPORTANT: all non-aggregated SELECT columns must appear in GROUP BY
dbExecute(con,
          sprintf("
          CREATE VIEW resource_metadata AS
          SELECT
              r.id AS resource_id,
              r.ah_id,
              r.title,
              r.dataprovider,
              r.species,
              r.taxonomyid,
              r.genome,
              r.description,
              r.coordinate_1_based,
              r.maintainer,
              r.rdatadateadded,
              r.rdatadateremoved,
              r.preparerclass,

              s.status,
              
              lp.location_prefix,

              list(DISTINCT rp.rdataclass) AS rdataclass

          FROM read_parquet('%s/resources.parquet') r

          LEFT JOIN read_parquet('%s/statuses.parquet') s
              ON r.status_id = s.id

          LEFT JOIN read_parquet('%s/location_prefixes.parquet') lp
              ON r.location_prefix_id = lp.id

          LEFT JOIN read_parquet('%s/rdatapaths.parquet') rp
              ON r.id = rp.resource_id

          GROUP BY
              r.id,
              r.ah_id,
              r.title,
              r.dataprovider,
              r.species,
              r.taxonomyid,
              r.genome,
              r.description,
              r.coordinate_1_based,
              r.maintainer,
              r.rdatadateadded,
              r.rdatadateremoved,
              r.preparerclass,
              s.status,
              lp.location_prefix
          ",
          parquet_base,
          parquet_base,
          parquet_base,
          parquet_base
          ))

meta_check <- dbGetQuery(con, "
                         SELECT
                             COUNT(*) AS total_rows,
                             COUNT(DISTINCT resource_id) AS unique_resources
                         FROM resource_metadata
                         "
                         )

fail_if(meta_check$total_rows != meta_check$unique_resources,
        "resource_metadata is not one-row-per-resource"
        )

message("Creating resource_downloadlinks view")

dbExecute(con,
          sprintf("
          CREATE VIEW resource_downloadlinks AS
          SELECT
              rp.id AS rdatapath_id,
              rp.resource_id,

              r.ah_id,
              r.title,
              r.description,
              s.status,

              lp.location_prefix,
              rp.rdatapath,

              concat(coalesce(lp.location_prefix, ''), '/', rp.rdatapath) AS full_path,

              rp.rdataclass,
              rp.dispatchclass

          FROM read_parquet('%s/rdatapaths.parquet') rp

          LEFT JOIN read_parquet('%s/resources.parquet') r
              ON r.id = rp.resource_id

          LEFT JOIN read_parquet('%s/statuses.parquet') s
              ON r.status_id = s.id

          LEFT JOIN read_parquet('%s/location_prefixes.parquet') lp
              ON r.location_prefix_id = lp.id
          ",
          parquet_base,
          parquet_base,
          parquet_base,
          parquet_base
          )
)

download_check <- dbGetQuery(con, "
                             SELECT
                             COUNT(*) AS total_rows,
                             COUNT(DISTINCT rdatapath_id) AS unique_paths
                             FROM resource_downloadlinks
                             ")

fail_if(download_check$total_rows != download_check$unique_paths,
    "resource_downloadlinks contains duplicate rdatapath_id values"
    )

message("Creating resource_full view")

dbExecute(con, "
          CREATE VIEW resource_full AS
          SELECT
              d.rdatapath_id,
              d.resource_id,

              m.ah_id,
              m.title,
              m.dataprovider,
              m.species,
              m.taxonomyid,
              m.genome,
              m.description,
              m.coordinate_1_based,
              m.maintainer,
              m.rdatadateadded,
              m.rdatadateremoved,
              m.preparerclass,

              m.status,
              m.location_prefix,
              m.rdataclass,

              d.rdatapath,
              d.full_path,
              d.rdataclass AS file_rdataclass,
              d.dispatchclass

          FROM resource_downloadlinks d

          LEFT JOIN resource_metadata m
              ON m.resource_id = d.resource_id
          "
)

full_check <- dbGetQuery(con,
                         "
                         SELECT COUNT(*) AS n
                         FROM resource_full
                         ")

download_n <- dbGetQuery(con,
                         "
                         SELECT COUNT(*) AS n
                         FROM resource_downloadlinks
                         ")
fail_if(full_check$n != download_n$n,
    "resource_full row count mismatch with resource_downloadlinks"
)

message("Writing curated  views")
dir.create(cfg$parquet_dir, recursive = TRUE, showWarnings = FALSE)

full_file <- file.path(cfg$parquet_dir, "resource_full.parquet")
dbExecute(con,
          sprintf("
          COPY resource_full
          TO '%s'
          (FORMAT PARQUET)
          ",
          full_file))

download_file <- file.path(cfg$parquet_dir, "resource_downloadlinks.parquet")
dbExecute(con,
          sprintf("
          COPY resource_downloadlinks
          TO '%s'
          (FORMAT PARQUET)
          ",
          download_file))

meta_file <- file.path(cfg$parquet_dir, "resource_metadata.parquet")
dbExecute(con,
          sprintf("
          COPY resource_metadata
          TO '%s'
          (FORMAT PARQUET)
          ",
          meta_file))

output_files <- c(
    full_file,
    download_file,
    meta_file
)
for (f in output_files) {
    fail_if(!file.exists(f),
            paste("Missing output parquet:", f)
            )
    size <- file.info(f)$size
    fail_if(is.na(size) || size == 0,
            paste("Empty parquet output:", f)
            )
}

message("Views build complete for ", cfg$name)
quit(status = 0)
