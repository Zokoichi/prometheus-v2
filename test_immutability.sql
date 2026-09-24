\echo '=== TEST IMMUTABILITE record_execution_event ==='
SELECT record_execution_event(
  'TEST-IMMUT-001', 'RUN-20260910-0001', NULL, 'TEST_STAGE', 1,
  'TEST_EVENT', NULL, NULL, 'SUCCEEDED', now(), now(), 100,
  NULL, NULL, '[]'::jsonb, '[]'::jsonb, '{"note":"first"}'::jsonb
);

\echo '=== MEME EVENT_ID, CONTENU IDENTIQUE (doit etre idempotent) ==='
SELECT record_execution_event(
  'TEST-IMMUT-001', 'RUN-20260910-0001', NULL, 'TEST_STAGE', 1,
  'TEST_EVENT', NULL, NULL, 'SUCCEEDED', now(), now(), 100,
  NULL, NULL, '[]'::jsonb, '[]'::jsonb, '{"note":"first"}'::jsonb
);

\echo '=== MEME EVENT_ID, CONTENU DIFFERENT (doit etre refuse) ==='
SELECT record_execution_event(
  'TEST-IMMUT-001', 'RUN-20260910-0001', NULL, 'TEST_STAGE', 1,
  'TEST_EVENT', NULL, NULL, 'SUCCEEDED', now(), now(), 999,
  NULL, NULL, '[]'::jsonb, '[]'::jsonb, '{"note":"tampered"}'::jsonb
);

\echo '=== ETAT FINAL - une seule ligne attendue ==='
SELECT event_id, duration_ms, event_data FROM production_execution_event WHERE event_id = 'TEST-IMMUT-001';

\echo '=== CLEANUP ==='
DELETE FROM production_execution_event WHERE event_id = 'TEST-IMMUT-001';
