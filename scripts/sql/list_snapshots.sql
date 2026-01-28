-- =============================================================================
-- LIST ICEBERG SNAPSHOTS
-- =============================================================================
-- Shows all snapshots (versions) for the penguins_iceberg table
-- Each snapshot represents a point-in-time state of the table
--
-- Note: METADATA_LOCATION is substituted via envsubst from the Taskfile
--       (iceberg_tables is a PostgreSQL view, not available in DuckDB)
--
-- Run via: task iceberg:list-snapshots
-- =============================================================================

\echo ''
\echo '=== ICEBERG SNAPSHOTS for penguins_iceberg ==='
\echo ''

SELECT 
    sequence_number as seq, 
    snapshot_id, 
    timestamp_ms as created_at
FROM iceberg_snapshots('${METADATA_LOCATION}')
ORDER BY sequence_number;

\echo ''
\echo 'Each snapshot is a recoverable point-in-time version of your data.'
