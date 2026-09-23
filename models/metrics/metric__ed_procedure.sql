-- metric__ed_procedure -- D5 metric view for the ED-scoped procedure indicator registered in
-- documentations/metrics/*.yml: ed_procedure.
--
-- Per-procedure (subject) grain: one row per recorded procedure performed while the patient was
-- in the emergency department, value_numeric 1, so a consumer aggregates at whatever grain it
-- needs. See specs/dbt-model/metric__ed_procedure.md BL-001 for why this is its own metric.
--
-- "Emergency" is OMOP concept 9203, the same definition int__emergency_visits uses for its
-- intake segment -- it covers emergency, triage and observation encounter phases
-- (models/maps/map__omop_visit_type.sql). BL-002 details the segment this is evaluated against.
--
-- The registry carries the definition; this model is its implementation.

with procedure_occurrence as (
    -- BL-004: procedure branch only, per clinical__procedure_occurrence's own consumer
    -- contract (its BL-001) -- imaging is not this metric's population
    select * from {{ ref('clinical__procedure_occurrence') }}
    where procedure_type_source_value = 'procedure'
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

-- BL-005: department, resolved to a name for metric_filters scoping. Unlike facility_id
-- (the procedure's own location), department follows the resolved segment instead --
-- bases/locations carries no department_id.
departments as (
    select * from {{ ref('departments') }}
),

procedures as (
    select
        po.procedure_occurrence_id,
        po.procedure_date,
        loc.facility_id,
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
        -- BL-005
        coalesce(dept.name, 'Not recorded') as department
    from procedure_occurrence po
    -- BL-002: the segment the procedure happened in, resolved once by
    -- clinical__procedure_occurrence (its BL-005) rather than re-derived here -- the as-of
    -- match against the procedure's own timestamp, with the first-segment clamp for a
    -- procedure timestamped before any segment began. A procedure whose segment did not
    -- resolve carries a NULL FK and is dropped by this inner join.
    join visit_detail vd
        on vd.visit_detail_id = po.visit_detail_id
    join person pr
        on pr.person_id = po.person_id
    -- inner join: a procedure's location resolving to nothing is an anomaly, excluded rather
    -- than attributed to a NULL facility -- the same convention metric__opd_procedure uses
    join locations loc
        on loc.id = po.location_id
    left join departments dept
        on dept.id = vd.department_id
    where vd.visit_detail_concept_id = 9203
)

-- D5 wide format: value_boolean is unused by this metric. period_granularity is 'day' -- a
-- procedure is recorded against a date, not a timestamp with a period to close.
select
    'ed_procedure'::text as metric_id,
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
    sex,
    procedure,
    procedure_code,
    is_completed,
    age_years,
    department
from procedures
