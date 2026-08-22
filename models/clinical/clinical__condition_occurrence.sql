-- clinical__condition_occurrence -- OMOP-lite CONDITION_OCCURRENCE domain. One row per
-- recorded diagnosis, unioning two sources: encounter diagnoses (BL-001) and program-registry
-- conditions (BL-007). The FK graph anchors on the encounter for the first (BL-002) and on the
-- enrolment for the second, which has no encounter. The source code is retained and
-- condition_concept_id is deferred to the future vocab__ layer (BL-003). Sources only from
-- bases/ (D10).
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

-- the population clinical__episode models, read from the model that defines it rather than
-- rebuilt here (BL-009, BL-026). A condition tracked alongside an enrolment is only a
-- diagnosis if the enrolment is one: without this the branch emits conditions against
-- enrolments recorded in error, and against patients merged away, which have no episode and
-- no clinical__person row to answer for them
enrolments as (
    select * from {{ ref('int__program_enrolments') }}
    where registration_status != 'recordedInError'
),

-- encounter diagnosis branch (BL-001)
encounter_branch as (
    select
        -- identity (BL-001)
        ed.id as condition_occurrence_id,

        -- person anchored on the encounter (BL-002)
        e.patient_id as person_id,

        -- diagnosis datetimes; encounter diagnoses are point-in-time, so no end (BL-004)
        ed.datetime::date as condition_start_date,
        ed.datetime       as condition_start_datetime,
        null::date        as condition_end_date,
        null::timestamp   as condition_end_datetime,

        -- provenance: every row here is an EHR encounter diagnosis (BL-006)
        'encounter diagnosis' as condition_type_source_value,

        -- status + primary/secondary flag; certainty retained verbatim (BL-005)
        ed.certainty  as condition_status_source_value,
        ed.is_primary as is_primary,

        -- provider + visit FKs (BL-002)
        ed.diagnosed_by_id as provider_id,
        ed.encounter_id    as visit_occurrence_id,

        -- diagnosis ICD-10 code + name; concept_id deferred to vocab__ (BL-003)
        rd.code as condition_source_value,
        rd.name as condition_source_name

    from encounter_diagnoses ed
    join encounters e on e.id = ed.encounter_id
    left join reference_data rd on rd.id = ed.diagnosis_id
),

-- program-registry condition branch (BL-007). A condition tracked alongside an enrolment: no
-- encounter, so no visit FK (BL-008), and the person comes through the registration (BL-009)
registry_branch as (
    select
        rc.id as condition_occurrence_id,
        r.person_id,

        rc.datetime::date as condition_start_date,
        rc.datetime as condition_start_datetime,
        null::date as condition_end_date,
        null::timestamp as condition_end_datetime,

        'program registry condition' as condition_type_source_value,

        -- the category is the registry's equivalent of encounter-diagnosis certainty:
        -- confirmed, suspected, resolved and so on (BL-010)
        cc.code as condition_status_source_value,

        -- a registry condition is not ranked against the others on the enrolment
        null::boolean as is_primary,

        rc.recorded_by_id as provider_id,

        -- recorded against the enrolment, not an encounter (BL-008)
        null::varchar as visit_occurrence_id,

        prc.code as condition_source_value,
        prc.name as condition_source_name

    from registration_conditions rc
    join enrolments r on r.enrolment_id = rc.patient_program_registration_id
    left join registry_conditions prc on prc.id = rc.program_registry_condition_id
    left join condition_categories cc on cc.id = rc.program_registry_condition_category_id
    -- a removed condition is not a condition the patient has (BL-011)
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
