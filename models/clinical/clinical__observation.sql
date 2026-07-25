-- clinical__observation -- OMOP-lite OBSERVATION domain. One row per clinical fact that is
-- neither a measurement nor a drug exposure, unioning three standard sources:
-- program/referral-survey answers (BL-006), vaccinations not given (BL-007), and triage
-- assessments unpivoted from triages (BL-008, via int__triage_observations). The observed
-- fact is retained as source code/name; FK graph wired from the encounter (BL-002);
-- *_concept_id deferred to the future vocab__ layer (BL-003). Sources only from bases/ +
-- intermediate (D10). Deployment-specific observation sources are added by per-deployment
-- override (see spec). See spec for BL-001..BL-008.

with survey_response_answers as (
    select * from {{ ref('survey_response_answers') }}
),

survey_responses as (
    select * from {{ ref('survey_responses') }}
),

surveys as (
    select * from {{ ref('surveys') }}
),

program_data_elements as (
    select * from {{ ref('program_data_elements') }}
),

vaccine_administrations as (
    select * from {{ ref('vaccine_administrations') }}
),

vaccine_schedules as (
    select * from {{ ref('vaccine_schedules') }}
),

reference_data as (
    select * from {{ ref('reference_data') }}
),

triage_observations as (
    select * from {{ ref('int__triage_observations') }}
),

encounters as (
    select * from {{ ref('encounters') }}
),

-- every recorded answer to a programs/referral survey; sensitive surveys included, echo /
-- non-answer question types excluded (BL-006)
survey_answers as (
    select
        sra.id,
        trim(sra.body) as body,
        s.survey_type,
        sr.encounter_id,
        sr.start_datetime,
        sr.submitted_by_id,
        pde.code,
        pde.name
    from survey_response_answers sra
    join survey_responses sr on sr.id = sra.response_id
    join surveys s on s.id = sr.survey_id and s.survey_type in ('programs', 'referral')
    join program_data_elements pde
        on pde.id = sra.data_element_id
        -- coalesce so a NULL type means "keep" rather than silently dropping the answer
        and coalesce(pde.type, '') not in ('PatientData', 'UserData', 'Instruction')
    where sra.body is not null and trim(sra.body) != ''
),

-- survey branch (BL-006). ids cast to varchar so the union is type-safe (BL-002)
survey_observations as (
    select
        sa.id::varchar           as observation_id,
        e.patient_id::varchar    as person_id,
        sa.start_datetime::date  as observation_date,
        sa.start_datetime        as observation_datetime,
        -- provenance / union discriminator (BL-005)
        case sa.survey_type
            when 'programs' then 'program survey'
            else 'referral survey'
        end                      as observation_type_source_value,
        case when sa.body ~ '^-?[0-9]+(\.[0-9]+)?$' then sa.body::numeric end as value_as_number,
        sa.body                  as value_source_value,
        sa.submitted_by_id::varchar as provider_id,
        sa.encounter_id::varchar as visit_occurrence_id,
        sa.code as observation_source_value,
        sa.name as observation_source_name
    from survey_answers sa
    join encounters e on e.id = sa.encounter_id
),

-- vaccination-not-given branch (BL-007): the refusal/not-done fact is the observation, so
-- rows are kept even when no reason was recorded. Vaccine identity carried like
-- clinical__drug_exposure: vaccine_name as the name, code via the scheduled vaccine
not_given_observations as (
    select
        av.id::varchar        as observation_id,
        e.patient_id::varchar as person_id,
        av.datetime::date     as observation_date,
        av.datetime           as observation_datetime,  -- when the not-given was recorded (BL-004)
        'vaccination not given' as observation_type_source_value,
        null::numeric         as value_as_number,
        coalesce(rdr.name, av.reason) as value_source_value,
        -- recorded_by_id (a real user FK) preferred; given_by is free text, so the FK test
        -- is scoped off this branch (BL-002)
        coalesce(av.recorded_by_id, av.given_by)::varchar as provider_id,
        av.encounter_id::varchar as visit_occurrence_id,
        rd.code         as observation_source_value,
        av.vaccine_name as observation_source_name
    from vaccine_administrations av
    join encounters e on e.id = av.encounter_id
    left join reference_data rdr on rdr.id = av.not_given_reason_id
    left join vaccine_schedules vs on vs.id = av.scheduled_vaccine_id
    left join reference_data rd on rd.id = vs.vaccine_id
    where av.status = 'NOT_GIVEN'
),

-- triage branch, unpivoted upstream by int__triage_observations (BL-008). The synthetic
-- id is <triage_id>-<element>, unique since each triage yields each element at most once
triage_branch_observations as (
    select
        (t.triage_id || '-' || t.observation_source_value)::varchar as observation_id,
        e.patient_id::varchar         as person_id,
        t.observation_datetime::date  as observation_date,
        t.observation_datetime        as observation_datetime,
        'triage'                      as observation_type_source_value,
        case when trim(t.value_source_value) ~ '^-?[0-9]+(\.[0-9]+)?$' then trim(t.value_source_value)::numeric end as value_as_number,
        t.value_source_value          as value_source_value,
        t.clinician_id::varchar       as provider_id,
        t.encounter_id::varchar       as visit_occurrence_id,
        t.observation_source_value    as observation_source_value,
        t.observation_source_name     as observation_source_name
    from triage_observations t
    join encounters e on e.id = t.encounter_id
)

-- columns listed explicitly per branch so reordering one branch can't silently mis-map
select
    observation_id,
    person_id,
    observation_date,
    observation_datetime,
    observation_type_source_value,
    value_as_number,
    value_source_value,
    provider_id,
    visit_occurrence_id,
    observation_source_value,
    observation_source_name
from survey_observations

union all

select
    observation_id,
    person_id,
    observation_date,
    observation_datetime,
    observation_type_source_value,
    value_as_number,
    value_source_value,
    provider_id,
    visit_occurrence_id,
    observation_source_value,
    observation_source_name
from not_given_observations

union all

select
    observation_id,
    person_id,
    observation_date,
    observation_datetime,
    observation_type_source_value,
    value_as_number,
    value_source_value,
    provider_id,
    visit_occurrence_id,
    observation_source_value,
    observation_source_name
from triage_branch_observations
