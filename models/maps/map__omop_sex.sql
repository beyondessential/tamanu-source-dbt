-- Tamanu sex codes -> OMOP Gender concept IDs (OHDSI Athena, vocabulary 'Gender').
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
        ('male', 'Male', 8507, 'MALE', 'Gender'),
        ('female', 'Female', 8532, 'FEMALE', 'Gender'),
        ('other', 'Other', 0, 'No matching concept', 'Gender')
) as t (local_code, local_name, concept_id, concept_name, vocabulary_id)
