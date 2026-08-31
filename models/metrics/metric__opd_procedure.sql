-- metric__opd_procedure -- D5 metric view for the OPD-scoped procedure indicator registered in
-- documentations/metrics/*.yml: opd_procedure.
--
-- Per-procedure (subject) grain: one row per recorded procedure performed during an outpatient
-- encounter, value_numeric 1, so a consumer aggregates at whatever grain it needs. See
-- specs/dbt-model/metric__opd_procedure.md BL-001 for why this is its own metric.
--
-- "Outpatient" is OMOP concept 9202, the same definition metric__outpatient_visit uses -- it
-- covers clinic, imaging and vaccination encounters (models/maps/map__omop_visit_type.sql).
-- Filtered here on clinical__visit_occurrence.visit_concept_id, the whole-encounter grain
-- metric__procedure already joins to -- not clinical__visit_detail's first-segment grain,
-- which is what metric__outpatient_visit itself filters on. The two can disagree for a
-- multi-segment encounter, though this is rare in practice.
--
-- The registry carries the definition; this model is its implementation.

with procedure_occurrence as (
    select * from {{ ref('clinical__procedure_occurrence') }}
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
        {{ age_years('po.procedure_date', 'pr') }} as age_years
    from procedure_occurrence po
    -- inner join: resolves for every procedure whose encounter type is covered by
    -- map__omop_visit_type, which clinical__visit_occurrence inner-joins -- an uncovered type
    -- would drop the procedure rather than surface it, the same tradeoff metric__procedure
    -- makes
    join visit_occurrence vo
        on vo.visit_occurrence_id = po.visit_occurrence_id
    join person pr
        on pr.person_id = po.person_id
    -- inner join: a procedure's location resolving to nothing is an anomaly, excluded rather
    -- than attributed to a NULL facility -- the same convention metric__procedure uses
    join locations loc
        on loc.id = po.location_id
    where vo.visit_concept_id = 9202
)

-- D5 wide format: value_boolean is unused by this metric. period_granularity is 'day' -- a
-- procedure is recorded against a date, not a timestamp with a period to close.
select
    'opd_procedure'::text as metric_id,
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
    age_years
from procedures
