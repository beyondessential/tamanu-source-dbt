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

-- BL-008/BL-010: OMOP PROVIDER wrapper over bases/users. One row per user, so the joins
-- below cannot fan out.
provider as (
    select * from {{ ref('ref__provider') }}
),

-- BL-013: the intake segment's own department, resolved to a name for metric_filters scoping.
departments as (
    select * from {{ ref('departments') }}
),

-- BL-003: an outpatient visit is the first history segment of an encounter whose OMOP
-- visit concept is 9202/Outpatient Visit -- covering clinic, vaccination, and imaging.
opd_intake as (
    select
        visit_occurrence_id,
        -- the ordering key both CTEs below compare against (BL-011)
        visit_detail_id,
        person_id,
        visit_detail_start_date,
        visit_detail_start_datetime,
        care_site_id,
        -- BL-008: the clinician recorded on the intake segment
        provider_id,
        -- BL-013
        department_id
    from visit_detail
    where preceding_visit_detail_id is null
        and visit_detail_concept_id = 9202 -- OMOP 'Outpatient Visit'
),

-- BL-011: the end of the outpatient episode -- the first segment after intake at a concept
-- other than 9202. A later 9202 segment is a handover or a room move, not a departure. An
-- encounter that never leaves 9202 falls through to the encounter end below.
--
-- Compared on (datetime, visit_detail_id), the key clinical__visit_detail orders its own
-- window by, not on datetime alone: the two can tie, and on datetime alone a tied segment
-- reads as simultaneous rather than later. See BL-011.
opd_exits as (
    select
        later.visit_occurrence_id,
        min(later.visit_detail_start_datetime) as opd_exit__datetime
    from visit_detail later
    join opd_intake i
        on i.visit_occurrence_id = later.visit_occurrence_id
    where (later.visit_detail_start_datetime, later.visit_detail_id)
        > (i.visit_detail_start_datetime, i.visit_detail_id)
        and later.visit_detail_concept_id <> 9202
    group by later.visit_occurrence_id
),

-- BL-009/BL-010: the earliest segment at concept 9201. Its existence is the admission
-- outcome; its clinician is who admitted the patient. `distinct on` holds it to one row per
-- encounter, so the left join below cannot fan out.
admission_segments as (
    select distinct on (adm.visit_occurrence_id)
        adm.visit_occurrence_id,
        adm.provider_id as admission_clinician_id
    from visit_detail adm
    -- joined to the intake so this ranks only outpatient encounters, and so the admission is
    -- ordered against the intake on the same key opd_exits uses
    join opd_intake i
        on i.visit_occurrence_id = adm.visit_occurrence_id
    where adm.visit_detail_concept_id = 9201 -- OMOP 'Inpatient Visit'
        and (adm.visit_detail_start_datetime, adm.visit_detail_id)
        > (i.visit_detail_start_datetime, i.visit_detail_id)
    order by adm.visit_occurrence_id asc, adm.visit_detail_start_datetime asc, adm.visit_detail_id asc
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
        -- BL-008: who saw the patient in clinic. The id keeps its NULL as a key; the label
        -- takes 'Not recorded', because a NULL is dropped by the array filter a consumer
        -- exposes it through.
        i.provider_id as clinician_id,
        coalesce(clin.provider_name, 'Not recorded') as clinician_name,
        -- BL-009: false, not NULL, where the visit was not admitted -- same array-filter
        -- reason as above.
        adm.visit_occurrence_id is not null as is_admitted,
        -- BL-010: who admitted the patient. 'Not recorded' here also covers the ordinary case
        -- of a visit never admitted, so a card ranking it scopes itself to is_admitted.
        adm.admission_clinician_id,
        coalesce(adm_clin.provider_name, 'Not recorded') as admission_clinician_name,
        -- BL-012: a system-generated discharge, so the encounter end is the discharge
        -- sweep's clock rather than when the patient left. Flagged, not filtered. Same
        -- predicate as macros/datasets/discharge_audit.sql BL-004, so the repo holds one
        -- definition of a system discharge.
        coalesce(dis.note like 'Automatically discharged%', false) as is_auto_discharge,
        -- BL-013
        coalesce(dept.name, 'Not recorded') as department,
        -- BL-011: intake to the departure resolved above, falling back to the encounter
        -- end. NULL while the encounter is open and nothing has ended the episode.
        case
            when coalesce(x.opd_exit__datetime, vo.visit_end_datetime) is null then null
            else extract(epoch from (
                    coalesce(x.opd_exit__datetime, vo.visit_end_datetime)
                    - i.visit_detail_start_datetime
                ))::bigint
        end as opd_time__seconds
    from opd_intake i
    -- inner: always resolves, a segment cannot exist without its encounter
    join visit_occurrence vo
        on vo.visit_occurrence_id = i.visit_occurrence_id
    -- inner: a visit whose patient bases/patients excludes (deleted or merged) is dropped
    -- rather than counted with blank demographics
    join person pr
        on pr.person_id = i.person_id
    -- inner: a visit whose location does not resolve is dropped rather than attributed to a
    -- NULL facility (BL-006)
    join locations loc
        on loc.id = i.care_site_id
    -- left: a visit that never left outpatient care has no exit segment
    left join opd_exits x
        on x.visit_occurrence_id = i.visit_occurrence_id
    -- left: a visit that was never admitted still counts
    left join admission_segments adm
        on adm.visit_occurrence_id = i.visit_occurrence_id
    -- left: a visit with no discharge still counts
    left join discharges dis
        on dis.encounter_id = i.visit_occurrence_id
    -- left: a visit with no clinician, or a deleted user, still counts
    left join provider clin
        on clin.provider_id = i.provider_id
    left join provider adm_clin
        on adm_clin.provider_id = adm.admission_clinician_id
    -- left: a visit with no department set still counts
    left join departments dept
        on dept.id = i.department_id
)

-- D5 wide format: value_boolean is unused. period_granularity is 'day' -- period_start and
-- period_end are dates, so opd_time__minutes carries the minute-resolution duration (BL-011).
--
-- BL-007: facility_id and location_id stay untranslated Tamanu ids, crosswalked by the
-- consumer. The clinician is the exception -- id and display name are both emitted, so a
-- consumer charting by clinician needs no join.
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
    clinician_name,
    -- BL-009
    is_admitted,
    -- BL-010
    admission_clinician_id,
    admission_clinician_name,
    -- BL-012
    is_auto_discharge,
    -- BL-011: minutes to two decimal places, a fixed scale so the value is stable to
    -- compare. Unbanded and unaveraged, for the same reason as age: those are presentation
    -- choices the consumer makes.
    round(opd_time__seconds / 60.0, 2) as opd_time__minutes,
    -- BL-013
    department
from outpatient_visits
