-- ds__patient_program_registrations -- consumer-shaped registry line list.
--
-- BL-022: every enrolment fact -- registration status and datetime, registry, clinical
-- status, currently-at, registering facility, registered-by, deactivation -- comes from
-- int__program_enrolments, resolved once and shared with clinical__episode so the two
-- cannot drift.
-- BL-023: patient demographics, patient_additional_data contact and administrative columns,
-- and the related-condition aggregation stay here -- Tupaia presentation concerns, not part
-- of the OMOP episode.
-- BL-024: the output column set, names and order are unchanged.
-- BL-025: this model reads the wider population. An enrolment recorded in error is not a
-- clinical fact and so is absent from clinical__episode, but the removed-patients report
-- lists it and always has.
--
-- Spec: specs/dbt-model/clinical__episode.md, BL-022..BL-026.

-- BL-022: aggregated on the condition's own registration key, so no base registration table
-- is joined here either -- the enrolment population comes from int__program_enrolments alone,
-- and the left join to this aggregate below scopes it to that population
with related_conditions as (
    select
        pprc.patient_program_registration_id,
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
    left join {{ ref('program_registry_conditions') }} prc on prc.id = pprc.program_registry_condition_id
    left join {{ ref('program_registry_condition_categories') }} prcc on prcc.id = pprc.program_registry_condition_category_id
    group by pprc.patient_program_registration_id
)

select
    ep.enrolment_id as patient_program_registration_id,
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

    -- BL-022: resolved once, in int__program_enrolments
    ep.currently_at_name as currently_at,
    ep.currently_at_type,

    c.condition_ids as related_condition_ids,
    c.conditions as related_conditions,
    c.condition_category_ids as related_condition_category_ids,
    c.condition_categories as related_condition_categories,
    ep.clinical_status_id,
    ep.clinical_status_name as clinical_status,
    ep.registration_status,
    ep.program_registry_id,
    subdivision.id as subdivision_id,
    subdivision.name as subdivision,
    division.id as division_id,
    division.name as division,
    ep.enrolment_datetime as registration_datetime,
    ep.deactivated_by_id,
    deactivated_by.display_name as deactivated_by,
    ep.deactivated_datetime,
    pad.primary_contact_number,
    pad.secondary_contact_number,
    pad.emergency_contact_name,
    pad.emergency_contact_number
from {{ ref('int__program_enrolments') }} ep
join {{ ref('patients') }} p on p.id = ep.person_id
left join {{ ref("patient_additional_data") }} pad on pad.patient_id = p.id
left join {{ ref('facilities') }} registering_facility on registering_facility.id = ep.registering_facility_id
left join {{ ref('users') }} registered_by on registered_by.id = ep.registered_by_id
left join {{ ref('reference_data') }} village on village.id = p.village_id
left join {{ ref('reference_data') }} subdivision on subdivision.id = pad.subdivision_id
left join {{ ref('reference_data') }} division on division.id = pad.division_id
left join related_conditions c on c.patient_program_registration_id = ep.enrolment_id
left join {{ ref('users') }} deactivated_by on deactivated_by.id = ep.deactivated_by_id
