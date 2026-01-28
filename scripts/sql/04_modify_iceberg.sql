-- Check Chinstrap counts
SELECT count(*) as chinstrap_count_before 
FROM penguins_iceberg 
WHERE species = 'Chinstrap';

-- Delete them (ACID operation)
DELETE FROM penguins_iceberg
WHERE species = 'Chinstrap';

-- Verify deletion
SELECT count(*) as chinstrap_count_after 
FROM penguins_iceberg 
WHERE species = 'Chinstrap';
