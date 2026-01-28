-- Export to S3: Turn any PostgreSQL query into a data lake file
-- This shows pg_lake's bi-directional data flow capability

-- First, let's see what we have after the DELETE
SELECT species, count(*) as count 
FROM penguins_iceberg 
GROUP BY species 
ORDER BY species;

-- Export only Adelie penguins to S3 as Parquet
-- Anyone with S3 access can now read this with Spark, DuckDB, Python, etc.
COPY (
    SELECT * FROM penguins_iceberg 
    WHERE species = 'Adelie'
) TO 's3://${S3_BUCKET}/exports/adelie_penguins.parquet';

-- Export a summary report
COPY (
    SELECT 
        species,
        island,
        count(*) as count,
        round(avg(bill_length_mm)::numeric, 2) as avg_bill_length,
        round(avg(body_mass_g)::numeric, 0) as avg_body_mass
    FROM penguins_iceberg
    GROUP BY species, island
    ORDER BY species, island
) TO 's3://${S3_BUCKET}/exports/penguin_summary.parquet';

-- Verify the exports exist in S3
-- Run: task s3:list to see the new files
