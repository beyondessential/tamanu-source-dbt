-- clinical__visit_occurrence -- OMOP-lite VISIT_OCCURRENCE domain. One row per encounter (BL-001).
-- Visit-concept shadow column sits alongside local encounter_type source value; native UUID PK
-- (D1 OMOP-lite). Sources only from bases/ (D10).
-- See specs/dbt-model/clinical__visit_occurrence.md for BL-001..BL-007.

with encounters as (
    select * from {{ ref('encounters') }}
),

visit_map as (
    select * from {{ ref('map__omop_visit_type') }}
),

locations as (
    select * from {{ ref('locations') }}
),

-- collect the distinct encounter types seen in history for each encounter;
-- used to detect admission encounters that passed through an ER phase (BL-002)
encounter_history_types as (
    select distinct
        encounter_id,
        encounter_type
    from {{ ref('encounter_history') }}
)

select
    -- identity (BL-001)
    e.id as visit_occurrence_id,

    -- patient FK (BL-001)
    e.patient_id as person_id,

    -- visit type: concept shadow + retained source value (BL-002)
    -- admission encounters that had a prior emergency/triage/observation phase
    -- map to 262 (Emergency Room and Inpatient Visit); all others use the map
    case
        when e.encounter_type = 'admission'
            and exists (
                select 1 from encounter_history_types eht
                where eht.encounter_id = e.id
                    and eht.encounter_type in ('emergency', 'triage', 'observation')
            )
        then 262
        else vm.concept_id
    end as visit_concept_id,

    -- visit datetimes (BL-004)
    e.start_datetime::date as visit_start_date,
    e.start_datetime       as visit_start_datetime,
    e.end_datetime::date   as visit_end_date,
    e.end_datetime         as visit_end_datetime,

    -- visit type provenance: constant EHR administration record (BL-003)
    32817 as visit_type_concept_id,

    -- provider and care site (BL-005, BL-006)
    -- care site is the ward: the location_group of the encounter's location. FK to
    -- ref__care_site (ward-type rows) (BL-006)
    e.clinician_id  as provider_id,
    loc.location_group_id as care_site_id,

    -- source value retained alongside concept (BL-007)
    e.encounter_type as visit_source_value

from encounters e
left join visit_map vm on vm.local_code = e.encounter_type
left join locations loc on loc.id = e.location_id
