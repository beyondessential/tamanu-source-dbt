select
    cdc.id,
    cdc.time_after_onset,
    cdc.patient_death_data_id,
    cdc.condition_id
from {{ resolve_input_model('contributing_death_causes', source_type=var('base_model_source_type', 'source')) }} cdc
join {{ resolve_input_model('patient_death_data', source_type=var('base_model_source_type', 'source')) }} pdd on pdd.id = cdc.patient_death_data_id
where cdc.deleted_at is null
    and pdd.deleted_at is null
    and pdd.patient_id != '{{ var("test_patient") }}'
