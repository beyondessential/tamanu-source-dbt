{{ config(severity='error') }}

-- Overrides dbt_project.yml's project-wide `data_tests: +severity: warn`. This test is a
-- schema-drift alarm, and the drift it catches is silent: the two models below inner-join
-- the map, so an unmapped encounter_type removes those encounters from the OMOP layer
-- while the build still reports success. A warning does not stop that, so this one errors.

-- Coverage test: every encounter_type actually recorded in encounters or encounter_history
-- must have a matching row in map__omop_visit_type.local_code. This is the earliest point a
-- schema-drift gap (a new Tamanu encounter_type not yet added to the map) can be caught --
-- before it reaches clinical__visit_detail (BL-003 there) or clinical__visit_occurrence
-- (BL-002 there), both of which inner-join the map and would otherwise silently exclude the
-- affected encounter/segment entirely. One row per unmapped encounter_type value found in
-- the source data.

with encounter_types as (
    select encounter_type from {{ ref('encounters') }}
    union
    select encounter_type from {{ ref('encounter_history') }}
),

visit_map as (
    select * from {{ ref('map__omop_visit_type') }}
)

select distinct
    et.encounter_type,
    'unmapped_encounter_type' as failed_check
from encounter_types et
left join visit_map vm on vm.local_code = et.encounter_type
where vm.local_code is null
