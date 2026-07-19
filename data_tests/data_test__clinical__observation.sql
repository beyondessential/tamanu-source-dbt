-- Singular tests for clinical__observation. One row per violation, tagged with the
-- acceptance criterion it breaks. See specs/dbt-model/clinical__observation.md.

with observation as (
    select * from {{ ref('clinical__observation') }}
),

-- AC-008: every survey/triage row has a recorded value_source_value. Only a
-- vaccination-not-given row may have a NULL value (the refusal itself is the fact,
-- with or without a recorded reason) (BL-006, BL-008)
ac_008 as (
    select
        observation_id,
        'AC-008' as failed_ac
    from observation
    where value_source_value is null
        and observation_type_source_value != 'vaccination not given'
)

select observation_id, failed_ac from ac_008
