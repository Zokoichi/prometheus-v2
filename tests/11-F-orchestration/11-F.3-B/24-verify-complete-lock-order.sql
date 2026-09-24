\set ON_ERROR_STOP on
\pset pager off

WITH src AS (
    SELECT pg_get_functiondef(p.oid) AS s
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public'
      AND p.proname='complete_stage_atomically'
)
SELECT
    'COMPLETE_SOURCE_MARKERS' AS section,
    x.label,
    x.pos
FROM src
CROSS JOIN LATERAL (
    VALUES
      ('RUN_LOCK',
       position(
         'FROM public.production_run pr' IN src.s
       )),
      ('RUN_FOR_UPDATE',
       position(
         'WHERE pr.run_id = v_run_id' IN src.s
       )),
      ('STAGE_LOCK',
       position(
         'FROM public.production_stage ps' IN src.s
       )),
      ('STAGE_FOR_UPDATE',
       position(
         'WHERE ps.stage_id = p_stage_id' IN src.s
       )),
      ('RELATION_GUARD',
       position(
         'COMPLETE_STAGE_RUN_RELATION_CHANGED' IN src.s
       )),
      ('ARTIFACT_FOR_SHARE',
       position(
         'FROM public.artifact_registry ar' IN src.s
       )),
      ('STAGE_EVENT',
       position(
         'INSERT INTO public.production_stage_event' IN src.s
       ))
) x(label,pos)
ORDER BY x.pos;

SELECT
    'COMPLETE_SOURCE_MD5' AS section,
    md5(pg_get_functiondef(p.oid)) AS source_md5
FROM pg_proc p
JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public'
  AND p.proname='complete_stage_atomically';

SELECT
    'FUNCTION_COUNT' AS section,
    count(*)
FROM pg_proc p
JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public'
  AND p.proname='complete_stage_atomically';

SELECT
    'ERROR_STATE' AS section,
    (SELECT count(*) FROM public.production_run WHERE status='ERROR') AS error_runs,
    (SELECT count(*) FROM public.production_stage WHERE status='ERROR') AS error_stages;
