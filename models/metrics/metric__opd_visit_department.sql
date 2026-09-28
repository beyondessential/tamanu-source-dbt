-- metric__opd_visit_department -- D5 metric view for the outpatient visit-by-department
-- indicator registered in documentations/metrics/*.yml: opd_visit_department.
--
-- Segment grain (BL-001): one row per outpatient visit's clinical__visit_detail segment --
-- deliberately NOT one row per (metric_id, subject_id) like every sibling metric asserts via
-- its own AC-001. Built to answer "did this encounter ever touch department X, and how long
-- did it spend there", which metric__outpatient_visit's intake-only department (its own
-- BL-013) cannot: a pure department transfer with no encounter_type change still opens a new
-- clinical__visit_detail segment, invisible past an intake-only filter. subject_id legitimately
-- repeats once per segment -- see the spec's § Consumers for what that means for aggregation.
--
-- metric__outpatient_visit itself is left untouched: it is already shipped and consumed by
-- the unrelated `outpatient` Tupaia product, so this is an additive new metric, not a
-- modification. Its opd_intake/admission_segments logic is duplicated here rather than
-- ref()'d -- no metric in this repo currently references another metric, and the one thing
-- that differs (department/clinician/time) isn't reusable through that ref anyway. Keep this
-- in sync with metric__outpatient_visit.sql's own BL-003/BL-008..BL-012 if either changes.
--
-- The registry carries the definition; this model is its implementation.

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

-- one row per user, so the joins below cannot fan out
provider as (
    select * from {{ ref('ref__provider') }}
),

-- BL-005: resolved per segment now, not per encounter -- see the final select
departments as (
    select * from {{ ref('departments') }}
),

-- same population as metric__outpatient_visit's own opd_intake: an outpatient visit is the
-- first history segment of an encounter whose OMOP visit concept is 9202/Outpatient Visit
opd_intake as (
    select
        visit_occurrence_id,
        visit_detail_id,
        person_id,
        visit_detail_start_date,
        visit_detail_start_datetime,
        care_site_id
    from visit_detail
    where preceding_visit_detail_id is null
        and visit_detail_concept_id = 9202 -- OMOP 'Outpatient Visit'
),

-- same as metric__outpatient_visit's own admission_segments: the earliest segment at concept
-- 9201, ranked to one row per encounter so the left join below cannot fan out
admission_segments as (
    select distinct on (adm.visit_occurrence_id)
        adm.visit_occurrence_id,
        adm.provider_id as admission_clinician_id
    from visit_detail adm
    join opd_intake i
        on i.visit_occurrence_id = adm.visit_occurrence_id
    where adm.visit_detail_concept_id = 9201 -- OMOP 'Inpatient Visit'
        and (adm.visit_detail_start_datetime, adm.visit_detail_id)
        > (i.visit_detail_start_datetime, i.visit_detail_id)
    order by adm.visit_occurrence_id asc, adm.visit_detail_start_datetime asc, adm.visit_detail_id asc
),

-- BL-001: every clinical__visit_detail segment belonging to an outpatient encounter --
-- deliberately not collapsed to one row per department. An encounter that leaves and
-- re-enters the same department produces two rows here on purpose, so a consumer can sum
-- segment_time__minutes across them for total time in that department. clinical__visit_detail
-- bounds each segment at the next segment's start (its own BL-002), so segments are
-- contiguous with no gaps -- summing durations for one department is correct however finely
-- an unrelated field change (e.g. an examiner handover) sliced the segments.
opd_segments as (
    select
        vd.visit_occurrence_id,
        vd.visit_detail_id,
        vd.department_id,
        -- this segment's own clinician, not the encounter's intake clinician -- more
        -- accurate for a segment the encounter was transferred into
        vd.provider_id,
        vd.visit_detail_start_date,
        vd.visit_detail_start_datetime,
        vd.visit_detail_end_date,
        vd.visit_detail_end_datetime,
        -- NULL while the segment (and therefore the encounter) is still open, not zero
        case
            when vd.visit_detail_end_datetime is null then null
            else extract(epoch from (
                    vd.visit_detail_end_datetime - vd.visit_detail_start_datetime
                ))::bigint
        end as segment_time__seconds
    from visit_detail vd
    join opd_intake i
        on i.visit_occurrence_id = vd.visit_occurrence_id
    -- bounded to the outpatient episode itself, the same boundary
    -- metric__outpatient_visit's own opd_time__minutes uses (its BL-011): a segment after the
    -- visit transitions to a different OMOP concept (an inpatient admission, most commonly)
    -- belongs to that different episode, not to this outpatient visit's own department
    -- history. clinical__visit_detail's own lead()-based end-dating already closes the last
    -- included 9202 segment at that transition segment's start (or the encounter end, for a
    -- visit that never leaves 9202), so no separate exit-finding logic is needed here.
    where vd.visit_detail_concept_id = 9202
),

-- the encounter-level attributes every segment row carries unchanged -- everything except
-- department/clinician/time, which are the segment's own (BL-002 above). Facility/location
-- stay intake-based, the same as metric__outpatient_visit's own BL-006 -- out of scope for
-- this metric, which is about department and time only.
outpatient_visits as (
    select
        i.visit_occurrence_id,
        loc.facility_id,
        loc.id as location_id,
        pr.gender_source_value as sex,
        {{ age_years('i.visit_detail_start_date', 'pr') }} as age_years,
        adm.visit_occurrence_id is not null as is_admitted,
        adm.admission_clinician_id,
        coalesce(adm_clin.provider_name, 'Not recorded') as admission_clinician_name,
        coalesce(dis.note like 'Automatically discharged%', false) as is_auto_discharge
    from opd_intake i
    -- inner: population parity with metric__outpatient_visit -- clinical__visit_occurrence's
    -- own map__omop_visit_type join can drop an encounter whose (current) encounter_type is
    -- unmapped even though an earlier segment mapped to 9202; not selected from otherwise
    join visit_occurrence vo
        on vo.visit_occurrence_id = i.visit_occurrence_id
    -- inner: a visit whose patient bases/patients excludes (deleted or merged) is dropped
    -- rather than counted with blank demographics
    join person pr
        on pr.person_id = i.person_id
    -- inner: a visit whose location does not resolve is dropped rather than attributed to a
    -- NULL facility
    join locations loc
        on loc.id = i.care_site_id
    left join admission_segments adm
        on adm.visit_occurrence_id = i.visit_occurrence_id
    left join discharges dis
        on dis.encounter_id = i.visit_occurrence_id
    left join provider adm_clin
        on adm_clin.provider_id = adm.admission_clinician_id
)

-- D5 wide format: value_boolean is unused. period_granularity is 'day'. period_start/
-- period_end are this segment's own start/end (BL-002), not the encounter's overall dates --
-- the "did this encounter ever touch department X" question is answered by how a consumer
-- scopes and aggregates this data, not by how this metric shapes its rows.
--
-- BL-001 (repeat, made explicit at the point of output): summing value_numeric or
-- segment_time__minutes with no department scope is meaningless -- an encounter touching
-- three departments contributes three rows. Valid once a consumer scopes to exactly one
-- department and counts/sums distinct subject_id -- see the spec for why this metric departs
-- from metric__outpatient_visit's own "count(distinct subject_id) and sum(value_numeric)
-- agree" guarantee.
select
    'opd_visit_department'::text as metric_id,
    null::text as variant_id,
    ov.visit_occurrence_id::varchar as subject_id,
    -- BL-001: the segment's own id is the grain key -- period_start is a date, so two
    -- segments of one visit on the same day share it
    s.visit_detail_id::varchar as segment_id,
    s.visit_detail_start_date as period_start,
    s.visit_detail_end_date as period_end,
    'day'::text as period_granularity,
    1::numeric as value_numeric,
    null::boolean as value_boolean,
    ov.facility_id,
    ov.location_id,
    ov.sex,
    ov.age_years,
    s.provider_id as clinician_id,
    coalesce(clin.provider_name, 'Not recorded') as clinician_name,
    ov.is_admitted,
    ov.admission_clinician_id,
    ov.admission_clinician_name,
    ov.is_auto_discharge,
    round(s.segment_time__seconds / 60.0, 2) as segment_time__minutes,
    coalesce(dept.name, 'Not recorded') as department
from outpatient_visits ov
join opd_segments s
    on s.visit_occurrence_id = ov.visit_occurrence_id
left join provider clin
    on clin.provider_id = s.provider_id
left join departments dept
    on dept.id = s.department_id
