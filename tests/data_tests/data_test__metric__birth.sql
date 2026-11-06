-- Singular tests for metric__birth. One row per violation, tagged with the acceptance
-- criterion it breaks. See specs/dbt-model/metric__birth.md.

with birth as (
    select * from {{ ref('metric__birth') }}
),

patient_birth_data as (
    select * from {{ ref('patient_birth_data') }}
),

-- The included population: metric__birth's own `birth` rows already carry BL-002's inclusion
-- filter, so anchoring on them tests the subsets without re-deriving that filter here.
population as (
    select
        b.subject_id,
        pbd.birth_weight,
        pbd.gestational_age_estimate,
        pbd.apgar_score_five_minutes
    from birth b
    join patient_birth_data pbd on pbd.patient_id = b.subject_id
    where b.metric_id = 'birth'
),

-- Which subset each included birth qualifies for, re-derived from the source measures rather
-- than from the model, so the check is independent of how the model builds the subsets.
expected as (
    select subject_id, 'low_birth_weight' as metric_id
    from population
    where birth_weight is not null and birth_weight < 2.5

    union all

    select subject_id, 'preterm_birth'
    from population
    where gestational_age_estimate is not null and gestational_age_estimate < 37

    union all

    select subject_id, 'low_apgar_5min'
    from population
    where apgar_score_five_minutes is not null and apgar_score_five_minutes < 7
),

actual as (
    select subject_id, metric_id
    from birth
    where metric_id != 'birth'
),

-- AC-013: subset membership matches the source predicate over the included population, in
-- both directions.
--
-- A missing row means a qualifying birth was dropped from its subset; an extra row means a
-- subset emitted a birth the population itself does not hold, or emitted one whose measure
-- does not meet the threshold. Deliberately not a self-join against `birth` alone: the
-- subsets are `where` filters over one shared CTE today, so a self-join is structurally
-- incapable of failing and would give the criterion no regression cover. This form bites if a
-- subset is ever rebuilt on its own base or its threshold drifts from the spec.
ac_013 as (
    select
        coalesce(e.subject_id, a.subject_id) as subject_id,
        coalesce(e.metric_id, a.metric_id) as metric_id,
        case
            when a.subject_id is null
                then 'AC-013 (qualifying birth missing from subset)'
            when not exists (
                select 1 from population pop where pop.subject_id = a.subject_id
            ) then 'AC-013 (subset row has no birth row)'
            else 'AC-013 (subset row not qualified by the source measure)'
        end as failed_ac
    from expected e
    full outer join actual a
        on a.subject_id = e.subject_id and a.metric_id = e.metric_id
    where e.subject_id is null or a.subject_id is null
)

select
    subject_id,
    metric_id,
    failed_ac
from ac_013
