-- Create an Iceberg table that loads data from the Parquet files in S3
-- Environment variables are substituted via envsubst before execution

DROP TABLE IF EXISTS penguins_iceberg;

CREATE TABLE penguins_iceberg()
USING ICEBERG
WITH (load_from = 's3://${S3_BUCKET}/raw/*.parquet');

-- Inspect the structure
\d penguins_iceberg

-- Prove it is an Iceberg table by looking at metadata
SELECT catalog_name, table_namespace, table_name, metadata_location 
FROM iceberg_tables 
WHERE table_name = 'penguins_iceberg';
