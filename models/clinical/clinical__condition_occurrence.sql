-- clinical__condition_occurrence -- OMOP-lite CONDITION_OCCURRENCE domain. One row per
-- recorded diagnosis, unioning two sources: encounter diagnoses and program-registry
-- conditions. The FK graph anchors on the encounter for the first and on the enrolment for the
-- second, which has no encounter. Sources only from bases/ and intermediate (D10).
--
-- BL-003: the source code is retained and condition_concept_id is deferred to the future
-- vocab__ layer.
-- See specs/dbt-model/clinical__condition_occurrence.md for BL-001..BL-011.

with encounter_diagnoses as (
    select * from {{ ref('encounter_diagnoses') }}
),

encounters as (
    select * from {{ ref('encounters') }}
),

reference_data as (
    select * from {{ ref('reference_data') }}
),

registration_conditions as (
    select * from {{ ref('patient_program_registration_conditions') }}
),

registry_conditions as (
    select * from {{ ref('program_registry_conditions') }}
),

condition_categories as (
    select * from {{ ref('program_registry_condition_categories') }}
),

-- BL-009: the population clinical__episode models, read from the model that defines it rather
-- than rebuilt here (the population rule is clinical__episode.md's BL-026). A condition tracked
-- alongside an enrolment is only a diagnosis if the enrolment is one: without this the branch
-- emits conditions against enrolments recorded in error, and against patients merged away,
-- which have no episode and no clinical__person row to answer for them
enrolments as (
    select * from {{ ref('int__program_enrolments') }}
    where registration_status != 'recordedInError'
),

-- BL-001: encounter diagnosis branch
encounter_branch as (
    select
        ed.id as condition_occurrence_id,

        -- BL-002: person anchored on the encounter
        e.patient_id as person_id,

        -- BL-004: diagnosis datetimes. Encounter diagnoses are point-in-time, so no end
        ed.datetime::date as condition_start_date,
        ed.datetime       as condition_start_datetime,
        null::date        as condition_end_date,
        null::timestamp   as condition_end_datetime,

        -- BL-006: provenance -- every row here is an EHR encounter diagnosis
        'encounter diagnosis' as condition_type_source_value,

        -- BL-005: status and primary/secondary flag, certainty retained verbatim
        ed.certainty  as condition_status_source_value,
        ed.is_primary as is_primary,

        -- BL-002: provider and visit FKs
        ed.diagnosed_by_id as provider_id,
        ed.encounter_id    as visit_occurrence_id,

        -- BL-003: diagnosis ICD-10 code and name, concept_id deferred to vocab__
        rd.code as condition_source_value,
        rd.name as condition_source_name

    from encounter_diagnoses ed
    join encounters e on e.id = ed.encounter_id
    left join reference_data rd on rd.id = ed.diagnosis_id
),

-- BL-007: program-registry condition branch. A condition tracked alongside an enrolment, so no
-- encounter behind it (BL-008) and the person reached through the registration (BL-009)
registry_branch as (
    select
        rc.id as condition_occurrence_id,
        r.person_id,

        -- BL-004: registry conditions carry no resolution date either, so no end
        rc.datetime::date as condition_start_date,
        rc.datetime as condition_start_datetime,
        null::date as condition_end_date,
        null::timestamp as condition_end_datetime,

        'program registry condition' as condition_type_source_value,

        -- BL-010: the category is the registry's equivalent of encounter-diagnosis certainty
        -- -- confirmed, suspected, resolved and so on
        cc.code as condition_status_source_value,

        -- BL-010: a registry condition is not ranked against the others on the enrolment
        null::boolean as is_primary,

        rc.recorded_by_id as provider_id,

        -- BL-008: recorded against the enrolment, not an encounter
        null::varchar as visit_occurrence_id,

        prc.code as condition_source_value,
        prc.name as condition_source_name

    from registration_conditions rc
    join enrolments r on r.enrolment_id = rc.patient_program_registration_id
    left join registry_conditions prc on prc.id = rc.program_registry_condition_id
    left join condition_categories cc on cc.id = rc.program_registry_condition_category_id
    -- BL-011: a removed condition is not a condition the patient has
    where rc.deleted_datetime is null
)

-- columns listed explicitly per branch so reordering one branch cannot silently mis-map
select
    condition_occurrence_id,
    person_id,
    condition_start_date,
    condition_start_datetime,
    condition_end_date,
    condition_end_datetime,
    condition_type_source_value,
    condition_status_source_value,
    is_primary,
    provider_id,
    visit_occurrence_id,
    condition_source_value,
    condition_source_name
from encounter_branch

union all

select
    condition_occurrence_id,
    person_id,
    condition_start_date,
    condition_start_datetime,
    condition_end_date,
    condition_end_datetime,
    condition_type_source_value,
    condition_status_source_value,
    is_primary,
    provider_id,
    visit_occurrence_id,
    condition_source_value,
    condition_source_name
from registry_branch
