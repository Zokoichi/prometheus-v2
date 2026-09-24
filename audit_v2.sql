\echo '=== 1. TABLES PROMETHEUS V2 (hors tables internes n8n) ==='
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND (table_name LIKE 'stage%' OR table_name LIKE 'production%' OR table_name LIKE 'artifact%' OR table_name LIKE 'run%')
ORDER BY table_name;

\echo '=== 2. NOMBRE DE LIGNES PAR TABLE ==='
SELECT table_name,
  (xpath('/row/cnt/text()', query_to_xml(format('SELECT count(*) AS cnt FROM %I', table_name), false, true, '')))[1]::text::bigint AS row_count
FROM information_schema.tables
WHERE table_schema = 'public'
  AND (table_name LIKE 'stage%' OR table_name LIKE 'production%' OR table_name LIKE 'artifact%' OR table_name LIKE 'run%')
ORDER BY table_name;

\echo '=== 3. COLONNES DE CHAQUE TABLE ==='
SELECT table_name, ordinal_position, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN (
    SELECT table_name FROM information_schema.tables
    WHERE table_schema = 'public'
      AND (table_name LIKE 'stage%' OR table_name LIKE 'production%' OR table_name LIKE 'artifact%' OR table_name LIKE 'run%')
  )
ORDER BY table_name, ordinal_position;

\echo '=== 4. CONTRAINTES REELLES (UNIQUE / CHECK / FK) ==='
SELECT conrelid::regclass AS table_name, conname, contype, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE connamespace = 'public'::regnamespace
  AND conrelid::regclass::text IN (
    SELECT table_name FROM information_schema.tables
    WHERE table_schema = 'public'
      AND (table_name LIKE 'stage%' OR table_name LIKE 'production%' OR table_name LIKE 'artifact%' OR table_name LIKE 'run%')
  )
ORDER BY table_name, contype;

\echo '=== 5. TRIGGERS ==='
SELECT event_object_table, trigger_name, event_manipulation, action_timing
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table;

\echo '=== 6. FONCTIONS CUSTOM (guards, register_stage_definition, etc.) ==='
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'public' AND routine_type IN ('FUNCTION','PROCEDURE')
ORDER BY routine_name;
