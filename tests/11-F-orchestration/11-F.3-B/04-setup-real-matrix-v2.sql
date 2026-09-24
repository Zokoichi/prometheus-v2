\set ON_ERROR_STOP on
BEGIN;

-- ============================================================
-- CLEAN OLD FIXTURES
-- ============================================================

DELETE FROM public.production_execution_event
WHERE run_id LIKE 'RUN-11F3B-%';

DELETE FROM public.production_stage_event
WHERE run_id LIKE 'RUN-11F3B-%';

DELETE FROM public.artifact_registry
WHERE run_id LIKE 'RUN-11F3B-%';

DELETE FROM public.production_stage_dependency
WHERE stage_id LIKE 'STG-11F3B-%'
   OR depends_on_stage_id LIKE 'STG-11F3B-%';

DELETE FROM public.production_stage
WHERE run_id LIKE 'RUN-11F3B-%';

DELETE FROM public.production_run
WHERE run_id LIKE 'RUN-11F3B-%';

-- ============================================================
-- FIXTURE A — CLAIM <-> FAIL_STAGE
-- ============================================================

INSERT INTO public.production_run
(run_id, project_id, status, current_stage, attempt, input_json, output_json)
VALUES
('RUN-11F3B-A','PROJECT-11F3B','CREATED','CLAIM_FAIL_STAGE',1,'{}','{}');

INSERT INTO public.production_stage
(stage_id, run_id, stage_name, stage_order, status, attempt,
 idempotency_key, input_artifact_ids, output_artifact_ids,
 input_json, output_json, retryable)
VALUES
('STG-11F3B-A','RUN-11F3B-A','CLAIM_FAIL_STAGE',1,'PENDING',1,
 'RUN-11F3B-A:CLAIM_FAIL_STAGE:1','[]','[]','{}','{}',false);

-- ============================================================
-- FIXTURE B — CLAIM <-> FAIL_RUN
-- ============================================================

INSERT INTO public.production_run
(run_id, project_id, status, current_stage, attempt, input_json, output_json)
VALUES
('RUN-11F3B-B','PROJECT-11F3B','CREATED','CLAIM_FAIL_RUN',1,'{}','{}');

INSERT INTO public.production_stage
(stage_id, run_id, stage_name, stage_order, status, attempt,
 idempotency_key, input_artifact_ids, output_artifact_ids,
 input_json, output_json, retryable)
VALUES
('STG-11F3B-B','RUN-11F3B-B','CLAIM_FAIL_RUN',1,'PENDING',1,
 'RUN-11F3B-B:CLAIM_FAIL_RUN:1','[]','[]','{}','{}',false);

-- ============================================================
-- FIXTURE C — CLAIM <-> COMPLETE
-- ============================================================

INSERT INTO public.production_run
(run_id, project_id, status, current_stage, attempt, input_json, output_json)
VALUES
('RUN-11F3B-C','PROJECT-11F3B','CREATED','CLAIM_COMPLETE',1,'{}','{}');

INSERT INTO public.production_stage
(stage_id, run_id, stage_name, stage_order, status, attempt,
 idempotency_key, input_artifact_ids, output_artifact_ids,
 input_json, output_json, retryable)
VALUES
('STG-11F3B-C','RUN-11F3B-C','CLAIM_COMPLETE',1,'PENDING',1,
 'RUN-11F3B-C:CLAIM_COMPLETE:1','[]',
 '["ART-11F3B-C"]','{}','{}',false);

INSERT INTO public.artifact_registry
(artifact_id, run_id, stage, artifact_type, object_key,
 content_type, size_bytes, sha256, version, status, metadata_json)
VALUES
('ART-11F3B-C','RUN-11F3B-C','CLAIM_COMPLETE','TEST',
 'run/RUN-11F3B-C/test/output.bin',
 'application/octet-stream',1,
 repeat('a',64),1,'VALIDATED','{}');

-- ============================================================
-- FIXTURE D — COMPLETE <-> FAIL_STAGE
-- ============================================================

INSERT INTO public.production_run
(run_id, project_id, status, current_stage, attempt, input_json, output_json)
VALUES
('RUN-11F3B-D','PROJECT-11F3B','CREATED','COMPLETE_FAIL_STAGE',1,'{}','{}');

INSERT INTO public.production_stage
(stage_id, run_id, stage_name, stage_order, status, attempt,
 idempotency_key, input_artifact_ids, output_artifact_ids,
 input_json, output_json, retryable)
VALUES
('STG-11F3B-D','RUN-11F3B-D','COMPLETE_FAIL_STAGE',1,'RUNNING',1,
 'RUN-11F3B-D:COMPLETE_FAIL_STAGE:1','[]',
 '["ART-11F3B-D"]','{}','{}',false);

INSERT INTO public.artifact_registry
(artifact_id, run_id, stage, artifact_type, object_key,
 content_type, size_bytes, sha256, version, status, metadata_json)
VALUES
('ART-11F3B-D','RUN-11F3B-D','COMPLETE_FAIL_STAGE','TEST',
 'run/RUN-11F3B-D/test/output.bin',
 'application/octet-stream',1,
 repeat('b',64),1,'VALIDATED','{}');

-- ============================================================
-- FIXTURE E — COMPLETE <-> FAIL_RUN
-- ============================================================

INSERT INTO public.production_run
(run_id, project_id, status, current_stage, attempt, input_json, output_json)
VALUES
('RUN-11F3B-E','PROJECT-11F3B','CREATED','COMPLETE_FAIL_RUN',1,'{}','{}');

INSERT INTO public.production_stage
(stage_id, run_id, stage_name, stage_order, status, attempt,
 idempotency_key, input_artifact_ids, output_artifact_ids,
 input_json, output_json, retryable)
VALUES
('STG-11F3B-E','RUN-11F3B-E','COMPLETE_FAIL_RUN',1,'RUNNING',1,
 'RUN-11F3B-E:COMPLETE_FAIL_RUN:1','[]',
 '["ART-11F3B-E"]','{}','{}',false);

INSERT INTO public.artifact_registry
(artifact_id, run_id, stage, artifact_type, object_key,
 content_type, size_bytes, sha256, version, status, metadata_json)
VALUES
('ART-11F3B-E','RUN-11F3B-E','COMPLETE_FAIL_RUN','TEST',
 'run/RUN-11F3B-E/test/output.bin',
 'application/octet-stream',1,
 repeat('c',64),1,'VALIDATED','{}');

COMMIT;

-- ============================================================
-- VERIFY ALL FIXTURES AFTER COMMIT
-- ============================================================

SELECT
    'FIXTURE' AS test,
    pr.run_id,
    pr.status AS run_status,
    ps.stage_id,
    ps.status AS stage_status,
    ps.attempt,
    ps.retryable,
    ps.idempotency_key
FROM public.production_run pr
JOIN public.production_stage ps ON ps.run_id = pr.run_id
WHERE pr.run_id LIKE 'RUN-11F3B-%'
ORDER BY pr.run_id;

SELECT
    'ARTIFACT' AS test,
    artifact_id,
    run_id,
    status
FROM public.artifact_registry
WHERE run_id LIKE 'RUN-11F3B-%'
ORDER BY artifact_id;
