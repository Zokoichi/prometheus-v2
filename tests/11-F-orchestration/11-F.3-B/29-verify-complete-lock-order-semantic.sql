\pset pager off
\pset tuples_only off

\echo ============================================================
\echo 11-F.3-B — SEMANTIC LOCK ORDER VERIFICATION
\echo ============================================================

WITH src AS (
    SELECT pg_get_functiondef(
        'public.complete_stage_atomically(character varying,jsonb)'::regprocedure
    ) AS source
),
lines AS (
    SELECT
        row_number() OVER () AS line_no,
        line
    FROM src,
    regexp_split_to_table(source, E'\n') AS line
)
SELECT
    line_no,
    line
FROM lines
WHERE
    line ~* 'production_run'
    OR line ~* 'production_stage'
    OR line ~* 'FOR UPDATE'
    OR line ~* 'SELECT.*run_id'
ORDER BY line_no;

\echo
\echo ============================================================
\echo EXACT LOCK STATEMENTS
\echo ============================================================

WITH src AS (
    SELECT pg_get_functiondef(
        'public.complete_stage_atomically(character varying,jsonb)'::regprocedure
    ) AS source
),
lines AS (
    SELECT
        row_number() OVER () AS line_no,
        line
    FROM src,
    regexp_split_to_table(source, E'\n') AS line
)
SELECT
    line_no,
    trim(line) AS lock_statement
FROM lines
WHERE
    line ~* 'FOR UPDATE'
ORDER BY line_no;

\echo
\echo ============================================================
\echo SEMANTIC CLASSIFICATION
\echo ============================================================

WITH src AS (
    SELECT pg_get_functiondef(
        'public.complete_stage_atomically(character varying,jsonb)'::regprocedure
    ) AS source
),
lines AS (
    SELECT
        row_number() OVER () AS line_no,
        line
    FROM src,
    regexp_split_to_table(source, E'\n') AS line
),
locks AS (
    SELECT
        line_no,
        CASE
            WHEN line ~* 'production_run.*FOR UPDATE'
              OR line ~* 'FROM public\.production_run.*FOR UPDATE'
              OR line ~* 'FROM production_run.*FOR UPDATE'
            THEN 'RUN_LOCK'
            WHEN line ~* 'production_stage.*FOR UPDATE'
              OR line ~* 'FROM public\.production_stage.*FOR UPDATE'
              OR line ~* 'FROM production_stage.*FOR UPDATE'
            THEN 'STAGE_LOCK'
            ELSE 'OTHER'
        END AS lock_type,
        trim(line) AS statement
    FROM lines
    WHERE line ~* 'FOR UPDATE'
)
SELECT *
FROM locks
ORDER BY line_no;

\echo
\echo ============================================================
\echo ORDER CHECK
\echo ============================================================

WITH src AS (
    SELECT pg_get_functiondef(
        'public.complete_stage_atomically(character varying,jsonb)'::regprocedure
    ) AS source
),
lines AS (
    SELECT
        row_number() OVER () AS line_no,
        line
    FROM src,
    regexp_split_to_table(source, E'\n') AS line
),
locks AS (
    SELECT
        line_no,
        CASE
            WHEN line ~* 'production_run.*FOR UPDATE'
              OR line ~* 'FROM public\.production_run.*FOR UPDATE'
              OR line ~* 'FROM production_run.*FOR UPDATE'
            THEN 'RUN'
            WHEN line ~* 'production_stage.*FOR UPDATE'
              OR line ~* 'FROM public\.production_stage.*FOR UPDATE'
              OR line ~* 'FROM production_stage.*FOR UPDATE'
            THEN 'STAGE'
            ELSE 'OTHER'
        END AS lock_type
    FROM lines
    WHERE line ~* 'FOR UPDATE'
),
run_lock AS (
    SELECT min(line_no) AS pos
    FROM locks
    WHERE lock_type = 'RUN'
),
stage_lock AS (
    SELECT min(line_no) AS pos
    FROM locks
    WHERE lock_type = 'STAGE'
)
SELECT
    run_lock.pos AS run_lock_pos,
    stage_lock.pos AS stage_lock_pos,
    CASE
        WHEN run_lock.pos IS NULL THEN 'FAIL — RUN LOCK ABSENT'
        WHEN stage_lock.pos IS NULL THEN 'FAIL — STAGE LOCK ABSENT'
        WHEN run_lock.pos < stage_lock.pos THEN 'PASS — RUN BEFORE STAGE'
        ELSE 'FAIL — STAGE BEFORE RUN'
    END AS result
FROM run_lock, stage_lock;

\echo
\echo ============================================================
\echo CURRENT FUNCTION MD5
\echo ============================================================

SELECT
    md5(pg_get_functiondef(
        'public.complete_stage_atomically(character varying,jsonb)'::regprocedure
    )) AS complete_stage_atomically_md5;

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
\echo 11-F.3-B — SEMANTIC LOCK ORDER VERIFICATION COMPLETE
\echo ============================================================
