select
    ir.id,
    ir.display_id,
    ir.requested_date::timestamp as datetime,
    ir.status,
    ir.priority,
    ir.imaging_type,
    ir.encounter_id,
    ir.requested_by_id,
    ir.completed_by_id,
    ir.location_id,
    ir.location_group_id,
    ir.reason_for_cancellation
from {{ resolve_input_model('imaging_requests', source_type=var('base_model_source_type', 'source')) }} ir
join {{ resolve_input_model('encounters', source_type=var('base_model_source_type', 'source')) }} e on e.id = ir.encounter_id
where ir.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
