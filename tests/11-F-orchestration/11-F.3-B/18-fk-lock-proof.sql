\set ON_ERROR_STOP on
\pset pager off

SELECT
    'FK_CONSTRAINT' AS section,
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS referenced_table,
    ccu.column_name AS referenced_column
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
 AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage ccu
  ON tc.constraint_name = ccu.constraint_name
 AND tc.table_schema = ccu.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'public'
  AND tc.table_name = 'production_stage_event'
ORDER BY tc.constraint_name;

SELECT
    'INTERNAL_FK_TRIGGER' AS section,
    tg.tgname,
    c.relname AS table_name,
    p.proname AS trigger_function,
    pg_get_triggerdef(tg.oid) AS trigger_definition
FROM pg_trigger tg
JOIN pg_class c
  ON c.oid = tg.tgrelid
JOIN pg_proc p
  ON p.oid = tg.tgfoid
WHERE c.relnamespace = 'public'::regnamespace
  AND c.relname = 'production_stage_event'
  AND tg.tgisinternal
ORDER BY tg.tgname;

SELECT
    'CURRENT_PRODUCTION_ERROR_STATE' AS section,
    (SELECT count(*) FROM public.production_run WHERE status='ERROR') AS error_runs,
    (SELECT count(*) FROM public.production_stage WHERE status='ERROR') AS error_stages;

SELECT
    '11-F.3-B-FK-LOCK-PROOF' AS result;
