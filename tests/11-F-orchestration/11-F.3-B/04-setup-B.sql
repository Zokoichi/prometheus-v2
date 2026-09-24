\set ON_ERROR_STOP on
BEGIN;

INSERT INTO public.production_run
(run_id, project_id, status, current_stage, attempt, input_json, output_json)
VALUES
('RUN-11F3B-B','PROJECT-11F3B','CREATED','RUN_MANAGER',1,'{}','{}');

INSERT INTO public.production_stage
(stage_id, run_id, stage_name, stage_order, status, attempt,
 idempotency_key, input_artifact_ids, output_artifact_ids,
 input_json, output_json, retryable)
VALUES
('STG-11F3B-B','RUN-11F3B-B','CONCURRENCY_B',1,'PENDING',1,
 '','[]','[]','{}','{}',false);

COMMIT;