\set ON_ERROR_STOP on

BEGIN;

DELETE FROM public.production_stage_event
WHERE run_id='RUN-11F3B-D-FIX';

DELETE FROM public.artifact_registry
WHERE run_id='RUN-11F3B-D-FIX';

DELETE FROM public.production_stage
WHERE run_id='RUN-11F3B-D-FIX';

DELETE FROM public.production_run
WHERE run_id='RUN-11F3B-D-FIX';

INSERT INTO public.production_run
(run_id, project_id, status, current_stage, attempt, input_json, output_json)
VALUES
('RUN-11F3B-D-FIX','PROJECT-11F3B','CREATED','COMPLETE_FAIL_STAGE_FIX',1,'{}','{}');

INSERT INTO public.production_stage
(stage_id, run_id, stage_name, stage_order, status, attempt,
 idempotency_key, input_artifact_ids, output_artifact_ids,
 input_json, output_json, retryable)
VALUES
('STG-11F3B-D-FIX','RUN-11F3B-D-FIX',
 'COMPLETE_FAIL_STAGE_FIX',1,'RUNNING',1,
 'RUN-11F3B-D-FIX:COMPLETE_FAIL_STAGE_FIX:1',
 '[]','["ART-11F3B-D-FIX"]','{}','{}',false);

INSERT INTO public.artifact_registry
(artifact_id, run_id, stage, artifact_type, object_key,
 content_type, size_bytes, sha256, version, status, metadata_json)
VALUES
('ART-11F3B-D-FIX',
 'RUN-11F3B-D-FIX',
 'COMPLETE_FAIL_STAGE_FIX',
 'TEST',
 'run/RUN-11F3B-D-FIX/test/output.bin',
 'application/octet-stream',
 1,
 repeat('d',64),
 1,
 'VALIDATED',
 '{}');

COMMIT;
