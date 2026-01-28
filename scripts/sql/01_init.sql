-- Enable the pg_lake extension
CREATE EXTENSION IF NOT EXISTS pg_lake CASCADE;

-- Set the default Iceberg storage location to use our bucket
-- Environment variables are substituted via envsubst before execution
ALTER SYSTEM SET pg_lake_iceberg.default_location_prefix = 's3://${S3_BUCKET}/pg_lake/';
SELECT pg_reload_conf();

-- Verify the setting
SHOW pg_lake_iceberg.default_location_prefix;
