{#- Body of `outpatient_appointments` and of its copy for each sensitive network. See
    specs/dbt-model/sensitive-facility-partition.md for the BL clauses. -#}
{%- macro outpatient_appointments_base(network=none) -%}
select
    a.id,
    a.created_at at time zone '{{ var("timezone") }}' as created_datetime,
    a.start_time::timestamp as start_datetime,
    a.end_time::timestamp as end_datetime,
    a.patient_id,
    a.clinician_id,
    a.encounter_id,
    a.schedule_id,
    a.location_group_id,
    a.appointment_type_id,
    case
        when a.is_high_priority then 'Yes' else 'No'
    end as priority,
    a.status,
    s.until_date::date as until_date,
    s.interval,
    s.days_of_week,
    s.frequency,
    s.nth_weekday,
    s.occurrence_count,
    s.is_fully_generated,
    s.generated_until_date,
    s.cancelled_at_date,
    a.updated_at_sync_tick
from {{ source('tamanu', 'appointments') }} a
left join {{ source('tamanu', 'appointment_schedules') }} s on s.id = a.schedule_id
where a.deleted_at is null
    and a.patient_id != '{{ var("test_patient") }}'
    and a.appointment_type_id notnull
    -- BL-001: the appointment's location group decides the partition
    and {{ location_group_id_in_partition('a.location_group_id', network) }}
{%- if is_incremental() %}
    and a.updated_at_sync_tick >= {{ last_sync_tick() }}
    {%- endif %}
{%- endmacro %}
