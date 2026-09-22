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
-- filter on this one metric rather than needing a separate metric per setting, and because
-- the scoped siblings (metric__opd_procedure, metric__ipd_procedure) read the same segment,
-- filtering this metric to one setting agrees with the matching sibling by construction.
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

procedures as (
    select
        po.procedure_occurrence_id,
        po.procedure_date,
        loc.facility_id,
        -- the segment the procedure happened in, not the encounter's whole-visit type --
        -- lets a consumer scope to inpatient, emergency or outpatient procedures without a
        -- separate metric per setting, and agrees with the scoped siblings, which filter
        -- the same column
        vd.visit_detail_source_value as encounter_type,
        pr.gender_source_value as sex,
        -- the procedure as recorded, coalesced so the column is never NULL -- Tupaia exposes
        -- these as array filters, and an array filter drops a NULL row
        coalesce(po.procedure_source_value, 'Not recorded') as procedure_code,
        coalesce(
            po.procedure_source_name, po.procedure_source_value, 'Not recorded'
        ) as procedure,
        po.is_completed,
        -- age in whole years at the procedure; the NULL rule lives in the macro
        {{ age_years('po.procedure_date', 'pr') }} as age_years
    from procedure_occurrence po
    -- inner join on the segment FK clinical__procedure_occurrence already resolved -- no
    -- as-of derivation here, so this metric and its scoped siblings cannot disagree about
    -- which segment a procedure belongs to. A procedure whose segment did not resolve
    -- (NULL FK, where the encounter's type is absent from map__omop_visit_type) is dropped
    -- rather than surfaced with no setting, the same tradeoff the previous join to
    -- clinical__visit_occurrence made
    join visit_detail vd
        on vd.visit_detail_id = po.visit_detail_id
    join person pr
        on pr.person_id = po.person_id
    -- inner join: a procedure's location resolving to nothing is an anomaly, excluded rather
    -- than attributed to a NULL facility -- the same convention metric__encounter_diagnosis
    -- uses for its facility join
    join locations loc
        on loc.id = po.location_id
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
    sex,
    procedure,
    procedure_code,
    is_completed,
    age_years
from procedures
