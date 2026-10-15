with base as (
    select count(distinct e.id) as total_encounters
    from {{ ref('encounters') }} e
    -- Mirrors the report's history join. No join to users: the report left-joins the
    -- history actor (BL-007 of specs/reports/encounter-summary.md), so an encounter
    -- whose history rows carry no actor is still reported, and must still be counted.
    join {{ ref('encounter_history') }} eh
        on eh.encounter_id = e.id
    join {{ ref('locations') }} l
        on l.id = e.location_id
    join {{ ref('facilities') }} f
        on f.id = l.facility_id
    join {{ ref('departments') }} dp
        on dp.id = e.department_id
    join {{ ref('patients') }} p
        on p.id = e.patient_id
    where f.sensitive_network_id is null
        and e.end_datetime is not null
        and e.end_datetime >= '2024-01-01'::date
        and e.end_datetime <= '2024-01-31'::date
        and e.patient_id != '{{ var("test_patient") }}'
),

report as (
    select count(*) as total_encounters
    from {{ ref('encounter-summary-by-end-date') }}
)

select
    base.total_encounters as base_total_encounters,
    report.total_encounters as report_total_encounters
from base
join report on report.total_encounters != base.total_encounters
