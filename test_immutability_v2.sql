\echo '=== Capture d un timestamp fixe reutilisable ==='
SELECT now() AS fixed_ts \gset

\echo '=== APPEL 1 ==='
SELECT record_execution_event(
  'TEST-IMMUT-002', 'RUN-20260910-0001', NULL, 'TEST_STAGE', 1,
  'TEST_EVENT', NULL, NULL, 'SUCCEEDED', :'fixed_ts'::timestamptz, :'fixed_ts'::timestamptz, 100,
  NULL, NULL, '[]'::jsonb, '[]'::jsonb, '{"note":"first"}'::jsonb
);

\echo '=== APPEL 2 - VRAIMENT identique (meme timestamp exact) : doit etre idempotent, pas conflict ==='
SELECT record_execution_event(
  'TEST-IMMUT-002', 'RUN-20260910-0001', NULL, 'TEST_STAGE', 1,
  'TEST_EVENT', NULL, NULL, 'SUCCEEDED', :'fixed_ts'::timestamptz, :'fixed_ts'::timestamptz, 100,
  NULL, NULL, '[]'::jsonb, '[]'::jsonb, '{"note":"first"}'::jsonb
);

\echo '=== APPEL 3 - meme timestamp, duration differente : doit etre CONFLICT ==='
SELECT record_execution_event(
  'TEST-IMMUT-002', 'RUN-20260910-0001', NULL, 'TEST_STAGE', 1,
  'TEST_EVENT', NULL, NULL, 'SUCCEEDED', :'fixed_ts'::timestamptz, :'fixed_ts'::timestamptz, 999,
  NULL, NULL, '[]'::jsonb, '[]'::jsonb, '{"note":"tampered"}'::jsonb
);

\echo '=== ETAT FINAL - une seule ligne attendue ==='
SELECT event_id, duration_ms FROM production_execution_event WHERE event_id = 'TEST-IMMUT-002';

\echo '=== CLEANUP ==='
DELETE FROM production_execution_event WHERE event_id = 'TEST-IMMUT-002';
