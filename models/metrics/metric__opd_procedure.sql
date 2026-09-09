-- metric__opd_procedure -- D5 metric view for the OPD-scoped procedure indicator registered in
-- documentations/metrics/*.yml: opd_procedure.
--
-- Per-procedure (subject) grain: one row per recorded procedure performed during an outpatient
-- encounter, value_numeric 1, so a consumer aggregates at whatever grain it needs. See
-- specs/dbt-model/metric__opd_procedure.md BL-001 for why this is its own metric.
--
-- "Outpatient" is OMOP concept 9202, the same definition metric__outpatient_visit uses -- it
-- covers clinic, imaging and vaccination encounters (models/maps/map__omop_visit_type.sql).
-- BL-003 details the segment this is evaluated against, and the first-segment clamp applied
-- when a procedure predates every segment.
--
-- The registry carries the definition; this model is its implementation.

with procedure_occurrence as (
    -- BL-008: procedure branch only, per clinical__procedure_occurrence's own consumer
    -- contract (its BL-001) -- imaging is metric__opd_imaging_request's population
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

-- BL-003: the segment active at the procedure's own timestamp, not the encounter's first or
-- current segment. distinct on picks the latest segment that had already started by
-- procedure_datetime; tie-broken on visit_detail_id, the same tiebreak
-- clinical__visit_detail's own segment-ordering window uses for its zero-length-segment case
-- (BL-002).
--
-- BL-003: clamped to the first segment when the procedure predates every segment (Juliana,
-- MAUI-6862/MAUI-6806) -- a procedure genuinely belongs to its own encounter, so a segment
-- recorded starting after it (a data-timing artifact, not a real ordering issue) should not
-- exclude it. No join condition on the timestamp: every encounter has >= 1 segment
-- (clinical__visit_detail BL-005), so the join itself can never drop a row -- the order by
-- picks the correct as-of segment where one qualifies, and falls back to the earliest
-- segment otherwise.
procedure_segment as (
    select distinct on (po.procedure_occurrence_id)
        po.procedure_occurrence_id,
        vd.visit_detail_concept_id
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
    join procedure_segment ps
        on ps.procedure_occurrence_id = po.procedure_occurrence_id
    join person pr
        on pr.person_id = po.person_id
    -- inner join: a procedure's location resolving to nothing is an anomaly, excluded rather
    -- than attributed to a NULL facility -- the same convention metric__procedure uses
    join locations loc
        on loc.id = po.location_id
    where ps.visit_detail_concept_id = 9202
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
