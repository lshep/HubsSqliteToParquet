args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
    stop("Usage: Rscript build_views.R <annotationhub|experimenthub>")
}

hub <- args[1]

source("pipeline/hubs.R")
cfg <- get_hub_config(hub)


library(DBI)
library(duckdb)

message("Building views for: ", cfg$name)

con <- dbConnect(duckdb::duckdb(), dbdir = ":memory:")

dbExecute(con, "INSTALL httpfs")
dbExecute(con, "LOAD httpfs")

parquet_base <- cfg$parquet_dir

message("Using parquet base: ", parquet_base)


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
          )
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

dbDisconnect(con, shutdown = TRUE)

message("Views build complete for ", cfg$name)
