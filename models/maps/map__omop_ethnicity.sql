-- Tamanu ethnicity reference data -> OMOP custom concepts, one row per ethnicity.
-- See specs/dbt-model/map__omop_ethnicity.md for the BL clauses this model implements.
--
-- BL-001: one custom concept per ethnicity, joined by clinical__person for
-- ethnicity_source_concept_id.
-- BL-002: concept IDs come from the deployment's block in documentations/omop-custom-concepts.md.
-- BL-003: empty here, so the join is a no-op and every patient carries concept 0.
-- BL-004: a deployment that codes its ethnicity list disables this model and defines its own of
-- the same name, which carries the tests declared here.

select
    null::text as local_code,
    null::text as local_name,
    null::integer as concept_id,
    null::text as concept_name,
    null::text as vocabulary_id
where false
