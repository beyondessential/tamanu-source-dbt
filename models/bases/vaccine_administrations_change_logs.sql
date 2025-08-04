with filtered_changes as (
    select 
        av.*
    from ({{ base_history_from_log('administered_vaccines') }}) av
    join {{ ref("encounters") }} e on e.id = av.record_data ->> 'encounter_id'
    where e.patient_id != '{{ var("test_patient") }}'
)

select
    fc.changelog_id,
    fc.logged_at at time zone '{{ var("timezone") }}' as logged_at,
    fc.record_created_at at time zone '{{ var("timezone") }}' as created_at,
    fc.record_updated_at at time zone '{{ var("timezone") }}' as updated_at,
    fc.updated_by_user_id,
    fc.record_id as id,
    fc.record_data ->> 'date' as datetime,
    fc.record_data ->> 'batch' as batch,
    fc.record_data ->> 'consent' as is_consented,
    fc.record_data ->> 'disease' as disease,
    fc.record_data ->> 'given_by' as given_by,
    fc.record_data ->> 'given_elsewhere' as is_given_elsewhere,
    fc.record_data ->> 'circumstance_ids' as circumstance_ids,
    fc.record_data ->> 'recorder_id' as recorded_by_id,
    fc.record_data ->> 'encounter_id' as encounter_id,
    fc.record_data ->> 'location_id' as location_id,
    fc.record_data ->> 'department_id' as department_id,
    fc.record_data ->> 'vaccine_name' as vaccine_name,
    fc.record_data ->> 'vaccine_brand' as vaccine_brand,
    fc.record_data ->> 'injection_site' as injection_site,
    fc.record_data ->> 'consent_given_by' as consent_given_by,
    fc.record_data ->> 'scheduled_vaccine_id' as scheduled_vaccine_id,
    fc.record_data ->> 'status' as status,
    fc.record_data ->> 'reason' as reason,
    fc.record_data ->> 'not_given_reason_id' as not_given_reason_id
from filtered_changes fc