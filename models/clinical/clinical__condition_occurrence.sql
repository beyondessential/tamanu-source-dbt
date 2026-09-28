-- clinical__condition_occurrence -- OMOP-lite CONDITION_OCCURRENCE domain. One row per
-- encounter diagnosis (BL-001). FK graph anchored on the encounter (BL-002); the ICD-10
-- code is retained as the source value and condition_concept_id is deferred to the future
-- vocab__ layer (BL-003). Sources only from bases/ (D10).
-- See specs/dbt-model/clinical__condition_occurrence.md for BL-001..BL-006.

with encounter_diagnoses as (
    select * from {{ ref('encounter_diagnoses') }}
),

encounters as (
    select * from {{ ref('encounters') }}
),

reference_data as (
    select * from {{ ref('reference_data') }}
)

select
    -- identity (BL-001)
    ed.id as condition_occurrence_id,

    -- person anchored on the encounter (BL-002)
    e.patient_id as person_id,

    -- diagnosis datetimes; encounter diagnoses are point-in-time, so no end (BL-004)
    ed.datetime::date as condition_start_date,
    ed.datetime as condition_start_datetime,
    null::date as condition_end_date,
    null::timestamp as condition_end_datetime,

    -- provenance: every row here is an EHR encounter diagnosis (BL-006)
    'encounter diagnosis' as condition_type_source_value,

    -- status + primary/secondary flag; certainty retained verbatim (BL-005)
    ed.certainty as condition_status_source_value,
    ed.is_primary,

    -- provider + visit FKs (BL-002)
    ed.diagnosed_by_id as provider_id,
    ed.encounter_id as visit_occurrence_id,

    -- diagnosis ICD-10 code + name; concept_id deferred to vocab__ (BL-003)
    rd.code as condition_source_value,
    rd.name as condition_source_name

from encounter_diagnoses ed
join encounters e on e.id = ed.encounter_id
left join reference_data rd on rd.id = ed.diagnosis_id
