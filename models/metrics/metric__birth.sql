-- metric__birth -- D5 metric view for the four maternity/newborn indicators registered in
-- documentations/metrics/maternity.yml: birth, low_birth_weight, preterm_birth,
-- low_apgar_5min (MAUI-6838).
-- Spec: specs/dbt-model/metric__birth.md (BL-001..BL-014).
--
-- Per-birth (subject) grain: one row per registered live birth, per metric_id, value_numeric
-- 1, so a consumer aggregates at whatever grain it needs (BL-013). low_birth_weight,
-- preterm_birth and low_apgar_5min are each a `where` subset of birth sharing the same base,
-- so a subject appears once per metric_id it qualifies for.
--
-- Subsets are separate metric_ids rather than boolean disaggregation columns (ed_visit's
-- is_admitted) because each depends on a measure that is often unrecorded: a boolean would
-- have to collapse "not low birth weight" and "weight not recorded" into one false.
--
-- No visit/encounter concept applies: patient_birth_data is a standalone birth-registration
-- table, not visit-scoped (BL-002).
--
-- The registry carries the definition; this model is its implementation (BL-001).

with patient_birth_data as (
    select * from {{ ref('patient_birth_data') }}
),

patients as (
    select * from {{ ref('patients') }}
),

person as (
    select * from {{ ref('clinical__person') }}
),

facilities as (
    select * from {{ ref('facilities') }}
),

-- BL-002: inner join to patients drops soft-deleted, merged and test patients.
-- BL-003: period_start is the date of birth, falling back to the registration date where the
-- patient record carries no date of birth. birth_time is deliberately absent: at day
-- granularity it cannot change the result, since date_of_birth + birth_time truncates to the
-- same day as date_of_birth alone.
-- BL-004: sex is the newborn's own clinical__person.gender_source_value.
-- BL-010: facility is left-joined and left nullable -- a home or other-place birth
-- genuinely has none, and dropping those rows would bias "deliveries by place" toward
-- facility births.
births as (
    select
        pbd.patient_id as subject_id,
        date_trunc(
            'day',
            coalesce(
                p.date_of_birth::timestamp,
                pbd.registration_date::timestamp
            )
        ) as period_start,
        f.id as facility_id,
        per.gender_source_value as sex,
        pbd.birth_delivery_type,
        pbd.attendant_at_birth,
        pbd.registered_birth_place,
        pbd.birth_type,
        pbd.birth_weight,
        pbd.gestational_age_estimate,
        pbd.apgar_score_five_minutes
    from patient_birth_data pbd
    join patients p on p.id = pbd.patient_id
    join person per on per.person_id = pbd.patient_id
    left join facilities f on f.id = pbd.birth_facility_id
),

-- D5 wide format: one row per (metric_id, subject_id). birth is every row; the three
-- subsets below are each a `where` filter over the same base, unioned together (BL-005,
-- BL-006, BL-007).
metric_rows as (
    select
        'birth'::text as metric_id,
        *
    from births

    union all

    -- BL-005: low_birth_weight, numerator only -- WHO/UNICEF threshold. A birth with no
    -- recorded weight emits no row here, and is not subtracted from birth's count.
    select
        'low_birth_weight'::text as metric_id,
        *
    from births
    where birth_weight is not null and birth_weight < 2.5

    union all

    -- BL-006: preterm_birth, numerator only -- WHO threshold, same caveat as above.
    select
        'preterm_birth'::text as metric_id,
        *
    from births
    where gestational_age_estimate is not null and gestational_age_estimate < 37

    union all

    -- BL-007: low_apgar_5min, numerator only -- WHO Newborn Health guidance threshold,
    -- same caveat as above.
    select
        'low_apgar_5min'::text as metric_id,
        *
    from births
    where apgar_score_five_minutes is not null and apgar_score_five_minutes < 7
)

select
    metric_id,
    null::text as variant_id,
    subject_id::varchar as subject_id,
    period_start,
    -- BL-003: a birth is a point event, not a stay -- period_end equals period_start rather
    -- than signalling "still open" the way an encounter's NULL period_end does.
    period_start as period_end,
    'day'::text as period_granularity,
    -- BL-013: one birth per row, so the count contribution is always 1.
    1::numeric as value_numeric,
    null::boolean as value_boolean,
    facility_id,
    sex,
    -- BL-009: raw source values, ungrouped -- relabelling to a human-readable form is a
    -- presentation choice left to the consumer's data table.
    birth_delivery_type,
    attendant_at_birth,
    registered_birth_place,
    birth_type,
    -- BL-014: measures, not dimensions -- continuous, so banding is the consumer's.
    birth_weight,
    gestational_age_estimate,
    apgar_score_five_minutes
from metric_rows
