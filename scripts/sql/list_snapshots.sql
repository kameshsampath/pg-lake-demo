-- =============================================================================
-- LIST ICEBERG SNAPSHOTS
-- =============================================================================
-- Shows all snapshots (versions) for the penguins_iceberg table
-- Each snapshot represents a point-in-time state of the table
--
-- Uses lake_iceberg.snapshots() - native PostgreSQL function (no DuckDB needed)
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
FROM lake_iceberg.snapshots(
    (SELECT metadata_location FROM iceberg_tables WHERE table_name = 'penguins_iceberg')
)
ORDER BY sequence_number;

\echo ''
\echo 'Each snapshot is a recoverable point-in-time version of your data.'
