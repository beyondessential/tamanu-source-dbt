-- metric__opd_imaging_request -- D5 metric view for the OPD-scoped imaging request indicator
-- registered in documentations/metrics/outpatient.yml: opd_imaging_request (MAUI-6806).
--
-- Per-request (subject) grain: one row per imaging request raised while the patient's active
-- clinical__visit_detail segment was a clinic encounter, value_numeric 1, so a consumer
-- aggregates at whatever grain it needs. See specs/dbt-model/metric__opd_imaging_request.md
-- BL-003 for why this is clinic-only rather than the full OMOP 9202 clinic/imaging/vaccination
-- definition metric__outpatient_visit and metric__opd_procedure both use, and BL-004 for why
-- the as-of join is evaluated at request time rather than completion time, and for the
-- first-segment clamp applied when a request predates every segment.
--
-- BL-010: sourced from clinical__procedure_occurrence's imaging branch, not bases/imaging_requests
-- directly -- the same clinical layer metric__procedure and metric__opd_procedure build on.
-- deleted/entered_in_error rows are already excluded there (its own BL-002), so this model does
-- not re-filter status. Facility and completion still need bases/-level detail the clinical
-- model doesn't carry (BL-004, BL-002) -- see those clauses for what and why.
--
-- The registry carries the definition; this model is its implementation.

with procedure_occurrence as (
    select * from {{ ref('clinical__procedure_occurrence') }}
    where procedure_type_source_value = 'imaging request'
),

imaging_results as (
    select * from {{ ref('imaging_results') }}
),

imaging_request_areas as (
    select * from {{ ref('imaging_request_areas') }}
),

reference_data as (
    select * from {{ ref('reference_data') }}
),

notes as (
    select * from {{ ref('notes') }}
),

visit_detail as (
    select * from {{ ref('clinical__visit_detail') }}
),

person as (
    select * from {{ ref('clinical__person') }}
),

locations as (
    select * from {{ ref('locations') }}
),

-- BL-002: one completion timestamp per request -- the earliest recorded result, the same
-- rule macros/datasets/imaging_requests.sql uses for ds__imaging_requests.completed_datetime.
completions as (
    select
        imaging_request_id,
        min(datetime) as completed_datetime
    from imaging_results
    group by imaging_request_id
),

-- BL-007: legacy free-text area fallback, one row per request.
imaging_area_notes as (
    select
        record_id as imaging_request_id,
        string_agg(content, ', ' order by datetime) as imaging_area
    from notes
    where record_type = 'ImagingRequest'
        and note_type = 'areaToBeImaged'
    group by record_id
),

-- BL-007: structured body-area names, one row per request -- the same shape
-- macros/datasets/imaging_requests.sql already builds. procedure_occurrence_id is
-- imaging_requests.id unchanged (BL-010), so it joins straight to these bases/ tables.
imaging_areas as (
    select
        po.procedure_occurrence_id as imaging_request_id,
        coalesce(
            string_agg(rd.name, ', ' order by rd.name),
            n.imaging_area
        ) as imaging_area
    from procedure_occurrence po
    left join imaging_request_areas ira on ira.imaging_request_id = po.procedure_occurrence_id
    left join reference_data rd on rd.id = ira.area_id
    left join imaging_area_notes n on n.imaging_request_id = po.procedure_occurrence_id
    group by po.procedure_occurrence_id, n.imaging_area
),

