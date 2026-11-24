{#- Body of `outpatient_appointments_change_logs` and of its copy for each sensitive network. See
    specs/dbt-model/sensitive-facility-partition.md for the BL clauses. -#}
{%- macro outpatient_appointments_change_logs_base(network=none) -%}
-- BL-037: thin projection of the appointment change log -- source filters, no window
-- functions, so consumers can filter it and have the predicate reach the scan. The windowed
-- change history is built in outpatient_appointments_change_history(), which cannot be
-- filtered that way.
-- logged_at and record_updated_at are in the deployment's local time, as in every other
-- change-log base (MAUI-6960).
select
    c.id as changelog_id,
    c.record_id as appointment_id,
    c.logged_at at time zone '{{ var("timezone") }}' as logged_at,
    c.record_updated_at at time zone '{{ var("timezone") }}' as record_updated_at,
    -- sort-only: local logged_at and record_updated_at repeat an hour at a DST fall-back, so
    -- order history by these
    c.logged_at at time zone 'UTC' as logged_at_utc,
    c.record_updated_at at time zone 'UTC' as record_updated_at_utc,
    c.updated_by_user_id,
    c.updated_at_sync_tick,
    c.record_data
from {{ source('logs__tamanu', 'changes') }} c
-- BL-037: the change-log source filters. A row is excluded where the appointment was
-- already flagged deleted when that row was written -- see BL-035 case 4
where c.table_name = 'appointments'
    and c.record_deleted_at is null
    and (c.record_data ->> 'appointment_type_id') is not null
    and (c.record_data ->> 'patient_id') != '{{ var("test_patient") }}'
    -- BL-008: a change follows the partition of the record it describes, as that record is now
    and {{ location_group_id_in_partition("(select pa.location_group_id from " ~ source('tamanu', 'appointments') ~ " pa where pa.id = c.record_id)", network) }}
{%- if is_incremental() %}
    and c.record_id in ({{ changed_since_last_run('appointments') }})
    {%- endif %}
{%- endmacro %}
