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
-- filter on this one metric rather than needing a separate metric per setting. This
-- replaced the former metric__opd_procedure and metric__ipd_procedure, which were exactly
-- this metric filtered to one encounter_type and are now a filter on it instead.
--
-- clinical__procedure_occurrence carries both a procedure and an imaging branch,
-- distinguished by procedure_type_source_value (see its spec, BL-001). This metric's
-- population is the procedure branch only -- imaging is metric__opd_imaging_request's
-- population, not this one's.
--
-- The registry carries the definition; this model is its implementation.

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

-- department, resolved to a name for metric_filters scoping. Like facility_id, department
-- follows the resolved segment -- it comes off the segment directly, since bases/locations
-- carries no department_id.
departments as (
    select * from {{ ref('departments') }}
),

procedures as (
    select
        po.procedure_occurrence_id,
        po.procedure_date,
        loc.facility_id,
        -- the segment the procedure happened in, not the encounter's whole-visit type --
        -- lets a consumer scope to inpatient, emergency or outpatient procedures without a
        -- separate metric per setting
        vd.visit_detail_source_value as encounter_type,
        -- the OMOP visit concept of that segment, grouped into a readable setting. This is
        -- what the retired metric__opd_procedure and metric__ipd_procedure filtered on
        -- (9202 and 9201), and it is deliberately coarser than encounter_type: 9202 covers
        -- clinic, imaging and vaccination alike, so 'Outpatient' is not the same set as
        -- encounter_type = 'clinic'. A consumer scoping to a setting filters this column,
        -- not encounter_type, so its scope does not shift if map__omop_visit_type gains an
        -- encounter type.
        case vd.visit_detail_concept_id
            when 9201 then 'Inpatient'
            when 9202 then 'Outpatient'
            when 9203 then 'Emergency'
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
    -- inner join on the segment FK clinical__procedure_occurrence already resolved -- no
    -- as-of derivation here, so every metric over this clinical model agrees on which
    -- segment a procedure belongs to. A procedure whose segment did not resolve
    -- (NULL FK, where the encounter's type is absent from map__omop_visit_type) is dropped
    -- rather than surfaced with no setting, the same tradeoff the previous join to
    -- clinical__visit_occurrence made
    join visit_detail vd
        on vd.visit_detail_id = po.visit_detail_id
    join person pr
        on pr.person_id = po.person_id
    -- facility is the resolved segment's own care_site_id, not the procedure's own
    -- location_id -- the same source metric__imaging_request resolves facility from, so a
    -- procedure and an imaging request belonging to the same segment agree on facility. It
    -- also means a procedure whose own location_id does not resolve keeps a facility rather
    -- than being dropped by this join.
    -- inner join: a segment's care_site resolving to nothing is an anomaly, excluded rather
    -- than attributed to a NULL facility
    join locations loc
        on loc.id = vd.care_site_id
    left join departments dept
        on dept.id = vd.department_id
    -- BL-001: procedure branch only -- imaging is metric__opd_imaging_request's population
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
    encounter_setting,
    sex,
    procedure,
    procedure_code,
    is_completed,
    age_years,
    department
from procedures
