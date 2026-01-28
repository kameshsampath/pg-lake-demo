-- Create a foreign table using pg_lake to read Parquet files from S3
-- Note: Empty schema '()' triggers automatic schema inference
DROP FOREIGN TABLE IF EXISTS penguins_raw;

CREATE FOREIGN TABLE penguins_raw() 
SERVER pg_lake 
OPTIONS (path 's3://my-lake/raw/penguins.parquet');

-- Verify the structure
\d penguins_raw

-- Select data
SELECT * FROM penguins_raw LIMIT 5;
