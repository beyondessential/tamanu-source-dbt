-- metric__appointment -- D5 metric view for the outpatient appointment indicator registered in
-- documentations/metrics/*.yml: outpatient_appointment.
-- See specs/dbt-model/metric__appointment.md for the BL clauses this model implements.
--
-- Per-appointment (subject) grain: one row per scheduled outpatient appointment, value_numeric
-- 1, so a consumer aggregates at whatever grain it needs -- any subset of the
-- disaggregations, and any time grain from minute upwards (BL-003).
--
-- The registry carries the definition; this model is its implementation (BL-001).

with appointments as (
    select * from {{ ref('outpatient_appointments') }}
),

person as (
    select * from {{ ref('clinical__person') }}
),

location_groups as (
    select * from {{ ref('location_groups') }}
),

reference_data as (
    select * from {{ ref('reference_data') }}
),

-- BL-002: every outpatient appointment bases/outpatient_appointments holds -- it already drops
-- deleted appointments, test-patient appointments and location bookings (an appointment with
-- no appointment type) -- whatever its status.
outpatient_appointments as (
    select
        a.id as appointment_id,
        a.start_datetime,
        a.end_datetime,
        -- BL-005: the facility is the appointment's location group's facility.
        lg.facility_id,
        -- BL-006
        coalesce(lg.name, 'Not recorded') as location_group_name,
        -- BL-007
        coalesce(a.status, 'Not recorded') as appointment_status,
        -- BL-008
        coalesce(appointment_type.name, 'Not recorded') as appointment_type,
        -- BL-009
        pr.gender_source_value as sex,
        {{ age_years('a.start_datetime::date', 'pr') }} as age_years
    from appointments a
    -- BL-009: inner -- an appointment whose patient bases/patients excludes (deleted or
    -- merged) is dropped rather than counted with blank demographics. The patient id is used
    -- only for this join and is not emitted (BL-010).
    join person pr
        on pr.person_id = a.patient_id
    -- BL-005: inner -- an appointment whose location group does not resolve is dropped rather
    -- than attributed to a NULL facility.
    join location_groups lg
        on lg.id = a.location_group_id
    -- BL-008: left -- an appointment type that no longer resolves still counts.
    left join reference_data appointment_type
        on appointment_type.id = a.appointment_type_id
)

-- D5 wide format: value_boolean is unused by this metric.
select
    'outpatient_appointment'::text as metric_id,
    null::text as variant_id,
    appointment_id::varchar as subject_id,
    -- BL-004: the scheduled start and end, at minute grain. period_end is NULL where the
    -- appointment records no end.
    date_trunc('minute', start_datetime) as period_start,
    date_trunc('minute', end_datetime) as period_end,
    'minute'::text as period_granularity,
    -- BL-003: one appointment per row, so the count contribution is always 1.
    1::numeric as value_numeric,
    null::boolean as value_boolean,
    facility_id,
    sex,
    -- BL-009: unbanded -- banding is the consumer's.
    age_years,
    appointment_status,
    appointment_type,
    location_group_name
from outpatient_appointments
