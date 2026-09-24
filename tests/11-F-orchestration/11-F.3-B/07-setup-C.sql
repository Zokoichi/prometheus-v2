\set ON_ERROR_STOP on
BEGIN;

INSERT INTO public.production_run
(run_id, project_id, status, current_stage, attempt, input_json, output_json)
VALUES
('RUN-11F3B-C','PROJECT-11F3B','CREATED','RUN_MANAGER',1,'{}','{}');

INSERT INTO public.production_stage
(stage_id, run_id, stage_name, stage_order, status, attempt,
 idempotency_key, input_artifact_ids, output_artifact_ids,
 input_json, output_json, retryable)
VALUES
('STG-11F3B-C','RUN-11F3B-C','CONCURRENCY_C',1,'PENDING',1,
 '','[]','["ART-11F3B-C"]','{}','{}',false);

INSERT INTO public.artifact_registry
(artifact_id, run_id, stage, artifact_type, object_key,
 content_type, size_bytes, sha256, version, status, metadata_json)
VALUES
('ART-11F3B-C','RUN-11F3B-C','CONCURRENCY_C','TEST',
 'run/RUN-11F3B-C/test/artifact.txt',
 'text/plain',1,
 repeat('a',64),
 1,'VALIDATED','{}');

COMMIT;