select
    lrl.id,
    lrl.lab_request_id,
    lrl.status,
    lrl.updated_at::timestamp as updated_datetime,
    lrl.updated_by_id
from {{ resolve_input_model('lab_request_logs', source_type=var('base_model_source_type', 'source')) }} lrl
join {{ resolve_input_model('lab_requests', source_type=var('base_model_source_type', 'source')) }} lr on lr.id = lrl.lab_request_id
join {{ resolve_input_model('encounters', source_type=var('base_model_source_type', 'source')) }} e on e.id = lr.encounter_id
where lrl.deleted_at is null
    and lr.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
