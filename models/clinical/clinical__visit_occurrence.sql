-- clinical__visit_occurrence -- OMOP-lite VISIT_OCCURRENCE domain. One row per encounter,
-- provided its encounter_type is covered by map__omop_visit_type (BL-001, BL-002 -- inner
-- join, see BL-002 for the consequence of an unmapped encounter_type). Visit-concept shadow
-- column sits alongside local encounter_type source value; native UUID PK (D1 OMOP-lite).
-- Sources only from bases/ (D10).
-- See specs/dbt-model/clinical__visit_occurrence.md for BL-001..BL-008.

with encounters as (
    select * from {{ ref('encounters') }}
),

visit_map as (
    select * from {{ ref('map__omop_visit_type') }}
),

-- collect the distinct encounter types seen in history for each encounter;
-- used to detect admission encounters that passed through an ER phase (BL-002)
encounter_history_types as (
    select distinct
        encounter_id,
        encounter_type
    from {{ ref('encounter_history') }}
),

-- BL-002: encounters with an emergency, triage or observation phase in their history -- an
-- admission among them is an ER-to-admission episode (262)
er_phases as (
    select distinct encounter_id
    from encounter_history_types
    where encounter_type in ('emergency', 'triage', 'observation')
)

select
    -- identity (BL-001)
    e.id as visit_occurrence_id,

    -- patient FK (BL-001)
    e.patient_id as person_id,

    -- visit type: concept shadow + retained source value (BL-002)
    -- admission encounters that had a prior emergency/triage/observation phase
    -- map to 262 (Emergency Room and Inpatient Visit); all others use the map
    case when e.encounter_type = 'admission' and er.encounter_id is not null then 262 else vm.concept_id end as visit_concept_id,
    -- the concept's OMOP name, the same choice as visit_concept_id (BL-002)
    case
        when e.encounter_type = 'admission' and er.encounter_id is not null
            then 'Emergency Room and Inpatient Visit'
        else vm.concept_name
    end as visit_concept_name,

    -- visit datetimes (BL-004)
    e.start_datetime::date as visit_start_date,
    e.start_datetime as visit_start_datetime,
    e.end_datetime::date as visit_end_date,
    e.end_datetime as visit_end_datetime,

    -- visit type provenance: constant EHR administration record (BL-003)
    32817 as visit_type_concept_id,

    -- provider (BL-005)
    e.clinician_id as provider_id,

    -- care site is the encounter's location. FK to ref__care_site (location-type rows) (BL-006)
    e.location_id as care_site_id,

    -- department carried as an attribute. FK to ref__care_site (department-type rows) (BL-008)
    e.department_id,

    -- source value retained alongside concept (BL-007)
    e.encounter_type as visit_source_value

from encounters e
join visit_map vm on vm.local_code = e.encounter_type
left join er_phases er on er.encounter_id = e.id
