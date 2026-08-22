-- ds__patient_program_registrations -- consumer-shaped registry line list.
--
-- Enrolment facts come from clinical__episode, so the currently-at resolution and the episode
-- boundaries have one definition rather than two that drift (BL-022). Patient demographics,
-- patient_additional_data contact and administrative columns, and the related-condition
-- aggregation stay here: they are Tupaia presentation concerns and not part of the OMOP
-- episode (BL-023). The output column set is unchanged (BL-024).
--
-- Reading through clinical__episode also drops enrolments recorded in error, which this model
-- previously listed (BL-025).
--
-- Spec: specs/dbt-model/clinical__episode.md, BL-022..BL-025.

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
    ep.episode_id as patient_program_registration_id,
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

    -- resolved once, in clinical__episode (BL-022)
    ep.currently_at_name as currently_at,
    ep.currently_at_type,

    c.condition_ids as related_condition_ids,
    c.conditions as related_conditions,
    c.condition_category_ids as related_condition_category_ids,
    c.condition_categories as related_condition_categories,
    prcs.id as clinical_status_id,
    ep.clinical_status_source_name as clinical_status,
    ep.registration_status,
    ppr.program_registry_id,
    subdivision.id as subdivision_id,
    subdivision.name as subdivision,
    division.id as division_id,
    division.name as division,
    ep.episode_start_datetime as registration_datetime,
    ppr.deactivated_by_id,
    deactivated_by.display_name as deactivated_by,
    ppr.deactivated_datetime,
    pad.primary_contact_number,
    pad.secondary_contact_number,
    pad.emergency_contact_name,
    pad.emergency_contact_number
from {{ ref('clinical__episode') }} ep
join {{ ref('patient_program_registrations') }} ppr on ppr.id = ep.episode_id
join {{ ref('patients') }} p on p.id = ep.person_id
left join {{ ref("patient_additional_data") }} pad on pad.patient_id = p.id
left join {{ ref('facilities') }} registering_facility on registering_facility.id = ep.care_site_id
left join {{ ref('users') }} registered_by on registered_by.id = ep.provider_id
left join {{ ref('reference_data') }} village on village.id = p.village_id
left join {{ ref('reference_data') }} subdivision on subdivision.id = pad.subdivision_id
left join {{ ref('reference_data') }} division on division.id = pad.division_id
left join related_conditions c on c.patient_program_registration_id = ep.episode_id
left join {{ ref('program_registry_clinical_statuses') }} prcs on prcs.id = ppr.clinical_status_id
left join {{ ref('users') }} deactivated_by on deactivated_by.id = ppr.deactivated_by_id
