-- metric__procedure -- D5 metric view for the procedure indicator registered in
-- documentations/metrics/*.yml: procedure.
--
-- Per-procedure (subject) grain: one row per recorded procedure, value_numeric 1, so a consumer
-- aggregates at whatever grain it needs -- any subset of the disaggregations, and any time
-- grain from day upwards.
--
-- encounter_type is the setting the procedure itself happened in -- read off the
-- clinical__visit_detail segment clinical__procedure_occurrence resolves as its
-- visit_detail_id (that model's BL-005), not the encounter's own whole-visit type. A
-- procedure performed during the triage phase of an encounter later admitted is an
-- emergency procedure, not an inpatient one. A consumer scopes to any single setting via a
-- filter on this one metric rather than needing a separate metric per setting.
--
-- clinical__procedure_occurrence carries both a procedure and an imaging branch,
-- distinguished by procedure_type_source_value (see its spec, BL-001). This metric's
-- population is the procedure branch only -- imaging is metric__imaging_request's
-- population, not this one's.
--
-- The registry carries the definition; this model is its implementation.
-- See specs/dbt-model/metric__procedure.md for BL-001..BL-010.

with procedure_occurrence as (
    select * from {{ ref('clinical__procedure_occurrence') }}
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

-- BL-009: department, resolved to a name for metric_filters scoping. It comes off the
-- segment directly, since bases/locations carries no department_id.
departments as (
    select * from {{ ref('departments') }}
),

procedures as (
    select
        po.procedure_occurrence_id,
        po.procedure_date,
        loc.facility_id,
        -- BL-003: the segment the procedure was performed in, not the encounter's
        -- whole-visit type
        vd.visit_detail_source_value as encounter_type,
        -- BL-010: the segment's OMOP Visit concept and its name, as clinical__visit_detail
        -- carries them
        vd.visit_detail_concept_id,
        vd.visit_detail_concept_name,
        -- BL-008: the segment's OMOP visit concept grouped to a setting, coarser than
        -- encounter_type -- 9202 covers clinic, imaging and vaccination alike, so
        -- 'Outpatient' is wider than encounter_type = 'clinic'. Scope a setting by this
        -- column and the scope holds when map__omop_visit_type gains an encounter type.
        -- Do not add an emergency value here: emergency reporting has its own metrics, and
        -- a value would let an emergency card be drawn from this one.
        case vd.visit_detail_concept_id
            when 9201 then 'Inpatient'
            when 9202 then 'Outpatient'
            else 'Other'
        end as encounter_setting,
        pr.gender_source_value as sex,
        -- the procedure as recorded, coalesced so the column is never NULL -- Tupaia exposes
        -- these as array filters, and an array filter drops a NULL row
        coalesce(po.procedure_source_value, 'Not recorded') as procedure_code,
        coalesce(
            po.procedure_source_name, po.procedure_source_value, 'Not recorded'
        ) as procedure,
        po.is_completed,
        -- age in whole years at the procedure; the NULL rule lives in the macro
        {{ age_years('po.procedure_date', 'pr') }} as age_years,
        -- the resolved segment's own department, coalesced so an array filter cannot drop
        -- the row
        coalesce(dept.name, 'Not recorded') as department
    from procedure_occurrence po
    -- BL-003: inner join on the segment FK clinical__procedure_occurrence resolves (its
    -- BL-005), so every metric over that model agrees on which segment a procedure belongs
    -- to. A procedure whose segment did not resolve (NULL FK, where the encounter's type is
    -- absent from map__omop_visit_type) is dropped rather than surfaced with no setting
    join visit_detail vd
        on vd.visit_detail_id = po.visit_detail_id
    join person pr
        on pr.person_id = po.person_id
    -- BL-004: facility is the resolved segment's own care_site_id -- the same source
    -- metric__imaging_request resolves facility from, so a procedure and an imaging request
    -- belonging to one segment agree on facility. Inner join: a segment's care_site
    -- resolving to nothing is an anomaly, excluded rather than attributed to a NULL
    -- facility
    join locations loc
        on loc.id = vd.care_site_id
    left join departments dept
        on dept.id = vd.department_id
    -- BL-001: procedure branch only -- imaging is metric__imaging_request's population
    where po.procedure_type_source_value = 'procedure'
)

-- D5 wide format: value_boolean is unused by this metric. period_granularity is 'day' -- a
-- procedure is recorded against a date, not a timestamp with a period to close.
select
    'procedure'::text as metric_id,
    null::text as variant_id,
    procedure_occurrence_id::varchar as subject_id,
    procedure_date as period_start,
    null::date as period_end,
    'day'::text as period_granularity,
    -- one procedure per row, so the count contribution is always 1. Additive, so a data table
    -- summing it is correct at every grain.
    1::numeric as value_numeric,
    null::boolean as value_boolean,
    facility_id,
    encounter_type,
    visit_detail_concept_id,
    visit_detail_concept_name,
    encounter_setting,
    sex,
    procedure,
    procedure_code,
    is_completed,
    age_years,
    department
from procedures
