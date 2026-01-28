-- =============================================================================
-- TIME TRAVEL: Access Historical Data in Iceberg Tables
-- =============================================================================
--
-- HOW IT WORKS:
-- 
-- 1. Iceberg tables maintain metadata files for every version (snapshot)
-- 2. When you make changes (INSERT/UPDATE/DELETE), a NEW metadata file is created
-- 3. The previous_metadata_location in iceberg_tables points to the prior version
-- 4. Over time, old versions move to lake_engine.deletion_queue (GC tracking)
-- 5. Files stay available for the retention period (default: 10 days)
--    See: SHOW pg_lake_engine.orphaned_file_retention_period;
--
-- IMPORTANT: deletion_queue behavior (from pg_lake engineering):
-- 
--   When you make a change (like DELETE), here's what happens:
--    
--    Transaction 1: Your change commits
--    - Current metadata becomes 'previous_metadata_location' 
--    - New metadata becomes current
--    - Previous version is immediately accessible via previous_metadata_location
--
--    Transaction 2: Another change commits  
--    - The old 'previous_metadata_location' moves to 'deletion_queue'
--    - Now you have deeper history available
--
--    In practice: After 1 transaction, use previous_metadata_location for time travel.
--    After 2+ transactions, older versions appear in deletion_queue for deeper history."
--
-- This is why our script uses previous_metadata_location FIRST (always available
-- after any single change), then falls back to deletion_queue for older history.
--
-- TIME TRAVEL OPTIONS:
-- - Use previous_metadata_location for immediate access to the last version
-- - Use deletion_queue for older versions (requires 2+ transactions)
--
-- =============================================================================

\echo ''
\echo '=== CURRENT STATE ==='

SELECT species, count(*) as current_count 
FROM penguins_iceberg 
GROUP BY species 
ORDER BY species;

-- =============================================================================
-- AVAILABLE TIME TRAVEL POINTS
-- =============================================================================

\echo ''
\echo '=== PREVIOUS VERSION (immediate) ==='

-- Show the immediately previous version (always available after any change)
SELECT 
    'Previous version' as "Source",
    regexp_replace(previous_metadata_location, '.*/', '') as "Metadata File"
FROM iceberg_tables 
WHERE table_name = 'penguins_iceberg'
  AND previous_metadata_location IS NOT NULL;

\echo ''
\echo '=== HISTORICAL VERSIONS (deletion queue) ==='

-- Show older versions from deletion_queue (populated over time by GC)
SELECT 
    d.orphaned_at as "Expired At",
    CASE 
        WHEN extract(epoch from now() - d.orphaned_at) < 60 
            THEN round(extract(epoch from now() - d.orphaned_at)) || ' sec ago'
        WHEN extract(epoch from now() - d.orphaned_at) < 3600 
            THEN round(extract(epoch from now() - d.orphaned_at) / 60) || ' min ago'
        WHEN extract(epoch from now() - d.orphaned_at) < 86400 
            THEN round(extract(epoch from now() - d.orphaned_at) / 3600, 1) || ' hours ago'
        ELSE round(extract(epoch from now() - d.orphaned_at) / 86400, 1) || ' days ago'
    END as "Age",
    regexp_replace(d.path, '.*/(\d+)-.*', '\1') as "Version"
FROM lake_engine.deletion_queue d
JOIN iceberg_tables t ON d.path LIKE regexp_replace(t.metadata_location, '/metadata/.*', '') || '/%'
WHERE t.table_name = 'penguins_iceberg'
  AND d.path LIKE '%.metadata.json'
ORDER BY d.orphaned_at DESC
LIMIT 5;

\echo ''
\echo 'Retention period:'
SHOW pg_lake_engine.orphaned_file_retention_period;

-- =============================================================================
-- TIME TRAVEL: Access the previous version
-- =============================================================================

DROP FOREIGN TABLE IF EXISTS penguins_time_travel;

DO $$
DECLARE
    historical_path text;
    table_path_prefix text;
    versions_in_queue int;
BEGIN
    -- First, try to get previous_metadata_location (most reliable, always available)
    SELECT previous_metadata_location
    INTO historical_path
    FROM iceberg_tables 
    WHERE table_name = 'penguins_iceberg';
    
    IF historical_path IS NOT NULL THEN
        EXECUTE format(
            'CREATE FOREIGN TABLE penguins_time_travel () SERVER pg_lake OPTIONS (path %L)',
            historical_path
        );
        RAISE NOTICE '';
        RAISE NOTICE '=== TIME TRAVEL SUCCESS ===';
        RAISE NOTICE 'Using previous_metadata_location (immediate prior version)';
        RAISE NOTICE 'File: %', regexp_replace(historical_path, '.*/', '');
    ELSE
        -- Fallback: check deletion_queue for older versions
        SELECT regexp_replace(metadata_location, '/metadata/.*', '')
        INTO table_path_prefix
        FROM iceberg_tables 
        WHERE table_name = 'penguins_iceberg';
        
        SELECT count(*) INTO versions_in_queue
        FROM lake_engine.deletion_queue 
        WHERE path LIKE table_path_prefix || '/%'
          AND path LIKE '%.metadata.json';
        
        IF versions_in_queue > 0 THEN
            SELECT path INTO historical_path
            FROM lake_engine.deletion_queue 
            WHERE path LIKE table_path_prefix || '/%'
              AND path LIKE '%.metadata.json'
            ORDER BY orphaned_at DESC
            LIMIT 1;
            
            EXECUTE format(
                'CREATE FOREIGN TABLE penguins_time_travel () SERVER pg_lake OPTIONS (path %L)',
                historical_path
            );
            RAISE NOTICE '';
            RAISE NOTICE '=== TIME TRAVEL SUCCESS ===';
            RAISE NOTICE 'Using deletion_queue (% versions available)', versions_in_queue;
            RAISE NOTICE 'File: %', regexp_replace(historical_path, '.*/', '');
        ELSE
            RAISE NOTICE '';
            RAISE NOTICE '=== NO HISTORY AVAILABLE ===';
            RAISE NOTICE 'No changes have been made to penguins_iceberg yet.';
            RAISE NOTICE 'Run DELETE or UPDATE to create history, then try again.';
            RAISE EXCEPTION 'No historical versions available.';
        END IF;
    END IF;
END $$;

-- =============================================================================
-- COMPARE: Current vs Historical
-- =============================================================================

\echo ''
\echo '=== HISTORICAL STATE (before changes) ==='

SELECT species, count(*) as historical_count 
FROM penguins_time_travel 
GROUP BY species 
ORDER BY species;

\echo ''
\echo '=== COMPARISON: Then vs Now ==='

-- Show which metadata versions we're comparing
SELECT 
    regexp_replace(previous_metadata_location, '.*/', '') as "Then (Historical)",
    regexp_replace(metadata_location, '.*/', '') as "Now (Current)"
FROM iceberg_tables 
WHERE table_name = 'penguins_iceberg';

SELECT 
    COALESCE(h.species, c.species) as species,
    h.count as "Then",
    c.count as "Now",
    COALESCE(h.count, 0) - COALESCE(c.count, 0) as "Difference"
FROM (
    SELECT species, count(*) FROM penguins_time_travel GROUP BY species
) h(species, count)
FULL OUTER JOIN (
    SELECT species, count(*) FROM penguins_iceberg GROUP BY species
) c(species, count) ON h.species = c.species
ORDER BY species;

\echo ''
\echo 'TIP: Run "task iceberg:list-snapshots" to see snapshot IDs and timestamps'
