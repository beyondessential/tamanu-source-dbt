{{ config(
    materialized = ('view' if target.name.startswith('reporting_') else 'table'),
    tags = ['clinical'],
) }}

-- clinical__visit_occurrence -- OMOP-lite VISIT_OCCURRENCE domain. One row per encounter (BL-001).
-- Visit-concept shadow column sits alongside local encounter_type source value; native UUID PK
-- (D1 OMOP-lite). Sources only from bases/ (D10).
-- See specs/dbt-model/clinical__visit_occurrence.md for BL-001..BL-007.

with encounters as (
    select * from {{ ref('encounters') }}
),

visit_map as (
    select * from {{ ref('map__omop_visit_type') }}
)

select
    -- identity (BL-001)
    e.id as visit_occurrence_id,

    -- patient FK (BL-001)
    e.patient_id as person_id,

    -- visit type: concept shadow + retained source value (BL-002)
    vm.concept_id as visit_concept_id,

    -- visit datetimes (BL-004)
    e.start_datetime::date as visit_start_date,
    e.start_datetime       as visit_start_datetime,
    e.end_datetime::date   as visit_end_date,
    e.end_datetime         as visit_end_datetime,

    -- visit type provenance: constant EHR administration record (BL-003)
    32817 as visit_type_concept_id,

    -- provider and care site (BL-005, BL-006)
    e.clinician_id  as provider_id,
    e.department_id as care_site_id,

    -- source value retained alongside concept (BL-007)
    e.encounter_type as visit_source_value

from encounters e
left join visit_map vm on vm.local_code = e.encounter_type
