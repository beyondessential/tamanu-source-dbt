-- clinical__measurement -- OMOP-lite MEASUREMENT domain. One row per clinical measurement,
-- unioning three standard sources: vitals via the Tamanu Vitals survey (BL-006), lab tests
-- carrying a reading (BL-007), and birth anthropometry unpivoted from patient_birth_data
-- (BL-008, via int__patient_birth_measurements). Numeric results populate value_as_number;
-- categorical results keep value_source_value. FK graph wired from the encounter where one
-- exists (BL-002); *_concept_id (LOINC) deferred to the future vocab__ layer (BL-003).
-- Sources only from bases/ + intermediate (D10). Deployment-specific measurements are added
-- by per-deployment override (see spec). See spec for BL-001..BL-011.

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

encounters as (
    select * from {{ ref('encounters') }}
),

lab_tests as (
    select * from {{ ref('lab_tests') }}
),

lab_requests as (
    select * from {{ ref('lab_requests') }}
),

lab_test_types as (
    select * from {{ ref('lab_test_types') }}
),

lab_result_encoding as (
    select * from {{ ref('map__lab_test_result_encoding') }}
),

patient_birth_measurements as (
    select * from {{ ref('int__patient_birth_measurements') }}
),

-- every recorded answer to the core Vitals survey; numeric and categorical alike (BL-006)
vitals_answers as (
    select
        sra.id,
        trim(sra.body) as body,
        sra.data_element_id,
        sr.encounter_id,
        sr.start_datetime,
        sr.submitted_by_id
    from survey_response_answers sra
    join survey_responses sr on sr.id = sra.response_id
    join surveys s on s.id = sr.survey_id and s.survey_type = 'vitals'
    where sra.body is not null and trim(sra.body) != ''
),

-- vitals branch (BL-006). ids cast to varchar so the union with labs is type-safe
vitals_measurements as (
    select
        va.id::varchar          as measurement_id,
        e.patient_id::varchar   as person_id,
        va.start_datetime::date as measurement_date,
        va.start_datetime       as measurement_datetime,
        'vitals survey'         as measurement_type_source_value,  -- provenance / union discriminator (BL-005)
        case when va.body ~ '^-?[0-9]+(\.[0-9]+)?$' then va.body::numeric end as value_as_number,
        va.body                 as value_source_value,
        null::varchar           as unit_source_value,
        va.submitted_by_id::varchar as provider_id,
        va.encounter_id::varchar    as visit_occurrence_id,
        va.data_element_id::varchar as measurement_source_id,  -- BL-010
        pde.code as measurement_source_value,
        pde.name as measurement_source_name
    from vitals_answers va
    join encounters e on e.id = va.encounter_id
    left join program_data_elements pde on pde.id = va.data_element_id
),

-- BL-009: the reading is the typed result, else the result the test type encodes. Resolved once
-- here so the numeric cast, the emitted value and the has-a-reading filter all read the same thing
lab_test_readings as (
    select
        lt.id,
        lt.lab_request_id,
        lt.lab_test_type_id,
        lt.completed_datetime,
        coalesce(nullif(trim(lt.result), ''), nullif(trim(enc.encoded_result), '')) as reading
    from lab_tests lt
    -- BL-009: one row per type at most, so this cannot fan out
    left join lab_result_encoding enc on enc.lab_test_type_id = lt.lab_test_type_id
),

-- lab branch: lab tests carrying a reading, under a request that was not withdrawn (BL-007)
lab_measurements as (
    select
        lt.id::varchar        as measurement_id,
        e.patient_id::varchar as person_id,
        coalesce(lt.completed_datetime, lr.published_datetime, lr.requested_datetime)::date as measurement_date,
        coalesce(lt.completed_datetime, lr.published_datetime, lr.requested_datetime)       as measurement_datetime,  -- completed, else published/requested (BL-004)
        'lab'                 as measurement_type_source_value,
        case when lt.reading ~ '^-?[0-9]+(\.[0-9]+)?$' then lt.reading::numeric end as value_as_number,
        lt.reading            as value_source_value,
        ltt.unit              as unit_source_value,
        lr.requested_by_id::varchar as provider_id,
        lr.encounter_id::varchar    as visit_occurrence_id,
        lt.lab_test_type_id::varchar as measurement_source_id,  -- BL-010
        ltt.code as measurement_source_value,
        ltt.name as measurement_source_name
    from lab_test_readings lt
    join lab_requests lr on lr.id = lt.lab_request_id
    join encounters e on e.id = lr.encounter_id
    left join lab_test_types ltt on ltt.id = lt.lab_test_type_id
    -- BL-009: a reading exists where a result was recorded or the type encodes one
    where lt.reading is not null
      -- drop requests that never produced a valid result even if a stale value lingers.
      -- coalesce so a NULL status means "keep" rather than silently dropping the row
      and coalesce(lr.status, '') not in (
          'cancelled', 'deleted', 'entered-in-error', 'invalidated', 'rejected', 'sample-not-collected'
      )  -- BL-011
),

-- birth anthropometry, unpivoted upstream by int__patient_birth_measurements (BL-008).
-- Patient-level: no encounter, so provider_id and visit_occurrence_id are NULL
birth_measurements as (
    select
        (bm.patient_id || '-birthdata-' || bm.measurement_source_value)::varchar as measurement_id,
        bm.patient_id::varchar  as person_id,
        bm.measurement_datetime::date as measurement_date,
        bm.measurement_datetime as measurement_datetime,
        'birth data'            as measurement_type_source_value,
        case when trim(bm.value_source_value) ~ '^-?[0-9]+(\.[0-9]+)?$' then trim(bm.value_source_value)::numeric end as value_as_number,
        bm.value_source_value   as value_source_value,
        null::varchar           as unit_source_value,
        null::varchar           as provider_id,
        null::varchar           as visit_occurrence_id,
        null::varchar               as measurement_source_id,  -- BL-010
        bm.measurement_source_value as measurement_source_value,
        bm.measurement_source_name  as measurement_source_name
    from patient_birth_measurements bm
)

-- columns listed explicitly per branch so reordering one branch can't silently mis-map
select
    measurement_id,
    person_id,
    measurement_date,
    measurement_datetime,
    measurement_type_source_value,
    value_as_number,
    value_source_value,
    unit_source_value,
    provider_id,
    visit_occurrence_id,
    measurement_source_id,
    measurement_source_value,
    measurement_source_name
from vitals_measurements

union all

select
    measurement_id,
    person_id,
    measurement_date,
    measurement_datetime,
    measurement_type_source_value,
    value_as_number,
    value_source_value,
    unit_source_value,
    provider_id,
    visit_occurrence_id,
    measurement_source_id,
    measurement_source_value,
    measurement_source_name
from lab_measurements

union all

select
    measurement_id,
    person_id,
    measurement_date,
    measurement_datetime,
    measurement_type_source_value,
    value_as_number,
    value_source_value,
    unit_source_value,
    provider_id,
    visit_occurrence_id,
    measurement_source_id,
    measurement_source_value,
    measurement_source_name
from birth_measurements
