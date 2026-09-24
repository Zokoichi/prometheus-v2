\set ON_ERROR_STOP on
\pset pager off

BEGIN;

DELETE FROM production_stage_event
WHERE run_id = 'RUN-11E32-FIX-RETEST';

DELETE FROM production_run_event
WHERE run_id = 'RUN-11E32-FIX-RETEST';

DELETE FROM production_stage
WHERE stage_id = 'STG-11E32-FIX-RETEST';

DELETE FROM production_run
WHERE run_id = 'RUN-11E32-FIX-RETEST';

COMMIT;

SELECT COUNT(*) AS remaining_fixture_runs
FROM production_run
WHERE run_id = 'RUN-11E32-FIX-RETEST';

SELECT COUNT(*) AS remaining_fixture_stages
FROM production_stage
WHERE stage_id = 'STG-11E32-FIX-RETEST';

SELECT COUNT(*) AS remaining_fixture_run_events
FROM production_run_event
WHERE run_id = 'RUN-11E32-FIX-RETEST';

SELECT COUNT(*) AS remaining_fixture_stage_events
FROM production_stage_event
WHERE run_id = 'RUN-11E32-FIX-RETEST';
