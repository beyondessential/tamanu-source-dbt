with related_conditions as (
    select
        ppr.id as patient_program_registration_id,
        string_agg(
            prc.name, '; '
            order by pprc.datetime
        ) as conditions,
        array_agg(
            pprc.program_registry_condition_id
            order by pprc.datetime
        ) as condition_ids,
        string_agg(
            prcc.name, '; '
            order by pprc.datetime
        ) as condition_categories,
        array_agg(
            pprc.program_registry_condition_category_id
            order by pprc.datetime
        ) as condition_category_ids
    from {{ ref('patient_program_registration_conditions') }} pprc
    join {{ ref('patient_program_registrations') }} ppr on ppr.id = pprc.patient_program_registration_id
    left join {{ ref('program_registry_conditions') }} prc on prc.id = pprc.program_registry_condition_id
    left join {{ ref('program_registry_condition_categories') }} prcc on prcc.id = pprc.program_registry_condition_category_id
    group by ppr.id
)

select
    ppr.id as patient_program_registration_id,
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    p.sex,
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
    pr.currently_at_type,
    c.condition_ids as related_condition_ids,
    c.conditions as related_conditions,
    c.condition_category_ids as related_condition_category_ids,
    c.condition_categories as related_condition_categories,
    prcs.id as clinical_status_id,
    prcs.name as clinical_status,
    ppr.registration_status,
    ppr.program_registry_id,
    ppr.datetime as registration_datetime,
    ppr.deactivated_by_id,
    deactivated_by.display_name as deactivated_by,
    ppr.deactivated_datetime
from {{ ref('patient_program_registrations') }} ppr
join {{ ref('program_registries') }} pr on pr.id = ppr.program_registry_id
join {{ ref('patients') }} p on p.id = ppr.patient_id
left join {{ ref('facilities') }} registering_facility on registering_facility.id = ppr.registering_facility_id
left join {{ ref('users') }} registered_by on registered_by.id = ppr.registered_by_id
left join {{ ref('reference_data') }} village on village.id = p.village_id
left join {{ ref('facilities') }} currently_at_facility on currently_at_facility.id = ppr.facility_id
left join {{ ref('reference_data') }} currently_at_village on currently_at_village.id = ppr.village_id
left join related_conditions c on c.patient_program_registration_id = ppr.id
left join {{ ref('program_registry_clinical_statuses') }} prcs on prcs.id = ppr.clinical_status_id
left join {{ ref('users') }} deactivated_by on deactivated_by.id = ppr.deactivated_by_id
