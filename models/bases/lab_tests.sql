select
    lt.id,
    lt.date::date as date,
    lt.result,
    lt.lab_request_id,
    lt.lab_test_type_id,
    lt.lab_test_method_id,
    lt.laboratory_officer,
    lt.completed_date::timestamp as completed_datetime,
    lt.verification
from {{ resolve_input_model('lab_tests', source_type=var('base_model_source_type', 'source')) }} lt
join {{ resolve_input_model('lab_requests', source_type=var('base_model_source_type', 'source')) }} lr on lr.id = lt.lab_request_id
join {{ resolve_input_model('encounters', source_type=var('base_model_source_type', 'source')) }} e on e.id = lr.encounter_id
where lt.deleted_at is null
    and lr.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
