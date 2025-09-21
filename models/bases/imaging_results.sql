select
    ires.id,
    ires.completed_at::timestamp as datetime,
    ires.description,
    ires.imaging_request_id,
    ires.external_code,
    ires.completed_by_id,
    ires.visibility_status
from {{ resolve_input_model('imaging_results', source_type=var('base_model_source_type', 'source')) }} ires
join {{ resolve_input_model('imaging_requests', source_type=var('base_model_source_type', 'source')) }} ireq on ireq.id = ires.imaging_request_id
join {{ resolve_input_model('encounters', source_type=var('base_model_source_type', 'source')) }} e on e.id = ireq.encounter_id
where ires.deleted_at is null
    and ireq.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
