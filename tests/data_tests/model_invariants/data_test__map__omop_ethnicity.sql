{{ config(severity = 'warn') }}

-- Invariants on map__omop_ethnicity, one row per gap tagged with the acceptance criterion it
-- breaks. See specs/dbt-model/map__omop_ethnicity.md for the clauses (BL-005, AC-009).
-- A gap is the earliest sign that the ethnicity list in Tamanu has moved on from the
-- deployment's map, and it leaves the affected patients on concept 0 in clinical__person.
--
-- BL-005: both checks run only when the map holds rows, so a deployment on the empty package map
-- reports nothing.

-- A current ethnicity reference record with no map row. A retired one a patient still carries is
-- caught by the patient check below.
select
    'AC-009' as failed_ac,
    'unmapped_reference_ethnicity' as failed_check,
    r.id as local_code
from {{ ref('reference_data') }} r
left join {{ ref('map__omop_ethnicity') }} m on m.local_code = r.id
where r.type = 'ethnicity'
    and r.visibility_status = 'current'
    and m.local_code is null
    and exists (select 1 from {{ ref('map__omop_ethnicity') }})

union all

-- An ethnicity recorded against a patient that clinical__person emits, with no map row.
select distinct
    'AC-009' as failed_ac,
    'unmapped_patient_ethnicity' as failed_check,
    a.ethnicity_id as local_code
from {{ ref('patient_additional_data') }} a
inner join {{ ref('patients') }} p on p.id = a.patient_id
left join {{ ref('map__omop_ethnicity') }} m on m.local_code = a.ethnicity_id
where nullif(a.ethnicity_id, '') is not null
    and m.local_code is null
    and exists (select 1 from {{ ref('map__omop_ethnicity') }})
