-- metric__emergency_visit -- D5 metric view for the emergency care attendance
-- indicator registered in documentations/metrics/*.yml: ed_visit (MAUI-6694).
-- Spec: specs/dbt-model/metric__emergency_visit.md (BL-001..BL-016).
--
-- Per-attendance (subject) grain: one row per ED attendance, value_numeric 1, so a consumer
-- aggregates at whatever grain it needs -- any subset of the disaggregations, and any time
-- grain from minute upwards (BL-011).
--
-- period_start/period_end are timestamps bounding the attendance's stay in the ED, so a
-- consumer computes length of stay as period_end - period_start (BL-002).
--
-- The attendance base, its joins and its derived timings are shared with
-- metric__emergency_stay via int__emergency_visits.
--
-- The registry carries the definition; this model is its implementation (BL-001).

with ed_visits as (
    select * from {{ ref('int__emergency_visits') }}
)

-- BL-005: admission outcome is a disaggregation column, so a consumer groups by it,
-- filters to it, or ignores it. The admitted count is the sum of value_numeric where
-- is_admitted is true.

-- BL-006: the model emits counts. The admission rate is
-- sum(value_numeric) filter (where is_admitted) / sum(value_numeric), formed at whatever
-- grain the consumer groups to.

-- BL-002: every attendance is emitted, including today's. A consumer needing whole periods
-- only -- a monthly trend line -- applies its own date filter.

-- D5 wide format: value_boolean is unused by this metric.
--
-- BL-009: facility is emitted as the Tamanu facility_id only. Translating it to a
-- consumer's own identifier -- a Tupaia entity code, a DHIS2 org unit -- is a
-- consumer-layer concern and is done there (for Tupaia, in the data table), not here.
select
    'ed_visit'::text as metric_id,
    null::text as variant_id,
    visit_occurrence_id::varchar as subject_id,
    -- BL-002: minute grain, arrival in the ED to discharge from hospital, so
    -- period_end - period_start is total length of stay -- spanning the inpatient episode for
    -- an admitted attendance. metric__emergency_stay measures the ED portion instead.
    -- period_end is NULL while the encounter is open.
    ed_start__datetime as period_start,
    visit_end__datetime as period_end,
    'minute'::text as period_granularity,
    -- BL-011: one attendance per row, so the count contribution is always 1. Additive,
    -- so data_table_metric: sum is correct at every grain.
    1::numeric as value_numeric,
    null::boolean as value_boolean,
    facility_id,
    sex,
    -- BL-004: age in whole years at arrival.
    -- BL-019: unbanded -- an age classification is a presentation choice a deployment may set
    -- differently, so the consumer's data table bands it.
    age_years,
    triage_score,
    -- BL-013
    case
        when principal_diagnosis_code is null then 'Not recorded'
        else {{ diagnosis__icd10_chapter('principal_diagnosis_code') }}
    end as principal_diagnosis__icd10_chapter,
    -- BL-014: the wait to active care, in minutes
    waiting_time__minutes,
    -- BL-015: total length of stay in minutes.
    -- BL-019: unbanded, for the same reason as age.
    length_of_stay__minutes,
    -- BL-016: local hour of arrival, 0-23
    ed_start__hour,
    is_admitted
from ed_visits