-- BL-003, BL-004: the visit_detail segment active at the moment each request was raised --
-- the latest segment whose start is at or before requested_date, tie-broken on
-- visit_detail_id descending on a same-instant tie. The same as-of pattern
-- metric__opd_procedure uses, anchored on requested_date rather than a completion event so a
-- still-open or cancelled request (no completion timestamp) still resolves to a segment.
-- Also carries care_site_id -- the segment's own location, used for facility (BL-005).
--
-- BL-004: clamped to the first segment when the request predates every segment (Juliana,
-- MAUI-6806/MAUI-6862) -- a request genuinely belongs to its own encounter, so a segment
-- recorded starting after the request (a data-timing artifact, not a real ordering issue)
-- should not exclude it. No join condition on the timestamp: every encounter has >= 1
-- segment (clinical__visit_detail BL-005), so the join itself can never drop a row -- the
-- order by picks the correct as-of segment where one qualifies, and falls back to the
-- earliest segment otherwise.
active_segment_at_request as (
    select distinct on (po.procedure_occurrence_id)
        po.procedure_occurrence_id as imaging_request_id,
        vd.person_id,
        vd.visit_detail_source_value,
        vd.care_site_id
    from procedure_occurrence po
    join visit_detail vd
        on vd.visit_occurrence_id = po.visit_occurrence_id
    order by
        po.procedure_occurrence_id,
        (vd.visit_detail_start_datetime <= po.procedure_datetime) desc,
        case when vd.visit_detail_start_datetime <= po.procedure_datetime
             then vd.visit_detail_start_datetime end desc,
        case when vd.visit_detail_start_datetime > po.procedure_datetime
             then vd.visit_detail_start_datetime end asc,
        vd.visit_detail_id desc
),

requests as (
    select
        po.procedure_occurrence_id as imaging_request_id,
        po.procedure_datetime as requested_datetime,
        -- BL-002: only a completed request has a real completion event to report -- an
        -- imaging_results row can exist against a still-open or cancelled request (e.g. a
        -- preliminary result entered before cancellation), so this is gated on
        -- is_completed rather than surfacing c.completed_datetime unconditionally, the
        -- same guard macros/datasets/imaging_requests.sql applies via its own status check.
        case when po.is_completed then c.completed_datetime end as completed_datetime,
        loc.facility_id,
        pr.gender_source_value as sex,
        {{ age_years('po.procedure_date', 'pr') }} as age_years,
        po.is_completed,
        po.procedure_source_value as imaging_type_code_raw,
        po.procedure_source_name as imaging_type_raw,
        areas.imaging_area as imaging_area_raw
    from procedure_occurrence po
    join active_segment_at_request seg
        on seg.imaging_request_id = po.procedure_occurrence_id
    join person pr
        on pr.person_id = seg.person_id
    -- inner join: the segment's own location, not the request's location_group_id (BL-005) --
    -- excluded rather than attributed to a NULL facility, the same "excluded rather than
    -- guessed" convention metric__opd_procedure uses for its own location join.
    join locations loc
        on loc.id = seg.care_site_id
    left join completions c
        on c.imaging_request_id = po.procedure_occurrence_id
    left join imaging_areas areas
        on areas.imaging_request_id = po.procedure_occurrence_id
    -- BL-003: clinic only -- not OMOP concept 9202, which would also admit imaging and
    -- vaccination encounter types (decision, MAUI-6806).
    where seg.visit_detail_source_value = 'clinic'
)

-- D5 wide format: value_boolean is unused by this metric.
select
    'opd_imaging_request'::text as metric_id,
    null::text as variant_id,
    imaging_request_id::varchar as subject_id,
    requested_datetime as period_start,
    -- BL-002: NULL unless the request has completed.
    completed_datetime as period_end,
    'minute'::text as period_granularity,
    -- BL-001: one request per row, so the count contribution is always 1. Additive, so a
    -- data table summing it is correct at every grain.
    1::numeric as value_numeric,
    null::boolean as value_boolean,
    facility_id,
    sex,
    -- BL-010: the clinical model's own completion flag -- cancelled and still-open requests
    -- are both false, indistinguishable from each other by this column alone (out of scope
    -- for the current visual; see bases/imaging_requests.status for the full lifecycle if
    -- that distinction is needed later).
    is_completed,
    -- BL-007: raw Tamanu modality value, never NULL.
    coalesce(imaging_type_code_raw, 'Not recorded') as imaging_type_code,
    -- BL-007: readable modality label, falling back to the raw code where the shared
    -- imaging_type__label macro doesn't recognise it, never NULL -- the same
    -- name/code pair metric__procedure emits as procedure/procedure_code.
    coalesce(imaging_type_raw, imaging_type_code_raw, 'Not recorded') as imaging_type,
    -- BL-007: aggregated body area, never NULL.
    coalesce(imaging_area_raw, 'Not recorded') as imaging_area,
    -- BL-008: a measure, not a dimension -- age classification is the consumer's.
    age_years
from requests
