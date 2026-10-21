-- Singular tests for metric__immunisation_dose. One row per violation, tagged with the
-- acceptance criterion it breaks. See specs/dbt-model/metric__immunisation_dose.md.
{{ config(severity='error') }}

-- AC-021: every given vaccination whose patient is included appears as an immunisation_dose
-- row -- whatever its location and whether or not it was given elsewhere (BL-004, BL-016).
-- Re-derived from the bases rather than from the model, so a join that silently drops doses
-- (as an inner join on the dose's own location once did, losing every older record held only
-- against its encounter's location) fails here.
with given as (
    select av.id
    from {{ ref('vaccine_administrations') }} av
    join {{ ref('encounters') }} e on e.id = av.encounter_id
    join {{ ref('clinical__person') }} pr on pr.person_id = e.patient_id
    where av.status = 'GIVEN'
),

counted as (
    select subject_id
    from {{ ref('metric__immunisation_dose') }}
    where metric_id = 'immunisation_dose'
)

select
    'AC-021' as acceptance_criterion,
    g.id as administered_vaccine_id
from given g
left join counted c on c.subject_id = g.id
where c.subject_id is null
