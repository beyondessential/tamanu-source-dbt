-- int__program_enrolments -- one row per patient enrolment in a program registry, with the
-- registry, clinical status and currently-at resolved (BL-026).
--
-- Two models need these facts and they must not drift: clinical__episode, which is the OMOP
-- EPISODE domain and so carries only clinical facts, and ds__patient_program_registrations,
-- which is a consumer line list and carries what the Tamanu registry screen shows. Those
-- populations differ by exactly one status -- an enrolment recorded in error is not a clinical
-- fact (BL-002) but is still something the removed-patients report lists (BL-025) -- so the
-- resolution lives here and each consumer filters it rather than resolving it again.
--
-- Recorded-in-error rows are kept; clinical__episode drops them. Patients merged away are not:
-- a registration id embeds its patient id, so a merge cannot repoint it and the enrolment
-- strands on a record bases/patients drops (BL-001).
--
-- Ephemeral, so this is inlined into each consumer and materialises nothing.
--
-- Spec: specs/dbt-model/clinical__episode.md, BL-026.

with registrations as (
    select * from {{ ref('patient_program_registrations') }}
),

program_registries as (
    select * from {{ ref('program_registries') }}
),

clinical_statuses as (
    select * from {{ ref('program_registry_clinical_statuses') }}
),

facilities as (
    select * from {{ ref('facilities') }}
),

reference_data as (
    select * from {{ ref('reference_data') }}
),

patients as (
    select * from {{ ref('patients') }}
),

-- every enrolment held by a patient clinical__person carries, whatever its status (BL-001)
enrolments as (
    select r.*
    from registrations r
    join patients p on p.id = r.patient_id
)

select
    e.id as enrolment_id,
    e.patient_id as person_id,
    e.datetime as enrolment_datetime,
    e.registration_status,
    e.deactivated_datetime,
    e.deactivated_by_id,

    e.program_registry_id,
    pr.code as registry_code,
    pr.name as registry_name,
    pr.program_id,

    e.clinical_status_id,
    cs.code as clinical_status_code,
    cs.name as clinical_status_name,

    -- only the column the registry is configured for is maintained, so the other is ignored
    -- even when populated (BL-007)
    pr.currently_at_type,
    case pr.currently_at_type
        when 'facility' then e.facility_id
        when 'village' then e.village_id
    end as currently_at_id,
    case pr.currently_at_type
        when 'facility' then currently_at_facility.name
        when 'village' then currently_at_village.name
    end as currently_at_name,

    e.registering_facility_id,
    e.registered_by_id

from enrolments e
-- the registry is what the enrolment is in, so it is required: an enrolment whose registry has
-- been deleted is one neither consumer lists (BL-011)
join program_registries pr on pr.id = e.program_registry_id
-- every other lookup is left-joined: an enrolment with no clinical status set, or no registering
-- facility, is still a valid enrolment (BL-011)
left join clinical_statuses cs on cs.id = e.clinical_status_id
left join facilities currently_at_facility on currently_at_facility.id = e.facility_id
left join reference_data currently_at_village on currently_at_village.id = e.village_id
