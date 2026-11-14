-- clinical__person -- OMOP-lite PERSON domain. One row per patient (BL-001).
-- Concept-ID shadow columns sit alongside local source values; native UUID PK
-- (D1 OMOP-lite). Sources only from bases/ (D10).
-- See specs/dbt-model/clinical__person.md for the BL clauses this model implements.

with patients as (
    select * from {{ ref('patients') }}
),

additional as (
    select
        patient_id,
        ethnicity_id
    from {{ ref('patient_additional_data') }}
),

birth as (
    select
        patient_id,
        birth_time
    from {{ ref('patient_birth_data') }}
),

sex_map as (
    select * from {{ ref('map__omop_sex') }}
),

ethnicity_map as (
    select
        local_code,
        concept_id
    from {{ ref('map__omop_ethnicity') }}
)

select
    -- identity (BL-001)
    p.id as person_id,
    -- source business identifier (display_id / MRN); a direct identifier that
    -- bases/ drops on analytics targets, so NULL on the replica (BL-006)
    {% if is_analytics_target() -%}
    null::text as person_source_value,
    {%- else -%}
    p.display_id as person_source_value,
    {%- endif %}

    -- gender: concept shadow + retained source value (BL-002)
    sm.concept_id as gender_concept_id,
    p.sex as gender_source_value,

    -- birth (BL-003)
    extract(year from p.date_of_birth)::int as year_of_birth,
    extract(month from p.date_of_birth)::int as month_of_birth,
    extract(day from p.date_of_birth)::int as day_of_birth,
    case
        when b.birth_time is not null
            then (p.date_of_birth + b.birth_time)::timestamp
    end as birth_datetime,

    -- ethnicity source value (BL-004)
    a.ethnicity_id as ethnicity_source_value,

    -- location: FK to ref__location (patient's village) (BL-007)
    p.village_id as location_id,

    -- BL-008: no standard ethnicity concept exists, and the deployment's custom concept
    -- is 0 where the ethnicity is unrecorded or unmapped
    0 as ethnicity_concept_id,
    coalesce(em.concept_id, 0) as ethnicity_source_concept_id
from patients p
-- enrichment joins are all left joins so a missing record yields NULL rather than
-- dropping the patient; only the patient record itself is required (BL-005)
left join additional a on a.patient_id = p.id
left join birth b on b.patient_id = p.id
left join sex_map sm on sm.local_code = lower(p.sex)
left join ethnicity_map em on em.local_code = a.ethnicity_id
