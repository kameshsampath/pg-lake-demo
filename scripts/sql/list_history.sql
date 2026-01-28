-- =============================================================================
-- LIST TRANSACTION HISTORY
-- =============================================================================
-- Shows metadata versioning and deletion queue for penguins_iceberg
-- Helps understand how pg_lake tracks table history for time travel
--
-- IMPORTANT: deletion_queue behavior (from pg_lake engineering):
--   "Whenever a transaction commits, first the metadata_location becomes 
--    previous_metadata_location. Only when one MORE transaction commits, 
--    the previous_metadata_location is moved to deletion_queue.
--    To use deletion_queue you need more than 1 transaction."
--
-- Run via: task iceberg:list-history
-- =============================================================================

\echo ''
\echo '=== CURRENT & PREVIOUS METADATA ==='

-- Show current and previous metadata locations
-- previous_metadata_location is always available after any single change
SELECT 
    'Current' as version,
    regexp_replace(metadata_location, '.*/', '') as metadata_file
FROM iceberg_tables 
WHERE table_name = 'penguins_iceberg'
UNION ALL
SELECT 
    'Previous' as version,
    regexp_replace(previous_metadata_location, '.*/', '') as metadata_file
FROM iceberg_tables 
WHERE table_name = 'penguins_iceberg' 
  AND previous_metadata_location IS NOT NULL;

\echo ''
\echo '=== DELETION QUEUE (older versions, requires 2+ transactions) ==='

-- Show older versions from deletion_queue
-- These are versions that have been superseded by 2+ subsequent transactions
SELECT 
    d.orphaned_at as expired_at,
    CASE 
        WHEN extract(epoch from now() - d.orphaned_at) < 60 
            THEN round(extract(epoch from now() - d.orphaned_at)) || ' sec ago'
        WHEN extract(epoch from now() - d.orphaned_at) < 3600 
            THEN round(extract(epoch from now() - d.orphaned_at) / 60) || ' min ago'
        ELSE round(extract(epoch from now() - d.orphaned_at) / 3600, 1) || ' hours ago'
    END as age,
    regexp_replace(d.path, '.*/', '') as metadata_file
FROM lake_engine.deletion_queue d
JOIN iceberg_tables t ON d.path LIKE regexp_replace(t.metadata_location, '/metadata/.*', '') || '/%'
WHERE t.table_name = 'penguins_iceberg' 
  AND d.path LIKE '%.metadata.json'
ORDER BY d.orphaned_at DESC 
LIMIT 5;

\echo ''
\echo 'TIP: previous_metadata_location is always available after 1 transaction.'
\echo '     deletion_queue fills up after 2+ transactions commit.'
