-- metric__imaging_request -- D5 metric view for the imaging-request indicator registered
-- in documentations/metrics/imaging.yml: imaging_request (MAUI-6806).
--
-- Per-request (subject) grain: one row per imaging request, value_numeric 1, so a consumer
-- aggregates at whatever grain it needs. It is the imaging-request counterpart to
-- metric__procedure over the same clinical model.
-- See specs/dbt-model/metric__imaging_request.md for BL-001..BL-011.
--
-- BL-003: encounter_type is the setting the request was raised in -- read off the
-- clinical__visit_detail segment clinical__procedure_occurrence resolves as its
-- visit_detail_id (that model's BL-005), not the encounter's own whole-visit type. A
-- request raised during the triage phase of an encounter later admitted is an emergency
-- request, not an inpatient one. A consumer scopes a setting by filtering this column:
-- 'clinic' for outpatient imaging and 'admission' for inpatient. Outpatient imaging is
-- clinic only, narrower than OMOP 9202, which also admits imaging- and vaccination-typed
-- encounters -- an imaging-typed encounter and an imaging request are independent Tamanu
-- concepts that happen to share a name (MAUI-6806). Emergency imaging is
-- metric__ed_imaging_request's population, on OMOP 9203.
--
-- BL-010: sourced from clinical__procedure_occurrence's imaging branch, not
-- bases/imaging_requests directly -- the same clinical layer metric__procedure builds on.
-- deleted/entered_in_error rows are already excluded there (its own BL-002), so this model
-- does not re-filter status.
--
-- BL-005: facility_id is the resolved segment's own care_site_id, the same source
-- metric__procedure uses, so a procedure and an imaging request belonging to one segment
-- agree on facility. Not imaging_requests.location_id, which is deprecated in Tamanu and
-- effectively unpopulated (see clinical__procedure_occurrence's imaging_branch comment on
-- that column).
--
-- The registry carries the definition and this model is its implementation.

with procedure_occurrence as (
    select * from {{ ref('clinical__procedure_occurrence') }}
    where procedure_type_source_value = 'imaging request'
),

visit_detail as (
    select * from {{ ref('clinical__visit_detail') }}
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

person as (
    select * from {{ ref('clinical__person') }}
),

locations as (
    select * from {{ ref('locations') }}
),

-- BL-011: the resolved segment's own department, resolved to a name for metric_filters
-- scoping. It comes off the segment directly, since bases/locations carries no
-- department_id.
departments as (
    select * from {{ ref('departments') }}
),

-- BL-002: one completion timestamp per request -- the earliest recorded result, the same
-- rule macros/datasets/imaging_requests.sql uses for
-- ds__imaging_requests.completed_datetime.
completions as (
    select
        imaging_request_id,
        min(datetime) as completed_datetime
    from imaging_results
    group by imaging_request_id
),

-- BL-007: the current revision of each imaging-request note. Ranked before the note_type
-- filter, since a revision can change a note's type.
imaging_request_notes as (
    select
        notes.id,
        notes.record_id,
        notes.note_type,
        notes.content,
        notes.datetime,
        notes.created_datetime,
        {{ notes__revision_rank('notes') }} as revision_rank
    from notes
    where notes.record_type = 'ImagingRequest'
),

-- BL-007: legacy free-text area fallback, one row per request, in the order the notes were
-- recorded. created_datetime and id break a same-second tie so the string is stable.
imaging_area_notes as (
    select
        record_id as imaging_request_id,
        string_agg(content, ', ' order by datetime, created_datetime, id) as imaging_area
    from imaging_request_notes
    where revision_rank = 1
        and note_type = 'areaToBeImaged'
    group by record_id
),

-- BL-007: structured body-area names, one row per request -- the same shape
-- macros/datasets/imaging_requests.sql already builds. procedure_occurrence_id is
-- imaging_requests.id unchanged, so it joins straight to these bases/ tables.
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

requests as (
    select
        po.procedure_occurrence_id as imaging_request_id,
        po.procedure_datetime as requested_datetime,
        -- BL-002: only a completed request has a real completion event to report -- an
        -- imaging_results row can exist against a still-open or cancelled request (e.g. a
        -- preliminary result entered before cancellation), so this is gated on
        -- is_completed rather than surfacing c.completed_datetime unconditionally.
        case when po.is_completed then c.completed_datetime end as completed_datetime,
        loc.facility_id,
        -- BL-003: the segment the request was raised in, not the encounter's whole-visit
        -- type -- lets a consumer scope to inpatient, emergency, or outpatient imaging
        -- requests without a separate metric per setting, and agrees with the scoped
        -- siblings, which filter this same segment.
        vd.visit_detail_source_value as encounter_type,
        pr.gender_source_value as sex,
        {{ age_years('po.procedure_date', 'pr') }} as age_years,
        po.is_completed,
        po.procedure_source_value as imaging_type_code_raw,
        po.procedure_source_name as imaging_type_raw,
        areas.imaging_area as imaging_area_raw,
        -- BL-011
        coalesce(dept.name, 'Not recorded') as department
    from procedure_occurrence po
    -- BL-003: inner join on the segment FK clinical__procedure_occurrence already resolved
    -- (its BL-005) -- no as-of derivation here, so this metric and its scoped siblings
    -- cannot disagree about which segment a request belongs to. A request whose segment did
    -- not resolve (NULL FK, where the encounter's type is absent from map__omop_visit_type)
    -- is dropped rather than surfaced with no setting, the same tradeoff metric__procedure
    -- makes.
    join visit_detail vd
        on vd.visit_detail_id = po.visit_detail_id
    join person pr
        on pr.person_id = vd.person_id
    -- BL-005: inner join -- the segment's own care_site_id resolving to nothing is an
    -- anomaly, excluded rather than attributed to a NULL facility.
    join locations loc
        on loc.id = vd.care_site_id
    left join completions c
        on c.imaging_request_id = po.procedure_occurrence_id
    left join imaging_areas areas
        on areas.imaging_request_id = po.procedure_occurrence_id
    left join departments dept
        on dept.id = vd.department_id
)

-- D5 wide format: value_boolean is unused by this metric.
select
    'imaging_request'::text as metric_id,
    null::text as variant_id,
    imaging_request_id::varchar as subject_id,
    requested_datetime as period_start,
    -- NULL unless the request has completed.
    completed_datetime as period_end,
    'minute'::text as period_granularity,
    -- BL-001: one request per row, so the count contribution is always 1. Additive, so a
    -- data table summing it is correct at every grain.
    1::numeric as value_numeric,
    null::boolean as value_boolean,
    facility_id,
    encounter_type,
    sex,
    -- the clinical model's own completion flag -- cancelled and still-open requests are
    -- both false, indistinguishable from each other by this column alone.
    is_completed,
    -- BL-007: raw Tamanu modality value, never NULL.
    coalesce(imaging_type_code_raw, 'Not recorded') as imaging_type_code,
    -- BL-007: readable modality label, falling back to the raw code where the shared
    -- imaging_type__label macro doesn't recognise it, never NULL -- the same name/code
    -- pair metric__procedure emits as procedure/procedure_code.
    coalesce(imaging_type_raw, imaging_type_code_raw, 'Not recorded') as imaging_type,
    -- BL-007: aggregated body area, never NULL.
    coalesce(imaging_area_raw, 'Not recorded') as imaging_area,
    -- BL-008: a measure, not a dimension -- age classification is the consumer's.
    age_years,
    -- BL-011: the resolved segment's own department, never NULL.
    department
from requests
