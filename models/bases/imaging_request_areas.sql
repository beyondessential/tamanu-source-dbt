select
    ira.id,
    ira.imaging_request_id,
    ira.area_id
from {{ resolve_input_model('imaging_request_areas', source_type=var('base_model_source_type', 'source')) }} ira
join {{ resolve_input_model('imaging_requests', source_type=var('base_model_source_type', 'source')) }} ir on ir.id = ira.imaging_request_id
join {{ resolve_input_model('encounters', source_type=var('base_model_source_type', 'source')) }} e on e.id = ir.encounter_id
where ira.deleted_at is null
    and ir.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
