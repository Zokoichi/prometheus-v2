\set ON_ERROR_STOP on

BEGIN;

DELETE FROM public.production_stage_event
WHERE run_id='RUN-11F3B-FK';

DELETE FROM public.production_stage
WHERE run_id='RUN-11F3B-FK';

DELETE FROM public.production_run
WHERE run_id='RUN-11F3B-FK';

INSERT INTO public.production_run
(run_id, project_id, status, current_stage, attempt, input_json, output_json)
VALUES
('RUN-11F3B-FK','PROJECT-11F3B','CREATED','FK_LOCK_PROOF',1,'{}','{}');

INSERT INTO public.production_stage
(stage_id, run_id, stage_name, stage_order, status, attempt,
 idempotency_key, input_artifact_ids, output_artifact_ids,
 input_json, output_json, retryable)
VALUES
('STG-11F3B-FK','RUN-11F3B-FK','FK_LOCK_PROOF',1,'RUNNING',1,
 'RUN-11F3B-FK:FK_LOCK_PROOF:1','[]','[]','{}','{}',false);

COMMIT;

SELECT
    'FIXTURE_READY' AS result,
    pr.run_id,
    ps.stage_id,
    pr.status AS run_status,
    ps.status AS stage_status
FROM public.production_run pr
JOIN public.production_stage ps
  ON ps.run_id=pr.run_id
WHERE pr.run_id='RUN-11F3B-FK';
