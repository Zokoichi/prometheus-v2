\pset pager off
\pset tuples_only off
\pset format unaligned

\echo '===== CLAIM ====='
SELECT pg_get_functiondef('public.claim_stage_for_execution(character varying)'::regprocedure);

\echo '===== COMPLETE STAGE ====='
SELECT pg_get_functiondef('public.complete_stage_atomically(character varying,jsonb)'::regprocedure);

\echo '===== RECORD EXECUTION EVENT ====='
SELECT pg_get_functiondef(
'public.record_execution_event(
character varying,
character varying,
character varying,
character varying,
integer,
character varying,
character varying,
character varying,
character varying,
timestamp with time zone,
timestamp with time zone,
bigint,
character varying,
character varying,
jsonb,
jsonb,
jsonb
)'::regprocedure
);

\echo '===== RUN TRANSITION ====='
SELECT pg_get_functiondef(
'public.request_run_transition(
character varying,
character varying,
character varying,
character varying,
jsonb
)'::regprocedure
);

\echo '===== VALIDATE STAGE ARTIFACTS ====='
SELECT pg_get_functiondef(
'public.validate_stage_artifacts(character varying)'::regprocedure
);

\echo '===== VALIDATE RUN/STAGE CONSISTENCY ====='
SELECT pg_get_functiondef(
'public.validate_run_stage_consistency(character varying)'::regprocedure
);

\echo '===== CREATE DEPENDENCY ====='
SELECT pg_get_functiondef(
'public.create_stage_dependency(
character varying,
character varying,
character varying
)'::regprocedure
);

\echo '===== ARTIFACT RECONCILIATION ====='
SELECT pg_get_functiondef(
'public.reconcile_artifact_presence(
character varying,
boolean
)'::regprocedure
);

\echo '===== STAGE DEFINITION REGISTRATION ====='
SELECT pg_get_functiondef(
'public.register_stage_definition(
character varying,
integer,
text,
jsonb,
jsonb,
jsonb,
integer,
integer,
jsonb,
jsonb,
character varying,
jsonb,
jsonb,
boolean
)'::regprocedure
);

\echo '===== CONTRACT REGISTRATION ====='
SELECT pg_get_functiondef(
'public.register_contract_definition(
character varying,
integer,
text,
jsonb,
character varying,
jsonb,
boolean
)'::regprocedure
);

\echo '===== RUN DIAGNOSTIC ====='
SELECT pg_get_functiondef(
'public.diagnose_run(character varying)'::regprocedure
);
