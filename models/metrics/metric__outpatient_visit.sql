-- metric__outpatient_visit -- D5 metric view for the outpatient visit indicator registered in
-- documentations/metrics/*.yml: opd_visit.
--
-- Per-visit (subject) grain: one row per outpatient visit, value_numeric 1, so a consumer
-- aggregates at whatever grain it needs -- any subset of the disaggregations, and any time
-- grain from day upwards (BL-002).
--
-- The registry carries the definition; this model is its implementation (BL-001).

with visit_detail as (
    select * from {{ ref('clinical__visit_detail') }}
),

visit_occurrence as (
    select * from {{ ref('clinical__visit_occurrence') }}
),

person as (
    select * from {{ ref('clinical__person') }}
),

locations as (
    select * from {{ ref('locations') }}
),

discharges as (
    select * from {{ ref('discharges') }}
),

-- BL-003: an outpatient visit is the first history segment of an encounter whose OMOP
-- visit concept is 9202/Outpatient Visit -- covering clinic, vaccination, and imaging.
opd_intake as (
    select
        visit_occurrence_id,
        person_id,
        visit_detail_start_date,
        visit_detail_start_datetime,
        care_site_id,
        -- BL-008: the clinician recorded on the intake segment
        provider_id
    from visit_detail
    where preceding_visit_detail_id is null
        and visit_detail_concept_id = 9202 -- OMOP 'Outpatient Visit'
),

-- BL-011: the end of the outpatient episode -- the first segment after intake carrying a
-- concept other than 9202. A later 9202 segment is a clinician handover or a move between
-- clinic rooms, which does not end the outpatient episode, so only a change of concept
-- counts. An encounter that never leaves 9202 falls through to the encounter end below.
opd_exits as (
    select
        later.visit_occurrence_id,
        min(later.visit_detail_start_datetime) as opd_exit__datetime
    from visit_detail later
    join opd_intake i
        on i.visit_occurrence_id = later.visit_occurrence_id
    where later.visit_detail_start_datetime > i.visit_detail_start_datetime
        and later.visit_detail_concept_id <> 9202
    group by later.visit_occurrence_id
),

-- BL-009/BL-010: the admission segment of an encounter that began as an outpatient visit --
-- the earliest segment at OMOP visit concept 9201/Inpatient Visit. Its existence is the
-- admission outcome (BL-009); its clinician is who admitted the patient (BL-010).
-- `distinct on` holds this to one row per encounter, so the left join below cannot fan out.
admission_segments as (
    select distinct on (visit_occurrence_id)
        visit_occurrence_id,
        provider_id as admission_clinician_id
    from visit_detail
    where visit_detail_concept_id = 9201 -- OMOP 'Inpatient Visit'
    order by visit_occurrence_id asc, visit_detail_start_datetime asc, visit_detail_id asc
),

-- BL-003: facility, location and demographics are resolved off the intake segment; the
-- encounter end comes from the visit occurrence (BL-002).
outpatient_visits as (
    select
        i.visit_occurrence_id,
        i.visit_detail_start_date,
        vo.visit_end_date,
        loc.facility_id,
        -- BL-006: the location itself, one level finer than facility -- lets a consumer
        -- join to bases/location_groups (or similar) for area/clinic detail later, without
        -- this model resolving that join itself
        loc.id as location_id,
        pr.gender_source_value as sex,
        -- age in whole years at the visit; the NULL rule lives in the macro
        {{ age_years('i.visit_detail_start_date', 'pr') }} as age_years,
        -- BL-008: the clinician who saw the patient in the outpatient department, as the
        -- Tamanu user id. Nullable -- an intake segment recorded with no clinician stays
        -- NULL rather than excluding the visit.
        i.provider_id as clinician_id,
        -- BL-009: whether the encounter went on to an inpatient admission. False, not NULL,
        -- where it did not -- the data tables expose this as an array filter, and Tupaia's
        -- array filter drops NULL rows.
        adm.visit_occurrence_id is not null as is_admitted,
        -- BL-010: who admitted the patient, as the Tamanu user id. NULL for a visit that was
        -- never admitted, and for an admission segment recorded with no clinician.
        adm.admission_clinician_id,
        -- BL-012: a system-generated discharge, not a clinical one. Tamanu's outpatient
        -- discharger closes encounters left open at the end of the day, so the end datetime
        -- of one of these is the sweep's clock, not when the patient actually left -- which
        -- makes its duration meaningless. Flagged, not filtered: a consumer forming a mean
        -- excludes them, a consumer counting visits keeps them. Same rule as
        -- macros/datasets/discharge_audit.sql BL-004, deliberately, so the repo has one
        -- definition of a system discharge.
        coalesce(dis.note like 'Automatically discharged%', false) as is_auto_discharge,
        -- BL-011: time in the outpatient department -- intake to the departure resolved
        -- above, falling back to the encounter end for a visit that never left 9202. NULL
        -- while the encounter is still open and nothing has ended the outpatient episode.
        case
            when coalesce(x.opd_exit__datetime, vo.visit_end_datetime) is null then null
            else extract(epoch from (
                    coalesce(x.opd_exit__datetime, vo.visit_end_datetime)
                    - i.visit_detail_start_datetime
                ))::bigint
        end as opd_time__seconds
    from opd_intake i
    -- inner join: a visit_detail row cannot exist without its parent encounter, so this
    -- always resolves
    join visit_occurrence vo
        on vo.visit_occurrence_id = i.visit_occurrence_id
    -- inner join: a visit whose patient bases/patients excludes (soft-deleted or merged
    -- away) is excluded from the metric entirely, not counted with blank demographics
    join person pr
        on pr.person_id = i.person_id
    -- inner join: encounters always carry a location in practice, so a failure to match
    -- here (the segment's location has since been soft-deleted) is a genuine anomaly --
    -- excluded from the metric rather than surfacing with a NULL facility_id
    join locations loc
        on loc.id = i.care_site_id
    -- BL-011: left join -- a visit that never left the outpatient department has no exit
    -- segment. Grouped to one row per encounter above, so it cannot fan out.
    left join opd_exits x
        on x.visit_occurrence_id = i.visit_occurrence_id
    -- BL-009/BL-010: left join -- a visit that was never admitted still counts. `distinct on`
    -- above holds it to one row per encounter, so this cannot fan out.
    left join admission_segments adm
        on adm.visit_occurrence_id = i.visit_occurrence_id
    -- BL-012: left join -- a visit with no discharge record still counts. bases/discharges is
    -- deduplicated to one row per encounter, so it cannot fan out.
    left join discharges dis
        on dis.encounter_id = i.visit_occurrence_id
)

-- D5 wide format: value_boolean is unused by this metric. period_granularity is 'day' --
-- period_start and period_end are dates, so a duration taken from them is whole days. The
-- minute-resolution duration is opd_time__minutes, derived from the underlying timestamps
-- (BL-011).
--
-- BL-007: facility_id, location_id, clinician_id and admission_clinician_id are emitted as
-- Tamanu ids, untranslated. Translating them to a consumer's own identifiers is a
-- consumer-layer concern and is done there (for Tupaia, in the data table).
select
    'opd_visit'::text as metric_id,
    null::text as variant_id,
    visit_occurrence_id::varchar as subject_id,
    visit_detail_start_date as period_start,
    -- BL-002: NULL while the encounter is open
    visit_end_date as period_end,
    'day'::text as period_granularity,
    -- BL-003: one visit per row, so the count contribution is always 1. Additive, so
    -- a data table summing it is correct at every grain.
    1::numeric as value_numeric,
    null::boolean as value_boolean,
    facility_id,
    location_id,
    sex,
    -- BL-004: age in whole years at the visit. Unbanded -- an age classification is a
    -- presentation choice a deployment may set differently, so the consumer's data table
    -- bands it.
    age_years,
    -- BL-008
    clinician_id,
    -- BL-009
    is_admitted,
    -- BL-010
    admission_clinician_id,
    -- BL-012
    is_auto_discharge,
    opd_time__seconds,
    -- BL-011: time in the outpatient department as minutes, to two decimal places --
    -- 0.6-second resolution, finer than any reporting need, and a fixed scale so the value
    -- is stable to compare. Unbanded, for the same reason as age: a mean, a median or a
    -- band set are all presentation choices, so the consumer forms them. NULL while the
    -- encounter is open.
    round(opd_time__seconds / 60.0, 2) as opd_time__minutes
from outpatient_visits
