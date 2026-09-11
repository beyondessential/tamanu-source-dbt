-- metric__imaging_request -- D5 metric view for the generic (any encounter setting)
-- imaging-request indicator registered in documentations/metrics/imaging.yml:
-- imaging_request (MAUI-6806).
--
-- Per-request (subject) grain: one row per imaging request, value_numeric 1, so a consumer
-- aggregates at whatever grain it needs. Mirrors metric__procedure's setting-scoping
-- pattern: encounter_type is the encounter's own whole-visit type (admission, clinic,
-- emergency, ...), so a consumer scopes to one setting -- or none -- via a filter on this
-- one metric, rather than needing a separate metric per setting. Unlike
-- metric__opd_imaging_request (clinic-only) and metric__ipd_imaging_request
-- (admission-only), this metric carries no encounter-setting restriction at all -- it is
-- the direct imaging-request counterpart to metric__procedure, the way that model is the
-- direct counterpart to the procedure branch of clinical__procedure_occurrence. See
-- specs/dbt-model/metric__imaging_request.md.
--
-- BL-010 (naming carried over from metric__opd_imaging_request's own clause numbering):
-- sourced from clinical__procedure_occurrence's imaging branch, not bases/imaging_requests
-- directly -- the same clinical layer metric__procedure and metric__opd_imaging_request
-- build on. deleted/entered_in_error rows are already excluded there (its own BL-002), so
-- this model does not re-filter status.
--
-- Facility: NOT po.location_id, unlike metric__procedure's own join. imaging_requests'
-- own location_id is deprecated in Tamanu and effectively unpopulated (see
-- clinical__procedure_occurrence's imaging_branch comment on that column) -- joining it the
-- way metric__procedure does would silently exclude nearly every row, the same class of
-- bug metric__opd_imaging_request's own BL-005 already found and fixed for the clinic-only
-- metric. This model instead resolves facility_id from the encounter's own care_site_id via
-- clinical__visit_occurrence -- the same table already joined for encounter_type -- rather
-- than introducing the as-of segment join the OPD/IPD-scoped siblings use, since this
-- metric is deliberately encounter-grain, not segment-grain.
--
-- The registry carries the definition; this model is its implementation.

with procedure_occurrence as (
    select * from {{ ref('clinical__procedure_occurrence') }}
    where procedure_type_source_value = 'imaging request'
),

visit_occurrence as (
    select * from {{ ref('clinical__visit_occurrence') }}
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

-- one completion timestamp per request -- the earliest recorded result, the same rule
-- macros/datasets/imaging_requests.sql uses for ds__imaging_requests.completed_datetime,
-- and the same rule metric__opd_imaging_request uses.
completions as (
    select
        imaging_request_id,
        min(datetime) as completed_datetime
    from imaging_results
    group by imaging_request_id
),

-- legacy free-text area fallback, one row per request.
imaging_area_notes as (
    select
        record_id as imaging_request_id,
        string_agg(content, ', ' order by datetime) as imaging_area
    from notes
    where record_type = 'ImagingRequest'
        and note_type = 'areaToBeImaged'
    group by record_id
),

-- structured body-area names, one row per request -- the same shape
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
        -- only a completed request has a real completion event to report -- an
        -- imaging_results row can exist against a still-open or cancelled request (e.g. a
        -- preliminary result entered before cancellation), so this is gated on
        -- is_completed rather than surfacing c.completed_datetime unconditionally, the same
        -- guard metric__opd_imaging_request applies.
        case when po.is_completed then c.completed_datetime end as completed_datetime,
        loc.facility_id,
        -- the encounter's own whole-visit type -- lets a consumer scope to inpatient,
        -- emergency, or outpatient imaging requests without a separate metric per setting,
        -- the same convention metric__procedure.encounter_type uses.
        vo.visit_source_value as encounter_type,
        pr.gender_source_value as sex,
        {{ age_years('po.procedure_date', 'pr') }} as age_years,
        po.is_completed,
        po.procedure_source_value as imaging_type_code_raw,
        po.procedure_source_name as imaging_type_raw,
        areas.imaging_area as imaging_area_raw
    from procedure_occurrence po
    -- inner join: resolves for every request whose encounter type is covered by
    -- map__omop_visit_type, which clinical__visit_occurrence inner-joins -- an uncovered
    -- type would drop the request rather than surface it, the same tradeoff
    -- metric__procedure makes.
    join visit_occurrence vo
        on vo.visit_occurrence_id = po.visit_occurrence_id
    join person pr
        on pr.person_id = vo.person_id
    -- inner join: the encounter's own care_site_id resolving to nothing is an anomaly,
    -- excluded rather than attributed to a NULL facility -- the same convention
    -- metric__procedure uses for its own location join.
    join locations loc
        on loc.id = vo.care_site_id
    left join completions c
        on c.imaging_request_id = po.procedure_occurrence_id
    left join imaging_areas areas
        on areas.imaging_request_id = po.procedure_occurrence_id
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
    -- one request per row, so the count contribution is always 1. Additive, so a data
    -- table summing it is correct at every grain.
    1::numeric as value_numeric,
    null::boolean as value_boolean,
    facility_id,
    encounter_type,
    sex,
    -- the clinical model's own completion flag -- cancelled and still-open requests are
    -- both false, indistinguishable from each other by this column alone.
    is_completed,
    -- raw Tamanu modality value, never NULL.
    coalesce(imaging_type_code_raw, 'Not recorded') as imaging_type_code,
    -- readable modality label, falling back to the raw code where the shared
    -- imaging_type__label macro doesn't recognise it, never NULL -- the same name/code
    -- pair metric__procedure emits as procedure/procedure_code.
    coalesce(imaging_type_raw, imaging_type_code_raw, 'Not recorded') as imaging_type,
    -- aggregated body area, never NULL.
    coalesce(imaging_area_raw, 'Not recorded') as imaging_area,
    -- a measure, not a dimension -- age classification is the consumer's.
    age_years
from requests
