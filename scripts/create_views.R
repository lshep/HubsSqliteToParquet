library(DBI)
library(duckdb)

con <- dbConnect(duckdb())

dbExecute(con,
          "
          CREATE VIEW resource_full AS
          SELECT
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

              rp.rdatapath,
              rp.rdataclass,
              rp.dispatchclass,

              b.biocversion

          FROM read_parquet('parquet/resources.parquet') r

          LEFT JOIN read_parquet('parquet/statuses.parquet') s
              ON r.status_id = s.id

          LEFT JOIN read_parquet('parquet/rdatapaths.parquet') rp
              ON r.id = rp.resource_id

          LEFT JOIN read_parquet('parquet/biocversions.parquet') b
              ON r.id = b.resource_id
          "
)


dbExecute(con,
          "
          COPY resource_full
          TO 'parquet/resource_full.parquet'
          (FORMAT PARQUET)
          "
)
