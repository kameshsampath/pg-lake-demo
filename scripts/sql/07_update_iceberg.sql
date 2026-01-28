-- =============================================================================
-- OPTIONAL: UPDATE Operations on Iceberg Tables
-- =============================================================================
-- Demonstrates UPDATE (in addition to DELETE shown earlier)
-- Also triggers deletion_queue population since this is transaction #2+
--
-- Run via: task demo:update
-- =============================================================================

\echo ''
\echo '=== CURRENT STATE ==='

SELECT species, island, count(*) as count, round(avg(body_mass_g)) as avg_mass
FROM penguins_iceberg
GROUP BY species, island
ORDER BY species, island;

\echo ''
\echo '=== UPDATE: Increase body mass for Biscoe island penguins by 10% ==='

-- Show before
SELECT species, island, round(avg(body_mass_g)) as avg_mass_before
FROM penguins_iceberg
WHERE island = 'Biscoe'
GROUP BY species, island;

-- Perform UPDATE
UPDATE penguins_iceberg
SET body_mass_g = body_mass_g * 1.10
WHERE island = 'Biscoe';

-- Show after  
SELECT species, island, round(avg(body_mass_g)) as avg_mass_after
FROM penguins_iceberg
WHERE island = 'Biscoe'
GROUP BY species, island;

\echo ''
\echo '=== VERIFY: This transaction populated the deletion_queue ==='

-- Now that we have 2+ transactions, deletion_queue should have entries
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
\echo 'The deletion_queue now has entries because we have 2+ committed transactions!'
\echo 'Previous version (before DELETE) is now in the queue for time travel.'
