-- Singular tests for clinical__condition_occurrence's program-registry branch. One row per
-- violation, tagged with the acceptance criterion it breaks.
-- See specs/dbt-model/clinical__condition_occurrence.md.

with condition_occurrence as (
    select * from {{ ref('clinical__condition_occurrence') }}
),

registration_conditions as (
    select * from {{ ref('patient_program_registration_conditions') }}
),

condition_categories as (
    select * from {{ ref('program_registry_condition_categories') }}
),

-- AC-009: a registry condition is recorded against the enrolment, so it has no visit; an
-- encounter diagnosis always has one (BL-008)
ac_009 as (
    select
        condition_occurrence_id,
        'AC-009' as failed_ac
    from condition_occurrence
    where (condition_type_source_value = 'program registry condition')
        != (visit_occurrence_id is null)
),

-- AC-011: the status on a registry row is a condition category code, not free text (BL-010)
ac_011 as (
    select
        co.condition_occurrence_id,
        'AC-011' as failed_ac
    from condition_occurrence co
    left join condition_categories cc on cc.code = co.condition_status_source_value
    where co.condition_type_source_value = 'program registry condition'
        and co.condition_status_source_value is not null
        and cc.code is null
),

-- AC-012: a removed condition is not a condition the patient has (BL-011)
ac_012 as (
    select
        co.condition_occurrence_id,
        'AC-012' as failed_ac
    from condition_occurrence co
    join registration_conditions rc on rc.id = co.condition_occurrence_id
    where co.condition_type_source_value = 'program registry condition'
        and rc.deleted_datetime is not null
)

select condition_occurrence_id, failed_ac from ac_009
union all select condition_occurrence_id, failed_ac from ac_011
union all select condition_occurrence_id, failed_ac from ac_012
