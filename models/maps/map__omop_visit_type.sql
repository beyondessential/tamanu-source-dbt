-- Tamanu encounter_type codes -> OMOP Visit concept IDs (OHDSI Athena, vocabulary 'Visit').
-- Universal mapping: applies to every deployment, so it lives in tamanu-source-dbt
-- (derived-elements-conventions.md § map__omop seeds).
-- View-over-values rather than a seed so it ships in the compiled production bundle.

select
    local_code,
    local_name,
    concept_id,
    concept_name,
    vocabulary_id
from (
    values
        ('admission',       'Inpatient Admission',  9201, 'Inpatient Visit',          'Visit'),
        ('clinic',          'Outpatient Clinic',    9202, 'Outpatient Visit',          'Visit'),
        ('imaging',         'Imaging',              9202, 'Outpatient Visit',          'Visit'),
        ('emergency',       'Emergency',            9203, 'Emergency Room Visit',      'Visit'),
        ('observation',     'Observation',          9202, 'Outpatient Visit',          'Visit'),
        ('triage',          'Triage',               9203, 'Emergency Room Visit',      'Visit'),
        ('surveyResponse',  'Survey Response',         0, 'No matching concept',       'Visit'),
        ('vaccination',     'Vaccination',          9202, 'Outpatient Visit',          'Visit')
) as t (local_code, local_name, concept_id, concept_name, vocabulary_id)
