-- Version >= 2.33
select
    c.id,
    c.record_updated_at::timestamp,
    -- Extract fields from record_data JSON when version >= 2.33
    (c.record_data->>'date')::timestamp as datetime,
    c.record_data->>'program_registry_condition_id' as program_registry_condition_id,
    c.record_data->>'patient_program_registration_id' as patient_program_registration_id,
    c.record_data->>'condition_category' as condition_category,
    c.record_data->>'reason_for_change' as reason_for_change,
    c.record_data->>'clinician_id' as recorded_by_id,
    (c.record_data->>'deletion_date')::timestamp as deleted_datetime,
    c.record_data->>'deletion_clinician_id' as deleted_by_id
from {{ source("logs__tamanu", "changes") }} c
where c.table_name = 'patient_program_registration_conditions'
    and c.version >= '2.33'
