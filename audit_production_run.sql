\echo '=== SCHEMA PRODUCTION_RUN ==='

SELECT 
column_name,
data_type,
is_nullable
FROM information_schema.columns
WHERE table_name='production_run'
ORDER BY ordinal_position;

