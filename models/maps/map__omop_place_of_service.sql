-- Tamanu facilities.type codes -> OMOP place-of-service classification.
-- View-over-values rather than a seed so it ships in the compiled production bundle.
--
-- BASELINE DEFAULT — expected to be overridden per deployment. Tamanu core declares
-- Facility.type as a free-text string (Sequelize.STRING; no enum), so the values below
-- are best-effort archetypes, not a canonical set. A deployment with real facility.type
-- values overrides this model in its tamanu-dbt-<deployment> project (the same package
-- override mechanism used for map__omop_ethnicity). An unmapped/unknown type falls
-- through to a NULL concept in ref__care_site (the row is kept, never dropped), so this
-- default is safe to ship: it never asserts a wrong concept, only a NULL one.
--
-- OMOP-lite classification: place-of-service source concepts map into the standard
-- Visit-setting concepts (Inpatient/Outpatient/ER) in the OHDSI vocabularies, and those
-- standard concepts are already the ones used by map__omop_visit_type, so we reuse them
-- here rather than introduce unverified Place-of-Service-vocabulary IDs.

select
    local_code,
    local_name,
    concept_id,
    concept_name,
    vocabulary_id
from (
    values
        ('hospital',      'Hospital',       9201, 'Inpatient Visit',      'Visit'),
        ('clinic',        'Clinic',         9202, 'Outpatient Visit',     'Visit'),
        ('health_centre', 'Health Centre',  9202, 'Outpatient Visit',     'Visit'),
        ('dispensary',    'Dispensary',     9202, 'Outpatient Visit',     'Visit'),
        ('emergency',     'Emergency',      9203, 'Emergency Room Visit', 'Visit')
) as t (local_code, local_name, concept_id, concept_name, vocabulary_id)
