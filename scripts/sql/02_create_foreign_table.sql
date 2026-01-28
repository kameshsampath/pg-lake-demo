-- Create a foreign table using pg_lake to read Parquet files from S3
-- Note: Empty schema '()' triggers automatic schema inference
-- Environment variables are substituted via envsubst before execution

DROP FOREIGN TABLE IF EXISTS penguins_raw;

CREATE FOREIGN TABLE penguins_raw() 
SERVER pg_lake 
OPTIONS (path 's3://${S3_BUCKET}/${S3_PARQUET_KEY}');

-- Verify the structure
\d penguins_raw

-- Select data
SELECT * FROM penguins_raw LIMIT 5;
