with related_conditions as (
    select
        pprc.patient_id,
        pprc.program_registry_id,
        string_agg(
            prc.name, '; '
            order by pprc.datetime
        ) as conditions,
        array_agg(
            pprc.program_registry_condition_id
            order by pprc.datetime
        ) as condition_ids
    from {{ ref('patient_program_registration_conditions') }} pprc
    left join {{ ref('program_registry_conditions') }} prc on prc.id = pprc.program_registry_condition_id
    group by pprc.program_registry_id, pprc.patient_id
)

select
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    initcap(p.sex::text) as sex,
    village.id as village_id,
    village.name as village,
    registering_facility.id as registering_facility_id,
    registering_facility.name as registering_facility,
    registered_by.id as registered_by_id,
    registered_by.display_name as registered_by,
    case
        when pr.currently_at_type = 'facility' then currently_at_facility.name
        when pr.currently_at_type = 'village' then currently_at_village.name
    end as currently_at,
    c.conditions as related_conditions,
    prcs.id as clinical_status_id,
    prcs.name as clinical_status,
    ppr.is_most_recent,
    ppr.registration_status,
    ppr.datetime as registration_datetime
from {{ ref('patient_program_registrations') }} ppr
join {{ ref('program_registries') }} pr on pr.id = ppr.program_registry_id
join {{ ref('patients') }} p on p.id = ppr.patient_id
join {{ ref('facilities') }} registering_facility on registering_facility.id = ppr.registering_facility_id
join {{ ref('users') }} registered_by on registered_by.id = ppr.registered_by_id
left join {{ ref('reference_data') }} village on village.id = p.village_id
left join {{ ref('facilities') }} currently_at_facility on currently_at_facility.id = ppr.facility_id
left join {{ ref('reference_data') }} currently_at_village on currently_at_village.id = ppr.village_id
left join related_conditions c on (c.patient_id, c.program_registry_id) = (ppr.patient_id, ppr.program_registry_id)
left join {{ ref('program_registry_clinical_statuses') }} prcs on prcs.id = ppr.clinical_status_id
order by ppr.datetime desc
