-- metric__emergency_stay -- D5 metric view for the emergency care stay indicator
-- registered in documentations/metrics/*.yml: ed_stay (MAUI-6694).
-- Spec: specs/dbt-model/metric__emergency_stay.md (BL-001..BL-017).
--
-- One row per ED stay, which is one ED attendance viewed as a span rather than an arrival:
-- period_start is arrival in the ED and period_end is departure from it, so
-- period_end - period_start is time in the ED (BL-002).
--
-- Departure is departure from the **ED**, not the end of the encounter -- for a stay that
-- ended in admission, period_end is the moment of admission (BL-002).
--
-- Shares its attendance base with metric__emergency_visit via int__emergency_visits; the
-- two differ in what they disaggregate by, not in which rows they cover.
--
-- The registry carries the definition; this model is its implementation (BL-001).

with ed_visits as (
    select * from {{ ref('int__emergency_visits') }}
)

-- BL-006: the model emits counts. A mean or median time in the ED is
-- period_end - period_start aggregated at whatever grain the consumer groups to -- an
-- interval is not additive, so no duration column is emitted.

-- D5 wide format: value_boolean is unused by this metric.
--
-- BL-009: facility is emitted as the Tamanu facility_id only.
select
    'ed_stay'::text as metric_id,
    null::text as variant_id,
    visit_occurrence_id::varchar as subject_id,
    -- BL-002: minute grain, arrival in the ED to departure from it -- whether that departure
    -- is an internal transfer to an inpatient bed or a discharge straight from the ED.
    -- period_end is NULL while the patient is still in the ED.
    ed_start__datetime as period_start,
    ed_end__datetime as period_end,
    'minute'::text as period_granularity,
    -- BL-011: one stay per row, so the count contribution is always 1
    1::numeric as value_numeric,
    null::boolean as value_boolean,
    facility_id,
    sex,
    -- BL-004: age in whole years at arrival. Unbanded -- an age classification is a
    -- presentation choice a deployment may set differently, so the data table bands it
    -- (metric__emergency_visit.md BL-019).
    age_years,
    triage_score,
    -- BL-015: time in the ED in minutes. Unbanded, for the same reason as age.
    ed_time__minutes,
    -- BL-017: how the encounter ended. Encounter-grained, so for a stay that was admitted
    -- this is the eventual hospital discharge, not the ED departure.
    discharge_disposition
from ed_visits
