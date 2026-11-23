{#- Body of `patient_program_registration_conditions_change_logs` and of its copy for each sensitive network. See
    specs/dbt-model/sensitive-facility-partition.md for the BL clauses. -#}
{%- macro patient_program_registration_conditions_change_logs_base(network=none) -%}
with filtered_changes as (
    -- noqa: disable=LT01,LT02
    {{ base_history_from_log('patient_program_registration_conditions') }}
        and (
            version = 'unknown'
            or string_to_array(version, '.')::int[] >= string_to_array('2.33.0', '.')::int[]
        )
        -- BL-008: a change follows the partition of the record it describes, as that record is now
        and {{ facility_id_in_partition("(select ppr.registering_facility_id from " ~ source('tamanu', 'patient_program_registration_conditions') ~ " pprc join " ~ source('tamanu', 'patient_program_registrations') ~ " ppr on ppr.id = pprc.patient_program_registration_id where pprc.id::text = record_id)", network) }}
        {%- if is_incremental() %}
        and record_id in ({{ changed_since_last_run('patient_program_registration_conditions') }})
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
    fc.record_data ->> 'program_registry_condition_id' as program_registry_condition_id,
    fc.record_data ->> 'patient_program_registration_id' as patient_program_registration_id,
    fc.record_data ->> 'program_registry_condition_category_id' as program_registry_condition_category_id,
    fc.record_data ->> 'reason_for_change' as reason_for_change,
    fc.record_data ->> 'clinician_id' as recorded_by_id,
    (fc.record_data ->> 'deletion_date')::timestamp as deleted_datetime,
    fc.record_data ->> 'deletion_clinician_id' as deleted_by_id,
    fc.updated_at_sync_tick
from filtered_changes fc
{%- endmacro %}
