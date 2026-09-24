\pset pager off
\pset tuples_only off

\echo ============================================================
\echo 11-F.3-B — CORRECTED SEMANTIC LOCK ORDER VERIFICATION
\echo ============================================================

WITH src AS (
    SELECT pg_get_functiondef(
        'public.complete_stage_atomically(character varying,jsonb)'::regprocedure
    ) AS source
),
normalized AS (
    SELECT regexp_replace(source, '[[:space:]]+', ' ', 'g') AS source
    FROM src
),
positions AS (
    SELECT
        source,

        strpos(
            lower(source),
            'select pr.run_id into v_locked_run_id'
        ) AS run_select_pos,

        strpos(
            lower(source),
            'select ps.status, ps.output_artifact'
        ) AS stage_select_pos
    FROM normalized
),
lock_positions AS (
    SELECT
        source,
        run_select_pos,
        stage_select_pos,

        CASE
            WHEN run_select_pos > 0 THEN
                run_select_pos +
                strpos(
                    lower(substr(source, run_select_pos)),
                    'for update'
                ) - 1
            ELSE NULL
        END AS run_lock_pos,

        CASE
            WHEN stage_select_pos > 0 THEN
                stage_select_pos +
                strpos(
                    lower(substr(source, stage_select_pos)),
                    'for update'
                ) - 1
            ELSE NULL
        END AS stage_lock_pos
    FROM positions
)
SELECT
    run_select_pos,
    stage_select_pos,
    run_lock_pos,
    stage_lock_pos,
    CASE
        WHEN run_lock_pos IS NULL OR run_lock_pos = 0
            THEN 'FAIL — RUN LOCK NOT FOUND'
        WHEN stage_lock_pos IS NULL OR stage_lock_pos = 0
            THEN 'FAIL — STAGE LOCK NOT FOUND'
        WHEN run_lock_pos < stage_lock_pos
            THEN 'PASS — RUN LOCK BEFORE STAGE LOCK'
        ELSE
            'FAIL — STAGE LOCK BEFORE RUN LOCK'
    END AS result
FROM lock_positions;

\echo
\echo ============================================================
\echo LOCK CONTEXT — RUN
\echo ============================================================

WITH src AS (
    SELECT regexp_replace(
        pg_get_functiondef(
            'public.complete_stage_atomically(character varying,jsonb)'::regprocedure
        ),
        '[[:space:]]+',
        ' ',
        'g'
    ) AS source
)
SELECT substring(
    source
    FROM greatest(
        1,
        strpos(lower(source), 'from public.production_run pr') - 150
    )
    FOR 550
)
FROM src;

\echo
\echo ============================================================
\echo LOCK CONTEXT — STAGE
\echo ============================================================

WITH src AS (
    SELECT regexp_replace(
        pg_get_functiondef(
            'public.complete_stage_atomically(character varying,jsonb)'::regprocedure
        ),
        '[[:space:]]+',
        ' ',
        'g'
    ) AS source
)
SELECT substring(
    source
    FROM greatest(
        1,
        strpos(lower(source), 'from public.production_stage ps') - 150
    )
    FOR 550
)
FROM src;

\echo
\echo ============================================================
\echo REQUIRED SOURCE MARKERS
\echo ============================================================

WITH src AS (
    SELECT lower(
        regexp_replace(
            pg_get_functiondef(
                'public.complete_stage_atomically(character varying,jsonb)'::regprocedure
            ),
            '[[:space:]]+',
            ' ',
            'g'
        )
    ) AS source
)
SELECT
    CASE
        WHEN src.source LIKE '%select pr.run_id into v_locked_run_id%'
         AND src.source LIKE '%from public.production_run pr%'
         AND src.source LIKE '%for update%'
        THEN 'PASS'
        ELSE 'FAIL'
    END AS run_lock,

    CASE
        WHEN src.source LIKE '%select ps.status, ps.output_artifact%'
         AND src.source LIKE '%from public.production_stage ps%'
         AND src.source LIKE '%for update%'
        THEN 'PASS'
        ELSE 'FAIL'
    END AS stage_lock,

    CASE
        WHEN src.source LIKE '%where ps.stage_id = p_stage_id%'
        THEN 'PASS'
        ELSE 'FAIL'
    END AS stage_identity,

    CASE
        WHEN src.source LIKE '%production_stage_event%'
        THEN 'PASS'
        ELSE 'FAIL'
    END AS stage_event,

    CASE
        WHEN src.source LIKE '%for share%'
        THEN 'PASS'
        ELSE 'FAIL'
    END AS artifact_share
FROM src;

\echo
\echo ============================================================
\echo FUNCTION SOURCE MD5
\echo ============================================================

SELECT md5(
    pg_get_functiondef(
        'public.complete_stage_atomically(character varying,jsonb)'::regprocedure
    )
) AS complete_stage_atomically_md5;

\echo
\echo ============================================================
\echo FUNCTION COUNT
\echo ============================================================

SELECT count(*) AS function_count
FROM pg_proc p
JOIN pg_namespace n
  ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'complete_stage_atomically';

\echo
\echo ============================================================
\echo CURRENT PRODUCTION ERROR STATE
\echo ============================================================

SELECT
    count(*) FILTER (WHERE status = 'ERROR') AS error_runs
FROM public.production_run;

SELECT
    count(*) FILTER (WHERE status = 'ERROR') AS error_stages
FROM public.production_stage;

\echo
\echo ============================================================
\echo 11-F.3-B — CORRECTED SEMANTIC VERIFICATION COMPLETE
\echo ============================================================
