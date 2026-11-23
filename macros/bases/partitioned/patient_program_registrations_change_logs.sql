{#- Body of `patient_program_registrations_change_logs` and of its copy for each sensitive network. See
    specs/dbt-model/sensitive-facility-partition.md for the BL clauses. -#}
{%- macro patient_program_registrations_change_logs_base(network=none) -%}
with filtered_changes as (
    -- noqa: disable=LT01,LT02
    {{ base_history_from_log('patient_program_registrations') }}
        and (
            version = 'unknown'
            or string_to_array(version, '.')::int[] >= string_to_array('2.33.0', '.')::int[]
        )
        and record_data ->> 'patient_id' != '{{ var("test_patient") }}'
        -- BL-008: a change follows the partition of the record it describes, as that record is now
        and {{ facility_id_in_partition("(select ppr.registering_facility_id from " ~ source('tamanu', 'patient_program_registrations') ~ " ppr where ppr.id::text = record_id)", network) }}
        {%- if is_incremental() %}
        and record_id in ({{ changed_since_last_run('patient_program_registrations') }})
        {%- endif %}
    -- noqa: enable=LT01,LT02
)

select
    fc.changelog_id,
    fc.logged_at at time zone '{{ var("timezone") }}' as logged_at,
    -- sort-only: local logged_at repeats an hour at a DST fall-back, so order history by this
    fc.logged_at at time zone 'UTC' as logged_at_utc,
    fc.updated_by_user_id,
    fc.record_id as id,
    (fc.record_data ->> 'date')::timestamp as datetime,
    fc.record_data ->> 'registration_status' as registration_status,
    fc.record_data ->> 'patient_id' as patient_id,
    fc.record_data ->> 'program_registry_id' as program_registry_id,
    fc.record_data ->> 'clinical_status_id' as clinical_status_id,
    fc.record_data ->> 'clinician_id' as registered_by_id,
    fc.record_data ->> 'registering_facility_id' as registering_facility_id,
    fc.record_data ->> 'facility_id' as facility_id,
    fc.record_data ->> 'village_id' as village_id,
    fc.record_data ->> 'deactivated_clinician_id' as deactivated_by_id,
    (fc.record_data ->> 'deactivated_date')::timestamp as deactivated_datetime,
    fc.record_updated_at at time zone '{{ var("timezone") }}' as record_updated_at,
    fc.record_updated_at at time zone 'UTC' as record_updated_at_utc,
    fc.updated_at_sync_tick
from filtered_changes fc
{%- endmacro %}
